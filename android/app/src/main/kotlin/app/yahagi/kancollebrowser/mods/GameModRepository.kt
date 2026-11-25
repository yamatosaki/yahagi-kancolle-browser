package app.yahagi.kancollebrowser.mods

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.FilterOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.ByteArrayInputStream
import java.io.OutputStreamWriter
import java.net.URI
import java.util.UUID

private const val MAX_INDEX_BYTES = 64L * 1024 * 1024
private val coordinateArtKinds = setOf(
    "full", "full_dmg", "full_x2", "full_x2_dmg", "character_full", "character_full_dmg",
    "character_up", "character_up_dmg",
)

/** Private mod storage, durable drafts and immutable request sessions. */
class GameModRepository @JvmOverloads constructor(root: File, private val progress: GameModProgress? = null) {
    /** Applied software-image inventory. This never counts as a game resource request. */
    @Synchronized fun portraitSnapshot(): Map<String, Any?> = linkedMapOf(
        "token" to active.token,
        "resources" to active.portraits.values.map { selected ->
            linkedMapOf("id" to selected.resource.id, "path" to selected.resource.path)
        },
    )

    @Synchronized internal fun portraitToken(): String = active.token

    /**
     * Own a short package lease while copying immutable PNG bytes, then release it before returning.
     * A stale session, damaged image or missing file falls back in Flutter without changing game diagnostics.
     */
    fun readPortrait(token: String, resourceId: String): ByteArray? {
        val leased = synchronized(this) {
            if (active.token != token) return null
            val selected = active.portraits[resourceId] ?: return null
            val resource = selected.resource
            if (resource.sizeBytes !in 1..GameModPng.MAX_BYTES) return null
            try {
                val file = child("packages/${selected.packageId}/${resource.relativeFile}")
                if (!file.isFile || file.length() != resource.sizeBytes) return null
                val input = FileInputStream(file)
                leases[selected.packageId] = (leases[selected.packageId] ?: 0) + 1
                PortraitLease(selected.packageId, resource.sizeBytes.toInt(), input)
            } catch (_: Exception) { return null }
        }
        try {
            val bytes = ByteArray(leased.size)
            var position = 0
            while (position < bytes.size) {
                val count = leased.input.read(bytes, position, bytes.size - position)
                if (count <= 0) return null
                position += count
            }
            if (leased.input.read() != -1) return null
            GameModPng.validate(bytes)
            return synchronized(this) { if (active.token == token) bytes else null }
        } catch (_: Exception) {
            return null
        } finally {
            try { leased.input.close() } catch (_: IOException) { /* Software fallback is independent of game failures. */ }
            synchronized(this) {
                val count = (leases[leased.packageId] ?: 1) - 1
                if (count == 0) leases.remove(leased.packageId) else leases[leased.packageId] = count
                collectGarbage()
            }
        }
    }

    fun activeCoordinateSnapshot(): Map<String, Any?> = activeCoordinateSnapshot(kanxyVpnActive = false)

    fun activeCoordinateSnapshot(kanxyVpnActive: Boolean): Map<String,Any?> {
        val snapshot = synchronized(this) { active }
        val ships = snapshot.coordinateShips.mapValues { (_, ship) -> linkedMapOf(
            "graph" to ship.graph.mapValues { it.value.toList() }, "resourceIds" to ship.resourceIds.toList()) }
        val config = linkedMapOf<String, Any?>(
            "sessionId" to snapshot.id,
            "token" to snapshot.token,
            "ships" to ships,
            "questTranslations" to snapshot.questTranslations.mapValues { (_, translation) ->
                mapOf("title" to translation.title, "detail" to translation.detail)
            },
        )
        if (snapshot.displayTranslations.isNotEmpty()) {
            config[GameModDisplayTranslations.CONFIG_KEY] = snapshot.displayTranslations
        }
        if (kanxyVpnActive) {
            config["localArtShips"] = snapshot.winners.values.asSequence()
                .map { it.resource }
                .filter { it.kind == "ship" && it.path.split('/').getOrNull(3)?.let(coordinateArtKinds::contains) == true }
                .mapNotNull { it.groupId?.removePrefix("ship:")?.toIntOrNull() }
                .distinct().toList()
        }
        return config
    }
    @Synchronized fun recordCoordinateResult(sessionId: Long, token: String, resourceIds: List<String>, failure: String? = null) {
        val session = active
        if (session.id != sessionId || session.token != token) return
        resourceIds.distinct().filter { it in session.coordinateIds }.forEach { id ->
            if (failure == null) { session.hits.add(id); session.failures.remove(id) }
            else recordFailure(session, id, "coordinate_apply_failed")
        }
    }
    private val root = root.absoluteFile.normalize()
    private val canonicalRoot: File
    private val gson = Gson()
    private val staging = mutableMapOf<String, StagedImport>()
    private val leases = mutableMapOf<String, Int>()
    private val garbage = mutableSetOf<String>()
    private val pendingCleanup = mutableSetOf<String>()
    private var cleanupDiscoveryPending = true
    private var transaction: ApplyTransaction? = null
    private var state: State
    private var active: Session

    init {
        if ((!this.root.isDirectory && !this.root.mkdirs()) || isLink(this.root)) {
            throw GameModException("storage_error", "Cannot create private mod storage")
        }
        canonicalRoot = this.root.canonicalFile
        child("packages").mkdirs(); child("staging").mkdirs()
        state = readState()
        active = buildSession(state.applied, state.sessionId, state.appliedPackages)
        // Previews have process-local tokens; immutable packages survive process death.
        child("staging").listFiles()?.forEach(::deletePrivateTree)
        val retained = (state.packages + state.appliedPackages).map { it.id }.toSet()
        child("packages").listFiles()?.filter { it.name !in retained }?.forEach(::deletePrivateTree)
        canonicalRoot.listFiles()?.filter { it.name.startsWith("state-") && it.name.endsWith(".tmp") }?.forEach(::deletePrivateTree)
        collectGarbage(discover = true)
    }

    /** ZIP validation never holds the monitor needed by status and request interception. */
    fun preflight(input: InputStream, sourceName: String): Map<String, Any?> = preflightChecked(input, sourceName, false)

    fun preflightUpdate(input: InputStream, sourceName: String, id: String): Map<String, Any?> {
        val base = synchronized(this) {
            requireIdle()
            state.packages.firstOrNull { it.id == id && !it.pendingRemoval }
                ?: throw GameModException("invalid_config", "Choose an existing mod package to update")
        }
        return preflightChecked(input, sourceName, false, base)
    }

    /** Library archives are generated locally from bounded, checked resource trees. */
    fun preflightLibrary(input: InputStream, sourceName: String): Map<String, Any?> = preflightChecked(input, sourceName, true)

    private fun preflightChecked(input: InputStream, sourceName: String, library: Boolean, updateBase: ModPackage? = null): Map<String, Any?> {
        progress?.update(phase = "validate", currentPackage = sourceName)
        val token = UUID.randomUUID().toString()
        val directory = child("staging/$token")
        synchronized(this) {
            if (staging.size >= 4) throw GameModException("busy", "Discard an existing import preview first")
            if (!directory.mkdirs()) throw GameModException("storage_error", "Cannot prepare mod import")
        }
        try {
            val parsed = input.use {
                val archive = GameModArchive(progress)
                if (library) archive.unpackLibrary(it, sourceName, directory) else archive.unpack(it, sourceName, directory)
            }
            synchronized(this) { staging[token] = StagedImport(directory, parsed, updateBase) }
            val preview = linkedMapOf<String, Any?>("token" to token, "name" to parsed.name,
                "resourceCount" to parsed.resources.size, "supportedCount" to parsed.resources.count { it.supported },
                "unsupportedCount" to parsed.resources.count { !it.supported }, "sourceFileCount" to parsed.resources.sumOf { it.sourcePaths.size },
                "warnings" to parsed.warnings.toList())
            if (updateBase != null) {
                val oldPaths = updateBase.resources.map { it.path }.toSet()
                val newPaths = parsed.resources.map { it.path }.toSet()
                preview["packageName"] = updateBase.name
                preview["addedCount"] = (newPaths - oldPaths).size
                preview["removedCount"] = (oldPaths - newPaths).size
            }
            return preview
        } catch (error: Exception) {
            deletePrivateTree(directory)
            if (error is GameModException) throw error
            throw GameModException("storage_error", "Cannot read mod archive: ${error.message ?: "read failed"}")
        }
    }

