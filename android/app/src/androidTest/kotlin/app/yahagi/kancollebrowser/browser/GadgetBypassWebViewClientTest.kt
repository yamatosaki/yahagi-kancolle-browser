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
    fun kanxyVpnUsesFreshNativeResponsesUntilItDisconnects() {
        val portrait = "https://w17k.kancolle-server.com/kcs2/resources/ship/full/0623_5644_tuzbqjvyptyt.png?version=1"
        val script = "https://w17k.kancolle-server.com/kcs2/js/main.js?version=1"
        val missing = "https://w17k.kancolle-server.com/kcs2/resources/ship/full/missing.png?version=1"
        val passthrough = response("webview")
        val original = RecordingClient(passthrough)
        val root = File(cacheDir, "kanxy-game-resources")
        val fetches = mutableListOf<String>()
        var kanxyActive = false
        var localModEnabled = false
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            GameResourceFetcher { url, _, _ ->
                fetches += url
                val body = when (url) {
                    portrait -> if (kanxyActive) "kanxy portrait" else "cached portrait"
                    script -> "kanxy script"
                    else -> return@GameResourceFetcher null
                }
                GameResourceFetchResult(200, "OK", emptyMap(), body.toByteArray())
            },
        ) { GameResourceCacheMode.FULL }
        val wrapper = GadgetBypassWebViewClient(
            original = original,
            engine = GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            isEnabled = { false },
            endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
            gameResourceEngine = resourceEngine,
            cookiesIncludedInRequestHeaders = true,
            modResourceInterceptor = { url, method, _ ->
                if (localModEnabled && url == portrait && method == "GET") response("local portrait") else null
            },
            useFreshGameResources = { kanxyActive },
        )

        withWebView { webView ->
            val portraitRequest = request(portrait)
            assertEquals("cached portrait", wrapper.shouldInterceptRequest(webView, portraitRequest)?.readBody())

            kanxyActive = true
            localModEnabled = true
            assertEquals("local portrait", wrapper.shouldInterceptRequest(webView, portraitRequest)?.readBody())
            assertEquals(listOf(portrait), fetches)
            localModEnabled = false
            val freshPortrait = wrapper.shouldInterceptRequest(webView, portraitRequest)
            assertEquals("kanxy portrait", freshPortrait?.readBody())
            assertEquals("no-store", freshPortrait?.responseHeaders?.get("Cache-Control"))
            assertEquals("kanxy portrait", wrapper.shouldInterceptRequest(webView, portrait)?.readBody())
            assertEquals("kanxy script", wrapper.shouldInterceptRequest(webView, request(script))?.readBody())
            assertSame(passthrough, wrapper.shouldInterceptRequest(webView, request(missing)))

            kanxyActive = false
            assertEquals("cached portrait", wrapper.shouldInterceptRequest(webView, portraitRequest)?.readBody())
        }
        assertEquals(listOf(portrait, portrait, portrait, script, missing), fetches)
        assertEquals(1, original.interceptCalls)
    }

    @Test
    fun kanxySocketFallbackPrefixesOnlyTheActiveGameWebViewsFreshMainScript() {
        val url = "https://w17k.kancolle-server.com/kcs2/js/main.js?version=1"
        val otherScript = url.replace("main.js", "other.js")
        val otherPort = url.replace(".com/", ".com:444/")
        val body = "window.gameLoaded = true;"
        val passthrough = response("webview")
        val root = File(cacheDir, "kanxy-main-script-fallback")
        var routeActive = true
        var localModEnabled = false
        var encoded = false
        var fallbackView: WebView? = null
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            GameResourceFetcher { _, _, _ ->
                val headers = mapOf(
                    "Content-Type" to "application/javascript; charset=utf-8",
                    "cOnTeNt-LeNgTh" to body.length.toString(),
                    "ETag" to "\"original\"",
                    "Digest" to "sha-256=original",
                    "Last-Modified" to "Fri, 13 Nov 2026 00:00:00 GMT",
                    "X-Content-Type-Options" to "nosniff",
                ) + if (encoded) mapOf("Content-Encoding" to "gzip") else emptyMap()
                GameResourceFetchResult(200, "OK", headers, body.toByteArray())
            },
        ) { GameResourceCacheMode.FULL }
        val wrapper = GadgetBypassWebViewClient(
            original = RecordingClient(passthrough),
            engine = GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            isEnabled = { false },
            endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
            gameResourceEngine = resourceEngine,
            cookiesIncludedInRequestHeaders = true,
            modResourceInterceptor = { _, _, _ -> if (localModEnabled) response("local script") else null },
            useFreshGameResources = { routeActive },
            needsKanxyScriptFallback = { it === fallbackView },
        )

        withWebView { webView ->
            assertEquals(body, wrapper.shouldInterceptRequest(webView, request(url))?.readBody())
            fallbackView = webView
            val prefixed = requireNotNull(wrapper.shouldInterceptRequest(webView, request(url)))
            val prefixedBody = prefixed.readBody()
            assertTrue(prefixedBody.startsWith(KanxyWebSocketScript.source))
            assertTrue(prefixedBody.endsWith(body))
            assertEquals("no-store", prefixed.responseHeaders["Cache-Control"])
            assertEquals("nosniff", prefixed.responseHeaders["X-Content-Type-Options"])
            assertTrue(prefixed.responseHeaders.keys.none {
                it.lowercase() in setOf("content-length", "etag", "digest", "last-modified")
            })

            assertEquals(body, wrapper.shouldInterceptRequest(webView, request(otherScript))?.readBody())
            assertSame(passthrough, wrapper.shouldInterceptRequest(webView, request(otherPort)))
            assertEquals(body, wrapper.shouldInterceptRequest(webView, request(url, redirected = true))?.readBody())

            localModEnabled = true
            assertEquals("local script", wrapper.shouldInterceptRequest(webView, request(url))?.readBody())
            localModEnabled = false
            encoded = true
            assertEquals(body, wrapper.shouldInterceptRequest(webView, request(url))?.readBody())
            encoded = false
            routeActive = false
            assertEquals(body, wrapper.shouldInterceptRequest(webView, request(url))?.readBody())
        }
    }

    @Test
    fun localModAndGadgetMirrorStillTakePriorityWhenKanxyVpnIsActive() {
        val url = "https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js"
        val endpoint = "https://mirror.invalid/cache/"
        val mirrorCache = GadgetBypassCache(cacheDir)
        mirrorCache.put("${endpoint.trimEnd('/')}\n$url", "window.fromMirror = true;".toByteArray())
        val original = RecordingClient(response("webview"))
        var modEnabled = true
        var mirrorHits = 0
        val wrapper = GadgetBypassWebViewClient(
            original = original,
            engine = GadgetBypassEngine(mirrorCache, onCacheHit = { mirrorHits++ }),
            isEnabled = { true },
            endpoint = { endpoint },
            modResourceInterceptor = { requestUrl, method, _ ->
                if (modEnabled && requestUrl == url && method == "GET") response("local mod") else null
            },
            useFreshGameResources = { true },
        )

        withWebView { webView ->
            assertEquals("local mod", wrapper.shouldInterceptRequest(webView, request(url))?.readBody())
            assertEquals(0, mirrorHits)

            modEnabled = false
            assertEquals("window.fromMirror = true;", wrapper.shouldInterceptRequest(webView, url)?.readBody())
        }
        assertEquals(1, mirrorHits)
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

    private fun request(url: String, redirected: Boolean = false): WebResourceRequest = object : WebResourceRequest {
        override fun getUrl(): Uri = Uri.parse(url)
        override fun isForMainFrame(): Boolean = false
        override fun isRedirect(): Boolean = redirected
        override fun hasGesture(): Boolean = false
        override fun getMethod(): String = "GET"
        override fun getRequestHeaders(): Map<String, String> = mapOf("Cookie" to "sid=browser")
    }

    private fun response(body: String) =
        WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(body.toByteArray()))

    private fun WebResourceResponse.readBody(): String = data.bufferedReader().use { it.readText() }

    private fun withWebView(action: (WebView) -> Unit) {
        val result = AtomicReference<Result<Unit>>()
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            result.set(runCatching {
                val webView = WebView(ApplicationProvider.getApplicationContext())
                try {
                    action(webView)
                } finally {
                    webView.destroy()
                }
            })
        }
        result.get().getOrThrow()
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
