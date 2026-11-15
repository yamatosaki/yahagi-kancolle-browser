package app.yahagi.kancollebrowser.browser

import java.io.ByteArrayInputStream
import java.io.InputStream
import java.io.SequenceInputStream

/** Passes through the game bundle and inspects only its bounded Kanxy injection tail. */
internal class KanxyDropdownTouchInputStream(
    private val source: InputStream,
    bodyLength: Long,
    private val onPatched: () -> Unit,
) : InputStream() {
    private var prefixRemaining = (bodyLength - MAX_TAIL_BYTES).coerceAtLeast(0)
    private val tailLength = (bodyLength - prefixRemaining).toInt()
    private var inspectedTail: InputStream? = null
    private var reportPatchOnRead = false

    override fun read(): Int {
        if (prefixRemaining > 0) {
            val value = source.read()
            if (value >= 0) prefixRemaining--
            return value
        }
        return tail().read().also { if (it >= 0) reportPatch() }
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (offset < 0 || length < 0 || length > buffer.size - offset) throw IndexOutOfBoundsException()
        if (length == 0) return 0
        if (prefixRemaining > 0) {
            val count = source.read(buffer, offset, minOf(length.toLong(), prefixRemaining).toInt())
            if (count > 0) prefixRemaining -= count
            return count
        }
        return tail().read(buffer, offset, length).also { if (it > 0) reportPatch() }
    }

    override fun skip(length: Long): Long {
        if (length <= 0) return 0
        val prefix = if (prefixRemaining > 0) source.skip(minOf(length, prefixRemaining)) else 0
        prefixRemaining -= prefix
        if (prefix == length || prefixRemaining > 0) return prefix
        val tail = tail().skip(length - prefix)
        if (tail > 0) reportPatchOnRead = false
        return prefix + tail
    }

    override fun available(): Int = inspectedTail?.available() ?: source.available()

    override fun close() = source.close()

    private fun reportPatch() {
        if (!reportPatchOnRead) return
        reportPatchOnRead = false
        runCatching(onPatched)
    }

    private fun tail(): InputStream {
        inspectedTail?.let { return it }
        val original = ByteArray(tailLength)
        var read = 0
        while (read < original.size) {
            val count = source.read(original, read, original.size - read)
            if (count <= 0) break
            read += count
        }
        val bytes = ByteArrayInputStream(original, 0, read)
        val tail = if (read != original.size) {
            SequenceInputStream(bytes, source)
        } else {
            val extra = source.read()
            if (extra >= 0) {
                val rest = SequenceInputStream(ByteArrayInputStream(byteArrayOf(extra.toByte())), source)
                SequenceInputStream(bytes, rest)
            } else {
                val patched = patchDropdown(original)
                reportPatchOnRead = patched != null
                if (patched == null) bytes else ByteArrayInputStream(patched)
            }
        }
        inspectedTail = tail
        return tail
    }

    private companion object {
        const val MAX_TAIL_BYTES = 1024 * 1024L
        const val LEGACY_HANDLER = "bg.on(\"click\", function () {"
        const val TOUCH_HANDLER = "bg.on(EventTypeConst_1.EventType.CLICK, function () {"
        val uiStart = Regex("(?m)^class UI\\r?\\n\\{")
        val dropdownStart = Regex("(?m)^    PixiDropdown\\(options\\) \\{")
        val dropdownEnd = Regex("(?m)^    CreateKanxyTags\\(tagList, containerWidth\\) \\{")
        val socketStart = Regex("(?m)^class WSClient \\{")
        val headerHandler = Regex("(?m)^        selectedBg\\.on\\(\\r?\\n            EventTypeConst_1\\.EventType\\.CLICK,")

        fun patchDropdown(original: ByteArray): ByteArray? {
            // Latin-1 is a reversible byte view. It preserves every non-ASCII character in the script.
            val tail = original.toString(Charsets.ISO_8859_1)
            val ui = uiStart.findAll(tail).singleOrNull() ?: return null
            val socket = socketStart.findAll(tail).singleOrNull() ?: return null
            if (socket.range.first <= ui.range.last ||
                !tail.substring(socket.range.last + 1).contains("new WebSocket(this.kanxy.url)")
            ) return null
            val uiBody = tail.substring(ui.range.last + 1, socket.range.first)
            val start = dropdownStart.findAll(uiBody).singleOrNull() ?: return null
            val end = dropdownEnd.findAll(uiBody).singleOrNull() ?: return null
            if (end.range.first <= start.range.last) return null
            val dropdown = uiBody.substring(start.range.last + 1, end.range.first)
            val first = dropdown.indexOf(LEGACY_HANDLER)
            if (first < 0) return null
            val second = dropdown.indexOf(LEGACY_HANDLER, first + LEGACY_HANDLER.length)
            if (second < 0 || dropdown.indexOf(LEGACY_HANDLER, second + LEGACY_HANDLER.length) >= 0) return null
            val header = headerHandler.find(dropdown, second + LEGACY_HANDLER.length) ?: return null
            if (!dropdown.substring(first + LEGACY_HANDLER.length, second).contains("showChildren(index);") ||
                !dropdown.substring(second + LEGACY_HANDLER.length, header.range.first)
                    .contains("selectedChildIndex = childIndex;")
            ) return null
            val offset = ui.range.last + 1 + start.range.last + 1
            return tail.replaceRange(offset, offset + dropdown.length, dropdown.replace(LEGACY_HANDLER, TOUCH_HANDLER))
                .toByteArray(Charsets.ISO_8859_1)
        }
    }
}
