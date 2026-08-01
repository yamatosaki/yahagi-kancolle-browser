import 'package:shared_preferences/shared_preferences.dart';

abstract interface class GameAudioStore {
  Future<bool?> readMuted();

  Future<void> writeMuted(bool muted);
}

final class SharedPreferencesGameAudioStore implements GameAudioStore {
  static const _key = 'game_audio_muted';

  @override
  Future<bool?> readMuted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key);
  }

  @override
  Future<void> writeMuted(bool muted) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_key, muted);
    if (!saved) {
      throw StateError('game audio preference was not saved');
    }
  }
}
