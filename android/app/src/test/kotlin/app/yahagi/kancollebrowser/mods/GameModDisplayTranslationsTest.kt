package app.yahagi.kancollebrowser.mods

import com.google.gson.Gson
import com.google.gson.JsonObject
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

class GameModDisplayTranslationsTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun `local config carries only applied winners and table shapes`() {
        val root = temporary.newFolder()
        val repo = GameModRepository(root)
        val first = import(repo,
            "release/text/text/Fleetname.json" to """
                {
                    // Client data can contain comments and duplicate keys.
                    "第一艦隊": "原译",
                    "第二艦隊": "第二舰队",
                    "第一艦隊": "第一舰队<br>出击",
                }
            """.trimIndent(),
            "release/text/text_regex/terms.json" to """{"^に$":"","([0-9]+)隻":"$1艘","期間(\\d+)日":"共$1天"}""",
            "release/text/bgm_name/battle.json" to """{"1":{"ja":"出撃","zh":"出击"}}""",
            "release/text/bgm_name/titles.json" to """{"出撃":"出击"}""",
        )
        val second = import(repo, "text/text/Fleetname.json" to """{"第一艦隊":"另一个译名"}""")
        val order = listOf(first["id"], second["id"])
        val resourceIds = (resources(first) + resources(second)).map { it["id"] }
        assertEquals(listOf("bgm_translation", "bgm_translation", "text_regex_translation", "text_translation"),
            resources(first).map { it["kind"] as String }.sorted())
        assertNull(config(repo)["displayTranslations"])

        fun select(master: Boolean = true, selected: List<Any?> = resourceIds, priority: List<Any?> = order,
                   enabled: List<Any?> = order) {
            repo.saveDraft(mapOf("master" to master, "order" to priority, "enabledPackages" to enabled,
                "enabledResources" to selected))
        }
        fun literal(source: GameModRepository) = config(source).getAsJsonObject("displayTranslations")
            .getAsJsonObject("dictionaries").getAsJsonObject("Fleetname")

        select()
        assertNull(config(repo)["displayTranslations"])
        apply(repo)
        assertEquals("第一舰队<br>出击", literal(repo)["第一艦隊"].asString)
        val tables = config(repo).getAsJsonObject("displayTranslations")
        assertEquals(listOf("^に$", "([0-9]+)隻", """期間(\d+)日"""), tables.getAsJsonObject("regex").getAsJsonArray("terms").map {
            it.asJsonArray[0].asString
        })
        assertEquals("", tables.getAsJsonObject("regex").getAsJsonArray("terms")[0].asJsonArray[1].asString)
        assertEquals("出击", tables.getAsJsonObject("bgm").getAsJsonObject("battle").getAsJsonObject("1")["zh"].asString)
        assertEquals("出击", tables.getAsJsonObject("bgm").getAsJsonObject("titles")["出撃"].asString)
        assertNull(repo.openResource("https://w15p.kancolle-server.com/text/text/Fleetname.json", "GET", emptyMap()))