    @Synchronized fun commitImport(token: String): Map<String, Any?> {
        requireIdle()
        val staged = staging[token] ?: throw GameModException("invalid_token", "Import preview has expired")
        if (staged.updateBase != null) throw GameModException("invalid_token", "Use the mod library to confirm this update")
        progress?.update(phase = "import", currentPackage = staged.result.name)
        val id = UUID.randomUUID().toString()
        val destination = child("packages/$id")
        val resources = staged.result.resources.mapIndexed { index, resource ->
            val file = inside(staged.directory, resource.relativeFile)
            Resource("$id:$index", resource.path, resource.kind, resource.label, resource.supported,
                resource.reason, resource.groupId, resource.relativeFile, file.length(),
                resource.sourcePaths.toList(), resource.coordinateShipId, resource.coordinateGraph.mapValues { it.value.toList() })
        }
        val entry = ModPackage(id, staged.result.name, staged.result.sizeBytes,
            System.currentTimeMillis(), resources, staged.result.warnings.toList())
        try {
            move(staged.directory, destination)
            val next = state.copy(packages = state.packages + entry,
                draft = state.draft.copy(order = state.draft.order + id,
                    enabledResources = state.draft.enabledResources + resources.filter { it.supported }.map { it.id }))
            persist(next); state = next; staging.remove(token)
            return packageMap(entry)
        } catch (error: Exception) {
            if (destination.exists() && !staged.directory.exists()) {
                try { move(destination, staged.directory) } catch (_: Exception) { deletePrivateTree(destination) }
            }
            if (error is GameModException) throw error
            throw GameModException("storage_error", "Cannot save imported mod")
        }
    }

    /** Accept a checked public-library revision without overwriting any applied resource. */
    @Synchronized fun commitLibraryImport(token: String, id: String): Map<String, Any?> = commitLibraryImport(token, id, "")

