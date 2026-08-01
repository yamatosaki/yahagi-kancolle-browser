import 'package:flutter/foundation.dart';

import 'safety_settings_store.dart';

class SafetySettingsController extends ChangeNotifier {
  SafetySettingsController._(this._store);

  final SafetySettingsStore _store;
  late BattleWarningMode _battleWarningMode;

  BattleWarningMode get battleWarningMode => _battleWarningMode;

  static Future<SafetySettingsController> load(
    SafetySettingsStore store,
  ) async {
    final controller = SafetySettingsController._(store);
    await controller.loadSettings();
    return controller;
  }

  Future<void> loadSettings() async {
    _battleWarningMode = await _store.loadWarningMode();
    notifyListeners();
  }

  Future<void> setBattleWarningMode(BattleWarningMode mode) async {
    if (_battleWarningMode == mode) return;
    _battleWarningMode = mode;
    notifyListeners();
    await _store.saveWarningMode(mode);
  }
}
