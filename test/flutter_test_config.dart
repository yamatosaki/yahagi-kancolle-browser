import 'dart:async';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GameStateController.disableTimerForTest = true;
  await testMain();
}
