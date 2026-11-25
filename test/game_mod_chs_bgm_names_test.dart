import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('game mod BGM names use safe exact matches', () {
    final result = Process.runSync('node', [
      'test/game_mod_chs_bgm_names_test.cjs',
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/mods/'
          'GameModChsBgmNames.kt',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
