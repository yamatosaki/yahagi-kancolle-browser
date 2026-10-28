package app.yahagi.kancollebrowser.browser

import android.annotation.SuppressLint
import android.app.Activity
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.ceil
import kotlin.math.floor

/** An app-owned control above both Activity WebViews and Flutter PlatformViews.
 * Only its 34 x 34 logical-pixel circle takes touches; the game stays usable.
 */
internal class GameFullscreenChannel(
    private val activity: Activity,
    engine: FlutterEngine,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "app.yahagi.kancollebrowser/game_fullscreen")
    private var button: ImageView? = null
    private var questNotice: TextView? = null
    private val noticeState = FullscreenNoticeState()
    private var noticeRoot: FrameLayout? = null
    private val noticeRootLayoutListener = View.OnLayoutChangeListener { _, left, top, right, bottom,
        oldLeft, oldTop, oldRight, oldBottom ->
        if (right - left != oldRight - oldLeft || bottom - top != oldBottom - oldTop) {
            refreshNotice()
        }
    }
    private var scale = 1f
    private var geometryRevision = 0L
    private var minX = 0f
    private var maxX = 0f
    private var minY = 0f
    private var maxY = 0f
    private var requestedContentBounds: FullscreenOverlayBounds? = null
    private var hintShown = false
    private var hintToast: Toast? = null
    private val gesture = FullscreenExitGesture(ViewConfiguration.get(activity).scaledTouchSlop.toFloat())

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "questNotice") {
            try {
                if (noticeState.setQuestMessage(call.argument<String>("message").orEmpty())) {
                    refreshNotice()
                }
                result.success(null)
            } catch (error: Exception) {
                result.error("quest_notice_unavailable", error.message, null)
            }
            return
        }
        if (call.method == "damageControlNotice") {
            try {
                val id = requireNotNull(call.argument<Number>("id")).toLong()
                val message = call.argument<String>("message").orEmpty()
                if (message.isEmpty()) {
                    if (noticeState.clearDamageControlNotice(id)) refreshNotice()
                    result.success(false)
                } else {
                    noticeState.setDamageControlNotice(id, message)
                    result.success(refreshNotice())
                }
            } catch (_: Exception) {
                rejectDamageControlNotice()
                result.success(false)
            }
            return
        }
        if (call.method == "damageControlNoticeVisible") {
            val visible = try {
                call.argument<Number>("id")?.toLong()?.let(::isDamageControlNoticeVisible) ?: false
            } catch (_: Exception) {
                false
            }
            result.success(visible)
            return
        }
        if (call.method != "update") {
            result.notImplemented()
            return
        }
        try {
            val requestedRevision = call.argument<Number>("geometryRevision")?.toLong()
            val nextRevision = requestedRevision ?: geometryRevision
            val geometryChanged = requestedRevision == null || nextRevision != geometryRevision
            if (geometryChanged) {
                gesture.finish(cancelled = true)
                button?.isPressed = false
            }
            geometryRevision = nextRevision
            updateContentBounds(call)
            if (call.argument<Boolean>("active") == true) {
                update(call, geometryChanged)
            } else {
                removeButton()
            }
            result.success(null)
        } catch (error: Exception) {
            removeButton()
            result.error("fullscreen_control_unavailable", error.message, null)
        }
    }

    private fun updateContentBounds(call: MethodCall) {
        fun number(key: String) = call.argument<Number>(key)?.toDouble()?.takeIf { it.isFinite() }
        val density = number("scale")?.takeIf { it > 0 }
        val left = number("contentLeft")
        val top = number("contentTop")
        val width = number("contentWidth")?.takeIf { it >= 0 }
        val height = number("contentHeight")?.takeIf { it >= 0 }
        requestedContentBounds = if (
            density != null && left != null && top != null && width != null && height != null
        ) {
            FullscreenOverlayBounds(
                (left * density).toInt(),
                (top * density).toInt(),
                ((left + width) * density).toInt(),
                ((top + height) * density).toInt(),
            )
        } else {
            // Older Flutter clients omit the rectangle and use the whole root.
            null
        }
    }

    private fun update(call: MethodCall, geometryChanged: Boolean) {
        fun number(key: String): Float = requireNotNull(call.argument<Number>(key)).toFloat().also {
            require(it.isFinite())
        }
        scale = number("scale").also { require(it > 0) }
        minX = number("minX") * scale
        maxX = number("maxX") * scale
        minY = number("minY") * scale
        maxY = number("maxY") * scale
        require(maxX >= minX && maxY >= minY)
        val root = requireNotNull(activity.findViewById<FrameLayout>(android.R.id.content))
        if (noticeRoot !== root) {
            noticeRoot?.removeOnLayoutChangeListener(noticeRootLayoutListener)
            noticeRoot = root
            root.addOnLayoutChangeListener(noticeRootLayoutListener)
        }
        val isNewButton = button == null
        val view = button ?: createButton().also {
            button = it
            root.addView(it)
        }
        view.contentDescription = call.argument<String>("description") ?: call.argument<String>("label")
        if (geometryChanged || isNewButton) {
            view.layoutParams = FrameLayout.LayoutParams(
                (number("width") * scale).toInt().coerceAtLeast(1),
                (number("height") * scale).toInt().coerceAtLeast(1),
                Gravity.TOP or Gravity.LEFT,
            ).apply {
                leftMargin = (number("x") * scale).coerceIn(minX, maxX).toInt()
                topMargin = (number("y") * scale).coerceIn(minY, maxY).toInt()
            }
            view.translationX = 0f
            view.translationY = 0f
        }
        view.bringToFront()
        refreshNotice()
        val hint = call.argument<String>("hint").orEmpty()
        if (hint.isNotEmpty() && !hintShown) {
            hintShown = true
            hintToast = Toast.makeText(activity, hint, Toast.LENGTH_LONG).also { it.show() }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createButton(): ImageView {
        val density = activity.resources.displayMetrics.density
        val paddingPx = (7 * density).toInt()
        val view = ImageView(activity).apply {
            setImageDrawable(ExitIcon())
            scaleType = ImageView.ScaleType.FIT_CENTER
            setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xcc122431.toInt())
                setStroke((density).toInt().coerceAtLeast(1), 0x668197a5)
            }
            // Elevation keeps the control above WebViews created after it.
            elevation = 10000 * density
            isClickable = true
            isFocusable = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setOnClickListener {
                channel.invokeMethod("exit", mapOf("geometryRevision" to geometryRevision))
            }
        }
        var rawDownX = 0f
        var rawDownY = 0f
        var startX = 0f
        var startY = 0f
        var dragging = false
        var gestureRevision = geometryRevision
        view.setOnTouchListener { _, event ->
            if (event.actionMasked != MotionEvent.ACTION_DOWN && gestureRevision != geometryRevision) {
                view.isPressed = false
                dragging = false
                gesture.finish(cancelled = true)
                return@setOnTouchListener true
            }
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    gestureRevision = geometryRevision
                    rawDownX = event.rawX
                    rawDownY = event.rawY
                    startX = view.x
                    startY = view.y
                    dragging = false
                    gesture.begin(rawDownX, rawDownY)
                    view.isPressed = true
                }
                MotionEvent.ACTION_MOVE -> {
                    dragging = gesture.move(event.rawX, event.rawY)
                    if (dragging) {
                        view.isPressed = false
                        view.x = (startX + event.rawX - rawDownX).coerceIn(minX, maxX)
                        view.y = (startY + event.rawY - rawDownY).coerceIn(minY, maxY)
                    }
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    view.isPressed = false
                    if (gesture.finish(cancelled = event.actionMasked == MotionEvent.ACTION_CANCEL)) {
                        view.performClick()
                    } else if (dragging && event.actionMasked != MotionEvent.ACTION_CANCEL) {
                        channel.invokeMethod("moved", mapOf(
                            "x" to view.x / scale,
                            "y" to view.y / scale,
                            "geometryRevision" to gestureRevision,
                        ))
                    }
                    dragging = false
                }
            }
            true
        }
        return view
    }

    private fun removeButton() {
        noticeState.clear()
        removeNotice()
        noticeRoot?.removeOnLayoutChangeListener(noticeRootLayoutListener)
        noticeRoot = null
        button?.let { (it.parent as? FrameLayout)?.removeView(it) }
        button = null
        gesture.finish(cancelled = true)
        hintToast?.cancel()
        hintToast = null
    }

    private fun removeNotice() {
        questNotice?.let { (it.parent as? FrameLayout)?.removeView(it) }
        questNotice = null
    }

    private fun rejectDamageControlNotice(): Boolean {
        noticeState.rejectDamageControlPresentation()
        removeNotice()
        return false
    }

    /** Returns true only for a complete damage-control notice with usable native bounds. */
    private fun refreshNotice(): Boolean {
        val message = noticeState.displayMessage
        if (message.isEmpty() || button == null) {
            removeNotice()
            if (noticeState.canPresentDamageControl) noticeState.rejectDamageControlPresentation()
            return false
        }
        val root = requireNotNull(activity.findViewById<FrameLayout>(android.R.id.content))
        val damageControl = noticeState.canPresentDamageControl
        if (damageControl && !hasUsableFullscreenRoot(root)) return rejectDamageControlNotice()
        val density = activity.resources.displayMetrics.density
        val view = questNotice ?: TextView(activity).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            isClickable = false
            isFocusable = false
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
            setPadding((12 * density).toInt(), (7 * density).toInt(), (12 * density).toInt(), (7 * density).toInt())
            background = GradientDrawable().apply {
                cornerRadius = 8 * density
                setColor(0xee203743.toInt())
                setStroke(density.toInt().coerceAtLeast(1), 0xffd4a85f.toInt())
            }
            elevation = 9999 * density
            questNotice = this
            root.addView(this)
        }
        // Damage-control notices are accepted only when all natural lines fit; never ellipsize.
        view.maxLines = if (damageControl) Int.MAX_VALUE else 2
        view.ellipsize = if (damageControl) null else TextUtils.TruncateAt.END
        view.text = message
        val metrics = activity.resources.displayMetrics
        val content = fullscreenOverlayContentBounds(
            root.width.takeIf { it > 0 } ?: metrics.widthPixels,
            root.height.takeIf { it > 0 } ?: metrics.heightPixels,
            requestedContentBounds,
        )
        val geometry = FullscreenQuestNoticeGeometry(content, density)
        view.maxWidth = geometry.maxWidth
        view.maxHeight = if (damageControl) Int.MAX_VALUE else geometry.maxHeight
        view.measure(
            View.MeasureSpec.makeMeasureSpec(geometry.maxWidth, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(
                if (damageControl) 0 else geometry.maxHeight,
                if (damageControl) View.MeasureSpec.UNSPECIFIED else View.MeasureSpec.AT_MOST,
            ),
        )
        val bounds = geometry.place(view.measuredWidth, view.measuredHeight)
        if (damageControl && !completeDamageControlTextFits(view, bounds, content)) {
            return rejectDamageControlNotice()
        }
        view.layoutParams = FrameLayout.LayoutParams(
            bounds.width,
            bounds.height,
            Gravity.TOP or Gravity.LEFT,
        ).apply {
            leftMargin = bounds.left
            topMargin = bounds.top
        }
        view.bringToFront()
        button?.bringToFront()
        return damageControl
    }

    private fun hasUsableFullscreenRoot(root: FrameLayout): Boolean =
        root.width > 0 && root.height > 0 && root.isAttachedToWindow && root.isShown &&
            root.windowVisibility == View.VISIBLE &&
            button?.let { it.parent === root && it.isAttachedToWindow && it.isShown } == true

    private fun fullscreenControlBounds(): FullscreenOverlayBounds? {
        val view = button ?: return null
        val params = view.layoutParams as? FrameLayout.LayoutParams ?: return null
        // Geometry updates apply LayoutParams on the next frame; drags apply translation now.
        val pendingLayout = view.isLayoutRequested || view.width <= 0 || view.height <= 0
        val root = view.parent as? FrameLayout
        val x = if (pendingLayout) {
            params.leftMargin + (root?.paddingLeft ?: 0) + view.translationX
        } else view.x
        val y = if (pendingLayout) {
            params.topMargin + (root?.paddingTop ?: 0) + view.translationY
        } else view.y
        val width = if (pendingLayout) params.width else view.width
        val height = if (pendingLayout) params.height else view.height
        return FullscreenOverlayBounds(
            floor(x).toInt(), floor(y).toInt(), ceil(x + width).toInt(), ceil(y + height).toInt(),
        )
    }

    private fun completeDamageControlTextFits(
        view: TextView,
        bounds: FullscreenOverlayBounds,
        content: FullscreenOverlayBounds,
    ): Boolean {
        val textLayout = view.layout ?: return false
        val lines = textLayout.lineCount
        return fullscreenDamageControlNoticeFits(
            noticeState.displayMessage,
            lines,
            if (lines > 0) textLayout.getLineEnd(lines - 1) else 0,
            (0 until lines).any { textLayout.getEllipsisCount(it) != 0 },
            ceil((0 until lines).maxOfOrNull { textLayout.getLineWidth(it) } ?: 0f).toInt() +
                view.compoundPaddingLeft + view.compoundPaddingRight,
            textLayout.height + view.compoundPaddingTop + view.compoundPaddingBottom,
            bounds,
            content,
            fullscreenControlBounds(),
        )
    }

    private fun isDamageControlNoticeVisible(id: Long): Boolean {
        if (noticeState.damageControlId != id || !noticeState.canPresentDamageControl) return false
        val root = activity.findViewById<FrameLayout>(android.R.id.content) ?: return false
        val view = questNotice ?: return false
        if (!hasUsableFullscreenRoot(root) || view.parent !== root || !view.isAttachedToWindow ||
            !view.isShown || view.alpha <= 0f || view.isLayoutRequested ||
            view.text.toString() != noticeState.displayMessage
        ) return false
        val visibleBounds = Rect()
        if (!view.getGlobalVisibleRect(visibleBounds) ||
            visibleBounds.width() != view.width || visibleBounds.height() != view.height
        ) return false
        return completeDamageControlTextFits(
            view,
            FullscreenOverlayBounds(view.left, view.top, view.right, view.bottom),
            fullscreenOverlayContentBounds(root.width, root.height, requestedContentBounds),
        )
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        removeButton()
    }

    private class ExitIcon : Drawable() {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        override fun getIntrinsicWidth(): Int = 24
        override fun getIntrinsicHeight(): Int = 24
        override fun draw(canvas: Canvas) {
            val checkpoint = canvas.save()
            canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
            canvas.scale(bounds.width() / 24f, bounds.height() / 24f)
            canvas.drawLines(floatArrayOf(
                4f, 9f, 9f, 9f, 9f, 9f, 9f, 4f,
                15f, 4f, 15f, 9f, 15f, 9f, 20f, 9f,
                4f, 15f, 9f, 15f, 9f, 15f, 9f, 20f,
                15f, 20f, 15f, 15f, 15f, 15f, 20f, 15f,
            ), paint)
            canvas.restoreToCount(checkpoint)
        }
        override fun setAlpha(alpha: Int) { paint.alpha = alpha }
        override fun setColorFilter(colorFilter: ColorFilter?) { paint.colorFilter = colorFilter }
        @Deprecated("Deprecated in Java")
        override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
    }
}
