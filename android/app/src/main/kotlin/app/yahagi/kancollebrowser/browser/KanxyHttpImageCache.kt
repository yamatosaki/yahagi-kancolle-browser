package app.yahagi.kancollebrowser.browser

import java.net.Proxy
import java.net.URI
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit

internal enum class KanxyImageCacheEvent {
    HIT, MISS, EXPIRED, STORED,
    DISK_HIT, DISK_MISS, DISK_STORED, DISK_WRITE_FAILED,
    NO_ACTIVE_SESSION, REQUEST_BYPASS, LOCK_TIMEOUT, SESSION_CHANGED, WEBVIEW_FALLBACK,
    IMAGE_SIZE_LIMIT, RESPONSE_HEADERS, RESPONSE_NOT_FRESH, BUFFER_READ_FAILED,
}

/** A foreground game session on one verified HTTP proxy. Replacing it forgets all images. */
internal class KanxyHttpImageCache(
    val proxy: Proxy,
    private val elapsedMs: () -> Long = { TimeUnit.NANOSECONDS.toMillis(System.nanoTime()) },
) {
    private data class Entry(val image: GameResourceFetchResult, val expiresAt: Long)
    internal data class PreparedAsset(
        val response: GameResourceFetchResult,
        val mimeType: String,
        val expiresAtWallMs: Long?,
        val expiresAtElapsedMs: Long?,
    )

    private val entries = LinkedHashMap<GameResourceCacheKey, Entry>(16, 0.75f, true)
    private var totalBytes = 0L

    fun requestTime(): Long = elapsedMs()

    @Synchronized
    fun read(key: GameResourceCacheKey, report: ((KanxyImageCacheEvent) -> Unit)?): GameResourceFetchResult? {
        val entry = entries[key] ?: return null.also { report?.invoke(KanxyImageCacheEvent.MISS) }
        if (entry.expiresAt > elapsedMs()) return entry.image
        remove(key)
        report?.invoke(KanxyImageCacheEvent.EXPIRED)
        return null
    }

    @Synchronized
    fun remove(key: GameResourceCacheKey) {
        entries.remove(key)?.let { totalBytes -= it.image.bodyLength }
    }

    fun prepare(
        image: GameResourceFetchResult,
        url: String,
        requestAt: Long,
        receivedWallMs: Long,
        diskAssetLimit: Long?,
        report: ((KanxyImageCacheEvent) -> Unit)?,
    ): PreparedAsset? {
        val receivedAt = elapsedMs()
        val length = image.bodyLength
        if (length !in 1..(diskAssetLimit ?: MAX_IMAGE_BYTES)) {
            report?.invoke(KanxyImageCacheEvent.IMAGE_SIZE_LIMIT)
            return null
        }
        val contentType = image.headers.header("Content-Type")
        val mime = contentType?.substringBefore(';')?.trim()
        val contentLength = image.headers.header("Content-Length")
        val expectedMime = GameResourceCacheRules.mimeTypeFor(url).mime
        val vary = image.headers.header("Vary")
        val coding = image.headers.header("Content-Encoding")
        val diskSnapshot = diskAssetLimit != null
        if (!expectedMime.equals(mime, ignoreCase = true) ||
            contentType?.contains(',') == true ||
            (contentLength != null && contentLength.deltaSeconds() != length) ||
            image.headers.header("Content-Range") != null ||
            (vary != null && (!diskSnapshot || !vary.trim().equals("Accept-Encoding", true))) ||
            // HttpURLConnection removes these wire headers when it transparently decodes gzip.
            (diskSnapshot && coding != null && !coding.trim().equals("identity", true))
        ) {
            report?.invoke(KanxyImageCacheEvent.RESPONSE_HEADERS)
            return null
        }
        val ttl = freshnessMs(image.headers, receivedWallMs, receivedAt - requestAt)
        if (ttl == null && (!diskSnapshot || !hasKanxySnapshotPolicy(image.headers))) {
            report?.invoke(KanxyImageCacheEvent.RESPONSE_NOT_FRESH)
            return null
        }
        val response = if (diskSnapshot || image.file == null) image else {
            val bytes = runCatching { image.file.readBytes() }.getOrNull()
            if (bytes == null || bytes.size.toLong() != length) {
                report?.invoke(KanxyImageCacheEvent.BUFFER_READ_FAILED)
                return null
            }
            image.copy(bytes = bytes, file = null)
        }
        return PreparedAsset(
            response,
            expectedMime,
            ttl?.let { receivedWallMs + it },
            ttl?.let { receivedAt + it },
        )
    }

    fun admit(key: GameResourceCacheKey, image: PreparedAsset, report: ((KanxyImageCacheEvent) -> Unit)?) {
        val expiresAt = image.expiresAtElapsedMs ?: return
        write(key, image.response, expiresAt)
        report?.invoke(KanxyImageCacheEvent.STORED)
    }

    @Synchronized
    private fun write(key: GameResourceCacheKey, image: GameResourceFetchResult, expiresAt: Long) {
        remove(key)
        entries[key] = Entry(image, expiresAt)
        totalBytes += image.bodyLength
        val oldest = entries.entries.iterator()
        while (totalBytes > MAX_BYTES || entries.size > MAX_ENTRIES) {
            totalBytes -= oldest.next().value.image.bodyLength
            oldest.remove()
        }
    }

    private fun freshnessMs(headers: Map<String, String>, wallMs: Long, responseDelayMs: Long): Long? {
        val cacheControl = headers.header("Cache-Control") ?: return null
        // Only admit unambiguous max-age policies. Quoted extension values can contain commas.
        if ('"' in cacheControl) return null
        val controls = cacheControl.split(',').map { it.trim().split('=', limit = 2) }
        if (controls.any { directive ->
                RESTRICTIVE_DIRECTIVES.any { it.equals(directive.first().trim(), true) }
            } || headers.header("Pragma")?.contains("no-cache", ignoreCase = true) == true
        ) return null
        val maxAge = controls.filter { it.first().trim().equals("max-age", true) }.singleOrNull()
            ?.getOrNull(1)?.deltaSeconds()?.takeIf { it in 1..MAX_AGE_SECONDS } ?: return null
        val age = headers.header("Age")?.let {
            it.deltaSeconds()?.takeIf { seconds -> seconds in 0 until maxAge } ?: return null
        } ?: 0L
        val apparentAge = headers.header("Date")?.let {
            val date = runCatching {
                ZonedDateTime.parse(it, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant().toEpochMilli()
            }.getOrNull() ?: return null
            (wallMs - date).coerceAtLeast(0)
        } ?: 0L
        val currentAge = maxOf(apparentAge, age * 1_000 + responseDelayMs)
        return (maxAge * 1_000 - currentAge).coerceAtMost(MAX_TTL_MS).takeIf { it > 0 }
    }

    private fun hasKanxySnapshotPolicy(headers: Map<String, String>): Boolean {
        // Kanxy 1.01.9 deliberately applies this policy to their downstream HTTP response.
        // The manually cleared snapshot cache only recognizes this exact verified-route policy.
        val policy = headers.header("Cache-Control")?.split(',')?.map { it.trim().lowercase() } ?: return false
        return policy.size == KANXY_SNAPSHOT_DIRECTIVES.size && policy.toSet() == KANXY_SNAPSHOT_DIRECTIVES &&
            headers.header("Pragma")?.trim()?.equals("no-cache", true) == true &&
            headers.header("Expires")?.trim() == "0" &&
            headers.header("Age").let { it == null || it.deltaSeconds() != null } &&
            headers.header("Date").let {
                it == null || runCatching { ZonedDateTime.parse(it, DateTimeFormatter.RFC_1123_DATE_TIME) }.isSuccess
            }
    }

    private fun Map<String, String>.header(name: String): String? =
        entries.filter { it.key.equals(name, ignoreCase = true) }.takeIf { it.isNotEmpty() }
            ?.joinToString(",") { it.value }

    private fun String.deltaSeconds(): Long? = trim().takeIf { s -> s.all { it in '0'..'9' } }?.toLongOrNull()

    companion object {
        fun supports(url: String): Boolean {
            val uri = runCatching { URI(url) }.getOrNull() ?: return false
            return GameResourceCacheRules.isShareableStaticUri(uri) &&
                GameResourceCacheRules.mimeTypeFor(url).mime in IMAGE_TYPES
        }

        private const val MAX_TTL_MS = 60_000L
        private const val MAX_BYTES = 8L * 1024 * 1024
        private const val MAX_IMAGE_BYTES = 512L * 1024
        private const val MAX_ENTRIES = 256
        private const val MAX_AGE_SECONDS = Long.MAX_VALUE / 2_000
        private val IMAGE_TYPES = setOf("image/png", "image/jpeg", "image/webp", "image/gif")
        private val RESTRICTIVE_DIRECTIVES = setOf("private", "no-store", "no-cache")
        private val KANXY_SNAPSHOT_DIRECTIVES = setOf("no-store", "no-cache", "must-revalidate", "max-age=0")
    }
}
