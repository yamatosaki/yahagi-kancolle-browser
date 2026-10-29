package app.yahagi.kancollebrowser.backup

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/** Local Documents SAF bridge. The live document is never overwritten in place. */
class RecordBackupHandler(
    private val activity: Activity,
    private val launch: (Intent, Int) -> Unit,
    private val deleteSavedDocument: (Uri) -> Boolean = {
        DocumentsContract.deleteDocument(activity.applicationContext.contentResolver, it)
    },
    private val exportStore: PendingBackupExportStore = PendingBackupExportStore(
        File(activity.filesDir, "record-backup-exports"),
    ),
    exportDocumentsOverride: PendingBackupExportStore.Documents? = null,
    private val exportTimeoutMillis: Long = 60_000,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/record_backup"
        const val DIRECTORY_REQUEST = 2410
        const val IMPORT_REQUEST = 2411
        const val SAVE_REQUEST = PendingBackupExportStore.FIRST_PICKER_REQUEST
        private const val PREFS = "record_backup_documents"
        private const val MAX_BYTES = 100 * 1024 * 1024
        // Export recovery must never queue ahead of automatic backup I/O. Keep
        // this executor alive when its initiating Activity is destroyed.
        private val exportWorker = BackupExportExecutor()
        private val exportRecoveryWorker = BackupExportExecutor(maxConcurrent = 1)
    }

    private val resolver get() = activity.contentResolver
    private val prefs get() = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val worker = Executors.newSingleThreadExecutor()
    private var pickerResult: MethodChannel.Result? = null
    private var pickerRequestCode: Int? = null
    @Volatile private var disposed = false
    private val saveResults = ConcurrentHashMap.newKeySet<MethodChannel.Result>()
    private val exportResolver = activity.applicationContext.contentResolver
    private val exportDocuments = exportDocumentsOverride ?: object : PendingBackupExportStore.Documents {
        override fun write(uri: String, source: File) {
            // rwt truncates an earlier interrupted write. A provider that cannot
            // support this mode fails safely and leaves a retryable cleanup.
            exportResolver.openOutputStream(Uri.parse(uri), "rwt")?.use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
                output.flush()
            } ?: error("Unable to save backup")
        }
        override fun matches(uri: String, source: File): Boolean {
            val input = exportResolver.openInputStream(Uri.parse(uri))
                ?: error("Unable to read saved backup for verification")
            return input.use { actual ->
                source.inputStream().use expectedStream@ { expected ->
                    val buffer = ByteArray(8192)
                    val other = ByteArray(8192)
                    while (true) {
                        val count = expected.read(buffer)
                        if (count < 0) return@expectedStream actual.read() < 0
                        var offset = 0
                        while (offset < count) {
                            val read = actual.read(other, offset, count - offset)
                            if (read < 0) return@expectedStream false
                            offset += read
                        }
                        for (index in 0 until count) {
                            if (buffer[index] != other[index]) return@expectedStream false
                        }
                    }
                    @Suppress("UNREACHABLE_CODE") false
                }
            }
        }
        override fun delete(uri: String): Boolean = deleteSavedDocument(Uri.parse(uri))
    }
    private data class ShareTarget(val token: String, val file: File)
    @Volatile private var shareTarget: ShareTarget? = null

    init {
        exportRecoveryWorker.execute {
            exportStore.recover(exportDocuments, ::releaseExportPermission)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("activity_destroyed", "Activity was closed", null)
            return
        }
        when (call.method) {
            "hasDirectory" -> result.success(directory() != null)
            "chooseDirectory" -> chooseDirectory(result)
            "pickImport" -> pickImport(result)
            "saveFile" -> saveFile(call, result)
            "launchShareFile" -> {
                try {
                    val target = requireShareTarget(call)
                    shareExport(target.file)
                    shareTarget = null
                    result.success(target.file.name)
                } catch (error: Throwable) {
                    result.error("backup_share_failed", error.message ?: "Cannot share backup", null)
                }
            }
            "discardShareFile" -> worker.execute {
                try {
                    val target = requireShareTarget(call)
                    try {
                        require(target.file.parentFile?.deleteRecursively() == true) {
                            "Unable to remove unshared backup"
                        }
                    } finally {
                        shareTarget = null
                    }
                    activity.runOnUiThread { result.success(null) }
                } catch (error: Throwable) {
                    activity.runOnUiThread {
                        result.error("backup_share_failed", error.message ?: "Cannot discard share", null)
                    }
                }
            }
            "completeSavedFile", "discardSavedFile" -> {
                saveResults.add(result)
                executeExport(result) {
                try {
                    val token = requireExportToken(call)
                    val entry = exportStore.get(token)
                    if (call.method == "completeSavedFile") {
                        // A recreated caller may acknowledge while recovery is
                        // still writing. The transaction lock serializes both.
                        if (entry != null && !entry.verified) {
                            exportStore.writeAndVerify(token, exportDocuments)
                        }
                        exportStore.complete(token)
                    } else {
                        require(exportStore.discard(token, exportDocuments)) {
                            "Unable to remove canceled export; cleanup will retry"
                        }
                    }
                    releaseExportPermission(entry)
                    saveSuccess(result, null)
                } catch (error: Throwable) {
                    saveError(result, error)
                }
                }
            }
            "readCandidate", "promoteCandidate", "writeLive", "prepareShareFile" -> worker.execute {
                try {
                    val response: Any? = when (call.method) {
                        "readCandidate" -> readCandidate(
                            requireMember(call), requireName(call), requireSlot(call),
                        )
                        "promoteCandidate" -> {
                            promoteCandidate(
                                requireMember(call), requireName(call),
                                requireSlot(call), requireBytes(call),
                            )
                            null
                        }
                        "writeLive" -> {
                            writeLive(requireMember(call), requireName(call), requireBytes(call))
                            null
                        }
                        else -> prepareShareFile(requireName(call), requireBytes(call))
                    }
                    activity.runOnUiThread {
                        try {
                            if (call.method == "prepareShareFile") {
                                val file = response as File
                                if (shareTarget != null) {
                                    file.parentFile?.deleteRecursively()
                                    error("A share is already prepared")
                                }
                                val target = ShareTarget(UUID.randomUUID().toString(), file)
                                shareTarget = target
                                result.success(target.token)
                            } else {
                                result.success(response)
                            }
                        } catch (error: Throwable) {
                            result.error("backup_share_failed", error.message ?: "Cannot share backup", null)
                        }
                    }
                } catch (error: Throwable) {
                    activity.runOnUiThread {
                        result.error("backup_io_failed", error.message ?: "Document I/O failed", null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun requireMember(call: MethodCall): Int =
        (call.argument<Number>("memberId")?.toInt() ?: 0).also {
            require(it > 0) { "Game account is unknown" }
        }

    private fun requireName(call: MethodCall): String =
        (call.argument<String>("name") ?: "").also {
            require(it.endsWith(".yhb") && it.length < 180 &&
                !it.contains('/') && !it.contains('\\')) { "Invalid backup name" }
        }

    private fun requireBytes(call: MethodCall): ByteArray =
        (call.argument<ByteArray>("bytes") ?: error("Missing backup data")).also {
            require(it.size <= MAX_BYTES) { "Backup is too large" }
        }

    private fun requireSlot(call: MethodCall): String =
        (call.argument<String>("slot") ?: "").also {
            require(it == "pending" || it == "main" || it == "previous") {
                "Invalid backup copy"
            }
        }

    private fun chooseDirectory(result: MethodChannel.Result) {
        if (pickerResult != null) {
            result.error("picker_busy", "Document picker is already open", null)
            return
        }
        pickerResult = result
        pickerRequestCode = DIRECTORY_REQUEST
        val initial = DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents", "primary:Documents",
        )
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, initial)
            }
        }
        launch(intent, DIRECTORY_REQUEST)
    }

    private fun pickImport(result: MethodChannel.Result) {
        if (pickerResult != null) {
            result.error("picker_busy", "Document picker is already open", null)
            return
        }
        pickerResult = result
        pickerRequestCode = IMPORT_REQUEST
        launch(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, IMPORT_REQUEST)
    }

    private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
        if (pickerResult != null) {
            result.error("picker_busy", "Document picker is already open", null)
            return
        }
        saveResults.add(result)
        try {
            val name = requireName(call)
            val bytes = requireBytes(call)
            require(bytes.isNotEmpty()) { "Backup is empty" }
            pickerResult = result
            // No actual request identity exists until durable staging finishes.
            pickerRequestCode = null
            executeExport(result) {
                try {
                    val entry = exportStore.stage(name, bytes)
                    activity.runOnUiThread {
                        if (disposed || !saveResults.contains(result)) {
                            executeExport { exportStore.cancelPicker(entry.token) }
                            return@runOnUiThread
                        }
                        try {
                            pickerRequestCode = entry.requestCode
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/octet-stream"
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                                putExtra(Intent.EXTRA_TITLE, name)
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                                        DocumentsContract.buildDocumentUri(
                                            "com.android.externalstorage.documents", "primary:Documents",
                                        ))
                                }
                            }
                            launch(intent, entry.requestCode)
                        } catch (error: Throwable) {
                            pickerResult = null
                            pickerRequestCode = null
                            executeExport { exportStore.cancelPicker(entry.token) }
                            saveError(result, error)
                        }
                    }
                } catch (error: Throwable) {
                    activity.runOnUiThread {
                        if (pickerResult === result) {
                            pickerResult = null
                            pickerRequestCode = null
                        }
                        saveError(result, error)
                    }
                }
            }
        } catch (error: Throwable) {
            saveError(result, error)
        }
    }

    private fun requireExportToken(call: MethodCall): String =
        call.argument<String>("token") ?: error("Missing export token")

    private fun executeExport(result: MethodChannel.Result? = null, work: () -> Unit) {
        exportWorker.execute(timeoutMillis = exportTimeoutMillis, onFailure = { error ->
            activity.runOnUiThread {
                // Staging has already returned and the picker is waiting for
                // the user. A racing staging deadline must not dismiss it.
                if (result != null && pickerResult === result && pickerRequestCode != null) {
                    return@runOnUiThread
                }
                if (result != null && pickerResult === result) {
                    pickerResult = null
                    pickerRequestCode = null
                }
                saveError(result, error)
            }
        }, work = work)
    }

    private fun saveSuccess(result: MethodChannel.Result?, value: Any?) {
        if (result == null || !saveResults.remove(result)) return
        activity.runOnUiThread { runCatching { result.success(value) } }
    }

    private fun saveError(result: MethodChannel.Result?, error: Throwable) {
        if (result == null || !saveResults.remove(result)) return
        activity.runOnUiThread {
            runCatching { result.error("backup_save_failed", error.message ?: "Cannot save backup", null) }
        }
    }

    private fun releaseExportPermission(entry: PendingBackupExportStore.Entry?) {
        if (entry?.uri == null || entry.grantFlags == 0) return
        runCatching {
            exportResolver.releasePersistableUriPermission(Uri.parse(entry.uri), entry.grantFlags)
        }
    }

    private fun requireShareTarget(call: MethodCall): ShareTarget {
        val token = call.argument<String>("token") ?: error("Missing share file")
        return shareTarget?.takeIf { it.token == token }
            ?: error("Share file is no longer available")
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (isSaveRequest(requestCode)) {
            handleSaveResult(requestCode, resultCode, data)
            return true
        }
        if (requestCode != DIRECTORY_REQUEST && requestCode != IMPORT_REQUEST) return false
        if (pickerRequestCode != requestCode) return true
        val result = pickerResult ?: return true
        pickerResult = null
        pickerRequestCode = null
        val uri = data?.data?.takeIf { resultCode == Activity.RESULT_OK }
        if (uri == null) {
            result.success(if (requestCode == DIRECTORY_REQUEST) false else null)
            return true
        }
        if (requestCode == DIRECTORY_REQUEST) {
            try {
                val id = DocumentsContract.getTreeDocumentId(uri)
                val path = id.substringAfter(':', "")
                require(uri.authority == "com.android.externalstorage.documents" &&
                    (path == Environment.DIRECTORY_DOCUMENTS ||
                        path.startsWith("${Environment.DIRECTORY_DOCUMENTS}/"))) {
                    "请选择本机文档文件夹或其子文件夹"
                }
                resolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
                val previous = directory()
                worker.execute {
                    try {
                        if (previous != null && previous != uri) {
                            migrateBackupDocuments(previous, uri)
                        }
                        // Keep member-to-filename mappings for every account. A folder
                        // change must not strand another account's live backup.
                        require(prefs.edit().putString("tree", uri.toString()).commit()) {
                            "Unable to save backup folder"
                        }
                        activity.runOnUiThread { result.success(true) }
                    } catch (error: Throwable) {
                        activity.runOnUiThread {
                            result.error("backup_migration_failed", error.message, null)
                        }
                    }
                }
            } catch (error: Throwable) {
                result.error("invalid_backup_directory", error.message, null)
            }
            return true
        }
        worker.execute {
            try {
                val bytes = readDocument(uri)
                activity.runOnUiThread { result.success(bytes) }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    result.error("backup_import_failed", error.message, null)
                }
            }
        }
        return true
    }

    private fun isSaveRequest(requestCode: Int): Boolean = requestCode in
        PendingBackupExportStore.FIRST_PICKER_REQUEST..PendingBackupExportStore.LAST_PICKER_REQUEST

    private fun handleSaveResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Every picker gets a durable request identity. An old OK/CANCELED
        // callback must never attach its URI to a newer export's stage.
        val entry = exportStore.forPicker(requestCode) ?: return
        if (entry.uri != null) return
        val result = pickerResult.takeIf { pickerRequestCode == requestCode }
        if (pickerRequestCode == requestCode) {
            pickerResult = null
            pickerRequestCode = null
        }
        // A replacement Activity has no Dart Result, but the durable stage still
        // identifies the outstanding picker and must receive its target URI.
        val token = entry.token
        val uri = data?.data?.takeIf { resultCode == Activity.RESULT_OK }
        if (uri == null) {
            executeExport(result) {
                try {
                    exportStore.cancelPicker(token)
                    saveSuccess(result, null)
                } catch (error: Throwable) { saveError(result, error) }
            }
            return
        }
        val resultFlags = data.flags
        val flags = (resultFlags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
        try {
            // Persist the URI before queuing provider I/O; a kill immediately
            // after picker return can then be recovered on the next process.
            exportStore.select(token, uri.toString(), flags)
            if (resultFlags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0 && flags != 0) {
                runCatching {
                    // Pass only the permission bits the picker actually granted.
                    when (flags) {
                        Intent.FLAG_GRANT_READ_URI_PERMISSION -> exportResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION -> exportResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        else -> exportResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    }
                }
            }
            executeExport(result) {
                try {
                    exportStore.writeAndVerify(token, exportDocuments)
                    if (result == null || !saveResults.contains(result)) {
                        releaseExportPermission(exportStore.get(token))
                    }
                    saveSuccess(result, token)
                } catch (error: Throwable) {
                    runCatching { exportStore.discardIncomplete(token, exportDocuments) }
                    val current = exportStore.get(token)
                    if (current == null) releaseExportPermission(
                        entry.copy(uri = uri.toString(), grantFlags = flags),
                    )
                    if (current?.verified == true) {
                        if (result == null || !saveResults.contains(result)) releaseExportPermission(current)
                        saveSuccess(result, token)
                    } else saveError(result, error)
                }
            }
        } catch (error: Throwable) {
            executeExport {
                runCatching { exportStore.discardIncomplete(token, exportDocuments) }
                if (exportStore.get(token) == null) releaseExportPermission(
                    entry.copy(uri = uri.toString(), grantFlags = flags),
                )
            }
            saveError(result, error)
        }
    }

    private fun directory(): Uri? {
        val uri = prefs.getString("tree", null)?.let(Uri::parse) ?: return null
        val granted = resolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
        return uri.takeIf { granted }
    }

    private fun tree(): Uri = directory() ?: error("Backup folder is unavailable")

    private fun rootDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))

    private fun readDocument(uri: Uri): ByteArray {
        val input = resolver.openInputStream(uri) ?: error("Unable to read backup")
        return input.use { stream ->
            val output = java.io.ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            while (true) {
                val count = stream.read(chunk)
                if (count < 0) break
                require(output.size() + count <= MAX_BYTES) { "Backup is too large" }
                output.write(chunk, 0, count)
            }
            output.toByteArray()
        }
    }

    private fun documentMatches(uri: Uri, expected: ByteArray): Boolean =
        (resolver.openInputStream(uri) ?: error("Unable to read backup")).use { input ->
            BackupDocumentReadback.matches(input, expected)
        }

    private fun backupDocuments(tree: Uri): List<Pair<String, Uri>> {
        val id = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
        val found = mutableListOf<Pair<String, Uri>>()
        (resolver.query(
            children,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, OpenableColumns.DISPLAY_NAME),
            null, null, null,
        ) ?: error("Unable to enumerate backup documents")).use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameColumn)
                if (name.endsWith(".yhb") || name.endsWith(".yhb.previous") ||
                    name.endsWith(".yhb.pending")) {
                    found.add(name to DocumentsContract.buildDocumentUriUsingTree(
                        tree, cursor.getString(idColumn),
                    ))
                }
            }
        }
        return found
    }

    private fun migrateBackupDocuments(from: Uri, to: Uri) {
        // Source documents are read only. A conflicting destination is left
        // untouched and the selected folder is not switched.
        for ((name, source) in backupDocuments(from)) {
            val bytes = readDocument(source)
            val existing = find(to, name)
            if (existing != null) {
                require(documentMatches(existing, bytes)) {
                    "The new folder already contains a different $name"
                }
                continue
            }
            val created = DocumentsContract.createDocument(
                resolver, rootDocument(to), "application/octet-stream", name,
            ) ?: error("Unable to copy $name")
            try {
                requireDocumentName(created, name)
                resolver.openOutputStream(created, "w")?.use { it.write(bytes); it.flush() }
                    ?: error("Unable to copy $name")
                require(documentMatches(created, bytes)) {
                    "Copied backup verification failed: $name"
                }
            } catch (error: Throwable) {
                runCatching { DocumentsContract.deleteDocument(resolver, created) }
                throw error
            }
        }
    }

    private fun find(tree: Uri, name: String): Uri? {
        val id = DocumentsContract.getTreeDocumentId(tree)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
        var match: Uri? = null
        (resolver.query(
            children,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, OpenableColumns.DISPLAY_NAME),
            null, null, null,
        ) ?: error("Unable to enumerate backup documents")).use { cursor ->
            val idColumn = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            while (cursor.moveToNext()) {
                if (cursor.getString(nameColumn) == name) {
                    require(match == null) { "Duplicate backup document name: $name" }
                    match = DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(idColumn))
                }
            }
        }
        return match
    }

    private fun requireDocumentName(uri: Uri, expected: String) {
        val actual = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) null else cursor.getString(
                    cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME),
                )
            }
        require(actual == expected) {
            "Backup provider renamed $expected to ${actual ?: "unknown"}"
        }
    }

    private fun archiveMemberId(bytes: ByteArray): Int? = BackupArchiveOwner.memberId(bytes)

    private fun liveName(tree: Uri, memberId: Int, suggested: String): String {
        prefs.getString("member.$memberId", null)?.let { return it }
        val stem = suggested.removeSuffix(".yhb")
        for (index in 1..1000) {
            val candidate = if (index == 1) suggested else "$stem ($index).yhb"
            val document = find(tree, candidate) ?: return candidate
            val bytes = readDocument(document)
            val owner = archiveMemberId(bytes) ?: listOf(
                "$candidate.pending", "$candidate.previous",
            ).firstNotNullOfOrNull { fallback ->
                find(tree, fallback)?.let { copy ->
                    archiveMemberId(readDocument(copy))
                }
            } ?: error("Unable to verify existing backup account")
            if (owner == memberId) {
                prefs.edit().putString("member.$memberId", candidate).apply()
                return candidate
            }
        }
        error("Too many backup files with the same name")
    }

    private fun candidateName(name: String, slot: String): String = when (slot) {
        "pending" -> "$name.pending"
        "main" -> name
        "previous" -> "$name.previous"
        else -> error("Invalid backup copy")
    }

    private fun readCandidate(memberId: Int, suggested: String, slot: String): ByteArray? {
        val tree = tree()
        val name = liveName(tree, memberId, suggested)
        val document = find(tree, candidateName(name, slot)) ?: return null
        return readDocument(document)
    }

    private fun promoteCandidate(
        memberId: Int, suggested: String, slot: String, expected: ByteArray,
    ) {
        require(slot != "main") { "Main backup needs no recovery" }
        val tree = tree()
        val name = liveName(tree, memberId, suggested)
        val candidate = find(tree, candidateName(name, slot))
            ?: error("Backup copy vanished during recovery")
        require(documentMatches(candidate, expected)) {
            "Backup copy changed during recovery"
        }
        require(archiveMemberId(expected) == memberId) {
            "Backup copy belongs to another account"
        }
        if (slot == "previous") {
            // writeLive keeps previous intact until its new pending copy has
            // been fully written and verified.
            writeLive(memberId, suggested, expected)
            return
        }
        val main = find(tree, name)
        if (main != null && documentMatches(main, expected)) {
            require(DocumentsContract.deleteDocument(resolver, candidate)) {
                "Unable to remove redundant pending backup"
            }
            return
        }
        // Never delete or rename the chosen pending copy first. If the app
        // stops between the two renames, pending remains the newest valid copy.
        find(tree, "$name.previous")?.let {
            require(DocumentsContract.deleteDocument(resolver, it)) {
                "Unable to rotate previous backup"
            }
        }
        main?.let {
            val old = DocumentsContract.renameDocument(resolver, it, "$name.previous")
                ?: error("Unable to preserve current backup")
            requireDocumentName(old, "$name.previous")
        }
        val promoted = DocumentsContract.renameDocument(resolver, candidate, name)
            ?: error("Unable to promote pending backup")
        requireDocumentName(promoted, name)
        require(documentMatches(promoted, expected)) {
            "Promoted backup verification failed"
        }
        prefs.edit().putString("member.$memberId", name).apply()
    }

    private fun writeLive(memberId: Int, suggested: String, bytes: ByteArray) {
        val tree = tree()
        val name = liveName(tree, memberId, suggested)
        // Keep a known-good document until the replacement has been written
        // and read back. Recovery can use .previous if the app stops mid-swap.
        find(tree, "$name.pending")?.let {
            require(DocumentsContract.deleteDocument(resolver, it)) {
                "Unable to remove stale pending backup"
            }
        }
        val pending = DocumentsContract.createDocument(
            resolver, rootDocument(tree), "application/octet-stream", "$name.pending",
        ) ?: error("Unable to create pending backup")
        try {
            requireDocumentName(pending, "$name.pending")
            resolver.openOutputStream(pending, "w")?.use { it.write(bytes); it.flush() }
                ?: error("Unable to write pending backup")
            require(documentMatches(pending, bytes)) {
                "Pending backup verification failed"
            }
            find(tree, "$name.previous")?.let {
                require(DocumentsContract.deleteDocument(resolver, it)) {
                    "Unable to rotate previous backup"
                }
            }
            find(tree, name)?.let { old ->
                val preserved = DocumentsContract.renameDocument(resolver, old, "$name.previous")
                    ?: error("Unable to preserve previous backup")
                requireDocumentName(preserved, "$name.previous")
            }
            val live = DocumentsContract.renameDocument(resolver, pending, name)
                ?: error("Unable to install live backup")
            requireDocumentName(live, name)
            require(documentMatches(live, bytes)) {
                "Installed live backup verification failed"
            }
            prefs.edit().putString("member.$memberId", name).apply()
        } catch (error: Throwable) {
            // Keep pending for recovery if the live document was already moved.
            throw error
        }
    }

    private fun prepareShareFile(name: String, bytes: ByteArray): File {
        return BackupShareCache.write(
            File(activity.cacheDir, "record-backup-share"), name, bytes,
        )
    }

    private fun shareExport(file: File) {
        val uri = FileProvider.getUriForFile(
            activity, "${activity.packageName}.diagnostics", file,
        )
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(resolver, file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(
            Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
        )
    }

    fun dispose() {
        disposed = true
        val pendingPicker = pickerResult
        if (pendingPicker != null && !saveResults.contains(pendingPicker)) {
            pendingPicker.error("picker_cancelled", "Activity was closed", null)
        }
        pickerResult = null
        pickerRequestCode = null
        for (result in saveResults.toList()) {
            if (saveResults.remove(result)) {
                runCatching { result.error("picker_cancelled", "Activity was closed; export continues safely", null) }
            }
        }
        // Selected targets belong to the durable transaction, not this
        // Activity. Their writes and verified documents survive disposal.
        shareTarget?.let { target ->
            worker.execute { runCatching { target.file.parentFile?.deleteRecursively() } }
            shareTarget = null
        }
        worker.shutdown()
    }
}
