package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FixedCanvasScalePolicyTest {
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
}
