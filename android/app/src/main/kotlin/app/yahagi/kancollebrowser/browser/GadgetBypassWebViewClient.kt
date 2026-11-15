package app.yahagi.kancollebrowser.browser

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.os.Message
import android.os.SystemClock
import android.view.KeyEvent
import android.webkit.ClientCertRequest
import android.webkit.CookieManager
import android.webkit.HttpAuthHandler
import android.webkit.RenderProcessGoneDetail
import android.webkit.SafeBrowsingResponse
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.util.Log
import androidx.webkit.WebResourceRequestCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.diagnostics.KanxyDiagnosticStatus
import java.io.ByteArrayInputStream
import java.io.FilterInputStream
import java.io.InputStream
import java.io.SequenceInputStream
import java.net.HttpURLConnection
import java.net.URI

/**
 * Wraps the plugin's [WebViewClient] and serves gadget client files from the
 * bypass engine. Every other callback is delegated to the original client so
 * the rest of the app keeps working unchanged.
 */
class GadgetBypassWebViewClient(
    private val original: WebViewClient,
    private val engine: GadgetBypassEngine,
    private val isEnabled: () -> Boolean,
    private val endpoint: () -> String,
    private val gameResourceEngine: GameResourceCacheEngine? = null,
    private val cookiesIncludedInRequestHeaders: Boolean = false,
    private val modResourceInterceptor: ((String, String, Map<String, String>) -> WebResourceResponse?)? = null,
    val ownerToken: Any? = null,
    private val onDocumentStarted: (WebView?) -> Unit = {},
    private val useFreshGameResources: () -> Boolean = { false },
    private val needsKanxyScriptFallback: (WebView) -> Boolean = { false },
    private val isKanxyDiagnosticsEnabled: () -> Boolean = { false },
    private val onKanxyMainScript: (KanxyDiagnosticStatus) -> Unit = {},
) : WebViewClient() {

    private companion object {
        const val TAG = "GadgetBypass"
        const val SLOW_CACHE_REQUEST_MS = 500L
        const val GAME_MAIN_SCRIPT_PATH = "/kcs2/js/main.js"
        val kanxyScriptPrefix by lazy { "${KanxyWebSocketScript.source}\n".toByteArray(Charsets.UTF_8) }
        val javaScriptMimeTypes = setOf(
            "application/javascript", "application/x-javascript", "text/javascript",
            "application/ecmascript", "text/ecmascript",
        )
        val scriptCharsets = setOf("utf-8", "utf8", "us-ascii")
        val originalBodyHeaders = setOf(
            "content-length", "content-range", "accept-ranges", "transfer-encoding",
            "etag", "last-modified", "content-md5", "digest", "content-digest", "repr-digest",
        )
    }

    val originalClient: WebViewClient
        get() = original

    var documentEpoch: Long = 0
        private set

    override fun shouldInterceptRequest(
        view: WebView,
        request: WebResourceRequest,
    ): WebResourceResponse? {
        val url = request.url?.toString() ?: return null
        return interceptResources(view, url, request.method, request.requestHeaders, request)
            ?: original.shouldInterceptRequest(view, request)
    }

    @SuppressLint("Deprecated")
    @Deprecated("Deprecated in WebView")
    override fun shouldInterceptRequest(view: WebView, url: String?): WebResourceResponse? {
        if (url == null) return null
        return interceptResources(view, url, "GET", emptyMap()) ?: original.shouldInterceptRequest(view, url)
    }

    private fun interceptResources(
        view: WebView,
        url: String,
        method: String,
        headers: Map<String, String>,
        request: WebResourceRequest? = null,
    ): WebResourceResponse? {
        serveFromMods(url, method, headers)?.let { return it }
        val kanxy = useFreshGameResources()
        if (kanxy) {
            val mainScript = method.equals("GET", true) && request?.isForMainFrame != true && isKanxyMainScript(url)
            val traceMainScript = mainScript && kanxyDiagnosticsEnabled()
            if (traceMainScript) recordKanxyMainScript(KanxyDiagnosticStatus.MAIN_SCRIPT_REQUESTED)
            val rewriteMainScript = mainScript && !isRedirect(request)
            serveFromGameCache(
                url, headers, method, kanxy = true,
                traceMainScript = traceMainScript, rewriteMainScript = rewriteMainScript,
            ) {
                needsKanxyScriptFallback(view)
            }?.let { return it }
            if (traceMainScript) recordKanxyMainScript(KanxyDiagnosticStatus.MAIN_SCRIPT_WEBVIEW_FALLBACK)
        }
        if (isEnabled() && GadgetBypassRules.shouldIntercept(url, method)) return serveFromBypass(url)
        return if (kanxy) null else serveFromGameCache(url, headers, method, kanxy = false)
    }

    private fun serveFromMods(url: String, method: String, headers: Map<String, String>): WebResourceResponse? =
        runCatching { modResourceInterceptor?.invoke(url, method, headers) }.getOrNull()

    private fun serveFromBypass(url: String): WebResourceResponse? {
        val startedAt = SystemClock.elapsedRealtime()
        val path = runCatching { URI(url).rawPath }.getOrNull() ?: "unknown"
        return try {
            val bytes = engine.fetch(url, endpoint())
            if (bytes == null) {
                Log.d(TAG, "mirror fallback took ${SystemClock.elapsedRealtime() - startedAt}ms for $path")
                return null
            }
            val mime = GadgetBypassRules.mimeTypeFor(url)
            Log.d(TAG, "mirror response took ${SystemClock.elapsedRealtime() - startedAt}ms for $path (${bytes.size} bytes)")
            WebResourceResponse(mime.mime, mime.encoding, ByteArrayInputStream(bytes))
        } catch (e: Exception) {
            // Any interception failure must degrade to the default loading path.
            null
        }
    }

    private fun serveFromGameCache(
        url: String,
        requestHeaders: Map<String, String>,
        method: String,
        kanxy: Boolean,
        traceMainScript: Boolean = false,
        rewriteMainScript: Boolean = false,
        needsBridgePrefix: () -> Boolean = { false },
    ): WebResourceResponse? {
        if (kanxy && !GameResourceCacheRules.shouldCache(url, method)) return null
        if (!method.equals("GET", true) ||
            !cookiesIncludedInRequestHeaders &&
                !GameResourceCacheRules.canInterceptWithoutCookieHeaders(url, method)
        ) return null
        val startedAt = SystemClock.elapsedRealtime()
        val path = runCatching { URI(url).rawPath }.getOrNull() ?: "unknown"
        return try {
            val cacheHeaders = if (cookiesIncludedInRequestHeaders) requestHeaders else {
                // Shared binary assets need no cookie lookup on the WebView I/O thread.
                val shareable = runCatching { URI(url) }.getOrNull()
                    ?.let(GameResourceCacheRules::isShareableStaticUri) == true
                val alreadyHasCookie = requestHeaders.keys.any { it.equals("Cookie", true) }
                val cookie = if (shareable || alreadyHasCookie) null else {
                    runCatching { CookieManager.getInstance().getCookie(url) }.getOrNull()
                }
                GameResourceCacheRules.withFallbackCookie(requestHeaders, cookie)
            }
            // Let Kanxy serve fresh bytes without reading or updating the stock cache.
            val response = if (kanxy) gameResourceEngine?.fetchFresh(url, cacheHeaders, method)
                else gameResourceEngine?.fetch(url, cacheHeaders, method = method)
            val elapsedMs = SystemClock.elapsedRealtime() - startedAt
            if (elapsedMs >= SLOW_CACHE_REQUEST_MS) {
                Log.w(TAG, "resource cache ${response?.source ?: "fallback"} took ${elapsedMs}ms for $path")
            } else if (response?.source == GameResourceResponseSource.NETWORK) {
                Log.d(TAG, "resource cache NETWORK took ${elapsedMs}ms for $path")
            }
            if (response == null) return null
            val plainScript = (rewriteMainScript || traceMainScript) && response.isPlainJavaScriptResponse()
            val rewrite = rewriteMainScript && plainScript
            val prefix = rewrite && needsBridgePrefix()
            val source = try { response.openStream() } catch (error: Exception) {
                response.discard()
                throw error
            }
            val inspected = if (traceMainScript && plainScript) {
                KanxyMainScriptInputStream(
                    source,
                    response.bodyLength,
                    ::recordKanxyMainScript,
                    ::kanxyDiagnosticsEnabled,
                )
            } else source
            val body = if (rewrite) {
                KanxyDropdownTouchInputStream(inspected, response.bodyLength) {
                    if (traceMainScript) recordKanxyMainScript(KanxyDiagnosticStatus.MAIN_SCRIPT_DROPDOWN_PATCHED)
                }
            } else inspected
            val stream = if (prefix) SequenceInputStream(ByteArrayInputStream(kanxyScriptPrefix), body) else body
            try {
                WebResourceResponse(
                    response.mimeType,
                    response.encoding,
                    response.statusCode,
                    response.reasonPhrase,
                    if (rewrite) response.headers.filterKeys { it.lowercase() !in originalBodyHeaders }
                    else response.headers,
                    stream,
                ).also {
                    if (traceMainScript) {
                        recordKanxyMainScript(KanxyDiagnosticStatus.MAIN_SCRIPT_SERVED)
                        if (prefix) recordKanxyMainScript(KanxyDiagnosticStatus.MAIN_SCRIPT_BRIDGE_PREFIXED)
                    }
                }
            } catch (error: Exception) {
                stream.close()
                throw error
            }
        } catch (error: Exception) {
            Log.w(TAG, "resource cache failed for $path: ${error.javaClass.simpleName}")
            null
        }
    }

    private fun isRedirect(request: WebResourceRequest?): Boolean = request != null &&
        WebViewFeature.isFeatureSupported(WebViewFeature.WEB_RESOURCE_REQUEST_IS_REDIRECT) &&
        WebResourceRequestCompat.isRedirect(request)

    private fun isKanxyMainScript(url: String): Boolean {
        if (!url.contains(GAME_MAIN_SCRIPT_PATH)) return false
        val uri = runCatching { URI(url) }.getOrNull() ?: return false
        return uri.rawPath == GAME_MAIN_SCRIPT_PATH && uri.rawFragment == null &&
            GameResourceCacheRules.isOfficialStaticUri(uri)
    }

    private fun GameResourceResponse.isPlainJavaScriptResponse(): Boolean {
        if (source != GameResourceResponseSource.NETWORK || statusCode != HttpURLConnection.HTTP_OK ||
            bodyLength == 0L || mimeType.lowercase() !in javaScriptMimeTypes ||
            encoding?.lowercase() !in scriptCharsets
        ) return false
        return headers.none { (name, value) ->
            when (name.lowercase()) {
                "content-encoding" -> !value.trim().equals("identity", true)
                "content-type" -> value.split(';').drop(1).any { parameter ->
                    parameter.substringBefore('=').trim().equals("charset", true) &&
                        parameter.substringAfter('=', "").trim().trim('"').lowercase() !in scriptCharsets
                }
                else -> false
            }
        }
    }

    private fun kanxyDiagnosticsEnabled(): Boolean = runCatching(isKanxyDiagnosticsEnabled).getOrDefault(false)

    private fun recordKanxyMainScript(status: KanxyDiagnosticStatus) {
        if (kanxyDiagnosticsEnabled()) runCatching { onKanxyMainScript(status) }
    }

    @Deprecated("Deprecated in WebView")
    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean =
        original.shouldOverrideUrlLoading(view, url)

    override fun shouldOverrideUrlLoading(
        view: WebView?,
        request: WebResourceRequest?,
    ): Boolean = original.shouldOverrideUrlLoading(view, request)

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        documentEpoch++
        onDocumentStarted(view)
        original.onPageStarted(view, url, favicon)
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        original.onPageFinished(view, url)
    }

    override fun onLoadResource(view: WebView?, url: String?) {
        original.onLoadResource(view, url)
    }

    override fun onPageCommitVisible(view: WebView?, url: String?) {
        original.onPageCommitVisible(view, url)
    }

    override fun onReceivedError(
        view: WebView?,
        request: WebResourceRequest?,
        error: WebResourceError?,
    ) {
        original.onReceivedError(view, request, error)
    }

    @Suppress("DEPRECATION")
    override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
        original.onReceivedError(view, errorCode, description, failingUrl)
    }

    override fun onReceivedHttpError(
        view: WebView?,
        request: WebResourceRequest?,
        errorResponse: WebResourceResponse?,
    ) {
        original.onReceivedHttpError(view, request, errorResponse)
    }

    override fun onReceivedSslError(
        view: WebView?,
        handler: SslErrorHandler?,
        error: android.net.http.SslError?,
    ) {
        original.onReceivedSslError(view, handler, error)
    }

    override fun onReceivedClientCertRequest(view: WebView?, request: ClientCertRequest?) {
        original.onReceivedClientCertRequest(view, request)
    }

    override fun onReceivedHttpAuthRequest(
        view: WebView?,
        handler: HttpAuthHandler?,
        host: String?,
        realm: String?,
    ) {
        original.onReceivedHttpAuthRequest(view, handler, host, realm)
    }

    override fun onFormResubmission(view: WebView?, dontResend: Message?, resend: Message?) {
        original.onFormResubmission(view, dontResend, resend)
    }

    override fun doUpdateVisitedHistory(view: WebView?, url: String?, isReload: Boolean) {
        original.doUpdateVisitedHistory(view, url, isReload)
    }

    override fun onReceivedLoginRequest(
        view: WebView?,
        realm: String?,
        account: String?,
        args: String?,
    ) {
        original.onReceivedLoginRequest(view, realm, account, args)
    }

    @androidx.annotation.RequiresApi(26)
    override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean =
        original.onRenderProcessGone(view, detail)

    override fun onUnhandledKeyEvent(view: WebView?, event: KeyEvent?) {
        original.onUnhandledKeyEvent(view, event)
    }

    override fun onScaleChanged(view: WebView?, oldScale: Float, newScale: Float) {
        original.onScaleChanged(view, oldScale, newScale)
    }

    @androidx.annotation.RequiresApi(27)
    override fun onSafeBrowsingHit(
        view: WebView?,
        request: WebResourceRequest?,
        threatType: Int,
        callback: SafeBrowsingResponse?,
    ) {
        original.onSafeBrowsingHit(view, request, threatType, callback)
    }
}

