package app.yahagi.kancollebrowser.mods

import android.app.Activity
import android.content.Intent
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.webkit.WebResourceResponse
import app.yahagi.kancollebrowser.browser.GameModApplyCoordinator
import app.yahagi.kancollebrowser.browser.GameModPagePresence
import app.yahagi.kancollebrowser.browser.PreparedGameFrameReloadBridgePort
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.UUID
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Android document selection and Flutter control plane; interception stays entirely native. */
internal class GameModManager(
    private val activity: Activity,
    private val reloadBridge: PreparedGameFrameReloadBridgePort,
    private val onStateChanged: () -> Unit,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/mod_manager"
        const val PICK_ZIP_REQUEST = 0x594d
        const val PICK_LIBRARY_REQUEST = 0x594e

        // Retained native WebViews and in-flight streams can outlive an Activity.
        // Keep one repository per private root so their snapshots and leases stay coherent.
        private val repositories = mutableMapOf<String, GameModRepository>()
        private val progressReporters = mutableMapOf<String, GameModProgress>()
        @Synchronized private fun progressFor(root: File): GameModProgress =
            progressReporters.getOrPut(root.absolutePath) { GameModProgress() }
        @Synchronized private fun repositoryFor(root: File): GameModRepository =
            repositories.getOrPut(root.absolutePath) { GameModRepository(root, progressFor(root)) }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val mutations = Mutex()
    private val progress = progressFor(File(activity.applicationContext.filesDir, "mod_manager"))
    private val ready = CountDownLatch(1)
    private val replies = mutableSetOf<Reply>()
    private var picker: Reply? = null
    private var pickerRequest = 0
    private var disposed = false
    @Volatile private var repository: GameModRepository? = null
    @Volatile private var initializationFailed = false
    private val libraryPreferences = activity.applicationContext.getSharedPreferences("game_mod_library", Context.MODE_PRIVATE)
    @Volatile private var documentStore: GameModDocumentLibraryStore? = null
    @Volatile private var libraryCoordinator: GameModLibraryCoordinator? = null
    @Volatile private var libraryError: String? = null
    @Volatile private var defaultMigrationWarning: String? = null
    private val coordinateEndpoint = GameModCoordinateEndpoint(
        snapshot = { if (disposed || initializationFailed || ready.count != 0L) null else repository?.activeCoordinateSnapshot() },
        record = { session, token, ids, failure ->
            if (!disposed && !initializationFailed && ready.count == 0L) {
                repository?.recordCoordinateResult(session, token, ids, failure)
            }
        },
    )
    private val initialization = scope.async(Dispatchers.IO) {
        try {
            repositoryFor(File(activity.applicationContext.filesDir, "mod_manager")).also { repo ->
                repository = repo
                ready.countDown()
                // A lost public-folder grant must never prevent loading the last working game resources.
                try { loadLibrary(repo) } catch (error: Exception) { libraryError = libraryFailure(error) }
            }
        } catch (error: Exception) {
            initializationFailed = true
            throw error
        } finally {
            ready.countDown()
        }
    }

    init {
        scope.launch {
            runCatching { initialization.await() }
            if (!disposed) onStateChanged()
        }
    }

    private fun supported() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && reloadBridge.isSupported()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val reply = Reply(result).also { replies.add(it) }
        if (disposed) { reply.error("activity_destroyed", "The activity is no longer available"); return }
        if (call.method == "capabilities") {
            reply.success(mapOf("supported" to supported(), "reason" to if (supported()) "" else "unsupported_platform"))
            return
        }
        if (!supported()) { reply.error("unsupported_platform", "Mod resources require a supported Android WebView"); return }
        when (call.method) {
            "pickAndPreflightArchive" -> pickArchive(reply)
            "chooseLibraryDirectory" -> chooseLibrary(reply)
            "openLibraryDirectory" -> openLibrary(reply)
            "operationProgress" -> reply.success(progress.snapshot())
            "scanLibrary" -> runIo(reply, progressOperation = "scan") { requireLibrary().scan().also { libraryError = null } }
            "commitLibraryScan" -> runIo(reply, progressOperation = "import") { requireLibrary().commitScan(argument(call, "token")); null }
            "discardLibraryScan" -> runIo(reply) { libraryCoordinator?.discardScan(argument(call, "token")); null }
            "status" -> runIo(reply, notifyStateChange = false) { status() + mapOf("supported" to true, "library" to libraryStatus()) }
            "portraitSnapshot" -> runReadIo(reply) { portraitSnapshot() }
            "readPortrait" -> runReadIo(reply) {
                val arguments = call.arguments as? Map<*, *>
                val token = arguments?.get("token") as? String
                val resourceId = arguments?.get("resourceId") as? String
                if (token == null || resourceId == null) null else readPortrait(token, resourceId)
            }
            "commitImport" -> runIo(reply, progressOperation = "import") { requireLibrary().commitImport(argument(call, "token")) }
            "discardImport" -> runIo(reply) { discardImport(argument(call, "token")); null }
            "saveDraft" -> runIo(reply) {
                saveDraft(call.argument<Map<*, *>>("config") ?: throw GameModException("invalid_config", "Missing configuration"))
                null
            }
            "cancelChanges" -> runIo(reply) { cancelChanges(); null }
            "removePackage" -> runIo(reply) { removePackage(argument(call, "id")); null }
            "resetAll" -> runIo(reply) { resetAll(); null }
            "applyAndReload" -> applyAndReload(reply)
            else -> reply.notImplemented()
        }
    }

    private fun argument(call: MethodCall, name: String) =
        call.argument<String>(name)?.takeIf { it.isNotEmpty() }
            ?: throw GameModException("invalid_argument", "Missing $name")

    private fun runIo(reply: Reply, notifyStateChange: Boolean = true, progressOperation: String? = null, operation: GameModRepository.() -> Any?) {
        scope.launch {
            try {
                val value = mutations.withLock {
                    val repo = initialization.await()
                    val operationId = progressOperation?.let(progress::begin)
                    try {
                        withContext(Dispatchers.IO) {
                            if (operationId == null) operation(repo)
                            else progress.withOperation(operationId) { operation(repo) }
                        }
                    }
                    finally { operationId?.let(progress::finish) }
                }
                if (notifyStateChange) onStateChanged()
                reply.success(value)
            } catch (error: Exception) { reply.failure(error) }
        }
    }

    /** Read-only portrait calls must not emit state events or wait for a reload transaction. */
    private fun runReadIo(reply: Reply, operation: GameModRepository.() -> Any?) {
        scope.launch {
            try {
                val repo = initialization.await()
                reply.success(withContext(Dispatchers.IO) { operation(repo) })
            } catch (error: Exception) { reply.failure(error) }
        }
    }

    fun portraitToken(): String? = repository?.portraitToken()

    private fun coordinatorFor(repo: GameModRepository, store: GameModDocumentLibraryStore): GameModLibraryCoordinator {
        val key = UUID.nameUUIDFromBytes(store.identity.toByteArray(Charsets.UTF_8)).toString()
        val core = GameModLibrary(store, File(activity.cacheDir, "mod_library_scans/$key"), progress)
        return GameModLibraryCoordinator(repo, core, File(activity.filesDir, "mod_library_sync/$key"), progress)
    }

    private fun loadLibrary(repo: GameModRepository) {
        var uri = libraryPreferences.getString("treeUri", null)?.let(Uri::parse) ?: return
        var root = libraryPreferences.getString("rootDocumentId", null) ?: DocumentsContract.getTreeDocumentId(uri)
        val recoveryTree = migrationParentTree(uri, root)
        val target = GameModLibraryDirectoryPolicy.legacyDefaultTarget(uri.authority.orEmpty(), root)
        // A provider rename can succeed before the preference commit. Recover its durable
        // receipt before constructing a store at the now-missing old document ID.
        if (target != null && libraryPreferences.getString("pendingDefaultRoot", null) == target && recoveryTree != null &&
            !GameModDocumentLibraryStore.documentExists(activity.contentResolver, recoveryTree, root)) {
            val recovered = GameModLibraryDefaultMigration.migrate(uri.authority.orEmpty(), root, true, target,
                defaultMigrationAccess(recoveryTree))
            defaultMigrationWarning = recovered.warning
            root = recovered.rootDocumentId
            if (root == target) uri = recoveryTree
        }
        val store = GameModDocumentLibraryStore(activity.contentResolver, uri, root)
        documentStore = store
        verifyLibraryAccess(store)
        libraryCoordinator = coordinatorFor(repo, store)
        libraryCoordinator?.migrateExisting()
        migrateDefaultLibrary(repo)
    }

    private fun migrationParentTree(current: Uri, root: String): Uri? {
        val parent = root.substringBeforeLast('/', "")
        val permissions = activity.contentResolver.persistedUriPermissions.filter { it.isReadPermission && it.isWritePermission }
        val preferred = libraryPreferences.getString("pendingDefaultTreeUri", null)?.let(Uri::parse)
        return (listOfNotNull(preferred, current) + permissions.map { it.uri }).distinct().firstOrNull { candidate ->
            candidate.authority == current.authority && permissions.any { it.uri == candidate } && runCatching {
                val granted = DocumentsContract.getTreeDocumentId(candidate)
                parent == granted || parent.startsWith("$granted/")
            }.getOrDefault(false)
        }
    }

    private fun defaultMigrationAccess(tree: Uri): GameModDefaultMigrationAccess {
        val oldTree = libraryPreferences.getString("treeUri", null)
        val oldRoot = libraryPreferences.getString("rootDocumentId", null)
        return object : GameModDefaultMigrationAccess {
            override fun exists(documentId: String) = GameModDocumentLibraryStore.documentExists(activity.contentResolver, tree, documentId)
            override fun rename(documentId: String, name: String) = GameModDocumentLibraryStore.renameRoot(activity.contentResolver, tree, documentId, name)
            override fun recordIntent(targetId: String): Boolean {
                val saved = libraryPreferences.edit().putString("pendingDefaultRoot", targetId)
                    .putString("pendingDefaultTreeUri", tree.toString()).commit()
                if (!saved) libraryPreferences.edit().remove("pendingDefaultRoot").remove("pendingDefaultTreeUri").apply()
                return saved
            }
            override fun saveRoot(targetId: String): Boolean {
                val saved = libraryPreferences.edit().putString("treeUri", tree.toString()).putString("rootDocumentId", targetId)
                    .remove("pendingDefaultRoot").remove("pendingDefaultTreeUri").commit()
                if (!saved) {
                    // commit(false) can still change the process-local SharedPreferences cache.
                    libraryPreferences.edit().putString("treeUri", oldTree).putString("rootDocumentId", oldRoot)
                        .putString("pendingDefaultRoot", targetId).putString("pendingDefaultTreeUri", tree.toString()).apply()
                }
                return saved
            }
            override fun clearIntent() { libraryPreferences.edit().remove("pendingDefaultRoot").remove("pendingDefaultTreeUri").commit() }
        }
    }

    private fun migrateDefaultLibrary(repo: GameModRepository) {
        val store = documentStore ?: return
        if (GameModLibraryDirectoryPolicy.legacyDefaultTarget(store.treeUri.authority.orEmpty(), store.rootDocumentId) == null) return
        // The old public journal must finish against the old root before the rename.
        libraryCoordinator?.migrateExisting()
        val parentTree = migrationParentTree(store.treeUri, store.rootDocumentId)
        val result = GameModLibraryDefaultMigration.migrate(store.treeUri.authority.orEmpty(), store.rootDocumentId,
            parentTree != null, libraryPreferences.getString("pendingDefaultRoot", null), defaultMigrationAccess(parentTree ?: store.treeUri))
        defaultMigrationWarning = result.warning
        if (result.rootDocumentId == store.rootDocumentId) return
        val nextStore = GameModDocumentLibraryStore(activity.contentResolver, checkNotNull(parentTree), result.rootDocumentId)
        verifyLibraryAccess(nextStore)
        libraryCoordinator?.dispose()
        documentStore = nextStore
        libraryCoordinator = coordinatorFor(repo, nextStore)
        libraryCoordinator?.migrateExisting()
    }

    private fun verifyLibraryAccess(store: GameModDocumentLibraryStore) {
        val granted = activity.contentResolver.persistedUriPermissions.any {
            it.uri == store.treeUri && it.isReadPermission && it.isWritePermission
        }
        if (!granted) throw GameModException("library_permission_lost", "Choose the same Documents folder again to authorize access")
        store.list("")
    }

    private fun requireLibrary(): GameModLibraryCoordinator {
        val store = documentStore ?: throw GameModException("library_not_configured", "Choose a local mod folder first")
        try { verifyLibraryAccess(store) } catch (error: Exception) {
            libraryError = libraryFailure(error)
            throw GameModException(checkNotNull(libraryError), "The mod folder is not available; choose it again")
        }
        return libraryCoordinator ?: throw GameModException("library_unavailable", "The mod folder is not ready")
    }

    private fun libraryStatus(): Map<String, Any?> {
        val configured = libraryPreferences.contains("treeUri")
        val fallback = mapOf("configured" to configured, "available" to false,
            "displayName" to documentStore?.displayName, "uri" to libraryPreferences.getString("treeUri", null),
            "error" to (libraryError ?: defaultMigrationWarning), "packageCount" to 0)
        if (!configured) return fallback
        return try {
            val value = requireLibrary().status()
            value + mapOf("uri" to documentStore?.rootUri.toString(), "error" to (libraryError ?: defaultMigrationWarning ?: value["error"]))
        } catch (error: Exception) { fallback + ("error" to (libraryError ?: libraryFailure(error))) }
    }

    private fun libraryFailure(error: Exception): String = when (error) {
        is GameModException -> error.code
        is SecurityException -> "library_permission_lost"
        else -> "library_unavailable"
    }

    @Suppress("DEPRECATION")
    private fun chooseLibrary(reply: Reply) {
        if (picker != null) { reply.error("busy", "A document selection is already open"); return }
        picker = reply; pickerRequest = PICK_LIBRARY_REQUEST
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, documentStore?.rootUri ?: DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents", "primary:Documents"))
            }, PICK_LIBRARY_REQUEST)
        } catch (error: Exception) { picker = null; pickerRequest = 0; reply.failure(error) }
    }

    private fun openLibrary(reply: Reply) {
        scope.launch {
            try {
                val store = mutations.withLock {
                    initialization.await()
                    withContext(Dispatchers.IO) { requireLibrary(); checkNotNull(documentStore) }
                }
                activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(store.rootUri, DocumentsContract.Document.MIME_TYPE_DIR)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                })
                reply.success(null)
            } catch (_: Exception) { reply.error("library_open_failed", "The file manager could not open this folder") }
        }
    }

    @Suppress("DEPRECATION")
    private fun pickArchive(reply: Reply) {
        if (picker != null) { reply.error("busy", "A document selection is already open"); return }
        picker = reply
        pickerRequest = PICK_ZIP_REQUEST
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream"))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }, PICK_ZIP_REQUEST)
        } catch (error: Exception) {
            picker = null
            pickerRequest = 0
            reply.failure(error)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_ZIP_REQUEST && requestCode != PICK_LIBRARY_REQUEST) return false
        if (requestCode != pickerRequest) return true
        val reply = picker ?: return true
        picker = null
        pickerRequest = 0
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { reply.success(if (requestCode == PICK_LIBRARY_REQUEST) false else null); return true }
        if (requestCode == PICK_LIBRARY_REQUEST) {
            runIo(reply, progressOperation = "directory") {
                val permissions = (data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION))
                if (permissions != (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)) {
                    throw GameModException("library_permission_denied", "Read and write access to the mod folder is required")
                }
                GameModLibraryDirectoryPolicy.selectDocumentId(uri.authority.orEmpty(), DocumentsContract.getTreeDocumentId(uri))
                activity.contentResolver.takePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
                // Finish the previous root's journal before another same-identity default
                // can be opened. Rebind a recovered Documents grant to the old root first.
                documentStore?.let { previous ->
                    val grantedRoot = DocumentsContract.getTreeDocumentId(uri)
                    if (uri.authority == previous.treeUri.authority &&
                        (previous.rootDocumentId == grantedRoot || previous.rootDocumentId.startsWith("$grantedRoot/"))) {
                        libraryCoordinator?.dispose()
                        documentStore = GameModDocumentLibraryStore(activity.contentResolver, uri, previous.rootDocumentId)
                        libraryCoordinator = coordinatorFor(this, checkNotNull(documentStore))
                    }
                    libraryCoordinator?.retryPending()
                    (libraryCoordinator?.status()?.get("error") as? String)?.let { code ->
                        throw GameModException(code, "Finish synchronizing the previous mod folder first")
                    }
                }
                val store = GameModDocumentLibraryStore.selected(activity.contentResolver, uri)
                val next = coordinatorFor(this, store)
                next.migrateExisting()
                if (!libraryPreferences.edit().putString("treeUri", uri.toString()).putString("rootDocumentId", store.rootDocumentId).commit()) {
                    throw GameModException("library_write_failed", "Cannot save the mod folder authorization")
                }
                libraryCoordinator?.dispose()
                documentStore = store; libraryCoordinator = next; libraryError = null; defaultMigrationWarning = null
                migrateDefaultLibrary(this)
                true
            }
            return true
        }
        runIo(reply, progressOperation = "import") {
            requireLibrary()
            val resolver = activity.contentResolver
            val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0)?.take(240) else null
            } ?: "cache.zip"
            progress.startPackage("read", name, 0, 1)
            resolver.openInputStream(uri)?.use { preflight(it, name) }
                ?: throw GameModException("archive_unreadable", "Unable to read selected archive")
        }
        return true
    }

    private fun applyAndReload(reply: Reply) {
        scope.launch {
            try {
                mutations.withLock {
                    val repo = initialization.await()
                    var prepared: GameModApplyToken? = null
                    var published = false
                    var rollbackRequested = false
                    var outcome: String? = null
                    var removedIds: List<String> = emptyList()
                    try {
                        withContext(Dispatchers.IO) {
                            removedIds = (repo.status()["packages"] as? List<*>).orEmpty().mapNotNull {
                                val entry = it as? Map<*, *>
                                (entry?.get("id") as? String)?.takeIf { entry["pendingRemoval"] == true }
                            }
                            // Every published setup must have a usable persistent backup destination.
                            if (libraryPreferences.contains("treeUri")) requireLibrary()
                            prepared = repo.prepareApply()
                        }
                        val token = checkNotNull(prepared)
                        val coordinator = GameModApplyCoordinator(
                            applyConfig = {
                                repo.publishApply(token)
                                published = true
                                onStateChanged()
                                token
                            },
                            rollback = { rollbackRequested = true },
                            finish = {},
                            requestReload = reloadBridge::reloadPrepared,
                        )
                        outcome = suspendCancellableCoroutine<String> { continuation ->
                            coordinator.apply(reloadBridge.gamePagePresence() != GameModPagePresence.ABSENT) { value ->
                                if (continuation.isActive) continuation.resumeWith(Result.success(value))
                            }
                        }
                    } finally {
                        // Complete file cleanup even if the Activity is destroyed during a reload.
                        // A published request may already have reached the frame, so cancellation
                        // alone must not restore an old snapshot underneath that new page.
                        prepared?.let { token -> withContext(NonCancellable + Dispatchers.IO) {
                            when {
                                rollbackRequested -> repo.rollbackApply(token)
                                published -> {
                                    val library = libraryCoordinator
                                    var journaled = library == null
                                    try {
                                        library?.journalApplied(removedIds)
                                        journaled = true
                                    } catch (_: Exception) { libraryError = "library_backup_pending" }
                                    if (journaled) {
                                        // Keep deletion intent durable before removing its private metadata.
                                        repo.finishApply(token)
                                        library?.retryPending()
                                    } else {
                                        repo.deferApplyCleanup(token)
                                    }
                                }
                                else -> repo.cancelPreparedApply(token)
                            }
                        } }
                        if (!disposed) onStateChanged()
                    }
                    reply.success(mapOf("result" to outcome))
                }
            } catch (error: Exception) { reply.failure(error) }
        }
    }

    fun intercept(url: String, method: String, headers: Map<String, String>): WebResourceResponse? {
        if (!url.contains(".kancolle-server.com")) return null
        // Only the first startup request may wait for the independent native state load.
        val initialized = ready.await(5, TimeUnit.SECONDS) && !initializationFailed && !disposed
        val response = coordinateEndpoint.open(url, method)
            ?: (if (initialized) repository?.openResource(url, method, headers) else null)
            ?: return null
        return response.toWebResourceResponse()
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        picker = null
        replies.toList().forEach { it.error("activity_destroyed", "The operation was cancelled") }
        scope.cancel()
        ready.countDown()
    }

    private inner class Reply(private val result: MethodChannel.Result) {
        private val completed = AtomicBoolean(false)
        private fun complete(action: () -> Unit) {
            if (!completed.compareAndSet(false, true)) return
            replies.remove(this)
            action()
        }
        fun success(value: Any?) = complete { result.success(value) }
        fun error(code: String, message: String?) = complete { result.error(code, message, null) }
        fun notImplemented() = complete { result.notImplemented() }
        fun failure(error: Exception) = when (error) {
            is GameModException -> error(error.code, error.message)
            is CancellationException -> error("operation_cancelled", "The operation was cancelled")
            else -> error("mod_operation_failed", "Unable to complete mod operation")
        }
    }
}
