package app.yahagi.kancollebrowser.mods

import java.io.DataInputStream
import java.io.File
import java.io.RandomAccessFile

internal object GameModStaticAssets {
    private const val MAINTENANCE = "kcs/html/maintenance.png"
    private const val OPEN_TYPE = 0x4F54544F // OTTO
    private const val WOFF2 = 0x774F4632   // wOF2
    private val maintenanceRequest = Regex("(?:kcs/)?html/maintenance\\.png(?:\\.pagespeed\\.ce\\.[A-Za-z0-9_-]+\\.png)?")
    private val pngDirectories = setOf("furniture", "slot", "useitem", "world", "map", "worldselect", "area")
    val fontPaths = setOf(
        "kcs2/resources/font/A-OTF-UDShinGoPro-Light.woff2",
        "kcs2/resources/font/A-OTF-UDShinGoPro-Regular.woff2",
    )

    fun isPngPath(path: String): Boolean {
        if (!path.endsWith(".png")) return false
        if (path == MAINTENANCE || path.startsWith("kcs2/img/")) return true
        if (!path.startsWith("kcs2/resources/")) return false
        return path.substring("kcs2/resources/".length).substringBefore('/') in pngDirectories
    }

    fun isJpegPath(path: String) = path.startsWith("kcs2/img/") &&
        (path.endsWith(".jpg") || path.endsWith(".jpeg"))

    fun isFontPath(path: String) = path in fontPaths

    fun eligibleForStaticQuota(path: String) = isPngPath(path) || isJpegPath(path) || isFontPath(path) ||
        (path.startsWith("kcs2/resources/ship/album_status/") && GameModArchive.SHIP_PATH.matches(path))

    fun maintenanceTarget(path: String): String? =
        if (maintenanceRequest.matches(path)) MAINTENANCE else null

    /** Check JPEG framing and the decoded image budget without allocating a bitmap. */
    fun validateJpeg(file: File) {
        try {
            val imageEnd = file.length() - 2
            RandomAccessFile(file, "r").use { input ->
                input.seek(imageEnd)
                require(input.readUnsignedShort() == 0xFFD9)
            }
            DataInputStream(file.inputStream().buffered()).use { input ->
                require(input.readUnsignedShort() == 0xFFD8)
                var offset = 2L
                var components = 0
                while (offset < imageEnd) {
                    require(input.readUnsignedByte() == 0xFF)
                    offset++
                    var marker: Int
                    do {
                        marker = input.readUnsignedByte()
                        offset++
                    } while (marker == 0xFF)
                    require(marker in 0xC0..0xFE && marker !in 0xD0..0xD9)
                    val size = input.readUnsignedShort()
                    require(size >= 2 && offset + size <= imageEnd)
                    var bytesRead = 2
                    if (marker in 0xC0..0xC2) {
                        require(components == 0 && size >= 8 && input.readUnsignedByte() == 8)
                        val height = input.readUnsignedShort()
                        val width = input.readUnsignedShort()
                        components = input.readUnsignedByte()
                        require(width in 1..16_384 && height in 1..16_384 &&
                            width.toLong() * height * 4 <= GameModPng.MAX_BYTES &&
                            components in 1..4 && size == 8 + 3 * components)
                        bytesRead = 8
                    } else if (marker == 0xDA) {
                        val scanComponents = input.readUnsignedByte()
                        require(scanComponents in 1..components && size == 6 + 2 * scanComponents &&
                            offset + size < imageEnd)
                        return
                    }
                    require(input.skipBytes(size - bytesRead) == size - bytesRead)
                    offset += size
                }
                throw IllegalArgumentException("Missing JPEG scan")
            }
        } catch (_: Exception) {
            throw GameModException("invalid_jpeg", "JPEG 已损坏、被截断或尺寸超出限制。")
        }
    }

    /** The Chinese release ships raw CFF OpenType data under the original .woff2 URL. */
    fun validateFont(file: File) {
        try {
            DataInputStream(file.inputStream().buffered()).use { input ->
                val length = file.length()
                when (input.readInt()) {
                    OPEN_TYPE -> validateOpenType(input, length)
                    WOFF2 -> validateWoff2(input, length)
                    else -> throw IllegalArgumentException("Unknown font signature")
                }
            }
        } catch (_: Exception) {
            throw GameModException("invalid_font", "游戏字体文件已损坏或格式不受支持。")
        }
    }

    fun fontMime(file: File): String = DataInputStream(file.inputStream()).use { input ->
        when (input.readInt()) {
            OPEN_TYPE -> "font/otf"
            WOFF2 -> "font/woff2"
            else -> throw GameModException("invalid_font", "游戏字体文件已损坏或格式不受支持。")
        }
    }

    private fun validateOpenType(input: DataInputStream, length: Long) {
        val tables = input.readUnsignedShort()
        val headerEnd = 12L + 16L * tables
        require(tables in 1..256 && headerEnd <= length)
        input.skipBytes(6)
        val tags = mutableSetOf<Int>()
        var hasOutlines = false
        repeat(tables) {
            val tag = input.readInt()
            input.readInt() // Table checksum, checked by the font decoder.
            val offset = input.readUnsignedInt()
            val size = input.readUnsignedInt()
            require(tags.add(tag) && offset >= headerEnd && offset % 4L == 0L && offset + size <= length)
            if (tag == 0x43464620 || tag == 0x43464632) hasOutlines = size >= 4 // CFF or CFF2
        }
        require(hasOutlines)
    }

    private fun validateWoff2(input: DataInputStream, length: Long) {
        val flavor = input.readInt()
        val declaredLength = input.readUnsignedInt()
        val tables = input.readUnsignedShort()
        val reserved = input.readUnsignedShort()
        val decodedSize = input.readUnsignedInt()
        val compressedSize = input.readUnsignedInt()
        require((flavor == OPEN_TYPE || flavor == 0x00010000) && declaredLength == length &&
            tables in 1..256 && reserved == 0 && decodedSize in (12L + 16L * tables)..GameModArchive.MAX_FILE_BYTES &&
            compressedSize in 1..(length - 48 - tables))
        input.readInt() // Version.
        val metadataOffset = input.readUnsignedInt()
        val metadataLength = input.readUnsignedInt()
        val metadataSize = input.readUnsignedInt()
        val privateOffset = input.readUnsignedInt()
        val privateLength = input.readUnsignedInt()
        val minimumOffset = 48 + tables + compressedSize
        require(optionalFontBlockFits(metadataOffset, metadataLength, minimumOffset, length) &&
            optionalFontBlockFits(privateOffset, privateLength, minimumOffset, length) &&
            (if (metadataLength == 0L) metadataSize == 0L else metadataSize in 1..GameModArchive.MAX_FILE_BYTES) &&
            (metadataLength == 0L || privateLength == 0L || privateOffset >= metadataOffset + metadataLength))
    }

    private fun optionalFontBlockFits(offset: Long, size: Long, minimumOffset: Long, length: Long): Boolean =
        if (size == 0L) offset == 0L else offset >= minimumOffset && offset + size <= length

    private fun DataInputStream.readUnsignedInt() = readInt().toLong() and 0xFFFF_FFFFL
}
