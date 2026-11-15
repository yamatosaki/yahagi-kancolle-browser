package app.yahagi.kancollebrowser.browser

import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.diagnostics.KanxyDiagnosticStatus

internal object KanxyWebSocketControl {
    private val gameOrigin = Regex("https://w[0-9]+[a-z]\\.kancolle-server\\.com(?::443)?/?")
    private val statuses = setOf(
        KanxyDiagnosticStatus.WS_REQUESTED,
        KanxyDiagnosticStatus.WS_OPEN,
        KanxyDiagnosticStatus.WS_SPH_RECEIVED,
        KanxyDiagnosticStatus.WS_CONNECTION_CLOSED,
        KanxyDiagnosticStatus.WS_TRANSPORT_FAILED,
        KanxyDiagnosticStatus.WS_ROUTE_CLOSED,
    ).associateBy { it.name }

    fun acceptsOrigin(origin: String): Boolean = gameOrigin.matches(origin)

    fun diagnostic(message: String): KanxyDiagnosticStatus? = statuses[message]
}

/** Requests reconnects and records status. Chromium owns the socket and all payloads. */
internal class KanxyWebSocketObserver(
    private val onDiagnostic: (KanxyDiagnosticStatus) -> Unit,
) {
    private var webView: WebView? = null
    private var scriptHandler: ScriptHandler? = null
    private var listenerInstalled = false
    private var reportedUnsupported = false
    private val frames = LinkedHashSet<JavaScriptReplyProxy>()

    @Volatile private var fallbackWebView: WebView? = null

    fun ensureInstalled(target: WebView?) {
        if (target == null || webView === target) return
        detach()
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            if (!reportedUnsupported) onDiagnostic(KanxyDiagnosticStatus.BRIDGE_UNSUPPORTED)
            reportedUnsupported = true
            return
        }
        webView = target
        try {
            WebViewCompat.addWebMessageListener(
                target, KanxyWebSocketScript.objectName, KanxyWebSocketScript.allowedOriginRules,
            ) { sender, message, origin, _, reply ->
                if (sender === webView && message.type == WebMessageCompat.TYPE_STRING &&
                    KanxyWebSocketControl.acceptsOrigin(origin.toString())
                ) {
                    message.data?.let { onFrameMessage(reply, it) }
                }
            }
            listenerInstalled = true
            if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                scriptHandler = WebViewCompat.addDocumentStartJavaScript(
                    target, KanxyWebSocketScript.source, KanxyWebSocketScript.allowedOriginRules,
                )
            }
            if (scriptHandler == null) fallbackWebView = target
            onDiagnostic(if (scriptHandler == null) KanxyDiagnosticStatus.BRIDGE_MAIN_SCRIPT
                else KanxyDiagnosticStatus.BRIDGE_DOCUMENT_START)
        } catch (_: RuntimeException) {
            detach()
            onDiagnostic(KanxyDiagnosticStatus.BRIDGE_INSTALL_FAILED)
        }
    }

    fun needsScriptFallback(target: WebView): Boolean = fallbackWebView === target

    fun onPageStarted(target: WebView?) {
        if (target != null && webView === target) frames.clear()
    }

    fun reconnect(generation: Int) {
        val command = """{"kind":"reconnect","generation":$generation}"""
        val iterator = frames.iterator()
        while (iterator.hasNext()) {
            try {
                iterator.next().postMessage(command)
            } catch (_: RuntimeException) {
                iterator.remove()
            }
        }
    }

    fun retireLegacyWebView(nativeWebView: WebView?) {
        val target = webView?.takeUnless { it === nativeWebView } ?: return
        // Flutter's PlatformView dispose does not destroy its WebView. A detached
        // game document can otherwise keep retrying and evict the new socket.
        for (frame in frames) {
            runCatching { frame.postMessage("""{"kind":"retire"}""") }
        }
        runCatching { target.stopLoading() }
        runCatching { target.settings.javaScriptEnabled = false }
        runCatching { target.loadUrl("about:blank") }
    }

    fun detach() {
        fallbackWebView = null
        frames.clear()
        val target = webView
        webView = null
        runCatching { scriptHandler?.remove() }
        scriptHandler = null
        if (target != null && listenerInstalled) {
            runCatching { WebViewCompat.removeWebMessageListener(target, KanxyWebSocketScript.objectName) }
        }
        listenerInstalled = false
    }

    private fun onFrameMessage(reply: JavaScriptReplyProxy, message: String) {
        when (message) {
            "ready" -> {
                frames.remove(reply)
                if (frames.size >= MAX_GAME_FRAMES) frames.remove(frames.first())
                frames.add(reply)
            }
            "retired" -> frames.remove(reply)
            else -> if (reply in frames) {
                KanxyWebSocketControl.diagnostic(message)?.let(onDiagnostic)
            }
        }
    }

    private companion object {
        const val MAX_GAME_FRAMES = 16
    }
}
