package app.yahagi.kancollebrowser.nativewebview

import android.annotation.SuppressLint
import android.graphics.Color
import android.os.Build
import android.view.View
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.browser.GameTouchFeedbackScript
import app.yahagi.kancollebrowser.browser.GameMouseWheelBridge

internal enum class NativeGameWebViewConfigurationAction {
    JAVA_SCRIPT_ENABLED,
    DOM_STORAGE_ENABLED,
    DATABASE_ENABLED,
    MEDIA_PLAYBACK_WITHOUT_GESTURE,
    USER_AGENT_SET,
    BACKGROUND_BLACK,
    HARDWARE_LAYER,
    TAP_HIGHLIGHT_SCRIPT_SET,
    ACCEPT_COOKIE,
    ACCEPT_THIRD_PARTY_COOKIES,
    PRESENTATION_BRIDGE_SET,
    WEB_VIEW_CLIENT_SET,
    WEB_CHROME_CLIENT_SET,
}

/** Applies the deliberately narrow configuration used by the native game WebView. */
internal object NativeGameWebViewConfigurator {
    fun configure(
        webView: WebView,
        client: WebViewClient,
        onPresentationStateChanged: (Boolean) -> Unit = {},
        onPresentationPending: () -> Unit = {},
    ) = configureWithPending(webView, client, onPresentationStateChanged, {}, onPresentationPending)

    internal fun configure(
        webView: WebView,
        client: WebViewClient,
        onPresentationStateChanged: (Boolean) -> Unit,
        onApplied: (NativeGameWebViewConfigurationAction) -> Unit,
    ) = configureWithPending(webView, client, onPresentationStateChanged, onApplied, {})

    @SuppressLint("ObsoleteSdkInt", "SetJavaScriptEnabled")
    private fun configureWithPending(
        webView: WebView,
        client: WebViewClient,
        onPresentationStateChanged: (Boolean) -> Unit,
        onApplied: (NativeGameWebViewConfigurationAction) -> Unit,
        onPresentationPending: () -> Unit,
    ) {
        webView.settings.apply {
            javaScriptEnabled = true
            onApplied(NativeGameWebViewConfigurationAction.JAVA_SCRIPT_ENABLED)
            domStorageEnabled = true
            onApplied(NativeGameWebViewConfigurationAction.DOM_STORAGE_ENABLED)
            @Suppress("DEPRECATION")
            databaseEnabled = true
            onApplied(NativeGameWebViewConfigurationAction.DATABASE_ENABLED)
            mediaPlaybackRequiresUserGesture = false
            onApplied(NativeGameWebViewConfigurationAction.MEDIA_PLAYBACK_WITHOUT_GESTURE)
            userAgentString = NativeGameWebViewUserAgent.toDesktop(userAgentString)
            onApplied(NativeGameWebViewConfigurationAction.USER_AGENT_SET)
        }
        GameMouseWheelBridge.attach(webView)
        webView.setBackgroundColor(Color.BLACK)
        onApplied(NativeGameWebViewConfigurationAction.BACKGROUND_BLACK)
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
        onApplied(NativeGameWebViewConfigurationAction.HARDWARE_LAYER)

        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(
                webView,
                GameTouchFeedbackScript.source,
                GameTouchFeedbackScript.allowedOriginRules,
            )
            onApplied(NativeGameWebViewConfigurationAction.TAP_HIGHLIGHT_SCRIPT_SET)
        }

        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            onApplied(NativeGameWebViewConfigurationAction.ACCEPT_COOKIE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                setAcceptThirdPartyCookies(webView, true)
                onApplied(NativeGameWebViewConfigurationAction.ACCEPT_THIRD_PARTY_COOKIES)
            }
        }
        val presentationBridge = NativeGamePresentationBridge(onPresentationStateChanged, onPresentationPending)
        val nativeClient = client as? NativeGameWebViewClient
        nativeClient?.attachPresentationBridge(presentationBridge)
        webView.addJavascriptInterface(
            presentationBridge,
            "YahagiPresentation",
        )
        onApplied(NativeGameWebViewConfigurationAction.PRESENTATION_BRIDGE_SET)
        webView.webViewClient = client
        onApplied(NativeGameWebViewConfigurationAction.WEB_VIEW_CLIENT_SET)
        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                nativeClient?.onPageProgress(view, newProgress)
            }
        }
        onApplied(NativeGameWebViewConfigurationAction.WEB_CHROME_CLIENT_SET)
    }
}

internal class NativeGamePresentationBridge(
    private val onPresentationStateChanged: (Boolean) -> Unit,
    private val onPresentationPending: () -> Unit = {},
) {
    private var lastPresentationState: String? = null

    @Synchronized
    fun resetForNavigation() {
        lastPresentationState = null
    }

    @JavascriptInterface
    @Synchronized
    fun postMessage(message: String) {
        // A fit request is an action, not a state transition. Page finish,
        // fullscreen and window recovery must reapply even for game -> game.
        if (message == "game-fit") {
            lastPresentationState = "game"
            onPresentationStateChanged(true)
            return
        }
        if (message != "game" && message != "web" && message != "pending") return
        if (message == lastPresentationState) return
        lastPresentationState = message
        when (message) {
            "game" -> onPresentationStateChanged(true)
            "web" -> onPresentationStateChanged(false)
            "pending" -> onPresentationPending()
        }
    }
}

internal object NativeGameWebViewUserAgent {
    private val chromePattern = Regex("\\bChrome/[0-9.]+")
    private val appleWebKitPattern = Regex("\\bAppleWebKit/[0-9.]+")
    private val safariPattern = Regex("\\bSafari/[0-9.]+")

    fun toDesktop(current: String): String {
        val chrome = chromePattern.find(current)?.value ?: return current
        val appleWebKit = appleWebKitPattern.find(current)?.value ?: return current
        val safari = safariPattern.find(current)?.value ?: return current
        return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
            "$appleWebKit (KHTML, like Gecko) $chrome $safari"
    }
}
