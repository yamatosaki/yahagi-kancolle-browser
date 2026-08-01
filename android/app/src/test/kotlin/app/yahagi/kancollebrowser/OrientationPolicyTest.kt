package app.yahagi.kancollebrowser

import android.content.pm.ActivityInfo
import org.junit.Assert.assertEquals
import org.junit.Test

class OrientationPolicyTest {
    @Test
    fun locksToLandscapeWhenSystemAutoRotateIsDisabled() {
        assertEquals(
            ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE,
            OrientationPolicy.requestedOrientation(autoRotateEnabled = false),
        )
    }

    @Test
    fun followsAllPhysicalDirectionsWhenSystemAutoRotateIsEnabled() {
        assertEquals(
            ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR,
            OrientationPolicy.requestedOrientation(autoRotateEnabled = true),
        )
    }
}