/** Reports only bytes already read by WebView, without buffering or modifying the script. */
internal class KanxyMainScriptInputStream(
    input: InputStream,
    expectedLength: Long,
    private val onStatus: (KanxyDiagnosticStatus) -> Unit,
    private val isRecording: () -> Boolean = { true },
) : FilterInputStream(input) {
    private companion object {
        // Kanxy 1.01.9 assets/main.js.kai/MainEntrance.js creates the socket here.
        val marker = "new WebSocket(this.kanxy.url)".toByteArray(Charsets.US_ASCII)
        val fallback = IntArray(marker.size).also { offsets ->
            var length = 0
            for (index in 1 until marker.size) {
                while (length > 0 && marker[index] != marker[length]) length = offsets[length - 1]
                if (marker[index] == marker[length]) length++
                offsets[index] = length
            }
        }
    }

    private var matched = 0
    private var remaining = expectedLength
    private var completeCoverage = true
    private var finished = false

    override fun read(): Int {
        val value = super.read()
        if (value >= 0 && shouldInspect()) {
            inspect(value.toByte())
            consumed(1)
        }
        return value
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        val count = super.read(buffer, offset, length)
        if (count > 0 && shouldInspect()) {
            for (index in offset until offset + count) {
                inspect(buffer[index])
                if (finished) break
            }
            consumed(count)
        }
        return count
    }

    override fun skip(length: Long): Long = super.skip(length).also { count ->
        if (count > 0) interruptCoverage()
    }

    override fun reset() {
        super.reset()
        interruptCoverage()
    }

    private fun interruptCoverage() {
        matched = 0
        completeCoverage = false
    }

    private fun shouldInspect(): Boolean {
        if (!finished && !isRecording()) finished = true
        return !finished
    }

    private fun inspect(value: Byte) {
        while (matched > 0 && value != marker[matched]) matched = fallback[matched - 1]
        if (value == marker[matched]) matched++
        if (matched == marker.size) report(KanxyDiagnosticStatus.MAIN_SCRIPT_KANXY_MARKER)
    }

    private fun consumed(count: Int) {
        remaining -= count
        if (!finished && completeCoverage && remaining == 0L) {
            report(KanxyDiagnosticStatus.MAIN_SCRIPT_MARKER_MISSING)
        }
    }

    private fun report(status: KanxyDiagnosticStatus) {
        finished = true
        runCatching { onStatus(status) }
    }
}
