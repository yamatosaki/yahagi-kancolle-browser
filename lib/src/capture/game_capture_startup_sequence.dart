final class GameWebViewNotReadyException implements Exception {
  const GameWebViewNotReadyException();
}

final class GameCaptureStartupSequence {
  const GameCaptureStartupSequence._();

  static Future<void> run({
    required Future<void> Function() waitForPlatformView,
    required Future<void> Function() configureCapture,
    required Future<void> Function() navigate,
  }) async {
    await waitForPlatformView();
    await configureCapture();
    await navigate();
  }

  static Future<void> configureWithRetry({
    required Future<void> Function() configure,
    Future<void> Function()? waitBeforeRetry,
    int maxAttempts = 20,
  }) async {
    assert(maxAttempts > 0);
    final wait = waitBeforeRetry ?? _waitForHybridWebView;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await configure();
        return;
      } on GameWebViewNotReadyException {
        if (attempt == maxAttempts) {
          rethrow;
        }
        await wait();
      }
    }
  }

  static Future<void> _waitForHybridWebView() {
    return Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
