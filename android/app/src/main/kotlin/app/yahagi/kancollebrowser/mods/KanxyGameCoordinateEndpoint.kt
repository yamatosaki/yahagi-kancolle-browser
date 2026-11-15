package app.yahagi.kancollebrowser.mods

import app.yahagi.kancollebrowser.browser.KanxyResourceRoute
import app.yahagi.kancollebrowser.browser.NativeProxyRouting
import com.google.gson.Gson
import java.io.ByteArrayInputStream
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.URI
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** Resolves the selected Kanxy coordinate asset through the same route as game traffic. */
internal class KanxyGameCoordinateEndpoint(
    private val currentRoute: () -> KanxyResourceRoute?,
    private val openConnection: (URL, Proxy?) -> HttpsURLConnection = { url, proxy ->
        requireNotNull(NativeProxyRouting.openConnection(url, proxy) as? HttpsURLConnection)
    },
) {
    private val gson = Gson()

    fun open(url: String, method: String): GameModResponse? {
        if (!url.contains(VIRTUAL_PREFIX)) return null
        // Reserve the virtual path even if its query or fragment is malformed.
        val resourceUrl = url.substringBefore('?').substringBefore('#')
        val uri = runCatching { URI(resourceUrl) }.getOrNull() ?: return null
        val host = uri.host ?: return null
        val path = uri.rawPath ?: return null
        if (uri.scheme != "https" || uri.userInfo != null || (uri.port != -1 && uri.port != 443) ||
            !officialHost.matches(host) || !path.startsWith(VIRTUAL_PREFIX)
        ) return null
        if (method != "GET") return response(405, "Method Not Allowed")
        if (url != resourceUrl) return response(400, "Bad Request")
        val name = fileName.matchEntire(path.removePrefix(VIRTUAL_PREFIX))
            ?.groupValues?.get(1) ?: return notFound()

        return try {
            val route = currentRoute() ?: return notFound()
            val asset = "https://$host/kcs/resources/swf/ships/$name.config"
            val json = fetchWithRetry(asset, "json", route)
            val result = if (json == Asset.NotFound && currentRoute() === route) {
                fetchWithRetry(asset, "ini", route)
            } else json
            if (result is Asset.Valid && currentRoute() === route) response(200, "OK", result.graph) else notFound()
        } catch (_: Exception) {
            notFound()
        }
    }

    private fun fetchWithRetry(asset: String, format: String, route: KanxyResourceRoute): Asset = try {
        fetch(asset, format, route.proxy)
    } catch (error: Exception) {
        if (error !is SocketTimeoutException && error !is SocketException) throw error
        if (currentRoute() === route) fetch(asset, format, route.proxy) else Asset.Unavailable
    }

    private fun fetch(asset: String, format: String, proxy: Proxy?): Asset {
        val connection = openConnection(URL("$asset.$format"), proxy)
        try {
            connection.requestMethod = "GET"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            connection.useCaches = false
            return when (connection.responseCode) {
                HttpURLConnection.HTTP_NOT_FOUND -> Asset.NotFound
                HttpURLConnection.HTTP_OK -> {
                    val buffer = ByteArray(MAX_BYTES + 1)
                    val size = connection.inputStream.use { input ->
                        var count = 0
                        while (count < buffer.size) {
                            val read = input.read(buffer, count, buffer.size - count)
                            if (read < 0) break
                            if (read == 0) return Asset.Unavailable
                            count += read
                        }
                        count
                    }
                    if (size > MAX_BYTES) return Asset.Unavailable
                    Asset.Valid(GameModCoordinateParser.parse(buffer.copyOf(size), format).graph)
                }
                else -> Asset.Unavailable
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun notFound() = response(404, "Not Found")

    private fun response(
        status: Int,
        reason: String,
        graph: Map<String, List<Int>> = emptyMap(),
    ): GameModResponse {
        val bytes = gson.toJson(graph).toByteArray(Charsets.UTF_8)
        return GameModResponse(
            "application/json", status, reason,
            mapOf(
                "Content-Type" to "application/json; charset=utf-8",
                "Content-Length" to bytes.size.toString(),
                "Cache-Control" to "no-store",
            ),
            ByteArrayInputStream(bytes),
        )
    }

    private sealed interface Asset {
        data class Valid(val graph: Map<String, List<Int>>) : Asset
        data object NotFound : Asset
        data object Unavailable : Asset
    }

    private companion object {
        const val VIRTUAL_PREFIX = "/__yahagi_mods__/kanxy-coordinates/"
        const val TIMEOUT_MS = 1_200
        const val MAX_BYTES = 128 * 1024
        val officialHost = Regex("w[0-9]+[a-z]\\.kancolle-server\\.com")
        val fileName = Regex("([a-z0-9]{12})\\.json")
    }
}
