import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class GameStartupCheckSettingsController extends ChangeNotifier {
  GameStartupCheckSettingsController._(this._preferences, this._enabled);

  static const preferenceKey = 'game.startupCheck';

  final SharedPreferences _preferences;
  bool _enabled;
  bool _saving = false;
  bool _saveFailed = false;
  bool _disposed = false;

  bool get enabled => _enabled;
  bool get saving => _saving;
  bool get saveFailed => _saveFailed;

  static Future<GameStartupCheckSettingsController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.get(preferenceKey);
    return GameStartupCheckSettingsController._(
      preferences,
      stored is bool ? stored : true,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _saving || enabled == _enabled) return;
    _saving = true;
    _saveFailed = false;
    final stored = _preferences.get(preferenceKey);
    notifyListeners();
    try {
      if (!await _preferences.setBool(preferenceKey, enabled)) {
        throw StateError('Startup check preference was not saved');
      }
      _enabled = enabled;
    } catch (_) {
      // SharedPreferences mutates its Dart cache before the platform responds.
      // Restore the previous selection (or its absent key) on a rejected write.
      try {
        if (stored is bool) {
          await _preferences.setBool(preferenceKey, stored);
        } else {
          await _preferences.remove(preferenceKey);
        }
      } catch (_) {}
      _saveFailed = true;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
