package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.net.URL
import java.net.HttpURLConnection
import java.net.Proxy
import java.util.concurrent.TimeUnit

class GameResourceFetcherTest {
    @get:Rule val temporaryFolder = TemporaryFolder()

    @Test
    fun `default downloads preserve system routing instead of forcing direct access`() {
        var called = false
        var requestedProxy: Proxy? = Proxy.NO_PROXY
        val fetcher = HttpUrlConnectionGameResourceFetcher(
            temporaryDirectory = temporaryFolder.newFolder("system-proxy"),
            connectionFactory = { _, proxy -> called = true; requestedProxy = proxy; null },
        )
        assertNull(fetcher.fetch("https://w17k.kancolle-server.com/kcs2/resources/a.png", emptyMap(), null))
        assertTrue(called)
        assertNull("No application override must retain the system proxy selector", requestedProxy)
    }

    @Test
    fun `slow resource download falls back within total budget and leaves no late file`() {
        val server = TestHttpServer()
        server.start()
        val directory = temporaryFolder.newFolder("budget")
        val url = "https://w17k.kancolle-server.com/kcs2/resources/a.png"
        server.handlers["/resource"] = Pair({ Thread.sleep(300); byteArrayOf(1, 2, 3) }, 200)
        val fetcher = HttpUrlConnectionGameResourceFetcher(
            connectTimeoutMs = 3000, readTimeoutMs = 3000, temporaryDirectory = directory,
            totalTimeoutMs = 80,
            connectionFactory = { _, _ -> URL("http://127.0.0.1:${server.port}/resource").openConnection() as HttpURLConnection },
        )
        try {
            val started = System.nanoTime()
            assertNull(fetcher.fetch(url, emptyMap(), null))
            assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started) < 500)
            Thread.sleep(350)
            assertTrue(directory.listFiles().orEmpty().isEmpty())
        } finally { server.stop() }
    }

    @Test
    fun `download streams body into a temporary file`() {
        val bytes = ByteArray(64 * 1024) { it.toByte() }
        val file = HttpUrlConnectionGameResourceFetcher.downloadToTemporaryFile(
            ByteArrayInputStream(bytes), bytes.size.toLong(), bytes.size.toLong(),
            temporaryFolder.root,
        )

        assertArrayEquals(bytes, file?.readBytes())
        assertEquals(1, temporaryFolder.root.listFiles()?.size)
    }

    @Test
    fun `oversized or truncated body leaves no temporary file`() {
        val bytes = ByteArray(1024)
        assertNull(HttpUrlConnectionGameResourceFetcher.downloadToTemporaryFile(
            ByteArrayInputStream(bytes), -1, 512, temporaryFolder.root,
        ))
        assertNull(HttpUrlConnectionGameResourceFetcher.downloadToTemporaryFile(
            ByteArrayInputStream(bytes), 2048, 2048, temporaryFolder.root,
        ))
        assertTrue(temporaryFolder.root.listFiles().orEmpty().isEmpty())
    }
}