    @Synchronized fun commitLibraryImport(token: String, id: String, sourceFingerprint: String): Map<String, Any?> {
        requireIdle()
        if (!Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}").matches(id) ||
            sourceFingerprint.length > 256 || sourceFingerprint.any { it.code < 32 }) {
            throw GameModException("invalid_config", "Invalid library package identity")
        }
        val staged = staging[token] ?: throw GameModException("invalid_token", "Import preview has expired")
        progress?.update(phase = "import", currentPackage = staged.result.name)
        val existing = state.packages.firstOrNull { it.id == id }
        val updateBase = staged.updateBase
        val original = state.zipUpdateOriginals.firstOrNull { it.id == id }
        if (updateBase != null && (updateBase.id != id || updateBase != existing)) {
            throw GameModException("invalid_token", "The package changed after preview; choose the ZIP again")
        }
        if (updateBase == null && original != null) {
            throw GameModException("library_changed", "Apply or cancel the pending ZIP update before replacing this package")
        }
        if (existing?.pendingRemoval == true) throw GameModException("invalid_config", "Cancel pending removal before updating this package")
        val oldResources = existing?.resources.orEmpty().associateBy { it.path }
        val revision = "revisions/${UUID.randomUUID()}"
        val directory = child("packages/$id")
        val revisions = child("packages/$id/revisions")
        if ((!directory.isDirectory && !directory.mkdirs()) || (!revisions.isDirectory && !revisions.mkdir())) {
            throw GameModException("storage_error", "Cannot create immutable mod revision")
        }
        val destination = child("packages/$id/$revision")
        val resources = staged.result.resources.map { resource ->
            val resourceId = oldResources[resource.path]?.id ?: "$id:${UUID.nameUUIDFromBytes(resource.path.toByteArray(Charsets.UTF_8))}"
            Resource(resourceId, resource.path, resource.kind, resource.label, resource.supported, resource.reason,
                resource.groupId, "$revision/${resource.relativeFile}", inside(staged.directory, resource.relativeFile).length(),
                resource.sourcePaths.toList(), resource.coordinateShipId, resource.coordinateGraph.mapValues { it.value.toList() })
        }
        val entry = ModPackage(id, staged.result.name, staged.result.sizeBytes, existing?.importedAt ?: System.currentTimeMillis(),
            resources, staged.result.warnings.toList(), sourceFingerprint = sourceFingerprint)
        try {
            move(staged.directory, destination)
            val packages = if (existing == null) state.packages + entry else state.packages.map { if (it.id == id) entry else it }
            val available = packages.filterNot { it.pendingRemoval }
            val supported = available.flatMap { it.resources }.filter { it.supported }.map { it.id }.toSet()
            val draft = state.draft.withAvailablePackages(available).let {
                val retained = it.enabledResources.filter { resourceId -> resourceId in supported }
                val added = resources.filter { resource ->
                    resource.supported && (existing == null || (updateBase != null && oldResources[resource.path]?.supported != true))
                }.map { resource -> resource.id }
                it.copy(enabledResources = (retained + added).distinct())
            }
            val originals = if (updateBase != null && original == null) state.zipUpdateOriginals + updateBase else state.zipUpdateOriginals
            val next = state.copy(packages = packages, draft = draft, zipUpdateOriginals = originals)
            persist(next); state = next; staging.remove(token)
            // A housekeeping failure must not move the newly committed revision back to staging.
            // This import can only obsolete revisions belonging to its own package.
            // Avoid rediscovering every package for every item in a large scan batch.
            pendingCleanup.add(id)
            try { collectGarbage() } catch (_: Exception) { /* Retry on the next lease release or startup. */ }
            return packageMap(entry, pendingUpdate = updateBase != null)
        } catch (error: Exception) {
            if (destination.exists() && !staged.directory.exists()) {
                try { move(destination, staged.directory) } catch (_: Exception) { deletePrivateTree(destination) }
            }
            if (existing == null && directory.listFiles()?.all { it.name == "revisions" && it.listFiles()?.isEmpty() == true } == true) deletePrivateTree(directory)
            if (error is GameModException) throw error
            throw GameModException("storage_error", "Cannot save library mod revision")
        }
    }

    @Synchronized internal fun preflightUpdateTarget(token: String): ZipUpdateTarget? {
        requireIdle()
        val staged = staging[token] ?: throw GameModException("invalid_token", "Import preview has expired")
        val base = staged.updateBase ?: return null
        if (state.packages.none { it == base }) throw GameModException("invalid_token", "The package changed after preview; choose the ZIP again")
        if (staged.result.resources.none { it.supported }) {
            throw GameModException("unsupported_archive", "The ZIP contains no supported game resources")
        }
        val original = state.zipUpdateOriginals.firstOrNull { it.id == base.id } ?: base
        return ZipUpdateTarget(base.id, base.name, original.sourceFingerprint, base.sourceFingerprint)
    }

    @Synchronized internal fun zipUpdates(published: Boolean): List<ZipUpdateTarget> {
        val packages = state.packages.associateBy { it.id }
        val applied = state.appliedPackages.associateBy { it.id }
        return state.zipUpdateOriginals.mapNotNull { original ->
            val current = packages[original.id] ?: return@mapNotNull null
            if ((current == applied[current.id]) != published || current.pendingRemoval) return@mapNotNull null
            ZipUpdateTarget(current.id, current.name, original.sourceFingerprint, current.sourceFingerprint)
        }
    }

    @Synchronized internal fun finishZipUpdateSync(ids: Set<String>) {
        requireIdle()
        if (ids.isEmpty()) return
        val next = state.copy(zipUpdateOriginals = state.zipUpdateOriginals.filterNot { it.id in ids })
        persist(next); state = next
        pendingCleanup.addAll(ids)
        collectGarbage()
    }

    /** Migration adds a library link without changing the applied revision or pending choices. */
    @Synchronized fun attachLibraryFingerprint(id: String, sourceFingerprint: String) {
        requireIdle()
        if (sourceFingerprint.length > 256 || sourceFingerprint.any { it.code < 32 }) throw GameModException("invalid_config", "Invalid library fingerprint")
        val entry = state.packages.firstOrNull { it.id == id } ?: throw GameModException("invalid_config", "Unknown mod package")
        val packages = state.packages.map { if (it.id == id) it.copy(sourceFingerprint = sourceFingerprint) else it }
        val applied = state.appliedPackages.map { if (it.id == id && it.resources == entry.resources) it.copy(sourceFingerprint = sourceFingerprint) else it }
        val next = state.copy(packages = packages, appliedPackages = applied)
        persist(next); state = next
    }

    /** Export last successful choices by canonical paths, independent of archive entry order. */
    @Synchronized fun exportAppliedConfiguration(): Map<String, Any?> {
        val selected = state.applied.enabledResources.toSet()
        return linkedMapOf("version" to 1, "schemaVersion" to 1, "master" to state.applied.master,
            "order" to state.applied.order.toList(), "enabledPackages" to state.applied.enabledPackages.toList(),
            "enabledResources" to state.appliedPackages.associate { entry -> entry.id to entry.resources.filter { it.id in selected }.map { it.path } })
    }

    /** Restored library settings are a draft until the normal verified apply succeeds. */
    @Synchronized fun restoreLibraryConfiguration(value: Map<*, *>) {
        requireIdle()
        fun invalid(): Nothing = throw GameModException("invalid_config", "Invalid saved library configuration")
        fun strings(list: Any?): List<String> {
            val items = list as? List<*> ?: invalid()
            if (items.any { it !is String } || items.distinct().size != items.size) invalid()
            return items.filterIsInstance<String>()
        }
        val version = value["schemaVersion"] ?: value["version"]
        if (version !is Number || version.toDouble() != 1.0) invalid()
        val master = value["master"] as? Boolean ?: invalid()
        val savedOrder = strings(value["order"])
        val savedEnabled = strings(value["enabledPackages"])
        val savedResources = value["enabledResources"] as? Map<*, *> ?: invalid()
        if (savedResources.keys.any { it !is String }) invalid()
        val paths = savedResources.mapValues { strings(it.value).toSet() }
        val packages = state.packages.filterNot { it.pendingRemoval }
        val ids = packages.map { it.id }.toSet()
        val order = savedOrder.filter { it in ids }.let { saved -> saved + packages.map { it.id }.filterNot { it in saved } }
        // A missing package entry keeps import defaults; an explicit empty entry stays empty.
        val importedSelections = state.draft.enabledResources.toSet()
        val resources = packages.flatMap { entry -> entry.resources.filter { resource ->
            resource.supported && if (paths.containsKey(entry.id)) resource.path in paths[entry.id].orEmpty()
                else resource.id in importedSelections
        }.map { it.id } }
        val next = state.copy(draft = Config(master, order, savedEnabled.filter { it in ids }, resources))
        persist(next); state = next
    }

    /** Materialize a checked import in a caller-owned empty directory before saving it to SAF. */
    @Synchronized fun exportPreflightTree(token: String, directory: File): Map<String, Any?> {
        val staged = staging[token] ?: throw GameModException("invalid_token", "Import preview has expired")
        progress?.startPackage("save", staged.result.name, 0, 1)
        val resources = staged.result.resources.mapIndexed { index, resource ->
            Resource("preview:$index", resource.path, resource.kind, resource.label, resource.supported, resource.reason,
                resource.groupId, resource.relativeFile, inside(staged.directory, resource.relativeFile).length(),
                resource.sourcePaths, resource.coordinateShipId, resource.coordinateGraph)
        }
        val warnings = exportTree(resources, staged.directory, directory, staged.result.warnings)
        return linkedMapOf("name" to staged.result.name, "warnings" to warnings)
    }

    /** Editable resource paths preserve unsupported files; runtime file names remain private. */
    @JvmOverloads fun exportPackageTree(id: String, directory: File, originalBeforeZipUpdate: Boolean = false): Map<String, Any?> {
        val entry = synchronized(this) {
            val original = if (originalBeforeZipUpdate) state.zipUpdateOriginals.firstOrNull { it.id == id } else null
            val entry = original ?: state.packages.firstOrNull { it.id == id }
                ?: throw GameModException("invalid_config", "Unknown mod package")
            leases[id] = (leases[id] ?: 0) + 1
            entry
        }
        try {
            val warnings = exportTree(entry.resources, child("packages/$id"), directory, entry.warnings)
            return packageMap(entry) + ("warnings" to warnings)
        } finally {
            synchronized(this) {
                val count = (leases[id] ?: 1) - 1
                if (count == 0) leases.remove(id) else leases[id] = count
                collectGarbage()
            }
        }
    }

    private fun exportTree(resources: List<Resource>, source: File, directory: File, originalWarnings: List<String>): List<String> {
        if (!directory.isDirectory || isLink(directory) || directory.listFiles()?.isEmpty() != true) throw GameModException("storage_error", "Export directory must be empty")
        val exportRoot = directory.canonicalFile
        val used = mutableSetOf<String>()
        val warnings = originalWarnings.toMutableSet()
        var completedBytes = 0L
        progress?.update(phase = "save")
        progress?.files(0, resources.size, null, 0, null)
        resources.forEachIndexed { index, resource ->
            progress?.files(index, resources.size, resource.path, completedBytes, null)
            val coordinate = resource.kind == "coordinates" && resource.coordinateShipId != null
            val path = when {
                coordinate -> "kcs2/resources/ship/config/${resource.coordinateShipId.padStart(4, '0')}.config.json"
                resource.kind == "coordinates" -> resource.sourcePaths.firstOrNull()?.replace('\\', '/')?.removePrefix("cache/")
                    ?.replace(Regex("\\.hack\\.([A-Za-z0-9]+)$"), ".$1") ?: resource.path
                resource.kind == "audio" && resource.relativeFile.endsWith(".wav", ignoreCase = true) && resource.path.endsWith(".mp3") -> resource.path.dropLast(4) + ".wav"
                else -> resource.path
            }
            if (path.isEmpty() || path.startsWith('/') || '\\' in path || ':' in path || path.split('/').any { it.isEmpty() || it == "." || it == ".." }) throw GameModException("storage_error", "Unsafe exported resource path")
            if (!used.add(path)) throw GameModException("duplicate_resource", "Exported resource paths conflict")
            val target = File(exportRoot, path)
            if (!beneath(target.canonicalFile, exportRoot)) throw GameModException("storage_error", "Export path escaped output directory")
            val parent = target.parentFile ?: throw GameModException("storage_error", "Exported resource has no parent directory")
            if (!parent.isDirectory && !parent.mkdirs()) throw GameModException("storage_error", "Cannot create editable resource folders")
            if (coordinate) {
                target.writeText(gson.toJson(mapOf("api_mst_shipgraph" to resource.coordinateGraph)), Charsets.UTF_8)
                warnings.add("coordinate_sources_normalized")
            } else {
                val file = inside(source, resource.relativeFile)
                if (!file.isFile || file.length() != resource.sizeBytes) throw GameModException("storage_error", "A private mod resource is missing or changed")
                file.inputStream().use { input -> target.outputStream().use { input.copyTo(it) } }
            }
            completedBytes += target.length()
            progress?.files(index + 1, resources.size, resource.path, completedBytes, null)
        }
        return warnings.toList()
    }

    fun discardImport(token: String) {
        val staged = synchronized(this) { staging.remove(token) } ?: return
        deletePrivateTree(staged.directory)
    }

    fun status(): Map<String, Any?> {
        val captured = synchronized(this) { StatusSnapshot(state, active, active.hits.toList(), active.partialHits.toList(), active.failures.toMap()) }
        val current = captured.state
        val updateIds = current.zipUpdateOriginals.map { it.id }.toSet()
        val applied = current.appliedPackages.associateBy { it.id }
        // Package metadata is immutable. Encoding a large inventory must not delay publication
        // or request interception while the UI polls completed-response counters.
        return linkedMapOf(
            "packages" to current.packages.map { packageMap(it, it.id in updateIds && it != applied[it.id]) },
            "draft" to current.draft.toMap(), "applied" to current.applied.toMap(),
            "pending" to isPending(current), "sessionId" to captured.session.id,
            "winners" to winners(current.draft, current.packages.filterNot { it.pendingRemoval }).mapValues { it.value.resource.id },
            "activeWinners" to captured.session.winners.mapValues { it.value.resource.id },
            "hits" to captured.hits, "partialHits" to captured.partialHits, "failures" to captured.failures)
    }

    @Synchronized fun saveDraft(config: Map<*, *>) {
        requireIdle()
        val next = state.copy(draft = parseConfig(config, state.packages.filterNot { it.pendingRemoval }))
        persist(next); state = next
    }

    /** Restore the last applied choices; imported files and the live request session stay intact. */
    @Synchronized fun cancelChanges() {
        requireIdle()
        val applied = state.appliedPackages.associateBy { it.id }
        val originals = state.zipUpdateOriginals.associateBy { it.id }
        val packages = state.packages.map { applied[it.id] ?: originals[it.id] ?: it.copy(pendingRemoval = false) }
        // Keep the source sync receipt only for an already published ZIP revision.
        val published = state.packages.filter { it.copy(pendingRemoval = false) == applied[it.id] }.map { it.id }.toSet()
        val next = state.copy(packages = packages, draft = state.applied.withAvailablePackages(packages),
            zipUpdateOriginals = state.zipUpdateOriginals.filter { it.id in published })
        persist(next); state = next
        collectGarbage(discover = true)
    }

    /** Run on IO: compile/serialize/fsync without blocking active request/status readers. */
    fun prepareApply(): GameModApplyToken {
        val reservation = synchronized(this) {
            requireIdle()
            ApplyTransaction(GameModApplyToken(UUID.randomUUID().toString()), state, active).also { transaction = it }
        }
        var temporary: File? = null
        try {
            val before = reservation.before
            val appliedPackages = before.packages.filterNot { it.pendingRemoval }
            val appliedIds = appliedPackages.map { it.id }.toSet()
            val next = before.copy(applied = before.draft, appliedPackages = appliedPackages, sessionId = before.sessionId + 1,
                zipUpdateOriginals = before.zipUpdateOriginals.filter { it.id in appliedIds })
            val session = buildSession(next.applied, next.sessionId, appliedPackages)
            temporary = writeStateTemporary(next)
            synchronized(this) {
                if (transaction !== reservation) throw GameModException("invalid_token", "Apply preparation was cancelled")
                reservation.prepared = PreparedApply(next, session, temporary)
            }
            return reservation.token
        } catch (error: Exception) {
            temporary?.delete()
            synchronized(this) { if (transaction === reservation) transaction = null }
            throw error
        }
    }

    /** Publish the prepared session and report whether an effective game font changed. */
    @Synchronized fun publishApply(token: GameModApplyToken): Boolean {
        val current = requireTransaction(token)
        if (current.published) throw GameModException("invalid_token", "Apply transaction was already published")
        val prepared = current.prepared ?: throw GameModException("busy", "Apply preparation is still in progress")
        val fontsChanged = GameModStaticAssets.fontPaths.any { path ->
            current.session.winners[path] != prepared.session.winners[path]
        }
        try { move(prepared.file, child("state.json")) }
        catch (error: Exception) { throw GameModException("storage_error", "Cannot publish prepared mod configuration") }
        state = prepared.next; active = prepared.session; current.published = true
        return fontsChanged
    }

    /** Run on IO after verification fails. This never rolls back a published session. */
    fun cancelPreparedApply(token: GameModApplyToken) {
        val file = synchronized(this) {
            val current = transaction?.takeIf { it.token === token } ?: return
            if (current.published) return
            transaction = null
            current.prepared?.file
        }
        file?.delete()
    }

    /** Convenience for non-UI callers. Android bridge uses prepareApply/publishApply separately. */
    fun applyDraft(): GameModApplyToken {
        val token = prepareApply()
        try { publishApply(token); return token }
        catch (error: Exception) { cancelPreparedApply(token); throw error }
    }

    @Synchronized fun rollbackApply(token: GameModApplyToken) {
        val previous = requireTransaction(token)
        if (!previous.published) { cancelPreparedApply(token); return }
        persist(previous.before)
        state = previous.before; active = previous.session; transaction = null
        cleanupDiscoveryPending = true
    }

    @Synchronized fun finishApply(token: GameModApplyToken) {
        if (!requireTransaction(token).published) throw GameModException("invalid_token", "Apply transaction is not published")
        val removed = state.packages.filter { it.pendingRemoval }.map { it.id }
        if (removed.isEmpty()) { transaction = null; collectGarbage(discover = true); return }
        val next = state.copy(packages = state.packages.filterNot { it.pendingRemoval })
        // Publication already succeeded. A cleanup failure retains the pending metadata/files,
        // but must release the reservation so another apply can retry housekeeping.
        try { persist(next) } finally { transaction = null }
        state = next
        garbage.addAll(removed); collectGarbage(discover = true)
    }

    /** A failed write-ahead public journal must retain durable removal intent for retry. */
    @Synchronized fun deferApplyCleanup(token: GameModApplyToken) {
        if (!requireTransaction(token).published) throw GameModException("invalid_token", "Apply transaction is not published")
        // Publication already persisted pendingRemoval metadata and the new applied snapshot.
        // Release the mutation reservation while leaving those files and identities intact.
        transaction = null
        cleanupDiscoveryPending = true
    }

    /** Existing requests and the current page retain their immutable files until apply succeeds. */
    @Synchronized fun removePackage(id: String) {
        requireIdle()
        if (state.packages.none { it.id == id }) throw GameModException("invalid_config", "Unknown mod package")
        val packages = state.packages.map { if (it.id == id) it.copy(pendingRemoval = true) else it }
        val next = state.copy(packages = packages, draft = state.draft.restrictTo(packages.filterNot { it.pendingRemoval }))
        persist(next); state = next
    }

    @Synchronized fun resetAll() {
        requireIdle()
        val next = state.copy(packages = state.packages.map { it.copy(pendingRemoval = true) }, draft = Config())
        persist(next); state = next
    }

    @Synchronized fun hasActiveOrPending(): Boolean = active.winners.isNotEmpty() ||
        state.applied.master || state.draft.master || isPending()

    /** Null sends the request through the normal cache/network chain. */
    @Synchronized fun openResource(url: String, method: String, headers: Map<String, String>): GameModResponse? {
        if (method != "GET" && method != "HEAD") return null
        val session = active
        val selected = session.winners[targetPath(url) ?: return null] ?: return null
        val resource = selected.resource
        val audio = resource.kind == "audio"
        val rangeHeaders = headers.filterKeys { it.equals("Range", true) }.values
        if (!audio && (method != "GET" || rangeHeaders.isNotEmpty())) return null
        if (resource.id in session.failures) return null
        val file = try {
            val file = child("packages/${selected.packageId}/${resource.relativeFile}")
            if (!file.isFile || file.length() != resource.sizeBytes) throw IOException("Imported resource is missing or changed")
            file
        } catch (error: Exception) {
            recordFailure(session, resource.id, error.message ?: "Cannot open imported resource"); return null
        }
        val range = if (audio && method == "GET" && headers.keys.none { it.equals("If-Range", true) })
            audioByteRange(rangeHeaders.singleOrNull(), resource.sizeBytes) else null
        val mime = try {
            when {
                audio && resource.relativeFile.endsWith(".wav", ignoreCase = true) -> "audio/wav"
                audio -> "audio/mpeg"
                GameModStaticAssets.isJpegPath(resource.path) -> "image/jpeg"
                GameModStaticAssets.isFontPath(resource.path) -> GameModStaticAssets.fontMime(file)
                else -> "image/png"
            }
        } catch (error: Exception) {
            recordFailure(session, resource.id, error.message ?: "Cannot open imported resource")
            return null
        }
        val responseHeaders = linkedMapOf("Content-Type" to mime,
            "Content-Length" to resource.sizeBytes.toString(), "Cache-Control" to "no-store",
            "Accept-Ranges" to if (audio) "bytes" else "none", "Access-Control-Allow-Origin" to "*")
        if (!audio) responseHeaders["X-Content-Type-Options"] = "nosniff"
        if (range?.unsatisfiable == true) {
            responseHeaders["Content-Length"] = "0"
            responseHeaders["Content-Range"] = "bytes */${resource.sizeBytes}"
            return GameModResponse(mime, 416, "Range Not Satisfiable", responseHeaders, ByteArrayInputStream(byteArrayOf()))
        }
        // Range is GET-only. HEAD returns metadata for the full representation without a lease.
        if (method == "HEAD") return GameModResponse(mime, 200, "OK", responseHeaders, ByteArrayInputStream(byteArrayOf()))
        val first = range?.first ?: 0L
        val last = range?.last ?: resource.sizeBytes - 1
        val expected = last - first + 1
        val stream = try {
            FileInputStream(file).also { opened ->
                try { if (first > 0) opened.channel.position(first) }
                catch (error: Exception) { opened.close(); throw error }
            }
        } catch (error: Exception) {
            recordFailure(session, resource.id, error.message ?: "Cannot open imported resource"); return null
        }
        leases[selected.packageId] = (leases[selected.packageId] ?: 0) + 1
        val counted = CompletionStream(stream, expected,
            completed = { synchronized(this) {
                if (audio) recordAudioCoverage(session, resource.id, first..last, resource.sizeBytes)
                else session.hits.add(resource.id)
            } },
            progress = { if (audio) synchronized(this) { session.partialHits.add(resource.id) } },
            failed = { message -> synchronized(this) { recordFailure(session, resource.id, message) } },
            closed = { synchronized(this) {
                val count = (leases[selected.packageId] ?: 1) - 1
                if (count == 0) leases.remove(selected.packageId) else leases[selected.packageId] = count
                collectGarbage()
            } })
        responseHeaders["Content-Length"] = expected.toString()
        if (range != null) responseHeaders["Content-Range"] = "bytes $first-$last/${resource.sizeBytes}"
        return GameModResponse(mime, if (range == null) 200 else 206,
            if (range == null) "OK" else "Partial Content", responseHeaders, counted)
    }

    private fun requireIdle() {
        if (transaction != null) throw GameModException("busy", "A mod apply is still in progress")
    }
    private fun requireTransaction(token: GameModApplyToken): ApplyTransaction = transaction?.takeIf { it.token === token }
        ?: throw GameModException("invalid_token", "Apply transaction has expired")
    private fun recordFailure(session: Session, id: String, message: String) {
        session.failures[id] = message.take(300)
    }
    private fun recordAudioCoverage(session: Session, id: String, completed: LongRange, size: Long) {
        if (id in session.hits) return
        val ranges = (session.audioCoverage[id].orEmpty() + listOf(completed)).sortedBy { it.first }
        val merged = mutableListOf<LongRange>()
        ranges.forEach { range ->
            val previous = merged.lastOrNull()
            if (previous != null && range.first <= previous.last + 1) merged[merged.lastIndex] = previous.first..maxOf(previous.last, range.last)
            else merged.add(range)
        }
        if (merged.size == 1 && merged[0].first == 0L && merged[0].last == size - 1) {
            session.hits.add(id); session.audioCoverage.remove(id)
        } else session.audioCoverage[id] = merged
    }
    private fun isPending(snapshot: State = state): Boolean {
        val applied = snapshot.appliedPackages.associateBy { it.id }
        val updating = snapshot.zipUpdateOriginals.map { it.id }.toSet()
        return snapshot.packages.any { entry ->
            val active = applied[entry.id]
            entry.pendingRemoval || (active != entry && (active != null || entry.id in updating))
        } || !snapshot.draft.sameAs(snapshot.applied.withAvailablePackages(snapshot.packages))
    }
    private fun winners(config: Config, packages: List<ModPackage>): Map<String, Selected> {
        if (!config.master) return emptyMap()
        val byId = packages.associateBy { it.id }
        val enabledPackages = config.enabledPackages.toHashSet()
        val enabledResources = config.enabledResources.toHashSet()
        val result = linkedMapOf<String, Selected>()
        config.order.forEach { id ->
            val entry = byId[id] ?: return@forEach
            if (id in enabledPackages) entry.resources.forEach { r ->
                if (r.supported && r.id in enabledResources) resourceTargets(r).forEach { target ->
                    if (target !in result) result[target] = Selected(id, r)
                }
            }
        }
        return result
    }
    private fun buildSession(config: Config, id: Long, packages: List<ModPackage>): Session {
        val selected = winners(config, packages)
        val coordinateFields = linkedMapOf<String, MutableMap<String, List<Int>>>()
        val coordinateIds = linkedMapOf<String, MutableSet<String>>()
        selected.forEach { (target, source) ->
            val resource = source.resource
            val shipId = resource.coordinateShipId
            if (resource.kind == "coordinates" && shipId != null) {
                val field = target.substringAfterLast('/')
                coordinateFields.getOrPut(shipId) { linkedMapOf() }[field] = resource.coordinateGraph.getValue(field).toList()
                coordinateIds.getOrPut(shipId) { linkedSetOf() }.add(resource.id)
            }
        }
        val ships = coordinateFields.mapValues { (shipId, graph) -> CoordinateShip(graph.toMap(), coordinateIds.getValue(shipId).toList()) }
        val questTranslations = selected[GameModQuestTranslations.PATH]?.let { source ->
            readQuestTranslations(source.packageId, source.resource.relativeFile, source.resource.sizeBytes)
        }.orEmpty()
        return Session(id, selected, ships, questTranslations, readDisplayTranslations(selected))
    }

    private fun readDisplayTranslations(selected: Map<String, Selected>): Map<String, Any> {
        val tables = GameModDisplayTranslations.Category.entries.associateWith { linkedMapOf<String, Any>() }
        var bytes = 0L
        var tableCount = 0
        var regexCount = 0
        for ((path, source) in selected) {
            val table = GameModDisplayTranslations.table(path) ?: continue
            val resource = source.resource
            if (resource.kind != table.kind) continue
            val content = readDisplayTable(table, source.packageId, resource.relativeFile, resource.sizeBytes) ?: continue
            bytes += resource.sizeBytes
            tableCount++
            if (table.category == GameModDisplayTranslations.Category.REGEX) regexCount += content.count
            if (bytes > GameModDisplayTranslations.MAX_TOTAL_BYTES || tableCount > GameModDisplayTranslations.MAX_TABLES ||
                regexCount > GameModDisplayTranslations.MAX_TOTAL_REGEX) {
                throw GameModException("quota_exceeded", "Selected display translation tables exceed the session quota")
            }
            tables.getValue(table.category)[table.name] = content.data
        }
        if (tableCount == 0) return emptyMap()
        return tables.entries.associate { (category, content) -> category.configKey to content }
    }

    private fun readDisplayTable(table: GameModDisplayTranslations.Table, packageId: String, relativeFile: String,
        sizeBytes: Long): GameModDisplayTranslations.Content? = try {
        val file = child("packages/$packageId/$relativeFile")
        if (file.length() == sizeBytes) GameModDisplayTranslations.parse(file, table) else null
    } catch (_: GameModException) {
        null
    }

    private fun readQuestTranslations(packageId: String, relativeFile: String, sizeBytes: Long):
        Map<String, GameModQuestTranslations.Translation>? = try {
        val file = child("packages/$packageId/$relativeFile")
        if (file.length() == sizeBytes) GameModQuestTranslations.parse(file) else null
    } catch (_: GameModException) {
        null
    }

    private fun resourceTargets(resource: Resource): List<String> = if (resource.kind == "coordinates" && resource.coordinateShipId != null)
        resource.coordinateGraph.keys.map { "${resource.path}/$it" } else listOf(resource.path)
    private fun packageMap(entry: ModPackage, pendingUpdate: Boolean = false): Map<String, Any?> = linkedMapOf(
        "id" to entry.id, "name" to entry.name, "sizeBytes" to entry.sizeBytes, "importedAt" to entry.importedAt,
        "sourceFileCount" to entry.resources.sumOf { it.sourcePaths.size },
        "resources" to entry.resources.map { r -> linkedMapOf("id" to r.id, "path" to r.path, "kind" to r.kind,
            "label" to r.label, "supported" to r.supported, "reason" to r.reason, "groupId" to r.groupId,
            "sourcePaths" to r.sourcePaths.toList(), "targetPaths" to resourceTargets(r)) },
        "warnings" to entry.warnings.toList(), "pendingRemoval" to entry.pendingRemoval, "pendingUpdate" to pendingUpdate,
        "sourceFingerprint" to entry.sourceFingerprint)

    private fun parseConfig(value: Map<*, *>, packages: List<ModPackage>): Config {
        fun invalid(): Nothing = throw GameModException("invalid_config", "Mod selection contains invalid or unsupported resources")
        fun strings(key: String): List<String> {
            val list = value[key] as? List<*> ?: invalid()
            if (list.any { it !is String } || list.distinct().size != list.size) invalid()
            return list.filterIsInstance<String>()
        }
        val master = value["master"] as? Boolean ?: invalid()
        val order = strings("order"); val enabledPackages = strings("enabledPackages"); val enabledResources = strings("enabledResources")
        val allPackages = packages.map { it.id }.toSet()
        val supported = packages.flatMap { it.resources }.filter { it.supported }.map { it.id }.toSet()
        if (order.toSet() != allPackages || !allPackages.containsAll(enabledPackages) || !supported.containsAll(enabledResources)) invalid()
        return Config(master, order, enabledPackages, enabledResources)
    }

    private fun targetPath(url: String): String? = try {
        val uri = URI(url)
        if (uri.scheme != "https" || uri.userInfo != null || uri.fragment != null ||
            (uri.port != -1 && uri.port != 443) || !Regex("w[0-9]+[a-z]\\.kancolle-server\\.com").matches(uri.host ?: "")) null
        else if (uri.rawQuery != null && !Regex("version=[A-Za-z0-9._~-]+").matches(uri.rawQuery)) null
        else {
            val path = uri.rawPath.orEmpty().removePrefix("/")
            if ('%' in path || '\\' in path || path.split('/').any { it == "." || it == ".." }) null
            else when {
                path.startsWith("kcs2/") && path.endsWith(".png") -> path
                GameModStaticAssets.isJpegPath(path) || GameModStaticAssets.isFontPath(path) -> path
                GameModArchive.AUDIO_PATH.matches(path) -> path
                else -> GameModStaticAssets.maintenanceTarget(path)
            }
        }
    } catch (_: Exception) { null }

    private fun child(relative: String): File = inside(canonicalRoot, relative)
    private fun inside(parent: File, relative: String): File {
        if (relative.isEmpty() || relative.startsWith('/') || '\\' in relative || ':' in relative ||
            relative.split('/').any { it.isEmpty() || it == "." || it == ".." }) throw GameModException("storage_error", "Unsafe mod storage path")
        val file = File(parent, relative)
        val canonical = file.canonicalFile
        if (!beneath(canonical, canonicalRoot) || !beneath(canonical, parent.canonicalFile)) {
            throw GameModException("storage_error", "Mod storage path escaped its private root")
        }
        return file
    }
    private fun collectGarbage(discover: Boolean = false) {
        // Lifecycle changes discover work once. Ordinary image/audio closes only revisit
        // queued packages whose last lease has ended, without enumerating the library.
        if (discover) cleanupDiscoveryPending = true
        if (cleanupDiscoveryPending) {
            val directories = child("packages").listFiles() ?: return
            pendingCleanup.addAll(directories.filter { it.isDirectory && !isLink(it) }.map { it.name })
            pendingCleanup.addAll(garbage)
            cleanupDiscoveryPending = false
        }
        val ready = pendingCleanup.filter { (leases[it] ?: 0) == 0 }
        if (ready.isEmpty()) return
        val retained = state.packages + state.appliedPackages + state.zipUpdateOriginals +
            transaction?.before?.let { it.packages + it.appliedPackages + it.zipUpdateOriginals }.orEmpty()
        val packages = retained.groupBy { it.id }
        ready.forEach { id ->
            val directory = child("packages/$id")
            if (id in garbage && id !in packages) {
                deletePrivateTree(directory)
                if (!directory.exists()) { garbage.remove(id); pendingCleanup.remove(id) }
                return@forEach
            }
            if (id in packages) garbage.remove(id)
            // One package lease protects all its immutable revisions, including an old
            // voice stream. Other packages can still finish their cleanup independently.
            val files = packages[id].orEmpty().flatMap { it.resources }.map { it.relativeFile }.toSet()
            val revisions = files.mapNotNull { it.takeIf { file -> file.startsWith("revisions/") }?.split('/')?.getOrNull(1) }.toSet()
            val revisionDirectory = File(directory, "revisions")
            val entries = revisionDirectory.listFiles()
            if (entries == null && revisionDirectory.exists()) return@forEach
            val obsolete = entries.orEmpty().filter { it.name !in revisions }.toMutableList()
            if (files.none { it.startsWith("files/") }) File(directory, "files").takeIf { it.exists() }?.let(obsolete::add)
            obsolete.forEach(::deletePrivateTree)
            // Deletion can fail without throwing. Keep only unfinished work for retry.
            if (obsolete.none { it.exists() }) pendingCleanup.remove(id)
        }
    }
    private fun deletePrivateTree(file: File) {
        val absolute = file.absoluteFile.normalize()
        if (!beneath(absolute, canonicalRoot)) return
        if (isLink(file)) { file.delete(); return }
        val canonical = try { file.canonicalFile } catch (_: IOException) { return }
        if (!beneath(canonical, canonicalRoot)) return
        if (file.isDirectory) file.listFiles()?.forEach(::deletePrivateTree)
        file.delete()
    }
    private fun move(source: File, destination: File) {
        // Some filesystems let rename replace an empty directory with a file.
        // A damaged state/index path must fail without discarding that directory.
        if (destination.exists() && source.isDirectory != destination.isDirectory) {
            throw IOException("Cannot replace mod data with a different file type")
        }
        // Android's same-filesystem rename replaces the destination atomically, including API 24.
        if (source.renameTo(destination)) return
        // Windows does not replace an existing File.renameTo target. Reflect NIO so API 24/25
        // never links java.nio.file classes which are only present on Android API 26+.
        try {
            val pathType = Class.forName("java.nio.file.Path")
            val optionType = Class.forName("java.nio.file.CopyOption")
            val standardType = Class.forName("java.nio.file.StandardCopyOption")
            val options = java.lang.reflect.Array.newInstance(optionType, 2)
            java.lang.reflect.Array.set(options, 0, standardType.getField("ATOMIC_MOVE").get(null))
            java.lang.reflect.Array.set(options, 1, standardType.getField("REPLACE_EXISTING").get(null))
            val toPath = File::class.java.getMethod("toPath")
            val move = Class.forName("java.nio.file.Files").getMethod("move", pathType, pathType, options.javaClass)
            try { move.invoke(null, toPath.invoke(source), toPath.invoke(destination), options) }
            catch (error: java.lang.reflect.InvocationTargetException) {
                if (error.cause?.javaClass?.name != "java.nio.file.AtomicMoveNotSupportedException") throw error
                val replace = java.lang.reflect.Array.newInstance(optionType, 1)
                java.lang.reflect.Array.set(replace, 0, standardType.getField("REPLACE_EXISTING").get(null))
                move.invoke(null, toPath.invoke(source), toPath.invoke(destination), replace)
            }
        } catch (error: Exception) { throw IOException("Cannot atomically move mod data", error) }
    }
    private fun beneath(file: File, parent: File): Boolean = file.path.startsWith(parent.path + File.separator,
        ignoreCase = File.separatorChar == '\\')
    private fun isLink(file: File): Boolean = try {
        val anchored = file.parentFile?.canonicalFile?.let { File(it, file.name) } ?: file.absoluteFile
        anchored.canonicalFile != anchored.absoluteFile
    } catch (_: IOException) { true }
    private fun persist(next: State) {
        progress?.update(phase = "save")
        val temporary = writeStateTemporary(next)
        try {
            move(temporary, child("state.json"))
        } catch (error: Exception) {
            temporary.delete()
            throw GameModException("storage_error", "Cannot persist mod configuration: ${error.message ?: "write failed"}")
        }
    }
    private fun writeStateTemporary(next: State): File {
        val temporary = child("state-${UUID.randomUUID()}.tmp")
        try {
            // Persist string-keyed maps so R8 cannot rename or remove JSON fields.
            FileOutputStream(temporary).use { output ->
                val bounded = object : FilterOutputStream(output) {
                    private var written = 0L
                    override fun write(value: Int) {
                        requireCapacity(1)
                        out.write(value)
                        written++
                    }
                    override fun write(bytes: ByteArray, offset: Int, length: Int) {
                        requireCapacity(length)
                        out.write(bytes, offset, length)
                        written += length
                    }
                    private fun requireCapacity(length: Int) {
                        if (length.toLong() > MAX_INDEX_BYTES - written) {
                            throw GameModException("quota_exceeded", "Saved mod configuration cannot exceed 64 MiB")
                        }
                    }
                }
                // Count encoded bytes while writing, rather than allocating a second full
                // JSON string/byte array. Never publish a file that readState would reject.
                val writer = OutputStreamWriter(bounded, Charsets.UTF_8)
                gson.toJson(stateMap(next), writer)
                writer.flush()
                output.fd.sync()
            }
            return temporary
        } catch (error: Exception) {
            temporary.delete()
            if (error is GameModException) throw error
            throw GameModException("storage_error", "Cannot prepare mod configuration: ${error.message ?: "write failed"}")
        }
    }
    private fun readState(): State {
        val file = child("state.json")
        if (!file.exists()) return State()
        try {
            if (file.length() > MAX_INDEX_BYTES) throw IOException("Mod index is too large")
            val json = storedObject(JsonParser.parseString(file.readText()).asJsonObject,
                listOf("version", "packages", "draft", "applied", "sessionId", "appliedPackages", "zipUpdateOriginals"))
            if (json["version"].asInt != 1) throw IOException("Unsupported mod index version")
            val promotedDraftIds = mutableListOf<String>()
            val validatedTranslationFiles = mutableMapOf<Pair<File, Long>, Boolean>()
            fun packages(name: String): List<ModPackage> = json[name].asJsonArray.map { node ->
                val entry = storedObject(node.asJsonObject,
                    listOf("id", "name", "sizeBytes", "importedAt", "resources", "warnings", "pendingRemoval", "sourceFingerprint"))
                val id = entry.text("id")
                if (!Regex("[0-9a-f-]{36}").matches(id)) throw IOException("Invalid package identity")
                child("packages/$id")
                val pendingRemoval = entry["pendingRemoval"].asBoolean
                val resources = entry["resources"].asJsonArray.map { item ->
                    val r = storedObject(item.asJsonObject,
                        listOf("id", "path", "kind", "label", "supported", "reason", "groupId", "relativeFile", "sizeBytes", "sourcePaths", "coordinateShipId", "coordinateGraph"))
                    val relativeFile = r.text("relativeFile")
                    val file = child("packages/$id/$relativeFile")
                    val path = r.text("path"); val resourceId = r.text("id")
                    if (path.startsWith('/') || '\\' in path || path.split('/').any { it == "." || it == ".." } ||
                        !resourceId.startsWith("$id:")) throw IOException("Invalid resource identity")
                    val graph = r["coordinateGraph"]?.takeIf { it.isJsonObject && it.asJsonObject.size() > 0 }?.let { element ->
                        GameModCoordinateParser.parse(("{\"api_mst_shipgraph\":" + gson.toJson(element) + "}").toByteArray(), "json").graph
                    } ?: emptyMap()
                    val shipId = r.optionalText("coordinateShipId")
                    if (shipId != null && (shipId.toIntOrNull() !in 1..9999 || path != "coordinates/ship/$shipId" || graph.isEmpty())) throw IOException("Invalid coordinate identity")
                    val sizeBytes = r["sizeBytes"].asLong.also { if (it < 0) throw IOException("Invalid resource size") }
                    val sourcePaths = r["sourcePaths"]?.asJsonArray?.map { it.asString } ?: listOf(path)
                    val kind = r.text("kind")
                    val supported = r["supported"].asBoolean
                    val reason = r.optionalText("reason")
                    // Legacy indexes retained these files as unsupported JSON. Select the validated files in the draft.
                    val quest = path == GameModQuestTranslations.PATH
                    val table = GameModDisplayTranslations.table(path)
                    val dataKind = if (quest) GameModQuestTranslations.KIND else table?.kind
                    val promote = dataKind != null && kind == "unsupported" && !supported && reason == "json_unsupported" &&
                        sourcePaths.any { it.replace('\\', '/').let { source -> source == path || source.endsWith("/$path") } } &&
                        validatedTranslationFiles.getOrPut(file to sizeBytes) {
                            if (quest) readQuestTranslations(id, relativeFile, sizeBytes) != null
                            else table != null && readDisplayTable(table, id, relativeFile, sizeBytes) != null
                        }
                    if (promote && name == "packages" && !pendingRemoval) promotedDraftIds.add(resourceId)
                    Resource(resourceId, path, if (promote) checkNotNull(dataKind) else kind,
                        r.text("label"), promote || supported, if (promote) null else reason, r.optionalText("groupId"),
                        relativeFile, sizeBytes, sourcePaths, shipId, graph)
                }
                if (resources.map { it.id }.distinct().size != resources.size || resources.map { it.path }.distinct().size != resources.size) throw IOException("Duplicate resource")
                val warnings = entry["warnings"].asJsonArray.map { it.asString }.let {
                    if (resources.none { r -> r.kind == "unsupported" && !r.supported }) it - "unsupported_files" else it
                }
                ModPackage(id, entry.text("name"), entry["sizeBytes"].asLong, entry["importedAt"].asLong,
                    resources, warnings, pendingRemoval, entry.optionalText("sourceFingerprint") ?: "")
            }
            val packages = packages("packages")
            if (packages.map { it.id }.distinct().size != packages.size) throw IOException("Duplicate package")
            fun config(name: String, available: List<ModPackage>): Config {
                val c = storedObject(json[name].asJsonObject, listOf("master", "order", "enabledPackages", "enabledResources"))
                return parseConfig(mapOf("master" to c["master"].asBoolean, "order" to c["order"].asJsonArray.map { it.asString },
                    "enabledPackages" to c["enabledPackages"].asJsonArray.map { it.asString },
                    "enabledResources" to c["enabledResources"].asJsonArray.map { it.asString }), available)
            }
            val draft = config("draft", packages.filterNot { it.pendingRemoval }).let {
                it.copy(enabledResources = (it.enabledResources + promotedDraftIds).distinct())
            }
            val appliedOrder = storedObject(json["applied"].asJsonObject,
                listOf("master", "order", "enabledPackages", "enabledResources"))["order"].asJsonArray.map { it.asString }.toSet()
            // Older indexes shared package metadata with their applied configuration.
            // New indexes keep revisions separate so a pending update survives process death.
            val appliedPackages = if (json.has("appliedPackages")) packages("appliedPackages") else packages.filter { it.id in appliedOrder }.map { it.copy(pendingRemoval = false) }
            if (appliedPackages.map { it.id }.distinct().size != appliedPackages.size || appliedPackages.any { it.pendingRemoval }) throw IOException("Invalid applied packages")
            val applied = config("applied", appliedPackages)
            val zipUpdateOriginals = if (json.has("zipUpdateOriginals")) packages("zipUpdateOriginals") else emptyList()
            val ids = packages.map { it.id }.toSet()
            if (zipUpdateOriginals.map { it.id }.distinct().size != zipUpdateOriginals.size ||
                zipUpdateOriginals.any { it.pendingRemoval || it.id !in ids }) throw IOException("Invalid ZIP update packages")
            return State(packages = packages, draft = draft, applied = applied,
                sessionId = json["sessionId"].asLong.also { if (it < 0) throw IOException("Invalid session") },
                appliedPackages = appliedPackages, zipUpdateOriginals = zipUpdateOriginals)
        } catch (error: Exception) { throw GameModException("storage_error", "Cannot read saved mod configuration: ${error.message ?: "invalid index"}") }
    }
    private fun JsonObject.text(name: String): String = this[name].asString
    private fun JsonObject.optionalText(name: String): String? = this[name]?.takeUnless { it.isJsonNull }?.asString

    /** The shipped beta3 used these positional R8 names; normalize only this object's schema. */
    private fun storedObject(value: JsonObject, names: List<String>): JsonObject {
        val shortNames = names.indices.map { ('a' + it).toString() }
        val canonical = names.any(value::has)
        val legacy = shortNames.any(value::has)
        if (canonical && legacy) throw IOException("Ambiguous mod configuration fields")
        if (!legacy) return value
        if (value.keySet().any { it !in shortNames }) throw IOException("Unknown beta3 mod configuration field")
        return JsonObject().apply {
            names.forEachIndexed { index, name -> value[shortNames[index]]?.let { add(name, it) } }
        }
    }

    private fun stateMap(value: State): Map<String, Any> = linkedMapOf<String, Any>(
        "version" to value.version, "packages" to value.packages.map(::storedPackageMap),
        "draft" to value.draft.toMap(), "applied" to value.applied.toMap(),
        "sessionId" to value.sessionId, "appliedPackages" to value.appliedPackages.map(::storedPackageMap)).apply {
        if (value.zipUpdateOriginals.isNotEmpty()) put("zipUpdateOriginals", value.zipUpdateOriginals.map(::storedPackageMap))
    }

    private fun storedPackageMap(value: ModPackage): Map<String, Any> = linkedMapOf(
        "id" to value.id, "name" to value.name, "sizeBytes" to value.sizeBytes,
        "importedAt" to value.importedAt, "resources" to value.resources.map { resource ->
            linkedMapOf("id" to resource.id, "path" to resource.path, "kind" to resource.kind,
                "label" to resource.label, "supported" to resource.supported, "reason" to resource.reason,
                "groupId" to resource.groupId, "relativeFile" to resource.relativeFile, "sizeBytes" to resource.sizeBytes,
                "sourcePaths" to resource.sourcePaths, "coordinateShipId" to resource.coordinateShipId,
                "coordinateGraph" to resource.coordinateGraph)
        }, "warnings" to value.warnings, "pendingRemoval" to value.pendingRemoval,
        "sourceFingerprint" to value.sourceFingerprint)

    private data class Config(val master: Boolean = false, val order: List<String> = emptyList(),
        val enabledPackages: List<String> = emptyList(), val enabledResources: List<String> = emptyList()) {
        fun sameAs(other: Config) = master == other.master && order == other.order &&
            enabledPackages.toSet() == other.enabledPackages.toSet() &&
            enabledResources.toSet() == other.enabledResources.toSet()
        fun toMap(): Map<String, Any> = linkedMapOf("master" to master, "order" to order.toList(),
            "enabledPackages" to enabledPackages.toList(), "enabledResources" to enabledResources.toList())
        fun restrictTo(packages: List<ModPackage>): Config {
            val ids = packages.map { it.id }.toSet(); val resources = packages.flatMap { it.resources }.map { it.id }.toSet()
            return copy(order = order.filter { it in ids }, enabledPackages = enabledPackages.filter { it in ids }, enabledResources = enabledResources.filter { it in resources })
        }
        fun withAvailablePackages(packages: List<ModPackage>): Config {
            val existing = restrictTo(packages)
            val ordered = existing.order.toSet()
            return existing.copy(order = existing.order + packages.map { it.id }.filterNot { it in ordered })
        }
    }
    private data class Resource(val id: String, val path: String, val kind: String, val label: String,
        val supported: Boolean, val reason: String?, val groupId: String?, val relativeFile: String, val sizeBytes: Long,
        val sourcePaths: List<String> = listOf(path), val coordinateShipId: String? = null, val coordinateGraph: Map<String,List<Int>> = emptyMap())
    private data class ModPackage(val id: String, val name: String, val sizeBytes: Long, val importedAt: Long,
        val resources: List<Resource>, val warnings: List<String>, val pendingRemoval: Boolean = false,
        val sourceFingerprint: String = "")
    private data class State(val version: Int = 1, val packages: List<ModPackage> = emptyList(),
        val draft: Config = Config(), val applied: Config = Config(), val sessionId: Long = 0,
        val appliedPackages: List<ModPackage> = emptyList(), val zipUpdateOriginals: List<ModPackage> = emptyList())
    private data class StagedImport(val directory: File, val result: ArchiveResult, val updateBase: ModPackage?)
    internal data class ZipUpdateTarget(val id: String, val name: String, val oldFingerprint: String, val newFingerprint: String)
    private data class Selected(val packageId: String, val resource: Resource)
    private data class PortraitLease(val packageId: String, val size: Int, val input: FileInputStream)
    private class Session(
        val id: Long,
        val winners: Map<String, Selected>,
        val coordinateShips: Map<String, CoordinateShip>,
        val questTranslations: Map<String, GameModQuestTranslations.Translation>,
        val displayTranslations: Map<String, Any>,
    ) {
        val token = UUID.randomUUID().toString()
        val portraits = winners.values.filter { selected ->
            selected.resource.kind in setOf("ship", "image") && selected.resource.path.endsWith(".png")
        }.associateBy { it.resource.id }
        val coordinateIds = coordinateShips.values.flatMap { it.resourceIds }.toSet()
        val hits = linkedSetOf<String>(); val partialHits = linkedSetOf<String>(); val failures = linkedMapOf<String, String>()
        val audioCoverage = mutableMapOf<String, List<LongRange>>()
    }
    private data class CoordinateShip(val graph: Map<String,List<Int>>, val resourceIds: List<String>)
    private data class StatusSnapshot(val state: State, val session: Session, val hits: List<String>, val partialHits: List<String>, val failures: Map<String, String>)
    private class ApplyTransaction(val token: GameModApplyToken, val before: State, val session: Session) {
        var prepared: PreparedApply? = null
        var published = false
    }
    private data class PreparedApply(val next: State, val session: Session, val file: File)
}

