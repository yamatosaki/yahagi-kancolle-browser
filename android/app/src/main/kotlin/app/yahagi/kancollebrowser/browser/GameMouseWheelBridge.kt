package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.content.SharedPreferences
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import java.lang.ref.WeakReference
import app.yahagi.kancollebrowser.R
import org.json.JSONObject

/** One bridge per WebView, shared by the native and Flutter input paths. */
internal class GameMouseWheelBridge private constructor(webView: WebView) {
    private val view = WeakReference(webView)
    private val preferences = webView.context.getSharedPreferences(
        "FlutterSharedPreferences", Context.MODE_PRIVATE,
    )
    private class Frame(val token: String, val origin: String, val reply: JavaScriptReplyProxy) {
        // null while an enable reply is in flight; false only after the frame found no canvas.
        var available: Boolean? = false
    }
    private val frames = linkedMapOf<String, Frame>()
    private var lastActiveToken: String? = null
    private var enabled = false
    private var revision = 0
    private var listening = false
    private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        if (key == PREFERENCE || key == null) refreshPreference()
    }
    private val attachmentListener = object : View.OnAttachStateChangeListener {
        override fun onViewAttachedToWindow(view: View) = startListening()
        override fun onViewDetachedFromWindow(view: View) {
            preferences.unregisterOnSharedPreferenceChangeListener(preferenceListener)
            listening = false
            setEnabled(false)
        }
    }

    companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/game_mouse_wheel"
        private const val PREFERENCE = "flutter.game.mouseWheelCompatibility"

        fun attach(webView: WebView) {
            if (webView.getTag(R.id.game_mouse_wheel_bridge) != null ||
                !WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) ||
                !WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) return
            val bridge = GameMouseWheelBridge(webView)
            try {
                WebViewCompat.addWebMessageListener(
                    webView, GameMouseWheelScript.objectName, GameMouseWheelScript.origins,
                ) { _, message, origin, _, reply ->
                    if (origin.scheme != "https" ||
                        origin.host?.endsWith(".kancolle-server.com") != true) return@addWebMessageListener
                    val data = runCatching { message.data }.getOrNull()
                        ?.takeIf { it.length <= 1_024 } ?: return@addWebMessageListener
                    val payload = runCatching { JSONObject(data) }.getOrNull()
                        ?: return@addWebMessageListener
                    val frameToken = payload.optString("token").takeIf { it.length in 1..100 }
                        ?: return@addWebMessageListener
                    bridge.onMessage(payload, frameToken, origin.toString(), reply)
                }
                WebViewCompat.addDocumentStartJavaScript(
                    webView, GameMouseWheelScript.source, GameMouseWheelScript.origins,
                )
                webView.setOnGenericMotionListener { _, event -> bridge.onMotion(event) }
                webView.setTag(R.id.game_mouse_wheel_bridge, bridge)
                webView.addOnAttachStateChangeListener(bridge.attachmentListener)
                if (webView.isAttachedToWindow) bridge.startListening()
            } catch (_: RuntimeException) {
                // Optional input compatibility must not prevent game startup.
                runCatching {
                    WebViewCompat.removeWebMessageListener(webView, GameMouseWheelScript.objectName)
                }
            }
        }

        fun forward(webView: WebView, x: Double, y: Double, dx: Double, dy: Double): Boolean =
            (webView.getTag(R.id.game_mouse_wheel_bridge) as? GameMouseWheelBridge)
                ?.send(x, y, dx, dy) ?: false
    }

    private fun startListening() {
        if (!listening) {
            preferences.registerOnSharedPreferenceChangeListener(preferenceListener)
            listening = true
        }
        refreshPreference()
    }

    private fun refreshPreference() {
        setEnabled(view.get()?.isAttachedToWindow == true && preferences.getBoolean(PREFERENCE, false))
    }

    private fun setEnabled(value: Boolean) {
        if (enabled == value) return
        enabled = value
        revision++
        frames.values.toList().forEach(::configure)
    }

    private fun configure(frame: Frame) {
        frame.available = if (enabled) null else false
        try {
            frame.reply.postMessage(JSONObject().put("kind", "configure").put("token", frame.token)
                .put("enabled", enabled).put("revision", revision).toString())
        } catch (_: RuntimeException) {
            removeFrame(frame.token)
        }
    }

    private fun removeFrame(token: String) {
        frames.remove(token)
        if (lastActiveToken == token) lastActiveToken = null
    }

    private fun onMessage(payload: JSONObject, token: String, origin: String, reply: JavaScriptReplyProxy) {
        if (payload.optString("kind") == "ready") {
            refreshPreference()
            // A proxy belongs to one document. Keep dormant endpoints so enabling needs no reload.
            frames.values.filter { it.reply === reply && it.token != token }
                .forEach { removeFrame(it.token) }
            val existing = frames[token]
            if (existing != null && (existing.reply !== reply || existing.origin != origin)) return
            if (existing == null && frames.size >= 8) removeFrame(frames.keys.first())
            val frame = existing ?: Frame(token, origin, reply).also { frames[token] = it }
            configure(frame)
            return
        }
        val frame = frames[token] ?: return
        if (frame.reply !== reply || frame.origin != origin) return
        when (payload.optString("kind")) {
            "gone" -> removeFrame(token)
            "availability" -> {
                if (!enabled || payload.optInt("revision", -1) != revision) return
                val available = payload.opt("available") as? Boolean ?: return
                frame.available = available
                if (available) lastActiveToken = token
                else if (lastActiveToken == token) lastActiveToken = null
            }
        }
    }

    private fun onMotion(event: MotionEvent): Boolean {
        if (event.actionMasked != MotionEvent.ACTION_SCROLL ||
            !event.isFromSource(InputDevice.SOURCE_MOUSE) ||
            event.metaState and KeyEvent.META_CTRL_ON != 0) return false
        val webView = view.get() ?: return false
        if (webView.width <= 0 || webView.height <= 0) return false
        // Android's positive vertical axis points up; DOM deltaY points down.
        return send(
            event.x.toDouble() / webView.width,
            event.y.toDouble() / webView.height,
            -event.getAxisValue(MotionEvent.AXIS_HSCROLL).toDouble() * 120.0,
            -event.getAxisValue(MotionEvent.AXIS_VSCROLL).toDouble() * 120.0,
        )
    }

    private fun send(x: Double, y: Double, dx: Double, dy: Double): Boolean {
        if (!preferences.getBoolean(PREFERENCE, false) ||
            !GameMouseWheelPolicy.accepts(x, y, dx, dy)) return false
        val webView = view.get() ?: return false
        if (!webView.isAttachedToWindow || !webView.isShown ||
            !webView.hasWindowFocus() || webView.width <= 0 || webView.height <= 0) return false
        // A preference write and the first wheel may share a UI turn. Configure first, then
        // deliver through the same ordered reply channel without waiting for an availability round trip.
        refreshPreference()
        val lastActive = lastActiveToken?.let(frames::get)
        val frame = lastActive?.takeIf { it.available == true }
            ?: frames.values.lastOrNull { it.available == true }
            ?: lastActive?.takeIf { it.available == null }
            ?: frames.values.lastOrNull { it.available == null }
            ?: return false
        if (frame.available == true) lastActiveToken = frame.token
        return try {
            frame.reply.postMessage(JSONObject().put("kind", "wheel").put("token", frame.token)
                .put("x", x).put("y", y).put("deltaX", dx).put("deltaY", dy).toString())
            true // Do not also let WebView dispatch the same native wheel.
        } catch (_: RuntimeException) {
            removeFrame(frame.token)
            false
        }
    }
}

internal object GameMouseWheelPolicy {
    fun accepts(x: Double, y: Double, dx: Double, dy: Double): Boolean =
        x.isFinite() && y.isFinite() && dx.isFinite() && dy.isFinite() &&
            x >= 0 && x < 1 && y >= 0 && y < 1 && dy != 0.0
}
