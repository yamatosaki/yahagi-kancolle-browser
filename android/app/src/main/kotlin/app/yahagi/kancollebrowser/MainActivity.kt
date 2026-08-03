package app.yahagi.kancollebrowser

import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.webkit.WebView
import androidx.core.view.WindowCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import app.yahagi.kancollebrowser.browser.WebViewProxyManager
import app.yahagi.kancollebrowser.browser.GadgetBypassManager
import app.yahagi.kancollebrowser.browser.GadgetBypassWebViewClient
import app.yahagi.kancollebrowser.capture.GameCaptureBridge
import kotlin.math.abs

class MainActivity : FlutterActivity(), GadgetBypassManager.Host {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val attr = window.attributes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else {
                attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
            window.attributes = attr
        }
    }

    private companion object {
        const val GAME_AUDIO_CHANNEL = "app.yahagi.kancollebrowser/game_audio"
        const val GAME_CAPTURE_CHANNEL = "app.yahagi.kancollebrowser/game_capture"
        const val SCALE_CHANNEL = "app.webview/fixed_canvas_scaling"
        const val PROXY_CHANNEL = "app.yahagi.kancollebrowser/network_proxy"
        const val GADGET_BYPASS_CHANNEL = "app.yahagi.kancollebrowser/gadget_bypass"
    }

    private var gameCaptureBridge: GameCaptureBridge? = null
    private var webViewProxyManager: WebViewProxyManager? = null
    private var gadgetBypassManager: GadgetBypassManager? = null
    private var gadgetBypassLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    
    private var boundWebView: WebView? = null
    private var previousFitScale: Float = 0f

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        webViewProxyManager = WebViewProxyManager(context)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROXY_CHANNEL,
        ).setMethodCallHandler(webViewProxyManager)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_AUDIO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(
                    WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO),
                )
                "setMuted" -> {
                    val muted = call.argument<Boolean>("muted")
                    if (muted == null) {
                        result.error("invalid_argument", "muted must be a boolean", null)
                        return@setMethodCallHandler
                    }
                    setGameWebViewMuted(muted, result)
                }
                else -> result.notImplemented()
            }
        }

        val captureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_CAPTURE_CHANNEL,
        )
        gameCaptureBridge = GameCaptureBridge(this, captureChannel)
        captureChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(
                    gameCaptureBridge?.isSupported() == true,
                )
                "configure" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    val script = call.argument<String>("script")
                    if (enabled == null || script == null) {
                        result.error(
                            "invalid_argument",
                            "enabled and script are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    gameCaptureBridge?.configure(enabled, script, result)
                        ?: result.error(
                            "capture_unavailable",
                            "The capture bridge is not available.",
                            null,
                        )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCALE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindFixedCanvas" -> {
                    val contentWidth = call.argument<Int>("contentWidth") ?: 1200
                    val contentHeight = call.argument<Int>("contentHeight") ?: 720
                    setFixedCanvasScaling(contentWidth, contentHeight, result)
                }
                else -> result.notImplemented()
            }
        }

        val bypassManager = GadgetBypassManager(context, this)
        gadgetBypassManager = bypassManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GADGET_BYPASS_CHANNEL,
        ).setMethodCallHandler(bypassManager)
    }

    override fun onDestroy() {
        removeGadgetBypassLayoutListener()
        gameCaptureBridge?.dispose()
        gameCaptureBridge = null
        webViewProxyManager?.dispose()
        webViewProxyManager = null
        gadgetBypassManager = null
        boundWebView = null
        super.onDestroy()
    }

    override fun onBypassEnabledChanged(enabled: Boolean) {
        if (enabled) {
            installGadgetBypassLayoutListener()
            ensureGadgetBypassWrap()
        } else {
            restoreGadgetBypassClient()
            removeGadgetBypassLayoutListener()
        }
    }

    private fun ensureGadgetBypassWrap() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = gadgetBypassManager ?: return
        if (!manager.enabled) return

        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        if (webViews.size != 1) return
        val webView = webViews.single()

        val current = webView.webViewClient ?: return
        if (current is GadgetBypassWebViewClient) return

        Log.d("GadgetBypass", "wrapping WebViewClient")
        webView.setWebViewClient(
            GadgetBypassWebViewClient(
                original = current,
                engine = manager.engine,
                isEnabled = { manager.enabled },
                endpoint = { manager.endpoint },
            ),
        )
    }

    private fun restoreGadgetBypassClient() {
        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        for (webView in webViews) {
            val current = webView.webViewClient
            if (current is GadgetBypassWebViewClient) {
                Log.d("GadgetBypass", "restoring original WebViewClient")
                webView.setWebViewClient(current.originalClient)
            }
        }
    }

    private fun installGadgetBypassLayoutListener() {
        if (gadgetBypassLayoutListener != null) return
        val listener = ViewTreeObserver.OnGlobalLayoutListener {
            ensureGadgetBypassWrap()
        }
        window.decorView.viewTreeObserver.addOnGlobalLayoutListener(listener)
        gadgetBypassLayoutListener = listener
    }

    private fun removeGadgetBypassLayoutListener() {
        gadgetBypassLayoutListener?.let { listener ->
            window.decorView.viewTreeObserver.removeOnGlobalLayoutListener(listener)
        }
        gadgetBypassLayoutListener = null
    }

    private fun setGameWebViewMuted(
        muted: Boolean,
        result: MethodChannel.Result,
    ) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO)) {
            result.error(
                "mute_audio_unsupported",
                "This Android WebView does not support per-WebView audio muting.",
                null,
            )
            return
        }

        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        when (webViews.size) {
            0 -> result.error(
                "webview_not_found",
                "The game WebView is not attached yet.",
                null,
            )
            1 -> {
                try {
                    WebViewCompat.setAudioMuted(webViews.single(), muted)
                    result.success(null)
                } catch (error: RuntimeException) {
                    result.error(
                        "mute_audio_failed",
                        error.message ?: "Unable to change WebView audio state.",
                        null,
                    )
                }
            }
            else -> result.error(
                "multiple_webviews",
                "Expected one game WebView but found ${webViews.size}.",
                null,
            )
        }
    }

    private fun setFixedCanvasScaling(
        contentWidth: Int,
        contentHeight: Int,
        result: MethodChannel.Result,
    ) {
        if (boundWebView != null) {
            // Already bound, scaling is handled by LayoutChangeListener
            result.success(null)
            return
        }
        
        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        when (webViews.size) {
            0 -> result.error(
                "webview_not_found",
                "The game WebView is not attached yet.",
                null,
            )
            1 -> {
                try {
                    val webView = webViews.single()
                    boundWebView = webView
                    
                    webView.settings.useWideViewPort = true
                    webView.settings.loadWithOverviewMode = false
                    webView.settings.builtInZoomControls = true
                    webView.settings.displayZoomControls = false

                    val applyScale = { w: Int, h: Int ->
                        if (w > 0 && h > 0) {
                            val fitScale = java.lang.Float.min(
                                w.toFloat() / contentWidth.toFloat(),
                                h.toFloat() / contentHeight.toFloat()
                            )
                            if (abs(fitScale - previousFitScale) > 0.01f) {
                                previousFitScale = fitScale
                                val initialScalePercent = (fitScale * 100f).toInt()
                                webView.setInitialScale(initialScalePercent)
                            }
                        }
                    }

                    applyScale(webView.width, webView.height)
                    
                    webView.addOnLayoutChangeListener { v, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom ->
                        val w = right - left
                        val h = bottom - top
                        applyScale(w, h)
                    }

                    result.success(null)
                } catch (error: RuntimeException) {
                    result.error(
                        "scaling_failed",
                        error.message ?: "Unable to set WebView scaling.",
                        null,
                    )
                }
            }
            else -> result.error(
                "multiple_webviews",
                "Expected one game WebView but found ${webViews.size}.",
                null,
            )
        }
    }

    private fun collectWebViews(
        view: View,
        results: MutableList<WebView>,
    ) {
        if (view is WebView) {
            results.add(view)
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                collectWebViews(view.getChildAt(index), results)
            }
        }
    }
}
