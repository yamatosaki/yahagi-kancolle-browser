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
import java.util.Locale
import java.net.URI

interface NativeGameWebViewEventSink {
    fun created(generation: Long)
    fun pageStarted(generation: Long, url: String)
    fun pageFinished(generation: Long, url: String)
    fun presentationChanged(generation: Long, isGame: Boolean) = Unit
    fun presentationPending(generation: Long) = Unit
    fun resourceError(generation: Long, errorCode: Int) = Unit
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
) {
    private var currentDocumentTarget: NavigationTarget? = null

    fun pageStarted(url: String) {
        currentDocumentTarget = NavigationTarget.from(url)
        emit { it.pageStarted(generation, url) }
    }

    fun pageFinished(url: String) = emit { it.pageFinished(generation, url) }

    fun presentationPending() = emit { it.presentationPending(generation) }

    fun receivedError(isMainFrame: Boolean, errorCode: Int, description: String?, requestUrl: String? = null) {
        if (isMainFrame && !isCurrentDocument(requestUrl)) return
        if (isMainFrame) {
            emit { it.mainFrameError(generation, errorCode, sanitizeDescription(description)) }
        } else {
            // Child errors are useful diagnostics but must never hide a login
            // page or include its private resource URL in the event payload.
            emit { it.resourceError(generation, errorCode) }
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

    private data class NavigationTarget(
        val scheme: String,
        val host: String,
        val port: Int,
        val path: String,
        val query: String?,
    ) {
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
        const val INVALID_SCHEME = "invalid"
    }
}

internal class NativeGameWebViewClient(
    generation: Long,
    sink: NativeGameWebViewEventSink,
    acceptsGeneration: () -> Boolean,
    prepareRenderProcessGone: (Long) -> Boolean,
    onRenderProcessGone: (Long) -> Unit,
    private val onMainFrameNavigationStarted: (WebView?) -> Unit,
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
