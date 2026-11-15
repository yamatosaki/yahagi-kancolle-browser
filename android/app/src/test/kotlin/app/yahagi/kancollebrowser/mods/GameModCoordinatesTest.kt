package app.yahagi.kancollebrowser.mods

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.util.zip.CRC32
import java.util.zip.DeflaterOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import com.google.gson.JsonParser

class GameModCoordinatesTest {
    @get:Rule val temporary = TemporaryFolder()
    private val image = "kcs2/resources/ship/full/0001_secret.png"
    private val jsonPath = "kcs/resources/swf/ships/secret.config.json"
    private val iniPath = "kcs/resources/swf/ships/secret.config.ini"
    private val url get() = "https://w15p.kancolle-server.com/$image"

    @Test fun `equivalent INI JSON become one logical coordinate resource with two source paths`() {
        val repo = GameModRepository(temporary.newFolder())
        val preview = repo.preflight(zip(mapOf(image to png(), jsonPath to json(mapOf("api_boko_n" to listOf(1,2))),
            iniPath to "[graph]\nboko_n_left=1\nboko_n_top=2".toByteArray())), "dual.zip")
        assertEquals(2, preview["resourceCount"]); assertEquals(2, preview["supportedCount"]); assertEquals(3, preview["sourceFileCount"])
        val pack = repo.commitImport(preview["token"] as String)
        val coordinate = resources(pack).single { it["kind"] == "coordinates" }
        assertEquals("coordinates/ship/1", coordinate["path"])
        assertEquals("ship:0001", coordinate["groupId"])
        assertEquals(setOf(jsonPath, iniPath), (coordinate["sourcePaths"] as List<*>).toSet())
        assertEquals(listOf("coordinates/ship/1/api_boko_n"), coordinate["targetPaths"])
    }
    @Test fun `coordinate and image switches remain independent`() {
        val repo = GameModRepository(temporary.newFolder()); val pack = import(repo, mapOf("api_boko_n" to listOf(1,2)))
        val coordId = coordinate(pack)["id"] as String
        val imageId = resources(pack).single { it["kind"] == "ship" }["id"] as String
        enable(repo, setOf(coordId)); apply(repo)
        assertNull(repo.openResource(url, "GET", emptyMap()))
        assertEquals(listOf(1,2), graph(repo)["api_boko_n"])
        enable(repo, setOf(imageId)); apply(repo)
        assertEquals(emptyMap<String, Any>(), repo.activeCoordinateSnapshot()["ships"])
        assertArrayEquals(png(), repo.openResource(url, "GET", emptyMap())!!.inputStream.use { it.readBytes() })
    }
    @Test fun `exact Yubari portrait and coordinates enter and leave the same applied session`() {
        val repo = GameModRepository(temporary.newFolder())
        val full = "kcs2/resources/ship/full/0623_5644_tuzbqjvyptyt.png"
        val config = "kcs/resources/swf/ships/tuzbqjvyptyt.config.json"
        val portraitUrl = "https://w20h.kancolle-server.com/$full?version=1"
        val imageBytes = png()
        val pair = mapOf("api_boko_n" to listOf(261, 221))
        val preview = repo.preflight(zip(mapOf(full to imageBytes, config to json(pair))), "yubari.zip")
        assertEquals(2, preview["supportedCount"])
        val pack = repo.commitImport(preview["token"] as String)
        val imageId = resources(pack).single { it["kind"] == "ship" }["id"]
        val coordinateId = coordinate(pack)["id"]
        enable(repo)

        assertNull(repo.openResource(portraitUrl, "GET", emptyMap()))
        assertEquals(emptyList<Int>(), repo.activeCoordinateSnapshot(kanxyVpnActive = true)["localArtShips"])
        apply(repo)

        val snapshot = repo.activeCoordinateSnapshot(kanxyVpnActive = true)
        assertEquals(listOf(623), snapshot["localArtShips"])
        assertEquals(mapOf("623" to mapOf("graph" to pair, "resourceIds" to listOf(coordinateId))), snapshot["ships"])
        assertArrayEquals(imageBytes, repo.openResource(portraitUrl, "GET", emptyMap())!!.inputStream.use { it.readBytes() })
        val reopenedPortraitUrl = "$portraitUrl-yahagi-newdocument"
        assertArrayEquals(imageBytes, repo.openResource(reopenedPortraitUrl, "GET", emptyMap())!!.inputStream.use { it.readBytes() })
        assertTrue((repo.status()["hits"] as List<*>).contains(imageId))
        assertNull(repo.openResource(portraitUrl.replace("5644", "1000"), "GET", emptyMap()))

        repo.resetAll()
        assertEquals(listOf(623), repo.activeCoordinateSnapshot(kanxyVpnActive = true)["localArtShips"])
        apply(repo)
        assertNull(repo.openResource(portraitUrl, "GET", emptyMap()))
        val reset = repo.activeCoordinateSnapshot(kanxyVpnActive = true)
        assertEquals(emptyList<Int>(), reset["localArtShips"])
        assertEquals(emptyMap<String, Any>(), reset["ships"])
        assertNull(repo.activeCoordinateSnapshot()["localArtShips"])
    }

