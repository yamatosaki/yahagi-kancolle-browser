package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.MainActivity
import java.io.ByteArrayInputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Real bridge, SharedPreferences notifications and cross-origin Chromium messages; fixture-only requests. */
@RunWith(AndroidJUnit4::class)
class GameMouseWheelWebViewTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    @Test fun defaultOffDoesNoDomWorkAndTheFirstWheelAfterLiveEnableIsDelivered() = withGame(null) { game ->
        val initial = game.snapshot()
        assertEquals(0, initial.getInt("observers"))
        assertEquals(0, initial.getInt("canvasReads"))
        assertEquals(0, initial.getInt("layoutReads"))
        val disabled = game.snapshot("mutate")
        assertEquals(0, disabled.getInt("canvasReads"))
        assertEquals(0, disabled.getInt("layoutReads"))
        assertFalse(onMain { game.wheel() })

        // No renderer turn or availability reply can run between this write and first send.
        assertTrue(onMain { game.setEnabled(true); game.wheel() })
        var enabled = game.awaitSnapshot { it.getInt("wheels") == 1 }
        assertEquals(initial.getString("documentId"), enabled.getString("documentId"))
        assertEquals(1, enabled.getInt("observers"))
        assertEquals(310.0, enabled.getDouble("clientX"), .01)
        assertEquals(110.0, enabled.getDouble("clientY"), .01)
        assertEquals(120.0, enabled.getDouble("deltaY"), .01)

