package app.yahagi.kancollebrowser.browser

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

enum class GameResourceDownloadState(val wireName: String) {
    IDLE("idle"),
    DOWNLOADING("downloading"),
    PAUSED("paused"),
    COMPLETE("complete"),
    CHECKING("checking"),
    CAPACITY_BLOCKED("capacityBlocked"),
    ERROR("error"),
}

data class GameResourceDownloadStatus(
    val state: GameResourceDownloadState,
    val cachedBytes: Long,
    val targetBytes: Long,
    val downloadedBytes: Long,
    val bytesPerSecond: Long,
    val remainingSeconds: Long?,
    val missingCount: Int,
    val damagedCount: Int,
    val outdatedCount: Int,
    val capacityBlocked: Boolean,
    val isMetered: Boolean,
    val waitingForWifi: Boolean,
    val manifestReady: Boolean,
    val preloadBlockedByProxy: Boolean,
)

data class GameResourceNetworkState(
    val connected: Boolean,
    val metered: Boolean,
    val wifi: Boolean = !metered,
)

class GameResourcePreparedManifest internal constructor(
    val profile: String,
    val urls: List<String>,
    val targetBytes: Long,
    internal val expectedByteLengths: Map<String, Long>,
    internal val validByteLengths: Map<String, Long>,
    internal val missingCount: Int,
    internal val damagedCount: Int,
    internal val outdatedCount: Int,
    internal val temporaryFile: File,
)

