package app.yahagi.kancollebrowser.browser

import java.io.ByteArrayInputStream
import java.io.InputStream
import java.io.SequenceInputStream

/** Passes through the game bundle and inspects only its bounded Kanxy injection tail. */
internal class KanxyMainScriptCompatibilityInputStream(
    private val source: InputStream,
    bodyLength: Long,
    private val onPatched: (Patch) -> Unit,
) : InputStream() {
    enum class Patch { DROPDOWN, CONTROLLER_POINTER }

    private var prefixRemaining = (bodyLength - MAX_TAIL_BYTES).coerceAtLeast(0)
    private val tailLength = (bodyLength - prefixRemaining).toInt()
    private var inspectedTail: InputStream? = null
    private var patchesToReport = emptyList<Patch>()

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
        if (tail > 0) patchesToReport = emptyList()
        return prefix + tail
    }

    override fun available(): Int = inspectedTail?.available() ?: source.available()

    override fun close() = source.close()

    private fun reportPatch() {
        if (patchesToReport.isEmpty()) return
        val patches = patchesToReport
        patchesToReport = emptyList()
        patches.forEach { patch -> runCatching { onPatched(patch) } }
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
                // Latin-1 is a reversible byte view, including for non-ASCII source.
                var script = original.toString(Charsets.ISO_8859_1)
                patchDropdown(script)?.let {
                    script = it
                    patchesToReport = listOf(Patch.DROPDOWN)
                }
                patchControllerPointer(script)?.let {
                    script = it
                    patchesToReport = patchesToReport + Patch.CONTROLLER_POINTER
                }
                if (patchesToReport.isEmpty()) bytes
                else ByteArrayInputStream(script.toByteArray(Charsets.ISO_8859_1))
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

        fun patchDropdown(tail: String): String? {
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
        }

        private val controllerStart = Regex("(?m)^class ExtraController \\{\\r?$")
        private val classStart = Regex("(?m)^class ")
        private val mouseUpdateStart = Regex("(?m)^ +UpdateMouse\\(\\) \\{\\r?$")
        private val pointerMoveStart = Regex("(?m)^ +simulatePointerMove\\(\\) \\{\\r?$")
        private val pointerDispatch = Regex(
            "(?m)^( +)self\\.interaction\\.mouseOverRenderer = true;\\r?\\n" +
                "\\1self\\.interaction\\.didMove = true;\\r?\\n\\1this\\.simulatePointerMove\\(\\);",
        )
        private const val updateX = "this.x = Math.min(1200, Math.max(0, this.x + this.PointerSpeed * this.CommandState.MoveX));"
        private const val updateY = "this.y = Math.min(720, Math.max(0, this.y + this.PointerSpeed * this.CommandState.MoveY));"

        fun patchControllerPointer(tail: String): String? {
            val controller = controllerStart.findAll(tail).singleOrNull() ?: return null
            val start = controller.range.last + 1
            val end = classStart.find(tail, start)?.range?.first ?: tail.length
            val body = tail.substring(start, end)
            if (!body.contains("kanxy.AddOnRec(\"ExtraControllerInput\", this.RecExtraControllerInput.bind(this));")) return null
            val update = mouseUpdateStart.findAll(body).singleOrNull() ?: return null
            val move = pointerMoveStart.findAll(body).singleOrNull() ?: return null
            val updateStart = update.range.last + 1
            if (updateStart >= move.range.first ||
                !body.substring(move.range.last + 1).trimStart()
                    .startsWith("kanxy.app.view.dispatchEvent(new PointerEvent(\"pointermove\", {")) return null

            val updateBody = body.substring(updateStart, move.range.first)
            val dispatch = pointerDispatch.findAll(updateBody).singleOrNull() ?: return null
            val newline = if (dispatch.value.contains("\r\n")) "\r\n" else "\n"
            val indent = dispatch.groupValues[1]
            val position = updateBody.indexOf("$newline$indent$updateX$newline$indent$updateY")
            if (position < 0 || position >= dispatch.range.first) return null
            // Idle synthetic events would take over the real pointer's Pixi state each frame.
            val guard = """
                const moved = Number.isFinite(this.x) && Number.isFinite(this.y) &&
                    (this.x !== previousX || this.y !== previousY);
                if (moved || this.CommandState.Select === "down" ||
                    this.CommandState.Pointer === "down" || this.CommandState.Pointer === "up" ||
                    this.CommandState.WheelUp === "down" || this.CommandState.WheelDown === "down") {
                    self.interaction.mouseOverRenderer = true;
                    self.interaction.didMove = true;
                    this.simulatePointerMove();
                }
            """.trimIndent().prependIndent(indent).replace("\n", newline)
            val beforePosition = position + newline.length
            val patched = updateBody.replaceRange(dispatch.range, guard).replaceRange(
                beforePosition, beforePosition,
                "${indent}const previousX = this.x;$newline${indent}const previousY = this.y;$newline",
            )
            return tail.replaceRange(start + updateStart, start + move.range.first, patched)
        }
    }
}
