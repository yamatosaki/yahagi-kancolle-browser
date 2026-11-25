package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.mods.GameModRepository
import app.yahagi.kancollebrowser.mods.toWebResourceResponse
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class GameModStaticWebViewTest {
    @Test fun webViewLoadsLocalEquipmentArtTitleAndOpenTypeFont() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val root = File(context.cacheDir, "static-mod-webview-${System.nanoTime()}")
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        var webView: WebView? = null
        try {
            val repo = GameModRepository(File(root, "mods"))
            val zip = localStaticArchive()
            val preview = repo.preflight(ByteArrayInputStream(zip), "local.zip")
            assertEquals(4, preview["supportedCount"])
            val entry = repo.commitImport(preview["token"] as String)
            val resourceIds = (entry["resources"] as List<*>).map { (it as Map<*, *>)["id"] }
            val packageIds = listOf(entry["id"])
            repo.saveDraft(mapOf("master" to true, "order" to packageIds,
                "enabledPackages" to packageIds, "enabledResources" to resourceIds))
            repo.finishApply(repo.applyDraft())

            val result = WebViewResult()
            instrumentation.runOnMainSync {
                webView = WebView(context).apply {
                    settings.javaScriptEnabled = true
                    webViewClient = GadgetBypassWebViewClient(
                        object : WebViewClient() {
                            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                                if (request.isForMainFrame) return null
                                return WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", emptyMap(),
                                    ByteArrayInputStream(byteArrayOf()))
                            }
                        },
                        GadgetBypassEngine(GadgetBypassCache(File(root, "bypass"))),
                        { false }, { GadgetBypassRules.DEFAULT_ENDPOINT }, null, true,
                        modResourceInterceptor = { url, method, headers ->
                            repo.openResource(url, method, headers)?.toWebResourceResponse()
                        },
                    )
                    addJavascriptInterface(result, "AssetProbe")
                }
            }
            instrumentation.runOnMainSync {
                checkNotNull(webView).loadDataWithBaseURL("https://w15p.kancolle-server.com/", PROBE, "text/html", "UTF-8", null)
            }

            assertTrue("WebView did not finish the local resource requests, last event: ${result.lastEvent}",
                result.done.await(25, TimeUnit.SECONDS))
            assertEquals("2,2,2,font/otf:loaded", result.value)
            assertEquals(resourceIds.toSet(), (repo.status()["hits"] as List<*>).toSet())
        } finally {
            instrumentation.runOnMainSync { webView?.destroy() }
            root.deleteRecursively()
        }
    }

    @Test fun applyingFontChangesReloadsTheOriginalAndReplacementGlyphsAtTheSameUrl() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val version = System.nanoTime().toString()
        val root = File(context.cacheDir, "font-mod-webview-$version")
        val gameOrigin = "https://w13665p.kancolle-server.com"
        val outerOrigin = "https://font-probe.kancolle-server.com"
        val outerPath = "/font-probe-outer.html"
        val frameUrl = "$gameOrigin/kcs2/font-probe.html?version=$version"
        val cssPath = "/kcs2/font-probe.css"
        val fontPath = "/kcs2/resources/font/A-OTF-UDShinGoPro-Regular.woff2"
        val stockBytes = Base64.decode(STOCK_FONT, Base64.DEFAULT)
        val result = FontProbeResult()
        var webView: WebView? = null
        try {
            val repo = GameModRepository(File(root, "mods"))
            val preview = repo.preflight(ByteArrayInputStream(localStaticArchive()), "fonts.zip")
            val entry = repo.commitImport(preview["token"] as String)
            val packageIds = listOf(entry["id"])
            val fontId = (entry["resources"] as List<*>).map { it as Map<*, *> }
                .single { it["kind"] == "font" }["id"]
            val frame = """
                <link rel="stylesheet" href="$cssPath?version=$version">
                <body>AAAA<script>
                const report = value => parent.postMessage(value, '$outerOrigin');
                (async () => {
                  const font = '100px GameProbeFont';
                  const loaded = await document.fonts.load(font, 'AAAA');
                  if (!loaded.length) throw new Error('No loaded font');
                  const canvas = document.createElement('canvas').getContext('2d');
                  canvas.font = font;
                  report(String(Math.round(canvas.measureText('AAAA').width)));
                })().catch(error => report(String(error)));
                </script></body>
            """.trimIndent()
            val stylesheet = """
                @font-face { font-family: GameProbeFont; src: url('$fontPath?version=$version'); }
                body { font-family: GameProbeFont; }
            """.trimIndent()
            val outer = """
                <script>
                window.addEventListener('message', event => {
                  if (event.origin === '$gameOrigin') FontProbe.report(event.data);
                });
                window.reloadProbe = () => {
                  const frame = document.getElementById('htmlWrap');
                  frame.setAttribute('src', frame.getAttribute('src'));
                };
                </script>
                <iframe id="htmlWrap" src="$frameUrl"></iframe>
            """.trimIndent()
            val cacheable = "public, max-age=86400"
            fun response(mime: String, cache: String, bytes: ByteArray) = WebResourceResponse(
                mime, if (mime.startsWith("text/")) "UTF-8" else null,
                200, "OK", mapOf("Cache-Control" to cache), ByteArrayInputStream(bytes),
            )
            instrumentation.runOnMainSync {
                webView = WebView(context).apply {
                    settings.javaScriptEnabled = true
                    webViewClient = object : WebViewClient() {
                        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                            repo.openResource(request.url.toString(), request.method, request.requestHeaders)
                                ?.let { return it.toWebResourceResponse() }
                            return when (request.url.path) {
                                outerPath -> response("text/html", "no-store", outer.toByteArray())
                                "/kcs2/font-probe.html" -> response("text/html", "no-store", frame.toByteArray())
                                cssPath -> response("text/css", cacheable, stylesheet.toByteArray())
                                fontPath -> response("font/woff2", cacheable, stockBytes)
                                else -> WebResourceResponse("text/plain", "UTF-8", 404, "Not Found",
                                    emptyMap(), ByteArrayInputStream(byteArrayOf()))
                            }
                        }
                    }
                    addJavascriptInterface(result, "FontProbe")
                    loadUrl("$outerOrigin$outerPath")
                }
            }
            fun reloadWithFont(enabled: Boolean) {
                repo.saveDraft(mapOf("master" to true, "order" to packageIds,
                    "enabledPackages" to if (enabled) packageIds else emptyList(),
                    "enabledResources" to listOf(fontId)))
                val token = repo.prepareApply()
                val fontWinnersChanged = repo.publishApply(token)
                repo.finishApply(token)
                instrumentation.runOnMainSync {
                    checkNotNull(webView).apply {
                        if (fontWinnersChanged) clearCache(false)
                        evaluateJavascript("window.reloadProbe()", null)
                    }
                }
            }

            assertEquals("Original glyphs before enabling", "160", result.widths.poll(15, TimeUnit.SECONDS))
            reloadWithFont(true)
            assertEquals("Imported glyphs after enabling", "240", result.widths.poll(15, TimeUnit.SECONDS))
            reloadWithFont(false)
            assertEquals("Original glyphs after disabling", "160", result.widths.poll(15, TimeUnit.SECONDS))
        } finally {
            instrumentation.runOnMainSync { webView?.destroy() }
            root.deleteRecursively()
        }
    }

    private fun localStaticArchive(): ByteArray = ByteArrayOutputStream().also { output ->
        val png = bitmap(Bitmap.CompressFormat.PNG)
        val files = mapOf(
            "cache/kcs2/resources/slot/item_up/0123_4567.hack.png" to png,
            "cache/kcs2/img/title/title2.hack.jpg" to bitmap(Bitmap.CompressFormat.JPEG),
            "cache/kcs/html/maintenance.hack.png" to png,
            "cache/kcs2/resources/font/A-OTF-UDShinGoPro-Regular.hack.woff2" to Base64.decode(OPEN_TYPE, Base64.DEFAULT),
        )
        ZipOutputStream(output).use { zip ->
            files.forEach { (path, bytes) ->
                zip.putNextEntry(ZipEntry(path))
                zip.write(bytes)
                zip.closeEntry()
            }
        }
    }.toByteArray()

    private fun bitmap(format: Bitmap.CompressFormat): ByteArray = ByteArrayOutputStream().use { output ->
        val bitmap = Bitmap.createBitmap(2, 2, Bitmap.Config.ARGB_8888)
        try {
            bitmap.eraseColor(Color.RED)
            check(bitmap.compress(format, 100, output))
            output.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

    class WebViewResult {
        val done = CountDownLatch(1)
        @Volatile var value: String? = null
        @Volatile var lastEvent: String? = null

        @JavascriptInterface fun event(event: String) { lastEvent = event }

        @JavascriptInterface fun report(result: String) {
            value = result
            done.countDown()
        }
    }

    class FontProbeResult {
        val widths = LinkedBlockingQueue<String>()
        @JavascriptInterface fun report(width: String) { widths.add(width) }
    }

    private companion object {
        val PROBE = """
            <html><body><script>
            window.addEventListener('error', error => AssetProbe.report(error.message));
            AssetProbe.event('page started');
            function image(path) {
              return new Promise((resolve, reject) => {
                const item = new Image();
                item.onload = () => {
                  AssetProbe.event(path);
                  resolve(item.naturalWidth);
                };
                item.onerror = () => reject(new Error(path));
                item.src = path;
                document.body.appendChild(item);
              });
            }
            async function loadFont() {
              const response = await fetch('/kcs2/resources/font/A-OTF-UDShinGoPro-Regular.woff2?version=test');
              if (!response.ok) throw new Error('Font request: ' + response.status);
              const font = new FontFace('LocalModTest', await response.arrayBuffer());
              document.fonts.add(font);
              AssetProbe.event('font fetched');
              const loaded = await font.load();
              return response.headers.get('Content-Type') + ':' + loaded.status;
            }
            Promise.all([
              image('/kcs2/resources/slot/item_up/0123_4567.png?version=test'),
              image('/kcs2/img/title/title2.jpg?version=test'),
              image('/html/maintenance.png'),
              loadFont()
            ]).then(values => AssetProbe.report(values.join(',')),
              error => AssetProbe.report(String(error)));
            </script></body></html>
        """.trimIndent()

        // A generated two-glyph OpenType CFF font. CHS uses this payload format behind a .woff2 URL.
        val OPEN_TYPE = """
        T1RUTwAJAIAAAwAQQ0ZGIFizZfQAAALYAAAAd09TLzJFIUQ1AAABAAAAAGBjbWFwAAwAlAAAAoQAAAA0aGVhZC/CDeoA
        AACcAAAANmhoZWEFegHEAAAA1AAAACRobXR4AooAAAAAA1AAAAAGbWF4cAACUAAAAAD4AAAABm5hbWWflg2CAAABYAAA
        ASNwb3N0AAMAAAAAArgAAAAgAAEAAAABAAD8V6zZXw889QADA+gAAAAA5ynlDgAAAADnKeUOADIAAAImAu4AAAADAAIA
        AAAAAAAAAQAAAyD/OAAAAlgAMgAyAiYAAQAAAAAAAAAAAAAAAAAAAAEAAFAAAAIAAAADAlgBkAAFAAQAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAA/Pz8/AAAAQQBBAyD/OAAAAyAAyAAAAAAAAAAAAAAA
        AAAAACAAAAAAAAoAfgABAAAAAAABAAsAAAABAAAAAAACAAcACwABAAAAAAADABMAEgABAAAAAAAEABMAEgABAAAAAAAG
        ABIAJQADAAEECQABABYANwADAAEECQACAA4ATQADAAEECQADACYAWwADAAEECQAEACYAWwADAAEECQAGACQAgVlhaGFn
        aSBUZXN0UmVndWxhcllhaGFnaSBUZXN0IFJlZ3VsYXJZYWhhZ2lUZXN0LVJlZ3VsYXIAWQBhAGgAYQBnAGkAIABUAGUA
        cwB0AFIAZQBnAHUAbABhAHIAWQBhAGgAYQBnAGkAIABUAGUAcwB0ACAAUgBlAGcAdQBsAGEAcgBZAGEAaABhAGcAaQBU
        AGUAcwB0AC0AUgBlAGcAdQBsAGEAcgAAAAACAAAAAwAAABQAAwABAAAAFAAEACAAAAAEAAQAAQAAAEH//wAAAEH////A
        AAEAAAAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAQBAAEBARNZYWhhZ2lUZXN0LVJlZ3VsYXIAAQEB
        GfgbAvgcA/gYBL2L+Lr5ggXpD4v3CxLsEQACAQEUH1lhaGFnaSBUZXN0IFJlZ3VsYXJZYWhhZ2kgVGVzdAAAAAAiAAIB
        AQQR+OwO+Oy9FviIBvuO+YIFDgACWAAAADIAAA==
        """.trimIndent()

        // WOFF2 version of OPEN_TYPE with a 400-unit 'A' advance instead of 600.
        val STOCK_FONT = """
        d09GMk9UVE8AAAGMAAkAAAAAA1gAAAFIAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAADXcGYAA0ATYCJAMIBAYFgiMHIBu1AiCe
        BXZzMijMKL21+bhyVwqe/sd9d968Bfzd1jodVENbV7fuuKlA6IJ8QZmJ37tfKff/e0t3En6ggeyNprDbRoEndGmYQATpcdqQ
        As/SbaoifiJYLAjW3SPBCiIS0zU0OTQx1To2N5/5fdFeRCTpI8VIVYm2jU/dZUTNhETfRGFEYjPOJUdwR3O3BnBhv9FGfdyE
        8xzEP/Z/u3XhqOmUXWBpXcDVrwG11KrjvwTUwYlTBzalCsSiCBCLxQFYLALU/v8Pwv8xAnBXYHFvpWUgouI1UPUC4NxpeK7+
        1pAH0m/uAMWYuUw2nQCUVyHKKDedILsMGsEAwSwjAAghwBIMAYSAEkO0bJf9icaLIjYIIZ5iAUM4daD46JHt1B8PaxRZ0vp4
        7HsPP6iLISYZYoIpHLQyxhzzNDPGBAvMMgRsqCOdqjLHKw0A
        """.trimIndent()
    }
}
