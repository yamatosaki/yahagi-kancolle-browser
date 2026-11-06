package app.yahagi.kancollebrowser.nativewebview

import android.annotation.SuppressLint
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.WebStorage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.net.URI
import java.util.UUID
import java.util.WeakHashMap
import java.util.concurrent.atomic.AtomicBoolean

internal interface NativeGameWebViewHostOperations {
    val currentGeneration: Long?

    fun create(): Long?
    fun setBounds(generation: Long, bounds: NativeGameWebViewBounds): Boolean
    fun setVisible(generation: Long, visible: Boolean): Boolean
    fun loadUri(uri: String)
    fun showLocalHome(html: String)
    fun reload()
    fun canGoBack(): Boolean
    fun goBack()
    fun runJavaScript(javascript: String)
    fun fitGameScreen(javascript: String)
    fun clearCache()
    fun clearSession(onComplete: (Exception?) -> Unit)
    fun destroy(generation: Long): Boolean
}

internal class ActivityNativeGameWebViewHostOperations(
    private val host: ActivityWebViewHost,
) : NativeGameWebViewHostOperations {
    override val currentGeneration: Long?
        get() = host.currentGeneration

    override fun create(): Long? = host.create()

    override fun setBounds(generation: Long, bounds: NativeGameWebViewBounds): Boolean =
        host.setBounds(generation, bounds)

    override fun setVisible(generation: Long, visible: Boolean): Boolean =
        host.setVisible(generation, visible)

    override fun loadUri(uri: String) {
        requireWebView().loadUrl(uri)
    }

    override fun showLocalHome(html: String) {
        requireWebView().loadDataWithBaseURL(
            LOCAL_HOME_BASE_URL,
            html,
            "text/html",
            "UTF-8",
            null,
        )
    }

    override fun reload() {
        requireWebView().reload()
    }

    override fun canGoBack(): Boolean = requireWebView().canGoBack()

    override fun goBack() {
        requireWebView().goBack()
    }

    override fun runJavaScript(javascript: String) {
        requireWebView().evaluateJavascript(javascript, null)
    }

    override fun fitGameScreen(javascript: String) {
        requireWebView().evaluateJavascript(javascript, null)
    }

    override fun clearCache() {
        requireWebView().clearCache(true)
    }

    override fun clearSession(onComplete: (Exception?) -> Unit) {
        WebStorage.getInstance().deleteAllData()
        requireWebView().apply {
            clearFormData()
            clearHistory()
            clearCache(true)
        }
        CookieManager.getInstance().removeAllCookies {
            try {
                CookieManager.getInstance().flush()
                onComplete(null)
            } catch (error: Exception) {
                onComplete(error)
            }
        }
    }

    override fun destroy(generation: Long): Boolean = host.destroy(generation)

    private fun requireWebView() = checkNotNull(host.currentWebView) {
        "Native game WebView is not ready"
    }

    private companion object {
        const val LOCAL_HOME_BASE_URL = "https://localhost/"
    }
}

internal interface NativeGameWebViewLifecycleObserver {
    fun onCreated() = Unit
    fun onPageStarted() = Unit
    fun onPageFinished() = Unit
    fun onRenderProcessGone() = Unit
    fun onCreateFailed() = Unit
}

internal object NoOpNativeGameWebViewLifecycleObserver : NativeGameWebViewLifecycleObserver

internal fun interface NativeGameWebViewScheduledOperation {
    fun cancel()
}

internal fun interface NativeGameWebViewOperationTimeoutScheduler {
    fun schedule(delayMs: Long, operation: () -> Unit): NativeGameWebViewScheduledOperation
}

private object NoOpNativeGameWebViewOperationTimeoutScheduler : NativeGameWebViewOperationTimeoutScheduler {
    override fun schedule(delayMs: Long, operation: () -> Unit) =
        NativeGameWebViewScheduledOperation { }
}

private object AndroidNativeGameWebViewOperationTimeoutScheduler : NativeGameWebViewOperationTimeoutScheduler {
    private val handler by lazy { Handler(Looper.getMainLooper()) }

    override fun schedule(delayMs: Long, operation: () -> Unit): NativeGameWebViewScheduledOperation {
        val runnable = Runnable(operation)
        check(handler.postDelayed(runnable, delayMs)) { "Unable to schedule the native WebView operation timeout" }
        return NativeGameWebViewScheduledOperation { handler.removeCallbacks(runnable) }
    }
}

internal sealed interface NativeWebViewActivityStartupOutcome {
    data object StartHost : NativeWebViewActivityStartupOutcome

    data class Unavailable(
        val errorCode: String,
        val message: String,
    ) : NativeWebViewActivityStartupOutcome
}

