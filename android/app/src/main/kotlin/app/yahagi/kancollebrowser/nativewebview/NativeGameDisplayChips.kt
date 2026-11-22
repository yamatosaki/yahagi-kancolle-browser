package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.RadioButton
import kotlin.math.max

/** Wraps labels at their own width without recreating a chip when its state changes. */
internal class NativeGameDisplayChipGroup(
    context: Context,
    private val columnSpacing: Int,
    private val rowSpacing: Int,
) : ViewGroup(context) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val bounded = MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED
        val widthLimit = if (bounded) MeasureSpec.getSize(widthMeasureSpec) else Int.MAX_VALUE
        val childWidth = if (bounded) MeasureSpec.makeMeasureSpec(widthLimit, MeasureSpec.AT_MOST)
            else MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        val childHeight = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        var maximumWidth = 0
        var totalHeight = 0
        var rowWidth = 0
        var rowHeight = 0
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            child.measure(childWidth, childHeight)
            if (rowWidth > 0 && rowWidth + columnSpacing + child.measuredWidth > widthLimit) {
                maximumWidth = max(maximumWidth, rowWidth)
                totalHeight += rowHeight + rowSpacing
                rowWidth = 0
                rowHeight = 0
            }
            if (rowWidth > 0) rowWidth += columnSpacing
            rowWidth += child.measuredWidth
            rowHeight = max(rowHeight, child.measuredHeight)
        }
        setMeasuredDimension(
            resolveSize(max(maximumWidth, rowWidth), widthMeasureSpec),
            resolveSize(totalHeight + rowHeight, heightMeasureSpec),
        )
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        val rtl = layoutDirection == View.LAYOUT_DIRECTION_RTL
        var rowWidth = 0
        var rowHeight = 0
        var y = 0
        for (index in 0 until childCount) {
            val child = getChildAt(index)
            val width = child.measuredWidth
            if (rowWidth > 0 && rowWidth + columnSpacing + width > measuredWidth) {
                y += rowHeight + rowSpacing
                rowWidth = 0
                rowHeight = 0
            }
            if (rowWidth > 0) rowWidth += columnSpacing
            val x = if (rtl) measuredWidth - rowWidth - width else rowWidth
            child.layout(x, y, x + width, y + child.measuredHeight)
            rowWidth += width
            rowHeight = max(rowHeight, child.measuredHeight)
        }
    }
}

internal class NativeGameDisplayChip(
    context: Context,
    val singleChoice: Boolean,
) : CheckBox(context) {
    override fun toggle() {
        if (!singleChoice || !isChecked) super.toggle()
    }

    override fun getAccessibilityClassName(): CharSequence =
        if (singleChoice) RadioButton::class.java.name else super.getAccessibilityClassName()
}
