package app.yahagi.kancollebrowser.nativewebview

import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.Point
import android.graphics.Rect
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.MainActivity
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.abs
import kotlin.math.roundToInt

/** Runs a local canvas in the actual Activity host and injects display-coordinate taps. */
@RunWith(AndroidJUnit4::class)
class FullscreenSystemBarsSmokeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var fixture: FrameLayout
    private lateinit var host: ActivityWebViewHost
    private lateinit var webView: WebView
    private var gapTaps = 0

    @Test fun fixedScreenPointsMatchTheSameGameCanvasAcrossSystemBarChanges() {
        scenario = ActivityScenario.launch(MainActivity::class.java)
        try {
            onMain { activity -> activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE }
            await("landscape Activity") {
                onMain { activity ->
                    val root = activity.findViewById<FrameLayout>(android.R.id.content)
                    root.width > root.height && root.height > 0 && activity.window.decorView.hasWindowFocus()
                }
            }
            setBars(top = false, bottom = false)
            awaitBars("initial hide", top = false, bottom = false)
            onMain { activity ->
                fixture = FrameLayout(activity).apply {
                    setBackgroundColor(GAP_COLOR)
                    elevation = 32 * resources.displayMetrics.density
                    isClickable = true
                    setOnClickListener { gapTaps++ }
                }
                activity.findViewById<FrameLayout>(android.R.id.content).addView(
                    fixture,
                    FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
                )
            }
            await("attached fixture") { onMain { fixture.width > fixture.height && fixture.height > 0 } }
            val rootRect = onMain { screenRect(fixture) }
            val width = minOf(rootRect.width().toDouble(), rootRect.height() * (1200.0 / 720.0))
            val height = width * (720.0 / 1200.0)
            val left = (rootRect.width() - width) / 2
            val top = (rootRect.height() - height) / 2
            val expected = Rect(
                rootRect.left + left.roundToInt(),
                rootRect.top + top.roundToInt(),
                rootRect.left + (left + width).roundToInt(),
                rootRect.top + (top + height).roundToInt(),
            )
            val generation = onMain { activity ->
                host = ActivityWebViewHost(activity, fixture, SilentSink)
                val created = requireNotNull(host.create())
                val density = activity.resources.displayMetrics.density.toDouble()
                assertTrue(host.setBounds(created, NativeGameWebViewBounds(
                    left / density, top / density, width / density, height / density, density,
                )))
                assertTrue(host.setVisible(created, true))
                webView = requireNotNull(host.currentWebView)
                webView.settings.blockNetworkLoads = true
                webView.loadDataWithBaseURL("https://fullscreen-smoke.invalid/", CANVAS, "text/html", "UTF-8", null)
                created
            }
            await("local canvas and centred WebView") {
                onMain { screenRect(webView) == expected } && javascript("Boolean(window.gameProbe)") == "true"
            }
            val targets = listOf(
                target(expected, .18, .18, Color.rgb(216, 48, 56)),
                target(expected, .82, .18, Color.rgb(54, 172, 65)),
                target(expected, .18, .82, Color.rgb(54, 100, 214)),
                target(expected, .82, .82, Color.rgb(233, 172, 48)),
                target(expected, .50, .50, Color.WHITE),
            )
            val canvasSize = JSONArray(javascript("[document.querySelector('canvas').clientWidth, document.querySelector('canvas').clientHeight]"))
            // WebView click coordinates are quantized to CSS pixels.
            val xTolerance = 1200.0 / canvasSize.getDouble(0) + 1200.0 / expected.width()
            val yTolerance = 720.0 / canvasSize.getDouble(1) + 720.0 / expected.height()
            val gap = when {
                expected.left - rootRect.left > 24 -> Point((rootRect.left + expected.left) / 2, expected.centerY())
                expected.top - rootRect.top > 200 -> Point(expected.centerX(), (rootRect.top + expected.top) / 2)
                else -> null
            }
            var clickCount = 0
            val baselineClicks = mutableListOf<Pair<Double, Double>>()
            for ((label, topShown, bottomShown) in listOf(
                Triple("hidden", false, false), Triple("status", true, false),
                Triple("both", true, true), Triple("navigation", false, true), Triple("hidden-again", false, false),
            )) {
                setBars(topShown, bottomShown)
                awaitBars(label, topShown, bottomShown)
                repeat(3) {
                    assertGeometry(label, rootRect, expected, generation)
                    SystemClock.sleep(32)
                }
                assertPainted(label, targets, gap)
                for ((index, marker) in targets.withIndex()) {
                    tap(marker.point)
                    clickCount++
                    var last = JSONObject()
                    await("$label marker ${index + 1} receives the fixed display tap") {
                        last = JSONObject(javascript("window.gameProbe"))
                        last.getInt("count") == clickCount
                    }
                    val x = last.getDouble("x")
                    val y = last.getDouble("y")
                    assertEquals("$label marker ${index + 1} logical x", marker.x, x, xTolerance)
                    assertEquals("$label marker ${index + 1} logical y", marker.y, y, yTolerance)
                    if (label == "hidden") {
                        baselineClicks.add(x to y)
                    } else {
                        assertEquals("$label marker ${index + 1} click coordinate", baselineClicks[index], x to y)
                    }
                }
                if (gap != null) {
                    val oldGapTaps = onMain { gapTaps }
                    tap(gap)
                    await("$label side gap receives the display tap outside WebView") { onMain { gapTaps == oldGapTaps + 1 } }
                    assertEquals("$label side gap must not reach the game DOM", clickCount,
                        JSONObject(javascript("window.gameProbe")).getInt("count"))
                }
                assertGeometry(label, rootRect, expected, generation)
                assertEquals("$label status/navigation visibility after the taps", Pair(topShown, bottomShown), bars())
                Log.i("FullscreenBarsSmoke", "phase=$label bars=$topShown/$bottomShown root=$rootRect game=$expected clicks=$clickCount gap=${gap != null}")
            }
        } finally {
            try {
                onMain {
                    if (::host.isInitialized) host.currentGeneration?.let { host.destroy(it) }
                    if (::fixture.isInitialized) (fixture.parent as? ViewGroup)?.removeView(fixture)
                }
            } finally {
                scenario.close()
            }
        }
    }

    private fun assertGeometry(label: String, root: Rect, expected: Rect, generation: Long) = onMain {
        assertEquals("$label Activity content bounds", root, screenRect(fixture))
        assertEquals("$label WebView screen bounds", expected, screenRect(webView))
        assertEquals("$label host generation", generation, host.currentGeneration)
        assertSame("$label keeps the same WebView instance", webView, host.currentWebView)
        assertTrue("$label leaves the game visible", webView.isShown)
    }

    private fun setBars(top: Boolean, bottom: Boolean) = onMain { activity ->
        val status = WindowInsetsCompat.Type.statusBars()
        val navigation = WindowInsetsCompat.Type.navigationBars()
        val shown = (if (top) status else 0) or (if (bottom) navigation else 0)
        val hidden = (if (top) 0 else status) or (if (bottom) 0 else navigation)
        WindowInsetsControllerCompat(activity.window, activity.window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            if (hidden != 0) hide(hidden)
            if (shown != 0) show(shown)
        }
    }

    private fun bars(): Pair<Boolean, Boolean>? = onMain {
        ViewCompat.getRootWindowInsets(it.window.decorView)?.let { insets ->
            Pair(insets.isVisible(WindowInsetsCompat.Type.statusBars()), insets.isVisible(WindowInsetsCompat.Type.navigationBars()))
        }
    }

    private fun awaitBars(label: String, top: Boolean, bottom: Boolean) {
        await("$label real system bars become status=$top/navigation=$bottom") { bars() == Pair(top, bottom) }
    }

    private data class Target(val point: Point, val x: Double, val y: Double, val color: Int)

    private fun target(rect: Rect, x: Double, y: Double, color: Int): Target {
        val dx = (rect.width() * x).roundToInt()
        val dy = (rect.height() * y).roundToInt()
        return Target(Point(rect.left + dx, rect.top + dy), dx * 1200.0 / rect.width(), dy * 720.0 / rect.height(), color)
    }

    private fun assertPainted(label: String, targets: List<Target>, gap: Point?) {
        val pixels = targets.map { it.point to it.color } + listOfNotNull(gap?.let { it to GAP_COLOR })
        await("$label real display paints the complete game and side gap") {
            val bitmap = instrumentation.uiAutomation.takeScreenshot() ?: return@await false
            try {
                pixels.all { (point, color) ->
                    point.x in 0 until bitmap.width && point.y in 0 until bitmap.height &&
                        closeColor(color, bitmap.getPixel(point.x, point.y))
                }
            } finally {
                bitmap.recycle()
            }
        }
    }

    private fun closeColor(expected: Int, actual: Int): Boolean =
        abs(Color.red(expected) - Color.red(actual)) <= 10 &&
            abs(Color.green(expected) - Color.green(actual)) <= 10 &&
            abs(Color.blue(expected) - Color.blue(actual)) <= 10

    private fun tap(point: Point) {
        val downTime = SystemClock.uptimeMillis()
        for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
            val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, point.x.toFloat(), point.y.toFloat(), 0)
            event.source = InputDevice.SOURCE_TOUCHSCREEN
            try {
                assertTrue("Inject actual display tap at $point", instrumentation.uiAutomation.injectInputEvent(event, true))
            } finally {
                event.recycle()
            }
        }
    }

    private fun javascript(script: String): String {
        val result = AtomicReference<String>()
        val done = CountDownLatch(1)
        onMain { webView.evaluateJavascript(script) { result.set(it); done.countDown() } }
        assertTrue("Local WebView should answer JavaScript", done.await(4, TimeUnit.SECONDS))
        return result.get()
    }

    private fun screenRect(view: View): Rect {
        val origin = IntArray(2).also { view.getLocationOnScreen(it) }
        return Rect(origin[0], origin[1], origin[0] + view.width, origin[1] + view.height)
    }

    private fun await(label: String, condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 10_000
        while (SystemClock.uptimeMillis() < deadline) {
            if (condition()) return
            SystemClock.sleep(45)
        }
        throw AssertionError("Timed out waiting for $label; bars=${bars()}")
    }

    private fun <T> onMain(action: (MainActivity) -> T): T {
        val result = AtomicReference<T>()
        scenario.onActivity { result.set(action(it)) }
        return result.get()
    }

    private object SilentSink : NativeGameWebViewEventSink {
        override fun created(generation: Long) = Unit
        override fun pageStarted(generation: Long, url: String) = Unit
        override fun pageFinished(generation: Long, url: String) = Unit
        override fun mainFrameError(generation: Long, errorCode: Int, description: String) = Unit
        override fun navigationBlocked(generation: Long, scheme: String) = Unit
        override fun renderProcessGone(generation: Long, didCrash: Boolean) = Unit
        override fun destroyed(generation: Long) = Unit
    }

    companion object {
        private val GAP_COLOR = Color.rgb(20, 24, 30)
        private const val CANVAS = """
            <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>html,body{margin:0;overflow:hidden}canvas{display:block;width:100vw;height:100vh;touch-action:none}</style>
            <canvas width="1200" height="720"></canvas>
            <script>
              const canvas = document.querySelector('canvas'), context = canvas.getContext('2d');
              [['#d83038',0,0],['#36ac41',600,0],['#3664d6',0,360],['#e9ac30',600,360]].forEach(([color,x,y])=>{
                context.fillStyle=color; context.fillRect(x,y,600,360);
              });
              context.fillStyle='#fff'; context.fillRect(565,325,70,70);
              window.gameProbe={count:0,x:0,y:0};
              canvas.addEventListener('click', (event)=>{
                const r=canvas.getBoundingClientRect();
                window.gameProbe={count:window.gameProbe.count+1,
                  x:(event.clientX-r.left)*1200/r.width,y:(event.clientY-r.top)*720/r.height};
              });
            </script>
        """
    }
}