internal class NativeWebViewActivityStartupCoordinator(
    private val guard: NativeWebViewStartupGuard,
    private val nowMs: () -> Long,
    private val scheduleTimeout: (Long, () -> Unit) -> Unit,
    private val cancelTimeout: () -> Unit,
    private val requestRestart: () -> Unit,
) : NativeGameWebViewLifecycleObserver {
    private var timeoutVersion = 0L
    private var hasScheduledTimeout = false
    private var restartRequested = false
    private var foreground = true
    private var pausedAtMs: Long? = null
    private var pausedDurationMs = 0L
    private var remainingTimeoutMs: Long? = null
    private var armedAtMs: Long? = null

    fun setForeground(foreground: Boolean) {
        if (this.foreground == foreground) return
        val rawNow = nowMs()
        if (!foreground) {
            val virtualNow = foregroundNowMs(rawNow)
            val armedAt = armedAtMs
            if (armedAt != null) {
                remainingTimeoutMs = remainingTimeoutMs?.let {
                    (it - (virtualNow - armedAt).coerceAtLeast(0L)).coerceAtLeast(0L)
                }
            }
            this.foreground = false
            pausedAtMs = rawNow
            cancelScheduledTimeout(clearBudget = false)
        } else {
            pausedAtMs?.let { pausedDurationMs += (rawNow - it).coerceAtLeast(0L) }
            pausedAtMs = null
            this.foreground = true
            remainingTimeoutMs?.let(::schedule)
        }
    }

    private fun foregroundNowMs(rawNow: Long = nowMs()): Long {
        val currentPause = pausedAtMs?.let { (rawNow - it).coerceAtLeast(0L) } ?: 0L
        return (rawNow - pausedDurationMs - currentPause).coerceAtLeast(0L)
    }

    fun begin(storedMode: String?): NativeWebViewActivityStartupOutcome {
        // Match Dart GameRenderingModeCodec: missing/unknown preferences use native mode.
        val renderingMode = when (storedMode) {
            "standard", "compatibility", "canvasCompatibility" -> storedMode
            else -> NATIVE_ACTIVITY_RENDERING_MODE
        }
        if (renderingMode != NATIVE_ACTIVITY_RENDERING_MODE) {
            return NativeWebViewActivityStartupOutcome.Unavailable(
                "native_webview_unavailable",
                "Native Activity WebView mode is not active.",
            )
        }
        // Only this live Activity's idle background intervals are discounted.
        // Persisted attempts from a different process still use the guard's
        // normal crash/fallback policy when beginAttempt is first called.
        return when (val decision = guard.beginAttempt(foregroundNowMs())) {
            is NativeWebViewStartupDecision.Started -> {
                schedule(NativeWebViewStartupGuard.STARTUP_TIMEOUT_MS)
                NativeWebViewActivityStartupOutcome.StartHost
            }
            is NativeWebViewStartupDecision.AlreadyInProgress -> {
                schedule(decision.remainingMs)
                NativeWebViewActivityStartupOutcome.StartHost
            }
            NativeWebViewStartupDecision.FallbackTriggered -> {
                requestRestartOnce()
                fallbackUnavailable()
            }
            NativeWebViewStartupDecision.FallbackActive -> fallbackUnavailable()
            NativeWebViewStartupDecision.PersistenceFailed,
            NativeWebViewStartupDecision.PersistenceIndeterminate,
            -> NativeWebViewActivityStartupOutcome.Unavailable(
                "native_webview_startup_failed",
                "Native WebView startup persistence is unavailable.",
            )
            else -> NativeWebViewActivityStartupOutcome.Unavailable(
                "native_webview_startup_failed",
                "Native WebView startup could not begin.",
            )
        }
    }

    private fun fallbackUnavailable() = NativeWebViewActivityStartupOutcome.Unavailable(
        "native_webview_unavailable",
        "Native Activity WebView fallback is active.",
    )

    override fun onPageFinished() {
        cancelScheduledTimeout()
        handleTerminalDecision(guard.recordPageFinished())
    }

    override fun onRenderProcessGone() {
        cancelScheduledTimeout()
        handleTerminalDecision(guard.recordRenderProcessGone())
    }

    override fun onCreateFailed() = onRenderProcessGone()

    fun close() {
        cancelScheduledTimeout()
        runCatching { guard.cancelAttempt() }
    }

    private fun schedule(delayMs: Long) {
        if (hasScheduledTimeout) cancelTimeout()
        remainingTimeoutMs = delayMs.coerceAtLeast(0L)
        armedAtMs = null
        if (!foreground) return
        hasScheduledTimeout = true
        armedAtMs = foregroundNowMs()
        val version = ++timeoutVersion
        scheduleTimeout(delayMs.coerceAtLeast(0L)) {
            if (version != timeoutVersion || !foreground) return@scheduleTimeout
            hasScheduledTimeout = false
            remainingTimeoutMs = null
            armedAtMs = null
            when (val decision = guard.recordStartupTimeout(foregroundNowMs())) {
                is NativeWebViewStartupDecision.NotTimedOut -> schedule(decision.remainingMs)
                else -> handleTerminalDecision(decision)
            }
        }
    }

    private fun cancelScheduledTimeout(clearBudget: Boolean = true) {
        timeoutVersion++
        armedAtMs = null
        if (clearBudget) remainingTimeoutMs = null
        if (hasScheduledTimeout) {
            hasScheduledTimeout = false
            cancelTimeout()
        }
    }

    private fun handleTerminalDecision(decision: NativeWebViewStartupDecision) {
        if (decision == NativeWebViewStartupDecision.FallbackTriggered) {
            requestRestartOnce()
        }
    }

    private fun requestRestartOnce() {
        if (restartRequested) return
        restartRequested = true
        requestRestart()
    }

    companion object {
        const val NATIVE_ACTIVITY_RENDERING_MODE = "nativeActivityExperimental"
    }
}

internal class NativeGameWebViewActivityAttachment internal constructor(
    internal val id: Long,
)

