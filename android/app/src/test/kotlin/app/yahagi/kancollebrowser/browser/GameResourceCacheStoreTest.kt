package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.nio.file.Files
import java.nio.file.attribute.BasicFileAttributes

class GameResourceCacheStoreTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `unreliable file identity rehashes valid files before reusing validation`() {
        val root = temporaryFolder.newFolder("unreliable-identity-valid")
        var checksums = 0
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            reliableFileIdentity = false,
            fileChecksum = { file ->
                checksums++
                MessageDigest.getInstance("SHA-256").digest(file.readBytes())
                    .joinToString("") { "%02x".format(it) }
            },
        )
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        val bytes = byteArrayOf(1, 2, 3)
        store.commit(key, bytes, mimeType = "image/png")
        checksums = 0
        val verified = checkNotNull(store.readFile(key))
        assertEquals(1, checksums)

        val validated = store.markVerifiedValidated(key, verified, emptyMap(), store.generation())

        assertEquals(2, checksums)
        assertNotNull(validated)
        assertArrayEquals(bytes, validated!!.file.readBytes())
    }

    @Test
    fun `unreliable equal metadata cannot reuse a checksum after same length content changes`() {
        val root = temporaryFolder.newFolder("unreliable-identity-damaged")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            reliableFileIdentity = false,
        )
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commit(key, byteArrayOf(1, 2, 3), mimeType = "image/png")
        val verified = checkNotNull(store.readFile(key))
        val before = checkNotNull(verified.identity)
        verified.file.writeBytes(byteArrayOf(4, 5, 6))
        Files.setLastModifiedTime(verified.file.toPath(), before.modified)
        val attrs = Files.readAttributes(verified.file.toPath(), BasicFileAttributes::class.java)
        // Model the old Android backport: changed bytes can retain every field
        // exposed by its path-based file key and timestamp metadata.
        assertEquals(before, GameResourceFileIdentity(
            attrs.fileKey()?.toString(), attrs.size(), attrs.lastModifiedTime(), attrs.creationTime(),
        ))

        assertNull(store.markVerifiedValidated(key, verified, emptyMap(), store.generation()))
        assertFalse(store.contains(key))
    }

    @Test
    fun `file commit hashes the prepared copy when caller source changes`() {
        val root = temporaryFolder.newFolder("copy-integrity")
        val source = temporaryFolder.newFile("mutable-source.part").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        var changed = false
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 100,
            fileChecksum = { file ->
                val hash = MessageDigest.getInstance("SHA-256").digest(file.readBytes()).joinToString("") { "%02x".format(it) }
                if (!changed) { changed = true; source.writeBytes(byteArrayOf(4, 5, 6)) }
                hash
            })
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commitFileWithEviction(key, source, mimeType = "image/png")
        assertArrayEquals(byteArrayOf(1, 2, 3), store.read(key)?.bytes)
    }

    @Test
    fun `startup and index migration defer orphan cleanup until maintenance`() {
        val root = temporaryFolder.newFolder("deferred-cleanup")
        root.resolve("tmp").mkdirs()
        val orphan = root.resolve("tmp/orphan.part").apply { writeBytes(byteArrayOf(9)) }
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 100)
        assertTrue(orphan.exists())
        store.removeLegacyHostlessEntries()
        assertTrue(orphan.exists())
        store.enforcePolicy()
        assertFalse(orphan.exists())
    }

    @Test
    fun `orphan maintenance yields at budget and resumes from its cursor`() {
        val root = temporaryFolder.newFolder("orphan-budget")
        var tick = 0L
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 100,
            maintenanceNowNanos = { tick.also { tick += TimeUnit.MILLISECONDS.toNanos(100) } })
        val orphans = (0..3).map { root.resolve("files/$it.cache").apply { writeBytes(byteArrayOf(9)) } }
        val temporary = root.resolve("tmp/orphan.part").apply { writeBytes(byteArrayOf(9)) }
        store.enforcePolicy(250)
        assertEquals(3, orphans.count { it.exists() })
        assertTrue(temporary.exists())
        store.enforcePolicy(250)
        assertEquals(2, orphans.count { it.exists() })
        store.enforcePolicy()
        assertTrue(orphans.none { it.exists() })
        assertFalse(temporary.exists())
    }

    @Test
    fun `periodic commit maintenance also yields instead of draining orphan cleanup`() {
        val root = temporaryFolder.newFolder("commit-maintenance-budget")
        var tick = 0L
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000,
            clock = { 1L }, policyProvider = { GameResourceCachePolicy(10_000, maxIdleAgeMs = 1000) },
            maintenanceNowNanos = { tick.also { tick += TimeUnit.MILLISECONDS.toNanos(100) } })
        repeat(255) { store.commit(GameResourceCacheKey("/kcs2/resources/$it.png"), byteArrayOf(1), mimeType = "image/png") }
        val orphans = (0..3).map { root.resolve("files/orphan-$it.cache").apply { writeBytes(byteArrayOf(9)) } }
        store.commit(GameResourceCacheKey("/kcs2/resources/256.png"), byteArrayOf(1), mimeType = "image/png")
        assertTrue("periodic commit swept past its maintenance budget", orphans.count { it.exists() } >= 3)
        assertEquals(256, store.entries().size)
        store.enforcePolicy()
        assertTrue(orphans.none { it.exists() })
        assertEquals(256, store.entries().size)
    }

    @Test
    fun `maintenance can yield between expired entries without weakening explicit sweep`() {
        var now = 1L
        val root = temporaryFolder.newFolder("maintenance-budget")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 100,
            clock = { now }, policyProvider = { GameResourceCachePolicy(100, maxIdleAgeMs = 10) })
        repeat(4) { store.commit(GameResourceCacheKey("/kcs2/resources/$it.png"), byteArrayOf(it.toByte()), mimeType = "image/png") }
        now = 20
        store.enforcePolicy(maxDurationMs = 0)
        assertEquals(4, store.entries().size)
        store.enforcePolicy()
        assertTrue(store.entries().isEmpty())
    }

    @Test
    fun `default capacity is fifty decimal gigabytes`() {
        assertEquals(50_000_000_000L, GameResourceCacheStore.DEFAULT_MAX_BYTES)
    }

    @Test
    fun `metadata budget evicts old resource without growing the index`() {
        val root = temporaryFolder.newFolder("metadata-budget")
        val index = GameResourceCacheIndex(root.resolve("index.json"), maxMetadataBytes = 1_024)
        val store = GameResourceCacheStore(root, index, 10_000)
        val first = GameResourceCacheKey("/kcs2/resources/first.png")
        val second = GameResourceCacheKey("/kcs2/resources/second.png")
        val headers = mapOf("Content-Security-Policy" to "x".repeat(400))

        store.commit(first, byteArrayOf(1), mimeType = "image/png", responseHeaders = headers)
        store.commit(second, byteArrayOf(2), mimeType = "image/png", responseHeaders = headers)

        assertFalse(store.contains(first))
        assertTrue(store.contains(second))
        assertEquals(1, store.entries().size)
    }

    @Test
    fun `clear rejects a write started before clear`() {
        val root = temporaryFolder.newFolder("clear-generation")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10)
        val generation = store.generation()
        store.clear()

        assertNull(store.commitWithEviction(
            GameResourceCacheKey("/kcs2/resources/a.png"),
            byteArrayOf(1),
            mimeType = "image/png",
            expectedGeneration = generation,
        ))
        assertEquals(0, store.totalBytes())
    }

    @Test
    fun `clear reports undeleted files instead of claiming success`() {
        val root = temporaryFolder.newFolder("clear-failure")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10)
        val blocked = root.resolve("files/blocked")
        assertTrue(blocked.mkdir())
        blocked.resolve("child").writeText("busy")

        assertTrue(runCatching { store.clear() }.isFailure)
        assertTrue(blocked.isDirectory)
        blocked.resolve("child").delete()
        blocked.delete()
        store.clear()
        assertTrue(root.resolve("files").listFiles().orEmpty().isEmpty())
    }

    @Test
    fun `failed eviction keeps index entry until physical removal succeeds`() {
        val root = temporaryFolder.newFolder("eviction-failure")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10)
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        val entry = store.commit(key, byteArrayOf(1), mimeType = "image/png")
        val file = root.resolve("files/${entry.fileName}")
        assertTrue(file.delete())
        assertTrue(file.mkdir())
        file.resolve("child").writeText("nonempty")

        assertTrue(runCatching { store.remove(key) }.isFailure)
        assertEquals(1L, store.totalBytes())
        assertEquals(1, store.entries().size)
        assertTrue(runCatching {
            store.commitWithEviction(GameResourceCacheKey("/kcs2/resources/new.png"),
                ByteArray(10) { 2 }, mimeType = "image/png")
        }.isFailure)
        assertTrue(root.resolve("tmp").listFiles().orEmpty().isEmpty())

        file.resolve("child").delete()
        file.delete()
        assertTrue(store.remove(key))
        assertEquals(0L, store.totalBytes())
    }

    @Test
    fun `journal write failure removes new unindexed file and temporary part`() {
        val root = temporaryFolder.newFolder("index-write-failure")
        val journal = root.resolve("index.json.journal")
        assertTrue(journal.mkdir())
        journal.resolve("block").writeText("nonempty")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10)

        assertTrue(runCatching {
            store.commitWithEviction(GameResourceCacheKey("/kcs2/resources/a.png"),
                byteArrayOf(1), mimeType = "image/png")
        }.isFailure)

        assertTrue(root.resolve("tmp").listFiles().orEmpty().isEmpty())
        assertTrue(root.resolve("files").listFiles().orEmpty().isEmpty())
        assertEquals(0L, store.totalBytes())
    }

    @Test
    fun `ten thousand entries shrink under a temporary policy within a bounded time`() {
        val root = temporaryFolder.newFolder("large-shrink")
        val entries = JSONArray()
        repeat(10_000) { number ->
            entries.put(JSONObject()
                .put("key", "https://w17k.kancolle-server.com/kcs2/resources/$number.png")
                .put("fileName", "shared.cache")
                .put("version", JSONObject.NULL)
                .put("mimeType", "image/png")
                .put("byteLength", 1)
                .put("etag", JSONObject.NULL)
                .put("lastModified", JSONObject.NULL)
                .put("lastAccessedAt", number)
                .put("lastValidatedAt", number)
                .put("sha256", "hash"))
        }
        root.resolve("index.json").writeText(JSONObject().put("entries", entries).toString())
        var capacity = 10_000L
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")),
            policyProvider = { GameResourceCachePolicy(capacity) })
        assertEquals(10_000L, store.totalBytes())
        capacity = 0L

        val started = System.nanoTime()
        store.enforcePolicy()

        assertEquals(0L, store.totalBytes())
        assertTrue("large mode shrink exceeded 30 seconds",
            TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started) < 30_000)
    }

    @Test
    fun `temporary policy expires entries after seven idle days`() {
        var now = 1L
        val root = temporaryFolder.newFolder("expiry")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            clock = { now },
            policyProvider = {
                GameResourceCachePolicy(
                    maxBytes = 10,
                    maxIdleAgeMs = GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS,
                )
            },
        )
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commit(key, byteArrayOf(1), mimeType = "image/png")

        now += GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS

        assertNull(store.read(key))
        assertFalse(store.contains(key))
    }

    @Test
    fun `enforce policy shrinks cache by least recent access`() {
        var now = 1L
        var policy = GameResourceCachePolicy(maxBytes = 10)
        val root = temporaryFolder.newFolder("shrink")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            clock = { now++ },
            policyProvider = { policy },
        )
        val oldest = GameResourceCacheKey("/kcs2/resources/old.png")
        val newest = GameResourceCacheKey("/kcs2/resources/new.png")
        store.commit(oldest, byteArrayOf(1, 2, 3, 4), mimeType = "image/png")
        store.commit(newest, byteArrayOf(5, 6, 7, 8), mimeType = "image/png")

        policy = GameResourceCachePolicy(maxBytes = 4)
        store.enforcePolicy()

        assertFalse(store.contains(oldest))
        assertTrue(store.contains(newest))
        assertEquals(4L, store.totalBytes())
    }

    @Test
    fun `full policy keeps old entries`() {
        var now = 1L
        val root = temporaryFolder.newFolder("persistent")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            clock = { now },
            policyProvider = { GameResourceCachePolicy(maxBytes = 10) },
        )
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commit(key, byteArrayOf(1), mimeType = "image/png")

        now += GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS * 2

        assertArrayEquals(byteArrayOf(1), store.read(key)?.bytes)
    }

    @Test
    fun `atomic commit survives index reload`() {
        val root = temporaryFolder.newFolder("cache")
        val key = GameResourceCacheKey("/kcs2/resources/a.png?version=21")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            maxBytes = 10_000,
        )

        store.commit(key, byteArrayOf(1, 2, 3), version = "21", mimeType = "image/png")

        val reloaded = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            maxBytes = 10_000,
        )
        assertArrayEquals(byteArrayOf(1, 2, 3), reloaded.read(key)?.bytes)
    }

    @Test
    fun `temporary and corrupted files are never cache hits`() {
        val root = temporaryFolder.newFolder("cache")
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
        root.resolve("tmp").mkdirs()
        root.resolve("tmp/orphan.part").writeBytes(byteArrayOf(9))
        assertNull(store.read(key))

        val entry = store.commit(key, byteArrayOf(1, 2, 3), mimeType = "image/png")
        root.resolve("files/${entry.fileName}").writeBytes(byteArrayOf(1))

        assertNull(store.read(key))
        assertFalse(store.contains(key))
    }

    @Test
    fun `metadata inspection avoids checksumming until explicit integrity check`() {
        val root = temporaryFolder.newFolder("cache")
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
        val entry = store.commit(key, byteArrayOf(1, 2, 3), mimeType = "image/png")
        root.resolve("files/${entry.fileName}").writeBytes(byteArrayOf(4, 5, 6))

        assertEquals(GameResourceStoredState.VALID, store.inspectMetadata(key).state)
        assertEquals(GameResourceStoredState.DAMAGED, store.inspect(key).state)
    }

    @Test
    fun `eviction removes least recently used unprotected files`() {
        var now = 1L
        val root = temporaryFolder.newFolder("cache")
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            maxBytes = 6,
            clock = { now++ },
        )
        val oldest = GameResourceCacheKey("/kcs2/resources/old.png")
        val protected = GameResourceCacheKey("/kcs2/resources/protected.png")
        store.commit(oldest, byteArrayOf(1, 2, 3), mimeType = "image/png")
        store.commit(protected, byteArrayOf(4, 5, 6), mimeType = "image/png")

        val removed = store.evictToFit(requiredBytes = 3, protectedKeys = setOf(protected))

        assertEquals(listOf(oldest), removed)
        assertNull(store.read(oldest))
        assertTrue(store.contains(protected))
        assertFalse(store.wouldExceedCapacity(3))
    }

    @Test
    fun `eviction applies independently of cache profile`() {
        val root = temporaryFolder.newFolder("cache")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 5)
        val key = GameResourceCacheKey("/kcs2/resources/a.png")
        store.commit(key, byteArrayOf(1, 2, 3), mimeType = "image/png")

        assertEquals(listOf(key), store.evictToFit(3))
        assertFalse(store.contains(key))
        assertFalse(store.wouldExceedCapacity(3))
    }

    @Test
    fun `concurrent commits cannot exceed hard capacity`() {
        val root = temporaryFolder.newFolder("cache")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 3)
        val ready = CountDownLatch(2)
        val release = CountDownLatch(1)
        val pool = Executors.newFixedThreadPool(2)
        val futures = (1..2).map { id ->
            pool.submit {
                ready.countDown()
                release.await(5, TimeUnit.SECONDS)
                store.commitWithEviction(
                    GameResourceCacheKey("/kcs2/resources/$id.png"),
                    byteArrayOf(id.toByte(), id.toByte()),
                    mimeType = "image/png",
                )
            }
        }
        assertTrue(ready.await(5, TimeUnit.SECONDS))

        release.countDown()
        futures.forEach { it.get(5, TimeUnit.SECONDS) }

        assertTrue(store.totalBytes() <= 3)
        assertEquals(1, store.entries().size)
        pool.shutdownNow()
    }

    @Test
    fun `resource larger than per file limit is not cached`() {
        val root = temporaryFolder.newFolder("cache")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")))
        val oversized = ByteArray((HttpUrlConnectionGameResourceFetcher.MAX_RESOURCE_BYTES + 1).toInt())

        assertNull(store.commitWithEviction(
            GameResourceCacheKey("/kcs2/resources/large.mp4"), oversized, mimeType = "video/mp4",
        ))
        assertTrue(store.entries().isEmpty())
        assertTrue(root.resolve("files").listFiles().orEmpty().isEmpty())
    }
}
