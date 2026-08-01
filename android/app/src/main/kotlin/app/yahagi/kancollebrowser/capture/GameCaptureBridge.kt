package app.yahagi.kancollebrowser.capture

import android.app.Activity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.MethodChannel

class GameCaptureBridge(
    private val activity: Activity,
    private val channel: MethodChannel,
    private val originPolicy: CaptureOriginPolicy = CaptureOriginPolicy(),
    private val validator: CaptureMessageValidator = CaptureMessageValidator(),
) {
    private companion object {
        const val MESSAGE_OBJECT_NAME = "YahagiNativeCapture"
    }

    private var attachedWebView: WebView? = null
    private var scriptHandler: ScriptHandler? = null
    private var listenerInstalled = false

    fun isSupported(): Boolean {
        return WebViewFeature.isFeatureSupported(
            WebViewFeature.DOCUMENT_START_SCRIPT,
        ) && WebViewFeature.isFeatureSupported(
            WebViewFeature.WEB_MESSAGE_LISTENER,
        )
    }

    fun configure(
        enabled: Boolean,
        script: String,
        result: MethodChannel.Result,
    ) {
        if (!enabled) {
            disable()
            result.success(null)
            return
        }
        if (!isSupported()) {
            result.error(
                "capture_unsupported",
                "This Android WebView does not support document-start capture.",
                null,
            )
            return
        }
        if (script.isBlank()) {
            result.error(
                "invalid_capture_script",
                "The capture script must not be empty.",
                null,
            )
            return
        }

        val webViews = mutableListOf<WebView>()
        collectWebViews(activity.window.decorView, webViews)
        if (webViews.size != 1) {
            result.error(
                if (webViews.isEmpty()) {
                    "webview_not_found"
                } else {
                    "multiple_webviews"
                },
                "Expected one game WebView but found ${webViews.size}.",
                null,
            )
            return
        }

        val webView = webViews.single()
        if (attachedWebView === webView &&
            listenerInstalled &&
            scriptHandler != null
        ) {
            result.success(null)
            return
        }

        disable()
        try {
            WebViewCompat.addWebMessageListener(
                webView,
                MESSAGE_OBJECT_NAME,
                originPolicy.allowedOriginRules,
                ::onPostMessage,
            )
            listenerInstalled = true
            scriptHandler = WebViewCompat.addDocumentStartJavaScript(
                webView,
                script,
                originPolicy.allowedOriginRules,
            )
            attachedWebView = webView
            result.success(null)
        } catch (error: RuntimeException) {
            disableWebView(webView)
            result.error(
                "capture_configuration_failed",
                error.message ?: "Unable to configure game capture.",
                null,
            )
        }
    }

    fun dispose() {
        disable()
    }

    @Suppress("UNUSED_PARAMETER")
    private fun onPostMessage(
        webView: WebView,
        message: WebMessageCompat,
        sourceOrigin: android.net.Uri,
        isMainFrame: Boolean,
        replyProxy: androidx.webkit.JavaScriptReplyProxy,
    ) {
        val origin = sourceOrigin.toString()
        if (!originPolicy.isAllowed(origin)) {
            return
        }
        val messageData = message.data ?: return
        val event = validator.validate(messageData, origin) ?: return
        activity.runOnUiThread {
            channel.invokeMethod("onCaptureEvent", event)
        }
    }

    private fun disable() {
        val webView = attachedWebView
        scriptHandler?.remove()
        scriptHandler = null
        if (webView != null) {
            disableWebView(webView)
        }
        attachedWebView = null
    }

    private fun disableWebView(webView: WebView) {
        if (listenerInstalled) {
            try {
                WebViewCompat.removeWebMessageListener(
                    webView,
                    MESSAGE_OBJECT_NAME,
                )
            } catch (_: RuntimeException) {
                // A page reload still destroys the old JavaScript context.
            }
        }
        listenerInstalled = false
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
