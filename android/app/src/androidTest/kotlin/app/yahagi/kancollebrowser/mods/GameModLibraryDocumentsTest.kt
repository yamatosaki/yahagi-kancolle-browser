package app.yahagi.kancollebrowser.mods

import android.content.ContentResolver
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.provider.DocumentsContract
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.filters.SdkSuppress
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Uses the real external-storage DocumentsProvider, entirely below a unique test directory.
 * Supply treeUri/rootDocumentId instrumentation arguments, or authorize the app's mod folder first.
 * Missing persisted authorization is an explicit skipped test, never a successful SAF verification.
 */
@Suppress("UNCHECKED_CAST")
@RunWith(AndroidJUnit4::class)
class GameModLibraryDocumentsTest {
    private val imagePath = "kcs2/resources/ship/banner/0001_1234.png"
    private val extraPath = "kcs2/resources/ship/banner/0002_1234.png"

    @Test fun documentsReadWriteTruncateRenameAndRejectUnsafePaths() = isolated { store, _, resolver ->
        val longText = "魔改文件夹 / 伊47 / voice\n".repeat(40).toByteArray(Charsets.UTF_8)
        val shortText = "短文：吹雪".toByteArray(Charsets.UTF_8)
        store.createDirectory("多层/子目录")
        write(store, "多层/子目录/说明.txt", longText)
        assertArrayEquals(longText, read(store, "多层/子目录/说明.txt"))
        write(store, "多层/子目录/说明.txt", shortText)
        assertArrayEquals("Writing must truncate old trailing bytes", shortText, read(store, "多层/子目录/说明.txt"))
        assertEquals(shortText.size.toLong(), store.list("多层/子目录").single { it.name == "说明.txt" }.size)

        val binary = ByteArray(4096) { (it % 256).toByte() }
        write(store, "多层/子目录/二进制.bin", binary)
        assertArrayEquals(binary, read(store, "多层/子目录/二进制.bin"))
        val shorter = byteArrayOf(0, -1, 1)
        write(store, "多层/子目录/二进制.bin", shorter)
        assertArrayEquals(shorter, read(store, "多层/子目录/二进制.bin"))

        assertTrue(store.rename("多层", "重命名"))
        assertArrayEquals(shortText, read(store, "重命名/子目录/说明.txt"))
        assertEquals(setOf("说明.txt", "二进制.bin"), store.list("重命名/子目录").map { it.name }.toSet())

        // Bypass the store to mimic a user renaming a folder in the system file manager.
        val nested = document(resolver, store.treeUri, store.rootDocumentId, "重命名/子目录")
        val external = requireNotNull(DocumentsContract.renameDocument(resolver, nested, "外部改名"))
        assertTrue(DocumentsContract.getDocumentId(external).startsWith("${store.rootDocumentId}/"))
        assertArrayEquals(shortText, read(store, "重命名/外部改名/说明.txt"))
        assertEquals("外部改名", store.list("重命名").single().name)
        val missing = runCatching { store.openRead("重命名/子目录/说明.txt").close() }.exceptionOrNull()
        assertEquals("library_source_missing", (missing as? GameModException)?.code)

        val text = document(resolver, store.treeUri, store.rootDocumentId, "重命名/外部改名/说明.txt")
        assertNotNull(DocumentsContract.renameDocument(resolver, text, "外部文本.txt"))
        assertArrayEquals(shortText, read(store, "重命名/外部改名/外部文本.txt"))
        assertTrue(store.delete("重命名/外部改名/二进制.bin"))
        assertTrue(store.delete("重命名/外部改名/二进制.bin"))
        assertEquals(listOf("外部文本.txt"), store.list("重命名/外部改名").map { it.name })

        expectUnsafe { store.list("../outside") }
        expectUnsafe { store.openRead("../outside.txt").close() }
        expectUnsafe { store.openWrite("/outside.txt").close() }
        expectUnsafe { store.createDirectory("nested/../outside") }
        expectUnsafe { store.delete("") }
        expectUnsafe { store.rename("重命名", "../outside") }
        expectUnsafe { store.openWrite("nested\\outside.txt").close() }
        assertArrayEquals(shortText, read(store, "重命名/外部改名/外部文本.txt"))
        assertTrue(store.delete("重命名"))
        assertTrue(store.list().isEmpty())
        Log.i("ModLibraryDocuments", "real provider UTF-8/binary/truncate/rename/external-rename/delete/path checks: OK")
    }

