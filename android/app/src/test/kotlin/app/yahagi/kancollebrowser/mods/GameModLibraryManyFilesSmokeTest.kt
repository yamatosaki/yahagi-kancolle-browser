package app.yahagi.kancollebrowser.mods

import com.google.gson.Gson
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.zip.CRC32
import java.util.zip.DeflaterOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Bounded local integration smoke: 52 real ZIPs, 208 decoded PNGs and 104 companion files. */
class GameModLibraryManyFilesSmokeTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun `fifty two multi-file ZIP packages survive cancelled previews import rescan apply and restart`() {
        val public = temporary.newFolder("public")
        val privateRoot = temporary.newFolder("private")
        val libraryWorkspace = temporary.newFolder("library-worker")
        val coordinatorWorkspace = temporary.newFolder("coordinator-worker")
        val fixtures = (1..52).associate { index ->
            val ship = index.toString().padStart(4, '0')
            val files = linkedMapOf(
                "kcs2/resources/ship/full/${ship}_1234.png" to png(index, 1),
                "kcs2/resources/ship/banner/${ship}_1234.png" to png(index, 2),
                "kcs2/resources/ship/card/${ship}_1234.png" to png(index, 3),
                "kcs2/img/测试子目录/图标-$index.png" to png(index, 4),
                "说明/使用说明-$index.txt" to "魔改包 $index 的说明，保留原始字节。\n".toByteArray(Charsets.UTF_8),
                "notes/额外/metadata-$index.json" to "{\"package\":$index,\"支持\":false}\n".toByteArray(Charsets.UTF_8),
            )
            val name = "舰娘包-${index.toString().padStart(2, '0')}"
            public.resolve("$name.zip").writeBytes(zip(files, index % 2 == 0))
            name to files
        }
        val expectedSourceBytes = fixtures.values.sumOf { files -> files.values.sumOf { it.size.toLong() } }
        val originalZipHashes = public.listFiles()!!.associate { it.name to sha256(it.readBytes()) }
        val repository = GameModRepository(privateRoot)
        val library = GameModLibrary(GameModFileLibraryStore(public), libraryWorkspace)
        val coordinator = GameModLibraryCoordinator(repository, library, coordinatorWorkspace)
        val timings = linkedMapOf<String, Long>()
        fun <T> timed(label: String, block: () -> T): T {
            val started = System.nanoTime()
            return block().also { timings[label] = (System.nanoTime() - started) / 1_000_000 }
        }

        // Cancelling a full preview must neither consume any ZIP nor publish a partial batch.
        val cancelled = timed("cancelledScanMs") { coordinator.scan() }
        assertScan(cancelled, "new")
        coordinator.discardScan(cancelled["token"] as String)
        assertTrue(packages(repository).isEmpty())
        assertEquals(0, library.status()["packageCount"])
        assertEquals(originalZipHashes, public.listFiles()!!.associate { it.name to sha256(it.readBytes()) })
        assertTrue("Discard must release every staged package", libraryWorkspace.listFiles()!!.isEmpty())

        val first = timed("rescanAfterCancelMs") { coordinator.scan() }
        assertScan(first, "new")
        timed("commitScanMs") { coordinator.commitScan(first["token"] as String) }
        val imported = packages(repository)
        assertInventory(imported)
        assertEquals(52, library.status()["packageCount"])
        assertTrue("Successful import consumes all original ZIPs", public.listFiles()!!.none { it.extension == "zip" })
        assertEquals(52, public.listFiles()!!.count { it.isDirectory })
        val initialStatus = repository.status()
        assertEquals(false, config(initialStatus, "draft")["master"])
        assertEquals(emptyList<String>(), config(initialStatus, "draft")["enabledPackages"])
        assertEquals(emptyList<String>(), config(initialStatus, "applied")["enabledPackages"])
        imported.flatMap(::resources).filter { it["supported"] == true }.forEach { resource ->
            assertNull("A newly imported package must be inactive", read(repository, resource["path"] as String))
        }

        // Hash every file in both editable source trees and immutable private exports, including
        // the unsupported companions. Directory entries and empty directories are not resources.
        val publicPackages = (library.status()["packages"] as List<*>).filterIsInstance<Map<*, *>>()
        var exportedBytes = 0L
        imported.forEach { pack ->
            val expected = fixtures.getValue(pack["name"] as String)
            val expectedHashes = expected.mapValues { sha256(it.value) }
            val record = publicPackages.single { it["id"] == pack["id"] }
            val tree = public.resolve(record["path"] as String)
            assertTrue(tree.resolve(".nomedia").isFile)
            assertEquals(expectedHashes, treeHashes(tree, omitMarker = true))
            val export = temporary.newFolder()
            repository.exportPackageTree(pack["id"] as String, export)
            assertEquals("Every source file must survive private import and export", expectedHashes, treeHashes(export))
            exportedBytes += export.walkTopDown().filter { it.isFile }.sumOf { it.length() }
        }
        assertEquals(expectedSourceBytes, exportedBytes)

