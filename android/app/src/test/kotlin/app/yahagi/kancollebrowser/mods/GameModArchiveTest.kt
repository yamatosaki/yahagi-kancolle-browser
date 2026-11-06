package app.yahagi.kancollebrowser.mods

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.util.zip.CRC32
import java.util.zip.DeflaterOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class GameModArchiveTest {
    @Test fun `7z signature gets actionable ZIP conversion error`() {
        val bytes = byteArrayOf(0x37, 0x7a, 0xbc.toByte(), 0xaf.toByte(), 0x27, 0x1c) + ByteArray(32)
        assertEquals("seven_zip_unsupported", failure(bytes).code)
    }
    @Test fun `valid PNG trailing bytes are removed from local extracted copy only`() {
        val valid = png()
        val source = archive(full to (valid + byteArrayOf(1, 2, 3)))
        val original = source.clone()
        val root = temporaryFolder.newFolder()
        val result = GameModArchive().unpack(source.inputStream(), "tail.zip", root)
        assertArrayEquals(original, source)
        assertArrayEquals(valid, root.resolve(result.resources.single().relativeFile).readBytes())
        assertTrue(result.warnings.contains("png_trailing_data_removed"))
    }

    @Test fun `trailing bytes never hide invalid PNG CRC or truncated zlib`() {
        val invalid = png().also { it[29] = (it[29].toInt() xor 1).toByte() } + byteArrayOf(0)
        assertEquals("invalid_png", failure(archive(full to invalid)).code)
        assertEquals("invalid_png", failure(archive(full to (png(compressedData = byteArrayOf(0x78, 0x9c.toByte(), 0x01)) + byteArrayOf(0)))).code)
    }
    @get:Rule val temporaryFolder = TemporaryFolder()
    private val full = "kcs2/resources/ship/full/0001_1234_secret.png"

    @Test fun `imports KiddAutomata cache wrapper and normalizes hack suffix and backslashes`() {
        val png = png()
        val root = temporaryFolder.newFolder()
        val result = GameModArchive().unpack(
            archive("cache\\${full.replace('/', '\\').removeSuffix(".png")}.hack.png" to png).inputStream(),
            "My ships cache.zip", root,
        )
        assertEquals("My ships cache", result.name)
        assertEquals(png.size.toLong(), result.sizeBytes)
        val resource = result.resources.single()
        assertEquals(full, resource.path)
        assertEquals("ship:0001", resource.groupId)
        assertTrue(resource.supported)
        assertArrayEquals(png, root.resolve(resource.relativeFile).readBytes())
    }

    @Test fun `supports UI PNG and independently supplied plain game resource PNG`() {
        val result = unpack(archive(full to png(), "kcs2/img/port/port_main.hack.png" to png()))
        assertEquals(2, result.resources.count { it.supported })
        assertEquals("kcs2/img/port/port_main.png", result.resources.last().path)
    }

    @Test fun `does not guess unknown ship types or override scripts and arbitrary JSON`() {
        val result = unpack(archive(
            "kcs2/resources/ship/unknown/0001_1234.png" to png(),
            "kcs2/js/main.hack.js" to "alert(1)".toByteArray(),
            "kcs2/version.hack.json" to "{}".toByteArray(),
        ))
        assertEquals(3, result.resources.size)
        assertTrue(result.resources.none { it.supported })
        assertTrue(result.resources.all { !it.reason.isNullOrBlank() })
    }

    @Test fun `kcs2 MP3 remains unsupported without guessing legacy voice mapping`() {
        val resource = unpack(archive("cache/kcs2/sound/kcsecret/123.hack.mp3" to byteArrayOf(1, 2))).resources.single()
        assertFalse(resource.supported)
        assertEquals("audio_path_unsupported", resource.reason)
    }

    @Test fun `PNG paired with spritesheet JSON is disabled rather than replacing atlas blindly`() {
        val result = unpack(archive(
            "kcs2/img/port/main.hack.png" to png(),
            "kcs2/img/port/main.json" to "{\"frames\":{}}".toByteArray(),
        ))
        assertTrue(result.resources.none { it.supported })
        assertEquals("spritesheet_json_dependency", result.resources.first().reason)
    }

    @Test fun `PNG paired with png dot JSON metadata is also disabled`() {
        val result = unpack(archive(
            "kcs2/img/port/main.hack.png" to png(),
            "kcs2/img/port/main.png.json" to "{\"frames\":{}}".toByteArray(),
        ))
        assertTrue(result.resources.none { it.supported })
        assertEquals("spritesheet_json_dependency", result.resources.first().reason)
    }

    @Test fun `matched coordinate config becomes a supported unit without blocking images`() {
        val result = unpack(archive(
            full to png(), "kcs2/resources/ship/card/0001_4321.png" to png(),
            "kcs2/resources/ship/full/0002_1234_other.png" to png(),
            "cache/kcs/resources/swf/ships/secret.config.ini" to "[graph]\nboko_n_left=3\nboko_n_top=4".toByteArray(),
        ))
        assertTrue(result.resources.filter { it.groupId == "ship:0001" }.all { it.supported })
        assertTrue(result.resources.single { it.path.contains("0002") }.supported)
        assertEquals(mapOf("api_boko_n" to listOf(3,4)), result.resources.single { it.kind == "coordinates" }.coordinateGraph)
    }

    @Test fun `unmatched coordinate JSON conservatively disables ship images without disabling UI`() {
        val result = unpack(archive(
            full to png(), "kcs2/img/port/port_main.png" to png(),
            "kcs/resources/swf/ships/unknown.config.json" to "{\"api_mst_shipgraph\":{\"api_boko_n\":[0,0]}}".toByteArray(),
        ))
        assertFalse(result.resources.single { it.path == full }.supported)
        assertEquals("coordinate_dependency_unresolved", result.resources.single { it.path == full }.reason)
        assertTrue(result.resources.single { it.path.startsWith("kcs2/img/") }.supported)
    }

    @Test fun `bat intermediate format gives actionable conversion error`() {
        val error = failure(archive("ship/0001_Test/full.png" to png()))
        assertEquals("unsupported_archive", error.code)
        assertTrue(error.message.orEmpty().contains("cache.zip"))
    }

    @Test fun `rejects traversal absolute paths drives and encoded path ambiguity`() {
        for (path in listOf("../a.png", "/a.png", "C:\\a.png", "cache\\..\\a.png", "cache/%2e%2e/a.png")) {
            assertEquals(path, "unsafe_path", failure(archive(path to png())).code)
        }
    }

    @Test fun `rejects duplicate normalized resources including hack aliases and wrapper aliases`() {
        assertEquals("duplicate_resource", failure(archive(full to png(), "cache/${full.replace(".png", ".hack.png")}" to png())).code)
        assertEquals("duplicate_resource", failure(archive(full to png(), "cache/$full" to png())).code)
    }

    @Test fun `same folder hack suffix overrides plain cache backup in either entry order`() {
        val modded = png(scanline = byteArrayOf(0, 11, 22, 33, -1))
        val original = png(scanline = byteArrayOf(0, 99, 88, 77, -1))
        for (entries in listOf(
            arrayOf("kcs2/img/common/bg_map/bg_h.hack.png" to modded, "kcs2/img/common/bg_map/bg_h.png" to original),
            arrayOf("kcs2/img/common/bg_map/bg_h.png" to original, "kcs2/img/common/bg_map/bg_h.hack.png" to modded),
        )) {
            val root = temporaryFolder.newFolder()
            val result = GameModArchive().unpack(archive(*entries).inputStream(), "battle-bg.zip", root)
            val resource = result.resources.single()
            assertEquals("kcs2/img/common/bg_map/bg_h.png", resource.path)
            assertTrue(resource.supported)
            assertEquals(2, resource.sourcePaths.size)
            assertTrue(result.warnings.contains("hack_overrides_original"))
            assertArrayEquals(modded, root.resolve(resource.relativeFile).readBytes())
            assertEquals(1, root.resolve("files").listFiles()!!.size)
        }
    }

    @Test fun `unpacks GBK outer wrapper directory with battle backgrounds shutter and furniture`() {
        val moddedDay = png(scanline = byteArrayOf(0, 1, 2, 3, -1))
        val plainDay = png(scanline = byteArrayOf(0, 9, 9, 9, -1))
        val moddedNight = png(scanline = byteArrayOf(0, 4, 5, 6, -1))
        val plainNight = png(scanline = byteArrayOf(0, 8, 8, 8, -1))
        val shutter = png(scanline = byteArrayOf(0, 7, 8, 9, -1))
        val furniture = png(scanline = byteArrayOf(0, 10, 20, 30, -1))
        val wrapper = "[舰colle] 硬盘挖出来的战斗界面魔改"
        val gbkOut = ByteArrayOutputStream()
        ZipOutputStream(gbkOut, java.nio.charset.Charset.forName("GBK")).use { zip ->
            zip.putNextEntry(ZipEntry("$wrapper/")); zip.closeEntry()
            mapOf(
                "$wrapper/cover.png" to png(),
                "$wrapper/info.json" to "{\"name\":\"battle\"}".toByteArray(),
                "$wrapper/kcs2/img/common/bg_map/bg_h.hack.png" to moddedDay,
                "$wrapper/kcs2/img/common/bg_map/bg_h.png" to plainDay,
                "$wrapper/kcs2/img/common/bg_map/bg_y.hack.png" to moddedNight,
                "$wrapper/kcs2/img/common/bg_map/bg_y.png" to plainNight,
                "$wrapper/kcs2/img/common/common_shutter.hack.png" to shutter,
                "$wrapper/kcs2/resources/furniture/outside/050_01.png" to furniture,
            ).forEach { (name, bytes) ->
                zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry()
            }
        }
        val root = temporaryFolder.newFolder()
        val result = GameModArchive().unpack(gbkOut.toByteArray().inputStream(), "$wrapper.zip", root)
        val byPath = result.resources.associateBy { it.path }
        assertEquals(6, result.resources.size)
        assertEquals(4, result.resources.count { it.supported })
        assertTrue(result.warnings.contains("hack_overrides_original"))
        assertTrue(result.warnings.contains("unsupported_files"))
        assertArrayEquals(moddedDay, root.resolve(byPath.getValue("kcs2/img/common/bg_map/bg_h.png").relativeFile).readBytes())
        assertArrayEquals(moddedNight, root.resolve(byPath.getValue("kcs2/img/common/bg_map/bg_y.png").relativeFile).readBytes())
        assertArrayEquals(shutter, root.resolve(byPath.getValue("kcs2/img/common/common_shutter.png").relativeFile).readBytes())
        assertArrayEquals(furniture, root.resolve(byPath.getValue("kcs2/resources/furniture/outside/050_01.png").relativeFile).readBytes())
        assertFalse(byPath.getValue("cover.png").supported)
        assertFalse(byPath.getValue("info.json").supported)
    }

    @Test fun `rejects unix symlink entries before extracting`() {
        val bytes = archive(full to png())
        val offset = central(bytes)
        putInt(bytes, offset + 38, 0xA1FF0000.toInt())
        assertEquals("unsafe_path", failure(bytes).code)
    }

    @Test fun `rejects declared per file quota before inflating`() {
        val bytes = archive(full to png())
        putInt(bytes, central(bytes) + 24, 64 * 1024 * 1024 + 1)
        assertEquals("quota_exceeded", failure(bytes).code)
    }

    @Test fun `rejects compression bombs using actual bytes even if advertised size is false`() {
        val bytes = archive("notes.txt" to ByteArray(200_000))
        putInt(bytes, central(bytes) + 24, 0)
        assertEquals("quota_exceeded", failure(bytes).code)
    }

    @Test fun `rejects forged compressed size extending into the central directory`() {
        val bytes = archive("notes.txt" to ByteArray(200_000))
        putInt(bytes, central(bytes) + 20, 200_000)
        assertEquals("invalid_archive", failure(bytes).code)
    }

    @Test fun `rejects overlapping local file ranges despite valid inflated contents`() {
        val bytes = archive("one.txt" to byteArrayOf(1, 2, 3), "two.txt" to byteArrayOf(4, 5, 6))
        val first = central(bytes)
        val second = first + 46 + "one.txt".length
        val secondLocal = (0..3).sumOf { (bytes[second + 42 + it].toInt() and 255) shl (8 * it) }
        putInt(bytes, first + 20, secondLocal - (30 + "one.txt".length) + 1)
        assertEquals("invalid_archive", failure(bytes).code)
    }

    @Test fun `rejects local file name that disagrees with the central entry`() {
        val bytes = archive("notes.txt" to byteArrayOf(1, 2, 3))
        bytes[30] = 'x'.code.toByte()
        assertEquals("invalid_archive", failure(bytes).code)
    }

    @Test fun `rejects local compression flags or method that disagree with the central entry`() {
        for (offset in listOf(6, 8)) {
            val bytes = archive("notes.txt" to byteArrayOf(1, 2, 3))
            bytes[offset] = (bytes[offset].toInt() xor 1).toByte()
            assertEquals("invalid_archive", failure(bytes).code)
        }
    }

    @Test fun `rejects too many entries including directories`() {
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use { zip ->
            repeat(20_001) { zip.putNextEntry(ZipEntry("$it/")); zip.closeEntry() }
        }
        assertEquals("quota_exceeded", failure(output.toByteArray()).code)
    }

    @Test fun `rejects invalid and truncated ZIP instead of treating it as empty import`() {
        assertEquals("invalid_archive", failure("not zip".toByteArray()).code)
        val zip = archive(full to png())
        assertEquals("invalid_archive", failure(zip.copyOf(zip.size - 7)).code)
    }

    @Test fun `rejects corrupted PNG CRC and missing IEND`() {
        val valid = png()
        val corrupt = valid.clone().also { it[29] = (it[29].toInt() xor 1).toByte() }
        assertEquals("invalid_png", failure(archive(full to corrupt)).code)
        assertEquals("invalid_png", failure(archive(full to valid.copyOf(valid.size - 12))).code)
    }

    @Test fun `rejects truncated IDAT even when all PNG chunk CRCs are valid`() {
        val truncated = png(compressedData = byteArrayOf(0x78, 0x9c.toByte(), 0x01))
        assertEquals("invalid_png", failure(archive(full to truncated)).code)
    }

    @Test fun `rejects invalid scanline filter and decoded dimension bombs`() {
        assertEquals("invalid_png", failure(archive(full to png(scanline = byteArrayOf(5, 0, 0, 0, 0)))).code)
        assertEquals("invalid_png", failure(archive(full to png(width = 1_000_000))).code)
    }

    @Test fun `validates actual ZIP CRC instead of trusting central directory`() {
        val bytes = archive(full to png())
        putInt(bytes, central(bytes) + 16, 0)
        assertEquals("invalid_archive", failure(bytes).code)
    }

    @Test fun `failed import does not leave extracted resource files`() {
        val root = temporaryFolder.newFolder()
        try {
            GameModArchive().unpack(archive(full to png(), "../bad" to byteArrayOf(1)).inputStream(), "broken.zip", root)
            fail("expected failure")
        } catch (_: GameModException) {
            assertTrue(root.walkTopDown().none { it.isFile })
        }
    }

    private fun unpack(bytes: ByteArray) = GameModArchive().unpack(
        ByteArrayInputStream(bytes), "test.zip", temporaryFolder.newFolder(),
    )

    private fun failure(bytes: ByteArray): GameModException {
        try { unpack(bytes) } catch (error: GameModException) { return error }
        throw AssertionError("Archive unexpectedly accepted")
    }

    private fun archive(vararg files: Pair<String, ByteArray>): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip -> files.forEach { (name, bytes) ->
            zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry()
        } }
        return out.toByteArray()
    }

    private fun png(width: Int = 1, scanline: ByteArray = byteArrayOf(0, 0, 0, 0, -1), compressedData: ByteArray? = null): ByteArray {
        val out = ByteArrayOutputStream()
        val data = DataOutputStream(out)
        data.write(byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10))
        fun chunk(type: String, bytes: ByteArray) {
            val typeBytes = type.toByteArray(Charsets.US_ASCII)
            data.writeInt(bytes.size); data.write(typeBytes); data.write(bytes)
            val crc = CRC32().apply { update(typeBytes); update(bytes) }
            data.writeInt(crc.value.toInt())
        }
        val header = ByteArrayOutputStream().also { headerOut -> DataOutputStream(headerOut).apply {
            writeInt(width); writeInt(1); write(byteArrayOf(8, 6, 0, 0, 0))
        } }.toByteArray()
        val compressed = compressedData ?: ByteArrayOutputStream().also {
            DeflaterOutputStream(it).use { deflater -> deflater.write(scanline) }
        }.toByteArray()
        chunk("IHDR", header); chunk("IDAT", compressed); chunk("IEND", byteArrayOf())
        return out.toByteArray()
    }

    private fun central(bytes: ByteArray): Int = (0..bytes.size - 4).first { offset ->
        bytes[offset] == 0x50.toByte() && bytes[offset + 1] == 0x4b.toByte() &&
            bytes[offset + 2] == 0x01.toByte() && bytes[offset + 3] == 0x02.toByte()
    }

    private fun putInt(bytes: ByteArray, offset: Int, value: Int) {
        repeat(4) { bytes[offset + it] = (value ushr (8 * it)).toByte() }
    }
}