internal class NativeGameWebViewChannel(
    private val operationTimeoutScheduler: NativeGameWebViewOperationTimeoutScheduler =
        NoOpNativeGameWebViewOperationTimeoutScheduler,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private data class ActivityBinding(
        val token: NativeGameWebViewActivityAttachment,
        val dispatchToMain: ((() -> Unit) -> Unit),
        val lifecycleObserver: NativeGameWebViewLifecycleObserver,
        var host: NativeGameWebViewHostOperations? = null,
        var detaching: Boolean = false,
        var unavailable: NativeWebViewActivityStartupOutcome.Unavailable? = null,
        var operationWatchdog: NativeGameWebViewScheduledOperation? = null,
    )

    private data class ParsedCall(
        val method: String,
        val generation: Long? = null,
        val bounds: NativeGameWebViewBounds? = null,
        val visible: Boolean? = null,
        val text: String? = null,
    )

    private data class PendingCall(
        val parsed: ParsedCall,
        val result: MethodChannel.Result,
        var attachmentId: Long? = null,
        val terminal: AtomicBoolean = AtomicBoolean(false),
        val asyncCompletionClaimed: AtomicBoolean = AtomicBoolean(false),
    )

    private var activityBinding: ActivityBinding? = null
    private var nextAttachmentId = 0L
    private val pendingCalls = ArrayDeque<PendingCall>()
    private var callRunning = false
    private var dispatchVersion = 0L
    private var asyncVersion = 0L
    private var eventSink: EventChannel.EventSink? = null
    private var acceptedGeneration: Long? = null
    private var engineDestroyed = false

    fun attachActivity(
        dispatchToMain: ((() -> Unit) -> Unit),
        lifecycleObserver: NativeGameWebViewLifecycleObserver =
            NoOpNativeGameWebViewLifecycleObserver,
    ): NativeGameWebViewActivityAttachment {
        check(!engineDestroyed) { "Native game WebView engine channel is destroyed" }
        activityBinding?.let(::detachBinding)
        val token = NativeGameWebViewActivityAttachment(nextAttachmentId++)
        activityBinding = ActivityBinding(token, dispatchToMain, lifecycleObserver)
        return token
    }

    fun attachHost(
        attachment: NativeGameWebViewActivityAttachment,
        host: NativeGameWebViewHostOperations,
    ) {
        val binding = activityBinding
        check(binding?.token === attachment) { "Native game WebView Activity is not attached" }
        check(!binding.detaching) { "Native game WebView Activity is detaching" }
        check(binding.unavailable == null) { "Native game WebView Activity is unavailable" }
        check(binding.host == null) { "Native game WebView host is already attached" }
        binding.host = host
        dispatchNext(binding)
    }

    fun attachUnavailable(
        attachment: NativeGameWebViewActivityAttachment,
        unavailable: NativeWebViewActivityStartupOutcome.Unavailable,
    ) {
        val binding = activityBinding
        check(binding?.token === attachment) { "Native game WebView Activity is not attached" }
        check(!binding.detaching) { "Native game WebView Activity is detaching" }
        markBindingUnavailable(binding, unavailable, includeRebindCalls = true)
    }

    fun eventSinkFor(attachment: NativeGameWebViewActivityAttachment): NativeGameWebViewEventSink {
        val binding = activityBinding
        check(binding?.token === attachment) { "Native game WebView Activity is not attached" }
        val attachmentId = attachment.id
        return object : NativeGameWebViewEventSink {
            override fun created(generation: Long) = handleCreated(attachmentId, generation)

            override fun pageStarted(generation: Long, url: String) =
                handlePageStarted(attachmentId, generation, url)

            override fun pageFinished(generation: Long, url: String) =
                handlePageFinished(attachmentId, generation, url)

            override fun presentationChanged(generation: Long, isGame: Boolean) =
                emitForGeneration(
                    attachmentId,
                    generation,
                    mapOf(
                        "type" to "presentationChanged",
                        "generationId" to generation,
                        "isGame" to isGame,
                    ),
                )

            override fun mainFrameError(generation: Long, errorCode: Int, description: String) =
                handleMainFrameError(attachmentId, generation, errorCode, description)

            override fun presentationPending(generation: Long) =
                emitForGeneration(
                    attachmentId,
                    generation,
                    mapOf(
                        "type" to "presentationChanged",
                        "generationId" to generation,
                        "isGame" to false,
                        "state" to "pending",
                    ),
                )

            override fun resourceError(generation: Long, errorCode: Int) =
                emitForGeneration(
                    attachmentId,
                    generation,
                    mapOf(
                        "type" to "resourceError",
                        "generationId" to generation,
                        "errorCode" to errorCode,
                        "description" to "",
                    ),
                )

            override fun navigationBlocked(generation: Long, scheme: String) =
                handleNavigationBlocked(attachmentId, generation, scheme)

            override fun renderProcessGone(generation: Long, didCrash: Boolean) =
                handleRenderProcessGone(attachmentId, generation, didCrash)

            override fun destroyed(generation: Long) = handleDestroyed(attachmentId, generation)
        }
    }

    fun detachActivity(attachment: NativeGameWebViewActivityAttachment) {
        val binding = activityBinding
        if (binding?.token !== attachment) return
        detachBinding(binding)
    }

    private fun detachBinding(binding: ActivityBinding) {
        binding.detaching = true
        asyncVersion++
        binding.operationWatchdog?.cancel()
        binding.operationWatchdog = null
        val abandoned = pendingCalls.filter { it.attachmentId == binding.token.id }
        pendingCalls.removeAll { it.attachmentId == binding.token.id }
        callRunning = false
        dispatchVersion++
        abandoned.forEach { pending ->
            completeError(
                pending,
                HOST_UNAVAILABLE,
                "The native WebView Activity was detached.",
            )
        }
        binding.host?.currentGeneration?.let { generation ->
            try {
                binding.host?.destroy(generation)
            } catch (_: Exception) {
                acceptedGeneration = null
            }
        }
        binding.host = null
        acceptedGeneration = null
        if (activityBinding === binding) activityBinding = null
    }

    fun shutdownEngine() {
        if (engineDestroyed) return
        activityBinding?.let(::detachBinding)
        engineDestroyed = true
        acceptedGeneration = null
        failPendingRebindCalls()
        val sink = eventSink
        eventSink = null
        try {
            sink?.endOfStream()
        } catch (_: Exception) {
            // A detached Flutter listener must not break engine cleanup.
        }
    }

    /** Compatibility alias for tests and explicit permanent teardown. */
    fun disable() = shutdownEngine()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in SUPPORTED_METHODS) {
            safeNotImplemented(result)
            return
        }
        val parsed = try {
            parseCall(call)
        } catch (error: InvalidArgumentsException) {
            safeError(result, INVALID_ARGUMENT, error.message)
            return
        }
        if (engineDestroyed) {
            safeError(result, ACTIVITY_DESTROYED, "The Flutter engine has been destroyed.")
            return
        }
        val binding = activityBinding
        binding?.unavailable?.let { unavailable ->
            safeError(result, unavailable.errorCode, unavailable.message)
            return
        }
        if (binding == null || binding.detaching || binding.host == null) {
            enqueueDuringRebind(parsed, result)
            return
        }
        pendingCalls.addLast(PendingCall(parsed, result, binding.token.id))
        dispatchNext(binding)
    }

    private fun dispatchNext(binding: ActivityBinding) {
        if (callRunning || pendingCalls.isEmpty()) return
        if (activityBinding !== binding || binding.detaching || binding.unavailable != null) {
            return
        }
        callRunning = true
        val version = ++dispatchVersion
        try {
            binding.dispatchToMain {
                if (version != dispatchVersion) return@dispatchToMain
                if (
                    activityBinding !== binding ||
                    binding.detaching ||
                    binding.unavailable != null ||
                    pendingCalls.isEmpty()
                ) {
                    callRunning = false
                    return@dispatchToMain
                }
                val pending = pendingCalls.first()
                pending.attachmentId = binding.token.id
                executeOnMain(binding, pending)
            }
        } catch (error: Exception) {
            if (version != dispatchVersion) return
            markBindingUnavailable(
                binding,
                NativeWebViewActivityStartupOutcome.Unavailable(
                    HOST_UNAVAILABLE,
                    error.message ?: "Unable to dispatch native WebView operation.",
                ),
                includeRebindCalls = true,
            )
        }
    }

    private fun enqueueDuringRebind(parsed: ParsedCall, result: MethodChannel.Result) {
        val hasPendingCreate = pendingCalls.any { it.parsed.method == "create" }
        if (parsed.method == "create") {
            if (hasPendingCreate) {
                safeError(result, HOST_UNAVAILABLE, "A native WebView create is already pending rebind.")
            } else {
                pendingCalls.addLast(PendingCall(parsed, result))
            }
            return
        }
        if (hasPendingCreate) {
            pendingCalls.addLast(PendingCall(parsed, result))
        } else {
            safeError(result, HOST_UNAVAILABLE, "The native WebView host is unavailable.")
        }
    }

    private fun failPendingRebindCalls() {
        callRunning = false
        dispatchVersion++
        while (pendingCalls.isNotEmpty()) {
            completeError(
                pendingCalls.removeFirst(),
                HOST_UNAVAILABLE,
                "The native WebView host is unavailable.",
            )
        }
    }

    private fun markBindingUnavailable(
        binding: ActivityBinding,
        unavailable: NativeWebViewActivityStartupOutcome.Unavailable,
        includeRebindCalls: Boolean,
    ) {
        if (activityBinding !== binding || binding.detaching) return
        binding.unavailable = unavailable
        binding.operationWatchdog?.cancel()
        binding.operationWatchdog = null
        asyncVersion++
        dispatchVersion++
        callRunning = false
        val failed = pendingCalls.filter { pending ->
            pending.attachmentId == binding.token.id ||
                (includeRebindCalls && pending.attachmentId == null)
        }
        pendingCalls.removeAll(failed.toSet())
        failed.forEach { pending ->
            completeError(pending, unavailable.errorCode, unavailable.message)
        }
    }

    private fun executeOnMain(binding: ActivityBinding, pending: PendingCall) {
        val host = binding.host
        if (host == null) {
            finish(binding, pending) {
                safeError(pending.result, HOST_UNAVAILABLE, "The native WebView host is unavailable.")
            }
            return
        }
        val parsed = pending.parsed
        try {
            if (parsed.method == "create") {
                host.currentGeneration?.let { oldGeneration ->
                    check(host.destroy(oldGeneration)) { "Unable to destroy the previous native WebView" }
                }
                val generation = host.create()
                if (generation == null || generation < 0L) {
                    safeObserverCall(binding.lifecycleObserver::onCreateFailed)
                    error("Unable to create the native WebView")
                }
                acceptedGeneration = generation
                pendingCalls.drop(1).forEach { queued ->
                    if (queued.attachmentId == null) queued.attachmentId = binding.token.id
                }
                finish(binding, pending) { safeSuccess(pending.result, generation) }
                return
            }

            val generation = checkNotNull(parsed.generation)
            if (host.currentGeneration != generation || acceptedGeneration != generation) {
                finish(binding, pending) {
                    safeError(pending.result, STALE_GENERATION, "The native WebView generation is stale.")
                }
                return
            }

            when (parsed.method) {
                "setBounds" -> {
                    check(host.setBounds(generation, checkNotNull(parsed.bounds))) {
                        "The native WebView bounds could not be applied"
                    }
                    finishSuccess(binding, pending)
                }
                "setVisible" -> {
                    check(host.setVisible(generation, checkNotNull(parsed.visible))) {
                        "The native WebView visibility could not be applied"
                    }
                    finishSuccess(binding, pending)
                }
                "loadUri" -> {
                    host.loadUri(checkNotNull(parsed.text))
                    finishSuccess(binding, pending)
                }
                "showLocalHome" -> {
                    host.showLocalHome(checkNotNull(parsed.text))
                    finishSuccess(binding, pending)
                }
                "reload" -> {
                    host.reload()
                    finishSuccess(binding, pending)
                }
                "canGoBack" -> finish(binding, pending) {
                    safeSuccess(pending.result, host.canGoBack())
                }
                "goBack" -> {
                    host.goBack()
                    finishSuccess(binding, pending)
                }
                "runJavaScript" -> {
                    host.runJavaScript(checkNotNull(parsed.text))
                    finishSuccess(binding, pending)
                }
                "fitGameScreen" -> {
                    host.fitGameScreen(checkNotNull(parsed.text))
                    finishSuccess(binding, pending)
                }
                "clearCache" -> {
                    host.clearCache()
                    finishSuccess(binding, pending)
                }
                "clearSession" -> startClearSession(binding, pending, host)
                "destroy" -> {
                    check(host.destroy(generation)) { "Unable to destroy the native WebView" }
                    finishSuccess(binding, pending)
                }
            }
        } catch (error: Exception) {
            finish(binding, pending) {
                if (error is NativeGameWebViewCreateException) {
                    safeError(
                        pending.result,
                        CREATE_FAILED,
                        error.message,
                        error.safeDetails,
                    )
                } else {
                    safeError(
                        pending.result,
                        HOST_ERROR,
                        error.message ?: "Native WebView operation failed.",
                    )
                }
            }
        }
    }

    private fun startClearSession(
        binding: ActivityBinding,
        pending: PendingCall,
        host: NativeGameWebViewHostOperations,
    ) {
        val version = ++asyncVersion
        val attachmentId = binding.token.id
        val weakChannel = WeakReference(this)
        val weakPending = WeakReference(pending)
        try {
            binding.operationWatchdog = operationTimeoutScheduler.schedule(CLEAR_SESSION_TIMEOUT_MS) {
                val activePending = weakPending.get() ?: return@schedule
                weakChannel.get()?.onClearSessionWatchdog(version, attachmentId, activePending)
            }
            host.clearSession { error ->
                val activePending = weakPending.get() ?: return@clearSession
                weakChannel.get()?.onClearSessionComplete(version, attachmentId, activePending, error)
            }
        } catch (error: Exception) {
            if (pending.asyncCompletionClaimed.compareAndSet(false, true)) {
                markBindingUnavailable(
                    binding,
                    NativeWebViewActivityStartupOutcome.Unavailable(
                        HOST_UNAVAILABLE,
                        error.message ?: "Unable to clear the native WebView session.",
                    ),
                    includeRebindCalls = false,
                )
            }
        }
    }

    private fun onClearSessionComplete(
        version: Long,
        attachmentId: Long,
        pending: PendingCall,
        error: Exception?,
    ) {
        if (!pending.asyncCompletionClaimed.compareAndSet(false, true)) return
        val binding = activityBinding ?: return
        if (
            version != asyncVersion ||
            binding.token.id != attachmentId ||
            binding.detaching ||
            binding.unavailable != null ||
            pending.terminal.get()
        ) {
            return
        }
        try {
            binding.dispatchToMain callback@{
                val activeBinding = activityBinding
                if (
                    version != asyncVersion ||
                    activeBinding !== binding ||
                    binding.detaching ||
                    binding.unavailable != null ||
                    pending.terminal.get()
                ) {
                    return@callback
                }
                finish(binding, pending) {
                    if (error == null) safeSuccess(pending.result, null)
                    else safeError(
                        pending.result,
                        HOST_ERROR,
                        error.message ?: "Unable to clear the native WebView session.",
                    )
                }
            }
        } catch (dispatchError: Exception) {
            markBindingUnavailable(
                binding,
                NativeWebViewActivityStartupOutcome.Unavailable(
                    HOST_UNAVAILABLE,
                    dispatchError.message ?: "Unable to dispatch the native WebView session result.",
                ),
                includeRebindCalls = false,
            )
        }
    }

    private fun onClearSessionWatchdog(
        version: Long,
        attachmentId: Long,
        pending: PendingCall,
    ) {
        if (!pending.asyncCompletionClaimed.compareAndSet(false, true)) return
        val binding = activityBinding ?: return
        if (
            version != asyncVersion ||
            binding.token.id != attachmentId ||
            binding.detaching ||
            pending.terminal.get()
        ) {
            return
        }
        try {
            binding.dispatchToMain timeout@{
                val activeBinding = activityBinding
                if (
                    version != asyncVersion ||
                    activeBinding !== binding ||
                    binding.detaching ||
                    pending.terminal.get()
                ) {
                    return@timeout
                }
                markBindingUnavailable(
                    binding,
                    NativeWebViewActivityStartupOutcome.Unavailable(
                        HOST_UNAVAILABLE,
                        "Native WebView session clearing timed out.",
                    ),
                    includeRebindCalls = false,
                )
            }
        } catch (error: Exception) {
            markBindingUnavailable(
                binding,
                NativeWebViewActivityStartupOutcome.Unavailable(
                    HOST_UNAVAILABLE,
                    error.message ?: "Unable to dispatch the native WebView session timeout.",
                ),
                includeRebindCalls = false,
            )
        }
    }

    private fun finishSuccess(binding: ActivityBinding, pending: PendingCall) =
        finish(binding, pending) { safeSuccess(pending.result, null) }

    private fun finish(binding: ActivityBinding, pending: PendingCall, completion: () -> Unit) {
        if (activityBinding !== binding || binding.detaching || pendingCalls.firstOrNull() !== pending) return
        binding.operationWatchdog?.cancel()
        binding.operationWatchdog = null
        pendingCalls.removeFirst()
        callRunning = false
        if (pending.terminal.compareAndSet(false, true)) completion()
        dispatchNext(binding)
    }

    private fun completeError(pending: PendingCall, code: String, message: String) {
        if (pending.terminal.compareAndSet(false, true)) {
            safeError(pending.result, code, message)
        }
    }

    private fun parseCall(call: MethodCall): ParsedCall {
        val arguments = strictMap(call.arguments)
        return when (call.method) {
            "create" -> {
                requireExactKeys(arguments, setOf("renderer"))
                if (arguments["renderer"] != "webgl") invalid("renderer must be webgl")
                ParsedCall(call.method)
            }
            "setBounds" -> {
                requireExactKeys(arguments, setOf("generationId", "bounds"))
                ParsedCall(call.method, requireGeneration(arguments), bounds = parseBounds(arguments["bounds"]))
            }
            "setVisible" -> {
                requireExactKeys(arguments, setOf("generationId", "visible"))
                val visible = arguments["visible"] as? Boolean ?: invalid("visible must be a boolean")
                ParsedCall(call.method, requireGeneration(arguments), visible = visible)
            }
            "loadUri" -> {
                requireExactKeys(arguments, setOf("generationId", "uri"))
                val uri = arguments["uri"] as? String ?: invalid("uri must be a string")
                if (!isSafeWebUri(uri)) invalid("uri must be an absolute HTTP(S) URI")
                ParsedCall(call.method, requireGeneration(arguments), text = uri)
            }
            "showLocalHome" -> {
                requireExactKeys(arguments, setOf("generationId", "html"))
                val html = arguments["html"] as? String ?: invalid("html must be a string")
                if (html.length > MAX_LOCAL_HOME_LENGTH) invalid("html is too large")
                ParsedCall(call.method, requireGeneration(arguments), text = html)
            }
            "runJavaScript" -> {
                requireExactKeys(arguments, setOf("generationId", "javascript"))
                val javascript = arguments["javascript"] as? String ?: invalid("javascript must be a string")
                ParsedCall(call.method, requireGeneration(arguments), text = javascript)
            }
            "fitGameScreen" -> {
                requireExactKeys(arguments, setOf("generationId", "javascript"))
                val javascript = arguments["javascript"] as? String ?: invalid("javascript must be a string")
                if (javascript.length > MAX_FIT_SCRIPT_LENGTH) invalid("javascript is too large")
                ParsedCall(call.method, requireGeneration(arguments), text = javascript)
            }
            else -> {
                requireExactKeys(arguments, setOf("generationId"))
                ParsedCall(call.method, requireGeneration(arguments))
            }
        }
    }

    private fun requireGeneration(arguments: Map<String, Any?>): Long {
        val value = arguments["generationId"]
        val generation = when (value) {
            is Int -> value.toLong()
            is Long -> value
            else -> invalid("generationId must be an integer")
        }
        if (generation < 0L) invalid("generationId must be non-negative")
        return generation
    }

    private fun parseBounds(raw: Any?): NativeGameWebViewBounds {
        val bounds = strictMap(raw)
        val hasClip = bounds.keys.any { it in CLIP_KEYS }
        requireExactKeys(bounds, if (hasClip) BOUNDS_KEYS + CLIP_KEYS else BOUNDS_KEYS)
        fun double(key: String): Double =
            (bounds[key] as? Double)?.takeIf(Double::isFinite) ?:
                invalid("$key must be a finite double")
        return try {
            NativeGameWebViewBounds(
                left = double("left"),
                top = double("top"),
                width = double("width"),
                height = double("height"),
                devicePixelRatio = double("devicePixelRatio"),
                clipLeft = if (hasClip) double("clipLeft") else null,
                clipTop = if (hasClip) double("clipTop") else null,
                clipWidth = if (hasClip) double("clipWidth") else null,
                clipHeight = if (hasClip) double("clipHeight") else null,
            )
        } catch (error: IllegalArgumentException) {
            invalid(error.message ?: "Invalid bounds")
        }
    }

    private fun strictMap(raw: Any?): Map<String, Any?> {
        if (raw !is Map<*, *>) invalid("arguments must be a map")
        if (raw.keys.any { it !is String }) invalid("argument keys must be strings")
        @Suppress("UNCHECKED_CAST")
        return raw as Map<String, Any?>
    }

    private fun requireExactKeys(arguments: Map<String, Any?>, expected: Set<String>) {
        if (arguments.keys != expected) invalid("arguments do not match the method schema")
    }

    private fun isSafeWebUri(raw: String): Boolean =
        try {
            val uri = URI(raw)
            (uri.scheme == "http" || uri.scheme == "https") && !uri.host.isNullOrEmpty()
        } catch (_: Exception) {
            false
        }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (!engineDestroyed) eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun handleCreated(attachmentId: Long, generation: Long) {
        val binding = bindingForEvent(attachmentId) ?: return
        if (binding.host?.currentGeneration != generation) return
        acceptedGeneration = generation
        runCatching { binding.lifecycleObserver.onCreated() }
        emit(mapOf("type" to "created", "generationId" to generation))
    }

    private fun handlePageStarted(attachmentId: Long, generation: Long, url: String) {
        val binding = bindingForAcceptedEvent(attachmentId, generation) ?: return
        safeObserverCall(binding.lifecycleObserver::onPageStarted)
        emit(
            mapOf("type" to "pageStarted", "generationId" to generation, "url" to url),
        )
    }

    private fun handlePageFinished(attachmentId: Long, generation: Long, url: String) {
        val binding = bindingForAcceptedEvent(attachmentId, generation) ?: return
        safeObserverCall(binding.lifecycleObserver::onPageFinished)
        emit(mapOf("type" to "pageFinished", "generationId" to generation, "url" to url))
    }

    private fun handleMainFrameError(
        attachmentId: Long,
        generation: Long,
        errorCode: Int,
        description: String,
    ) {
        emitForGeneration(
            attachmentId,
            generation,
            mapOf(
                "type" to "mainFrameError",
                "generationId" to generation,
                "errorCode" to errorCode,
                "description" to description,
            ),
        )
    }

    private fun handleNavigationBlocked(attachmentId: Long, generation: Long, scheme: String) {
        emitForGeneration(
            attachmentId,
            generation,
            mapOf("type" to "navigationBlocked", "generationId" to generation, "scheme" to scheme),
        )
    }

    private fun handleRenderProcessGone(attachmentId: Long, generation: Long, didCrash: Boolean) {
        val binding = bindingForAcceptedEvent(attachmentId, generation) ?: return
        safeObserverCall(binding.lifecycleObserver::onRenderProcessGone)
        emit(
            mapOf(
                "type" to "renderProcessGone",
                "generationId" to generation,
                "didCrash" to didCrash,
            ),
        )
    }

    private fun handleDestroyed(attachmentId: Long, generation: Long) {
        val binding = bindingForAcceptedEvent(
            attachmentId,
            generation,
            allowDetaching = true,
        ) ?: return
        emit(mapOf("type" to "destroyed", "generationId" to generation))
        if (activityBinding === binding && acceptedGeneration == generation) {
            acceptedGeneration = null
        }
    }

    private fun emitForGeneration(attachmentId: Long, generation: Long, event: Map<String, Any?>) {
        if (bindingForAcceptedEvent(attachmentId, generation) != null) emit(event)
    }

    private fun bindingForAcceptedEvent(
        attachmentId: Long,
        generation: Long,
        allowDetaching: Boolean = false,
    ): ActivityBinding? =
        bindingForEvent(attachmentId, allowDetaching)
            ?.takeIf { acceptedGeneration == generation }

    private fun bindingForEvent(
        attachmentId: Long,
        allowDetaching: Boolean = false,
    ): ActivityBinding? {
        if (engineDestroyed) return null
        val binding = activityBinding ?: return null
        if (binding.token.id != attachmentId) return null
        if (binding.detaching && !allowDetaching) return null
        return binding
    }

    private fun emit(event: Map<String, Any?>) {
        val sink = eventSink ?: return
        try {
            sink.success(event)
        } catch (_: Exception) {
            // A detached Flutter listener must not break WebView lifecycle work.
        }
    }

    private fun safeObserverCall(callback: () -> Unit) {
        try {
            callback()
        } catch (_: Exception) {
            // Startup diagnostics must not break the primary WebView callback.
        }
    }

    private fun safeSuccess(result: MethodChannel.Result, value: Any?) {
        try {
            result.success(value)
        } catch (_: Exception) {
            // A detached Dart caller must not stop command serialization.
        }
    }

    private fun safeError(
        result: MethodChannel.Result,
        code: String,
        message: String?,
        details: Any? = null,
    ) {
        try {
            result.error(code, message, details)
        } catch (_: Exception) {
            // A detached Dart caller must not stop command serialization.
        }
    }

    private fun safeNotImplemented(result: MethodChannel.Result) {
        try {
            result.notImplemented()
        } catch (_: Exception) {
            // A detached Dart caller must not break the engine handler.
        }
    }

    private class InvalidArgumentsException(message: String) : IllegalArgumentException(message)

    companion object {
        const val METHOD_CHANNEL_NAME = "app.yahagi.kancollebrowser/native_game_webview"
        const val EVENT_CHANNEL_NAME = "app.yahagi.kancollebrowser/native_game_webview_events"
        val SUPPORTED_METHODS = setOf(
            "create",
            "setBounds",
            "setVisible",
            "loadUri",
            "showLocalHome",
            "reload",
            "canGoBack",
            "goBack",
            "runJavaScript",
            "fitGameScreen",
            "clearCache",
            "clearSession",
            "destroy",
        )
        val BOUNDS_KEYS = setOf("left", "top", "width", "height", "devicePixelRatio")
        val CLIP_KEYS = setOf("clipLeft", "clipTop", "clipWidth", "clipHeight")
        const val INVALID_ARGUMENT = "invalid_argument"
        const val STALE_GENERATION = "stale_generation"
        const val HOST_UNAVAILABLE = "native_webview_unavailable"
        const val HOST_ERROR = "native_webview_error"
        const val CREATE_FAILED = "native_webview_create_failed"
        const val ACTIVITY_DESTROYED = "activity_destroyed"
        const val CLEAR_SESSION_TIMEOUT_MS = 10_000L
        const val MAX_LOCAL_HOME_LENGTH = 64 * 1024
        const val MAX_FIT_SCRIPT_LENGTH = 64 * 1024

        fun invalid(message: String): Nothing = throw InvalidArgumentsException(message)
    }
}

