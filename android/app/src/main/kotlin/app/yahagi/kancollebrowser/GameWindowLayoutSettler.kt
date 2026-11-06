package app.yahagi.kancollebrowser

/** Quiet-period decisions shared by layout callbacks and the final recheck. */
internal class GameWindowLayoutSettler<G : Any>(private val quietMillis: Long = 200L) {
    data class Decision(val changing: Boolean = false, val stable: Boolean = false, val retryAfterMillis: Long? = null)
    private var candidate: G? = null
    private var changedAt = 0L
    private var waiting = false

    fun observe(geometry: G, nowMillis: Long): Decision {
        if (geometry != candidate) {
            candidate = geometry
            changedAt = nowMillis
            waiting = true
            return Decision(changing = true, retryAfterMillis = quietMillis)
        }
        if (!waiting) return Decision()
        val remaining = quietMillis - (nowMillis - changedAt)
        if (remaining > 0) return Decision(retryAfterMillis = remaining)
        waiting = false
        return Decision(stable = true)
    }
}
