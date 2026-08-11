package app.yahagi.kancollebrowser.browser

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.os.Message
import android.view.KeyEvent
import android.webkit.ClientCertRequest
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
    private val shouldPatchMainScript: () -> Boolean = { false },
    private val mainScriptFetcher: GameMainScriptFetcher = GameMainScriptFetcher(),
) : WebViewClient() {

    private companion object {
        const val TAG = "GadgetBypass"
    }

    val originalClient: WebViewClient
        get() = original

    override fun shouldInterceptRequest(
        view: WebView,
        request: WebResourceRequest,
    ): WebResourceResponse? {
        val url = request.url?.toString() ?: return null
        if (request.method.equals("GET", ignoreCase = true) &&
            shouldPatchMainScript() &&
            GameMainScriptPatcher.isMainScriptUrl(url)
        ) {
            servePatchedMainScript(url, request.requestHeaders)?.let { return it }
        }
        if (isEnabled() && GadgetBypassRules.shouldIntercept(url, request.method)) {
            return serveFromBypass(url) ?: original.shouldInterceptRequest(view, request)
        }
        return original.shouldInterceptRequest(view, request)
    }

    @SuppressLint("Deprecated")
    @Deprecated("Deprecated in WebView")
    override fun shouldInterceptRequest(view: WebView, url: String?): WebResourceResponse? {
        if (url == null) {
            return null
        }
        if (shouldPatchMainScript() && GameMainScriptPatcher.isMainScriptUrl(url)) {
            servePatchedMainScript(url)?.let { return it }
        }
        if (isEnabled() && GadgetBypassRules.shouldIntercept(url, "GET")) {
            return serveFromBypass(url) ?: original.shouldInterceptRequest(view, url)
        }
        return original.shouldInterceptRequest(view, url)
    }

    private fun servePatchedMainScript(
        url: String,
        requestHeaders: Map<String, String> = emptyMap(),
    ): WebResourceResponse? = try {
        val originalBytes = if (isEnabled() && GadgetBypassRules.shouldIntercept(url, "GET")) {
            engine.fetch(url, endpoint())
        } else {
            mainScriptFetcher.fetch(url, requestHeaders)
        } ?: return null
        val originalScript = originalBytes.toString(Charsets.UTF_8)
        val patchedScript = GameMainScriptPatcher.patch(originalScript)
        if (patchedScript == originalScript) {
            Log.w(TAG, "60 FPS unlock pattern not found in $url")
        } else {
            Log.d(TAG, "patched 60 FPS limit in $url")
        }
        WebResourceResponse(
            "application/javascript",
            "utf-8",
            ByteArrayInputStream(patchedScript.toByteArray(Charsets.UTF_8)),
        )
    } catch (_: Exception) {
        null
    }

    private fun serveFromBypass(url: String): WebResourceResponse? {
        return try {
            val bytes = engine.fetch(url, endpoint()) ?: return null
            val mime = GadgetBypassRules.mimeTypeFor(url)
            Log.d(TAG, "intercept $url -> ${bytes.size} bytes")
            WebResourceResponse(mime.mime, mime.encoding, ByteArrayInputStream(bytes))
        } catch (e: Exception) {
            // Any interception failure must degrade to the default loading path.
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

    override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean =
        original.onRenderProcessGone(view, detail)

    override fun onUnhandledKeyEvent(view: WebView?, event: KeyEvent?) {
        original.onUnhandledKeyEvent(view, event)
    }

    override fun onScaleChanged(view: WebView?, oldScale: Float, newScale: Float) {
        original.onScaleChanged(view, oldScale, newScale)
    }

    override fun onSafeBrowsingHit(
        view: WebView?,
        request: WebResourceRequest?,
        threatType: Int,
        callback: SafeBrowsingResponse?,
    ) {
        original.onSafeBrowsingHit(view, request, threatType, callback)
    }
}
