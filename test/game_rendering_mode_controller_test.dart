import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('shared preferences store defaults and round-trips', () async {
    final store = SharedPreferencesGameRenderingModeStore();

    expect(await store.load(), GameRenderingMode.standard);
    await store.save(GameRenderingMode.canvasCompatibility);
    expect(await store.load(), GameRenderingMode.canvasCompatibility);
  });

  test('controller saves and restarts a different mode', () async {
    final store = MemoryGameRenderingModeStore();
    final controller = await GameRenderingModeController.load(store);
    final port = _RecordingRestartPort();
    controller.attachRestartPort(port);
    addTearDown(controller.dispose);

    final result = await controller.changeMode(GameRenderingMode.compatibility);

    expect(result.status, GameRenderingModeChangeStatus.applied);
    expect(controller.mode, GameRenderingMode.compatibility);
    expect(await store.load(), GameRenderingMode.compatibility);
    expect(port.modes, <GameRenderingMode>[GameRenderingMode.compatibility]);
  });

  test('selecting the active mode does not save or restart', () async {
    final store = _CountingStore(GameRenderingMode.compatibility);
    final controller = await GameRenderingModeController.load(store);
    final port = _RecordingRestartPort();
    controller.attachRestartPort(port);
    addTearDown(controller.dispose);

    final result = await controller.changeMode(GameRenderingMode.compatibility);

    expect(result.status, GameRenderingModeChangeStatus.unchanged);
    expect(store.saveCount, 0);
    expect(port.modes, isEmpty);
  });

  test('a second request is rejected while restart is in progress', () async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    final port = _BlockingRestartPort();
    controller.attachRestartPort(port);
    addTearDown(controller.dispose);

    final first = controller.changeMode(GameRenderingMode.compatibility);
    await port.started.future;
    final second = await controller.changeMode(
      GameRenderingMode.canvasCompatibility,
    );

    expect(second.status, GameRenderingModeChangeStatus.busy);
    port.release.complete();
    expect((await first).status, GameRenderingModeChangeStatus.applied);
  });

  test('save failure keeps the active mode and does not restart', () async {
    final controller = await GameRenderingModeController.load(
      _FailingSaveStore(),
    );
    final port = _RecordingRestartPort();
    controller.attachRestartPort(port);
    addTearDown(controller.dispose);

    final result = await controller.changeMode(GameRenderingMode.compatibility);

    expect(result.status, GameRenderingModeChangeStatus.saveFailed);
    expect(controller.mode, GameRenderingMode.standard);
    expect(port.modes, isEmpty);
  });

  test('restart failure rolls back persisted and active mode to standard', () async {
    final store = MemoryGameRenderingModeStore();
    final controller = await GameRenderingModeController.load(store);
    final port = _FailFirstRestartPort();
    controller.attachRestartPort(port);
    addTearDown(controller.dispose);

    final result = await controller.changeMode(
      GameRenderingMode.canvasCompatibility,
    );

    expect(result.status, GameRenderingModeChangeStatus.rolledBack);
    expect(controller.mode, GameRenderingMode.standard);
    expect(await store.load(), GameRenderingMode.standard);
    expect(port.modes, <GameRenderingMode>[
      GameRenderingMode.canvasCompatibility,
      GameRenderingMode.standard,
    ]);
  });
}

final class _RecordingRestartPort implements GameEnvironmentRestartPort {
  final List<GameRenderingMode> modes = <GameRenderingMode>[];

  @override
  Future<void> restart(GameRenderingMode mode) async => modes.add(mode);
}

final class _BlockingRestartPort implements GameEnvironmentRestartPort {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> restart(GameRenderingMode mode) async {
    started.complete();
    await release.future;
  }
}

final class _FailFirstRestartPort implements GameEnvironmentRestartPort {
  final List<GameRenderingMode> modes = <GameRenderingMode>[];

  @override
  Future<void> restart(GameRenderingMode mode) async {
    modes.add(mode);
    if (modes.length == 1) throw StateError('restart failed');
  }
}

final class _CountingStore implements GameRenderingModeStore {
  _CountingStore(this.value);

  GameRenderingMode value;
  int saveCount = 0;

  @override
  Future<GameRenderingMode> load() async => value;

  @override
  Future<void> save(GameRenderingMode mode) async {
    saveCount += 1;
    value = mode;
  }
}

final class _FailingSaveStore implements GameRenderingModeStore {
  @override
  Future<GameRenderingMode> load() async => GameRenderingMode.standard;

  @override
  Future<void> save(GameRenderingMode mode) async {
    throw StateError('save failed');
  }
}
