import 'package:shared_preferences/shared_preferences.dart';

enum BattleWarningMode { off, reminder, confirm }

abstract class SafetySettingsStore {
  Future<BattleWarningMode> loadWarningMode();
  Future<void> saveWarningMode(BattleWarningMode mode);
}

class SharedPreferencesSafetySettingsStore implements SafetySettingsStore {
  static const String _modeKey = 'safety.battleWarningMode';

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
}

class MemorySafetySettingsStore implements SafetySettingsStore {
  BattleWarningMode _mode = BattleWarningMode.confirm;

  @override
  Future<BattleWarningMode> loadWarningMode() async => _mode;

  @override
  Future<void> saveWarningMode(BattleWarningMode mode) async {
    _mode = mode;
  }
}
