package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameDialogOwnerQueueTest {
    private val oldShip = NativeGameDialogKey("newShip", 1)
    private val oldDebuff = NativeGameDialogKey("debuff", 2)
    private val currentDebuff = NativeGameDialogKey("debuff", 3)

    @Test fun retiringTheOldOwnerKeepsTheNewOwnersQueuedReminder() {
        val queue = mixedOwners()
        assertEquals(listOf(oldShip, oldDebuff), discard(queue, setOf(oldShip, oldDebuff)))
        assertEquals(currentDebuff, queue.active)
        assertTrue(queue.waiting.isEmpty())
    }

    @Test fun aPhysicalGestureRetainsOnlyTheOldActiveProtectionBeforeTheNewOwner() {
        val queue = mixedOwners()
        assertEquals(listOf(oldDebuff), discard(queue, setOf(oldShip, oldDebuff), preserveActive = true))
        assertEquals(oldShip, queue.active)
        assertEquals(listOf(currentDebuff), queue.waiting)
        queue.finish(oldShip.kind, oldShip.id)
        assertEquals(currentDebuff, queue.active)
    }

    @Test fun retiringQueuedOldOwnersCannotCancelTheCurrentActiveReminder() {
        val queue = NativeGameDialogQueue()
        queue.offer(currentDebuff.kind, currentDebuff.id, false)
        queue.offer(oldShip.kind, oldShip.id, false)
        assertEquals(listOf(oldShip), discard(queue, setOf(oldShip)))
        assertEquals(currentDebuff, queue.active)
        assertTrue(queue.waiting.isEmpty())
    }

    @Test fun retiringAllOwnersWithoutAPhysicalGestureLeavesNoPendingRequest() {
        val queue = NativeGameDialogQueue()
        queue.offer(oldShip.kind, oldShip.id, false)
        queue.offer(oldDebuff.kind, oldDebuff.id, false)
        assertEquals(listOf(oldShip, oldDebuff), discard(queue, setOf(oldShip, oldDebuff)))
        assertNull(queue.active)
        assertTrue(queue.waiting.isEmpty())
    }

    @Test fun unconfirmedContactsAreTrackedBeforeAnActionHasBeenChosen() {
        val state = NativeGameWarningDialogState()
        state.present(1)
        assertFalse(hasPointers(state))
        state.pointerDown(3)
        assertTrue(hasPointers(state))
        assertFalse(state.actionChosen)
        state.choose(1)
        assertFalse(state.canScheduleRelease)
        state.pointerUp(3)
        assertFalse(hasPointers(state))
        assertTrue(state.canScheduleRelease)
    }

    private fun mixedOwners() = NativeGameDialogQueue().apply {
        offer(oldShip.kind, oldShip.id, false)
        offer(oldDebuff.kind, oldDebuff.id, false)
        offer(currentDebuff.kind, currentDebuff.id, false)
    }

    @Suppress("UNCHECKED_CAST")
    private fun discard(queue: NativeGameDialogQueue, invalid: Set<NativeGameDialogKey>, preserveActive: Boolean = false): List<NativeGameDialogKey> {
        val method = try {
            queue.javaClass.getDeclaredMethod("discardInvalid", Set::class.java, java.lang.Boolean.TYPE)
        } catch (_: NoSuchMethodException) {
            fail("Owner changes must retire only stale requests while preserving the current owner's pending reminders")
            throw AssertionError("unreachable")
        }
        return method.invoke(queue, invalid, preserveActive) as List<NativeGameDialogKey>
    }

    private fun hasPointers(state: NativeGameWarningDialogState): Boolean {
        val method = try {
            state.javaClass.getDeclaredMethod("getHasPointers")
        } catch (_: NoSuchMethodException) {
            fail("An unconfirmed pointer must keep global protection during an owner change")
            throw AssertionError("unreachable")
        }
        return method.invoke(state) as Boolean
    }
}