    @Test fun realDocumentLibraryMigrationRestoreUpdatesAndReversibleDeletion() = isolated { parent, privateRoot, resolver ->
        repeat(2) { cycle ->
            val cycleName = "cycle-$cycle"
            parent.createDirectory(cycleName)
            val cycleUri = document(resolver, parent.treeUri, parent.rootDocumentId, cycleName)
            val sourceStore = GameModDocumentLibraryStore(resolver, parent.treeUri, DocumentsContract.getDocumentId(cycleUri))
            val original = GameModRepository(File(privateRoot, "$cycle-original"))
            val firstBytes = png(Color.rgb(90 + cycle, 20, 30))
            val oldBytes = png(Color.rgb(10, 80 + cycle, 40))
            val newBytes = png(Color.rgb(50, 30, 140 + cycle))
            val firstId = import(original, "合成A", mapOf(imagePath to firstBytes, extraPath to png(Color.BLUE)))
            val secondId = import(original, "合成B", mapOf(imagePath to oldBytes))
            val originalPackages = packages(original)
            val selectedResources = originalPackages.flatMap { pack ->
                (pack["resources"] as List<Map<String, Any?>>).filter { it["path"] == imagePath }.map { it["id"] as String }
            }
            // Preserve both an off package and an unselected resource, plus a non-import priority order.
            original.saveDraft(mapOf("master" to true, "order" to listOf(secondId, firstId),
                "enabledPackages" to listOf(secondId), "enabledResources" to selectedResources))
            original.finishApply(original.applyDraft())
            val expectedConfiguration = original.exportAppliedConfiguration()
            val sourceLibrary = GameModLibrary(sourceStore, File(privateRoot, "$cycle-library-before"))
            val sourceCoordinator = GameModLibraryCoordinator(original, sourceLibrary, File(privateRoot, "$cycle-coordinator-before"))
            val beforeMigration = original.portraitSnapshot()
            try {
                assertEquals(2, sourceCoordinator.migrateExisting())
                assertEquals(0, sourceCoordinator.migrateExisting())
                assertEquals(beforeMigration, original.portraitSnapshot())
                assertSavedSetup(expectedConfiguration, requireNotNull(sourceLibrary.appliedConfiguration()))
            } finally { sourceCoordinator.dispose() }

            // A fresh repository has no private imports/settings; restoration reads only the SAF library.
            val restored = GameModRepository(File(privateRoot, "$cycle-restored"))
            val restoredStore = GameModDocumentLibraryStore(resolver, parent.treeUri, DocumentsContract.getDocumentId(cycleUri))
            val library = GameModLibrary(restoredStore, File(privateRoot, "$cycle-library-after"))
            val coordinator = GameModLibraryCoordinator(restored, library, File(privateRoot, "$cycle-coordinator-after"))
            try {
                val restoration = coordinator.scan()
                assertEquals(true, restoration["restoreAvailable"])
                assertEquals(2, entries(restoration).count { it["kind"] == "new" })
                coordinator.commitScan(restoration["token"] as String)
                assertTrue((restored.portraitSnapshot()["resources"] as List<*>).isEmpty())
                val restoredDraft = restored.status()["draft"] as Map<*, *>
                assertEquals(listOf(secondId, firstId), restoredDraft["order"])
                assertEquals(listOf(secondId), restoredDraft["enabledPackages"])
                val restoredSelection = (restoredDraft["enabledResources"] as List<*>).toSet()
                val selectedPaths = packages(restored).associate { pack ->
                    (pack["id"] as String) to (pack["resources"] as List<Map<String, Any?>>)
                        .filter { it["id"] in restoredSelection }.map { it["path"] as String }
                }
                assertEquals(expectedConfiguration["enabledResources"], selectedPaths)
                apply(restored, coordinator)
                assertEquals(expectedConfiguration, restored.exportAppliedConfiguration())
                assertArrayEquals(oldBytes, activeImage(restored))

                val record = (library.status()["packages"] as List<Map<String, Any?>>).single { it["id"] == secondId }
                val publicImage = "${record["path"]}/$imagePath"
                write(restoredStore, publicImage, newBytes)
                val beforeUpdate = restored.portraitSnapshot()
                val discarded = coordinator.scan()
                assertEquals("updated", entries(discarded).single { it["id"] == secondId }["kind"])
                coordinator.discardScan(discarded["token"] as String)
                assertEquals(beforeUpdate, restored.portraitSnapshot())
                assertEquals(false, restored.status()["pending"])

                val update = coordinator.scan()
                coordinator.commitScan(update["token"] as String)
                assertEquals(true, restored.status()["pending"])
                assertArrayEquals(oldBytes, activeImage(restored))
                restored.cancelChanges()
                assertEquals(false, restored.status()["pending"])
                assertEquals(beforeUpdate, restored.portraitSnapshot())
                assertArrayEquals(newBytes, read(restoredStore, publicImage))

                val retry = coordinator.scan()
                assertEquals("updated", entries(retry).single { it["id"] == secondId }["kind"])
                coordinator.commitScan(retry["token"] as String)
                apply(restored, coordinator)
                assertArrayEquals(newBytes, activeImage(restored))
                assertEquals(expectedConfiguration, restored.exportAppliedConfiguration())

                repeat(2) {
                    restored.removePackage(secondId)
                    assertArrayEquals(newBytes, read(restoredStore, publicImage))
                    assertArrayEquals(newBytes, activeImage(restored))
                    restored.cancelChanges()
                    assertEquals(false, restored.status()["pending"])
                    assertEquals(expectedConfiguration, restored.exportAppliedConfiguration())
                }
                restored.resetAll()
                assertEquals(true, restored.status()["pending"])
                assertArrayEquals(newBytes, read(restoredStore, publicImage))
                restored.cancelChanges()
                assertEquals(expectedConfiguration, restored.exportAppliedConfiguration())

                restored.removePackage(secondId)
                apply(restored, coordinator)
                assertEquals(setOf(firstId), packages(restored).map { it["id"] }.toSet())
                assertTrue(restoredStore.list().none { it.name == record["path"] })
                assertNull(restored.openResource("https://w01x.kancolle-server.com/$imagePath", "GET", emptyMap()))
                val afterDelete = coordinator.scan()
                assertTrue(entries(afterDelete).none { it["id"] == secondId })
                coordinator.discardScan(afterDelete["token"] as String)

                restored.resetAll()
                apply(restored, coordinator)
                assertTrue(packages(restored).isEmpty())
                assertEquals(0, library.status()["packageCount"])
                assertEquals(emptyList<String>(), library.appliedConfiguration()!!["order"])
                val empty = coordinator.scan()
                assertTrue(entries(empty).isEmpty())
                coordinator.discardScan(empty["token"] as String)
                assertNull(coordinator.status()["error"])
                Log.i("ModLibraryDocuments", "real provider migration/restore/edit/cancel/apply/delete cycle ${cycle + 1}: OK")
            } finally { coordinator.dispose() }
        }
    }

