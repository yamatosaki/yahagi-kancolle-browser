package app.yahagi.kancollebrowser.browser

import app.yahagi.kancollebrowser.diagnostics.KanxyDiagnosticStatus
import java.io.ByteArrayInputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class KanxyMainScriptInputStreamTest {
    @Test
    fun findsTheKanxyCoreMarkerAcrossReadsWithoutChangingTheScript() {
        val script = "prefix: new WebSocket(this.kanxy.unew WebSocket(this.kanxy.url); tail".toByteArray()
        val events = mutableListOf<KanxyDiagnosticStatus>()
        val stream = KanxyMainScriptInputStream(ByteArrayInputStream(script), script.size.toLong(), events::add)
        val buffer = ByteArray(7)
        val received = stream.use { input ->
            java.io.ByteArrayOutputStream().apply {
                write(input.read())
                while (true) {
                    val count = input.read(buffer, 1, 5)
                    if (count < 0) break
                    write(buffer, 1, count)
                }
            }.toByteArray()
        }

        assertArrayEquals(script, received)
        assertEquals(listOf(KanxyDiagnosticStatus.MAIN_SCRIPT_KANXY_MARKER), events)
    }

    @Test
    fun reportsMissingOnlyAfterTheWholeScriptHasBeenRead() {
        val script = "window.gameLoaded = true;".toByteArray()
        val events = mutableListOf<KanxyDiagnosticStatus>()
        val stream = KanxyMainScriptInputStream(ByteArrayInputStream(script), script.size.toLong(), events::add)
        val received = ByteArray(script.size)

        stream.use {
            assertEquals(script.size - 1, it.read(received, 0, script.size - 1))
            assertTrue(events.isEmpty())
            assertEquals(1, it.read(received, script.size - 1, 1))
        }

        assertArrayEquals(script, received)
        assertEquals(listOf(KanxyDiagnosticStatus.MAIN_SCRIPT_MARKER_MISSING), events)
    }

    @Test
    fun incompleteOrSkippedReadsDoNotReportTheMarkerMissing() {
        val script = "prefix: new WebSocket(this.kanxy.url); tail".toByteArray()
        val events = mutableListOf<KanxyDiagnosticStatus>()
        val partial = KanxyMainScriptInputStream(ByteArrayInputStream(script), script.size.toLong(), events::add)
        partial.use { it.read() }

        val skipped = KanxyMainScriptInputStream(ByteArrayInputStream(script), script.size.toLong(), events::add)
        skipped.use {
            assertEquals(9L, it.skip(9))
            assertArrayEquals(script.copyOfRange(9, script.size), it.readBytes())
        }

        assertTrue(events.isEmpty())
    }
}
