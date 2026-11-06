package app.yahagi.kancollebrowser

import kotlin.math.abs

enum class GameWindowMode(val wireValue: String) {
    SINGLE("single"), SIDE_BY_SIDE("sideBySide"), STACKED("stacked"),
    UNKNOWN("unknown"), PICTURE_IN_PICTURE("pictureInPicture"),
}

data class GameWindowBounds(val left: Int, val top: Int, val width: Int, val height: Int)
data class GameWindowLayout(val mode: GameWindowMode, val isLandscape: Boolean) {
    fun toMap(): Map<String, Any> = mapOf("mode" to mode.wireValue, "isLandscape" to isLandscape)
}

class GameWindowLayoutPolicy {
    fun classify(
        current: GameWindowBounds,
        maximum: GameWindowBounds,
        isInMultiWindowMode: Boolean,
        isInPictureInPictureMode: Boolean,
        tolerancePx: Int,
    ): GameWindowLayout {
        val landscape = maximum.width > maximum.height
        if (isInPictureInPictureMode) return GameWindowLayout(GameWindowMode.PICTURE_IN_PICTURE, landscape)
        if (current.width <= 0 || current.height <= 0 || maximum.width <= 0 || maximum.height <= 0) {
            return GameWindowLayout(GameWindowMode.UNKNOWN, landscape)
        }
        if (!isInMultiWindowMode) return GameWindowLayout(GameWindowMode.SINGLE, current.width > current.height)
        val tolerance = tolerancePx.coerceAtLeast(0).toLong()
        fun spans(start: Int, size: Int, fullStart: Int, fullSize: Int): Boolean =
            abs(start.toLong() - fullStart) <= tolerance &&
                abs(start.toLong() + size - fullStart.toLong() - fullSize) <= tolerance
        val spansWidth = spans(current.left, current.width, maximum.left, maximum.width)
        val spansHeight = spans(current.top, current.height, maximum.top, maximum.height)
        fun touchesEdge(start: Int, size: Int, fullStart: Int, fullSize: Int): Boolean =
            abs(start.toLong() - fullStart) <= tolerance ||
                abs(start.toLong() + size - fullStart.toLong() - fullSize) <= tolerance
        val touchesHorizontalEdge = touchesEdge(current.left, current.width, maximum.left, maximum.width)
        val touchesVerticalEdge = touchesEdge(current.top, current.height, maximum.top, maximum.height)
        val inside = current.left.toLong() >= maximum.left.toLong() - tolerance &&
            current.top.toLong() >= maximum.top.toLong() - tolerance &&
            current.left.toLong() + current.width <= maximum.left.toLong() + maximum.width + tolerance &&
            current.top.toLong() + current.height <= maximum.top.toLong() + maximum.height + tolerance
        val mode = when {
            !inside -> GameWindowMode.UNKNOWN
            spansWidth && !spansHeight && touchesVerticalEdge -> GameWindowMode.STACKED
            spansHeight && !spansWidth && touchesHorizontalEdge -> GameWindowMode.SIDE_BY_SIDE
            else -> GameWindowMode.UNKNOWN
        }
        return GameWindowLayout(mode, landscape)
    }
}
