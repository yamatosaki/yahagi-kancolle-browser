package app.yahagi.kancollebrowser.browser

import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URI
import java.net.URL

/** JVM-only routing policy shared by native downloads and connection diagnostics. */
internal object NativeProxyRouting {
    fun fromUrl(proxyUrl: String): Proxy {
        val uri = URI(proxyUrl)
        val type = when {
            uri.scheme.equals("http", ignoreCase = true) -> Proxy.Type.HTTP
            uri.scheme.equals("socks", ignoreCase = true) -> Proxy.Type.SOCKS
            else -> throw IllegalArgumentException("Unsupported proxy protocol")
        }
        val host = requireNotNull(uri.host) { "Proxy host is required" }.removeSurrounding("[", "]")
        require(host.isNotEmpty() && uri.port in 1..65535) { "Invalid proxy host or port" }
        // Applying settings runs on the UI thread. Leave DNS to the connection worker.
        return Proxy(type, InetSocketAddress.createUnresolved(host, uri.port))
    }

    /** null means system routing; NO_PROXY explicitly requests a direct connection. */
    fun openConnection(url: URL, proxy: Proxy?): HttpURLConnection? =
        (if (proxy == null) url.openConnection() else url.openConnection(proxy)) as? HttpURLConnection
}
