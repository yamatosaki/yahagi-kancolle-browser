package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GadgetBypassRulesTest {
    @Test
    fun interceptsOnlyGadgetHtml5RequestsOnW00g() {
        assertTrue(
            GadgetBypassRules.shouldIntercept(
                "https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js",
                "GET",
            ),
        )
        assertTrue(
            GadgetBypassRules.shouldIntercept(
                "http://w00g.kancolle-server.com/gadget_html5/index.html",
                "get",
            ),
        )
    }

    @Test
    fun doesNotInterceptKcsapiOrOtherHosts() {
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "http://203.104.209.7/kcsapi/api_start2/getData",
                "GET",
            ),
        )
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://w00g.kancolle-server.com/kcsapi/api_port/port",
                "GET",
            ),
        )
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://accounts.dmm.com/service/login",
                "GET",
            ),
        )
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://osapi.dmm.com/gadgets/ifr?aid=854854",
                "GET",
            ),
        )
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://www.kancolle-server.com/gadget_html5/js/main.js",
                "GET",
            ),
        )
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://w00g.kancolle-server.com/gadget_html5/../kcsapi/api_port/port",
                "GET",
            ),
        )
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://w00g.kancolle-server.com/gadget_html5/%2e%2e/kcsapi/api_port/port",
                "GET",
            ),
        )
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://w00g.kancolle-server.com.evil.example/gadget_html5/js/main.js",
                "GET",
            ),
        )
    }

    @Test
    fun doesNotInterceptPostRequestsOrNullUrls() {
        assertFalse(
            GadgetBypassRules.shouldIntercept(
                "https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js",
                "POST",
            ),
        )
        assertFalse(GadgetBypassRules.shouldIntercept(null, "GET"))
    }

    @Test
    fun rewritesW00gPrefixToEndpoint() {
        assertEquals(
            "https://kcwiki.github.io/cache/gadget_html5/js/kcs_cda.js",
            GadgetBypassRules.rewrite(
                "https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js",
                "https://kcwiki.github.io/cache/",
            ),
        )
        assertEquals(
            "https://luckyjervis.com/gadget_html5/index.html?ver=1",
            GadgetBypassRules.rewrite(
                "http://w00g.kancolle-server.com/gadget_html5/index.html?ver=1",
                "https://luckyjervis.com",
            ),
        )
    }

    @Test
    fun rewriteReturnsNullForUnrelatedUrls() {
        assertNull(
            GadgetBypassRules.rewrite(
                "https://accounts.dmm.com/service/login",
                "https://kcwiki.github.io/cache/",
            ),
        )
    }

    @Test
    fun validatesAndNormalizesSafeHttpsEndpoints() {
        val result = GadgetBypassRules.validateEndpoint(
            "https://KCWIKI.GITHUB.IO/cache",
        )
        assertTrue(result.isValid)
        assertEquals("https://kcwiki.github.io/cache/", result.normalized)
        assertNull(result.error)
    }

    @Test
    fun rejectsUnsafeEndpoints() {
        val endpoints = listOf(
            "http://kcwiki.github.io/cache/",
            "https://user:pass@kcwiki.github.io/cache/",
            "https://localhost/cache/",
            "https://127.0.0.1/cache/",
            "https://10.0.0.1/cache/",
            "https://kcwiki.github.io/cache/?target=https://evil.example",
            "https://kcwiki.github.io/cache/#fragment",
            "https://kcwiki.github.io/cache/../private/",
            "https://kcwiki.github.io/cache/%2e%2e/private/",
            "https://w00g.kancolle-server.com/",
        )
        endpoints.forEach { endpoint ->
            assertFalse(endpoint, GadgetBypassRules.validateEndpoint(endpoint).isValid)
        }
    }

    @Test
    fun mapsKnownFileExtensionsToMimeTypes() {
        assertEquals(
            "application/javascript",
            GadgetBypassRules.mimeTypeFor("https://x/gadget_html5/js/kcs_cda.js").mime,
        )
        assertEquals(
            "text/html",
            GadgetBypassRules.mimeTypeFor("https://x/gadget_html5/index.html").mime,
        )
        assertEquals(
            "image/png",
            GadgetBypassRules.mimeTypeFor("https://x/gadget_html5/img/icon.png").mime,
        )
        assertEquals(
            "text/css",
            GadgetBypassRules.mimeTypeFor("https://x/gadget_html5/css/main.css").mime,
        )
    }

    @Test
    fun mapsUnknownExtensionsToOctetStream() {
        assertEquals(
            "application/octet-stream",
            GadgetBypassRules.mimeTypeFor("https://x/gadget_html5/data/unknown.xyz").mime,
        )
    }
}
