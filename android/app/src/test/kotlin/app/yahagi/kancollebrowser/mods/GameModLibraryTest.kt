package app.yahagi.kancollebrowser.mods

import com.google.gson.JsonParser
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.File
import java.util.UUID
import java.util.zip.CRC32
import java.util.zip.DeflaterOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class GameModLibraryTest {
    @get:Rule val temporary = TemporaryFolder()
    private val path = "kcs2/resources/ship/full/0001_1234_secret.png"

    @Test fun `migration keeps editable files and stable package id across reinstall`() {
        val root = temporary.newFolder(); val tree = temporary.newFolder()
        tree.resolve(path).apply { parentFile.mkdirs(); writeBytes(png()) }
        val id = UUID.randomUUID().toString()
        val library = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        library.savePackage(id, "伊47", tree)
        val config = mapOf("schemaVersion" to 1, "master" to true, "order" to listOf(id),
            "enabledPackages" to listOf(id), "enabledResources" to mapOf(id to listOf(path)))
        library.saveAppliedConfiguration(config)
        val fresh = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        assertEquals(listOf(id), fresh.appliedConfiguration()!!["order"])
        val scan = fresh.scan()
        val candidate = fresh.acceptScan(scan.token).single()
        assertEquals(id, candidate.id)
        assertEquals("unchanged", candidate.status)
        assertTrue(root.walkTopDown().any { it.isFile && it.invariantSeparatorsPath.endsWith(path) })
        assertTrue(candidate.archive.isFile)
    }

    @Test fun `scan detects same size content update even when modification time is unchanged`() {
        val root = temporary.newFolder(); val tree = temporary.newFolder()
        tree.resolve(path).apply { parentFile.mkdirs(); writeBytes(png(0)) }
        val library = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        library.savePackage(UUID.randomUUID().toString(), "Ship", tree)
        val image = root.walkTopDown().first { it.name == "0001_1234_secret.png" }
        val before = image.lastModified(); val size = image.length()
        image.writeBytes(png(1)); image.setLastModified(before)
        assertEquals(size, image.length())
        assertEquals("updated", library.scan().items.single()["status"])
    }

    @Test fun `root ZIP is imported once then unchanged source does not duplicate its editable folder`() {
        val root = temporary.newFolder(); root.resolve("cache.zip").writeBytes(zip(path to png()))
        val library = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        val first = library.scan(); assertEquals("new", first.items.single()["status"])
        val candidate = library.acceptScan(first.token).single()
        assertEquals(1, library.scan().items.count { it["status"] in listOf("new", "updated", "unchanged") })
        assertEquals(candidate.id, library.acceptScan(library.scan().token).single().id)
        assertTrue(root.resolve("cache.zip").isFile)
    }

    @Test fun `invalid edited image is reported and old package and applied settings stay intact`() {
        val root = temporary.newFolder(); val tree = temporary.newFolder()
        tree.resolve(path).apply { parentFile.mkdirs(); writeBytes(png()) }
        val id = UUID.randomUUID().toString()
        val library = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        library.savePackage(id, "Ship", tree)
        library.saveAppliedConfiguration(mapOf("schemaVersion" to 1, "order" to listOf(id)))
        root.walkTopDown().first { it.name.endsWith("secret.png") }.writeText("partial copy")
        val scan = library.scan()
        assertEquals("invalid", scan.items.single()["status"])
        assertTrue(library.acceptScan(scan.token).isEmpty())
        assertEquals(listOf(id), library.appliedConfiguration()!!["order"])
    }

    @Test fun `delete is explicit and never removes ZIP outside library`() {
        val root = temporary.newFolder(); val tree = temporary.newFolder(); val outside = temporary.newFile("outside.zip")
        outside.writeBytes(zip(path to png()))
        tree.resolve(path).apply { parentFile.mkdirs(); writeBytes(png()) }
        val id = UUID.randomUUID().toString()
        val library = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        library.savePackage(id, "Ship", tree)
        assertTrue(library.deletePackages(listOf(id)).isEmpty())
        assertTrue(library.scan().items.none { it["status"] == "new" })
        assertTrue(outside.isFile)
        root.resolve("cache.zip").writeBytes(outside.readBytes())
        val scanned = library.acceptScan(library.scan().token).single()
        assertTrue(library.deletePackages(listOf(scanned.id)).isEmpty())
        assertFalse(root.resolve("cache.zip").exists())
        root.resolve("cache.zip").writeBytes(outside.readBytes())
        val readded = library.acceptScan(library.scan().token).single()
        assertNotEquals("An intentionally recopied ZIP is a new import after successful deletion", scanned.id, readded.id)
        assertTrue(outside.isFile)
    }

    @Test fun `file store rejects traversal and symbolic link escapes`() {
        val store = GameModFileLibraryStore(temporary.newFolder())
        try { store.openWrite("../escape"); fail("Traversal accepted") } catch (expected: GameModException) { assertEquals("unsafe_path", expected.code) }
    }

    @Test fun `new unpacked folder gains marker only after acceptance and missing folder is reported`() {
        val root = temporary.newFolder(); root.resolve("my ship/$path").apply {parentFile.mkdirs();writeBytes(png())}
        val library = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        val preview = library.scan()
        assertEquals("new", preview.items.single()["status"])
        assertFalse(root.resolve("my ship/.yahagi-package.json").exists())
        val imported = library.acceptScan(preview.token).single()
        assertTrue(root.resolve("my ship/.yahagi-package.json").exists())
        root.resolve("my ship").deleteRecursively()
        assertEquals(imported.id, library.scan().items.single()["id"])
        assertEquals("missing", library.scan().items.single()["status"])
    }

    @Test fun `source changed after scan cannot be silently accepted`() {
        val root=temporary.newFolder(); root.resolve("ship/$path").apply {parentFile.mkdirs();writeBytes(png())}
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        val preview=library.scan()
        root.resolve("ship/$path").writeBytes(png(1))
        try { library.acceptScan(preview.token); fail("Changed source accepted") }
        catch (expected: GameModException) { assertEquals("library_changed",expected.code) }
        assertFalse(root.resolve("ship/.yahagi-package.json").exists())
    }

    @Test fun `failed deletion is tombstoned and scan never resurrects the package`() {
        val root=temporary.newFolder(); val tree=temporary.newFolder();tree.resolve(path).apply {parentFile.mkdirs();writeBytes(png())}
        val files=GameModFileLibraryStore(root)
        val store=object:GameModLibraryStore by files {override fun delete(relative:String):Boolean=false}
        val library=GameModLibrary(store,temporary.newFolder());val id=UUID.randomUUID().toString()
        library.savePackage(id,"Ship",tree)
        assertTrue(library.deletePackages(listOf(id)).isNotEmpty())
        val restored=GameModLibrary(files,temporary.newFolder())
        assertTrue(restored.scan().items.none { it["status"] in listOf("new","updated","unchanged") })
        assertTrue(restored.deletePackages(listOf(id)).isEmpty())
    }

    @Test fun `truncated newest configuration falls back to last complete saved version`() {
        val root=temporary.newFolder();val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        library.saveAppliedConfiguration(mapOf("schemaVersion" to 1,"order" to listOf("first")))
        library.saveAppliedConfiguration(mapOf("schemaVersion" to 1,"order" to listOf("second")))
        val newest=root.listFiles()!!.filter {it.extension=="json"}.maxBy {JsonParser.parseString(it.readText()).asJsonObject["generation"].asLong}
        newest.writeText("{partial")
        val restored=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        assertEquals(listOf("first"),restored.appliedConfiguration()!!["order"])
    }

    @Test fun `changed root ZIP updates original UUID without creating another package`() {
        val root=temporary.newFolder(); val source=root.resolve("cache.zip");source.writeBytes(zip(path to png()))
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        val first=library.acceptScan(library.scan().token).single()
        source.writeBytes(zip(path to png(1)))
        val preview=library.scan()
        assertEquals(1,preview.items.count {it["status"] in listOf("new","updated","unchanged")})
        val updated=library.acceptScan(preview.token).single()
        assertEquals(first.id,updated.id);assertEquals("updated",updated.status)
        assertNotEquals(first.contentHash,updated.contentHash)
        assertEquals(1,library.scan().items.count {it["status"] in listOf("new","updated","unchanged")})
    }

    @Test fun `a copied ZIP is reported duplicate instead of guessing overwrite by filename`() {
        val root=temporary.newFolder();root.resolve("first.zip").writeBytes(zip(path to png()))
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        library.acceptScan(library.scan().token)
        root.resolve("second.zip").writeBytes(zip(path to png()))
        val scan=library.scan()
        assertEquals(1,scan.items.count {it["status"]=="duplicate"})
        assertEquals(1,library.acceptScan(scan.token).size)
    }

    @Test fun `same display names do not overwrite other package folders`() {
        val root=temporary.newFolder(); val first=temporary.newFolder();val second=temporary.newFolder()
        first.resolve(path).apply {parentFile.mkdirs();writeBytes(png())}
        second.resolve(path).apply {parentFile.mkdirs();writeBytes(png(1))}
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        val one=library.savePackage(UUID.randomUUID().toString(),"Same name",first)
        val two=library.savePackage(UUID.randomUUID().toString(),"Same name",second)
        assertNotEquals(one["path"],two["path"])
        assertEquals(2,library.scan().items.count {it["status"]=="unchanged"})
    }

    @Test fun `failed scan discard has no public file side effects`() {
        val root=temporary.newFolder();root.resolve("cache.zip").writeBytes(zip(path to png()))
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        val scan=library.scan();library.discardScan(scan.token)
        assertEquals(listOf("cache.zip"),root.list()!!.toList())
        try {library.acceptScan(scan.token);fail("Expired token accepted")}
        catch(expected:GameModException) {assertEquals("invalid_token",expected.code)}
    }

    @Test fun `provider without rename can import editable files and restore configuration`() {
        val root=temporary.newFolder();val files=GameModFileLibraryStore(root)
        val store=object:GameModLibraryStore by files {override fun rename(from:String,to:String):Boolean=false}
        val tree=temporary.newFolder();tree.resolve(path).apply {parentFile.mkdirs();writeBytes(png())}
        val library=GameModLibrary(store,temporary.newFolder());val id=UUID.randomUUID().toString()
        library.savePackage(id,"Ship",tree)
        library.saveAppliedConfiguration(mapOf("schemaVersion" to 1,"order" to listOf(id)))
        val restored=GameModLibrary(files,temporary.newFolder())
        assertEquals(id,restored.acceptScan(restored.scan().token).single().id)
        assertEquals(listOf(id),restored.appliedConfiguration()!!["order"])
    }

    @Test fun `damaged package marker is invalid rather than imported with a new identity`() {
        val root=temporary.newFolder();val tree=temporary.newFolder();tree.resolve(path).apply {parentFile.mkdirs();writeBytes(png())}
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        library.savePackage(UUID.randomUUID().toString(),"Ship",tree)
        root.walkTopDown().first {it.name==".yahagi-package.json"}.writeText("{partial")
        val scan=library.scan()
        assertEquals("invalid",scan.items.single()["status"])
        assertTrue(library.acceptScan(scan.token).isEmpty())
    }

    @Test fun `content fingerprint includes file boundaries and cannot confuse file bytes with another path`() {
        val root=temporary.newFolder();val one=temporary.newFolder();val two=temporary.newFolder()
        listOf(one,two).forEach {it.resolve(path).apply {parentFile.mkdirs();writeBytes(png())}}
        one.resolve("a.bin").writeBytes("x\u0000b.bin\u0000y".toByteArray())
        two.resolve("a.bin").writeText("x");two.resolve("b.bin").writeText("y")
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder())
        val first=library.savePackage(UUID.randomUUID().toString(),"First",one)
        val second=library.savePackage(UUID.randomUUID().toString(),"Second",two)
        assertNotEquals(first["contentHash"],second["contentHash"])
    }

    @Test fun `changing known folder marker identity is invalid and cannot silently become a new package`() {
        val root=temporary.newFolder();val tree=temporary.newFolder();tree.resolve(path).apply {parentFile.mkdirs();writeBytes(png())}
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder());val id=UUID.randomUUID().toString()
        val saved=library.savePackage(id,"Ship",tree)
        val marker=root.resolve("${saved["path"]}/.yahagi-package.json")
        val json=JsonParser.parseString(marker.readText()).asJsonObject
        json.addProperty("id",UUID.randomUUID().toString());marker.writeText(json.toString())
        val scan=library.scan()
        assertEquals(1,scan.items.size);assertEquals("invalid",scan.items.single()["status"])
        assertTrue(library.acceptScan(scan.token).isEmpty())
    }

    @Test fun `saving package never overwrites or deletes a folder whose marker now belongs to another id`() {
        val root=temporary.newFolder();val tree=temporary.newFolder();tree.resolve(path).apply {parentFile.mkdirs();writeBytes(png())}
        val library=GameModLibrary(GameModFileLibraryStore(root),temporary.newFolder());val id=UUID.randomUUID().toString()
        val saved=library.savePackage(id,"Ship",tree)
        val marker=root.resolve("${saved["path"]}/.yahagi-package.json");val changed=UUID.randomUUID().toString()
        val json=JsonParser.parseString(marker.readText()).asJsonObject;json.addProperty("id",changed);marker.writeText(json.toString())
        val newSave=library.savePackage(id,"Ship",tree)
        assertNotEquals(saved["path"],newSave["path"])
        assertEquals(changed,JsonParser.parseString(marker.readText()).asJsonObject["id"].asString)
        assertTrue(marker.parentFile!!.isDirectory)
    }

    @Test fun `local fingerprint rejects excessive directory depth before recursive resource handling`() {
        val tree=temporary.newFolder();var nested=tree
        repeat(70) {nested=File(nested,"d").apply {mkdir()}}
        File(nested,"x.bin").writeText("x")
        val library=GameModLibrary(GameModFileLibraryStore(temporary.newFolder()),temporary.newFolder())
        try {library.fingerprintLocalTree(tree);fail("Excessive nesting accepted")}
        catch(expected:GameModException) {assertEquals("quota_exceeded",expected.code)}
    }

    @Test fun `scan quota counts empty directories as entries too`() {
        val files=GameModFileLibraryStore(temporary.newFolder())
        val store=object:GameModLibraryStore by files {
            override fun list(relative:String):List<GameModLibraryEntry> = when(relative) {
                "" -> listOf(GameModLibraryEntry("Ship",true))
                "Ship" -> (1..20001).map {GameModLibraryEntry("d$it",true)}
                else -> emptyList()
            }
        }
        val library=GameModLibrary(store,temporary.newFolder())
        val scan=library.scan()
        assertEquals("invalid",scan.items.single()["status"])
        assertTrue((scan.items.single()["error"] as String).contains("20000"))
    }

    @Test fun `scan imports GBK outer wrapper ZIP and preserves hack override over plain backup`() {
        val root = temporary.newFolder()
        val moddedDay = png(1)
        val plainDay = png(2)
        val moddedNight = png(3)
        val plainNight = png(4)
        val shutter = png(5)
        val wrapper = "[舰colle] 硬盘挖出来的战斗界面魔改"
        val gbkZip = ByteArrayOutputStream().also { out ->
            ZipOutputStream(out, java.nio.charset.Charset.forName("GBK")).use { zip ->
                zip.putNextEntry(ZipEntry("$wrapper/")); zip.closeEntry()
                listOf(
                    "$wrapper/cover.png" to png(0),
                    "$wrapper/info.json" to "{\"name\":\"battle\"}".toByteArray(),
                    "$wrapper/kcs2/img/common/bg_map/bg_h.hack.png" to moddedDay,
                    "$wrapper/kcs2/img/common/bg_map/bg_h.png" to plainDay,
                    "$wrapper/kcs2/img/common/bg_map/bg_y.hack.png" to moddedNight,
                    "$wrapper/kcs2/img/common/bg_map/bg_y.png" to plainNight,
                    "$wrapper/kcs2/img/common/common_shutter.hack.png" to shutter,
                ).forEach { (name, bytes) ->
                    zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry()
                }
            }
        }.toByteArray()
        root.resolve("$wrapper.zip").writeBytes(gbkZip)
        val library = GameModLibrary(GameModFileLibraryStore(root), temporary.newFolder())
        val scan = library.scan()
        assertEquals("new", scan.items.single()["status"])
        assertEquals(3, scan.items.single()["supportedCount"])
        val candidate = library.acceptScan(scan.token).single()
        val folder = root.resolve(candidate.path)
        assertArrayEquals(moddedDay, folder.resolve("kcs2/img/common/bg_map/bg_h.png").readBytes())
        assertArrayEquals(moddedNight, folder.resolve("kcs2/img/common/bg_map/bg_y.png").readBytes())
        assertArrayEquals(shutter, folder.resolve("kcs2/img/common/common_shutter.png").readBytes())
    }

    private fun zip(vararg entries: Pair<String, ByteArray>): ByteArray = ByteArrayOutputStream().also { output ->
        ZipOutputStream(output).use { zip -> entries.forEach { (name, bytes) -> zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry() } }
    }.toByteArray()
    private fun png(value: Int = 0): ByteArray {
        val output = ByteArrayOutputStream(); val writer = DataOutputStream(output)
        writer.write(byteArrayOf(0x89.toByte(),0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a))
        fun chunk(type: String, bytes: ByteArray) { val tag=type.toByteArray(); writer.writeInt(bytes.size);writer.write(tag);writer.write(bytes);writer.writeInt(CRC32().also {it.update(tag);it.update(bytes)}.value.toInt()) }
        chunk("IHDR", ByteArrayOutputStream().also {DataOutputStream(it).apply {writeInt(1);writeInt(1);write(byteArrayOf(8,6,0,0,0))}}.toByteArray())
        chunk("IDAT", ByteArrayOutputStream().also {DeflaterOutputStream(it).use {it.write(byteArrayOf(0,value.toByte(),0,0,0xff.toByte()))}}.toByteArray())
        chunk("IEND", byteArrayOf()); return output.toByteArray()
    }
}
