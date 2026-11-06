package app.yahagi.kancollebrowser.nativewebview

import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.drawable.Drawable
import kotlin.math.roundToInt

/** Material checkbox artwork independent of the device vendor's Dialog theme. */
internal class NativeGameDialogCheckboxDrawable(
    private val density: Float,
    private val selected: Int,
    private val check: Int,
    private val outline: Int,
) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    override fun getIntrinsicWidth() = (18 * density).roundToInt()
    override fun getIntrinsicHeight() = (18 * density).roundToInt()
    override fun isStateful() = true
    override fun onStateChange(state: IntArray): Boolean { invalidateSelf(); return true }
    override fun draw(canvas: Canvas) {
        val checked = state.contains(android.R.attr.state_checked)
        val rect = RectF(bounds).apply { inset(density, density) }
        paint.color = if (checked) selected else outline
        paint.style = if (checked) Paint.Style.FILL else Paint.Style.STROKE
        paint.strokeWidth = 2 * density
        canvas.drawRoundRect(rect, 2 * density, 2 * density, paint)
        if (checked) {
            paint.color = check
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 2 * density
            paint.strokeJoin = Paint.Join.MITER
            val path = Path().apply {
                moveTo(bounds.left + 4 * density, bounds.top + 9 * density)
                lineTo(bounds.left + 7 * density, bounds.top + 12 * density)
                lineTo(bounds.left + 14 * density, bounds.top + 5 * density)
            }
            canvas.drawPath(path, paint)
        }
    }
    override fun setAlpha(alpha: Int) { paint.alpha = alpha; invalidateSelf() }
    override fun setColorFilter(filter: ColorFilter?) { paint.colorFilter = filter; invalidateSelf() }
    @Suppress("DEPRECATION") override fun getOpacity() = PixelFormat.TRANSLUCENT
}
