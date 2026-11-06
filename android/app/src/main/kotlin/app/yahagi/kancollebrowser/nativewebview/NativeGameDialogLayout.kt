package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.ScrollView
import kotlin.math.max
import kotlin.math.min

/** Intrinsic Material dialog width, with independently reachable content and actions. */
internal class NativeGameDialogCard(
    context: Context,
    private val content: ScrollView,
    actions: View,
    private val minimumCardWidth: Int,
) : ViewGroup(context) {
    private val footer = ScrollView(context).apply {
        tag = "dialog-actions-scroll"
        isFillViewport = false
        isVerticalScrollBarEnabled = true
        addView(actions, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    }

    init {
        content.tag = "dialog-content-scroll"
        addView(content, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        addView(footer, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val unbounded = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        content.measure(unbounded, unbounded)
        footer.measure(unbounded, unbounded)
        val desiredWidth = max(minimumCardWidth, max(content.measuredWidth, footer.measuredWidth))
        val width = resolveSize(desiredWidth, widthMeasureSpec)
        val exactWidth = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY)
        content.measure(exactWidth, unbounded)
        footer.measure(exactWidth, unbounded)
        val naturalContentHeight = content.measuredHeight
        val naturalFooterHeight = footer.measuredHeight
        val height = resolveSize(naturalContentHeight + naturalFooterHeight, heightMeasureSpec)
        // Most dialogs pin all actions below the scrolling content. On unusually
        // short screens with very large/long actions, both areas can scroll.
        val footerLimit = if (naturalContentHeight + naturalFooterHeight <= height) naturalFooterHeight
            else min(naturalFooterHeight, max(1, height / 2))
        footer.measure(exactWidth, MeasureSpec.makeMeasureSpec(footerLimit, MeasureSpec.AT_MOST))
        content.measure(exactWidth, MeasureSpec.makeMeasureSpec((height - footer.measuredHeight).coerceAtLeast(0), MeasureSpec.AT_MOST))
        setMeasuredDimension(width, min(height, content.measuredHeight + footer.measuredHeight))
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        content.layout(0, 0, measuredWidth, content.measuredHeight)
        footer.layout(0, content.measuredHeight, measuredWidth, content.measuredHeight + footer.measuredHeight)
    }
}

/** Flutter OverflowBar: end-aligned horizontal actions, vertical when they do not fit. */
internal class NativeGameDialogActions(context: Context, private val spacing: Int) : ViewGroup(context) {
    private var horizontal = true

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val bounded = MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED
        val available = if (bounded) (MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight).coerceAtLeast(0) else Int.MAX_VALUE
        val widthSpec = if (bounded) MeasureSpec.makeMeasureSpec(available, MeasureSpec.AT_MOST)
            else MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        val heightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        var sumWidth = 0
        var maxWidth = 0
        var sumHeight = 0
        var maxHeight = 0
        for (index in 0 until childCount) {
            getChildAt(index).measure(widthSpec, heightSpec)
            val child = getChildAt(index)
            sumWidth += child.measuredWidth + if (index > 0) spacing else 0
            maxWidth = max(maxWidth, child.measuredWidth)
            sumHeight += child.measuredHeight
            maxHeight = max(maxHeight, child.measuredHeight)
        }
        horizontal = sumWidth <= available
        setMeasuredDimension(resolveSize((if (horizontal) sumWidth else maxWidth) + paddingLeft + paddingRight, widthMeasureSpec),
            resolveSize((if (horizontal) maxHeight else sumHeight) + paddingTop + paddingBottom, heightMeasureSpec))
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        val rtl = layoutDirection == View.LAYOUT_DIRECTION_RTL
        var totalWidth = 0
        for (index in 0 until childCount) totalWidth += getChildAt(index).measuredWidth + if (index > 0) spacing else 0
        var x = if (rtl) paddingLeft + totalWidth else measuredWidth - paddingRight - totalWidth
        var y = paddingTop
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            val left = if (horizontal) { if (rtl) x - child.measuredWidth else x }
                else if (rtl) paddingLeft else measuredWidth - paddingRight - child.measuredWidth
            val top = if (horizontal) paddingTop else y
            child.layout(left, top, left + child.measuredWidth, top + child.measuredHeight)
            if (horizontal) x += (child.measuredWidth + spacing) * if (rtl) -1 else 1 else y += child.measuredHeight
        }
    }
}
