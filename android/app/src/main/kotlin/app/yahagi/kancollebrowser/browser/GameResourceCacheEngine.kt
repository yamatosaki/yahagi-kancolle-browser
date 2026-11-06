package app.yahagi.kancollebrowser.browser

import java.net.HttpURLConnection
import java.net.URI
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FilterInputStream
import java.io.InputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock

enum class GameResourceResponseSource { CACHE, NETWORK }

class GameResourceResponse(
    private val bodyBytes: ByteArray = ByteArray(0),
    val mimeType: String,
    val encoding: String?,
    val statusCode: Int = 200,
    val reasonPhrase: String = "OK",
    val headers: Map<String, String> = emptyMap(),
    val source: GameResourceResponseSource,
    private val file: File? = null,
    private val deleteFileOnClose: Boolean = false,
) {
    val bytes: ByteArray get() = file?.readBytes() ?: bodyBytes
    val bodyLength: Long = file?.length() ?: bodyBytes.size.toLong()

    fun openStream(): InputStream {
        val resourceFile = file ?: return ByteArrayInputStream(bodyBytes)
        val input = resourceFile.inputStream()
        if (!deleteFileOnClose) return input
        return object : FilterInputStream(input) {
            override fun close() {
                try { super.close() } finally { resourceFile.delete() }
            }
        }
    }

    fun discard() {
        if (deleteFileOnClose) file?.delete()
    }
}

