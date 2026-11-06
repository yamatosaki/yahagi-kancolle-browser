package app.yahagi.kancollebrowser.nativewebview

/** Resolved Flutter values. All dimensions are logical pixels, never Android SP. */
internal data class NativeGameDialogPresentation(
    val colors: Colors = Colors(),
    val text: Text = Text(),
    val layout: Layout = Layout(),
    val textDirection: String = "ltr",
    val fontAsset: String? = null,
    val customFontPath: String? = null,
) {
    data class Colors(
        val surface: Int = 0xff2b261e.toInt(),
        val onSurface: Int = 0xffece1d3.toInt(),
        val body: Int = 0xffd1c5b4.toInt(),
        val primary: Int = 0xffedbf69.toInt(),
        val onPrimary: Int = 0xff412d00.toInt(),
        val checkbox: Int = primary,
        val checkboxCheck: Int = onPrimary,
        val outline: Int = 0xff9a8f80.toInt(),
        val barrier: Int = 0x8a000000.toInt(),
        val error: Int = 0xfff2b8b5.toInt(),
    )
    data class TextStyle(val fontSize: Float, val lineHeight: Float, val fontWeight: Int, val fontFamily: String? = null)
    data class Text(
        val title: TextStyle = TextStyle(24f, 32f, 400),
        val body: TextStyle = TextStyle(14f, 20f, 400),
        val action: TextStyle = TextStyle(14f, 20f, 500),
        val checkbox: TextStyle = TextStyle(16f, 24f, 400),
    )
    data class Layout(
        val insetPadding: List<Float> = listOf(40f, 24f, 40f, 24f),
        val titlePadding: List<Float> = listOf(24f, 24f, 24f, 0f),
        val contentPadding: List<Float> = listOf(24f, 16f, 24f, 24f),
        val actionsPadding: List<Float> = listOf(24f, 0f, 24f, 24f),
        val radius: Float = 28f,
        val minWidth: Float = 280f,
        val actionMinHeight: Float = 40f,
        val actionSpacing: Float = 8f,
        val buttonRadius: Float = 20f,
    )

    companion object {
        fun parse(arguments: Any?): NativeGameDialogPresentation {
            if (arguments == null) return NativeGameDialogPresentation()
            val map = arguments as? Map<*, *> ?: error("Dialog presentation must be a map")
            fun section(key: String): Map<*, *> = map[key]?.let { it as? Map<*, *> ?: error("Invalid dialog $key") } ?: emptyMap<Any, Any>()
            fun number(values: Map<*, *>, key: String, fallback: Float, positive: Boolean = false): Float {
                val value = values[key] ?: return fallback
                require(value is Number && value.toDouble().isFinite() && value.toDouble() >= (if (positive) 0.01 else 0.0) && value.toDouble() <= 10000.0) { "Invalid dialog $key" }
                return value.toFloat()
            }
            fun color(values: Map<*, *>, key: String, fallback: Int): Int {
                val value = values[key] ?: return fallback
                require(value is Int || value is Long) { "Invalid dialog color $key" }
                val argb = (value as Number).toLong()
                require(argb in 0L..0xffffffffL) { "Invalid dialog color $key" }
                return argb.toInt()
            }
            fun optionalString(values: Map<*, *>, key: String): String? = values[key]?.let {
                require(it is String && it.isNotBlank() && it.length <= 4096) { "Invalid dialog $key" }; it
            }
            val defaults = NativeGameDialogPresentation()
            val c = section("colors")
            val colors = defaults.colors.let { Colors(color(c, "surface", it.surface), color(c, "onSurface", it.onSurface),
                color(c, "body", it.body), color(c, "primary", it.primary), color(c, "onPrimary", it.onPrimary),
                color(c, "checkbox", it.checkbox), color(c, "checkboxCheck", it.checkboxCheck), color(c, "outline", it.outline), color(c, "barrier", it.barrier), color(c, "error", it.error)) }
            val t = section("text")
            fun text(key: String, fallback: TextStyle): TextStyle {
                val values = t[key]?.let { it as? Map<*, *> ?: error("Invalid dialog text $key") } ?: emptyMap<Any, Any>()
                val weight = values["fontWeight"] ?: fallback.fontWeight
                require(weight is Int && weight in 100..900) { "Invalid dialog fontWeight" }
                return TextStyle(number(values, "fontSize", fallback.fontSize, true), number(values, "lineHeight", fallback.lineHeight, true), weight,
                    optionalString(values, "fontFamily"))
            }
            val text = Text(text("title", defaults.text.title), text("body", defaults.text.body), text("action", defaults.text.action), text("checkbox", defaults.text.checkbox))
            val l = section("layout")
            fun padding(key: String, fallback: List<Float>): List<Float> {
                val values = l[key] ?: return fallback
                require(values is List<*> && values.size == 4) { "Invalid dialog padding $key" }
                return values.map { value ->
                    require(value is Number && value.toDouble().isFinite() && value.toDouble() in 0.0..10000.0) { "Invalid dialog padding $key" }
                    value.toFloat()
                }
            }
            val layout = defaults.layout.let { Layout(padding("insetPadding", it.insetPadding), padding("titlePadding", it.titlePadding),
                padding("contentPadding", it.contentPadding), padding("actionsPadding", it.actionsPadding), number(l, "radius", it.radius),
                number(l, "minWidth", it.minWidth), number(l, "actionMinHeight", it.actionMinHeight), number(l, "actionSpacing", it.actionSpacing), number(l, "buttonRadius", it.buttonRadius)) }
            val direction = map["textDirection"] ?: "ltr"
            require(direction == "ltr" || direction == "rtl") { "Invalid dialog textDirection" }
            return NativeGameDialogPresentation(colors, text, layout, direction as String, optionalString(map, "fontAsset"), optionalString(map, "customFontPath"))
        }
    }
}
