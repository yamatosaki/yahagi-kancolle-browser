import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';

void main() {
  group('CaptureModeController', () {
    test('defaults to game mode when no preference exists', () async {
      final controller = await CaptureModeController.load(_MemoryModeStore());

      expect(controller.mode, CaptureMode.game);
      expect(controller.errorMessage, isNull);
    });

    test('restores browser-only mode from storage', () async {
      final controller = await CaptureModeController.load(
        _MemoryModeStore(CaptureMode.browserOnly),
      );

      expect(controller.mode, CaptureMode.browserOnly);
    });

    test('changes mode only after storage succeeds', () async {
      final store = _MemoryModeStore();
      final controller = await CaptureModeController.load(store);
      var changes = 0;
      controller.addListener(() => changes += 1);

      final changed = await controller.setMode(CaptureMode.browserOnly);

      expect(changed, isTrue);
      expect(controller.mode, CaptureMode.browserOnly);
      expect(store.savedMode, CaptureMode.browserOnly);
      expect(changes, 1);
    });

    test('keeps current mode when storage fails', () async {
      final controller = await CaptureModeController.load(
        _MemoryModeStore()..failSaving = true,
      );

      final changed = await controller.setMode(CaptureMode.browserOnly);

      expect(changed, isFalse);
      expect(controller.mode, CaptureMode.game);
      expect(controller.errorMessage, '无法保存捕获模式，请重试');
    });
  });
}

final class _MemoryModeStore implements CaptureModeStore {
  _MemoryModeStore([this.savedMode]);

  CaptureMode? savedMode;
  bool failSaving = false;

  @override
  Future<CaptureMode?> read() async => savedMode;

  @override
  Future<void> write(CaptureMode mode) async {
    if (failSaving) {
      throw StateError('save failed');
    }
    savedMode = mode;
  }
}
