package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameWarningDialogStateTest {
    // Reflection lets the first red run assert the missing behavior instead of
    // failing Kotlin compilation before the production class has been added.
    private class State {
        private val type = try {
            Class.forName("app.yahagi.kancollebrowser.nativewebview.NativeGameWarningDialogState")
        } catch (_: ClassNotFoundException) {
            fail("Native warning needs independent input protection without hiding the WebView")
            throw AssertionError("unreachable")
        }
        private val instance = type.getDeclaredConstructor().newInstance()
        fun show(id: Long) { call("present", arrayOf(java.lang.Long.TYPE), id) }
        fun choose(id: Long): Boolean = call("choose", arrayOf(java.lang.Long.TYPE), id) as Boolean
        fun down(pointer: Int) { call("pointerDown", arrayOf(Integer.TYPE), pointer) }
        fun up(pointer: Int) { call("pointerUp", arrayOf(Integer.TYPE), pointer) }
        fun cancel() { call("cancelPointers", emptyArray()) }
        fun version(): Long = call("getReleaseVersion", emptyArray()) as Long
        fun release(id: Long, version: Long): Boolean = call(
            "releaseIfQuiet", arrayOf(java.lang.Long.TYPE, java.lang.Long.TYPE), id, version,
        ) as Boolean
        fun dismiss(id: Long): Boolean = call("dismiss", arrayOf(java.lang.Long.TYPE), id) as Boolean
        private fun call(name: String, parameters: Array<Class<*>>, vararg args: Any): Any? =
            type.getDeclaredMethod(name, *parameters).invoke(instance, *args)
    }

    @Test fun warningRemainsProtectedUntilAnActionIsChosen() {
        val state = State()
        state.show(10)
        assertFalse(state.release(10, state.version()))
        assertTrue(state.choose(10))
        assertTrue(state.release(10, state.version()))
    }

    @Test fun repeatedButtonsAndExpiredWarningsCannotDispatchAnActionAgain() {
        val state = State()
        state.show(10)
        assertFalse(state.choose(9))
        assertTrue(state.choose(10))
        assertFalse(state.choose(10))
        state.show(11)
        assertFalse(state.choose(10))
        assertTrue(state.choose(11))
    }

    @Test fun heldPointersAndMultitouchKeepProtectingTheGameAfterTheButton() {
        val state = State()
        state.show(20)
        state.down(3)
        state.down(7)
        assertTrue(state.choose(20))
        state.up(3)
        assertFalse(state.release(20, state.version()))
        state.up(7)
        assertTrue(state.release(20, state.version()))
    }

    @Test fun anotherTouchRestartsTheEntireQuietInterval() {
        val state = State()
        state.show(20)
        state.choose(20)
        val expired = state.version()
        state.down(3)
        state.up(3)
        assertFalse(state.release(20, expired))
        assertTrue(state.release(20, state.version()))
    }

    @Test fun anOldTimerOrDismissCannotRemoveTheNextWarningOrItsGuard() {
        val state = State()
        state.show(30)
        state.choose(30)
        val expired = state.version()
        state.show(31)
        state.choose(31)
        assertFalse(state.release(30, expired))
        assertFalse(state.dismiss(30))
        assertTrue(state.release(31, state.version()))
    }

    @Test fun aCancelledGestureCanFinishProtectionWithoutAnUpEvent() {
        val state = State()
        state.show(40)
        state.down(1)
        state.choose(40)
        state.cancel()
        assertTrue(state.release(40, state.version()))
    }

    @Test fun replacingAWarningWhileAContactIsHeldKeepsThatContactProtected() {
        val state = NativeGameWarningDialogState()
        state.present(50)
        state.choose(50)
        state.pointerDown(3)
        state.present(51)
        state.choose(51)
        assertFalse(state.canScheduleRelease)
        assertFalse(state.releaseIfQuiet(51, state.releaseVersion))
        state.pointerUp(3)
        assertTrue(state.canScheduleRelease)
        assertTrue(state.releaseIfQuiet(51, state.releaseVersion))
    }

    @Test fun localizedLabelsAndDisabledRefreshActionsRemainSeparateFromTheActionKeys() {
        val spec = NativeGameWarningDialogSpec.parse(mapOf(
            "id" to 60L, "title" to "大破警告", "headline" to "请撤退", "body" to "说明",
            "rows" to listOf("阿武隈 7/51"),
            "labels" to mapOf("acknowledge" to "确认", "mute" to "本次不提醒", "reloadGame" to "刷新", "reloadFrame" to "刷新框架"),
            "enabled" to mapOf("reloadFrame" to false), "refreshFailed" to "刷新失败，请重试",
        ))
        assertEquals(60L, spec.id)
        assertEquals("确认", spec.labels["acknowledge"])
        assertEquals(listOf("阿武隈 7/51"), spec.rows)
        assertTrue(spec.enabled.getValue("acknowledge"))
        assertTrue(spec.enabled.getValue("reloadGame"))
        assertFalse(spec.enabled.getValue("reloadFrame"))
        assertEquals("刷新失败，请重试", spec.refreshFailed)
    }

    @Test(expected = IllegalStateException::class)
    fun incompleteButtonLabelsAreRejectedBeforePresentingAnUnusableWarning() {
        NativeGameWarningDialogSpec.parse(mapOf(
            "id" to 61L, "title" to "warning", "headline" to "danger", "body" to "body",
            "rows" to emptyList<String>(), "labels" to mapOf("acknowledge" to "OK"),
        ))
    }
}
