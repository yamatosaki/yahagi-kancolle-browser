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
import java.io.ByteArrayInputStream
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
) : WebViewClient() {

    private companion object {
        const val TAG = "GadgetBypass"
        const val SLOW_CACHE_REQUEST_MS = 500L
    }

    val originalClient: WebViewClient
        get() = original

    override fun shouldInterceptRequest(
        view: WebView,
        request: WebResourceRequest,
    ): WebResourceResponse? {
        val url = request.url?.toString() ?: return null
        serveFromMods(url, request.method, request.requestHeaders)?.let { return it }
        if (isEnabled() && GadgetBypassRules.shouldIntercept(url, request.method)) {
            return serveFromBypass(url) ?: original.shouldInterceptRequest(view, request)
        }
        serveFromGameCache(url, request.requestHeaders, request.method)?.let { return it }
        return original.shouldInterceptRequest(view, request)
    }

    @SuppressLint("Deprecated")
    @Deprecated("Deprecated in WebView")
    override fun shouldInterceptRequest(view: WebView, url: String?): WebResourceResponse? {
        if (url == null) {
            return null
        }
        serveFromMods(url, "GET", emptyMap())?.let { return it }
        if (isEnabled() && GadgetBypassRules.shouldIntercept(url, "GET")) {
            return serveFromBypass(url) ?: original.shouldInterceptRequest(view, url)
        }
        serveFromGameCache(url)?.let { return it }
        return original.shouldInterceptRequest(view, url)
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
        requestHeaders: Map<String, String> = emptyMap(),
        method: String = "GET",
    ): WebResourceResponse? {
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
            val response = gameResourceEngine?.fetch(url, cacheHeaders, method = method)
            val elapsedMs = SystemClock.elapsedRealtime() - startedAt
            if (elapsedMs >= SLOW_CACHE_REQUEST_MS) {
                Log.w(TAG, "resource cache ${response?.source ?: "fallback"} took ${elapsedMs}ms for $path")
            } else if (response?.source == GameResourceResponseSource.NETWORK) {
                Log.d(TAG, "resource cache NETWORK took ${elapsedMs}ms for $path")
            }
            if (response == null) return null
            val stream = try { response.openStream() } catch (error: Exception) {
                response.discard()
                throw error
            }
            try {
                WebResourceResponse(
                    response.mimeType,
                    response.encoding,
                    response.statusCode,
                    response.reasonPhrase,
                    response.headers,
                    stream,
                )
            } catch (error: Exception) {
                stream.close()
                throw error
            }
        } catch (error: Exception) {
            Log.w(TAG, "resource cache failed for $path: ${error.javaClass.simpleName}")
            null
        }
    }

    @Deprecated("Deprecated in WebView")
    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean =
        original.shouldOverrideUrlLoading(view, url)

    override fun shouldOverrideUrlLoading(
        view: WebView?,
        request: WebResourceRequest?,
    ): Boolean = original.shouldOverrideUrlLoading(view, request)

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
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
