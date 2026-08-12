import '../settings/game_rendering_mode.dart';

abstract interface class GameWebViewCompatibilityPort {
  Future<void> allowThirdPartyCookies();

  Future<void> setUserAgent(String userAgent);
}

abstract final class GameWebViewCompatibility {
  static const canvasCompatibilityUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'Version/26.0 Safari/605.1.15';

  static String toDesktopUserAgent(String currentUserAgent) {
    final chromeVersion = RegExp(
      r'\bChrome/[0-9.]+',
    ).firstMatch(currentUserAgent)?.group(0);

    final appleWebKitVersion = RegExp(
      r'\bAppleWebKit/[0-9.]+',
    ).firstMatch(currentUserAgent)?.group(0);

    final safariVersion = RegExp(
      r'\bSafari/[0-9.]+',
    ).firstMatch(currentUserAgent)?.group(0);

    if (chromeVersion == null ||
        appleWebKitVersion == null ||
        safariVersion == null) {
      return currentUserAgent;
    }

    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        '$appleWebKitVersion (KHTML, like Gecko) '
        '$chromeVersion $safariVersion';
  }

  static String userAgentFor(
    GameRenderingMode renderingMode,
    String currentUserAgent,
  ) {
    if (renderingMode.usesCanvasRenderer) {
      return canvasCompatibilityUserAgent;
    }
    return toDesktopUserAgent(currentUserAgent);
  }

  static Future<void> configure(
    GameWebViewCompatibilityPort port, {
    required String currentUserAgent,
    GameRenderingMode renderingMode = GameRenderingMode.compatibility,
  }) async {
    await port.allowThirdPartyCookies();
    await port.setUserAgent(userAgentFor(renderingMode, currentUserAgent));
  }
}
