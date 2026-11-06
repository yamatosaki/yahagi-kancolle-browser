package app.yahagi.kancollebrowser.browser

import android.webkit.WebResourceResponse
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.atomic.AtomicReference
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
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
    fun eachMainDocumentInvalidatesFitBeforeDelegatingEvenForTheSameUrl() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val events = mutableListOf<String>()
            val original = object : WebViewClient() {
                override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                    events += "delegate:$url"
                }
            }
            val client = GadgetBypassWebViewClient(
                original = original,
                engine = GadgetBypassEngine(GadgetBypassCache(cacheDir)),
                isEnabled = { false },
                endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
                onDocumentStarted = { events += "invalidate" },
            )
            repeat(2) { client.onPageStarted(null, "https://example.test/game", null) }
            assertEquals(listOf("invalidate", "delegate:https://example.test/game", "invalidate", "delegate:https://example.test/game"), events)
        }
    }

    @Test
    fun cookieAwareRequestInterceptionCanBeEnabledOnSupportedWebView() {
        assumeTrue(WebViewFeature.isFeatureSupported(WebViewFeature.COOKIE_INTERCEPT))
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val webView = WebView(ApplicationProvider.getApplicationContext())
            WebSettingsCompat.setCookiesIncludedInShouldInterceptRequest(webView.settings, true)
            webView.destroy()
        }
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

    @Test
    fun gameResourceCacheServesOfficialStaticAssetBeforeOriginalClient() {
        val sentinel = WebResourceResponse(
            "text/plain",
            "utf-8",
            ByteArrayInputStream("original".toByteArray()),
        )
        val original = RecordingClient(sentinel)
        val root = File(cacheDir, "game-resources")
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            GameResourceFetcher { _, _, _ ->
                GameResourceFetchResult(200, "OK", mapOf("Content-Type" to "image/png"), "cached".toByteArray())
            },
        ) { GameResourceCacheMode.LIGHT }
        val wrapper = GadgetBypassWebViewClient(
            original = original,
            engine = GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            isEnabled = { false },
            endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
            gameResourceEngine = resourceEngine,
            cookiesIncludedInRequestHeaders = true,
        )
        val actual = AtomicReference<WebResourceResponse?>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val webView = WebView(ApplicationProvider.getApplicationContext())
            actual.set(
                wrapper.shouldInterceptRequest(
                    webView,
                    request("https://w17k.kancolle-server.com/kcs2/resources/ship/full/a.png?version=1"),
                ),
            )
            webView.destroy()
        }

        assertEquals("cached", actual.get()!!.data.bufferedReader().readText())
        assertEquals(0, original.interceptCalls)
    }

    @Test
    fun legacyUrlOnlyCallbackServesOfficialStaticAssetThroughGameCache() {
        val sentinel = WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(byteArrayOf(9)))
        val original = RecordingClient(sentinel)
        val root = File(cacheDir, "legacy-resources")
        var fetches = 0
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            GameResourceFetcher { _, _, _ ->
                fetches++
                GameResourceFetchResult(200, "OK", emptyMap(), byteArrayOf(1))
            },
        ) { GameResourceCacheMode.FULL }
        val wrapper = GadgetBypassWebViewClient(
            original, GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            { false }, { GadgetBypassRules.DEFAULT_ENDPOINT }, resourceEngine, true,
        )
        val actual = AtomicReference<WebResourceResponse?>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val webView = WebView(ApplicationProvider.getApplicationContext())
            actual.set(wrapper.shouldInterceptRequest(
                webView, "https://w17k.kancolle-server.com/kcs2/resources/a.png"))
            webView.destroy()
        }
        assertNotNull(actual.get())
        actual.get()!!.data.use { stream ->
            assertArrayEquals(byteArrayOf(1), stream.readBytes())
        }
        assertEquals(1, fetches)
        assertEquals(0, original.interceptCalls)
    }

    @Test
    fun legacyApiCallbackDelegatesWithoutReadingGameCache() {
        val sentinel = WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(byteArrayOf(9)))
        val original = RecordingClient(sentinel)
        val root = File(cacheDir, "legacy-api-resources")
        var fetches = 0
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            GameResourceFetcher { _, _, _ ->
                fetches++
                GameResourceFetchResult(200, "OK", emptyMap(), byteArrayOf(1))
            },
        ) { GameResourceCacheMode.FULL }
        val wrapper = GadgetBypassWebViewClient(
            original, GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            { false }, { GadgetBypassRules.DEFAULT_ENDPOINT }, resourceEngine, true,
        )
        val actual = AtomicReference<WebResourceResponse?>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val webView = WebView(ApplicationProvider.getApplicationContext())
            actual.set(wrapper.shouldInterceptRequest(
                webView, "https://w17k.kancolle-server.com/kcsapi/api_port/port"))
            webView.destroy()
        }
        assertSame(sentinel, actual.get())
        assertEquals(0, fetches)
        assertEquals(1, original.interceptCalls)
    }

    private fun request(url: String): WebResourceRequest = object : WebResourceRequest {
        override fun getUrl(): Uri = Uri.parse(url)
        override fun isForMainFrame(): Boolean = false
        override fun isRedirect(): Boolean = false
        override fun hasGesture(): Boolean = false
        override fun getMethod(): String = "GET"
        override fun getRequestHeaders(): Map<String, String> = mapOf("Cookie" to "sid=browser")
    }

    @Test
    fun postToStaticPathIsDelegatedWithoutFetching() {
        val sentinel = WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(byteArrayOf(9)))
        val original = RecordingClient(sentinel)
        val root = File(cacheDir, "post-resources")
        var fetches = 0
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            GameResourceFetcher { _, _, _ ->
                fetches++
                GameResourceFetchResult(200, "OK", emptyMap(), byteArrayOf(1))
            },
        ) { GameResourceCacheMode.TEMPORARY }
        val wrapper = GadgetBypassWebViewClient(
            original = original,
            engine = GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            isEnabled = { false },
            endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
            gameResourceEngine = resourceEngine,
            cookiesIncludedInRequestHeaders = true,
        )
        val request = object : WebResourceRequest {
            override fun getUrl(): Uri = Uri.parse("https://w17k.kancolle-server.com/kcs2/resources/a.png")
            override fun isForMainFrame(): Boolean = false
            override fun isRedirect(): Boolean = false
            override fun hasGesture(): Boolean = false
            override fun getMethod(): String = "POST"
            override fun getRequestHeaders(): Map<String, String> = emptyMap()
        }
        val actual = AtomicReference<WebResourceResponse?>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val webView = WebView(ApplicationProvider.getApplicationContext())
            actual.set(wrapper.shouldInterceptRequest(webView, request))
            webView.destroy()
        }

        assertSame(sentinel, actual.get())
        assertEquals(1, original.interceptCalls)
        assertEquals(0, fetches)
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

        override fun shouldInterceptRequest(
            view: WebView,
            request: WebResourceRequest,
        ): WebResourceResponse {
            interceptCalls += 1
            return response
        }
    }
}
