package app.yahagi.kancollebrowser

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.junit.After
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Actual WebView mute APIs, using local documents without game/account access. */
@RunWith(AndroidJUnit4::class)
class GameWebViewAudioTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val views = mutableListOf<WebView>()

    @Before fun requireMuteSupport() {
        instrumentation.runOnMainSync {
            assumeTrue("Runtime WebView must support per-view mute", WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO))
        }
    }

    @After fun destroyViews() {
        instrumentation.runOnMainSync {
            views.forEach { it.stopLoading(); it.destroy() }
            views.clear()
        }
    }

    @Test fun muteIsAppliedBeforeLocalNavigationForThreeReplacementViews() {
        val state = GameWebViewAudioState<WebView>()
        state.setTarget(true)
        repeat(3) {
            val view = createView()
            instrumentation.runOnMainSync {
                assertFalse(WebViewCompat.isAudioMuted(view))
                assertTrue(state.reconcile(view, apply = WebViewCompat::setAudioMuted))
                assertTrue("Replacement must be muted before its first load", WebViewCompat.isAudioMuted(view))
            }
            loadLocal(view)
            instrumentation.runOnMainSync { assertTrue(WebViewCompat.isAudioMuted(view)) }
        }
    }

    @Test fun localReloadPreservesMuteAndRepeatedLayoutDoesNotReapplyIt() {
        val view = createView()
        val state = GameWebViewAudioState<WebView>()
        var writes = 0
        val apply = { owner: WebView, muted: Boolean ->
            writes++
            WebViewCompat.setAudioMuted(owner, muted)
        }
        instrumentation.runOnMainSync {
            state.setTarget(true)
            state.reconcile(view, apply = apply)
        }
        loadLocal(view)
        awaitDocument(view) { it.reload() }
        instrumentation.runOnMainSync {
            repeat(200) { assertFalse(state.reconcile(view, apply = apply)) }
            assertEquals(1, writes)
            assertTrue(WebViewCompat.isAudioMuted(view))
        }
    }

    @Test fun resumeRepairRestoresActualMuteAndOnlyAnExplicitRequestUnmutes() {
        val view = createView()
        val state = GameWebViewAudioState<WebView>()
        instrumentation.runOnMainSync {
            state.setTarget(true)
            state.reconcile(view, apply = WebViewCompat::setAudioMuted)
            WebViewCompat.setAudioMuted(view, false)
            assertFalse(WebViewCompat.isAudioMuted(view))
            assertTrue(state.reconcile(view, force = true, apply = WebViewCompat::setAudioMuted))
            assertTrue(WebViewCompat.isAudioMuted(view))
            state.setTarget(false)
            assertTrue(state.reconcile(view, apply = WebViewCompat::setAudioMuted))
            assertFalse(WebViewCompat.isAudioMuted(view))
        }
    }

    @Test fun muteRequestedBeforeAttachmentIsAppliedToTheFirstActualView() {
        val state = GameWebViewAudioState<WebView>()
        state.setTarget(true)
        assertFalse(state.reconcile(null, apply = WebViewCompat::setAudioMuted))
        val view = createView()
        instrumentation.runOnMainSync {
            assertTrue(state.reconcile(view, apply = WebViewCompat::setAudioMuted))
            assertTrue(WebViewCompat.isAudioMuted(view))
        }
    }

    private fun createView(): WebView {
        lateinit var view: WebView
        instrumentation.runOnMainSync {
            view = WebView(instrumentation.targetContext)
            views.add(view)
        }
        return view
    }

    private fun loadLocal(view: WebView) = awaitDocument(view) {
        it.loadDataWithBaseURL("https://audio-smoke.invalid/", "<html><body>Local audio mute smoke</body></html>", "text/html", "utf-8", null)
    }

    private fun awaitDocument(view: WebView, load: (WebView) -> Unit) {
        val finished = CountDownLatch(1)
        instrumentation.runOnMainSync {
            view.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) { finished.countDown() }
            }
            load(view)
        }
        assertTrue("Local WebView document did not finish", finished.await(10, TimeUnit.SECONDS))
    }
}
