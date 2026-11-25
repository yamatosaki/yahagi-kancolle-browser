package app.yahagi.kancollebrowser.mods

import com.google.gson.Gson
import com.google.gson.JsonParser
import java.io.ByteArrayInputStream
import java.net.URI
import java.net.URLDecoder

/** Private virtual routes. They never forward configuration or acknowledgements to the network. */
internal class GameModCoordinateEndpoint(
    private val snapshot: () -> Map<String, Any?>?,
    private val kanxyActive: () -> Boolean,
    private val stockShipNames: () -> Map<String, String> = { emptyMap() },
    private val record: (Long, String, List<String>, String?) -> Unit,
) {
    constructor(
        snapshot: () -> Map<String, Any?>?,
        record: (Long, String, List<String>, String?) -> Unit,
    ) : this(snapshot, { false }, record = record)

    private val gson = Gson()

    fun open(url: String, method: String): GameModResponse? {
        // Recognize paths before decoding query data so malformed reports also fail closed.
        val base = runCatching { URI(url.substringBefore('?')) }.getOrNull() ?: return null
        if (base.scheme != "https" || base.userInfo != null || base.fragment != null ||
            base.port !in listOf(-1, 443) ||
            !Regex("w[0-9]+[a-z]\\.kancolle-server\\.com").matches(base.host.orEmpty()) ||
            base.rawPath !in listOf(CONFIG_PATH, REPORT_PATH)) return null
        if (method != "GET") return response(405, "Method Not Allowed")
        return try {
            if (base.rawPath == CONFIG_PATH) {
                if (url.contains('?') || url.contains('#')) return response(400, "Bad Request")
                val local = snapshot() ?: mapOf("sessionId" to 0, "token" to "",
                    "ships" to emptyMap<String, Any>(), "questTranslations" to emptyMap<String, Any>())
                val config = if (kanxyActive()) {
                    local + mapOf("kanxy" to true, "stockShipNames" to stockShipNames())
                } else local
                response(200, "OK", config)
            } else {
                val raw = url.substringAfter('?', "")
                if (raw.length > 65_536 || !raw.startsWith("payload=") || raw.contains('&') || raw.contains('#')) {
                    return response(400, "Bad Request")
                }
                val body = JsonParser.parseString(URLDecoder.decode(raw.removePrefix("payload="), "UTF-8")).asJsonObject
                val session = body.get("sessionId")?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isNumber }
                    ?.asString?.takeIf { it.matches(Regex("[0-9]{1,16}")) }?.toLongOrNull()
                    ?.takeIf { it <= 9_007_199_254_740_991L } ?: return response(400, "Bad Request")
                val token = body.get("token")?.takeIf { it.isJsonPrimitive && it.asJsonPrimitive.isString }
                    ?.asString?.takeIf { it.length in 1..128 } ?: return response(400, "Bad Request")
                val array = body.getAsJsonArray("resourceIds") ?: return response(400, "Bad Request")
                if (array.size() !in 1..256) return response(400, "Bad Request")
                val ids = array.map {
                    if (!it.isJsonPrimitive || !it.asJsonPrimitive.isString || it.asString.length !in 1..200) {
                        return response(400, "Bad Request")
                    }
                    it.asString
                }.distinct()
                val failureValue = body.get("failure")
                val failure = if (failureValue == null || failureValue.isJsonNull) null
                    else if (failureValue.isJsonPrimitive && failureValue.asJsonPrimitive.isString &&
                        failureValue.asString == "coordinate_apply_failed") failureValue.asString
                    else return response(400, "Bad Request")
                record(session, token, ids, failure)
                response(200, "OK")
            }
        } catch (_: Exception) { response(400, "Bad Request") }
    }

    private fun response(status: Int, reason: String, body: Any = emptyMap<String, Any>()): GameModResponse {
        val bytes = gson.toJson(body).toByteArray(Charsets.UTF_8)
        return GameModResponse("application/json", status, reason,
            mapOf("Content-Type" to "application/json; charset=utf-8", "Content-Length" to bytes.size.toString(),
                "Cache-Control" to "no-store"), ByteArrayInputStream(bytes))
    }

    private companion object {
        const val CONFIG_PATH = "/__yahagi_mods__/coordinates.json"
        const val REPORT_PATH = "/__yahagi_mods__/coordinates-report"
    }
}
