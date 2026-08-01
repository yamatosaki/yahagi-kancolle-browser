import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_webview_compatibility.dart';

void main() {
  group('GameWebViewCompatibility', () {
    test('converts an Android WebView user agent into a desktop Chrome one', () {
      const androidWebViewUserAgent =
          'Mozilla/5.0 (Linux; Android 13; Pixel Tablet Build/TQ3A.230805.001; wv) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
          'Chrome/109.0.0.0 Safari/537.36 Mobile';

      expect(
        GameWebViewCompatibility.toDesktopUserAgent(androidWebViewUserAgent),
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/109.0.0.0 Safari/537.36',
      );
    });

    test('keeps the actual Chromium version instead of inventing one', () {
      const currentUserAgent =
          'Mozilla/5.0 (Linux; Android 16; Pixel Tablet; wv) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
          'Chrome/140.0.7339.0 Mobile Safari/537.36';

      final desktopUserAgent = GameWebViewCompatibility.toDesktopUserAgent(
        currentUserAgent,
      );

      expect(desktopUserAgent, contains('Chrome/140.0.7339.0'));
      expect(desktopUserAgent, isNot(contains('Android')));
      expect(desktopUserAgent, isNot(contains('; wv')));
      expect(desktopUserAgent, isNot(contains(' Mobile')));
    });

    test('applies desktop identity and Android cookie compatibility', () async {
      final port = _RecordingCompatibilityPort();

      await GameWebViewCompatibility.configure(
        port,
        currentUserAgent:
            'Mozilla/5.0 (Linux; Android 13; Pixel Tablet; wv) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
            'Chrome/109.0.0.0 Mobile Safari/537.36',
      );

      expect(port.acceptedThirdPartyCookies, isTrue);
      expect(port.userAgent, contains('Windows NT 10.0'));
    });
  });
}

final class _RecordingCompatibilityPort
    implements GameWebViewCompatibilityPort {
  bool? acceptedThirdPartyCookies;
  String? userAgent;

  @override
  Future<void> allowThirdPartyCookies() async {
    acceptedThirdPartyCookies = true;
  }

  @override
  Future<void> setUserAgent(String userAgent) async {
    this.userAgent = userAgent;
  }
}
