package app.yahagi.kancollebrowser.browser

import app.yahagi.kancollebrowser.diagnostics.KanxyDiagnosticStatus
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.net.URL
import java.security.cert.CertPathValidatorException
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLPeerUnverifiedException

internal fun isKanxyCertificateIssuer(distinguishedName: String): Boolean =
    distinguishedName.substringBefore(',') == "CN=Kanxy Local CA"

internal fun classifyKanxyHttpsFailure(error: IOException): KanxyDiagnosticStatus {
    val certificateFailure = generateSequence<Throwable>(error) { it.cause }.take(8).any {
        it is SSLPeerUnverifiedException || it is CertificateException || it is CertPathValidatorException
    }
    return if (certificateFailure) KanxyDiagnosticStatus.HTTP_TLS_UNTRUSTED
        else KanxyDiagnosticStatus.HTTP_TUNNEL_FAILED
}

internal fun isLoopbackHttpProxy(proxy: Proxy?): Boolean {
    if (proxy?.type() != Proxy.Type.HTTP) return false
    val address = proxy.address() as? InetSocketAddress ?: return false
    return address.port in 1..65535 &&
        address.hostString.removeSurrounding("[", "]").lowercase() in loopbackProxyHosts &&
        address.address?.isLoopbackAddress != false
}

private val loopbackProxyHosts = setOf("127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1")

/** Main-confined state for the user-selected HTTP proxy and its Kanxy listener. */
internal class KanxyHttpProxyMonitor(
    private val scope: CoroutineScope,
    private val isKanxyInstalled: () -> Boolean,
    private val onChanged: (Proxy?) -> Unit,
    private val probeListening: suspend (Proxy) -> Boolean = { proxy ->
        withContext(Dispatchers.IO) { respondsAsHttpProxy(proxy) }
    },
    private val probeIdentity: suspend (Proxy) -> KanxyDiagnosticStatus = { proxy ->
        withContext(Dispatchers.IO) { identifyHttpProxy(proxy) }
    },
    private val pollIntervalMillis: Long = 2_000,
    private val onDiagnostic: (KanxyDiagnosticStatus) -> Unit = {},
) {
    private var configured: Proxy? = null
    private var active: Proxy? = null
    private var firstSample: CompletableDeferred<Unit>? = null
    private var job: Job? = null
    var diagnosticStatus: KanxyDiagnosticStatus? = null
        private set

    /** Gives a newly applied proxy a bounded head start before the game loads. */
    suspend fun setProxy(proxy: Proxy?) {
        val candidate = proxy?.takeIf(::isLoopbackHttpProxy)
        val retryNow = candidate != null && active != candidate && firstSample?.isCompleted == true
        if (configured != candidate || retryNow) {
            stop()
            configured = candidate
            if (candidate != null) {
                val sample = CompletableDeferred<Unit>()
                firstSample = sample
                job = scope.launch {
                    try {
                        var misses = 0
                        while (true) {
                            val installed = isKanxyInstalled()
                            val listening = installed && probeListening(candidate)
                            val status = when {
                                !installed -> KanxyDiagnosticStatus.HTTP_PACKAGE_UNRECOGNIZED
                                !listening -> KanxyDiagnosticStatus.HTTP_LISTENER_UNAVAILABLE
                                active == candidate -> KanxyDiagnosticStatus.HTTP_VERIFIED
                                else -> probeIdentity(candidate)
                            }
                            val identified = status == KanxyDiagnosticStatus.HTTP_VERIFIED
                            ensureActive()
                            if (diagnosticStatus != status) {
                                diagnosticStatus = status
                                runCatching { onDiagnostic(status) }
                            }
                            if (identified) {
                                misses = 0
                                publish(candidate)
                            } else if (!installed || ++misses >= MISSES_BEFORE_LOSS) {
                                publish(null)
                            }
                            sample.complete(Unit)
                            val retryDelay = if (listening && !identified) {
                                pollIntervalMillis * 4
                            } else {
                                pollIntervalMillis
                            }
                            delay(retryDelay)
                        }
                    } finally {
                        sample.complete(Unit)
                    }
                }
            }
        }
        val sample = firstSample ?: return
        withTimeoutOrNull(INITIAL_WAIT_MS) { sample.await() }
    }

    fun stop() {
        job?.cancel()
        job = null
        firstSample?.complete(Unit)
        firstSample = null
        configured = null
        diagnosticStatus = null
        publish(null)
    }

    private fun publish(proxy: Proxy?) {
        if (active == proxy) return
        active = proxy
        onChanged(proxy)
    }

    private companion object {
        const val INITIAL_WAIT_MS = 4_000L
        const val LOCAL_TIMEOUT_MS = 500
        const val HTTPS_TIMEOUT_MS = 1_500
        const val MISSES_BEFORE_LOSS = 2

        val statusLine = "HTTP/1.1 400 Bad Request\r\n".toByteArray(Charsets.US_ASCII)
        val localRequest = "GET / HTTP/1.1\r\n\r\n".toByteArray(Charsets.US_ASCII)

        fun respondsAsHttpProxy(proxy: Proxy): Boolean {
            val address = proxy.address() as InetSocketAddress
            return try {
                val target = if (address.isUnresolved) InetSocketAddress(address.hostString, address.port) else address
                if (target.address?.isLoopbackAddress != true) return false
                Socket(Proxy.NO_PROXY).use { socket ->
                    socket.connect(target, LOCAL_TIMEOUT_MS)
                    socket.getOutputStream().write(localRequest)
                    val input = socket.getInputStream()
                    val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(LOCAL_TIMEOUT_MS.toLong())
                    // Kanxy rejects a request without a Host locally, without contacting an upstream.
                    statusLine.all { expected ->
                        val remaining = TimeUnit.NANOSECONDS.toMillis(deadline - System.nanoTime())
                        if (remaining <= 0) return false
                        socket.soTimeout = remaining.toInt()
                        input.read() == expected.toInt()
                    }
                }
            } catch (_: IOException) {
                false
            } catch (_: SecurityException) {
                false
            }
        }

        fun identifyHttpProxy(proxy: Proxy): KanxyDiagnosticStatus {
            return try {
                val connection = NativeProxyRouting.openConnection(URL("https://w00g.kancolle-server.com/"), proxy)
                    as? HttpsURLConnection ?: return KanxyDiagnosticStatus.HTTP_TUNNEL_FAILED
                try {
                    connection.instanceFollowRedirects = false
                    connection.useCaches = false
                    connection.connectTimeout = HTTPS_TIMEOUT_MS
                    connection.readTimeout = HTTPS_TIMEOUT_MS
                    connection.connect()
                    val leaf = connection.serverCertificates.firstOrNull() as? X509Certificate
                    // The platform verifies TLS and the host before we check the issuer's product name.
                    val issuer = leaf?.issuerX500Principal?.name
                    if (issuer != null && isKanxyCertificateIssuer(issuer)) KanxyDiagnosticStatus.HTTP_VERIFIED
                    else KanxyDiagnosticStatus.HTTP_CA_MISMATCH
                } finally {
                    connection.disconnect()
                }
            } catch (error: IOException) {
                classifyKanxyHttpsFailure(error)
            } catch (_: SecurityException) {
                KanxyDiagnosticStatus.HTTP_TUNNEL_FAILED
            }
        }
    }
}
