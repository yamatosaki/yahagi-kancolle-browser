package app.yahagi.kancollebrowser.capture

import java.net.URI
import java.util.Locale

class CaptureOriginPolicy {
    private val allowedRoots = setOf(
        "dmm.com",
        "dmm.co.jp",
        "kancolle-server.com",
    )

    val allowedOriginRules: Set<String> = setOf(
        "https://*.dmm.com",
        "https://*.dmm.co.jp",
        "https://*.kancolle-server.com",
    )

    fun isAllowed(origin: String): Boolean {
        val uri = try {
            URI(origin)
        } catch (_: Exception) {
            return false
        }
        if (!uri.scheme.equals("https", ignoreCase = true)) {
            return false
        }
        if (uri.port != -1 && uri.port != 443) {
            return false
        }
        if (uri.rawUserInfo != null || uri.rawQuery != null || uri.rawFragment != null) {
            return false
        }

        val host = uri.host?.lowercase(Locale.ROOT) ?: return false
        return allowedRoots.any { root ->
            host == root || host.endsWith(".$root")
        }
    }
}
