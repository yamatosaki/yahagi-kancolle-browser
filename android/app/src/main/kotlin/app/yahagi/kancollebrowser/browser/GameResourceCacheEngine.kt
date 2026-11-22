package app.yahagi.kancollebrowser.browser

import java.net.HttpURLConnection
import java.net.URI
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FilterInputStream
import java.io.InputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
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
    bodyStream: InputStream? = null,
    streamLength: Long = 0L,
) {
    private val ownedStream = bodyStream?.let { AtomicReference(it) }
    val bytes: ByteArray get() = if (ownedStream != null) openStream().use { it.readBytes() }
        else file?.readBytes() ?: bodyBytes
    val bodyLength: Long = if (bodyStream != null) streamLength else file?.length() ?: bodyBytes.size.toLong()

    fun openStream(): InputStream {
        if (ownedStream != null) return checkNotNull(ownedStream.getAndSet(null)) { "Resource stream already opened" }
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
        ownedStream?.getAndSet(null)?.close()
        if (deleteFileOnClose) file?.delete()
    }
}

class GameResourceCacheEngine internal constructor(
    private val store: GameResourceCacheStore,
    private val fetcher: GameResourceFetcher,
    private val clock: () -> Long = System::currentTimeMillis,
    private val kanxyHttpImageCache: () -> KanxyHttpImageCache? = { null },
    private val resourceRouteGeneration: () -> Long = { 0L },
    private val kanxyDiskCache: KanxyDiskResourceCache? = null,
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

    /** Resolve against Kanxy without reading or changing the stock resource cache. */
    internal fun fetchFresh(
        url: String,
        requestHeaders: Map<String, String> = emptyMap(),
        method: String = "GET",
        ownsImageCache: () -> Boolean = { true },
        report: ((KanxyImageCacheEvent) -> Unit)? = null,
    ): GameResourceResponse? {
        if (!GameResourceCacheRules.shouldCache(url, method)) return null
        val supportedAsset = { kanxyDiskCache?.supports(url) ?: KanxyHttpImageCache.supports(url) }
        if (requestHeaders.keys.any { name -> FRESH_BYPASS_HEADERS.any { it.equals(name, true) } } ||
            requestHeaders.any { (name, value) -> name.equals("Cache-Control", true) && value.hasDirective("only-if-cached") }
        ) {
            if (report != null && supportedAsset()) report(KanxyImageCacheEvent.REQUEST_BYPASS)
            return null
        }
        val route = resourceRouteGeneration()
        val currentSession = { kanxyHttpImageCache()?.takeIf { ownsImageCache() } }
        val session = currentSession()
        val cacheableAssetType = (session != null || report != null) && supportedAsset()
        val key = if (cacheableAssetType && session != null) {
            GameResourceCacheKey.from(url, requestHeaders, includeStaticRequestHeaders = true)
        } else null
        if (session == null || key == null) {
            val imageReport = report.takeIf { cacheableAssetType }
            if (session == null) imageReport?.invoke(KanxyImageCacheEvent.NO_ACTIVE_SESSION)
            else imageReport?.invoke(KanxyImageCacheEvent.REQUEST_BYPASS)
            return fetchFreshResponse(url, requestHeaders, route, imageReport)
        }

        val diskGeneration = kanxyDiskCache?.generation()
        val sessionIsCurrent = {
            resourceRouteGeneration() == route && currentSession() === session &&
                kanxyDiskCache?.generation() == diskGeneration
        }

        val deadlineNanos = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(fetcher.budgetMillis(url).coerceAtLeast(1))
        // Serialize same-key reads and reloads so a late older miss cannot refill a cleared entry.
        val lock = locks[(key.hashCode() and Int.MAX_VALUE) % locks.size]
        if (!acquireWithinDeadline(lock, deadlineNanos)) {
            report?.invoke(KanxyImageCacheEvent.LOCK_TIMEOUT)
            return null
        }
        try {
            if (!sessionIsCurrent()) {
                report?.invoke(KanxyImageCacheEvent.SESSION_CHANGED)
                return null
            }
            return fetchFreshAsset(url, requestHeaders, session, key, deadlineNanos, diskGeneration, sessionIsCurrent, report)
        } finally {
            lock.unlock()
        }
    }

    private fun fetchFreshAsset(
        url: String,
        requestHeaders: Map<String, String>,
        session: KanxyHttpImageCache,
        key: GameResourceCacheKey,
        deadlineNanos: Long,
        diskGeneration: Long?,
        sessionIsCurrent: () -> Boolean,
        report: ((KanxyImageCacheEvent) -> Unit)?,
    ): GameResourceResponse? {
        val disk = kanxyDiskCache
        val diskEntry = if (disk != null && diskGeneration != null) {
            disk.entry(session.proxy, key, url, requestHeaders, diskGeneration)
        } else null
        val useAssetCache = (disk == null || diskEntry != null) && requestHeaders.keys.none { name ->
            UNCACHED_IMAGE_REQUEST_HEADERS.any { it.equals(name, true) } ||
                (name.startsWith("X-", true) && !name.equals("X-Requested-With", true))
        }
        if (useAssetCache) {
            val cached = if (diskEntry != null) {
                diskEntry.read(clock()).also {
                    if (it == null) report?.invoke(KanxyImageCacheEvent.DISK_MISS)
                }
            } else session.read(key, report)?.let {
                it.toResponse(url, it.webViewHeaders(), source = GameResourceResponseSource.CACHE)
            }
            if (cached != null) {
                if (!sessionIsCurrent()) {
                    cached.discard()
                    report?.invoke(KanxyImageCacheEvent.SESSION_CHANGED)
                    return null
                }
                report?.invoke(if (diskEntry != null) KanxyImageCacheEvent.DISK_HIT else KanxyImageCacheEvent.HIT)
                return cached
            }
        } else {
            if (diskEntry != null) diskEntry.remove() else session.remove(key)
            report?.invoke(KanxyImageCacheEvent.REQUEST_BYPASS)
        }

        if (!sessionIsCurrent()) {
            report?.invoke(KanxyImageCacheEvent.SESSION_CHANGED)
            return null
        }
        val requestAt = session.requestTime()
        val fetched = runCatching {
            fetcher.fetchViaHttpProxy(url, requestHeaders, session.proxy, deadlineNanos)
        }.getOrNull()?.validFreshResponse(requireUnambiguousLength = diskEntry != null)
        if (fetched == null) {
            report?.invoke(KanxyImageCacheEvent.WEBVIEW_FALLBACK)
            return null
        }
        val prepared = if (useAssetCache && sessionIsCurrent()) {
            session.prepare(fetched, url, requestAt, clock(), diskEntry?.maxAssetBytes, report)
        } else null
        if (prepared != null && sessionIsCurrent()) {
            if (diskEntry != null) {
                val stored = diskEntry.write(prepared)
                if (stored && !sessionIsCurrent()) diskEntry.remove()
                report?.invoke(if (stored) KanxyImageCacheEvent.DISK_STORED else KanxyImageCacheEvent.DISK_WRITE_FAILED)
            } else {
                session.admit(key, prepared, report)
            }
        }
        if (!sessionIsCurrent()) {
            fetched.file?.delete()
            report?.invoke(KanxyImageCacheEvent.SESSION_CHANGED)
            return null
        }
        // Disk snapshots keep the download openable for WebView. The RAM path already copied it.
        if (prepared != null && diskEntry == null) fetched.file?.delete()
        val response = prepared?.response ?: fetched
        return response.toResponse(url, response.webViewHeaders())
    }

    private fun fetchFreshResponse(
        url: String,
        headers: Map<String, String>,
        route: Long,
        report: ((KanxyImageCacheEvent) -> Unit)?,
    ): GameResourceResponse? {
        val fetched = runCatching { fetcher.fetch(url, headers, null) }.getOrNull()?.validFreshResponse()
        if (fetched == null) {
            report?.invoke(KanxyImageCacheEvent.WEBVIEW_FALLBACK)
            return null
        }
        if (resourceRouteGeneration() != route) {
            fetched.file?.delete()
            report?.invoke(KanxyImageCacheEvent.SESSION_CHANGED)
            return null
        }
        return fetched.toResponse(url, fetched.webViewHeaders())
    }

    private fun GameResourceFetchResult.validFreshResponse(
        requireUnambiguousLength: Boolean = false,
    ): GameResourceFetchResult? {
        val contentLength = headers.value("Content-Length")
        val length = if (requireUnambiguousLength) {
            contentLength?.trim()
                ?.takeIf { value -> value.all { it in '0'..'9' } }?.toLongOrNull()
        } else contentLength?.toLongOrNull()
        val ambiguousLength = requireUnambiguousLength && contentLength != null &&
            (length == null || headers.keys.count { it.equals("Content-Length", true) } != 1)
        if (statusCode != HttpURLConnection.HTTP_OK ||
            headers.value("Set-Cookie") != null || headers.value("Set-Cookie2") != null ||
            bodyLength > HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES ||
            ambiguousLength || (length != null && length != bodyLength)
        ) {
            file?.delete()
            return null
        }
        return this
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
        val route = resourceRouteGeneration()
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
            if (resourceRouteGeneration() != route || !modeProvider().readsCache) return null
            val storeGeneration = store.generation()
            val cached = store.readFile(key)
            if (resourceRouteGeneration() != route || !modeProvider().readsCache) return null
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
            if (resourceRouteGeneration() != route || !modeProvider().readsCache) {
                fetched?.file?.delete()
                return null
            }
            fetched
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
            if (matchesManifest && cacheableResponse && modeProvider().writesCache && shouldStore() &&
                resourceRouteGeneration() == route
            ) {
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
            if (resourceRouteGeneration() != route || !modeProvider().readsCache) return null
            retainFetchedFile = fetched.file != null
            return fetched.toResponse(url, mimeType = mimeType)
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

    fun closeMaintenance() {
        store.closeMaintenance()
        kanxyDiskCache?.closeMaintenance()
    }

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

    private fun GameResourceFetchResult.toResponse(
        url: String,
        responseHeaders: Map<String, String> = headers,
        mimeType: String? = null,
        source: GameResourceResponseSource = GameResourceResponseSource.NETWORK,
    ): GameResourceResponse {
        val fallback = GameResourceCacheRules.mimeTypeFor(url)
        val mime = mimeType ?: headers.value("Content-Type")?.substringBefore(';')?.trim()
            ?.takeIf { it.isNotEmpty() } ?: fallback.mime
        return GameResourceResponse(
            bodyBytes = bytes,
            mimeType = mime,
            encoding = fallback.encoding,
            statusCode = statusCode,
            reasonPhrase = reasonPhrase,
            headers = responseHeaders,
            source = source,
            file = file,
            deleteFileOnClose = file != null,
        )
    }

    private fun GameResourceFetchResult.webViewHeaders(): Map<String, String> =
        headers.filterKeys { !it.equals("Cache-Control", ignoreCase = true) } + ("Cache-Control" to "no-store")

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
        private val FRESH_BYPASS_HEADERS = BYPASS_REQUEST_HEADERS - setOf("If-None-Match", "If-Modified-Since")
        private val UNCACHED_IMAGE_REQUEST_HEADERS = setOf("Cache-Control", "Pragma", "If-None-Match", "If-Modified-Since")
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
