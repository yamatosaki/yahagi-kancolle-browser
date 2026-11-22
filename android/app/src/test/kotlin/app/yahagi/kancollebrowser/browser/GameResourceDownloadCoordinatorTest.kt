package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.CopyOnWriteArrayList

class GameResourceDownloadCoordinatorTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `repair replaces same length corruption and leaves healthy files cached`() {
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { url, _, _ ->
            calls.incrementAndGet()
            response(byteArrayOf(if (url.contains("healthy.png")) 2 else 1))
        })
        val damaged = official("/kcs2/resources/damaged.png?version=1")
        val healthy = official("/kcs2/resources/healthy.png?version=1")
        fixture.engine.fetch(damaged)
        val entry = fixture.engine.entries().single()
        fixture.engine.fetch(healthy)
        val file = fixture.root.resolve("files/${entry.fileName}")
        file.writeBytes(byteArrayOf(9))
        fixture.coordinator.setManifest("full", listOf(damaged, healthy), 2, listOf(1, 1))
        try {
            assertEquals(1, fixture.coordinator.checkIntegrity().damagedCount)
            assertTrue("Checking must not delete the damaged file", file.isFile)
            assertTrue(fixture.coordinator.repair())
            awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
            assertEquals("Only the damaged resource is fetched again", 3, calls.get())
            assertEquals(GameResourceInspectionState.VALID, fixture.engine.inspect(damaged, 1).state)
            assertEquals(0, fixture.coordinator.status().damagedCount)
        } finally { fixture.coordinator.dispose() }
    }

    @Test
    fun `failed repair never reports complete and can be retried`() {
        var fail = false
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            calls.incrementAndGet()
            if (fail) null else response(byteArrayOf(1))
        })
        val url = official("/kcs2/resources/failure.png?version=1")
        fixture.engine.fetch(url)
        fixture.root.resolve("files/${fixture.engine.entries().single().fileName}").writeBytes(byteArrayOf(9))
        fixture.coordinator.setManifest("full", listOf(url), 1, listOf(1))
        try {
            fail = true
            assertTrue(fixture.coordinator.repair())
            awaitState(fixture.coordinator, GameResourceDownloadState.IDLE)
            assertEquals(2, calls.get())
            assertFalse(fixture.engine.hasCached(url))
            fail = false
            assertTrue(fixture.coordinator.repair())
            awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
            assertEquals(GameResourceInspectionState.VALID, fixture.engine.inspect(url, 1).state)
        } finally { fixture.coordinator.dispose() }
    }

    @Test
    fun `repair handles removed and truncated files without refetching healthy data`() {
        for (remove in listOf(false, true)) {
            val calls = AtomicInteger()
            val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
                calls.incrementAndGet()
                response(byteArrayOf(1, 2))
            })
            val url = official("/kcs2/resources/repair.png?version=1")
            try {
                fixture.engine.fetch(url)
                val file = fixture.root.resolve("files/${fixture.engine.entries().single().fileName}")
                if (remove) file.delete() else file.writeBytes(byteArrayOf(9))
                fixture.coordinator.setManifest("full", listOf(url), 2, listOf(2))
                assertTrue(fixture.coordinator.repair())
                awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
                assertEquals(2, calls.get())
                assertEquals(GameResourceInspectionState.VALID, fixture.engine.inspect(url, 2).state)
                assertTrue(fixture.coordinator.repair())
                awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
                assertEquals(2, calls.get())
            } finally { fixture.coordinator.dispose() }
        }
    }

    @Test
    fun `a concurrent game fetch that repairs damage is reused by repair`() {
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            calls.incrementAndGet()
            response(byteArrayOf(1))
        })
        val url = official("/kcs2/resources/concurrent.png?version=1")
        try {
            fixture.engine.fetch(url)
            fixture.root.resolve("files/${fixture.engine.entries().single().fileName}").writeBytes(byteArrayOf(9))
            fixture.coordinator.setManifest("full", listOf(url), 1, listOf(1))
            assertEquals(1, fixture.coordinator.checkIntegrity().damagedCount)
            fixture.engine.fetch(url)?.discard()
            assertTrue(fixture.coordinator.startDownload())
            awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
            assertEquals(2, calls.get())
            assertEquals(GameResourceInspectionState.VALID, fixture.engine.inspect(url, 1).state)
        } finally { fixture.coordinator.dispose() }
    }

    @Test
    fun `cancelled repair cannot store its response and resume repairs once`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            if (calls.incrementAndGet() == 2) {
                entered.countDown()
                check(release.await(5, TimeUnit.SECONDS))
            }
            response(byteArrayOf(1))
        })
        val url = official("/kcs2/resources/cancelled.png?version=1")
        try {
            fixture.engine.fetch(url)
            fixture.root.resolve("files/${fixture.engine.entries().single().fileName}").writeBytes(byteArrayOf(9))
            fixture.coordinator.setManifest("full", listOf(url), 1, listOf(1))
            assertTrue(fixture.coordinator.repair())
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            assertFalse(fixture.engine.hasCached(url))
            assertTrue(fixture.coordinator.cancelDownload())
            release.countDown()
            assertTrue(fixture.coordinator.startDownload())
            awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
            assertEquals(3, calls.get())
            assertEquals(GameResourceInspectionState.VALID, fixture.engine.inspect(url, 1).state)
        } finally {
            release.countDown()
            fixture.coordinator.dispose()
        }
    }

    @Test
    fun `temporary mode never starts manifest download`() {
        val fixture = fixture(mode = GameResourceCacheMode.TEMPORARY)
        fixture.coordinator.setManifest(
            "temporary",
            listOf(official("/kcs2/resources/a.png")),
            1,
        )

        assertFalse(fixture.coordinator.startDownload())
        fixture.coordinator.dispose()
    }

    @Test
    fun `full baseline sized manifest can be prepared and restored`() {
        val stateFile = temporaryFolder.newFile("large-manifest-state.json")
        val fixture = fixture(stateFile = stateFile)
        val urls = List(62_226) { id -> official("/kcs2/resources/ship/full/$id.png?version=1") }
        val lengths = List(urls.size) { 1L }

        fixture.coordinator.setManifest("full", urls, urls.size.toLong(), lengths)
        assertEquals(urls.size, fixture.coordinator.status().missingCount)
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine, { GameResourceCacheMode.FULL }, stateFile,
        )
        assertEquals(urls.size, restored.status().missingCount)
        restored.dispose()
    }

    @Test
    fun `full baseline manifest can be prepared while cache index is populated`() {
        val fixture = fixture()
        val urls = List(62_226) { id -> official("/kcs2/resources/ship/full/$id.png?version=1") }
        fixture.root.resolve("index.json").bufferedWriter().use { writer ->
            writer.write("{\"version\":2}\n")
            urls.forEachIndexed { id, url ->
                val checksum = id.toString().padStart(64, '0')
                writer.write(
                    "{\"key\":\"$url\",\"fileName\":\"$checksum.cache\"," +
                        "\"version\":null,\"mimeType\":\"image/png\",\"byteLength\":1," +
                        "\"etag\":null,\"lastModified\":null,\"lastAccessedAt\":0," +
                        "\"lastValidatedAt\":0,\"sha256\":\"$checksum\"}\n",
                )
            }
        }

        fixture.coordinator.setManifest("full", urls, urls.size.toLong(), List(urls.size) { 1L })

        assertEquals(urls.size, fixture.coordinator.status().damagedCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `oversized manifest is rejected before building JSON`() {
        val fixture = fixture()
        val urls = List(GameResourceCacheIndex.MAX_ENTRIES + 1) {
            official("/kcs2/resources/same.png")
        }

        assertThrows(IllegalArgumentException::class.java) {
            fixture.coordinator.prepareManifest("full", urls, 1)
        }
        fixture.coordinator.dispose()
    }

    @Test
    fun `manifest is deduplicated and download completes`() {
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            calls.incrementAndGet()
            response(byteArrayOf(1))
        })
        val url = official("/kcs2/resources/a.png")
        fixture.coordinator.setManifest("light", listOf(url, url), 1)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)

        assertEquals(1, calls.get())
        assertEquals(0, fixture.coordinator.status().missingCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `completed estimated manifest converges target to actual cached bytes`() {
        val stateFile = temporaryFolder.newFile("estimated-progress-state.json")
        val fixture = fixture(
            stateFile = stateFile,
            fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) },
        )
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            115_000,
        )

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)

        assertEquals(1, fixture.coordinator.status().cachedBytes)
        assertEquals(1, fixture.coordinator.status().targetBytes)
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )
        assertEquals(1, restored.status().targetBytes)
        restored.dispose()
    }

    @Test
    fun `completed exact manifest keeps its declared target after restart`() {
        val stateFile = temporaryFolder.newFile("exact-progress-state.json")
        val fixture = fixture(
            stateFile = stateFile,
            fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) },
        )
        fixture.coordinator.setManifest(
            "full",
            listOf(official("/kcs2/resources/a.png")),
            9,
            expectedLengths = listOf(1),
        )

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        assertEquals(9, fixture.coordinator.status().targetBytes)
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )
        assertEquals(9, restored.status().targetBytes)
        restored.dispose()
    }

    @Test
    fun `backup manifest target wins over newer state when primary is damaged`() {
        val stateFile = temporaryFolder.newFile("backup-target-state.json")
        val fixture = fixture(stateFile = stateFile)
        fixture.coordinator.setManifest(
            "full",
            listOf(official("/kcs2/resources/old.png")),
            10,
            expectedLengths = listOf(10),
        )
        fixture.coordinator.setManifest(
            "full",
            listOf(official("/kcs2/resources/new.png")),
            20,
            expectedLengths = listOf(20),
        )
        fixture.coordinator.dispose()
        File(stateFile.parentFile, "${stateFile.name}.manifest.json").writeText("damaged")

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )
        assertEquals(10, restored.status().targetBytes)
        restored.dispose()
    }

    @Test
    fun `mode change stops exposing the previous manifest totals`() {
        val url = official("/kcs2/resources/a.png")
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) })
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("light", listOf(url), 580_000_000)
        assertEquals(1, fixture.coordinator.status().targetBytes)

        assertTrue(
            fixture.coordinator.configureModeChange(
                profile = "full",
                isDisabled = false,
            ) { true },
        )

        val pendingFull = fixture.coordinator.status()
        assertEquals(0, pendingFull.targetBytes)
        assertEquals(0, pendingFull.cachedBytes)
        assertEquals(0, pendingFull.missingCount)
        assertTrue(fixture.engine.hasCached(url))
        fixture.coordinator.dispose()
    }

    @Test
    fun `same mode configuration keeps the restored manifest totals`() {
        val fixture = fixture()
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            580_000_000,
        )

        assertTrue(
            fixture.coordinator.configureModeChange(
                profile = "light",
                isDisabled = false,
            ) { true },
        )

        assertEquals(580_000_000, fixture.coordinator.status().targetBytes)
        assertEquals(1, fixture.coordinator.status().missingCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `failed mode configuration retains previous manifest and progress`() {
        val stateFile = temporaryFolder.newFile("failed-mode-state.json")
        val fixture = fixture(stateFile = stateFile)
        fixture.coordinator.setManifest(
            "light", listOf(official("/kcs2/resources/a.png")), 123,
        )
        val manifest = File(stateFile.parentFile, "${stateFile.name}.manifest.json")
        assertTrue(manifest.isFile)
        assertTrue(stateFile.delete())
        assertTrue(stateFile.mkdir())
        File(stateFile, "block-replacement").writeText("keep directory nonempty")

        val failed = runCatching {
            fixture.coordinator.configureModeChange("full", false) { true }
        }

        assertTrue(failed.isFailure)
        assertEquals(123, fixture.coordinator.status().targetBytes)
        assertTrue(manifest.isFile)
        fixture.coordinator.dispose()
    }

    @Test
    fun `mode change does not revive an old backup manifest after restart`() {
        val stateFile = temporaryFolder.newFile("mode-change-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/a.png")
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("full", listOf(url), 5_800_000_000)
        fixture.coordinator.setManifest("light", listOf(url), 580_000_000)
        assertTrue(
            fixture.coordinator.configureModeChange(
                profile = "full",
                isDisabled = false,
            ) { true },
        )
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )

        assertEquals(0, restored.status().targetBytes)
        assertEquals(0, restored.status().cachedBytes)
        assertTrue(fixture.engine.hasCached(url))
        restored.dispose()
    }

    @Test
    fun `pause finishes active item but does not take another until resume`() {
        val firstStarted = CountDownLatch(1)
        val releaseFirst = CountDownLatch(1)
        val calls = AtomicInteger()
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            if (calls.incrementAndGet() == 1) {
                firstStarted.countDown()
                releaseFirst.await(5, TimeUnit.SECONDS)
            }
            response(byteArrayOf(1))
        })
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png"), official("/kcs2/resources/b.png")),
            2,
        )
        fixture.coordinator.startDownload()
        assertTrue(firstStarted.await(5, TimeUnit.SECONDS))

        fixture.coordinator.pauseDownload()
        releaseFirst.countDown()
        awaitState(fixture.coordinator, GameResourceDownloadState.PAUSED)
        Thread.sleep(100)
        assertEquals(1, calls.get())

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        assertEquals(2, calls.get())
        fixture.coordinator.dispose()
    }

    @Test
    fun `clear cancellation prevents an in flight response from being stored`() {
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val url = official("/kcs2/resources/in-flight.png")
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ ->
            started.countDown()
            release.await(5, TimeUnit.SECONDS)
            response(byteArrayOf(1))
        })
        fixture.coordinator.setManifest("light", listOf(url), 1)
        fixture.coordinator.startDownload()
        assertTrue(started.await(5, TimeUnit.SECONDS))

        fixture.coordinator.cancelDownload()
        fixture.engine.clear()
        release.countDown()
        awaitState(fixture.coordinator, GameResourceDownloadState.PAUSED)

        assertFalse(fixture.engine.hasCached(url))
        fixture.coordinator.dispose()
    }

    @Test
    fun `full mode uses lru eviction and continues downloading`() {
        val fixture = fixture(
            mode = GameResourceCacheMode.FULL,
            maxBytes = 3,
            fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1, 2)) },
        )
        val old = official("/kcs2/resources/old.png")
        val url = official("/kcs2/resources/a.png")
        fixture.engine.fetch(old)
        fixture.coordinator.setManifest("full", listOf(url), 2)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        assertFalse(fixture.engine.hasCached(old))
        assertTrue(fixture.engine.hasCached(url))
        assertFalse(fixture.coordinator.status().capacityBlocked)
        fixture.coordinator.dispose()
    }

    @Test
    fun `missing resource is skipped silently while later resources download`() {
        val missing = official("/kcs2/resources/missing.png")
        val available = official("/kcs2/resources/available.png")
        val fixture = fixture(fetcher = GameResourceFetcher { url, _, _ ->
            if (url == missing) {
                GameResourceFetchResult(404, "Not Found", emptyMap(), byteArrayOf())
            } else {
                response(byteArrayOf(1))
            }
        })
        fixture.coordinator.setManifest("full", listOf(missing, available), 2)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.IDLE)

        assertEquals(1, fixture.coordinator.status().missingCount)
        assertTrue(fixture.engine.hasCached(available))
        fixture.coordinator.dispose()
    }

    @Test
    fun `baseline expected length mismatch stays missing without stopping queue`() {
        val mismatch = official("/kcs2/resources/mismatch.png")
        val available = official("/kcs2/resources/available.png")
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) })
        fixture.coordinator.setManifest(
            "full",
            listOf(mismatch, available),
            3,
            expectedLengths = listOf(2, 1),
        )

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.IDLE)

        assertEquals(1, fixture.coordinator.status().missingCount)
        assertTrue(fixture.engine.hasCached(available))
        fixture.coordinator.dispose()
    }

    @Test
    fun `new expected length marks existing cache outdated and replaces it`() {
        val url = official("/kcs2/resources/changed.png")
        val responses = ArrayDeque(
            listOf(response(byteArrayOf(1)), response(byteArrayOf(2, 3))),
        )
        val fixture = fixture(fetcher = GameResourceFetcher { _, _, _ -> responses.removeFirst() })
        fixture.engine.fetch(url, expectedLength = 1)

        fixture.coordinator.setManifest("full", listOf(url), 2, expectedLengths = listOf(2))
        assertEquals(1, fixture.coordinator.status().outdatedCount)
        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)

        assertEquals(2, fixture.coordinator.status().cachedBytes)
        assertEquals(0, fixture.coordinator.status().outdatedCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `paused manifest snapshot is restored`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png"), official("/kcs2/resources/a.png")),
            9,
        )
        fixture.coordinator.pauseDownload()
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(fixture.engine, { GameResourceCacheMode.FULL }, stateFile)
        val status = restored.status()
        assertEquals(GameResourceDownloadState.PAUSED, status.state)
        assertEquals(1, status.missingCount)
        assertEquals(9, status.targetBytes)
        restored.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            9,
        )
        assertFalse(restored.startAutoUpdate())
        assertEquals(GameResourceDownloadState.PAUSED, restored.status().state)
        restored.dispose()
    }

    @Test
    fun `manifest urls are not rewritten with frequently updated state`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/large-manifest-entry.png")

        fixture.coordinator.setManifest("full", listOf(url), 9)

        assertFalse(stateFile.readText().contains(url))
        fixture.coordinator.dispose()
        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )
        assertEquals(1, restored.status().missingCount)
        assertEquals(9, restored.status().targetBytes)
        assertTrue(restored.startDownload())
        awaitState(restored, GameResourceDownloadState.COMPLETE)
        restored.dispose()
    }

    @Test
    fun `first status after restart restores cached bytes from manifest snapshot`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/cached.png")
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("light", listOf(url), 1)
        fixture.coordinator.dispose()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )

        assertEquals(1, restored.status().cachedBytes)
        assertEquals(0, restored.status().missingCount)
        restored.dispose()
    }

    @Test
    fun `restart status uses persisted snapshot until explicit integrity check`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val url = official("/kcs2/resources/cached.png")
        fixture.engine.fetch(url)
        fixture.coordinator.setManifest("light", listOf(url), 1)
        val entry = fixture.engine.entries().single()
        fixture.coordinator.dispose()
        fixture.root.resolve("files/${entry.fileName}").delete()

        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )

        assertEquals(1, restored.status().cachedBytes)
        assertEquals(0, restored.status().missingCount)
        val checked = restored.checkIntegrity()
        assertEquals(0, checked.cachedBytes)
        assertEquals(1, checked.damagedCount)
        restored.dispose()
    }

    @Test
    fun `authorized download resumes after restart when wifi returns`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        var network = GameResourceNetworkState(connected = true, metered = true)
        val fixture = fixture(stateFile = stateFile, networkProvider = { network })
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/resume.png")),
            1,
        )
        assertFalse(fixture.coordinator.startDownload())
        fixture.coordinator.dispose()

        network = GameResourceNetworkState(connected = true, metered = false)
        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
            { network },
        )
        restored.onNetworkChanged()

        awaitState(restored, GameResourceDownloadState.COMPLETE)
        restored.dispose()
    }

    @Test
    fun `bulk download waits for wifi and resumes when network changes`() {
        var network = GameResourceNetworkState(connected = true, metered = true)
        val fixture = fixture(networkProvider = { network })
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            1,
        )

        assertFalse(fixture.coordinator.startDownload())
        assertTrue(fixture.coordinator.status().waitingForWifi)

        network = GameResourceNetworkState(connected = true, metered = false)
        fixture.coordinator.onNetworkChanged()
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.dispose()
    }

    @Test
    fun `confirmed mobile data download is allowed for current run`() {
        val fixture = fixture(
            networkProvider = {
                GameResourceNetworkState(connected = true, metered = true)
            },
        )
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/a.png")),
            1,
        )

        assertTrue(fixture.coordinator.startDownload(allowMetered = true))
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.dispose()
    }

    @Test
    fun `an early download click does not authorize auto updates when the manifest arrives`() {
        val fixture = fixture()
        try {
            assertTrue(fixture.coordinator.configureModeChange("full", false) { true })
            assertFalse(fixture.coordinator.status().manifestReady)
            assertFalse(fixture.coordinator.startDownload())

            val url = official("/kcs2/resources/ship/banner/early.png?version=1")
            fixture.coordinator.setManifest("full", listOf(url), 1)

            assertTrue(fixture.coordinator.status().manifestReady)
            assertFalse(fixture.coordinator.startAutoUpdate())
            assertEquals(GameResourceDownloadState.IDLE, fixture.coordinator.status().state)
            assertTrue(fixture.coordinator.startDownload())
            awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        } finally {
            fixture.coordinator.dispose()
        }
    }

    @Test
    fun `manual click during proxy block does not authorize a download after disconnect`() {
        val proxyBlocked = AtomicBoolean(true)
        val fixture = fixture(preloadBlockedByProxy = proxyBlocked::get)
        try {
            fixture.coordinator.setManifest("full", listOf(official("/kcs2/resources/a.png")), 1)
            assertTrue(fixture.coordinator.status().manifestReady)
            assertTrue(fixture.coordinator.status().preloadBlockedByProxy)
            assertFalse(fixture.coordinator.status().waitingForWifi)
            assertFalse(fixture.coordinator.startDownload())

            proxyBlocked.set(false)
            assertFalse(fixture.coordinator.status().preloadBlockedByProxy)
            assertFalse(fixture.coordinator.startAutoUpdate())
            assertEquals(GameResourceDownloadState.IDLE, fixture.coordinator.status().state)
        } finally {
            fixture.coordinator.dispose()
        }
    }

    @Test
    fun `proxy pauses authorized work without claiming wifi loss and resumes after disconnect`() {
        val proxyBlocked = AtomicBoolean(false)
        val firstFetchEntered = CountDownLatch(1)
        val finishFirstFetch = CountDownLatch(1)
        val requests = CopyOnWriteArrayList<String>()
        val first = official("/kcs2/resources/a.png?version=1")
        val second = official("/kcs2/resources/b.png?version=1")
        val fixture = fixture(
            fetcher = GameResourceFetcher { url, _, _ ->
                requests.add(url)
                if (requests.size == 1) {
                    firstFetchEntered.countDown()
                    assertTrue(finishFirstFetch.await(5, TimeUnit.SECONDS))
                }
                response(byteArrayOf(1))
            },
            preloadBlockedByProxy = proxyBlocked::get,
        )
        try {
            fixture.coordinator.setManifest("full", listOf(first, second), 2)
            assertTrue(fixture.coordinator.startDownload())
            assertTrue(firstFetchEntered.await(5, TimeUnit.SECONDS))
            proxyBlocked.set(true)
            fixture.coordinator.onNetworkChanged()
            finishFirstFetch.countDown()

            awaitState(fixture.coordinator, GameResourceDownloadState.PAUSED)
            val paused = fixture.coordinator.status()
            assertTrue(paused.preloadBlockedByProxy)
            assertFalse(paused.waitingForWifi)
            assertEquals(0L, paused.cachedBytes)
            assertEquals(listOf(first), requests.toList())

            proxyBlocked.set(false)
            fixture.coordinator.onNetworkChanged()
            awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
            assertEquals(listOf(first, first, second), requests.toList())
        } finally {
            finishFirstFetch.countDown()
            fixture.coordinator.dispose()
        }
    }

    @Test
    fun `automatic update starts only after first manual authorization`() {
        val fixture = fixture()
        val first = official("/kcs2/resources/a.png?version=1")
        val second = official("/kcs2/resources/b.png?version=1")
        fixture.coordinator.setManifest("light", listOf(first), 1)

        assertFalse(fixture.coordinator.startAutoUpdate())
        assertEquals(GameResourceDownloadState.IDLE, fixture.coordinator.status().state)

        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.setManifest("light", listOf(first, second), 2)
        assertTrue(fixture.coordinator.startAutoUpdate())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.dispose()
    }

    @Test
    fun `status bytes count only valid files in current manifest`() {
        val fixture = fixture()
        fixture.engine.fetch(official("/kcs2/resources/unrelated.png?version=1"))
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/target.png?version=1")),
            10,
        )

        assertEquals(0, fixture.coordinator.status().cachedBytes)
        fixture.coordinator.dispose()
    }

    @Test
    fun `integrity check reports a corrupted manifest file as damaged`() {
        val fixture = fixture()
        val url = official("/kcs2/resources/a.png?version=1")
        fixture.engine.fetch(url)
        val entry = fixture.engine.entries().single()
        fixture.root.resolve("files/${entry.fileName}").writeBytes(byteArrayOf(9))
        fixture.coordinator.setManifest("light", listOf(url), 1)

        assertEquals(0, fixture.coordinator.status().damagedCount)

        val status = fixture.coordinator.checkIntegrity()

        assertEquals(0, status.missingCount)
        assertEquals(1, status.damagedCount)
        fixture.coordinator.dispose()
    }

    @Test
    fun `replacing manifest cancels remaining work from old generation`() {
        val firstStarted = CountDownLatch(1)
        val releaseFirst = CountDownLatch(1)
        val visited = CopyOnWriteArrayList<String>()
        val oldFirst = official("/kcs2/resources/old-a.png?version=1")
        val oldSecond = official("/kcs2/resources/old-b.png?version=1")
        val current = official("/kcs2/resources/current.png?version=1")
        val fixture = fixture(fetcher = GameResourceFetcher { url, _, _ ->
            visited += url
            if (url == oldFirst) {
                firstStarted.countDown()
                releaseFirst.await(5, TimeUnit.SECONDS)
            }
            response(byteArrayOf(1))
        })
        fixture.coordinator.setManifest("full", listOf(oldFirst, oldSecond), 2)
        fixture.coordinator.startDownload()
        assertTrue(firstStarted.await(5, TimeUnit.SECONDS))

        fixture.coordinator.setManifest("light", listOf(current), 1)
        fixture.coordinator.startDownload()
        releaseFirst.countDown()
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)

        assertFalse(visited.contains(oldSecond))
        assertFalse(fixture.engine.hasCached(oldFirst))
        assertTrue(visited.contains(current))
        fixture.coordinator.dispose()
    }

    @Test
    fun `superseded prepared manifest is rolled back`() {
        val stateFile = temporaryFolder.newFile("download-state.json")
        val fixture = fixture(stateFile = stateFile)
        val original = official("/kcs2/resources/original.png")
        val stale = official("/kcs2/resources/stale.png")
        fixture.coordinator.setManifest("light", listOf(original), 1)
        val prepared = fixture.coordinator.prepareManifest("full", listOf(stale), 9)
        val checks = AtomicInteger()

        val applied = fixture.coordinator.applyPreparedManifestIf(prepared) {
            checks.incrementAndGet() == 1
        }
        fixture.coordinator.discardPreparedManifest(prepared)

        assertFalse(applied)
        assertEquals(1, fixture.coordinator.status().targetBytes)
        fixture.coordinator.dispose()
        val restored = GameResourceDownloadCoordinator(
            fixture.engine,
            { GameResourceCacheMode.FULL },
            stateFile,
        )
        assertEquals(1, restored.status().targetBytes)
        assertEquals(1, restored.status().missingCount)
        restored.dispose()
    }

    @Test
    fun `network callback after dispose is ignored`() {
        val fixture = fixture()
        fixture.coordinator.dispose()

        fixture.coordinator.onNetworkChanged()

        assertFalse(fixture.coordinator.startDownload())
    }

    @Test
    fun `superseded mode configuration has no side effects`() {
        val fixture = fixture()
        fixture.coordinator.setManifest(
            "light",
            listOf(official("/kcs2/resources/current.png")),
            1,
        )

        assertFalse(
            fixture.coordinator.configureModeChange(
                profile = "none",
                isDisabled = true,
            ) { false },
        )

        assertEquals(GameResourceDownloadState.IDLE, fixture.coordinator.status().state)
        assertTrue(fixture.coordinator.startDownload())
        awaitState(fixture.coordinator, GameResourceDownloadState.COMPLETE)
        fixture.coordinator.dispose()
    }

    @Test
    fun `worker persist failure becomes error without restart loop`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = AtomicInteger()
        val stateFile = temporaryFolder.newFile("worker-error-state.json")
        val fixture = fixture(
            stateFile = stateFile,
            fetcher = GameResourceFetcher { _, _, _ ->
                calls.incrementAndGet()
                entered.countDown()
                release.await(5, TimeUnit.SECONDS)
                response(byteArrayOf(1))
            },
        )
        fixture.coordinator.setManifest("full",
            listOf(official("/kcs2/resources/a.png")), 1, expectedLengths = listOf(1))
        assertTrue(fixture.coordinator.startDownload())
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        assertTrue(stateFile.delete())
        assertTrue(stateFile.mkdir())
        File(stateFile, "block-replacement").writeText("nonempty")
        release.countDown()

        awaitState(fixture.coordinator, GameResourceDownloadState.ERROR)
        Thread.sleep(100)
        assertEquals(1, calls.get())
        fixture.coordinator.dispose()
    }

    private fun fixture(
        mode: GameResourceCacheMode = GameResourceCacheMode.FULL,
        maxBytes: Long = 10_000,
        stateFile: File = temporaryFolder.newFile(),
        fetcher: GameResourceFetcher = GameResourceFetcher { _, _, _ -> response(byteArrayOf(1)) },
        networkProvider: () -> GameResourceNetworkState = {
            GameResourceNetworkState(connected = true, metered = false)
        },
        preloadBlockedByProxy: () -> Boolean = { false },
    ): Fixture {
        val root = temporaryFolder.newFolder()
        val store = GameResourceCacheStore(root, GameResourceCacheIndex(root.resolve("index.json")), maxBytes)
        val engine = GameResourceCacheEngine(store, fetcher) { mode }
        return Fixture(
            root,
            engine,
            GameResourceDownloadCoordinator(engine, { mode }, stateFile, networkProvider, preloadBlockedByProxy),
        )
    }

    private fun awaitState(
        coordinator: GameResourceDownloadCoordinator,
        expected: GameResourceDownloadState,
    ) {
        val deadline = System.currentTimeMillis() + 5_000
        while (System.currentTimeMillis() < deadline) {
            if (coordinator.status().state == expected) return
            Thread.sleep(10)
        }
        assertEquals(expected, coordinator.status().state)
    }

    private fun official(path: String) = "https://w17k.kancolle-server.com$path"

    private data class Fixture(
        val root: File,
        val engine: GameResourceCacheEngine,
        val coordinator: GameResourceDownloadCoordinator,
    )

    companion object {
        private fun response(bytes: ByteArray) = GameResourceFetchResult(
            200,
            "OK",
            mapOf("Content-Length" to bytes.size.toString(), "Content-Type" to "image/png"),
            bytes,
        )
    }
}
