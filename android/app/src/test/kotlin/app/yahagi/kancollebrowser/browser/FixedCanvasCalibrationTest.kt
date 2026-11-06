package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FixedCanvasCalibrationTest {
    @Test
    fun acceptsPhysicalPixelRoundingWithoutZoomingOrMovingTheCanvas() {
        val calibration = FixedCanvasCalibration(0.5, 1200)
        val decisions = (0L..800L step 80).map {
            calibration.sample(it, 0.5 - 0.75 / 1200, 0.75)
        }

        assertTrue(decisions.contains(FixedCanvasCalibration.Action.Complete))
        assertFalse(decisions.any { it is FixedCanvasCalibration.Action.Zoom })
        assertFalse(decisions.contains(FixedCanvasCalibration.Action.ResetScroll))
    }

    @Test
    fun waitsForStableRendererSamplesBeforeFirstZoom() {
        val calibration = FixedCanvasCalibration(0.5, 1200)

        for (now in listOf(0L, 80L, 160L)) {
            assertEquals(FixedCanvasCalibration.Action.Wait, calibration.sample(now, 1.0, 0.0))
        }
        assertTrue(calibration.sample(240L, 1.0, 0.0) is FixedCanvasCalibration.Action.Zoom)
    }

    @Test
    fun leavesAnAsynchronousZoomTimeToReachTheRenderer() {
        val calibration = FixedCanvasCalibration(0.5, 1200)
        val decisions = mutableListOf<FixedCanvasCalibration.Action>()
        for (now in 0L..1600L step 80) {
            // Chromium does not expose the first correction until 480 ms later.
            decisions += calibration.sample(now, if (now < 720) 1.0 else 0.5, 0.0)
        }

        assertEquals(1, decisions.count { it is FixedCanvasCalibration.Action.Zoom })
        assertTrue(decisions.contains(FixedCanvasCalibration.Action.Complete))
    }

    @Test
    fun stopsWhenRendererCannotApplyTheRequestedZoom() {
        val calibration = FixedCanvasCalibration(0.5, 1200)
        val decisions = (0L..4000L step 80).map { calibration.sample(it, 0.51, 0.0) }

        assertEquals(1, decisions.count { it is FixedCanvasCalibration.Action.Zoom })
        assertTrue(decisions.contains(FixedCanvasCalibration.Action.Unresolved))
        assertFalse(decisions.contains(FixedCanvasCalibration.Action.Complete))
    }

    @Test
    fun makesAtMostTwoCorrectionsWhenEachZoomStillMissesTheTarget() {
        val calibration = FixedCanvasCalibration(0.5, 1200)
        var scale = 1.0
        var zooms = 0
        val decisions = (0L..4000L step 80).map {
            calibration.sample(it, scale, 0.0).also { decision ->
                if (decision is FixedCanvasCalibration.Action.Zoom) {
                    zooms++
                    scale = if (zooms == 1) 0.55 else 0.52
                }
            }
        }

        assertEquals(2, zooms)
        assertTrue(decisions.contains(FixedCanvasCalibration.Action.Unresolved))
    }

    @Test
    fun triesScrollOriginOnlyOnceThenStopsAnUnresolvableOffset() {
        val calibration = FixedCanvasCalibration(0.5, 1200)
        val decisions = (0L..4000L step 80).map { calibration.sample(it, 0.5, 2.0) }

        assertEquals(1, decisions.count { it == FixedCanvasCalibration.Action.ResetScroll })
        assertFalse(decisions.any { it is FixedCanvasCalibration.Action.Zoom })
        assertTrue(decisions.contains(FixedCanvasCalibration.Action.Unresolved))
    }
}
