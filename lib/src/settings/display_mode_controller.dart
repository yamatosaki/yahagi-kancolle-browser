import 'package:flutter/foundation.dart';

import 'display_mode_store.dart';

class DisplayModeController extends ChangeNotifier {
  DisplayModeController._(this._store);

  final DisplayModeStore _store;
  late DisplayMode _displayMode;

  DisplayMode get displayMode => _displayMode;

  static Future<DisplayModeController> load(DisplayModeStore store) async {
    final controller = DisplayModeController._(store);
    await controller.loadSettings();
    return controller;
  }

  Future<void> loadSettings() async {
    _displayMode = await _store.loadDisplayMode();
    notifyListeners();
  }

  Future<void> setDisplayMode(DisplayMode mode) async {
    if (_displayMode == mode) return;
    _displayMode = mode;
    notifyListeners();
    await _store.saveDisplayMode(mode);
  }
}
