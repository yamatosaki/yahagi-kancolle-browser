import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameFrameRateMode {
  automatic('auto'),
  stable30('stable30'),
  prefer60('prefer60');

  const GameFrameRateMode(this.wireName);

  final String wireName;

  static GameFrameRateMode fromWireName(String? value) {
    return values.firstWhere(
      (mode) => mode.wireName == value,
      orElse: () => GameFrameRateMode.automatic,
    );
  }
}

abstract interface class GameFrameRatePort {
  Future<bool> isSupported();

  Future<void> configure(GameFrameRateMode mode);
}

abstract interface class GameFrameRateSettingsStore {
  Future<GameFrameRateMode> loadMode();

  Future<void> saveMode(GameFrameRateMode mode);
}

final class SharedPreferencesGameFrameRateSettingsStore
    implements GameFrameRateSettingsStore {
  static const String _modeKey = 'game.frameRateMode.v2';
  static const String _booleanKey = 'game.unlockFrameRate';
  static const String _legacyModeKey = 'game.frameRateMode';

  @override
  Future<GameFrameRateMode> loadMode() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.containsKey(_modeKey)) {
      return GameFrameRateMode.fromWireName(preferences.getString(_modeKey));
    }

    final oldBoolean = preferences.getBool(_booleanKey);
    if (oldBoolean != null) {
      return _persistMigration(
        preferences,
        oldBoolean ? GameFrameRateMode.prefer60 : GameFrameRateMode.stable30,
      );
    }

    final legacyMode = switch (preferences.getString(_legacyModeKey)) {
      'max60' || 'followDisplay' => GameFrameRateMode.prefer60,
      'off' => GameFrameRateMode.stable30,
      _ => null,
    };
    if (legacyMode != null) {
      return _persistMigration(preferences, legacyMode);
    }
    return GameFrameRateMode.automatic;
  }

  Future<GameFrameRateMode> _persistMigration(
    SharedPreferences preferences,
    GameFrameRateMode mode,
  ) async {
    final saved = await preferences.setString(_modeKey, mode.wireName);
    if (!saved) throw StateError('frame rate mode migration was not saved');
    return mode;
  }

  @override
  Future<void> saveMode(GameFrameRateMode mode) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _modeKey,
      mode.wireName,
    );
    if (!saved) throw StateError('frame rate mode was not saved');
  }
}

final class MemoryGameFrameRateSettingsStore
    implements GameFrameRateSettingsStore {
  MemoryGameFrameRateSettingsStore([this._mode = GameFrameRateMode.automatic]);

  GameFrameRateMode _mode;

  @override
  Future<GameFrameRateMode> loadMode() async => _mode;

  @override
  Future<void> saveMode(GameFrameRateMode mode) async => _mode = mode;
}

final class GameFrameRateSettingsController extends ChangeNotifier {
  GameFrameRateSettingsController._(this._store, this._mode);

  final GameFrameRateSettingsStore _store;
  GameFrameRatePort? _port;
  GameFrameRateMode _mode;
  bool? _supported;
  Future<void> _modeChangeQueue = Future<void>.value();

  GameFrameRateMode get mode => _mode;
  bool? get supported => _supported;

  static Future<GameFrameRateSettingsController> load(
    GameFrameRateSettingsStore store,
  ) async => GameFrameRateSettingsController._(store, await store.loadMode());

  Future<void> setMode(GameFrameRateMode mode) {
    final operation = _modeChangeQueue.then((_) => _setMode(mode));
    _modeChangeQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> _setMode(GameFrameRateMode mode) async {
    if (_mode == mode) return;
    await _store.saveMode(mode);
    _mode = mode;
    final port = _port;
    if (port != null && _supported == true) {
      try {
        await port.configure(mode);
      } catch (_) {
        _supported = false;
      }
    }
    notifyListeners();
  }

  Future<void> attachPort(GameFrameRatePort port) async {
    _port = port;
    try {
      _supported = await port.isSupported();
      if (_supported == true) await port.configure(_mode);
    } catch (_) {
      _supported = false;
    }
    notifyListeners();
  }
}
