package app.yahagi.kancollebrowser.browser

import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URI
import java.net.URL
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.FutureTask
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

data class GameResourceFetchResult(
    val statusCode: Int,
    val reasonPhrase: String,
    val headers: Map<String, String>,
    val bytes: ByteArray = ByteArray(0),
    val file: File? = null,
) {
    val bodyLength: Long get() = file?.length() ?: bytes.size.toLong()
}

fun interface GameResourceFetcher {
    fun fetch(
        url: String,
        requestHeaders: Map<String, String>,
        cached: GameResourceCacheEntry?,
    ): GameResourceFetchResult?

    fun budgetMillis(url: String): Long =
        if (GameResourceCacheRules.requiresStrictValidation(url)) 5_000 else 15_000

    fun fetchWithinDeadline(
        url: String,
        requestHeaders: Map<String, String>,
        cached: GameResourceCacheEntry?,
        deadlineNanos: Long,
    ): GameResourceFetchResult? = fetch(url, requestHeaders, cached)
}

class HttpUrlConnectionGameResourceFetcher(
    private val proxyProvider: () -> Proxy? = { null },
    private val connectTimeoutMs: Int = 8_000,
    private val readTimeoutMs: Int = 30_000,
    private val maxFileBytes: Long = MAX_RESOURCE_BYTES,
    private val temporaryDirectory: File = File(System.getProperty("java.io.tmpdir"), "yahagi-resource-downloads"),
    private val totalTimeoutMs: Long = 15_000,
    private val connectionFactory: (String, Proxy?) -> HttpURLConnection? = { url, proxy ->
        NativeProxyRouting.openConnection(URL(url), proxy)
    },
) : GameResourceFetcher {
    private val cleanupDone = AtomicBoolean(false)
    init {
        temporaryDirectory.mkdirs()
    }

    override fun fetch(
        url: String,
        requestHeaders: Map<String, String>,
        cached: GameResourceCacheEntry?,
    ): GameResourceFetchResult? = fetchWithinDeadline(url, requestHeaders, cached,
        System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(budgetMillis(url).coerceAtLeast(1)))

    override fun budgetMillis(url: String): Long =
        if (GameResourceCacheRules.requiresStrictValidation(url)) minOf(totalTimeoutMs, 5_000) else totalTimeoutMs

    override fun fetchWithinDeadline(
        url: String,
        requestHeaders: Map<String, String>,
        cached: GameResourceCacheEntry?,
        deadlineNanos: Long,
    ): GameResourceFetchResult? {
        val forwarded = GameResourceCacheRules.boundedForwardedRequestHeaders(requestHeaders)
            ?: return null
        if (!GameResourceCacheRules.shouldCache(url, "GET")) return null
        val deadline = minOf(deadlineNanos,
            System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(budgetMillis(url).coerceAtLeast(1)))
        val remainingNanos = deadline - System.nanoTime()
        if (remainingNanos <= 0) return null
        val aborted = AtomicBoolean(false)
        val completed = AtomicReference<GameResourceFetchResult?>()
        val task = FutureTask {
            val response = runCatching { fetchWithinBudget(url, forwarded, cached, deadline, aborted) }.getOrNull()
            completed.set(response)
            if (aborted.get()) { response?.file?.delete(); null } else response
        }
        var delivered = false
        try {
            downloads.execute(task)
            val response = task.get((deadline - System.nanoTime()).coerceAtLeast(1), TimeUnit.NANOSECONDS)
            delivered = response != null
            return response
        } catch (_: Exception) {
            return null
        } finally {
            if (!delivered) {
                aborted.set(true)
                task.cancel(true)
                completed.get()?.file?.delete()
            }
        }
    }

    private fun remainingMs(deadline: Long): Long =
        TimeUnit.NANOSECONDS.toMillis(deadline - System.nanoTime()).coerceAtLeast(0)

    private fun fetchWithinBudget(
        url: String,
        forwarded: Map<String, String>,
        cached: GameResourceCacheEntry?,
        deadline: Long,
        aborted: AtomicBoolean,
    ): GameResourceFetchResult? {
        if (!cleanupDone.get()) synchronized(cleanupDone) {
            if (!cleanupDone.get()) {
                for (file in temporaryDirectory.listFiles().orEmpty()) {
                    if (aborted.get() || remainingMs(deadline) <= 0) return null
                    if (file.name.endsWith(".part") &&
                        System.currentTimeMillis() - file.lastModified() > 24L * 60L * 60L * 1000L
                    ) file.delete()
                }
                cleanupDone.set(true)
            }
        }
        var current = url
        repeat(MAX_REDIRECTS + 1) { redirectCount ->
            val remaining = remainingMs(deadline).takeIf { it > 0 && !aborted.get() } ?: return null
            if (!GameResourceCacheRules.shouldCache(current, "GET")) return null
            val connection = connectionFactory(current, proxyProvider()) ?: return null
            try {
                connection.instanceFollowRedirects = false
                connection.connectTimeout = minOf(connectTimeoutMs.toLong(), remaining).coerceAtLeast(1).toInt()
                connection.readTimeout = minOf(readTimeoutMs.toLong(), remaining).coerceAtLeast(1).toInt()
                connection.requestMethod = "GET"
                forwarded.forEach { (name, value) ->
                    connection.setRequestProperty(name, value)
                }
                cached?.etag?.let { connection.setRequestProperty("If-None-Match", it) }
                cached?.lastModified?.let { connection.setRequestProperty("If-Modified-Since", it) }
                val statusCode = connection.responseCode
                if (aborted.get() || remainingMs(deadline) <= 0) return null
                if (statusCode in REDIRECT_CODES) {
                    if (redirectCount >= MAX_REDIRECTS) return null
                    val location = connection.getHeaderField("Location") ?: return null
                    val next = URI(current).resolve(location).toString()
                    if (!isSafeRedirect(current, next)) return null
                    current = next
                    return@repeat
                }
                val headers = linkedMapOf<String, String>()
                var headerChars = 0L
                connection.headerFields.forEach { (key, values) ->
                    if (key == null) return@forEach
                    if (key.length > 128 || values.size > 32) return null
                    headerChars += key.length + values.sumOf { it.length.toLong() + 2L }
                    if (headerChars > 32_768) return null
                    headers[key] = values.joinToString(", ")
                }
                if (statusCode == HttpURLConnection.HTTP_NOT_MODIFIED) {
                    return GameResourceFetchResult(statusCode, connection.responseMessage ?: "Not Modified", headers, ByteArray(0))
                }
                if (statusCode !in 200..299) return null
                // WebView handles range responses and Set-Cookie; do not download the body twice.
                if (statusCode == HttpURLConnection.HTTP_PARTIAL ||
                    headers.keys.any { it.equals("Set-Cookie", true) || it.equals("Set-Cookie2", true) }) {
                    return GameResourceFetchResult(statusCode, connection.responseMessage ?: "OK", headers)
                }
                val declaredLength = connection.contentLengthLong
                if (declaredLength > maxFileBytes) return null
                val file = connection.inputStream.use { input ->
                    downloadToTemporaryFile(input, declaredLength, maxFileBytes, temporaryDirectory) {
                        val left = remainingMs(deadline)
                        if (left <= 0 || aborted.get()) false else {
                            connection.readTimeout = minOf(readTimeoutMs.toLong(), left).coerceAtLeast(1).toInt()
                            true
                        }
                    }
                }
                    ?: return null
                return GameResourceFetchResult(statusCode, connection.responseMessage ?: "OK", headers, file = file)
            } finally {
                connection.disconnect()
            }
        }
        return null
    }

    private fun isSafeRedirect(previous: String, next: String): Boolean {
        val before = runCatching { URI(previous) }.getOrNull() ?: return false
        val after = runCatching { URI(next) }.getOrNull() ?: return false
        if (!GameResourceCacheRules.shouldCache(next, "GET")) return false
        if (before.scheme.equals("https", true) && !after.scheme.equals("https", true)) return false
        return before.host.equals(after.host, ignoreCase = true)
    }

    companion object {
        const val MAX_RESOURCE_BYTES = 16L * 1024L * 1024L
        private const val MAX_REDIRECTS = 5
        private val REDIRECT_CODES = setOf(301, 302, 303, 307, 308)
        private val downloads = ThreadPoolExecutor(2, 2, 30, TimeUnit.SECONDS,
            ArrayBlockingQueue(4), { task -> Thread(task, "game-resource-download").apply { isDaemon = true } },
            ThreadPoolExecutor.AbortPolicy())

        internal fun downloadToTemporaryFile(
            input: InputStream,
            declaredLength: Long,
            maxBytes: Long,
            directory: File,
            shouldContinue: () -> Boolean = { true },
        ): File? {
            if (declaredLength > maxBytes || !directory.isDirectory && !directory.mkdirs()) return null
            val file = directory.resolve("${UUID.randomUUID()}.part")
            var complete = false
            try {
                file.outputStream().buffered().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        if (!shouldContinue()) return null
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (count == 0) continue
                        total += count
                        if (total > maxBytes) return null
                        output.write(buffer, 0, count)
                    }
                    if (declaredLength >= 0 && declaredLength != total) return null
                    if (!shouldContinue()) return null
                }
                complete = true
                return file
            } finally {
                if (!complete) file.delete()
            }
        }
    }
}
