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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class GameModQuestWebViewTest {
    @Test fun importedQuestTextReachesGameAndCaptureReadsOriginalResponse() {
        assumeTrue(WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT))
        val context = ApplicationProvider.getApplicationContext<Context>()
        val root = File(context.cacheDir, "quest-mod-webview-${System.nanoTime()}")
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        var webView: WebView? = null
        try {
            val repo = GameModRepository(root)
            val translation = """
                [{"api_no":101,"api_title":"$TRANSLATED_TITLE","api_detail":"$TRANSLATED_DETAIL"}]
            """.trimIndent()
            val archive = ByteArrayOutputStream().also { bytes ->
                ZipOutputStream(bytes).use { zip ->
                    zip.putNextEntry(ZipEntry("text/api/questlist.json"))
                    zip.write(translation.toByteArray())
                    zip.closeEntry()
                }
            }
            val preview = repo.preflight(ByteArrayInputStream(archive.toByteArray()), "quest-text.zip")
            assertEquals(1, preview["supportedCount"])
            val entry = repo.commitImport(preview["token"] as String)
            val resource = (entry["resources"] as List<*>).single() as Map<*, *>
            val packageIds = listOf(entry["id"])
            repo.saveDraft(mapOf(
                "master" to true,
                "order" to packageIds,
                "enabledPackages" to packageIds,
                "enabledResources" to listOf(resource["id"]),
            ))
            repo.finishApply(repo.applyDraft())

            val endpoint = GameModCoordinateEndpoint(repo::activeCoordinateSnapshot, repo::recordCoordinateResult)
            val probe = QuestProbe()
            instrumentation.runOnMainSync {
                webView = WebView(context).apply {
                    settings.javaScriptEnabled = true
                    addJavascriptInterface(probe, "QuestProbe")
                    webViewClient = object : WebViewClient() {
                        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse {
                            val url = request.url.toString()
                            if (url == "$ORIGIN/kcs2/index.php" && request.method == "GET") {
                                return fixtureResponse("text/html", PAGE)
                            }
                            endpoint.open(url, request.method)?.let { return it.toWebResourceResponse() }
                            if (request.method == "POST" &&
                                (url == "$ORIGIN$QUEST_PATH" || url == "$ORIGIN$OTHER_PATH")
                            ) {
                                return fixtureResponse("text/plain", ORIGINAL_BODY)
                            }
                            // The synthetic origin must never send a request to the network.
                            return WebResourceResponse("text/plain", "UTF-8", 404, "Not Found",
                                emptyMap(), ByteArrayInputStream(byteArrayOf()))
                        }
                    }
                    WebViewCompat.addDocumentStartJavaScript(
                        this, GameModCoordinateScript.source, GameModCoordinateScript.allowedOriginRules,
                    )
                    loadUrl("$ORIGIN/kcs2/index.php")
                }
            }

            assertTrue("WebView did not complete the synthetic quest requests", probe.completed.await(20, TimeUnit.SECONDS))
            val result = JSONObject(checkNotNull(probe.result))
            assertTrue(result.optString("error"), !result.has("error"))
            val expected = ORIGINAL_BODY.replace(ORIGINAL_TITLE, TRANSLATED_TITLE)
                .replace(ORIGINAL_DETAIL, TRANSLATED_DETAIL)
            assertEquals(expected, result.getString("xhrText"))
            assertEquals(expected, result.getString("xhrResponse"))
            assertEquals(expected, result.getString("fetchText"))
            assertEquals(ORIGINAL_BODY, result.getString("xhrOriginal"))
            assertEquals(ORIGINAL_BODY, result.getString("fetchOriginal"))
            assertEquals(ORIGINAL_BODY, result.getString("otherText"))
        } finally {
            instrumentation.runOnMainSync { webView?.destroy() }
            root.deleteRecursively()
        }
    }

    private fun fixtureResponse(mime: String, body: String): WebResourceResponse =
        WebResourceResponse(mime, "UTF-8", 200, "OK",
            mapOf("Content-Type" to "$mime; charset=utf-8", "Cache-Control" to "no-store"),
            ByteArrayInputStream(body.toByteArray()),
        )

    class QuestProbe {
        val completed = CountDownLatch(1)
        var result: String? = null

        @JavascriptInterface fun report(value: String) {
            result = value
            completed.countDown()
        }
    }

    private companion object {
        const val ORIGIN = "https://w999z.kancolle-server.com"
        const val QUEST_PATH = "/kcsapi/api_get_member/questlist"
        const val OTHER_PATH = "/kcsapi/api_get_member/mission"
        const val ORIGINAL_TITLE = "第一艦隊を編成せよ！"
        const val ORIGINAL_DETAIL = "第一艦隊を編成する。"
        const val TRANSLATED_TITLE = "编成第一舰队！"
        const val TRANSLATED_DETAIL = "编成第一舰队。"
        const val ORIGINAL_BODY = """svdata={"api_result":1,"api_result_msg":"成功","api_data":{"api_count":2,"api_list":[{"api_no":101,"api_state":2,"api_title":"$ORIGINAL_TITLE","api_detail":"$ORIGINAL_DETAIL"},-1,{"api_no":102,"api_state":1,"api_title":"艦隊の出撃","api_detail":"出撃せよ。"}]}}"""
        val PAGE = """
            <html><body><script>
            function xhrPost(path) {
              return new Promise((resolve, reject) => {
                const request = new XMLHttpRequest();
                request.open('POST', path);
                request.onload = () => request.status === 200
                  ? resolve(request) : reject(new Error(path + ': ' + request.status));
                request.onerror = () => reject(new Error(path + ': transport error'));
                request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                request.send('api_page_no=1');
              });
            }
            (async () => {
              const xhr = await xhrPost('$QUEST_PATH');
              const other = await xhrPost('$OTHER_PATH');
              const response = await fetch('$QUEST_PATH', {
                method: 'POST',
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'api_page_no=1'
              });
              const raw = window.__yahagiModOriginalResponses;
              const xhrOriginal = raw.xhrText(xhr);
              const fetchOriginal = raw.fetch(response).clone().text();
              QuestProbe.report(JSON.stringify({
                xhrText: xhr.responseText,
                xhrResponse: xhr.response,
                fetchText: await response.text(),
                xhrOriginal,
                fetchOriginal: await fetchOriginal,
                otherText: other.responseText
              }));
            })().catch(error => QuestProbe.report(JSON.stringify({error: String(error)})));
            </script></body></html>
        """.trimIndent()
    }
}
