import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_startup_sequence.dart';

void main() {
  test('installs capture before the first real page navigation', () async {
    final calls = <String>[];

    await GameCaptureStartupSequence.run(
      waitForPlatformView: () async => calls.add('mounted'),
      configureCapture: () async => calls.add('capture'),
      navigate: () async => calls.add('navigate'),
    );

    expect(calls, <String>['mounted', 'capture', 'navigate']);
  });

  test('retries only a temporarily missing hybrid WebView', () async {
    var attempts = 0;

    await GameCaptureStartupSequence.configureWithRetry(
      configure: () async {
        attempts++;
        if (attempts < 3) throw const GameWebViewNotReadyException();
      },
      waitBeforeRetry: () async {},
      maxAttempts: 3,
    );

    expect(attempts, 3);
  });

  test('does not hide permanent capture configuration errors', () async {
    await expectLater(
      GameCaptureStartupSequence.configureWithRetry(
        configure: () async => throw StateError('invalid script'),
        waitBeforeRetry: () async {},
      ),
      throwsStateError,
    );
  });

  test('does not navigate when capture configuration fails', () async {
    var navigated = false;

    await expectLater(
      GameCaptureStartupSequence.run(
        waitForPlatformView: () async {},
        configureCapture: () async => throw StateError('invalid script'),
        navigate: () async => navigated = true,
      ),
      throwsStateError,
    );

    expect(navigated, isFalse);
  });
}
