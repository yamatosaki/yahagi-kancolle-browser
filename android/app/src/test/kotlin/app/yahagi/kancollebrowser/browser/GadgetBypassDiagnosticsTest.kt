package app.yahagi.kancollebrowser.browser

import java.net.ServerSocket
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class GadgetBypassDiagnosticsTest {
    private lateinit var server: TestHttpServer

    @Before
    fun setUp() {
        server = TestHttpServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.stop()
    }

    private fun baseUrl() = "http://127.0.0.1:${server.port}"

    @Test
    fun probeReportsSuccessFor200() {
        server.handlers["/ok"] = Pair({ byteArrayOf(1) }, 200)
        val result = GadgetBypassDiagnostics.probe("${baseUrl()}/ok", 2000, 2000)
        assertTrue(result.reachable)
        assertEquals(200, result.statusCode)
        assertNull(result.error)
    }

    @Test
    fun probeTreatsAnyHttpStatusAsReachable() {
        server.handlers["/denied"] = Pair({ ByteArray(0) }, 403)
        server.handlers["/broken"] = Pair({ ByteArray(0) }, 500)
        assertTrue(GadgetBypassDiagnostics.probe("${baseUrl()}/denied", 2000, 2000).reachable)
        assertTrue(GadgetBypassDiagnostics.probe("${baseUrl()}/broken", 2000, 2000).reachable)
    }

    @Test
    fun probeClassifies403AsGadgetServerBlocked() {
        server.handlers["/denied"] = Pair({ ByteArray(0) }, 403)
        val result = GadgetBypassDiagnostics.probe("${baseUrl()}/denied", 2000, 2000)
        assertTrue(result.reachable)
        assertTrue(result.blocked)
        assertFalse(result.successful)
    }

    @Test
    fun probeReportsUnreachableOnConnectionRefused() {
        val closedPort = ServerSocket(0).use { it.localPort }
        val result = GadgetBypassDiagnostics.probe(
            "http://127.0.0.1:$closedPort/x",
            1000,
            1000,
        )
        assertFalse(result.reachable)
        assertNull(result.statusCode)
        assertNotNull(result.error)
    }

    @Test
    fun probeReportsUnreachableOnTimeout() {
        server.hang = true
        val result = GadgetBypassDiagnostics.probe("${baseUrl()}/hang", 1000, 600)
        assertFalse(result.reachable)
        assertTrue(result.elapsedMs >= 500)
    }

    @Test
    fun endpointGadgetUrlRewritesThroughTheRules() {
        assertEquals(
            "https://kcwiki.github.io/cache/gadget_html5/js/kcs_const.js",
            GadgetBypassDiagnostics.endpointGadgetUrl("https://kcwiki.github.io/cache/"),
        )
    }
}
