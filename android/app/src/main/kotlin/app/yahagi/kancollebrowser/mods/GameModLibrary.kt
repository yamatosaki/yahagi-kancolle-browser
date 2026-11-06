package app.yahagi.kancollebrowser.mods

import java.io.File
import java.io.InputStream
import java.io.OutputStream
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.nio.file.Files
import java.nio.file.LinkOption
import java.nio.file.attribute.BasicFileAttributes
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/** Applied configurations and synchronization journals share the private index budget. */
internal const val GAME_MOD_LIBRARY_STATE_LIMIT = 64L * 1024 * 1024

/** A user-owned document tree. Paths are relative and never refer outside its root. */
interface GameModLibraryStore {
    val displayName: String
    val identity: String
    fun list(relative: String = ""): List<GameModLibraryEntry>
    fun openRead(relative: String): InputStream
    fun openWrite(relative: String): OutputStream
    fun createDirectory(relative: String)
    fun delete(relative: String): Boolean
    fun rename(from: String, to: String): Boolean
    /** Reuse provider lookups within one read pass; never across a source recheck. */
    fun <T> withReadSession(block: () -> T): T = block()
}

data class GameModLibraryEntry(val name: String, val isDirectory: Boolean, val size: Long = 0, val modified: Long = 0)
data class GameModLibraryCandidate(
    val id: String, val name: String, val archive: File, val status: String,
    val contentHash: String, val path: String,
)
data class GameModLibraryScan(val token: String, val items: List<Map<String, Any?>>, val cleanupCount: Int = 0) {
    fun toMap(): Map<String, Any?> = mapOf("token" to token, "items" to items, "cleanupCount" to cleanupCount)
}

