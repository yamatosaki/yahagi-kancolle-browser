package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlin.coroutines.resume

class WebViewProxyManager(private val context: Context) : MethodChannel.MethodCallHandler {

    private val mainScope = CoroutineScope(Dispatchers.Main + Job())
    private val ioScope = CoroutineScope(Dispatchers.IO + Job())
    private val proxyMutex = Mutex()

    fun dispose() {
        mainScope.cancel()
        ioScope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isProxyOverrideSupported" -> {
                result.success(WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE))
            }
            "getNetworkStatus" -> {
                result.success(getNetworkStatus())
            }
            "applyHttpProxy" -> {
                val host = call.argument<String>("host") ?: ""
                val port = call.argument<Int>("port") ?: 8099
                applyProxyConfig("http://$host:$port", result)
            }
            "applySocksProxy" -> {
                val host = call.argument<String>("host") ?: ""
                val port = call.argument<Int>("port") ?: 1080
                // AndroidX ProxyConfig supports socks
                applyProxyConfig("socks://$host:$port", result)
            }
            "clearProxyOverride" -> {
                clearProxyConfig(result)
            }
            "runNetworkDiagnostic" -> {
                val mode = call.argument<String>("mode") ?: "system"
                val host = call.argument<String>("host") ?: ""
                val port = call.argument<Int>("port") ?: 8099
                runNetworkDiagnostic(mode, host, port, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getNetworkStatus(): Map<String, Any> {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        val hasVpn = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false
        val hasActiveNetwork = capabilities != null
        return mapOf(
            "hasVpn" to hasVpn,
            "hasActiveNetwork" to hasActiveNetwork
        )
    }

    private fun applyProxyConfig(proxyUrl: String, result: MethodChannel.Result) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            result.success(
                mapOf("success" to false, "code" to "proxy_override_unsupported", "message" to "当前设备不支持应用内代理")
            )
            return
        }

        mainScope.launch {
            if (!proxyMutex.tryLock()) {
                result.success(
                    mapOf("success" to false, "code" to "proxy_operation_busy", "message" to "代理设置操作进行中，请稍后")
                )
                return@launch
            }

            try {
                val startTime = System.currentTimeMillis()
                val proxyConfig = ProxyConfig.Builder()
                    .addProxyRule(proxyUrl)
                    .build()

                val completed = awaitProxyCallback { callback ->
                    ProxyController.getInstance().setProxyOverride(
                        proxyConfig,
                        { Handler(Looper.getMainLooper()).post(it) },
                        callback,
                    )
                }
                val elapsedMs = System.currentTimeMillis() - startTime
                if (completed) {
                    result.success(
                        mapOf("success" to true, "code" to "ok", "message" to "代理设置成功", "elapsedMs" to elapsedMs)
                    )
                } else {
                    result.success(
                        mapOf("success" to false, "code" to "proxy_apply_timeout", "message" to "代理设置超时", "elapsedMs" to elapsedMs)
                    )
                }
            } catch (e: Exception) {
                result.success(
                    mapOf("success" to false, "code" to "unknown_error", "message" to (e.message ?: "未知错误"))
                )
            } finally {
                proxyMutex.unlock()
            }
        }
    }

    private fun clearProxyConfig(result: MethodChannel.Result) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            // If it's not supported, we can just say success because it means there was no proxy set anyway.
            result.success(
                mapOf("success" to true, "code" to "ok", "message" to "无需清除代理")
            )
            return
        }

        mainScope.launch {
            if (!proxyMutex.tryLock()) {
                result.success(
                    mapOf("success" to false, "code" to "proxy_operation_busy", "message" to "代理设置操作进行中，请稍后")
                )
                return@launch
            }

            try {
                val startTime = System.currentTimeMillis()
                val completed = awaitProxyCallback { callback ->
                    ProxyController.getInstance().clearProxyOverride(
                        { Handler(Looper.getMainLooper()).post(it) },
                        callback,
                    )
                }
                val elapsedMs = System.currentTimeMillis() - startTime
                if (completed) {
                    result.success(
                        mapOf("success" to true, "code" to "ok", "message" to "系统网络已恢复", "elapsedMs" to elapsedMs)
                    )
                } else {
                    result.success(
                        mapOf("success" to false, "code" to "proxy_clear_timeout", "message" to "清除代理超时", "elapsedMs" to elapsedMs)
                    )
                }
            } catch (e: Exception) {
                result.success(
                    mapOf("success" to false, "code" to "unknown_error", "message" to (e.message ?: "未知错误"))
                )
            } finally {
                proxyMutex.unlock()
            }
        }
    }

    private suspend fun awaitProxyCallback(
        start: (Runnable) -> Unit,
    ): Boolean {
        return withTimeoutOrNull(8_000) {
            suspendCancellableCoroutine { continuation ->
                start(
                    Runnable {
                        if (continuation.isActive) {
                            continuation.resume(Unit)
                        }
                    },
                )
            }
            true
        } ?: false
    }

    private fun runNetworkDiagnostic(mode: String, host: String, port: Int, result: MethodChannel.Result) {
        ioScope.launch {
            val startTime = System.currentTimeMillis()
            var tcpSuccess = false
            var tcpElapsed = 0L
            
            if (mode != "system") {
                val tcpStart = System.currentTimeMillis()
                try {
                    Socket().use { socket ->
                        socket.connect(InetSocketAddress(host, port), 5000)
                    }
                    tcpSuccess = true
                    tcpElapsed = System.currentTimeMillis() - tcpStart
                } catch (e: Exception) {
                    tcpElapsed = System.currentTimeMillis() - tcpStart
                    withContext(Dispatchers.Main) {
                        result.success(
                            mapOf(
                                "success" to false,
                                "code" to "connection_refused",
                                "message" to (e.message ?: "TCP连接失败"),
                                "elapsedMs" to tcpElapsed,
                                "details" to mapOf(
                                    "proxy" to mapOf("status" to "failed", "elapsedMs" to tcpElapsed)
                                )
                            )
                        )
                    }
                    return@launch
                }
            } else {
                tcpSuccess = true
            }

            val proxyType = when (mode) {
                "httpProxy" -> Proxy.Type.HTTP
                "socks5Proxy" -> Proxy.Type.SOCKS
                else -> Proxy.Type.DIRECT
            }
            val proxy = if (mode == "system") Proxy.NO_PROXY else Proxy(proxyType, InetSocketAddress(host, port))

            val gameJob = async { testHttpUrl("https://accounts.dmm.com/", proxy, 8000) }
            val googleJob = async { testHttpUrl("https://www.google.com/gen_204", proxy, 5000) }

            val gameRes = gameJob.await()
            val googleRes = googleJob.await()
            
            val totalElapsed = System.currentTimeMillis() - startTime

            val success = gameRes.first
            var msg = ""
            var code = ""
            if (success && !googleRes.first) {
                msg = "普通网络可用，但Google连接超时，不影响游戏。"
                code = "warning"
            } else if (success) {
                msg = "网络畅通，可正常访问游戏服务。"
                code = "ok"
            } else if (googleRes.first) {
                msg = "外网可用，但游戏相关服务无法访问 (可能被墙或被拦截)。"
                code = "game_failed"
            } else {
                msg = "当前网络连接失败或代理无法正常工作。"
                code = "all_failed"
            }

            withContext(Dispatchers.Main) {
                result.success(
                    mapOf(
                        "success" to success,
                        "code" to code,
                        "message" to msg,
                        "elapsedMs" to totalElapsed,
                        "details" to mapOf(
                            "proxy" to mapOf(
                                "status" to if (mode == "system") "skipped" else "success",
                                "elapsedMs" to tcpElapsed
                            ),
                            "gameTarget" to mapOf(
                                "status" to if (gameRes.first) "success" else "failed",
                                "elapsedMs" to gameRes.second
                            ),
                            "google" to mapOf(
                                "status" to if (googleRes.first) "success" else "failed",
                                "elapsedMs" to googleRes.second
                            )
                        )
                    )
                )
            }
        }
    }

    private fun testHttpUrl(urlString: String, proxy: Proxy, timeout: Int): Pair<Boolean, Long> {
        val start = System.currentTimeMillis()
        return try {
            val url = URL(urlString)
            val conn = url.openConnection(proxy) as HttpsURLConnection
            conn.connectTimeout = timeout
            conn.readTimeout = timeout
            conn.connect()
            val code = conn.responseCode
            Pair(true, System.currentTimeMillis() - start)
        } catch (e: Exception) {
            Pair(false, System.currentTimeMillis() - start)
        }
    }
}
