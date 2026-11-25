package app.yahagi.kancollebrowser.mods

import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import java.io.File

internal object GameModQuestTranslations {
    const val PATH = "text/api/questlist.json"
    const val KIND = "quest_translation"
    private const val MAX_BYTES = 512 * 1024
    private const val MAX_ENTRIES = 2048
    private val questId = Regex("[1-9][0-9]{0,8}")

    data class Translation(val title: String, val detail: String)

    fun parse(file: File): Map<String, Translation> =
        GameModTranslationsJson.parse(file, MAX_BYTES, ::invalid, ::readTranslations)

    private fun readTranslations(reader: JsonReader): Map<String, Translation> {
        val translations = linkedMapOf<String, Translation>()
        var entryCount = 0
        reader.beginArray()
        while (reader.hasNext()) {
            if (++entryCount > MAX_ENTRIES) invalid()
            var id: String? = null
            var title: String? = null
            var detail: String? = null
            reader.beginObject()
            while (reader.hasNext()) {
                when (reader.nextName()) {
                    "api_no" -> {
                        if (id != null || reader.peek() != JsonToken.NUMBER) invalid()
                        id = reader.nextString().takeIf(questId::matches) ?: invalid()
                    }
                    "api_title" -> {
                        if (title != null) invalid()
                        title = readDisplayText(reader, 160, allowBreaks = false)
                    }
                    "api_detail" -> {
                        if (detail != null) invalid()
                        detail = readDisplayText(reader, 1024, allowBreaks = true)
                    }
                    else -> invalid()
                }
            }
            reader.endObject()
            val number = id ?: invalid()
            val translation = Translation(title ?: invalid(), detail ?: invalid())
            // The Asaico table repeats an identical row for quest 863.
            val previous = translations.put(number, translation)
            if (previous != null && previous != translation) invalid()
        }
        reader.endArray()
        if (translations.isEmpty() || reader.peek() != JsonToken.END_DOCUMENT) invalid()
        return translations
    }

    private fun readDisplayText(reader: JsonReader, limit: Int, allowBreaks: Boolean): String {
        if (reader.peek() != JsonToken.STRING) invalid()
        val text = reader.nextString()
        val plainText = if (allowBreaks) text.replace("<br>", "") else text
        if (text.length > limit || plainText.isBlank() || '<' in plainText ||
            plainText.any { it.isISOControl() } || !Charsets.UTF_8.newEncoder().canEncode(plainText)) invalid()
        return text
    }

    private fun invalid(): Nothing = throw GameModException("invalid_quest_translation", "Invalid or unsupported quest translation table")
}
