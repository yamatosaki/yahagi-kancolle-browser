package app.yahagi.kancollebrowser.browser

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GadgetBypassCacheTest {
    private fun tempDir(): File = Files.createTempDirectory("gadget-cache-test").toFile()

    @Test
    fun storesAndReadsBytesByUrl() {
        val cache = GadgetBypassCache(tempDir(), now = { 1000L })
        val url = "https://w00g.kancolle-server.com/gadget_html5/js/main.js"
        val bytes = "console.log('hi')".toByteArray()
        cache.put(url, bytes)
        assertArrayEquals(bytes, cache.get(url))
    }

    @Test
    fun returnsNullForMissingEntries() {
        val cache = GadgetBypassCache(tempDir(), now = { 1000L })
        assertNull(cache.get("https://w00g.kancolle-server.com/missing.js"))
    }

    @Test
    fun expiresEntriesOlderThanMaxAge() {
        var currentTime = 1000L
        val cache = GadgetBypassCache(
            tempDir(),
            maxAgeMs = 24 * 60 * 60 * 1000L,
            now = { currentTime },
        )
        cache.put("https://w00g.kancolle-server.com/gadget_html5/js/a.js", byteArrayOf(1))
        currentTime += 25 * 60 * 60 * 1000L
        assertNull(cache.get("https://w00g.kancolle-server.com/gadget_html5/js/a.js"))
    }

    @Test
    fun keepsEntriesWithinMaxAge() {
        var currentTime = 1000L
        val cache = GadgetBypassCache(
            tempDir(),
            maxAgeMs = 24 * 60 * 60 * 1000L,
            now = { currentTime },
        )
        cache.put("https://w00g.kancolle-server.com/gadget_html5/js/a.js", byteArrayOf(1))
        currentTime += 23 * 60 * 60 * 1000L
        assertArrayEquals(byteArrayOf(1), cache.get("https://w00g.kancolle-server.com/gadget_html5/js/a.js"))
    }

    @Test
    fun evictsOldestWhenOverCapacity() {
        var currentTime = 1000L
        val cache = GadgetBypassCache(
            tempDir(),
            maxBytes = 100,
            now = { currentTime },
        )
        val urlA = "https://w00g.kancolle-server.com/gadget_html5/a.js"
        val urlB = "https://w00g.kancolle-server.com/gadget_html5/b.js"
        cache.put(urlA, ByteArray(60))
        currentTime += 1
        cache.put(urlB, ByteArray(60))
        assertEquals(60L, cache.sizeBytes())
        assertNull(cache.get(urlA))
        assertArrayEquals(ByteArray(60), cache.get(urlB))
    }

    @Test
    fun clearRemovesAllEntries() {
        val cache = GadgetBypassCache(tempDir(), now = { 1000L })
        cache.put("https://w00g.kancolle-server.com/a.js", byteArrayOf(1))
        cache.put("https://w00g.kancolle-server.com/b.js", byteArrayOf(2))
        cache.clear()
        assertEquals(0L, cache.sizeBytes())
        assertNull(cache.get("https://w00g.kancolle-server.com/a.js"))
    }
}
