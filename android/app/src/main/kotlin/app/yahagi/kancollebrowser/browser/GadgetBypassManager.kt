package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Method channel bridge between Dart settings and the native bypass engine.
 *
 * The manager owns the engine/cache and forwards enable/disable transitions to
 * the host (MainActivity) so the WebView client can be wrapped or restored.
 */
class GadgetBypassManager(
    context: Context,
    private val host: Host,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "GadgetBypass"
    }

    interface Host {
        fun onBypassEnabledChanged(enabled: Boolean)
    }

    private val cache = GadgetBypassCache(File(context.cacheDir, "gadget_bypass_cache"))

    val engine = GadgetBypassEngine(
        cache = cache,
        onCacheHit = { url -> Log.d(TAG, "cache hit $url") },
    )

    @Volatile
    var enabled: Boolean = false
        private set

    @Volatile
    var endpoint: String = GadgetBypassRules.DEFAULT_ENDPOINT
        private set

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                val requestedEnabled = call.argument<Boolean>("enabled") ?: false
                val requestedEndpoint = call.argument<String>("endpoint")
                    ?: GadgetBypassRules.DEFAULT_ENDPOINT
                val validation = GadgetBypassRules.validateEndpoint(requestedEndpoint)
                if (!validation.isValid || validation.normalized == null) {
                    result.success(
                        mapOf(
                            "success" to false,
                            "error" to (validation.error ?: "invalid_endpoint"),
                        ),
                    )
                    return
                }
                enabled = requestedEnabled
                endpoint = validation.normalized
                Log.d(TAG, "configure enabled=$enabled endpoint=$endpoint")
                host.onBypassEnabledChanged(enabled)
                result.success(
                    mapOf(
                        "success" to true,
                        "endpoint" to endpoint,
                    ),
                )
            }
            "status" -> {
                result.success(
                    mapOf(
                        "enabled" to enabled,
                        "endpoint" to endpoint,
                        "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O),
                        "cacheBytes" to cache.sizeBytes(),
                    ),
                )
            }
            "clearCache" -> {
                cache.clear()
                result.success(mapOf("success" to true))
            }
            "diagnose" -> {
                val endpointToProbe = endpoint
                Thread {
                    val w00g = GadgetBypassDiagnostics.probe(
                        GadgetBypassDiagnostics.w00gGadgetUrl(),
                    )
                    val endpointResult = GadgetBypassDiagnostics.probe(
                        GadgetBypassDiagnostics.endpointGadgetUrl(endpointToProbe),
                    )
                    Handler(Looper.getMainLooper()).post {
                        result.success(
                            mapOf(
                                "w00g" to probeToMap(w00g),
                                "endpoint" to probeToMap(endpointResult),
                            ),
                        )
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun probeToMap(probe: GadgetBypassProbe): Map<String, Any?> = mapOf(
        "reachable" to probe.reachable,
        "statusCode" to probe.statusCode,
        "elapsedMs" to probe.elapsedMs,
        "error" to probe.error,
    )
}
