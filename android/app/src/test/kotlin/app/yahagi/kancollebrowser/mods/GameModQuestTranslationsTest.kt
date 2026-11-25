package app.yahagi.kancollebrowser.mods

import com.google.gson.Gson
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

class GameModQuestTranslationsTest {
    @get:Rule val temporary = TemporaryFolder()

    private val questPath = "text/api/questlist.json"

    @Test fun `selected quest table is delivered only by the local config and follows package priority`() {
        val root = temporary.newFolder()
        val repo = GameModRepository(root)
        val first = importTable(repo, jsonc("击破敌舰队！"), path = "release/$questPath")
        val second = importTable(repo, jsonc("另一个任务标题"))
        val firstId = first["id"] as String
        val secondId = second["id"] as String
        val firstResource = resource(first)["id"] as String
        val secondResource = resource(second)["id"] as String
        val order = listOf(firstId, secondId)
        assertEquals("quest_translation", resource(first)["kind"])
        assertEquals(listOf(questPath), resource(first)["targetPaths"])
        assertEquals(0, translations(repo).size())

        fun select(master: Boolean = true, selected: List<String> = listOf(firstResource, secondResource),
            priority: List<String> = order, enabled: List<String> = order) {
            repo.saveDraft(mapOf("master" to master, "order" to priority, "enabledPackages" to enabled,
                "enabledResources" to selected))
        }

        select()
        apply(repo)
        assertEquals("击破敌舰队！", translations(repo)["201"].asJsonObject["title"].asString)
        assertEquals("说明 // 保留 /* 原文 */<br>下一行", translations(repo)["201"].asJsonObject["detail"].asString)
        assertEquals(1, translations(repo).size())
        assertNull(repo.openResource("https://w15p.kancolle-server.com/$questPath", "GET", emptyMap()))
        assertNull(repo.openResource("https://w15p.kancolle-server.com/kcsapi/api_get_member/questlist", "GET", emptyMap()))

        select(priority = order.reversed())
        assertEquals("击破敌舰队！", translations(repo)["201"].asJsonObject["title"].asString)
        apply(repo)
        assertEquals("另一个任务标题", translations(GameModRepository(root))["201"].asJsonObject["title"].asString)

        select(selected = listOf(firstResource))
        apply(repo)
        assertEquals("击破敌舰队！", translations(repo)["201"].asJsonObject["title"].asString)
        select(enabled = emptyList())
        apply(repo)
        assertEquals(0, translations(repo).size())
        select(master = false)
        apply(repo)
        assertEquals(0, translations(repo).size())
    }

    @Test fun `malformed or unsafe whitelisted translations fail while other JSON remains unsupported`() {
        val repo = GameModRepository(temporary.newFolder())
        val cases = listOf(
            "[]",
            """[{"api_no":0,"api_title":"title","api_detail":"detail"}]""",
            """[{"api_no":"201","api_title":"title","api_detail":"detail"}]""",
            """[{"api_no":20/*comment*/1,"api_title":"title","api_detail":"detail"}]""",
            """[{"api_no":201,"api_title":"<br>title","api_detail":"detail"}]""",
            """[{"api_no":201,"api_title":"title","api_detail":"\u003cimg src=x onerror=x\u003e"}]""",
            """[{"api_no":201,"api_title":"title","api_detail":"\ud800"}]""",
            """[{"api_no":201,"api_title":"title","api_detail":"detail","api_detail":"other"}]""",
            """[{"api_no":201,"api_title":"title","api_detail":"detail","extra":{"code":"data"}}]""",
            """[{"api_no":201,"api_title":"title","api_detail":"detail"},{"api_no":201,"api_title":"conflict","api_detail":"detail"}]""",
            jsonc("a".repeat(200)),
        )
        for (text in cases) {
            try {
                repo.preflight(zip(questPath to text.toByteArray()), "invalid.zip")
                fail("Should reject invalid quest translations")
            } catch (error: GameModException) {
                assertEquals("invalid_quest_translation", error.code)
            }
        }
        val other = repo.preflight(zip("text/api/another.json" to byteArrayOf(0), "text/api/questlist.hack.json" to byteArrayOf(0)),
            "unrelated.zip")
        assertEquals(0, other["supportedCount"])
        assertEquals(2, other["unsupportedCount"])
    }

    @Test fun `public ZIP scans preserve the exact whitelist through extraction and revalidation`() {
        val publicRoot = temporary.newFolder()
        val repo = GameModRepository(temporary.newFolder())
        val library = GameModLibrary(GameModFileLibraryStore(publicRoot), temporary.newFolder())
        val coordinator = GameModLibraryCoordinator(repo, library, temporary.newFolder())
        val alias = "text/api/questlist.hack.json"
        val archive = zip(questPath to jsonc("支持的任务").toByteArray(), alias to byteArrayOf(0))
        archive.use { input -> File(publicRoot, "quests.zip").outputStream().use { input.copyTo(it) } }

        val preview = coordinator.scan()
        coordinator.commitScan(preview["token"] as String)
        val pack = packages(repo).single()
        val resources = (pack["resources"] as List<*>).filterIsInstance<Map<*, *>>().associateBy { it["path"] }
        val resource = resources.getValue(questPath)
        assertEquals(true, resource["supported"])
        assertEquals(false, resources.getValue(alias)["supported"])
        repo.saveDraft(mapOf("master" to true, "order" to listOf(pack["id"]), "enabledPackages" to listOf(pack["id"]),
            "enabledResources" to listOf(resource["id"])))
        apply(repo)
        assertEquals("支持的任务", translations(repo)["201"].asJsonObject["title"].asString)
    }

