package app.yahagi.kancollebrowser.browser

import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@Suppress("DEPRECATION")
class GadgetBypassWebViewClientTest {
    private val cacheDir = File(
        ApplicationProvider.getApplicationContext<android.content.Context>().cacheDir,
        "gadget-bypass-webview-test",
    )

    @After
    fun tearDown() {
        cacheDir.deleteRecursively()
    }

    @Test
    fun disabledBypassDelegatesToOriginalClient() {
        assertDelegates(
            enabled = false,
            url = "https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js",
        )
    }

    @Test
    fun enabledBypassDelegatesRequestsOutsideItsScope() {
        assertDelegates(
            enabled = true,
            url = "https://w00g.kancolle-server.com/kcsapi/api_port/port",
        )
    }

    @Test
    fun defaultMirrorServesTheLiveProbeResource() {
        val bytes = GadgetBypassEngine(GadgetBypassCache(cacheDir)).fetch(
            GadgetBypassDiagnostics.w00gGadgetUrl(),
            GadgetBypassRules.DEFAULT_ENDPOINT,
        )

        assertNotNull(bytes)
        assertTrue(bytes!!.size > 100)
    }

    private fun assertDelegates(enabled: Boolean, url: String) {
        val sentinel = WebResourceResponse(
            "text/plain",
            "utf-8",
            ByteArrayInputStream("original".toByteArray()),
        )
        val original = RecordingClient(sentinel)
        val wrapper = GadgetBypassWebViewClient(
            original = original,
            engine = GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            isEnabled = { enabled },
            endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
        )
        val actual = AtomicReference<WebResourceResponse?>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val webView = WebView(ApplicationProvider.getApplicationContext())
            actual.set(wrapper.shouldInterceptRequest(webView, url))
            webView.destroy()
        }

        assertSame(sentinel, actual.get())
        assertEquals(1, original.interceptCalls)
    }

    private class RecordingClient(
        private val response: WebResourceResponse,
    ) : WebViewClient() {
        var interceptCalls = 0

        override fun shouldInterceptRequest(
            view: WebView,
            url: String,
        ): WebResourceResponse {
            interceptCalls += 1
            return response
        }
    }
}
