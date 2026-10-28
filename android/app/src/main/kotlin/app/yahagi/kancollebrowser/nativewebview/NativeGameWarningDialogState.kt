package app.yahagi.kancollebrowser.nativewebview

/** Owns a warning and the quiet input interval after its single accepted action. */
internal class NativeGameWarningDialogState {
    var id: Long? = null
        private set
    var actionChosen = false
        private set
    var releaseVersion = 0L
        private set
    private val pointers = mutableSetOf<Int>()

    val hasPointers: Boolean get() = pointers.isNotEmpty()

    val canScheduleRelease: Boolean
        get() = id != null && actionChosen && pointers.isEmpty()

    fun present(id: Long) {
        this.id = id
        actionChosen = false
        releaseVersion++
    }

    fun choose(id: Long): Boolean {
        if (this.id != id || actionChosen) return false
        actionChosen = true
        releaseVersion++
        return true
    }

    fun pointerDown(pointer: Int) {
        pointers.add(pointer)
        releaseVersion++
    }

    fun pointerUp(pointer: Int) {
        pointers.remove(pointer)
        releaseVersion++
    }

    fun cancelPointers() {
        pointers.clear()
        releaseVersion++
    }

    fun releaseIfQuiet(id: Long, version: Long): Boolean {
        if (this.id != id || releaseVersion != version || !canScheduleRelease) return false
        return dismiss(id)
    }

    fun dismiss(id: Long): Boolean {
        if (this.id != id) return false
        this.id = null
        actionChosen = false
        pointers.clear()
        releaseVersion++
        return true
    }
}

