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
import android.graphics.drawable.RippleDrawable
import android.content.res.ColorStateList
import android.util.TypedValue
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextUtils
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
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
import androidx.core.graphics.ColorUtils
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
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
    private val releasePolicy: NativeGameDialogReleasePolicy = NativeGameDialogReleasePolicy(SystemClock::uptimeMillis),
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
    private data class ChecklistRow(val checkbox: CheckBox, val value: TextView, val icon: ChecklistIcon?)
    private class ChecklistViews(
        val key: NativeGameDialogKey,
        val version: Long,
        val title: TextView,
        val done: Button,
        val reset: Button?,
        val close: Button?,
        val scroll: ScrollView,
        val rows: LinkedHashMap<String, ChecklistRow>,
    ) {
        var restoringScroll = true
        var patching = false
    }
    private var checklistViews: ChecklistViews? = null
    private var presentation = NativeGameDialogPresentation()
    private var fontSource: Pair<String?, String?>? = null
    private var dialogTypeface: Typeface? = null
    private val stableInsets = Rect()
    private val checklistIconTypeface: Typeface? by lazy {
        runCatching { Typeface.createFromAsset(activity.assets, flutterAssetKey("fonts/MaterialIcons-Regular.otf")) }.getOrNull()
    }
    private var backKeyDown: RenderedKey? = null
    private var foreground = true
    private var disposed = false

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
        releasePolicy.clear()
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
        if (!request.spec.protectInputOnDismiss) {
            dismissWithoutProtection(key)
            return
        }
        request.complete(null)
        if (!state.actionChosen) {
            state.choose(key.id)
            showInputGuard()
        }
        scheduleReleaseIfQuiet()
    }

    private fun createWindow() {
        val createdRoot = FrameLayout(activity).apply {
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            isClickable = false
            isFocusable = false
        }
        ViewCompat.setOnApplyWindowInsetsListener(createdRoot) { view, insets ->
            // Reserve the same safe area while transient gesture navigation
            // appears or disappears, including between a Button's DOWN and UP.
            val bars = insets.getInsetsIgnoringVisibility(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            stableInsets.set(bars.left, bars.top, bars.right, bars.bottom)
            applySafePadding(view)
            insets
        }
        // A default floating Dialog is resized around visible system bars even
        // with MATCH_PARENT. Use an edge-to-edge window so its coordinate
        // space stays fixed when gesture navigation is temporarily revealed.
        val createdDialog = object : Dialog(activity, android.R.style.Theme_Translucent_NoTitleBar) {
            override fun onWindowFocusChanged(hasFocus: Boolean) {
                super.onWindowFocusChanged(hasFocus)
                if (hasFocus) window?.let(::keepImmersive)
            }

            override fun dispatchTouchEvent(event: MotionEvent): Boolean {
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
                scheduleReleaseIfQuiet()
                // Every native dialog owns its full window. Outside input is
                // consumed without selecting an action or starting closure.
                return true
            }

            @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
            // API 33+ gestures use installBackCallback(); retain the legacy
            // callback for older Android versions and hardware Back dispatch.
            @android.annotation.SuppressLint("GestureBackNavigation")
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
            setDimAmount(0f)
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

    private fun acknowledgeFromBack() {
        val key = queue.active ?: return
        if (!key.isBattle && !state.actionChosen) dismissFromUser(key)
    }

    /** Back cancels a choice or confirmation without accepting its primary action. */
    private fun dismissFromUser(key: NativeGameDialogKey, version: Long = renderVersion) {
        val request = requests[key] ?: return
        if (!request.spec.isSurfaceDialog && !request.spec.backCancels) {
            choose(key, "acknowledge", version)
            return
        }
        if (version != renderVersion || queue.active != key || request.cancelled || !state.choose(key.id)
        ) return
        request.cancelled = true
        if (!request.spec.protectInputOnDismiss) {
            dismissWithoutProtection(key)
            return
        }
        cancelRelease()
        showInputGuard()
        // Keep the cancellation result private until the closing touch is protected.
        scheduleReleaseIfQuiet()
    }

    private fun showWindow() {
        val current = dialog ?: return
        // Configure the pending controller before show, avoiding the system-bar
        // flash when focus moves from Flutter's immersive activity to us.
        current.window?.let(::keepImmersive)
        current.show()
        current.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        installBackCallback()
        root?.let { ViewCompat.requestApplyInsets(it) }
    }

    private fun keepImmersive(window: Window) {
        WindowInsetsControllerCompat(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
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
        val container = root ?: return
        presentation = value.presentation
        val source = presentation.fontAsset to presentation.customFontPath
        if (fontSource != source) {
            fontSource = source
            dialogTypeface = presentation.customFontPath?.let { runCatching { Typeface.createFromFile(it) }.getOrNull() }
                ?: presentation.fontAsset?.let { runCatching { Typeface.createFromAsset(activity.assets, flutterAssetKey(it)) }.getOrNull() }
        }
        container.layoutDirection = if (presentation.textDirection == "rtl") View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        applySafePadding(container)
        container.id = when (value.kind) {
            "debuff" -> R.id.native_game_reminder_debuff
            "newShip" -> R.id.native_game_reminder_new_ship
            "surfaceDialog" -> R.id.native_game_surface_dialog
            else -> R.id.native_game_warning_dialog
        }
        container.removeAllViews()
        // Window dim only supports black. Paint the complete themed barrier so
        // colored Flutter dialog barriers are also reproduced faithfully.
        container.setBackgroundColor(presentation.colors.barrier)
        dialog?.window?.setDimAmount(0f)
        if (value.isChecklist) {
            container.id = R.id.native_game_resource_checklist
            renderChecklist(container, value)
            installBackCallback()
            return
        }
        renderSurfaceDialog(container, value)
        installBackCallback()
    }

    private fun renderSurfaceDialog(container: FrameLayout, value: NativeGameWarningDialogSpec) {
        val version = renderVersion
        val request = requests[value.key] ?: return
        val content = dialogContent(value.title)
        val body = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL; setDialogPadding(presentation.layout.contentPadding) }
        val scroll = ScrollView(activity).apply {
            id = R.id.native_game_surface_dialog_scroll
            isFillViewport = false
            isVerticalScrollBarEnabled = true
            addView(content, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            setOnScrollChangeListener { _, _, scrollY, _, _ ->
                if (version == renderVersion && queue.active == value.key) request.scrollY = scrollY
            }
        }
        if (value.headline.isNotEmpty()) body.addView(styledText(value.headline,
            color = if (value.kind == "battle") presentation.colors.error else presentation.colors.onSurface))
        if (value.body.isNotEmpty()) body.addView(styledText(value.body).apply { tag = "dialog-body" }, spaced(if (body.childCount > 0) 12 else 0))
        value.rows.forEach { row -> body.addView(styledText(row), spaced(8)) }
        value.refreshFailed?.let { body.addView(styledText(it, color = presentation.colors.error), spaced(10)) }
        var previousGroup: String? = null
        value.choices.forEach { choice ->
            if (choice.group.isNotEmpty() && previousGroup != choice.group) {
                body.addView(styledText(choice.group, color = presentation.colors.primary), spaced(16))
            }
            previousGroup = choice.group
            val row = LinearLayout(activity).apply {
                id = R.id.native_game_surface_dialog_choice
                tag = "surface-dialog-choice:${choice.id}"
                orientation = LinearLayout.VERTICAL
                minimumHeight = dp(48)
                setPadding(dp(16), dp(8), dp(16), dp(8))
                background = RippleDrawable(ColorStateList.valueOf(withAlpha(presentation.colors.primary, 0.12f)),
                    rounded(if (choice.id == value.selectedChoiceId) withAlpha(presentation.colors.primary, 0.12f) else Color.TRANSPARENT, dp(12).toFloat()), null)
                isClickable = true
                isFocusable = true
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
                contentDescription = listOf(choice.label, choice.detail).filter { it.isNotEmpty() }.joinToString("\n")
                addView(styledText(choice.label, presentation.text.checkbox, presentation.colors.onSurface))
                if (choice.detail.isNotEmpty()) addView(styledText(choice.detail), spaced(4))
                setOnClickListener { choose(value.key, choice.id, version) }
            }
            body.addView(row, spaced(6))
        }
        value.checkbox?.let { checkbox ->
            body.addView(CheckBox(activity).apply {
                id = R.id.native_game_surface_dialog_checkbox
                tag = "surface-dialog-checkbox"
                text = checkbox.label
                styleCheckbox(this)
                isChecked = request.checkboxChecked
                setOnCheckedChangeListener { _, checked ->
                    if (version == renderVersion && queue.active == value.key && !state.actionChosen && !request.cancelled) {
                        request.checkboxChecked = checked
                    }
                }
            }, spaced(16))
        }
        content.addView(body)
        val actions = dialogActions()
        value.displayActions.forEachIndexed { index, action ->
            actions.addView(button(value, action, index == value.displayActions.lastIndex))
        }
        attachCard(container, scroll, actions)
        scroll.post {
            if (version == renderVersion && queue.active == value.key && !state.actionChosen) scroll.scrollTo(0, request.scrollY)
        }
    }

    private fun applySafePadding(view: View) {
        val compact = queue.active?.let { requests[it]?.spec?.compactShipChecklist } == true
        val padding = if (compact) listOf(12f, 12f, 12f, 12f) else presentation.layout.insetPadding
        view.setPadding(stableInsets.left + dp(padding[0]), stableInsets.top + dp(padding[1]),
            stableInsets.right + dp(padding[2]), stableInsets.bottom + dp(padding[3]))
    }

    private fun View.setDialogPadding(padding: List<Float>) = setPadding(dp(padding[0]), dp(padding[1]), dp(padding[2]), dp(padding[3]))

    private fun dialogContent(title: String) = LinearLayout(activity).apply {
        orientation = LinearLayout.VERTICAL
        addView(styledText(title, presentation.text.title, presentation.colors.onSurface).apply {
            tag = "dialog-title"
            setDialogPadding(presentation.layout.titlePadding)
            ViewCompat.setAccessibilityHeading(this, true)
        })
    }

    private fun dialogActions(compact: Boolean = false) = NativeGameDialogActions(activity, dp(presentation.layout.actionSpacing), compact).apply {
        tag = "dialog-actions"
        if (compact) setPadding(dp(8), dp(3), dp(8), dp(6)) else setDialogPadding(presentation.layout.actionsPadding)
    }

    private fun attachCard(container: FrameLayout, content: ScrollView, actions: View, header: View? = null) {
        val compact = header != null
        val minimumWidth = dp(if (compact) 440f else presentation.layout.minWidth)
        container.addView(NativeGameDialogCard(activity, content, actions, minimumWidth, header,
            maximumCardWidth = if (compact) minimumWidth else Int.MAX_VALUE,
            maximumCardHeight = if (compact) dp(480) else Int.MAX_VALUE).apply {
            tag = if (container.id == R.id.native_game_resource_checklist) "resourceChecklistCard" else "dialog-card"
            background = if (compact) rounded(compactColor(0xff101d27, presentation.colors.surface), dp(10).toFloat()).apply {
                setStroke(dp(1), compactColor(0xff385064, presentation.colors.outline))
            } else rounded(presentation.colors.surface, dp(presentation.layout.radius).toFloat())
            clipToOutline = true
        }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
    }

    private fun compactColor(dark: Long, light: Int): Int =
        if (ColorUtils.calculateLuminance(presentation.colors.surface) < 0.5) dark.toInt() else light

    private fun NativeGameDialogPresentation.TextStyle.compact(scale: Float, weight: Int = 700) =
        copy(fontSize = fontSize * scale, lineHeight = lineHeight * scale, fontWeight = weight)

    private fun styledText(value: String, style: NativeGameDialogPresentation.TextStyle = presentation.text.body, color: Int = presentation.colors.body) = TextView(activity).apply {
        text = value
        styleText(this, style, color)
    }

    private fun styleText(view: TextView, style: NativeGameDialogPresentation.TextStyle, color: Int) {
        view.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.fontSize * activity.resources.displayMetrics.density)
        view.setTextColor(color)
        view.includeFontPadding = false
        val family = dialogTypeface ?: style.fontFamily?.let { Typeface.create(it, Typeface.NORMAL) } ?: Typeface.DEFAULT
        view.typeface = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Typeface.create(family, style.fontWeight, false)
            else Typeface.create(family, if (style.fontWeight >= 600) Typeface.BOLD else Typeface.NORMAL)
        val metrics = view.paint.fontMetrics
        view.setLineSpacing((style.lineHeight * activity.resources.displayMetrics.density - (metrics.descent - metrics.ascent)).coerceAtLeast(0f), 1f)
    }

    private fun styleCheckbox(view: CheckBox, compact: Boolean = false) {
        val style = presentation.text.checkbox
        styleText(view, if (compact) style.compact(0.8125f) else style,
            if (compact) compactColor(0xffdce6eb, presentation.colors.onSurface) else presentation.colors.onSurface)
        view.minHeight = dp(if (compact) 36 else 56)
        view.minimumHeight = view.minHeight
        view.setPadding(dp(if (compact) 8 else 12), 0, dp(if (compact) 8 else 16), 0)
        view.compoundDrawablePadding = dp(if (compact) 8 else 16)
        view.buttonTintList = null
        view.buttonDrawable = NativeGameDialogCheckboxDrawable(activity.resources.displayMetrics.density,
            presentation.colors.checkbox, presentation.colors.checkboxCheck, presentation.colors.body)
    }

    private fun checklistItemText(item: NativeGameChecklistItem, compact: Boolean): CharSequence {
        val detail = item.detail
        if (!compact || detail.isNullOrBlank()) return item.label
        return SpannableStringBuilder(item.label).apply {
            append("  ")
            val start = length
            append(detail)
            setSpan(ForegroundColorSpan(compactColor(0xffa2b8c6, presentation.colors.body)), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            setSpan(RelativeSizeSpan(0.85f), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }

    private fun withAlpha(color: Int, alpha: Float) = (color and 0xffffff) or ((255 * alpha).roundToInt() shl 24)

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
            value.presentation != presentation ||
            views.rows.keys.toList() != value.items.map { it.id } ||
            (views.close != null) != value.compactShipChecklist ||
            (views.reset == null) != (value.resetLabel == null)
        ) return false
        views.patching = true
        try {
            views.title.text = value.title
            views.close?.contentDescription = value.closeLabel
            views.done.text = value.labels.getValue("acknowledge")
            views.done.isEnabled = value.enabled.getValue("acknowledge")
            views.reset?.text = value.resetLabel
            value.items.forEach { item ->
                views.rows.getValue(item.id).apply {
                    checkbox.text = checklistItemText(item, value.compactShipChecklist)
                    checkbox.isChecked = item.checked
                    checkbox.isEnabled = item.enabled && requests[value.key]?.checklistChanges?.canToggle != false
                    this.value.text = item.value
                    icon?.let { updateChecklistIcon(it, item) }
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
        val compact = value.compactShipChecklist
        val content = if (compact) LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
            else dialogContent(value.title)
        val title = if (compact) styledText(value.title, presentation.text.title.compact(0.6f),
            compactColor(0xffdce6eb, presentation.colors.onSurface)).apply {
            tag = "dialog-title"
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(4), dp(4), dp(4), dp(4))
            ViewCompat.setAccessibilityHeading(this, true)
        } else content.findViewWithTag<TextView>("dialog-title")
        val close = value.closeLabel?.let { label ->
            Button(activity).apply {
                tag = "compact-ship-checklist-close"
                text = "×"
                contentDescription = label
                styleCompactChecklistButton(this, filled = false)
                styleText(this, presentation.text.title.compact(0.8f, weight = 500),
                    compactColor(0xffa2b8c6, presentation.colors.onSurface))
                minWidth = dp(40)
                minimumWidth = minWidth
                setPadding(0, 0, 0, 0)
                setOnClickListener { dismissFromUser(value.key, version) }
            }
        }
        val header = close?.let {
            LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(8), 0, dp(3), 0)
                addView(title, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                addView(it, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            }
        }
        val actions = dialogActions(compact)
        val reset = value.resetLabel?.let { label ->
            checklistHeaderButton(label, R.id.native_game_resource_checklist_reset, false, compact).apply {
                setOnClickListener {
                    resetChecklist(value.key, version)
                }
                isEnabled = requests[value.key]?.checklistChanges?.canToggle != false
                actions.addView(this)
            }
        }
        val done = checklistHeaderButton(value.labels.getValue("acknowledge"), R.id.native_game_resource_checklist_done, true, compact).apply {
            isEnabled = value.enabled.getValue("acknowledge")
            setOnClickListener { choose(value.key, "acknowledge", version) }
        }
        actions.addView(done)
        val list = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            if (compact) setPadding(dp(7), dp(3), dp(7), dp(3)) else setDialogPadding(presentation.layout.contentPadding)
        }
        content.addView(list)
        val scroll = ScrollView(activity).apply {
            id = R.id.native_game_resource_checklist_list
            isFillViewport = false
            isVerticalScrollBarEnabled = true
            addView(content, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        val views = ChecklistViews(value.key, version, title, done, reset, close, scroll, linkedMapOf())
        checklistViews = views
        value.items.forEach { item ->
            val row = LinearLayout(activity).apply {
                tag = "row:${item.id}"
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = dp(if (compact) 36 else 56)
                if (compact) {
                    setPaddingRelative(0, 0, dp(8), 0)
                    val colors = presentation.colors
                    val rowColor = compactColor(0xff172a38, ColorUtils.blendARGB(colors.surface, colors.onSurface, 0.06f))
                    background = rounded(rowColor, dp(5).toFloat())
                } else setPadding(0, 0, dp(2), 0)
            }
            val icon = if (compact) null else checklistIcon(item)
            val checkbox = CheckBox(activity).apply {
                id = R.id.native_game_resource_checklist_item
                tag = item.id
                text = checklistItemText(item, compact)
                styleCheckbox(this, compact)
                maxLines = if (compact) 1 else 2
                if (compact) ellipsize = TextUtils.TruncateAt.END
                isChecked = item.checked
                isEnabled = item.enabled && requests[value.key]?.checklistChanges?.canToggle != false
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
            val valueText = styledText(item.value).apply {
                tag = "value:${item.id}"
                gravity = Gravity.END
                maxLines = if (compact) 1 else 2
                maxWidth = dp(140)
                includeFontPadding = false
                if (compact) {
                    styleText(this, presentation.text.body.compact(0.85f), compactColor(0xff8adac7, 0xff216d4f.toInt()))
                    ellipsize = TextUtils.TruncateAt.END
                }
            }
            icon?.let { row.addView(it.host, LinearLayout.LayoutParams(dp(20), dp(20)).apply { marginEnd = dp(6) }) }
            row.addView(checkbox, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(valueText, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
            row.setOnClickListener {
                if (checkbox.isEnabled && currentChecklist(value.key, version)?.checklistChanges?.canToggle == true) checkbox.performClick()
            }
            list.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                if (compact) bottomMargin = dp(3)
            })
            views.rows[item.id] = ChecklistRow(checkbox, valueText, icon)
        }
        scroll.setOnScrollChangeListener { _, _, scrollY, _, _ ->
            if (!views.restoringScroll) requests[views.key]?.scrollY = scrollY
        }
        attachCard(container, scroll, actions, header)
        scroll.post {
            if (checklistViews === views && views.version == renderVersion && queue.active == value.key && !state.actionChosen) {
                scroll.scrollTo(0, requests[value.key]?.scrollY ?: 0)
                views.restoringScroll = false
            }
        }
    }

    private fun checklistHeaderButton(label: String, resourceId: Int, filled: Boolean, compact: Boolean) = Button(activity).apply {
        id = resourceId
        text = label
        if (compact) styleCompactChecklistButton(this, filled) else styleButton(this, if (filled) "filled" else "text")
    }

    private fun styleCompactChecklistButton(view: Button, filled: Boolean) {
        val colors = presentation.colors
        val color = if (filled) colors.onPrimary else colors.primary
        styleText(view, presentation.text.action.compact(0.9f), color)
        view.isAllCaps = false
        view.gravity = Gravity.CENTER
        view.minWidth = 0
        view.minimumWidth = 0
        view.minHeight = dp(38)
        view.minimumHeight = view.minHeight
        val shape = rounded(if (filled) colors.primary else Color.TRANSPARENT, dp(6).toFloat())
        view.background = RippleDrawable(ColorStateList.valueOf(withAlpha(color, 0.12f)), shape, null)
        view.setPadding(dp(12), dp(4), dp(12), dp(4))
        view.stateListAnimator = null
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
        styleButton(this, value.variants[action] ?: if (prominent) "filled" else "text")
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

    private fun styleButton(view: Button, variant: String) {
        val filled = variant == "filled"
        val color = if (filled) presentation.colors.onPrimary else presentation.colors.primary
        styleText(view, presentation.text.action, color)
        view.isAllCaps = false
        view.gravity = Gravity.CENTER
        view.minWidth = dp(64)
        view.minimumWidth = dp(64)
        view.minHeight = dp(presentation.layout.actionMinHeight.coerceAtLeast(48f))
        view.minimumHeight = view.minHeight
        val shape = rounded(if (filled) presentation.colors.primary else Color.TRANSPARENT, dp(presentation.layout.buttonRadius).toFloat()).apply {
            if (variant == "outlined") setStroke(dp(1), presentation.colors.outline)
        }
        view.background = InsetDrawable(RippleDrawable(ColorStateList.valueOf(withAlpha(color, 0.12f)), shape, null), 0, dp(4), 0, dp(4))
        // Background assignment adopts Drawable padding. Apply label padding
        // afterwards so the InsetDrawable cannot erase the Material spacing.
        view.setPadding(dp(if (filled || variant == "outlined") 24 else 12), dp(8), dp(if (filled || variant == "outlined") 24 else 12), dp(8))
        view.stateListAnimator = null
    }

    private fun choose(key: NativeGameDialogKey, action: String, version: Long = renderVersion) {
        val request = requests[key] ?: return
        val isChoice = request.spec.isSurfaceDialog && request.spec.choices.any { it.id == action }
        if (version != renderVersion || queue.active != key || request.cancelled ||
            (!isChoice && (action !in request.spec.displayActions || request.spec.enabled[action] != true)) || !state.choose(key.id)
        ) return
        request.action = action
        if (!request.spec.protectInputOnDismiss) {
            dismissWithoutProtection(key)
            return
        }
        cancelRelease()
        showInputGuard()
        // Battles refresh immediately. Ordinary acknowledgements are deferred
        // until the actual protected gesture and quiet interval have finished.
        if (!request.spec.isNotice) request.complete(action)
        scheduleReleaseIfQuiet()
    }

    private fun showInputGuard() {
        val request = queue.active?.let { requests[it] }
        val postTouchProtection = request?.let { current ->
            current.spec.postTouchProtectionActions?.let { actions ->
                !current.cancelled && current.action?.let(actions::contains) == true
            } ?: true
        } ?: true
        releasePolicy.begin(request?.spec?.isSurfaceDialog == true, postTouchProtection)
        saveChecklistScroll()
        renderVersion++
        checklistViews = null
        backKeyDown = null
        root?.apply {
            removeAllViews()
            setBackgroundColor(Color.TRANSPARENT)
            id = R.id.native_game_warning_input_guard
        }
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
                finishActiveRequest(key)
            }
        }
        release = operation
        // Surface confirmations must not keep extending an invisible full-screen
        // window indefinitely when the user tries tapping the app underneath.
        handler.postDelayed(operation, releasePolicy.nextDelayMillis())
    }

    private fun dismissWithoutProtection(key: NativeGameDialogKey) {
        state.dismiss(key.id)
        finishActiveRequest(key)
    }

    private fun finishActiveRequest(key: NativeGameDialogKey) {
        val request = requests.remove(key)
        request?.complete(if (request.cancelled) null else request.action)
        queue.finish(key.kind, key.id)
        // Keep the same native window across queued notices so the
        // underlying game never gets a briefly exposed input target.
        activateCurrent()
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
            val keepProtection = previous in invalid && requests[previous]?.spec?.protectInputOnDismiss != false &&
                (state.actionChosen || state.hasPointers)
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
        releasePolicy.clear()
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

    private fun spaced(top: Int) = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        .apply { topMargin = dp(top) }

    private fun rounded(color: Int, radius: Float) = GradientDrawable().apply { setColor(color); cornerRadius = radius }
    private fun dp(value: Int) = (value * activity.resources.displayMetrics.density).roundToInt()
    private fun dp(value: Float) = (value * activity.resources.displayMetrics.density).roundToInt()

    companion object {
        const val CHANNEL = "app.yahagi.kancollebrowser/native_warning"
        const val PROTECTION_MILLIS = NativeGameDialogReleasePolicy.QUIET_MILLIS
        private const val AVAILABILITY_TIMEOUT_MILLIS = 5000L
        private const val AVAILABILITY_POLL_MILLIS = 50L
    }
}
