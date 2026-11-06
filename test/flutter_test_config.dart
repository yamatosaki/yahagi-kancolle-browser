import 'dart:async';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GameStateController.disableTimerForTest = true;
  setUp(() {
    // The test engine has no Android window provider. Complete the initial
    // handshake deterministically; protocol tests override this with snapshots.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('app.yahagi.kancollebrowser/window_layout'),
          (_) async => throw MissingPluginException(),
        );
  });
  await testMain();
}
