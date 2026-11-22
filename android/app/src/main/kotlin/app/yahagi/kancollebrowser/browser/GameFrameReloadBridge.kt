package app.yahagi.kancollebrowser.browser

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.capture.CaptureOriginPolicy
import java.util.Collections
import java.util.IdentityHashMap
import java.util.UUID
import org.json.JSONObject
import org.json.JSONTokener

internal interface GameFrameReloadBridgePort {
    fun isSupported(): Boolean

    fun configure()

    fun reload(onComplete: (String) -> Unit)

    fun dispose()
}

internal interface PreparedGameFrameReloadBridgePort : GameFrameReloadBridgePort {
    fun gamePagePresence(): GameModPagePresence
    fun reloadPrepared(beforeDispatch: () -> Unit, onComplete: (String, Boolean) -> Unit)
}

internal object GameFrameReloadBridgeScript {
    const val objectName = "YahagiGameFrameReload"

    val source: String =
        """
        (() => {
          'use strict';
          if (window.__yahagiGameFrameReloadInstalled) return;
          const bridge = window.YahagiGameFrameReload;
          if (!bridge || typeof bridge.postMessage !== 'function') return;
          window.__yahagiGameFrameReloadInstalled = true;

          const post = (payload) => bridge.postMessage(JSON.stringify(payload));
          const documentId = String(Date.now()) + '-' + String(Math.random());
          window.__yahagiGameFrameReloadDocumentId = documentId;
          let active = true;
          let pageHidden = false;
          let observer;
          let lastAvailability;
          let lastProbeRequestId;
          const reportTarget = (requestId = lastProbeRequestId, force = false) => {
            const available = active && document.getElementById('htmlWrap') !== null;
            if (!force && available === lastAvailability) return;
            lastAvailability = available;
            post({kind: 'target', available: available, requestId: requestId});
          };
          const announceDocument = () => {
            if (window.top === window) post({kind: 'document', documentId: documentId});
          };
          const startObserving = () => {
            if (!active) return;
            reportTarget();
            if (observer) return;
            observer = new MutationObserver(() => reportTarget());
            observer.observe(document.documentElement || document, {
              childList: true, subtree: true, attributes: true, attributeFilter: ['id']
            });
          };
          const probe = (requestId, resume = false) => {
            if (typeof requestId !== 'string' || !requestId ||
                requestId === lastProbeRequestId) return;
            if (!active) {
              if (!resume || pageHidden) return;
              active = true;
              startObserving();
            }
            lastProbeRequestId = requestId;
            reportTarget(requestId, true);
            // Reach current child documents even after native navigation reset.
            for (let index = 0; index < window.frames.length; index++) {
              try {
                window.frames[index].postMessage({kind: 'yahagi-reload-probe', requestId: requestId, resume: true}, '*');
              } catch (_) {}
            }
          };
          const retire = () => {
            if (!active) return;
            active = false;
            lastProbeRequestId = undefined;
            observer?.disconnect();
            observer = undefined;
            reportTarget(undefined, true);
            post({kind: 'retired'});
          };

          bridge.onmessage = (event) => {
            let data;
            try {
              data = typeof event.data === 'string'
                ? JSON.parse(event.data)
                : event.data;
            } catch (_) {
              return;
            }
            if (!data) return;
            if (data.kind === 'probe') {
              const currentDocument = window.top === window && data.documentId === documentId;
              if (data.documentId && !currentDocument) return;
              probe(data.requestId, currentDocument);
              return;
            }
            if (!active || data.kind !== 'reload' || typeof data.requestId !== 'string') {
              return;
            }
            const game = document.getElementById('htmlWrap');
            if (!game) {
              reportTarget(data.requestId, true);
              post({kind: 'result', requestId: data.requestId, result: 'html_wrap_not_found'});
              return;
            }

            let result = 'reloaded';
            try {
              game.contentWindow.location.reload();
            } catch (_) {
              const source = game.getAttribute('src');
              if (!source) {
                result = 'blocked';
              } else {
                game.setAttribute('src', source);
              }
            }
            post({kind: 'result', requestId: data.requestId, result: result});
          };

          window.addEventListener('message', (event) => {
            if (window.top === window || event.source !== window.parent || !event.data ||
                event.data.kind !== 'yahagi-reload-probe') return;
            probe(event.data.requestId, event.data.resume === true);
          });
          window.addEventListener('pagehide', () => {
            pageHidden = true;
            retire();
          });
          window.addEventListener('beforeunload', retire);
          window.addEventListener('pageshow', () => {
            if (active) return;
            pageHidden = false;
            active = true;
            announceDocument();
            startObserving();
            reportTarget(undefined, true);
          });
          announceDocument();
          startObserving();
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => {
              startObserving();
              if (active) reportTarget(undefined, true);
            }, {once: true});
          }
        })();
        """.trimIndent()
}

