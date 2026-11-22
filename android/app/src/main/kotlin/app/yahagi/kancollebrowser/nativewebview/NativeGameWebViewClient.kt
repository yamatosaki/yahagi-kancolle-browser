package app.yahagi.kancollebrowser.nativewebview

import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import app.yahagi.kancollebrowser.browser.GadgetBypassRules
import java.net.URI
import java.util.Locale

enum class NativeGameWebViewResourceKind(val wireValue: String) {
    GADGET("gadget"),
}

interface NativeGameWebViewEventSink {
    fun created(generation: Long)
    fun pageStarted(generation: Long, url: String)
    fun pageProgress(generation: Long, progress: Int, url: String?) = Unit
    fun pageFinished(generation: Long, url: String)
    fun presentationChanged(generation: Long, isGame: Boolean) = Unit
    fun presentationPending(generation: Long) = Unit
    fun resourceError(generation: Long, errorCode: Int, kind: NativeGameWebViewResourceKind? = null) = Unit
    fun mainFrameError(generation: Long, errorCode: Int, description: String)
    fun navigationBlocked(generation: Long, scheme: String)
    fun renderProcessGone(generation: Long, didCrash: Boolean)
    fun destroyed(generation: Long)
}

/** Android-free policy and event mapper used by [NativeGameWebViewClient]. */
internal class NativeGameWebViewClientDelegate(
    private val generation: Long,
    private val sink: NativeGameWebViewEventSink,
    private val acceptsGeneration: () -> Boolean,
    private val prepareRenderProcessGone: () -> Boolean,
    private val onRenderProcessGone: () -> Unit,
    private val startupChecksEnabled: () -> Boolean = { true },
) {
    private var currentDocumentTarget: NavigationTarget? = null

    fun pageStarted(url: String) {
        currentDocumentTarget = NavigationTarget.from(url)
        emit { it.pageStarted(generation, url) }
    }

    fun pageFinished(url: String) = emit { it.pageFinished(generation, url) }

    fun pageProgress(progress: Int, readUrl: () -> String?) {
        if (!startupChecksEnabled() || progress !in 0..100) return
        val current = currentDocumentTarget ?: return
        val url = readUrl()
        val reported = url?.let(NavigationTarget::from)
        // Chromium can still expose the old document URL while a redirect is committing.
        if (url != null && reported != current) return
        emit { it.pageProgress(generation, progress, reported?.safeAddress()) }
    }

    fun presentationPending() = emit { it.presentationPending(generation) }

    fun receivedError(isMainFrame: Boolean, errorCode: Int, description: String?, requestUrl: String? = null) {
        if (isMainFrame && !isCurrentDocument(requestUrl)) return
        if (isMainFrame) {
            emit { it.mainFrameError(generation, errorCode, sanitizeDescription(description)) }
        } else {
            // Report only an allowlisted type rather than exposing child resource URLs.
            emit {
                val kind = if (startupChecksEnabled()) classifyResource(requestUrl) else null
                it.resourceError(generation, errorCode, kind)
            }
        }
    }

    fun receivedHttpError(isMainFrame: Boolean, statusCode: Int, requestUrl: String? = null) {
        if (statusCode >= 400) receivedError(isMainFrame, statusCode, "HTTP $statusCode", requestUrl)
    }

    fun shouldOverrideUrlLoading(url: String?, isMainFrame: Boolean = true): Boolean {
        if (!acceptsGeneration()) {
            return true
        }
        val scheme = normalizedScheme(url)
        if (scheme == "http" || scheme == "https") {
            return false
        }
        if (isMainFrame) {
            runCatching { sink.navigationBlocked(generation, scheme) }
        }
        return true
    }

    fun renderProcessGone(didCrash: Boolean): Boolean {
        if (!acceptsGeneration()) {
            return true
        }
        if (!runCatching(prepareRenderProcessGone).getOrDefault(false)) {
            return true
        }
        runCatching { sink.renderProcessGone(generation, didCrash) }
        runCatching(onRenderProcessGone)
        return true
    }

    private fun emit(event: (NativeGameWebViewEventSink) -> Unit) {
        if (acceptsGeneration()) {
            runCatching { event(sink) }
        }
    }

    private fun normalizedScheme(url: String?): String {
        val match = SCHEME_PATTERN.find(url.orEmpty()) ?: return INVALID_SCHEME
        return match.groupValues[1].lowercase(Locale.ROOT).take(MAX_SCHEME_LENGTH)
    }

    private fun sanitizeDescription(description: String?): String = description.orEmpty().take(MAX_DESCRIPTION_LENGTH)

    private fun isCurrentDocument(requestUrl: String?): Boolean {
        val current = currentDocumentTarget ?: return true
        val requested = requestUrl?.let(NavigationTarget::from) ?: return true
        return current == requested
    }

    private fun classifyResource(requestUrl: String?): NativeGameWebViewResourceKind? {
        val uri = requestUrl?.let { runCatching { URI(it) }.getOrNull() } ?: return null
        if (!GadgetBypassRules.GADGET_HOST.equals(uri.host, ignoreCase = true) || uri.userInfo != null) return null
        val port = when (uri.scheme?.lowercase(Locale.ROOT)) {
            "http" -> 80
            "https" -> 443
            else -> return null
        }
        if (uri.port != -1 && uri.port != port) return null
        return NativeGameWebViewResourceKind.GADGET.takeIf { uri.rawPath in GADGET_STARTUP_SCRIPTS }
    }

    private data class NavigationTarget(
        val scheme: String,
        val host: String,
        val port: Int,
        val path: String,
        val query: String?,
    ) {
        fun safeAddress(): String? {
            if (scheme != "https" && scheme != "http") return null
            val origin = URI(scheme, null, host, port, null, null, null).toASCIIString()
            val safePath = path.split('/').takeWhile { '=' !in it && !it.contains("%3d", ignoreCase = true) }
                .joinToString("/")
            return (origin + safePath).takeIf { it.length <= MAX_ADDRESS_LENGTH }
        }

        companion object {
            fun from(value: String): NavigationTarget? = runCatching {
                val uri = URI(value)
                val scheme = uri.scheme?.lowercase(Locale.ROOT) ?: return@runCatching null
                val host = uri.host?.lowercase(Locale.ROOT) ?: return@runCatching null
                val port = when {
                    (scheme == "https" && uri.port == 443) || (scheme == "http" && uri.port == 80) -> -1
                    else -> uri.port
                }
                NavigationTarget(scheme, host, port, uri.rawPath.orEmpty().ifEmpty { "/" }, uri.rawQuery)
            }.getOrNull()
        }
    }

    private companion object {
        val SCHEME_PATTERN = Regex("^([A-Za-z][A-Za-z0-9+.-]*):")
        const val MAX_SCHEME_LENGTH = 32
        const val MAX_DESCRIPTION_LENGTH = 256
        const val MAX_ADDRESS_LENGTH = 2048
        const val INVALID_SCHEME = "invalid"
        val GADGET_STARTUP_SCRIPTS = setOf(
            "/gadget_html5/js/kcs_const.js",
            "/gadget_html5/js/kcs_cda.js",
            "/gadget_html5/js/kcs_content.js",
            "/gadget_html5/js/kcs_global.js",
            "/gadget_html5/js/kcs_login.js",
            "/gadget_html5/script/jquery.min.js",
        )
    }
}