class GameModLibrary @JvmOverloads constructor(
    private val store: GameModLibraryStore,
    private val workspace: File,
    private val progress: GameModProgress? = null,
) {
    private val gson = Gson()
    private var generation = 0L
    private var state: LibraryState
    private val scans = linkedMapOf<String, ScanPreview>()
    // Only this process's successful byte validation can populate this bounded cache.
    // Public marker hashes, timestamps and persisted indexes never establish trust.
    private val validations = linkedMapOf<String, ValidationSummary>()

    init {
        if (!workspace.isDirectory && !workspace.mkdirs()) fail("storage_error", "无法创建魔改库检查目录。")
        state = readState()
    }

    @Synchronized fun status(): Map<String, Any?> = linkedMapOf(
        "configured" to true, "location" to store.displayName, "identity" to store.identity,
        "packageCount" to state.packages.size, "restoreAvailable" to (state.applied != null),
        "packages" to state.packages.map { it.toMap() },
        "deletionFailures" to state.tombstones.filter { !it.cleaned }.map { it.id },
    )

    /** The same content fingerprint used by scans; timestamps and marker files are excluded. */
    fun fingerprintLocalTree(directory: File): String = localHash(directory)

    /** Inspection copies and validates every byte, but never changes the public directory. */
    @Synchronized fun scan(): GameModLibraryScan {
        if (scans.size >= 2) discardScan(scans.keys.first())
        val token = UUID.randomUUID().toString()
        val directory = stage("scan-$token")
        val prepared = mutableListOf<Prepared>()
        val archives = mutableListOf<SourceArchive>()
        val items = mutableListOf<MutableMap<String, Any?>>()
        val root = store.list().sortedBy { it.name }
        val directories = root.filter { it.isDirectory && !it.name.startsWith(".yahagi-") }
        val zipFiles = root.filter { !it.isDirectory && it.name.endsWith(".zip", true) }
        val totalPackages = directories.size + zipFiles.size
        var completedPackages = 0
        progress?.update(phase = "discover", completedPackages = 0, totalPackages = totalPackages)
        val known = state.packages.associateBy { it.id }
        val discovered = linkedMapOf<String, Prepared>()
        val seen = mutableSetOf<String>()
        var itemNumber = 0

        directories.forEach { entry ->
            val path = entry.name
            progress?.startPackage("read", entry.name, completedPackages, totalPackages)
            try {
                safeEntryName(path)
                val marker = readMarker(path)
                val markerHash = markerHash(path)
                val located = state.packages.firstOrNull { it.path == path }
                if (located != null && marker != null && located.id != marker.id) {
                    fail("library_metadata_invalid", "已知魔改目录的包标识发生变化，请恢复其标记文件后重试。")
                }
                if (state.tombstones.any { !it.cleaned && (it.id == marker?.id || it.path == path) }) return@forEach
                val id = marker?.id ?: located?.id ?: UUID.randomUUID().toString()
                val previous = known[id]
                if (previous != null && previous.path != path && root.any { it.name == previous.path && it.isDirectory }) {
                    items.add(item(id, marker?.name ?: entry.name, path, "duplicate", marker?.contentHash, "同一包的旧目录或副本，已跳过。"))
                    return@forEach
                }
                if (!seen.add(id)) {
                    items.add(item(id, marker?.name ?: entry.name, path, "duplicate", marker?.contentHash, "存在相同魔改包标识，已跳过。"))
                    return@forEach
                }
                val local = File(directory, "${itemNumber++}").apply { mkdirs() }
                val tree = File(local, "tree").apply { mkdirs() }
                val hash = copyTree(path, tree)
                if (hashTree(path) != hash) fail("library_changed", "扫描期间文件发生变化，请复制完成后重试。")
                if (markerHash(path) != markerHash) fail("library_changed", "扫描期间魔改包标记发生变化，请重新扫描。")
                val archive = File(local, "package.zip")
                zipTree(tree, archive)
                val checked = validations[hash] ?: validate(archive, marker?.name ?: entry.name, File(local, "validate"))
                    .summary().also { rememberValidation(hash, it) }
                val record = PackageRecord(id, marker?.name ?: previous?.name ?: entry.name, path, hash,
                    marker?.sourceZip ?: previous?.sourceZip, marker?.sourceHash ?: previous?.sourceHash,
                    sourceConsumed = marker?.sourceConsumed == true || previous?.sourceConsumed == true)
                val kind = if ((previous?.contentHash ?: marker?.contentHash) == hash) "unchanged"
                    else if (previous != null || marker != null) "updated" else "new"
                val row = item(id, record.name, path, kind, hash).apply {
                    put("resourceCount", checked.resourceCount); put("supportedCount", checked.supportedCount)
                }
                val result = Prepared(record, archive, tree, path, hash, false, kind, row,
                    TreeSnapshot(path, hash, markerHash))
                prepared.add(result); discovered[id] = result; items.add(row)
            } catch (error: Exception) {
                val old = state.packages.firstOrNull { it.path == path }
                old?.let { seen.add(it.id) }
                items.add(item(old?.id, old?.name ?: entry.name, path, "invalid", null, message(error)))
            } finally {
                completedPackages++
                progress?.update(completedPackages = completedPackages)
            }
        }

        zipFiles.forEach { entry ->
            val path = entry.name
            progress?.startPackage("read", entry.name, completedPackages, totalPackages)
            try {
                safeEntryName(path)
                val local = File(directory, "${itemNumber++}").apply { mkdirs() }
                val archive = File(local, "package.zip")
                progress?.files(0, 1, path, 0, null)
                val sourceHash = store.withReadSession {
                    store.openRead(path).use { source -> archive.outputStream().use { output ->
                        copyHashed(source, output, MAX_ARCHIVE) { bytes -> progress?.files(0, 1, path, bytes, null) }
                    } }
                }
                progress?.files(1, 1, path, archive.length(), null)
                if (hashFile(path, MAX_ARCHIVE) != sourceHash) fail("library_changed", "ZIP 仍在复制，请完成后重新扫描。")
                if (state.tombstones.any { !it.cleaned && it.sourceZip == path && it.sourceHash == sourceHash }) return@forEach
                val previous = state.packages.firstOrNull { it.sourceZip == path && (!it.sourceConsumed || it.sourceHash == sourceHash) }
                    ?: discovered.values.firstOrNull { it.record.sourceZip == path && (!it.record.sourceConsumed || it.record.sourceHash == sourceHash) }?.record
                // An older import may still have its ZIP beside the editable directory.
                if (previous?.sourceHash == sourceHash) {
                    discovered[previous.id]?.let { archives.add(SourceArchive(it.record.id, path, sourceHash, it.record.contentHash)) }
                    return@forEach
                }
                val checked = validate(archive, entry.name.removeSuffixIgnoreCase(".zip"), File(local, "validate"))
                val tree = File(local, "tree").apply { mkdirs() }
                extractValidated(archive, tree)
                val hash = localHash(tree)
                rememberValidation(hash, checked.summary())
                val duplicate = discovered.values.firstOrNull { it.record.contentHash == hash && it.record.id != previous?.id }
                if (duplicate != null) {
                    items.add(item(duplicate.record.id, checked.name, path, "duplicate", hash, "内容与已有魔改包相同，已跳过。"))
                    return@forEach
                }
                val id = previous?.id ?: UUID.randomUUID().toString()
                val current = discovered[id]
                if (current != null && current.kind == "updated") {
                    prepared.remove(current); current.row["status"] = "invalid"; current.row["error"] = "解压目录和来源 ZIP 均已修改，请保留一种更新来源再扫描。"
                    items.add(item(id, previous?.name ?: checked.name, path, "invalid", hash, "解压目录和来源 ZIP 均已修改。"))
                    return@forEach
                }
                val replaced = if (previous == null) null else current?.replaced ?: run {
                    if (exists(previous.path)) fail("library_changed", "原解压目录未通过扫描，请保留其文件并重新扫描。")
                    TreeSnapshot(previous.path, null, null)
                }
                if (current != null) { prepared.remove(current); items.remove(current.row) }
                val kind = if (previous != null) "updated" else "new"
                val record = PackageRecord(id, previous?.name ?: checked.name, previous?.path ?: "", hash, path, sourceHash)
                val row = item(id, record.name, path, kind, hash).apply {
                    put("resourceCount", checked.resources.size); put("supportedCount", checked.resources.count { it.supported })
                }
                val normalized = File(local, "normalized.zip")
                zipTree(tree, normalized)
                val result = Prepared(record, normalized, tree, path, sourceHash, true, kind, row, replaced)
                prepared.add(result); discovered[id] = result; seen.add(id); items.add(row)
                archives.add(SourceArchive(id, path, sourceHash, hash))
            } catch (error: Exception) {
                val old = state.packages.firstOrNull { it.sourceZip == path }
                items.add(item(old?.id, old?.name ?: entry.name, path, "invalid", null, message(error)))
            } finally {
                completedPackages++
                progress?.update(completedPackages = completedPackages)
            }
        }

        state.packages.filter { it.id !in seen && state.tombstones.none { dead -> dead.id == it.id } }.forEach {
            items.add(item(it.id, it.name, it.path, "missing", it.contentHash, "公共目录中的文件已缺失，当前生效副本会保留。"))
        }
        // Different marker-less directories with identical content also remain a single import.
        val unique = mutableMapOf<String, Prepared>()
        prepared.toList().sortedBy { if (it.kind == "unchanged") 0 else 1 }.forEach { candidate ->
            val earlier = unique[candidate.record.contentHash]
            if (earlier != null && earlier.record.id != candidate.record.id) {
                prepared.remove(candidate); candidate.row["status"] = "duplicate"; candidate.row["error"] = "内容与已有魔改包相同，已跳过。"
            } else unique[candidate.record.contentHash] = candidate
        }
        val cleanup = archives.distinctBy { it.path }.filter { source -> prepared.any { it.record.id == source.id } }
        scans[token] = ScanPreview(directory, prepared, cleanup)
        return GameModLibraryScan(token, items.toList(), cleanup.size)
    }

    /** Recheck before accepting: a preview never gives permission to use subsequently changed files. */
    @Synchronized fun acceptScan(token: String): List<GameModLibraryCandidate> {
        val preview = scans[token] ?: fail("invalid_token", "扫描预览已失效，请重新扫描。")
        preview.prepared.forEachIndexed { index, candidate ->
            progress?.startPackage("read", candidate.record.name, index, preview.prepared.size)
            val current = if (candidate.zip) hashFile(candidate.sourcePath, MAX_ARCHIVE) else hashTree(candidate.sourcePath)
            if (current != candidate.sourceHash) fail("library_changed", "预览后魔改文件发生变化，请重新扫描。")
            if (candidate.zip) candidate.replaced?.let(::verifyReplacement)
            progress?.update(completedPackages = index + 1)
        }
        val results = mutableListOf<GameModLibraryCandidate>()
        preview.prepared.forEachIndexed { index, candidate ->
            progress?.startPackage("save", candidate.record.name, index, preview.prepared.size)
            val record = if (candidate.zip) saveTree(candidate.record, candidate.tree, candidate.replaced) else {
                writeMarker(candidate.record)
                updateRecord(candidate.record)
                candidate.record
            }
            results.add(GameModLibraryCandidate(record.id, record.name, candidate.archive, candidate.kind, record.contentHash, record.path))
            progress?.update(completedPackages = index + 1)
        }
        // Keep returned local archives alive until the next preview/discard, for repository preflight.
        return results
    }

    @Synchronized fun discardScan(token: String) {
        scans.remove(token)?.directory?.deleteRecursively()
    }

    /** Only after the complete repository import succeeds; previews and failed imports keep their ZIPs. */
    @Synchronized fun completeScan(token: String): List<String> {
        val preview = scans[token] ?: fail("invalid_token", "扫描预览已失效，请重新扫描。")
        return preview.archives.mapNotNull { source ->
            try {
                val path = safe(source.path)
                if (path.contains('/') || !path.endsWith(".zip", true)) fail("unsafe_path", "来源 ZIP 必须位于魔改库根目录。")
                val entry = store.list().firstOrNull { it.name == path } ?: return@mapNotNull null
                val record = state.packages.singleOrNull { it.id == source.id }
                if (entry.isDirectory || record == null || record.contentHash != source.contentHash ||
                    readMarker(record.path)?.id != source.id || hashTree(record.path) != source.contentHash ||
                    hashFile(path, MAX_ARCHIVE) != source.hash) return@mapNotNull path
                if (!record.sourceConsumed) {
                    // Keep ownership for failed-delete retries, but a later unrelated cache.zip
                    // must not update this package merely because it reuses the filename.
                    val consumed = record.copy(sourceConsumed = true)
                    writeMarker(consumed)
                    updateRecord(consumed)
                }
                if (hashFile(path, MAX_ARCHIVE) != source.hash || !store.delete(path)) path else null
            } catch (_: Exception) { source.path }
        }
    }

    @Synchronized fun savePackage(id: String, name: String, directory: File, sourceZip: String? = null, sourceHash: String? = null): Map<String, Any?> {
        requireUuid(id)
        if (sourceZip != null && (safe(sourceZip).contains('/') || !sourceZip.endsWith(".zip", true))) fail("unsafe_path", "来源 ZIP 必须位于魔改库根目录。")
        if (sourceHash != null && !HASH.matches(sourceHash)) fail("invalid_config", "来源 ZIP 指纹无效。")
        val local = stage("save")
        try {
            val archive = File(local, "check.zip")
            zipTree(directory, archive)
            validate(archive, name, File(local, "validate"))
            val hash = localHash(directory)
            val previous = state.packages.firstOrNull { it.id == id }
            val record = saveTree(PackageRecord(id, name.trim().take(160).ifEmpty { "魔改包" }, previous?.path ?: "", hash, sourceZip, sourceHash), directory)
            return record.toMap()
        } finally { local.deleteRecursively() }
    }

    @Synchronized fun saveAppliedConfiguration(config: Map<*, *>) {
        @Suppress("UNCHECKED_CAST")
        val copied = gson.fromJson(gson.toJson(config), Map::class.java) as Map<String, Any?>
        saveState(state.copy(applied = copied))
    }

    @Synchronized fun appliedConfiguration(): Map<String, Any?>? {
        @Suppress("UNCHECKED_CAST")
        return state.applied?.let { gson.fromJson(gson.toJson(it), Map::class.java) as Map<String, Any?> }
    }

    /** Call only after an apply succeeds. Tombstones are durable before any public file is removed. */
    @Synchronized fun deletePackages(ids: List<String>): List<String> {
        ids.forEach(::requireUuid)
        val records = state.packages.filter { it.id in ids }
        val dead = (state.tombstones + records.map { record ->
            val source = record.sourceZip?.takeUnless { zip -> record.sourceConsumed &&
                runCatching { !exists(zip) || hashFile(zip, MAX_ARCHIVE) != record.sourceHash }.getOrDefault(false) }
            Tombstone(record.id, record.path, source, record.sourceHash)
        }).distinctBy { it.id }
        saveState(state.copy(packages = state.packages.filterNot { it.id in ids }, tombstones = dead))
        val failures = mutableListOf<String>()
        val cleaned = state.tombstones.map { tombstone ->
            if (tombstone.id !in ids || tombstone.cleaned) return@map tombstone
            var complete = true
            if (exists(tombstone.path)) {
                try {
                    if (readMarker(tombstone.path)?.id != tombstone.id || !store.delete(tombstone.path)) {
                        failures.add(tombstone.path); complete = false
                    }
                } catch (_: Exception) { failures.add(tombstone.path); complete = false }
            }
            tombstone.sourceZip?.let { source ->
                if (exists(source)) try {
                    if (hashFile(source, MAX_ARCHIVE) != tombstone.sourceHash || !store.delete(source)) {
                        failures.add(source); complete = false
                    }
                } catch (_: Exception) { failures.add(source); complete = false }
            }
            tombstone.copy(cleaned = complete)
        }
        saveState(state.copy(tombstones = cleaned))
        return failures.distinct()
    }

    private fun saveTree(record: PackageRecord, tree: File, replaced: TreeSnapshot? = null): PackageRecord {
        replaced?.let(::verifyReplacement)
        val previous = state.packages.firstOrNull { it.id == record.id }
        val ownsPrevious = previous != null && exists(previous.path) && runCatching { readMarker(previous.path)?.id == previous.id }.getOrDefault(false)
        if (replaced == null && previous != null && ownsPrevious && previous.contentHash == record.contentHash && hashTree(previous.path) == record.contentHash) {
            val same = record.copy(path = previous.path); writeMarker(same); updateRecord(same); return same
        }
        val safeName = record.name.replace(Regex("[\\\\/:*?%#\"<>|\\p{Cntrl}]"), "_").trim().take(64).ifEmpty { "魔改包" }
        var destination = "$safeName-${record.id.take(8)}-${record.contentHash.take(8)}"
        if (exists(destination)) destination += "-${UUID.randomUUID().toString().take(8)}"
        val temporary = ".yahagi-import-${UUID.randomUUID()}"
        store.createDirectory(temporary)
        var incompleteDestination: String? = null
        try {
            copyLocalToStore(tree, temporary)
            val staged = record.copy(path = temporary)
            if (hashTree(temporary) != record.contentHash) fail("storage_error", "魔改库写入校验失败。")
            writeMarker(staged)
            if (!store.rename(temporary, destination)) {
                // Providers without rename still publish only after every resource has been verified.
                store.createDirectory(destination)
                incompleteDestination = destination
                // An unsupported marker version keeps a failed partial copy unimportable,
                // even when the provider also refuses cleanup or the process is interrupted.
                writeMarker(record.copy(path = destination, schemaVersion = 0))
                copyLocalToStore(tree, destination)
                if (hashTree(destination) != record.contentHash) fail("storage_error", "魔改库写入校验失败。")
                writeMarker(record.copy(path = destination))
                incompleteDestination = null
                store.delete(temporary)
            }
            val saved = record.copy(path = destination)
            writeMarker(saved) // A renamed marker must describe its final location.
            replaced?.let(::verifyReplacement)
            val beforeUpdate = state
            updateRecord(saved)
            // Publishing/index IO can yield to an editor or document provider. This
            // includes markerless trees and directories that were absent at preview.
            if (replaced != null) {
                try { verifyReplacement(replaced) }
                catch (changed: GameModException) {
                    // Keep earlier successful packages in this batch, but do not let
                    // this refused replacement hide its still-editable old directory.
                    try { saveState(beforeUpdate) }
                    catch (rollback: Exception) {
                        fail("storage_error", "原文件已保留，但魔改库配置回滚失败：${message(rollback)}")
                    }
                    throw changed
                }
            }
            if (ownsPrevious && previous.path != saved.path) {
                if (replaced != null || readMarker(previous.path)?.id == previous.id) store.delete(previous.path)
            }
            return saved
        } catch (error: Exception) {
            runCatching { store.delete(temporary) }
            incompleteDestination?.let(::discardIncompleteTree)
            // A complete public directory is intentionally retained if only its index write failed.
            if (error is GameModException) throw error
            fail("storage_error", "无法保存公共魔改文件：${message(error)}")
        }
    }

    private fun markerHash(path: String): String? =
        if (store.list(path).any { it.name == MARKER }) hashFile("$path/$MARKER", MAX_METADATA) else null

    private fun verifyReplacement(snapshot: TreeSnapshot) {
        val unchanged = runCatching {
            if (snapshot.contentHash == null) !exists(snapshot.path)
            else exists(snapshot.path) && markerHash(snapshot.path) == snapshot.markerHash &&
                hashTree(snapshot.path) == snapshot.contentHash
        }.getOrDefault(false)
        if (!unchanged) fail("library_changed", "预览后原解压目录或包标记发生变化，已保留原文件，请重新扫描。")
    }

    private fun discardIncompleteTree(path: String) {
        runCatching {
            // Recursive provider deletes may remove the marker before a locked resource.
            // Keep that guard until every resource has been removed successfully.
            for (entry in store.list(path).filter { it.name != MARKER }) {
                if (!store.delete("$path/${safe(entry.name)}")) return@runCatching
            }
            if (store.list(path).all { it.name == MARKER }) store.delete(path)
        }
    }

    private fun updateRecord(record: PackageRecord) {
        saveState(state.copy(packages = state.packages.filterNot { it.id == record.id } + record,
            tombstones = state.tombstones.filterNot { it.id == record.id }))
    }

    private fun writeMarker(record: PackageRecord) {
        writeBytes("${safe(record.path)}/$MARKER", gson.toJson(recordMetadata(record)).toByteArray(Charsets.UTF_8))
    }

    private fun readMarker(directory: String): PackageRecord? {
        val entry = store.list(directory).firstOrNull { it.name == MARKER } ?: return null
        if (entry.isDirectory || entry.size > MAX_METADATA) fail("library_metadata_invalid", "魔改包标记文件无效。")
        try {
            val value = readRecordMetadata(JsonParser.parseString(readText("$directory/$MARKER")).asJsonObject, optionalVersion = false)
            return value.copy(path = directory)
        } catch (error: Exception) {
            if (error is GameModException) throw error
            fail("library_metadata_invalid", "魔改包标记文件已损坏。")
        }
    }

    private fun readState(): LibraryState {
        val present = store.list().filter { it.name in STATE_FILES && !it.isDirectory }
        if (present.isEmpty()) return LibraryState()
        val valid = present.mapNotNull { entry ->
            try {
                val envelope = JsonParser.parseString(readText(entry.name, GAME_MOD_LIBRARY_STATE_LIMIT)).asJsonObject
                val payload = envelope.getAsJsonObject("state")
                val encoded = payload.toString().toByteArray(Charsets.UTF_8)
                if (envelope["schemaVersion"].asInt != 1 || envelope["sha256"].asString != digest(encoded)) return@mapNotNull null
                // Verify the untouched payload before recognizing the beta3 field aliases.
                val decoded = readStateMetadata(payload)
                envelope["generation"].asLong to decoded
            } catch (_: Exception) { null }
        }.maxByOrNull { it.first } ?: fail("library_metadata_invalid", "魔改库配置已损坏，公共资源仍保留，请恢复 library.json 备份。")
        generation = valid.first
        return valid.second
    }

    private fun saveState(next: LibraryState) {
        val nextGeneration = generation + 1
        val payload = stateMetadata(next)
        val envelope = JsonObject().apply {
            addProperty("schemaVersion", 1); addProperty("generation", nextGeneration)
            addProperty("sha256", digest(payload.toString().toByteArray(Charsets.UTF_8))); add("state", payload)
        }
        val name = STATE_FILES[((nextGeneration - 1) % STATE_FILES.size).toInt()]
        val bytes = envelope.toString().toByteArray(Charsets.UTF_8)
        if (bytes.size > GAME_MOD_LIBRARY_STATE_LIMIT) fail("quota_exceeded", "魔改库配置不能超过 64 MiB。")
        try {
            writeBytes(name, bytes)
            if (!store.openRead(name).use { it.readBytesLimited(GAME_MOD_LIBRARY_STATE_LIMIT) }.contentEquals(bytes)) fail("storage_error", "魔改库配置写入校验失败。")
        } catch (error: Exception) {
            if (error is GameModException) throw error
            fail("storage_error", "无法保存魔改库配置：${message(error)}")
        }
        state = next; generation = nextGeneration
    }

    // Persist literal JSON keys rather than Kotlin field names: R8 may rename or remove fields.
    private fun recordMetadata(record: PackageRecord): Map<String, Any?> = record.toMap() + mapOf(
        "schemaVersion" to record.schemaVersion, "sourceConsumed" to record.sourceConsumed,
    )

    private fun stateMetadata(value: LibraryState): JsonObject = JsonObject().apply {
        addProperty("schemaVersion", value.schemaVersion)
        add("packages", gson.toJsonTree(value.packages.map(::recordMetadata)))
        value.applied?.let { add("applied", gson.toJsonTree(it)) }
        add("tombstones", gson.toJsonTree(value.tombstones.map { tombstone -> linkedMapOf(
            "id" to tombstone.id, "path" to tombstone.path, "sourceZip" to tombstone.sourceZip,
            "sourceHash" to tombstone.sourceHash, "cleaned" to tombstone.cleaned,
        ) }))
    }

    private fun readStateMetadata(payload: JsonObject): LibraryState {
        val aliases = mapOf("packages" to "a", "applied" to "b", "tombstones" to "c")
        val legacy = aliases.values.any(payload::has)
        val fields = metadataFields(payload, aliases, setOf("schemaVersion"))
        // beta3 optimized this constant field away. The verified envelope still declares v1.
        if (legacy) fields.addProperty("schemaVersion", 1)
        metadataVersion(fields)
        val packages = fields["packages"]?.takeIf { it.isJsonArray }?.asJsonArray
            ?: fail("library_metadata_invalid", "魔改库包列表无效。")
        val tombstones = fields["tombstones"]?.takeIf { it.isJsonArray }?.asJsonArray
            ?: fail("library_metadata_invalid", "魔改库删除记录无效。")
        @Suppress("UNCHECKED_CAST")
        val applied = fields["applied"]?.takeUnless { it.isJsonNull }?.let {
            if (!it.isJsonObject) fail("library_metadata_invalid", "已保存搭配无效。")
            // Map keys are already literal JSON keys, including any nested user-visible names.
            gson.fromJson(it, Map::class.java) as Map<String, Any?>
        }
        return LibraryState(packages = packages.map { readRecordMetadata(it.asJsonObject) },
            applied = applied, tombstones = tombstones.map { readTombstoneMetadata(it.asJsonObject) })
    }

    private fun readRecordMetadata(value: JsonObject, optionalVersion: Boolean = true): PackageRecord {
        val fields = metadataFields(value, mapOf("id" to "a", "name" to "b", "path" to "c",
            "contentHash" to "d", "sourceZip" to "e", "sourceHash" to "f",
            "schemaVersion" to "g", "sourceConsumed" to "h"))
        metadataVersion(fields, optional = optionalVersion)
        val id = metadataText(fields, "id").also(::requireUuid)
        val name = metadataText(fields, "name").also { if (it.isBlank()) fail("library_metadata_invalid", "魔改包名称无效。") }
        val path = safe(metadataText(fields, "path"))
        val contentHash = metadataText(fields, "contentHash").also { if (!HASH.matches(it)) fail("library_metadata_invalid", "魔改库记录校验无效。") }
        return PackageRecord(id, name, path, contentHash, metadataSource(fields), metadataHash(fields),
            sourceConsumed = metadataBoolean(fields, "sourceConsumed"))
    }

    private fun readTombstoneMetadata(value: JsonObject): Tombstone {
        val fields = metadataFields(value, mapOf("id" to "a", "path" to "b", "sourceZip" to "c",
            "sourceHash" to "d", "cleaned" to "e"))
        return Tombstone(metadataText(fields, "id").also(::requireUuid), safe(metadataText(fields, "path")),
            metadataSource(fields), metadataHash(fields), metadataBoolean(fields, "cleaned"))
    }

    private fun metadataFields(value: JsonObject, aliases: Map<String, String>, extraKeys: Set<String> = emptySet()): JsonObject {
        val canonical = (aliases.keys + extraKeys).any(value::has)
        val legacy = aliases.values.any(value::has)
        if (canonical && legacy) fail("library_metadata_invalid", "魔改库记录混用了不同版本的字段。")
        if (!legacy) return value
        if (value.keySet().any { it !in aliases.values }) fail("library_metadata_invalid", "旧版魔改库记录字段无效。")
        return JsonObject().apply { aliases.forEach { (name, alias) -> if (value.has(alias)) add(name, value[alias]) } }
    }

    private fun metadataVersion(value: JsonObject, optional: Boolean = false) {
        val version = value["schemaVersion"] ?: if (optional) return else fail("library_metadata_invalid", "魔改库记录缺少版本。")
        if (!version.isJsonPrimitive || !version.asJsonPrimitive.isNumber || version.asBigDecimal.compareTo(java.math.BigDecimal.ONE) != 0) {
            fail("library_metadata_invalid", "魔改库记录版本无效。")
        }
    }

    private fun metadataText(value: JsonObject, key: String): String {
        val text = value[key]
        if (text == null || !text.isJsonPrimitive || !text.asJsonPrimitive.isString) fail("library_metadata_invalid", "魔改库记录字段无效。")
        return text.asString
    }

    private fun metadataOptionalText(value: JsonObject, key: String): String? =
        value[key]?.takeUnless { it.isJsonNull }?.let { metadataText(value, key) }

    private fun metadataBoolean(value: JsonObject, key: String): Boolean {
        val flag = value[key] ?: return false
        if (!flag.isJsonPrimitive || !flag.asJsonPrimitive.isBoolean) fail("library_metadata_invalid", "魔改库记录开关无效。")
        return flag.asBoolean
    }

    private fun metadataSource(value: JsonObject): String? = metadataOptionalText(value, "sourceZip")?.also {
        if (safe(it).contains('/') || !it.endsWith(".zip", true)) fail("unsafe_path", "魔改包来源路径无效。")
    }

    private fun metadataHash(value: JsonObject): String? = metadataOptionalText(value, "sourceHash")?.also {
        if (!HASH.matches(it)) fail("library_metadata_invalid", "魔改包来源校验无效。")
    }

    private fun copyTree(path: String, destination: File): String = store.withReadSession {
        val files = treeFiles(path)
        val digest = MessageDigest.getInstance("SHA-256")
        var total = 0L
        progress?.files(0, files.size, null, 0, null)
        files.forEachIndexed { index, relative ->
            progress?.files(index, files.size, relative, total, null)
            val file = File(destination, relative).apply { parentFile?.mkdirs() }
            digestName(digest, relative)
            val fileDigest = MessageDigest.getInstance("SHA-256")
            val before = total
            store.openRead("$path/$relative").use { source -> file.outputStream().use { output ->
                val size = copyDigest(source, output, fileDigest, MAX_FILE) { bytes ->
                    progress?.files(index, files.size, relative, before + bytes, null)
                }; total += size
                if (total > MAX_TREE) fail("quota_exceeded", "魔改包总大小不能超过 1 GiB。")
            } }
            digest.update(fileDigest.digest())
            digest.update(0)
            progress?.files(index + 1, files.size, relative, total, null)
        }
        hex(digest.digest())
    }

    private fun hashTree(path: String): String = store.withReadSession {
        val digest = MessageDigest.getInstance("SHA-256"); var total = 0L
        val files = treeFiles(path)
        progress?.update(phase = "read")
        progress?.files(0, files.size, null, 0, null)
        files.forEachIndexed { index, relative ->
            progress?.files(index, files.size, relative, total, null)
            digestName(digest, relative)
            val fileDigest = MessageDigest.getInstance("SHA-256")
            val before = total
            store.openRead("$path/$relative").use { total += copyDigest(it, null, fileDigest, MAX_FILE) { bytes ->
                progress?.files(index, files.size, relative, before + bytes, null)
            } }
            if (total > MAX_TREE) fail("quota_exceeded", "魔改包总大小不能超过 1 GiB。")
            digest.update(fileDigest.digest())
            digest.update(0)
            progress?.files(index + 1, files.size, relative, total, null)
        }
        hex(digest.digest())
    }

    private fun treeFiles(path: String): List<String> {
        val files = mutableListOf<String>()
        var count = 0
        fun walk(directory: String, prefix: String, depth: Int) {
            if (depth > 64) fail("quota_exceeded", "魔改目录层级过多。")
            val entries = store.list(directory)
            count += entries.size
            if (count > MAX_ENTRIES) fail("quota_exceeded", "魔改目录条目数量不能超过 20000。")
            if (entries.map { it.name }.distinct().size != entries.size) fail("duplicate_resource", "魔改目录含同名文件。")
            entries.forEach { entry ->
                if (prefix.isEmpty() && entry.name == MARKER) return@forEach
                val name = safe(entry.name)
                if ('/' in name) fail("unsafe_path", "魔改文件名不能包含路径。")
                val relative = prefix + name
                if (entry.isDirectory) walk("$directory/$name", "$relative/", depth + 1)
                else { if (entry.size > MAX_FILE) fail("quota_exceeded", "单个魔改文件不能超过 64 MiB。"); files.add(relative) }
                if (files.size > MAX_ENTRIES) fail("quota_exceeded", "魔改文件数量不能超过 20000。")
            }
        }
        walk(path, "", 0)
        if (files.isEmpty()) fail("invalid_archive", "魔改目录中没有文件。")
        return files.sorted()
    }

    /** Enumerate safely without reading every byte merely to obtain a file list. */
    private fun localFiles(directory: File): List<File> {
        val fileStore = GameModFileLibraryStore(directory)
        val files = mutableListOf<File>()
        var count = 0
        var total = 0L
        fun visit(path: String, depth: Int) {
            if (depth > 64) fail("quota_exceeded", "魔改目录层级过多。")
            val entries = fileStore.list(path).sortedBy { it.name }
            count += entries.size
            if (count > MAX_ENTRIES) fail("quota_exceeded", "魔改目录条目数量不能超过 20000。")
            entries.forEach { entry ->
                val relative = if (path.isEmpty()) entry.name else "$path/${entry.name}"
                if (relative == MARKER) return@forEach
                safeEntryName(entry.name)
                val checked = fileStore.resolve(safe(relative))
                if (entry.isDirectory) visit(relative, depth + 1) else {
                    if (entry.size > MAX_FILE) fail("quota_exceeded", "单个魔改文件不能超过 64 MiB。")
                    total += entry.size
                    if (total > MAX_TREE) fail("quota_exceeded", "魔改包总大小不能超过 1 GiB。")
                    files.add(checked)
                }
            }
        }
        visit("", 0)
        if (files.isEmpty() || files.size > MAX_ENTRIES) fail("quota_exceeded", "魔改包文件数量无效。")
        files.sortBy { it.relativeTo(directory).invariantSeparatorsPath }
        return files
    }

    private fun localHash(directory: File): String {
        val fileStore = GameModFileLibraryStore(directory)
        val files = localFiles(directory)
        val digest = MessageDigest.getInstance("SHA-256"); var total = 0L
        files.forEach { file ->
            val relative = file.relativeTo(directory).invariantSeparatorsPath
            digestName(digest, relative)
            val fileDigest = MessageDigest.getInstance("SHA-256")
            fileStore.openRead(relative).use { total += copyDigest(it, null, fileDigest, MAX_FILE) }
            if (total > MAX_TREE) fail("quota_exceeded", "魔改包总大小不能超过 1 GiB。")
            digest.update(fileDigest.digest())
            digest.update(0)
        }
        return hex(digest.digest())
    }

    private fun zipTree(tree: File, archive: File) {
        val files = localFiles(tree)
        var total = 0L
        ZipOutputStream(archive.outputStream().buffered()).use { zip ->
            // Compression-free staging avoids imposing extra ratio restrictions on already validated images.
            zip.setLevel(0)
            files.forEach { file ->
                zip.putNextEntry(ZipEntry(file.relativeTo(tree).invariantSeparatorsPath))
                file.inputStream().use { total += copyDigest(it, zip, null, MAX_FILE) }
                if (total > MAX_TREE) fail("quota_exceeded", "魔改包总大小不能超过 1 GiB。")
                zip.closeEntry()
            }
        }
        if (archive.length() > GAME_MOD_LIBRARY_ARCHIVE_LIMIT) fail("quota_exceeded", "魔改库内部检查文件超过限额。")
    }

    private fun validate(archive: File, name: String, directory: File): ArchiveResult {
        progress?.update(phase = "validate")
        val result = archive.inputStream().use { GameModArchive(progress).unpackLibrary(it, "$name.zip", directory) }
        if (result.resources.none { it.supported }) fail("unsupported_archive", "未找到受支持的游戏资源，请保留 kcs/kcs2 文件夹结构。")
        return result
    }

    private fun extractValidated(archive: File, tree: File) {
        var total = 0L
        ZipFile(archive, GameModArchive.selectCharset(archive)).use { zip ->
            val allEntries = zip.entries().asSequence().filterNot { it.name.replace('\\', '/').endsWith('/') }.toList()
            val wrapper = GameModArchive.detectWrapperDirectory(allEntries.asSequence().map { it.name })
            val hackTargets = allEntries.mapNotNullTo(mutableSetOf()) { entry ->
                val parsed = GameModArchive.parseEntryPath(entry.name, wrapper)
                if (parsed.isHack && parsed.normalizedPath.endsWith(".png", ignoreCase = true)) parsed.strippedRaw.replace(GameModArchive.HACK_SUFFIX, ".$1") else null
            }
            for (entry in allEntries) {
                val parsed = GameModArchive.parseEntryPath(entry.name, wrapper)
                if (!parsed.isHack && parsed.strippedRaw in hackTargets) continue
                val normalized = safe(parsed.normalizedPath)
                if (normalized == MARKER) fail("unsafe_path", "ZIP 不能覆盖魔改包标记。")
                val destination = File(tree, normalized).apply { parentFile?.mkdirs() }
                zip.getInputStream(entry).use { source -> destination.outputStream().use { total += copyDigest(source, it, null, MAX_FILE) } }
                if (total > MAX_TREE) fail("quota_exceeded", "魔改包总大小不能超过 1 GiB。")
                if (normalized.endsWith(".png", ignoreCase = true)) {
                    GameModPng.validateImport(destination)
                }
            }
        }
    }

    private fun copyLocalToStore(tree: File, destination: String) {
        val files = localFiles(tree)
        var total = 0L
        progress?.update(phase = "save")
        progress?.files(0, files.size, null, 0, null)
        files.forEachIndexed { index, file ->
            val relative = file.relativeTo(tree).invariantSeparatorsPath
            progress?.files(index, files.size, relative, total, null)
            val parent = relative.substringBeforeLast('/', "")
            if (parent.isNotEmpty()) store.createDirectory("$destination/$parent")
            val before = total
            file.inputStream().use { source -> store.openWrite("$destination/$relative").use { output ->
                total += copyDigest(source, output, null, MAX_FILE) { bytes ->
                    progress?.files(index, files.size, relative, before + bytes, null)
                }
            } }
            if (total > MAX_TREE) fail("quota_exceeded", "魔改包总大小不能超过 1 GiB。")
            progress?.files(index + 1, files.size, relative, total, null)
        }
    }

    private fun exists(path: String): Boolean {
        val checked = safe(path)
        return store.list(checked.substringBeforeLast('/', "")).any { it.name == checked.substringAfterLast('/') }
    }
    private fun hashFile(path: String, limit: Long): String = store.withReadSession {
        progress?.update(phase = "read")
        progress?.files(0, 1, path, 0, null)
        var size = 0L
        val hash = store.openRead(safe(path)).use { input -> copyHashed(input, null, limit) { bytes ->
            size = bytes
            progress?.files(0, 1, path, bytes, null)
        } }
        progress?.files(1, 1, path, size, null)
        hash
    }
    private fun writeBytes(path: String, bytes: ByteArray) = store.openWrite(safe(path)).use { it.write(bytes) }
    private fun readText(path: String, limit: Long = MAX_METADATA): String = store.openRead(safe(path)).use { it.readBytesLimited(limit).toString(Charsets.UTF_8) }
    private fun stage(name: String): File = File(workspace, "$name-${UUID.randomUUID()}").apply { if (!mkdirs()) fail("storage_error", "无法准备魔改库临时目录。") }
    private fun item(id: String?, name: String, path: String, status: String, hash: String?, error: String? = null): MutableMap<String, Any?> = linkedMapOf(
        "id" to id, "name" to name, "path" to path, "status" to status, "contentHash" to hash,
        "error" to error, "reason" to error,
    )

    private data class LibraryState(val schemaVersion: Int = 1, val packages: List<PackageRecord> = emptyList(), val applied: Map<String, Any?>? = null, val tombstones: List<Tombstone> = emptyList())
    private data class PackageRecord(val id: String, val name: String, val path: String, val contentHash: String, val sourceZip: String? = null, val sourceHash: String? = null, val schemaVersion: Int = 1, val sourceConsumed: Boolean = false) {
        fun toMap(): Map<String, Any?> = linkedMapOf("id" to id, "name" to name, "path" to path, "contentHash" to contentHash, "sourceZip" to sourceZip, "sourceHash" to sourceHash)
    }
    private data class Tombstone(val id: String, val path: String, val sourceZip: String? = null, val sourceHash: String? = null, val cleaned: Boolean = false)
    private data class TreeSnapshot(val path: String, val contentHash: String?, val markerHash: String?)
    private data class Prepared(val record: PackageRecord, val archive: File, val tree: File, val sourcePath: String, val sourceHash: String, val zip: Boolean, val kind: String, val row: MutableMap<String, Any?>, val replaced: TreeSnapshot? = null)
    private data class SourceArchive(val id: String, val path: String, val hash: String, val contentHash: String)
    private data class ScanPreview(val directory: File, val prepared: List<Prepared>, val archives: List<SourceArchive>)
    private data class ValidationSummary(val resourceCount: Int, val supportedCount: Int)
    private fun ArchiveResult.summary() = ValidationSummary(resources.size, resources.count { it.supported })
    private fun rememberValidation(hash: String, summary: ValidationSummary) {
        validations[hash] = summary
        if (validations.size > 256) validations.remove(validations.keys.first())
    }

    private companion object {
        const val MARKER = ".yahagi-package.json"
        val STATE_FILES = listOf("library.json", ".yahagi-library-backup.json")
        val HASH = Regex("[0-9a-f]{64}")
        const val MAX_ARCHIVE = 256L * 1024 * 1024
        const val MAX_FILE = 64L * 1024 * 1024
        const val MAX_TREE = 1024L * 1024 * 1024
        const val MAX_METADATA = 4L * 1024 * 1024
        const val MAX_ENTRIES = 20_000
        fun message(error: Exception): String = (error.message ?: "文件读取失败。 ").take(300)
        fun fail(code: String, message: String): Nothing = throw GameModException(code, message)
        fun requireUuid(id: String) { if (runCatching { UUID.fromString(id).toString() == id.lowercase() }.getOrDefault(false).not()) fail("invalid_config", "魔改包标识无效。") }
        fun safe(relative: String): String {
            if (relative.isEmpty() || relative.length > 4096 || relative.startsWith('/') || relative.any { it.code < 32 || it in "\\:%?#" } || relative.split('/').any { it.isEmpty() || it == "." || it == ".." || it.length > 255 }) fail("unsafe_path", "魔改库包含不安全的相对路径。")
            return relative
        }
        fun safeEntryName(name: String): String = safe(name).also {
            if ('/' in it) fail("unsafe_path", "魔改库条目名称不能包含路径。")
        }
        fun digest(bytes: ByteArray): String = hex(MessageDigest.getInstance("SHA-256").digest(bytes))
        fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it.toInt() and 255) }
        fun digestName(digest: MessageDigest, name: String) { digest.update(name.toByteArray(Charsets.UTF_8)); digest.update(0) }
        fun copyHashed(input: InputStream, output: OutputStream?, limit: Long, onProgress: ((Long) -> Unit)? = null): String {
            val digest = MessageDigest.getInstance("SHA-256"); copyDigest(input, output, digest, limit, onProgress); return hex(digest.digest())
        }
        fun copyDigest(input: InputStream, output: OutputStream?, digest: MessageDigest?, limit: Long, onProgress: ((Long) -> Unit)? = null): Long {
            val buffer = ByteArray(32 * 1024); var total = 0L
            while (true) { val count = input.read(buffer); if (count < 0) break; if (count == 0) continue
                total += count; if (total > limit) fail("quota_exceeded", "魔改文件超过大小限制。")
                digest?.update(buffer, 0, count); output?.write(buffer, 0, count)
                onProgress?.invoke(total)
            }
            return total
        }
        fun InputStream.readBytesLimited(limit: Long): ByteArray = java.io.ByteArrayOutputStream().also { copyDigest(this, it, null, limit) }.toByteArray()
        fun String.removeSuffixIgnoreCase(suffix: String): String = if (endsWith(suffix, true)) dropLast(suffix.length) else this
    }
}