internal data class NativeGameWarningDialogSpec(
    val id: Long,
    val title: String,
    val headline: String,
    val body: String,
    val rows: List<String>,
    val labels: Map<String, String>,
    val enabled: Map<String, Boolean>,
    val refreshFailed: String?,
    val kind: String = "battle",
    val displayActions: List<String> = actions,
    val items: List<NativeGameChecklistItem> = emptyList(),
    val resetLabel: String? = null,
    val appliedChangeId: Long = 0L,
    val dismissible: Boolean = true,
    val checkbox: NativeGameSurfaceCheckbox? = null,
    val choices: List<NativeGameSurfaceChoice> = emptyList(),
    val selectedChoiceId: String? = null,
) {
    val key: NativeGameDialogKey get() = NativeGameDialogKey(kind, id)
    val isNotice: Boolean get() = kind != "battle"
    val isChecklist: Boolean get() = kind in checklistKinds
    val isSurfaceDialog: Boolean get() = kind == "surfaceDialog"

    companion object {
        val actions = listOf("acknowledge", "mute", "reloadGame", "reloadFrame")
        val checklistKinds = setOf("headerResources", "collapsedResources", "moduleDisplay", "fleetDisplay")
        val kinds = setOf("battle", "debuff", "newShip", "surfaceDialog") + checklistKinds

        fun parse(arguments: Any?): NativeGameWarningDialogSpec {
            val values = arguments as? Map<*, *> ?: error("Warning arguments must be a map")
            val id = (values["id"] as? Number)?.toLong()?.takeIf { it > 0 }
                ?: error("Warning id must be a positive integer")
            val kind = values["kind"] ?: "battle"
            require(kind is String && kind in kinds) { "Unknown dialog kind" }
            val notice = kind != "battle"
            val checklist = kind in checklistKinds
            val surface = kind == "surfaceDialog"
            require(values["actions"] == null || values["actions"] is List<*>) { "Dialog actions must be a list" }
            val displayActions = (values["actions"] as? List<*>)?.map {
                it as? String ?: error("Dialog actions must be strings")
            } ?: if (notice) listOf("acknowledge") else actions
            if (surface) {
                require(displayActions.size in 1..4 && displayActions.toSet().size == displayActions.size &&
                    displayActions.all(::isSurfaceDialogId)) { "Invalid surface dialog actions" }
            } else {
                require(displayActions == if (notice) listOf("acknowledge") else actions) { "Invalid actions for dialog kind" }
            }
            fun text(key: String, allowEmpty: Boolean = false): String {
                val value = values[key] as? String ?: error("$key must be a string")
                require(value.length <= 32768 && (allowEmpty || value.isNotBlank()))
                return value
            }
            val rows = ((values["rows"] ?: if (notice) emptyList<Any>() else null) as? List<*>)?.map {
                (it as? String)?.takeIf { row -> row.length <= 8192 }
                    ?: error("Warning rows must be strings")
            } ?: error("Warning rows must be a list")
            require(rows.size <= 64)
            val labels = values["labels"] as? Map<*, *> ?: error("Warning labels are missing")
            val enabled = values["enabled"] as? Map<*, *>
            require(checklist || (values["items"] == null && values["resetLabel"] == null)) {
                "Interactive items require a resource checklist"
            }
            val rawItems = values["items"]
            require(rawItems == null || rawItems is List<*>) { "Checklist items must be a list" }
            val items = (rawItems as? List<*>)?.map(NativeGameChecklistItem::parse) ?: emptyList()
            require(items.size <= 64 && items.map { it.id }.toSet().size == items.size) {
                "Checklist items must have unique ids and at most 64 entries"
            }
            val resetLabel = values["resetLabel"]?.let {
                require(it is String && it.isNotBlank() && it.length <= 4096) { "Invalid reset label" }
                it
            }
            val applied = values["appliedChangeId"] ?: 0L
            require(applied is Number && applied.toDouble().isFinite() && applied.toLong() >= 0 &&
                applied.toDouble() == applied.toLong().toDouble()) { "Invalid applied checklist change id" }
            require(surface || listOf("choices", "checkbox", "selectedChoiceId", "dismissible").none { values.containsKey(it) }) {
                "Surface dialog controls require a surface dialog"
            }
            val dismissible = values["dismissible"] ?: true
            require(dismissible is Boolean) { "Dialog dismissible must be boolean" }
            val checkbox = values["checkbox"]?.let(NativeGameSurfaceCheckbox::parse)
            val rawChoices = values["choices"]
            require(rawChoices == null || rawChoices is List<*>) { "Dialog choices must be a list" }
            val choices = (rawChoices as? List<*>)?.map(NativeGameSurfaceChoice::parse) ?: emptyList()
            require(choices.size <= 256 && choices.map { it.id }.toSet().size == choices.size &&
                choices.none { it.id in displayActions }) { "Dialog choice ids must be unique, bounded and distinct from actions" }
            val selectedChoiceId = values["selectedChoiceId"]?.let {
                require(it is String && choices.any { choice -> choice.id == it }) { "Unknown selected dialog choice" }
                it
            }
            return NativeGameWarningDialogSpec(
                id, text("title"), if (notice && values["headline"] == null) "" else text("headline", allowEmpty = notice),
                if (checklist && values["body"] == null) "" else text("body", allowEmpty = true), rows,
                displayActions.associateWith { action ->
                    (labels[action] as? String)?.takeIf { it.isNotBlank() && it.length <= 4096 }
                        ?: error("Missing label for $action")
                },
                displayActions.associateWith { action ->
                    val value = enabled?.get(action)
                    require(value == null || value is Boolean)
                    value ?: true
                },
                (values["refreshFailed"] as? String)?.takeIf { it.isNotEmpty() },
                kind, displayActions, items, resetLabel, applied.toLong(), dismissible, checkbox, choices, selectedChoiceId,
            )
        }
    }
}

private fun isSurfaceDialogId(value: String): Boolean =
    value.matches(Regex("[A-Za-z0-9][A-Za-z0-9_-]{0,127}"))

internal data class NativeGameSurfaceCheckbox(val label: String, val checked: Boolean) {
    companion object {
        fun parse(arguments: Any?): NativeGameSurfaceCheckbox {
            val values = arguments as? Map<*, *> ?: error("Dialog checkbox must be a map")
            val label = values["label"] as? String ?: error("Dialog checkbox label is missing")
            require(label.isNotBlank() && label.length <= 4096) { "Invalid dialog checkbox label" }
            val checked = values["checked"] as? Boolean ?: error("Dialog checkbox checked must be boolean")
            return NativeGameSurfaceCheckbox(label, checked)
        }
    }
}

