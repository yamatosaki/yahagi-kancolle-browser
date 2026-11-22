package app.yahagi.kancollebrowser.browser

import java.net.URI
import java.security.MessageDigest
import java.util.Locale

@JvmInline
value class GameResourceCacheKey(val value: String) {
    companion object {
        fun from(
            url: String,
            requestHeaders: Map<String, String> = emptyMap(),
            includeStaticRequestHeaders: Boolean = false,
        ): GameResourceCacheKey? {
            if (url.length > 2_048) return null
            val uri = try {
                URI(url)
            } catch (_: Exception) {
                return null
            }
            if (!GameResourceCacheRules.isOfficialStaticUri(uri)) return null
            val path = uri.rawPath ?: return null
            val query = uri.rawQuery?.let { "?$it" }.orEmpty()
            val base = "https://${uri.host.lowercase(Locale.ROOT)}$path$query"
            val forwarded = GameResourceCacheRules.boundedForwardedRequestHeaders(requestHeaders)
                ?: return null
            if (!includeStaticRequestHeaders && GameResourceCacheRules.isShareableStaticUri(uri)) {
                return GameResourceCacheKey(base)
            }
            val variant = forwarded.entries
                .sortedBy { it.key.lowercase(Locale.ROOT) }
            if (variant.isEmpty()) return GameResourceCacheKey(base)
            val hasher = MessageDigest.getInstance("SHA-256")
            variant.forEachIndexed { index, (name, value) ->
                if (index > 0) hasher.update('\n'.code.toByte())
                hasher.update(name.lowercase(Locale.ROOT).toByteArray(Charsets.UTF_8))
                hasher.update(':'.code.toByte())
                hasher.update(value.toByteArray(Charsets.UTF_8))
            }
            val digest = hasher.digest()
                .joinToString("") { "%02x".format(it) }
            return GameResourceCacheKey("$base|headers=$digest")
        }
    }
}
