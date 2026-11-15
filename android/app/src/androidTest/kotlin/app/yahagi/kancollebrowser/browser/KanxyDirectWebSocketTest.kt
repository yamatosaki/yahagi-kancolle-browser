package app.yahagi.kancollebrowser.browser

import android.security.NetworkSecurityPolicy
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.net.InetAddress
import java.net.ServerSocket
import java.security.MessageDigest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class KanxyDirectWebSocketTest {
    @Test
    fun cleartextPolicyPermitsOnlyLoopback() {
        val policy = NetworkSecurityPolicy.getInstance()
        for (host in listOf("localhost", "127.0.0.1", "::1")) {
            assertTrue(host, policy.isCleartextTrafficPermitted(host))
        }
        for (host in listOf("kancolle-server.com", "w00g.kancolle-server.com", "192.168.0.1", "localhost.example.test")) {
            assertFalse(host, policy.isCleartextTrafficPermitted(host))
        }
    }

    @Test
    fun secureGameFrameReceivesNativeLoopbackWebSocketMessage() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val result = GameFrameResult()
        val worker = Executors.newSingleThreadExecutor()
        var webView: WebView? = null
        try {
            ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { listener ->
                listener.soTimeout = 10_000
                val origin = worker.submit<String> { serveWebSocket(listener) }
                val gamePage = """
                    <!doctype html><script>
                    if (self === top || location.origin !== '$GAME_ORIGIN') {
                        GameFrameResult.receive('wrong frame or origin');
                    } else {
                        try {
                            const socket = new WebSocket('ws://localhost:${listener.localPort}/');
                            socket.onmessage = (event) => GameFrameResult.receive(event.data);
                            socket.onerror = () => GameFrameResult.receive('connection error');
                        } catch (error) {
                            GameFrameResult.receive(error.name + ': ' + error.message);
                        }
                    }
                    </script>
                """.trimIndent()
                instrumentation.runOnMainSync {
                    webView = WebView(instrumentation.targetContext).apply {
                        settings.javaScriptEnabled = true
                        assertEquals(WebSettings.MIXED_CONTENT_NEVER_ALLOW, settings.mixedContentMode)
                        addJavascriptInterface(result, "GameFrameResult")
                        webViewClient = object : WebViewClient() {
                            override fun shouldInterceptRequest(
                                view: WebView?,
                                request: WebResourceRequest?,
                            ): WebResourceResponse? {
                                if (request?.url.toString() != GAME_PAGE_URL) return null
                                return WebResourceResponse("text/html", "UTF-8", gamePage.byteInputStream())
                            }
                        }
                        loadDataWithBaseURL(
                            "https://play.games.dmm.com/",
                            "<!doctype html><iframe src=\"$GAME_PAGE_URL\"></iframe>",
                            "text/html",
                            "UTF-8",
                            null,
                        )
                    }
                }
                assertTrue("Game frame did not report a WebSocket result", result.received.await(12, TimeUnit.SECONDS))
                assertEquals(FRAME_PAYLOAD, result.message.get())
                assertEquals(GAME_ORIGIN, origin.get(2, TimeUnit.SECONDS))
            }
        } finally {
            instrumentation.runOnMainSync { webView?.destroy() }
            worker.shutdownNow()
        }
    }

    private fun serveWebSocket(listener: ServerSocket): String = listener.accept().use { connection ->
        connection.soTimeout = 5_000
        val request = connection.getInputStream().bufferedReader(Charsets.US_ASCII)
        assertEquals("GET / HTTP/1.1", request.readLine())
        val headers = generateSequence(request::readLine)
            .takeWhile(String::isNotEmpty)
            .associate { line -> line.substringBefore(':').lowercase() to line.substringAfter(':').trim() }
        assertEquals("websocket", headers["upgrade"]?.lowercase())
        val key = headers.getValue("sec-websocket-key") + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        val digest = MessageDigest.getInstance("SHA-1").digest(key.toByteArray(Charsets.US_ASCII))
        val accept = Base64.encodeToString(digest, Base64.NO_WRAP)
        val response = connection.getOutputStream()
        response.write(
            ("HTTP/1.1 101 Switching Protocols\r\n" +
                "Upgrade: websocket\r\n" +
                "Connection: Upgrade\r\n" +
                "Sec-WebSocket-Accept: $accept\r\n\r\n").toByteArray(Charsets.US_ASCII),
        )
        val data = FRAME_PAYLOAD.toByteArray(Charsets.UTF_8)
        response.write(byteArrayOf(0x81.toByte(), data.size.toByte()))
        response.write(data)
        response.flush()
        headers.getValue("origin")
    }

    class GameFrameResult {
        val received = CountDownLatch(1)
        val message = AtomicReference<String>()

        @JavascriptInterface
        fun receive(value: String) {
            if (message.compareAndSet(null, value)) received.countDown()
        }
    }

    private companion object {
        const val GAME_ORIGIN = "https://w00g.kancolle-server.com"
        const val GAME_PAGE_URL = "$GAME_ORIGIN/kanxy-websocket-test"
        const val FRAME_PAYLOAD = "kanxy-direct-test"
    }
}
