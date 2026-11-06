package app.yahagi.kancollebrowser

import org.junit.Assert.assertEquals
import org.junit.Test

class GameWindowLayoutPolicyTest {
    private val policy = GameWindowLayoutPolicy()
    private val portrait = GameWindowBounds(0, 0, 1080, 2400)
    private val landscape = GameWindowBounds(0, 0, 2400, 1080)

    @Test fun sideBySideUsesTheReducedWidthRegardlessOfDeviceOrientation() {
        assertEquals(GameWindowMode.SIDE_BY_SIDE, classify(GameWindowBounds(0, 0, 800, 1080), landscape).mode)
        assertEquals(GameWindowMode.SIDE_BY_SIDE, classify(GameWindowBounds(548, 0, 532, 2400), portrait).mode)
    }

    @Test fun stackedUsesTheReducedHeightRegardlessOfDeviceOrientation() {
        assertEquals(GameWindowMode.STACKED, classify(GameWindowBounds(0, 1500, 1080, 900), portrait).mode)
        assertEquals(GameWindowMode.STACKED, classify(GameWindowBounds(0, 0, 2400, 420), landscape).mode)
    }

    @Test fun singleWindowReportsItsOwnOrientation() {
        assertEquals(GameWindowLayout(GameWindowMode.SINGLE, true), classify(landscape, landscape, multiWindow = false))
        assertEquals(GameWindowLayout(GameWindowMode.SINGLE, false), classify(portrait, portrait, multiWindow = false))
    }

    @Test fun floatingAndUnusableMetricsRemainUnknown() {
        assertEquals(GameWindowMode.UNKNOWN, classify(GameWindowBounds(100, 200, 500, 800), portrait).mode)
        assertEquals(GameWindowMode.UNKNOWN, classify(portrait, portrait).mode)
        assertEquals(GameWindowMode.UNKNOWN, classify(GameWindowBounds(0, 0, 0, 0), portrait).mode)
    }

    @Test fun floatingWindowsThatDoNotTouchEitherSplitEdgeRemainUnknown() {
        assertEquals(GameWindowMode.UNKNOWN, classify(GameWindowBounds(0, 800, 1080, 600), portrait).mode)
        assertEquals(GameWindowMode.UNKNOWN, classify(GameWindowBounds(300, 0, 400, 2400), portrait).mode)
    }

    @Test fun pictureInPictureIsNotClassifiedAsSplitScreen() {
        assertEquals(GameWindowMode.PICTURE_IN_PICTURE, classify(GameWindowBounds(0, 0, 400, 240), landscape, pip = true).mode)
    }

    @Test fun matchingEdgesUseToleranceAndRespectTheDisplayOrigin() {
        val display = GameWindowBounds(100, 200, 2400, 1080)
        assertEquals(GameWindowMode.SIDE_BY_SIDE, classify(GameWindowBounds(100, 202, 900, 1076), display).mode)
        assertEquals(GameWindowMode.STACKED, classify(GameWindowBounds(102, 750, 2396, 530), display).mode)
        assertEquals(GameWindowMode.UNKNOWN, classify(GameWindowBounds(140, 250, 900, 900), display).mode)
    }

    private fun classify(current: GameWindowBounds, maximum: GameWindowBounds, multiWindow: Boolean = true, pip: Boolean = false) =
        policy.classify(current, maximum, multiWindow, pip, tolerancePx = 8)
}
