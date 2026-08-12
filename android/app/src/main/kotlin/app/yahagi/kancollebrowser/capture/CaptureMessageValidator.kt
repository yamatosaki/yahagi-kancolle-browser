package app.yahagi.kancollebrowser.capture

import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.time.Instant

enum class CaptureMessageFailure {
    INVALID_FORMAT,
    TOO_LARGE,
}

class CaptureMessageValidator(
    private val maxMessageBytes: Int = 8 * 1024 * 1024,
    private val clock: () -> String = { Instant.now().toString() },
) {
    private companion object {
        const val BINARY_HEADER_BYTES = 4
        const val MAX_METADATA_BYTES = 64 * 1024
    }

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
            val responseBody = json.opt("responseBody")
            if (responseBody !is String) {
                null
            } else {
                parse(
                    json = json,
                    sourceOrigin = sourceOrigin,
                    responseBodyKey = "responseBody",
                    responseBody = responseBody,
                )
            }
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

    fun validate(
        message: ByteArray,
        sourceOrigin: String,
    ): Map<String, Any?>? {
        if (message.size > maxMessageBytes) {
            lastFailure = CaptureMessageFailure.TOO_LARGE
            return null
        }
        if (message.size < BINARY_HEADER_BYTES) {
            lastFailure = CaptureMessageFailure.INVALID_FORMAT
            return null
        }

        val metadataSize = ByteBuffer.wrap(
            message,
            0,
            BINARY_HEADER_BYTES,
        ).int
        if (metadataSize <= 0 ||
            metadataSize > MAX_METADATA_BYTES ||
            metadataSize > message.size - BINARY_HEADER_BYTES
        ) {
            lastFailure = CaptureMessageFailure.INVALID_FORMAT
            return null
        }

        val metadataEnd = BINARY_HEADER_BYTES + metadataSize
        val metadata = decodeUtf8(
            message.copyOfRange(BINARY_HEADER_BYTES, metadataEnd),
        )
        if (metadata == null) {
            lastFailure = CaptureMessageFailure.INVALID_FORMAT
            return null
        }
        val json = try {
            JSONObject(metadata)
        } catch (_: Exception) {
            lastFailure = CaptureMessageFailure.INVALID_FORMAT
            return null
        }
        if (json.has("responseBody")) {
            lastFailure = CaptureMessageFailure.INVALID_FORMAT
            return null
        }

        val event = try {
            parse(
                json = json,
                sourceOrigin = sourceOrigin,
                responseBodyKey = "responseBodyBytes",
                responseBody = message.copyOfRange(metadataEnd, message.size),
            )
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
        responseBodyKey: String,
        responseBody: Any,
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
            responseBodyKey to responseBody,
            "statusCode" to statusCode,
            "transport" to transport,
            "sourceOrigin" to sourceOrigin,
            "capturedAt" to clock(),
            "sequence" to sequence,
        )
    }

    private fun decodeUtf8(bytes: ByteArray): String? {
        return try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes))
                .toString()
        } catch (_: Exception) {
            null
        }
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
