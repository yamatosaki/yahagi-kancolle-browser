package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameChecklistIconTest {
    private fun item(icon: Map<String, Any> = emptyMap()): NativeGameChecklistItem =
        NativeGameChecklistItem.parse(mapOf("id" to "fuel", "label" to "燃料", "value" to "123", "checked" to true) + icon)

    private fun field(item: NativeGameChecklistItem, name: String): Any? {
        val getter = item.javaClass.declaredMethods.firstOrNull { it.name == name }
        assertNotNull("Native checklist items must retain validated icon metadata", getter)
        return getter!!.invoke(item)
    }

    private fun reject(icon: Map<String, Any>) {
        try {
            item(icon)
            fail("Malformed checklist icon metadata must be rejected: $icon")
        } catch (_: IllegalArgumentException) {
        } catch (_: IllegalStateException) {
        }
    }

    @Test fun legacyItemsRemainValidWithoutAnIcon() {
        val item = item()
        assertNull(field(item, "getIconAsset"))
        assertNull(field(item, "getIconCodePoint"))
        assertNull(field(item, "getIconColor"))
        assertEquals("燃料", item.label)
    }

    @Test fun materialAndUseitemPngPathsRetainTheirFlutterAssetNames() {
        for (path in listOf("assets/images/material/01.png", "assets/images/material/useitem_104.png")) {
            val item = item(mapOf("iconAsset" to path))
            assertEquals(path, field(item, "getIconAsset"))
            assertNull(field(item, "getIconCodePoint"))
        }
    }

    @Test fun materialGlyphAndUnsignedArgbSurviveThePlatformChannel() {
        val item = item(mapOf("iconCodePoint" to 0xf6d2, "iconColor" to 0xffe0b25cL))
        assertEquals(0xf6d2, field(item, "getIconCodePoint"))
        assertEquals(0xffe0b25cL.toInt(), field(item, "getIconColor"))
        assertNull(field(item, "getIconAsset"))
        assertEquals(0xffffffffL.toInt(), field(item(mapOf("iconCodePoint" to 0xe148L, "iconColor" to 0xffffffffL)), "getIconColor"))
        assertEquals(0, field(item(mapOf("iconCodePoint" to 0xe148, "iconColor" to 0)), "getIconColor"))
    }

    @Test fun assetPathsCannotEscapeTheBundledResourceDirectory() {
        for (path in listOf(
            "", "/assets/images/material/01.png", "C:/assets/images/material/01.png",
            "file:///assets/images/material/01.png", "../assets/images/material/01.png",
            "assets/images/material/../01.png", "assets/images/material/sub/01.png",
            "assets\\images\\material\\01.png", "assets/images/slotitem/01.png",
            "assets/images/material/01.svg", "assets/images/material/01.png?x=1",
            "assets/images/material/%2e%2e.png", "assets/images/material/01.png\u0000",
        )) reject(mapOf("iconAsset" to path))
        reject(mapOf("iconAsset" to 1))
    }

    @Test fun anItemCannotSpecifyBothAnAssetAndAGlyph() {
        reject(mapOf("iconAsset" to "assets/images/material/01.png", "iconCodePoint" to 0xe148))
    }

    @Test fun glyphCodePointsMustBeUnicodeScalarIntegers() {
        for (invalid in listOf(-1, 0x110000, 0xd800, 0xdfff, 0x100000000L, 0xe148.toDouble(), "e148")) {
            reject(mapOf("iconCodePoint" to invalid))
        }
        for (valid in listOf(0, 0xd7ff, 0xe000, 0x10ffff)) {
            assertEquals(valid, field(item(mapOf("iconCodePoint" to valid)), "getIconCodePoint"))
        }
    }

    @Test fun colorsMustBeUnsignedArgbIntegersWithoutOverflow() {
        for (invalid in listOf(-1, 0x100000000L, 0xffe0b25cL.toDouble(), "#ffe0b25c")) {
            reject(mapOf("iconCodePoint" to 0xe148, "iconColor" to invalid))
        }
    }
}
