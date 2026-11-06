package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout

internal interface NativeGameWebViewCleanup {
    fun stopLoading(webView: WebView)
    fun loadBlank(webView: WebView)
    fun clearHistory(webView: WebView)
    fun removeAllViews(webView: WebView)
    fun clearWebChromeClient(webView: WebView)
    fun clearWebViewClient(webView: WebView)
    fun destroy(webView: WebView)
}

internal object AndroidNativeGameWebViewCleanup : NativeGameWebViewCleanup {
    override fun stopLoading(webView: WebView) = webView.stopLoading()

    override fun loadBlank(webView: WebView) = webView.loadUrl("about:blank")

    override fun clearHistory(webView: WebView) = webView.clearHistory()

    override fun removeAllViews(webView: WebView) = webView.removeAllViews()

    override fun clearWebChromeClient(webView: WebView) {
        webView.webChromeClient = null
    }

    override fun clearWebViewClient(webView: WebView) {
        webView.webViewClient = WebViewClient()
    }

    override fun destroy(webView: WebView) = webView.destroy()
}

/**
 * Owns a native game [WebView] mounted as the final child of [contentRoot].
 *
 * All public methods must be called on the Android main thread. Calls from a
 * background thread fail fast to keep View ownership and generation changes atomic.
 */
class ActivityWebViewHost internal constructor(
    private val context: Context,
    private val contentRoot: FrameLayout,
    private val eventSink: NativeGameWebViewEventSink,
    private val onPresentationStateChanged: (Boolean) -> Unit = {},
    private val webViewFactory: (Context) -> WebView = { context -> WebView(context) },
    private val configureWebView: (WebView, WebViewClient, (Boolean) -> Unit) -> Unit = { webView, client, onPresentation ->
        NativeGameWebViewConfigurator.configure(
            webView,
            client,
            onPresentation,
            onPresentationPending = { (client as? NativeGameWebViewClient)?.presentationPending() },
        )
    },
    private val webViewCleanup: NativeGameWebViewCleanup = AndroidNativeGameWebViewCleanup,
) {
    constructor(
        context: Context,
        contentRoot: FrameLayout,
        eventSink: NativeGameWebViewEventSink,
        onPresentationStateChanged: (Boolean) -> Unit = {},
    ) : this(
        context = context,
        contentRoot = contentRoot,
        eventSink = eventSink,
        onPresentationStateChanged = onPresentationStateChanged,
        webViewFactory = { factoryContext -> WebView(factoryContext) },
        configureWebView = { webView, client, onPresentation ->
            NativeGameWebViewConfigurator.configure(
                webView,
                client,
                onPresentation,
                onPresentationPending = { (client as? NativeGameWebViewClient)?.presentationPending() },
            )
        },
        webViewCleanup = AndroidNativeGameWebViewCleanup,
    )

    private val state = NativeGameWebViewHostState()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var ownedResources: OwnedWebViewResources? = null
    private var hasValidBounds = false

    internal val currentWebView: WebView?
        get() {
            requireMainThread()
            return ownedResources?.takeIf { state.phase == NativeGameWebViewHostPhase.READY }?.webView
        }

    val currentGeneration: Long?
        get() {
            requireMainThread()
            return state.generationId?.takeIf { state.phase == NativeGameWebViewHostPhase.READY }
        }

    fun create(): Long? {
        requireMainThread()
        if (state.phase != NativeGameWebViewHostPhase.ABSENT) {
            return null
        }

        val generation = state.beginCreate()
        val resources = OwnedWebViewResources(generation)
        // Publish a token before any allocation or hierarchy operation can throw.
        ownedResources = resources
        var createStage = NativeGameWebViewCreateStage.CREATE_OVERLAY
        try {
            val createdOverlay = FrameLayout(context)
            resources.overlay = createdOverlay
            createdOverlay.apply {
                visibility = View.INVISIBLE
                setBackgroundColor(Color.TRANSPARENT)
                clipChildren = true
                clipToPadding = true
            }
            createStage = NativeGameWebViewCreateStage.ATTACH_OVERLAY
            contentRoot.addView(
                createdOverlay,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            createStage = NativeGameWebViewCreateStage.CREATE_WEB_VIEW
            val createdWebView = webViewFactory(context)
            if (!isCurrentCreate(resources)) {
                cleanupStandaloneWebView(createdWebView)
                rollbackCreate(resources)
                return null
            }
            resources.webView = createdWebView
            val client = NativeGameWebViewClient(
                generation = generation,
                sink = eventSink,
                acceptsGeneration = { state.accepts(generation) },
                prepareRenderProcessGone = ::prepareRenderProcessGone,
                onRenderProcessGone = ::onRenderProcessGone,
            )
            val presentationQuery = NativeGamePresentationQuery()
            client.setPresentationHintHandler {
                if (state.accepts(generation) && ownedResources?.webView === createdWebView) {
                    val token = presentationQuery.begin(client.documentEpoch)
                    runCatching {
                        createdWebView.evaluateJavascript(NativeGamePresentationQuery.SCRIPT) { result ->
                            if (state.accepts(generation) && ownedResources?.webView === createdWebView) {
                                when (presentationQuery.resolve(token, client.documentEpoch, result)) {
                                    "pending" -> eventSink.presentationPending(generation)
                                    "web" -> {
                                        eventSink.presentationChanged(generation, false)
                                        onPresentationStateChanged(false)
                                    }
                                    "game" -> {
                                        eventSink.presentationChanged(generation, true)
                                        onPresentationStateChanged(true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            createStage = NativeGameWebViewCreateStage.CONFIGURE_WEB_VIEW
            configureWebView(createdWebView, client) { _ ->
                // A bridge message is only a hint: an old document may have
                // queued it before navigation. Read the current DOM instead.
                client.presentationHint()
            }
            if (!isCurrentCreate(resources)) {
                rollbackCreate(resources)
                return null
            }
            createStage = NativeGameWebViewCreateStage.ATTACH_WEB_VIEW
            createdOverlay.addView(
                createdWebView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            if (!isCurrentCreate(resources)) {
                rollbackCreate(resources)
                return null
            }
            hasValidBounds = false
            createStage = NativeGameWebViewCreateStage.MARK_READY
            if (!state.markReady(generation)) {
                rollbackCreate(resources)
                return null
            }
            runCatching { eventSink.created(generation) }
            return generation.takeIf { isCurrentReady(resources) }
        } catch (error: Throwable) {
            rollbackCreate(resources)
            throw NativeGameWebViewCreateFailureReporter.report(
                context,
                createStage,
                error,
            )
        }
    }

    fun setBounds(generation: Long, bounds: NativeGameWebViewBounds?): Boolean {
        requireMainThread()
        if (!state.accepts(generation)) {
            return false
        }
        val viewport = bounds?.toPhysicalBounds(contentRoot.width, contentRoot.height)
        val plane = bounds?.toLayoutBounds(contentRoot.width, contentRoot.height)
        if (viewport == null || plane == null) {
            hasValidBounds = false
            ownedResources?.overlay?.visibility = View.INVISIBLE
            return false
        }
        val activeOverlay = ownedResources?.overlay ?: return false
        val webView = ownedResources?.webView ?: return false
        // Native overlays do not inherit Flutter's ClipRect. Keep that clip
        // as the outer container and the complete game plane as its child.
        // Camera/system padding therefore stays empty without refitting the
        // full canvas into the cropped visible rectangle.
        updateFrame(activeOverlay, viewport.left, viewport.top, viewport.width, viewport.height)
        updateFrame(webView, plane.left - viewport.left, plane.top - viewport.top, plane.width, plane.height)
        hasValidBounds = true
        return true
    }

    private fun updateFrame(view: View, left: Int, top: Int, width: Int, height: Int) {
        val previous = view.layoutParams as? FrameLayout.LayoutParams
        if (previous != null && previous.width == width && previous.height == height &&
            previous.leftMargin == left && previous.topMargin == top) return
        view.layoutParams = FrameLayout.LayoutParams(width, height).apply {
            leftMargin = left
            topMargin = top
        }
    }

    fun setVisible(generation: Long, visible: Boolean): Boolean {
        requireMainThread()
        if (!state.accepts(generation)) {
            return false
        }
        val activeOverlay = ownedResources?.overlay ?: return false
        if (!visible) {
            activeOverlay.visibility = View.INVISIBLE
            return true
        }
        if (state.phase != NativeGameWebViewHostPhase.READY || !hasValidBounds) {
            activeOverlay.visibility = View.INVISIBLE
            return false
        }
        activeOverlay.visibility = View.VISIBLE
        return true
    }

    fun destroy(generation: Long): Boolean {
        requireMainThread()
        return destroyInternal(generation, rendererGone = false)
    }

    /** Idempotent lifecycle cleanup for the owning Activity's `onDestroy`. */
    fun destroyCurrent(): Boolean {
        requireMainThread()
        return state.generationId?.let { destroyInternal(it, rendererGone = false) } ?: false
    }

    /** Completes a renderer-loss transaction after its event has been delivered. */
    internal fun onRenderProcessGone(generation: Long): Boolean {
        requireMainThread()
        if (state.generationId != generation || state.phase != NativeGameWebViewHostPhase.DESTROYING) {
            return false
        }
        completeDestroy(generation, rendererGone = true)
        return true
    }

    /** Starts renderer-loss teardown before the client synchronously reports it to the sink. */
    private fun prepareRenderProcessGone(generation: Long): Boolean {
        requireMainThread()
        return beginDestroy(generation)
    }

    private fun destroyInternal(generation: Long, rendererGone: Boolean): Boolean {
        if (!beginDestroy(generation)) {
            return false
        }
        completeDestroy(generation, rendererGone)
        return true
    }

    private fun beginDestroy(generation: Long): Boolean {
        if (!state.beginDestroy(generation)) {
            return false
        }
        ownedResources?.overlay?.visibility = View.INVISIBLE
        hasValidBounds = false
        return true
    }

    private fun completeDestroy(generation: Long, rendererGone: Boolean) {
        val resources = ownedResources
        resources?.let { cleanupResources(it, rendererGone) }
        if (ownedResources === resources) {
            ownedResources = null
        }
        state.completeDestroy(generation)
        runCatching { eventSink.destroyed(generation) }
    }

    private fun rollbackCreate(resources: OwnedWebViewResources) {
        val canCompleteOldGeneration = state.beginDestroy(resources.generation)
        try {
            cleanupResources(resources, rendererGone = false)
        } finally {
            if (ownedResources === resources) {
                ownedResources = null
                hasValidBounds = false
            }
            if (canCompleteOldGeneration &&
                state.generationId == resources.generation &&
                state.phase == NativeGameWebViewHostPhase.DESTROYING
            ) {
                state.completeDestroy(resources.generation)
            }
        }
    }

    private fun cleanupResources(resources: OwnedWebViewResources, rendererGone: Boolean) {
        if (resources.cleaned) {
            return
        }
        resources.cleaned = true
        val activeOverlay = resources.overlay
        val activeWebView = resources.webView
        if (!rendererGone) {
            bestEffort { activeWebView?.let(webViewCleanup::stopLoading) }
            // The destroying state makes client callbacks reject this generation.
            bestEffort { activeWebView?.let(webViewCleanup::loadBlank) }
            bestEffort { activeWebView?.let(webViewCleanup::clearHistory) }
            bestEffort { activeWebView?.let(webViewCleanup::removeAllViews) }
        }
        bestEffort { activeOverlay?.removeView(activeWebView) }
        bestEffort { contentRoot.removeView(activeOverlay) }
        if (!rendererGone) {
            bestEffort { activeWebView?.let(webViewCleanup::clearWebChromeClient) }
            bestEffort { activeWebView?.let(webViewCleanup::clearWebViewClient) }
        }
        bestEffort { activeWebView?.let(webViewCleanup::destroy) }
    }

    private fun isCurrentCreate(resources: OwnedWebViewResources): Boolean =
        ownedResources === resources &&
            state.generationId == resources.generation &&
            state.phase == NativeGameWebViewHostPhase.CREATING

    private fun isCurrentReady(resources: OwnedWebViewResources): Boolean =
        ownedResources === resources &&
            state.generationId == resources.generation &&
            state.phase == NativeGameWebViewHostPhase.READY

    private fun cleanupStandaloneWebView(webView: WebView) {
        bestEffort { webViewCleanup.clearWebChromeClient(webView) }
        bestEffort { webViewCleanup.clearWebViewClient(webView) }
        bestEffort { webViewCleanup.destroy(webView) }
    }

    private class OwnedWebViewResources(
        val generation: Long,
        var overlay: FrameLayout? = null,
        var webView: WebView? = null,
        var cleaned: Boolean = false,
    )

    private fun bestEffort(operation: () -> Unit) {
        runCatching(operation)
    }

    private fun requireMainThread() {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "ActivityWebViewHost must be used on the Android main thread"
        }
    }
}
