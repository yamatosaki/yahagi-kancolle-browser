import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/native_game_capture_script.dart';

void main() {
  group('nativeGameCaptureScript', () {
    test('uses the native frame bridge and versioned kcsapi protocol', () {
      expect(
        nativeGameCaptureScript,
        contains('YahagiNativeCapture.postMessage'),
      );
      expect(nativeGameCaptureScript, contains('/kcsapi/'));
      expect(nativeGameCaptureScript, contains("version: 1"));
      expect(nativeGameCaptureScript, contains("kind: 'kcsapi_response'"));
    });

    test('observes xhr and cloned fetch responses without cookie access', () {
      expect(nativeGameCaptureScript, contains('.clone()'));
      expect(nativeGameCaptureScript, contains("'loadend'"));
      expect(nativeGameCaptureScript, contains('originalFetch'));
      expect(nativeGameCaptureScript, contains('originalSend'));
      expect(nativeGameCaptureScript, isNot(contains('document.cookie')));
      expect(nativeGameCaptureScript, isNot(contains('localStorage')));
    });

    test('is idempotent and removes sensitive request parameters', () {
      expect(
        nativeGameCaptureScript,
        contains('__yahagiMobileNativeCaptureInstalled'),
      );
      expect(nativeGameCaptureScript, contains('api_token'));
      expect(nativeGameCaptureScript, contains('api_starttime'));
      expect(nativeGameCaptureScript, contains('delete'));
    });

    test('preserves formation parameters from modern POST body types', () {
      expect(
        nativeGameCaptureScript,
        contains('body instanceof URLSearchParams'),
      );
      expect(nativeGameCaptureScript, contains('input.clone().text()'));
    });
  });
}