internal class NativeGameWebViewClient(
    generation: Long,
    sink: NativeGameWebViewEventSink,
    acceptsGeneration: () -> Boolean,
    prepareRenderProcessGone: (Long) -> Boolean,
    onRenderProcessGone: (Long) -> Unit,
    private val onMainFrameNavigationStarted: (WebView?) -> Unit,
    startupChecksEnabled: () -> Boolean = { true },
) : WebViewClient() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var presentationBridge: NativeGamePresentationBridge? = null
    private var presentationHintHandler: (() -> Unit)? = null
    var documentEpoch = 0L
        private set

    fun attachPresentationBridge(bridge: NativeGamePresentationBridge) {
        presentationBridge = bridge
    }

    fun setPresentationHintHandler(handler: () -> Unit) {
        presentationHintHandler = handler
    }

    fun presentationHint() {
        mainHandler.post { presentationHintHandler?.invoke() }
    }
    private val delegate = NativeGameWebViewClientDelegate(
        generation = generation,
        sink = sink,
        acceptsGeneration = acceptsGeneration,
        prepareRenderProcessGone = { prepareRenderProcessGone(generation) },
        onRenderProcessGone = { onRenderProcessGone(generation) },
        startupChecksEnabled = startupChecksEnabled,
    )

    fun presentationPending() {
        // JavaScriptInterface callbacks arrive on a background thread.
        mainHandler.post {
            presentationHintHandler?.invoke() ?: delegate.presentationPending()
        }
    }

    override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        documentEpoch++
        presentationBridge?.resetForNavigation()
        onMainFrameNavigationStarted(view)
        delegate.pageStarted(url.orEmpty())
    }

    override fun onPageFinished(view: WebView?, url: String?) {
        delegate.pageFinished(url.orEmpty())
    }

    fun onPageProgress(view: WebView?, progress: Int) = delegate.pageProgress(progress) { view?.url }

    override fun onReceivedError(
        view: WebView?,
        request: WebResourceRequest?,
        error: WebResourceError?,
    ) {
        delegate.receivedError(
            isMainFrame = request?.isForMainFrame == true,
            errorCode = error?.errorCode ?: 0,
            description = error?.description?.toString(),
            requestUrl = request?.url?.toString(),
        )
    }

    override fun onReceivedHttpError(
        view: WebView?,
        request: WebResourceRequest?,
        errorResponse: WebResourceResponse?,
    ) {
        delegate.receivedHttpError(
            isMainFrame = request?.isForMainFrame == true,
            statusCode = errorResponse?.statusCode ?: 0,
            requestUrl = request?.url?.toString(),
        )
    }

    @Deprecated("Deprecated in WebView")
    override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
        delegate.receivedError(isMainFrame = true, errorCode = errorCode, description = description, requestUrl = failingUrl)
    }

    @Deprecated("Deprecated in WebView")
    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean =
        delegate.shouldOverrideUrlLoading(url)

    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean =
        delegate.shouldOverrideUrlLoading(
            url = request?.url?.toString(),
            isMainFrame = request?.isForMainFrame == true,
        )

    override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean =
        delegate.renderProcessGone(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) detail?.didCrash() == true else false,
        )
}
