import 'package:flutter/foundation.dart';

import 'capture_mode.dart';
import 'capture_mode_store.dart';

final class CaptureModeController extends ChangeNotifier {
  CaptureModeController._({
    required this._store,
    required this._mode,
    this._errorMessage,
  });

  final CaptureModeStore _store;
  CaptureMode _mode;
  String? _errorMessage;

  CaptureMode get mode => _mode;
  String? get errorMessage => _errorMessage;
  bool get captureEnabled => _mode == CaptureMode.game;

  static Future<CaptureModeController> load(CaptureModeStore store) async {
    try {
      return CaptureModeController._(
        store: store,
        mode: await store.read() ?? CaptureMode.game,
      );
    } catch (_) {
      return CaptureModeController._(
        store: store,
        mode: CaptureMode.game,
        errorMessage: '无法读取捕获模式，已使用游戏模式',
      );
    }
  }

  Future<bool> setMode(CaptureMode mode) async {
    if (mode == _mode) {
      return false;
    }

    try {
      await _store.write(mode);
    } catch (_) {
      _errorMessage = '无法保存捕获模式，请重试';
      notifyListeners();
      return false;
    }

    _mode = mode;
    _errorMessage = null;
    notifyListeners();
    return true;
  }
}
