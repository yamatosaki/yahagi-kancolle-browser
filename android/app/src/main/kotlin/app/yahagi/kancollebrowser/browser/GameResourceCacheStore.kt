package app.yahagi.kancollebrowser.browser

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.UUID
import java.nio.file.attribute.BasicFileAttributes
import java.nio.file.attribute.FileTime
import java.nio.file.DirectoryStream
import java.nio.file.Path

data class GameResourceCachedValue(
    val bytes: ByteArray,
    val entry: GameResourceCacheEntry,
)

class GameResourceCachedFile internal constructor(
    val file: File,
    val entry: GameResourceCacheEntry,
    internal val generation: Long = -1,
    internal val identity: GameResourceFileIdentity? = null,
)

internal data class GameResourceFileIdentity(
    val fileKey: String?, val size: Long, val modified: FileTime, val created: FileTime,
)

enum class GameResourceStoredState { MISSING, VALID, DAMAGED }

data class GameResourceStoredInspection(
    val state: GameResourceStoredState,
    val entry: GameResourceCacheEntry? = null,
)

data class GameResourceCachePolicy(
    val maxBytes: Long,
    val maxIdleAgeMs: Long? = null,
) {
    init {
        require(maxBytes >= 0L) { "Cache capacity must not be negative" }
        require(maxIdleAgeMs == null || maxIdleAgeMs > 0L) {
            "Cache idle age must be positive"
        }
    }
}

