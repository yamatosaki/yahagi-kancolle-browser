package app.yahagi.kancollebrowser.diagnostics

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

internal class KanxyDiagnosticChannel(private val channel: MethodChannel) {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var session: Any? = null
    private var lastStatus: KanxyDiagnosticStatus? = null

    val recording: Boolean get() = session != null

    fun setRecording(enabled: Boolean) {
        if (enabled == recording) return
        lastStatus = null
        session = if (enabled) Any() else null
    }

    fun record(status: KanxyDiagnosticStatus) {
        val activeSession = session ?: return
        val occurredAt = System.currentTimeMillis()
        if (Looper.myLooper() == main.looper) {
            deliver(activeSession, status, occurredAt)
        } else {
            main.post { deliver(activeSession, status, occurredAt) }
        }
    }

    private fun deliver(activeSession: Any, status: KanxyDiagnosticStatus, occurredAt: Long) {
        if (session !== activeSession || lastStatus == status) return
        lastStatus = status
        runCatching {
            channel.invokeMethod("kanxyEvent", mapOf("status" to status.name, "occurredAtMs" to occurredAt))
        }
    }
}
