import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_policy.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';

void main() {
  test('downgrades only after two consecutive unstable CreateJS windows', () {
    final policy = GameFrameRatePolicy(mode: GameFrameRateMode.automatic);

    _addUnstableCreateJsWindow(policy);
    expect(policy.completeWindow(), FrameRateDecision.keep60);
    _addUnstableCreateJsWindow(policy);
    expect(policy.completeWindow(), FrameRateDecision.downgradeTo30);
    expect(policy.completeWindow(), FrameRateDecision.lock30);
  });

  test('a stable window resets the consecutive unstable count', () {
    final policy = GameFrameRatePolicy(mode: GameFrameRateMode.automatic);
    _addUnstableCreateJsWindow(policy);
    expect(policy.completeWindow(), FrameRateDecision.keep60);

    for (final fps in <double>[58, 59, 60, 58, 60]) {
      policy.addCreateJsSample(fps);
    }
    expect(policy.completeWindow(), FrameRateDecision.keep60);

    _addUnstableCreateJsWindow(policy);
    expect(policy.completeWindow(), FrameRateDecision.keep60);
  });

  test('Flutter frames require ten samples and twenty percent over 32 ms', () {
    final insufficient = GameFrameRatePolicy(mode: GameFrameRateMode.automatic);
    for (var index = 0; index < 9; index++) {
      insufficient.addFlutterFrame(const Duration(milliseconds: 40));
    }
    expect(insufficient.completeWindow(), FrameRateDecision.keep60);

    final policy = GameFrameRatePolicy(mode: GameFrameRateMode.automatic);
    for (var window = 0; window < 2; window++) {
      for (var index = 0; index < 8; index++) {
        policy.addFlutterFrame(const Duration(milliseconds: 16));
      }
      for (var index = 0; index < 2; index++) {
        policy.addFlutterFrame(const Duration(milliseconds: 40));
      }
      expect(
        policy.completeWindow(),
        window == 0
            ? FrameRateDecision.keep60
            : FrameRateDecision.downgradeTo30,
      );
    }
  });

  test('manual modes never trigger an automatic downgrade', () {
    for (final mode in <GameFrameRateMode>[
      GameFrameRateMode.stable30,
      GameFrameRateMode.prefer60,
    ]) {
      final policy = GameFrameRatePolicy(mode: mode);
      _addUnstableCreateJsWindow(policy);
      _addUnstableFlutterWindow(policy);
      expect(
        policy.completeWindow(),
        mode == GameFrameRateMode.stable30
            ? FrameRateDecision.lock30
            : FrameRateDecision.keep60,
      );
    }
  });
}

void _addUnstableCreateJsWindow(GameFrameRatePolicy policy) {
  for (final fps in <double>[49, 48, 47, 55, 56]) {
    policy.addCreateJsSample(fps);
  }
}

void _addUnstableFlutterWindow(GameFrameRatePolicy policy) {
  for (var index = 0; index < 8; index++) {
    policy.addFlutterFrame(const Duration(milliseconds: 16));
  }
  for (var index = 0; index < 2; index++) {
    policy.addFlutterFrame(const Duration(milliseconds: 40));
  }
}
