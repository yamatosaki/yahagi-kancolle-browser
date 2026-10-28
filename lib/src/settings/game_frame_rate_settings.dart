import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameFrameRateMode {
  automatic('auto'),
  stable60('stable60'),
  stable30('stable30'),
  highRefresh('highRefresh');

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

final class GameFrameRateConfigurationCancelledException implements Exception {
  const GameFrameRateConfigurationCancelledException();
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
        oldBoolean ? GameFrameRateMode.automatic : GameFrameRateMode.stable30,
      );
    }

    final legacyMode = switch (preferences.getString(_legacyModeKey)) {
      'max60' || 'followDisplay' => GameFrameRateMode.automatic,
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
  bool _disposed = false;
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

  Future<void> attachPort(GameFrameRatePort port) {
    final operation = _modeChangeQueue.then((_) => _attachPort(port));
    _modeChangeQueue = operation.catchError((_) {});
    return operation;
  }

  /// Waits for native bridge installation before the first real navigation.
  ///
  /// The feature probe also applies Android version policy, so it cannot
  /// establish whether this WebView supports the document-start bridge.
  Future<bool> attachPortForStartup(
    GameFrameRatePort port, {
    Future<void>? cancelled,
    bool Function()? isActive,
  }) {
    var cancellationRequested = false;
    final cancellation = cancelled?.then<void>((_) {
      cancellationRequested = true;
    });
    final operation = _modeChangeQueue.then(
      (_) => _attachPortForStartup(
        port,
        cancelled: cancellation,
        isActive: () => !cancellationRequested && isActive?.call() != false,
      ),
    );
    _modeChangeQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<bool> _attachPortForStartup(
    GameFrameRatePort port, {
    Future<void>? cancelled,
    required bool Function() isActive,
  }) async {
    _ensureStartupActive(isActive);
    _port = port;
    _supported = null;
    try {
      await Future.any<void>(<Future<void>>[
        port.configure(_mode),
        if (cancelled != null)
          cancelled.then<void>((_) {
            throw const GameFrameRateConfigurationCancelledException();
          }),
      ]);
      _ensureStartupActive(isActive);
      _supported = true;
      return true;
    } on PlatformException catch (error) {
      _supported = false;
      _ensureStartupActive(isActive);
      if (error.code == 'frame_rate_unsupported') return false;
      rethrow;
    } catch (_) {
      _supported = false;
      _ensureStartupActive(isActive);
      rethrow;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void _ensureStartupActive(bool Function() isActive) {
    if (_disposed) {
      throw StateError('Game frame-rate startup controller has been disposed');
    }
    if (!isActive()) {
      throw const GameFrameRateConfigurationCancelledException();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _attachPort(GameFrameRatePort port) async {
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