    @Test fun zipImportKeepsExternalSourceAndConsumesOnlyConfirmedLibraryZip() = isolated { parent, privateRoot, resolver ->
        repeat(2) { cycle ->
            val libraryName = "zip-library-$cycle"
            parent.createDirectory(libraryName)
            val libraryUri = document(resolver, parent.treeUri, parent.rootDocumentId, libraryName)
            val store = GameModDocumentLibraryStore(resolver, parent.treeUri, DocumentsContract.getDocumentId(libraryUri))
            val repository = GameModRepository(File(privateRoot, "zip-repository-$cycle"))
            val library = GameModLibrary(store, File(privateRoot, "zip-library-worker-$cycle"))
            val coordinator = GameModLibraryCoordinator(repository, library, File(privateRoot, "zip-coordinator-$cycle"))
            try {
                // This ZIP is a sibling of the chosen library, mimicking the normal picker.
                // Reading the picked source does not make that file library-owned.
                val externalPath = "outside-original-$cycle.zip"
                val buttonImage = png(Color.rgb(70 + cycle, 30, 20))
                val externalZip = zipBytes(mapOf(imagePath to buttonImage))
                write(parent, externalPath, externalZip)
                val preview = parent.openRead(externalPath).use { repository.preflight(it, externalPath) }
                val imported = coordinator.commitImport(preview["token"] as String)
                assertArrayEquals(externalZip, read(parent, externalPath))
                assertEquals(1, packages(repository).size)
                assertEquals(1, store.list().count { it.isDirectory })
                assertTrue("Picker import saves an editable directory, never an internal ZIP", store.list().none { it.name.endsWith(".zip", true) })
                val importedRecord = (library.status()["packages"] as List<Map<String, Any?>>).single { it["id"] == imported["id"] }
                assertArrayEquals(buttonImage, read(store, "${importedRecord["path"]}/$imagePath"))

                val manualName = "manual-$cycle.zip"
                val manualImage = png(Color.rgb(20, 130 + cycle, 150))
                val manualZip = zipBytes(mapOf(extraPath to manualImage))
                write(store, manualName, manualZip)
                val cancelled = coordinator.scan()
                assertEquals(1, entries(cancelled).count { it["kind"] == "new" })
                assertArrayEquals("Scanning is read-only for a newly copied ZIP", manualZip, read(store, manualName))
                coordinator.discardScan(cancelled["token"] as String)
                assertArrayEquals("Cancelling must preserve the original internal ZIP", manualZip, read(store, manualName))
                assertEquals(1, packages(repository).size)

                val confirmed = coordinator.scan()
                val manualId = entries(confirmed).single { it["kind"] == "new" }["id"] as String
                coordinator.commitScan(confirmed["token"] as String)
                assertTrue("Only a successful import consumes the library-owned ZIP", store.list().none { it.name == manualName })
                assertTrue(store.list().none { it.name.endsWith(".zip", true) })
                assertEquals(2, store.list().count { it.isDirectory })
                assertEquals(2, packages(repository).size)
                val manualRecord = (library.status()["packages"] as List<Map<String, Any?>>).single { it["id"] == manualId }
                assertArrayEquals(manualImage, read(store, "${manualRecord["path"]}/$extraPath"))
                assertArrayEquals("Consuming an internal source must not touch the picker source", externalZip, read(parent, externalPath))

                val again = coordinator.scan()
                assertEquals(2, entries(again).size)
                assertTrue("Confirmed ZIP import must not create duplicates on a later scan", entries(again).all { it["kind"] == "unchanged" })
                coordinator.discardScan(again["token"] as String)
                val packs = packages(repository)
                val ids = packs.map { it["id"] as String }
                val selected = packs.flatMap { (it["resources"] as List<Map<String, Any?>>).filter { resource -> resource["supported"] == true }.map { resource -> resource["id"] as String } }
                repository.saveDraft(mapOf("master" to true, "order" to ids, "enabledPackages" to ids, "enabledResources" to selected))
                val applied = repository.applyDraft()
                coordinator.journalApplied(emptyList())
                repository.finishApply(applied)
                coordinator.retryPending()
                assertNull(coordinator.status()["error"])
                assertArrayEquals(buttonImage, activeImage(repository))
                assertArrayEquals(manualImage, requireNotNull(repository.openResource(
                    "https://w01x.kancolle-server.com/$extraPath", "GET", emptyMap()
                )).inputStream.use { it.readBytes() })
                assertArrayEquals(externalZip, read(parent, externalPath))
                Log.i("ModLibraryDocuments", "real provider external ZIP preserved/internal ZIP preview-cancel-confirm-cleanup cycle ${cycle + 1}: OK")
            } finally { coordinator.dispose() }
        }
    }

