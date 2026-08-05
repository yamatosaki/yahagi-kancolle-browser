import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_awake_controller.dart';

void main() {
  test('defaults off and applies a persisted setting when attached', () async {
    final store = _MemoryScreenAwakeStore();
    final port = _RecordingScreenAwakePort();
    final controller = await ScreenAwakeController.load(store);

    await controller.attachPort(port);

    expect(controller.enabled, isFalse);
    expect(port.values, <bool>[false]);
  });

  test('persists changes and disables only while backgrounded', () async {
    final store = _MemoryScreenAwakeStore();
    final port = _RecordingScreenAwakePort();
    final controller = await ScreenAwakeController.load(store);
    await controller.attachPort(port);
    port.values.clear();

    await controller.setEnabled(true);
    await controller.handleLifecycleState(AppLifecycleState.paused);
    await controller.handleLifecycleState(AppLifecycleState.resumed);

    expect(store.value, isTrue);
    expect(controller.enabled, isTrue);
    expect(port.values, <bool>[true, false, true]);
  });

  test('rolls the switch back when native state cannot be applied', () async {
    final store = _MemoryScreenAwakeStore();
    final port = _RecordingScreenAwakePort()..fail = true;
    final controller = await ScreenAwakeController.load(store);
    await controller.attachPort(port);

    await controller.setEnabled(true);

    expect(controller.enabled, isFalse);
    expect(store.value, isFalse);
    expect(controller.errorMessage, isNotNull);
  });
}

final class _MemoryScreenAwakeStore implements ScreenAwakeStore {
  bool? value;

  @override
  Future<bool?> readEnabled() async => value;

  @override
  Future<void> writeEnabled(bool enabled) async => value = enabled;
}

final class _RecordingScreenAwakePort implements ScreenAwakePort {
  bool fail = false;
  bool actual = false;
  final List<bool> values = <bool>[];

  @override
  Future<bool> isEnabled() async => actual;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (fail) {
      throw StateError('native failure');
    }
    actual = enabled;
    values.add(enabled);
  }
}
