package app.yahagi.kancollebrowser.mods

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import java.io.OutputStream
import java.lang.reflect.InvocationTargetException
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.CRC32
import java.util.zip.DeflaterOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class GameModLibraryCoordinatorTest {
    @get:Rule val temporary = TemporaryFolder()
    private val path = "kcs2/resources/ship/banner/0001_1234.png"

    @Test fun `ZIP update keeps priority and resource choices while the applied revision stays readable`() {
        val privateRoot = temporary.newFolder()
        val repo = GameModRepository(privateRoot)
        val public = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val workspace = temporary.newFolder()
        val coordinator = GameModLibraryCoordinator(repo, library, workspace)
        val disabled = "kcs2/resources/ship/banner/0002_1234.png"
        val removed = "kcs2/resources/ship/banner/0003_1234.png"
        val added = "kcs2/resources/ship/banner/0004_1234.png"
        val oldArchive = archive(path to png(1), disabled to png(1), removed to png(1))
        val original = coordinator.commitImport(repo.preflight(oldArchive.inputStream(), "Installed.zip")["token"] as String)
        val id = original["id"] as String
        val other = coordinator.commitImport(repo.preflight(archive(png(8)).inputStream(), "Other.zip")["token"] as String)
        val otherId = other["id"] as String
        val resources = (original["resources"] as List<*>).filterIsInstance<Map<*, *>>().associate { it["path"] to it["id"] }
        repo.saveDraft(mapOf("master" to true, "order" to listOf(otherId, id), "enabledPackages" to listOf(id),
            "enabledResources" to listOf(resources[path], resources[removed])))
        repo.finishApply(repo.applyDraft())
        coordinator.applied(emptyList())
        val oldTree = public.listFiles()!!.single { it.isDirectory && it.name.startsWith("Installed-") }
        val preview = coordinator.preflightUpdate(archive(added to png(2), disabled to png(2), path to png(2)).inputStream(), "Renamed.zip", id)
        assertEquals("Installed", preview["packageName"])
        assertEquals(1, preview["addedCount"])
        assertEquals(1, preview["removedCount"])
        coordinator.commitImport(preview["token"] as String)

        val restarted = GameModRepository(privateRoot)
        val pending = restarted.status()
        val pack = (pending["packages"] as List<*>).filterIsInstance<Map<*, *>>().single { it["id"] == id }
        assertEquals(true, pack["pendingUpdate"])
        assertEquals("Renamed", pack["name"])
        val updatedResources = (pack["resources"] as List<*>).filterIsInstance<Map<*, *>>().associate { it["path"] to it["id"] }
        assertEquals(resources[path], updatedResources[path])
        assertEquals(resources[disabled], updatedResources[disabled])
        val draft = pending["draft"] as Map<*, *>
        assertEquals(listOf(otherId, id), draft["order"])
        assertEquals(listOf(id), draft["enabledPackages"])
        assertEquals(setOf(updatedResources[path], updatedResources[added]), (draft["enabledResources"] as List<*>).toSet())
        assertArrayEquals(png(1), activeBytes(restarted, path))
        assertArrayEquals(png(1), activeBytes(restarted, removed))
        assertArrayEquals(png(1), oldTree.resolve(path).readBytes())

        // A crash after publication still leaves enough durable information to update the backup.
        val resumed = GameModLibraryCoordinator(restarted, library, workspace)
        resumed.checkReadyToApply()
        restarted.finishApply(restarted.applyDraft())
        val recovered = GameModRepository(privateRoot)
        val recoveredLibrary = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val refreshed = GameModLibraryCoordinator(recovered, recoveredLibrary, workspace)
        refreshed.retryPending()
        assertArrayEquals(png(2), activeBytes(recovered, path))
        assertArrayEquals(png(2), activeBytes(recovered, added))
        assertNull(activeBytes(recovered, removed))
        assertNull(activeBytes(recovered, disabled))
        assertFalse(oldTree.exists())
        val saved = public.listFiles()!!.single { it.isDirectory && it.name.startsWith("Renamed-") }
        assertArrayEquals(png(2), saved.resolve(path).readBytes())
        assertFalse(saved.resolve(removed).exists())
        val savedChoices = checkNotNull(recoveredLibrary.appliedConfiguration())
        val expectedChoices = recovered.exportAppliedConfiguration()
        listOf("master", "order", "enabledPackages", "enabledResources").forEach { key ->
            assertEquals(expectedChoices[key], savedChoices[key])
        }
        val scan = refreshed.scan()
        assertEquals(setOf("unchanged"), (scan["entries"] as List<*>).filterIsInstance<Map<*, *>>().map { it["kind"] }.toSet())
    }

    @Test fun `cancel ZIP update before first apply keeps the original managed package`() {
        val privateRoot = temporary.newFolder()
        val repo = GameModRepository(privateRoot)
        val public = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val original = coordinator.commitImport(repo.preflight(archive(png(1)).inputStream(), "Installed.zip")["token"] as String)
        val id = original["id"] as String
        val preview = coordinator.preflightUpdate(archive(png(2)).inputStream(), "Update.zip", id)
        coordinator.commitImport(preview["token"] as String)
        val restarted = GameModRepository(privateRoot)
        restarted.cancelChanges()

        assertEquals(listOf(original), restarted.status()["packages"])
        assertEquals(false, restarted.status()["pending"])
        assertArrayEquals(png(1), public.walkTopDown().single { it.name == "0001_1234.png" }.readBytes())
    }

    @Test fun `ZIP update rejects a changed public source before modifying the draft`() {
        val public = temporary.newFolder()
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val original = coordinator.commitImport(repo.preflight(archive(png(1)).inputStream(), "Installed.zip")["token"] as String)
        val id = original["id"] as String
        val preview = coordinator.preflightUpdate(archive(png(2)).inputStream(), "Update.zip", id)
        val originalStatus = repo.status()
        val source = public.walkTopDown().single { it.name == "0001_1234.png" }
        source.writeBytes(png(3))

        val rejected = runCatching { coordinator.commitImport(preview["token"] as String) }.exceptionOrNull()
        assertEquals("library_changed", (rejected as? GameModException)?.code)
        assertEquals(originalStatus, repo.status())
        assertArrayEquals(png(3), source.readBytes())
    }

    @Test fun `ZIP update safely backs up a published revision if the original became externally edited during apply`() {
        val public = temporary.newFolder()
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val original = coordinator.commitImport(repo.preflight(archive(png(1)).inputStream(), "Installed.zip")["token"] as String)
        val id = original["id"] as String
        enable(repo)
        coordinator.applied(emptyList())
        val source = public.walkTopDown().single { it.name == "0001_1234.png" }
        val preview = coordinator.preflightUpdate(archive(png(2)).inputStream(), "Update.zip", id)
        coordinator.commitImport(preview["token"] as String)
        coordinator.checkReadyToApply()
        source.writeBytes(png(3))

        repo.finishApply(repo.applyDraft())
        coordinator.applied(emptyList())

        assertArrayEquals(png(3), source.readBytes())
        assertArrayEquals(png(2), activeBytes(repo, path))
        assertNull(coordinator.status()["error"])
        val current = (library.status()["packages"] as List<*>).filterIsInstance<Map<*, *>>().single()
        val replacement = public.resolve(current["path"] as String)
        assertArrayEquals(png(2), replacement.resolve(path).readBytes())
        val rows = (coordinator.scan()["entries"] as List<*>).filterIsInstance<Map<*, *>>()
        assertEquals(setOf("unchanged", "duplicate"), rows.map { it["kind"] }.toSet())
        assertTrue(replacement.deleteRecursively())
        val reopened = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val scan = reopened.scan()
        assertTrue(reopened.acceptScan(scan.token).isEmpty())
        assertEquals(setOf("missing", "duplicate"), scan.items.map { it["status"] }.toSet())
    }

    @Test fun `picker import preserves original ZIP outside the library and saves only an editable tree`() {
        val source = temporary.newFile("original.zip").apply { writeBytes(archive(png(1))) }
        val original = source.readBytes()
        val public = temporary.newFolder()
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val preview = source.inputStream().use { repo.preflight(it, source.name) }
        coordinator.commitImport(preview["token"] as String)
        assertArrayEquals(original, source.readBytes())
        assertTrue(public.listFiles()!!.none { it.extension.equals("zip", true) })
        assertArrayEquals(png(1), public.walkTopDown().single { it.name == "0001_1234.png" }.readBytes())
    }

    @Test fun `manual ZIP remains during previews and is consumed only after successful scan commit`() {
        repeat(3) { cycle ->
            val public = temporary.newFolder()
            val source = public.resolve("manual.zip").apply { writeBytes(archive(png(cycle))) }
            val repo = GameModRepository(temporary.newFolder())
            val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
            val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
            repeat(2) {
                val cancelled = coordinator.scan()
                assertTrue(source.exists())
                coordinator.discardScan(cancelled["token"] as String)
                assertTrue(source.exists())
                assertEquals(0, public.listFiles()!!.count { it.isDirectory })
            }
            val scan = coordinator.scan()
            coordinator.commitScan(scan["token"] as String)
            assertFalse("Successful import retains only the editable directory", source.exists())
            val id = ((repo.status()["packages"] as List<*>).single() as Map<*, *>)["id"]
            assertArrayEquals(png(cycle), public.walkTopDown().single { it.name == "0001_1234.png" }.readBytes())
            val next = coordinator.scan()
            val entry = ((next["entries"] as List<*>).single() as Map<*, *>)
            assertEquals(id, entry["id"])
            assertEquals("unchanged", entry["kind"])
            coordinator.discardScan(next["token"] as String)
        }
    }

    @Test fun `failed repository validation keeps manual ZIP even after public extraction`() {
        val public = temporary.newFolder()
        val source = public.resolve("manual.zip").apply { writeBytes(archive(png(1))) }
        val bytes = source.readBytes()
        val repo = GameModRepository(temporary.newFolder())
        val libraryWorkspace = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), libraryWorkspace)
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val preview = coordinator.scan()
        libraryWorkspace.walkTopDown().single { it.name == "normalized.zip" }.writeBytes(byteArrayOf(1, 2, 3))
        val error = runCatching { coordinator.commitScan(preview["token"] as String) }.exceptionOrNull()
        assertEquals("invalid_archive", (error as? GameModException)?.code)
        assertArrayEquals(bytes, source.readBytes())
        assertTrue((repo.status()["packages"] as List<*>).isEmpty())
        val retry = coordinator.scan()
        coordinator.commitScan(retry["token"] as String)
        assertFalse(source.exists())
        assertEquals(1, (repo.status()["packages"] as List<*>).size)
    }

    @Test fun `failed manual ZIP cleanup retries safely and never removes a replacement ZIP`() {
        val public = temporary.newFolder()
        val source = public.resolve("manual.zip").apply { writeBytes(archive(png(1))) }
        val store = FailingStore(GameModFileLibraryStore(public)).apply { failDeletePackages = true }
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(store, temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val preview = coordinator.scan()
        coordinator.commitScan(preview["token"] as String)
        assertTrue(source.exists())
        assertEquals("library_cleanup_failed", coordinator.status()["error"])
        store.failDeletePackages = false
        val retry = coordinator.scan()
        coordinator.commitScan(retry["token"] as String)
        assertFalse(source.exists())
        assertNull(coordinator.status()["error"])

        source.writeBytes(archive(png(2)))
        val changed = coordinator.scan()
        assertTrue((changed["entries"] as List<*>).any { (it as Map<*, *>)["kind"] == "new" })
        val replacement = archive(png(3))
        source.writeBytes(replacement)
        val error = runCatching { coordinator.commitScan(changed["token"] as String) }.exceptionOrNull()
        assertEquals("library_changed", (error as? GameModException)?.code)
        assertArrayEquals(replacement, source.readBytes())
    }

    @Test fun `legacy retained ZIP is cleaned after confirmation while skipped duplicate files stay untouched`() {
        val public = temporary.newFolder()
        val source = public.resolve("manual.zip").apply { writeBytes(archive(png(1))) }
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val oldPreview = library.scan()
        val candidate = library.acceptScan(oldPreview.token).single()
        val preflight = candidate.archive.inputStream().use { repo.preflightLibrary(it, "Legacy.zip") }
        repo.commitLibraryImport(preflight["token"] as String, candidate.id, candidate.contentHash)
        library.discardScan(oldPreview.token) // The previous release retained this source archive.
        enable(repo)
        val applied = repo.exportAppliedConfiguration()
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val preview = coordinator.scan()
        assertEquals(1, preview["cleanupCount"])
        assertEquals("unchanged", ((preview["entries"] as List<*>).single() as Map<*, *>)["kind"])
        coordinator.discardScan(preview["token"] as String)
        assertTrue(source.exists())
        val confirmed = coordinator.scan()
        coordinator.commitScan(confirmed["token"] as String)
        assertFalse(source.exists())
        assertEquals(applied, repo.exportAppliedConfiguration())
        assertEquals(false, repo.status()["pending"])

        val duplicate = public.resolve("duplicate.zip").apply { writeBytes(archive(png(1))) }
        val scan = coordinator.scan()
        assertEquals(0, scan["cleanupCount"])
        assertEquals(1, (scan["entries"] as List<*>).count { (it as Map<*, *>)["kind"] == "duplicate" })
        coordinator.commitScan(scan["token"] as String)
        assertTrue("Skipped duplicate archives have not been imported", duplicate.exists())
        assertEquals(1, (repo.status()["packages"] as List<*>).size)
        assertEquals(applied, repo.exportAppliedConfiguration())
    }

    @Test fun `reusing generic cache ZIP name after consumption imports another package instead of overwriting the old one`() {
        val public = temporary.newFolder()
        val source = public.resolve("cache.zip").apply { writeBytes(archive(png(1))) }
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val first = coordinator.scan()
        coordinator.commitScan(first["token"] as String)
        val original = (repo.status()["packages"] as List<*>).single() as Map<*, *>
        val firstId = original["id"]
        source.writeBytes(archive(png(2)))
        val next = coordinator.scan()
        assertEquals("Unrelated exports often share cache.zip as their filename", 1,
            (next["entries"] as List<*>).count { (it as Map<*, *>)["kind"] == "new" })
        coordinator.commitScan(next["token"] as String)
        assertEquals(2, (repo.status()["packages"] as List<*>).size)
        assertEquals(2, public.listFiles()!!.count { it.isDirectory })
        assertTrue((repo.status()["packages"] as List<*>).any { (it as Map<*, *>)["id"] == firstId })
        assertFalse(source.exists())
    }

    @Test fun `package deletion also cleans its failed ZIP import cleanup and does not resurrect it`() {
        val public = temporary.newFolder()
        val source = public.resolve("cache.zip").apply { writeBytes(archive(png(1))) }
        val store = FailingStore(GameModFileLibraryStore(public)).apply { failDeletePackages = true }
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(store, temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val preview = coordinator.scan()
        coordinator.commitScan(preview["token"] as String)
        assertTrue(source.exists())
        val retry = coordinator.scan()
        assertEquals(1, retry["cleanupCount"])
        coordinator.discardScan(retry["token"] as String)
        val id = ((repo.status()["packages"] as List<*>).single() as Map<*, *>)["id"] as String
        repo.removePackage(id)
        repo.finishApply(repo.applyDraft())
        store.failDeletePackages = false
        coordinator.applied(listOf(id))
        assertFalse(source.exists())
        assertTrue((coordinator.scan()["entries"] as List<*>).isEmpty())
    }

    @Test fun `migrate existing packages and restore last applied choices after private data is lost`() {
        val repo = GameModRepository(temporary.newFolder()); import(repo, png(0)); enable(repo)
        val public = temporary.newFolder(); val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = coordinator(repo, library)
        val before = repo.portraitSnapshot()
        invoke(coordinator, "migrateExisting")
        assertEquals(before, repo.portraitSnapshot())
        val expected = repo.exportAppliedConfiguration()
        val restored = GameModRepository(temporary.newFolder())
        val fresh = coordinator(restored, GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder()))
        val scan = invoke(fresh, "scan") as Map<*, *>
        assertEquals(true, scan["restoreAvailable"])
        invoke(fresh, "commitScan", scan["token"] as String)
        assertTrue((restored.status()["packages"] as List<*>).isNotEmpty())
        assertTrue((restored.portraitSnapshot()["resources"] as List<*>).isEmpty())
        restored.finishApply(restored.applyDraft())
        assertEquals(expected, restored.exportAppliedConfiguration())
    }

    @Test fun `manual edits stage an update which can be cancelled without changing public source or active image`() {
        val repo = GameModRepository(temporary.newFolder()); import(repo, png(0)); enable(repo)
        val public = temporary.newFolder(); val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = coordinator(repo, library); invoke(coordinator, "migrateExisting")
        val before = repo.portraitSnapshot()
        val image = public.walkTopDown().first { it.name == "0001_1234.png" }; image.writeBytes(png(1))
        val scan = invoke(coordinator, "scan") as Map<*, *>
        assertEquals("updated", ((scan["entries"] as List<*>).single() as Map<*, *>)["kind"])
        invoke(coordinator, "commitScan", scan["token"] as String)
        assertEquals(before, repo.portraitSnapshot())
        assertEquals(true, repo.status()["pending"])
        repo.cancelChanges()
        assertEquals(before, repo.portraitSnapshot())
        assertEquals(false, repo.status()["pending"])
        assertArrayEquals(png(1), image.readBytes())
        val again = invoke(coordinator, "scan") as Map<*, *>
        assertEquals("updated", ((again["entries"] as List<*>).single() as Map<*, *>)["kind"])
    }

    @Test fun `deletion touches public files only after apply and cannot reappear in the next scan`() {
        val repo = GameModRepository(temporary.newFolder()); val id = import(repo, png(0)); enable(repo)
        val public = temporary.newFolder(); val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = coordinator(repo, library); invoke(coordinator, "migrateExisting")
        val source = public.walkTopDown().first { it.name == "0001_1234.png" }
        repeat(3) { repo.removePackage(id); assertTrue(source.exists()); repo.cancelChanges(); assertTrue(source.exists()) }
        repo.removePackage(id); repo.finishApply(repo.applyDraft())
        invoke(coordinator, "applied", listOf(id))
        assertFalse(source.exists())
        assertTrue((invoke(coordinator, "scan") as Map<*, *>)["entries"].let { it as List<*> }.none { (it as Map<*, *>)["kind"] == "new" })
        assertEquals(emptyList<String>(), library.appliedConfiguration()!!["order"])
    }

    @Test fun `moving back to an existing library never overwrites externally edited resources`() {
        val repo = GameModRepository(temporary.newFolder()); import(repo, png(0)); enable(repo)
        val public = temporary.newFolder(); val first = coordinator(repo, GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder()))
        invoke(first, "migrateExisting")
        val image = public.walkTopDown().first { it.name == "0001_1234.png" }; image.writeBytes(png(1))
        val next = coordinator(repo, GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder()))
        invoke(next, "migrateExisting")
        assertArrayEquals(png(1), image.readBytes())
        val scan = invoke(next, "scan") as Map<*, *>
        assertEquals("updated", ((scan["entries"] as List<*>).single() as Map<*, *>)["kind"])
    }

    @Test fun `pending public write failure blocks scanning and migration until durable retry succeeds`() {
        val repo = GameModRepository(temporary.newFolder()); val id = import(repo, png(0)); enable(repo)
        val public = temporary.newFolder()
        val store = FailingStore(GameModFileLibraryStore(public))
        var library = GameModLibrary(store, temporary.newFolder())
        val workspace = temporary.newFolder()
        var coordinator = GameModLibraryCoordinator(repo, library, workspace)
        coordinator.migrateExisting()
        val source = public.walkTopDown().first { it.name == "0001_1234.png" }
        store.failWrite = true
        repo.removePackage(id); repo.finishApply(repo.applyDraft())
        coordinator.applied(listOf(id))
        assertTrue(source.exists())
        val scanError = runCatching { coordinator.scan() }.exceptionOrNull()
        val migrationError = runCatching { coordinator.migrateExisting() }.exceptionOrNull()
        assertEquals("library_backup_pending", (scanError as? GameModException)?.code)
        assertEquals("library_backup_pending", (migrationError as? GameModException)?.code)
        assertEquals("library_backup_pending", coordinator.status()["error"])
        assertTrue((repo.status()["packages"] as List<*>).isEmpty())

        // A new process gets only the durable journal, not the old coordinator's error flag.
        store.failWrite = false
        library = GameModLibrary(store, temporary.newFolder())
        coordinator = GameModLibraryCoordinator(repo, library, workspace)
        coordinator.retryPending()
        assertNull(coordinator.status()["error"])
        assertFalse(source.exists())
        assertFalse(workspace.resolve("pending-public-sync.json").exists())
        assertEquals(emptyList<String>(), library.appliedConfiguration()!!["order"])
        assertTrue((coordinator.scan()["entries"] as List<*>).isEmpty())
    }

    @Test fun `failed public directory deletion blocks new scans and retries cleanup without resurrection`() {
        val repo = GameModRepository(temporary.newFolder()); val id = import(repo, png(0)); enable(repo)
        val public = temporary.newFolder()
        val store = FailingStore(GameModFileLibraryStore(public))
        val library = GameModLibrary(store, temporary.newFolder())
        val workspace = temporary.newFolder()
        val coordinator = GameModLibraryCoordinator(repo, library, workspace)
        coordinator.migrateExisting()
        val source = public.walkTopDown().first { it.name == "0001_1234.png" }
        store.failDeletePackages = true
        repo.removePackage(id); repo.finishApply(repo.applyDraft()); coordinator.applied(listOf(id))
        assertEquals("library_cleanup_failed", coordinator.status()["error"])
        assertTrue(source.exists())
        val scanError = runCatching { coordinator.scan() }.exceptionOrNull()
        val migrationError = runCatching { coordinator.migrateExisting() }.exceptionOrNull()
        assertEquals("library_cleanup_failed", (scanError as? GameModException)?.code)
        assertEquals("library_cleanup_failed", (migrationError as? GameModException)?.code)
        store.failDeletePackages = false
        coordinator.retryPending()
        assertNull(coordinator.status()["error"]); assertFalse(source.exists())
        assertTrue((coordinator.scan()["entries"] as List<*>).isEmpty())
        assertTrue((repo.status()["packages"] as List<*>).isEmpty())
    }

    @Test fun `a scan imports six distinct packages without exceeding the preview staging quota`() {
        val repo = GameModRepository(temporary.newFolder())
        val public = temporary.newFolder()
        repeat(6) { index -> public.resolve("A-new-$index/$path").apply { parentFile!!.mkdirs(); writeBytes(png(index + 1)) } }
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val before = repo.portraitSnapshot()
        val preview = coordinator.scan()
        assertEquals(6, (preview["entries"] as List<*>).size)
        coordinator.commitScan(preview["token"] as String)
        assertEquals(6, (repo.status()["packages"] as List<*>).size)
        assertEquals(before, repo.portraitSnapshot())
        assertEquals(emptyList<String>(), (repo.status()["draft"] as Map<*, *>)["enabledPackages"])
    }

    @Test fun `invalid sixth scan archive rejects the batch before repository changes and keeps applied resources`() {
        val repo = GameModRepository(temporary.newFolder()); import(repo, png(0)); enable(repo)
        val public = temporary.newFolder()
        val libraryWorkspace = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), libraryWorkspace)
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        coordinator.migrateExisting()
        repeat(6) { index -> public.resolve("A-new-$index/$path").apply { parentFile!!.mkdirs(); writeBytes(png(index + 1)) } }
        val before = repo.portraitSnapshot()
        val applied = repo.exportAppliedConfiguration()
        val preview = coordinator.scan()
        // Simulate damaged local scan storage, while public source files remain unchanged.
        libraryWorkspace.walkTopDown().single { it.name == "package.zip" && it.parentFile!!.name == "5" }.writeBytes(byteArrayOf(1, 2, 3))
        val error = runCatching { coordinator.commitScan(preview["token"] as String) }.exceptionOrNull()
        assertEquals("invalid_archive", (error as? GameModException)?.code)
        assertEquals(1, (repo.status()["packages"] as List<*>).size)
        assertEquals(before, repo.portraitSnapshot())
        assertEquals(applied, repo.exportAppliedConfiguration())
        assertArrayEquals(png(0), repo.openResource("https://w01x.kancolle-server.com/$path", "GET", emptyMap())!!.inputStream.use { it.readBytes() })
    }

    @Test fun `ZIP import binds identical public package identity before the first scan`() {
        val repo = GameModRepository(temporary.newFolder())
        val public = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val tree = temporary.newFolder()
        tree.resolve(path).apply { parentFile!!.mkdirs(); writeBytes(png(1)) }
        val id = UUID.randomUUID().toString()
        library.savePackage(id, "Already saved", tree)
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val archive = archive(png(1))
        val preview = repo.preflight(archive.inputStream(), "Same package.zip")
        val imported = coordinator.commitImport(preview["token"] as String)
        assertEquals(id, imported["id"])
        assertEquals(1, (library.status()["packages"] as List<*>).size)
        assertEquals(1, (repo.status()["packages"] as List<*>).size)
        assertEquals(1, public.listFiles()!!.count { it.isDirectory })
    }

    @Test fun `ZIP duplicate binding preserves an externally edited public tree`() {
        val repo = GameModRepository(temporary.newFolder())
        val public = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val tree = temporary.newFolder()
        tree.resolve(path).apply { parentFile!!.mkdirs(); writeBytes(png(1)) }
        val id = UUID.randomUUID().toString()
        val saved = library.savePackage(id, "Already saved", tree)
        val source = public.resolve(saved["path"] as String).resolve(path)
        source.writeBytes(png(2))
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val preview = repo.preflight(archive(png(1)).inputStream(), "Same package.zip")
        assertEquals(id, coordinator.commitImport(preview["token"] as String)["id"])
        assertArrayEquals(png(2), source.readBytes())
        val scan = coordinator.scan()
        assertEquals("updated", ((scan["entries"] as List<*>).single() as Map<*, *>)["kind"])
    }

    @Test fun `journal is durable before private cleanup and retries public IO after process restart`() {
        val repo = GameModRepository(temporary.newFolder()); val id = import(repo, png(0)); enable(repo)
        val public = temporary.newFolder()
        val store = FailingStore(GameModFileLibraryStore(public))
        val library = GameModLibrary(store, temporary.newFolder())
        val workspace = temporary.newFolder()
        val coordinator = GameModLibraryCoordinator(repo, library, workspace)
        coordinator.migrateExisting()
        val source = public.walkTopDown().first { it.name == "0001_1234.png" }
        store.failWrite = true
        repo.removePackage(id)
        val published = repo.applyDraft()
        val method = coordinator.javaClass.methods.singleOrNull { it.name == "journalApplied" }
        assertNotNull("Missing write-ahead synchronization journal API", method)
        method!!.invoke(coordinator, listOf(id))
        assertTrue(workspace.resolve("pending-public-sync.json").isFile)
        assertTrue(source.exists())
        assertEquals(listOf(id), library.appliedConfiguration()!!["order"])
        repo.finishApply(published)
        assertTrue((repo.status()["packages"] as List<*>).isEmpty())
        store.failWrite = false
        val restartedLibrary = GameModLibrary(store, temporary.newFolder())
        val restarted = GameModLibraryCoordinator(repo, restartedLibrary, workspace)
        restarted.retryPending()
        assertFalse(source.exists())
        assertNull(restarted.status()["error"])
        assertFalse(workspace.resolve("pending-public-sync.json").exists())
        assertEquals(emptyList<String>(), restartedLibrary.appliedConfiguration()!!["order"])
    }

    @Test fun `first reinstall scan restores saved choices after importing one ZIP and never overwrites an applied setup`() {
        val original = GameModRepository(temporary.newFolder())
        val a = import(original, png(1)); val b = import(original, png(2))
        val originalPackages = original.status()["packages"] as List<*>
        val chosen = (((originalPackages[1] as Map<*, *>)["resources"] as List<*>).single() as Map<*, *>)["id"] as String
        original.saveDraft(mapOf("master" to false, "order" to listOf(b, a), "enabledPackages" to listOf(b), "enabledResources" to listOf(chosen)))
        original.finishApply(original.applyDraft())
        val expected = original.exportAppliedConfiguration()
        val public = temporary.newFolder()
        val firstLibrary = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val first = GameModLibraryCoordinator(original, firstLibrary, temporary.newFolder())
        first.migrateExisting()

        val fresh = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(fresh, library, temporary.newFolder())
        val preview = fresh.preflight(archive(png(1)).inputStream(), "Already saved.zip")
        assertEquals(a, coordinator.commitImport(preview["token"] as String)["id"])
        assertEquals(1, (fresh.status()["packages"] as List<*>).size)
        val beforeActive = fresh.portraitSnapshot()
        val scan = coordinator.scan()
        assertEquals("Importing a ZIP is not a successfully applied local setup", true, scan["restoreAvailable"])
        coordinator.commitScan(scan["token"] as String)
        assertEquals(beforeActive, fresh.portraitSnapshot())
        val draft = fresh.status()["draft"] as Map<*, *>
        assertEquals(false, draft["master"])
        assertEquals(listOf(b, a), draft["order"])
        assertEquals(listOf(b), draft["enabledPackages"])
        fresh.finishApply(fresh.applyDraft())
        assertEquals(expected, fresh.exportAppliedConfiguration())

        // Once a local setup has succeeded, an older external backup only supplies new
        // packages. It must never silently replace the user's current choices again.
        val resources = (fresh.status()["packages"] as List<*>).flatMap { entry ->
            ((entry as Map<*, *>)["resources"] as List<*>).map { (it as Map<*, *>)["id"] as String }
        }
        val local = mapOf("master" to true, "order" to listOf(a, b), "enabledPackages" to listOf(a, b), "enabledResources" to resources)
        fresh.saveDraft(local); fresh.finishApply(fresh.applyDraft())
        val localApplied = fresh.exportAppliedConfiguration()
        val second = coordinator.scan()
        assertEquals(false, second["restoreAvailable"])
        coordinator.commitScan(second["token"] as String)
        assertEquals(localApplied, fresh.exportAppliedConfiguration())
        assertEquals(local, fresh.status()["draft"])
    }

    @Test fun `restart after published deletion journal cannot migrate the pending private package back to public storage`() {
        val root = temporary.newFolder()
        val original = GameModRepository(root); val id = import(original, png(0)); enable(original)
        val public = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val workspace = temporary.newFolder()
        val coordinator = GameModLibraryCoordinator(original, library, workspace)
        coordinator.migrateExisting()
        val source = public.walkTopDown().first { it.name == "0001_1234.png" }
        original.removePackage(id)
        original.applyDraft() // Published, then the process dies before finishApply removes metadata.
        coordinator.journalApplied(listOf(id))
        assertTrue(source.exists())

        val restarted = GameModRepository(root)
        val restartedLibrary = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val fresh = GameModLibraryCoordinator(restarted, restartedLibrary, workspace)
        assertEquals(0, fresh.migrateExisting())
        assertFalse("Recovery must not export an already applied deletion back into the source library", source.exists())
        assertTrue((restartedLibrary.status()["packages"] as List<*>).isEmpty())
        assertTrue((fresh.scan()["entries"] as List<*>).none { (it as Map<*, *>)["id"] == id })
        assertTrue((restarted.portraitSnapshot()["resources"] as List<*>).isEmpty())
    }

    @Test fun `legacy staged deletion remains migratable until it is successfully applied and can still be cancelled`() {
        val root = temporary.newFolder()
        val original = GameModRepository(root); val id = import(original, png(0)); enable(original)
        original.removePackage(id) // Existing game session still uses the package.
        val restarted = GameModRepository(root)
        val public = temporary.newFolder()
        val library = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(restarted, library, temporary.newFolder())
        assertEquals(1, coordinator.migrateExisting())
        assertTrue(public.walkTopDown().any { it.name == "0001_1234.png" })
        restarted.cancelChanges()
        assertEquals(false, restarted.status()["pending"])
        assertEquals(listOf(id), (restarted.status()["draft"] as Map<*, *>)["enabledPackages"])
        assertArrayEquals(png(0), restarted.openResource("https://w01x.kancolle-server.com/$path", "GET", emptyMap())!!.inputStream.use { it.readBytes() })
    }

    private fun coordinator(repo: GameModRepository, library: GameModLibrary): Any {
        val cls = try { Class.forName("app.yahagi.kancollebrowser.mods.GameModLibraryCoordinator") }
        catch (_: ClassNotFoundException) { throw AssertionError("Missing library coordinator") }
        return cls.getConstructor(GameModRepository::class.java, GameModLibrary::class.java, File::class.java).newInstance(repo, library, temporary.newFolder())
    }
    private fun invoke(target: Any, method: String, vararg args: Any): Any? {
        val types = args.map { if (it is List<*>) List::class.java else it.javaClass }.toTypedArray()
        try { return target.javaClass.getMethod(method, *types).invoke(target, *args) }
        catch (error: InvocationTargetException) { throw error.targetException }
    }
    private fun import(repo: GameModRepository, bytes: ByteArray): String {
        val archive = archive(bytes)
        val preview = repo.preflight(archive.inputStream(), "Ship.zip")
        return repo.commitImport(preview["token"] as String)["id"] as String
    }
    private fun archive(bytes: ByteArray) = archive(path to bytes)
    private fun archive(vararg files: Pair<String, ByteArray>) = ByteArrayOutputStream().also { output ->
        ZipOutputStream(output).use { zip ->
            files.forEach { (name, bytes) ->
                zip.putNextEntry(ZipEntry(name))
                zip.write(bytes)
                zip.closeEntry()
            }
        }
    }.toByteArray()
    private fun activeBytes(repo: GameModRepository, name: String) =
        repo.openResource("https://w01x.kancolle-server.com/$name", "GET", emptyMap())?.inputStream?.use { it.readBytes() }
    private class FailingStore(private val delegate: GameModLibraryStore) : GameModLibraryStore by delegate {
        var failWrite = false
        var failDeletePackages = false
        override fun openWrite(relative: String): OutputStream {
            if (failWrite) throw GameModException("library_write_failed", "Injected document-provider write failure")
            return delegate.openWrite(relative)
        }
        override fun delete(relative: String): Boolean {
            if (failDeletePackages && !relative.startsWith('.') && relative != "library.json") return false
            return delegate.delete(relative)
        }
    }
    private fun enable(repo: GameModRepository) {
        val packages = repo.status()["packages"] as List<*>
        val ids = packages.map { (it as Map<*, *>)["id"] as String }
        val resources = packages.flatMap { (((it as Map<*, *>)["resources"]) as List<*>).map { (it as Map<*, *>)["id"] as String } }
        repo.saveDraft(mapOf("master" to true, "order" to ids, "enabledPackages" to ids, "enabledResources" to resources)); repo.finishApply(repo.applyDraft())
    }
    private fun png(value: Int): ByteArray = ByteArrayOutputStream().also { output ->
        val data = DataOutputStream(output); data.write(byteArrayOf(-119,80,78,71,13,10,26,10))
        fun chunk(name: String, bytes: ByteArray) { val tag=name.toByteArray();data.writeInt(bytes.size);data.write(tag);data.write(bytes);data.writeInt(CRC32().also {it.update(tag);it.update(bytes)}.value.toInt()) }
        chunk("IHDR", ByteArrayOutputStream().also { DataOutputStream(it).apply {writeInt(1);writeInt(1);write(byteArrayOf(8,6,0,0,0))} }.toByteArray())
        chunk("IDAT", ByteArrayOutputStream().also {DeflaterOutputStream(it).use {it.write(byteArrayOf(0,value.toByte(),0,0,-1))}}.toByteArray()); chunk("IEND", byteArrayOf())
    }.toByteArray()
}
