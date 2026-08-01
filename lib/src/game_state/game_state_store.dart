import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';
import 'game_state_serializer.dart';

class GameStateStore {
  GameStateStore({this.saveDelay = const Duration(seconds: 5)});

  static const String _key = 'yahagi_kancolle_browser_game_state';
  final Duration saveDelay;
  Timer? _debounceTimer;
  GameState? _pendingState;

  Future<GameState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return GameStateSerializer.deserialize(jsonStr);
      }
    } catch (e) {
      // Ignore load errors and return empty state
    }
    return GameState.empty;
  }

  void save(GameState state) {
    _pendingState = state;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(saveDelay, () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final state = _pendingState;
    if (state == null) {
      return;
    }
    _pendingState = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = GameStateSerializer.serialize(state);
      await prefs.setString(_key, jsonStr);
    } catch (_) {
      // A later live API event will schedule another complete snapshot.
    }
  }
}
