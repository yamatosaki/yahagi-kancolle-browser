import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_rendering_mode.dart';

abstract interface class GameRenderingModeStore {
  Future<GameRenderingMode> load();

  Future<void> save(GameRenderingMode mode);
}

final class SharedPreferencesGameRenderingModeStore
    implements GameRenderingModeStore {
  static const _key = 'game.renderingMode';

  @override
  Future<GameRenderingMode> load() async {
    final preferences = await SharedPreferences.getInstance();
    return GameRenderingModeCodec.decode(preferences.getString(_key));
  }

  @override
  Future<void> save(GameRenderingMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, mode.storageName);
    if (!saved) throw StateError('Unable to save game rendering mode');
  }
}

final class MemoryGameRenderingModeStore implements GameRenderingModeStore {
  MemoryGameRenderingModeStore([
    this._mode = GameRenderingMode.standard,
  ]);

  GameRenderingMode _mode;

  @override
  Future<GameRenderingMode> load() async => _mode;

  @override
  Future<void> save(GameRenderingMode mode) async => _mode = mode;
}

abstract interface class GameEnvironmentRestartPort {
  Future<void> restart(GameRenderingMode mode);
}

enum GameRenderingModeChangeStatus {
  unchanged,
  applied,
  busy,
  unavailable,
  saveFailed,
  rolledBack,
  restartFailed,
}

final class GameRenderingModeChangeResult {
  const GameRenderingModeChangeResult(this.status, {this.error});

  final GameRenderingModeChangeStatus status;
  final Object? error;
}

final class GameRenderingModeController extends ChangeNotifier {
  GameRenderingModeController._(this._store, this._mode);

  final GameRenderingModeStore _store;
  GameRenderingMode _mode;
  GameEnvironmentRestartPort? _restartPort;
  bool _isBusy = false;
  bool _disposed = false;
  GameRenderingModeChangeResult? _lastResult;

  GameRenderingMode get mode => _mode;
  bool get isBusy => _isBusy;
  GameRenderingModeChangeResult? get lastResult => _lastResult;

  static Future<GameRenderingModeController> load(
    GameRenderingModeStore store,
  ) async => GameRenderingModeController._(store, await store.load());

  void attachRestartPort(GameEnvironmentRestartPort port) {
    _restartPort = port;
  }

  void detachRestartPort(GameEnvironmentRestartPort port) {
    if (identical(_restartPort, port)) _restartPort = null;
  }

  Future<GameRenderingModeChangeResult> changeMode(
    GameRenderingMode target,
  ) async {
    if (_isBusy) {
      return const GameRenderingModeChangeResult(
        GameRenderingModeChangeStatus.busy,
      );
    }
    if (target == _mode) {
      return const GameRenderingModeChangeResult(
        GameRenderingModeChangeStatus.unchanged,
      );
    }
    final restartPort = _restartPort;
    if (restartPort == null) {
      return const GameRenderingModeChangeResult(
        GameRenderingModeChangeStatus.unavailable,
      );
    }

    _isBusy = true;
    _notify();
    try {
      try {
        await _store.save(target);
      } catch (error) {
        return _finish(
          GameRenderingModeChangeResult(
            GameRenderingModeChangeStatus.saveFailed,
            error: error,
          ),
        );
      }

      try {
        await restartPort.restart(target);
        _mode = target;
        return _finish(
          const GameRenderingModeChangeResult(
            GameRenderingModeChangeStatus.applied,
          ),
        );
      } catch (error) {
        try {
          await _store.save(GameRenderingMode.standard);
          await restartPort.restart(GameRenderingMode.standard);
          _mode = GameRenderingMode.standard;
          return _finish(
            GameRenderingModeChangeResult(
              GameRenderingModeChangeStatus.rolledBack,
              error: error,
            ),
          );
        } catch (rollbackError) {
          return _finish(
            GameRenderingModeChangeResult(
              GameRenderingModeChangeStatus.restartFailed,
              error: rollbackError,
            ),
          );
        }
      }
    } finally {
      if (_isBusy) {
        _isBusy = false;
        _notify();
      }
    }
  }

  GameRenderingModeChangeResult _finish(
    GameRenderingModeChangeResult result,
  ) {
    _lastResult = result;
    _isBusy = false;
    _notify();
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _restartPort = null;
    super.dispose();
  }
}
