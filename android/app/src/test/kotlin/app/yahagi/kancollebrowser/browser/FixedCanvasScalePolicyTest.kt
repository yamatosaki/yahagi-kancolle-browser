package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FixedCanvasScalePolicyTest {
    @Test
    fun fitsChangedBoundsEvenWhenIntegerScalePercentDoesNotChange() {
        val policy = FixedCanvasScalePolicy()

        assertEquals(50, policy.nextScalePercent(600, 360, 1200, 720))
        assertEquals(50, policy.nextScalePercent(601, 361, 1200, 720))
        assertNull(policy.nextScalePercent(601, 361, 1200, 720))
    }

    @Test
    fun forceRecoveryNeverUsesKeyboardBoundsAndResumesAfterKeyboardCloses() {
        val policy = FixedCanvasScalePolicy()
        repeat(100) {
            assertEquals(100, policy.nextScalePercent(1200, 720, 1200, 720, force = true))
            assertNull(policy.nextScalePercent(1200, 200, 1200, 720, force = true, imeVisible = true))
            assertNull(policy.nextScalePercent(1, 1, 1200, 720, force = true))
            assertEquals(50, policy.nextScalePercent(600, 360, 1200, 720, force = true))
        }
    }

    @Test
    fun ignoresTransientSliverRatherThanRequestingWebViewDefaultZoom() {
        val policy = FixedCanvasScalePolicy()
        assertEquals(100, policy.nextScalePercent(1200, 720, 1200, 720))
        for ((width, height) in listOf(1 to 720, 1200 to 1, 10 to 6)) {
            assertNull(policy.nextScalePercent(width, height, 1200, 720, force = true))
        }
        assertEquals(100, policy.nextScalePercent(1200, 720, 1200, 720, force = true))
    }

    @Test
    fun repeatedResizeSequencesAlwaysFitTheLatestNonzeroBounds() {
        val policy = FixedCanvasScalePolicy()
        val sizes = listOf(1200 to 720, 600 to 360, 1 to 1, 0 to 0,
            900 to 540, 2400 to 1440, 731 to 401, 1200 to 720)
        repeat(200) {
            for ((width, height) in sizes) {
                val result = policy.nextScalePercent(width, height, 1200, 720, force = true)
                if (width < 12 || height < 8) {
                    assertNull(result)
                } else {
                    assertTrue(result!! > 0)
                    assertTrue(1200 * result / 100.0 <= width)
                    assertTrue(720 * result / 100.0 <= height)
                }
            }
        }
    }

    @Test
    fun reappliesTheSameScaleWhenANewPageFinishes() {
        val policy = FixedCanvasScalePolicy()

        assertEquals(50, policy.nextScalePercent(600, 360, 1200, 720))
        assertNull(policy.nextScalePercent(600, 360, 1200, 720))
        assertEquals(
            50,
            policy.nextScalePercent(
                600,
                360,
                1200,
                720,
                force = true,
            ),
        )
    }

    @Test
    fun correctsAProvisionalFirstLayoutWhenTheFinalSizeArrives() {
        val policy = FixedCanvasScalePolicy()

        assertEquals(25, policy.nextScalePercent(300, 180, 1200, 720))
        assertEquals(50, policy.nextScalePercent(600, 360, 1200, 720))
    }

    @Test
    fun ignoresInvalidDimensions() {
        val policy = FixedCanvasScalePolicy()

        assertNull(policy.nextScalePercent(0, 360, 1200, 720))
        assertNull(policy.nextScalePercent(600, 0, 1200, 720))
        assertNull(policy.nextScalePercent(600, 360, 0, 720))
    }

    @Test
    fun fittedCanvasNeverExceedsEitherViewportEdge() {
        val policy = FixedCanvasScalePolicy()
        val scalePercent = policy.nextScalePercent(731, 401, 1200, 720)!!

        assertTrue(1200 * scalePercent / 100f <= 731f)
        assertTrue(720 * scalePercent / 100f <= 401f)
    }

    @Test
    fun ignoresTemporaryViewportHeightWhileImeIsVisible() {
        val policy = FixedCanvasScalePolicy()

        assertEquals(50, policy.nextScalePercent(600, 360, 1200, 720))
        assertNull(
            policy.nextScalePercent(
                600,
                180,
                1200,
                720,
                imeVisible = true,
            ),
        )
        assertNull(policy.nextScalePercent(600, 360, 1200, 720))
    }

    @Test
    fun resumesScalingAfterImeCloses() {
        val policy = FixedCanvasScalePolicy()

        assertEquals(50, policy.nextScalePercent(600, 360, 1200, 720))
        assertNull(
            policy.nextScalePercent(
                600,
                180,
                1200,
                720,
                imeVisible = true,
            ),
        )
        assertEquals(
            66,
            policy.nextScalePercent(
                800,
                480,
                1200,
                720,
                imeVisible = false,
            ),
        )
    }
}
