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
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.net.URL
import java.util.concurrent.Executor

class WebViewProxyManager(
    private val context: Context,
    private val onEffectiveProxyChanged: suspend (Proxy?) -> Unit = {},
) : MethodChannel.MethodCallHandler {

    private val mainScope = CoroutineScope(Dispatchers.Main + Job())
    private val ioScope = CoroutineScope(Dispatchers.IO + Job())
    fun currentNativeProxy(): Proxy? = proxyRoutes.currentNativeProxy()

    fun setKanxyVpnActive(active: Boolean, onComplete: (Boolean) -> Unit = {}) {
        mainScope.launch(Dispatchers.Main.immediate) {
            val completed = try {
                proxyRoutes.setKanxyActive(active).also { applied ->
                    if (applied) onEffectiveProxyChanged(currentNativeProxy())
                }
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                false
            }
            onComplete(completed)
        }
    }

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
                configureProxy("http://$host:$port", result)
            }
            "applySocksProxy" -> {
                val host = call.argument<String>("host") ?: ""
                val port = call.argument<Int>("port") ?: 1080
                // AndroidX ProxyConfig supports socks
                configureProxy("socks://$host:$port", result)
            }
            "clearProxyOverride" -> {
                configureProxy(null, result)
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

    private fun configureProxy(proxyUrl: String?, result: MethodChannel.Result) {
        mainScope.launch {
            val startTime = System.currentTimeMillis()
            try {
                val outcome = proxyRoutes.configure(proxyUrl)
                if (outcome == WebViewProxyRoutes.Result.APPLIED) {
                    onEffectiveProxyChanged(currentNativeProxy())
                }
                val (success, code, message) = when (outcome) {
                    WebViewProxyRoutes.Result.APPLIED ->
                        Triple(true, "ok", if (proxyUrl == null) "系统网络已恢复" else "代理设置成功")
                    WebViewProxyRoutes.Result.BUSY ->
                        Triple(false, "proxy_operation_busy", "代理设置操作进行中，请稍后")
                    WebViewProxyRoutes.Result.UNSUPPORTED ->
                        Triple(false, "proxy_override_unsupported", "当前设备不支持应用内代理")
                    WebViewProxyRoutes.Result.TIMEOUT -> if (proxyUrl == null) {
                        Triple(false, "proxy_clear_timeout", "清除代理超时")
                    } else {
                        Triple(false, "proxy_apply_timeout", "代理设置超时")
                    }
                }
                result.success(mapOf(
                    "success" to success, "code" to code, "message" to message,
                    "elapsedMs" to (System.currentTimeMillis() - startTime),
                ))
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                result.success(mapOf(
                    "success" to false, "code" to "unknown_error", "message" to (error.message ?: "未知错误"),
                ))
            }
        }
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
            val proxy = if (mode == "system") null else Proxy(
                proxyType,
                InetSocketAddress.createUnresolved(host.removeSurrounding("[", "]"), port),
            )

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

    private fun testHttpUrl(urlString: String, proxy: Proxy?, timeout: Int): Pair<Boolean, Long> {
        val start = System.currentTimeMillis()
        return try {
            val url = URL(urlString)
            val conn = requireNotNull(NativeProxyRouting.openConnection(url, proxy))
            try {
                conn.connectTimeout = timeout
                conn.readTimeout = timeout
                conn.connect()
                conn.responseCode
                Pair(true, System.currentTimeMillis() - start)
            } finally {
                conn.disconnect()
            }
        } catch (e: Exception) {
            Pair(false, System.currentTimeMillis() - start)
        }
    }

    private companion object {
        // AndroidX applies an override to all WebViews in this process.
        val proxyRoutes by lazy {
            WebViewProxyRoutes(
                CoroutineScope(Dispatchers.Main.immediate + SupervisorJob()),
                { WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE) },
                { proxyUrl, completed ->
                    val controller = ProxyController.getInstance()
                    val handler = Handler(Looper.getMainLooper())
                    val executor = Executor { handler.post(it) }
                    if (proxyUrl == null) {
                        controller.clearProxyOverride(executor, completed)
                    } else {
                        val config = ProxyConfig.Builder().addProxyRule(proxyUrl).build()
                        controller.setProxyOverride(config, executor, completed)
                    }
                },
            )
        }
    }
}

/** Serializes AndroidX callbacks on the main dispatcher, including callbacks after a timeout. */
internal class WebViewProxyRoutes(
    private val scope: CoroutineScope,
    private val supported: () -> Boolean,
    private val changeOverride: (String?, Runnable) -> Unit,
    private val timeoutMs: Long = 8_000,
) {
    enum class Result { APPLIED, BUSY, UNSUPPORTED, TIMEOUT }

    private data class Route(val url: String, val native: Proxy)
    private class Operation(val route: Route?) {
        val completed = CompletableDeferred<Unit>()
        var reconcileAfterCallback = false
    }

    private val mutex = Mutex()
    private var saved: Route? = null
    private var installed: Route? = null
    private var installedKnown = false
    private var pending: Operation? = null
    private var kanxyActive = false
    private var configuring = false
    @Volatile private var effectiveProxy: Proxy? = null

    fun currentNativeProxy(): Proxy? = effectiveProxy

    suspend fun configure(url: String?): Result {
        if (configuring) return Result.BUSY
        configuring = true
        try {
            return mutex.withLock {
                if (!supported()) {
                    if (url != null) return@withLock Result.UNSUPPORTED
                    saved = null
                    effectiveProxy = null
                    return@withLock Result.APPLIED
                }
                val route = url?.let { Route(it, NativeProxyRouting.fromUrl(it)) }
                if (!install { route.takeUnless { kanxyActive } }) return@withLock Result.TIMEOUT
                saved = route
                publishEffective()
                Result.APPLIED
            }
        } finally {
            configuring = false
        }
    }

    suspend fun setKanxyActive(active: Boolean): Boolean {
        kanxyActive = active
        if (active) effectiveProxy = null
        return mutex.withLock {
            if (kanxyActive != active) return@withLock false
            if (!supported() || (!active && saved == null && !installedKnown && pending == null)) {
                return@withLock true
            }
            reconcile() && kanxyActive == active
        }
    }

    private suspend fun reconcile(): Boolean {
        if (!install { saved.takeUnless { kanxyActive } }) return false
        publishEffective()
        return true
    }

    private fun publishEffective() {
        effectiveProxy = if (kanxyActive) null else installed?.native
    }

    private suspend fun install(desired: () -> Route?): Boolean {
        val previous = pending
        if (previous != null && !waitFor(previous)) return false
        val target = desired()
        if (installedKnown && installed == target) return true
        val operation = Operation(target)
        pending = operation
        try {
            changeOverride(target?.url, Runnable {
                scope.launch {
                    if (pending !== operation) return@launch
                    installed = operation.route
                    installedKnown = true
                    pending = null
                    operation.completed.complete(Unit)
                    if (operation.reconcileAfterCallback) reconcileLater()
                }
            })
        } catch (error: Exception) {
            pending = null
            throw error
        }
        var completed = false
        try {
            completed = waitFor(operation)
            return completed
        } finally {
            if (!completed) {
                // AndroidX may still complete the operation after the caller times out or is cancelled.
                operation.reconcileAfterCallback = true
                if (pending !== operation) reconcileLater()
            }
        }
    }

    private suspend fun waitFor(operation: Operation): Boolean = withTimeoutOrNull(timeoutMs) {
        operation.completed.await()
        true
    } ?: operation.completed.isCompleted

    private fun reconcileLater() {
        scope.launch {
            mutex.withLock {
                runCatching { reconcile() }
            }
        }
    }
}
