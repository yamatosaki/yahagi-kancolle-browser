package app.yahagi.kancollebrowser.browser

internal class FullscreenNoticeState {
    private var pendingQuestMessage = ""
    private var damageControlMessage = ""
    var damageControlId: Long? = null
        private set
    var canPresentDamageControl = false
        private set

    val displayMessage: String
        get() = if (damageControlId != null) {
            if (canPresentDamageControl) damageControlMessage else ""
        } else {
            pendingQuestMessage
        }

    /** Updating a queued quest must not trigger a new layout of an active damage notice. */
    fun setQuestMessage(message: String): Boolean {
        pendingQuestMessage = message
        return damageControlId == null
    }

    fun setDamageControlNotice(id: Long, message: String) {
        require(message.isNotEmpty())
        damageControlId = id
        damageControlMessage = message
        canPresentDamageControl = true
    }

    fun clearDamageControlNotice(id: Long): Boolean {
        if (damageControlId != id) return false
        damageControlId = null
        damageControlMessage = ""
        canPresentDamageControl = false
        return true
    }

    // A failed show must not surface later when an unrelated fullscreen update arrives.
    fun rejectDamageControlPresentation() { canPresentDamageControl = false }

    fun clear() {
        pendingQuestMessage = ""
        damageControlId = null
        damageControlMessage = ""
        canPresentDamageControl = false
    }
}

internal fun fullscreenDamageControlNoticeFits(
    message: String,
    lineCount: Int,
    lastLineEnd: Int,
    hasEllipsis: Boolean,
    requiredWidth: Int,
    requiredHeight: Int,
    bounds: FullscreenOverlayBounds,
    content: FullscreenOverlayBounds,
    controlBounds: FullscreenOverlayBounds? = null,
): Boolean = message.isNotEmpty() &&
    lineCount in 1..2 && lastLineEnd == message.length && !hasEllipsis &&
    requiredWidth > 0 && requiredHeight > 0 &&
    bounds.width >= requiredWidth && bounds.height >= requiredHeight &&
    content.width > 0 && content.height > 0 &&
    bounds.left >= content.left && bounds.top >= content.top &&
    bounds.right <= content.right && bounds.bottom <= content.bottom &&
    (controlBounds == null || bounds.right <= controlBounds.left ||
        bounds.left >= controlBounds.right || bounds.bottom <= controlBounds.top ||
        bounds.top >= controlBounds.bottom)