/** Only bytes actually delivered count; skip and early close cannot claim a completed response. */
private class CompletionStream(private val source: InputStream, private val expected: Long,
    private val completed: () -> Unit, private val progress: () -> Unit,
    private val failed: (String) -> Unit, private val closed: () -> Unit) : InputStream() {
    private var consumed = 0L; private var skipped = false; private var finished = false; private var isClosed = false
    private var progressReported = false
    override fun read(): Int = protect {
        if (consumed == expected) -1 else source.read().also { account(if (it == -1) -1 else 1) }
    }
    override fun read(bytes: ByteArray, offset: Int, length: Int): Int = protect {
        if (offset < 0 || length < 0 || offset > bytes.size - length) throw IndexOutOfBoundsException()
        if (length == 0) 0 else if (consumed == expected) -1
        else source.read(bytes, offset, minOf(length.toLong(), expected - consumed).toInt()).also(::account)
    }
    override fun skip(count: Long): Long = protect {
        source.skip(count.coerceAtLeast(0).coerceAtMost(expected - consumed)).also { if (it > 0) { skipped = true; consumed += it } }
    }
    override fun available(): Int = protect { minOf(source.available().toLong(), expected - consumed).toInt() }
    override fun markSupported() = false
    override fun close() {
        if (isClosed) return
        isClosed = true
        try { source.close() } catch (error: IOException) { failed(error.message ?: "Resource close failed"); throw error }
        finally { closed() }
    }
    private fun account(count: Int) {
        if (count < 0 && consumed != expected) throw IOException("Imported resource ended before its expected length")
        if (count > 0) {
            consumed += count
            if (!progressReported) { progressReported = true; progress() }
        }
        if (!finished && !skipped && consumed == expected) { finished = true; completed() }
    }
    private fun <T> protect(block: () -> T): T = try {
        if (isClosed) throw IOException("Resource stream is closed")
        block()
    } catch (error: IOException) { failed(error.message ?: "Resource read failed"); throw error }
}
