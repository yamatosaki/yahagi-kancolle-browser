import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameToolbarDisplayMode { autoHide, persistent }

abstract interface class GameToolbarDisplayStore {
  Future<GameToolbarDisplayMode?> read();

  Future<void> write(GameToolbarDisplayMode mode);
}

final class SharedPreferencesGameToolbarDisplayStore
    implements GameToolbarDisplayStore {
  static const _key = 'game_toolbar_display_mode';

  @override
  Future<GameToolbarDisplayMode?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return GameToolbarDisplayMode.values
        .cast<GameToolbarDisplayMode?>()
        .firstWhere((mode) => mode?.name == value, orElse: () => null);
  }

  @override
  Future<void> write(GameToolbarDisplayMode mode) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      mode.name,
    );
    if (!saved) {
      throw StateError('toolbar display preference was not saved');
    }
  }
}

final class GameToolbarDisplayController extends ChangeNotifier {
  GameToolbarDisplayController._(this._store, this._mode);

  static Future<GameToolbarDisplayController> load(
    GameToolbarDisplayStore store,
  ) async {
    return GameToolbarDisplayController._(
      store,
      await store.read() ?? GameToolbarDisplayMode.autoHide,
    );
  }

  final GameToolbarDisplayStore _store;
  GameToolbarDisplayMode _mode;

  GameToolbarDisplayMode get mode => _mode;

  Future<void> setMode(GameToolbarDisplayMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    await _store.write(mode);
  }
}
