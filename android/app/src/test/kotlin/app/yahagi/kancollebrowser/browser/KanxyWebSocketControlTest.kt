package app.yahagi.kancollebrowser.browser

import app.yahagi.kancollebrowser.diagnostics.KanxyDiagnosticStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class KanxyWebSocketControlTest {
    @Test
    fun acceptsOnlyHttpsWorldOriginsOnDefaultPort() {
        val origin = "https://w00g.kancolle-server.com"
        assertTrue(KanxyWebSocketControl.acceptsOrigin(origin))
        assertTrue(KanxyWebSocketControl.acceptsOrigin("$origin:443/"))
        listOf(
            "http://w00g.kancolle-server.com",
            "https://w00g.kancolle-server.com:444",
            "https://w00g.kancolle-server.com/path",
            "https://w00g.kancolle-server.com.example",
            "https://extra.w00g.kancolle-server.com",
            "https://other.kancolle-server.com",
            "https://kancolle-server.com",
            "https://w00g.kancolle-server.com@localhost",
        ).forEach { assertFalse(it, KanxyWebSocketControl.acceptsOrigin(it)) }
    }

    @Test
    fun admitsOnlyFixedSocketDiagnostics() {
        for (status in listOf(
            KanxyDiagnosticStatus.WS_REQUESTED,
            KanxyDiagnosticStatus.WS_OPEN,
            KanxyDiagnosticStatus.WS_SPH_RECEIVED,
            KanxyDiagnosticStatus.WS_CONNECTION_CLOSED,
            KanxyDiagnosticStatus.WS_TRANSPORT_FAILED,
            KanxyDiagnosticStatus.WS_ROUTE_CLOSED,
        )) {
            assertEquals(status, KanxyWebSocketControl.diagnostic(status.name))
        }
        for (message in listOf("ready", "retired", "ROUTE_HTTP", "WS_OPEN:localhost", """{"SPH":1}""")) {
            assertNull(message, KanxyWebSocketControl.diagnostic(message))
        }
    }
}
