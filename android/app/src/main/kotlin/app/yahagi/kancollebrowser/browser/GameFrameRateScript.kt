package app.yahagi.kancollebrowser.browser

import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.Locale

object GameMainScriptPatcher {
    private val tickerPattern = Regex("(createjs[^,;=]{0,40})(=createjs[^,;=]{0,40}),")

    fun isMainScriptUrl(url: String?): Boolean {
        if (url == null) return false
        val uri = try {
            URI(url)
        } catch (_: Exception) {
            return false
        }
        if (uri.scheme?.lowercase(Locale.ROOT) !in setOf("http", "https")) return false
        val host = uri.host?.lowercase(Locale.ROOT) ?: return false
        if (host != "kancolle-server.com" && !host.endsWith(".kancolle-server.com")) return false
        return uri.path?.endsWith("/kcs2/js/main.js") == true
    }

    fun patch(mainScript: String): String = tickerPattern.replaceFirst(
        mainScript,
        "\$1=createjs.Ticker.RAF,",
    )
}

class GameMainScriptFetcher(
    private val connectTimeoutMs: Int = 8_000,
    private val readTimeoutMs: Int = 15_000,
    private val maxResponseBytes: Int = 32 * 1024 * 1024,
) {
    fun fetch(url: String, requestHeaders: Map<String, String> = emptyMap()): ByteArray? {
        if (!GameMainScriptPatcher.isMainScriptUrl(url)) return null
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = connectTimeoutMs
        connection.readTimeout = readTimeoutMs
        connection.instanceFollowRedirects = true
        requestHeaders.forEach { (name, value) ->
            if (!name.equals("Host", true) && !name.equals("Accept-Encoding", true)) {
                connection.setRequestProperty(name, value)
            }
        }
        return try {
            if (connection.responseCode !in 200..299) return null
            connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val chunk = ByteArray(8192)
                var total = 0
                while (true) {
                    val read = input.read(chunk)
                    if (read < 0) break
                    total += read
                    if (total > maxResponseBytes) return null
                    output.write(chunk, 0, read)
                }
                output.toByteArray()
            }
        } finally {
            connection.disconnect()
        }
    }
}
