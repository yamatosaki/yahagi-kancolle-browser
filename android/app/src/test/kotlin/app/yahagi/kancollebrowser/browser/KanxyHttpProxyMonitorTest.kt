package app.yahagi.kancollebrowser.browser

import app.yahagi.kancollebrowser.diagnostics.KanxyDiagnosticStatus
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.async
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.InetSocketAddress
import java.net.InetAddress
import java.net.Proxy
import java.net.ServerSocket
import java.net.SocketTimeoutException
import java.security.cert.CertPathValidatorException
import javax.net.ssl.SSLHandshakeException
import javax.net.ssl.SSLPeerUnverifiedException

class KanxyHttpProxyMonitorTest {
    @Test
    fun acceptsTheObservedKanxyIssuerWithAdditionalAttributes() {
        assertTrue(isKanxyCertificateIssuer("CN=Kanxy Local CA,O=Kanxy,C=CN"))
        assertTrue(isKanxyCertificateIssuer("CN=Kanxy Local CA"))
        assertFalse(isKanxyCertificateIssuer("CN=Kanxy Local CA clone,O=Other"))
    }

    @Test
    fun distinguishesUntrustedTlsFromTunnelFailures() {
        val untrusted = SSLHandshakeException("test").apply {
            initCause(CertPathValidatorException("test"))
        }
        assertEquals(KanxyDiagnosticStatus.HTTP_TLS_UNTRUSTED, classifyKanxyHttpsFailure(untrusted))
        assertEquals(KanxyDiagnosticStatus.HTTP_TLS_UNTRUSTED,
            classifyKanxyHttpsFailure(SSLPeerUnverifiedException("test")))
        assertEquals(KanxyDiagnosticStatus.HTTP_TUNNEL_FAILED,
            classifyKanxyHttpsFailure(SSLHandshakeException("test")))
        assertEquals(KanxyDiagnosticStatus.HTTP_TUNNEL_FAILED,
            classifyKanxyHttpsFailure(SocketTimeoutException("test")))
    }

    @Test
    fun reportsHttpProbeFailuresByStageWithoutActivatingTheRoute() = runBlocking {
        val statuses = mutableListOf<KanxyDiagnosticStatus>()
        val route = http("127.0.0.1")
        var installed = false
        var listening = false
        var identity = KanxyDiagnosticStatus.HTTP_TLS_UNTRUSTED
        val monitor = KanxyHttpProxyMonitor(
            this, { installed }, { error("Unexpected route change") },
            probeListening = { listening },
            probeIdentity = { identity },
            onDiagnostic = { statuses += it },
        )
        try {
            monitor.setProxy(route)
            installed = true
            monitor.setProxy(route)
            listening = true
            monitor.setProxy(route)
            identity = KanxyDiagnosticStatus.HTTP_CA_MISMATCH
            monitor.setProxy(route)
            assertEquals(listOf(
                KanxyDiagnosticStatus.HTTP_PACKAGE_UNRECOGNIZED,
                KanxyDiagnosticStatus.HTTP_LISTENER_UNAVAILABLE,
                KanxyDiagnosticStatus.HTTP_TLS_UNTRUSTED,
                KanxyDiagnosticStatus.HTTP_CA_MISMATCH,
            ), statuses)
            assertEquals(KanxyDiagnosticStatus.HTTP_CA_MISMATCH, monitor.diagnosticStatus)
            monitor.setProxy(http("example.org"))
            assertNull(monitor.diagnosticStatus)
        } finally {
            monitor.stop()
        }
    }