internal data class NativeGameSurfaceChoice(val id: String, val label: String, val detail: String = "", val group: String = "") {
    companion object {
        fun parse(arguments: Any?): NativeGameSurfaceChoice {
            val values = arguments as? Map<*, *> ?: error("Dialog choice must be a map")
            val id = values["id"] as? String ?: error("Dialog choice id is missing")
            require(isSurfaceDialogId(id)) { "Invalid dialog choice id" }
            val label = values["label"] as? String ?: error("Dialog choice label is missing")
            require(label.isNotBlank() && label.length <= 4096) { "Invalid dialog choice label" }
            fun optionalText(key: String): String {
                if (!values.containsKey(key)) return ""
                val text = values[key] as? String ?: error("Dialog choice $key must be text")
                require(text.length <= 8192) { "Dialog choice $key is too long" }
                return text
            }
            return NativeGameSurfaceChoice(id, label, optionalText("detail"), optionalText("group"))
        }
    }
}

internal data class NativeGameChecklistItem(
    val id: String,
    val label: String,
    val value: String,
    val checked: Boolean,
    val iconAsset: String? = null,
    val iconCodePoint: Int? = null,
    val iconColor: Int? = null,
    val enabled: Boolean = true,
) {
    companion object {
        private val resourceIconAsset = Regex("assets/images/material/[A-Za-z0-9_-]+\\.png")

        fun parse(arguments: Any?): NativeGameChecklistItem {
            val values = arguments as? Map<*, *> ?: error("Checklist item must be a map")
            val id = values["id"] as? String ?: error("Checklist item id is missing")
            require(id.matches(Regex("[A-Za-z0-9][A-Za-z0-9_-]{0,127}"))) { "Invalid checklist item id" }
            val label = values["label"] as? String ?: error("Checklist item label is missing")
            require(label.isNotBlank() && label.length <= 4096) { "Invalid checklist item label" }
            val value = values["value"] as? String ?: error("Checklist item value must be text")
            require(value.length <= 8192) { "Checklist item value is too long" }
            val checked = values["checked"] as? Boolean ?: error("Checklist item checked must be boolean")
            val enabled = if (values.containsKey("enabled")) {
                values["enabled"] as? Boolean ?: error("Checklist item enabled must be boolean")
            } else true
            val iconAsset = values["iconAsset"]?.let {
                require(it is String && it.length <= 256 && resourceIconAsset.matches(it)) { "Invalid checklist icon asset" }
                it
            }
            val iconCodePoint = values["iconCodePoint"]?.let {
                val scalar = iconInteger(it, "code point")
                require(scalar in 0L..0x10ffffL && scalar !in 0xd800L..0xdfffL) { "Invalid checklist icon code point" }
                scalar.toInt()
            }
            require(iconAsset == null || iconCodePoint == null) { "Checklist icons must use either an asset or a glyph" }
            val iconColor = values["iconColor"]?.let {
                val argb = iconInteger(it, "color")
                require(argb in 0..0xffffffffL) { "Invalid checklist icon color" }
                argb.toInt()
            }
            return NativeGameChecklistItem(id, label, value, checked, iconAsset, iconCodePoint, iconColor, enabled)
        }

        private fun iconInteger(value: Any, name: String): Long {
            require(value is Int || value is Long) { "Checklist icon $name must be an integer" }
            return (value as Number).toLong()
        }
    }
}

/** Keeps a delayed Dart state refresh from reversing more recent native taps. */
internal class NativeGameChecklistChangeState(initialChangeId: Long) {
    constructor() : this(0L)

    init { require(initialChangeId >= 0) }

    private var latestChangeId = initialChangeId
    private var acknowledgedChangeId = initialChangeId
    private var pendingResetId: Long? = null
    val canToggle: Boolean get() = pendingResetId == null

    fun change(reset: Boolean): Long? {
        if (pendingResetId != null) return null
        check(latestChangeId < Long.MAX_VALUE) { "Checklist change sequence exhausted" }
        latestChangeId++
        if (reset) pendingResetId = latestChangeId
        return latestChangeId
    }

    /** True means all checked values in this update can replace the local UI. */
    fun acknowledge(changeId: Long): Boolean {
        if (changeId > latestChangeId) return false
        val staleAcknowledgement = changeId > 0 && changeId < acknowledgedChangeId
        val pendingLocalChanges = latestChangeId > acknowledgedChangeId
        val applyChecks = !staleAcknowledgement && (!pendingLocalChanges || changeId >= latestChangeId)
        acknowledgedChangeId = maxOf(acknowledgedChangeId, changeId)
        pendingResetId?.let { if (changeId >= it) pendingResetId = null }
        return applyChecks
    }
}
