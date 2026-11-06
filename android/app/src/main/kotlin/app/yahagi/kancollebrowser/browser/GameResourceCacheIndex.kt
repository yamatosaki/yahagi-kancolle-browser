package app.yahagi.kancollebrowser.browser

import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.StandardCopyOption

data class GameResourceCacheEntry(
    val key: String,
    val fileName: String,
    val version: String?,
    val mimeType: String,
    val byteLength: Long,
    val etag: String?,
    val lastModified: String?,
    val lastAccessedAt: Long,
    val lastValidatedAt: Long,
    val sha256: String,
    val responseHeaders: Map<String, String> = emptyMap(),
)

class GameResourceCacheIndex(
    private val indexFile: File,
    private val maxMetadataBytes: Long = MAX_METADATA_BYTES,
) {
    private val entries = linkedMapOf<String, GameResourceCacheEntry>()
    private val fileReferenceCounts = hashMapOf<String, Int>()
    private var cachedTotalBytes = 0L
    private var cachedMetadataBytes = 0L
    private val journalFile = File(indexFile.parentFile, "${indexFile.name}.journal")
    private val resetMarkerFile = File(indexFile.parentFile, "${indexFile.name}.reset")
    private var loaded = false

    init {
        require(maxMetadataBytes > 0L) { "Resource cache index metadata limit must be positive" }
    }

    @Synchronized
    fun get(key: GameResourceCacheKey): GameResourceCacheEntry? {
        ensureLoaded()
        return entries[key.value]
    }

    @Synchronized
    fun snapshot(): List<GameResourceCacheEntry> {
        ensureLoaded()
        return entries.values.toList()
    }

    @Synchronized
    fun entryCount(): Int {
        ensureLoaded()
        return entries.size
    }

    @Synchronized
    fun isFull(): Boolean {
        ensureLoaded()
        return entries.size >= MAX_ENTRIES || cachedMetadataBytes >= maxMetadataBytes
    }

    @Synchronized
    fun canPut(entry: GameResourceCacheEntry): Boolean {
        ensureLoaded()
        val compacted = entry.compactHeaders()
        val recordBytes = validateEntry(compacted)
        val replacedBytes = entries[compacted.key]?.let(::recordBytes) ?: 0
        return (compacted.key in entries || entries.size < MAX_ENTRIES) &&
            cachedMetadataBytes - replacedBytes + recordBytes <= maxMetadataBytes
    }

    @Synchronized
    fun oldestEntry(): GameResourceCacheEntry? {
        ensureLoaded()
        return entries.values.minByOrNull { it.lastAccessedAt }
    }

    @Synchronized
    fun totalBytes(): Long {
        ensureLoaded()
        return cachedTotalBytes
    }

    @Synchronized
    fun put(entry: GameResourceCacheEntry) {
        ensureLoaded()
        val compacted = entry.compactHeaders()
        val recordBytes = validateEntry(compacted)
        check(compacted.key in entries || entries.size < MAX_ENTRIES) { "Resource cache index is full" }
        val replacedBytes = entries[compacted.key]?.let(::recordBytes) ?: 0
        require(cachedMetadataBytes - replacedBytes + recordBytes <= maxMetadataBytes) {
            "Resource cache index metadata limit reached"
        }
        appendJournalRecord(JSONObject().put("op", "put").put("entry", compacted.toJson()))
        entries[compacted.key]?.let {
            decrementFileReference(it.fileName)
            cachedTotalBytes -= it.byteLength
        }
        entries[compacted.key] = compacted
        cachedMetadataBytes += recordBytes - replacedBytes
        incrementFileReference(compacted.fileName)
        cachedTotalBytes += compacted.byteLength
        compactJournalIfNeeded()
    }

    @Synchronized
    fun remove(key: GameResourceCacheKey): GameResourceCacheEntry? {
        ensureLoaded()
        val removed = entries[key.value] ?: return null
        appendJournalRecord(JSONObject().put("op", "remove").put("key", key.value))
        entries.remove(key.value)
        cachedMetadataBytes -= recordBytes(removed)
        decrementFileReference(removed.fileName)
        cachedTotalBytes -= removed.byteLength
        compactJournalIfNeeded()
        return removed
    }

    @Synchronized
    fun isFileReferenced(fileName: String): Boolean {
        ensureLoaded()
        return (fileReferenceCounts[fileName] ?: 0) > 0
    }

    @Synchronized
    fun fileReferenceCount(fileName: String): Int {
        ensureLoaded()
        return fileReferenceCounts[fileName] ?: 0
    }

    @Synchronized
    fun removePrefix(prefix: String): List<GameResourceCacheEntry> {
        ensureLoaded()
        val removed = entries.values.filter { it.key.startsWith(prefix) }
        if (removed.isEmpty()) return emptyList()
        appendJournalRecord(JSONObject().put("op", "removePrefix").put("prefix", prefix))
        removed.forEach {
            entries.remove(it.key)
            cachedMetadataBytes -= recordBytes(it)
            decrementFileReference(it.fileName)
            cachedTotalBytes -= it.byteLength
        }
        compactJournalIfNeeded()
        return removed
    }

    @Synchronized
    fun clear() {
        ensureLoaded()
        appendJournalRecord(JSONObject().put("op", "clear"))
        entries.clear()
        cachedMetadataBytes = 0L
        fileReferenceCounts.clear()
        cachedTotalBytes = 0L
        compactJournalIfNeeded()
    }

    private fun ensureLoaded() {
        if (loaded) return
        try {
            resetOversizedLegacySnapshot()
            if (indexFile.isFile) {
                runCatching {
                    loadSnapshot()
                }.onFailure {
                    entries.clear()
                    cachedMetadataBytes = 0L
                }
            }
            if (journalFile.isFile) replayJournal()
            rebuildFileReferences()
            loaded = true
        } catch (error: Exception) {
            loaded = false
            entries.clear()
            fileReferenceCounts.clear()
            cachedTotalBytes = 0L
            cachedMetadataBytes = 0L
            throw error
        }
    }

    private fun replayJournal() {
        var validBytes = 0L
        BufferedInputStream(FileInputStream(journalFile)).use { input ->
            while (true) {
                val line = readBoundedLine(input) ?: break
                if (line.text == null) {
                    validBytes += line.byteCount
                    continue
                }
                val applied = runCatching {
                    val operation = JSONObject(line.text)
                    when (operation.getString("op")) {
                        "put" -> addLoadedEntry(operation.getJSONObject("entry").toEntry())
                        "remove" -> removeLoadedEntry(operation.getString("key"))
                        "removePrefix" -> {
                            val prefix = operation.getString("prefix")
                            entries.keys.filter { it.startsWith(prefix) }.forEach(::removeLoadedEntry)
                        }
                        "clear" -> {
                            entries.clear()
                            cachedMetadataBytes = 0L
                        }
                        else -> error("Unknown resource cache journal operation")
                    }
                }.isSuccess
                if (!applied) break
                validBytes += line.byteCount
            }
        }
        if (validBytes != journalFile.length()) {
            RandomAccessFile(journalFile, "rw").use { it.setLength(validBytes) }
        }
    }

    private fun loadSnapshot() {
        if (isVersion2Snapshot()) {
            BufferedInputStream(FileInputStream(indexFile)).use { input ->
                readBoundedLine(input) // version header
                while (true) {
                    val line = readBoundedLine(input) ?: break
                    if (line.text != null) runCatching {
                        addLoadedEntry(JSONObject(line.text).toEntry())
                    }
                }
            }
            return
        }
        loadLegacySnapshot()
    }

    private fun resetOversizedLegacySnapshot() {
        if (!resetMarkerFile.isFile &&
            (!indexFile.isFile || indexFile.length() <= MAX_LEGACY_SNAPSHOT_BYTES || isVersion2Snapshot())
        ) return
        // A large beta.2/beta.4 JSON snapshot can require a huge StringBuilder
        // allocation. Drop only this regenerable resource cache before loading it.
        if (!resetMarkerFile.isFile && !resetMarkerFile.createNewFile()) {
            throw IllegalStateException("Cannot mark resource cache index reset")
        }
        if (journalFile.exists() && !journalFile.delete()) {
            throw IllegalStateException("Cannot reset resource cache journal")
        }
        if (indexFile.exists() && !indexFile.delete()) {
            throw IllegalStateException("Cannot reset resource cache snapshot")
        }
        if (!resetMarkerFile.delete()) {
            throw IllegalStateException("Cannot complete resource cache index reset")
        }
    }

    private fun isVersion2Snapshot(): Boolean {
        val prefix = ByteArray(SNAPSHOT_HEADER.length)
        val count = FileInputStream(indexFile).use { input ->
            var read = 0
            while (read < prefix.size) {
                val amount = input.read(prefix, read, prefix.size - read)
                if (amount < 0) break
                read += amount
            }
            read
        }
        return count == prefix.size && String(prefix, Charsets.UTF_8) == SNAPSHOT_HEADER
    }

    private fun loadLegacySnapshot() {
        BufferedInputStream(FileInputStream(indexFile)).use { input ->
            // Version 1 has one top-level entries array. Parse each object separately.
            while (true) {
                val byte = input.read()
                if (byte < 0) return
                if (byte == '['.code) break
            }
            while (true) {
                var byte = input.read()
                while (byte == ','.code || byte == ' '.code || byte == '\n'.code ||
                    byte == '\r'.code || byte == '\t'.code) byte = input.read()
                if (byte == ']'.code || byte < 0) return
                if (byte != '{'.code) return
                val output = ByteArrayOutputStream()
                output.write(byte)
                var depth = 1
                var quoted = false
                var escaped = false
                var oversized = false
                while (depth > 0) {
                    byte = input.read()
                    if (byte < 0) return
                    if (!oversized) {
                        if (output.size() < MAX_RECORD_BYTES) output.write(byte)
                        else oversized = true
                    }
                    if (quoted) {
                        when {
                            escaped -> escaped = false
                            byte == '\\'.code -> escaped = true
                            byte == '"'.code -> quoted = false
                        }
                    } else {
                        when (byte) {
                            '"'.code -> quoted = true
                            '{'.code -> depth++
                            '}'.code -> depth--
                        }
                    }
                }
                if (!oversized) runCatching {
                    addLoadedEntry(JSONObject(String(output.toByteArray(), Charsets.UTF_8)).toEntry())
                }
            }
        }
    }

    private fun addLoadedEntry(entry: GameResourceCacheEntry) {
        val compacted = entry.compactHeaders()
        val newBytes = validateEntry(compacted)
        val replacedBytes = entries[compacted.key]?.let(::recordBytes) ?: 0
        while ((compacted.key !in entries && entries.size >= MAX_ENTRIES) ||
            cachedMetadataBytes - replacedBytes + newBytes > maxMetadataBytes
        ) {
            val oldest = entries.entries.firstOrNull { it.key != compacted.key } ?: return
            removeLoadedEntry(oldest.key)
        }
        entries[compacted.key] = compacted
        cachedMetadataBytes += newBytes - replacedBytes
    }

    private fun removeLoadedEntry(key: String) {
        val removed = entries.remove(key) ?: return
        cachedMetadataBytes -= recordBytes(removed)
    }

    private fun GameResourceCacheEntry.compactHeaders(): GameResourceCacheEntry =
        copy(responseHeaders = GameResourceCacheRules.persistedResponseHeaders(responseHeaders))

    private data class BoundedLine(val text: String?, val byteCount: Long)

    private fun readBoundedLine(input: BufferedInputStream): BoundedLine? {
        val output = ByteArrayOutputStream()
        var byteCount = 0L
        var oversized = false
        while (true) {
            val byte = input.read()
            if (byte < 0) return null
            byteCount++
            if (byte == '\n'.code) {
                return BoundedLine(
                    if (oversized) null else String(output.toByteArray(), Charsets.UTF_8),
                    byteCount,
                )
            }
            if (!oversized) {
                if (output.size() < MAX_LINE_BYTES) output.write(byte)
                else oversized = true
            }
        }
    }

    private fun validateEntry(entry: GameResourceCacheEntry): Int {
        require(entry.key.length <= 2_048 && entry.fileName.length <= 128 &&
            entry.version.orEmpty().length <= 1_024 && entry.mimeType.length <= 128 &&
            entry.etag.orEmpty().length <= 1_024 &&
            entry.lastModified.orEmpty().length <= 1_024 && entry.sha256.length <= 128 &&
            entry.responseHeaders.size <= 32 && entry.responseHeaders.all { (name, value) ->
                name.length <= 128 && value.length <= 1_024
            }
        ) { "Resource cache metadata is too large" }
        val bytes = recordBytes(entry)
        require(bytes <= MAX_RECORD_BYTES) {
            "Resource cache metadata record is too large"
        }
        return bytes
    }

    private fun recordBytes(entry: GameResourceCacheEntry): Int =
        entry.toJson().toString().toByteArray(Charsets.UTF_8).size

    private fun appendJournalRecord(operation: JSONObject) {
        try {
            journalFile.parentFile?.mkdirs()
            journalFile.appendText(operation.toString() + "\n")
        } catch (error: Exception) {
            // Reload on the next call so a partial tail is truncated before retry.
            loaded = false
            entries.clear()
            fileReferenceCounts.clear()
            cachedTotalBytes = 0L
            cachedMetadataBytes = 0L
            throw error
        }
    }

    private fun compactJournalIfNeeded() {
        if (journalFile.length() >= MAX_JOURNAL_BYTES) {
            save()
            if (!journalFile.delete()) {
                throw IllegalStateException("Cannot compact resource cache journal")
            }
        }
    }

    private fun incrementFileReference(fileName: String) {
        fileReferenceCounts[fileName] = (fileReferenceCounts[fileName] ?: 0) + 1
    }

    private fun decrementFileReference(fileName: String) {
        val count = fileReferenceCounts[fileName] ?: return
        if (count <= 1) fileReferenceCounts.remove(fileName)
        else fileReferenceCounts[fileName] = count - 1
    }

    private fun rebuildFileReferences() {
        fileReferenceCounts.clear()
        cachedTotalBytes = 0L
        entries.values.forEach {
            incrementFileReference(it.fileName)
            cachedTotalBytes += it.byteLength
        }
    }

    private fun save() {
        indexFile.parentFile?.mkdirs()
        val temporary = File(indexFile.parentFile, "${indexFile.name}.tmp")
        temporary.bufferedWriter(Charsets.UTF_8).use { writer ->
            writer.write(SNAPSHOT_HEADER)
            entries.values.forEach { entry ->
                writer.write(entry.toJson().toString())
                writer.write('\n'.code)
            }
        }
        atomicReplace(temporary, indexFile)
    }

    private fun JSONObject.nullableString(name: String): String? =
        if (isNull(name)) null else optString(name).takeIf { it.isNotEmpty() }

    private fun JSONObject.toEntry() = GameResourceCacheEntry(
        key = getString("key"),
        fileName = getString("fileName"),
        version = nullableString("version"),
        mimeType = getString("mimeType"),
        byteLength = getLong("byteLength"),
        etag = nullableString("etag"),
        lastModified = nullableString("lastModified"),
        lastAccessedAt = getLong("lastAccessedAt"),
        lastValidatedAt = optLong("lastValidatedAt", 0L),
        sha256 = getString("sha256"),
        responseHeaders = optJSONObject("responseHeaders")?.let { headers ->
            headers.keys().asSequence().associateWith(headers::getString)
        }.orEmpty(),
    )

    private fun GameResourceCacheEntry.toJson() = JSONObject()
        .put("key", key)
        .put("fileName", fileName)
        .put("version", version ?: JSONObject.NULL)
        .put("mimeType", mimeType)
        .put("byteLength", byteLength)
        .put("etag", etag ?: JSONObject.NULL)
        .put("lastModified", lastModified ?: JSONObject.NULL)
        .put("lastAccessedAt", lastAccessedAt)
        .put("lastValidatedAt", lastValidatedAt)
        .put("sha256", sha256)
        .put("responseHeaders", JSONObject(responseHeaders))

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

    companion object {
        internal const val MAX_ENTRIES = 70_000
        internal const val MAX_METADATA_BYTES = 40L * 1024L * 1024L
        private const val MAX_LEGACY_SNAPSHOT_BYTES = 8L * 1024L * 1024L
        private const val MAX_RECORD_BYTES = 8 * 1024
        private const val MAX_LINE_BYTES = 16 * 1024
        private const val MAX_JOURNAL_BYTES = 4L * 1024L * 1024L
        private const val SNAPSHOT_HEADER = "{\"version\":2}\n"
    }
}