class GameResourceCacheEngine(
    private val store: GameResourceCacheStore,
    private val fetcher: GameResourceFetcher,
    private val clock: () -> Long = System::currentTimeMillis,
    private val modeProvider: () -> GameResourceCacheMode,
) {
    private val locks = Array(64) { ReentrantLock() }
    private val downloadPermits = Semaphore(2)
    private val legacyMigrationDone = AtomicBoolean(false)
    private val legacyMigrationLock = ReentrantLock()

    private fun ensureLegacyMigration(deadlineNanos: Long = Long.MAX_VALUE): Boolean {
        if (legacyMigrationDone.get()) return true
        val acquired = if (deadlineNanos == Long.MAX_VALUE) {
            legacyMigrationLock.lock()
            true
        } else acquireWithinDeadline(legacyMigrationLock, deadlineNanos)
        if (!acquired) return false
        try {
            if (legacyMigrationDone.get()) return true
            // Index loading and migration run on the caller's background I/O path.
            store.removeLegacyHostlessEntries()
            legacyMigrationDone.set(true)
            return true
        } finally {
            legacyMigrationLock.unlock()
        }
    }

    private fun acquireWithinDeadline(lock: ReentrantLock, deadlineNanos: Long): Boolean =
        try {
            val remaining = deadlineNanos - System.nanoTime()
            remaining > 0 && lock.tryLock(remaining, TimeUnit.NANOSECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }

    fun fetch(
        url: String,
        requestHeaders: Map<String, String> = emptyMap(),
        method: String = "GET",
        expectedLength: Long? = null,
        shouldStore: () -> Boolean = { true },
        waitForSlot: Boolean = false,
    ): GameResourceResponse? {
        val deadlineNanos = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(fetcher.budgetMillis(url).coerceAtLeast(1))
        val mode = modeProvider()
        if (!mode.readsCache || requestHeaders.size > 32 ||
            requestHeaders.any { (name, value) -> name.length > 128 || value.length > 8_192 } ||
            !GameResourceCacheRules.shouldCache(url, method) ||
            requestHeaders.keys.any { name -> BYPASS_REQUEST_HEADERS.any { it.equals(name, true) } ||
                (name.startsWith("X-", ignoreCase = true) &&
                    !name.equals("X-Requested-With", ignoreCase = true)) } ||
            requestHeaders.value("Cache-Control").hasDirective("no-store") ||
            requestHeaders.value("Cache-Control").hasDirective("only-if-cached")
        ) return null
        if (!ensureLegacyMigration(deadlineNanos)) return null
        val key = GameResourceCacheKey.from(url, requestHeaders) ?: return null
        val lock = locks[(key.hashCode() and Int.MAX_VALUE) % locks.size]
        if (!acquireWithinDeadline(lock, deadlineNanos)) return null
        try {
            val storeGeneration = store.generation()
            val cached = store.readFile(key)
            val cachedLengthMismatch = cached != null && expectedLength != null &&
                cached.entry.byteLength != expectedLength
            // Keep beta2's hot-cache behavior for reload headers and response no-cache.
            // Explicit must-revalidate, zero max-age, and bootstrap validation still apply.
            val forceValidation =
                cached?.entry?.responseHeaders?.value("Cache-Control").hasDirective("must-revalidate") ||
                cached?.entry?.responseHeaders?.value("Cache-Control").hasDirective("max-age", "0")
            val mustValidate = GameResourceCacheRules.isAlwaysValidated(url) ||
                cachedLengthMismatch ||
                forceValidation ||
                (cached != null && cached.entry.version == null &&
                    clock() - cached.entry.lastValidatedAt >= UNVERSIONED_TTL_MS)
            if (cached != null && !mustValidate) return cached.toResponse()
            val strictValidation = GameResourceCacheRules.requiresStrictValidation(url)

            val acquired = try {
                val remaining = deadlineNanos - System.nanoTime()
                remaining > 0 && if (waitForSlot) downloadPermits.tryAcquire(remaining, TimeUnit.NANOSECONDS)
                    else downloadPermits.tryAcquire()
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                false
            }
            if (!acquired) {
                return if (strictValidation || forceValidation || cachedLengthMismatch) null
                    else cached?.toResponse()
            }
            try {
            val validationEntry = cached?.entry?.takeUnless { cachedLengthMismatch }
            val fetched = runCatching { fetcher.fetchWithinDeadline(url, requestHeaders, validationEntry, deadlineNanos) }.getOrNull()
                ?: return if (strictValidation || forceValidation || cachedLengthMismatch ||
                    store.generation() != storeGeneration) null else cached?.toResponse()
            var retainFetchedFile = false
            try {
            if (fetched.statusCode == HttpURLConnection.HTTP_NOT_MODIFIED) {
                if (cachedLengthMismatch) return null
                if (!fetched.headers.isCacheableResponse()) {
                    store.removeIfGeneration(key, storeGeneration)
                    return null
                }
                val updatedHeaders = fetched.headers.filterKeys { name ->
                    name.lowercase() !in HOP_BY_HOP_HEADERS &&
                        !name.equals("Content-Length", ignoreCase = true)
                }
                if (cached == null) return null
                return store.markVerifiedValidated(key, cached, updatedHeaders, storeGeneration)?.toResponse()
            }
            if (fetched.statusCode != HttpURLConnection.HTTP_OK) {
                if (fetched.statusCode == HttpURLConnection.HTTP_PARTIAL) return null
                return if (strictValidation || forceValidation || cachedLengthMismatch ||
                    store.generation() != storeGeneration) null else cached?.toResponse()
            }
            // WebView must process Set-Cookie itself. The fetcher stops before reading this body.
            if (fetched.headers.value("Set-Cookie") != null ||
                fetched.headers.value("Set-Cookie2") != null) {
                store.removeIfGeneration(key, storeGeneration)
                return null
            }
            val cacheableResponse = fetched.headers.isCacheableResponse()
            if (!cacheableResponse) store.removeIfGeneration(key, storeGeneration)
            val declaredLength = fetched.headers.value("Content-Length")?.toLongOrNull()
            if (fetched.bodyLength > HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES ||
                declaredLength != null && declaredLength != fetched.bodyLength) {
                return if (strictValidation || store.generation() != storeGeneration) null
                    else cached?.toResponse()
            }
            val mimeInfo = GameResourceCacheRules.mimeTypeFor(url)
            val mimeType = fetched.headers.value("Content-Type")
                ?.substringBefore(';')
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?: mimeInfo.mime
            val matchesManifest = expectedLength == null ||
                expectedLength == fetched.bodyLength
            if (matchesManifest && cacheableResponse && modeProvider().writesCache && shouldStore()) {
                try {
                    if (fetched.file != null) store.commitFileWithEviction(
                    key = key, source = fetched.file,
                    version = runCatching { URI(url).rawQuery }.getOrNull(),
                    mimeType = mimeType,
                    etag = fetched.headers.value("ETag"),
                    lastModified = fetched.headers.value("Last-Modified"),
                    responseHeaders = GameResourceCacheRules.persistedResponseHeaders(fetched.headers),
                    expectedGeneration = storeGeneration,
                ) else store.commitWithEviction(
                    key = key, bytes = fetched.bytes,
                    version = runCatching { URI(url).rawQuery }.getOrNull(),
                    mimeType = mimeType,
                    etag = fetched.headers.value("ETag"),
                    lastModified = fetched.headers.value("Last-Modified"),
                    responseHeaders = GameResourceCacheRules.persistedResponseHeaders(fetched.headers),
                    expectedGeneration = storeGeneration,
                )
                } catch (_: IllegalArgumentException) {
                    // The response is still usable; only its cache metadata was rejected.
                    null
                }
            }
            // The fetched body was already bounded and the store checks its own copy.
            // Keep the owned download for this response instead of reopening/rehashing
            // the newly committed cache file. A concurrent clear cannot delete it.
            val responseFile = fetched.file
            retainFetchedFile = responseFile != null && responseFile == fetched.file
            return GameResourceResponse(
                bodyBytes = fetched.bytes,
                mimeType = mimeType,
                encoding = mimeInfo.encoding,
                statusCode = fetched.statusCode,
                reasonPhrase = fetched.reasonPhrase,
                headers = fetched.headers,
                source = GameResourceResponseSource.NETWORK,
                file = responseFile,
                deleteFileOnClose = retainFetchedFile,
            )
            } finally {
                if (!retainFetchedFile) fetched.file?.delete()
            }
            } finally {
                downloadPermits.release()
            }
        } finally {
            lock.unlock()
        }
    }

    fun status(): GameResourceCacheStatus {
        ensureLegacyMigration()
        store.enforcePolicy()
        return statusSnapshot()
    }

    fun statusSnapshot(): GameResourceCacheStatus {
        ensureLegacyMigration()
        return GameResourceCacheStatus(
            usedBytes = store.totalBytes(),
            maxBytes = store.maxBytes,
            fileCount = store.entryCount(),
        )
    }

    fun enforcePolicy(maxDurationMs: Long = Long.MAX_VALUE) {
        ensureLegacyMigration()
        store.enforcePolicy(maxDurationMs)
    }

    fun closeMaintenance() = store.closeMaintenance()

    fun clear() = store.clear()

    fun entries(): List<GameResourceCacheEntry> {
        ensureLegacyMigration()
        return store.entries()
    }

    fun hasCached(url: String): Boolean {
        return inspect(url).state == GameResourceInspectionState.VALID
    }

    fun hasCachedMetadata(url: String, expectedLength: Long? = null): Boolean {
        return inspectMetadata(url, expectedLength).state == GameResourceInspectionState.VALID
    }

    fun inspect(url: String, expectedLength: Long? = null): GameResourceInspection =
        inspect(url, verifyChecksum = true, expectedLength = expectedLength)

    fun inspectMetadata(url: String, expectedLength: Long? = null): GameResourceInspection =
        inspect(url, verifyChecksum = false, expectedLength = expectedLength)

    private fun inspect(
        url: String,
        verifyChecksum: Boolean,
        expectedLength: Long?,
    ): GameResourceInspection {
        ensureLegacyMigration()
        val key = GameResourceCacheKey.from(url)
            ?: return GameResourceInspection(GameResourceInspectionState.MISSING)
        val stored = if (verifyChecksum) store.inspect(key) else store.inspectMetadata(key)
        val entry = stored.entry
        val state = when {
            stored.state == GameResourceStoredState.MISSING -> GameResourceInspectionState.MISSING
            stored.state == GameResourceStoredState.DAMAGED -> GameResourceInspectionState.DAMAGED
            entry != null && expectedLength != null && entry.byteLength != expectedLength ->
                GameResourceInspectionState.OUTDATED
            entry != null && expectedLength == null && entry.version == null &&
                clock() - entry.lastValidatedAt >= UNVERSIONED_TTL_MS ->
                GameResourceInspectionState.OUTDATED
            else -> GameResourceInspectionState.VALID
        }
        return GameResourceInspection(state, entry?.byteLength ?: 0L)
    }

    fun availableDeviceBytes(): Long = store.availableDeviceBytes()

    private fun GameResourceCachedFile.toResponse(): GameResourceResponse {
        val mime = entry.mimeType
        val encoding = if (mime.startsWith("text/") || mime.contains("javascript") || mime.contains("json")) "utf-8" else null
        return GameResourceResponse(
            file = file,
            mimeType = mime,
            encoding = encoding,
            headers = buildMap {
                putAll(entry.responseHeaders)
                if (keys.none { it.equals("ETag", true) }) entry.etag?.let { put("ETag", it) }
                if (keys.none { it.equals("Last-Modified", true) }) {
                    entry.lastModified?.let { put("Last-Modified", it) }
                }
                keys.filter { it.equals("Content-Length", true) }.forEach(::remove)
                put("Content-Length", entry.byteLength.toString())
            },
            source = GameResourceResponseSource.CACHE,
        )
    }

    private fun Map<String, String>.value(name: String): String? =
        entries.firstOrNull { it.key.equals(name, ignoreCase = true) }?.value

    private fun Map<String, String>.isCacheableResponse(): Boolean {
        if (value("Set-Cookie") != null || value("Set-Cookie2") != null ||
            value("Vary") != null
        ) return false
        val cacheControl = value("Cache-Control")
        return !cacheControl.hasDirective("private") && !cacheControl.hasDirective("no-store")
    }

    private fun String?.hasDirective(name: String, value: String? = null): Boolean =
        this?.split(',')?.any { directive ->
            val parts = directive.trim().split('=', limit = 2)
            parts[0].equals(name, ignoreCase = true) &&
                (value == null || parts.getOrNull(1)?.trim()?.trim('"') == value)
        } == true

    companion object {
        const val UNVERSIONED_TTL_MS: Long = 6L * 60L * 60L * 1000L
        private val HOP_BY_HOP_HEADERS = setOf(
            "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
            "te", "trailer", "transfer-encoding", "upgrade", "set-cookie",
        )
        private val BYPASS_REQUEST_HEADERS = setOf(
            "Range", "If-Range", "If-None-Match", "If-Modified-Since",
            "If-Match", "If-Unmodified-Since", "Authorization", "Proxy-Authorization",
        )
    }
}

enum class GameResourceInspectionState { MISSING, VALID, DAMAGED, OUTDATED }

data class GameResourceInspection(
    val state: GameResourceInspectionState,
    val byteLength: Long = 0L,
)

data class GameResourceCacheStatus(
    val usedBytes: Long,
    val maxBytes: Long,
    val fileCount: Int,
)
