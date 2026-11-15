package app.yahagi.kancollebrowser.browser

import java.net.Proxy
import java.util.concurrent.atomic.AtomicInteger

/** Identity of the current Kanxy resource route. A null proxy uses the system VPN. */
internal class KanxyResourceRoute(val proxy: Proxy?)

/** Main-thread state for game refreshes after the VPN or HTTP route changes. */
internal class KanxyGameRouteState {
    data class Route(val active: Boolean, val generation: Int)
    data class Change(val previous: Boolean, val route: Route, val renewed: Boolean = false)

    private var observed: Route? = null
    private var reconciling: Route? = null
    private var ready: Route? = null
    private var published: Route? = null
    private var http: Route? = null

    fun observe(active: Boolean, renewActive: Boolean = false) {
        if (observed?.active == active && !(active && renewActive)) return
        if (active) http = null
        observed = Route(active, generations.incrementAndGet())
    }

    fun beginReconcile(): Route? = observed
        ?.takeUnless { it === reconciling || it === ready }
        ?.also { reconciling = it }

    fun finishReconcile(route: Route, success: Boolean): Change? {
        if (reconciling === route) reconciling = null
        if (observed !== route || !success) return null
        ready = route
        val previous = published
        if (!route.active && previous?.active == false) return null
        published = route
        if (!route.active && previous == null) return null
        val previousActive = previous?.active ?: route.active
        return Change(previousActive, route, renewed = previousActive == route.active)
    }

    fun observeHttp(active: Boolean): Change {
        val route = Route(active, generations.incrementAndGet())
        http = route
        return Change(!active, route)
    }

    fun canReload(generation: Int, httpSelected: Boolean = false): Boolean {
        if (httpSelected) return http?.let { it.active && it.generation == generation } == true
        return published?.generation == generation &&
            ready === observed && ready?.active == published?.active
    }

    private companion object {
        val generations = AtomicInteger()
    }
}
