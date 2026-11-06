package app.yahagi.kancollebrowser.nativewebview

import kotlin.math.roundToInt

data class NativeGameWebViewBounds(
    val left: Double,
    val top: Double,
    val width: Double,
    val height: Double,
    val devicePixelRatio: Double,
    val clipLeft: Double? = null,
    val clipTop: Double? = null,
    val clipWidth: Double? = null,
    val clipHeight: Double? = null,
) {
    init {
        require(left.isFinite())
        require(top.isFinite())
        require(width.isFinite() && width > 0.0)
        require(height.isFinite() && height > 0.0)
        require(devicePixelRatio.isFinite() && devicePixelRatio > 0.0)
        val clip = listOf(clipLeft, clipTop, clipWidth, clipHeight)
        require(clip.all { it == null } || clip.all { it != null })
        if (clipLeft != null) {
            require(clipLeft.isFinite() && clipTop!!.isFinite())
            require(clipWidth!!.isFinite() && clipWidth > 0.0)
            require(clipHeight!!.isFinite() && clipHeight > 0.0)
        }
    }

    fun toPhysicalBounds(rootWidth: Int, rootHeight: Int): PhysicalBounds? {
        if (rootWidth <= 0 || rootHeight <= 0) {
            return null
        }

        val logicalRight = left + width
        val logicalBottom = top + height
        val physicalLeft = roundedCoordinate(left * devicePixelRatio) ?: return null
        val physicalTop = roundedCoordinate(top * devicePixelRatio) ?: return null
        val physicalRight = roundedCoordinate(logicalRight * devicePixelRatio) ?: return null
        val physicalBottom = roundedCoordinate(logicalBottom * devicePixelRatio) ?: return null

        val viewportLeft = clipLeft?.let { roundedCoordinate(it * devicePixelRatio) ?: return null } ?: 0
        val viewportTop = clipTop?.let { roundedCoordinate(it * devicePixelRatio) ?: return null } ?: 0
        val viewportRight = clipLeft?.let { roundedCoordinate((it + clipWidth!!) * devicePixelRatio) ?: return null } ?: rootWidth
        val viewportBottom = clipTop?.let { roundedCoordinate((it + clipHeight!!) * devicePixelRatio) ?: return null } ?: rootHeight
        val clippedLeft = maxOf(physicalLeft, viewportLeft, 0)
        val clippedTop = maxOf(physicalTop, viewportTop, 0)
        val clippedRight = minOf(physicalRight, viewportRight, rootWidth)
        val clippedBottom = minOf(physicalBottom, viewportBottom, rootHeight)
        if (clippedRight <= clippedLeft || clippedBottom <= clippedTop) {
            return null
        }

        return PhysicalBounds(clippedLeft, clippedTop, clippedRight, clippedBottom)
    }

    fun toLayoutBounds(rootWidth: Int, rootHeight: Int): GameWebViewLayoutBounds? {
        if (toPhysicalBounds(rootWidth, rootHeight) == null) return null
        val physicalLeft = roundedCoordinate(left * devicePixelRatio) ?: return null
        val physicalTop = roundedCoordinate(top * devicePixelRatio) ?: return null
        val physicalRight = roundedCoordinate((left + width) * devicePixelRatio) ?: return null
        val physicalBottom = roundedCoordinate((top + height) * devicePixelRatio) ?: return null
        val physicalWidth = physicalRight.toLong() - physicalLeft
        val physicalHeight = physicalBottom.toLong() - physicalTop
        if (physicalWidth !in 1..Int.MAX_VALUE.toLong() || physicalHeight !in 1..Int.MAX_VALUE.toLong()) return null
        // Layout retains the complete game canvas, including offscreen edges.
        // The parent clips those edges; shrinking the WebView first would make
        // its native scaler fit the whole game back into the visible fraction.
        return GameWebViewLayoutBounds(physicalLeft, physicalTop, physicalWidth.toInt(), physicalHeight.toInt())
    }

    private fun roundedCoordinate(value: Double): Int? {
        if (!value.isFinite() || value < Int.MIN_VALUE.toDouble() || value > Int.MAX_VALUE.toDouble()) {
            return null
        }
        return value.roundToInt()
    }
}

data class GameWebViewLayoutBounds(val left: Int, val top: Int, val width: Int, val height: Int)

class PhysicalBounds internal constructor(
    val left: Int,
    val top: Int,
    val right: Int,
    val bottom: Int,
) {
    init {
        require(left >= 0)
        require(top >= 0)
        require(right > left)
        require(bottom > top)
        require(right.toLong() - left.toLong() <= Int.MAX_VALUE.toLong())
        require(bottom.toLong() - top.toLong() <= Int.MAX_VALUE.toLong())
    }

    val width: Int
        get() = (right.toLong() - left.toLong()).toInt()

    val height: Int
        get() = (bottom.toLong() - top.toLong()).toInt()

    override fun equals(other: Any?): Boolean =
        other is PhysicalBounds &&
            left == other.left &&
            top == other.top &&
            right == other.right &&
            bottom == other.bottom

    override fun hashCode(): Int {
        var result = left
        result = 31 * result + top
        result = 31 * result + right
        return 31 * result + bottom
    }

    override fun toString(): String = "PhysicalBounds(left=$left, top=$top, right=$right, bottom=$bottom)"
}
