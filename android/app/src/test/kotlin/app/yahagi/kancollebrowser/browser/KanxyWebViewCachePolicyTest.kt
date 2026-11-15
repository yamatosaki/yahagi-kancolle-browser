package app.yahagi.kancollebrowser.browser

import java.net.InetSocketAddress
import java.net.Proxy
import org.junit.Assert.assertEquals
import org.junit.Test

class KanxyWebViewCachePolicyTest {
    @Test
    fun clearsStaleMemoryBeforeFirstLoadWithFreshResources() {
        val view = View()
        val actions = mutableListOf<String>()
        val policy = policy(actions)

        policy.update(view, null)
        policy.update(view, null)

        assertEquals(listOf("mode:2", "clear:2"), actions)
        assertEquals(2, view.cacheMode)
    }

    @Test
    fun invalidatesOnlyWhenTheEffectiveRouteChangesWhileFresh() {
        val view = View()
        val actions = mutableListOf<String>()
        val policy = policy(actions)
        val http = KanxyResourceRoute(Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved("localhost", 7410)))
        val vpn = KanxyResourceRoute(null)
        val renewedVpn = KanxyResourceRoute(null)

        policy.update(view, null)
        policy.update(view, http)
        policy.update(view, http)
        policy.update(view, vpn)
        policy.update(view, renewedVpn)
        policy.update(view, renewedVpn)

        assertEquals(listOf("mode:2", "clear:2", "clear:2", "clear:2", "clear:2"), actions)
    }

    @Test
    fun replacementViewClearsSharedMemoryAndPreviousViewRegainsItsMode() {
        val first = View()
        val second = View(cacheMode = 1)
        val actions = mutableListOf<String>()
        val policy = policy(actions)
        val vpn = KanxyResourceRoute(null)

        policy.update(first, vpn)
        policy.update(second, vpn)
        policy.update(null, null)
        policy.update(null, null)

        assertEquals(listOf("mode:2", "clear:2", "mode:-1", "mode:2", "clear:2", "mode:1"), actions)
        assertEquals(-1, first.cacheMode)
        assertEquals(1, second.cacheMode)
    }

    @Test
    fun teardownPreservesAReplacementCacheMode() {
        val view = View()
        val actions = mutableListOf<String>()
        val policy = policy(actions)
        policy.update(view, null)

        view.cacheMode = 1
        policy.update(null, null)

        assertEquals(listOf("mode:2", "clear:2"), actions)
        assertEquals(1, view.cacheMode)
    }

    private fun policy(actions: MutableList<String>) = KanxyWebViewCachePolicy<View>(
        freshCacheMode = 2,
        readCacheMode = { it.cacheMode },
        writeCacheMode = { view, value ->
            view.cacheMode = value
            actions += "mode:$value"
        },
        clearMemoryCache = { actions += "clear:${it.cacheMode}" },
    )

    private data class View(var cacheMode: Int = -1)
}
