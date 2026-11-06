package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

/** Channel-only presentation values: parsing must not need an Android Context or scale text again. */
class NativeGameDialogPresentationTest {
    private fun colors(): Map<String, Any> = mapOf(
        "surface" to 0xfff7f2e8L,
        "onSurface" to 0xff211b13L,
        "body" to 0xff504638L,
        "primary" to 0xff755b27L,
        "onPrimary" to 0xffffffffL,
        "checkbox" to 0xff6d5528L,
        "checkboxCheck" to 0xfffaf1d8L,
        "outline" to 0xff817664L,
        "barrier" to 0x66000000L,
    )

    private fun textStyle(fontSize: Double, lineHeight: Double, fontWeight: Int): Map<String, Any> = mapOf(
        "fontSize" to fontSize, "lineHeight" to lineHeight, "fontWeight" to fontWeight,
    )

    private fun text(): Map<String, Any> = mapOf(
        "title" to textStyle(27.5, 36.25, 600),
        "body" to textStyle(18.25, 27.5, 400),
        "action" to textStyle(17.75, 24.5, 700),
        "checkbox" to textStyle(20.5, 29.75, 500),
    )

    private fun layout(): Map<String, Any> = mapOf(
        "insetPadding" to listOf(16.0, 12.0, 20.0, 14.0),
        "titlePadding" to listOf(18.0, 20.0, 22.0, 2.0),
        "contentPadding" to listOf(18.0, 14.0, 22.0, 18.0),
        "actionsPadding" to listOf(17.0, 3.0, 11.0, 19.0),
        "radius" to 18.0,
        "minWidth" to 312.5,
        "actionMinHeight" to 44.0,
        "actionSpacing" to 10.0,
        "buttonRadius" to 22.0,
    )

    private fun payload(): Map<String, Any> = mapOf(
        "colors" to colors(), "text" to text(), "layout" to layout(), "textDirection" to "rtl",
        "fontAsset" to "assets/fonts/dialog.ttf",
        "customFontPath" to "/data/user/0/app.yahagi.kancollebrowser/files/fonts/custom.ttf",
    )

    private fun reject(arguments: Any?) {
        try {
            NativeGameDialogPresentation.parse(arguments)
            fail("Invalid dialog presentation accepted: $arguments")
        } catch (_: IllegalArgumentException) {
        } catch (_: IllegalStateException) {
        }
    }

    @Test fun missingPresentationAndEmptyMapsKeepTheDefaultContract() {
        val value = NativeGameDialogPresentation.parse(null)
        assertEquals(value, NativeGameDialogPresentation.parse(emptyMap<String, Any>()))
        assertEquals(value, NativeGameDialogPresentation.parse(mapOf(
            "colors" to emptyMap<String, Any>(),
            "text" to emptyMap<String, Any>(),
            "layout" to emptyMap<String, Any>(),
        )))
        assertEquals("ltr", value.textDirection)
        assertNull(value.fontAsset)
        assertNull(value.customFontPath)
        assertEquals(listOf(40f, 24f, 40f, 24f), value.layout.insetPadding)
        assertEquals(listOf(24f, 24f, 24f, 0f), value.layout.titlePadding)
        assertEquals(listOf(24f, 16f, 24f, 24f), value.layout.contentPadding)
        assertEquals(listOf(24f, 0f, 24f, 24f), value.layout.actionsPadding)
        assertEquals(28f, value.layout.radius, 0f)
        assertEquals(280f, value.layout.minWidth, 0f)
        assertEquals(40f, value.layout.actionMinHeight, 0f)
        assertEquals(8f, value.layout.actionSpacing, 0f)
        assertEquals(20f, value.layout.buttonRadius, 0f)
        assertEquals(24f, value.text.title.fontSize, 0f)
        assertEquals(32f, value.text.title.lineHeight, 0f)
        assertEquals(400, value.text.title.fontWeight)
        assertEquals(14f, value.text.body.fontSize, 0f)
        assertEquals(20f, value.text.body.lineHeight, 0f)
        assertEquals(400, value.text.body.fontWeight)
        assertEquals(14f, value.text.action.fontSize, 0f)
        assertEquals(20f, value.text.action.lineHeight, 0f)
        assertEquals(500, value.text.action.fontWeight)
        assertEquals(16f, value.text.checkbox.fontSize, 0f)
        assertEquals(24f, value.text.checkbox.lineHeight, 0f)
        assertEquals(400, value.text.checkbox.fontWeight)
    }

