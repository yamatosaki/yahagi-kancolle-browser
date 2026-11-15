package app.yahagi.kancollebrowser.browser

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WebViewProxyRoutesTest {
    @Test
    fun kanxyUsesSystemAndRestoresTheLatestSavedProxyOnDisconnect() = runBlocking {
        val overrides = mutableListOf<String?>()
        val routes = WebViewProxyRoutes(this, { true }, { url, done ->
            overrides += url
            done.run()
        })
        val initial = "http://first.example:8099"
        val edited = "socks://second.example:1080"

        assertEquals(WebViewProxyRoutes.Result.APPLIED, routes.configure(initial))
        assertEquals(NativeProxyRouting.fromUrl(initial), routes.currentNativeProxy())
        assertTrue(routes.setKanxyActive(true))
        assertNull(routes.currentNativeProxy())
        assertEquals(WebViewProxyRoutes.Result.APPLIED, routes.configure(edited))
        assertEquals(listOf(initial, null), overrides)
        assertTrue(routes.setKanxyActive(false))
        assertEquals(listOf(initial, null, edited), overrides)
        assertEquals(NativeProxyRouting.fromUrl(edited), routes.currentNativeProxy())
    }

    @Test
    fun savedProxySetupWaitsForTheInitialKanxyClear() = runBlocking {
        val requested = mutableListOf<String?>()
        val clear = CompletableDeferred<Runnable>()
        val routes = WebViewProxyRoutes(this, { true }, { url, done ->
            requested += url
            if (url == null) clear.complete(done) else done.run()
        })
        val configured = "http://first.example:8099"

        val vpn = async(start = CoroutineStart.UNDISPATCHED) { routes.setKanxyActive(true) }
        val setup = async(start = CoroutineStart.UNDISPATCHED) { routes.configure(configured) }
        assertFalse(setup.isCompleted)
        assertEquals(listOf<String?>(null), requested)

        clear.await().run()
        assertTrue(vpn.await())
        assertEquals(WebViewProxyRoutes.Result.APPLIED, setup.await())
        assertNull(routes.currentNativeProxy())
        assertTrue(routes.setKanxyActive(false))
        assertEquals(listOf(null, configured), requested)
        assertEquals(NativeProxyRouting.fromUrl(configured), routes.currentNativeProxy())
    }

    @Test
    fun kanxyClearsASetupOverrideOnlyAfterItsLateCallback() = runBlocking {
        val requested = mutableListOf<String?>()
        val first = CompletableDeferred<Runnable>()
        val clearing = CompletableDeferred<Runnable>()
        val routes = WebViewProxyRoutes(this, { true }, { url, done ->
            requested += url
            if (url == null) clearing.complete(done) else first.complete(done)
        }, timeoutMs = 100)
        val configured = "http://first.example:8099"

        assertEquals(WebViewProxyRoutes.Result.TIMEOUT, routes.configure(configured))
        val vpn = async(start = CoroutineStart.UNDISPATCHED) { routes.setKanxyActive(true) }
        assertEquals(listOf(configured), requested)
        assertNull(routes.currentNativeProxy())
        assertFalse(clearing.isCompleted)

        first.await().run()
        withTimeout(1_000) { clearing.await() }.run()
        assertTrue(vpn.await())
        assertEquals(listOf(configured, null), requested)
        assertTrue(routes.setKanxyActive(false))
        assertNull(routes.currentNativeProxy())
    }
}