    @Test
    fun ignoresOtherProxyTypesAndHosts() = runBlocking {
        val probes = mutableListOf<Proxy>()
        val monitor = KanxyHttpProxyMonitor(
            this, { true }, { error("Unexpected route change") },
            probeListening = { probes += it; true },
            probeIdentity = { error("Unexpected identity probe") },
        )
        try {
            monitor.setProxy(http("example.org"))
            monitor.setProxy(http("localhost.example.org"))
            monitor.setProxy(Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", 8888)))
            monitor.setProxy(Proxy.NO_PROXY)
            assertTrue(probes.isEmpty())
        } finally {
            monitor.stop()
        }
    }

    @Test
    fun activatesOnlyAfterIdentifyingTheProxyAndReidentifiesAfterLoss() = runBlocking {
        val changes = Channel<Proxy?>(Channel.UNLIMITED)
        val route = http("::1", 8833)
        var listening = true
        var identified = false
        val identities = mutableListOf<Proxy>()
        val statuses = mutableListOf<KanxyDiagnosticStatus>()
        val monitor = KanxyHttpProxyMonitor(
            this, { true }, { changes.trySend(it) },
            probeListening = { listening },
            probeIdentity = {
                identities += it
                if (identified) KanxyDiagnosticStatus.HTTP_VERIFIED else KanxyDiagnosticStatus.HTTP_TUNNEL_FAILED
            },
            pollIntervalMillis = 5,
            onDiagnostic = { statuses += it },
        )
        try {
            monitor.setProxy(route)
            assertEquals(listOf(route), identities)
            assertTrue(changes.tryReceive().isFailure)

            identified = true
            assertEquals(route, withTimeout(2_000) { changes.receive() })
            listening = false
            assertNull(withTimeout(2_000) { changes.receive() })

            listening = true
            assertEquals(route, withTimeout(2_000) { changes.receive() })
            assertEquals(listOf(route, route, route), identities)
            assertEquals(listOf(
                KanxyDiagnosticStatus.HTTP_TUNNEL_FAILED,
                KanxyDiagnosticStatus.HTTP_VERIFIED,
                KanxyDiagnosticStatus.HTTP_LISTENER_UNAVAILABLE,
                KanxyDiagnosticStatus.HTTP_VERIFIED,
            ), statuses)
        } finally {
            monitor.stop()
            changes.close()
        }
    }

    @Test
    fun replacementCannotPublishAnInFlightResultForTheOldRoute() = runBlocking {
        val first = http("localhost", 7410)
        val second = http("127.0.0.1", 8821)
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val changes = mutableListOf<Proxy?>()
        val monitor = KanxyHttpProxyMonitor(
            this, { true }, { changes += it },
            probeListening = { true },
            probeIdentity = { route ->
                if (route == first) {
                    entered.complete(Unit)
                    withContext(NonCancellable) { release.await() }
                }
                KanxyDiagnosticStatus.HTTP_VERIFIED
            },
        )
        try {
            val applyingFirst = async { monitor.setProxy(first) }
            withTimeout(2_000) { entered.await() }
            monitor.setProxy(second)
            release.complete(Unit)
            withTimeout(2_000) { applyingFirst.await() }
            monitor.setProxy(null)
            assertEquals(listOf(second, null), changes)
        } finally {
            release.complete(Unit)
            monitor.stop()
        }
    }

    @Test
    fun tcpAcceptAloneDoesNotActivateKanxy() = runBlocking {
        ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { server ->
            server.soTimeout = 2_000
            val accepted = async(Dispatchers.IO) {
                server.accept().use { socket ->
                    socket.soTimeout = 2_000
                    socket.getInputStream().bufferedReader(Charsets.US_ASCII).readLine()
                }
            }
            val monitor = KanxyHttpProxyMonitor(
                this, { true }, { error("Unexpected route change") },
                probeIdentity = { error("A TCP connection is not a proxy response") },
            )
            try {
                monitor.setProxy(http("127.0.0.1", server.localPort))
                assertEquals("GET / HTTP/1.1", withTimeout(2_000) { accepted.await() })
            } finally {
                monitor.stop()
            }
        }
    }

    private fun http(host: String, port: Int = 7410): Proxy =
        Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved(host, port))
}
