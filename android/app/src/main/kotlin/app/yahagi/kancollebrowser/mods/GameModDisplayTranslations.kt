package app.yahagi.kancollebrowser.mods

import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import java.io.File

internal object GameModDisplayTranslations {
    const val CONFIG_KEY = "displayTranslations"
    const val MAX_TABLES = 96
    const val MAX_TOTAL_BYTES = 2L * 1024 * 1024
    const val MAX_TOTAL_REGEX = 1024

    enum class Category(val directory: String, val configKey: String, val kind: String, val maxEntries: Int) {
        DICTIONARY("text", "dictionaries", "text_translation", 2048),
        REGEX("text_regex", "regex", "text_regex_translation", 256),
        BGM("bgm_name", "bgm", "bgm_translation", 1024),
    }

    data class Table(val category: Category, val name: String) {
        val kind: String get() = category.kind
    }

    data class Content(val data: Any, val count: Int)
    private val tablePath = Regex("text/(text|text_regex|bgm_name)/([A-Za-z0-9_-]{1,64})\\.json")
    private val reservedKeys = setOf("__proto__", "prototype", "constructor")
    private val bgmId = Regex("[0-9]{1,8}")

    fun table(path: String): Table? {
        val match = tablePath.matchEntire(path) ?: return null
        val category = Category.entries.first { it.directory == match.groupValues[1] }
        val name = match.groupValues[2]
        if (name in reservedKeys || (category == Category.BGM && name !in setOf("titles", "battle", "port"))) return null
        return Table(category, name)
    }

    fun parse(file: File, table: Table): Content = GameModTranslationsJson.parse(
        file, 128 * 1024, { invalid(table) },
    ) { reader ->
        val rows = linkedMapOf<String, Any>()
        var entryCount = 0
        reader.beginObject()
        while (reader.hasNext()) {
            if (++entryCount > table.category.maxEntries) invalid(table)
            val key = text(reader.nextName(), 512, table)
            if (key.isEmpty() || key in reservedKeys) invalid(table)
            val value = when {
                table.category == Category.REGEX -> {
                    val replacement = text(string(reader, table), 1024, table)
                    if (!validPattern(key, replacement)) invalid(table)
                    replacement
                }
                table.category == Category.BGM && table.name != "titles" -> {
                    if (!bgmId.matches(key)) invalid(table)
                    readBgmName(reader, table)
                }
                else -> text(string(reader, table), 1024, table)
            }
            // Legacy tables contain repeated keys. Match JSON.parse's last value and first key position.
            rows[key] = value
        }
        reader.endObject()
        if (rows.isEmpty() || reader.peek() != JsonToken.END_DOCUMENT) invalid(table)
        val data = if (table.category == Category.REGEX) rows.map { (pattern, value) -> listOf(pattern, value) } else rows
        Content(data, rows.size)
    }

    private fun readBgmName(reader: JsonReader, table: Table): Map<String, String> {
        val names = linkedMapOf<String, String>()
        reader.beginObject()
        while (reader.hasNext()) {
            val field = reader.nextName()
            if ((field != "ja" && field != "zh") || field in names) invalid(table)
            names[field] = text(string(reader, table), 256, table)
        }
        reader.endObject()
        if (names.size != 2) invalid(table)
        return names
    }

    private fun string(reader: JsonReader, table: Table): String {
        if (reader.peek() != JsonToken.STRING) invalid(table)
        return reader.nextString()
    }

    private fun text(value: String, maxLength: Int, table: Table): String {
        if (value.length > maxLength || value.any { it.isISOControl() && it != '\n' } ||
            !Charsets.UTF_8.newEncoder().canEncode(value)) invalid(table)
        val plain = if (table.category == Category.DICTIONARY) value.replace("<br>", "") else value
        if ('<' in plain || '>' in plain) invalid(table)
        return value
    }

    private fun invalid(table: Table): Nothing = throw GameModException(
        "invalid_display_translation", "Invalid or unsupported display table: text/${table.category.directory}/${table.name}.json",
    )

    // Goto's remodel table uses a bounded lookahead over quoted resource descriptions.
    private const val REMODEL_RESOURCES =
        """｢([^｢｣\n]+)｣(×[0-9]+)(?:  |(\n))(?=(?:｢[^｢｣\n]+｣×[0-9]+(?:  |\n)){0,11}｢[^｢｣\n]+｣×[0-9]+ が必要です。$)"""

