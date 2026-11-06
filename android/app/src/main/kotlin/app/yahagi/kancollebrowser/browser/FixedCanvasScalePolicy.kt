package app.yahagi.kancollebrowser.browser

import kotlin.math.min

class FixedCanvasScalePolicy {
    private data class FitBounds(val width: Int, val height: Int, val contentWidth: Int, val contentHeight: Int)
    private var previousBounds: FitBounds? = null

    fun nextScalePercent(
        viewportWidth: Int,
        viewportHeight: Int,
        contentWidth: Int,
        contentHeight: Int,
        force: Boolean = false,
        imeVisible: Boolean = false,
    ): Int? {
        if (imeVisible) return null
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

        // Android interprets 0 as automatic/default zoom, not a tiny scale.
        // Ignore transitional slivers and wait for a usable layout instead.
        if (scalePercent <= 0) return null

        val bounds = FitBounds(viewportWidth, viewportHeight, contentWidth, contentHeight)
        if (!force && bounds == previousBounds) {
            return null
        }
        previousBounds = bounds
        return scalePercent
    }

    fun reset() {
        previousBounds = null
    }
}
