package app.yahagi.kancollebrowser

import java.lang.ref.WeakReference

/** Last effective request belongs to the app; successful application belongs to one view. */
internal class GameWebViewAudioState<T : Any> {
    private var target: Boolean? = null
    private var targetRevision = 0L
    private var appliedOwner: WeakReference<T>? = null
    private var appliedMuted: Boolean? = null

    val hasTarget: Boolean get() = target != null

    fun setTarget(muted: Boolean) {
        if (target != muted) targetRevision++
        target = muted
    }

    fun reconcile(owner: T?, force: Boolean = false, apply: (T, Boolean) -> Unit): Boolean {
        val muted = target ?: return false
        if (owner == null) return false
        if (!force && appliedOwner?.get() === owner && appliedMuted == muted) return false
        val revision = targetRevision
        // An exception can follow a native side effect. A later repair must
        // not trust the last success after an intervening failed request.
        appliedOwner = null
        appliedMuted = null
        apply(owner, muted)
        if (revision == targetRevision) {
            appliedOwner = WeakReference(owner)
            appliedMuted = muted
        }
        return true
    }
}
