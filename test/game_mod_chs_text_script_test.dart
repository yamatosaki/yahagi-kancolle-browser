import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CHS text preserves PIXI setters and typewriter callbacks', () {
    const modsPath =
        'android/app/src/main/kotlin/app/yahagi/kancollebrowser/mods';
    final result = Process.runSync('node', [
      'test/game_mod_chs_text_script_test.cjs',
      '$modsPath/GameModChsTextScript.kt',
      '$modsPath/GameModChsBgmNames.kt',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('CHS display translations passed'));
  });
}
