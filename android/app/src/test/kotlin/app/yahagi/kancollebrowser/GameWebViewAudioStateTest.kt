package app.yahagi.kancollebrowser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameWebViewAudioStateTest {
    private class Owner(var muted: Boolean = false)

    @Test fun unknownTargetDoesNotEnableSoundOrTouchANewOwner() {
        val state = GameWebViewAudioState<Owner>()
        val owner = Owner(muted = true)
        var calls = 0
        assertFalse(state.reconcile(owner, force = true) { _, _ -> calls++ })
        assertTrue(owner.muted)
        assertEquals(0, calls)
    }

    @Test fun aMuteRequestedBeforeAttachmentIsAppliedWhenAnOwnerAppears() {
        val state = GameWebViewAudioState<Owner>()
        state.setTarget(true)
        assertFalse(state.reconcile(null) { _, _ -> error("No owner") })
        val owner = Owner()
        assertTrue(state.reconcile(owner) { view, muted -> view.muted = muted })
        assertTrue(owner.muted)
    }

    @Test fun aRecreatedOwnerInheritsTheLastMuteWithoutAnotherUserToggle() {
        val state = GameWebViewAudioState<Owner>()
        val first = Owner()
        val replacement = Owner()
        val owners = mutableListOf<Owner>()
        state.setTarget(true)
        state.reconcile(first) { view, muted -> view.muted = muted; owners.add(view) }
        assertTrue(state.reconcile(replacement) { view, muted -> view.muted = muted; owners.add(view) })
        assertTrue(first.muted)
        assertTrue(replacement.muted)
        assertEquals(listOf(first, replacement), owners)
    }

    @Test fun repeatedLayoutDiscoveryDoesNotRepeatedlySetTheSameAudioState() {
        val state = GameWebViewAudioState<Owner>()
        val owner = Owner()
        var calls = 0
        state.setTarget(true)
        repeat(200) {
            state.reconcile(owner) { view, muted -> view.muted = muted; calls++ }
        }
        assertTrue(owner.muted)
        assertEquals(1, calls)
    }

    @Test fun aResumeOrFocusRefreshCanRepairTheActualStateDespiteCachedSuccess() {
        val state = GameWebViewAudioState<Owner>()
        val owner = Owner()
        state.setTarget(true)
        state.reconcile(owner) { view, muted -> view.muted = muted }
        owner.muted = false
        assertTrue(state.reconcile(owner, force = true) { view, muted -> view.muted = muted })
        assertTrue(owner.muted)
    }

    @Test fun onlyAnExplicitFalseTargetUnmutesAnAlreadyMutedOwner() {
        val state = GameWebViewAudioState<Owner>()
        val owner = Owner()
        val commands = mutableListOf<Boolean>()
        val apply: (Owner, Boolean) -> Unit = { view, muted -> view.muted = muted; commands.add(muted) }
        state.setTarget(true)
        state.reconcile(owner, apply = apply)
        state.setTarget(false)
        state.reconcile(owner, apply = apply)
        state.reconcile(owner, apply = apply)
        assertFalse(owner.muted)
        assertEquals(listOf(true, false), commands)
    }

    @Test fun aFailedNativeCallDoesNotConsumeTheRetainedMuteTarget() {
        val state = GameWebViewAudioState<Owner>()
        val owner = Owner()
        state.setTarget(true)
        var failed = false
        try {
            state.reconcile(owner) { _, _ -> throw IllegalStateException("transient native failure") }
        } catch (_: IllegalStateException) {
            failed = true
        }
        assertTrue(failed)
        assertTrue(state.reconcile(owner) { view, muted -> view.muted = muted })
        assertTrue(owner.muted)
    }

    @Test fun anErrorAfterAnUnmuteSideEffectCannotHideTheNextMuteRepair() {
        val state = GameWebViewAudioState<Owner>()
        val owner = Owner()
        state.setTarget(true)
        state.reconcile(owner) { view, muted -> view.muted = muted }
        state.setTarget(false)
        try {
            state.reconcile(owner) { view, muted ->
                view.muted = muted
                throw IllegalStateException("failed after applying")
            }
        } catch (_: IllegalStateException) {
            // Native error replies do not prove that their side effect failed.
        }
        assertFalse(owner.muted)
        state.setTarget(true)
        assertTrue(state.reconcile(owner) { view, muted -> view.muted = muted })
        assertTrue(owner.muted)
    }

    @Test fun reentrantTargetReplacementCannotOverwriteTheLatestSuccessfulOwner() {
        val state = GameWebViewAudioState<Owner>()
        val old = Owner()
        val current = Owner(muted = true)
        var currentCalls = 0
        val applyCurrent: (Owner, Boolean) -> Unit = { view, muted ->
            view.muted = muted
            currentCalls++
        }
        state.setTarget(true)
        state.reconcile(old) { view, muted ->
            view.muted = muted
            state.setTarget(false)
            state.reconcile(current, apply = applyCurrent)
        }
        assertFalse(state.reconcile(current, apply = applyCurrent))
        assertFalse(current.muted)
        assertEquals(1, currentCalls)
    }
}
