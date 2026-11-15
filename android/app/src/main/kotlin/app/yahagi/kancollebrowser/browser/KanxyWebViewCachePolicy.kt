package app.yahagi.kancollebrowser.browser

/** Applies the Kanxy cache override and drops stock resources retained by Blink. */
internal class KanxyWebViewCachePolicy<View : Any>(
    private val freshCacheMode: Int,
    private val readCacheMode: (View) -> Int,
    private val writeCacheMode: (View, Int) -> Unit,
    private val clearMemoryCache: (View) -> Unit,
) {
    private data class Override<View>(
        val view: View,
        val previousMode: Int,
        var route: KanxyResourceRoute?,
    )

    private var active: Override<View>? = null

    /** A target with no verified route still bypasses cache for a configured local proxy. */
    fun update(target: View?, route: KanxyResourceRoute?) {
        val previous = active
        if (previous != null && previous.view === target) {
            if (previous.route !== route) {
                clearMemoryCache(previous.view)
                previous.route = route
            }
            return
        }
        active = null
        if (previous != null) {
            runCatching {
                if (readCacheMode(previous.view) == freshCacheMode) {
                    writeCacheMode(previous.view, previous.previousMode)
                }
            }
        }
        if (target != null) {
            val previousMode = readCacheMode(target)
            writeCacheMode(target, freshCacheMode)
            active = Override(target, previousMode, route)
            clearMemoryCache(target)
        }
    }
}
