package app.yahagi.kancollebrowser.browser

import java.io.File
import java.security.MessageDigest

/**
 * Simple on-disk cache for bypassed gadget files.
 *
 * Entries expire after [maxAgeMs] and the whole cache is trimmed to [maxBytes].
 * Failures are swallowed on purpose: a broken cache must never break the bypass path.
 */
class GadgetBypassCache(
    private val cacheDir: File,
    private val maxBytes: Long = 200L * 1024 * 1024,
    private val maxAgeMs: Long = 24L * 60 * 60 * 1000,
    private val now: () -> Long = System::currentTimeMillis,
) {
    init {
        cacheDir.mkdirs()
    }

    fun get(url: String): ByteArray? {
        val file = fileFor(url)
        if (!file.isFile) return null
        if (now() - file.lastModified() > maxAgeMs) {
            file.delete()
            return null
        }
        return file.readBytes()
    }

    fun put(url: String, bytes: ByteArray) {
        try {
            val file = fileFor(url)
            file.parentFile?.mkdirs()
            file.writeBytes(bytes)
            file.setLastModified(now())
            evictIfNeeded()
        } catch (e: Exception) {
            // Never let cache write failures propagate.
        }
    }

    fun clear() {
        cacheDir.listFiles()?.forEach { it.delete() }
    }

    fun sizeBytes(): Long = cacheDir.listFiles()?.sumOf { it.length() } ?: 0L

    private fun evictIfNeeded() {
        while (sizeBytes() > maxBytes) {
            val oldest = cacheDir.listFiles()
                ?.filter { it.isFile }
                ?.minByOrNull { it.lastModified() }
                ?: return
            if (!oldest.delete()) return
        }
    }

    private fun fileFor(url: String): File {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(url.toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(cacheDir, "$digest.cache")
    }
}