    // These original rules require two adjacent variable-width atoms or two wildcard captures.
    private val officialPatterns = setOf(
        """(.+?) には「(.+?)」\s*([0-9]+)個が必要です。""",
        """(.+?)\s*が\s*【遠征】から帰投しました。""",
        """(.+?)\s*さんとの【演習】で敗北しました。""",
        """(.+?)\s*さんとの【演習】で勝利しました。""",
        "装備運用枠【+([0-9]+)装備分】",
    )
    private val fixedGroups = listOf("""(\+|\-)""", """(?=｣×[0-9])""", "(?:を)?", "(/?)")
    private val repeatGroups = linkedMapOf(
        "(.+?)" to ".", "([0-9]+)" to "[0-9]", """(\d+)""" to """\d""", "(×[0-9]+)" to "[0-9]",
        """([^｢｣\n]+)""" to """[^｢｣\n]""", """([^\n｢｣]*)""" to """[^\n｢｣]""",
    )
    private val captureReplacement = Regex("""\$[0-9]""")
    private val characterClass = Regex("""\^?(?:\\[nsd-]|[^\[\]\\&^])+""")

    /**
     * Keep user-provided regex to the client data's bounded grammar. Group repetitions,
     * nonliteral alternatives, backreferences and arbitrary lookaround can multiply backtracking.
     * The renderer also bounds the input passed to each expression.
     */
    private fun validPattern(pattern: String, replacement: String): Boolean {
        if (pattern.length > 256 || captureReplacement.findAll(replacement).take(13).count() > 12 ||
            replacement.contains("$&") || replacement.contains("$`") ||
            replacement.contains("$'") || replacement.contains("$<")) return false
        if (pattern == REMODEL_RESOURCES || pattern in officialPatterns) return true

        var index = 0
        var repeatCount = 0
        var optionalCount = 0
        var captureCount = 0
        var requiresInput = false
        var lastRepeat: Regex? = null
        val separators = mutableListOf<String>()

        fun addRepeat(atom: String): Boolean {
            if (++repeatCount > 3) return false
            val repeat = Regex(atom)
            // A required delimiter has to interrupt at least one of two neighboring runs.
            // A separator like the 'a' in a+a+a+ would leave their lengths ambiguous.
            val prior = lastRepeat
            if (prior != null && separators.none { delimiter ->
                delimiter.none { prior.canConsume(it) } || delimiter.none { repeat.canConsume(it) }
            }) return false
            lastRepeat = repeat
            separators.clear()
            return true
        }
        while (index < pattern.length) {
            val fixed = fixedGroups.firstOrNull { pattern.startsWith(it, index) }
            if (fixed != null) {
                index += fixed.length
                if (fixed.startsWith("(\\") || fixed == "(/?)") captureCount++
                if ('?' in fixed && !fixed.startsWith("(?=") && ++optionalCount > 3) return false
                if (fixed == """(\+|\-)""") {
                    separators.add("+-")
                    requiresInput = true
                }
                continue
            }
            val repeated = repeatGroups.keys.firstOrNull { pattern.startsWith(it, index) }
            if (repeated != null) {
                if (!addRepeat(repeatGroups.getValue(repeated))) return false
                index += repeated.length
                captureCount++
                if (!repeated.endsWith("*)")) requiresInput = true
                continue
            }
            val start = index
            val char = pattern[index++]
            if (char == '^' || char == '$') {
                if ((char == '^' && index != 1) || (char == '$' && index != pattern.length)) return false
                continue
            }
            val delimiter = when (char) {
                '[' -> {
                    val end = pattern.indexOf(']', index)
                    if (end == -1) return false
                    val body = pattern.substring(index, end)
                    if (!characterClass.matches(body)) return false
                    index = end + 1
                    body.takeUnless { it.any { c -> c in "^-\\" } }
                }
                '\\' -> when (val escaped = pattern.getOrNull(index++) ?: return false) {
                    'n' -> "\n"
                    's', 'd' -> null
                    in "[]()+-.$^*?{}|\\＋" -> escaped.toString()
                    else -> return false
                }
                in "(){}|*?+]" -> return false
                '.' -> null
                else -> char.toString().takeUnless { char.isSurrogate() }
            }
            when (pattern.getOrNull(index)) {
                '+', '*' -> {
                    if (!addRepeat(pattern.substring(start, index))) return false
                    if (pattern[index++] == '+') requiresInput = true
                    if (pattern.getOrNull(index) == '?') index++
                }
                '?' -> {
                    if (++optionalCount > 3) return false
                    index++
                }
                else -> {
                    if (delimiter != null) separators.add(delimiter)
                    requiresInput = true
                }
            }
        }
        if (!requiresInput || captureCount > 8) return false
        return runCatching { Regex(pattern) }.isSuccess
    }

    private fun Regex.canConsume(char: Char): Boolean = matches(char.toString()) ||
        ("\\s" in pattern && (char.isWhitespace() || char == '\uFEFF'))
}