    @Test fun renamingLegacyDefaultPreservesAllDocumentsAndRejectsExistingDestination() = isolated { parent, _, resolver ->
        parent.createDirectory("魔改")
        val legacyUri = document(resolver, parent.treeUri, parent.rootDocumentId, "魔改")
        val legacyId = DocumentsContract.getDocumentId(legacyUri)
        val legacy = GameModDocumentLibraryStore(resolver, parent.treeUri, legacyId)
        val files = mapOf("library.json" to "{\"selection\":\"off\",\"priority\":[2,1]}".toByteArray(),
            ".yahagi-library-id" to "stable-identity".toByteArray(),
            "舰娘包/.yahagi-package.json" to "{\"id\":\"keep\"}".toByteArray(),
            "舰娘包/$imagePath" to png(Color.CYAN))
        files.forEach { (path, bytes) -> write(legacy, path, bytes) }
        val renamedId = requireNotNull(GameModDocumentLibraryStore.renameRoot(resolver, parent.treeUri, legacyId, "Mods"))
        assertEquals("${parent.rootDocumentId}/Mods", renamedId)
        assertFalse(GameModDocumentLibraryStore.documentExists(resolver, parent.treeUri, legacyId))
        val renamed = GameModDocumentLibraryStore(resolver, parent.treeUri, renamedId)
        files.forEach { (path, bytes) -> assertArrayEquals(path, bytes, read(renamed, path)) }
        parent.createDirectory("Existing")
        write(parent, "Existing/keep.txt", "do not merge".toByteArray())
        val conflict = runCatching { GameModDocumentLibraryStore.renameRoot(resolver, parent.treeUri, renamedId, "Existing") }.exceptionOrNull()
        assertEquals("library_default_migration_conflict", (conflict as? GameModException)?.code)
        assertArrayEquals("do not merge".toByteArray(), read(parent, "Existing/keep.txt"))
        files.forEach { (path, bytes) -> assertArrayEquals(path, bytes, read(renamed, path)) }
        Log.i("ModLibraryDocuments", "real provider default-directory rename preserves all bytes and rejects conflicts: OK")
    }

