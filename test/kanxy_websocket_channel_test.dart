import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the game uses native Kanxy WebSockets and reconnects on route changes',
    () {
      final result = Process.runSync('node', [
        'test/fixtures/kanxy_websocket_script_test.cjs',
        'android/app/src/main/kotlin/app/yahagi/kancollebrowser/browser/'
            'KanxyWebSocketScript.kt',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    },
  );
}
