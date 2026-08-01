abstract interface class GameWebViewCompatibilityPort {
  Future<void> allowThirdPartyCookies();

  Future<void> setUserAgent(String userAgent);
}

abstract final class GameWebViewCompatibility {
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

  static Future<void> configure(
    GameWebViewCompatibilityPort port, {
    required String currentUserAgent,
  }) async {
    await port.allowThirdPartyCookies();
    await port.setUserAgent(toDesktopUserAgent(currentUserAgent));
  }
}
