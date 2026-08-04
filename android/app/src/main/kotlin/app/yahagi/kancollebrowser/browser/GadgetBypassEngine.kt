package app.yahagi.kancollebrowser.browser

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Fetches gadget client files from a mirror endpoint with a disk cache and a
 * direct-connection fallback.
 *
 * The engine is Android-free so it can be exercised by plain JVM unit tests.
 */
class GadgetBypassEngine(
    private val cache: GadgetBypassCache,
    private val connectTimeoutMs: Int = 8_000,
    private val readTimeoutMs: Int = 15_000,
    private val maxResponseBytes: Int = 64 * 1024 * 1024,
    private val endpointValidator: (String) -> Boolean = {
        GadgetBypassRules.validateEndpoint(it).isValid
    },
    private val onCacheHit: (String) -> Unit = {},
) {
    /**
     * Returns the bytes that should be served for [originalUrl], or null when the
     * request is out of scope or every source failed.
     */
    fun fetch(originalUrl: String, endpoint: String): ByteArray? {
        if (!GadgetBypassRules.shouldIntercept(originalUrl, "GET")) return null
        if (!endpointValidator(endpoint)) return null

        val cacheKey = "${endpoint.trimEnd('/')}\n$originalUrl"
        cache.get(cacheKey)?.let {
            onCacheHit(originalUrl)
            return it
        }

        val rewritten = GadgetBypassRules.rewrite(originalUrl, endpoint) ?: return null
        try {
            val fromEndpoint = download(rewritten)
            if (fromEndpoint != null) {
                cache.put(cacheKey, fromEndpoint)
                return fromEndpoint
            }
        } catch (e: Exception) {
            // Fall through to the direct source.
        }

        return null
    }

    private fun download(urlString: String): ByteArray? {
        val connection = URL(urlString).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = connectTimeoutMs
        connection.readTimeout = readTimeoutMs
        connection.instanceFollowRedirects = false
        connection.setRequestProperty("User-Agent", "Yahagi-GadgetBypass/1.0")
        try {
            val code = connection.responseCode
            if (code !in 200..299) return null
            return connection.inputStream.use { readLimited(it) }
        } finally {
            connection.disconnect()
        }
    }

    private fun readLimited(input: InputStream): ByteArray? {
        val buffer = ByteArrayOutputStream()
        val chunk = ByteArray(8192)
        var total = 0
        while (true) {
            val read = input.read(chunk)
            if (read < 0) break
            total += read
            if (total > maxResponseBytes) return null
            buffer.write(chunk, 0, read)
        }
        return buffer.toByteArray()
    }
}
