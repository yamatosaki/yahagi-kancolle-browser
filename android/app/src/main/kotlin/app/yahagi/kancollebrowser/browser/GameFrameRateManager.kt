package app.yahagi.kancollebrowser.browser

import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

enum class GameFrameRateMode(val wireName: String) {
    AUTO("auto"),
    STABLE_30("stable30"),
    PREFER_60("prefer60");

    val patchesMainScript: Boolean
        get() = this != STABLE_30

    companion object {
        fun fromWireName(value: String?): GameFrameRateMode =
            entries.firstOrNull { it.wireName == value } ?: AUTO
    }
}

class GameFrameRateManager(
    private val host: Host,
) : MethodChannel.MethodCallHandler {
    interface Host {
        fun onFrameRateModeChanged(mode: GameFrameRateMode)
    }

    @Volatile
    var mode: GameFrameRateMode = GameFrameRateMode.AUTO
        private set

    val patchesMainScript: Boolean
        get() = mode.patchesMainScript

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            "configure" -> {
                mode = GameFrameRateMode.fromWireName(call.argument<String>("mode"))
                host.onFrameRateModeChanged(mode)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        mode = GameFrameRateMode.AUTO
    }
}