    @Test fun `coordinate fields use first package priority while complementary fields combine`() {
        val repo = GameModRepository(temporary.newFolder())
        val first = import(repo, mapOf("api_boko_n" to listOf(1,2), "api_boko_d" to listOf(3,4)))
        val second = import(repo, mapOf("api_boko_n" to listOf(9,9), "api_battle_n" to listOf(5,6)))
        enable(repo); apply(repo)
        assertEquals(mapOf("api_boko_n" to listOf(1,2), "api_boko_d" to listOf(3,4), "api_battle_n" to listOf(5,6)), graph(repo))
        val active = repo.status()["activeWinners"] as Map<*, *>
        assertEquals(coordinate(first)["id"], active["coordinates/ship/1/api_boko_n"])
        assertEquals(coordinate(second)["id"], active["coordinates/ship/1/api_battle_n"])
        enable(repo, order = listOf(second["id"] as String, first["id"] as String)); apply(repo)
        assertEquals(listOf(9,9), graph(repo)["api_boko_n"])
        assertEquals(listOf(3,4), graph(repo)["api_boko_d"])
    }
    @Test fun `only token and session validated game acknowledgement counts coordinate hits`() {
        val repo = GameModRepository(temporary.newFolder()); val pack = import(repo, mapOf("api_boko_n" to listOf(1,2)))
        enable(repo); apply(repo)
        val id = coordinate(pack)["id"] as String
        val imageId = resources(pack).single { it["kind"] == "ship" }["id"] as String
        val snapshot = repo.activeCoordinateSnapshot(); val session = snapshot["sessionId"] as Long; val token = snapshot["token"] as String
        assertTrue(token.isNotBlank()); assertEquals(emptyList<String>(), repo.status()["hits"])
        repo.recordCoordinateResult(session, "wrong", listOf(id))
        repo.recordCoordinateResult(session - 1, token, listOf(id))
        repo.recordCoordinateResult(session, token, listOf(imageId, "unknown"))
        assertEquals(emptyList<String>(), repo.status()["hits"])
        repo.recordCoordinateResult(session, token, listOf(id), "failed")
        assertEquals("coordinate_apply_failed", (repo.status()["failures"] as Map<*, *>)[id])
        repo.recordCoordinateResult(session, token, listOf(id))
        assertEquals(listOf(id), repo.status()["hits"])
        assertFalse((repo.status()["failures"] as Map<*, *>).containsKey(id))
        apply(repo)
        repo.recordCoordinateResult(session, token, listOf(id))
        assertEquals(emptyList<String>(), repo.status()["hits"])
    }
    @Test fun `restart persists merged graph and reset prevents stale reports`() {
        val root = temporary.newFolder(); val repo = GameModRepository(root)
        val pack = import(repo, mapOf("api_boko_n" to listOf(180,180))); enable(repo); apply(repo)
        val restored = GameModRepository(root)
        assertEquals(graph(repo), graph(restored))
        assertEquals(coordinate(pack)["sourcePaths"], coordinate(packages(restored).single())["sourcePaths"])
        val before = restored.activeCoordinateSnapshot()
        assertNotEquals(before["token"], repo.activeCoordinateSnapshot()["token"])
        restored.resetAll(); apply(restored)
        restored.recordCoordinateResult(before["sessionId"] as Long, before["token"] as String, listOf(coordinate(pack)["id"] as String))
        assertEquals(emptyMap<String,Any>(), restored.activeCoordinateSnapshot()["ships"])
        assertEquals(emptyList<String>(), restored.status()["hits"])
    }
    @Test fun `conflicting invalid and unbound coordinate configurations are explicit`() {
        val repo = GameModRepository(temporary.newFolder())
        try { repo.preflight(zip(mapOf(image to png(), jsonPath to json(mapOf("api_boko_n" to listOf(1,2))), iniPath to "[graph]\nboko_n_left=9\nboko_n_top=9".toByteArray())), "conflict.zip"); fail() }
        catch (error: GameModException) { assertEquals("coordinate_conflict", error.code) }
        try { repo.preflight(zip(mapOf(image to png(), jsonPath to "{}".toByteArray())), "invalid.zip"); fail() }
        catch (error: GameModException) { assertEquals("invalid_coordinates", error.code) }
        val preview = repo.preflight(zip(mapOf(image to png(), jsonPath.replace("secret", "unmatched") to json(mapOf("api_boko_n" to listOf(1,2))))), "unmatched.zip")
        assertEquals(0, preview["supportedCount"])
        val pack = repo.commitImport(preview["token"] as String)
        assertEquals("coordinate_unmatched", coordinate(pack)["reason"])
        assertEquals("coordinate_dependency_unresolved", resources(pack).single { it["kind"] == "ship" }["reason"])
    }
    @Test fun `published coordinate snapshots cannot be mutated by a caller`() {
        val repo = GameModRepository(temporary.newFolder()); import(repo, mapOf("api_boko_n" to listOf(1,2))); enable(repo); apply(repo)
        val snapshot = repo.activeCoordinateSnapshot()
        @Suppress("UNCHECKED_CAST") val ships = snapshot["ships"] as MutableMap<String, Any>
        @Suppress("UNCHECKED_CAST") val publicGraph = (ships["1"] as Map<String,Any>)["graph"] as MutableMap<String,List<Int>>
        publicGraph["api_boko_n"] = listOf(999,999); ships.clear()
        assertEquals(listOf(1,2), graph(repo)["api_boko_n"])
    }
    @Test fun `old version one image state without coordinate or source metadata remains readable`() {
        val root = temporary.newFolder(); val repo = GameModRepository(root)
        val preview = repo.preflight(zip(mapOf(image to png())), "legacy.zip"); repo.commitImport(preview["token"] as String)
        enable(repo); apply(repo)
        val index = root.resolve("state.json")
        val legacy = JsonParser.parseString(index.readText()).asJsonObject
        legacy["packages"].asJsonArray.forEach { pack -> pack.asJsonObject["resources"].asJsonArray.forEach { resource ->
            listOf("sourcePaths", "coordinateShipId", "coordinateGraph").forEach { resource.asJsonObject.remove(it) }
        } }
        index.writeText(legacy.toString())
        val restored = GameModRepository(root)
        assertEquals(listOf(image), resources(packages(restored).single()).single()["sourcePaths"])
        assertEquals(emptyMap<String,Any>(), restored.activeCoordinateSnapshot()["ships"])
        assertArrayEquals(png(), restored.openResource(url, "GET", emptyMap())!!.inputStream.use { it.readBytes() })
    }
    @Test fun `unmatched malicious and empty stems cannot poison the durable index`() {
        listOf("..config.ini", ".config.ini", "...config.ini", "config.ini").forEach { name ->
            val root = temporary.newFolder(); val repo = GameModRepository(root)
            val path = "kcs/resources/swf/ships/$name"
            val preview = repo.preflight(zip(mapOf(path to "[graph]\nboko_n_left=1\nboko_n_top=2".toByteArray())), "unmatched.zip")
            repo.commitImport(preview["token"] as String)
            val restored = GameModRepository(root)
            val resource = resources(packages(restored).single()).single()
            assertEquals("coordinate_unmatched", resource["reason"])
            assertEquals(listOf(path), resource["sourcePaths"])
            assertTrue((resource["path"] as String).split('/').none { it.isEmpty() || it == "." || it == ".." })
        }
    }
    @Test fun `ordinary source files cannot collide with a derived coordinate logical target`() {
        val repo = GameModRepository(temporary.newFolder())
        try {
            repo.preflight(zip(mapOf(image to png(), jsonPath to json(mapOf("api_boko_n" to listOf(1,2))),
                "coordinates/ship/1" to "unmapped file".toByteArray())), "collision.zip")
            fail("Derived resource targets must be unique before commit")
        } catch (error: GameModException) { assertEquals("duplicate_resource", error.code) }
        assertTrue(packages(repo).isEmpty())
    }

