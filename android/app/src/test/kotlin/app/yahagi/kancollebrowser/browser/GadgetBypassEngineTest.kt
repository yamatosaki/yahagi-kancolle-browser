package app.yahagi.kancollebrowser.browser

import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class GadgetBypassEngineTest {
    private lateinit var server: TestHttpServer
    private lateinit var tempDir: File

    @Before
    fun setUp() {
        server = TestHttpServer()
        server.start()
        tempDir = Files.createTempDirectory("gadget-engine-test").toFile()
    }

    @After
    fun tearDown() {
        server.stop()
    }

    private fun baseUrl() = "http://127.0.0.1:${server.port}"

    private fun installEndpointHandler(bytes: ByteArray, status: Int = 200) {
        server.handlers["/endpoint"] = Pair({ bytes }, status)
    }

    private fun installDirectHandler(bytes: ByteArray, status: Int = 200) {
        server.handlers["/gadget_html5"] = Pair({ bytes }, status)
    }

    private fun engine(
        cache: GadgetBypassCache = GadgetBypassCache(tempDir, now = { 1000L }),
        endpointValidator: (String) -> Boolean = { true },
    ) = GadgetBypassEngine(
        cache = cache,
        connectTimeoutMs = 3000,
        readTimeoutMs = 3000,
        endpointValidator = endpointValidator,
    )

    private fun originalUrl(path: String = "/gadget_html5/js/kcs_cda.js") =
        "http://w00g.kancolle-server.com$path"

    @Test
    fun fetchesFromEndpointWhenItSucceeds() {
        val content = "window.__gadget = true;".toByteArray(StandardCharsets.UTF_8)
        installEndpointHandler(content)
        val result = engine().fetch(
            originalUrl = originalUrl(),
            endpoint = "${baseUrl()}/endpoint",
        )
        assertArrayEquals(content, result)
        assertEquals(1, server.hits["/endpoint"])
        assertNull(server.hits["/gadget_html5"])
    }

    @Test
    fun returnsNullForWebViewFallbackWhenEndpointFails() {
        installEndpointHandler(ByteArray(0), status = 500)
        val result = engine().fetch(
            originalUrl = originalUrl(),
            endpoint = "${baseUrl()}/endpoint",
        )
        assertNull(result)
        assertEquals(1, server.hits["/endpoint"])
        assertNull(server.hits["/gadget_html5"])
    }

    @Test
    fun returnsNullWhenBothSourcesFail() {
        installEndpointHandler(ByteArray(0), status = 404)
        installDirectHandler(ByteArray(0), status = 500)
        assertNull(
            engine().fetch(
                originalUrl = originalUrl(),
                endpoint = "${baseUrl()}/endpoint",
            ),
        )
    }

    @Test
    fun servesSecondCallFromCacheWithoutHittingNetwork() {
        val content = "cached content".toByteArray(StandardCharsets.UTF_8)
        installEndpointHandler(content)
        val engine = engine()
        val url = originalUrl()
        val endpoint = "${baseUrl()}/endpoint"
        assertArrayEquals(content, engine.fetch(url, endpoint))
        assertArrayEquals(content, engine.fetch(url, endpoint))
        assertEquals(1, server.hits["/endpoint"])
    }

    @Test
    fun isolatesCachedFilesByEndpoint() {
        server.handlers["/endpoint-a"] = Pair({ "from-a".toByteArray() }, 200)
        server.handlers["/endpoint-b"] = Pair({ "from-b".toByteArray() }, 200)
        val engine = engine()
        val url = originalUrl()

        assertArrayEquals(
            "from-a".toByteArray(),
            engine.fetch(url, "${baseUrl()}/endpoint-a"),
        )
        assertArrayEquals(
            "from-b".toByteArray(),
            engine.fetch(url, "${baseUrl()}/endpoint-b"),
        )
        assertEquals(1, server.hits["/endpoint-a"])
        assertEquals(1, server.hits["/endpoint-b"])
    }

    @Test
    fun ignoresRequestsOutsideBypassRules() {
        installEndpointHandler(ByteArray(0))
        assertNull(
            engine().fetch(
                originalUrl = "http://203.104.209.7/kcsapi/api_start2/getData",
                endpoint = "${baseUrl()}/endpoint",
            ),
        )
        assertNull(server.hits["/endpoint"])
    }
}
