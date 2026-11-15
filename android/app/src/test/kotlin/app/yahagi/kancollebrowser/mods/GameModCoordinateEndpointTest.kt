package app.yahagi.kancollebrowser.mods

import java.net.URLEncoder
import org.junit.Assert.*
import org.junit.Test

class GameModCoordinateEndpointTest {
    private val origin = "https://w01y.kancolle-server.com"

    @Test fun returnsCurrentSnapshotWithoutTouchingOrdinaryRequests() {
        val endpoint = GameModCoordinateEndpoint({ mapOf("sessionId" to 8, "token" to "active", "ships" to emptyMap<String, Any>()) }) { _, _, _, _ -> fail() }
        val response = endpoint.open("$origin/__yahagi_mods__/coordinates.json", "GET")!!
        assertEquals(200, response.statusCode)
        assertTrue(response.inputStream.bufferedReader().readText().contains("\"sessionId\":8"))
        assertEquals("no-store", response.headers["Cache-Control"])
        assertNull(endpoint.open("$origin/kcsapi/api_start2/getData", "POST"))
        assertNull(endpoint.open("https://example.test/__yahagi_mods__/coordinates.json", "GET"))
        assertNull(endpoint.open("http://w01y.kancolle-server.com/__yahagi_mods__/coordinates.json", "GET"))
        assertNull(endpoint.open("https://w01y.kancolle-server.com:123/__yahagi_mods__/coordinates.json", "GET"))
        assertNull(endpoint.open("https://secret@w01y.kancolle-server.com/__yahagi_mods__/coordinates.json", "GET"))
    }

    @Test fun acceptsOnlyBoundedStructuredReports() {
        val reports = mutableListOf<List<Any?>>()
        val endpoint = GameModCoordinateEndpoint({ null }) { session, token, ids, failure -> reports.add(listOf(session, token, ids, failure)) }
        fun report(payload: String) = endpoint.open("$origin/__yahagi_mods__/coordinates-report?payload=${URLEncoder.encode(payload, "UTF-8")}", "GET")!!
        assertEquals(200, report("""{"sessionId":8,"token":"active","resourceIds":["pack:1"],"failure":null}""").statusCode)
        assertEquals(listOf(8L, "active", listOf("pack:1"), null), reports.single())
        assertEquals(200, report("""{"sessionId":8,"token":"active","resourceIds":["pack:1"],"failure":"coordinate_apply_failed"}""").statusCode)
        for (body in listOf("bad", "{}", """{"sessionId":8.5,"token":"active","resourceIds":["pack:1"]}""",
            """{"sessionId":8,"token":"active","resourceIds":[5]}""",
            """{"sessionId":8,"token":"active","resourceIds":["pack:1"],"failure":"arbitrary"}""")) {
            assertEquals(body, 400, report(body).statusCode)
        }
        assertEquals(2, reports.size)
    }

    @Test fun virtualRoutesFailClosedWhenUnavailableOrMalformed() {
        val endpoint = GameModCoordinateEndpoint({ null }) { _, _, _, _ -> fail() }
        val config = endpoint.open("$origin/__yahagi_mods__/coordinates.json", "GET")!!
        assertEquals(200, config.statusCode)
        assertTrue(config.inputStream.bufferedReader().readText().contains("\"ships\":{}"))
        assertEquals(405, endpoint.open("$origin/__yahagi_mods__/coordinates-report", "POST")!!.statusCode)
        assertEquals(400, endpoint.open("$origin/__yahagi_mods__/coordinates.json?bad=1", "GET")!!.statusCode)
        assertEquals(400, endpoint.open("$origin/__yahagi_mods__/coordinates-report?payload=%", "GET")!!.statusCode)
        assertEquals(400, endpoint.open("$origin/__yahagi_mods__/coordinates-report?payload=${"x".repeat(65_537)}", "GET")!!.statusCode)
    }

    @Test fun kanxyRouteIsAvailableWithoutALocalLibrary() {
        var active = true
        var nameReads = 0
        val endpoint = GameModCoordinateEndpoint(
            snapshot = { null },
            kanxyActive = { active },
            stockShipNames = { nameReads++; mapOf("623" to "Stock 623") },
        ) { _, _, _, _ -> fail() }
        fun config() = endpoint.open("$origin/__yahagi_mods__/coordinates.json", "GET")!!
            .inputStream.bufferedReader().use { it.readText() }
        val activeConfig = config()
        assertTrue(activeConfig.contains("\"kanxy\":true"))
        assertTrue(activeConfig.contains("\"ships\":{}"))
        assertTrue(activeConfig.contains("\"stockShipNames\":{\"623\":\"Stock 623\"}"))
        active = false
        val inactiveConfig = config()
        assertFalse(inactiveConfig.contains("\"kanxy\""))
        assertFalse(inactiveConfig.contains("\"stockShipNames\""))
        assertEquals(1, nameReads)
    }
}
