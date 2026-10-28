package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameCustomLabelChecklistTest {
    private fun item(extra: Map<String, Any?> = emptyMap()): NativeGameChecklistItem =
        NativeGameChecklistItem.parse(mapOf(
            "id" to "fleet1", "label" to "第一舰队", "value" to "", "checked" to false,
        ) + extra)

    private fun enabled(item: NativeGameChecklistItem): Boolean {
        val getter = item.javaClass.declaredMethods.firstOrNull { it.name == "getEnabled" }
        assertNotNull("Checklist items must retain their enabled flag", getter)
        return getter!!.invoke(item) as Boolean
    }

    @Test fun customModuleAndFleetSettingsUseTheExistingChecklistProtocol() {
        for (kind in listOf("moduleDisplay", "fleetDisplay")) {
            val spec = NativeGameWarningDialogSpec.parse(mapOf(
                "id" to 70L, "kind" to kind, "title" to "自定义标签",
                "labels" to mapOf("acknowledge" to "完成"),
                "items" to listOf(mapOf(
                    "id" to "fleet1", "label" to "第一舰队", "value" to "", "checked" to true,
                )),
            ))
            assertTrue(spec.isChecklist)
            assertTrue(spec.isNotice)
            assertEquals(listOf("acknowledge"), spec.displayActions)
            assertEquals("fleet1", spec.items.single().id)
        }
    }

    @Test fun aDisabledUncheckedItemRetainsItsLimitRestriction() {
        val item = item(mapOf("enabled" to false))
        assertFalse(enabled(item))
        assertFalse(item.checked)
        assertFalse(enabled(item.copy(checked = true)))
    }

    @Test fun olderItemsRemainEnabledWhenTheFieldIsAbsent() {
        assertTrue(enabled(item()))
        assertTrue(enabled(item(mapOf("enabled" to true))))
    }

    @Test fun anEnabledFieldRejectsNonBooleanValuesIncludingExplicitNull() {
        for (invalid in listOf(null, "false", 0, 1, emptyList<Any>())) {
            try {
                item(mapOf("enabled" to invalid))
                fail("Checklist enabled must reject $invalid")
            } catch (_: IllegalArgumentException) {
            } catch (_: IllegalStateException) {
            }
        }
    }
}
