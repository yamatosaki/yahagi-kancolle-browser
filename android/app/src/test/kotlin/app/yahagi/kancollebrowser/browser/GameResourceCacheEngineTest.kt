package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

class GameResourceCacheEngineTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `same key queue wait consumes the request budget`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = AtomicInteger()
        val fetcher = object : GameResourceFetcher {
            override fun budgetMillis(url: String) = 80L
            override fun fetch(url: String, requestHeaders: Map<String, String>, cached: GameResourceCacheEntry?): GameResourceFetchResult? {
                calls.incrementAndGet()
                entered.countDown()
                release.await(2, TimeUnit.SECONDS)
                return result(byteArrayOf(1))
            }
        }
        val engine = engine(fetcher)
        val url = official("/kcs2/version.json")
        val executor = Executors.newFixedThreadPool(2)
        try {
            val first = executor.submit<GameResourceResponse?> { engine.fetch(url) }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val queued = executor.submit<GameResourceResponse?> { engine.fetch(url) }
            assertNull(queued.get(300, TimeUnit.MILLISECONDS))
            assertEquals(1, calls.get())
            release.countDown()
            first.get(2, TimeUnit.SECONDS)
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun `download slot queue wait consumes the request budget`() {
        val entered = CountDownLatch(2)
        val release = CountDownLatch(1)
        val fetcher = object : GameResourceFetcher {
            override fun budgetMillis(url: String) = 80L
            override fun fetch(url: String, requestHeaders: Map<String, String>, cached: GameResourceCacheEntry?): GameResourceFetchResult? {
                entered.countDown()
                release.await(2, TimeUnit.SECONDS)
                return result(byteArrayOf(1))
            }
        }
        val engine = engine(fetcher)
        val urls = (0..100).map { official("/kcs2/resources/$it.png?v=1") }
            .distinctBy { (checkNotNull(GameResourceCacheKey.from(it)).hashCode() and Int.MAX_VALUE) % 64 }.take(3)
        val executor = Executors.newFixedThreadPool(3)
        try {
            val active = urls.take(2).map { url -> executor.submit<GameResourceResponse?> { engine.fetch(url) } }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val queued = executor.submit<GameResourceResponse?> { engine.fetch(urls.last(), waitForSlot = true) }
            assertNull(queued.get(300, TimeUnit.MILLISECONDS))
            release.countDown()
            active.forEach { it.get(2, TimeUnit.SECONDS) }
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun `queue time reduces the deadline passed to the fetcher`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val started = CountDownLatch(1)
        val remaining = java.util.Collections.synchronizedList(mutableListOf<Long>())
        val calls = AtomicInteger()
        val fetcher = object : GameResourceFetcher {
            override fun budgetMillis(url: String) = 200L
            override fun fetch(url: String, requestHeaders: Map<String, String>, cached: GameResourceCacheEntry?): GameResourceFetchResult? {
                if (calls.incrementAndGet() == 1) {
                    entered.countDown()
                    release.await(2, TimeUnit.SECONDS)
                }
                return result(byteArrayOf(1))
            }
            override fun fetchWithinDeadline(url: String, requestHeaders: Map<String, String>, cached: GameResourceCacheEntry?, deadlineNanos: Long): GameResourceFetchResult? {
                remaining += TimeUnit.NANOSECONDS.toMillis(deadlineNanos - System.nanoTime())
                return fetch(url, requestHeaders, cached)
            }
        }
        val engine = engine(fetcher)
        val url = official("/kcs2/version.json")
        val executor = Executors.newFixedThreadPool(2)
        try {
            val first = executor.submit<GameResourceResponse?> { engine.fetch(url) }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val queued = executor.submit<GameResourceResponse?> { started.countDown(); engine.fetch(url) }
            assertTrue(started.await(2, TimeUnit.SECONDS))
            Thread.sleep(80)
            release.countDown()
            first.get(2, TimeUnit.SECONDS)
            queued.get(2, TimeUnit.SECONDS)
            assertEquals(2, remaining.size)
            assertTrue("queue time reset the network budget: ${remaining.last()}", remaining.last() in 1..160)
        } finally {
            release.countDown()
            executor.shutdownNow()
        }
    }

    @Test
    fun `304 reuses checksum only with reliable file identity at resource sizes`() {
        for (megabytes in listOf(1, 4, 16)) {
            val root = temporaryFolder.newFolder("hash-$megabytes")
            val hashes = AtomicInteger()
            val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")),
                64L * 1024 * 1024, fileChecksum = { file ->
                    hashes.incrementAndGet()
                    MessageDigest.getInstance("SHA-256").digest(file.readBytes()).joinToString("") { "%02x".format(it) }
                })
            val url = official("/kcs2/version.json")
            val bytes = ByteArray(megabytes * 1024 * 1024) { 7 }
            val entry = store.commit(checkNotNull(GameResourceCacheKey.from(url)), bytes, mimeType = "application/json")
            val attributes = java.nio.file.Files.readAttributes(
                root.resolve("files/${entry.fileName}").toPath(),
                java.nio.file.attribute.BasicFileAttributes::class.java,
            )
            // Windows returns no file key, so safely rehash after the 304.
            // Filesystems with stable identity still hash only once per fetch.
            val expectedHashes = if (attributes.fileKey() != null) 1 else 2
            hashes.set(0)
            val engine = GameResourceCacheEngine(store, QueueFetcher(result(ByteArray(0), 304))) { GameResourceCacheMode.TEMPORARY }
            assertArrayEquals(bytes, engine.fetch(url)?.bytes)
            assertEquals("$megabytes MiB", expectedHashes, hashes.get())
        }
    }

    @Test
    fun `304 rejects same-length corruption during validation`() {
        val root = temporaryFolder.newFolder("304-corruption")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
        val url = official("/kcs2/version.json")
        val key = checkNotNull(GameResourceCacheKey.from(url))
        val entry = store.commit(key, byteArrayOf(1, 2, 3), mimeType = "application/json")
        val fetcher = GameResourceFetcher { _, _, _ ->
            val file = root.resolve("files/${entry.fileName}")
            file.writeBytes(byteArrayOf(4, 5, 6))
            java.nio.file.Files.setLastModifiedTime(file.toPath(), java.nio.file.attribute.FileTime.fromMillis(file.lastModified() + 1000))
            result(ByteArray(0), 304)
        }
        val engine = GameResourceCacheEngine(store, fetcher) { GameResourceCacheMode.TEMPORARY }
        assertNull(engine.fetch(url))
        assertFalse(store.contains(key))
    }

    @Test
    fun `304 cannot resurrect cleared or replaced cached entry`() {
        for (clear in listOf(true, false)) {
            val root = temporaryFolder.newFolder("304-change-$clear")
            val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
            val url = official("/kcs2/version.json")
            val key = checkNotNull(GameResourceCacheKey.from(url))
            store.commit(key, byteArrayOf(1, 2, 3), mimeType = "application/json")
            val fetcher = GameResourceFetcher { _, _, _ ->
                if (clear) store.clear() else store.commit(key, byteArrayOf(4, 5, 6), mimeType = "application/json")
                result(ByteArray(0), 304)
            }
            val engine = GameResourceCacheEngine(store, fetcher) { GameResourceCacheMode.TEMPORARY }
            assertNull(engine.fetch(url))
            if (!clear) assertArrayEquals(byteArrayOf(4, 5, 6), store.read(key)?.bytes)
        }
    }

    @Test
    fun `committed network response keeps its verified download until the response closes`() {
        val file = temporaryFolder.newFile("network.part").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        val fetched = result(byteArrayOf(1, 2, 3)).copy(bytes = ByteArray(0), file = file)
        val engine = engine(QueueFetcher(fetched))
        val response = checkNotNull(engine.fetch(official("/kcs2/resources/a.png?version=1")))
        assertTrue(file.isFile)
        response.openStream().use { assertArrayEquals(byteArrayOf(1, 2, 3), it.readBytes()) }
        assertFalse(file.exists())
        assertTrue(engine.hasCached(official("/kcs2/resources/a.png?version=1")))
    }

    @Test
    fun `legacy and missing modes migrate to supported profiles`() {
        assertEquals(GameResourceCacheMode.TEMPORARY, GameResourceCacheMode.fromWireName(null))
        assertEquals(GameResourceCacheMode.NONE, GameResourceCacheMode.fromWireName("none"))
        assertEquals(GameResourceCacheMode.TEMPORARY, GameResourceCacheMode.fromWireName("unknown"))
        assertEquals(GameResourceCacheMode.FULL, GameResourceCacheMode.fromWireName("light"))
    }

    @Test
    fun `second exact request is served from disk`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1, 2, 3)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png?version=21")

        val first = engine.fetch(url)
        val second = engine.fetch(url)

        assertArrayEquals(first?.bytes, second?.bytes)
        assertEquals(1, fetcher.calls.get())
        assertEquals(GameResourceResponseSource.NETWORK, first?.source)
        assertEquals(GameResourceResponseSource.CACHE, second?.source)
    }

    @Test
    fun `non GET request never enters resource cache`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher)
        assertNull(engine.fetch(official("/kcs2/resources/a.png"), method = "POST"))
        assertEquals(0, fetcher.calls.get())
    }

    @Test
    fun `range and conditional requests stay on the WebView network path`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.mp4")
        assertNull(engine.fetch(url, mapOf("Range" to "bytes=1-")))
        assertNull(engine.fetch(url, mapOf("If-None-Match" to "abc")))
        assertNull(engine.fetch(url, mapOf("Authorization" to "Bearer secret")))
        assertEquals(0, fetcher.calls.get())
    }

    @Test
    fun `request cache directives are handled by WebView instead of native cache`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png")
        assertNull(engine.fetch(url, mapOf("Cache-Control" to "no-store")))
        assertNull(engine.fetch(url, mapOf("Cache-Control" to "only-if-cached")))
        assertEquals(0, fetcher.calls.get())
        assertTrue(engine.entries().isEmpty())
    }

    @Test
    fun `oversized request header bypasses native cache before directive parsing`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png")

        assertNull(engine.fetch(url, mapOf("Cache-Control" to "max-age=1,".repeat(10_000))))
        assertEquals(0, fetcher.calls.get())
    }

    @Test
    fun `reload directive reuses cached static binary without network`() {
        val initial = result(byteArrayOf(7)).copy(headers = mapOf(
            "Content-Type" to "image/png", "ETag" to "asset-7",
        ))
        val fetcher = QueueFetcher(initial)
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png?version=7")

        assertEquals(GameResourceResponseSource.NETWORK, engine.fetch(url)?.source)
        val reloaded = engine.fetch(url, mapOf("Cache-Control" to "no-cache"))

        assertEquals(GameResourceResponseSource.CACHE, reloaded?.source)
        assertArrayEquals(byteArrayOf(7), reloaded?.bytes)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `pragma and zero max age also reuse cached static binary`() {
        val fetcher = QueueFetcher(result(byteArrayOf(7)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png?version=7")

        engine.fetch(url)
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Pragma" to "no-cache"))?.source)
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Cache-Control" to "max-age=0"))?.source)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `reload directive reuses a cached script as in beta2`() {
        val fetcher = QueueFetcher(result(byteArrayOf(7)))
        val engine = engine(fetcher)
        val url = official("/kcs2/js/feature.js?version=7")

        engine.fetch(url)
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Cache-Control" to "no-cache"))?.source)
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Pragma" to "no-cache"))?.source)
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Cache-Control" to "max-age=0"))?.source)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `unversioned static binary still revalidates after its ttl`() {
        var now = 1L
        val fetcher = QueueFetcher(result(byteArrayOf(7)), result(byteArrayOf(), statusCode = 304))
        val engine = engine(fetcher, clock = { now })
        val url = official("/kcs2/resources/a.png")

        engine.fetch(url)
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Cache-Control" to "no-cache"))?.source)
        assertEquals(1, fetcher.calls.get())

        now += GameResourceCacheEngine.UNVERSIONED_TTL_MS
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Cache-Control" to "no-cache"))?.source)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `temporary and full cache keep sortie assets through a frame reload`() {
        for (mode in listOf(GameResourceCacheMode.TEMPORARY, GameResourceCacheMode.FULL)) {
            val fetcher = QueueFetcher(
                result(byteArrayOf(1)),
                result(byteArrayOf(2)),
                result(byteArrayOf(3)),
                result(byteArrayOf(), statusCode = 304),
            )
            val engine = engine(fetcher, mode = mode)
            val bootstrap = official("/kcs2/version.json")
            val shipImage = official("/kcs2/resources/ship/full/123.png?version=5")
            val battleVoice = official("/kcs2/resources/voice/battle/123.mp3")

            engine.fetch(bootstrap)
            engine.fetch(shipImage)
            engine.fetch(battleVoice)
            val entriesBeforeReload = engine.entries().size

            assertEquals(mode.name, GameResourceResponseSource.CACHE,
                engine.fetch(bootstrap, mapOf("Cache-Control" to "no-cache"))?.source)
            assertEquals(mode.name, GameResourceResponseSource.CACHE,
                engine.fetch(shipImage, mapOf("Cache-Control" to "no-cache"))?.source)
            assertEquals(mode.name, GameResourceResponseSource.CACHE, engine.fetch(battleVoice)?.source)
            assertEquals(mode.name, entriesBeforeReload, engine.entries().size)
            assertEquals(mode.name, 4, fetcher.calls.get())
        }
    }

    @Test
    fun `no cache response is reused without forced validation as in beta2`() {
        val initial = result(byteArrayOf(9)).copy(headers = mapOf(
            "Content-Type" to "image/png", "Cache-Control" to "no-cache", "ETag" to "asset-9",
        ))
        val fetcher = QueueFetcher(initial)
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png?version=9")

        assertEquals(GameResourceResponseSource.NETWORK, engine.fetch(url)?.source)
        assertEquals(GameResourceResponseSource.CACHE, engine.fetch(url)?.source)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `reload header does not force a script network request`() {
        val fetcher = QueueFetcher(result(byteArrayOf(7)), null)
        val engine = engine(fetcher)
        val url = official("/kcs2/js/feature.js?version=7")

        assertEquals(GameResourceResponseSource.NETWORK, engine.fetch(url)?.source)
        assertEquals(GameResourceResponseSource.CACHE,
            engine.fetch(url, mapOf("Cache-Control" to "no-cache"))?.source)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `same path on different official servers has separate cache entries`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)), result(byteArrayOf(2)))
        val engine = engine(fetcher)
        val path = "/kcs2/resources/a.png?version=1"
        assertArrayEquals(byteArrayOf(1), engine.fetch("https://w01k.kancolle-server.com$path")?.bytes)
        assertArrayEquals(byteArrayOf(2), engine.fetch("https://w02k.kancolle-server.com$path")?.bytes)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `hostless legacy entries are removed when engine starts`() {
        val root = temporaryFolder.newFolder()
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
        store.commit(GameResourceCacheKey("/kcs2/resources/a.png"), byteArrayOf(1), mimeType = "image/png")

        val engine = GameResourceCacheEngine(store, QueueFetcher()) { GameResourceCacheMode.TEMPORARY }

        assertTrue(engine.entries().isEmpty())
        assertEquals(0, store.totalBytes())
    }

    @Test
    fun `oversized beta4 cache is reset without clearing other app data`() {
        val appRoot = temporaryFolder.newFolder()
        val settings = appRoot.resolve("settings.json")
        settings.writeText("keep")
        val cacheRoot = appRoot.resolve("game_resource_cache").apply { mkdirs() }
        val indexFile = cacheRoot.resolve("index.json")
        indexFile.bufferedWriter().use { writer ->
            writer.write("{\"entries\":[\"")
            repeat(8_193) { writer.write("x".repeat(1_024)) }
            writer.write("\"]}")
        }
        val cachedFile = cacheRoot.resolve("files/old.cache")
        cachedFile.parentFile?.mkdirs()
        cachedFile.writeBytes(byteArrayOf(1))
        val store = GameResourceCacheStore(cacheRoot, GameResourceCacheIndex(indexFile), 10_000)
        val engine = GameResourceCacheEngine(store, QueueFetcher()) { GameResourceCacheMode.TEMPORARY }

        assertTrue(engine.entries().isEmpty())
        engine.enforcePolicy()
        assertFalse(cachedFile.exists())
        assertEquals("keep", settings.readText())
    }

    @Test
    fun `ten thousand hostless keys migrate in one background batch`() {
        val root = temporaryFolder.newFolder()
        val entries = JSONArray()
        repeat(10_000) { number ->
            entries.put(JSONObject()
                .put("key", "/kcs2/resources/$number.png")
                .put("fileName", "shared.cache")
                .put("version", JSONObject.NULL)
                .put("mimeType", "image/png")
                .put("byteLength", 1)
                .put("etag", JSONObject.NULL)
                .put("lastModified", JSONObject.NULL)
                .put("lastAccessedAt", 1)
                .put("lastValidatedAt", 1)
                .put("sha256", "hash"))
        }
        root.resolve("index.json").writeText(JSONObject().put("entries", entries).toString())
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), 10_000)
        val constructedAt = System.nanoTime()
        val engine = GameResourceCacheEngine(store, QueueFetcher()) { GameResourceCacheMode.TEMPORARY }
        assertTrue("engine construction loaded the index on the caller thread",
            TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - constructedAt) < 2_000)

        val migrationStarted = System.nanoTime()
        assertTrue(engine.entries().isEmpty())
        assertTrue("batch migration exceeded 20 seconds",
            TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - migrationStarted) < 20_000)
        assertTrue(GameResourceCacheIndex(root.resolve("index.json")).snapshot().isEmpty())
    }

    @Test
    fun `interrupted legacy cleanup removes orphan after restart`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(indexFile), 10_000)
        store.commit(GameResourceCacheKey("/kcs2/resources/old.png"), byteArrayOf(1), mimeType = "image/png")
        val cachedFile = root.resolve("files").listFiles()!!.single()
        assertTrue(cachedFile.isFile)
        indexFile.resolveSibling("index.json.journal").appendText(
            JSONObject().put("op", "removePrefix").put("prefix", "/").toString() + "\n",
        )

        val restarted = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(indexFile), 10_000),
            QueueFetcher(),
        ) { GameResourceCacheMode.TEMPORARY }

        assertTrue(restarted.entries().isEmpty())
        restarted.enforcePolicy()
        assertTrue(root.resolve("files").listFiles().orEmpty().isEmpty())
    }

    @Test
    fun `interrupted clear removes orphan after restart`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(indexFile), 10_000)
        store.commit(GameResourceCacheKey.from(official("/kcs2/resources/a.png"))!!,
            byteArrayOf(1), mimeType = "image/png")
        assertTrue(root.resolve("files").listFiles().orEmpty().isNotEmpty())
        indexFile.resolveSibling("index.json.journal").appendText(
            JSONObject().put("op", "clear").toString() + "\n",
        )

        val restarted = GameResourceCacheEngine(
            GameResourceCacheStore(root, GameResourceCacheIndex(indexFile), 10_000),
            QueueFetcher(),
        ) { GameResourceCacheMode.TEMPORARY }

        assertTrue(restarted.entries().isEmpty())
        restarted.enforcePolicy()
        assertTrue(root.resolve("files").listFiles().orEmpty().isEmpty())
    }

    @Test
    fun `cookie variants never share cached response`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)), result(byteArrayOf(2)))
        val engine = engine(fetcher)
        val url = official("/gadget_html5/js/a.js?version=1")
        assertArrayEquals(byteArrayOf(1), engine.fetch(url, mapOf("Cookie" to "account=A"))?.bytes)
        assertArrayEquals(byteArrayOf(2), engine.fetch(url, mapOf("Cookie" to "account=B"))?.bytes)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `resource data remains isolated between accounts`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)), result(byteArrayOf(2)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/account.json?version=1")

        assertArrayEquals(byteArrayOf(1), engine.fetch(url, mapOf("Cookie" to "account=A"))?.bytes)
        assertArrayEquals(byteArrayOf(2), engine.fetch(url, mapOf("Cookie" to "account=B"))?.bytes)
        assertArrayEquals(byteArrayOf(1), engine.fetch(url, mapOf("Cookie" to "account=A"))?.bytes)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `oversized cookie falls back to WebView without a cache download`() {
        val fetcher = QueueFetcher()
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/account.json")

        assertNull(engine.fetch(url, mapOf("Cookie" to "x".repeat(100_000))))
        assertEquals(0, fetcher.calls.get())
    }

    @Test
    fun `no store response is served once without caching and partial response is delegated`() {
        val fetcher = QueueFetcher(
            result(byteArrayOf(1)).copy(headers = mapOf("Cache-Control" to "private, no-store")),
            result(byteArrayOf(2), statusCode = 206),
        )
        val engine = engine(fetcher)
        val first = official("/kcs2/resources/private.png")
        val second = official("/kcs2/resources/partial.png")
        assertEquals(GameResourceResponseSource.NETWORK, engine.fetch(first)?.source)
        assertNull(engine.fetch(second))
        assertEquals(GameResourceInspectionState.MISSING, engine.inspectMetadata(first).state)
        assertEquals(GameResourceInspectionState.MISSING, engine.inspectMetadata(second).state)
    }

    @Test
    fun `vary response is served once without entering the shared cache`() {
        val response = result(byteArrayOf(4)).copy(headers = mapOf(
            "Content-Type" to "image/png", "Vary" to "Accept-Encoding",
        ))
        val fetcher = QueueFetcher(response)
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/vary.png")

        assertEquals(GameResourceResponseSource.NETWORK, engine.fetch(url)?.source)
        assertEquals(GameResourceInspectionState.MISSING, engine.inspectMetadata(url).state)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `response setting a cookie remains on WebView path`() {
        val response = result(byteArrayOf(4)).copy(headers = mapOf(
            "Content-Type" to "image/png", "Set-Cookie" to "session=renewed; Path=/",
        ))
        val engine = engine(QueueFetcher(response))
        val url = official("/kcs2/resources/cookie.png")

        assertNull(engine.fetch(url))
        assertEquals(GameResourceInspectionState.MISSING, engine.inspectMetadata(url).state)
    }

    @Test
    fun `cached response retains security and cross origin headers`() {
        val headers = mapOf(
            "Content-Type" to "application/javascript",
            "Content-Length" to "1",
            "Content-Security-Policy" to "default-src 'none'",
            "Access-Control-Allow-Origin" to "https://example.com",
            "Cross-Origin-Resource-Policy" to "same-origin",
        )
        val fetcher = QueueFetcher(result(byteArrayOf(1)).copy(headers = headers))
        val engine = engine(fetcher)
        val url = official("/kcs2/js/script.js?version=1")

        engine.fetch(url)
        val cached = engine.fetch(url)

        assertEquals(GameResourceResponseSource.CACHE, cached?.source)
        assertEquals("default-src 'none'", cached?.headers?.get("Content-Security-Policy"))
        assertEquals("https://example.com", cached?.headers?.get("Access-Control-Allow-Origin"))
        assertEquals("same-origin", cached?.headers?.get("Cross-Origin-Resource-Policy"))
    }

    @Test
    fun `query version change downloads a new asset`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)), result(byteArrayOf(2)))
        val engine = engine(fetcher)

        val first = engine.fetch(official("/kcs2/resources/a.png?version=1"))
        val second = engine.fetch(official("/kcs2/resources/a.png?version=2"))

        assertArrayEquals(byteArrayOf(1), first?.bytes)
        assertArrayEquals(byteArrayOf(2), second?.bytes)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `concurrent requests for one key download once`() {
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val fetcher = object : GameResourceFetcher {
            val calls = AtomicInteger()
            override fun fetch(
                url: String,
                requestHeaders: Map<String, String>,
                cached: GameResourceCacheEntry?,
            ): GameResourceFetchResult {
                calls.incrementAndGet()
                started.countDown()
                release.await(5, TimeUnit.SECONDS)
                return result(byteArrayOf(7))
            }
        }
        val engine = engine(fetcher)
        val pool = Executors.newFixedThreadPool(2)
        val first = pool.submit<GameResourceResponse?> { engine.fetch(official("/kcs2/resources/a.png")) }
        assertTrue(started.await(5, TimeUnit.SECONDS))
        val second = pool.submit<GameResourceResponse?> { engine.fetch(official("/kcs2/resources/a.png")) }
        release.countDown()

        assertArrayEquals(byteArrayOf(7), first.get(5, TimeUnit.SECONDS)?.bytes)
        assertArrayEquals(byteArrayOf(7), second.get(5, TimeUnit.SECONDS)?.bytes)
        assertEquals(1, fetcher.calls.get())
        pool.shutdownNow()
    }

    @Test
    fun `at most two distinct cache misses download concurrently`() {
        val started = CountDownLatch(2)
        val release = CountDownLatch(1)
        val calls = AtomicInteger()
        val fetcher = GameResourceFetcher { _, _, _ ->
            calls.incrementAndGet()
            started.countDown()
            release.await(5, TimeUnit.SECONDS)
            result(byteArrayOf(7))
        }
        val engine = engine(fetcher)
        val pool = Executors.newFixedThreadPool(2)
        try {
            val first = pool.submit<GameResourceResponse?> { engine.fetch(official("/kcs2/resources/a.png")) }
            val second = pool.submit<GameResourceResponse?> { engine.fetch(official("/kcs2/resources/b.png")) }
            assertTrue(started.await(5, TimeUnit.SECONDS))

            assertNull(engine.fetch(official("/kcs2/resources/c.png")))
            assertEquals(2, calls.get())
            release.countDown()
            assertEquals(1, first.get(5, TimeUnit.SECONDS)?.bytes?.size)
            assertEquals(1, second.get(5, TimeUnit.SECONDS)?.bytes?.size)
        } finally {
            release.countDown()
            pool.shutdownNow()
        }
    }

    @Test
    fun `downloaded file is served and cached without a body array`() {
        val downloaded = temporaryFolder.newFile("download.part")
        downloaded.writeBytes(byteArrayOf(1, 2, 3))
        val fetcher = QueueFetcher(GameResourceFetchResult(
            200, "OK", mapOf("Content-Length" to "3"), file = downloaded,
        ))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png")

        val network = engine.fetch(url)
        assertArrayEquals(byteArrayOf(1, 2, 3), network?.openStream()?.use { it.readBytes() })
        assertEquals(3L, network?.bodyLength)
        assertArrayEquals(byteArrayOf(1, 2, 3), engine.fetch(url)?.openStream()?.use { it.readBytes() })
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `oversized metadata serves network response without caching`() {
        val fetched = result(byteArrayOf(1)).copy(headers = mapOf(
            "Content-Length" to "1", "ETag" to "x".repeat(20_000),
        ))
        val engine = engine(QueueFetcher(fetched))

        val response = engine.fetch(official("/kcs2/resources/a.png"))

        assertArrayEquals(byteArrayOf(1), response?.bytes)
        assertTrue(engine.entries().isEmpty())
    }

    @Test
    fun `uncached streamed response deletes temporary file when closed`() {
        val downloaded = temporaryFolder.newFile("uncached.part")
        downloaded.writeBytes(byteArrayOf(4, 5))
        val engine = engine(QueueFetcher(GameResourceFetchResult(200, "OK", emptyMap(), file = downloaded)))

        val response = engine.fetch(official("/kcs2/resources/a.png"), shouldStore = { false })
        assertTrue(downloaded.isFile)
        assertArrayEquals(byteArrayOf(4, 5), response?.openStream()?.use { it.readBytes() })
        assertFalse(downloaded.exists())
    }

    @Test
    fun `failed strict revalidation keeps exact cached file`() {
        val fetcher = QueueFetcher(result(byteArrayOf(4)), null)
        val engine = engine(fetcher)
        val url = official("/gadget_html5/js/kcs_const.js?version=8")

        assertArrayEquals(byteArrayOf(4), engine.fetch(url)?.bytes)
        val fallback = engine.fetch(url)

        assertArrayEquals(byteArrayOf(4), fallback?.bytes)
        assertEquals(GameResourceResponseSource.CACHE, fallback?.source)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `none mode bypasses engine without network`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher, mode = GameResourceCacheMode.NONE)

        assertNull(engine.fetch(official("/kcs2/resources/a.png")))
        assertEquals(0, fetcher.calls.get())
    }

    @Test
    fun `OOI request bypasses disk and official asset still warms cache`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1, 2, 3)))
        val engine = engine(fetcher)

        assertNull(engine.fetch("https://ooi.moe/browser"))
        assertEquals(0, fetcher.calls.get())
        assertTrue(engine.entries().isEmpty())

        val official = official("/kcs2/resources/a.png?version=21")
        assertEquals(GameResourceResponseSource.NETWORK, engine.fetch(official)?.source)
        assertEquals(GameResourceResponseSource.CACHE, engine.fetch(official)?.source)
        assertEquals(1, fetcher.calls.get())
        assertEquals(1, engine.entries().size)
    }

    @Test
    fun `unversioned resource revalidates after ttl and keeps 304 cache`() {
        var now = 1L
        val fetcher = QueueFetcher(
            result(byteArrayOf(1)),
            result(byteArrayOf(), statusCode = 304),
        )
        val engine = engine(fetcher, clock = { now })
        val url = official("/kcs2/resources/a.png")

        engine.fetch(url)
        engine.fetch(url)
        assertEquals(1, fetcher.calls.get())

        now += GameResourceCacheEngine.UNVERSIONED_TTL_MS
        val revalidated = engine.fetch(url)

        assertEquals(2, fetcher.calls.get())
        assertEquals(GameResourceResponseSource.CACHE, revalidated?.source)
    }

    @Test
    fun `304 no store response invalidates cached resource and falls back`() {
        val first = result(byteArrayOf(1))
        val revalidation = result(byteArrayOf(), statusCode = 304).copy(
            headers = mapOf("Cache-Control" to "no-store", "Set-Cookie" to "session=B"),
        )
        val engine = engine(QueueFetcher(first, revalidation))
        val url = official("/kcs2/version.json")
        assertArrayEquals(byteArrayOf(1), engine.fetch(url)?.bytes)

        assertNull(engine.fetch(url))
        assertEquals(GameResourceInspectionState.MISSING, engine.inspectMetadata(url).state)
    }

    @Test
    fun `304 response refreshes cached security headers`() {
        val first = result(byteArrayOf(1)).copy(headers = mapOf(
            "Content-Security-Policy" to "default-src 'self'",
        ))
        val revalidation = result(byteArrayOf(), statusCode = 304).copy(headers = mapOf(
            "Content-Security-Policy" to "default-src 'none'",
        ))
        val engine = engine(QueueFetcher(first, revalidation))
        val url = official("/kcs2/version.json")
        engine.fetch(url)

        val cached = engine.fetch(url)
        assertEquals(GameResourceResponseSource.CACHE, cached?.source)
        assertEquals("default-src 'none'", cached?.headers?.get("Content-Security-Policy"))
    }

    @Test
    fun `preloaded static media serves browser request with cookie and user agent`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/area/sally/001.png")
        engine.fetch(url)

        val browser = engine.fetch(url, mapOf("Cookie" to "account=A", "User-Agent" to "WebView"))
        assertEquals(GameResourceResponseSource.CACHE, browser?.source)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `manifest length keeps unversioned resource valid after ttl`() {
        var now = 1L
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher, clock = { now })
        val url = official("/kcs2/resources/a.png")

        engine.fetch(url, expectedLength = 1)
        now += GameResourceCacheEngine.UNVERSIONED_TTL_MS

        assertEquals(
            GameResourceInspectionState.VALID,
            engine.inspectMetadata(url, expectedLength = 1).state,
        )
    }

    @Test
    fun `critical entry does not fall back to stale cache when validation fails`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)), null)
        val engine = engine(fetcher)
        val url = official("/kcs2/version.json")

        assertArrayEquals(byteArrayOf(1), engine.fetch(url)?.bytes)
        assertNull(engine.fetch(url))
        assertEquals(1, engine.entries().size)
    }

    @Test
    fun `manifest length mismatch is returned but never persisted`() {
        val engine = engine(QueueFetcher(result(byteArrayOf(1, 2))))
        val url = official("/kcs2/resources/a.png")

        val response = engine.fetch(url, expectedLength = 3)

        assertArrayEquals(byteArrayOf(1, 2), response?.bytes)
        assertNull(engine.fetch(url, expectedLength = 3, shouldStore = { false }))
        assertEquals(GameResourceInspectionState.MISSING, engine.inspectMetadata(url).state)
    }

    @Test
    fun `changed manifest length bypasses stale cache and stores replacement`() {
        val fetcher = QueueFetcher(
            result(byteArrayOf(1)),
            result(byteArrayOf(2, 3)),
        )
        val engine = engine(fetcher)
        val url = official("/kcs2/resources/a.png")

        engine.fetch(url, expectedLength = 1)
        val replacement = engine.fetch(url, expectedLength = 2)

        assertArrayEquals(byteArrayOf(2, 3), replacement?.bytes)
        assertEquals(GameResourceResponseSource.NETWORK, replacement?.source)
        assertEquals(2, fetcher.calls.get())
        assertEquals(
            GameResourceInspectionState.VALID,
            engine.inspectMetadata(url, expectedLength = 2).state,
        )
    }

    private fun engine(
        fetcher: GameResourceFetcher,
        mode: GameResourceCacheMode = GameResourceCacheMode.TEMPORARY,
        clock: () -> Long = System::currentTimeMillis,
    ): GameResourceCacheEngine {
        val root = temporaryFolder.newFolder()
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            10_000,
            clock,
        )
        return GameResourceCacheEngine(store, fetcher, clock) { mode }
    }

    private fun official(path: String) = "https://w17k.kancolle-server.com$path"

    private fun result(bytes: ByteArray, statusCode: Int = 200) = GameResourceFetchResult(
        statusCode = statusCode,
        reasonPhrase = "OK",
        headers = mapOf("Content-Type" to "image/png", "Content-Length" to bytes.size.toString()),
        bytes = bytes,
    )

    private class QueueFetcher(vararg results: GameResourceFetchResult?) : GameResourceFetcher {
        private val queue = ArrayDeque(results.toList())
        val calls = AtomicInteger()

        override fun fetch(
            url: String,
            requestHeaders: Map<String, String>,
            cached: GameResourceCacheEntry?,
        ): GameResourceFetchResult? {
            calls.incrementAndGet()
            return if (queue.isEmpty()) null else queue.removeFirst()
        }
    }
}
