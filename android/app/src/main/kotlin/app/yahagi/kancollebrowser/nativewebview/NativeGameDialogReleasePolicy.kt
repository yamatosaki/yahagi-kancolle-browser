package app.yahagi.kancollebrowser.nativewebview

/** Chooses the post-gesture quiet delay without depending on Android's clock. */
internal class NativeGameDialogReleasePolicy(private val nowMs: () -> Long) {
    private var bounded = false
    private var postTouchProtection = true
    private var deadlineMs: Long? = null

    fun begin(surfaceDialog: Boolean, postTouchProtection: Boolean = true) {
        bounded = surfaceDialog
        this.postTouchProtection = postTouchProtection
        deadlineMs = null
    }

    /** Called only after all current pointers are up or cancelled. */
    fun nextDelayMillis(): Long {
        if (!postTouchProtection) return 0L
        if (!bounded) return QUIET_MILLIS
        val now = nowMs()
        // A long original closing gesture must still get its full quiet interval.
        val deadline = deadlineMs ?: (now + MAX_SURFACE_PROTECTION_MILLIS).also { deadlineMs = it }
        return minOf(QUIET_MILLIS, (deadline - now).coerceAtLeast(0L))
    }

    fun clear() {
        bounded = false
        postTouchProtection = true
        deadlineMs = null
    }

    companion object {
        const val QUIET_MILLIS = 600L
        const val MAX_SURFACE_PROTECTION_MILLIS = 2000L
    }
}