        select(priority = order.reversed())
        assertEquals("第一舰队<br>出击", literal(repo)["第一艦隊"].asString)
        apply(repo)
        assertEquals("另一个译名", literal(GameModRepository(root))["第一艦隊"].asString)
        select(selected = emptyList())
        apply(repo)
        assertNull(config(repo)["displayTranslations"])
        select(enabled = emptyList())
        apply(repo)
        assertNull(config(repo)["displayTranslations"])
        select(master = false)
        apply(repo)
        assertNull(config(repo)["displayTranslations"])
    }

    @Test fun `unrelated data stays unsupported and eligible tables require bounded safe data`() {
        val repo = GameModRepository(temporary.newFolder())
        val ignored = repo.preflight(archive(
            "text/text/subtitles/version.json" to "unvalidated",
            "text/api/start2.api_mst_ship.json" to "unvalidated",
            "text/text/items.hack.json" to "unvalidated",
            "text/bgm_name/battle.hack.json" to "unvalidated",
            "text/text_regex/terms.hack.json" to "unvalidated",
        ), "ignored.zip")
        assertEquals(0, ignored["supportedCount"])
        assertEquals(5, ignored["unsupportedCount"])

        val random = java.util.Random(0)
        val longText = buildString { repeat(3000) { append(('一'.code + random.nextInt(2000)).toChar()) } }
        val invalid = listOf(
            "text/text/items.json" to """{"艦船":{"zh":"舰船"}}""",
            "text/text/items.json" to """{"艦船":"<img onerror=x>"}""",
            "text/text/items.json" to """{"艦船":"\ud800"}""",
            "text/text/items.json" to """{"__proto__":"污染"}""",
            "text/text/items.json" to """{"艦船":"$longText"}""",
            "text/text_regex/terms.json" to """{"(a+)+$":"伤害"}""",
            "text/text_regex/terms.json" to """{"\\1匹配":"伤害"}""",
            "text/text_regex/terms.json" to """{"a*a*a*a*危険":"伤害"}""",
            "text/text_regex/terms.json" to """{"a+aa+aaa+ba危険":"伤害"}""",
            "text/bgm_name/battle.json" to """{"1":{"ja":"出撃","zh":"出击","script":"code"}}""",
            "text/bgm_name/port.json" to """{"notAnId":{"ja":"出撃","zh":"出击"}}""",
            "text/bgm_name/titles.json" to """{"出撃":432}""",
        )
        for ((path, source) in invalid) {
            try {
                repo.preflight(archive(path to source), "invalid.zip")
                fail("Should reject unsafe display translation data at $path")
            } catch (error: GameModException) {
                assertEquals("invalid_display_translation", error.code)
            }
        }
    }

    @Test fun `validated previously unsupported game data becomes a draft choice only`() {
        val root = temporary.newFolder()
        val repo = GameModRepository(root)
        val pack = import(repo, "text/text/items.json" to """{"艦船":"舰船"}""")
        val pkgId = pack["id"]
        val resourceId = resources(pack).single()["id"]
        repo.saveDraft(mapOf("master" to true, "order" to listOf(pkgId), "enabledPackages" to listOf(pkgId),
            "enabledResources" to listOf(resourceId)))
        apply(repo)

        val file = File(root, "state.json")
        val state = JsonParser.parseString(file.readText()).asJsonObject
        for (name in listOf("packages", "appliedPackages")) {
            val previous = state.getAsJsonArray(name)[0].asJsonObject
            val resource = previous.getAsJsonArray("resources")[0].asJsonObject
            resource.addProperty("kind", "unsupported")
            resource.addProperty("supported", false)
            resource.addProperty("reason", "json_unsupported")
            previous.getAsJsonArray("warnings").add("unsupported_files")
        }
        for (name in listOf("draft", "applied")) {
            state.getAsJsonObject(name).getAsJsonArray("enabledResources").remove(0)
        }
        file.writeText(Gson().toJson(state))

        val upgraded = GameModRepository(root)
        assertNull(config(upgraded)["displayTranslations"])
        apply(upgraded)
        assertEquals("舰船", config(upgraded).getAsJsonObject("displayTranslations")
            .getAsJsonObject("dictionaries").getAsJsonObject("items")["艦船"].asString)
    }

    @Test fun `Asaico release text import includes all 32 tables and excludes subtitles`() {
        val fixture = System.getenv("YAHAGI_REAL_CHS_MOD_ZIP")
        assumeTrue("Set YAHAGI_REAL_CHS_MOD_ZIP to Asaico v1.4.0", !fixture.isNullOrBlank())
        val source = ZipFile(fixture).use { zip ->
            archive(*zip.entries().asSequence().filter { entry -> !entry.isDirectory && entry.name.startsWith("text/") }
                .map { entry -> entry.name to zip.getInputStream(entry).use { it.readBytes().toString(Charsets.UTF_8) } }
                .toList().toTypedArray())
        }
        val repo = GameModRepository(temporary.newFolder())
        val pack = repo.commitImport(repo.preflight(source, "Asaico texts.zip")["token"] as String)
        val translations = resources(pack).filter { it["kind"] in listOf("text_translation", "text_regex_translation", "bgm_translation") }
        assertEquals(32, translations.size)
        assertTrue(translations.all { it["supported"] == true })
        assertFalse(resources(pack).any { it["path"].toString().contains("/subtitles/") && it["supported"] == true })
        val pkgId = pack["id"]
        repo.saveDraft(mapOf("master" to true, "order" to listOf(pkgId), "enabledPackages" to listOf(pkgId),
            "enabledResources" to translations.map { it["id"] }))
        apply(repo)
        val data = config(repo).getAsJsonObject("displayTranslations")
        assertEquals(22, data.getAsJsonObject("dictionaries").size())
        assertEquals(7, data.getAsJsonObject("regex").size())
        assertEquals(3, data.getAsJsonObject("bgm").size())
        assertEquals("工厂", data.getAsJsonObject("bgm").getAsJsonObject("port").getAsJsonObject("102")["zh"].asString)
    }

    private fun import(repo: GameModRepository, vararg entries: Pair<String, String>): Map<String, Any?> =
        repo.commitImport(repo.preflight(archive(*entries), "translations.zip")["token"] as String)

    @Suppress("UNCHECKED_CAST")
    private fun resources(pack: Map<String, Any?>) = pack["resources"] as List<Map<String, Any?>>

    private fun config(repo: GameModRepository): JsonObject {
        val endpoint = GameModCoordinateEndpoint(repo::activeCoordinateSnapshot) { _, _, _, _ -> }
        val url = "https://w15p.kancolle-server.com/__yahagi_mods__/coordinates.json"
        return endpoint.open(url, "GET")!!.inputStream.bufferedReader().use { JsonParser.parseReader(it).asJsonObject }
    }

    private fun apply(repo: GameModRepository) = repo.finishApply(repo.applyDraft())

    private fun archive(vararg entries: Pair<String, String>): InputStream = ByteArrayOutputStream().apply {
        ZipOutputStream(this).use { zip ->
            for ((path, text) in entries) {
                zip.putNextEntry(ZipEntry(path))
                zip.write(text.toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
        }
    }.toByteArray().inputStream()
}
