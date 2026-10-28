package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameSurfaceDialogSpecTest {
    private fun payload(): Map<String, Any> = mapOf(
        "kind" to "surfaceDialog", "id" to 17L, "title" to "刷新游戏",
        "body" to "保持游戏播放", "actions" to listOf("cancel", "reloadPage", "reloadFrame"),
        "labels" to mapOf("cancel" to "取消", "reloadPage" to "刷新游戏", "reloadFrame" to "框架刷新"),
    )

    private fun reject(values: Map<String, Any>) {
        try { NativeGameWarningDialogSpec.parse(values); fail("Invalid surface dialog accepted") }
        catch (_: IllegalArgumentException) {} catch (_: IllegalStateException) {}
    }

    private fun field(value: Any, name: String): Any? = value.javaClass.getDeclaredMethod(name).invoke(value)

    @Test fun surfaceDialogKeepsLocalizedActionsAndEmptyOptionalWarningFields() {
        val spec = NativeGameWarningDialogSpec.parse(payload())
        assertEquals("surfaceDialog", spec.kind)
        assertEquals(listOf("cancel", "reloadPage", "reloadFrame"), spec.displayActions)
        assertEquals("", spec.headline)
        assertEquals(emptyList<String>(), spec.rows)
        assertEquals("保持游戏播放", spec.body)
        assertEquals(true, field(spec, "getDismissible"))
    }

    @Test fun confirmationCheckboxIsOptionalAndStrictlyTyped() {
        val spec = NativeGameWarningDialogSpec.parse(payload() + ("checkbox" to mapOf("label" to "以后不再确认", "checked" to false)))
        val checkbox = field(spec, "getCheckbox")!!
        assertEquals("以后不再确认", field(checkbox, "getLabel"))
        assertEquals(false, field(checkbox, "getChecked"))
        reject(payload() + ("checkbox" to mapOf("label" to "跳过", "checked" to "false")))
        reject(payload() + ("checkbox" to mapOf("label" to "", "checked" to false)))
    }

    @Test fun singleChoicesKeepGroupsDetailsAndSelection() {
        val spec = NativeGameWarningDialogSpec.parse(payload() + mapOf(
            "choices" to listOf(mapOf("id" to "mission_1", "label" to "01 · 練習航海", "detail" to "00:15:00", "group" to "镇守府海域")),
            "selectedChoiceId" to "mission_1",
        ))
        val choice = (field(spec, "getChoices") as List<*>).single()!!
        assertEquals("mission_1", field(choice, "getId"))
        assertEquals("01 · 練習航海", field(choice, "getLabel"))
        assertEquals("00:15:00", field(choice, "getDetail"))
        assertEquals("镇守府海域", field(choice, "getGroup"))
        assertEquals("mission_1", field(spec, "getSelectedChoiceId"))
    }

    @Test fun selectionBeyondTheOldChecklistLimitRemainsAvailable() {
        val choices = (1..256).map { mapOf("id" to "mission_$it", "label" to "远征 $it") }
        val spec = NativeGameWarningDialogSpec.parse(payload() + ("choices" to choices))
        assertEquals(256, (field(spec, "getChoices") as List<*>).size)
        reject(payload() + ("choices" to choices + mapOf("id" to "mission_257", "label" to "远征257")))
    }

    @Test fun actionIdsAreUniqueBoundedAndCannotCollideWithChoices() {
        reject(payload() + ("actions" to listOf("cancel", "cancel")))
        reject(payload() + ("actions" to emptyList<String>()))
        reject(payload() + ("actions" to listOf("a", "b", "c", "d", "e")))
        reject(payload() + ("actions" to listOf("bad id")))
        reject(payload() + ("choices" to listOf(mapOf("id" to "cancel", "label" to "cannot confirm"))))
    }

    @Test fun malformedChoicesAndStaleSelectedIdsAreRejected() {
        reject(payload() + ("choices" to "bad"))
        reject(payload() + ("choices" to listOf(mapOf("id" to "m1", "label" to ""))))
        reject(payload() + ("choices" to listOf(mapOf("id" to "m1", "label" to "a"), mapOf("id" to "m1", "label" to "b"))))
        reject(payload() + ("selectedChoiceId" to "m1"))
        reject(payload() + ("choices" to listOf(mapOf("id" to "m1", "label" to "a", "detail" to 5))))
    }

    @Test fun barrierDismissalIsExplicitAndStrict() {
        val spec = NativeGameWarningDialogSpec.parse(payload() + ("dismissible" to false))
        assertEquals(false, field(spec, "getDismissible"))
        reject(payload() + ("dismissible" to "false"))
    }

    @Test fun oldNoticesCannotAcquireSurfaceDialogControls() {
        val old = mapOf("kind" to "debuff", "id" to 1L, "title" to "削甲", "body" to "完成", "labels" to mapOf("acknowledge" to "确认"))
        assertEquals(listOf("acknowledge"), NativeGameWarningDialogSpec.parse(old).displayActions)
        reject(old + ("actions" to listOf("cancel")))
        reject(old + ("choices" to listOf(mapOf("id" to "m1", "label" to "a"))))
        reject(old + ("checkbox" to mapOf("label" to "跳过", "checked" to false)))
    }
}