        val beforeRepeat = packages(repository)
        val repeated = timed("repeatScanMs") { coordinator.scan() }
        assertScan(repeated, "unchanged")
        timed("repeatCommitMs") { coordinator.commitScan(repeated["token"] as String) }
        assertEquals("Repeat confirmation must not add or replace packages", beforeRepeat, packages(repository))

        // Enable only two resources from each of three packages, leaving every other import off.
        val chosenPackages = imported.filter { it["name"] in setOf("舰娘包-01", "舰娘包-26", "舰娘包-52") }
        val chosenIds = chosenPackages.map { it["id"] as String }
        val chosenResources = chosenPackages.flatMap { pack -> resources(pack).filter { it["supported"] == true }.take(2) }
        val chosenResourceIds = chosenResources.map { it["id"] as String }
        val order = imported.map { it["id"] as String }.reversed()
        repository.saveDraft(mapOf("master" to true, "order" to order,
            "enabledPackages" to chosenIds, "enabledResources" to chosenResourceIds))
        repository.finishApply(repository.applyDraft())
        coordinator.applied(emptyList())
        val applied = repository.exportAppliedConfiguration()
        assertEquals(3, (config(repository.status(), "applied")["enabledPackages"] as List<*>).size)
        assertSelectedBytes(repository, imported, fixtures, chosenResourceIds.toSet())

        repository.saveDraft(mapOf("master" to false, "order" to order.reversed(),
            "enabledPackages" to emptyList<String>(), "enabledResources" to emptyList<String>()))
        repository.cancelChanges()
        assertEquals(config(repository.status(), "applied"), config(repository.status(), "draft"))
        val afterCancel = timed("scanAfterCancelChangesMs") { coordinator.scan() }
        assertScan(afterCancel, "unchanged")
        coordinator.commitScan(afterCancel["token"] as String)
        assertEquals(applied, repository.exportAppliedConfiguration())
        assertEquals(config(repository.status(), "applied"), config(repository.status(), "draft"))
        assertSelectedBytes(repository, packages(repository), fixtures, chosenResourceIds.toSet())

