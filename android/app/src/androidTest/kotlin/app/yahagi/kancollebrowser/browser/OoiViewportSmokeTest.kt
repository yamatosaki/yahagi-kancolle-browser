package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Base64
import android.view.InputDevice
import android.view.MotionEvent
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.nativewebview.NativeGamePresentationBridge
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Pass the original Dart runtime as alignmentScriptBase64; no duplicate JS fixture is kept. */
@RunWith(AndroidJUnit4::class)
class OoiViewportSmokeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val policy = FixedCanvasScalePolicy()
    private val pageFinishes = AtomicInteger()
    private val fits = AtomicInteger()
    private val scaleFailures = AtomicInteger()
    @Volatile private var lastScaleError: String? = null
    private val applier = FixedCanvasScaleApplier()
    private lateinit var view: FailingScaleWebView

    @Test
    fun originalScriptFitsOoiIframeAndEmbedAtRepeatedSizesWithoutReload() = withWebView { script ->
        for ((tag, id, wrapper) in listOf(
            Triple("iframe", "externalswf", "flashWrap"),
            Triple("embed", "externalswf", "ooi-game"),
            Triple("iframe", "htmlWrap", "ooi-game"),
        )) {
            load("https://ooi.moe/poi", ooiFixture(tag, id, wrapper))
            awaitJs("$tag $id child paints its offline canvas", "window.__fixtureChild?.ready === true")
            val finishes = pageFinishes.get()
            for ((width, height) in listOf(1200 to 720, 700 to 420, 1500 to 900, 900 to 900, 700 to 420)) {
                instrumentation.runOnMainSync { view.layout(0, 0, width, height) }
                val beforeFit = fits.get()
                fit(script)
                assertTrue("$tag ${width}x$height requests a native fit", fits.get() > beforeFit)
                val metrics = JSONObject(eval("""
                    (function(){
                      const frame=document.getElementById('$id');
                      const style=getComputedStyle(frame);
                      return {
                        state:window.__yahagiMobileReadPresentation(),
                        width:style.width,height:style.height,
                        transform:style.transform,
                        maxWidth:style.maxWidth,
                        styleCount:document.querySelectorAll('#__yahagi_mobile_ooi_browser__').length,
                        fixedCanvas:document.querySelectorAll('#__yahagi_mobile_fixed_canvas__').length
                      };
                    })()
                """.trimIndent()))
                assertEquals("OOI frame uses the native game fit", "game", metrics.getString("state"))
                assertEquals("$tag keeps the authored CSS width", "1280px", metrics.getString("width"))
                assertEquals("$tag keeps the authored CSS height", "800px", metrics.getString("height"))
                assertEquals("$tag is not CSS-transformed", "none", metrics.getString("transform"))
                assertEquals("UIkit max-width cannot shrink the frame", "none", metrics.getString("maxWidth"))
                assertEquals("Reinjection keeps one style", 1, metrics.getInt("styleCount"))
                assertEquals("Native fit stylesheet stays installed", 1, metrics.getInt("fixedCanvas"))
                assertOoiSurfaceGeometry(id)
                assertOfflineChildIsPaintedAndReceivesTouches()
            }
            assertEquals("Repeated fitting never reloads the OOI document", finishes, pageFinishes.get())
        }
    }

    @Test
    fun originalScriptManualFitRetriesNativeScaleAfterResetAndException() = withWebView { script ->
        load("https://play.games.dmm.com/game/kancolle/", "<canvas width='1200' height='720'></canvas>")
        fit(script)
        val finishes = pageFinishes.get()
        instrumentation.runOnMainSync {
            view.layout(0, 0, 700, 420)
            view.setInitialScale(100)
        }
        fit(script)
        assertCanvasCorners()
        val beforeFailure = scaleFailures.get()
        instrumentation.runOnMainSync { view.zoomBy(1.25f) }
        settle()
        instrumentation.runOnMainSync { view.failNextScale = true }
        fit(script, allowFailure = true)
        assertEquals("One simulated Android scale error", beforeFailure + 1, scaleFailures.get())
        val beforeRetry = fits.get()
        fit(script)
        assertTrue("Forced game-fit survives native state/scale deduplication", fits.get() > beforeRetry)
        assertCanvasCorners()
        assertEquals("Manual fit does not reload", finishes, pageFinishes.get())
    }

    @Test
    fun productionHelperPreciselyFitsRoundedSlotsAndResetsEffectiveZoomWithoutReload() = withWebView { script ->
        load("https://play.games.dmm.com/game/kancolle/", "<canvas width='1200' height='720'></canvas>")
        fit(script)
        assertCanvasRemainsFitted()
        val finishes = pageFinishes.get()
        // Both 1609x966 and 1614x969 used the same truncated 134% request.
        // The exact ratio must still update when bounds change within that percent.
        for ((width, height) in listOf(1614 to 969, 700 to 420, 1590 to 953, 1609 to 966, 1614 to 969, 900 to 900)) {
            instrumentation.runOnMainSync { view.layout(0, 0, width, height) }
            val beforeFit = fits.get()
            fit(script)
            assertTrue("${width}x$height manual fit applies a native request", fits.get() > beforeFit)
            assertCanvasRemainsFitted()
        }
        instrumentation.runOnMainSync { view.layout(0, 0, 1614, 969) }
        fit(script)
        var baseline = 0f
        instrumentation.runOnMainSync { baseline = view.scale }
        instrumentation.runOnMainSync { view.zoomBy(1.25f) }
        settle()
        var zoomed = 0f
        instrumentation.runOnMainSync { zoomed = view.scale }
        assertTrue("Effective zoom disturbance actually changes scale: $baseline -> $zoomed", zoomed > baseline * 1.05f)
        val beforeRestore = fits.get()
        fit(script)
        assertTrue("Same-percent manual restore applies a new native request", fits.get() > beforeRestore)
        assertCanvasRemainsFitted()
        repeat(3) {
            val beforeRepeat = fits.get()
            fit(script)
            assertTrue("Repeated reinjection applies a native request", fits.get() > beforeRepeat)
            assertCanvasRemainsFitted()
        }
        assertEquals("Repeated native fits preserve the document", finishes, pageFinishes.get())
        assertEquals("CSSOM changes retain the original script text", "true", eval("document.getElementById('__yahagi_mobile_fixed_canvas__').textContent.includes('min-width: 1200px')"))
    }

    @Test
    fun productionHelperCancelStaleAndWebPageCompleteWithoutNativeScaling() = withWebView { script ->
        load("https://play.games.dmm.com/game/kancolle/", "<canvas width='1200' height='720'></canvas>")
        fit(script)
        val completed = CountDownLatch(1)
        val callbacks = AtomicInteger()
        var applied = true
        var nativeBefore = 0
        instrumentation.runOnMainSync {
            nativeBefore = view.nativeScaleCalls
            applier.apply(view, view.width, 100, 1200, 720, { true }) { outcome ->
                applied = outcome.getOrThrow()
                callbacks.incrementAndGet()
                completed.countDown()
            }
            applier.cancel()
        }
        assertTrue("Cancellation completes the pending result", completed.await(5, TimeUnit.SECONDS))
        settle()
        assertEquals("Cancellation completes false", false, applied)
        assertEquals("Late JS callback cannot complete twice", 1, callbacks.get())
        assertEquals("Cancellation never changes native scale", nativeBefore, view.nativeScaleCalls)
        val stale = applyAndWait(current = false)
        assertEquals("A stale view is skipped", false, stale.getOrThrow())
        assertEquals("Stale request never scales", nativeBefore, view.nativeScaleCalls)
        load("https://ooi.moe/login", "<iframe id='externalswf' scrolling='auto'></iframe>")
        eval(script)
        settle()
        nativeBefore = view.nativeScaleCalls
        assertEquals("A web presentation is skipped", false, applyAndWait().getOrThrow())
        assertEquals("Login never receives native scaling", nativeBefore, view.nativeScaleCalls)
        assertEquals("Login frame attribute is retained", "\"auto\"", eval("document.getElementById('externalswf').getAttribute('scrolling')"))
    }

    @Test
    fun originalScriptKeepsNativeFitWhenCanvasBecomesOoiWrapper() = withWebView { script ->
        val original = "width=device-width,initial-scale=1,minimum-scale=0.8,maximum-scale=1,user-scalable=no"
        for (originalPresent in listOf(true, false)) {
            instrumentation.runOnMainSync { view.layout(0, 0, 700, 420) }
            load("https://ooi.moe/poi", "<canvas width='1200' height='720'></canvas>")
            if (originalPresent) {
                eval("window.__fixtureViewport=document.querySelector('meta[name=viewport]');window.__fixtureViewport.setAttribute('content',${JSONObject.quote(original)})")
            } else {
                eval("document.querySelectorAll('meta[name=viewport]').forEach(m=>m.remove())")
            }
            fit(script)
            assertCanvasRemainsFitted()
            val fitsBefore = fits.get()
            eval("document.body.innerHTML=\"<div id='flashWrap'><iframe id='externalswf' width='1280' height='800'></iframe></div>\"")
            fit(script)
            assertEquals("OOI wrapper stays on the native game fit", "\"game\"", eval("window.__yahagiMobileReadPresentation()"))
            if (originalPresent) {
                assertEquals("Original viewport node is retained", "true", eval("document.querySelector('meta[name=viewport]')===window.__fixtureViewport"))
            }
            assertTrue(
                "OOI game keeps a scalable viewport",
                eval("document.querySelector('meta[name=viewport]').getAttribute('content')").contains("minimum-scale=0.01"),
            )
            assertTrue("Replacing the canvas completes a fit even when scale is already correct", fits.get() > fitsBefore)
            assertOoiSurfaceGeometry("externalswf")
        }
    }

    @Test
    fun originalScriptManualFitResetsSameOriginOoiChildScroll() = withWebView { script ->
        load(
            "https://ooi.moe/poi",
            """<div id='flashWrap'><iframe id='externalswf' scrolling='auto' srcdoc="&lt;html&gt;&lt;body style='width:2000px;height:1800px'&gt;&lt;/body&gt;&lt;/html&gt;"></iframe></div>""",
        )
        eval("""
            window.__yahagiMobilePresentationRuntimeVersion=3;
            window.__yahagiMobileSyncPresentation=()=> 'web';
            window.__yahagiMobileReadPresentation=()=> 'web';
            window.__staleOoiClosureCalls=0;
            window.__yahagiMobileOoiAlignGame=()=>window.__staleOoiClosureCalls++;
        """.trimIndent())
        eval(script)
        settle()
        assertEquals("Runtime upgrades cached v3 state", "8", eval("window.__yahagiMobilePresentationRuntimeVersion"))
        assertEquals("Upgrade replaces old OOI alignment closure", "0", eval("window.__staleOoiClosureCalls"))
        val finishes = pageFinishes.get()
        eval("document.getElementById('externalswf').contentWindow.scrollTo(113,157)")
        val before = JSONObject(eval("(function(){const w=document.getElementById('externalswf').contentWindow;return {x:w.scrollX,y:w.scrollY};})()"))
        assertTrue("Fixture child actually scrolls", before.getInt("x") > 0 && before.getInt("y") > 0)
        eval(script)
        settle()
        val after = JSONObject(eval("(function(){const w=document.getElementById('externalswf').contentWindow;return {x:w.scrollX,y:w.scrollY};})()"))
        assertEquals("Manual fit resets child horizontal scroll", 0, after.getInt("x"))
        assertEquals("Manual fit resets child vertical scroll", 0, after.getInt("y"))
        assertEquals("Scroll recovery does not reload", finishes, pageFinishes.get())
        eval("window.__removedOoiFrame=document.getElementById('externalswf');document.getElementById('flashWrap').remove();window.__yahagiMobileSyncPresentation()")
        assertEquals("OOI cleanup restores original attribute", "\"auto\"", eval("window.__removedOoiFrame.getAttribute('scrolling')"))
        load("https://ooi.moe/login", "<div id='flashWrap'><iframe id='externalswf' scrolling='no'></iframe></div>")
        eval(script)
        assertEquals("Login keeps its original scrolling attribute", "\"no\"", eval("document.getElementById('externalswf').getAttribute('scrolling')"))
    }

    @Test
    fun originalScriptRestoresOrdinaryOoiFormAfterGameSurfaceIsRemovedAndFitsReinsertedSurface() = withWebView { script ->
        val original = "width=device-width,initial-scale=1,minimum-scale=0.8,maximum-scale=1,user-scalable=no"
        for (originalPresent in listOf(true, false)) {
            instrumentation.runOnMainSync { view.layout(0, 0, 700, 420) }
            load("https://ooi.moe/poi", ooiFixture("iframe", "htmlWrap", "flashWrap"))
            awaitJs("Offline child loads before fitting", "window.__fixtureChild?.ready === true")
            if (originalPresent) {
                eval("window.__fixtureViewport=document.querySelector('meta[name=viewport]');window.__fixtureViewport.setAttribute('content',${JSONObject.quote(original)})")
            } else {
                eval("document.querySelectorAll('meta[name=viewport]').forEach(m=>m.remove())")
            }
            fit(script)
            assertOoiSurfaceGeometry("htmlWrap")
            val finishes = pageFinishes.get()
            eval("""
                window.__fixtureRemovedWrap=document.getElementById('flashWrap');
                window.__fixtureRemovedFrame=document.getElementById('htmlWrap');
                document.body.innerHTML=${JSONObject.quote(ordinaryForm())};
            """.trimIndent())
            awaitJs("Removing the last game surface automatically restores web mode", "window.__yahagiMobileReadPresentation() === 'web' && window.__yahagiMobilePresentationState === 'web'")
            val restored = JSONObject(eval("""
                (()=>{
                  const html=getComputedStyle(document.documentElement),body=getComputedStyle(document.body);
                  return {fixed:!!document.getElementById('__yahagi_mobile_fixed_canvas__'),
                    ooi:!!document.getElementById('__yahagi_mobile_ooi_browser__'),
                    scrollLock:typeof window.__yahagiMobileScrollLock,
                    frameScrolling:window.__fixtureRemovedFrame.getAttribute('scrolling'),
                    overflow:html.overflow,touchAction:html.touchAction,clipPath:body.clipPath,
                    formVisible:document.getElementById('ordinary-form').getBoundingClientRect().height>0,
                    input:document.getElementById('fixture-input').value};
                })()
            """.trimIndent()))
            assertEquals("Fixed canvas stylesheet is released", false, restored.getBoolean("fixed"))
            assertEquals("OOI stylesheet is released", false, restored.getBoolean("ooi"))
            assertEquals("Game scroll listener is removed", "undefined", restored.getString("scrollLock"))
            assertEquals("Detached frame recovers authored scrolling", "auto", restored.getString("frameScrolling"))
            assertTrue("Ordinary document is no longer overflow-locked", restored.getString("overflow") != "hidden")
            assertEquals("Ordinary document recovers touch action", "auto", restored.getString("touchAction"))
            assertEquals("Native fit clipping is removed", "none", restored.getString("clipPath"))
            assertTrue("Replacement form remains visible", restored.getBoolean("formVisible"))
            assertEquals("Replacement input remains usable", "offline-value", restored.getString("input"))
            if (originalPresent) {
                assertEquals("Original viewport node is retained after leaving game", "true", eval("document.querySelector('meta[name=viewport]')===window.__fixtureViewport"))
                assertEquals("Authored viewport content is restored exactly", JSONObject.quote(original), eval("document.querySelector('meta[name=viewport]').getAttribute('content')"))
            } else {
                assertEquals("Viewport created for the game is removed", "0", eval("document.querySelectorAll('meta[name=viewport]').length"))
            }
            eval("window.scrollTo(90,150)")
            settle()
            assertTrue("Ordinary form can scroll after cleanup", JSONObject(eval("({x:scrollX,y:scrollY})")).getInt("y") > 0)
            eval("document.body.replaceChildren(window.__fixtureRemovedWrap)")
            fit(script)
            assertEquals("Reinserted OOI surface returns to game mode", "\"game\"", eval("window.__yahagiMobileReadPresentation()"))
            assertEquals("Reinserted frame is locked for game input", "\"no\"", eval("document.getElementById('htmlWrap').getAttribute('scrolling')"))
            assertOoiSurfaceGeometry("htmlWrap")
            assertEquals("Removing and reinserting the surface never reloads the document", finishes, pageFinishes.get())
        }
    }

    @Test
    fun originalScriptKeepsOoiHomeAndDmmAccountFormsInOrdinaryWebPresentation() = withWebView { script ->
        for (url in listOf("https://ooi.moe/", "https://ooi.moe/login", "https://accounts.dmm.com/service/login/password", "https://accounts.dmm.co.jp/service/login/password")) {
            load(url, ordinaryForm())
            val nativeBefore = view.nativeScaleCalls
            eval(script)
            settle()
            assertEquals("$url remains an ordinary web page", "\"web\"", eval("window.__yahagiMobileReadPresentation()"))
            assertEquals("$url never requests native game scaling", nativeBefore, view.nativeScaleCalls)
            assertEquals("$url keeps the authored viewport", "\"width=device-width,initial-scale=1\"", eval("document.querySelector('meta[name=viewport]').getAttribute('content')"))
            assertEquals("$url has no fixed canvas styles", "0", eval("document.querySelectorAll('#__yahagi_mobile_fixed_canvas__,#__yahagi_mobile_ooi_browser__').length"))
            assertEquals("$url retains the input value", "\"offline-value\"", eval("document.getElementById('fixture-input').value"))
            eval("document.getElementById('fixture-input').value='edited-offline';window.scrollTo(0,150)")
            settle()
            assertEquals("$url accepts form edits", "\"edited-offline\"", eval("document.getElementById('fixture-input').value"))
            assertTrue("$url remains scrollable", eval("scrollY>0") == "true")
        }
    }

    @Test
    fun originalScriptYieldsToOoiPasswordFormsAndNestedDialogs() = withWebView { script ->
        load("https://ooi.moe/poi", ooiFixture("iframe", "externalswf", "flashWrap"))
        awaitJs("Offline game child is ready", "window.__fixtureChild?.ready === true")
        val originalViewport = eval("document.querySelector('meta[name=viewport]').getAttribute('content')")
        fit(script)
        eval("""
            document.getElementById('flashWrap').insertAdjacentHTML('beforeend',
              '<div id="login-shell"><form><input id="login-password" name="password" type="password" autocomplete="current-password" value="offline-only"></form></div>');
        """.trimIndent())
        awaitJs("A visible login form releases OOI fitting", "window.__yahagiMobileReadPresentation() === 'web' && !document.getElementById('__yahagi_mobile_fixed_canvas__')")
        assertEquals("Login restores the authored viewport", originalViewport, eval("document.querySelector('meta[name=viewport]').getAttribute('content')"))
        eval("document.getElementById('login-password').type='text'")
        settle()
        assertEquals("Showing the password keeps login presentation", "\"web\"", eval("window.__yahagiMobileReadPresentation()"))
        assertEquals("Login input retains its value", "\"offline-only\"", eval("document.getElementById('login-password').value"))
        eval("document.getElementById('login-shell').remove()")
        fit(script)
        eval("""
            document.getElementById('flashWrap').insertAdjacentHTML('beforeend',
              '<div id="dialog-shell"><dialog id="fixture-dialog">Offline login dialog</dialog></div>');
            document.getElementById('fixture-dialog').showModal();
        """.trimIndent())
        awaitJs("A nested dialog releases OOI fitting", "window.__yahagiMobileReadPresentation() === 'web' && !document.getElementById('__yahagi_mobile_fixed_canvas__')")
        assertEquals("Nested dialog restores the authored viewport", originalViewport, eval("document.querySelector('meta[name=viewport]').getAttribute('content')"))
        assertEquals("Nested dialog stays visible", "true", eval("getComputedStyle(document.getElementById('fixture-dialog')).display !== 'none'"))
        eval("document.getElementById('dialog-shell').remove()")
        fit(script)
        assertOoiSurfaceGeometry("externalswf")
    }

    private fun withWebView(action: (String) -> Unit) {
        val encoded = InstrumentationRegistry.getArguments().getString("alignmentScriptBase64")
        assumeTrue("Pass alignmentScriptBase64 extracted from game_page_alignment_script.dart", !encoded.isNullOrEmpty())
        val script = String(Base64.decode(encoded, Base64.DEFAULT), Charsets.UTF_8)
        try {
            instrumentation.runOnMainSync {
                view = FailingScaleWebView(ApplicationProvider.getApplicationContext<Context>())
                view.settings.javaScriptEnabled = true
                view.settings.blockNetworkLoads = true
                view.settings.useWideViewPort = false
                view.settings.loadWithOverviewMode = false
                view.settings.builtInZoomControls = true
                view.layout(0, 0, 1200, 720)
                view.addJavascriptInterface(
                    NativeGamePresentationBridge(onPresentationStateChanged = { game ->
                        Handler(Looper.getMainLooper()).post {
                            if (game) {
                                view.settings.useWideViewPort = true
                                val scale = policy.nextScalePercent(view.width, view.height, 1200, 720, force = true)
                                if (scale != null) {
                                    val expectedView = view
                                    val expectedWidth = view.width
                                    val expectedHeight = view.height
                                    applier.apply(view, expectedWidth, scale, 1200, 720, {
                                        view === expectedView && view.width == expectedWidth && view.height == expectedHeight
                                    }) { outcome ->
                                        outcome.onSuccess { applied -> if (applied) fits.incrementAndGet() }
                                            .onFailure { lastScaleError = it.toString(); scaleFailures.incrementAndGet() }
                                    }
                                }
                            } else {
                                applier.cancel()
                                view.settings.useWideViewPort = false
                                policy.reset()
                            }
                        }
                    }),
                    "YahagiPresentation",
                )
            }
            action(script)
        } finally {
            instrumentation.runOnMainSync { applier.cancel(); if (::view.isInitialized) view.destroy() }
        }
    }

    private fun load(url: String, body: String) {
        val loaded = CountDownLatch(1)
        instrumentation.runOnMainSync {
            policy.reset()
            applier.cancel()
            view.settings.useWideViewPort = false
            view.setInitialScale(0)
            view.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    pageFinishes.incrementAndGet()
                    loaded.countDown()
                }
            }
            view.loadDataWithBaseURL(
                url,
                "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'><style>html,body{margin:0}iframe,embed{max-width:100%}</style></head><body>$body</body></html>",
                "text/html", "UTF-8", null,
            )
        }
        assertTrue("Local document loads", loaded.await(15, TimeUnit.SECONDS))
    }

    private fun ordinaryForm() = """
        <form id='ordinary-form' style='min-height:2400px;padding:24px'>
          <label>Offline fixture<input id='fixture-input' value='offline-value'></label>
          <button type='button'>Continue</button>
        </form>
    """.trimIndent()

    /** Both transports contain the same real HTML child; no account or network is involved. */
    private fun ooiFixture(tag: String, id: String, wrapper: String): String {
        val child = """
            <!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
            <style>html,body{margin:0;padding:0;background:#b000b0}canvas{display:block;touch-action:none}</style></head>
            <body><canvas id='offline-game' width='1200' height='720'></canvas><script>
              const canvas=document.getElementById('offline-game'),ctx=canvas.getContext('2d');
              ctx.fillStyle='#202020';ctx.fillRect(0,0,1200,720);
              [['#ff3030',0,0],['#30ff30',1152,0],['#3060ff',0,672],['#ffff30',1152,672]].forEach(([c,x,y])=>{
                ctx.fillStyle=c;ctx.fillRect(x,y,48,48);
              });
              let clicks=0;
              const report=(event)=>{
                const r=canvas.getBoundingClientRect();
                parent.postMessage({offlineOoi:true,ready:true,width:r.width,height:r.height,
                  x:r.x,y:r.y,clicks:clicks,clientX:event?.clientX??null,clientY:event?.clientY??null},'*');
              };
              canvas.addEventListener('click',event=>{clicks++;report(event)});
              report();
            </script></body></html>
        """.trimIndent()
        val source = if (tag == "iframe") {
            "srcdoc=\"${child.replace("&", "&amp;").replace("\"", "&quot;") }\""
        } else {
            val encoded = Base64.encodeToString(child.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
            "type='text/html' src='data:text/html;base64,$encoded'"
        }
        val frame = "<$tag id='$id' width='1280' height='800' scrolling='auto' $source></$tag>"
        val surface = if (wrapper == "flashWrap") "<div id='flashWrap'>$frame</div>" else frame
        return """
            <script>window.addEventListener('message',event=>{
              if(event.data?.offlineOoi===true) window.__fixtureChild=event.data;
            });</script>
            <div id='ooi-page'><header id='ooi-header' style='height:100px'>Offline OOI shell</header>
            <div id='ooi-game'>$surface</div><footer id='ooi-footer'>Offline footer</footer></div>
        """.trimIndent()
    }

    private fun awaitJs(message: String, condition: String) {
        val deadline = SystemClock.uptimeMillis() + 5_000
        var result = eval(condition)
        while (result != "true" && SystemClock.uptimeMillis() < deadline) {
            Thread.sleep(50)
            result = eval(condition)
        }
        assertEquals(message, "true", result)
    }

    private fun assertOoiSurfaceGeometry(id: String) {
        var width = 0
        var height = 0
        instrumentation.runOnMainSync { width = view.width; height = view.height }
        val targetScale = minOf(width / 1200.0, height / 720.0)
        val geometry = JSONObject(eval("""
            (()=>{const r=document.getElementById('$id').getBoundingClientRect(),v=visualViewport;
              return {x:r.x-v.offsetLeft,y:r.y-v.offsetTop,width:r.width,height:r.height,
                scale:v.scale*devicePixelRatio,offsetX:v.offsetLeft,offsetY:v.offsetTop};})()
        """.trimIndent()))
        assertEquals("OOI frame preserves its original 1280 CSS pixel width", 1280.0, geometry.getDouble("width"), 0.01)
        assertEquals("OOI frame preserves its original 800 CSS pixel height", 800.0, geometry.getDouble("height"), 0.01)
        assertEquals("OOI viewport uses the exact physical contain ratio", targetScale, geometry.getDouble("scale"), 0.5 / 1200.0)
        assertEquals("OOI composited frame starts at the left edge", 0.0, geometry.getDouble("x") * targetScale, 0.5)
        assertEquals("OOI composited frame starts at the top edge", 0.0, geometry.getDouble("y") * targetScale, 0.5)
        assertEquals("OOI viewport has no horizontal offset", 0.0, geometry.getDouble("offsetX") * targetScale, 0.5)
        assertEquals("OOI viewport has no vertical offset", 0.0, geometry.getDouble("offsetY") * targetScale, 0.5)
    }

    private data class Corner(val x: Int, val y: Int, val color: Int, val name: String)

    /** Verify child pixels in the rendered WebView, then inject physical-coordinate taps. */
    private fun assertOfflineChildIsPaintedAndReceivesTouches() {
        val child = JSONObject(eval("window.__fixtureChild"))
        assertEquals("Child canvas keeps its logical width", 1200.0, child.getDouble("width"), 0.01)
        assertEquals("Child canvas keeps its logical height", 720.0, child.getDouble("height"), 0.01)
        assertEquals("Child canvas starts at its frame's left edge", 0.0, child.getDouble("x"), 0.01)
        assertEquals("Child canvas starts at its frame's top edge", 0.0, child.getDouble("y"), 0.01)
        var width = 0
        var height = 0
        instrumentation.runOnMainSync { width = view.width; height = view.height }
        val scale = minOf(width / 1200.0, height / 720.0)
        val corners = listOf(
            Corner(24, 24, Color.rgb(255, 48, 48), "top-left"),
            Corner(1176, 24, Color.rgb(48, 255, 48), "top-right"),
            Corner(24, 696, Color.rgb(48, 96, 255), "bottom-left"),
            Corner(1176, 696, Color.rgb(255, 255, 48), "bottom-right"),
        )
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            var actual = emptyList<Int>()
            val deadline = SystemClock.uptimeMillis() + 3_000
            do {
                instrumentation.runOnMainSync { view.draw(Canvas(bitmap)) }
                actual = corners.map { bitmap.getPixel((it.x * scale).toInt(), (it.y * scale).toInt()) }
                if (corners.zip(actual).all { (corner, color) -> sameColor(corner.color, color) }) break
                Thread.sleep(50)
            } while (SystemClock.uptimeMillis() < deadline)
            corners.zip(actual).forEach { (corner, color) ->
                assertTrue("Real child ${corner.name} marker is painted at its fitted physical location: expected ${Integer.toHexString(corner.color)}, actual ${Integer.toHexString(color)}", sameColor(corner.color, color))
            }
        } finally {
            bitmap.recycle()
        }
        var clicks = child.getInt("clicks")
        for (corner in corners) {
            dispatchTap((corner.x * scale).toFloat(), (corner.y * scale).toFloat())
            clicks++
            awaitJs("Physical ${corner.name} tap reaches the offline child", "window.__fixtureChild?.clicks === $clicks")
            val touched = JSONObject(eval("window.__fixtureChild"))
            assertEquals("${corner.name} tap maps to child CSS x", corner.x.toDouble(), touched.getDouble("clientX"), 2.0 / scale)
            assertEquals("${corner.name} tap maps to child CSS y", corner.y.toDouble(), touched.getDouble("clientY"), 2.0 / scale)
        }
    }

    private fun sameColor(expected: Int, actual: Int) =
        kotlin.math.abs(Color.red(expected) - Color.red(actual)) <= 8 &&
            kotlin.math.abs(Color.green(expected) - Color.green(actual)) <= 8 &&
            kotlin.math.abs(Color.blue(expected) - Color.blue(actual)) <= 8 && Color.alpha(actual) == 255

    private fun dispatchTap(x: Float, y: Float) {
        instrumentation.runOnMainSync {
            view.requestFocus()
            val now = SystemClock.uptimeMillis()
            for ((action, time) in listOf(MotionEvent.ACTION_DOWN to now, MotionEvent.ACTION_UP to now + 60)) {
                val event = MotionEvent.obtain(now, time, action, x, y, 0)
                event.source = InputDevice.SOURCE_TOUCHSCREEN
                try {
                    assertTrue("WebView accepts physical touch event", view.dispatchTouchEvent(event))
                } finally {
                    event.recycle()
                }
            }
        }
    }

    private fun eval(script: String): String {
        val complete = CountDownLatch(1)
        var result = "null"
        instrumentation.runOnMainSync {
            view.evaluateJavascript(script) { value -> result = value; complete.countDown() }
        }
        assertTrue("JS callback returned", complete.await(10, TimeUnit.SECONDS))
        return result
    }

    private fun settle() { Thread.sleep(300); instrumentation.waitForIdleSync() }

    private fun fit(script: String, allowFailure: Boolean = false) {
        val before = fits.get()
        val failuresBefore = scaleFailures.get()
        eval(script)
        val deadline = android.os.SystemClock.uptimeMillis() + 5_500
        while (fits.get() <= before && scaleFailures.get() == failuresBefore &&
            android.os.SystemClock.uptimeMillis() < deadline) {
            Thread.sleep(50)
        }
        assertTrue("Native fit callback completes", fits.get() > before || scaleFailures.get() > failuresBefore)
        if (!allowFailure) assertEquals("Native fit completes without error: $lastScaleError", failuresBefore, scaleFailures.get())
    }

    private fun applyAndWait(current: Boolean = true): Result<Boolean> {
        val completed = CountDownLatch(1)
        var outcome: Result<Boolean>? = null
        instrumentation.runOnMainSync {
            applier.apply(view, view.width, 50, 1200, 720, { current }) { result -> outcome = result; completed.countDown() }
        }
        assertTrue("Native helper completes", completed.await(6, TimeUnit.SECONDS))
        return checkNotNull(outcome)
    }

    private fun assertCanvasCorners() {
        var width = 0
        var height = 0
        instrumentation.runOnMainSync { width = view.width; height = view.height }
        val targetScale = minOf(width / 1200.0, height / 720.0)
        fun readMetrics() = JSONObject(eval("""
            (()=>{const r=document.querySelector('canvas').getBoundingClientRect(),v=visualViewport;
            return {x:r.x-v.offsetLeft,y:r.y-v.offsetTop,right:r.right-v.offsetLeft,bottom:r.bottom-v.offsetTop,width:r.width,height:r.height,visualWidth:v.width,visualScale:v.scale,dpr:devicePixelRatio};})()
        """.trimIndent()))
        var metrics = readMetrics()
        val deadline = android.os.SystemClock.uptimeMillis() + 2_000
        while (kotlin.math.abs(metrics.getDouble("visualScale") * metrics.getDouble("dpr") - targetScale) > 0.5 / 1200.0 &&
            android.os.SystemClock.uptimeMillis() < deadline) {
            Thread.sleep(50)
            metrics = readMetrics()
        }
        val scale = metrics.getDouble("visualScale") * metrics.getDouble("dpr")
        assertEquals("Canvas CSS width is preserved", 1200.0, metrics.getDouble("width"), 0.01)
        assertEquals("Canvas CSS height is preserved", 720.0, metrics.getDouble("height"), 0.01)
        assertEquals("Exact proportional fit is applied at ${width}x$height", targetScale, scale, 0.5 / 1200.0)
        assertEquals("Left edge is aligned", 0.0, metrics.getDouble("x") * scale, 0.5)
        assertEquals("Top edge is aligned", 0.0, metrics.getDouble("y") * scale, 0.5)
        assertEquals("Right edge has no rounding gap", 1200 * targetScale, metrics.getDouble("right") * scale, 0.5)
        assertEquals("Bottom edge has no rounding gap", 720 * targetScale, metrics.getDouble("bottom") * scale, 0.5)
        assertTrue("Right corner is visible", metrics.getDouble("right") * scale <= width + 0.5)
        assertTrue("Bottom corner is visible", metrics.getDouble("bottom") * scale <= height + 0.5)
    }

    private fun assertCanvasRemainsFitted() {
        assertCanvasCorners()
        Thread.sleep(150)
        assertCanvasCorners()
        Thread.sleep(350)
        assertCanvasCorners()
    }

    private class FailingScaleWebView(context: Context) : WebView(context) {
        var failNextScale = false
        var scaleSetterCalls = 0
        var zoomCalls = 0
        val nativeScaleCalls get() = scaleSetterCalls + zoomCalls
        override fun zoomBy(zoomFactor: Float) {
            zoomCalls++
            if (failNextScale) {
                failNextScale = false
                throw IllegalStateException("Intentional zoomBy failure")
            }
            super.zoomBy(zoomFactor)
        }
        override fun setInitialScale(scaleInPercent: Int) {
            scaleSetterCalls++
            if (failNextScale) {
                failNextScale = false
                throw IllegalStateException("Intentional setInitialScale failure")
            }
            super.setInitialScale(scaleInPercent)
        }
    }
}