        repeat(3) { index ->
            onMain { game.setEnabled(false) }
            val stopped = game.awaitSnapshot { it.getInt("observers") == 0 }
            val afterMutation = game.snapshot("mutate")
            assertEquals(stopped.getInt("canvasReads"), afterMutation.getInt("canvasReads"))
            assertEquals(stopped.getInt("layoutReads"), afterMutation.getInt("layoutReads"))
            assertFalse(onMain { game.wheel() })
            assertTrue(onMain { game.setEnabled(true); game.wheel() })
            enabled = game.awaitSnapshot { it.getInt("wheels") == index + 2 }
            assertEquals(1, enabled.getInt("observers"))
        }
        assertEquals(initial.getString("documentId"), enabled.getString("documentId"))
        assertEquals(4, enabled.getInt("wheels"))
    }

    @Test fun persistedEnabledSurvivesIframeReloadAndPageLifecycle() = withGame(true) { game ->
        val initial = game.awaitSnapshot { it.getInt("observers") == 1 }
        assertTrue(onMain { game.wheel() })
        game.awaitSnapshot { it.getInt("wheels") == 1 }
        game.navigate("https://w01.kancolle-server.com/kcs2/mouse-fixture?reload")
        val reloaded = game.awaitSnapshot { it.getString("documentId") != initial.getString("documentId") && it.getInt("observers") == 1 }
        assertEquals(0, reloaded.getInt("wheels"))
        assertTrue(onMain { game.wheel() })
        game.awaitSnapshot { it.getInt("wheels") == 1 }

        val hidden = game.snapshot("pagehide")
        assertEquals(0, hidden.getInt("observers"))
        assertFalse("A gone frame cannot be used as the pending-enable fallback", onMain { game.wheel() })
        val hiddenMutation = game.snapshot("mutate")
        assertEquals(hidden.getInt("canvasReads"), hiddenMutation.getInt("canvasReads"))
        game.snapshot("pageshow")
        game.awaitSnapshot { it.getInt("observers") == 1 }
        assertTrue(onMain { game.wheel() })
        assertEquals(2, game.awaitSnapshot { it.getInt("wheels") == 2 }.getInt("wheels"))
    }

    @Test fun detachStopsObservationAndReattachUsesTheCurrentPreference() = withGame(true) { game ->
        game.awaitSnapshot { it.getInt("observers") == 1 }
        onMain { game.parent.removeView(game.view) }
        game.awaitSnapshot { it.getInt("observers") == 0 }
        assertFalse(onMain { game.wheel() })
        onMain { game.setEnabled(false); game.setEnabled(true) }
        assertEquals(0, game.snapshot("mutate").getInt("observers"))
        onMain { game.addToParent() }
        game.awaitSnapshot { it.getInt("observers") == 1 }
        await("reattached WebView focus") { onMain { game.view.hasWindowFocus() && game.view.width > 0 } }
        assertTrue(onMain { game.wheel() })
        game.awaitSnapshot { it.getInt("wheels") == 1 }
        onMain { game.view.visibility = View.INVISIBLE }
        assertFalse(onMain { game.wheel() })
        onMain { game.view.visibility = View.VISIBLE }
        assertFalse(onMain { game.wheel(x = 1.0) })
    }

    @Test fun unrelatedFrameOriginsAndPathsCannotReceiveWheels() = withGame(true) { game ->
        game.awaitSnapshot { it.getInt("observers") == 1 }
        for (url in listOf(
            "https://w01.kancolle-server.com/gadget_html5/",
            "https://w01.kancolle-server.com.evil.invalid/kcs2/mouse-fixture",
        )) {
            game.navigate(url)
            val snapshot = game.awaitSnapshot { it.getString("url") == url }
            assertEquals(0, snapshot.getInt("observers"))
            assertEquals(0, snapshot.getInt("canvasReads"))
            assertFalse(onMain { game.wheel() })
        }
        game.navigate(GAME_URL)
        game.awaitSnapshot { it.getInt("observers") == 1 }
        assertTrue(onMain { game.wheel() })
        game.awaitSnapshot { it.getInt("wheels") == 1 }
    }

    @Test fun reenableKeepsTheKnownGameTargetWhenAnotherFrameHasNoCanvas() = withGame(true) { game ->
        game.awaitSnapshot { it.getInt("observers") == 1 }
        assertTrue(onMain { game.wheel() })
        game.awaitSnapshot { it.getInt("wheels") == 1 }
        game.addEmptyFrame()
        game.awaitSnapshot(frame = 1) { it.getInt("observers") == 1 }

        // Both endpoints are pending after this same-turn toggle. Only the first has a game canvas.
        assertTrue(onMain { game.setEnabled(false); game.setEnabled(true); game.wheel() })
        val primary = game.awaitSnapshot { it.getInt("wheels") == 2 }
        assertEquals(2, primary.getInt("wheels"))
        assertEquals(0, game.snapshot(frame = 1).getInt("wheels"))
        game.snapshot("pagehide")
        assertFalse("Retiring the known target must not leave a stale fallback", onMain { game.wheel() })
    }

    @Test fun binaryAndMalformedBridgeMessagesAreIgnored() {
        assumeTrue(WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_ARRAY_BUFFER))
        withGame(true) { game ->
            game.awaitSnapshot { it.getInt("observers") == 1 }
            game.snapshot("malformed")
            assertTrue(onMain { game.wheel() })
            game.awaitSnapshot { it.getInt("wheels") == 1 }
        }
    }

    private inner class Game(val view: WebView, val parent: FrameLayout, val preferences: SharedPreferences) {
        val responses = LinkedBlockingQueue<JSONObject>()
        private var request = 0
        fun setEnabled(enabled: Boolean) { assertTrue(preferences.edit().putBoolean(PREFERENCE, enabled).commit()) }
        fun wheel(x: Double = .5): Boolean = GameMouseWheelBridge.forward(view, x, .25, 0.0, 120.0)
        fun addToParent() = parent.addView(view, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
        ))
        fun navigate(url: String) {
            val id = ++request
            onMain {
                view.evaluateJavascript("""
                    (() => {
                      const frame = document.querySelector('iframe');
                      frame.addEventListener('load', () => MouseWheelProbe.postMessage(JSON.stringify({request:$id})), {once:true});
                      frame.src = ${JSONObject.quote(url)};
                    })();
                """.trimIndent(), null)
            }
            response(id, "iframe navigation")
        }
        fun addEmptyFrame() {
            val id = ++request
            onMain {
                view.evaluateJavascript("""
                    (() => {
                      const frame = document.createElement('iframe');
                      frame.addEventListener('load', () => MouseWheelProbe.postMessage(JSON.stringify({request:$id})), {once:true});
                      frame.src = 'https://w01.kancolle-server.com/kcs2/empty-fixture';
                      document.body.appendChild(frame);
                    })();
                """.trimIndent(), null)
            }
            response(id, "auxiliary iframe")
        }
        fun snapshot(action: String = "probe", frame: Int = 0): JSONObject {
            val id = ++request
            onMain {
                view.evaluateJavascript("window.frames[$frame].postMessage({action:'$action', request:$id}, '*')", null)
            }
            return response(id, action)
        }
        private fun response(id: Int, action: String): JSONObject {
            val deadline = SystemClock.uptimeMillis() + 5_000
            while (SystemClock.uptimeMillis() < deadline) {
                val result = responses.poll(100, TimeUnit.MILLISECONDS) ?: continue
                if (result.optInt("request") == id) return result
            }
            error("No game fixture response for $action ($id)")
        }
        fun awaitSnapshot(frame: Int = 0, predicate: (JSONObject) -> Boolean): JSONObject {
            var latest = snapshot(frame = frame)
            await("game snapshot: $latest") {
                latest = snapshot(frame = frame)
                predicate(latest)
            }
            return latest
        }
    }

    private fun withGame(initialEnabled: Boolean?, action: (Game) -> Unit) {
        assumeTrue(WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT))
        assumeTrue(WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER))
        val context = ApplicationProvider.getApplicationContext<Context>()
        val preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val existed = preferences.contains(PREFERENCE)
        val previous = preferences.getBoolean(PREFERENCE, false)
        onMain {
            val edit = preferences.edit()
            if (initialEnabled == null) edit.remove(PREFERENCE) else edit.putBoolean(PREFERENCE, initialEnabled)
            assertTrue(edit.commit())
        }
        var game: Game? = null
        try {
            ActivityScenario.launch(MainActivity::class.java).use { scenario ->
                val loaded = CountDownLatch(1)
                scenario.onActivity { activity ->
                    val view = WebView(activity)
                    val fixture = Game(view, activity.findViewById(android.R.id.content), preferences)
                    game = fixture
                    view.settings.javaScriptEnabled = true
                    view.elevation = 100f
                    view.webViewClient = object : WebViewClient() {
                        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                            val html = if (request.url.host == "www.dmm.com") {
                                "<html><body style='margin:0'><iframe style='border:0;width:100vw;height:100vh' src='$GAME_URL'></iframe></body></html>"
                            } else if (request.url.path == "/kcs2/empty-fixture") {
                                // Keep the probe listener but give this valid-origin document no canvas.
                                GAME_HTML.replace("<canvas ", "<div ").replace("</canvas>", "</div>")
                            } else GAME_HTML
                            return WebResourceResponse("text/html", "UTF-8", ByteArrayInputStream(html.toByteArray()))
                        }
                        override fun onPageFinished(view: WebView, url: String) { loaded.countDown() }
                    }
                    WebViewCompat.addWebMessageListener(view, "MouseWheelProbe", setOf("*")) { _, message, _, _, _ ->
                        fixture.responses.offer(JSONObject(message.data!!))
                    }
                    WebViewCompat.addDocumentStartJavaScript(view, PROBE_SCRIPT, setOf("*"))
                    GameMouseWheelBridge.attach(view)
                    GameMouseWheelBridge.attach(view)
                    fixture.addToParent()
                    view.loadUrl("https://www.dmm.com/mouse-wheel-fixture")
                }
                try {
                    assertTrue("Local fixture loaded", loaded.await(20, TimeUnit.SECONDS))
                    val fixture = requireNotNull(game)
                    await("attached, focused WebView") { onMain { fixture.view.isAttachedToWindow && fixture.view.hasWindowFocus() && fixture.view.width > 0 } }
                    action(fixture)
                } finally {
                    onMain { game?.let { it.parent.removeView(it.view); it.view.destroy() } }
                }
            }
        } finally {
            onMain {
                val edit = preferences.edit()
                if (existed) edit.putBoolean(PREFERENCE, previous) else edit.remove(PREFERENCE)
                edit.commit()
            }
        }
    }

    private fun await(description: String, predicate: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 10_000
        while (SystemClock.uptimeMillis() < deadline) {
            if (predicate()) return
            SystemClock.sleep(50)
        }
        error("Timed out waiting for $description")
    }

    private fun <T> onMain(action: () -> T): T {
        val result = AtomicReference<Result<T>>()
        instrumentation.runOnMainSync { result.set(runCatching(action)) }
        return result.get().getOrThrow()
    }

    companion object {
        private const val PREFERENCE = "flutter.game.mouseWheelCompatibility"
        private const val GAME_URL = "https://w01.kancolle-server.com/kcs2/mouse-fixture"
        private val PROBE_SCRIPT = """
            (() => {
              const metrics = window.mouseProbe = {observers:0, canvasReads:0, layoutReads:0, wheels:0,
                documentId:String(Date.now()) + Math.random(), url:location.href};
              const NativeObserver = window.MutationObserver;
              window.MutationObserver = class extends NativeObserver {
                observe(...args) { if (!this.tracked) { metrics.observers++; this.tracked = true; } return super.observe(...args); }
                disconnect() { if (this.tracked) { metrics.observers--; this.tracked = false; } return super.disconnect(); }
              };
              const query = Document.prototype.querySelector;
              Document.prototype.querySelector = function(selector) {
                if (selector === 'canvas') metrics.canvasReads++;
                return query.call(this, selector);
              };
              const bounds = Element.prototype.getBoundingClientRect;
              Element.prototype.getBoundingClientRect = function() {
                if (this.tagName === 'CANVAS') metrics.layoutReads++;
                return bounds.call(this);
              };
            })();
        """.trimIndent()
        private val GAME_HTML = """
            <!doctype html><html><body style="margin:0"><canvas id="game" width="600" height="360" style="position:absolute;left:10px;top:20px"></canvas><script>
            const game = document.getElementById('game');
            game.addEventListener('wheel', event => {
              mouseProbe.wheels++;
              Object.assign(mouseProbe, {clientX:event.clientX, clientY:event.clientY, deltaY:event.deltaY});
            });
            window.addEventListener('message', event => {
              const data = event.data;
              if (!data || typeof data.request !== 'number') return;
              if (data.action === 'mutate') {
                game.classList.toggle('changed');
                document.body.appendChild(document.createElement('span'));
                dispatchEvent(new Event('resize'));
              }
              if (data.action === 'pagehide' || data.action === 'pageshow') dispatchEvent(new PageTransitionEvent(data.action, {persisted:true}));
              if (data.action === 'malformed') {
                YahagiMouseWheel.postMessage('not json');
                YahagiMouseWheel.postMessage('null');
                YahagiMouseWheel.postMessage(new ArrayBuffer(1));
              }
              setTimeout(() => MouseWheelProbe.postMessage(JSON.stringify({...mouseProbe, request:data.request})), 0);
            });
            </script></body></html>
        """.trimIndent()
    }
}
