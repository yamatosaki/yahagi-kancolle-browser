import 'package:shared_preferences/shared_preferences.dart';

enum DisplayMode { auto, landscape, portrait }

abstract class DisplayModeStore {
  Future<DisplayMode> loadDisplayMode();
  Future<void> saveDisplayMode(DisplayMode mode);
}

class SharedPreferencesDisplayModeStore implements DisplayModeStore {
  static const String _modeKey = 'settings.displayMode';

  @override
  Future<DisplayMode> loadDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_modeKey);
    return DisplayMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => DisplayMode.auto,
    );
  }

  @override
  Future<void> saveDisplayMode(DisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }
}

class MemoryDisplayModeStore implements DisplayModeStore {
  MemoryDisplayModeStore([this._mode = DisplayMode.auto]);
  DisplayMode _mode;

  @override
  Future<DisplayMode> loadDisplayMode() async => _mode;

  @override
  Future<void> saveDisplayMode(DisplayMode mode) async {
    _mode = mode;
  }
}
