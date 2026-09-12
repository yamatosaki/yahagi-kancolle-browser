package app.yahagi.kancollebrowser

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.os.SystemClock
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.PixelCopy
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.core.view.ViewCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel
import app.yahagi.kancollebrowser.browser.WebViewProxyManager
import app.yahagi.kancollebrowser.browser.GadgetBypassManager
import app.yahagi.kancollebrowser.browser.GadgetBypassWebViewClient
import app.yahagi.kancollebrowser.browser.FixedCanvasScalePolicy
import app.yahagi.kancollebrowser.browser.GameFrameRateManager
import app.yahagi.kancollebrowser.browser.GameFrameRateBridge
import app.yahagi.kancollebrowser.browser.AndroidGameFrameRateSystemConstraints
import app.yahagi.kancollebrowser.browser.AndroidGameFrameReloadBridge
import app.yahagi.kancollebrowser.browser.GameFrameReloadManager
import app.yahagi.kancollebrowser.browser.GameResourceCacheEngine
import app.yahagi.kancollebrowser.browser.GameResourceCacheIndex
import app.yahagi.kancollebrowser.browser.GameResourceCacheMode
import app.yahagi.kancollebrowser.browser.GameResourceCachePolicy
import app.yahagi.kancollebrowser.browser.GameResourceCacheStore
import app.yahagi.kancollebrowser.browser.HttpUrlConnectionGameResourceFetcher
import app.yahagi.kancollebrowser.browser.OriginCookieManagerChannel
import app.yahagi.kancollebrowser.browser.GameResourceCacheManager
import app.yahagi.kancollebrowser.browser.GameResourceDownloadCoordinator
import app.yahagi.kancollebrowser.browser.GameResourceNetworkMonitor
import app.yahagi.kancollebrowser.capture.GameCaptureBridge
import app.yahagi.kancollebrowser.capture.ScreenshotCaptureAttempt
import app.yahagi.kancollebrowser.capture.ScreenshotCapturePolicy
import app.yahagi.kancollebrowser.capture.ScreenshotDestination
import app.yahagi.kancollebrowser.capture.ScreenshotOutput
import app.yahagi.kancollebrowser.capture.ScreenshotViewCandidate
import app.yahagi.kancollebrowser.composition.CompositionImageHandler
import app.yahagi.kancollebrowser.diagnostics.DiagnosticExportDirectoryHost
import app.yahagi.kancollebrowser.diagnostics.DiagnosticDirectoryPickerUi
import app.yahagi.kancollebrowser.diagnostics.DiagnosticPickerSystemBars
import app.yahagi.kancollebrowser.diagnostics.DiagnosticPlatformHandler
import app.yahagi.kancollebrowser.nativewebview.ActivityNativeGameWebViewHostOperations
import app.yahagi.kancollebrowser.nativewebview.ActivityWebViewHost
import app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewChannel
import app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewActivityAttachment
import app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewEngineChannels
import app.yahagi.kancollebrowser.nativewebview.NativeGameWebViewLifecycleObserver
import app.yahagi.kancollebrowser.nativewebview.NativeWebViewActivityStartupCoordinator
import app.yahagi.kancollebrowser.nativewebview.NativeWebViewActivityStartupOutcome
import app.yahagi.kancollebrowser.nativewebview.NativeWebViewProcessState
import app.yahagi.kancollebrowser.nativewebview.NativeWebViewStartupGuard
import app.yahagi.kancollebrowser.nativewebview.SharedPreferencesNativeWebViewStartupStore
import app.yahagi.kancollebrowser.notification.AppNotificationManager
import app.yahagi.kancollebrowser.notification.NotificationProgressService
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity(), GadgetBypassManager.Host, DiagnosticExportDirectoryHost {
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    @Suppress("DEPRECATION")
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val shellArgs = super.getFlutterShellArgs()
        val storedMode = getSharedPreferences(
            GameRenderingModeHcppPolicy.PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        ).getString(GameRenderingModeHcppPolicy.RENDERING_MODE_KEY, null)
        val enableHcpp = GameRenderingModeHcppPolicy.shouldEnable(storedMode)

        shellArgs.remove(FlutterShellArgs.ARG_ENABLE_HCPP_AND_SURFACE_CONTROL)
        if (enableHcpp) {
            shellArgs.add(FlutterShellArgs.ARG_ENABLE_HCPP_AND_SURFACE_CONTROL)
        }
        return shellArgs
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val attr = window.attributes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else {
                attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
            window.attributes = attr
        }
        enableNativeActivityWebViewIfSelected()
        AppNotificationManager.initChannels(this)
        applyPreferredUiRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        applyPreferredUiRefreshRate()
    }

    override fun onMultiWindowModeChanged(
        isInMultiWindowMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        gameSurfaceRecoveryTrigger.onMultiWindowModeChanged(isInMultiWindowMode)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        gameSurfaceRecoveryTrigger.onPictureInPictureModeChanged(isInPictureInPictureMode)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        gameSurfaceRecoveryTrigger.onConfigurationChanged()
        applyPreferredUiRefreshRate()
    }

    private fun applyPreferredUiRefreshRate() {
        val refreshRates = window.decorView.display
            ?.supportedModes
            ?.map { mode -> mode.refreshRate }
            .orEmpty()
        val preferredRefreshRate = UiRefreshRatePolicy.highestSupported(refreshRates)
        val attributes = window.attributes
        if (attributes.preferredRefreshRate == preferredRefreshRate) return
        attributes.preferredRefreshRate = preferredRefreshRate
        window.attributes = attributes
    }

    private companion object {
        const val GAME_AUDIO_CHANNEL = "app.yahagi.kancollebrowser/game_audio"
        const val GAME_CAPTURE_CHANNEL = "app.yahagi.kancollebrowser/game_capture"
        const val SCALE_CHANNEL = "app.webview/fixed_canvas_scaling"
        const val PROXY_CHANNEL = "app.yahagi.kancollebrowser/network_proxy"
        const val GADGET_BYPASS_CHANNEL = "app.yahagi.kancollebrowser/gadget_bypass"
        const val SCREEN_AWAKE_CHANNEL = "app.yahagi.kancollebrowser/screen_awake"
        const val GAME_SCREENSHOT_CHANNEL = "app.yahagi.kancollebrowser/game_screenshot"
        const val GAME_FRAME_RATE_CHANNEL = "app.yahagi.kancollebrowser/game_frame_rate"
        const val GAME_FRAME_RELOAD_CHANNEL = "app.yahagi.kancollebrowser/game_frame_reload"
        const val BATTLE_DAMAGE_ALERT_CHANNEL = "app.yahagi.kancollebrowser/battle_damage_alert"
        const val NOTIFICATION_CHANNEL = "app.yahagi.kancollebrowser/notification"
        const val BACKGROUND_GAME_RETENTION_CHANNEL =
            "app.yahagi.kancollebrowser/background_game_retention"
        const val DIAGNOSTICS_CHANNEL = "app.yahagi.kancollebrowser/diagnostics"
        const val GAME_ENVIRONMENT_CHANNEL = "app.yahagi.kancollebrowser/game_environment"
        const val GAME_RESOURCE_CACHE_CHANNEL = "app.yahagi.kancollebrowser/game_resource_cache"
        const val SCREENSHOT_PERMISSION_REQUEST = 2406
        const val DIAGNOSTIC_DIRECTORY_REQUEST = 2407
        val NATIVE_WEB_VIEW_MAIN_HANDLER by lazy { Handler(Looper.getMainLooper()) }
    }

    private var gameCaptureBridge: GameCaptureBridge? = null
    private var webViewProxyManager: WebViewProxyManager? = null
    private var gadgetBypassManager: GadgetBypassManager? = null
    private var gameFrameRateManager: GameFrameRateManager? = null
    private var gameFrameReloadManager: GameFrameReloadManager? = null
    private var gameResourceCacheEngine: GameResourceCacheEngine? = null
    private var gameResourceCacheManager: GameResourceCacheManager? = null
    @Volatile
    private var gameResourceCacheMode: GameResourceCacheMode = GameResourceCacheMode.TEMPORARY
    private var diagnosticPlatformHandler: DiagnosticPlatformHandler? = null
    private val diagnosticDirectoryPickerUi by lazy {
        DiagnosticDirectoryPickerUi(
            systemBars = object : DiagnosticPickerSystemBars {
                override fun showExitControls() {
                    WindowInsetsControllerCompat(window, window.decorView).show(
                        WindowInsetsCompat.Type.systemBars(),
                    )
                }

                override fun restoreImmersiveMode() {
                    WindowInsetsControllerCompat(window, window.decorView).apply {
                        systemBarsBehavior =
                            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                        hide(WindowInsetsCompat.Type.systemBars())
                    }
                }
            },
        )
    }
    private var gadgetBypassLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    
    private val gameSurfaceRecoveryHandler = Handler(Looper.getMainLooper())
    private val pendingGameSurfaceRecoveryActions = mutableListOf<Runnable>()
    private val gameSurfaceRecoveryTrigger = GameSurfaceRecoveryTrigger(
        ::scheduleGameSurfaceRecovery,
    )
    private var boundWebView: WebView? = null
    private var fixedCanvasLayoutListener: View.OnLayoutChangeListener? = null
    private val fixedCanvasScalePolicy = FixedCanvasScalePolicy()
    private var fixedCanvasContentWidth: Int = 1200
    private var fixedCanvasContentHeight: Int = 720
    private var pendingScreenshotResult: MethodChannel.Result? = null
    private var compositionImageHandler: CompositionImageHandler? = null
    private var compositionImageChannel: MethodChannel? = null
    private var activeScreenshotResult: MethodChannel.Result? = null
    private var activeScreenshotOutput: ScreenshotOutput? = null
    private val nativeWebViewHandler = Handler(Looper.getMainLooper())
    private var nativeWebViewStartupTimeout: Runnable? = null
    private var nativeWebViewStartup: NativeWebViewActivityStartupCoordinator? = null
    private var nativeGameWebViewHost: ActivityWebViewHost? = null
    private var activityRestartRequested = false
    private var nativeGameWebViewChannel: NativeGameWebViewChannel? = null
    private var nativeGameWebViewAttachment: NativeGameWebViewActivityAttachment? = null

    private fun attachNativeGameWebViewChannel(channel: NativeGameWebViewChannel) {
        nativeGameWebViewAttachment = channel.attachActivity(
            dispatchToMain = { operation ->
                if (Looper.myLooper() == Looper.getMainLooper()) {
                    operation()
                } else {
                    check(NATIVE_WEB_VIEW_MAIN_HANDLER.post(operation)) {
                        "The native WebView main-thread dispatcher rejected an operation"
                    }
                }
            },
            lifecycleObserver = object : NativeGameWebViewLifecycleObserver {
                override fun onCreated() {
                    // The native host is now discoverable under decorView. Reapply
                    // the existing request client stack to this single WebView.
                    ensureGadgetBypassWrap()
                    // Install the frame bridge while this WebView is still blank so
                    // document-start injection is active for the first DMM load.
                    gameFrameReloadManager?.configure()
                }

                override fun onPageStarted() {
                    // Keep the current canvas binding until the new document is
                    // positively classified as game or web by the injected script.
                }

                override fun onPageFinished() {
                    nativeWebViewStartup?.onPageFinished()
                }

                override fun onRenderProcessGone() {
                    nativeWebViewStartup?.onRenderProcessGone()
                }

                override fun onCreateFailed() {
                    nativeWebViewStartup?.onCreateFailed()
                }
            },
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        compositionImageHandler?.dispose()
        val imageHandler = CompositionImageHandler(
            this,
            hasStoragePermission = {
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                ) == PackageManager.PERMISSION_GRANTED
            },
            requestStoragePermission = {
                if (pendingScreenshotResult == null) {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                        SCREENSHOT_PERMISSION_REQUEST,
                    )
                }
            },
        )
        compositionImageHandler = imageHandler
        compositionImageChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CompositionImageHandler.CHANNEL_NAME,
        ).also { it.setMethodCallHandler(imageHandler) }

        val nativeChannel = NativeGameWebViewEngineChannels.acquire(flutterEngine)
        nativeGameWebViewChannel = nativeChannel
        attachNativeGameWebViewChannel(nativeChannel)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OriginCookieManagerChannel.METHOD_CHANNEL_NAME,
        ).setMethodCallHandler(OriginCookieManagerChannel())

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_ENVIRONMENT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "restartActivity" -> {
                    result.success(null)
                    requestActivityRestart()
                }
                else -> result.notImplemented()
            }
        }
        
        webViewProxyManager = WebViewProxyManager(context)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROXY_CHANNEL,
        ).setMethodCallHandler(webViewProxyManager)
        val resourceCacheRoot = File(filesDir, "game_resource_cache")
        val resourceEngine = GameResourceCacheEngine(
            GameResourceCacheStore(
                resourceCacheRoot,
                GameResourceCacheIndex(File(resourceCacheRoot, "index.json")),
                policyProvider = {
                    if (gameResourceCacheMode == GameResourceCacheMode.TEMPORARY) {
                        GameResourceCachePolicy(
                            maxBytes = GameResourceCacheStore.TEMPORARY_MAX_BYTES,
                            maxIdleAgeMs = GameResourceCacheStore.TEMPORARY_MAX_IDLE_AGE_MS,
                        )
                    } else {
                        GameResourceCachePolicy(
                            maxBytes = GameResourceCacheStore.DEFAULT_MAX_BYTES,
                        )
                    }
                },
            ),
            HttpUrlConnectionGameResourceFetcher(
                proxyProvider = {
                    webViewProxyManager?.currentNativeProxy() ?: java.net.Proxy.NO_PROXY
                },
            ),
        ) { gameResourceCacheMode }
        gameResourceCacheEngine = resourceEngine
        val resourceNetworkMonitor = GameResourceNetworkMonitor(context)
        val resourceCoordinator = GameResourceDownloadCoordinator(
            resourceEngine,
            { gameResourceCacheMode },
            File(resourceCacheRoot, "download_state.json"),
            resourceNetworkMonitor::state,
        )
        val resourceManager = GameResourceCacheManager(
            resourceEngine,
            resourceCoordinator,
            { gameResourceCacheMode },
            ::onGameResourceCacheModeChanged,
            resourceNetworkMonitor,
        )
        resourceNetworkMonitor.start(resourceCoordinator::onNetworkChanged)
        gameResourceCacheManager = resourceManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_RESOURCE_CACHE_CHANNEL,
        ).setMethodCallHandler(resourceManager)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_AUDIO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(
                    WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO),
                )
                "setMuted" -> {
                    val muted = call.argument<Boolean>("muted")
                    if (muted == null) {
                        result.error("invalid_argument", "muted must be a boolean", null)
                        return@setMethodCallHandler
                    }
                    setGameWebViewMuted(muted, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_AWAKE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(
                    window.attributes.flags and
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0,
                )
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled == null) {
                        result.error("invalid_argument", "enabled must be a boolean", null)
                        return@setMethodCallHandler
                    }
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_SCREENSHOT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureWebView" -> captureGameWebView(result, ScreenshotOutput.GALLERY)
                "captureWebViewPreview" ->
                    captureGameWebView(result, ScreenshotOutput.MEMORY_PREVIEW)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTLE_DAMAGE_ALERT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "alert" -> {
                    val severity = call.argument<String>("severity")
                    if (severity == null ||
                        severity !in setOf("moderate", "heavy")
                    ) {
                        result.error(
                            "invalid_argument",
                            "severity must be moderate or heavy",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(BattleDamageVibrator.alert(this, severity))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "applySnapshot" -> {
                    val snapshot = call.arguments as? Map<*, *>
                    if (snapshot == null) {
                        result.error("invalid_argument", "notification snapshot required", null)
                    } else {
                        runCatching { AppNotificationManager.applySnapshot(this, snapshot) }
                            .onSuccess(result::success)
                            .onFailure {
                                result.error("apply_failed", it.message, it.javaClass.simpleName)
                            }
                    }
                }
                "getCapabilities" -> {
                    val notificationsGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) == PackageManager.PERMISSION_GRANTED
                    result.success(
                        mapOf(
                            "notificationsGranted" to notificationsGranted,
                            "exactAlarmsGranted" to AppNotificationManager.canScheduleExactAlarms(this),
                            "channelsEnabled" to AppNotificationManager.channelsEnabled(this),
                        ),
                    )
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val hasPermission = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) == PackageManager.PERMISSION_GRANTED
                        if (hasPermission) {
                            result.success(true)
                        } else if (pendingNotificationPermissionResult != null) {
                            result.error("request_in_progress", "notification permission request already active", null)
                        } else {
                            pendingNotificationPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                1001,
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    result.success(null)
                }
                "openSystemNotificationSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        },
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BACKGROUND_GAME_RETENTION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setRetaining" -> {
                    val retaining = call.argument<Boolean>("retaining")
                    if (retaining == null) {
                        result.error("invalid_argument", "retaining is required", null)
                    } else {
                        runCatching {
                            NotificationProgressService.setSessionRetention(this, retaining)
                        }.onSuccess {
                            result.success(null)
                        }.onFailure {
                            result.error(
                                "retention_failed",
                                it.message,
                                it.javaClass.simpleName,
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        diagnosticPlatformHandler = DiagnosticPlatformHandler(applicationContext, this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DIAGNOSTICS_CHANNEL,
        ).setMethodCallHandler(diagnosticPlatformHandler)

        val captureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_CAPTURE_CHANNEL,
        )
        gameCaptureBridge = GameCaptureBridge(this, captureChannel)
        captureChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(
                    gameCaptureBridge?.isSupported() == true,
                )
                "configure" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    val script = call.argument<String>("script")
                    if (enabled == null || script == null) {
                        result.error(
                            "invalid_argument",
                            "enabled and script are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    gameCaptureBridge?.configure(enabled, script, result)
                        ?: result.error(
                            "capture_unavailable",
                            "The capture bridge is not available.",
                            null,
                        )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCALE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindFixedCanvas" -> {
                    val contentWidth = call.argument<Int>("contentWidth") ?: 1200
                    val contentHeight = call.argument<Int>("contentHeight") ?: 720
                    setFixedCanvasScaling(contentWidth, contentHeight, result)
                }
                "releaseFixedCanvas" -> releaseFixedCanvasScaling(result)
                else -> result.notImplemented()
            }
        }

        val bypassManager = GadgetBypassManager(context, this)
        gadgetBypassManager = bypassManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GADGET_BYPASS_CHANNEL,
        ).setMethodCallHandler(bypassManager)

        val frameRateManager = GameFrameRateManager(
            GameFrameRateBridge(this),
            AndroidGameFrameRateSystemConstraints(this),
        )
        gameFrameRateManager = frameRateManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_FRAME_RATE_CHANNEL,
        ).setMethodCallHandler(frameRateManager)

        val frameReloadManager = GameFrameReloadManager(
            AndroidGameFrameReloadBridge(this),
        )
        gameFrameReloadManager = frameReloadManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_FRAME_RELOAD_CHANNEL,
        ).setMethodCallHandler(frameReloadManager)
    }

    override fun onDestroy() {
        disposeCompositionImageHandler()
        val nativeChannel = nativeGameWebViewChannel
        val nativeAttachment = nativeGameWebViewAttachment
        if (nativeChannel != null && nativeAttachment != null) {
            nativeChannel.detachActivity(nativeAttachment)
        }
        nativeGameWebViewAttachment = null
        nativeGameWebViewHost = null
        nativeWebViewStartup?.close()
        nativeWebViewStartup = null
        pendingGameSurfaceRecoveryActions.forEach(
            gameSurfaceRecoveryHandler::removeCallbacks,
        )
        pendingGameSurfaceRecoveryActions.clear()
        removeGadgetBypassLayoutListener()
        gameCaptureBridge?.dispose()
        gameCaptureBridge = null
        webViewProxyManager?.dispose()
        webViewProxyManager = null
        gadgetBypassManager = null
        gameResourceCacheManager?.dispose()
        gameResourceCacheManager = null
        gameResourceCacheEngine = null
        gameFrameRateManager?.dispose()
        gameFrameRateManager = null
        gameFrameReloadManager?.dispose()
        gameFrameReloadManager = null
        diagnosticPlatformHandler?.dispose()
        diagnosticPlatformHandler = null
        fixedCanvasLayoutListener?.let { listener ->
            boundWebView?.removeOnLayoutChangeListener(listener)
        }
        fixedCanvasLayoutListener = null
        boundWebView = null
        fixedCanvasScalePolicy.reset()
        pendingScreenshotResult?.error(
            "activity_destroyed",
            "The screenshot request was cancelled.",
            null,
        )
        pendingScreenshotResult = null
        activeScreenshotResult?.error(
            "activity_destroyed",
            "The screenshot request was cancelled.",
            null,
        )
        activeScreenshotResult = null
        activeScreenshotOutput = null
        super.onDestroy()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        disposeCompositionImageHandler()
        val nativeChannel = nativeGameWebViewChannel
        val nativeAttachment = nativeGameWebViewAttachment
        if (nativeChannel != null && nativeAttachment != null) {
            nativeChannel.detachActivity(nativeAttachment)
        }
        nativeGameWebViewAttachment = null
        nativeGameWebViewChannel = null
        if (shouldDestroyEngineWithHost()) {
            NativeGameWebViewEngineChannels.destroy(flutterEngine)
        }
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun disposeCompositionImageHandler() {
        compositionImageHandler?.dispose()
        compositionImageHandler = null
        compositionImageChannel?.setMethodCallHandler(null)
        compositionImageChannel = null
    }

    private fun enableNativeActivityWebViewIfSelected() {
        val preferences = getSharedPreferences(
            GameRenderingModeHcppPolicy.PREFERENCES_NAME,
            Context.MODE_PRIVATE,
        )
        val storedMode = try {
            preferences.getString(GameRenderingModeHcppPolicy.RENDERING_MODE_KEY, null)
        } catch (_: Exception) {
            null
        }
        val startup = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(
                SharedPreferencesNativeWebViewStartupStore(preferences),
                NativeWebViewProcessState.sessionId,
            ),
            nowMs = SystemClock::elapsedRealtime,
            scheduleTimeout = ::scheduleNativeWebViewStartupTimeout,
            cancelTimeout = ::cancelNativeWebViewStartupTimeout,
            requestRestart = ::requestActivityRestart,
        )
        nativeWebViewStartup = startup
        val nativeChannel = nativeGameWebViewChannel ?: return
        val nativeAttachment = nativeGameWebViewAttachment ?: return
        when (val outcome = startup.begin(storedMode)) {
            NativeWebViewActivityStartupOutcome.StartHost -> Unit
            is NativeWebViewActivityStartupOutcome.Unavailable -> {
                nativeChannel.attachUnavailable(nativeAttachment, outcome)
                return
            }
        }

        val contentRoot = findViewById<FrameLayout>(android.R.id.content)
        if (contentRoot == null) {
            startup.onCreateFailed()
            nativeChannel.attachUnavailable(
                nativeAttachment,
                nativeHostStartupFailure("The Activity content root is unavailable."),
            )
            return
        }
        val host = try {
            ActivityWebViewHost(
                this,
                contentRoot,
                nativeChannel.eventSinkFor(nativeAttachment),
                ::applyNativeGamePresentation,
            )
        } catch (error: Exception) {
            startup.onCreateFailed()
            nativeChannel.attachUnavailable(
                nativeAttachment,
                nativeHostStartupFailure(error.message ?: "Unable to construct the native WebView host."),
            )
            return
        }
        try {
            nativeChannel.attachHost(
                nativeAttachment,
                ActivityNativeGameWebViewHostOperations(
                    host,
                ),
            )
            nativeGameWebViewHost = host
        } catch (error: Exception) {
            startup.onCreateFailed()
            nativeChannel.attachUnavailable(
                nativeAttachment,
                nativeHostStartupFailure(error.message ?: "Unable to attach the native WebView host."),
            )
        }
    }

    private fun nativeHostStartupFailure(message: String) =
        NativeWebViewActivityStartupOutcome.Unavailable(
            "native_webview_startup_failed",
            message,
        )

    private fun scheduleNativeWebViewStartupTimeout(delayMs: Long, callback: () -> Unit) {
        cancelNativeWebViewStartupTimeout()
        val timeout = Runnable(callback)
        nativeWebViewStartupTimeout = timeout
        nativeWebViewHandler.postDelayed(timeout, delayMs)
    }

    private fun cancelNativeWebViewStartupTimeout() {
        nativeWebViewStartupTimeout?.let(nativeWebViewHandler::removeCallbacks)
        nativeWebViewStartupTimeout = null
    }

    private fun requestActivityRestart() {
        if (activityRestartRequested || isFinishing || isDestroyed) return
        activityRestartRequested = true
        nativeWebViewHandler.post {
            if (!isFinishing && !isDestroyed) recreate()
        }
    }

    override fun openDiagnosticExportDirectory(initialUri: Uri?) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && initialUri != null) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri)
            }
        }
        diagnosticDirectoryPickerUi.open {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, DIAGNOSTIC_DIRECTORY_REQUEST)
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DIAGNOSTIC_DIRECTORY_REQUEST) return
        diagnosticDirectoryPickerUi.finish()
        diagnosticPlatformHandler?.onDirectorySelected(
            data?.data?.takeIf { resultCode == Activity.RESULT_OK },
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            pendingNotificationPermissionResult?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
            )
            pendingNotificationPermissionResult = null
            return
        }
        if (requestCode != SCREENSHOT_PERMISSION_REQUEST) return

        val granted = permissions.indices.any { index ->
            permissions[index] == Manifest.permission.WRITE_EXTERNAL_STORAGE &&
                grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
        }
        compositionImageHandler?.onStoragePermissionResult(granted)
        val result = pendingScreenshotResult ?: return
        pendingScreenshotResult = null
        if (granted) {
            captureGameWebView(result)
        } else {
            result.error(
                "storage_permission_denied",
                "Storage permission is required to save screenshots to the gallery.",
                null,
            )
        }
    }

    override fun onBypassEnabledChanged(enabled: Boolean) {
        if (enabled) {
            installGadgetBypassLayoutListener()
            ensureGadgetBypassWrap()
        } else if (gameResourceCacheMode == GameResourceCacheMode.NONE) {
            restoreGadgetBypassClient()
            removeGadgetBypassLayoutListener()
        }
    }

    private fun ensureGadgetBypassWrap() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = gadgetBypassManager ?: return
        if (!manager.enabled && gameResourceCacheMode == GameResourceCacheMode.NONE) return

        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        if (webViews.size != 1) return
        val webView = webViews.single()

        val current = webView.webViewClient ?: return
        if (current is GadgetBypassWebViewClient) return

        Log.d("GadgetBypass", "wrapping WebViewClient")
        webView.setWebViewClient(
            GadgetBypassWebViewClient(
                original = current,
                engine = manager.engine,
                isEnabled = { manager.enabled },
                endpoint = { manager.endpoint },
                gameResourceEngine = gameResourceCacheEngine,
            ),
        )
    }

    private fun onGameResourceCacheModeChanged(mode: GameResourceCacheMode) {
        gameResourceCacheMode = mode
        if (mode != GameResourceCacheMode.NONE) {
            installGadgetBypassLayoutListener()
            ensureGadgetBypassWrap()
        } else if (gadgetBypassManager?.enabled != true) {
            restoreGadgetBypassClient()
            removeGadgetBypassLayoutListener()
        }
    }

    private fun restoreGadgetBypassClient() {
        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        for (webView in webViews) {
            val current = webView.webViewClient
            if (current is GadgetBypassWebViewClient) {
                Log.d("GadgetBypass", "restoring original WebViewClient")
                webView.setWebViewClient(current.originalClient)
            }
        }
    }

    private fun installGadgetBypassLayoutListener() {
        if (gadgetBypassLayoutListener != null) return
        val listener = ViewTreeObserver.OnGlobalLayoutListener {
            ensureGadgetBypassWrap()
        }
        window.decorView.viewTreeObserver.addOnGlobalLayoutListener(listener)
        gadgetBypassLayoutListener = listener
    }

    private fun removeGadgetBypassLayoutListener() {
        gadgetBypassLayoutListener?.let { listener ->
            window.decorView.viewTreeObserver.removeOnGlobalLayoutListener(listener)
        }
        gadgetBypassLayoutListener = null
    }

    private fun setGameWebViewMuted(
        muted: Boolean,
        result: MethodChannel.Result,
    ) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.MUTE_AUDIO)) {
            result.error(
                "mute_audio_unsupported",
                "This Android WebView does not support per-WebView audio muting.",
                null,
            )
            return
        }

        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        when (webViews.size) {
            0 -> result.error(
                "webview_not_found",
                "The game WebView is not attached yet.",
                null,
            )
            1 -> {
                try {
                    WebViewCompat.setAudioMuted(webViews.single(), muted)
                    result.success(null)
                } catch (error: RuntimeException) {
                    result.error(
                        "mute_audio_failed",
                        error.message ?: "Unable to change WebView audio state.",
                        null,
                    )
                }
            }
            else -> result.error(
                "multiple_webviews",
                "Expected one game WebView but found ${webViews.size}.",
                null,
            )
        }
    }

    private fun captureGameWebView(
        result: MethodChannel.Result,
        output: ScreenshotOutput = ScreenshotOutput.GALLERY,
    ) {
        if (
            output.requiresStoragePermission &&
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingScreenshotResult != null) {
                result.error("screenshot_busy", "A screenshot is already pending.", null)
                return
            }
            pendingScreenshotResult = result
            if (compositionImageHandler?.isAwaitingStoragePermission != true) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    SCREENSHOT_PERMISSION_REQUEST,
                )
            }
            return
        }

        if (activeScreenshotResult != null) {
            result.error("screenshot_busy", "A screenshot is already in progress.", null)
            return
        }

        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        val candidates = webViews.mapIndexed { index, webView ->
            val location = IntArray(2)
            webView.getLocationInWindow(location)
            ScreenshotViewCandidate(
                index = index,
                visible = webView.visibility == View.VISIBLE && webView.isShown,
                attached = webView.isAttachedToWindow,
                width = webView.width,
                height = webView.height,
                windowX = location[0],
                windowY = location[1],
            )
        }
        val selected = ScreenshotCapturePolicy.select(candidates)
        if (selected == null) {
            result.error(
                "webview_not_found",
                "No visible game WebView with a valid size was found.",
                null,
            )
            return
        }
        val webView = webViews[selected.index]
        activeScreenshotResult = result
        activeScreenshotOutput = output

        try {
            captureScreenshotAttempt(
                webView = webView,
                selected = selected,
                attempts = ScreenshotCapturePolicy.captureAttempts(
                    supportsPixelCopy = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O,
                ),
                attemptIndex = 0,
                result = result,
            )
        } catch (error: Exception) {
            completeScreenshotError(
                result,
                "screenshot_failed",
                error.message ?: "Unable to capture the game WebView.",
            )
        }
    }

    private fun captureScreenshotAttempt(
        webView: WebView,
        selected: ScreenshotViewCandidate,
        attempts: List<ScreenshotCaptureAttempt>,
        attemptIndex: Int,
        result: MethodChannel.Result,
    ) {
        if (activeScreenshotResult !== result) return
        if (attemptIndex >= attempts.size) {
            completeScreenshotError(
                result,
                "blank_screenshot",
                "All WebView capture methods returned a blank or single-color image.",
            )
            return
        }

        when (attempts[attemptIndex]) {
            ScreenshotCaptureAttempt.PIXEL_COPY_RECT -> captureRectWithPixelCopy(
                webView,
                selected,
                attempts,
                attemptIndex,
                result,
            )
            ScreenshotCaptureAttempt.PIXEL_COPY_WINDOW -> captureWindowWithPixelCopy(
                webView,
                selected,
                attempts,
                attemptIndex,
                result,
            )
            ScreenshotCaptureAttempt.WEB_VIEW_DRAW -> captureWithWebViewDraw(
                webView,
                selected,
                attempts,
                attemptIndex,
                result,
            )
        }
    }

    private fun captureRectWithPixelCopy(
        webView: WebView,
        selected: ScreenshotViewCandidate,
        attempts: List<ScreenshotCaptureAttempt>,
        attemptIndex: Int,
        result: MethodChannel.Result,
    ) {
        val bitmap = Bitmap.createBitmap(
            selected.width,
            selected.height,
            Bitmap.Config.ARGB_8888,
        )
        val source = ScreenshotCapturePolicy.captureRect(selected)
        val sourceRect = Rect(source.left, source.top, source.right, source.bottom)
        requestPixelCopy(bitmap, sourceRect) { succeeded ->
            handleScreenshotAttempt(
                bitmap,
                succeeded,
                webView,
                selected,
                attempts,
                attemptIndex,
                result,
            )
        }
    }

    private fun captureWindowWithPixelCopy(
        webView: WebView,
        selected: ScreenshotViewCandidate,
        attempts: List<ScreenshotCaptureAttempt>,
        attemptIndex: Int,
        result: MethodChannel.Result,
    ) {
        val decorView = window.decorView
        if (decorView.width <= 0 || decorView.height <= 0) {
            scheduleNextScreenshotAttempt(
                webView, selected, attempts, attemptIndex, result,
            )
            return
        }
        val windowBitmap = Bitmap.createBitmap(
            decorView.width,
            decorView.height,
            Bitmap.Config.ARGB_8888,
        )
        requestPixelCopy(windowBitmap, null) { succeeded ->
            if (!succeeded || activeScreenshotResult !== result) {
                windowBitmap.recycle()
                if (activeScreenshotResult === result) {
                    scheduleNextScreenshotAttempt(
                        webView, selected, attempts, attemptIndex, result,
                    )
                }
                return@requestPixelCopy
            }
            val cropped = Bitmap.createBitmap(
                selected.width,
                selected.height,
                Bitmap.Config.ARGB_8888,
            )
            Canvas(cropped).drawBitmap(
                windowBitmap,
                -selected.windowX.toFloat(),
                -selected.windowY.toFloat(),
                null,
            )
            windowBitmap.recycle()
            handleScreenshotAttempt(
                cropped,
                true,
                webView,
                selected,
                attempts,
                attemptIndex,
                result,
            )
        }
    }

    private fun requestPixelCopy(
        bitmap: Bitmap,
        sourceRect: Rect?,
        onComplete: (Boolean) -> Unit,
    ) {
        try {
            val listener = PixelCopy.OnPixelCopyFinishedListener { copyResult ->
                onComplete(copyResult == PixelCopy.SUCCESS)
            }
            if (sourceRect == null) {
                PixelCopy.request(window, bitmap, listener, Handler(Looper.getMainLooper()))
            } else {
                PixelCopy.request(
                    window,
                    sourceRect,
                    bitmap,
                    listener,
                    Handler(Looper.getMainLooper()),
                )
            }
        } catch (_: Exception) {
            onComplete(false)
        }
    }

    private fun captureWithWebViewDraw(
        webView: WebView,
        selected: ScreenshotViewCandidate,
        attempts: List<ScreenshotCaptureAttempt>,
        attemptIndex: Int,
        result: MethodChannel.Result,
    ) {
        webView.postOnAnimation {
            if (activeScreenshotResult !== result) return@postOnAnimation
            val bitmap = Bitmap.createBitmap(
                selected.width,
                selected.height,
                Bitmap.Config.ARGB_8888,
            )
            try {
                webView.draw(Canvas(bitmap))
                handleScreenshotAttempt(
                    bitmap,
                    true,
                    webView,
                    selected,
                    attempts,
                    attemptIndex,
                    result,
                )
            } catch (_: Exception) {
                bitmap.recycle()
                scheduleNextScreenshotAttempt(
                    webView, selected, attempts, attemptIndex, result,
                )
            }
        }
    }

    private fun handleScreenshotAttempt(
        bitmap: Bitmap,
        succeeded: Boolean,
        webView: WebView,
        selected: ScreenshotViewCandidate,
        attempts: List<ScreenshotCaptureAttempt>,
        attemptIndex: Int,
        result: MethodChannel.Result,
    ) {
        if (activeScreenshotResult !== result) {
            bitmap.recycle()
            return
        }
        if (succeeded && hasVisualContent(bitmap)) {
            finishScreenshot(bitmap, result)
            return
        }
        bitmap.recycle()
        scheduleNextScreenshotAttempt(webView, selected, attempts, attemptIndex, result)
    }

    private fun scheduleNextScreenshotAttempt(
        webView: WebView,
        selected: ScreenshotViewCandidate,
        attempts: List<ScreenshotCaptureAttempt>,
        attemptIndex: Int,
        result: MethodChannel.Result,
    ) {
        webView.postOnAnimation {
            captureScreenshotAttempt(
                webView,
                selected,
                attempts,
                attemptIndex + 1,
                result,
            )
        }
    }

    private fun finishScreenshot(bitmap: Bitmap, result: MethodChannel.Result) {
        if (activeScreenshotResult !== result) {
            bitmap.recycle()
            return
        }
        try {
            if (activeScreenshotOutput == ScreenshotOutput.MEMORY_PREVIEW) {
                val bytes = ByteArrayOutputStream().use { stream ->
                    check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                        "Unable to encode the game preview."
                    }
                    stream.toByteArray()
                }
                activeScreenshotResult = null
                activeScreenshotOutput = null
                result.success(bytes)
                return
            }
            val timestamp = SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.US)
                .format(Date())
            val destination = ScreenshotDestination.create(timestamp)
            saveScreenshotToGallery(bitmap, destination)
            activeScreenshotResult = null
            activeScreenshotOutput = null
            result.success(destination.displayLocation)
        } catch (error: Exception) {
            completeScreenshotError(
                result,
                "screenshot_failed",
                error.message ?: "Unable to save the game screenshot.",
            )
        } finally {
            bitmap.recycle()
        }
    }

    private fun completeScreenshotError(
        result: MethodChannel.Result,
        code: String,
        message: String,
    ) {
        if (activeScreenshotResult !== result) return
        activeScreenshotResult = null
        activeScreenshotOutput = null
        result.error(code, message, null)
    }

    private fun saveScreenshotToGallery(
        bitmap: Bitmap,
        destination: ScreenshotDestination,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveScreenshotWithMediaStore(bitmap, destination)
            return
        }

        @Suppress("DEPRECATION")
        val picturesRoot = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_PICTURES,
        )
        val outputDirectory = File(picturesRoot, "Yahagi")
        if (!outputDirectory.exists() && !outputDirectory.mkdirs()) {
            throw IllegalStateException("Unable to create the gallery directory.")
        }
        val output = File(outputDirectory, destination.fileName)
        FileOutputStream(output).use { stream ->
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                throw IllegalStateException("Unable to encode screenshot.")
            }
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(output.absolutePath),
            arrayOf("image/png"),
            null,
        )
    }

    private fun saveScreenshotWithMediaStore(
        bitmap: Bitmap,
        destination: ScreenshotDestination,
    ) {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, destination.fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, destination.relativeDirectory)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Images.Media.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
        val uri = contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create a gallery entry.")

        try {
            contentResolver.openOutputStream(uri, "w").use { stream ->
                if (
                    stream == null ||
                    !bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                ) {
                    throw IllegalStateException("Unable to encode screenshot.")
                }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun hasVisualContent(bitmap: Bitmap): Boolean {
        val stepX = (bitmap.width / 20).coerceAtLeast(1)
        val stepY = (bitmap.height / 20).coerceAtLeast(1)
        var firstColor: Int? = null
        var hasOpaquePixel = false
        var y = 0
        while (y < bitmap.height) {
            var x = 0
            while (x < bitmap.width) {
                val color = bitmap.getPixel(x, y)
                hasOpaquePixel = hasOpaquePixel || color ushr 24 != 0
                if (firstColor == null) {
                    firstColor = color
                } else if (color != firstColor && hasOpaquePixel) {
                    return true
                }
                x += stepX
            }
            y += stepY
        }
        return false
    }

    private fun setFixedCanvasScaling(
        contentWidth: Int,
        contentHeight: Int,
        result: MethodChannel.Result,
    ) {
        val webViews = mutableListOf<WebView>()
        collectWebViews(window.decorView, webViews)
        when (webViews.size) {
            0 -> result.error(
                "webview_not_found",
                "The game WebView is not attached yet.",
                null,
            )
            1 -> {
                try {
                    val webView = webViews.single()
                    fixedCanvasContentWidth = contentWidth
                    fixedCanvasContentHeight = contentHeight

                    if (boundWebView !== webView) {
                        fixedCanvasLayoutListener?.let { listener ->
                            boundWebView?.removeOnLayoutChangeListener(listener)
                        }
                        fixedCanvasScalePolicy.reset()
                        boundWebView = webView

                        val listener = View.OnLayoutChangeListener {
                                _, left, top, right, bottom, _, _, _, _ ->
                            applyFixedCanvasScale(
                                webView,
                                right - left,
                                bottom - top,
                            )
                        }
                        fixedCanvasLayoutListener = listener
                        webView.addOnLayoutChangeListener(listener)
                    }

                    webView.settings.useWideViewPort = true
                    webView.settings.loadWithOverviewMode = false
                    webView.settings.builtInZoomControls = true
                    webView.settings.displayZoomControls = false

                    // A new document resets WebView's effective initial scale even
                    // when the outer view keeps the same dimensions. Reapply after
                    // the current UI/layout work and only then complete the channel.
                    webView.post {
                        try {
                            applyFixedCanvasScale(
                                webView,
                                webView.width,
                                webView.height,
                                force = true,
                            )
                            result.success(null)
                        } catch (error: RuntimeException) {
                            result.error(
                                "scaling_failed",
                                error.message ?: "Unable to set WebView scaling.",
                                null,
                            )
                        }
                    }
                } catch (error: RuntimeException) {
                    result.error(
                        "scaling_failed",
                        error.message ?: "Unable to set WebView scaling.",
                        null,
                    )
                }
            }
            else -> result.error(
                "multiple_webviews",
                "Expected one game WebView but found ${webViews.size}.",
                null,
            )
        }
    }

    private fun applyFixedCanvasScale(
        webView: WebView,
        viewportWidth: Int,
        viewportHeight: Int,
        force: Boolean = false,
    ) {
        val scalePercent = fixedCanvasScalePolicy.nextScalePercent(
            viewportWidth,
            viewportHeight,
            fixedCanvasContentWidth,
            fixedCanvasContentHeight,
            force,
            imeVisible = ViewCompat.getRootWindowInsets(webView)
                ?.isVisible(WindowInsetsCompat.Type.ime()) == true,
        ) ?: return
        webView.setInitialScale(scalePercent)
    }

    private val nativePresentationMethodResult = object : MethodChannel.Result {
        override fun success(result: Any?) = Unit

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            Log.d("NativeGamePresentation", "$errorCode: $errorMessage")
        }

        override fun notImplemented() {
            Log.d("NativeGamePresentation", "notImplemented")
        }
    }

    private fun applyNativeGamePresentation(hasGameSurface: Boolean) {
        if (isFinishing || isDestroyed) return
        if (Looper.myLooper() != Looper.getMainLooper()) {
            nativeWebViewHandler.post { applyNativeGamePresentation(hasGameSurface) }
            return
        }
        if (hasGameSurface) {
            setFixedCanvasScaling(
                fixedCanvasContentWidth,
                fixedCanvasContentHeight,
                nativePresentationMethodResult,
            )
        } else {
            releaseFixedCanvasScaling(nativePresentationMethodResult)
        }
    }

    private fun releaseFixedCanvasScaling(result: MethodChannel.Result) {
        try {
            val webView = boundWebView
            fixedCanvasLayoutListener?.let { listener ->
                webView?.removeOnLayoutChangeListener(listener)
            }
            fixedCanvasLayoutListener = null
            boundWebView = null
            fixedCanvasScalePolicy.reset()

            if (webView != null) {
                webView.settings.useWideViewPort = false
                webView.settings.loadWithOverviewMode = false
            }
            result.success(null)
        } catch (error: RuntimeException) {
            result.error(
                "scaling_release_failed",
                error.message ?: "Unable to release WebView scaling.",
                null,
            )
        }
    }

    private fun scheduleGameSurfaceRecovery(reason: GameSurfaceRecoveryReason) {
        if (isFinishing || isDestroyed) return

        Log.d("GameSurfaceRecovery", "Scheduling recovery for $reason")
        pendingGameSurfaceRecoveryActions.forEach(
            gameSurfaceRecoveryHandler::removeCallbacks,
        )
        pendingGameSurfaceRecoveryActions.clear()

        for (delayMillis in longArrayOf(50L, 150L, 400L)) {
            lateinit var action: Runnable
            action = Runnable {
                pendingGameSurfaceRecoveryActions.remove(action)
                if (!isFinishing && !isDestroyed) {
                    recoverGameSurfaces()
                }
            }
            pendingGameSurfaceRecoveryActions.add(action)
            gameSurfaceRecoveryHandler.postDelayed(action, delayMillis)
        }
    }

    private fun recoverGameSurfaces() {
        val decorView = window.decorView
        decorView.requestApplyInsets()

        val webViews = mutableListOf<WebView>()
        collectWebViews(decorView, webViews)
        val webView = boundWebView?.takeIf {
            it.isAttachedToWindow && it.width > 0 && it.height > 0
        } ?: webViews.singleOrNull()?.takeIf {
            it.isAttachedToWindow && it.width > 0 && it.height > 0
        }
            ?: return

        webView.requestLayout()
        webView.invalidate()
        webView.postInvalidateOnAnimation()
        applyFixedCanvasScale(
            webView,
            webView.width,
            webView.height,
            force = true,
        )
        webView.evaluateJavascript(
            """
            (() => {
              window.dispatchEvent(new Event('resize'));
              const gameFrame = document.getElementById('game_frame');
              try {
                gameFrame?.contentWindow?.dispatchEvent(new Event('resize'));
              } catch (_) {}
            })();
            """.trimIndent(),
            null,
        )
    }

    private fun collectWebViews(
        view: View,
        results: MutableList<WebView>,
    ) {
        if (view is WebView) {
            results.add(view)
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                collectWebViews(view.getChildAt(index), results)
            }
        }
    }
}
