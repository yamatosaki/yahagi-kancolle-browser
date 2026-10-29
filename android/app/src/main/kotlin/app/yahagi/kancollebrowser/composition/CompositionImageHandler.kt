package app.yahagi.kancollebrowser.composition

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Owns only composition image writes; it never reads or controls the game. */
class CompositionImageHandler(
    context: Context,
    private val hasStoragePermission: () -> Boolean,
    private val requestStoragePermission: () -> Unit,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "app.yahagi.kancollebrowser/composition_image"
    }

    private val context = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var active: SaveRequest? = null
    private var disposed = false

    val isAwaitingStoragePermission: Boolean
        get() = active?.awaitingPermission == true

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "savePng") {
            result.notImplemented()
            return
        }
        if (disposed) {
            result.error("activity_destroyed", "The image save request was cancelled.", null)
            return
        }
        if (active != null) {
            result.error("composition_save_busy", "A composition image is already being saved.", null)
            return
        }
        val bytes = (call.arguments as? Map<*, *>)?.get("bytes") as? ByteArray
        if (bytes == null || bytes.isEmpty() || bytes.size > CompositionImagePolicy.MAX_BYTES) {
            result.error("invalid_composition_image", "A PNG of at most 16 MiB is required.", null)
            return
        }
        val request = SaveRequest(bytes, result)
        active = request
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P && !hasStoragePermission()) {
            request.awaitingPermission = true
            try {
                requestStoragePermission()
            } catch (error: Exception) {
                completeError(request, "storage_permission_denied", error.message)
            }
        } else {
            save(request)
        }
    }

    fun onStoragePermissionResult(granted: Boolean) {
        val request = active?.takeIf { it.awaitingPermission } ?: return
        request.awaitingPermission = false
        if (granted) {
            save(request)
        } else {
            completeError(
                request,
                "storage_permission_denied",
                "Storage permission is required to save composition images to the gallery.",
            )
        }
    }

    fun dispose() {
        if (disposed) return
        disposed = true
        val request = active
        active = null
        request?.cancelled?.set(true)
        request?.result?.error("activity_destroyed", "The image save request was cancelled.", null)
        // A running writer finishes its rollback before its executor is closed.
        if (request?.workerStarted != true) executor.shutdown()
    }

    private fun save(request: SaveRequest) {
        request.workerStarted = true
        executor.execute {
            var saved: SavedImage? = null
            var errorCode = "composition_save_failed"
            var errorMessage: String? = null
            try {
                request.checkActive()
                CompositionImagePolicy.validate(request.bytes)
                validateDecoding(request.bytes)
                request.checkActive()
                val timestamp = SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.US).format(Date())
                val destination = CompositionImageDestination.create(timestamp)
                saved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveWithMediaStore(request, destination)
                } else {
                    saveLegacy(request, destination)
                }
            } catch (error: IllegalArgumentException) {
                errorCode = "invalid_composition_image"
                errorMessage = error.message
            } catch (_: OutOfMemoryError) {
                errorCode = "invalid_composition_image"
                errorMessage = "There is not enough memory to decode the composition image."
            } catch (error: Exception) {
                errorMessage = error.message
            }
            val completedImage = saved
            mainHandler.post {
                if (disposed || active !== request) {
                    if (completedImage != null) executor.execute { completedImage.discard() }
                } else if (completedImage != null) {
                    active = null
                    request.result.success(completedImage.location)
                } else {
                    completeError(request, errorCode, errorMessage)
                }
                if (disposed) executor.shutdown()
            }
        }
    }

    private fun completeError(request: SaveRequest, code: String, message: String?) {
        if (active !== request) return
        active = null
        request.result.error(code, message ?: "Unable to save the composition image.", null)
    }

    private fun validateDecoding(bytes: ByteArray) {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        require(bounds.outMimeType == "image/png" && bounds.outWidth > 0 &&
            bounds.outHeight > 0 &&
            bounds.outWidth.toLong() * bounds.outHeight <= CompositionImagePolicy.MAX_PIXELS) {
            "The PNG dimensions are invalid or exceed 16 million pixels."
        }
        val options = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        requireNotNull(bitmap) { "The PNG could not be decoded." }
        bitmap.recycle()
    }

    @androidx.annotation.RequiresApi(29)
    private fun saveWithMediaStore(
        request: SaveRequest,
        destination: CompositionImageDestination,
    ): SavedImage {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, destination.fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, destination.relativeDirectory)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create a gallery entry.")
        val saved = SavedImage(destination.displayLocation) {
            resolver.delete(uri, null, null)
        }
        try {
            resolver.openOutputStream(uri, "w").use { stream ->
                checkNotNull(stream) { "Unable to open the gallery image." }
                request.checkActive()
                stream.write(request.bytes)
            }
            request.checkActive()
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            check(resolver.update(uri, values, null, null) > 0) {
                "Unable to publish the gallery image."
            }
            return saved
        } catch (error: Throwable) {
            saved.discard()
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(
        request: SaveRequest,
        destination: CompositionImageDestination,
    ): SavedImage {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "Yahagi/Compositions",
        )
        check(directory.isDirectory || directory.mkdirs()) { "Unable to create the gallery directory." }
        val output = File(directory, destination.fileName)
        check(output.createNewFile()) { "An image with this name already exists. Please try again." }
        val saved = SavedImage(destination.displayLocation) { output.delete() }
        try {
            FileOutputStream(output).use { stream ->
                request.checkActive()
                stream.write(request.bytes)
            }
            request.checkActive()
            MediaScannerConnection.scanFile(
                context,
                arrayOf(output.absolutePath),
                arrayOf("image/png"),
                null,
            )
            return saved
        } catch (error: Throwable) {
            saved.discard()
            throw error
        }
    }

    private class SaveRequest(val bytes: ByteArray, val result: MethodChannel.Result) {
        val cancelled = AtomicBoolean(false)
        var awaitingPermission = false
        var workerStarted = false

        fun checkActive() = check(!cancelled.get()) { "The image save request was cancelled." }
    }

    private class SavedImage(val location: String, private val rollback: () -> Unit) {
        fun discard() {
            // Preserve the original failure if the media provider is unavailable during cleanup.
            runCatching(rollback)
        }
    }
}
