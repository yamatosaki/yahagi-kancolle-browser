package app.yahagi.kancollebrowser.capture

data class ScreenshotDestination(
    val fileName: String,
    val relativeDirectory: String,
) {
    val displayLocation: String
        get() = "$relativeDirectory/$fileName"

    companion object {
        fun create(timestamp: String): ScreenshotDestination {
            return ScreenshotDestination(
                fileName = "yahagi-game-$timestamp.png",
                relativeDirectory = "Pictures/Yahagi",
            )
        }
    }
}
