package app.yahagi.kancollebrowser.nativewebview

import android.app.Activity
import android.app.Dialog
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.webkit.WebView
import android.widget.Button
import android.widget.CheckBox
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import app.yahagi.kancollebrowser.R
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/** One native window owns warnings, queued reminders and post-action input. */
internal class NativeGameWarningDialogChannel(
    private val activity: Activity,
    engine: FlutterEngine,
    private val checklistEventSink: ((Map<String, Any>) -> Unit)? = null,
    private val gameWebView: () -> WebView?,
) : MethodChannel.MethodCallHandler {
    private class Request(var spec: NativeGameWarningDialogSpec, val owner: WebView, result: MethodChannel.Result) {
        private var result: MethodChannel.Result? = result
        var action: String? = null
        var cancelled = false
        var scrollY = 0
        var checkboxChecked = spec.checkbox?.checked ?: false
        val checklistChanges = NativeGameChecklistChangeState(spec.appliedChangeId)
        fun complete(value: String?) {
            val completion = result
            result = null
            completion?.success(if (spec.isSurfaceDialog && value != null) {
                mapOf("action" to value, "checked" to checkboxChecked)
            } else value)
        }
        fun fail(error: Exception) {
            val completion = result
            result = null
            completion?.error("native_warning_failed", error.message ?: "Cannot present warning", null)
        }
    }

    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
    private val handler = Handler(Looper.getMainLooper())
    private val state = NativeGameWarningDialogState()
    private val queue = NativeGameDialogQueue()
    private val requests = linkedMapOf<NativeGameDialogKey, Request>()
    private class AvailabilityWait(val result: MethodChannel.Result, val deadline: Long) {
        lateinit var poll: Runnable
    }
    private val availabilityWaits = linkedSetOf<AvailabilityWait>()
    private var dialog: Dialog? = null
    private var root: FrameLayout? = null
    private var release: Runnable? = null
    private var backCallback: OnBackInvokedCallback? = null
    private data class RenderedKey(val key: NativeGameDialogKey, val version: Long)
    private var renderVersion = 0L
    private data class ChecklistIcon(val host: FrameLayout, val asset: ImageView, val glyph: TextView, var assetPath: String? = null)
    private data class ChecklistRow(val checkbox: CheckBox, val value: TextView, val icon: ChecklistIcon)
    private class ChecklistViews(
        val key: NativeGameDialogKey,
        val version: Long,
        val title: TextView,
        val done: Button,
        val reset: Button?,
        val scroll: ScrollView,
        val rows: LinkedHashMap<String, ChecklistRow>,
    ) {
        var restoringScroll = true
        var patching = false
    }
    private var checklistViews: ChecklistViews? = null
    private val checklistIconTypeface: Typeface? by lazy {
        runCatching { Typeface.createFromAsset(activity.assets, flutterAssetKey("fonts/MaterialIcons-Regular.otf")) }.getOrNull()
    }
    private var backKeyDown: RenderedKey? = null
    private var foreground = true
    private var disposed = false
    private var outsideDown: NativeGameDialogKey? = null
    private var outsideX = 0f
    private var outsideY = 0f
    private val touchSlop = ViewConfiguration.get(activity).scaledTouchSlop.toFloat()

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        check(Looper.myLooper() == Looper.getMainLooper())
        if (disposed) {
            if (call.method == "waitUntilAvailable") result.success(false)
            else result.error("native_warning_unavailable", "The warning host has been disposed", null)
            return
        }
        try {
            when (call.method) {
                "waitUntilAvailable" -> waitUntilAvailable(result)
                "show" -> present(NativeGameWarningDialogSpec.parse(call.arguments), result)
                "update" -> {
                    val next = NativeGameWarningDialogSpec.parse(call.arguments)
                    val request = requests[next.key]
                    if (request != null && !request.cancelled && request.action == null) {
                        request.spec = reconcileChecklistUpdate(request, next)
                        if (queue.active == next.key && !state.actionChosen) render(request.spec)
                    }
                    result.success(null)
                }
                "dismiss" -> {
                    dismiss(requestKey(call))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("native_warning_failed", error.message ?: "Cannot present warning", null)
        }
    }

    /** Observes readiness only: no modal, surface visibility change or queue reservation. */
    private fun waitUntilAvailable(result: MethodChannel.Result) {
        if (!foreground || activity.isFinishing || activity.isDestroyed) {
            result.success(false)
            return
        }
        if (availableGameWebView(requireVisible = true) != null) {
            result.success(true)
            return
        }
        val wait = AvailabilityWait(result, SystemClock.uptimeMillis() + AVAILABILITY_TIMEOUT_MILLIS)
        wait.poll = Runnable {
            if (wait !in availabilityWaits) return@Runnable
            val now = SystemClock.uptimeMillis()
            when {
                disposed || !foreground || activity.isFinishing || activity.isDestroyed || now >= wait.deadline ->
                    finishAvailabilityWait(wait, false)
                runCatching { availableGameWebView(requireVisible = true) != null }.getOrDefault(false) ->
                    finishAvailabilityWait(wait, true)
                else -> handler.postDelayed(wait.poll, minOf(AVAILABILITY_POLL_MILLIS, wait.deadline - now))
            }
        }
        availabilityWaits.add(wait)
        handler.postDelayed(wait.poll, AVAILABILITY_POLL_MILLIS)
    }

    private fun finishAvailabilityWait(wait: AvailabilityWait, available: Boolean) {
        if (!availabilityWaits.remove(wait)) return
        handler.removeCallbacks(wait.poll)
        wait.result.success(available)
    }

    private fun cancelAvailabilityWaits() {
        availabilityWaits.toList().forEach { finishAvailabilityWait(it, false) }
    }

    private fun availableGameWebView(requireVisible: Boolean): WebView? {
        if (activity.isFinishing || activity.isDestroyed) return null
        return gameWebView()?.takeIf { it.isAttachedToWindow && (!requireVisible || it.isShown) }
    }

    private fun requestKey(call: MethodCall): NativeGameDialogKey {
        val kind = call.argument<String>("kind") ?: "battle"
        require(kind in NativeGameWarningDialogSpec.kinds)
        val id = call.argument<Number>("id")?.toLong()?.takeIf { it > 0 }
            ?: error("Warning id is missing")
        return NativeGameDialogKey(kind, id)
    }

    private fun present(next: NativeGameWarningDialogSpec, result: MethodChannel.Result) {
        val webView = availableGameWebView(requireVisible = foreground)
        if (webView == null) {
            result.error("native_warning_unavailable", "No visible native game WebView is ready", null)
            return
        }
        require(next.key !in requests) { "Duplicate dialog request" }
        require(requests.size < 64) { "Too many pending reminders" }
        val previous = queue.active
        val activated = queue.offer(next.kind, next.id, state.actionChosen)
        requests[next.key] = Request(next, webView, result)
        if (activated) {
            // Preserve a preempted ordinary reminder. Replacing an unconfirmed
            // battle retains its existing cancellation semantics.
            if (previous != null && previous.isBattle) requests.remove(previous)?.complete(null)
            activateCurrent()
        }
    }

    private fun activateCurrent() {
        cancelRelease()
        resetOutsideTap()
        while (true) {
            val key = queue.active ?: run { closeWindow(); return }
            val request = requests[key]
            if (request == null || request.owner !== gameWebView() ||
                !request.owner.isAttachedToWindow || activity.isFinishing || activity.isDestroyed
            ) {
                requests.remove(key)?.complete(null)
                state.id?.let(state::dismiss)
                queue.finish(key.kind, key.id)
                continue
            }
            try {
                state.present(key.id)
                if (dialog == null) createWindow()
                render(request.spec)
                val now = SystemClock.uptimeMillis()
                val cancel = MotionEvent.obtain(now, now, MotionEvent.ACTION_CANCEL, 0f, 0f, 0)
                try { request.owner.dispatchTouchEvent(cancel) } finally { cancel.recycle() }
                if (foreground) showWindow()
                return
            } catch (error: Exception) {
                requests.remove(key)?.fail(error)
                state.dismiss(key.id)
                queue.finish(key.kind, key.id)
                closeWindow()
            }
        }
    }

    private fun dismiss(key: NativeGameDialogKey) {
        val request = requests[key] ?: return
        if (queue.active != key) {
            queue.removeQueued(key.kind, key.id)
            requests.remove(key)?.complete(null)
            return
        }
        request.cancelled = true
        request.complete(null)
        if (!state.actionChosen) {
            state.choose(key.id)
            showInputGuard()
        }
        scheduleReleaseIfQuiet()
    }

    private fun createWindow() {
        val createdRoot = object : FrameLayout(activity) {
            override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
                val available = (View.MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight)
                    .coerceAtLeast(0)
                val cardWidth = if (id == R.id.native_game_resource_checklist) CHECKLIST_WIDTH_DP else 520
                if (childCount > 0) getChildAt(0).layoutParams.width = dp(cardWidth).coerceAtMost(available)
                super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            }
        }.apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            isClickable = false
            isFocusable = false
            setPadding(dp(20), dp(20), dp(20), dp(20))
        }
        ViewCompat.setOnApplyWindowInsetsListener(createdRoot) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left + dp(20), bars.top + dp(20), bars.right + dp(20), bars.bottom + dp(20))
            insets
        }
        val createdDialog = object : Dialog(activity) {
            override fun dispatchTouchEvent(event: MotionEvent): Boolean {
                trackOutsideTap(event)
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                        cancelRelease()
                        state.pointerDown(event.getPointerId(event.actionIndex))
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> {
                        cancelRelease()
                        state.pointerUp(event.getPointerId(event.actionIndex))
                    }
                    MotionEvent.ACTION_CANCEL -> {
                        cancelRelease()
                        state.cancelPointers()
                    }
                }
                super.dispatchTouchEvent(event)
                if (event.actionMasked == MotionEvent.ACTION_UP) {
                    val key = outsideDown
                    if (key != null && key == queue.active && outsideCard(event.rawX, event.rawY)) {
                        dismissFromUser(key, fromBarrier = true)
                    }
                    resetOutsideTap()
                }
                scheduleReleaseIfQuiet()
                return true
            }

            @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
            override fun onBackPressed() { acknowledgeFromBack() }
        }
        createdDialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        createdDialog.setCancelable(false)
        createdDialog.setCanceledOnTouchOutside(false)
        createdDialog.setOnKeyListener { _, keyCode, event ->
            if (keyCode != KeyEvent.KEYCODE_BACK) false else {
                if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                    backKeyDown = queue.active?.takeIf { !it.isBattle && !state.actionChosen }
                        ?.let { RenderedKey(it, renderVersion) }
                } else if (event.action == KeyEvent.ACTION_UP) {
                    val pressed = backKeyDown
                    backKeyDown = null
                    if (!event.isCanceled && pressed != null) dismissFromUser(pressed.key, pressed.version)
                }
                true
            }
        }
        createdDialog.setContentView(createdRoot)
        createdDialog.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
            setDimAmount(0.55f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                attributes = attributes.apply {
                    layoutInDisplayCutoutMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                    } else WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
            WindowCompat.setDecorFitsSystemWindows(this, false)
        }
        dialog = createdDialog
        root = createdRoot
    }

    private fun trackOutsideTap(event: MotionEvent) {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val key = queue.active
                outsideDown = key?.takeIf {
                    !it.isBattle && !state.actionChosen && requests[it]?.spec?.dismissible != false && outsideCard(event.rawX, event.rawY)
                }
                outsideX = event.rawX
                outsideY = event.rawY
            }
            MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_CANCEL -> resetOutsideTap()
            MotionEvent.ACTION_MOVE, MotionEvent.ACTION_UP -> {
                val dx = event.rawX - outsideX
                val dy = event.rawY - outsideY
                if (dx * dx + dy * dy > touchSlop * touchSlop) {
                    resetOutsideTap()
                }
            }
        }
    }

    private fun outsideCard(x: Float, y: Float): Boolean {
        val card = root?.takeIf { it.childCount > 0 }?.getChildAt(0) ?: return false
        val rect = Rect()
        if (!card.getGlobalVisibleRect(rect)) return false
        // Visible bounds are root-relative; raw touch coordinates are screen-relative.
        val rootLocation = IntArray(2)
        card.rootView.getLocationOnScreen(rootLocation)
        rect.offset(rootLocation[0], rootLocation[1])
        return !rect.contains(x.toInt(), y.toInt())
    }

    private fun resetOutsideTap() { outsideDown = null }

    private fun acknowledgeFromBack() {
        val key = queue.active ?: return
        if (!key.isBattle && !state.actionChosen) dismissFromUser(key)
    }

    /** Back/outside cancel a choice or confirmation; they never accept its primary action. */
    private fun dismissFromUser(key: NativeGameDialogKey, version: Long = renderVersion, fromBarrier: Boolean = false) {
        val request = requests[key] ?: return
        if (!request.spec.isSurfaceDialog) {
            choose(key, "acknowledge", version)
            return
        }
        if (version != renderVersion || queue.active != key || request.cancelled ||
            (fromBarrier && !request.spec.dismissible) || !state.choose(key.id)
        ) return
        request.cancelled = true
        cancelRelease()
        showInputGuard()
        // Keep the cancellation result private until the closing touch is protected.
        scheduleReleaseIfQuiet()
    }

    private fun showWindow() {
        val current = dialog ?: return
        current.show()
        current.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        installBackCallback()
        root?.let { ViewCompat.requestApplyInsets(it) }
    }

    private fun installBackCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val current = dialog?.takeIf { it.isShowing } ?: return
        backCallback?.let { current.onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it) }
        val key = queue.active
        val version = renderVersion
        val callback = OnBackInvokedCallback {
            if (key != null && !key.isBattle) dismissFromUser(key, version)
        }
        current.onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback)
        backCallback = callback
    }

    private fun render(value: NativeGameWarningDialogSpec) {
        saveChecklistScroll()
        if (patchChecklist(value)) return
        renderVersion++
        checklistViews = null
        backKeyDown = null
        resetOutsideTap()
        val container = root ?: return
        container.id = when (value.kind) {
            "debuff" -> R.id.native_game_reminder_debuff
            "newShip" -> R.id.native_game_reminder_new_ship
            "surfaceDialog" -> R.id.native_game_surface_dialog
            else -> R.id.native_game_warning_dialog
        }
        container.removeAllViews()
        dialog?.window?.setDimAmount(0.55f)
        if (value.isChecklist) {
            container.id = R.id.native_game_resource_checklist
            renderChecklist(container, value)
            installBackCallback()
            return
        }
        if (value.isSurfaceDialog) {
            renderSurfaceDialog(container, value)
            installBackCallback()
            return
        }
        val card = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(18), dp(20), dp(16))
            background = rounded(Color.rgb(18, 36, 49), dp(22).toFloat())
        }
        val scroll = ScrollView(activity).apply {
            isFillViewport = false
            isVerticalScrollBarEnabled = true
            addView(card, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        container.addView(scroll, FrameLayout.LayoutParams(dp(520), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        card.addView(text(value.title, 21f, Color.rgb(212, 168, 95), true))
        if (value.headline.isNotEmpty()) card.addView(text(value.headline, 15f, Color.rgb(255, 127, 136), true), spaced(12))
        if (value.rows.isNotEmpty()) {
            val rows = LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12), dp(8), dp(12), dp(8))
                background = rounded(Color.rgb(22, 44, 56), dp(10).toFloat())
            }
            value.rows.forEach { row -> rows.addView(text(row, 14f, Color.WHITE)) }
            card.addView(rows, spaced(10))
        }
        if (value.body.isNotEmpty()) card.addView(text(value.body, 13f, Color.LTGRAY), spaced(10))
        value.refreshFailed?.let { card.addView(text(it, 13f, Color.rgb(255, 127, 136)), spaced(10)) }
        if (value.isNotice) {
            card.addView(button(value, "acknowledge", true), spaced(14))
        } else {
            card.addView(buttonRow(value, "reloadGame", "reloadFrame", false), spaced(12))
            card.addView(buttonRow(value, "mute", "acknowledge", true), spaced(10))
        }
        installBackCallback()
    }

    private fun renderSurfaceDialog(container: FrameLayout, value: NativeGameWarningDialogSpec) {
        val version = renderVersion
        val request = requests[value.key] ?: return
        val card = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(18), dp(20), dp(16))
            background = rounded(Color.rgb(18, 36, 49), dp(22).toFloat())
        }
        val scroll = ScrollView(activity).apply {
            id = R.id.native_game_surface_dialog_scroll
            isFillViewport = false
            isVerticalScrollBarEnabled = true
            addView(card, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            setOnScrollChangeListener { _, _, scrollY, _, _ ->
                if (version == renderVersion && queue.active == value.key) request.scrollY = scrollY
            }
        }
        container.addView(scroll, FrameLayout.LayoutParams(dp(520), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        card.addView(text(value.title, 21f, Color.rgb(212, 168, 95), true))
        if (value.headline.isNotEmpty()) card.addView(text(value.headline, 15f, Color.WHITE, true), spaced(12))
        if (value.body.isNotEmpty()) card.addView(text(value.body, 14f, Color.LTGRAY), spaced(12))
        value.rows.forEach { row -> card.addView(text(row, 14f, Color.WHITE), spaced(8)) }
        var previousGroup: String? = null
        value.choices.forEach { choice ->
            if (choice.group.isNotEmpty() && previousGroup != choice.group) {
                card.addView(text(choice.group, 14f, Color.rgb(228, 194, 103), true), spaced(16))
            }
            previousGroup = choice.group
            val row = LinearLayout(activity).apply {
                id = R.id.native_game_surface_dialog_choice
                tag = "surface-dialog-choice:${choice.id}"
                orientation = LinearLayout.VERTICAL
                minimumHeight = dp(48)
                setPadding(dp(12), dp(8), dp(12), dp(8))
                background = rounded(if (choice.id == value.selectedChoiceId) Color.rgb(64, 69, 48) else Color.rgb(27, 48, 61), dp(10).toFloat())
                isClickable = true
                isFocusable = true
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
                contentDescription = listOf(choice.label, choice.detail).filter { it.isNotEmpty() }.joinToString("\n")
                addView(text(choice.label, 14f, Color.WHITE, choice.id == value.selectedChoiceId))
                if (choice.detail.isNotEmpty()) addView(text(choice.detail, 12f, Color.LTGRAY), spaced(4))
                setOnClickListener { choose(value.key, choice.id, version) }
            }
            card.addView(row, spaced(6))
        }
        value.checkbox?.let { checkbox ->
            card.addView(CheckBox(activity).apply {
                id = R.id.native_game_surface_dialog_checkbox
                tag = "surface-dialog-checkbox"
                text = checkbox.label
                textSize = 14f
                setTextColor(Color.WHITE)
                isChecked = request.checkboxChecked
                setOnCheckedChangeListener { _, checked ->
                    if (version == renderVersion && queue.active == value.key && !state.actionChosen && !request.cancelled) {
                        request.checkboxChecked = checked
                    }
                }
            }, spaced(12))
        }
        value.displayActions.forEachIndexed { index, action ->
            card.addView(button(value, action, index == value.displayActions.lastIndex), spaced(10))
        }
        scroll.post {
            if (version == renderVersion && queue.active == value.key && !state.actionChosen) scroll.scrollTo(0, request.scrollY)
        }
    }

    private fun saveChecklistScroll() {
        checklistViews?.takeIf { !it.restoringScroll }?.let { views ->
            requests[views.key]?.scrollY = views.scroll.scrollY
        }
    }

    private fun reconcileChecklistUpdate(request: Request, next: NativeGameWarningDialogSpec): NativeGameWarningDialogSpec {
        if (!next.isChecklist || request.checklistChanges.acknowledge(next.appliedChangeId)) return next
        val previousChecks = request.spec.items.associate { it.id to it.checked }
        return next.copy(items = next.items.map { item ->
            previousChecks[item.id]?.let { item.copy(checked = it) } ?: item
        })
    }

    /** A data refresh must not replace the target of a held touch or reset scrolling. */
    private fun patchChecklist(value: NativeGameWarningDialogSpec): Boolean {
        val views = checklistViews ?: return false
        if (!value.isChecklist || views.key != value.key || views.version != renderVersion ||
            views.rows.keys.toList() != value.items.map { it.id } ||
            (views.reset == null) != (value.resetLabel == null)
        ) return false
        views.patching = true
        try {
            views.title.text = value.title
            views.done.text = value.labels.getValue("acknowledge")
            views.done.isEnabled = value.enabled.getValue("acknowledge")
            views.reset?.text = value.resetLabel
            value.items.forEach { item ->
                views.rows.getValue(item.id).apply {
                    checkbox.text = item.label
                    checkbox.isChecked = item.checked
                    checkbox.isEnabled = item.enabled && requests[value.key]?.checklistChanges?.canToggle != false
                    this.value.text = item.value
                    updateChecklistIcon(icon, item)
                }
            }
        } finally {
            views.patching = false
        }
        views.reset?.isEnabled = requests[value.key]?.checklistChanges?.canToggle != false
        return true
    }

    private fun renderChecklist(container: FrameLayout, value: NativeGameWarningDialogSpec) {
        val version = renderVersion
        val card = LinearLayout(activity).apply {
            tag = "resourceChecklistCard"
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = rounded(Color.rgb(18, 36, 49), dp(20).toFloat())
        }
        val heading = LinearLayout(activity).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        val title = text(value.title, 16f, Color.rgb(212, 168, 95), true).apply { maxLines = 2 }
        heading.addView(title, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val reset = value.resetLabel?.let { label ->
            checklistHeaderButton(label, R.id.native_game_resource_checklist_reset).apply {
                setOnClickListener {
                    resetChecklist(value.key, version)
                }
                isEnabled = requests[value.key]?.checklistChanges?.canToggle != false
                heading.addView(this, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            }
        }
        val done = checklistHeaderButton(value.labels.getValue("acknowledge"), R.id.native_game_resource_checklist_done).apply {
            isEnabled = value.enabled.getValue("acknowledge")
            setOnClickListener { choose(value.key, "acknowledge", version) }
        }
        heading.addView(done, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        card.addView(heading)
        val list = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        val scroll = object : ScrollView(activity) {
            override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
                val limit = if (View.MeasureSpec.getMode(heightMeasureSpec) == View.MeasureSpec.UNSPECIFIED) {
                    dp(CHECKLIST_LIST_HEIGHT_DP)
                } else View.MeasureSpec.getSize(heightMeasureSpec).coerceAtMost(dp(CHECKLIST_LIST_HEIGHT_DP))
                super.onMeasure(widthMeasureSpec, View.MeasureSpec.makeMeasureSpec(limit, View.MeasureSpec.AT_MOST))
            }
        }.apply {
            id = R.id.native_game_resource_checklist_list
            isFillViewport = false
            isVerticalScrollBarEnabled = true
            addView(list, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        val views = ChecklistViews(value.key, version, title, done, reset, scroll, linkedMapOf())
        checklistViews = views
        value.items.forEach { item ->
            val row = LinearLayout(activity).apply {
                tag = "row:${item.id}"
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = dp(44)
                setPadding(0, 0, dp(2), 0)
            }
            val icon = checklistIcon(item)
            val checkbox = CheckBox(activity).apply {
                id = R.id.native_game_resource_checklist_item
                tag = item.id
                text = item.label
                textSize = 13f
                includeFontPadding = false
                maxLines = 2
                setTextColor(Color.rgb(220, 230, 235))
                isChecked = item.checked
                isEnabled = item.enabled && requests[value.key]?.checklistChanges?.canToggle != false
                setPadding(0, 0, dp(6), 0)
                compoundDrawablePadding = dp(6)
                buttonDrawable?.let { drawable ->
                    buttonDrawable = object : InsetDrawable(drawable.mutate(), 0) {
                        override fun getIntrinsicWidth() = dp(20)
                        override fun getIntrinsicHeight() = dp(20)
                    }
                }
                minimumHeight = dp(40)
                minHeight = dp(40)
                buttonTintList = android.content.res.ColorStateList.valueOf(Color.rgb(228, 194, 103))
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
                setOnCheckedChangeListener { _, checked ->
                    if (!views.patching && !toggleChecklist(value.key, version, item.id, checked) && checklistViews === views) {
                        // Disabled or obsolete input cannot mutate even the visible optimistic check.
                        views.patching = true
                        isChecked = requests[value.key]?.spec?.items?.firstOrNull { it.id == item.id }?.checked ?: item.checked
                        views.patching = false
                    }
                }
            }
            val valueText = text(item.value, 12f, Color.rgb(172, 195, 205)).apply {
                tag = "value:${item.id}"
                gravity = Gravity.END
                maxLines = 2
                maxWidth = dp(140)
                includeFontPadding = false
            }
            row.addView(icon.host, LinearLayout.LayoutParams(dp(20), dp(20)).apply { marginEnd = dp(6) })
            row.addView(checkbox, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(valueText, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            row.setOnClickListener {
                if (checkbox.isEnabled && currentChecklist(value.key, version)?.checklistChanges?.canToggle == true) checkbox.performClick()
            }
            list.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            views.rows[item.id] = ChecklistRow(checkbox, valueText, icon)
        }
        scroll.setOnScrollChangeListener { _, _, scrollY, _, _ ->
            if (!views.restoringScroll) requests[views.key]?.scrollY = scrollY
        }
        card.addView(scroll, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        container.addView(card, FrameLayout.LayoutParams(dp(CHECKLIST_WIDTH_DP), ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        scroll.post {
            if (checklistViews === views && views.version == renderVersion && queue.active == value.key && !state.actionChosen) {
                scroll.scrollTo(0, requests[value.key]?.scrollY ?: 0)
                views.restoringScroll = false
            }
        }
    }

    private fun checklistHeaderButton(label: String, resourceId: Int) = Button(activity).apply {
        id = resourceId
        text = label
        textSize = 12f
        isAllCaps = false
        minimumWidth = 0
        minWidth = 0
        minimumHeight = dp(40)
        minHeight = dp(40)
        setPadding(dp(8), dp(4), dp(8), dp(4))
        setTextColor(Color.rgb(228, 194, 103))
        background = ColorDrawable(Color.TRANSPARENT)
    }

    private fun checklistIcon(item: NativeGameChecklistItem): ChecklistIcon {
        val host = FrameLayout(activity).apply {
            tag = "icon:${item.id}"
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        }
        val asset = ImageView(activity).apply {
            tag = "asset:${item.id}"
            scaleType = ImageView.ScaleType.FIT_CENTER
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val glyph = TextView(activity).apply {
            tag = "glyph:${item.id}"
            gravity = Gravity.CENTER
            setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, dp(20).toFloat())
            includeFontPadding = false
            typeface = checklistIconTypeface
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        host.addView(asset, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        host.addView(glyph, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        return ChecklistIcon(host, asset, glyph).also { updateChecklistIcon(it, item) }
    }

    private fun updateChecklistIcon(icon: ChecklistIcon, item: NativeGameChecklistItem) {
        if (icon.assetPath != item.iconAsset) {
            val bitmap = item.iconAsset?.let { asset ->
                runCatching { activity.assets.open(flutterAssetKey(asset)).use { BitmapFactory.decodeStream(it) } }.getOrNull()
            }
            icon.asset.setImageBitmap(bitmap)
            icon.assetPath = item.iconAsset
        }
        icon.asset.visibility = if (item.iconAsset != null && icon.asset.drawable != null) View.VISIBLE else View.GONE
        icon.glyph.text = item.iconCodePoint?.let { String(Character.toChars(it)) } ?: ""
        icon.glyph.setTextColor(item.iconColor ?: Color.rgb(159, 179, 191))
        icon.glyph.visibility = if (item.iconCodePoint != null && checklistIconTypeface != null) View.VISIBLE else View.GONE
        icon.host.visibility = if (icon.asset.visibility == View.VISIBLE || icon.glyph.visibility == View.VISIBLE) View.VISIBLE else View.GONE
    }

    private fun flutterAssetKey(asset: String): String =
        FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)

    private fun currentChecklist(key: NativeGameDialogKey, version: Long): Request? {
        val request = requests[key] ?: return null
        return request.takeIf {
            version == renderVersion && queue.active == key && !it.cancelled && !state.actionChosen &&
                it.action == null && it.spec.isChecklist && foreground && dialog?.isShowing == true &&
                it.owner === gameWebView() && it.owner.isAttachedToWindow
        }
    }

    private fun toggleChecklist(key: NativeGameDialogKey, version: Long, itemId: String, checked: Boolean): Boolean {
        val request = currentChecklist(key, version) ?: return false
        val previous = request.spec.items.firstOrNull { it.id == itemId } ?: return false
        if (!previous.enabled || previous.checked == checked) return false
        val changeId = request.checklistChanges.change(reset = false) ?: return false
        request.spec = request.spec.copy(items = request.spec.items.map { if (it.id == itemId) it.copy(checked = checked) else it })
        publishChecklist(mapOf("kind" to key.kind, "id" to key.id, "event" to "toggle", "itemId" to itemId, "checked" to checked,
            "changeId" to changeId))
        return true
    }

    private fun resetChecklist(key: NativeGameDialogKey, version: Long) {
        val request = currentChecklist(key, version) ?: return
        val changeId = request.checklistChanges.change(reset = true) ?: return
        checklistViews?.takeIf { it.key == key && it.version == version }?.let { views ->
            views.rows.values.forEach { it.checkbox.isEnabled = false }
            views.reset?.isEnabled = false
        }
        publishChecklist(mapOf("kind" to key.kind, "id" to key.id, "event" to "reset", "changeId" to changeId))
    }

    private fun publishChecklist(event: Map<String, Any>) {
        val sink = checklistEventSink
        if (sink != null) sink(event) else channel.invokeMethod("checklistChanged", event)
    }

    private fun button(value: NativeGameWarningDialogSpec, action: String, prominent: Boolean) = Button(activity).apply {
        val renderedVersion = renderVersion
        text = value.labels.getValue(action)
        textSize = if (prominent) 14f else 13f
        isAllCaps = false
        minHeight = dp(48)
        minimumWidth = 0
        setPadding(dp(10), dp(10), dp(10), dp(10))
        setTextColor(if (prominent) Color.rgb(48, 35, 5) else Color.WHITE)
        background = rounded(when {
            value.isSurfaceDialog -> if (prominent) Color.rgb(228, 194, 103) else Color.rgb(42, 65, 79)
            value.isNotice -> Color.rgb(228, 194, 103)
            action == "acknowledge" -> Color.rgb(255, 127, 136)
            prominent -> Color.rgb(228, 194, 103)
            else -> Color.rgb(42, 65, 79)
        }, dp(22).toFloat())
        isEnabled = value.enabled.getValue(action)
        alpha = if (isEnabled) 1f else 0.4f
        id = if (value.isSurfaceDialog) R.id.native_game_surface_dialog_action else if (value.isNotice) R.id.native_game_reminder_acknowledge else when (action) {
            "acknowledge" -> R.id.native_game_warning_acknowledge
            "mute" -> R.id.native_game_warning_mute
            "reloadGame" -> R.id.native_game_warning_reload_game
            else -> R.id.native_game_warning_reload_frame
        }
        if (value.isSurfaceDialog) tag = "surface-dialog-action:$action"
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        setOnClickListener { choose(value.key, action, renderedVersion) }
    }

    private fun buttonRow(value: NativeGameWarningDialogSpec, first: String, second: String, prominent: Boolean): View {
        val row = LinearLayout(activity).apply { orientation = LinearLayout.HORIZONTAL }
        listOf(first, second).forEachIndexed { index, action ->
            row.addView(button(value, action, prominent), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT,
                if (prominent && index == 0) 3f else if (prominent) 2f else 1f,
            ).apply { if (index > 0) leftMargin = dp(10) })
        }
        return row
    }

    private fun choose(key: NativeGameDialogKey, action: String, version: Long = renderVersion) {
        val request = requests[key] ?: return
        val isChoice = request.spec.isSurfaceDialog && request.spec.choices.any { it.id == action }
        if (version != renderVersion || queue.active != key || request.cancelled ||
            (!isChoice && (action !in request.spec.displayActions || request.spec.enabled[action] != true)) || !state.choose(key.id)
        ) return
        request.action = action
        cancelRelease()
        showInputGuard()
        // Battles refresh immediately. Ordinary acknowledgements are deferred
        // until the actual protected gesture and quiet interval have finished.
        if (!request.spec.isNotice) request.complete(action)
        scheduleReleaseIfQuiet()
    }

    private fun showInputGuard() {
        saveChecklistScroll()
        renderVersion++
        checklistViews = null
        backKeyDown = null
        resetOutsideTap()
        root?.apply { removeAllViews(); id = R.id.native_game_warning_input_guard }
        dialog?.window?.setDimAmount(0f)
        installBackCallback()
    }

    private fun scheduleReleaseIfQuiet() {
        if (!state.canScheduleRelease || release != null) return
        val key = queue.active ?: return
        val version = state.releaseVersion
        val operation = Runnable {
            release = null
            if (queue.active == key && state.releaseIfQuiet(key.id, version)) {
                val request = requests.remove(key)
                request?.complete(if (request.cancelled) null else request.action)
                queue.finish(key.kind, key.id)
                // Keep the same native window across queued notices so the
                // underlying game never gets a briefly exposed input target.
                activateCurrent()
            }
        }
        release = operation
        handler.postDelayed(operation, PROTECTION_MILLIS)
    }

    private fun cancelRelease() {
        release?.let(handler::removeCallbacks)
        release = null
    }

    fun setForeground(visible: Boolean) {
        foreground = visible
        if (!visible) {
            cancelAvailabilityWaits()
            cancelRelease()
            state.cancelPointers()
            resetOutsideTap()
            dialog?.hide()
            scheduleReleaseIfQuiet()
        } else if (queue.active != null) {
            if (activity.isFinishing || activity.isDestroyed) {
                cancelAllRequests()
                return
            }
            val currentOwner = gameWebView()
            val previous = queue.active
            val invalid = (listOfNotNull(previous) + queue.waiting).filterTo(mutableSetOf()) { key ->
                val pending = requests[key]
                pending == null || pending.owner !== currentOwner || !pending.owner.isAttachedToWindow
            }
            // Protection belongs to a physical gesture, including a contact
            // that started before the old reminder was confirmed or cancelled.
            val keepProtection = previous in invalid && (state.actionChosen || state.hasPointers)
            queue.discardInvalid(invalid, preserveActive = keepProtection).forEach { key ->
                requests.remove(key)?.complete(null)
            }
            if (keepProtection) {
                requests[previous]?.let { pending ->
                    pending.cancelled = true
                    pending.complete(null)
                }
                if (!state.actionChosen) {
                    previous?.let { state.choose(it.id) }
                    showInputGuard()
                }
                showWindow()
                scheduleReleaseIfQuiet()
            } else if (queue.active != previous) {
                state.id?.let(state::dismiss)
                activateCurrent()
            } else showWindow()
        }
    }

    private fun cancelAllRequests() {
        queue.clear().forEach { requests.remove(it)?.complete(null) }
        requests.values.forEach { it.complete(null) }
        requests.clear()
        state.id?.let(state::dismiss)
        closeWindow()
    }

    private fun closeWindow() {
        saveChecklistScroll()
        checklistViews = null
        renderVersion++
        backKeyDown = null
        cancelRelease()
        resetOutsideTap()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback?.let { callback -> dialog?.onBackInvokedDispatcher?.unregisterOnBackInvokedCallback(callback) }
        }
        backCallback = null
        dialog?.dismiss()
        dialog = null
        root = null
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        cancelAvailabilityWaits()
        channel.setMethodCallHandler(null)
        cancelAllRequests()
    }

    private fun text(value: String, size: Float, color: Int, bold: Boolean = false) = TextView(activity).apply {
        text = value
        textSize = size
        setTextColor(color)
        setLineSpacing(dp(3).toFloat(), 1f)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun spaced(top: Int) = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        .apply { topMargin = dp(top) }

    private fun rounded(color: Int, radius: Float) = GradientDrawable().apply { setColor(color); cornerRadius = radius }
    private fun dp(value: Int) = (value * activity.resources.displayMetrics.density).roundToInt()

    companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/native_warning"
        const val PROTECTION_MILLIS = 600L
        private const val AVAILABILITY_TIMEOUT_MILLIS = 5000L
        private const val AVAILABILITY_POLL_MILLIS = 50L
        private const val CHECKLIST_WIDTH_DP = 360
        private const val CHECKLIST_LIST_HEIGHT_DP = 360
    }
}
