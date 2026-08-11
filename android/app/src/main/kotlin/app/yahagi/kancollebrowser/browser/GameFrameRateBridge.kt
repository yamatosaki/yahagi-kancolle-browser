package app.yahagi.kancollebrowser.browser

import android.app.Activity
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.capture.CaptureOriginPolicy
import org.json.JSONObject

enum class GameFrameRateTarget(val wireName: String) {
    FPS_30("fps30"),
    FPS_60("fps60");

    companion object {
        fun fromWireName(value: String?): GameFrameRateTarget? =
            entries.firstOrNull { it.wireName == value }
    }
}

internal object GameFrameRateBridgeScript {
    const val objectName = "YahagiFrameRate"

    val source: String =
        """
        (() => {
          'use strict';
          if (window.__yahagiFrameRateBridgeInstalled) return;

          const bridge = window.YahagiFrameRate;
          if (!bridge || typeof bridge.postMessage !== 'function') return;
          window.__yahagiFrameRateBridgeInstalled = true;
          let requestedTarget = 'fps60';

          const applyTarget = () => {
            const ticker = window.createjs && window.createjs.Ticker;
            if (!ticker) return false;
            if (requestedTarget === 'fps30') {
              if (ticker.framerate !== 30) ticker.framerate = 30;
              if (ticker.timingMode !== ticker.TIMEOUT) {
                ticker.timingMode = ticker.TIMEOUT;
              }
            } else {
              if (ticker.framerate !== 60) ticker.framerate = 60;
              if (ticker.timingMode !== ticker.RAF) {
                ticker.timingMode = ticker.RAF;
              }
            }
            return true;
          };

          bridge.onmessage = (event) => {
            try {
              const data = typeof event.data === 'string'
                ? JSON.parse(event.data)
                : event.data;
              if (data && (data.target === 'fps30' || data.target === 'fps60')) {
                requestedTarget = data.target;
                applyTarget();
              }
            } catch (_) {}
          };

          bridge.postMessage(JSON.stringify({kind: 'ready'}));
          window.setInterval(() => {
            if (!applyTarget()) return;
            const ticker = window.createjs && window.createjs.Ticker;
            if (!ticker || typeof ticker.getMeasuredFPS !== 'function') return;
            const fps = Number(ticker.getMeasuredFPS());
            if (Number.isFinite(fps) && fps >= 0) {
              bridge.postMessage(JSON.stringify({kind: 'sample', fps: fps}));
            }
          }, 1000);
        })();
        """.trimIndent()
}

class GameFrameRateBridge(
    private val activity: Activity,
    private val originPolicy: CaptureOriginPolicy = CaptureOriginPolicy(),
) {
    private companion object {
        const val SAMPLE_MAX_AGE_MILLIS = 3_000L
    }

    private var attachedWebView: WebView? = null
    private var scriptHandler: ScriptHandler? = null
    private var listenerInstalled = false
    private var target = GameFrameRateTarget.FPS_60
    private val replyProxies = mutableMapOf<String, JavaScriptReplyProxy>()
    private var latestFps: Double? = null
    private var latestFpsAtMillis = 0L

    fun isSupported(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) &&
            WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)

    @Throws(GameFrameRateBridgeException::class)
    fun configure(target: GameFrameRateTarget) {
        this.target = target
        if (!isSupported()) {
            throw GameFrameRateBridgeException(
                "frame_rate_unsupported",
                "This Android WebView does not support frame-level messaging.",
            )
        }

        val webViews = mutableListOf<WebView>()
        collectWebViews(activity.window.decorView, webViews)
        if (webViews.size != 1) {
            throw GameFrameRateBridgeException(
                if (webViews.isEmpty()) "webview_not_found" else "multiple_webviews",
                "Expected one game WebView but found ${webViews.size}.",
            )
        }

        val webView = webViews.single()
        if (attachedWebView === webView && listenerInstalled && scriptHandler != null) {
            postTargetToAllFrames()
            return
        }

        disable()
        try {
            WebViewCompat.addWebMessageListener(
                webView,
                GameFrameRateBridgeScript.objectName,
                originPolicy.allowedOriginRules,
                ::onPostMessage,
            )
            listenerInstalled = true
            scriptHandler = WebViewCompat.addDocumentStartJavaScript(
                webView,
                GameFrameRateBridgeScript.source,
                originPolicy.allowedOriginRules,
            )
            attachedWebView = webView
        } catch (error: RuntimeException) {
            disableWebView(webView)
            throw GameFrameRateBridgeException(
                "frame_rate_configuration_failed",
                error.message ?: "Unable to configure frame-rate messaging.",
            )
        }
    }

    fun apply(target: GameFrameRateTarget) {
        this.target = target
        postTargetToAllFrames()
    }

    fun measuredFps(): Double? {
        val fps = latestFps ?: return null
        if (SystemClock.elapsedRealtime() - latestFpsAtMillis > SAMPLE_MAX_AGE_MILLIS) {
            return null
        }
        return fps
    }

    fun dispose() = disable()

    @Suppress("UNUSED_PARAMETER")
    private fun onPostMessage(
        webView: WebView,
        message: WebMessageCompat,
        sourceOrigin: android.net.Uri,
        isMainFrame: Boolean,
        replyProxy: JavaScriptReplyProxy,
    ) {
        val origin = sourceOrigin.toString()
        if (!originPolicy.isAllowed(origin)) return
        val payload = try {
            JSONObject(message.data ?: return)
        } catch (_: Exception) {
            return
        }

        replyProxies[origin] = replyProxy
        when (payload.optString("kind")) {
            "ready" -> {
                try {
                    postTarget(replyProxy)
                } catch (_: RuntimeException) {
                    replyProxies.remove(origin)
                }
            }
            "sample" -> {
                val fps = payload.optDouble("fps", Double.NaN)
                if (fps.isFinite() && fps in 0.0..240.0) {
                    latestFps = fps
                    latestFpsAtMillis = SystemClock.elapsedRealtime()
                }
            }
        }
    }

    private fun postTargetToAllFrames() {
        val iterator = replyProxies.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            try {
                postTarget(entry.value)
            } catch (_: RuntimeException) {
                iterator.remove()
            }
        }
    }

    private fun postTarget(replyProxy: JavaScriptReplyProxy) {
        replyProxy.postMessage(JSONObject().put("target", target.wireName).toString())
    }

    private fun disable() {
        val webView = attachedWebView
        scriptHandler?.remove()
        scriptHandler = null
        if (webView != null) disableWebView(webView)
        attachedWebView = null
        replyProxies.clear()
        latestFps = null
        latestFpsAtMillis = 0L
    }

    private fun disableWebView(webView: WebView) {
        if (listenerInstalled) {
            try {
                WebViewCompat.removeWebMessageListener(
                    webView,
                    GameFrameRateBridgeScript.objectName,
                )
            } catch (_: RuntimeException) {
                // Navigation already destroyed the previous JavaScript contexts.
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

class GameFrameRateBridgeException(
    val code: String,
    override val message: String,
) : RuntimeException(message)
