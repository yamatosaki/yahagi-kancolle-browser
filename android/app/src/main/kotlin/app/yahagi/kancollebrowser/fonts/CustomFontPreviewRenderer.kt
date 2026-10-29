package app.yahagi.kancollebrowser.fonts

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import java.io.File
import java.util.Locale

/** A preview owns only local objects; no font is registered in Flutter or cached here. */
internal object CustomFontPreviewRenderer {
    fun render(
        file: File,
        request: CustomFontPreviewRequest,
        isCancelled: () -> Boolean,
    ): ByteArray {
        fun checkActive() {
            if (isCancelled() || Thread.currentThread().isInterrupted) {
                throw CustomFontException("activity_destroyed", "The font preview was cancelled")
            }
        }
        checkActive()
        // File builders bypass the asset cache. Do not derive styled Typeface variants:
        // Typeface.create(custom, style/weight) retains them in framework style caches.
        val typeface = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Typeface.Builder(file).build()
        } else {
            Typeface.createFromFile(file)
        }
        if (typeface == null || typeface === Typeface.DEFAULT) {
            throw CustomFontException("invalid_font", "The selected font cannot be loaded")
        }
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            this.typeface = typeface
            textSize = request.fontSize
            color = request.color
            textLocale = Locale.forLanguageTag(request.locale)
        }
        try {
            checkActive()
            // Layout's API 23 constant has the same value as LineBreaker's API
            // 29 constant; using the latter would break Android 7/8 previews.
            @android.annotation.SuppressLint("WrongConstant")
            val layout = StaticLayout.Builder.obtain(request.text, 0, request.text.length, paint, request.width)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setLineSpacing(0f, 1.6f)
                .setIncludePad(true)
                .setBreakStrategy(Layout.BREAK_STRATEGY_SIMPLE)
                .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NONE)
                .setMaxLines(8)
                .setEllipsize(TextUtils.TruncateAt.END)
                .build()
            checkActive()
            val bitmap = Bitmap.createBitmap(request.width, request.bitmapHeight(layout.height), Bitmap.Config.ARGB_8888)
            try {
                val canvas = Canvas(bitmap)
                try {
                    layout.draw(canvas)
                    checkActive()
                    val output = CustomFontPreviewOutput(CustomFontPreviewRequest.MAX_PNG_BYTES)
                    if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                        throw CustomFontException("font_preview_failed", "Unable to render the font preview")
                    }
                    checkActive()
                    return output.toByteArray()
                } finally {
                    canvas.setBitmap(null)
                }
            } finally {
                bitmap.recycle()
            }
        } finally {
            paint.typeface = null
        }
    }
}
