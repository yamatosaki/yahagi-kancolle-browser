package app.yahagi.kancollebrowser.mods

import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.util.Base64
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class GameModStaticAssetsTest {
    @get:Rule val temporary = TemporaryFolder()
    private val origin = "https://w00g.kancolle-server.com"
    private val maintenance = "kcs/html/maintenance.png"
    private val title = "kcs2/img/title/title2.jpg"
    private val font = "kcs2/resources/font/A-OTF-UDShinGoPro-Regular.woff2"
    private val lightFont = "kcs2/resources/font/A-OTF-UDShinGoPro-Light.woff2"
    private val png = Base64.getDecoder().decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==",
    )
    private val jpeg = Base64.getDecoder().decode(
        "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAx" +
            "NDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIy" +
            "MjIyMjIyMjL/wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QA" +
            "FAEBAAAAAAAAAAAAAAAAAAAABv/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AJgA4Fn/2Q==",
    )

    @Test fun `release images and OpenType font stream through the applied repository`() {
        val paths = listOf(
            maintenance,
            "kcs2/resources/slot/btxt_flat/0001_3899.png",
            "kcs2/resources/useitem/card/001.png",
            "kcs2/resources/world/01y_ver_com_l.png",
            "kcs2/resources/map/001/01.png",
            "kcs2/resources/worldselect/btn_chinjyufu1.png",
            "kcs2/resources/area/airunit/006.png",
            "kcs2/resources/ship/album_status/0001_5832.png",
            "kcs2/img/album/album_main.png",
        )
        val entries = paths.associateWith { png } + mapOf(title to jpeg, font to openType(), lightFont to woff2())
        val inactive = mapOf(
            "text/api/picture_book.ship.json" to "{}".toByteArray(),
            "text/api/config.json" to "{\"api_mst_shipgraph\":true}".toByteArray(),
            "cache/kcs2/resources/font/unrecognized.hack.woff2" to woff2(),
        )
        val root = temporary.newFolder()
        val repo = GameModRepository(root)
        val preview = repo.preflight(archive(entries.mapKeys { hackPath(it.key) } + inactive).inputStream(),
            "Kancolle_to_CHS_1.4.0.zip")
        assertEquals(entries.size, preview["supportedCount"])
        assertEquals(inactive.size, preview["unsupportedCount"])
        val entry = repo.commitImport(preview["token"] as String)
        val resources = resources(entry)
        assertEquals("font", resources.single { it["path"] == font }["kind"])
        assertEquals("ship:0001", resources.single { it["path"] == paths[7] }["groupId"])
        assertNull(repo.openResource("$origin/$title", "GET", emptyMap()))
        enable(repo, entry)

        val restored = GameModRepository(root)
        for ((path, bytes) in entries) {
            val mime = when (path) {
                title -> "image/jpeg"
                font -> "font/otf"
                lightFont -> "font/woff2"
                else -> "image/png"
            }
            assertResponse(restored, "$origin/$path?version=1.4.0", mime, bytes)
        }
        assertResponse(restored, "$origin/html/maintenance.png", "image/png", png)
        assertResponse(restored, "$origin/html/maintenance.png.pagespeed.ce.In2HQP2RJG.png", "image/png", png)
        listOf(
            "https://w00g.kancolle-server.com.invalid/$font",
            "$origin/gadget_html5/font/${font.substringAfterLast('/')}",
            "$origin/$title?other=1",
            "$origin/foo/html/maintenance.png",
            "$origin/html/maintenance.html",
            "$origin/text/api/questlist.json",
            "$origin/kcs2/resources/font/unrecognized.woff2",
        ).forEach { assertNull(it, restored.openResource(it, "GET", emptyMap())) }
    }

    @Test fun `unsafe content on an image or font path fails import`() {
        val script = "<script>alert(1)</script>".toByteArray()
        for ((path, bytes) in listOf(title to script, font to script, title to jpeg.copyOf(50), font to openType().copyOf(28))) {
            val root = temporary.newFolder()
            try {
                GameModArchive().unpack(archive(mapOf(hackPath(path) to bytes)).inputStream(), "bad.zip", root)
                fail("Malformed resource accepted: $path")
            } catch (error: GameModException) {
                assertEquals(if (path == title) "invalid_jpeg" else "invalid_font", error.code)
            }
            assertTrue(root.listFiles()!!.isEmpty())
        }
    }

    @Test fun `real release ZIP accepts every static asset and the quest table`() {
        val configured = System.getenv("YAHAGI_REAL_CHS_MOD_ZIP")
        assumeTrue("Set YAHAGI_REAL_CHS_MOD_ZIP to run the real release audit", !configured.isNullOrBlank())
        val zip = File(configured!!)
        val root = temporary.newFolder()
        val actual = zip.inputStream().use { GameModArchive().unpack(it, zip.name, root) }
        val byPath = actual.resources.associateBy { it.path }
        ZipFile(zip).use { source ->
            val static = source.entries().asSequence().filter { !it.isDirectory && it.name.startsWith("cache/") }.toList()
            assertTrue(static.size > 2_800)
            for (entry in static) {
                val path = entry.name.removePrefix("cache/").replace(".hack.", ".")
                val resource = byPath.getValue(path)
                assertTrue(path, resource.supported)
                assertTrue(path, File(root, resource.relativeFile).isFile)
            }
            val quest = byPath.getValue("text/api/questlist.json")
            assertTrue(quest.supported)
            assertEquals("quest_translation", quest.kind)
            val texts = actual.resources.filter { it.path.startsWith("text/") && it.path != quest.path &&
                GameModDisplayTranslations.table(it.path) == null }
            assertTrue(texts.isNotEmpty())
            assertTrue(texts.all { !it.supported && it.reason == "json_unsupported" })
        }
    }

    private fun assertResponse(repo: GameModRepository, url: String, mime: String, expected: ByteArray) {
        val response = repo.openResource(url, "GET", emptyMap())
        assertNotNull(url, response)
        assertEquals(mime, response!!.mimeType)
        assertArrayEquals(url, expected, response.inputStream.use { it.readBytes() })
    }

    private fun enable(repo: GameModRepository, entry: Map<String, Any?>) {
        val id = entry.getValue("id") as String
        repo.saveDraft(mapOf(
            "master" to true,
            "order" to listOf(id),
            "enabledPackages" to listOf(id),
            "enabledResources" to resources(entry).filter { it["supported"] == true }.map { it.getValue("id") },
        ))
        repo.finishApply(repo.applyDraft())
    }

    @Suppress("UNCHECKED_CAST")
    private fun resources(entry: Map<String, Any?>) = entry.getValue("resources") as List<Map<String, Any?>>

    private fun archive(entries: Map<String, ByteArray>) = ByteArrayOutputStream().apply {
        ZipOutputStream(this).use { zip ->
            for ((path, bytes) in entries) {
                zip.putNextEntry(ZipEntry(path))
                zip.write(bytes)
                zip.closeEntry()
            }
        }
    }.toByteArray()

    private fun hackPath(path: String) = "cache/${path.substringBeforeLast('.')}.hack.${path.substringAfterLast('.')}"

    // A minimal sfnt container for the format and MIME checks. Real CFF rendering is covered by WebView.
    private fun openType() = ByteBuffer.allocate(32).apply {
        put("OTTO".toByteArray(Charsets.US_ASCII))
        putShort(1)
        putShort(16)
        putInt(0)
        put("CFF ".toByteArray(Charsets.US_ASCII))
        putInt(0)
        putInt(28)
        putInt(4)
        put(byteArrayOf(1, 0, 4, 4))
    }.array()

    // The generated two-glyph CFF font used in the WebView test, encoded as WOFF2.
    private fun woff2() = Base64.getDecoder().decode(
        "d09GMk9UVE8AAAGUAAkAAAAAA1gAAAFQAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAADXcGYAA0ATYCJAMGBAYFgiMHIBuzAgAuB2xj" +
            "BtaDQl2x8k1je3FurvDIDxGUY9hekhLz43gEReTat+QArXxlgCy5ZoFBfuObuPduh970ff3whfosBRd0C/h/6qb+mKDPo+JAuijS" +
            "BDb4wi6hpWECmWQfWICdJxJYdjMUnshmtbq9dymUEBFt124+uHn/4cW7+wcL/xfdISJ6/vcl/Vl32VtPTW//1fq7RYpoHzpYDysd" +
            "ni6PMDo8lJb/vykfaadX/WGQ09X4hMKSAR5/DE46mYcPt8nDPgMAhkFCRrss0K4YRlEETh6OUAJcg99XWo78qc75O3yb+dLozt8m" +
            "rJIm05ElENymT1et5tSUoIpdIMBZkq71TEh1KtBUqZP3WZtWAUp/XqnVhCxKjdBpi0zS6JTJJt2IlmOlcS8RyjBbg3HtOfyga256" +
            "4Kb7Hhp20V37Dpx3131PPXHT3NZhzzluYX+WAAA=",
    )
}
