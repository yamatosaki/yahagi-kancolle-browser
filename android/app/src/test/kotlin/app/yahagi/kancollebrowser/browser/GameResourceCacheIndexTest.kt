package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class GameResourceCacheIndexTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `entry count tracks insert replacement removal and clear`() {
        val indexFile = temporaryFolder.newFolder().resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)
        assertEquals(0, index.entryCount())

        index.put(entry(1))
        assertEquals(1, index.entryCount())
        index.put(entry(1).copy(byteLength = 2))
        assertEquals(1, index.entryCount())
        index.put(entry(2))
        assertEquals(2, index.entryCount())

        index.remove(GameResourceCacheKey(entry(1).key))
        assertEquals(1, index.entryCount())
        index.remove(GameResourceCacheKey(entry(1).key))
        assertEquals(1, index.entryCount())
        assertEquals(1, GameResourceCacheIndex(indexFile).entryCount())

        index.clear()
        assertEquals(0, index.entryCount())
        assertEquals(0, GameResourceCacheIndex(indexFile).entryCount())
    }

    @Test
    fun `entry count loads snapshot and replays journal on first access`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)
        indexFile.writeText("{\"version\":2}\n${entry(1).toSnapshotLine()}\n")
        root.resolve("index.json.journal").writeText(
            "{\"op\":\"put\",\"entry\":${entry(2).toSnapshotLine()}}\n",
        )

        assertEquals(2, index.entryCount())
        index.removePrefix("/kcs2/resources/")
        assertEquals(0, index.entryCount())
        assertEquals(0, GameResourceCacheIndex(indexFile).entryCount())
    }

    @Test
    fun `updates use an append journal and survive reload`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)

        repeat(1_000) { id -> index.put(entry(id)) }

        val journal = root.resolve("index.json.journal")
        assertTrue(journal.isFile)
        assertFalse(indexFile.isFile)
        assertEquals(1_000, GameResourceCacheIndex(indexFile).snapshot().size)
    }

    @Test
    fun `journal tombstones survive reload without rewriting snapshot`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)
        index.put(entry(1))
        index.put(entry(2))

        index.remove(GameResourceCacheKey(entry(1).key))

        val reloaded = GameResourceCacheIndex(indexFile)
        assertEquals(listOf(entry(2).key), reloaded.snapshot().map { it.key })
    }

    @Test
    fun `clear journal prevents old entries from returning after reload`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val index = GameResourceCacheIndex(indexFile)
        index.put(entry(1))
        index.put(entry(2))

        index.clear()

        assertTrue(GameResourceCacheIndex(indexFile).snapshot().isEmpty())
        assertTrue(root.resolve("index.json.journal").readText().contains("\"op\":\"clear\""))
    }

    @Test
    fun `response security headers survive index reload`() {
        val indexFile = temporaryFolder.newFolder().resolve("index.json")
        val entry = entry(1).copy(responseHeaders = mapOf(
            "Content-Security-Policy" to "default-src 'none'",
        ))
        GameResourceCacheIndex(indexFile).put(entry)

        assertEquals(
            "default-src 'none'",
            GameResourceCacheIndex(indexFile).snapshot().single().responseHeaders["Content-Security-Policy"],
        )
    }

    @Test
    fun `index persists only browser essential response headers`() {
        val indexFile = temporaryFolder.newFolder().resolve("index.json")
        val original = entry(1).copy(responseHeaders = mapOf(
            "Content-Security-Policy" to "default-src 'none'",
            "Access-Control-Allow-Origin" to "https://example.com",
            "Server" to "x".repeat(20_000),
            "Content-Length" to "123",
        ))

        GameResourceCacheIndex(indexFile).put(original)
        val loaded = GameResourceCacheIndex(indexFile).snapshot().single()

        assertEquals("default-src 'none'", loaded.responseHeaders["Content-Security-Policy"])
        assertEquals("https://example.com", loaded.responseHeaders["Access-Control-Allow-Origin"])
        assertFalse(loaded.responseHeaders.containsKey("Server"))
        assertFalse(loaded.responseHeaders.containsKey("Content-Length"))
        assertFalse(indexFile.resolveSibling("index.json.journal").readText().contains("Server"))
    }

    @Test
    fun `truncated journal tail is discarded before a new record is appended`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val journal = root.resolve("index.json.journal")
        journal.writeText("{\"op\":\"put\"")
        val index = GameResourceCacheIndex(indexFile)

        assertTrue(index.snapshot().isEmpty())
        index.put(entry(1))

        assertEquals(listOf(entry(1).key), GameResourceCacheIndex(indexFile).snapshot().map { it.key })
        assertEquals(1, journal.readLines().count { it.isNotBlank() })
    }

    @Test
    fun `failed journal append does not change in memory index`() {
        val root = temporaryFolder.newFolder()
        val journal = root.resolve("index.json.journal")
        assertTrue(journal.mkdir())
        journal.resolve("child").writeText("nonempty")
        val index = GameResourceCacheIndex(root.resolve("index.json"))

        assertTrue(runCatching { index.put(entry(1)) }.isFailure)
        assertEquals(0, index.entryCount())
        assertTrue(index.snapshot().isEmpty())
        assertEquals(0L, index.totalBytes())
    }

    @Test
    fun `reference counts and byte totals track replacements and removals`() {
        val index = GameResourceCacheIndex(temporaryFolder.newFolder().resolve("index.json"))
        index.put(entry(1).copy(fileName = "shared.cache", byteLength = 3))
        index.put(entry(2).copy(fileName = "shared.cache", byteLength = 5))
        assertEquals(8L, index.totalBytes())
        index.remove(GameResourceCacheKey(entry(1).key))
        assertTrue(index.isFileReferenced("shared.cache"))
        index.remove(GameResourceCacheKey(entry(2).key))
        assertFalse(index.isFileReferenced("shared.cache"))
        assertEquals(0L, index.totalBytes())
    }

    @Test
    fun `loads line based snapshot without assembling a JSON array`() {
        val file = temporaryFolder.newFolder().resolve("index.json")
        file.writeText("{\"version\":2}\n${entry(1).toSnapshotLine()}\n${entry(2).toSnapshotLine()}\n")

        assertEquals(2, GameResourceCacheIndex(file).snapshot().size)
    }

    @Test
    fun `legacy snapshot skips oversized entry and keeps following entries`() {
        val file = temporaryFolder.newFolder().resolve("index.json")
        file.bufferedWriter().use { writer ->
            writer.write("{\"entries\":[")
            writer.write(entry(1).toSnapshotLine().dropLast(1))
            writer.write(",\"responseHeaders\":{\"ETag\":\"")
            writer.write("x".repeat(5_000_000))
            writer.write("\"}},")
            writer.write(entry(2).toSnapshotLine())
            writer.write("],\"version\":1}")
        }

        assertEquals(listOf(entry(2).key), GameResourceCacheIndex(file).snapshot().map { it.key })
    }

    @Test
    fun `journal skips oversized complete record and replays later records`() {
        val root = temporaryFolder.newFolder()
        val file = root.resolve("index.json")
        root.resolve("index.json.journal").bufferedWriter().use { writer ->
            writer.write("{\"op\":\"put\",\"entry\":{\"key\":\"")
            writer.write("x".repeat(20_000))
            writer.write("\"}}\n")
            writer.write("{\"op\":\"put\",\"entry\":${entry(2).toSnapshotLine()}}\n")
        }

        assertEquals(listOf(entry(2).key), GameResourceCacheIndex(file).snapshot().map { it.key })
    }

    @Test
    fun `rejects oversized entry metadata before journaling`() {
        val root = temporaryFolder.newFolder()
        val index = GameResourceCacheIndex(root.resolve("index.json"))
        val oversized = entry(1).copy(responseHeaders = mapOf("Content-Security-Policy" to "x".repeat(20_000)))

        assertThrows(IllegalArgumentException::class.java) { index.put(oversized) }
        assertTrue(index.snapshot().isEmpty())
        assertFalse(root.resolve("index.json.journal").exists())
    }

    @Test
    fun `caps distinct index entries`() {
        val file = temporaryFolder.newFolder().resolve("index.json")
        file.bufferedWriter().use { writer ->
            writer.write("{\"version\":2}\n")
            repeat(GameResourceCacheIndex.MAX_ENTRIES) { id ->
                writer.write(entry(id).toSnapshotLine())
                writer.write('\n'.code)
            }
        }
        val index = GameResourceCacheIndex(file)

        assertThrows(IllegalStateException::class.java) {
            index.put(entry(GameResourceCacheIndex.MAX_ENTRIES))
        }
        assertEquals(GameResourceCacheIndex.MAX_ENTRIES, index.snapshot().size)
        assertEquals(GameResourceCacheIndex.MAX_ENTRIES, GameResourceCacheIndex(file).snapshot().size)
        if (file.isFile) assertEquals("{\"version\":2}", file.bufferedReader().use { it.readLine() })
    }

    @Test
    fun `full baseline sized snapshot remains available`() {
        val file = temporaryFolder.newFolder().resolve("index.json")
        file.bufferedWriter().use { writer ->
            writer.write("{\"version\":2}\n")
            repeat(62_226) { id ->
                writer.write(entry(id).copy(
                    key = "https://w17k.kancolle-server.com/kcs2/resources/ship/full/$id.png?version=1",
                    fileName = "${id.toString().padStart(64, '0')}.cache",
                    sha256 = id.toString().padStart(64, '0'),
                ).toSnapshotLine())
                writer.write('\n'.code)
            }
        }

        val index = GameResourceCacheIndex(file)
        assertEquals(62_226, index.snapshot().size)
        assertFalse(index.isFull())
    }

    @Test
    fun `oversized legacy snapshot is reset without parsing it`() {
        val root = temporaryFolder.newFolder()
        val file = root.resolve("index.json")
        file.bufferedWriter().use { writer ->
            writer.write("{\"entries\":[\"")
            repeat(8_193) { writer.write("x".repeat(1_024)) }
            writer.write("\"]}")
        }
        val journal = root.resolve("index.json.journal")
        journal.writeText("{\"op\":\"put\",\"entry\":${entry(1).toSnapshotLine()}}\n")

        assertEquals(0, GameResourceCacheIndex(file).entryCount())
        assertFalse(file.exists())
        assertFalse(journal.exists())
    }

    @Test
    fun `total metadata budget prevents unbounded index growth`() {
        val file = temporaryFolder.newFolder().resolve("index.json")
        val index = GameResourceCacheIndex(file, maxMetadataBytes = 1_024)
        val headers = mapOf("Content-Security-Policy" to "x".repeat(400))
        index.put(entry(1).copy(responseHeaders = headers))

        assertThrows(IllegalArgumentException::class.java) {
            index.put(entry(2).copy(responseHeaders = headers))
        }
        assertEquals(listOf(entry(1).key), index.snapshot().map { it.key })
        assertEquals(listOf(entry(1).key),
            GameResourceCacheIndex(file, maxMetadataBytes = 1_024).snapshot().map { it.key })
    }

    private fun GameResourceCacheEntry.toSnapshotLine(): String =
        "{\"key\":\"$key\",\"fileName\":\"$fileName\",\"version\":null," +
            "\"mimeType\":\"$mimeType\",\"byteLength\":$byteLength," +
            "\"etag\":null,\"lastModified\":null,\"lastAccessedAt\":$lastAccessedAt," +
            "\"lastValidatedAt\":$lastValidatedAt,\"sha256\":\"$sha256\"}"

    private fun entry(id: Int) = GameResourceCacheEntry(
        key = "/kcs2/resources/$id.png",
        fileName = "$id.cache",
        version = null,
        mimeType = "image/png",
        byteLength = 1,
        etag = null,
        lastModified = null,
        lastAccessedAt = id.toLong(),
        lastValidatedAt = id.toLong(),
        sha256 = id.toString(),
    )
}