class GameResourceDownloadCoordinator(
    private val engine: GameResourceCacheEngine,
    private val modeProvider: () -> GameResourceCacheMode,
    private val stateFile: File,
    private val networkProvider: () -> GameResourceNetworkState = {
        GameResourceNetworkState(connected = true, metered = false, wifi = true)
    },
    private val preloadBlockedByProxy: () -> Boolean = { false },
) {
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "game-resource-preloader").apply { isDaemon = true }
    }
    private val workerRunning = AtomicBoolean(false)
    private val disposed = AtomicBoolean(false)
    private val generation = AtomicLong(0)
    @Volatile private var pauseRequested = false
    @Volatile private var networkPaused = false
    @Volatile private var allowMetered = false
    @Volatile private var userPaused = false
    private var profile = "none"
    private var urls = emptyList<String>()
    private var manifestLoaded = false
    private val manifestFile = File(
        stateFile.parentFile ?: File("."),
        "${stateFile.name}.manifest.json",
    )
    private val manifestBackupFile = File(
        stateFile.parentFile ?: File("."),
        "${stateFile.name}.manifest.json.bak",
    )
    private var targetBytes = 0L
    private var cachedBytesSnapshot = 0L
    private var downloadedBytes = 0L
    private var startedAt = 0L
    private var missingCount = 0
    private var damagedCount = 0
    private var outdatedCount = 0
    private var validByteLengths = linkedMapOf<String, Long>()
    private var expectedByteLengths = linkedMapOf<String, Long>()
    // A metadata-only hit cannot clear a checksum failure discovered by an explicit check.
    // This set belongs to the active manifest and is only accessed under this monitor.
    private var checksumRequiredUrls = linkedSetOf<String>()
    private var state = GameResourceDownloadState.IDLE
    private var preloadAuthorized = false

    init {
        restore()
    }

    fun setManifest(
        profile: String,
        candidates: List<String>,
        targetBytes: Long,
        expectedLengths: List<Long> = emptyList(),
    ) {
        val prepared = prepareManifest(profile, candidates, targetBytes, expectedLengths)
        try {
            applyPreparedManifest(prepared)
        } finally {
            discardPreparedManifest(prepared)
        }
    }

    fun prepareManifest(
        profile: String,
        candidates: List<String>,
        targetBytes: Long,
        expectedLengths: List<Long> = emptyList(),
    ): GameResourcePreparedManifest {
        check(!disposed.get()) { "Resource cache coordinator is disposed" }
        require(candidates.size <= MAX_MANIFEST_ENTRIES &&
            candidates.sumOf { it.length.toLong() } <= MAX_MANIFEST_URL_CHARS
        ) { "Resource cache manifest is too large" }
        require(expectedLengths.isEmpty() || expectedLengths.size == candidates.size) {
            "Expected lengths must align with manifest URLs"
        }
        val filteredUrls = mutableListOf<String>()
        val filteredExpectedLengths = linkedMapOf<String, Long>()
        val seen = hashSetOf<String>()
        candidates.forEachIndexed { index, url ->
            if (GameResourceCacheRules.shouldCache(url, "GET") &&
                (profile != "full" || GameResourceCacheRules.isShareableStaticUri(java.net.URI(url))) &&
                seen.add(url)) {
                filteredUrls += url
                if (expectedLengths.isNotEmpty()) {
                    filteredExpectedLengths[url] = expectedLengths[index].coerceAtLeast(0L)
                }
            }
        }
        val validLengths = linkedMapOf<String, Long>()
        var missing = 0
        var damaged = 0
        var outdated = 0
        filteredUrls.forEach { url ->
            val inspection = engine.inspectMetadata(url, filteredExpectedLengths[url])
            when (inspection.state) {
                GameResourceInspectionState.VALID -> validLengths[url] = inspection.byteLength
                GameResourceInspectionState.MISSING -> missing++
                GameResourceInspectionState.DAMAGED -> damaged++
                GameResourceInspectionState.OUTDATED -> outdated++
            }
        }
        val effectiveTargetBytes = if (profile == "full" &&
            filteredUrls.size != candidates.size && filteredExpectedLengths.isNotEmpty()) {
            filteredExpectedLengths.values.sum()
        } else if (
            filteredExpectedLengths.isEmpty() &&
            filteredUrls.isNotEmpty() &&
            missing == 0 &&
            damaged == 0 &&
            outdated == 0
        ) {
            validLengths.values.sum()
        } else {
            targetBytes.coerceAtLeast(0)
        }
        val temporary = writeManifestTemporary(
            profile,
            filteredUrls,
            effectiveTargetBytes,
            filteredExpectedLengths,
        )
        return GameResourcePreparedManifest(
            profile = profile,
            urls = filteredUrls,
            targetBytes = effectiveTargetBytes,
            expectedByteLengths = filteredExpectedLengths,
            validByteLengths = validLengths,
            missingCount = missing,
            damagedCount = damaged,
            outdatedCount = outdated,
            temporaryFile = temporary,
        )
    }

    @Synchronized
    fun applyPreparedManifest(prepared: GameResourcePreparedManifest) {
        check(applyPreparedManifestIf(prepared) { true }) {
            "Resource cache coordinator is disposed"
        }
    }

    @Synchronized
    fun applyPreparedManifestIf(
        prepared: GameResourcePreparedManifest,
        isCurrent: () -> Boolean,
    ): Boolean {
        if (disposed.get() || !isCurrent()) return false
        val hadManifest = manifestFile.isFile
        installPreparedManifest(prepared.temporaryFile)
        if (disposed.get() || !isCurrent()) {
            restorePreviousManifest(hadManifest)
            return false
        }
        val previous = snapshotState()
        val profileChanged = this.profile != prepared.profile
        generation.incrementAndGet()
        this.profile = prepared.profile
        urls = prepared.urls
        manifestLoaded = true
        this.targetBytes = prepared.targetBytes
        downloadedBytes = 0
        if (profileChanged) {
            preloadAuthorized = false
            userPaused = false
        }
        validByteLengths = LinkedHashMap(prepared.validByteLengths)
        checksumRequiredUrls = linkedSetOf()
        cachedBytesSnapshot = validByteLengths.values.sum()
        missingCount = prepared.missingCount
        damagedCount = prepared.damagedCount
        outdatedCount = prepared.outdatedCount
        state = if (userPaused) {
            GameResourceDownloadState.PAUSED
        } else if (missingCount == 0 && damagedCount == 0 && outdatedCount == 0 && urls.isNotEmpty()) {
            GameResourceDownloadState.COMPLETE
        } else {
            GameResourceDownloadState.IDLE
        }
        pauseRequested = userPaused
        networkPaused = false
        allowMetered = false
        expectedByteLengths = LinkedHashMap(prepared.expectedByteLengths)
        persist()
        if (disposed.get() || !isCurrent()) {
            generation.incrementAndGet()
            restoreState(previous)
            restorePreviousManifest(hadManifest)
            persist()
            return false
        }
        return true
    }

    fun discardPreparedManifest(prepared: GameResourcePreparedManifest) {
        prepared.temporaryFile.delete()
    }

    @Synchronized
    fun configureModeChange(
        profile: String,
        isDisabled: Boolean,
        isCurrent: () -> Boolean,
    ): Boolean {
        if (disposed.get() || !isCurrent()) return false
        val previous = snapshotState()
        val profileChanged = this.profile != profile
        generation.incrementAndGet()
        try {
            if (profileChanged) {
                this.profile = profile
                urls = emptyList()
                manifestLoaded = true
                targetBytes = 0L
                cachedBytesSnapshot = 0L
                downloadedBytes = 0L
                startedAt = 0L
                missingCount = 0
                damagedCount = 0
                outdatedCount = 0
                validByteLengths = linkedMapOf()
                expectedByteLengths = linkedMapOf()
                checksumRequiredUrls = linkedSetOf()
                preloadAuthorized = false
                userPaused = isDisabled
            }
            pauseRequested = true
            networkPaused = false
            if (isDisabled) {
                userPaused = true
                state = GameResourceDownloadState.PAUSED
            } else {
                state = GameResourceDownloadState.IDLE
            }
            persist()
            if (profileChanged) {
                manifestFile.delete()
                manifestBackupFile.delete()
            }
            return true
        } catch (error: Exception) {
            generation.incrementAndGet()
            restoreState(previous)
            throw error
        }
    }

    @Synchronized
    fun startDownload(allowMetered: Boolean = false): Boolean {
        if (disposed.get()) return false
        return startDownloadInternal(allowMetered, authorize = true)
    }

    @Synchronized
    fun startAutoUpdate(): Boolean {
        if (disposed.get()) return false
        if (!preloadAuthorized || userPaused) return false
        return startDownloadInternal(allowMetered = false)
    }

    private fun startDownloadInternal(allowMetered: Boolean, authorize: Boolean = false): Boolean {
        ensureManifestLoaded()
        if (!hasFullManifest()) return false
        if (preloadBlockedByProxy()) {
            if (!authorize && state != GameResourceDownloadState.COMPLETE) {
                pauseForPreloadRestriction(proxyBlocked = true)
            }
            return false
        }
        val remainingEstimate = (targetBytes - cachedManifestBytes()).coerceAtLeast(0L)
        val reclaimableBudget = engine.availableDeviceBytes().let { available ->
            val used = engine.status().usedBytes
            if (Long.MAX_VALUE - available < used) Long.MAX_VALUE else available + used
        }
        if (remainingEstimate > reclaimableBudget) {
            state = GameResourceDownloadState.CAPACITY_BLOCKED
            pauseRequested = true
            persist()
            return false
        }
        if (authorize) {
            preloadAuthorized = true
            userPaused = false
        }
        this.allowMetered = allowMetered
        if (!canUseCurrentNetwork()) {
            pauseForPreloadRestriction(proxyBlocked = false)
            return false
        }
        networkPaused = false
        pauseRequested = false
        state = GameResourceDownloadState.DOWNLOADING
        if (startedAt == 0L) startedAt = System.currentTimeMillis()
        persist()
        val currentGeneration = generation.get()
        if (workerRunning.compareAndSet(false, true)) {
            scheduleDownload(currentGeneration)
        }
        return true
    }

    private fun hasFullManifest(): Boolean = modeProvider() == GameResourceCacheMode.FULL &&
        GameResourceCacheMode.fromWireName(profile) == GameResourceCacheMode.FULL && urls.isNotEmpty()

    private fun pauseForPreloadRestriction(proxyBlocked: Boolean) {
        networkPaused = !proxyBlocked
        pauseRequested = true
        state = GameResourceDownloadState.PAUSED
        persist()
    }

    @Synchronized
    fun pauseDownload(): Boolean {
        if (disposed.get()) return false
        userPaused = true
        networkPaused = false
        pauseRequested = true
        state = GameResourceDownloadState.PAUSED
        persist()
        return true
    }

    @Synchronized
    fun cancelDownload(): Boolean {
        if (disposed.get()) return false
        generation.incrementAndGet()
        return pauseDownload()
    }

    fun onNetworkChanged() {
        if (disposed.get()) return
        try {
            executor.execute { handleNetworkChanged() }
        } catch (_: RejectedExecutionException) {
            // A connectivity callback may already be in flight during disposal.
        }
    }

    @Synchronized
    private fun handleNetworkChanged() {
        if (disposed.get()) return
        ensureManifestLoaded()
        if (!preloadAuthorized || userPaused || !hasFullManifest()) return
        val proxyBlocked = preloadBlockedByProxy()
        if (proxyBlocked || !canUseCurrentNetwork()) {
            if (state != GameResourceDownloadState.COMPLETE) {
                pauseForPreloadRestriction(proxyBlocked)
            }
            return
        }
        startDownloadInternal(allowMetered = allowMetered)
    }

    fun checkIntegrity(): GameResourceDownloadStatus {
        synchronized(this) {
            ensureManifestLoaded()
            state = GameResourceDownloadState.CHECKING
        }
        synchronized(this) {
            refreshInspectionCounts(verifyChecksum = true)
            state = when {
                pauseRequested -> GameResourceDownloadState.PAUSED
                missingCount == 0 && damagedCount == 0 && outdatedCount == 0 && urls.isNotEmpty() ->
                    GameResourceDownloadState.COMPLETE
                else -> GameResourceDownloadState.IDLE
            }
            persist()
            return status()
        }
    }

    fun repair(): Boolean {
        checkIntegrity()
        return startDownload()
    }

    @Synchronized
    fun status(): GameResourceDownloadStatus {
        ensureManifestLoaded()
        val proxyBlocked = preloadBlockedByProxy()
        val cached = cachedManifestBytes()
        val elapsedSeconds = ((System.currentTimeMillis() - startedAt) / 1000).coerceAtLeast(1)
        val speed = if (startedAt == 0L) 0L else downloadedBytes / elapsedSeconds
        val remaining = if (speed > 0 && targetBytes > cached) (targetBytes - cached + speed - 1) / speed else null
        return GameResourceDownloadStatus(
            state = state,
            cachedBytes = cached,
            targetBytes = targetBytes,
            downloadedBytes = downloadedBytes,
            bytesPerSecond = speed,
            remainingSeconds = remaining,
            missingCount = missingCount,
            damagedCount = damagedCount,
            outdatedCount = outdatedCount,
            capacityBlocked = state == GameResourceDownloadState.CAPACITY_BLOCKED,
            isMetered = !networkProvider().wifi,
            waitingForWifi = networkPaused && !proxyBlocked,
            manifestReady = hasFullManifest(),
            preloadBlockedByProxy = proxyBlocked,
        )
    }

    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        pauseRequested = true
        generation.incrementAndGet()
        executor.shutdownNow()
    }

    private fun downloadLoop(workerGeneration: Long) {
        try {
            val work = synchronized(this) { urls.toList() }
            for (url in work) {
                val (expectedLength, requiresChecksum) = synchronized(this) {
                    if (workerGeneration != generation.get() || pauseRequested) return
                    val proxyBlocked = preloadBlockedByProxy()
                    if (proxyBlocked || !canUseCurrentNetwork()) {
                        pauseForPreloadRestriction(proxyBlocked)
                        return
                    }
                    expectedByteLengths[url] to (url in checksumRequiredUrls)
                }
                if (!requiresChecksum && engine.hasCachedMetadata(url, expectedLength)) continue
                val response = try {
                    engine.fetch(
                        url,
                        expectedLength = expectedLength,
                        waitForSlot = true,
                        shouldStore = {
                            workerGeneration == generation.get() &&
                                modeProvider() != GameResourceCacheMode.NONE && !preloadBlockedByProxy()
                        },
                    )
                } catch (_: Exception) {
                    synchronized(this) {
                        state = GameResourceDownloadState.ERROR
                        pauseRequested = true
                        persist()
                    }
                    return
                } ?: continue
                if (workerGeneration != generation.get() || pauseRequested) {
                    response.discard()
                    return
                }
                if (response.source == GameResourceResponseSource.NETWORK) {
                    synchronized(this) { downloadedBytes += response.bodyLength }
                }
                response.discard()
                val inspection = engine.inspect(url, expectedLength)
                if (inspection.state == GameResourceInspectionState.VALID) {
                    synchronized(this) {
                        val previousLength = validByteLengths.put(url, inspection.byteLength) ?: 0L
                        cachedBytesSnapshot += inspection.byteLength - previousLength
                    }
                }
                synchronized(this) { persist() }
            }
            synchronized(this) {
                if (!pauseRequested && workerGeneration == generation.get()) {
                    val proxyBlocked = preloadBlockedByProxy()
                    if (proxyBlocked || !canUseCurrentNetwork()) {
                        pauseForPreloadRestriction(proxyBlocked)
                        return
                    }
                    refreshInspectionCounts()
                    state = if (missingCount == 0 && damagedCount == 0 && outdatedCount == 0) {
                        GameResourceDownloadState.COMPLETE
                    } else {
                        GameResourceDownloadState.IDLE
                    }
                    persist()
                }
            }
        } catch (_: Exception) {
            synchronized(this) {
                if (!disposed.get() && workerGeneration == generation.get()) {
                    pauseRequested = true
                    state = GameResourceDownloadState.ERROR
                    runCatching { persist() }
                }
            }
        } finally {
            workerRunning.set(false)
            if (!disposed.get() && !pauseRequested && state == GameResourceDownloadState.DOWNLOADING && workerRunning.compareAndSet(false, true)) {
                val currentGeneration = generation.get()
                scheduleDownload(currentGeneration)
            }
        }
    }

    private fun scheduleDownload(workerGeneration: Long) {
        try {
            executor.execute { downloadLoop(workerGeneration) }
        } catch (_: RejectedExecutionException) {
            workerRunning.set(false)
        }
    }

    private fun canUseCurrentNetwork(): Boolean {
        val network = networkProvider()
        return network.connected && (network.wifi || allowMetered)
    }

    private fun refreshInspectionCounts(verifyChecksum: Boolean = false) {
        val inspections = urls.associateWith { url ->
            val expectedLength = expectedByteLengths[url]
            if (verifyChecksum || url in checksumRequiredUrls) {
                engine.inspect(url, expectedLength)
            } else {
                engine.inspectMetadata(url, expectedLength)
            }
        }
        validByteLengths.clear()
        inspections.forEach { (url, inspection) ->
            if (inspection.state == GameResourceInspectionState.DAMAGED) {
                checksumRequiredUrls.add(url)
            } else {
                checksumRequiredUrls.remove(url)
            }
            if (inspection.state == GameResourceInspectionState.VALID) {
                validByteLengths[url] = inspection.byteLength
            }
        }
        cachedBytesSnapshot = validByteLengths.values.sum()
        missingCount = inspections.values.count { it.state == GameResourceInspectionState.MISSING }
        damagedCount = inspections.values.count { it.state == GameResourceInspectionState.DAMAGED }
        outdatedCount = inspections.values.count { it.state == GameResourceInspectionState.OUTDATED }
        if (
            expectedByteLengths.isEmpty() &&
            urls.isNotEmpty() &&
            missingCount == 0 &&
            damagedCount == 0 &&
            outdatedCount == 0 &&
            targetBytes != cachedBytesSnapshot &&
            rewriteCurrentManifestTarget(cachedBytesSnapshot)
        ) {
            targetBytes = cachedBytesSnapshot
        }
    }

    private fun cachedManifestBytes(): Long = cachedBytesSnapshot

    private fun ensureManifestLoaded(refreshInspection: Boolean = false) {
        if (manifestLoaded) return
        manifestLoaded = loadManifest(manifestFile) || loadManifest(manifestBackupFile)
        if (manifestLoaded && refreshInspection) {
            refreshInspectionCounts()
            state = when {
                userPaused || networkPaused -> GameResourceDownloadState.PAUSED
                missingCount == 0 && damagedCount == 0 && outdatedCount == 0 && urls.isNotEmpty() ->
                    GameResourceDownloadState.COMPLETE
                else -> GameResourceDownloadState.IDLE
            }
        }
    }

    private fun loadManifest(file: File): Boolean {
        if (!file.isFile || file.length() == 0L || file.length() > MAX_MANIFEST_FILE_BYTES) return false
        return runCatching {
            val json = JSONObject(file.readText())
            if (json.optString("profile") != profile) return@runCatching false
            val array = json.optJSONArray("urls") ?: return@runCatching false
            val lengths = json.optJSONArray("expectedLengths")
            val loadedUrls = mutableListOf<String>()
            val loadedLengths = linkedMapOf<String, Long>()
            val seen = hashSetOf<String>()
            for (index in 0 until array.length()) {
                val url = array.getString(index)
                if (!GameResourceCacheRules.shouldCache(url, "GET") ||
                    (profile == "full" &&
                        !GameResourceCacheRules.isShareableStaticUri(java.net.URI(url))) ||
                    !seen.add(url)) continue
                loadedUrls += url
                if (lengths != null && index < lengths.length() && !lengths.isNull(index)) {
                    loadedLengths[url] = lengths.getLong(index).coerceAtLeast(0L)
                }
            }
            urls = loadedUrls
            expectedByteLengths = loadedLengths
            targetBytes = if (profile == "full" && loadedUrls.size != array.length() &&
                loadedLengths.isNotEmpty()) {
                loadedLengths.values.sum()
            } else {
                json.optLong("targetBytes", targetBytes).coerceAtLeast(0L)
            }
            true
        }.getOrDefault(false)
    }

    private fun rewriteCurrentManifestTarget(targetBytes: Long): Boolean = runCatching {
        val temporary = writeManifestTemporary(
            profile,
            urls,
            targetBytes,
            expectedByteLengths,
        )
        try {
            replaceManifestFile(temporary)
        } finally {
            temporary.delete()
        }
    }.isSuccess

    private fun writeManifestTemporary(
        profile: String,
        urls: List<String>,
        targetBytes: Long,
        expectedLengths: Map<String, Long>,
    ): File {
        manifestFile.parentFile?.mkdirs()
        val array = JSONArray()
        urls.forEach(array::put)
        val lengthArray = JSONArray()
        urls.forEach { url -> lengthArray.put(expectedLengths[url] ?: JSONObject.NULL) }
        val json = JSONObject()
            .put("version", 2)
            .put("profile", profile)
            .put("targetBytes", targetBytes)
            .put("urls", array)
            .put("expectedLengths", lengthArray)
        val parent = manifestFile.parentFile ?: File(".")
        val temporary = File.createTempFile("${manifestFile.name}.", ".tmp", parent)
        try {
            temporary.writeText(json.toString())
        } catch (error: Exception) {
            temporary.delete()
            throw error
        }
        return temporary
    }

    private fun installPreparedManifest(temporary: File) {
        if (manifestFile.isFile) {
            Files.copy(
                manifestFile.toPath(),
                manifestBackupFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        }
        replaceManifestFile(temporary)
    }

    private fun replaceManifestFile(temporary: File) {
        try {
            Files.move(
                temporary.toPath(),
                manifestFile.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (_: Exception) {
            Files.move(
                temporary.toPath(),
                manifestFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        }
    }

    private fun restorePreviousManifest(hadManifest: Boolean) {
        if (hadManifest && manifestBackupFile.isFile) {
            Files.copy(
                manifestBackupFile.toPath(),
                manifestFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        } else {
            manifestFile.delete()
        }
    }

    private fun snapshotState() = CoordinatorStateSnapshot(
        profile = profile,
        urls = urls,
        manifestLoaded = manifestLoaded,
        targetBytes = targetBytes,
        cachedBytesSnapshot = cachedBytesSnapshot,
        downloadedBytes = downloadedBytes,
        startedAt = startedAt,
        missingCount = missingCount,
        damagedCount = damagedCount,
        outdatedCount = outdatedCount,
        validByteLengths = validByteLengths,
        expectedByteLengths = expectedByteLengths,
        checksumRequiredUrls = checksumRequiredUrls,
        state = state,
        preloadAuthorized = preloadAuthorized,
        pauseRequested = pauseRequested,
        networkPaused = networkPaused,
        allowMetered = allowMetered,
        userPaused = userPaused,
    )

    private fun restoreState(snapshot: CoordinatorStateSnapshot) {
        profile = snapshot.profile
        urls = snapshot.urls
        manifestLoaded = snapshot.manifestLoaded
        targetBytes = snapshot.targetBytes
        cachedBytesSnapshot = snapshot.cachedBytesSnapshot
        downloadedBytes = snapshot.downloadedBytes
        startedAt = snapshot.startedAt
        missingCount = snapshot.missingCount
        damagedCount = snapshot.damagedCount
        outdatedCount = snapshot.outdatedCount
        validByteLengths = snapshot.validByteLengths
        expectedByteLengths = snapshot.expectedByteLengths
        checksumRequiredUrls = snapshot.checksumRequiredUrls
        state = snapshot.state
        preloadAuthorized = snapshot.preloadAuthorized
        pauseRequested = snapshot.pauseRequested
        networkPaused = snapshot.networkPaused
        allowMetered = snapshot.allowMetered
        userPaused = snapshot.userPaused
    }

    @Synchronized
    private fun persist() {
        stateFile.parentFile?.mkdirs()
        val json = JSONObject()
            .put("version", 2)
            .put("profile", profile)
            .put("targetBytes", targetBytes)
            .put("cachedBytes", cachedBytesSnapshot)
            .put("downloadedBytes", downloadedBytes)
            .put("missingCount", missingCount)
            .put("damagedCount", damagedCount)
            .put("outdatedCount", outdatedCount)
            .put("preloadAuthorized", preloadAuthorized)
            .put("userPaused", userPaused)
            .put("state", state.wireName)
        val temporary = File(stateFile.parentFile ?: return, "${stateFile.name}.tmp")
        temporary.writeText(json.toString())
        try {
            Files.move(temporary.toPath(), stateFile.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: Exception) {
            Files.move(temporary.toPath(), stateFile.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun restore() {
        if (!stateFile.isFile || stateFile.length() == 0L) return
        if (stateFile.length() > MAX_STATE_FILE_BYTES) {
            stateFile.delete()
            return
        }
        runCatching {
            val json = JSONObject(stateFile.readText())
            profile = json.optString("profile", "none")
            urls = emptyList()
            manifestLoaded = false
            targetBytes = json.optLong("targetBytes")
            cachedBytesSnapshot = json.optLong("cachedBytes")
            downloadedBytes = json.optLong("downloadedBytes")
            missingCount = json.optInt("missingCount", urls.size)
            damagedCount = json.optInt("damagedCount")
            outdatedCount = json.optInt("outdatedCount")
            preloadAuthorized = json.optBoolean("preloadAuthorized", false)
            userPaused = json.optBoolean("userPaused", false)
            val restored = json.optString("state")
            state = if (restored == GameResourceDownloadState.COMPLETE.wireName) {
                GameResourceDownloadState.COMPLETE
            } else {
                GameResourceDownloadState.PAUSED
            }
            pauseRequested = state == GameResourceDownloadState.PAUSED
            networkPaused = preloadAuthorized && !userPaused && state != GameResourceDownloadState.COMPLETE
        }
    }

    companion object {
        private const val MAX_STATE_FILE_BYTES = 256L * 1024L
        private const val MAX_MANIFEST_FILE_BYTES = 12L * 1024L * 1024L
        private const val MAX_MANIFEST_URL_CHARS = 8L * 1024L * 1024L
        private const val MAX_MANIFEST_ENTRIES = GameResourceCacheIndex.MAX_ENTRIES
    }

    private data class CoordinatorStateSnapshot(
        val profile: String,
        val urls: List<String>,
        val manifestLoaded: Boolean,
        val targetBytes: Long,
        val cachedBytesSnapshot: Long,
        val downloadedBytes: Long,
        val startedAt: Long,
        val missingCount: Int,
        val damagedCount: Int,
        val outdatedCount: Int,
        val validByteLengths: LinkedHashMap<String, Long>,
        val expectedByteLengths: LinkedHashMap<String, Long>,
        val checksumRequiredUrls: LinkedHashSet<String>,
        val state: GameResourceDownloadState,
        val preloadAuthorized: Boolean,
        val pauseRequested: Boolean,
        val networkPaused: Boolean,
        val allowMetered: Boolean,
        val userPaused: Boolean,
    )
}
