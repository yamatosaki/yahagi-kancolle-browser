import 'package:shared_preferences/shared_preferences.dart';

enum BattleWarningMode { off, reminder, confirm }

abstract class SafetySettingsStore {
  Future<BattleWarningMode> loadWarningMode();
  Future<void> saveWarningMode(BattleWarningMode mode);
  Future<bool> loadBattleDamageVibrationEnabled();
  Future<void> saveBattleDamageVibrationEnabled(bool enabled);
}

class SharedPreferencesSafetySettingsStore implements SafetySettingsStore {
  static const String _modeKey = 'safety.battleWarningMode';
  static const String _damageVibrationKey = 'battle.damageVibrationEnabled';

  @override
  Future<BattleWarningMode> loadWarningMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    return BattleWarningMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BattleWarningMode.confirm,
    );
  }

  @override
  Future<void> saveWarningMode(BattleWarningMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  @override
  Future<bool> loadBattleDamageVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_damageVibrationKey) ?? true;
  }

  @override
  Future<void> saveBattleDamageVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_damageVibrationKey, enabled);
  }
}

class MemorySafetySettingsStore implements SafetySettingsStore {
  BattleWarningMode _mode = BattleWarningMode.confirm;
  bool _damageVibrationEnabled = true;

  @override
  Future<BattleWarningMode> loadWarningMode() async => _mode;

  @override
  Future<void> saveWarningMode(BattleWarningMode mode) async {
    _mode = mode;
  }

  @override
  Future<bool> loadBattleDamageVibrationEnabled() async =>
      _damageVibrationEnabled;

  @override
  Future<void> saveBattleDamageVibrationEnabled(bool enabled) async {
    _damageVibrationEnabled = enabled;
  }
}
