package app.yahagi.kancollebrowser.browser

import org.junit.Assert.*
import org.junit.Test

class FullscreenDamageControlNoticeTest {
    @Test fun questUpdatesRequestARefreshOnlyWhenTheyCanChangeTheDisplayedNotice() {
        val state = FullscreenNoticeState()
        assertEquals(true, state.setQuestMessage("quest"))
        state.setDamageControlNotice(1, "damage control")
        assertEquals(false, state.setQuestMessage("updated quest"))
        state.rejectDamageControlPresentation()
        assertEquals(false, state.setQuestMessage("latest quest"))
        state.clearDamageControlNotice(1)
        assertEquals(true, state.setQuestMessage(""))
    }

    @Test fun damageControlTakesPriorityAndRestoresTheLatestPendingQuest() {
        val state = FullscreenNoticeState()
        state.setQuestMessage("quest A")
        assertEquals("quest A", state.displayMessage)
        state.setDamageControlNotice(10, "damage control")
        state.setQuestMessage("quest B")
        assertEquals("damage control", state.displayMessage)
        assertTrue(state.clearDamageControlNotice(10))
        assertEquals("quest B", state.displayMessage)
    }

    @Test fun anExpiredClearCannotRemoveANewerDamageControlNotice() {
        val state = FullscreenNoticeState()
        state.setDamageControlNotice(10, "old")
        state.setDamageControlNotice(11, "new")
        assertFalse(state.clearDamageControlNotice(10))
        assertEquals(11L, state.damageControlId)
        assertEquals("new", state.displayMessage)
    }

    @Test fun failedPresentationNeverReappearsDuringAFullscreenUpdate() {
        val state = FullscreenNoticeState()
        state.setQuestMessage("quest")
        state.setDamageControlNotice(12, "damage control")
        state.rejectDamageControlPresentation()
        state.setQuestMessage("updated quest")
        assertEquals(12L, state.damageControlId)
        assertEquals("", state.displayMessage)
        assertFalse(state.canPresentDamageControl)
        assertTrue(state.clearDamageControlNotice(12))
        assertEquals("updated quest", state.displayMessage)
    }

    @Test fun clearingTheQuestDuringDamageControlDoesNotRestoreAnExpiredQuest() {
        val state = FullscreenNoticeState()
        state.setQuestMessage("quest")
        state.setDamageControlNotice(13, "damage control")
        state.setQuestMessage("")
        state.clearDamageControlNotice(13)
        assertEquals("", state.displayMessage)
    }

    @Test fun leavingFullscreenClearsAllNoticesAndCannotReviveDamageControl() {
        val state = FullscreenNoticeState()
        state.setQuestMessage("quest")
        state.setDamageControlNotice(14, "damage control")
        state.clear()
        assertNull(state.damageControlId)
        assertFalse(state.canPresentDamageControl)
        assertEquals("", state.displayMessage)
        assertFalse(state.clearDamageControlNotice(14))
    }

    @Test fun completeTwoLineTextFitsAtTheContentBoundary() {
        assertTrue(fits())
    }

    @Test fun incompleteEllipsizedAndThirdLineTextMustUseTheDialog() {
        assertFalse(fits(lastLineEnd = 7))
        assertFalse(fits(hasEllipsis = true))
        assertFalse(fits(lineCount = 3))
        assertFalse(fits(lineCount = 0))
    }

    @Test fun textClippedByTheViewOrAvailableContentMustUseTheDialog() {
        assertFalse(fits(requiredWidth = 201))
        assertFalse(fits(requiredHeight = 61))
        assertFalse(fits(bounds = FullscreenOverlayBounds(99, 28, 299, 88)))
        assertFalse(fits(bounds = FullscreenOverlayBounds(100, 29, 300, 89)))
        assertFalse(fits(content = FullscreenOverlayBounds(0, 0, 0, 0)))
        assertFalse(fits(message = ""))
    }

    @Test fun aControlCoveringAnyPartOfTheNoticeMustUseTheDialog() {
        assertFalse(fits(controlBounds = FullscreenOverlayBounds(150, 28, 184, 62)))
        assertFalse(fits(controlBounds = FullscreenOverlayBounds(299, 87, 333, 121)))
        assertTrue(fits(controlBounds = FullscreenOverlayBounds(66, 28, 100, 62)))
        assertTrue(fits(controlBounds = FullscreenOverlayBounds(300, 28, 334, 62)))
        assertTrue(fits(controlBounds = FullscreenOverlayBounds(150, 88, 184, 122)))
    }

    private fun fits(
        message: String = "complete",
        lineCount: Int = 2,
        lastLineEnd: Int = message.length,
        hasEllipsis: Boolean = false,
        requiredWidth: Int = 200,
        requiredHeight: Int = 60,
        bounds: FullscreenOverlayBounds = FullscreenOverlayBounds(100, 28, 300, 88),
        content: FullscreenOverlayBounds = FullscreenOverlayBounds(100, 20, 300, 88),
        controlBounds: FullscreenOverlayBounds? = null,
    ) = fullscreenDamageControlNoticeFits(
        message, lineCount, lastLineEnd, hasEllipsis,
        requiredWidth, requiredHeight, bounds, content, controlBounds,
    )
}