class GameResourceCacheStore(
    private val root: File,
    private val index: GameResourceCacheIndex,
    maxBytes: Long = DEFAULT_MAX_BYTES,
    private val clock: () -> Long = System::currentTimeMillis,
    private val policyProvider: () -> GameResourceCachePolicy = {
        GameResourceCachePolicy(maxBytes = maxBytes)
    },
    private val fileChecksum: ((File) -> String)? = null,
    private val maintenanceNowNanos: () -> Long = System::nanoTime,
    // NIO backports below API 26 expose path-based keys instead of file identity.
    private val reliableFileIdentity: Boolean = true,
) {
    private val filesDirectory = root.resolve("files")
    private val temporaryDirectory = root.resolve("tmp")
    private var generation = 0L
    private var commitsSincePolicySweep = 0
    private var orphanCleanupPending = true
    private var orphanCleanupPhase = 0
    private var orphanDirectory: DirectoryStream<Path>? = null
    private var orphanIterator: Iterator<Path>? = null
    private val activeTemporaryFiles = hashSetOf<String>()
    val maxBytes: Long
        get() = policyProvider().maxBytes

    @Synchronized
    fun generation(): Long = generation

    init {
        filesDirectory.mkdirs()
        temporaryDirectory.mkdirs()
        // Scanning leftovers belongs to the first background migration/maintenance,
        // not to native construction before Flutter's first frame.
    }

    @Synchronized
    fun read(key: GameResourceCacheKey): GameResourceCachedValue? {
        val now = clock()
        val entry = liveEntry(key, now) ?: return null
        val file = safeFile(entry.fileName) ?: return invalidate(key)
        if (!file.isFile || file.length() != entry.byteLength) return invalidate(key)
        if (entry.byteLength > HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES) return invalidate(key)
        val bytes = runCatching { file.readBytes() }.getOrNull() ?: return invalidate(key)
        if (sha256(bytes) != entry.sha256) return invalidate(key)
        val touched = if (now - entry.lastAccessedAt >= ACCESS_TIME_WRITE_INTERVAL_MS) {
            entry.copy(lastAccessedAt = now).also(index::put)
        } else {
            entry
        }
        return GameResourceCachedValue(bytes, touched)
    }

    fun readFile(key: GameResourceCacheKey): GameResourceCachedFile? {
        // Hashing a cached file must not block unrelated WebView resource reads.
        repeat(2) {
            val (snapshotGeneration, snapshot) = synchronized(this) {
                generation to (liveEntry(key, clock()) ?: return null)
            }
            val file = safeFile(snapshot.fileName)
            val identity = file?.let(::fileIdentity)
            val valid = identity != null && identity.size == snapshot.byteLength &&
                snapshot.byteLength <= HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES &&
                runCatching { sha256(checkNotNull(file)) }.getOrNull() == snapshot.sha256 &&
                fileIdentity(checkNotNull(file)) == identity
            synchronized(this) {
                if (generation != snapshotGeneration) return null
                val current = liveEntry(key, clock()) ?: return null
                if (current.fileName != snapshot.fileName || current.sha256 != snapshot.sha256 ||
                    current.byteLength != snapshot.byteLength) return@synchronized
                if (!valid) return invalidateFile(key)
                val now = clock()
                val touched = if (now - current.lastAccessedAt >= ACCESS_TIME_WRITE_INTERVAL_MS) {
                    current.copy(lastAccessedAt = now).also(index::put)
                } else current
                return GameResourceCachedFile(checkNotNull(file), touched, snapshotGeneration, identity)
            }
        }
        return null
    }

    /** Reuse verification only within this fetch, for exactly the unchanged file. */
    @Synchronized
    fun markVerifiedValidated(
        key: GameResourceCacheKey,
        verified: GameResourceCachedFile,
        responseHeaders: Map<String, String>,
        expectedGeneration: Long,
    ): GameResourceCachedFile? {
        if (generation != expectedGeneration || verified.generation != generation) return null
        val current = liveEntry(key, clock()) ?: return null
        if (current.fileName != verified.entry.fileName || current.sha256 != verified.entry.sha256 ||
            current.byteLength != verified.entry.byteLength) return null
        val identity = fileIdentity(verified.file)
        if (identity == null) return invalidateFile(key)
        // A weak or absent file key cannot prove this is the verified file.
        // Rehash it even when the size and timestamps are unchanged.
        val unchangedReliableIdentity = reliableFileIdentity && identity.fileKey != null &&
            verified.identity != null && identity == verified.identity
        val valid = if (unchangedReliableIdentity) true else {
            runCatching { sha256(verified.file) }.getOrNull() == current.sha256 &&
                fileIdentity(verified.file) == identity
        }
        if (!valid) return invalidateFile(key)
        if (!markValidated(key, responseHeaders, expectedGeneration)) return null
        return GameResourceCachedFile(verified.file, checkNotNull(index.get(key)), generation, identity)
    }

    private fun fileIdentity(file: File): GameResourceFileIdentity? = runCatching {
        val attrs = Files.readAttributes(file.toPath(), BasicFileAttributes::class.java)
        if (!attrs.isRegularFile) null else GameResourceFileIdentity(
            attrs.fileKey()?.toString(), attrs.size(), attrs.lastModifiedTime(), attrs.creationTime(),
        )
    }.getOrNull()

    private fun invalidateFile(key: GameResourceCacheKey): GameResourceCachedFile? {
        remove(key)
        return null
    }

    @Synchronized
    fun contains(key: GameResourceCacheKey): Boolean {
        val entry = liveEntry(key, clock()) ?: return false
        val file = safeFile(entry.fileName) ?: return false
        return file.isFile && file.length() == entry.byteLength
    }

    fun commit(
        key: GameResourceCacheKey,
        bytes: ByteArray,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
        responseHeaders: Map<String, String> = emptyMap(),
    ): GameResourceCacheEntry = checkNotNull(
        commitWithEviction(key, bytes, version, mimeType, etag, lastModified, responseHeaders),
    ) { "Resource does not fit within the cache capacity" }

    fun commitWithEviction(
        key: GameResourceCacheKey,
        bytes: ByteArray,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
        responseHeaders: Map<String, String> = emptyMap(),
        expectedGeneration: Long? = null,
    ): GameResourceCacheEntry? = commitInternal(
        key, bytes.size.toLong(), { it.writeBytes(bytes) }, version,
        mimeType, etag, lastModified, responseHeaders, expectedGeneration,
    )

    fun commitFileWithEviction(
        key: GameResourceCacheKey,
        source: File,
        version: String? = null,
        mimeType: String,
        etag: String? = null,
        lastModified: String? = null,
        responseHeaders: Map<String, String> = emptyMap(),
        expectedGeneration: Long? = null,
    ): GameResourceCacheEntry? = commitInternal(
        key, source.length(), { source.copyTo(it, overwrite = true) },
        version, mimeType, etag, lastModified, responseHeaders, expectedGeneration,
    )

    private fun commitInternal(
        key: GameResourceCacheKey,
        bodyLength: Long,
        writeTemporary: (File) -> Unit,
        version: String?,
        mimeType: String,
        etag: String?,
        lastModified: String?,
        responseHeaders: Map<String, String>,
        expectedGeneration: Long?,
    ): GameResourceCacheEntry? {
        if (bodyLength > HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES) return null
        // Prepare the downloaded file outside the index lock so cache hits can proceed.
        val temporary = temporaryDirectory.resolve("${UUID.randomUUID()}.part")
        val preparationGeneration = synchronized(this) {
            activeTemporaryFiles += temporary.name
            generation
        }
        try {
            writeTemporary(temporary)
            if (temporary.length() != bodyLength) return null
            // Verify the exact copy being committed, rather than a caller-owned
            // source that may change between checksum and copy.
            val checksum = sha256(temporary)
            val fileName = "$checksum.cache"
            val destination = filesDirectory.resolve(fileName)
            return synchronized(this) {
                // Clear may have run while the temporary file was being written.
                if ((expectedGeneration ?: preparationGeneration) != generation) {
                    return@synchronized null
                }
                val policy = policyProvider()
                if (policy.maxIdleAgeMs != null && ++commitsSincePolicySweep >= 256) {
                    enforcePolicy(maxDurationMs = 250)
                    commitsSincePolicySweep = 0
                }
                val capacity = maxBytes
                if (bodyLength > capacity) return@synchronized null
                val previous = index.get(key)
                evictForReplacement(key, bodyLength, previous?.byteLength ?: 0L, capacity)
                if (projectedBytes(previous?.byteLength ?: 0L, bodyLength) > capacity) {
                    return@synchronized null
                }
                val entry = GameResourceCacheEntry(
                    key = key.value,
                    fileName = fileName,
                    version = version,
                    mimeType = mimeType,
                    byteLength = bodyLength,
                    etag = etag,
                    lastModified = lastModified,
                    lastAccessedAt = clock(),
                    lastValidatedAt = clock(),
                    sha256 = checksum,
                    responseHeaders = responseHeaders,
                )
                while (!index.canPut(entry)) {
                    val oldest = index.oldestEntry()?.takeIf { it.key != key.value }
                        ?: return@synchronized null
                    remove(GameResourceCacheKey(oldest.key))
                }
                if (!destination.isFile || destination.length() != bodyLength ||
                    runCatching { sha256(destination) }.getOrNull() != checksum
                ) atomicReplace(temporary, destination)
                try {
                    index.put(entry)
                } catch (error: Exception) {
                    scheduleOrphanCleanup()
                    runCatching {
                        if (!index.isFileReferenced(fileName) && destination.exists() &&
                            !destination.delete()) {
                            throw IllegalStateException("Cannot remove unindexed resource cache file")
                        }
                    }
                    throw error
                }
                if (previous != null && previous.fileName != fileName) {
                    deleteIfUnreferenced(previous.fileName)
                }
                entry
            }
        } finally {
            synchronized(this) { activeTemporaryFiles -= temporary.name }
            if (temporary.exists() && !temporary.delete()) {
                synchronized(this) { scheduleOrphanCleanup() }
            }
        }
    }

    private fun evictForReplacement(
        currentKey: GameResourceCacheKey,
        newBytes: Long,
        replacedBytes: Long,
        capacity: Long,
    ) {
        if (projectedBytes(replacedBytes, newBytes) <= capacity) return
        index.snapshot()
            .asSequence()
            .filterNot { it.key == currentKey.value }
            .sortedBy { it.lastAccessedAt }
            .forEach { entry ->
                if (projectedBytes(replacedBytes, newBytes) <= capacity) return@forEach
                remove(GameResourceCacheKey(entry.key))
            }
    }

    private fun projectedBytes(replacedBytes: Long, newBytes: Long): Long =
        totalBytes() - replacedBytes + newBytes

    @Synchronized
    fun totalBytes(): Long = index.totalBytes()

    @Synchronized
    fun wouldExceedCapacity(requiredBytes: Long): Boolean =
        requiredBytes > maxBytes || totalBytes() > maxBytes - requiredBytes

    @Synchronized
    fun enforcePolicy(maxDurationMs: Long = Long.MAX_VALUE) {
        val started = maintenanceNowNanos()
        fun budgetAvailable(): Boolean = maxDurationMs == Long.MAX_VALUE ||
            java.util.concurrent.TimeUnit.NANOSECONDS.toMillis(maintenanceNowNanos() - started) < maxDurationMs
        if (!budgetAvailable()) return
        if (orphanCleanupPending && !reconcileOrphanFiles(::budgetAvailable)) return
        val policy = policyProvider()
        val now = clock()
        if (policy.maxIdleAgeMs != null) {
            for (entry in index.snapshot()) {
                if (!budgetAvailable()) return
                if (isExpired(entry, now, policy)) remove(GameResourceCacheKey(entry.key))
            }
        }
        var usedBytes = totalBytes()
        if (usedBytes <= policy.maxBytes) return
        for (entry in index.snapshot().sortedBy { it.lastAccessedAt }) {
            if (!budgetAvailable()) return
            if (usedBytes <= policy.maxBytes) break
            if (remove(GameResourceCacheKey(entry.key))) {
                usedBytes -= entry.byteLength
            }
        }
    }

    @Synchronized
    fun evictToFit(
        requiredBytes: Long,
        protectedKeys: Set<GameResourceCacheKey> = emptySet(),
    ): List<GameResourceCacheKey> {
        if (!wouldExceedCapacity(requiredBytes)) return emptyList()
        val protectedValues = protectedKeys.mapTo(hashSetOf()) { it.value }
        val removed = mutableListOf<GameResourceCacheKey>()
        index.snapshot()
            .asSequence()
            .filterNot { it.key in protectedValues }
            .sortedBy { it.lastAccessedAt }
            .forEach { entry ->
                if (!wouldExceedCapacity(requiredBytes)) return@forEach
                val key = GameResourceCacheKey(entry.key)
                remove(key)
                removed += key
            }
        return removed
    }

    @Synchronized
    fun remove(key: GameResourceCacheKey): Boolean {
        val entry = index.get(key) ?: return false
        if (index.fileReferenceCount(entry.fileName) == 1) {
            val file = safeFile(entry.fileName)
                ?: throw IllegalStateException("Unsafe resource cache file name")
            if (file.exists() && !file.delete()) {
                throw IllegalStateException("Cannot remove resource cache file")
            }
        }
        index.remove(key) ?: return false
        return true
    }

    @Synchronized
    fun removeIfGeneration(key: GameResourceCacheKey, expectedGeneration: Long): Boolean =
        generation == expectedGeneration && remove(key)

    @Synchronized
    fun removeLegacyHostlessEntries() {
        val removed = index.removePrefix("/")
        if (removed.isNotEmpty()) {
            generation++
            scheduleOrphanCleanup()
        }
        // The index migration is required for safe reads. Physical leftovers
        // are reconciled by budgeted maintenance, away from the first request.
    }

    private fun reconcileOrphanFiles(budgetAvailable: () -> Boolean): Boolean {
        try {
            while (budgetAvailable()) {
                if (orphanIterator == null) {
                    val directory = if (orphanCleanupPhase == 0) filesDirectory else temporaryDirectory
                    orphanDirectory = Files.newDirectoryStream(directory.toPath())
                    orphanIterator = orphanDirectory!!.iterator()
                }
                val files = orphanIterator!!
                if (!files.hasNext()) {
                    closeOrphanDirectory()
                    if (++orphanCleanupPhase == 2) {
                        orphanCleanupPhase = 0
                        orphanCleanupPending = false
                        return true
                    }
                    continue
                }
                val path = files.next()
                val fileName = path.fileName.toString()
                val retained = if (orphanCleanupPhase == 0) index.isFileReferenced(fileName)
                    else fileName in activeTemporaryFiles
                if (!retained && !Files.deleteIfExists(path)) {
                    throw IllegalStateException("Cannot remove an orphaned resource cache file")
                }
            }
            return false
        } catch (error: Exception) {
            scheduleOrphanCleanup()
            throw error
        }
    }

    private fun closeOrphanDirectory() {
        runCatching { orphanDirectory?.close() }
        orphanDirectory = null
        orphanIterator = null
    }

    private fun scheduleOrphanCleanup() {
        closeOrphanDirectory()
        orphanCleanupPhase = 0
        orphanCleanupPending = true
    }

    @Synchronized
    fun closeMaintenance() {
        scheduleOrphanCleanup()
    }

    @Synchronized
    fun clear() {
        generation++
        index.clear()
        closeOrphanDirectory()
        orphanCleanupPhase = 0
        try {
            deleteAllChildren(filesDirectory)
            deleteAllChildren(temporaryDirectory)
            orphanCleanupPending = false
        } catch (error: Exception) {
            scheduleOrphanCleanup()
            throw error
        }
    }

    private fun deleteAllChildren(directory: File) {
        Files.newDirectoryStream(directory.toPath()).use { children ->
            children.forEach { child ->
                if (!Files.deleteIfExists(child)) {
                    throw IllegalStateException("Cannot clear resource cache file")
                }
            }
        }
    }

    fun entries(): List<GameResourceCacheEntry> = index.snapshot()

    @Synchronized
    fun inspect(key: GameResourceCacheKey): GameResourceStoredInspection {
        val metadata = inspectMetadata(key)
        val entry = metadata.entry ?: return metadata
        val file = safeFile(entry.fileName)
            ?: return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        val checksum = runCatching { sha256(file) }.getOrNull()
        if (checksum == null || checksum != entry.sha256) {
            return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        }
        return metadata
    }

    @Synchronized
    fun inspectMetadata(key: GameResourceCacheKey): GameResourceStoredInspection {
        val entry = liveEntry(key, clock())
            ?: return GameResourceStoredInspection(GameResourceStoredState.MISSING)
        val file = safeFile(entry.fileName)
        if (file == null || !file.isFile || file.length() != entry.byteLength) {
            return GameResourceStoredInspection(GameResourceStoredState.DAMAGED)
        }
        return GameResourceStoredInspection(GameResourceStoredState.VALID, entry)
    }

    @Synchronized
    fun markValidated(
        key: GameResourceCacheKey,
        responseHeaders: Map<String, String> = emptyMap(),
        expectedGeneration: Long? = null,
    ): Boolean {
        if (expectedGeneration != null && expectedGeneration != generation) return false
        val entry = index.get(key) ?: return false
        val merged = entry.responseHeaders.toMutableMap()
        GameResourceCacheRules.persistedResponseHeaders(responseHeaders).forEach { (name, value) ->
            merged.keys.filter { it.equals(name, ignoreCase = true) }.forEach(merged::remove)
            merged[name] = value
        }
        fun updated(name: String): String? = responseHeaders.entries
            .firstOrNull { it.key.equals(name, ignoreCase = true) }?.value
        index.put(entry.copy(
            lastValidatedAt = clock(),
            etag = updated("ETag") ?: entry.etag,
            lastModified = updated("Last-Modified") ?: entry.lastModified,
            responseHeaders = merged,
        ))
        return true
    }

    fun availableDeviceBytes(): Long = root.usableSpace

    private fun invalidate(key: GameResourceCacheKey): GameResourceCachedValue? {
        remove(key)
        return null
    }

    private fun liveEntry(key: GameResourceCacheKey, now: Long): GameResourceCacheEntry? {
        val entry = index.get(key) ?: return null
        if (!isExpired(entry, now, policyProvider())) return entry
        remove(key)
        return null
    }

    private fun isExpired(
        entry: GameResourceCacheEntry,
        now: Long,
        policy: GameResourceCachePolicy,
    ): Boolean = policy.maxIdleAgeMs?.let { now - entry.lastAccessedAt >= it } == true

    private fun deleteIfUnreferenced(fileName: String) {
        if (index.isFileReferenced(fileName)) return
        val file = safeFile(fileName) ?: throw IllegalStateException("Unsafe resource cache file name")
        if (file.exists() && !file.delete()) {
            scheduleOrphanCleanup()
            throw IllegalStateException("Cannot remove resource cache file")
        }
    }

    private fun safeFile(fileName: String): File? {
        if (fileName.contains('/') || fileName.contains('\\')) return null
        val file = filesDirectory.resolve(fileName)
        return file.takeIf { it.parentFile == filesDirectory }
    }

    private fun atomicReplace(source: File, target: File) {
        try {
            Files.move(
                source.toPath(),
                target.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (_: Exception) {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    private fun sha256(file: File): String {
        fileChecksum?.let { return it(file) }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    companion object {
        const val DEFAULT_MAX_BYTES: Long = 50_000_000_000L
        const val TEMPORARY_MAX_BYTES: Long = 2_000_000_000L
        const val TEMPORARY_MAX_IDLE_AGE_MS: Long = 7L * 24L * 60L * 60L * 1000L
        private const val ACCESS_TIME_WRITE_INTERVAL_MS = 60_000L
    }
}
