package app.yahagi.kancollebrowser.browser

import kotlin.math.abs

/** Renderer calibration decisions, independent of WebView and its asynchronous callbacks. */
internal class FixedCanvasCalibration(
    private val targetScale: Double,
    private val contentExtent: Int,
) {
    sealed interface Action {
        data object Wait : Action
        data class Zoom(val factor: Float) : Action
        data object ResetScroll : Action
        data object Complete : Action
        data object Unresolved : Action
    }

    private var firstSampleAt: Long? = null
    private var stableScale: Double? = null
    private var stableSince = 0L
    private var zoomRequestedAt: Long? = null
    private var errorBeforeZoom = 0.0
    private var zoomCount = 0
    private var scrollRequestedAt: Long? = null
    private var terminal: Action? = null

    fun sample(now: Long, actualScale: Double, physicalOffset: Double): Action {
        terminal?.let { return it }
        require(actualScale.isFinite() && actualScale > 0 && physicalOffset.isFinite() && physicalOffset >= 0)
        val started = firstSampleAt ?: now.also { firstSampleAt = it }
        if (now - started >= 2_400L) return stop(Action.Unresolved)

        val previous = stableScale
        if (previous == null || abs(previous - actualScale) * contentExtent > 0.25) {
            stableScale = actualScale
            stableSince = now
        }
        if (now - stableSince < 180L) return Action.Wait

        val scaleError = abs(targetScale - actualScale) * contentExtent
        zoomRequestedAt?.let { requestedAt ->
            // zoomBy is asynchronous. A stable old scale does not mean the
            // renderer has applied (or rejected) the requested correction yet.
            if (now - requestedAt < 600L) return Action.Wait
            zoomRequestedAt = null
            if (scaleError > 1.0 && errorBeforeZoom - scaleError < 0.25) {
                return stop(Action.Unresolved)
            }
        }

        if (scaleError > 1.0) {
            if (zoomCount >= 2) return stop(Action.Unresolved)
            zoomCount++
            errorBeforeZoom = scaleError
            zoomRequestedAt = now
            stableScale = null
            return Action.Zoom((targetScale / actualScale).toFloat().coerceIn(0.01f, 100f))
        }

        // Physical pixel quantization can leave a fractional offset even when
        // the native scroll position is already zero. Never force a 1px nudge.
        if (physicalOffset <= 1.0) return stop(Action.Complete)
        val requestedAt = scrollRequestedAt
        if (requestedAt == null) {
            scrollRequestedAt = now
            return Action.ResetScroll
        }
        return if (now - requestedAt < 400L) Action.Wait else stop(Action.Unresolved)
    }

    private fun stop(action: Action): Action = action.also { terminal = it }
}