internal class NativeGameWebViewChannelRegistry<K : Any>(
    private val channelFactory: () -> NativeGameWebViewChannel = ::NativeGameWebViewChannel,
) {
    // Both sides are weak: EventSink can retain its messenger/engine through the channel value.
    private val channels = WeakHashMap<K, WeakReference<NativeGameWebViewChannel>>()

    @Synchronized
    fun acquire(key: K, register: (NativeGameWebViewChannel) -> Unit): NativeGameWebViewChannel =
        channels[key]?.get() ?: channelFactory().also { channel ->
            register(channel)
            channels[key] = WeakReference(channel)
        }

    @Synchronized
    fun peek(key: K): NativeGameWebViewChannel? = channels[key]?.get()

    @Synchronized
    fun remove(key: K): NativeGameWebViewChannel? = channels.remove(key)?.get()
}

internal object NativeGameWebViewEngineChannels {
    private val registry = NativeGameWebViewChannelRegistry<FlutterEngine> {
        NativeGameWebViewChannel(AndroidNativeGameWebViewOperationTimeoutScheduler)
    }

    fun acquire(engine: FlutterEngine): NativeGameWebViewChannel =
        registry.acquire(engine) { channel ->
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                NativeGameWebViewChannel.METHOD_CHANNEL_NAME,
            ).setMethodCallHandler(channel)
            EventChannel(
                engine.dartExecutor.binaryMessenger,
                NativeGameWebViewChannel.EVENT_CHANNEL_NAME,
            ).setStreamHandler(channel)
        }

    fun destroy(engine: FlutterEngine) {
        val channel = registry.remove(engine) ?: return
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            NativeGameWebViewChannel.METHOD_CHANNEL_NAME,
        ).setMethodCallHandler(null)
        EventChannel(
            engine.dartExecutor.binaryMessenger,
            NativeGameWebViewChannel.EVENT_CHANNEL_NAME,
        ).setStreamHandler(null)
        channel.shutdownEngine()
    }
}

