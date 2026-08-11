package app.yahagi.kancollebrowser

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.media.MediaScannerConnection
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.PixelCopy
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.webkit.WebView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import app.yahagi.kancollebrowser.browser.WebViewProxyManager
import app.yahagi.kancollebrowser.browser.GadgetBypassManager
import app.yahagi.kancollebrowser.browser.GadgetBypassWebViewClient
import app.yahagi.kancollebrowser.browser.FixedCanvasScalePolicy
import app.yahagi.kancollebrowser.browser.GameFrameRateManager
import app.yahagi.kancollebrowser.capture.GameCaptureBridge
import app.yahagi.kancollebrowser.capture.ScreenshotCaptureAttempt
import app.yahagi.kancollebrowser.capture.ScreenshotCapturePolicy
import app.yahagi.kancollebrowser.capture.ScreenshotDestination
import app.yahagi.kancollebrowser.capture.ScreenshotViewCandidate
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity(), GadgetBypassManager.Host, GameFrameRateManager.Host {
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
        const val BATTLE_DAMAGE_ALERT_CHANNEL = "app.yahagi.kancollebrowser/battle_damage_alert"
        const val SCREENSHOT_PERMISSION_REQUEST = 2406
    }

    private var gameCaptureBridge: GameCaptureBridge? = null
    private var webViewProxyManager: WebViewProxyManager? = null
    private var gadgetBypassManager: GadgetBypassManager? = null
    private var gameFrameRateManager: GameFrameRateManager? = null
    private var gadgetBypassLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    
    private var boundWebView: WebView? = null
    private var fixedCanvasLayoutListener: View.OnLayoutChangeListener? = null
    private val fixedCanvasScalePolicy = FixedCanvasScalePolicy()
    private var fixedCanvasContentWidth: Int = 1200
    private var fixedCanvasContentHeight: Int = 720
    private var pendingScreenshotResult: MethodChannel.Result? = null
    private var activeScreenshotResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        webViewProxyManager = WebViewProxyManager(context)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROXY_CHANNEL,
        ).setMethodCallHandler(webViewProxyManager)

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
                "captureWebView" -> captureGameWebView(result)
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
                    if (severity != "moderate" && severity != "heavy") {
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
                else -> result.notImplemented()
            }
        }

        val bypassManager = GadgetBypassManager(context, this)
        gadgetBypassManager = bypassManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GADGET_BYPASS_CHANNEL,
        ).setMethodCallHandler(bypassManager)

        val frameRateManager = GameFrameRateManager(this)
        gameFrameRateManager = frameRateManager
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GAME_FRAME_RATE_CHANNEL,
        ).setMethodCallHandler(frameRateManager)
    }

    override fun onDestroy() {
        removeGadgetBypassLayoutListener()
        gameCaptureBridge?.dispose()
        gameCaptureBridge = null
        webViewProxyManager?.dispose()
        webViewProxyManager = null
        gadgetBypassManager = null
        gameFrameRateManager?.dispose()
        gameFrameRateManager = null
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
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SCREENSHOT_PERMISSION_REQUEST) return

        val result = pendingScreenshotResult ?: return
        pendingScreenshotResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
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
        } else if (gameFrameRateManager?.enabled != true) {
            restoreGadgetBypassClient()
            removeGadgetBypassLayoutListener()
        }
    }

    override fun onFrameRateUnlockChanged(enabled: Boolean) {
        if (enabled) {
            installGadgetBypassLayoutListener()
            ensureGadgetBypassWrap()
        } else if (gadgetBypassManager?.enabled != true) {
            restoreGadgetBypassClient()
            removeGadgetBypassLayoutListener()
        }
    }

    private fun ensureGadgetBypassWrap() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = gadgetBypassManager ?: return
        val frameRateManager = gameFrameRateManager
        if (!manager.enabled && frameRateManager?.enabled != true) return

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
                isFrameRateUnlockEnabled = { frameRateManager?.enabled == true },
            ),
        )
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

    private fun captureGameWebView(result: MethodChannel.Result) {
        if (
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
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                SCREENSHOT_PERMISSION_REQUEST,
            )
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
            val timestamp = SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.US)
                .format(Date())
            val destination = ScreenshotDestination.create(timestamp)
            saveScreenshotToGallery(bitmap, destination)
            activeScreenshotResult = null
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
        ) ?: return
        webView.setInitialScale(scalePercent)
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
