import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';

void main() {
  test('only game mode installs the game bridge', () {
    expect(CaptureMode.game.installsGameBridge, isTrue);
    expect(CaptureMode.browserOnly.installsGameBridge, isFalse);
  });
}
