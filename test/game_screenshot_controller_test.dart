import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_screenshot_controller.dart';

void main() {
  test('returns the saved WebView-only screenshot path', () async {
    final port = _FakeScreenshotPort('/pictures/yahagi.png');
    final controller = GameScreenshotController(port);

    final result = await controller.capture();

    expect(result.path, '/pictures/yahagi.png');
    expect(result.errorMessage, isNull);
    expect(port.calls, 1);
  });

  test(
    'coalesces concurrent screenshot taps and reports native failures',
    () async {
      final completer = Completer<String>();
      final port = _FakeScreenshotPort.future(completer.future);
      final controller = GameScreenshotController(port);

      final first = controller.capture();
      final second = controller.capture();
      expect(port.calls, 1);
      completer.completeError(StateError('blank screenshot'));

      final results = await Future.wait(<Future<GameScreenshotResult>>[
        first,
        second,
      ]);
      expect(results.every((result) => result.path == null), isTrue);
      expect(results.every((result) => result.errorMessage != null), isTrue);
      expect(port.calls, 1);
    },
  );

  test('preserves PixelCopy failure details from Android', () async {
    final port = _FakeScreenshotPort.future(
      Future<String>.error(
        PlatformException(
          code: 'pixel_copy_failed',
          message: 'PixelCopy failed with code 3.',
        ),
      ),
    );
    final controller = GameScreenshotController(port);

    final result = await controller.capture();

    expect(result.path, isNull);
    expect(result.errorMessage, contains('pixel_copy_failed'));
    expect(result.errorMessage, contains('code 3'));
  });
}

final class _FakeScreenshotPort implements GameScreenshotPort {
  _FakeScreenshotPort(String path) : _future = Future<String>.value(path);
  _FakeScreenshotPort.future(this._future);

  final Future<String> _future;
  int calls = 0;

  @override
  Future<String> captureWebView() {
    calls += 1;
    return _future;
  }
}
