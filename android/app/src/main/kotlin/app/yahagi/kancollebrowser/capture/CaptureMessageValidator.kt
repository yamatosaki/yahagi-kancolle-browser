package app.yahagi.kancollebrowser.capture

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

enum class CaptureMessageFailure {
    INVALID_FORMAT,
    TOO_LARGE,
}

class CaptureMessageValidator(
    private val maxMessageBytes: Int = 8 * 1024 * 1024,
    private val clock: () -> String = { Instant.now().toString() },
) {
    private val sensitiveKeys = setOf("api_token", "api_starttime")
    private var sequence = 0L

    var lastFailure: CaptureMessageFailure? = null
        private set

    fun validate(
        message: String,
        sourceOrigin: String,
    ): Map<String, Any?>? {
        if (message.toByteArray(Charsets.UTF_8).size > maxMessageBytes) {
            lastFailure = CaptureMessageFailure.TOO_LARGE
            return null
        }

        val json = try {
            JSONObject(message)
        } catch (_: Exception) {
            lastFailure = CaptureMessageFailure.INVALID_FORMAT
            return null
        }

        val event = try {
            parse(json, sourceOrigin)
        } catch (_: Exception) {
            null
        }
        lastFailure = if (event == null) {
            CaptureMessageFailure.INVALID_FORMAT
        } else {
            null
        }
        return event
    }

    private fun parse(
        json: JSONObject,
        sourceOrigin: String,
    ): Map<String, Any?>? {
        val kind = json.optString("kind")
        if (json.optInt("version", -1) != 1 || kind != "kcsapi_response") {
            return null
        }


        val method = json.optString("method")
        val path = json.optString("path")
        val transport = json.optString("transport")
        if (method !in setOf("GET", "POST") ||
            !path.startsWith("/kcsapi/") ||
            transport !in setOf("xhr", "fetch") ||
            !json.has("responseBody") ||
            json.opt("responseBody") !is String ||
            !json.has("statusCode") ||
            json.opt("statusCode") !is Number
        ) {
            return null
        }

        val requestParams = json.optJSONObject("requestParams") ?: return null
        val statusCode = json.getInt("statusCode")
        if (statusCode !in 0..599) {
            return null
        }

        sequence += 1
        return linkedMapOf(
            "version" to 1,
            "kind" to "kcsapi_response",
            "method" to method,
            "path" to path,
            "requestParams" to sanitizeObject(requestParams),
            "responseBody" to json.getString("responseBody"),
            "statusCode" to statusCode,
            "transport" to transport,
            "sourceOrigin" to sourceOrigin,
            "capturedAt" to clock(),
            "sequence" to sequence,
        )
    }

    private fun sanitizeObject(value: JSONObject): Map<String, Any?> {
        val output = linkedMapOf<String, Any?>()
        val keys = value.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            if (key !in sensitiveKeys) {
                output[key] = sanitizeValue(value.opt(key))
            }
        }
        return output
    }

    private fun sanitizeArray(value: JSONArray): List<Any?> {
        return List(value.length()) { index ->
            sanitizeValue(value.opt(index))
        }
    }

    private fun sanitizeValue(value: Any?): Any? {
        return when (value) {
            null, JSONObject.NULL -> null
            is JSONObject -> sanitizeObject(value)
            is JSONArray -> sanitizeArray(value)
            is String, is Number, is Boolean -> value
            else -> value.toString()
        }
    }
}
