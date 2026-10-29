package app.yahagi.kancollebrowser.browser

import org.junit.Assert.*
import org.junit.Test
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL
import java.net.URLConnection
import java.net.URLStreamHandler

class NativeProxyRoutingTest {
    @Test fun `proxy hostnames remain unresolved until a network worker connects`() {
        for (scheme in listOf("http", "socks")) {
            val proxy = NativeProxyRouting.fromUrl("$scheme://localhost:8099")
            val address = proxy.address() as InetSocketAddress
            assertTrue("Preparing a hostname proxy must not perform DNS", address.isUnresolved)
            assertEquals("localhost", address.hostString)
            assertEquals(8099, address.port)
        }
    }

    @Test fun `system routing delegates to the URL handler default proxy selection`() {
        val handler = RecordingHandler()
        val url = URL(null, "https://game.example/resource.png", handler)
        assertNotNull(NativeProxyRouting.openConnection(url, null))
        assertEquals(1, handler.systemCalls)
        assertEquals(0, handler.explicitCalls)
    }

    @Test fun `explicit proxy routing preserves the chosen proxy`() {
        val handler = RecordingHandler()
        val url = URL(null, "https://game.example/resource.png", handler)
        val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved("proxy.example", 8080))
        NativeProxyRouting.openConnection(url, proxy)
        assertEquals(0, handler.systemCalls)
        assertEquals(1, handler.explicitCalls)
        assertEquals(proxy, handler.lastProxy)
    }

    @Test fun `explicit direct routing is distinct from system routing`() {
        val handler = RecordingHandler()
        NativeProxyRouting.openConnection(URL(null, "https://game.example/", handler), Proxy.NO_PROXY)
        assertEquals(0, handler.systemCalls)
        assertSame(Proxy.NO_PROXY, handler.lastProxy)
    }

    @Test fun `proxy address preparation preserves protocol and literal addresses`() {
        for ((url, type, host) in listOf(
            Triple("http://127.0.0.1:8080", Proxy.Type.HTTP, "127.0.0.1"),
            Triple("socks://[::1]:1080", Proxy.Type.SOCKS, "::1"),
        )) {
            val proxy = NativeProxyRouting.fromUrl(url)
            val address = proxy.address() as InetSocketAddress
            assertEquals(type, proxy.type())
            assertEquals(host, address.hostString)
        }
    }

    @Test fun `invalid proxy addresses fail during preparation`() {
        for (url in listOf("http://:8080", "http://localhost:0", "http://localhost:65536", "ftp://localhost:8080")) {
            try {
                NativeProxyRouting.fromUrl(url)
                fail("Invalid proxy was accepted: $url")
            } catch (_: IllegalArgumentException) {
                // A caller can reject the request before changing WebView's proxy.
            }
        }
    }

    private class RecordingHandler : URLStreamHandler() {
        var systemCalls = 0
        var explicitCalls = 0
        var lastProxy: Proxy? = null
        override fun openConnection(url: URL): URLConnection {
            systemCalls++
            return connection(url)
        }
        override fun openConnection(url: URL, proxy: Proxy): URLConnection {
            explicitCalls++
            lastProxy = proxy
            return connection(url)
        }
        private fun connection(url: URL) = object : HttpURLConnection(url) {
            override fun connect() = Unit
            override fun disconnect() = Unit
            override fun usingProxy() = false
        }
    }
}
