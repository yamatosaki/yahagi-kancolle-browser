package app.yahagi.kancollebrowser.browser

import java.util.concurrent.atomic.AtomicLong

/** A request tracker for a single WebView; the bridge polls compact snapshots. */
internal class GameStartupActivityTracker(private val setting: Setting = Setting()) {
    @Volatile private var navigation: Navigation? = null

    val hasPendingNavigation: Boolean get() = currentNavigation()?.pending == true

    // Document and frame reload callbacks run on the UI thread.
    fun pageStarted(scheme: String?, host: String?) {
        startNavigation(isHttp(scheme) && !host.isNullOrEmpty())
    }

    fun startFrameReload() = startNavigation(eligible = true)

    private fun startNavigation(eligible: Boolean) {
        setting.refresh()
        navigation = setting.session?.takeIf { eligible }?.let {
            Navigation(nextNavigationId.incrementAndGet(), it)
        }
    }

    fun recordRequest(
        scheme: String?,
        host: String?,
        port: Int,
        userInfo: String?,
        path: String?,
        method: String,
    ) {
        val active = currentNavigation()?.takeIf { it.pending } ?: return
        if (!isHttp(scheme) || host.isNullOrEmpty()) return
        val kind = classifyGameRequest(scheme, host, port, userInfo, path, method)
        // If main-thread navigation replaces this object, this request can only
        // update the old object, which is no longer published by snapshot().
        active.record(kind)
    }

    fun snapshot(): Snapshot? {
        setting.refresh()
        return currentNavigation()?.snapshot()
    }

    private fun currentNavigation(): Navigation? {
        val session = setting.session ?: return null
        return navigation?.takeIf { it.settingSession === session }
    }

    /** Main-thread preference state, read on the WebView I/O thread without preferences access. */
    class Setting(private val readEnabled: () -> Boolean = { true }) {
        @Volatile var session: Any? = null
            private set

        val enabled: Boolean get() = session != null

        fun refresh() {
            val shouldEnable = readEnabled()
            // A fresh identity prevents an earlier navigation from reappearing
            // when monitoring is re-enabled, even for a detached WebView.
            if (shouldEnable != enabled) session = if (shouldEnable) Any() else null
        }
    }

    data class Snapshot(
        val navigationId: Long,
        val requestCount: Int,
        val gameResources: Boolean,
        val gameApi: Boolean,
    ) {
        fun toMap(): Map<String, Any> = mapOf(
            "navigationId" to navigationId,
            "requestCount" to requestCount,
            "gameResources" to gameResources,
            "gameApi" to gameApi,
        )
    }

    private enum class RequestKind { OTHER, RESOURCE, API }

    private class Navigation(private val id: Long, val settingSession: Any) {
        private var requestCount = 0
        private var gameResources = false
        @Volatile private var gameApi = false

        val pending: Boolean get() = !gameApi

        @Synchronized
        fun record(kind: RequestKind) {
            if (gameApi) return
            if (requestCount < Int.MAX_VALUE) requestCount++
            when (kind) {
                RequestKind.RESOURCE -> gameResources = true
                RequestKind.API -> gameApi = true
                RequestKind.OTHER -> Unit
            }
        }

        @Synchronized
        fun snapshot() = Snapshot(id, requestCount, gameResources, gameApi)
    }

    private companion object {
        val nextNavigationId = AtomicLong()
        val gameHost = Regex("w\\d+[a-z]\\.kancolle-server\\.com", RegexOption.IGNORE_CASE)

        fun isHttp(scheme: String?): Boolean = scheme.equals("https", true) || scheme.equals("http", true)

        fun classifyGameRequest(
            scheme: String?,
            host: String,
            port: Int,
            userInfo: String?,
            path: String?,
            method: String,
        ): RequestKind {
            if (path == null || userInfo != null) return RequestKind.OTHER
            val standardPort = if (scheme.equals("https", true)) 443 else 80
            if (port != -1 && port != standardPort) return RequestKind.OTHER
            val get = method.equals("GET", true)
            val kind = when {
                path.startsWith("/kcs2/", true) && get -> RequestKind.RESOURCE
                path.startsWith("/kcsapi/", true) && (get || method.equals("POST", true)) -> RequestKind.API
                else -> return RequestKind.OTHER
            }
            return if (gameHost.matches(host)) kind else RequestKind.OTHER
        }
    }
}
