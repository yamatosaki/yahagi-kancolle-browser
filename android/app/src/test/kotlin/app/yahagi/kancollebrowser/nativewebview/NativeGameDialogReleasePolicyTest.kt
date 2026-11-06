package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameDialogReleasePolicyTest {
    private class Policy {
        var now = 0L
        private val policy = NativeGameDialogReleasePolicy { now }
        fun begin(surfaceDialog: Boolean, postTouchProtection: Boolean = true) =
            policy.begin(surfaceDialog, postTouchProtection)
        fun delay(): Long = policy.nextDelayMillis()
        fun clear() = policy.clear()
    }

    @Test fun repeatedSurfaceDialogTouchesCannotExtendProtectionPastTwoSeconds() {
        val policy = Policy()
        policy.now = 100
        policy.begin(surfaceDialog = true)
        for (upAt in listOf(100L, 500L, 900L, 1300L)) {
            policy.now = upAt
            assertEquals(600L, policy.delay())
        }
        policy.now = 1900
        assertEquals(200L, policy.delay())
        policy.now = 2100
        assertEquals(0L, policy.delay())
        policy.now = 10_000
        assertEquals(0L, policy.delay())
    }

    @Test fun surfaceGuardStillWaitsForEveryHeldPointerAfterItsDeadline() {
        val policy = Policy()
        val state = NativeGameWarningDialogState()
        state.present(1)
        state.pointerDown(0)
        state.pointerDown(4)
        state.choose(1)
        policy.begin(surfaceDialog = true)
        // The original confirmation gesture must finish before the budget starts.
        policy.now = 3000
        assertFalse(state.canScheduleRelease)
        assertFalse(state.releaseIfQuiet(1, state.releaseVersion))
        state.pointerUp(0)
        assertFalse(state.canScheduleRelease)
        state.pointerUp(4)
        assertTrue(state.canScheduleRelease)
        assertEquals(600L, policy.delay())
        state.pointerDown(1)
        state.pointerDown(7)
        policy.now = 6000
        assertFalse(state.canScheduleRelease)
        state.pointerUp(1)
        assertFalse(state.canScheduleRelease)
        state.pointerUp(7)
        assertEquals(0L, policy.delay())
        assertTrue(state.releaseIfQuiet(1, state.releaseVersion))
    }

    @Test fun cancelReleasesAHeldSurfaceGestureAtTheExpiredDeadline() {
        val policy = Policy()
        val state = NativeGameWarningDialogState()
        state.present(2)
        state.pointerDown(0)
        state.choose(2)
        policy.begin(surfaceDialog = true)
        state.cancelPointers()
        assertTrue(state.canScheduleRelease)
        assertEquals(600L, policy.delay())
        state.pointerDown(3)
        policy.now = 2000
        state.cancelPointers()
        assertEquals(0L, policy.delay())
        assertTrue(state.releaseIfQuiet(2, state.releaseVersion))
    }

    @Test fun originalLongPressDoesNotConsumeTheSurfaceDialogBudget() {
        val policy = Policy()
        policy.begin(surfaceDialog = true)
        policy.now = 5000
        assertEquals(600L, policy.delay())
        policy.now = 6800
        assertEquals(200L, policy.delay())
        policy.now = 7000
        assertEquals(0L, policy.delay())
    }

    @Test fun battleAndOrdinaryNoticesKeepTheFullQuietIntervalAfterEveryTouch() {
        val policy = Policy()
        policy.begin(surfaceDialog = false)
        for (upAt in listOf(0L, 1500L, 2000L, 15_000L)) {
            policy.now = upAt
            assertEquals(600L, policy.delay())
        }
    }

    @Test fun eachSurfaceDialogGetsItsOwnDeadline() {
        val policy = Policy()
        policy.begin(surfaceDialog = true)
        assertEquals(600L, policy.delay())
        policy.now = 2500
        assertEquals(0L, policy.delay())
        policy.clear()
        policy.begin(surfaceDialog = true)
        assertEquals(600L, policy.delay())
        policy.now = 4300
        assertEquals(200L, policy.delay())
    }

    @Test fun clearingASurfaceDeadlineRestoresOrdinaryNoticeProtection() {
        val policy = Policy()
        policy.begin(surfaceDialog = true)
        policy.now = 3000
        policy.clear()
        policy.begin(surfaceDialog = false)
        assertEquals(600L, policy.delay())
    }

    @Test fun unprotectedSurfaceCancellationHasNoDelayAfterTheFinalUp() {
        val policy = Policy()
        policy.begin(surfaceDialog = true, postTouchProtection = false)
        assertEquals(0L, policy.delay())
        policy.now = 5000
        assertEquals(0L, policy.delay())
    }

    @Test fun unprotectedSurfaceCancellationStillWaitsForEveryClosingPointer() {
        val policy = Policy()
        val state = NativeGameWarningDialogState()
        state.present(3)
        state.pointerDown(0)
        state.pointerDown(8)
        state.choose(3)
        policy.begin(surfaceDialog = true, postTouchProtection = false)
        assertFalse(state.canScheduleRelease)
        state.pointerUp(0)
        assertFalse(state.canScheduleRelease)
        state.pointerUp(8)
        assertTrue(state.canScheduleRelease)
        assertEquals(0L, policy.delay())
        assertTrue(state.releaseIfQuiet(3, state.releaseVersion))
    }

    @Test fun anUnprotectedCancellationCannotDisableTheNextDialogsQuietInterval() {
        val policy = Policy()
        policy.begin(surfaceDialog = true, postTouchProtection = false)
        assertEquals(0L, policy.delay())
        policy.clear()
        policy.begin(surfaceDialog = true)
        assertEquals(600L, policy.delay())
    }
}
