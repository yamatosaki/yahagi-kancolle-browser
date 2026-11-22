package app.yahagi.kancollebrowser.nativewebview

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.SystemClock
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.roundToInt

internal data class NativeGameStartupCardData(
    val title: String,
    val stage: String? = null,
    val requests: String? = null,
    val pageProgress: Int? = null,
    val stalled: Boolean = false,
)

/** Lives inside the visible game viewport, above the WebView and outside its input path. */
internal class NativeGameStartupCard(context: Context) : FrameLayout(context) {
    private val density = resources.displayMetrics.density
    private val gutter = dp(12)
    private val panelParams = LayoutParams(0, WRAP_CONTENT, Gravity.CENTER).apply {
        setMargins(gutter, 0, gutter, 0)
    }
    private val panel = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(13), dp(9), dp(13), dp(9))
    }
    private val stageLabel = label(11f, MUTED)
    private val titleLabel = label(16f, FOREGROUND).apply {
        maxLines = 2
        setTypeface(typeface, Typeface.BOLD)
        accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
    }
    private val percentageLabel = label(12f, ACTIVE).apply {
        setPaddingRelative(dp(8), 0, 0, 0)
    }
    private val requestsLabel = label(12f, MUTED)
    private val indicator = NativeGameStartupIndicator(context).apply {
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    }
    private var rendered: NativeGameStartupCardData? = null

    init {
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        panel.addView(stageLabel)
        panel.addView(LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(titleLabel, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))
            addView(percentageLabel, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
        }, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
        panel.addView(requestsLabel)
        panel.addView(indicator, LinearLayout.LayoutParams(MATCH_PARENT, dp(4)).apply {
            topMargin = dp(6)
        })
        addView(panel, panelParams)
    }

    fun update(card: NativeGameStartupCardData) {
        val previous = rendered
        if (card == previous) return
        if (card.title != previous?.title) titleLabel.text = card.title
        if (card.stage != previous?.stage || previous == null) stageLabel.showText(card.stage)
        if (card.requests != previous?.requests || previous == null) requestsLabel.showText(card.requests)
        if (card.pageProgress != previous?.pageProgress || previous == null) {
            percentageLabel.showText(card.pageProgress?.let { "$it%" })
        }
        if (card.stalled != previous?.stalled) {
            val tone = if (card.stalled) AMBER else ACTIVE
            percentageLabel.setTextColor(tone)
            stageLabel.setTextColor(if (card.stalled) tone else MUTED)
            panel.background = GradientDrawable().apply {
                setColor(PANEL)
                setStroke(dp(1), if (card.stalled) AMBER_BORDER else BORDER)
                cornerRadius = dp(13).toFloat()
            }
        }
        indicator.update(card.pageProgress, if (card.stalled) AMBER else ACTIVE, card.stalled)
        rendered = card
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        // The parent is sized to the clipped viewport, which can be narrower than the WebView.
        val available = MeasureSpec.getSize(widthMeasureSpec) - gutter * 2
        panelParams.width = available.coerceIn(0, dp(424))
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean = false

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean = false

    private fun label(size: Float, color: Int) = TextView(context).apply {
        textSize = size
        setTextColor(color)
        includeFontPadding = false
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
    }

    private fun TextView.showText(value: String?) {
        text = value.orEmpty()
        visibility = if (value.isNullOrEmpty()) View.GONE else View.VISIBLE
    }

    private fun dp(value: Int): Int = (value * density).roundToInt()

    private companion object {
        val FOREGROUND = 0xffe0eaf0.toInt()
        val PANEL = 0xf2122431.toInt()
        val MUTED = 0xffa5b7be.toInt()
        val BORDER = 0xff3a515d.toInt()
        val ACTIVE = 0xff6fc3bd.toInt()
        val AMBER = 0xfff0d088.toInt()
        val AMBER_BORDER = 0xff776345.toInt()
    }
}

/** Repaints only the bar. Request-count updates leave the sweep running. */
internal class NativeGameStartupIndicator(
    context: Context,
    private val nowMillis: () -> Long = SystemClock::uptimeMillis,
    private val animationsEnabled: Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || ValueAnimator.areAnimatorsEnabled(),
) : View(context) {
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xff344a57.toInt() }
    private val highlight = Paint(Paint.ANTI_ALIAS_FLAG)
    private var progress: Int? = null
    private var stalled = false

    fun update(progress: Int?, color: Int, stalled: Boolean) {
        if (this.progress == progress && highlight.color == color && this.stalled == stalled) return
        this.progress = progress
        this.stalled = stalled
        highlight.color = color
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val right = width.toFloat()
        val bottom = height.toFloat()
        val radius = bottom / 2f
        canvas.drawRoundRect(0f, 0f, right, bottom, radius, radius, track)

        val measured = progress
        if (measured != null) {
            canvas.drawRoundRect(0f, 0f, right * (measured / 100f), bottom, radius, radius, highlight)
        } else if (!stalled) {
            val segmentWidth = right * 0.28f
            val phase = if (animationsEnabled) (nowMillis() % 1_400L) / 1_400f else 0.5f
            val start = (right - segmentWidth) * phase
            canvas.drawRoundRect(start, 0f, start + segmentWidth, bottom, radius, radius, highlight)
            if (animationsEnabled && isShown && windowVisibility == VISIBLE) {
                postInvalidateOnAnimation()
            }
        }
    }
}