    private fun import(repo: GameModRepository, graph: Map<String,List<Int>>): Map<String,Any?> {
        val preview = repo.preflight(zip(mapOf(image to png(), jsonPath to json(graph))), "ship.zip")
        return repo.commitImport(preview["token"] as String)
    }
    @Suppress("UNCHECKED_CAST") private fun packages(repo: GameModRepository) = repo.status()["packages"] as List<Map<String,Any?>>
    @Suppress("UNCHECKED_CAST") private fun resources(pack: Map<String,Any?>) = pack["resources"] as List<Map<String,Any?>>
    private fun coordinate(pack: Map<String,Any?>) = resources(pack).single { it["kind"] == "coordinates" }
    @Suppress("UNCHECKED_CAST") private fun graph(repo: GameModRepository) = (((repo.activeCoordinateSnapshot()["ships"] as Map<*, *>)["1"] as Map<*, *>)["graph"] as Map<String,List<Int>>)
    private fun enable(repo: GameModRepository, ids: Set<String> = packages(repo).flatMap(::resources).filter { it["supported"] == true }.map { it["id"] as String }.toSet(),
        order: List<String> = packages(repo).map { it["id"] as String }) = repo.saveDraft(mapOf("master" to true, "order" to order, "enabledPackages" to order, "enabledResources" to ids.toList()))
    private fun apply(repo: GameModRepository) = repo.finishApply(repo.applyDraft())
    private fun json(graph: Map<String,List<Int>>) = ("{\"api_mst_ship\":{\"api_name\":false},\"api_mst_shipgraph\":{" + graph.entries.joinToString(",") { (key,value) -> "\"$key\":[${value.joinToString(",")}]" } + "}}").toByteArray()
    private fun zip(files: Map<String,ByteArray>) = ByteArrayOutputStream().also { out -> ZipOutputStream(out).use { zip -> files.forEach { (path, data) -> zip.putNextEntry(ZipEntry(path)); zip.write(data); zip.closeEntry() } } }.toByteArray().inputStream()
    private fun png(): ByteArray = ByteArrayOutputStream().also { out ->
        val data = DataOutputStream(out); data.write(byteArrayOf(-119,80,78,71,13,10,26,10))
        fun chunk(kind: String, content: ByteArray) { val type=kind.toByteArray(); data.writeInt(content.size);data.write(type);data.write(content);data.writeInt(CRC32().apply{update(type);update(content)}.value.toInt()) }
        val header=ByteArrayOutputStream().also{DataOutputStream(it).apply{writeInt(1);writeInt(1);write(byteArrayOf(8,6,0,0,0))}}.toByteArray()
        val compressed=ByteArrayOutputStream().also{DeflaterOutputStream(it).use{z->z.write(byteArrayOf(0,0,0,0,-1))}}.toByteArray()
        chunk("IHDR",header);chunk("IDAT",compressed);chunk("IEND",byteArrayOf())
    }.toByteArray()
}
