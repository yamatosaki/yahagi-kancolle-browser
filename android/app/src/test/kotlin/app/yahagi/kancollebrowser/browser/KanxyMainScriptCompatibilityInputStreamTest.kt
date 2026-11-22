package app.yahagi.kancollebrowser.browser

import java.io.ByteArrayInputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class KanxyMainScriptCompatibilityInputStreamTest {
    @Test
    fun patchesOnlyBothKanxyRowsAndPreservesStreamingPrefixAndUnicode() {
        val prefix = ByteArray(1_100_000) { 65 } + "\n$legacyHandler\r\n前置\r\n".toByteArray()
        val body = prefix + module.toByteArray()
        val expected = prefix + module.replace(legacyHandler, fixedHandler).toByteArray()
        var patches = 0
        val original = ByteArrayInputStream(body)
        KanxyMainScriptCompatibilityInputStream(original, body.size.toLong()) { patches++ }.use { stream ->
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
            val output = KanxyMainScriptCompatibilityInputStream(ByteArrayInputStream(bytes), bytes.size.toLong()) {
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
            val output = KanxyMainScriptCompatibilityInputStream(ByteArrayInputStream(body), declaredLength.toLong()) {
                error("A mismatched length cannot be patched")
            }.use { it.readBytes() }
            assertArrayEquals(body, output)
        }
    }

    @Test
    fun guardsIdleControllerMovesWithoutRequiringTheDropdownModule() {
        val body = controllerModule.toByteArray()
        val patches = mutableListOf<KanxyMainScriptCompatibilityInputStream.Patch>()
        val output = KanxyMainScriptCompatibilityInputStream(ByteArrayInputStream(body), body.size.toLong()) {
            patches.add(it)
        }.use { it.readBytes().decodeToString() }

        assertEquals(listOf(KanxyMainScriptCompatibilityInputStream.Patch.CONTROLLER_POINTER), patches)
        assertTrue(output.contains("const previousX = this.x;"))
        assertTrue(output.contains("const previousY = this.y;"))
        assertTrue(output.contains("this.CommandState.Pointer === \"up\""))
        assertTrue(output.contains("this.CommandState.WheelDown === \"down\""))
        assertTrue(output.contains("if (this.CommandState.Pointer == \"down\")\r\n" +
            "                        this.simulatePointerDown();"))
    }

    @Test
    fun leavesSimilarControllerCodeOutsideTheKnownModuleUntouched() {
        val body = controllerModule.replace("class ExtraController {", "class OtherController {").toByteArray()
        val output = KanxyMainScriptCompatibilityInputStream(ByteArrayInputStream(body), body.size.toLong()) {
            error("Unrelated controller code must be left alone")
        }.use { it.readBytes() }
        assertArrayEquals(body, output)
    }

    @Test
    fun appliesBothCompatibilityPatchesWhenBothModulesArePresent() {
        val body = "$module\r\n$controllerModule".toByteArray()
        val patches = mutableListOf<KanxyMainScriptCompatibilityInputStream.Patch>()
        val output = KanxyMainScriptCompatibilityInputStream(ByteArrayInputStream(body), body.size.toLong()) {
            patches.add(it)
        }.use { it.readBytes().decodeToString() }

        assertEquals(
            listOf(
                KanxyMainScriptCompatibilityInputStream.Patch.DROPDOWN,
                KanxyMainScriptCompatibilityInputStream.Patch.CONTROLLER_POINTER,
            ),
            patches,
        )
        assertTrue(output.contains(fixedHandler))
        assertTrue(output.contains("const previousX = this.x;"))
    }

    @Test
    fun doesNotReportAPatchFromSkippedBytes() {
        val body = module.toByteArray()
        var patches = 0
        KanxyMainScriptCompatibilityInputStream(ByteArrayInputStream(body), body.size.toLong()) { patches++ }.use { stream ->
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
        val controllerModule = """
            class ExtraController {
                Init(kanxy) {
                    kanxy.AddOnRec("ExtraControllerInput", this.RecExtraControllerInput.bind(this));
                    this.virtualMouse = {
                        UpdateMouse() {
                            if (this.mode == self.InputMode.VIRTUAL) {
                                this.x = Math.min(1200, Math.max(0, this.x + this.PointerSpeed * this.CommandState.MoveX));
                                this.y = Math.min(720, Math.max(0, this.y + this.PointerSpeed * this.CommandState.MoveY));
                                self.interaction.mouseOverRenderer = true;
                                self.interaction.didMove = true;
                                this.simulatePointerMove();
                                if (this.CommandState.Pointer == "down")
                                    this.simulatePointerDown();
                            }
                        },
                        simulatePointerMove() {
                            kanxy.app.view.dispatchEvent(new PointerEvent("pointermove", { clientX: this.x, clientY: this.y }));
                        },
                    };
                }
            }
        """.trimIndent().replace("\n", "\r\n")
    }
}
