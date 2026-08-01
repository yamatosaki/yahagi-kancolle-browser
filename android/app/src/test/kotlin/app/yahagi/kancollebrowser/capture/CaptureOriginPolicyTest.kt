package app.yahagi.kancollebrowser.capture

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureOriginPolicyTest {
    private val policy = CaptureOriginPolicy()

    @Test
    fun allowsDmmAndKancolleHttpsOrigins() {
        assertTrue(policy.isAllowed("https://www.dmm.com"))
        assertTrue(policy.isAllowed("https://accounts.dmm.co.jp"))
        assertTrue(policy.isAllowed("https://w01y.kancolle-server.com"))
    }

    @Test
    fun rejectsLookalikeInsecureAndNonDefaultPortOrigins() {
        assertFalse(policy.isAllowed("http://www.dmm.com"))
        assertFalse(policy.isAllowed("https://www.dmm.com:8443"))
        assertFalse(policy.isAllowed("https://dmm.com.example.org"))
        assertFalse(policy.isAllowed("https://evildmm.com"))
        assertFalse(policy.isAllowed("not a uri"))
    }

    @Test
    fun exposesOnlyExplicitHttpsOriginRules() {
        assertTrue(
            policy.allowedOriginRules.contains("https://*.dmm.com"),
        )
        assertTrue(
            policy.allowedOriginRules.contains("https://*.dmm.co.jp"),
        )
        assertTrue(
            policy.allowedOriginRules.contains(
                "https://*.kancolle-server.com",
            ),
        )
        assertFalse(policy.allowedOriginRules.contains("*"))
    }
}
