package app.yahagi.kancollebrowser.browser

import java.net.ServerSocket
import java.nio.charset.StandardCharsets

/**
 * A tiny HTTP server for JVM tests. `com.sun.net.httpserver` is not on the
 * Android unit-test compile classpath, so this uses plain ServerSocket.
 */
internal class TestHttpServer {
    private val serverSocket = ServerSocket(0)
    private val thread = Thread { serve() }

    val port: Int = serverSocket.localPort

    /** path prefix -> (handler). Handler returns bytes and status code. */
    val handlers = mutableMapOf<String, Pair<(String) -> ByteArray, Int>>()
    val hits = mutableMapOf<String, Int>()

    /** When true, accepted connections are closed without responding. */
    @Volatile
    var hang: Boolean = false

    fun start() {
        thread.isDaemon = true
        thread.start()
    }

    fun stop() {
        serverSocket.close()
    }

    private fun serve() {
        while (!serverSocket.isClosed) {
            val socket = try {
                serverSocket.accept()
            } catch (e: Exception) {
                return
            }
            Thread {
                try {
                    handle(socket)
                } catch (e: Exception) {
                    // Ignore client errors in tests.
                } finally {
                    try {
                        socket.close()
                    } catch (e: Exception) {
                        // Ignore.
                    }
                }
            }.start()
        }
    }

    private fun handle(socket: java.net.Socket) {
        if (hang) {
            // Keep the socket open without responding until the client times out.
            Thread.sleep(60_000)
            return
        }
        val input = socket.getInputStream().bufferedReader(StandardCharsets.UTF_8)
        val requestLine = input.readLine() ?: return
        val parts = requestLine.split(" ")
        val path = if (parts.size >= 2) parts[1] else "/"
        // Consume headers.
        while (true) {
            val line = input.readLine() ?: break
            if (line.isEmpty()) break
        }

        val entry = handlers.entries.firstOrNull { path.startsWith(it.key) }
        val pair = entry?.value ?: Pair<(String) -> ByteArray, Int>({ ByteArray(0) }, 404)
        val handler = pair.first
        val status = pair.second
        hits[entry?.key ?: "/unmatched"] = (hits[entry?.key ?: "/unmatched"] ?: 0) + 1
        val body = handler(path)
        val head = "HTTP/1.1 $status OK\r\n" +
            "Content-Length: ${body.size}\r\n" +
            "Connection: close\r\n\r\n"
        socket.getOutputStream().use { it.write(head.toByteArray(StandardCharsets.US_ASCII) + body) }
    }
}
