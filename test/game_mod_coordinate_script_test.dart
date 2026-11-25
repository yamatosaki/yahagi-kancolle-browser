import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/native_game_capture_script.dart';

void main() {
  test('game mod response hooks preserve capture', () {
    final temporary = Directory.systemTemp.createTempSync(
      'yahagi-coordinates-',
    );
    try {
      final capture = File('${temporary.path}/capture.js')
        ..writeAsStringSync(nativeGameCaptureScript);
      final result = Process.runSync('node', [
        'test/fixtures/game_mod_coordinate_script_test.cjs',
        'android/app/src/main/kotlin/app/yahagi/kancollebrowser/mods/GameModCoordinateScript.kt',
        capture.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('60 scenarios passed'));
      expect(result.stdout, contains('Quest translations passed'));
    } finally {
      temporary.deleteSync(recursive: true);
    }
  });
}
