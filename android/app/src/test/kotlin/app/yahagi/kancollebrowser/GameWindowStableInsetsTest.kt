package app.yahagi.kancollebrowser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameWindowStableInsetsTest {
    private val none = GameWindowStableInsets(0, 0, 0, 0)

    @Test fun lowerSplitProjectsTheBottomBarIntoAnEdgeToEdgeFlutterView() {
        val window = GameWindowBounds(0, 1200, 1080, 1200)
        assertEquals(
            GameWindowStableInsets(0, 0, 0, 52),
            projectStableInsetsToView(window, GameWindowStableInsets(0, 0, 0, 52), window),
        )
    }

    @Test fun upperSplitWithoutNavigationBarHasNoBottomReservation() {
        val window = GameWindowBounds(0, 0, 1080, 1180)
        assertEquals(none, projectStableInsetsToView(window, none, window))
        assertEquals(
            none,
            projectStableInsetsToView(
                GameWindowBounds(0, 0, 1080, 2400),
                GameWindowStableInsets(0, 0, 0, 52),
                window,
            ),
        )
    }

    @Test fun flutterViewAlreadyInsideSystemBarsDoesNotReserveThemTwice() {
        assertEquals(
            none,
            projectStableInsetsToView(
                GameWindowBounds(0, 0, 1080, 2400),
                GameWindowStableInsets(0, 84, 0, 52),
                GameWindowBounds(0, 84, 1080, 2264),
            ),
        )
    }

    @Test fun landscapeEdgeToEdgeViewKeepsTheRightNavigationBar() {
        val window = GameWindowBounds(0, 0, 2400, 1080)
        assertEquals(
            GameWindowStableInsets(0, 0, 52, 0),
            projectStableInsetsToView(window, GameWindowStableInsets(0, 0, 52, 0), window),
        )
    }

    @Test fun projectionUsesScreenCoordinatesIncludingAnOffsetWindowOrigin() {
        assertEquals(
            GameWindowStableInsets(0, 12, 26, 42),
            projectStableInsetsToView(
                GameWindowBounds(150, 320, 1000, 800),
                GameWindowStableInsets(20, 32, 52, 52),
                GameWindowBounds(180, 340, 944, 770),
            ),
        )
    }

    @Test fun partiallyExcludedBarsReserveOnlyTheirRemainingOverlap() {
        assertEquals(
            GameWindowStableInsets(10, 0, 22, 0),
            projectStableInsetsToView(
                GameWindowBounds(0, 0, 1000, 800),
                GameWindowStableInsets(20, 0, 52, 0),
                GameWindowBounds(10, 0, 960, 800),
            ),
        )
    }

    @Test fun malformedInsetsAndCoordinatesCannotOverflowOrExceedViewDimensions() {
        assertEquals(
            GameWindowStableInsets(0, 200, 300, 0),
            projectStableInsetsToView(
                GameWindowBounds(Int.MIN_VALUE, Int.MIN_VALUE, Int.MAX_VALUE, Int.MAX_VALUE),
                GameWindowStableInsets(-20, Int.MAX_VALUE, Int.MAX_VALUE, -1),
                GameWindowBounds(Int.MAX_VALUE - 299, Int.MIN_VALUE, 300, 200),
            ),
        )
    }

    @Test fun unusableBoundsDoNotCreateReservations() {
        assertEquals(
            none,
            projectStableInsetsToView(
                GameWindowBounds(0, 0, 0, 800),
                GameWindowStableInsets(40, 50, 60, 70),
                GameWindowBounds(0, 0, 300, 200),
            ),
        )
        assertEquals(
            none,
            projectStableInsetsToView(
                GameWindowBounds(0, 0, 1000, 800),
                GameWindowStableInsets(40, 50, 60, 70),
                GameWindowBounds(0, 0, 300, -200),
            ),
        )
    }

    @Test fun sampleMessageBindsProjectedPhysicalInsetsToItsFlutterViewSize() {
        val sample = GameWindowStableInsetsSample(
            GameWindowBounds(0, 1200, 1080, 1200),
            GameWindowStableInsets(0, 0, 0, 52),
            GameWindowBounds(0, 1200, 1080, 1174),
        )
        assertEquals(
            mapOf(
                "stableInsets" to mapOf("left" to 0, "top" to 0, "right" to 0, "bottom" to 26),
                "insetsViewWidth" to 1080,
                "insetsViewHeight" to 1174,
            ),
            sample.toMap(),
        )
    }

    @Test fun changedStableNavigationInsetsStartANewQuietPeriodWithoutAWindowResize() {
        val window = GameWindowBounds(0, 1200, 1080, 1200)
        val before = GameWindowStableInsetsSample(window, GameWindowStableInsets(0, 0, 0, 52), window)
        val settler = GameWindowLayoutSettler<GameWindowStableInsetsSample>()
        assertTrue(settler.observe(before, 0).changing)
        assertTrue(settler.observe(before, 200).stable)
        // Visibility is intentionally absent: an identical ignoring-visibility
        // sample from a foreign IME callback cannot start another transition.
        assertEquals(GameWindowLayoutSettler.Decision(), settler.observe(before.copy(), 250))
        val after = before.copy(sourceInsets = GameWindowStableInsets(0, 0, 0, 100))
        assertTrue(settler.observe(after, 300).changing)
        assertFalse(settler.observe(after, 499).stable)
        assertTrue(settler.observe(after, 500).stable)
    }

    @Test fun feedbackDeviceProjectsTheSameNavigationFrameDifferentlyInUpperAndLowerSplit() {
        val display = GameWindowBounds(0, 0, 1220, 2712)
        val navigation = GameWindowStableInsets(0, 0, 0, 52)
        val upper = GameWindowBounds(0, 0, 1220, 824)
        val lower = GameWindowBounds(0, 1888, 1220, 824)

        // The reported navigation frame is [0,2660][1220,2712]. Its 52 px
        // overlap belongs only to the lower surface, despite equal view sizes.
        assertEquals(none, projectStableInsetsToView(display, navigation, upper))
        assertEquals(navigation, projectStableInsetsToView(display, navigation, lower))
        assertEquals(navigation, projectStableInsetsToView(lower, navigation, lower))
        assertEquals(
            none,
            projectStableInsetsToView(lower, navigation, lower.copy(height = 772)),
        )
    }

    @Test fun swappingEqualSizedSplitWindowsReleasesOneStableSampleAtTheOriginalDeadline() {
        val upper = GameWindowBounds(0, 0, 1220, 824)
        val lower = GameWindowBounds(0, 1888, 1220, 824)
        val before = GameWindowStableInsetsSample(upper, none, upper)
        val after = GameWindowStableInsetsSample(lower, GameWindowStableInsets(0, 0, 0, 52), lower)
        val settler = GameWindowLayoutSettler<GameWindowStableInsetsSample>()
        assertTrue(settler.observe(before, 0).changing)
        assertTrue(settler.observe(before, 200).stable)

        assertTrue(settler.observe(after, 300).changing)
        assertEquals(150L, settler.observe(after.copy(), 350).retryAfterMillis)
        assertEquals(1L, settler.observe(after.copy(), 499).retryAfterMillis)
        assertTrue(settler.observe(after, 500).stable)
        // Repeated focus/layout callbacks, including a delayed one after the
        // stable event, carry no new ignoring-visibility geometry.
        for (time in listOf(501L, 650L, 810L, 1200L)) {
            assertEquals(GameWindowLayoutSettler.Decision(), settler.observe(after.copy(), time))
        }
        assertEquals(
            mapOf("left" to 0, "top" to 0, "right" to 0, "bottom" to 52),
            after.toMap()["stableInsets"],
        )
    }

    @Test fun realFeedbackSplitResizeRestartsQuietPeriodButDuplicateCallbacksDoNot() {
        val oldBounds = GameWindowBounds(0, 1888, 1220, 824)
        val finalBounds = GameWindowBounds(0, 1712, 1220, 1000)
        val navigation = GameWindowStableInsets(0, 0, 0, 52)
        val before = GameWindowStableInsetsSample(oldBounds, navigation, oldBounds)
        val after = GameWindowStableInsetsSample(finalBounds, navigation, finalBounds)
        val settler = GameWindowLayoutSettler<GameWindowStableInsetsSample>()
        assertTrue(settler.observe(before, 0).changing)
        assertTrue(settler.observe(before, 200).stable)

        assertTrue(settler.observe(after, 300).changing)
        assertEquals(100L, settler.observe(after.copy(), 400).retryAfterMillis)
        assertEquals(1L, settler.observe(after.copy(), 499).retryAfterMillis)
        assertTrue(settler.observe(after, 500).stable)
        assertEquals(GameWindowLayoutSettler.Decision(), settler.observe(after.copy(), 810))
        assertEquals(1000, after.toMap()["insetsViewHeight"])
        assertEquals(
            mapOf("left" to 0, "top" to 0, "right" to 0, "bottom" to 52),
            after.toMap()["stableInsets"],
        )
    }
}
