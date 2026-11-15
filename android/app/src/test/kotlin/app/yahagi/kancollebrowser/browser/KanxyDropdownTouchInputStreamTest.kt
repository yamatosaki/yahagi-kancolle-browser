package app.yahagi.kancollebrowser.browser

import java.io.ByteArrayInputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class KanxyDropdownTouchInputStreamTest {
    @Test
    fun patchesOnlyBothKanxyRowsAndPreservesStreamingPrefixAndUnicode() {
        val prefix = ByteArray(1_100_000) { 65 } + "\n$legacyHandler\r\n前置\r\n".toByteArray()
        val body = prefix + module.toByteArray()
        val expected = prefix + module.replace(legacyHandler, fixedHandler).toByteArray()
        var patches = 0
        val original = ByteArrayInputStream(body)
        KanxyDropdownTouchInputStream(original, body.size.toLong()) { patches++ }.use { stream ->
            assertEquals(65, stream.read())
            assertEquals(body.size - 1, original.available())
            assertEquals(0, patches)
            assertArrayEquals(expected.copyOfRange(1, expected.size), stream.readBytes())
        }
        assertEquals(1, patches)
    }

    @Test
    fun leavesStockOrPartiallyMatchedScriptsUntouched() {
        val bodies = listOf(
            "window.stock = true;\n$legacyHandler",
            module.replaceFirst(legacyHandler, fixedHandler),
            module.replace("showChildren(index);", "somethingElse();"),
            module.replace("class WSClient {", "class Unrelated {"),
        )
        for (body in bodies) {
            val bytes = body.toByteArray()
            var patches = 0
            val output = KanxyDropdownTouchInputStream(ByteArrayInputStream(bytes), bytes.size.toLong()) {
                patches++
            }.use { it.readBytes() }
            assertArrayEquals(bytes, output)
            assertEquals(0, patches)
        }
    }

    @Test
    fun leavesBytesUntouchedWhenTheDeclaredLengthDiffers() {
        val body = module.toByteArray()
        for (declaredLength in listOf(body.size - 1, body.size + 1)) {
            val output = KanxyDropdownTouchInputStream(ByteArrayInputStream(body), declaredLength.toLong()) {
                error("A mismatched length cannot be patched")
            }.use { it.readBytes() }
            assertArrayEquals(body, output)
        }
    }

    @Test
    fun doesNotReportAPatchFromSkippedBytes() {
        val body = module.toByteArray()
        var patches = 0
        KanxyDropdownTouchInputStream(ByteArrayInputStream(body), body.size.toLong()) { patches++ }.use { stream ->
            assertEquals(5L, stream.skip(5))
            assertArrayEquals(module.replace(legacyHandler, fixedHandler).toByteArray().drop(5).toByteArray(),
                stream.readBytes())
        }
        assertEquals(0, patches)
    }

    private companion object {
        const val legacyHandler = "bg.on(\"click\", function () {"
        const val fixedHandler = "bg.on(EventTypeConst_1.EventType.CLICK, function () {"
        val module = """
            class UI
            {
                PixiDropdown(options) {
                            $legacyHandler
                                // 国籍
                                showChildren(index);
                            });
                                $legacyHandler
                                    selectedChildIndex = childIndex;
                                });
                    selectedBg.on(
                        EventTypeConst_1.EventType.CLICK,
                        function () {});
                }
                CreateKanxyTags(tagList, containerWidth) {
                }
            }
            class WSClient {
                connect() { this.ws = new WebSocket(this.kanxy.url); }
            }
        """.trimIndent().replace("\n", "\r\n")
    }
}
