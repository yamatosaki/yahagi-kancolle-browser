package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.webkit.ValueCallback
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FixedCanvasResizeTest {
    @Test
    fun actualApplierFitsRepeatedWindowAndFullscreenChangesWithoutReload() = withGame { game ->
        for (width in listOf(1200, 600, 1200, 1500, 900, 600, 600)) {
            val completed = CountDownLatch(1)
            var outcome: Result<Boolean>? = null
            var zoomsBefore = 0
            onMain {
                zoomsBefore = game.view.zoomTimes.size
                game.view.layout(0, 0, width, width * 3 / 5)
                game.fit { outcome = it; completed.countDown() }
            }
            assertTrue("Fit completed for width $width", completed.await(5, TimeUnit.SECONDS))
            val viewport = game.viewport()
            assertTrue("Fit succeeded for width $width: $outcome, $viewport", outcome!!.getOrThrow())
            assertEquals("Canvas fits width $width", width / 1200.0, viewport.getDouble("scale"), 1.0 / 1200)
            assertTrue("Fit uses at most two zoom corrections", game.view.zoomTimes.size - zoomsBefore <= 2)
        }
        assertEquals("Fitting never reloads the document", 1, game.pageFinishes)
        assertTrue("Fitting never nudges the canvas away from its origin", game.view.scrollPositions.all { it == (0 to 0) })
    }

    @Test
    fun identicalActiveRequestsShareOneFitAfterBoundsSettle() = withGame { game ->
        val completed = CountDownLatch(2)
        val outcomes = mutableListOf<Result<Boolean>>()
        var requestedAt = 0L
        onMain {
            game.view.layout(0, 0, 600, 360)
            requestedAt = SystemClock.uptimeMillis()
            repeat(2) {
                game.fit { outcomes += it; completed.countDown() }
            }
        }
        assertTrue("Both fit callers completed: $outcomes", completed.await(8, TimeUnit.SECONDS))
        assertTrue("Both callers receive the shared successful fit: $outcomes", outcomes.all { it.getOrThrow() })
        assertEquals("Joined callers prepare the document once", 1, game.view.prepareTimes.size)
        assertTrue("Fitting waits for stable bounds", game.view.prepareTimes.first() - requestedAt >= 180L)
        assertTrue("Joined callers do not repeat zoom work", game.view.zoomTimes.size <= 2)
    }

    @Test
    fun unavailableDocumentIdentityWaitsForTheLatestRequestWithoutJoiningTheOldCaller() =
        withGame(FixedCanvasScaleApplier(documentClient = { null })) { game ->
            val completed = CountDownLatch(2)
            var obsolete: Result<Boolean>? = null
            var latest: Result<Boolean>? = null
            var latestRequestedAt = 0L
            onMain {
                game.view.layout(0, 0, 600, 360)
                game.fit { obsolete = it; completed.countDown() }
                Handler(Looper.getMainLooper()).postDelayed({
                    latestRequestedAt = SystemClock.uptimeMillis()
                    game.fit { latest = it; completed.countDown() }
                }, 80)
            }

            assertTrue("Both callers completed", completed.await(5, TimeUnit.SECONDS))
            assertEquals(false, obsolete!!.getOrThrow())
            assertEquals(true, latest!!.getOrThrow())
            assertEquals(1, game.view.prepareTimes.size)
            assertTrue("Unknown identity settles from the latest call", game.view.prepareTimes.first() - latestRequestedAt >= 180L)
        }

    @Test
    fun changedPendingBoundsCancelOnlyTheOldFit() = withGame { game ->
        val completed = CountDownLatch(2)
        var obsolete: Result<Boolean>? = null
        var latest: Result<Boolean>? = null
        var finalRequestedAt = 0L
        onMain {
            game.view.layout(0, 0, 600, 360)
            game.fit { obsolete = it; completed.countDown() }
            Handler(Looper.getMainLooper()).postDelayed({
                game.view.layout(0, 0, 900, 540)
                finalRequestedAt = SystemClock.uptimeMillis()
                game.fit { latest = it; completed.countDown() }
            }, 80)
        }
        assertTrue("Both fit requests completed", completed.await(5, TimeUnit.SECONDS))
        assertEquals(false, obsolete!!.getOrThrow())
        assertEquals(true, latest!!.getOrThrow())
        assertEquals(1, game.view.prepareTimes.size)
        assertTrue("Only final stable bounds are prepared", game.view.prepareTimes.first() - finalRequestedAt >= 180L)
        assertTrue("Only final stable bounds are zoomed", game.view.zoomTimes.all { it - finalRequestedAt >= 180L })
    }

    @Test
    fun sameBoundsAndUrlCanFitANewDocument() = withGame { game ->
        repeat(2) { document ->
            if (document > 0) game.load()
            val completed = CountDownLatch(1)
            var outcome: Result<Boolean>? = null
            onMain {
                game.view.layout(0, 0, 600, 360)
                game.fit { outcome = it; completed.countDown() }
            }
            assertTrue("Document fit completed", completed.await(5, TimeUnit.SECONDS))
            assertEquals(true, outcome!!.getOrThrow())
        }
        assertEquals(2, game.pageFinishes)
    }

    @Test
    fun sameUrlNavigationInvalidatesAnActiveFitBeforePreparingTheNewDocument() = withGame { game ->
        val completed = CountDownLatch(2)
        var obsolete: Result<Boolean>? = null
        var latest: Result<Boolean>? = null
        onMain {
            game.view.layout(0, 0, 600, 360)
            game.fit { obsolete = it; completed.countDown() }
        }
        assertTrue("Old document preparation started", game.view.firstPreparation.await(2, TimeUnit.SECONDS))
        // No explicit cancel callback is installed on this wrapper: the
        // applier must also recognize its document epoch changing in place.
        game.load()
        onMain { game.fit { latest = it; completed.countDown() } }

        assertTrue("Both document requests completed", completed.await(5, TimeUnit.SECONDS))
        assertEquals(false, obsolete!!.getOrThrow())
        assertEquals(true, latest!!.getOrThrow())
        assertEquals(2, game.view.prepareTimes.size)
    }

    @Test
    fun invalidBoundsCancelPendingWorkAndRestartTheStabilityWindow() = withGame { game ->
        val completed = CountDownLatch(3)
        var obsolete: Result<Boolean>? = null
        var invalid: Result<Boolean>? = null
        var latest: Result<Boolean>? = null
        var restoredAt = 0L
        onMain {
            game.view.layout(0, 0, 600, 360)
            game.fit { obsolete = it; completed.countDown() }
            Handler(Looper.getMainLooper()).postDelayed({
                game.view.layout(0, 0, 0, 0)
                game.applier.apply(game.view, 0, 50, 1200, 720, { true }) {
                    invalid = it
                    completed.countDown()
                }
            }, 40)
            Handler(Looper.getMainLooper()).postDelayed({
                game.view.layout(0, 0, 600, 360)
                restoredAt = SystemClock.uptimeMillis()
                game.fit { latest = it; completed.countDown() }
            }, 100)
        }

        assertTrue("All fit callers completed", completed.await(5, TimeUnit.SECONDS))
        assertEquals(false, obsolete!!.getOrThrow())
        assertTrue(invalid!!.exceptionOrNull() is IllegalArgumentException)
        assertEquals(true, latest!!.getOrThrow())
        assertEquals(1, game.view.prepareTimes.size)
        assertTrue("Restored bounds get their own stability wait", game.view.prepareTimes.first() - restoredAt >= 180L)
    }

    private class RecordingWebView(context: Context) : WebView(context) {
        val zoomTimes = mutableListOf<Long>()
        val prepareTimes = mutableListOf<Long>()
        val firstPreparation = CountDownLatch(1)
        val scrollPositions = mutableListOf<Pair<Int, Int>>()

        override fun evaluateJavascript(script: String, resultCallback: ValueCallback<String>?) {
            if (script.contains("const style = document.getElementById")) {
                prepareTimes += SystemClock.uptimeMillis()
                firstPreparation.countDown()
            }
            super.evaluateJavascript(script, resultCallback)
        }

        override fun zoomBy(zoomFactor: Float) {
            zoomTimes += SystemClock.uptimeMillis()
            super.zoomBy(zoomFactor)
        }

        override fun scrollTo(x: Int, y: Int) {
            scrollPositions += x to y
            super.scrollTo(x, y)
        }
    }

    private class Game(val view: RecordingWebView, val applier: FixedCanvasScaleApplier) {
        var pageFinishes = 0
        private var loadCompleted: CountDownLatch? = null

        init {
            view.webViewClient = GadgetBypassWebViewClient(
                original = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        pageFinishes++
                        loadCompleted?.countDown()
                    }
                },
                engine = GadgetBypassEngine(GadgetBypassCache(File(view.context.cacheDir, "fixed-canvas-resize"))),
                isEnabled = { false },
                endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
            )
        }

        fun fit(onComplete: (Result<Boolean>) -> Unit) {
            val width = view.width
            val height = view.height
            val percent = FixedCanvasScalePolicy().nextScalePercent(width, height, 1200, 720)!!
            applier.apply(view, width, percent, 1200, 720,
                isCurrent = { view.width == width && view.height == height },
                onComplete = onComplete)
        }

        fun load() {
            val loaded = CountDownLatch(1)
            onMain {
                loadCompleted = loaded
                view.loadDataWithBaseURL("https://localhost/", """
                    <html><head><meta name="viewport" content="width=device-width,initial-scale=1,minimum-scale=0.01,maximum-scale=10,user-scalable=yes">
                    <style id="__yahagi_mobile_fixed_canvas__">html, body { margin:0; width:1200px; height:720px; overflow:hidden; }</style>
                    <script>window.__yahagiMobileReadPresentation = () => 'game';</script>
                    </head><body>canvas</body></html>
                """.trimIndent(), "text/html", "UTF-8", null)
            }
            assertTrue("Local game page loaded", loaded.await(15, TimeUnit.SECONDS))
        }

        fun viewport(): JSONObject {
            val read = CountDownLatch(1)
            var value: String? = null
            onMain {
                view.evaluateJavascript("({scale:visualViewport.scale*devicePixelRatio,x:visualViewport.offsetLeft,y:visualViewport.offsetTop,visualWidth:visualViewport.width,innerWidth:innerWidth,minWidth:getComputedStyle(document.documentElement).minWidth})") {
                    value = it
                    read.countDown()
                }
            }
            assertTrue(read.await(5, TimeUnit.SECONDS))
            return JSONObject(value!!)
        }
    }

    private fun withGame(applier: FixedCanvasScaleApplier = FixedCanvasScaleApplier(), test: (Game) -> Unit) {
        lateinit var game: Game
        onMain {
            game = Game(RecordingWebView(ApplicationProvider.getApplicationContext<Context>()).apply {
                settings.javaScriptEnabled = true
                settings.useWideViewPort = true
                settings.loadWithOverviewMode = false
                settings.builtInZoomControls = true
                layout(0, 0, 1200, 720)
            }, applier)
        }
        try {
            game.load()
            test(game)
        } finally {
            onMain { game.applier.cancel(); game.view.destroy() }
        }
    }

    companion object {
        private fun onMain(action: () -> Unit) = InstrumentationRegistry.getInstrumentation().runOnMainSync(action)
    }
}
