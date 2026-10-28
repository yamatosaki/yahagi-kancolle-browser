package app.yahagi.kancollebrowser.nativewebview

internal data class NativeGameDialogKey(val kind: String, val id: Long) {
    val isBattle: Boolean get() = kind == "battle"
}

/** Orders requests without completing the notification that was preempted. */
internal class NativeGameDialogQueue {
    var active: NativeGameDialogKey? = null
        private set
    private val queued = mutableListOf<NativeGameDialogKey>()
    val waiting: List<NativeGameDialogKey> get() = queued.toList()

    /** True means this request became active and must be rendered now. */
    fun offer(kind: String, id: Long, guarding: Boolean): Boolean {
        val key = NativeGameDialogKey(kind, id)
        require(active != key && key !in queued) { "Duplicate dialog request" }
        val previous = active
        if (previous == null) {
            active = key
            return true
        }
        if (guarding) {
            enqueue(key)
            return false
        }
        if (key.isBattle) {
            if (!previous.isBattle) {
                val firstNotice = queued.indexOfFirst { !it.isBattle }.let { if (it < 0) queued.size else it }
                queued.add(firstNotice, previous)
            }
            active = key
            return true
        }
        enqueue(key)
        return false
    }

    private fun enqueue(key: NativeGameDialogKey) {
        if (key.isBattle) {
            val firstNotice = queued.indexOfFirst { !it.isBattle }.let { if (it < 0) queued.size else it }
            queued.add(firstNotice, key)
        } else queued.add(key)
    }

    fun finish(kind: String, id: Long): NativeGameDialogKey? {
        if (active == NativeGameDialogKey(kind, id)) {
            active = if (queued.isEmpty()) null else queued.removeAt(0)
        }
        return active
    }

    fun removeQueued(kind: String, id: Long): Boolean = queued.remove(NativeGameDialogKey(kind, id))

    /** Removes stale owners without consuming requests for the current owner. */
    fun discardInvalid(invalid: Set<NativeGameDialogKey>, preserveActive: Boolean): List<NativeGameDialogKey> {
        val removed = mutableListOf<NativeGameDialogKey>()
        val previous = active
        if (!preserveActive && previous in invalid) removed.add(requireNotNull(previous))
        queued.removeAll { key ->
            if (key in invalid) {
                removed.add(key)
                true
            } else false
        }
        if (previous in removed) active = if (queued.isEmpty()) null else queued.removeAt(0)
        return removed
    }

    fun clear(): List<NativeGameDialogKey> {
        val all = listOfNotNull(active) + queued
        active = null
        queued.clear()
        return all
    }
}
