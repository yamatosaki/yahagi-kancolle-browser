package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameChecklistChangeStateTest {
    private class Changes {
        private val type = try {
            Class.forName("app.yahagi.kancollebrowser.nativewebview.NativeGameChecklistChangeState")
        } catch (_: ClassNotFoundException) {
            fail("Checklist needs an ordered acknowledgement state for rapid changes")
            throw AssertionError("unreachable")
        }
        private val instance = type.getDeclaredConstructor().newInstance()
        fun change(reset: Boolean = false): Long? = type.getDeclaredMethod("change", java.lang.Boolean.TYPE).invoke(instance, reset) as Long?
        fun acknowledge(id: Long): Boolean = type.getDeclaredMethod("acknowledge", java.lang.Long.TYPE).invoke(instance, id) as Boolean
        fun canToggle(): Boolean = type.getDeclaredMethod("getCanToggle").invoke(instance) as Boolean
    }

    @Test fun aLateFirstAcknowledgementCannotOverwriteTheSecondImmediateChange() {
        val state = Changes()
        assertEquals(1L, state.change())
        assertEquals(2L, state.change())
        assertFalse(state.acknowledge(1))
        assertTrue(state.acknowledge(2))
    }

    @Test fun aThirdClickKeepsItsIntentWhileTheSecondAcknowledgementArrives() {
        val state = Changes()
        state.change(); state.change()
        assertFalse(state.acknowledge(1))
        assertEquals(3L, state.change())
        assertFalse(state.acknowledge(2))
        assertTrue(state.acknowledge(3))
    }

    @Test fun anOldAcknowledgementStaysStaleAfterTheNewestOneWasApplied() {
        val state = Changes()
        state.change(); state.change()
        assertTrue(state.acknowledge(2))
        assertFalse(state.acknowledge(1))
        assertTrue(state.acknowledge(2))
    }

    @Test fun externalChangesAreImmediateOnceThereIsNoUnacknowledgedLocalChange() {
        val state = Changes()
        assertTrue(state.acknowledge(0))
        state.change()
        assertFalse(state.acknowledge(0))
        assertTrue(state.acknowledge(1))
        assertTrue(state.acknowledge(0))
    }

    @Test fun resetBlocksFurtherSelectionUntilItsOwnAcknowledgementArrives() {
        val state = Changes()
        assertEquals(1L, state.change(reset = true))
        assertFalse(state.canToggle())
        assertNull(state.change())
        assertNull(state.change(reset = true))
        assertFalse(state.acknowledge(0))
        assertFalse(state.canToggle())
        assertTrue(state.acknowledge(1))
        assertTrue(state.canToggle())
        assertEquals(2L, state.change())
    }

    @Test fun resetAfterAnEarlierToggleCannotBeReleasedByThatEarlierUpdate() {
        val state = Changes()
        state.change()
        assertEquals(2L, state.change(reset = true))
        assertFalse(state.acknowledge(1))
        assertFalse(state.canToggle())
        assertTrue(state.acknowledge(2))
        assertTrue(state.canToggle())
    }
}
