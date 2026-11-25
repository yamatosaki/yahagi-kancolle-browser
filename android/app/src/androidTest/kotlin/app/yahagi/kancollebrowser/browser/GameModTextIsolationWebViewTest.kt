package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import app.yahagi.kancollebrowser.mods.GameModCoordinateEndpoint
import app.yahagi.kancollebrowser.mods.GameModCoordinateScript
import app.yahagi.kancollebrowser.mods.GameModRepository
import app.yahagi.kancollebrowser.mods.toWebResourceResponse
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class GameModTextIsolationWebViewTest {
    @Test fun reloadingWithTheModDisabledRestoresGameTextAndOriginalSetters() {
        assumeTrue(WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT))
        val context = ApplicationProvider.getApplicationContext<Context>()
        val root = File(context.cacheDir, "display-mod-${System.nanoTime()}")
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val probe = TextProbe()
        val repo = GameModRepository(root)
        val endpoint = GameModCoordinateEndpoint(repo::activeCoordinateSnapshot, repo::recordCoordinateResult)
        var webView: WebView? = null
        try {
            instrumentation.runOnMainSync {
                webView = WebView(context).apply {
                    settings.javaScriptEnabled = true
                    addJavascriptInterface(probe, "TextProbe")
                    webViewClient = object : WebViewClient() {
                        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                            endpoint.open(request.url.toString(), request.method)?.let { return it.toWebResourceResponse() }
                            return when (request.url.path) {
                                "/kcs2/index.php" -> response("text/html", PAGE)
                                "/kcs2/js/pixi.min.js" -> response("application/javascript", PIXI)
                                else -> WebResourceResponse("text/plain", "UTF-8", 404, "Not Found",
                                    emptyMap(), ByteArrayInputStream(byteArrayOf()))
                            }
                        }
                    }
                    WebViewCompat.addDocumentStartJavaScript(this, BASELINE, setOf(ORIGIN))
                    WebViewCompat.addDocumentStartJavaScript(this, GameModCoordinateScript.source,
                        GameModCoordinateScript.allowedOriginRules)
                }
            }

            fun assertPage(phase: Int, active: Boolean) {
                instrumentation.runOnMainSync { checkNotNull(webView).loadUrl("$ORIGIN/kcs2/index.php?phase=$phase") }
                val result = JSONObject(checkNotNull(probe.results.poll(20, TimeUnit.SECONDS)) {
                    "Fixture WebView did not report phase $phase"
                })
                assertEquals(if (active) "开始建造吗？" else "建造を開始しますか？", result.getString("dictionary"))
                assertEquals(if (active) "共7天" else "期間7日", result.getString("regex"))
                assertEquals(if (active) "大海" else "海原", result.getString("bgm"))
                assertEquals(if (active) "早晨" else "朝", result.getString("port"))
                assertEquals("そのまま", result.getString("unmatched"))
                assertEquals(!active, result.getBoolean("originalSetter"))
                assertEquals(true, result.getBoolean("originalNetwork"))
            }

            assertPage(0, active = false)
            val preview = repo.preflight(ByteArrayInputStream(chsArchive()), "local-chs.zip")
            assertEquals(4, preview["supportedCount"])
            val entry = repo.commitImport(preview["token"] as String)
            val packageIds = listOf(entry["id"])
            val resourceIds = (entry["resources"] as List<*>).map { (it as Map<*, *>)["id"] }
            fun apply(enabled: Boolean) {
                repo.saveDraft(mapOf("master" to true, "order" to packageIds,
                    "enabledPackages" to if (enabled) packageIds else emptyList<Any>(),
                    "enabledResources" to resourceIds))
                repo.finishApply(repo.applyDraft())
            }
            apply(false)
            assertPage(1, active = false)
            apply(true)
            assertPage(2, active = true)
            apply(false)
            assertPage(3, active = false)
        } finally {
            instrumentation.runOnMainSync { webView?.destroy() }
            root.deleteRecursively()
        }
    }

    private fun chsArchive(): ByteArray = ByteArrayOutputStream().also { output ->
        val files = mapOf(
            "text/text/build.json" to """{"建造を開始しますか？":"开始建造吗？"}""",
            "text/text_regex/terms.json" to """{"期間(\\d+)日":"共$1天"}""",
            "text/bgm_name/titles.json" to """{"海原":"大海"}""",
            "text/bgm_name/port.json" to """{"1":{"ja":"朝","zh":"早晨"}}""",
        )
        ZipOutputStream(output).use { zip ->
            files.forEach { (name, text) ->
                zip.putNextEntry(ZipEntry(name))
                zip.write(text.toByteArray())
                zip.closeEntry()
            }
        }
    }.toByteArray()

    private fun response(mime: String, body: String): WebResourceResponse = WebResourceResponse(
        mime, "UTF-8", 200, "OK", mapOf("Cache-Control" to "no-store"), ByteArrayInputStream(body.toByteArray()),
    )

    class TextProbe {
        val results = LinkedBlockingQueue<String>()

        @JavascriptInterface fun report(result: String) { results.add(result) }
    }

    private companion object {
        const val ORIGIN = "https://w999z.kancolle-server.com"
        const val BASELINE = """
            window.fixtureNetwork = [XMLHttpRequest.prototype.open, XMLHttpRequest.prototype.send, window.fetch];
        """
        const val PIXI = """
            class FixtureText {
              constructor(text) { this.text = text; }
              get text() { return this.value; }
              set text(text) { this.value = text; }
            }
            window.fixtureTextSetter = Object.getOwnPropertyDescriptor(FixtureText.prototype, 'text').set;
            window.PIXI = {VERSION:'4.8.8', Text:FixtureText};
        """
        const val PAGE = """
            <html><body><script src="/kcs2/js/pixi.min.js"></script><script>
              const draw = text => new PIXI.Text(text).text;
              TextProbe.report(JSON.stringify({
                dictionary: draw('建造を開始しますか？'),
                regex: draw('期間7日'),
                bgm: draw('海原'),
                port: draw('朝'),
                unmatched: draw('そのまま'),
                originalSetter: Object.getOwnPropertyDescriptor(PIXI.Text.prototype, 'text').set === fixtureTextSetter,
                originalNetwork: fixtureNetwork[0] === XMLHttpRequest.prototype.open &&
                  fixtureNetwork[1] === XMLHttpRequest.prototype.send && fixtureNetwork[2] === window.fetch
              }));
            </script></body></html>
        """
    }
}