class GameModFileLibraryStore(private val root: File) : GameModLibraryStore {
    override val displayName: String get() = root.absolutePath
    override val identity: String get() = root.canonicalPath
    init { if ((!root.isDirectory && !root.mkdirs()) || Files.isSymbolicLink(root.toPath())) throw GameModException("storage_error", "无法创建魔改库目录。") }
    override fun list(relative: String): List<GameModLibraryEntry> = resolve(relative, true).let { directory ->
        if (!directory.isDirectory) throw GameModException("storage_error", "魔改库目录不存在。")
        directory.listFiles()?.map { file ->
            // Enumerate names before validating each candidate. A user's unrelated
            // backup#1 must not prevent inspection of the rest of the library.
            // Do not follow links even to obtain metadata; all IO still uses resolve.
            val attributes = Files.readAttributes(file.toPath(), BasicFileAttributes::class.java, LinkOption.NOFOLLOW_LINKS)
            GameModLibraryEntry(file.name, attributes.isDirectory, if (attributes.isRegularFile) attributes.size() else 0, attributes.lastModifiedTime().toMillis())
        } ?: throw GameModException("storage_error", "无法读取魔改库目录。")
    }
    override fun openRead(relative: String): InputStream = resolve(relative).let { if (!it.isFile) throw GameModException("storage_error", "魔改文件不存在。"); it.inputStream() }
    override fun openWrite(relative: String): OutputStream = resolve(relative).let { if (it.parentFile?.isDirectory != true) throw GameModException("storage_error", "魔改文件夹不存在。"); it.outputStream() }
    override fun createDirectory(relative: String) { val directory=resolve(relative); if (!directory.isDirectory && !directory.mkdirs()) throw GameModException("storage_error", "无法创建魔改文件夹。") }
    override fun delete(relative: String): Boolean {
        val target = resolve(relative)
        if (!target.exists()) return true
        fun remove(file: File): Boolean {
            resolve(file.relativeTo(root).invariantSeparatorsPath)
            if (file.isDirectory && file.listFiles()?.all(::remove) != true) return false
            return file.delete()
        }
        return remove(target)
    }
    override fun rename(from: String, to: String): Boolean { val source=resolve(from);val target=resolve(to);return !target.exists() && source.renameTo(target) }
    internal fun resolve(relative: String, allowRoot: Boolean = false): File {
        if (relative.isEmpty() && allowRoot) return root
        if (relative.isEmpty() || relative.startsWith('/') || relative.any {it.code<32 || it in "\\:%?#"} || relative.split('/').any {it.isEmpty()||it=="."||it==".."}) throw GameModException("unsafe_path", "魔改库路径不安全。")
        val file=File(root,relative).absoluteFile.normalize();val canonical=file.canonicalFile;val base=root.canonicalFile
        if (!canonical.path.startsWith(base.path+File.separator)) throw GameModException("unsafe_path", "魔改库路径越界。")
        var part=root.absoluteFile
        relative.split('/').forEach {part=File(part,it);if(Files.isSymbolicLink(part.toPath()))throw GameModException("unsafe_path","魔改库不能包含符号链接。")}
        return file
    }
}