        // A fresh repository and library must retain the same inventory and saved choices.
        val restartedRepository = GameModRepository(privateRoot)
        val restartedLibrary = GameModLibrary(GameModFileLibraryStore(public), temporary.newFolder("restart-library"))
        val restartedCoordinator = GameModLibraryCoordinator(restartedRepository, restartedLibrary,
            temporary.newFolder("restart-coordinator"))
        assertEquals(applied, restartedRepository.exportAppliedConfiguration())
        // Gson reads JSON version numbers as Double; compare the persisted JSON values.
        assertEquals(Gson().toJsonTree(applied), Gson().toJsonTree(restartedLibrary.appliedConfiguration()))
        val restartedScan = timed("restartScanMs") { restartedCoordinator.scan() }
        assertScan(restartedScan, "unchanged")
        assertEquals(false, restartedScan["restoreAvailable"])
        restartedCoordinator.commitScan(restartedScan["token"] as String)
        assertInventory(packages(restartedRepository))
        assertEquals(beforeRepeat, packages(restartedRepository))
        assertEquals(applied, restartedRepository.exportAppliedConfiguration())
        assertSelectedBytes(restartedRepository, packages(restartedRepository), fixtures, chosenResourceIds.toSet())
        assertNull(coordinator.status()["error"])
        assertNull(restartedCoordinator.status()["error"])
        println("MOD_MANY_FILES_SMOKE packages=52 supportedPngs=208 unsupportedFiles=104 sourceFiles=312 sourceBytes=$expectedSourceBytes exportedBytes=$exportedBytes " +
            timings.entries.joinToString(" ") { "${it.key}=${it.value}" })
    }

    private fun assertScan(scan: Map<String, Any?>, kind: String) {
        val entries = (scan["entries"] as List<*>).filterIsInstance<Map<*, *>>()
        assertEquals(52, entries.size)
        assertEquals(52, entries.count { it["kind"] == kind })
        assertEquals(52, entries.map { it["path"] }.distinct().size)
        assertEquals(312, entries.sumOf { (it["resourceCount"] as Number).toInt() })
        assertEquals(208, entries.sumOf { (it["supportedCount"] as Number).toInt() })
        assertEquals(104, entries.sumOf { (it["unsupportedCount"] as Number).toInt() })
        entries.forEach { assertNull(it["error"]) }
    }

    private fun assertInventory(packages: List<Map<*, *>>) {
        assertEquals(52, packages.size)
        assertEquals(52, packages.map { it["id"] }.distinct().size)
        assertEquals(312, packages.sumOf { resources(it).size })
        assertEquals(312, packages.sumOf { (it["sourceFileCount"] as Number).toInt() })
        assertEquals(208, packages.flatMap(::resources).count { it["supported"] == true })
        assertEquals(104, packages.flatMap(::resources).count { it["supported"] == false })
        packages.forEach { pack ->
            assertEquals(6, resources(pack).size)
            assertEquals(6, (pack["sourceFileCount"] as Number).toInt())
            assertFalse(resources(pack).any { (it["path"] as String).endsWith('/') })
        }
    }

    private fun assertSelectedBytes(repository: GameModRepository, packages: List<Map<*, *>>,
        fixtures: Map<String, Map<String, ByteArray>>, selected: Set<String>) {
        packages.forEach { pack -> resources(pack).forEach { resource ->
            val path = resource["path"] as String
            val actual = read(repository, path)
            if (resource["id"] in selected) assertArrayEquals("Selected resource $path",
                fixtures.getValue(pack["name"] as String).getValue(path), actual)
            else assertNull("Unselected or unsupported resource must remain inactive: $path", actual)
        } }
    }

    private fun read(repository: GameModRepository, path: String): ByteArray? =
        repository.openResource("https://w01x.kancolle-server.com/$path", "GET", emptyMap())
            ?.inputStream?.use { it.readBytes() }

    private fun packages(repository: GameModRepository) = (repository.status()["packages"] as List<*>).filterIsInstance<Map<*, *>>()
    private fun resources(pack: Map<*, *>) = (pack["resources"] as List<*>).filterIsInstance<Map<*, *>>()
    private fun config(status: Map<String, Any?>, key: String) = status[key] as Map<*, *>
    private fun treeHashes(directory: File, omitMarker: Boolean = false): Map<String, String> = directory.walkTopDown()
        .filter { it.isFile && !(omitMarker && it.parentFile == directory && it.name in setOf(".yahagi-package.json", ".nomedia")) }
        .associate { it.relativeTo(directory).invariantSeparatorsPath to sha256(it.readBytes()) }
    private fun sha256(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes)
        .joinToString("") { "%02x".format(it.toInt() and 255) }

    private fun zip(files: Map<String, ByteArray>, cachePrefix: Boolean): ByteArray = ByteArrayOutputStream().also { output ->
        ZipOutputStream(output).use { zip ->
            val prefix = if (cachePrefix) "cache/" else ""
            (listOf("${prefix}空目录/", "${prefix}空目录/无文件/", "${prefix}kcs2/", "${prefix}说明/") +
                if (cachePrefix) listOf("cache/") else emptyList()).forEach { directory ->
                zip.putNextEntry(ZipEntry(directory)); zip.closeEntry()
            }
            files.forEach { (path, bytes) ->
                zip.putNextEntry(ZipEntry(prefix + path)); zip.write(bytes); zip.closeEntry()
            }
        }
    }.toByteArray()

    private fun png(packageIndex: Int, resourceIndex: Int): ByteArray = ByteArrayOutputStream().also { output ->
        val data = DataOutputStream(output)
        data.write(byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10))
        fun chunk(name: String, bytes: ByteArray) {
            val tag = name.toByteArray(Charsets.US_ASCII)
            data.writeInt(bytes.size); data.write(tag); data.write(bytes)
            data.writeInt(CRC32().also { it.update(tag); it.update(bytes) }.value.toInt())
        }
        chunk("IHDR", ByteArrayOutputStream().also {
            DataOutputStream(it).apply { writeInt(1); writeInt(1); write(byteArrayOf(8, 6, 0, 0, 0)) }
        }.toByteArray())
        chunk("IDAT", ByteArrayOutputStream().also { compressed ->
            DeflaterOutputStream(compressed).use { it.write(byteArrayOf(0, packageIndex.toByte(), resourceIndex.toByte(), 0, -1)) }
        }.toByteArray())
        chunk("IEND", byteArrayOf())
    }.toByteArray()
}
