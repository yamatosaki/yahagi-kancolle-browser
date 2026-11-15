package app.yahagi.kancollebrowser.fleet

import android.os.SystemClock
import app.yahagi.kancollebrowser.browser.NativeProxyRouting
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URI
import java.util.UUID
import javax.net.ssl.HttpsURLConnection

internal object ShipPortraitRequestPolicy {
    private val host = Regex("w[0-9]+[a-z]\\.kancolle-server\\.com")
    private val path = Regex(
        "/kcs2/resources/(?:ship/(?:remodel|banner)(?:_dmg)?|slot/item_up)/[0-9]{4,10}_[0-9]{4}\\.png",
    )
    private val query = Regex("version=[0-9]+")

    fun parse(value: String?): URI? {
        if (value == null || value.length > 512) return null
        val uri = runCatching { URI(value) }.getOrNull() ?: return null
        if (uri.scheme != "https" || uri.port !in setOf(-1, 443) ||
            !host.matches(uri.host.orEmpty()) || uri.rawUserInfo != null || uri.rawFragment != null ||
            !path.matches(uri.rawPath.orEmpty()) || uri.rawQuery?.let { !query.matches(it) } == true
        ) return null
        return uri
    }
}

internal class ShipPortraitChannel(messenger: BinaryMessenger, kanxyActive: Boolean, proxy: Proxy? = null) {
    private data class Route(
        val kanxyActive: Boolean,
        val proxy: Proxy?,
        val token: String = UUID.randomUUID().toString(),
    ) {
        fun toMessage(): Map<String, Any> = mapOf("kanxyActive" to kanxyActive, "token" to token)
    }

    private val channel = MethodChannel(messenger, "app.yahagi.kancollebrowser/ship_portrait_network")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var route = Route(kanxyActive, proxy)

    init {
        channel.setMethodCallHandler(::handle)
        channel.invokeMethod("routeChanged", route.toMessage())
    }

    fun onRouteChanged(active: Boolean, proxy: Proxy?, refresh: Boolean = false) {
        if (route.kanxyActive == active && route.proxy == proxy && !refresh) return
        route = Route(active, proxy)
        channel.invokeMethod("routeChanged", route.toMessage())
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRoute" -> result.success(route.toMessage())
            "fetch" -> {
                val args = call.arguments as? Map<*, *>
                val uri = ShipPortraitRequestPolicy.parse(args?.get("uri") as? String)
                val requestRoute = route
                if (uri == null || args?.get("token") != requestRoute.token) {
                    result.success(null)
                    return
                }
                scope.launch {
                    val bytes = try {
                        withContext(Dispatchers.IO) { download(uri, requestRoute.proxy) }
                    } catch (error: CancellationException) {
                        result.success(null)
                        throw error
                    }
                    result.success(bytes.takeIf { route == requestRoute })
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun download(uri: URI, proxy: Proxy?): ByteArray? {
        val connection = try {
            NativeProxyRouting.openConnection(uri.toURL(), proxy) as? HttpsURLConnection ?: return null
        } catch (_: IOException) {
            return null
        }
        return try {
            // The default Android TLS verifier applies the app's host-specific trust anchors.
            connection.requestMethod = "GET"
            connection.instanceFollowRedirects = false
            connection.useCaches = false
            connection.connectTimeout = IO_TIMEOUT_MS
            connection.readTimeout = IO_TIMEOUT_MS
            connection.setRequestProperty("Accept", "image/png")
            val deadline = SystemClock.elapsedRealtime() + TOTAL_TIMEOUT_MS
            if (connection.responseCode != HttpURLConnection.HTTP_OK ||
                connection.getHeaderField("Content-Length")?.toLongOrNull()?.let { it > MAX_BYTES } == true
            ) return null
            connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8_192)
                while (SystemClock.elapsedRealtime() < deadline) {
                    val count = input.read(buffer)
                    if (count < 0) return output.toByteArray()
                    if (count > MAX_BYTES - output.size()) return null
                    output.write(buffer, 0, count)
                }
                null
            }
        } catch (_: IOException) {
            null
        } catch (_: SecurityException) {
            null
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val IO_TIMEOUT_MS = 7_000
        const val TOTAL_TIMEOUT_MS = 12_000L
        const val MAX_BYTES = 8 * 1024 * 1024
    }
}