internal class GameFrameReloadRequestCoordinator(
    private val requestIdFactory: () -> String = { UUID.randomUUID().toString() },
) {
    private var pending: PendingRequest? = null

    val hasPending: Boolean
        get() = pending != null

    fun start(onComplete: (String) -> Unit): String {
        val requestId = requestIdFactory()
        pending = PendingRequest(requestId, onComplete)
        return requestId
    }

    fun complete(requestId: String, result: String): Boolean {
        val active = pending ?: return false
        if (active.requestId != requestId) return false
        pending = null
        active.onComplete(result)
        return true
    }

    fun cancel(result: String): Boolean {
        val active = pending ?: return false
        pending = null
        active.onComplete(result)
        return true
    }

    private data class PendingRequest(
        val requestId: String,
        val onComplete: (String) -> Unit,
    )
}

internal class AndroidGameFrameReloadBridge(
    private val activity: Activity,
    private val originPolicy: CaptureOriginPolicy = CaptureOriginPolicy(),
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
    private val onFrameReloadDispatch: (WebView) -> Unit = {},
    private val onShortcutComplete: (String) -> Unit = {},
) : PreparedGameFrameReloadBridgePort {
    private companion object {
        const val TAG = "GameFrameReload"
        const val RELOAD_TIMEOUT_MILLIS = 5_000L
        const val PROBE_TIMEOUT_MILLIS = 1_000L
    }

    private var attachedWebView: WebView? = null
    private val scriptHandlers = mutableListOf<ScriptHandler>()
    private var listenerInstalled = false
    private val targetFrames: MutableSet<JavaScriptReplyProxy> =
        Collections.newSetFromMap(IdentityHashMap())
    private val frameProxies: MutableSet<JavaScriptReplyProxy> =
        Collections.newSetFromMap(IdentityHashMap())
    private val coordinator = GameFrameReloadRequestCoordinator()
    private var timeoutAction: Runnable? = null
    private var activeRequestId: String? = null
    private var reloadDelivered = false
    private var mainDocumentId: String? = null
    private var mainFrameProxy: JavaScriptReplyProxy? = null
    private var beforeReloadDispatch: (() -> Unit)? = null
    private var canReloadDispatch: (() -> Boolean)? = null
    private var reloadPosted = false

    override fun gamePagePresence(): GameModPagePresence {
        val webViews = mutableListOf<WebView>()
        collectWebViews(activity.window.decorView, webViews)
        return GameModPagePresencePolicy.classify(
            webViews.size, webViews.singleOrNull()?.url, targetFrames.isNotEmpty(),
        )
    }

    override fun isSupported(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) &&
            WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)

    override fun configure() {
        if (!isSupported()) {
            disable()
            return
        }

        val webViews = mutableListOf<WebView>()
        collectWebViews(activity.window.decorView, webViews)
        if (webViews.size != 1) {
            disable()
            Log.w(TAG, "configure expected one WebView, found ${webViews.size}")
            return
        }

        val webView = webViews.single()
        GameMouseWheelBridge.attach(webView)
        val documentScripts = platformGameDocumentStartScripts(
            originPolicy.allowedOriginRules,
        )
        if (attachedWebView === webView &&
            listenerInstalled &&
            scriptHandlers.size == documentScripts.size
        ) {
            return
        }

        disable()
        try {
            WebViewCompat.addWebMessageListener(
                webView,
                GameFrameReloadBridgeScript.objectName,
                originPolicy.allowedOriginRules,
                ::onPostMessage,
            )
            listenerInstalled = true
            documentScripts.forEach { script ->
                scriptHandlers += WebViewCompat.addDocumentStartJavaScript(
                    webView,
                    script.source,
                    script.allowedOriginRules,
                )
            }
            attachedWebView = webView
            Log.i(TAG, "configured frame-level reload bridge")
        } catch (error: RuntimeException) {
            scriptHandlers.forEach(ScriptHandler::remove)
            scriptHandlers.clear()
            disableWebView(webView)
            attachedWebView = null
            Log.w(TAG, "unable to configure frame-level reload bridge", error)
        }
    }

    override fun reload(onComplete: (String) -> Unit) =
        reloadPrepared({}) { result, _ -> onComplete(result) }

    override fun reloadPrepared(beforeDispatch: () -> Unit, onComplete: (String, Boolean) -> Unit) =
        reloadWhen({ true }, beforeDispatch, onComplete)

    fun reloadWhen(
        canDispatch: () -> Boolean,
        beforeDispatch: () -> Unit = {},
        onComplete: (String, Boolean) -> Unit,
    ) {
        if (!canDispatch()) {
            onComplete("blocked", false)
            return
        }
        if (!isSupported()) {
            onComplete("unsupported", false)
            return
        }
        if (attachedWebView == null || !listenerInstalled || scriptHandlers.isEmpty()) {
            onComplete("blocked", false)
            return
        }
        if (coordinator.hasPending) {
            onComplete("blocked", false)
            return
        }

        val mainProxy = mainFrameProxy
        val candidates = if (mainProxy != null) listOf(mainProxy) else frameProxies.toList()
        if (candidates.isEmpty()) {
            onComplete("html_wrap_not_found", false)
            return
        }

        beforeReloadDispatch = beforeDispatch
        canReloadDispatch = canDispatch
        reloadPosted = false
        lateinit var requestId: String
        requestId = coordinator.start { result ->
            val posted = reloadPosted
            cancelTimeout()
            activeRequestId = null
            reloadDelivered = false
            beforeReloadDispatch = null
            canReloadDispatch = null
            reloadPosted = false
            Log.i(TAG, "request=$requestId result=$result")
            onComplete(result, posted)
        }
        activeRequestId = requestId
        Log.i(TAG, "request=$requestId probe candidates=${candidates.size} knownTargets=${targetFrames.size}")
        val payload = JSONObject()
            .put("kind", "probe")
            .put("requestId", requestId)

        armTimeout("html_wrap_not_found", PROBE_TIMEOUT_MILLIS)

        if (mainProxy != null) {
            val webView = attachedWebView ?: return
            val expectedDocumentId = mainDocumentId
            webView.evaluateJavascript("window.__yahagiGameFrameReloadDocumentId || null") { encoded ->
                if (attachedWebView !== webView || activeRequestId != requestId) return@evaluateJavascript
                val currentId = decodeDocumentId(encoded)
                if (currentId == null || currentId != expectedDocumentId) {
                    coordinator.cancel("blocked")
                    return@evaluateJavascript
                }
                if (!postProbe(mainProxy, payload.put("documentId", currentId).toString())) {
                    coordinator.cancel("html_wrap_not_found")
                }
            }
        } else {
            val rawPayload = payload.toString()
            var delivered = false
            for (candidate in candidates) {
                if (postProbe(candidate, rawPayload)) delivered = true
            }
            if (!delivered) coordinator.cancel("html_wrap_not_found")
        }
    }

    override fun dispose() = disable()

    private fun onPostMessage(
        webView: WebView,
        message: WebMessageCompat,
        sourceOrigin: android.net.Uri,
        isMainFrame: Boolean,
        replyProxy: JavaScriptReplyProxy,
    ) {
        if (attachedWebView !== webView || !originPolicy.isAllowed(sourceOrigin.toString())) return
        val payload = try {
            JSONObject(message.data ?: return)
        } catch (_: Exception) {
            return
        }

        when (payload.optString("kind")) {
            "document" -> {
                if (!isMainFrame) return
                val documentId = payload.optString("documentId").takeIf { it.isNotEmpty() } ?: return
                // A queued document-start message must not reset a newer document.
                webView.evaluateJavascript("window.__yahagiGameFrameReloadDocumentId || null") { encoded ->
                    val currentId = decodeDocumentId(encoded)
                    if (attachedWebView !== webView || currentId != documentId) return@evaluateJavascript
                    mainFrameProxy = replyProxy
                    if (mainDocumentId == documentId) return@evaluateJavascript
                    mainDocumentId = documentId
                    targetFrames.clear()
                    frameProxies.clear()
                    frameProxies.add(replyProxy)
                    coordinator.cancel("blocked")
                    Log.i(TAG, "current main document confirmed; frame targets reset")
                }
            }
            "target" -> {
                frameProxies.add(replyProxy)
                if (payload.optBoolean("available", false)) {
                    targetFrames.add(replyProxy)
                } else {
                    targetFrames.remove(replyProxy)
                }
                val requestId = payload.optString("requestId")
                if (requestId.isNotEmpty() && requestId == activeRequestId &&
                    payload.optBoolean("available", false) && !reloadDelivered
                ) {
                    if (canReloadDispatch?.invoke() == false) {
                        coordinator.cancel("blocked")
                        return
                    }
                    reloadDelivered = true
                    armTimeout("blocked", RELOAD_TIMEOUT_MILLIS)
                    try {
                        beforeReloadDispatch?.invoke()
                        beforeReloadDispatch = null
                        onFrameReloadDispatch(webView)
                        replyProxy.postMessage(JSONObject()
                            .put("kind", "reload")
                            .put("requestId", requestId)
                            .toString())
                        reloadPosted = true
                    } catch (_: Exception) {
                        reloadDelivered = false
                        targetFrames.remove(replyProxy)
                        frameProxies.remove(replyProxy)
                        coordinator.cancel("blocked")
                    }
                }
            }
            "retired" -> {
                targetFrames.remove(replyProxy)
                frameProxies.remove(replyProxy)
                // Keep the verified main proxy for a nonce-confirmed canceled-unload probe.
            }
            "result" -> {
                val requestId = payload.optString("requestId")
                val result = payload.optString("result")
                if (requestId.isEmpty() || !reloadDelivered ||
                    result !in setOf("reloaded", "blocked", "html_wrap_not_found")) return
                coordinator.complete(requestId, result)
            }
        }
    }

    private fun disable() {
        cancelTimeout()
        coordinator.cancel("blocked")
        scriptHandlers.forEach(ScriptHandler::remove)
        scriptHandlers.clear()
        attachedWebView?.let(::disableWebView)
        attachedWebView = null
        targetFrames.clear()
        frameProxies.clear()
        mainDocumentId = null
        mainFrameProxy = null
    }

    private fun decodeDocumentId(encoded: String?): String? =
        runCatching { JSONTokener(encoded).nextValue() as? String }.getOrNull()

    private fun postProbe(candidate: JavaScriptReplyProxy, payload: String): Boolean =
        try {
            candidate.postMessage(payload)
            true
        } catch (_: RuntimeException) {
            targetFrames.remove(candidate)
            frameProxies.remove(candidate)
            false
        }

    private fun armTimeout(result: String, delayMillis: Long) {
        cancelTimeout()
        val timeout = Runnable { coordinator.cancel(result) }
        timeoutAction = timeout
        mainHandler.postDelayed(timeout, delayMillis)
    }

    private fun cancelTimeout() {
        timeoutAction?.let(mainHandler::removeCallbacks)
        timeoutAction = null
    }

    private fun disableWebView(webView: WebView) {
        if (listenerInstalled) {
            try {
                WebViewCompat.removeWebMessageListener(
                    webView,
                    GameFrameReloadBridgeScript.objectName,
                )
            } catch (_: RuntimeException) {
                // The old JavaScript context may already have been destroyed.
            }
        }
        listenerInstalled = false
    }

    private fun collectWebViews(view: View, results: MutableList<WebView>) {
        if (view is WebView) results.add(view)
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                collectWebViews(view.getChildAt(index), results)
            }
        }
    }
}