    @SdkSuppress(minSdkVersion = 29)
    @Test fun newAndExistingModImagesStayOutOfGallery() = isolated(visible = true) { parent, privateRoot, resolver ->
        parent.createDirectory("Mods")
        val store = GameModDocumentLibraryStore(resolver, parent.treeUri, "${parent.rootDocumentId}/Mods")
        val repository = GameModRepository(File(privateRoot, "repository"))
        val workspace = File(privateRoot, "library")
        val coordinatorWorkspace = File(privateRoot, "coordinator")
        val library = GameModLibrary(store, workspace)
        val testRoot = parent.rootDocumentId.substringAfterLast('/')
        val oldImageName = imagePath.substringAfterLast('/')
        val oldBytes = png(Color.CYAN)
        val newBytes = png(Color.BLUE)
        val photoBytes = png(Color.GREEN)

        val oldPath = GameModLibraryCoordinator(repository, library, coordinatorWorkspace).let { coordinator ->
            try {
                importToLibrary(repository, coordinator, library, "Old", imagePath, oldBytes)
            } finally { coordinator.dispose() }
        }
        // Reproduce an old app's public package and let Android index its image.
        assertTrue(store.delete("$oldPath/.nomedia"))
        write(store, "$oldPath/$imagePath", oldBytes)
        write(parent, "Photos/personal.png", photoBytes)
        awaitGalleryImages(testRoot, setOf(oldImageName, "personal.png"))

        val restoredLibrary = GameModLibrary(store, workspace)
        assertTrue(store.list(oldPath).any { it.name == ".nomedia" && !it.isDirectory })
        awaitGalleryImages(testRoot, setOf("personal.png"))

        val coordinator = GameModLibraryCoordinator(repository, restoredLibrary, coordinatorWorkspace)
        try {
            val newPath = importToLibrary(repository, coordinator, restoredLibrary, "New", extraPath, newBytes)
            assertTrue(store.list(newPath).any { it.name == ".nomedia" && !it.isDirectory })
            // A later unrelated photo confirms the gallery's scanner has processed a new write.
            write(parent, "Photos/later.png", photoBytes)
            awaitGalleryImages(testRoot, setOf("personal.png", "later.png"))
            assertArrayEquals(oldBytes, read(store, "$oldPath/$imagePath"))
            assertArrayEquals(newBytes, read(store, "$newPath/$extraPath"))
            assertArrayEquals(photoBytes, read(parent, "Photos/personal.png"))
            assertTrue(parent.list().none { it.name == ".nomedia" })
            assertTrue(store.list().none { it.name == ".nomedia" })
        } finally { coordinator.dispose() }
    }

