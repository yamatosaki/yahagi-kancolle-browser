package app.yahagi.kancollebrowser.browser

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/** Fits a stable viewport once, sharing the result with overlapping callers. */
internal class FixedCanvasScaleApplier(
    private val documentClient: (WebView) -> WebViewClient? = { webView ->
        if (WebViewFeature.isFeatureSupported(WebViewFeature.GET_WEB_VIEW_CLIENT)) WebViewCompat.getWebViewClient(webView)
        else null
    },
) {
    private data class FitKey(
        val webView: WebView,
        val documentUrl: String?,
        val documentClient: WebViewClient?,
        val documentEpoch: Long?,
        val unobservedDocumentRequest: Long?,
        val viewportWidth: Int,
        val viewportHeight: Int,
        val scalePercent: Int,
        val contentWidth: Int,
        val contentHeight: Int,
    )

    private val handler = Handler(Looper.getMainLooper())
    private val requests = FixedCanvasFitRequests<FitKey>()
    private var runningRequest: FixedCanvasFitRequests.Request<FitKey>? = null
    private var unobservedDocumentRequest = 0L

    fun cancel() = requests.cancel()

    fun apply(
        webView: WebView,
        viewportWidth: Int,
        scalePercent: Int,
        contentWidth: Int,
        contentHeight: Int,
        isCurrent: () -> Boolean,
        onComplete: (Result<Boolean>) -> Unit,
    ) {
        val key = try {
            val viewportHeight = webView.height
            require(viewportWidth > 0 && viewportHeight > 0 && scalePercent > 0 && contentWidth > 0 && contentHeight > 0)
            val client = documentClient(webView)
            // Without a client getter, equal URLs cannot establish that two
            // calls belong to the same document. Let the latest call settle.
            FitKey(webView, webView.url, client, (client as? GadgetBypassWebViewClient)?.documentEpoch,
                if (client == null) ++unobservedDocumentRequest else null,
                viewportWidth, viewportHeight, scalePercent, contentWidth, contentHeight)
        } catch (error: RuntimeException) {
            cancel()
            onComplete(Result.failure(error))
            return
        }
        val request = requests.begin(key, {
            isCurrent() && webView.url == key.documentUrl && documentClient(webView) === key.documentClient &&
                (key.documentClient as? GadgetBypassWebViewClient)?.documentEpoch == key.documentEpoch && webView.width == key.viewportWidth &&
                webView.height == key.viewportHeight
        }, onComplete)
        if (request === runningRequest) return
        runningRequest = request

        var timeout: Runnable? = null
        var preparation: Runnable? = null
        var alignment: Runnable? = null
        request.onFinish = {
            timeout?.let(handler::removeCallbacks)
            preparation?.let(handler::removeCallbacks)
            alignment?.let(handler::removeCallbacks)
            if (runningRequest === request) runningRequest = null
        }
        fun finish(outcome: Result<Boolean>) = requests.finish(request, outcome)
        fun current() = requests.isCurrent(request)

        try {
            if (!current()) {
                finish(Result.success(false))
                return
            }
            val targetScale = min(
                viewportWidth.toDouble() / contentWidth,
                key.viewportHeight.toDouble() / contentHeight,
            )
            val calibration = FixedCanvasCalibration(targetScale, max(contentWidth, contentHeight))
            val timeoutAction = Runnable {
                val outcome = try {
                    if (!current()) Result.success(false)
                    else Result.failure(IllegalStateException("Game fitting timed out."))
                } catch (error: RuntimeException) {
                    Result.failure<Boolean>(error)
                }
                finish(outcome)
            }
            timeout = timeoutAction
            if (!handler.postDelayed(timeoutAction, 3_000L)) {
                finish(Result.success(false))
                return
            }

            fun alignPrecisely() {
                try {
                    if (!current()) {
                        finish(Result.success(false))
                        return
                    }
                    // WebView.getScale() can still cache the preceding page
                    // scale. Read geometry from Chromium's visual viewport.
                    webView.evaluateJavascript("""
                        (() => {
                          if (window.__yahagiMobileReadPresentation?.() !== 'game') return null;
                          const viewport = window.visualViewport;
                          return viewport ? {scale: viewport.scale * window.devicePixelRatio, x: viewport.offsetLeft, y: viewport.offsetTop} : null;
                        })();
                    """.trimIndent()) { value ->
                        try {
                            if (!current() || value == "null") {
                                finish(Result.success(false))
                                return@evaluateJavascript
                            }
                            val viewport = JSONObject(value)
                            val actualScale = viewport.getDouble("scale")
                            val offset = max(abs(viewport.getDouble("x")), abs(viewport.getDouble("y"))) * actualScale
                            when (val action = calibration.sample(SystemClock.uptimeMillis(), actualScale, offset)) {
                                FixedCanvasCalibration.Action.Complete -> {
                                    finish(Result.success(true))
                                    return@evaluateJavascript
                                }
                                FixedCanvasCalibration.Action.Unresolved -> {
                                    Log.d("FixedCanvasScale", "Fit did not converge: viewport=${key.viewportWidth}x${key.viewportHeight}, target=$targetScale, actual=$actualScale, offset=$offset")
                                    finish(Result.success(false))
                                    return@evaluateJavascript
                                }
                                is FixedCanvasCalibration.Action.Zoom -> webView.zoomBy(action.factor)
                                FixedCanvasCalibration.Action.ResetScroll -> webView.scrollTo(0, 0)
                                FixedCanvasCalibration.Action.Wait -> Unit
                            }
                            val retry = Runnable { alignPrecisely() }
                            alignment = retry
                            if (!handler.postDelayed(retry, 80L)) finish(Result.success(false))
                        } catch (error: Exception) {
                            finish(Result.failure(error as? RuntimeException
                                ?: IllegalStateException("Unable to read game viewport.", error)))
                        }
                    }
                } catch (error: RuntimeException) {
                    finish(Result.failure(error))
                }
            }

            // Chromium rounds the viewport in density-independent pixels
            // before applying its minimum zoom. Keep the exact fit attainable.
            val density = webView.resources.displayMetrics.density.toDouble()
            val roundedViewportWidth = ceil(viewportWidth / density) * density
            val minimumWidth = max(
                contentWidth.toDouble(),
                ceil((roundedViewportWidth + density) * 100.0 / scalePercent) + 1.0,
            ).toLong()
            val prepare = """
                (() => {
                  const style = document.getElementById('__yahagi_mobile_fixed_canvas__');
                  if (!style || window.__yahagiMobileReadPresentation?.() !== 'game') return false;
                  const rule = style.sheet?.cssRules[0];
                  if (rule?.selectorText !== 'html, body') return false;
                  // CSSOM edits preserve textContent, so runtime reinjection
                  // keeps this rule. Removing the game style releases it.
                  rule.style.setProperty('min-width', '${minimumWidth}px', 'important');
                  rule.style.setProperty('background', '#000', 'important');
                  const sheet = style.sheet;
                  let bodyRule = Array.from(sheet.cssRules).find((entry) => entry.selectorText === 'body');
                  if (!bodyRule) bodyRule = sheet.cssRules[sheet.insertRule('body {}', sheet.cssRules.length)];
                  bodyRule.style.setProperty('clip-path', 'polygon(0 0, ${contentWidth}px 0, ${contentWidth}px ${contentHeight}px, 0 ${contentHeight}px)', 'important');
                  return true;
                })();
            """.trimIndent()
            val prepareAction = Runnable {
                try {
                    if (!current()) {
                        finish(Result.success(false))
                        return@Runnable
                    }
                    webView.evaluateJavascript(prepare) { prepared ->
                        if (!handler.post {
                            try {
                                if (!current() || prepared != "true") finish(Result.success(false))
                                else alignPrecisely()
                            } catch (error: RuntimeException) {
                                finish(Result.failure(error))
                            }
                        }) finish(Result.success(false))
                    }
                } catch (error: RuntimeException) {
                    finish(Result.failure(error))
                }
            }
            preparation = prepareAction
            // A changed viewport creates a new request and restarts this wait.
            // Joining the same request does not postpone an already stable fit.
            if (!handler.postDelayed(prepareAction, 180L)) finish(Result.success(false))
        } catch (error: RuntimeException) {
            finish(Result.failure(error))
        }
    }
}
