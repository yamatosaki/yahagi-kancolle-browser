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
    private val bridge: GameFrameRateBridge,
) : MethodChannel.MethodCallHandler {
    interface Host {
        fun onFrameRateModeChanged(mode: GameFrameRateMode)
    }

    @Volatile
    var mode: GameFrameRateMode = GameFrameRateMode.AUTO
        private set
    private var configured = false

    val patchesMainScript: Boolean
        get() = configured && mode.patchesMainScript

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && bridge.isSupported(),
            )
            "configure" -> {
                val requestedMode = GameFrameRateMode.fromWireName(
                    call.argument<String>("mode"),
                )
                try {
                    bridge.configure(requestedMode.initialTarget)
                    mode = requestedMode
                    configured = true
                    host.onFrameRateModeChanged(mode)
                    result.success(null)
                } catch (error: GameFrameRateBridgeException) {
                    result.error(error.code, error.message, null)
                }
            }
            "applyTarget" -> {
                val target = GameFrameRateTarget.fromWireName(
                    call.argument<String>("target"),
                )
                if (target == null) {
                    result.error("invalid_frame_rate_target", "Unknown frame-rate target.", null)
                } else {
                    bridge.apply(target)
                    result.success(null)
                }
            }
            "measuredFps" -> result.success(bridge.measuredFps())
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        bridge.dispose()
        configured = false
        mode = GameFrameRateMode.AUTO
    }
}

private val GameFrameRateMode.initialTarget: GameFrameRateTarget
    get() = if (this == GameFrameRateMode.STABLE_30) {
        GameFrameRateTarget.FPS_30
    } else {
        GameFrameRateTarget.FPS_60
    }