    @Test fun completePresentationKeepsUnsignedArgbResolvedTextAndDirectionalGeometry() {
        val value = NativeGameDialogPresentation.parse(payload())
        assertEquals(0xfff7f2e8L.toInt(), value.colors.surface)
        assertEquals(0xff211b13L.toInt(), value.colors.onSurface)
        assertEquals(0xff504638L.toInt(), value.colors.body)
        assertEquals(0xff755b27L.toInt(), value.colors.primary)
        assertEquals(0xffffffffL.toInt(), value.colors.onPrimary)
        assertEquals(0xff6d5528L.toInt(), value.colors.checkbox)
        assertEquals(0xfffaf1d8L.toInt(), value.colors.checkboxCheck)
        assertEquals(0xff817664L.toInt(), value.colors.outline)
        assertEquals(0x66000000, value.colors.barrier)
        assertEquals(27.5f, value.text.title.fontSize, 0f)
        assertEquals(36.25f, value.text.title.lineHeight, 0f)
        assertEquals(600, value.text.title.fontWeight)
        assertEquals(18.25f, value.text.body.fontSize, 0f)
        assertEquals(27.5f, value.text.body.lineHeight, 0f)
        assertEquals(400, value.text.body.fontWeight)
        assertEquals(17.75f, value.text.action.fontSize, 0f)
        assertEquals(24.5f, value.text.action.lineHeight, 0f)
        assertEquals(700, value.text.action.fontWeight)
        assertEquals(20.5f, value.text.checkbox.fontSize, 0f)
        assertEquals(29.75f, value.text.checkbox.lineHeight, 0f)
        assertEquals(500, value.text.checkbox.fontWeight)
        assertEquals(listOf(16f, 12f, 20f, 14f), value.layout.insetPadding)
        assertEquals(listOf(18f, 20f, 22f, 2f), value.layout.titlePadding)
        assertEquals(listOf(18f, 14f, 22f, 18f), value.layout.contentPadding)
        assertEquals(listOf(17f, 3f, 11f, 19f), value.layout.actionsPadding)
        assertEquals(18f, value.layout.radius, 0f)
        assertEquals(312.5f, value.layout.minWidth, 0f)
        assertEquals(44f, value.layout.actionMinHeight, 0f)
        assertEquals(10f, value.layout.actionSpacing, 0f)
        assertEquals(22f, value.layout.buttonRadius, 0f)
        assertEquals("rtl", value.textDirection)
        assertEquals("assets/fonts/dialog.ttf", value.fontAsset)
        assertEquals("/data/user/0/app.yahagi.kancollebrowser/files/fonts/custom.ttf", value.customFontPath)
    }

    @Test fun partialPresentationOverridesOnlyTheSuppliedValues() {
        val defaults = NativeGameDialogPresentation.parse(null)
        val value = NativeGameDialogPresentation.parse(mapOf(
            "colors" to mapOf("surface" to 0L),
            "text" to mapOf("body" to mapOf("fontSize" to 19.5)),
            "layout" to mapOf("minWidth" to 300),
        ))
        assertEquals(0, value.colors.surface)
        assertEquals(defaults.colors.primary, value.colors.primary)
        assertEquals(19.5f, value.text.body.fontSize, 0f)
        assertEquals(defaults.text.body.lineHeight, value.text.body.lineHeight, 0f)
        assertEquals(defaults.text.body.fontWeight, value.text.body.fontWeight)
        assertEquals(defaults.text.title, value.text.title)
        assertEquals(300f, value.layout.minWidth, 0f)
        assertEquals(defaults.layout.actionsPadding, value.layout.actionsPadding)
        assertEquals(defaults.textDirection, value.textDirection)
    }

    @Test fun invalidContainerAndNestedFieldTypesAreRejected() {
        reject("presentation")
        reject(emptyList<Any>())
        reject(mapOf("colors" to "gold"))
        reject(mapOf("text" to listOf("title")))
        reject(mapOf("text" to mapOf("body" to "large")))
        reject(mapOf("layout" to "compact"))
        reject(mapOf("textDirection" to "sideways"))
        reject(mapOf("fontAsset" to 42))
        reject(mapOf("customFontPath" to listOf("font.ttf")))
    }

    @Test fun colorInputsMustBeWholeUnsigned32BitValues() {
        for (invalid in listOf<Any>(-1L, 0x100000000L, 1.5, Double.NaN, "#ffffff")) {
            reject(mapOf("colors" to mapOf("surface" to invalid)))
        }
        assertEquals(0, NativeGameDialogPresentation.parse(mapOf("colors" to mapOf("surface" to 0))).colors.surface)
        assertEquals(-1, NativeGameDialogPresentation.parse(mapOf("colors" to mapOf("surface" to 0xffffffffL))).colors.surface)
    }

    @Test fun textSizesAndLineHeightsMustRemainFiniteAndNonNegative() {
        for (role in listOf("title", "body", "action", "checkbox")) {
            for (field in listOf("fontSize", "lineHeight")) {
                for (invalid in listOf<Any>(Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, Double.MAX_VALUE, -1.0, "18")) {
                    reject(mapOf("text" to mapOf(role to mapOf(field to invalid))))
                }
            }
        }
    }

    @Test fun fontWeightMustBeAnIntegerInTheSupportedWeightRange() {
        for (invalid in listOf<Any>(0, 1000, 500.5, "bold")) {
            reject(mapOf("text" to mapOf("action" to mapOf("fontWeight" to invalid))))
        }
    }

    @Test fun widthsRadiiButtonDimensionsAndSpacingRejectNonFiniteOrNegativeValues() {
        for (field in listOf("minWidth", "radius", "actionMinHeight", "actionSpacing", "buttonRadius")) {
            for (invalid in listOf<Any>(Double.NaN, Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, Double.MAX_VALUE, -1.0, "280")) {
                reject(mapOf("layout" to mapOf(field to invalid)))
            }
        }
    }

    @Test fun paddingsRequireFourFiniteNonNegativeEdges() {
        for (field in listOf("insetPadding", "titlePadding", "contentPadding", "actionsPadding")) {
            for (invalid in listOf<Any>(
                "24", emptyList<Int>(), listOf(1, 2, 3), listOf(1, 2, 3, 4, 5),
                listOf(1, -1, 3, 4), listOf(1, Double.NaN, 3, 4),
                listOf(1, 2, Double.POSITIVE_INFINITY, 4), listOf(1, Double.MAX_VALUE, 3, 4), listOf(1, 2, 3, "4"),
            )) reject(mapOf("layout" to mapOf(field to invalid)))
        }
    }
}