internal interface NativeWebViewSnapshotEditor {
    fun putInt(key: String, value: Int): NativeWebViewSnapshotEditor
    fun putLong(key: String, value: Long): NativeWebViewSnapshotEditor
    fun putString(key: String, value: String): NativeWebViewSnapshotEditor
    fun remove(key: String): NativeWebViewSnapshotEditor
    fun commit(): Boolean
}

internal interface NativeWebViewSnapshotPreferences {
    fun readAll(): Map<String, Any?>
    fun edit(): NativeWebViewSnapshotEditor
}

private class AndroidNativeWebViewSnapshotPreferences(
    private val preferences: SharedPreferences,
) : NativeWebViewSnapshotPreferences {
    override fun readAll(): Map<String, Any?> = preferences.all

    @SuppressLint("CommitPrefEdits")
    override fun edit(): NativeWebViewSnapshotEditor =
        object : NativeWebViewSnapshotEditor {
            private val editor = preferences.edit()

            override fun putInt(key: String, value: Int) = apply { editor.putInt(key, value) }
            override fun putLong(key: String, value: Long) = apply { editor.putLong(key, value) }
            override fun putString(key: String, value: String) = apply { editor.putString(key, value) }
            override fun remove(key: String) = apply { editor.remove(key) }
            override fun commit(): Boolean = editor.commit()
        }
}

