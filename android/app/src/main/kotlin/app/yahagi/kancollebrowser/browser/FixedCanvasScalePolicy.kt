package app.yahagi.kancollebrowser.browser

import kotlin.math.min

class FixedCanvasScalePolicy {
    private var previousScalePercent: Int? = null

    fun nextScalePercent(
        viewportWidth: Int,
        viewportHeight: Int,
        contentWidth: Int,
        contentHeight: Int,
        force: Boolean = false,
    ): Int? {
        if (
            viewportWidth <= 0 ||
            viewportHeight <= 0 ||
            contentWidth <= 0 ||
            contentHeight <= 0
        ) {
            return null
        }

        val scalePercent = (
            min(
                viewportWidth.toFloat() / contentWidth.toFloat(),
                viewportHeight.toFloat() / contentHeight.toFloat(),
            ) * 100f
        ).toInt()

        if (!force && scalePercent == previousScalePercent) {
            return null
        }
        previousScalePercent = scalePercent
        return scalePercent
    }

    fun reset() {
        previousScalePercent = null
    }
}
