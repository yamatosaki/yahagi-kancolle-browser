package app.yahagi.kancollebrowser

import android.content.pm.ActivityInfo

internal object OrientationPolicy {
    fun requestedOrientation(autoRotateEnabled: Boolean): Int =
        if (autoRotateEnabled) {
            ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR
        } else {
            ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        }
}
