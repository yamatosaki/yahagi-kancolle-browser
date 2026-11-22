package app.yahagi.kancollebrowser.browser

import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URI
import java.security.MessageDigest
import java.util.Locale

/** Independent local snapshots of eligible static resources on verified Kanxy HTTP routes. */
internal class KanxyDiskResourceCache(private val store: GameResourceCacheStore) {
    fun supports(url: String): Boolean {
        val uri = runCatching { URI(url) }.getOrNull() ?: return false
        return assetLimit(uri, url) != null
    }

    fun entry(
        proxy: Proxy,
        resource: GameResourceCacheKey,
        url: String,
        headers: Map<String, String>,
        generation: Long,
    ): Entry? {
        if (!isLoopbackHttpProxy(proxy) ||
            headers.keys.any { it.equals("Cookie", true) || it.equals("Cookie2", true) }
        ) return null
        val uri = runCatching { URI(url) }.getOrNull() ?: return null
        // Persist public URLs only, excluding signed requests and arbitrary query parameters.
        if (uri.rawFragment != null || uri.rawQuery?.let { !PUBLIC_VERSION_QUERY.matches(it) } == true) return null
        val maxAssetBytes = assetLimit(uri, url) ?: return null
        val endpoint = proxy.address() as InetSocketAddress
        val identity = "${endpoint.hostString.lowercase(Locale.ROOT)}\n${endpoint.port}\n${resource.value}"
        val digest = MessageDigest.getInstance("SHA-256").digest(identity.toByteArray(Charsets.UTF_8))
        val key = GameResourceCacheKey("kanxy-http-v1:${digest.joinToString("") { "%02x".format(it) }}")
        return Entry(store, key, generation, maxAssetBytes)
    }

    fun generation(): Long = store.generation()

    class Entry internal constructor(
        private val store: GameResourceCacheStore,
        private val key: GameResourceCacheKey,
        private val generation: Long,
        val maxAssetBytes: Long,
    ) {
        fun read(now: Long): GameResourceResponse? = runCatching {
            val cached = store.readFile(key) ?: return@runCatching null
            val policy = cached.entry.version
            if (policy != MANUAL_CLEAR && (policy?.toLongOrNull() ?: 0L) <= now) {
                store.removeIfGeneration(key, generation)
                return@runCatching null
            }
            val mime = cached.entry.mimeType
            val headers = cached.entry.responseHeaders.filterKeys { !it.equals("Cache-Control", true) } + mapOf(
                "Cache-Control" to "no-store",
                "Content-Type" to mime,
                "Content-Length" to cached.entry.byteLength.toString(),
            )
            GameResourceResponse(
                mimeType = mime,
                encoding = if (mime == "application/json") "utf-8" else null,
                headers = headers,
                source = GameResourceResponseSource.CACHE,
                // The descriptor remains valid if a later clear or eviction unlinks the file.
                bodyStream = cached.file.inputStream(),
                streamLength = cached.entry.byteLength,
            )
        }.getOrNull()

        fun write(asset: KanxyHttpImageCache.PreparedAsset): Boolean = runCatching {
            val response = asset.response
            val version = asset.expiresAtWallMs?.toString() ?: MANUAL_CLEAR
            val headers = GameResourceCacheRules.persistedResponseHeaders(response.headers)
            val file = response.file
            val committed = if (file != null) {
                // This makes a cache copy. The download still belongs to the first WebView response.
                store.commitFileWithEviction(
                    key, file, version, asset.mimeType, responseHeaders = headers, expectedGeneration = generation,
                )
            } else {
                store.commitWithEviction(
                    key, response.bytes, version, asset.mimeType, responseHeaders = headers, expectedGeneration = generation,
                )
            }
            committed != null
        }.getOrDefault(false)

        fun remove() {
            runCatching { store.removeIfGeneration(key, generation) }
        }
    }

    fun clear() = store.clear()

    fun closeMaintenance() = store.closeMaintenance()

    private companion object {
        const val MANUAL_CLEAR = "kanxy-manual-v1"
        const val MAX_RASTER_BYTES = 4L * 1024 * 1024
        const val MAX_ATLAS_BYTES = 1L * 1024 * 1024
        const val MAX_MP3_BYTES = 4L * 1024 * 1024
        val PUBLIC_VERSION_QUERY = Regex("version=[A-Za-z0-9._-]{1,128}")

        fun assetLimit(uri: URI, url: String): Long? {
            if (!GameResourceCacheRules.isOfficialStaticUri(uri)) return null
            val path = uri.rawPath.lowercase(Locale.ROOT)
            return when {
                path.startsWith("/kcs2/img/") && path.endsWith(".json") -> MAX_ATLAS_BYTES
                path.endsWith(".mp3") && (
                    path.startsWith("/kcs/sound/") || path.startsWith("/kcs2/resources/se/") ||
                        path.startsWith("/kcs2/resources/bgm/")
                    ) -> MAX_MP3_BYTES
                KanxyHttpImageCache.supports(url) -> MAX_RASTER_BYTES
                else -> null
            }
        }
    }
}
