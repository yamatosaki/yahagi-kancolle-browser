package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.net.InetSocketAddress
import java.net.Proxy
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
    fun `status snapshot counts persisted entries without enforcing idle expiry`() {
        val root = temporaryFolder.newFolder()
        val indexFile = root.resolve("index.json")
        var now = 1L
        fun store() = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(indexFile),
            clock = { now },
            policyProvider = { GameResourceCachePolicy(10_000, maxIdleAgeMs = 100) },
        )
        store().commit(
            GameResourceCacheKey(official("/kcs2/resources/a.png")),
            byteArrayOf(1, 2),
            mimeType = "image/png",
        )
        now = 102L
        val engine = GameResourceCacheEngine(store(), QueueFetcher(), { now }) {
            GameResourceCacheMode.TEMPORARY
        }

        val snapshot = engine.statusSnapshot()
        assertEquals(1, snapshot.fileCount)
        assertEquals(2L, snapshot.usedBytes)
        assertEquals(10_000L, snapshot.maxBytes)
        assertEquals(0, engine.status().fileCount)
        assertEquals(0, engine.statusSnapshot().fileCount)
    }

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
    fun `fresh fetches ignore the warmed cache and leave its original bytes intact`() {
        val stock = byteArrayOf(1, 2, 3)
        val firstFresh = byteArrayOf(4, 5, 6)
        val secondFresh = byteArrayOf(7, 8, 9)
        val responses = ArrayDeque(listOf(stock, firstFresh, secondFresh))
        val requests = mutableListOf<GameResourceCacheEntry?>()
        val engine = engine(GameResourceFetcher { _, _, cached ->
            requests.add(cached)
            responses.removeFirstOrNull()?.let { bytes ->
                val fetched = result(bytes)
                fetched.copy(headers = fetched.headers + ("cache-control" to "public, max-age=3600"))
            }
        })
        val url = official("/kcs2/resources/ship/full/a.png?version=21")

        assertArrayEquals(stock, engine.fetch(url)?.bytes)
        listOf(firstFresh, secondFresh).forEach { expected ->
            val fresh = checkNotNull(engine.fetchFresh(url))
            assertEquals(GameResourceResponseSource.NETWORK, fresh.source)
            assertArrayEquals(expected, fresh.bytes)
            assertEquals(
                listOf("no-store"),
                fresh.headers.filterKeys { it.equals("Cache-Control", ignoreCase = true) }.values.toList(),
            )
        }
        assertNull(engine.fetchFresh(url))

        val cached = checkNotNull(engine.fetch(url))
        assertEquals(GameResourceResponseSource.CACHE, cached.source)
        assertArrayEquals(stock, cached.bytes)
        assertEquals(listOf(null, null, null, null), requests)
    }

    @Test
    fun `fresh fetch rejects range authorization and requests outside the static resource scope`() {
        val fetcher = QueueFetcher(result(byteArrayOf(1)))
        val engine = engine(fetcher, mode = GameResourceCacheMode.NONE)
        val url = official("/kcs2/js/main.js?version=21")

        assertNull(engine.fetchFresh(url, mapOf("rAnGe" to "bytes=1-")))
        assertNull(engine.fetchFresh(url, mapOf("aUtHoRiZaTiOn" to "Bearer sample")))
        assertNull(engine.fetchFresh(url, mapOf("Proxy-Authorization" to "Basic sample")))
        assertNull(engine.fetchFresh(url, method = "POST"))
        assertNull(engine.fetchFresh(official("/kcsapi/api_start2/getData")))
        assertNull(engine.fetchFresh("https://example.test/kcs2/js/main.js"))
        assertEquals(0, fetcher.calls.get())

        assertArrayEquals(byteArrayOf(1), engine.fetchFresh(url)?.bytes)
        assertEquals(1, fetcher.calls.get())
        assertTrue(engine.entries().isEmpty())
    }

    @Test
    fun `Kanxy local resource snapshots persist separately until manually cleared`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val stock = byteArrayOf(1)
        val modified = byteArrayOf(2)
        val refreshed = byteArrayOf(3)
        val fetcher = QueueFetcher(result(stock), kanxyManualImage(modified), kanxyManualImage(refreshed))
        val root = temporaryFolder.newFolder()
        var disk = kanxyDisk(root)
        var session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)

        assertArrayEquals(stock, engine.fetch(url)?.bytes)
        assertArrayEquals(modified, engine.fetchFresh(url)?.bytes)
        assertArrayEquals(stock, engine.fetch(url)?.bytes)

        disk.closeMaintenance()
        disk = kanxyDisk(root)
        session = KanxyHttpImageCache(localProxy)
        val reopened = engine(fetcher, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)
        val observed = mutableListOf<KanxyImageCacheEvent>()
        val hit = reopened.fetchFresh(url, report = { observed.add(it) })
        assertArrayEquals(modified, hit?.bytes)
        assertEquals(GameResourceResponseSource.CACHE, hit?.source)
        assertEquals("no-store", hit?.headers?.get("Cache-Control"))
        assertEquals(listOf(KanxyImageCacheEvent.DISK_HIT), observed)
        assertEquals(2, fetcher.calls.get())

        disk.clear()
        assertArrayEquals(refreshed, reopened.fetchFresh(url)?.bytes)
        assertArrayEquals(refreshed, reopened.fetchFresh(url)?.bytes)
        assertEquals(3, fetcher.calls.get())
    }

    @Test
    fun `Kanxy disk keeps large file backed images and public atlas and sound assets`() {
        val assetPaths = listOf(
            Triple("/kcs2/img/organize/organize_main.png?version=21", "image/png", 1_720_000),
            Triple("/kcs2/img/organize/organize_main.json?version=21", "application/json", 512),
            Triple("/kcs2/resources/se/001.mp3", "audio/mpeg", 128),
            Triple("/kcs2/resources/bgm/port/001.mp3?version=2", "audio/mpeg", 1_610_000),
            Triple("/kcs/sound/001.mp3", "audio/mpeg", 128),
        )
        val root = temporaryFolder.newFolder()
        val disk = kanxyDisk(root, maxBytes = 8L * 1024 * 1024)
        var session = KanxyHttpImageCache(localProxy)
        val responses = assetPaths.map { (_, mime, size) ->
            val bytes = ByteArray(size) { (it % 199).toByte() }
            val file = temporaryFolder.newFile().apply { writeBytes(bytes) }
            val response = kanxyManualImage(bytes)
            response.copy(
                headers = response.headers + mapOf("Content-Type" to mime, "Vary" to "Accept-Encoding"),
                bytes = ByteArray(0),
                file = file,
            )
        }
        val fetcher = QueueFetcher(*responses.toTypedArray())
        val engine = engine(fetcher, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)
        for ((index, asset) in assetPaths.withIndex()) {
            val (path, mime, size) = asset
            val response = requireNotNull(engine.fetchFresh(official(path)))
            val file = requireNotNull(responses[index].file)
            assertTrue(file.exists())
            assertEquals(GameResourceResponseSource.NETWORK, response.source)
            assertEquals(mime, response.mimeType)
            assertEquals(size.toLong(), response.bodyLength)
            response.openStream().use { assertArrayEquals(file.readBytes(), it.readBytes()) }
            assertFalse(file.exists())
        }
        session = KanxyHttpImageCache(localProxy)
        for ((path, mime, size) in assetPaths) {
            val response = requireNotNull(engine.fetchFresh(official(path)))
            assertEquals(GameResourceResponseSource.CACHE, response.source)
            assertEquals(mime, response.mimeType)
            assertEquals(size.toLong(), response.bodyLength)
            assertEquals("no-store", response.headers["Cache-Control"])
            response.openStream().use { assertEquals(size, it.readBytes().size) }
        }
        assertEquals(assetPaths.size, fetcher.calls.get())
    }

    @Test
    fun `Kanxy disk refuses nonpublic types encoded variants and invalid lengths`() {
        val atlas = "/kcs2/img/organize/organize_main.json?version=21"
        val sound = "/kcs2/resources/se/001.mp3"
        val mp3Headers = mapOf("Content-Type" to "audio/mpeg")
        val jsonHeaders = mapOf("Content-Type" to "application/json")
        val refused = listOf(
            "/kcs2/resources/ship/graphic.json" to jsonHeaders,
            "/kcs2/img/organize/asset.js" to mapOf("Content-Type" to "text/javascript"),
            "/kcs2/resources/voice/001.mp3" to mp3Headers,
            "$atlas&token=opaque" to jsonHeaders,
            atlas to (jsonHeaders + ("Vary" to "Accept-Encoding, Origin")),
            atlas to (jsonHeaders + mapOf("Vary" to "Accept-Encoding", "Content-Encoding" to "gzip")),
            atlas to (jsonHeaders + ("Content-Range" to "bytes 0-0/1")),
            sound to mapOf("Content-Type" to "application/octet-stream"),
        )
        val malformed = listOf(
            mapOf("Content-Length" to "1, 1"),
            mapOf("content-length" to "1"),
            mapOf("Content-Length" to "invalid"),
            mapOf("Content-Length" to "2"),
        )
        val sample = kanxyManualImage(byteArrayOf(1))
        val fetcher = QueueFetcher(*(
            refused.flatMap { (_, headers) -> List(2) { sample.copy(headers = sample.headers + headers) } } +
                malformed.map { sample.copy(headers = sample.headers + jsonHeaders + it) }
            ).toTypedArray())
        val disk = kanxyDisk(temporaryFolder.newFolder())
        val session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)

        for ((path, _) in refused) repeat(2) {
            assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(official(path))?.source)
        }
        repeat(malformed.size) { assertNull(engine.fetchFresh(official(atlas))) }
        assertEquals(refused.size * 2 + malformed.size, fetcher.calls.get())
    }

    @Test
    fun `Kanxy local resource snapshots reject ambiguous restrictive policies`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val image = kanxyManualImage(byteArrayOf(1))
        val refused = listOf(
            image.copy(headers = image.headers + ("Cache-Control" to "no-store")),
            image.copy(headers = image.headers + ("Cache-Control" to "no-store, no-cache, must-revalidate, max-age=0, private")),
            image.copy(headers = image.headers + ("Cache-Control" to "no-store, no-store, no-cache, must-revalidate, max-age=0")),
            image.copy(headers = image.headers - "Pragma"),
            image.copy(headers = image.headers + ("Expires" to "invalid")),
            image.copy(headers = image.headers + ("Age" to "not-an-age")),
            image.copy(headers = image.headers + ("Vary" to "Cookie")),
            image.copy(headers = image.headers + ("Content-Range" to "bytes 0-0/2")),
        )
        val fetcher = QueueFetcher(*(refused + listOf(image)).toTypedArray())
        val disk = kanxyDisk(temporaryFolder.newFolder())
        val session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)

        repeat(refused.size + 1) {
            assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url)?.source)
        }
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.also { it.discard() }?.source)
        assertEquals(refused.size + 1, fetcher.calls.get())
    }

    @Test
    fun `Kanxy disk never shares snapshots between proxy endpoints or admits credentialed requests`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val first = kanxyManualImage(byteArrayOf(1))
        val other = kanxyManualImage(byteArrayOf(2))
        val fetcher = QueueFetcher(
            first,
            other,
            other, other, // requests with a game-server Cookie
            other, other, // requests with an opaque signed query
        )
        val disk = kanxyDisk(temporaryFolder.newFolder())
        var session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)

        assertArrayEquals(first.bytes, engine.fetchFresh(url)?.bytes)
        session = KanxyHttpImageCache(Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved("127.0.0.1", 7411)))
        assertArrayEquals(other.bytes, engine.fetchFresh(url)?.bytes)
        session = KanxyHttpImageCache(localProxy)
        assertArrayEquals(first.bytes, engine.fetchFresh(url)?.bytes)
        repeat(2) {
            assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url, mapOf("Cookie" to "test"))?.source)
            assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh("$url&credential=opaque")?.source)
        }
        assertNull(engine.fetchFresh(url, mapOf("Authorization" to "Bearer test")))
        assertNull(engine.fetchFresh(url, mapOf("Range" to "bytes=0-1")))
        assertEquals(6, fetcher.calls.get())
    }

    @Test
    fun `a normally cacheable Kanxy disk response honors its freshness across foreground sessions`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val image = cacheableImage(byteArrayOf(1))
        val first = image.copy(headers = image.headers + ("Cache-Control" to "public, max-age=1"))
        val second = cacheableImage(byteArrayOf(2))
        val fetcher = QueueFetcher(first, second)
        val disk = kanxyDisk(temporaryFolder.newFolder())
        var wallTime = 10_000L
        var session = KanxyHttpImageCache(localProxy) { 0L }
        val engine = engine(fetcher, clock = { wallTime }, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)

        assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url)?.source)
        session = KanxyHttpImageCache(localProxy) { 0L }
        wallTime = 10_999L
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.also { it.discard() }?.source)
        wallTime = 11_000L
        assertArrayEquals(second.bytes, engine.fetchFresh(url)?.bytes)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `clearing Kanxy local resource snapshots rejects an unfinished download`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val disk = kanxyDisk(temporaryFolder.newFolder())
        val session = KanxyHttpImageCache(localProxy)
        var calls = 0
        val fetcher = GameResourceFetcher { _, _, _ ->
            if (calls++ == 0) {
                disk.clear()
                kanxyManualImage(byteArrayOf(1))
            } else kanxyManualImage(byteArrayOf(2))
        }
        val engine = engine(fetcher, kanxyHttpImageCache = { session }, kanxyDiskCache = disk)

        assertNull(engine.fetchFresh(url))
        assertArrayEquals(byteArrayOf(2), engine.fetchFresh(url)?.bytes)
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.also { it.discard() }?.source)
        assertEquals(2, calls)
    }

    @Test
    fun `Kanxy HTTP reuses a versioned banner without replacing stock cache`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val stock = byteArrayOf(1)
        val modified = byteArrayOf(2)
        val fetcher = QueueFetcher(result(stock), cacheableImage(modified))
        var session: KanxyHttpImageCache? = null
        val engine = engine(fetcher, kanxyHttpImageCache = { session })

        assertArrayEquals(stock, engine.fetch(url)?.bytes)
        session = KanxyHttpImageCache(localProxy)
        assertArrayEquals(modified, engine.fetchFresh(url)?.bytes)
        val hit = engine.fetchFresh(url)
        assertEquals(GameResourceResponseSource.CACHE, hit?.source)
        assertArrayEquals(modified, hit?.bytes)
        assertEquals("no-store", hit?.headers?.get("Cache-Control"))
        assertEquals(2, fetcher.calls.get())
        session = null
        assertArrayEquals(stock, engine.fetch(url)?.bytes)
    }

    @Test
    fun `an admitted Kanxy image uses the same memory bytes on first response and hit`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val pixels = byteArrayOf(10, 20, 30)
        val download = temporaryFolder.newFile().apply { writeBytes(pixels) }
        val fetcher = QueueFetcher(cacheableImage(pixels).copy(bytes = byteArrayOf(), file = download))
        val session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session })

        val first = checkNotNull(engine.fetchFresh(url))
        assertEquals(GameResourceResponseSource.NETWORK, first.source)
        assertFalse("memory-backed response should release its temporary download before WebView opens it", download.exists())
        assertArrayEquals(pixels, first.openStream().use { it.readBytes() })
        assertArrayEquals(pixels, engine.fetchFresh(url)?.bytes)
        assertEquals(1, fetcher.calls.get())
    }

    @Test
    fun `Kanxy diagnostics distinguish response refusal from eviction or expiry`() {
        var elapsed = 0L
        val url = official("/kcs2/resources/ship/banner/example.png")
        val normal = cacheableImage(byteArrayOf(1))
        val noStore = normal.copy(headers = normal.headers + ("Cache-Control" to "no-store"))
        val oversized = cacheableImage(ByteArray(512 * 1024 + 1))
        val badHeaders = normal.copy(headers = normal.headers + ("Content-Length" to "1, 1"))
        val fetcher = QueueFetcher(noStore, oversized, badHeaders, normal, normal)
        val session = KanxyHttpImageCache(localProxy) { elapsed }
        val engine = engine(fetcher, kanxyHttpImageCache = { session })
        fun observed(): List<KanxyImageCacheEvent> = buildList {
            assertTrue(engine.fetchFresh(url, report = { add(it) }) != null)
        }

        val miss = KanxyImageCacheEvent.MISS
        val stored = KanxyImageCacheEvent.STORED
        assertEquals(listOf(miss, KanxyImageCacheEvent.RESPONSE_NOT_FRESH), observed())
        assertEquals(listOf(miss, KanxyImageCacheEvent.IMAGE_SIZE_LIMIT), observed())
        assertEquals(listOf(miss, KanxyImageCacheEvent.RESPONSE_HEADERS), observed())
        assertEquals(listOf(miss, stored), observed())
        assertEquals(listOf(KanxyImageCacheEvent.HIT), observed())
        elapsed = 60_000
        assertEquals(listOf(KanxyImageCacheEvent.EXPIRED, stored), observed())
        assertEquals(5, fetcher.calls.get())
    }

    @Test
    fun `Kanxy HTTP does not reuse a different URL or request representation`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val response = cacheableImage(byteArrayOf(1))
        val fetcher = QueueFetcher(response, response, response)
        val session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session })
        val headers = mapOf("Cookie" to "first")

        assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url, headers)?.source)
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url, headers)?.source)
        assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url, mapOf("Cookie" to "different"))?.source)
        assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url.replace("21", "22"), headers)?.source)
        assertEquals(3, fetcher.calls.get())
    }

    @Test
    fun `a retired WebView cannot read or populate the active Kanxy HTTP cache`() {
        val url = official("/kcs2/resources/ship/banner/example.png")
        val fetcher = QueueFetcher(cacheableImage(byteArrayOf(1)), cacheableImage(byteArrayOf(2)))
        val session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session })

        assertArrayEquals(byteArrayOf(1), engine.fetchFresh(url, ownsImageCache = { false })?.bytes)
        assertArrayEquals(byteArrayOf(2), engine.fetchFresh(url)?.bytes)
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.source)
        assertEquals(2, fetcher.calls.get())
    }

    @Test
    fun `Kanxy HTTP applies short TTL to a versioned image and counts upstream age`() {
        var elapsed = 0L
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val response = cacheableImage(byteArrayOf(1))
        val nearlyExpired = response.copy(headers = response.headers + mapOf("Cache-Control" to "max-age=10", "Age" to "9"))
        val fetcher = QueueFetcher(response, nearlyExpired, response)
        val session = KanxyHttpImageCache(localProxy) { elapsed }
        val engine = engine(fetcher, kanxyHttpImageCache = { session })

        assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url)?.source)
        elapsed = 59_999
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.source)
        elapsed = 60_000
        assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url)?.source)
        elapsed = 60_999
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.source)
        elapsed = 61_000
        assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(url)?.source)
        assertEquals(3, fetcher.calls.get())
    }

    @Test
    fun `Kanxy HTTP respects response cache restrictions and bypasses the script cache`() {
        val publicImage = cacheableImage(byteArrayOf(1))
        val image = official("/kcs2/resources/ship/banner/example.png?version=21")
        val script = official("/kcs2/js/main.js?version=21")
        val responses = listOf(
            publicImage.copy(headers = publicImage.headers + ("Cache-Control" to "max-age=60, no-store")),
            publicImage.copy(headers = publicImage.headers + ("Cache-Control" to "max-age=60, no-cache")),
            publicImage.copy(headers = publicImage.headers + ("Cache-Control" to "max-age=60, private")),
            publicImage.copy(headers = publicImage.headers + ("Cache-Control" to "max-age=60, max-age=0")),
            publicImage.copy(headers = publicImage.headers + ("Cache-Control" to "ext=\"x,max-age=60,y\"")),
            publicImage.copy(headers = publicImage.headers + ("Date" to "Tue, 25 Jun 2019 03:44:10 GMT")),
            publicImage.copy(headers = publicImage.headers + ("Vary" to "Cookie")),
        )
        val fetcher = QueueFetcher(*(responses + listOf(publicImage, publicImage, publicImage)).toTypedArray())
        val session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session })

        repeat(responses.size + 1) {
            assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(image)?.source)
        }
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(image)?.source)
        repeat(2) { assertEquals(GameResourceResponseSource.NETWORK, engine.fetchFresh(script)?.source) }
        assertEquals(responses.size + 3, fetcher.calls.get())
    }

    @Test
    fun `Kanxy HTTP explicit refresh bypasses and forgets a warm image`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val original = byteArrayOf(1)
        val changed = byteArrayOf(2)
        val fetcher = QueueFetcher(cacheableImage(original), cacheableImage(changed), cacheableImage(changed))
        val session = KanxyHttpImageCache(localProxy)
        val engine = engine(fetcher, kanxyHttpImageCache = { session })

        assertArrayEquals(original, engine.fetchFresh(url)?.bytes)
        assertArrayEquals(changed, engine.fetchFresh(url, mapOf("Cache-Control" to "no-cache"))?.bytes)
        assertArrayEquals(changed, engine.fetchFresh(url)?.bytes)
        assertEquals(3, fetcher.calls.get())
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.source)
    }

    @Test
    fun `Kanxy HTTP rejects an old response after refresh on the same proxy`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        val staleFile = temporaryFolder.newFile().apply { writeBytes(byteArrayOf(1)) }
        val fresh = byteArrayOf(2)
        var session = KanxyHttpImageCache(localProxy)
        var calls = 0
        val fetcher = GameResourceFetcher { _, _, _ ->
            if (calls++ == 0) {
                session = KanxyHttpImageCache(localProxy)
                cacheableImage(byteArrayOf(1)).copy(bytes = byteArrayOf(), file = staleFile)
            } else cacheableImage(fresh)
        }
        val engine = engine(fetcher, kanxyHttpImageCache = { session })

        assertNull(engine.fetchFresh(url))
        assertFalse(staleFile.exists())
        assertArrayEquals(fresh, engine.fetchFresh(url)?.bytes)
        assertEquals(GameResourceResponseSource.CACHE, engine.fetchFresh(url)?.source)
        assertEquals(2, calls)
    }

    @Test
    fun `stock download is discarded after a round trip through another route`() {
        val url = official("/kcs2/resources/ship/banner/example.png?version=21")
        var generation = 0L
        val fetcher = GameResourceFetcher { _, _, _ ->
            generation += 2
            result(byteArrayOf(1))
        }
        val engine = engine(fetcher, resourceRouteGeneration = { generation })

        assertNull(engine.fetch(url))
        assertTrue(engine.entries().isEmpty())
    }

    @Test
    fun `late main script from an old route is discarded before WebView sees it`() {
        val url = official("/kcs2/js/main.js?version=21")
        val download = temporaryFolder.newFile().apply { writeText("old script") }
        var generation = 1L
        val engine = engine(GameResourceFetcher { _, _, _ ->
            generation++
            GameResourceFetchResult(200, "OK", mapOf("Content-Type" to "application/javascript"), file = download)
        }, resourceRouteGeneration = { generation })

        assertNull(engine.fetchFresh(url))
        assertFalse(download.exists())
        assertTrue(engine.entries().isEmpty())
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
        kanxyHttpImageCache: () -> KanxyHttpImageCache? = { null },
        resourceRouteGeneration: () -> Long = { 0L },
        kanxyDiskCache: KanxyDiskResourceCache? = null,
    ): GameResourceCacheEngine {
        val root = temporaryFolder.newFolder()
        val store = GameResourceCacheStore(
            root,
            GameResourceCacheIndex(root.resolve("index.json")),
            10_000,
            clock,
        )
        return GameResourceCacheEngine(store, fetcher, clock, kanxyHttpImageCache, resourceRouteGeneration, kanxyDiskCache) { mode }
    }

    private fun kanxyDisk(root: java.io.File, maxBytes: Long = 10_000) = KanxyDiskResourceCache(
        GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), maxBytes),
    )

    private val localProxy = Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved("127.0.0.1", 7410))

    private fun official(path: String) = "https://w17k.kancolle-server.com$path"

    private fun cacheableImage(bytes: ByteArray): GameResourceFetchResult {
        val response = result(bytes)
        return response.copy(headers = response.headers + ("Cache-Control" to "public, max-age=2592000"))
    }

    private fun kanxyManualImage(bytes: ByteArray): GameResourceFetchResult {
        val response = result(bytes)
        return response.copy(headers = response.headers + mapOf(
            "Cache-Control" to "no-store, no-cache, must-revalidate, max-age=0",
            "Pragma" to "no-cache",
            "Expires" to "0",
        ))
    }

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
