package app.yahagi.kancollebrowser.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureMessageValidatorTest {
    @Test
    fun validatesProtocolAndAddsTrustedNativeMetadata() {
        val validator = CaptureMessageValidator(
            clock = { "2026-07-30T10:00:00.000Z" },
        )

        val event = validator.validate(
            validMessage(),
            "https://w01y.kancolle-server.com",
        )

        assertNotNull(event)
        assertEquals(1, event?.get("version"))
        assertEquals("kcsapi_response", event?.get("kind"))
        assertEquals("/kcsapi/api_port/port", event?.get("path"))
        assertEquals(
            "https://w01y.kancolle-server.com",
            event?.get("sourceOrigin"),
        )
        assertEquals("2026-07-30T10:00:00.000Z", event?.get("capturedAt"))
        assertEquals(1L, event?.get("sequence"))
    }

    @Test
    fun removesSensitiveRequestParametersRecursively() {
        val validator = CaptureMessageValidator()

        val event = validator.validate(
            validMessage(
                requestParams = """
                    {
                      "api_verno": "1",
                      "api_token": "secret",
                      "nested": {
                        "api_starttime": "secret",
                        "safe": true
                      }
                    }
                """.trimIndent(),
            ),
            "https://w01y.kancolle-server.com",
        )

        val params = event?.get("requestParams") as Map<*, *>
        assertFalse(params.containsKey("api_token"))
        val nested = params["nested"] as Map<*, *>
        assertFalse(nested.containsKey("api_starttime"))
        assertTrue(nested["safe"] as Boolean)
    }

    @Test
    fun rejectsObsoleteRequestInterceptMessages() {
        val validator = CaptureMessageValidator(
            clock = { "2026-07-30T10:00:00.000Z" },
        )
        val interceptMsg = """
            {
              "version": 1,
              "kind": "kcsapi_request_intercept",
              "path": "/kcsapi/api_req_map/start",
              "requestParams": {},
              "id": "123"
            }
        """.trimIndent()
        
        val event = validator.validate(interceptMsg, "https://w01y.kancolle-server.com")
        assertNull(event)
    }


    @Test
    fun rejectsWrongProtocolPathMethodAndTransport() {
        val validator = CaptureMessageValidator()

        assertNull(
            validator.validate(
                validMessage(version = 2),
                "https://w01y.kancolle-server.com",
            ),
        )
        assertNull(
            validator.validate(
                validMessage(path = "/analytics"),
                "https://w01y.kancolle-server.com",
            ),
        )
        assertNull(
            validator.validate(
                validMessage(method = "PUT"),
                "https://w01y.kancolle-server.com",
            ),
        )
        assertNull(
            validator.validate(
                validMessage(transport = "beacon"),
                "https://w01y.kancolle-server.com",
            ),
        )
    }

    @Test
    fun rejectsMessagesOverTheUtf8ByteLimit() {
        val validator = CaptureMessageValidator(maxMessageBytes = 32)

        assertNull(
            validator.validate(
                validMessage(responseBody = "舰".repeat(20)),
                "https://w01y.kancolle-server.com",
            ),
        )
        assertEquals(
            CaptureMessageFailure.TOO_LARGE,
            validator.lastFailure,
        )
    }

    private fun validMessage(
        version: Int = 1,
        path: String = "/kcsapi/api_port/port",
        method: String = "POST",
        transport: String = "xhr",
        responseBody: String = "svdata={\"api_result\":1}",
        requestParams: String = "{}",
    ): String {
        return """
            {
              "version": $version,
              "kind": "kcsapi_response",
              "method": "$method",
              "path": "$path",
              "requestParams": $requestParams,
              "responseBody": ${jsonString(responseBody)},
              "statusCode": 200,
              "transport": "$transport"
            }
        """.trimIndent()
    }

    private fun jsonString(value: String): String {
        return "\"" + value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"") + "\""
    }
}