internal class NativeWebViewStartupStoreProcessState {
    @Volatile
    private var poisoned = false

    fun isPoisoned(): Boolean = poisoned

    fun poison() {
        poisoned = true
    }
}

internal class SharedPreferencesNativeWebViewStartupStore internal constructor(
    private val preferences: NativeWebViewSnapshotPreferences,
    private val processState: NativeWebViewStartupStoreProcessState,
) : NativeWebViewStartupStore {
    constructor(preferences: SharedPreferences) : this(
        AndroidNativeWebViewSnapshotPreferences(preferences),
        NativeWebViewProcessState.startupStore,
    )

    override fun read(): NativeWebViewStartupReadResult {
        if (processState.isPoisoned()) return NativeWebViewStartupReadResult.Unavailable
        return try {
            val values = preferences.readAll()
            NativeWebViewStartupReadResult.Success(
                NativeWebViewStartupSnapshot(
                    consecutiveFailures = values.optionalTyped<Int>(
                        NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY,
                    ) ?: 0,
                    attemptStartedAtMs = values.optionalTyped<Long>(
                        NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY,
                    ),
                    attemptSessionId = values.optionalTyped<String>(
                        NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY,
                    )?.let(::NativeWebViewProcessSessionId),
                    storedRenderingMode = values.optionalTyped<String>(
                        NativeWebViewStartupGuard.RENDERING_MODE_KEY,
                    ),
                ),
            )
        } catch (_: Exception) {
            NativeWebViewStartupReadResult.Unavailable
        }
    }

    override fun write(nextSnapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupWriteResult {
        if (processState.isPoisoned()) return NativeWebViewStartupWriteResult.Indeterminate
        return try {
            val editor = preferences.edit()
                .putInt(
                    NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY,
                    nextSnapshot.consecutiveFailures,
                )
                .putNullableLong(
                    NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY,
                    nextSnapshot.attemptStartedAtMs,
                )
                .putNullableString(
                    NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY,
                    nextSnapshot.attemptSessionId?.value,
                )
                .putNullableString(
                    NativeWebViewStartupGuard.RENDERING_MODE_KEY,
                    nextSnapshot.storedRenderingMode,
                )
            if (editor.commit()) {
                NativeWebViewStartupWriteResult.Durable
            } else {
                processState.poison()
                NativeWebViewStartupWriteResult.Indeterminate
            }
        } catch (_: Exception) {
            processState.poison()
            NativeWebViewStartupWriteResult.Indeterminate
        }
    }

    private inline fun <reified T> Map<String, Any?>.optionalTyped(key: String): T? {
        if (!containsKey(key)) return null
        return get(key) as? T ?: throw IllegalStateException("Invalid persisted type for $key")
    }

    private fun NativeWebViewSnapshotEditor.putNullableLong(key: String, value: Long?) =
        if (value == null) remove(key) else putLong(key, value)

    private fun NativeWebViewSnapshotEditor.putNullableString(key: String, value: String?) =
        if (value == null) remove(key) else putString(key, value)
}

internal class NativeWebViewProcessSessionIdProvider(
    private val factory: () -> NativeWebViewProcessSessionId,
) {
    @Volatile
    private var cached: NativeWebViewProcessSessionId? = null

    fun current(): NativeWebViewProcessSessionId =
        cached ?: synchronized(this) {
            cached ?: factory().also { cached = it }
        }
}

internal object NativeWebViewProcessState {
    val startupStore = NativeWebViewStartupStoreProcessState()
    private val sessionProvider = NativeWebViewProcessSessionIdProvider {
        NativeWebViewProcessSessionId(UUID.randomUUID().toString())
    }

    val sessionId: NativeWebViewProcessSessionId
        get() = sessionProvider.current()
}
