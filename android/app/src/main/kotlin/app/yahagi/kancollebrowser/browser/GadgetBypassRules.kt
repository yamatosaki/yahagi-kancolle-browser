package app.yahagi.kancollebrowser.browser

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Locale

/**
 * Pure rules for the gadget-server bypass.
 *
 * Only GET requests for game client files under `w00g.kancolle-server.com/gadget_html5/`
 * are rewritten to a mirror endpoint. API (kcsapi), DMM and every other host stay untouched.
 */
object GadgetBypassRules {
    const val GADGET_HOST = "w00g.kancolle-server.com"
    const val DEFAULT_ENDPOINT = "https://kcwiki.github.io/cache/"

    data class MimeInfo(val mime: String, val encoding: String?)

    data class EndpointValidation(
        val isValid: Boolean,
        val normalized: String? = null,
        val error: String? = null,
    )

    fun shouldIntercept(url: String?, method: String?): Boolean {
        if (url == null) return false
        if (method != null && !method.equals("GET", ignoreCase = true)) return false
        if (hasUnsafeRawPath(url)) return false
        val uri = try {
            URI(url)
        } catch (_: Exception) {
            return false
        }
        if (uri.scheme?.lowercase(Locale.ROOT) !in setOf("http", "https")) return false
        if (!uri.host.equals(GADGET_HOST, ignoreCase = true)) return false
        if (uri.userInfo != null) return false
        val path = uri.rawPath ?: return false
        if (!path.startsWith("/gadget_html5/")) return false
        return path.split('/').none { it == "." || it == ".." }
    }

    /** Replaces the w00g origin with [endpoint], keeping the path and query intact. */
    fun rewrite(url: String, endpoint: String): String? {
        if (!shouldIntercept(url, "GET")) return null
        val source = try {
            URI(url)
        } catch (_: Exception) {
            return null
        }
        val base = endpoint.trim().trimEnd('/')
        if (base.isEmpty()) return null
        val path = source.rawPath.removePrefix("/")
        val query = source.rawQuery?.let { "?$it" }.orEmpty()
        return "$base/$path$query"
    }

    fun validateEndpoint(endpoint: String): EndpointValidation {
        val candidate = endpoint.trim()
        if (hasUnsafeRawPath(candidate)) {
            return EndpointValidation(false, error = "path_not_allowed")
        }
        val uri = try {
            URI(candidate)
        } catch (_: Exception) {
            return EndpointValidation(false, error = "invalid_url")
        }
        if (!uri.scheme.equals("https", ignoreCase = true)) {
            return EndpointValidation(false, error = "https_required")
        }
        if (uri.userInfo != null || uri.rawQuery != null || uri.rawFragment != null) {
            return EndpointValidation(false, error = "endpoint_components_not_allowed")
        }
        if (uri.port !in setOf(-1, 443)) {
            return EndpointValidation(false, error = "port_not_allowed")
        }
        val host = uri.host?.lowercase(Locale.ROOT)
            ?: return EndpointValidation(false, error = "host_required")
        if (!isPublicHostname(host) || host == GADGET_HOST) {
            return EndpointValidation(false, error = "host_not_allowed")
        }
        val rawPath = uri.rawPath.orEmpty().ifEmpty { "/" }
        if (rawPath.split('/').any { it == "." || it == ".." }) {
            return EndpointValidation(false, error = "path_not_allowed")
        }
        val normalizedPath = if (rawPath.endsWith('/')) rawPath else "$rawPath/"
        val normalized = URI(
            "https",
            null,
            host,
            -1,
            normalizedPath,
            null,
            null,
        ).toASCIIString()
        return EndpointValidation(true, normalized = normalized)
    }

    private fun isPublicHostname(host: String): Boolean {
        if (host == "localhost" || host.endsWith(".localhost") || host.endsWith(".local")) {
            return false
        }
        if (host.contains(':')) return false
        val ipv4 = host.split('.').map { it.toIntOrNull() }
        if (ipv4.size == 4 && ipv4.all { it != null && it in 0..255 }) return false
        return host.contains('.') && host.none { it.isWhitespace() }
    }

    private fun hasUnsafeRawPath(value: String): Boolean {
        val authorityStart = value.indexOf("://")
        if (authorityStart < 0) return false
        val pathStart = value.indexOf('/', authorityStart + 3)
        if (pathStart < 0) return false
        val rawPath = value.substring(pathStart).substringBefore('?').substringBefore('#')
        return rawPath.split('/').any { rawSegment ->
            var decoded = rawSegment
            repeat(2) {
                decoded = try {
                    URLDecoder.decode(decoded, StandardCharsets.UTF_8.name())
                } catch (_: Exception) {
                    return true
                }
            }
            decoded == "." || decoded == ".." || decoded.contains('/') || decoded.contains('\\')
        }
    }

    fun mimeTypeFor(url: String): MimeInfo {
        val path = url.substringBefore('?').substringBefore('#')
        val extension = path.substringAfterLast('.', "").lowercase()
        return when (extension) {
            "html", "htm" -> MimeInfo("text/html", "utf-8")
            "js", "mjs" -> MimeInfo("application/javascript", "utf-8")
            "css" -> MimeInfo("text/css", "utf-8")
            "json" -> MimeInfo("application/json", "utf-8")
            "svg" -> MimeInfo("image/svg+xml", "utf-8")
            "png" -> MimeInfo("image/png", null)
            "jpg", "jpeg" -> MimeInfo("image/jpeg", null)
            "gif" -> MimeInfo("image/gif", null)
            "webp" -> MimeInfo("image/webp", null)
            "woff" -> MimeInfo("font/woff", null)
            "woff2" -> MimeInfo("font/woff2", null)
            "ttf" -> MimeInfo("font/ttf", null)
            "mp3" -> MimeInfo("audio/mpeg", null)
            "ogg" -> MimeInfo("audio/ogg", null)
            "mp4" -> MimeInfo("video/mp4", null)
            "wasm" -> MimeInfo("application/wasm", null)
            else -> MimeInfo("application/octet-stream", null)
        }
    }
}
