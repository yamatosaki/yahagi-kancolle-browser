package app.yahagi.kancollebrowser.mods

import app.yahagi.kancollebrowser.browser.KanxyResourceRoute
import app.yahagi.kancollebrowser.browser.NativeProxyRouting
import java.io.ByteArrayInputStream
import java.io.IOException
import java.net.Proxy
import java.net.SocketTimeoutException
import java.net.URL
import java.security.cert.Certificate
import javax.net.ssl.HttpsURLConnection
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class KanxyGameCoordinateEndpointTest {
    private val origin = "https://w20h.kancolle-server.com"
    private val stem = "a1b2c3d4e5f6"
    private val virtual = "$origin/__yahagi_mods__/kanxy-coordinates/$stem.json"
    private val upstream = "$origin/kcs/resources/swf/ships/$stem.config"
    private val vpnRoute = KanxyResourceRoute(proxy = null)
    private val httpProxy = NativeProxyRouting.fromUrl("http://127.0.0.1:7410")
    private val coordinates =
        """{"api_mst_shipgraph":{"api_boko_n":[11,-17],"api_unknown":[1,2]},"api_mst_ship":{"api_name":"ignored"}}"""

    @Test
    fun readsOnlyTheExactOfficialAssetAndReturnsValidatedFields() {
        val connection = TestConnection(URL("$upstream.json"), 200, coordinates.toByteArray())
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { vpnRoute }) { url, proxy ->
            assertEquals("$upstream.json", url.toExternalForm())
            assertNull(proxy)
            connection
        }

        val response = endpoint.open(virtual, "GET")!!

        assertEquals(200, response.statusCode)
        assertEquals("""{"api_boko_n":[11,-17]}""", response.readBody())
        assertEquals("no-store", response.headers["Cache-Control"])
        assertEquals("GET", connection.requestMethod)
        assertFalse(connection.instanceFollowRedirects)
        assertFalse(connection.useCaches)
        assertNull(connection.getRequestProperty("Cookie"))
        assertEquals(1_200, connection.connectTimeout)
        assertEquals(1_200, connection.readTimeout)
        assertTrue(connection.disconnected)
    }

    @Test
    fun retriesTheSameJsonAssetThroughTheConfiguredHttpProxy() {
        val assetUrl = URL("$upstream.json")
        val first = TestConnection(assetUrl, 200, responseFailure = SocketTimeoutException())
        val second = TestConnection(assetUrl, 200, coordinates.toByteArray())
        val connections = ArrayDeque(listOf(first, second))
        val requested = mutableListOf<String>()
        val proxies = mutableListOf<Proxy?>()
        val route = KanxyResourceRoute(httpProxy)
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { route }) { url, proxy ->
            requested += url.toExternalForm()
            proxies += proxy
            connections.removeFirst()
        }

        val response = endpoint.open(virtual, "GET")!!

        assertEquals(200, response.statusCode)
        assertEquals("""{"api_boko_n":[11,-17]}""", response.readBody())
        assertEquals(listOf("$upstream.json", "$upstream.json"), requested)
        assertEquals(listOf(httpProxy, httpProxy), proxies)
        assertTrue(first.disconnected)
        assertTrue(second.disconnected)
    }

    @Test
    fun repeatedTimeoutStopsAfterOneRetry() {
        val requested = mutableListOf<String>()
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { vpnRoute }) { url, _ ->
            requested += url.toExternalForm()
            if (requested.size > 2) throw AssertionError("Unexpected additional retry")
            TestConnection(url, 200, responseFailure = SocketTimeoutException())
        }

        assertEquals(404, endpoint.open(virtual, "GET")?.statusCode)
        assertEquals(listOf("$upstream.json", "$upstream.json"), requested)
    }

    @Test
    fun retriesAsIniOnlyAfterAnUpstream404() {
        val requested = mutableListOf<String>()
        val route = KanxyResourceRoute(httpProxy)
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { route }) { url, proxy ->
            assertEquals(httpProxy, proxy)
            requested += url.toExternalForm()
            if (url.path.endsWith(".json")) {
                TestConnection(url, 404)
            } else {
                TestConnection(url, 200, "[graph]\nboko_n_left=24\nboko_n_top=-42".toByteArray())
            }
        }

        val response = endpoint.open(virtual, "GET")!!

        assertEquals(200, response.statusCode)
        assertEquals("""{"api_boko_n":[24,-42]}""", response.readBody())
        assertEquals(listOf("$upstream.json", "$upstream.ini"), requested)
    }

    @Test
    fun handlesAbsentInactiveOrFailedCoordinatesLocally() {
        var route: KanxyResourceRoute? = null
        var requests = 0
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { route }) { url, _ ->
            requests++
            TestConnection(url, 404)
        }

        assertEquals(404, endpoint.open(virtual, "GET")?.statusCode)
        assertEquals(0, requests)
        route = vpnRoute
        assertEquals(404, endpoint.open(virtual, "GET")?.statusCode)
        assertEquals(2, requests)

        val failed = KanxyGameCoordinateEndpoint(currentRoute = { vpnRoute }) { _, _ ->
            throw IOException("unavailable")
        }
        assertEquals(404, failed.open(virtual, "GET")?.statusCode)
    }

    @Test
    fun rejectsRedirectsInvalidCoordinatesAndOversizedResponsesWithoutIniFallback() {
        val responses = listOf(
            302 to byteArrayOf(),
            500 to byteArrayOf(),
            200 to """{"api_mst_shipgraph":{"api_boko_n":[1,"invalid"]}}""".toByteArray(),
            200 to (coordinates + " ".repeat(128 * 1024)).toByteArray(),
        )
        responses.forEach { (status, body) ->
            val requests = mutableListOf<String>()
            val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { vpnRoute }) { url, _ ->
                requests += url.toExternalForm()
                TestConnection(url, status, body)
            }

            assertEquals(404, endpoint.open(virtual, "GET")?.statusCode)
            assertEquals(listOf("$upstream.json"), requests)
        }
    }

    @Test
    fun rejectsResultsIfKanxyDisconnectsDuringTheRequest() {
        var route: KanxyResourceRoute? = KanxyResourceRoute(httpProxy)
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { route }) { url, _ ->
            route = null
            TestConnection(url, 200, coordinates.toByteArray())
        }

        assertEquals(404, endpoint.open(virtual, "GET")?.statusCode)
    }

    @Test
    fun rejectsResultsIfKanxyStopsAndRestartsDuringTheRequest() {
        var route = KanxyResourceRoute(httpProxy)
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { route }) { url, _ ->
            route = KanxyResourceRoute(httpProxy)
            TestConnection(url, 200, coordinates.toByteArray())
        }

        assertEquals(404, endpoint.open(virtual, "GET")?.statusCode)
    }

    @Test
    fun rejectsMalformedVirtualRequestsWithoutOpeningAConnection() {
        val endpoint = KanxyGameCoordinateEndpoint(currentRoute = { vpnRoute }) { _, _ ->
            throw AssertionError("Unexpected upstream request")
        }

        assertEquals(405, endpoint.open(virtual, "POST")?.statusCode)
        assertEquals(400, endpoint.open("$virtual?bad=%", "GET")?.statusCode)
        assertEquals(400, endpoint.open("$virtual#fragment", "GET")?.statusCode)
        assertEquals(404, endpoint.open(virtual.replace(stem, stem.uppercase()), "GET")?.statusCode)
        assertEquals(404, endpoint.open(virtual.replace(stem, "short"), "GET")?.statusCode)
        assertEquals(404, endpoint.open(virtual.replace(stem, "%611b2c3d4e5f6"), "GET")?.statusCode)
        assertNull(endpoint.open("$origin/kcsapi/api_start2/getData", "POST"))
        assertNull(endpoint.open(virtual.replace("w20h.kancolle-server.com", "evil.test"), "GET"))
        assertNull(endpoint.open(virtual.replace(origin, "$origin:444"), "GET"))
        assertNull(endpoint.open(virtual.replace("https://", "http://"), "GET"))
        assertNull(endpoint.open(virtual.replace("https://", "https://user@"), "GET"))
    }

    private fun GameModResponse.readBody(): String =
        inputStream.bufferedReader().use { it.readText() }

    private class TestConnection(
        url: URL,
        private val status: Int,
        private val body: ByteArray = byteArrayOf(),
        private val responseFailure: IOException? = null,
    ) : HttpsURLConnection(url) {
        var disconnected = false
            private set

        override fun getResponseCode(): Int {
            responseFailure?.let { throw it }
            return status
        }
        override fun getInputStream() = ByteArrayInputStream(body)
        override fun disconnect() { disconnected = true }
        override fun connect() = Unit
        override fun usingProxy() = false
        override fun getCipherSuite() = "test"
        override fun getLocalCertificates(): Array<Certificate>? = null
        override fun getServerCertificates(): Array<Certificate> = emptyArray()
    }
}
