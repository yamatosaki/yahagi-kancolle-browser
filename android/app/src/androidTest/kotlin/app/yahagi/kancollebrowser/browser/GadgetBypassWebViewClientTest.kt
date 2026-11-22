package app.yahagi.kancollebrowser.browser

import android.graphics.Bitmap
import android.graphics.Color
import android.webkit.WebResourceResponse
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.net.InetSocketAddress
import java.net.Proxy
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONTokener
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
    fun kanxyHttpReusesTheBannerWithinOneSessionAndRestoresStockAfterDisconnect() {
        val banner = "https://w17k.kancolle-server.com/kcs2/resources/ship/banner/0623_5644.png?version=1"
        val original = RecordingClient(response("webview"))
        val root = File(cacheDir, "kanxy-http-game-resources")
        val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress("127.0.0.1", 7410))
        val stockImage = png(Color.BLUE)
        val modifiedImage = png(Color.RED)
        val updatedImage = png(Color.GREEN)
        var session: KanxyHttpImageCache? = null
        var proxyImage = modifiedImage
        var downloads = 0
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            GameResourceFetcher { url, _, _ ->
                assertEquals(banner, url)
                downloads++
                val body = if (session == null) stockImage else proxyImage
                val download = File.createTempFile("banner", ".part", root).apply { writeBytes(body) }
                GameResourceFetchResult(
                    200,
                    "OK",
                    mapOf("Content-Type" to "image/png", "Cache-Control" to "public, max-age=60"),
                    file = download,
                )
            },
            kanxyHttpImageCache = { session },
        ) { if (session == null) GameResourceCacheMode.FULL else GameResourceCacheMode.NONE }
        val wrapper = GadgetBypassWebViewClient(
            original = original,
            engine = GadgetBypassEngine(GadgetBypassCache(cacheDir)),
            isEnabled = { false },
            endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
            gameResourceEngine = resourceEngine,
            cookiesIncludedInRequestHeaders = true,
            useFreshGameResources = { session != null },
        )

        withWebView { webView ->
            val bannerRequest = request(banner)
            fun requestBanner() = requireNotNull(wrapper.shouldInterceptRequest(webView, bannerRequest))

            assertArrayEquals(stockImage, requestBanner().data.use { it.readBytes() })
            assertEquals(1, downloads)

            session = KanxyHttpImageCache(proxy)
            assertArrayEquals(modifiedImage, requestBanner().data.use { it.readBytes() })
            proxyImage = updatedImage
            val cached = requestBanner()
            assertArrayEquals(modifiedImage, cached.data.use { it.readBytes() })
            assertEquals("no-store", cached.responseHeaders["Cache-Control"])
            assertEquals(2, downloads)

            session = KanxyHttpImageCache(proxy)
            assertArrayEquals(updatedImage, requestBanner().data.use { it.readBytes() })
            assertEquals(3, downloads)

            session = null
            assertArrayEquals(stockImage, requestBanner().data.use { it.readBytes() })
            assertEquals(3, downloads)
        }
        assertEquals(0, original.interceptCalls)
    }

    @Test
    fun realWebViewLoadsTheSameBannerAcrossKanxyHttpSessionChanges() {
        val baseUrl = "https://w17k.kancolle-server.com/"
        val banner = "${baseUrl}kcs2/resources/ship/banner/0623_5644.png?version=1"
        val documentPrefix = "${baseUrl}yahagi-cache-smoke.html?scene="
        val document = """
            <!doctype html>
            <meta name="referrer" content="no-referrer">
            <img id="banner" src="$banner">
        """.trimIndent().toByteArray()
        val finishedDocuments = LinkedBlockingQueue<String>()
        val root = File(cacheDir, "kanxy-http-real-webview")
        val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress("127.0.0.1", 7410))
        val stock = png(Color.BLUE)
        val proxyImage = AtomicReference(png(Color.RED))
        val session = AtomicReference<KanxyHttpImageCache?>()
        val interceptions = AtomicInteger()
        val stockDownloads = AtomicInteger()
        val proxyDownloads = AtomicInteger()
        val fallbackAttempts = AtomicInteger()
        val requestHeaderNames = AtomicReference<Set<String>>(emptySet())
        val fetcher = object : GameResourceFetcher {
            override fun fetch(
                url: String,
                requestHeaders: Map<String, String>,
                cached: GameResourceCacheEntry?,
            ): GameResourceFetchResult? {
                if (url != banner) return null
                stockDownloads.incrementAndGet()
                return imageResponse(stock)
            }

            override fun fetchViaHttpProxy(
                url: String,
                requestHeaders: Map<String, String>,
                proxy: Proxy,
                deadlineNanos: Long,
            ): GameResourceFetchResult? {
                if (url != banner || proxy != session.get()?.proxy) return null
                proxyDownloads.incrementAndGet()
                return imageResponse(proxyImage.get())
            }

            private fun imageResponse(bytes: ByteArray) = GameResourceFetchResult(
                200, "OK", mapOf("Content-Type" to "image/png", "Cache-Control" to "public, max-age=60"), bytes,
            )
        }
        val engine = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(File(root, "index.json")), 10_000),
            fetcher,
            kanxyHttpImageCache = session::get,
        ) { if (session.get() == null) GameResourceCacheMode.FULL else GameResourceCacheMode.NONE }
        val wrapper = GadgetBypassWebViewClient(
            original = object : WebViewClient() {
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                    val url = request.url.toString()
                    if (request.isForMainFrame && url.startsWith(documentPrefix)) {
                        return WebResourceResponse(
                            "text/html", "utf-8", 200, "OK", mapOf("Cache-Control" to "no-store"),
                            ByteArrayInputStream(document),
                        )
                    }
                    if (url == banner) fallbackAttempts.incrementAndGet()
                    return WebResourceResponse(
                        "text/plain", "utf-8", 404, "Not Found", mapOf("Cache-Control" to "no-store"),
                        ByteArrayInputStream(ByteArray(0)),
                    )
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    if (url?.startsWith(documentPrefix) == true) finishedDocuments.add(url)
                }
            },
            engine = GadgetBypassEngine(GadgetBypassCache(File(cacheDir, "kanxy-http-real-webview-bypass"))),
            isEnabled = { false },
            endpoint = { GadgetBypassRules.DEFAULT_ENDPOINT },
            gameResourceEngine = engine,
            cookiesIncludedInRequestHeaders = true,
            modResourceInterceptor = { url, _, headers ->
                if (url == banner) {
                    interceptions.incrementAndGet()
                    requestHeaderNames.set(headers.keys.toSet())
                }
                null
            },
            useFreshGameResources = { session.get() != null },
        )

        val instrumentation = InstrumentationRegistry.getInstrumentation()
        lateinit var webView: WebView
        instrumentation.runOnMainSync {
            webView = WebView(ApplicationProvider.getApplicationContext()).apply {
                settings.javaScriptEnabled = true
                settings.cacheMode = WebSettings.LOAD_NO_CACHE
                webViewClient = wrapper
            }
        }
        try {
            fun assertBanner(stage: String, pixel: String, interceptCount: Int, proxyCount: Int) {
                val actualPixel = loadBannerPixel(webView, "$documentPrefix$interceptCount", finishedDocuments)
                assertEquals("$stage must reach native interception", interceptCount, interceptions.get())
                assertEquals("$stage must keep the original cached download", 1, stockDownloads.get())
                assertEquals("$stage request headers: ${requestHeaderNames.get()}", proxyCount, proxyDownloads.get())
                assertEquals("$stage must not fall back to WebView networking", 0, fallbackAttempts.get())
                assertEquals(stage, pixel, actualPixel)
            }

            assertBanner("stock", "0,0,255,255", interceptCount = 1, proxyCount = 0)
            session.set(KanxyHttpImageCache(proxy))
            assertBanner("first Kanxy load", "255,0,0,255", interceptCount = 2, proxyCount = 1)
            proxyImage.set(png(Color.GREEN))
            assertBanner("warm Kanxy load", "255,0,0,255", interceptCount = 3, proxyCount = 1)
            session.set(KanxyHttpImageCache(proxy))
            assertBanner("renewed Kanxy session", "0,255,0,255", interceptCount = 4, proxyCount = 2)
            session.set(null)
            assertBanner("disconnected", "0,0,255,255", interceptCount = 5, proxyCount = 2)
        } finally {
            instrumentation.runOnMainSync { webView.destroy() }
        }
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

    private fun loadBannerPixel(
        webView: WebView,
        documentUrl: String,
        finishedDocuments: LinkedBlockingQueue<String>,
    ): String? {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        instrumentation.runOnMainSync {
            // Clear Blink's memory so the next document asks the app for the same image URL.
            webView.clearCache(false)
            webView.loadUrl(documentUrl)
        }
        assertEquals("Chromium did not finish loading the smoke document", documentUrl,
            finishedDocuments.poll(15, TimeUnit.SECONDS))
        val pixel = AtomicReference<String>()
        val read = CountDownLatch(1)
        instrumentation.runOnMainSync {
            webView.evaluateJavascript("""
                (() => {
                    const image = document.getElementById('banner');
                    if (!image) return 'missing-banner';
                    if (image.naturalWidth === 0) return 'image-error';
                    const canvas = document.createElement('canvas');
                    canvas.width = canvas.height = 1;
                    const context = canvas.getContext('2d');
                    context.drawImage(image, 0, 0);
                    return Array.from(context.getImageData(0, 0, 1, 1).data).join(',');
                })()
            """.trimIndent()) { value ->
                pixel.set(value)
                read.countDown()
            }
        }
        assertTrue("Chromium did not return the banner pixel", read.await(10, TimeUnit.SECONDS))
        return pixel.get()?.let { JSONTokener(it).nextValue() as? String }
    }

    private fun png(color: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        try {
            bitmap.eraseColor(color)
            val bytes = ByteArrayOutputStream()
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes))
            return bytes.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

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
