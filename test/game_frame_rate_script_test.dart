import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_script.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_runtime_controller.dart';

void main() {
  test('30 FPS script uses the CreateJS timeout ticker', () {
    final script = gameFrameRateApplyScript(GameFrameRateTarget.fps30);
    expect(script, contains('createjs.Ticker'));
    expect(script, contains('TIMEOUT'));
    expect(script, contains('framerate=30'));
  });

  test('60 FPS script uses CreateJS RAF without replacing global RAF', () {
    final script = gameFrameRateApplyScript(GameFrameRateTarget.fps60);
    expect(script, contains('createjs.Ticker'));
    expect(script, contains('RAF'));
    expect(script, contains('framerate=60'));
    expect(script, isNot(contains('requestAnimationFrame=')));
  });

  test('measurement script returns null when CreateJS ticker is absent', () {
    expect(gameFrameRateMeasurementScript, contains('getMeasuredFPS'));
    expect(gameFrameRateMeasurementScript, contains('return null'));
  });

  test('all scripts avoid requests and synthetic input', () {
    final scripts = <String>[
      gameFrameRateApplyScript(GameFrameRateTarget.fps30),
      gameFrameRateApplyScript(GameFrameRateTarget.fps60),
      gameFrameRateMeasurementScript,
    ];
    for (final script in scripts) {
      for (final forbidden in <String>[
        'fetch',
        'XMLHttpRequest',
        '.click',
        'dispatchEvent',
      ]) {
        expect(script, isNot(contains(forbidden)));
      }
    }
  });
}
