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
        assertEquals(false, field(spec, "getDismissible"))
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

    @Test fun legacyTrueCannotEnableOutsideDismissal() {
        for (value in listOf(false, true)) {
            val spec = NativeGameWarningDialogSpec.parse(payload() + ("dismissible" to value))
            assertFalse(spec.dismissible)
        }
        reject(payload() + ("dismissible" to "false"))
    }

    @Test fun everyNativeDialogKindKeepsOutsideDismissalDisabled() {
        for (kind in NativeGameWarningDialogSpec.kinds) {
            val ids = if (kind == "battle") NativeGameWarningDialogSpec.actions else listOf("acknowledge")
            val value = mapOf(
                "kind" to kind, "id" to 1L, "title" to "title", "headline" to "headline", "body" to "body",
                "rows" to emptyList<String>(), "labels" to ids.associateWith { it },
            )
            assertFalse("Outside dismissal must remain disabled for $kind", NativeGameWarningDialogSpec.parse(value).dismissible)
        }
    }

    @Test fun omittedPostTouchActionsKeepTheExistingProtectionDefault() {
        assertNull(NativeGameWarningDialogSpec.parse(payload()).postTouchProtectionActions)
    }

    @Test fun surfaceDialogsCanOptOutOfDismissalProtection() {
        assertTrue(NativeGameWarningDialogSpec.parse(payload()).protectInputOnDismiss)
        assertTrue(NativeGameWarningDialogSpec.parse(
            payload() + ("protectInputOnDismiss" to true),
        ).protectInputOnDismiss)
        assertFalse(NativeGameWarningDialogSpec.parse(
            payload() + ("protectInputOnDismiss" to false),
        ).protectInputOnDismiss)
        reject(payload() + ("protectInputOnDismiss" to "false"))
    }

    @Test fun postTouchProtectionCanSelectExistingActionsAndChoices() {
        val spec = NativeGameWarningDialogSpec.parse(payload() + mapOf(
            "choices" to listOf(mapOf("id" to "mission_1", "label" to "远征")),
            "postTouchProtectionActions" to listOf("reloadFrame", "mission_1"),
        ))
        assertEquals(setOf("reloadFrame", "mission_1"), spec.postTouchProtectionActions)
        assertEquals(emptySet<String>(), NativeGameWarningDialogSpec.parse(
            payload() + ("postTouchProtectionActions" to emptyList<String>()),
        ).postTouchProtectionActions)
    }

    @Test fun postTouchProtectionRejectsMalformedDuplicateAndUnknownIds() {
        for (value in listOf("reloadFrame", 1, setOf("reloadFrame"), listOf(1), listOf(null), listOf("reloadFrame", "reloadFrame"), listOf("missing"))) {
            reject(payload() + ("postTouchProtectionActions" to value))
        }
        reject(payload() + ("postTouchProtectionActions" to listOf("cancel", "missing")))
    }

    @Test(expected = IllegalArgumentException::class)
    fun explicitNullPostTouchProtectionIsNotAList() {
        NativeGameWarningDialogSpec.parse(payload() + mapOf("postTouchProtectionActions" to null))
    }

    @Test fun oldNoticesCannotAcquireSurfaceDialogControls() {
        val old = mapOf("kind" to "debuff", "id" to 1L, "title" to "削甲", "body" to "完成", "labels" to mapOf("acknowledge" to "确认"))
        assertEquals(listOf("acknowledge"), NativeGameWarningDialogSpec.parse(old).displayActions)
        reject(old + ("actions" to listOf("cancel")))
        reject(old + ("choices" to listOf(mapOf("id" to "m1", "label" to "a"))))
        reject(old + ("checkbox" to mapOf("label" to "跳过", "checked" to false)))
        reject(old + ("postTouchProtectionActions" to listOf("acknowledge")))
        reject(old + ("protectInputOnDismiss" to false))
    }

    @Test fun battleWarningsCannotOptOutOfDismissalProtection() {
        val battle = mapOf(
            "kind" to "battle", "id" to 17L, "title" to "大破警告",
            "headline" to "有舰船大破", "body" to "谨慎进击", "rows" to emptyList<String>(),
            "labels" to NativeGameWarningDialogSpec.actions.associateWith { it },
        )
        assertTrue(NativeGameWarningDialogSpec.parse(battle).protectInputOnDismiss)
        reject(battle + ("protectInputOnDismiss" to false))
    }
}
