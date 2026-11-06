package app.yahagi.kancollebrowser

import android.app.Activity
import android.graphics.Point
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.WindowInsets
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/** Publishes window topology only after the last real bounds change settles. */
internal class GameWindowLayoutChannel(
    private val activity: Activity,
    engine: FlutterEngine,
) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
    private val handler = Handler(Looper.getMainLooper())
    private val policy = GameWindowLayoutPolicy()
    private val settler = GameWindowLayoutSettler<Geometry>(SETTLE_MILLIS)
    private val decor = activity.window.decorView
    private var disposed = false
    private var publishedGeometry: Geometry? = null
    private var publishedLayout: GameWindowLayout? = null
    private var pendingAction: Runnable? = null
    private val layoutListener = ViewTreeObserver.OnGlobalLayoutListener { refresh() }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "getWindowLayout") {
                refresh()
                val geometry = readGeometry()
                result.success(message(geometry, publishedLayout ?: unknownLayout(geometry),
                    pendingAction == null && geometry == publishedGeometry))
            } else {
                result.notImplemented()
            }
        }
        decor.viewTreeObserver.addOnGlobalLayoutListener(layoutListener)
        refresh()
    }

    fun refresh() {
        if (disposed || activity.isFinishing || activity.isDestroyed) return
        val geometry = readGeometry()
        val decision = settler.observe(geometry, SystemClock.uptimeMillis())
        if (decision.changing) {
            pendingAction?.let(handler::removeCallbacks)
            pendingAction = null
            channel.invokeMethod("windowLayoutChanged", message(geometry, publishedLayout ?: unknownLayout(geometry), false))
        }
        if (decision.stable) {
            pendingAction?.let(handler::removeCallbacks)
            pendingAction = null
            publishedGeometry = geometry
            val next = policy.classify(
                geometry.current,
                geometry.maximum,
                geometry.multiWindow,
                geometry.pictureInPicture,
                geometry.tolerancePx,
            )
            Log.d("GameWindowLayout", "Stable ${next.mode.wireValue}: current=${geometry.current}, maximum=${geometry.maximum}")
            publishedLayout = next
            // A resize with the same topology must also release Dart's
            // stability gate with the corresponding final physical dimensions.
            channel.invokeMethod("windowLayoutChanged", message(geometry, next, true))
            return
        }
        val delay = decision.retryAfterMillis ?: return
        if (pendingAction == null) {
            val action = Runnable {
                pendingAction = null
                refresh()
            }
            pendingAction = action
            handler.postDelayed(action, delay)
        }
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        pendingAction?.let(handler::removeCallbacks)
        pendingAction = null
        if (decor.viewTreeObserver.isAlive) decor.viewTreeObserver.removeOnGlobalLayoutListener(layoutListener)
        channel.setMethodCallHandler(null)
    }

    private fun unknownLayout(geometry: Geometry) = GameWindowLayout(
        GameWindowMode.UNKNOWN, geometry.maximum.width > geometry.maximum.height,
    )

    private fun message(geometry: Geometry, layout: GameWindowLayout, stable: Boolean): Map<String, Any> =
        layout.toMap() + mapOf(
            "stable" to stable,
            "windowWidth" to geometry.current.width,
            "windowHeight" to geometry.current.height,
        ) + geometry.stableInsets?.toMap().orEmpty()

    private fun readGeometry(): Geometry {
        val density = activity.resources.displayMetrics.density
        val multiWindow = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && activity.isInMultiWindowMode
        val pictureInPicture = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && activity.isInPictureInPictureMode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val currentMetrics = activity.windowManager.currentWindowMetrics
            val current = currentMetrics.bounds
            val maximum = activity.windowManager.maximumWindowMetrics.bounds
            val bounds = GameWindowBounds(current.left, current.top, current.width(), current.height())
            // WindowMetrics bounds include bar areas even when the FlutterView
            // has already been laid out inside them. Never include Type.ime().
            val insets = currentMetrics.windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            return Geometry(
                bounds,
                GameWindowBounds(maximum.left, maximum.top, maximum.width(), maximum.height()),
                multiWindow,
                pictureInPicture,
                (density * 8).roundToInt().coerceAtLeast(2),
                sampleStableInsets(bounds, GameWindowStableInsets(insets.left, insets.top, insets.right, insets.bottom)),
            )
        }
        // Older releases expose only the laid-out decor area and display.
        // Keep the legacy topology tolerance; MainActivity requests edge-to-edge decor.
        val size = Point()
        @Suppress("DEPRECATION")
        activity.windowManager.defaultDisplay.getRealSize(size)
        val location = IntArray(2)
        decor.getLocationOnScreen(location)
        val bounds = GameWindowBounds(location[0], location[1], decor.width, decor.height)
        return Geometry(
            bounds,
            GameWindowBounds(0, 0, size.x, size.y),
            multiWindow,
            pictureInPicture,
            (density * 64).roundToInt().coerceAtLeast(2),
            sampleStableInsets(bounds, readLegacyStableInsets() ?: GameWindowStableInsets(0, 0, 0, 0)),
        )
    }

    @Suppress("DEPRECATION")
    private fun readLegacyStableInsets(): GameWindowStableInsets? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        val insets = decor.rootWindowInsets ?: return null
        val cutout = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) insets.displayCutout else null
        // MainActivity lays out its decor edge to edge. Root stable insets are
        // independent of bar visibility and never use the IME/visible frame.
        return GameWindowStableInsets(
            maxOf(0, insets.stableInsetLeft, cutout?.safeInsetLeft ?: 0),
            maxOf(0, insets.stableInsetTop, cutout?.safeInsetTop ?: 0),
            maxOf(0, insets.stableInsetRight, cutout?.safeInsetRight ?: 0),
            maxOf(0, insets.stableInsetBottom, cutout?.safeInsetBottom ?: 0),
        )
    }

    private fun sampleStableInsets(
        bounds: GameWindowBounds,
        insets: GameWindowStableInsets,
    ): GameWindowStableInsetsSample? {
        val flutterView = findAttachedFlutterView(decor) ?: return null
        val location = IntArray(2)
        flutterView.getLocationOnScreen(location)
        return GameWindowStableInsetsSample(
            bounds,
            insets,
            GameWindowBounds(location[0], location[1], flutterView.width, flutterView.height),
        )
    }

    private fun findAttachedFlutterView(view: View): FlutterView? {
        if (view is FlutterView && view.isAttachedToWindow && view.width > 0 && view.height > 0) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findAttachedFlutterView(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    private data class Geometry(
        val current: GameWindowBounds,
        val maximum: GameWindowBounds,
        val multiWindow: Boolean,
        val pictureInPicture: Boolean,
        val tolerancePx: Int,
        val stableInsets: GameWindowStableInsetsSample?,
    )

    private companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/window_layout"
        const val SETTLE_MILLIS = 200L
    }
}