    private fun importToLibrary(
        repository: GameModRepository,
        coordinator: GameModLibraryCoordinator,
        library: GameModLibrary,
        name: String,
        path: String,
        bytes: ByteArray,
    ): String {
        val preview = repository.preflight(zipBytes(mapOf(path to bytes)).inputStream(), "$name.zip")
        val imported = coordinator.commitImport(preview["token"] as String)
        val records = library.status()["packages"] as List<Map<String, Any?>>
        return records.single { it["id"] == imported["id"] }["path"] as String
    }

    private fun awaitGalleryImages(testRoot: String, expected: Set<String>) {
        val deadline = SystemClock.elapsedRealtime() + 10_000
        var actual = galleryImages(testRoot)
        while (actual != expected && SystemClock.elapsedRealtime() < deadline) {
            SystemClock.sleep(100)
            actual = galleryImages(testRoot)
        }
        assertEquals("Unexpected gallery images in $testRoot", expected, actual)
    }

    private fun galleryImages(testRoot: String): Set<String> {
        // Query as a separate reader. The app itself needs only its SAF tree grant.
        // UiAutomation splits arguments at whitespace without processing shell quotes.
        val command = "content query --uri content://media/external/images/media " +
            "--projection _display_name --where (relative_path)LIKE('%/$testRoot/%')"
        val output = ParcelFileDescriptor.AutoCloseInputStream(
            InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command)
        ).bufferedReader().use { it.readText().trim() }
        if (output == "No result found.") return emptySet()
        val rows = output.lineSequence().toList()
        assertTrue("MediaStore query failed: $output", rows.all { it.startsWith("Row: ") && "_display_name=" in it })
        return rows.mapTo(mutableSetOf()) { it.substringAfter("_display_name=") }
    }

    private fun isolated(visible: Boolean = false, block: (GameModDocumentLibraryStore, File, ContentResolver) -> Unit) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val resolver = context.contentResolver
        val arguments = InstrumentationRegistry.getArguments()
        val preferences = context.getSharedPreferences("game_mod_library", Context.MODE_PRIVATE)
        val savedTree = preferences.getString("treeUri", null)
        val treeText = arguments.getString("treeUri")?.takeIf { it.isNotBlank() } ?: savedTree
        assumeTrue("SAF verification requires an authorized mod tree; select a mod folder or supply treeUri/rootDocumentId", treeText != null)
        val treeUri = Uri.parse(requireNotNull(treeText))
        assumeTrue("SAF verification skipped: no persisted read/write permission for $treeUri",
            resolver.persistedUriPermissions.any { it.uri == treeUri && it.isReadPermission && it.isWritePermission })
        val configuredRoot = if (treeText == savedTree) preferences.getString("rootDocumentId", null) else null
        val rootId = arguments.getString("rootDocumentId")?.takeIf { it.isNotBlank() }
            ?: configuredRoot
            ?: DocumentsContract.getTreeDocumentId(treeUri)
        val grantedRoot = DocumentsContract.getTreeDocumentId(treeUri)
        assertTrue(rootId == grantedRoot || rootId.startsWith("$grantedRoot/"))
        GameModLibraryDirectoryPolicy.selectDocumentId(treeUri.authority.orEmpty(), rootId)
        val parent = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId)
        val prefix = if (visible) "yahagi-gallery-test" else ".yahagi-saf-test"
        val unique = "$prefix-${UUID.randomUUID()}"
        val privateRoot = File(context.cacheDir, unique)
        assertTrue(privateRoot.mkdir())
        var created: Uri? = null
        try {
            created = requireNotNull(DocumentsContract.createDocument(resolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, unique))
            val createdId = DocumentsContract.getDocumentId(created)
            assertEquals("$rootId/$unique", createdId)
            val store = GameModDocumentLibraryStore(resolver, treeUri, createdId)
            block(store, privateRoot, resolver)
        } finally {
            // Never pass the authorized tree/root to deletion: only this exact UUID-owned child.
            created?.let { testRoot ->
                assertEquals("$rootId/$unique", DocumentsContract.getDocumentId(testRoot))
                assertTrue("Could not remove the isolated SAF test directory", DocumentsContract.deleteDocument(resolver, testRoot))
            }
            assertEquals(File(context.cacheDir, unique).canonicalPath, privateRoot.canonicalPath)
            assertTrue("Could not remove the isolated private test directory", privateRoot.deleteRecursively())
        }
    }

    private fun document(resolver: ContentResolver, tree: Uri, rootId: String, path: String): Uri {
        var parent = rootId
        for (name in path.split('/')) {
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
            var found: String? = null
            resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) if (cursor.getString(1) == name) {
                    assertNull("Duplicate document display name", found)
                    found = cursor.getString(0)
                }
            } ?: throw AssertionError("Cannot query the isolated SAF test directory")
            parent = requireNotNull(found) { "Missing test document: $path" }
            assertTrue(parent.startsWith("$rootId/"))
        }
        return DocumentsContract.buildDocumentUriUsingTree(tree, parent)
    }

    private fun expectUnsafe(block: () -> Unit) {
        val error = runCatching(block).exceptionOrNull()
        assertEquals("Unsafe relative paths must fail before provider IO", "unsafe_path", (error as? GameModException)?.code)
    }
    private fun assertSavedSetup(expected: Map<String, Any?>, actual: Map<String, Any?>) {
        // Gson reads JSON numbers as Double; compare the actual setup rather than numeric representation.
        for (key in listOf("master", "order", "enabledPackages", "enabledResources")) assertEquals(key, expected[key], actual[key])
    }
    private fun write(store: GameModLibraryStore, path: String, bytes: ByteArray) = store.openWrite(path).use { it.write(bytes) }
    private fun read(store: GameModLibraryStore, path: String) = store.openRead(path).use { it.readBytes() }
    private fun packages(repository: GameModRepository) = repository.status()["packages"] as List<Map<String, Any?>>
    private fun entries(scan: Map<String, Any?>) = scan["entries"] as List<Map<String, Any?>>
    private fun activeImage(repository: GameModRepository): ByteArray = requireNotNull(
        repository.openResource("https://w01x.kancolle-server.com/$imagePath", "GET", emptyMap())
    ).inputStream.use { it.readBytes() }
    private fun apply(repository: GameModRepository, coordinator: GameModLibraryCoordinator) {
        val removed = packages(repository).filter { it["pendingRemoval"] == true }.map { it["id"] as String }
        repository.finishApply(repository.applyDraft())
        coordinator.applied(removed)
        assertNull(coordinator.status()["error"])
    }
    private fun import(repository: GameModRepository, name: String, files: Map<String, ByteArray>): String {
        val bytes = ByteArrayOutputStream().use { output ->
            ZipOutputStream(output).use { zip -> files.forEach { (path, data) ->
                zip.putNextEntry(ZipEntry(path)); zip.write(data); zip.closeEntry()
            } }
            output.toByteArray()
        }
        val preview = repository.preflight(bytes.inputStream(), "$name.zip")
        return repository.commitImport(preview["token"] as String)["id"] as String
    }
    private fun zipBytes(files: Map<String, ByteArray>): ByteArray = ByteArrayOutputStream().use { output ->
        ZipOutputStream(output).use { zip -> files.forEach { (path, data) ->
            zip.putNextEntry(ZipEntry(path)); zip.write(data); zip.closeEntry()
        } }
        output.toByteArray()
    }
    private fun png(color: Int): ByteArray = ByteArrayOutputStream().use { output ->
        val bitmap = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        try { bitmap.eraseColor(color); assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) }
        finally { bitmap.recycle() }
        output.toByteArray()
    }
}
