package app.yahagi.kancollebrowser.mods

import com.google.gson.Strictness
import com.google.gson.stream.JsonReader
import java.io.File
import java.io.StringReader
import java.nio.ByteBuffer

/** Streams a bounded UTF-8 JSONC document through Gson's strict JSON reader. */
internal object GameModTranslationsJson {
    fun <T> parse(file: File, maxBytes: Int, invalid: () -> Nothing, read: (JsonReader) -> T): T = try {
        val size = file.length()
        if (!file.isFile || size !in 1..maxBytes.toLong()) invalid()
        val bytes = ByteArray(size.toInt())
        file.inputStream().use { input ->
            var offset = 0
            while (offset < bytes.size) {
                val count = input.read(bytes, offset, bytes.size - offset)
                if (count <= 0) invalid()
                offset += count
            }
            if (input.read() != -1) invalid()
        }
        val source = Charsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString().removePrefix("\uFEFF")
        JsonReader(StringReader(strictJson(source, invalid))).use { reader ->
            reader.strictness = Strictness.STRICT
            read(reader)
        }
    } catch (error: GameModException) {
        throw error
    } catch (_: Exception) {
        invalid()
    }

    /** Strip JSONC comments and trailing commas without rewriting quoted strings or joining tokens. */
    private fun strictJson(source: String, invalid: () -> Nothing): String = buildString(source.length) {
        var index = 0
        var pendingComma = false
        while (index < source.length) {
            val char = source[index++]
            when {
                char in " \t\r\n" -> append(char)
                char == '/' && source.getOrNull(index) == '/' -> {
                    index++
                    while (index < source.length && source[index] != '\r' && source[index] != '\n') index++
                    append(' ')
                }
                char == '/' && source.getOrNull(index) == '*' -> {
                    val end = source.indexOf("*/", index + 1)
                    if (end < 0) invalid()
                    index = end + 2
                    append(' ')
                }
                else -> {
                    if (pendingComma && char != ']' && char != '}') append(',')
                    pendingComma = char == ','
                    if (pendingComma) continue
                    append(char)
                    if (char != '"') continue
                    // Preserve the whole string, leaving escape validation to the strict reader.
                    while (index < source.length) {
                        val next = source[index++]
                        append(next)
                        if (next == '"') break
                        if (next == '\\' && index < source.length) append(source[index++])
                    }
                }
            }
        }
        if (pendingComma) append(',')
    }

}
