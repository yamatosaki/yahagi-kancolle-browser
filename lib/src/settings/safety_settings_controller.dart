import 'package:flutter/foundation.dart';

import 'safety_settings_store.dart';

class SafetySettingsController extends ChangeNotifier {
  SafetySettingsController._(this._store);

  final SafetySettingsStore _store;
  late BattleWarningMode _battleWarningMode;
  late bool _battleDamageVibrationEnabled;

  BattleWarningMode get battleWarningMode => _battleWarningMode;
  bool get battleDamageVibrationEnabled => _battleDamageVibrationEnabled;

  static Future<SafetySettingsController> load(
    SafetySettingsStore store,
  ) async {
    final controller = SafetySettingsController._(store);
    await controller.loadSettings();
    return controller;
  }

  Future<void> loadSettings() async {
    _battleWarningMode = await _store.loadWarningMode();
    _battleDamageVibrationEnabled = await _store
        .loadBattleDamageVibrationEnabled();
    notifyListeners();
  }

  Future<void> setBattleWarningMode(BattleWarningMode mode) async {
    if (_battleWarningMode == mode) return;
    _battleWarningMode = mode;
    notifyListeners();
    await _store.saveWarningMode(mode);
  }

  Future<void> setBattleDamageVibrationEnabled(bool enabled) async {
    if (_battleDamageVibrationEnabled == enabled) return;
    _battleDamageVibrationEnabled = enabled;
    notifyListeners();
    await _store.saveBattleDamageVibrationEnabled(enabled);
  }
}
