package app.yahagi.kancollebrowser.browser

/** Owns callers while a fit is pending; completed fits are never cached. */
internal class FixedCanvasFitRequests<K> {
    class Request<K>(val key: K) {
        internal class Caller(val isCurrent: () -> Boolean, val onComplete: (Result<Boolean>) -> Unit)
        internal val callers = mutableListOf<Caller>()
        internal var completed = false
        var onFinish: (() -> Unit)? = null
    }

    private var active: Request<K>? = null

    fun begin(key: K, isCurrent: () -> Boolean, onComplete: (Result<Boolean>) -> Unit): Request<K> {
        val existing = active
        val request = if (existing != null && existing.key == key && this.isCurrent(existing)) {
            existing
        } else {
            cancel()
            Request(key).also { active = it }
        }
        request.callers += Request.Caller(isCurrent, onComplete)
        return request
    }

    fun isCurrent(request: Request<K>): Boolean = active === request && !request.completed &&
        request.callers.any { caller ->
            try {
                caller.isCurrent()
            } catch (_: RuntimeException) {
                false
            }
        }

    fun finish(request: Request<K>, outcome: Result<Boolean>) {
        if (request.completed) return
        request.completed = true
        if (active === request) active = null
        val cleanup = request.onFinish
        request.onFinish = null
        val callers = request.callers.toList()
        request.callers.clear()
        try {
            cleanup?.invoke()
        } catch (_: RuntimeException) {
            // Cleanup failure must not strand callers awaiting this result.
        }
        callers.forEach { caller ->
            val callerOutcome = try {
                if (outcome.getOrNull() == true && !caller.isCurrent()) Result.success(false) else outcome
            } catch (error: RuntimeException) {
                Result.failure(error)
            }
            try {
                caller.onComplete(callerOutcome)
            } catch (_: RuntimeException) {
                // Each callback owns its failure; continue delivering to others.
            }
        }
    }

    fun cancel() {
        active?.let { finish(it, Result.success(false)) }
    }
}
