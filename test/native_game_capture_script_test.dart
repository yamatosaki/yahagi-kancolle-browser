import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/native_game_capture_script.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_path_catalog.dart';

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

    test('prefers an ArrayBuffer payload with permanent string fallback', () {
      expect(
        nativeGameCaptureScript,
        contains('__YAHAGI_BINARY_CAPTURE_ENABLED__'),
      );
      expect(nativeGameCaptureScript, contains('new TextEncoder()'));
      expect(nativeGameCaptureScript, contains('new ArrayBuffer('));
      expect(nativeGameCaptureScript, contains('publishStringFallback'));
      expect(
        nativeGameCaptureScript,
        contains('YahagiNativeCapture.postMessage(JSON.stringify'),
      );
    });

    test('embeds the complete interested-path allowlist', () {
      for (final path in GameCapturePathCatalog.all) {
        expect(nativeGameCaptureScript, contains('"$path"'));
      }
      expect(nativeGameCaptureScript, contains('targetPaths.has(path)'));
    });

    test('observes xhr and cloned fetch responses without cookie access', () {
      expect(nativeGameCaptureScript, contains('.clone()'));
      expect(nativeGameCaptureScript, contains("'loadend'"));
      expect(nativeGameCaptureScript, contains('originalFetch'));
      expect(nativeGameCaptureScript, contains('originalSend'));
      expect(nativeGameCaptureScript, isNot(contains('document.cookie')));
      expect(nativeGameCaptureScript, isNot(contains('localStorage')));
    });

    test(
      'checks the allowlist before copying fetch or xhr response bodies',
      () {
        final fetchGuard = nativeGameCaptureScript.indexOf(
          'if (path !== null)',
        );
        final fetchCopy = nativeGameCaptureScript.indexOf(
          'response.clone().text()',
        );
        final xhrGuard = nativeGameCaptureScript.indexOf(
          'if (path !== null)',
          fetchGuard + 1,
        );
        final xhrCopy = nativeGameCaptureScript.indexOf('this.responseText');

        expect(fetchGuard, greaterThanOrEqualTo(0));
        expect(fetchCopy, greaterThan(fetchGuard));
        expect(xhrGuard, greaterThan(fetchGuard));
        expect(xhrCopy, greaterThan(xhrGuard));
      },
    );

    test('checks the allowlist before cloning a fetch Request body', () {
      final fetchStart = nativeGameCaptureScript.indexOf(
        'window.fetch = function(...args)',
      );
      final fetchEnd = nativeGameCaptureScript.indexOf(
        "if (typeof XMLHttpRequest === 'function')",
        fetchStart,
      );
      final fetchBlock = nativeGameCaptureScript.substring(
        fetchStart,
        fetchEnd,
      );
      final pathCheck = fetchBlock.indexOf('const path = targetPath(url)');
      final requestGuard = fetchBlock.indexOf('if (path !== null)');
      final requestClone = fetchBlock.indexOf('input.clone().text()');

      expect(pathCheck, greaterThanOrEqualTo(0));
      expect(requestGuard, greaterThan(pathCheck));
      expect(requestClone, greaterThan(requestGuard));
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

    test('builds a complete quest snapshot after a quest page opens', () {
      expect(nativeGameCaptureScript, contains('syncCompleteQuestSnapshot'));
      expect(nativeGameCaptureScript, contains('api_get_member/questlist'));
      expect(nativeGameCaptureScript, contains('api_page_no'));
      expect(nativeGameCaptureScript, contains('api_exec_count'));
      expect(nativeGameCaptureScript, contains('yahagi_full_quest_snapshot'));
    });
  });
}