    @Test fun `saved formerly unsupported table becomes a draft choice and keeps its identity through restart`() {
        val root = temporary.newFolder()
        val repo = GameModRepository(root)
        val pack = importTable(repo, jsonc("击破敌舰队！"))
        val id = pack["id"] as String
        val resourceId = resource(pack)["id"] as String
        repo.saveDraft(mapOf("master" to true, "order" to listOf(id), "enabledPackages" to listOf(id),
            "enabledResources" to listOf(resourceId)))
        apply(repo)

        val file = File(root, "state.json")
        val state = JsonParser.parseString(file.readText()).asJsonObject
        for (name in listOf("packages", "appliedPackages")) {
            val entry = state[name].asJsonArray.single().asJsonObject
            val legacy = entry["resources"].asJsonArray.single().asJsonObject
            legacy.addProperty("kind", "unsupported")
            legacy.addProperty("supported", false)
            legacy.addProperty("reason", "json_unsupported")
            entry["warnings"].asJsonArray.add("unsupported_files")
        }
        for (name in listOf("draft", "applied")) {
            state[name].asJsonObject["enabledResources"].asJsonArray.remove(0)
        }
        file.writeText(Gson().toJson(state))

        val upgraded = GameModRepository(root)
        val restored = packages(upgraded).single()
        assertEquals(resourceId, resource(restored)["id"])
        assertEquals("quest_translation", resource(restored)["kind"])
        assertTrue(resource(restored)["supported"] as Boolean)
        assertEquals(listOf(resourceId), (upgraded.status()["draft"] as Map<*, *>)["enabledResources"])
        assertEquals(emptyList<Any>(), (upgraded.status()["applied"] as Map<*, *>)["enabledResources"])
        assertEquals(0, translations(upgraded).size())
        assertTrue(upgraded.status()["pending"] as Boolean)
        upgraded.cancelChanges()

        val canceled = GameModRepository(root)
        assertEquals("quest_translation", resource(packages(canceled).single())["kind"])
        assertEquals(emptyList<Any>(), (canceled.status()["draft"] as Map<*, *>)["enabledResources"])
        assertFalse(canceled.status()["pending"] as Boolean)
        canceled.saveDraft(mapOf("master" to true, "order" to listOf(id), "enabledPackages" to listOf(id),
            "enabledResources" to listOf(resourceId)))
        apply(canceled)
        assertEquals("击破敌舰队！", translations(GameModRepository(root))["201"].asJsonObject["title"].asString)
    }

    @Test fun `official Asaico v1 4 quest table exposes all distinct IDs`() {
        val fixture = System.getenv("YAHAGI_REAL_QUEST_MOD_ZIP")
        assumeTrue("Set YAHAGI_REAL_QUEST_MOD_ZIP to Asaico v1.4.0", !fixture.isNullOrBlank())
        val table = ZipFile(File(fixture!!)).use { zip ->
            zip.getInputStream(zip.getEntry(questPath)).use { it.readBytes() }
        }
        val repo = GameModRepository(temporary.newFolder())
        val pack = importTable(repo, table)
        repo.saveDraft(mapOf("master" to true, "order" to listOf(pack["id"]), "enabledPackages" to listOf(pack["id"]),
            "enabledResources" to listOf(resource(pack)["id"])))
        apply(repo)
        val translated = translations(repo)
        assertEquals(652, translated.size())
        assertEquals("击破敌舰队！", translated["201"].asJsonObject["title"].asString)
        assertEquals("舰队出击，捕捉并消灭敌方舰队！<br>※胜利1次", translated["201"].asJsonObject["detail"].asString)
        assertEquals("精锐[第二二驱逐队]出击！", translated["863"].asJsonObject["title"].asString)
    }

    private fun translations(repo: GameModRepository) =
        GameModCoordinateEndpoint(repo::activeCoordinateSnapshot, repo::recordCoordinateResult)
            .open("https://w15p.kancolle-server.com/__yahagi_mods__/coordinates.json", "GET")!!
            .inputStream.bufferedReader().use { JsonParser.parseReader(it).asJsonObject["questTranslations"].asJsonObject }

    private fun importTable(repo: GameModRepository, text: String, path: String = questPath) =
        importTable(repo, text.toByteArray(), path)

    private fun importTable(repo: GameModRepository, bytes: ByteArray, path: String = questPath): Map<String, Any?> {
        val preview = repo.preflight(zip(path to bytes), "quest.zip")
        assertEquals(1, preview["supportedCount"])
        return repo.commitImport(preview["token"] as String)
    }

    @Suppress("UNCHECKED_CAST")
    private fun packages(repo: GameModRepository) = repo.status()["packages"] as List<Map<String, Any?>>

    @Suppress("UNCHECKED_CAST")
    private fun resource(pack: Map<String, Any?>) = (pack["resources"] as List<Map<String, Any?>>).single()

    private fun apply(repo: GameModRepository) = repo.finishApply(repo.applyDraft())

    private fun zip(vararg entries: Pair<String, ByteArray>): InputStream {
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { output ->
            for ((path, data) in entries) {
                output.putNextEntry(ZipEntry(path))
                output.write(data)
                output.closeEntry()
            }
        }
        return bytes.toByteArray().inputStream()
    }

    private fun jsonc(title: String): String = """
        [
          // Quest strings may contain comment markers.
          {"api_no":201,"api_title":"$title","api_detail":"说明 // 保留 /* 原文 */<br>下一行",},
          /* Identical duplicate quest rows are accepted. */
          {"api_no":201,"api_title":"$title","api_detail":"说明 // 保留 /* 原文 */<br>下一行"},
        ]
    """.trimIndent()
}
