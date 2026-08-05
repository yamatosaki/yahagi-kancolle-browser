package app.yahagi.kancollebrowser.browser

import java.net.HttpURLConnection
import java.net.URL

data class GadgetBypassProbe(
    val reachable: Boolean,
    val statusCode: Int?,
    val elapsedMs: Long,
    val error: String?,
) {
    val blocked: Boolean
        get() = statusCode == 403

    val successful: Boolean
        get() = statusCode in 200..299
}

/**
 * Connectivity probes for the bypass feature.
 *
 * "Reachable" means the server answered with any HTTP status code; a 4xx/5xx
 * still proves the network path works. Android-free so it can be JVM tested.
 */
object GadgetBypassDiagnostics {
    fun w00gGadgetUrl(): String =
        "https://w00g.kancolle-server.com/gadget_html5/js/kcs_const.js"

    fun endpointGadgetUrl(endpoint: String): String =
        GadgetBypassRules.rewrite(w00gGadgetUrl(), endpoint) ?: w00gGadgetUrl()

    fun probe(
        url: String,
        connectTimeoutMs: Int = 8_000,
        readTimeoutMs: Int = 10_000,
    ): GadgetBypassProbe {
        val start = System.currentTimeMillis()
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = connectTimeoutMs
            connection.readTimeout = readTimeoutMs
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("User-Agent", "Yahagi-GadgetBypass/1.0")
            val code = try {
                connection.responseCode
            } finally {
                connection.disconnect()
            }
            GadgetBypassProbe(
                reachable = true,
                statusCode = code,
                elapsedMs = System.currentTimeMillis() - start,
                error = null,
            )
        } catch (e: Exception) {
            GadgetBypassProbe(
                reachable = false,
                statusCode = null,
                elapsedMs = System.currentTimeMillis() - start,
                error = e.message,
            )
        }
    }
}
