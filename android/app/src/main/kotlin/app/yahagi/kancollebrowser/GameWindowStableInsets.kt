package app.yahagi.kancollebrowser

/** Physical system-bar/cutout insets. IME insets must never enter this value. */
internal data class GameWindowStableInsets(val left: Int, val top: Int, val right: Int, val bottom: Int)

/** Keep both source bars and surface geometry in the quiet-period identity. */
internal data class GameWindowStableInsetsSample(
    val window: GameWindowBounds,
    val sourceInsets: GameWindowStableInsets,
    val view: GameWindowBounds,
) {
    fun toMap(): Map<String, Any> {
        val projected = projectStableInsetsToView(window, sourceInsets, view)
        return mapOf(
            "stableInsets" to mapOf(
                "left" to projected.left,
                "top" to projected.top,
                "right" to projected.right,
                "bottom" to projected.bottom,
            ),
            "insetsViewWidth" to view.width,
            "insetsViewHeight" to view.height,
        )
    }
}

/** Projects window-relative bars into the actual Flutter surface in screen pixels. */
internal fun projectStableInsetsToView(
    window: GameWindowBounds,
    insets: GameWindowStableInsets,
    view: GameWindowBounds,
): GameWindowStableInsets {
    if (window.width <= 0 || window.height <= 0 || view.width <= 0 || view.height <= 0) {
        return GameWindowStableInsets(0, 0, 0, 0)
    }
    // Convert before adding/subtracting: OEM frames can briefly contain stale
    // coordinates, and malformed input must not overflow into a large padding.
    val windowLeft = window.left.toLong()
    val windowTop = window.top.toLong()
    val windowRight = windowLeft + window.width
    val windowBottom = windowTop + window.height
    val viewLeft = view.left.toLong()
    val viewTop = view.top.toLong()
    val viewRight = viewLeft + view.width
    val viewBottom = viewTop + view.height
    val sourceLeft = insets.left.coerceIn(0, window.width)
    val sourceTop = insets.top.coerceIn(0, window.height)
    val sourceRight = insets.right.coerceIn(0, window.width)
    val sourceBottom = insets.bottom.coerceIn(0, window.height)
    fun overlap(source: Int, size: Int, distance: Long): Int =
        if (source == 0) 0 else distance.coerceIn(0L, size.toLong()).toInt()
    val left = overlap(sourceLeft, view.width, windowLeft + sourceLeft - viewLeft)
    val top = overlap(sourceTop, view.height, windowTop + sourceTop - viewTop)
    val right = overlap(sourceRight, view.width - left, viewRight - (windowRight - sourceRight))
    val bottom = overlap(sourceBottom, view.height - top, viewBottom - (windowBottom - sourceBottom))
    return GameWindowStableInsets(left, top, right, bottom)
}
