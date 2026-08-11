package app.yahagi.kancollebrowser

object GameRenderingModeHcppPolicy {
    const val PREFERENCES_NAME = "FlutterSharedPreferences"
    const val RENDERING_MODE_KEY = "flutter.game.renderingMode"

    fun shouldEnable(storedMode: String?): Boolean =
        storedMode == "compatibility" || storedMode == "canvasCompatibility"
}
