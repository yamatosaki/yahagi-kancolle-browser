import 'package:flutter/foundation.dart';

import 'game_audio_port.dart';
import 'game_audio_store.dart';

enum GameAudioAvailability { checking, available, unavailable }

final class GameAudioController extends ChangeNotifier {
  GameAudioController._({required this._store, required this._isMuted});

  static Future<GameAudioController> load(GameAudioStore store) async {
    final savedMuted = await store.readMuted();
    return GameAudioController._(store: store, isMuted: savedMuted ?? false);
  }

  final GameAudioStore _store;

  GameAudioPort? _port;
  bool _isMuted;
  bool _isBusy = false;
  GameAudioAvailability _availability = GameAudioAvailability.checking;
  String? _errorMessage;

  bool get isMuted => _isMuted;
  bool get isBusy => _isBusy;
  GameAudioAvailability get availability => _availability;
  String? get errorMessage => _errorMessage;
  bool get canToggle =>
      _availability == GameAudioAvailability.available && !_isBusy;

  Future<void> attachPort(GameAudioPort port) async {
    _port = port;
    _errorMessage = null;
    try {
      final supported = await port.isSupported();
      if (!supported) {
        _availability = GameAudioAvailability.unavailable;
        notifyListeners();
        return;
      }
      await port.setMuted(_isMuted);
      _availability = GameAudioAvailability.available;
    } catch (error) {
      _availability = GameAudioAvailability.unavailable;
      _errorMessage = '当前设备无法控制游戏声音：$error';
    }
    notifyListeners();
  }

  Future<void> toggleMuted() async {
    final port = _port;
    if (port == null || !canToggle) {
      return;
    }

    final previous = _isMuted;
    final next = !previous;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await port.setMuted(next);
      try {
        await _store.writeMuted(next);
      } catch (_) {
        await port.setMuted(previous);
        rethrow;
      }
      _isMuted = next;
    } catch (error) {
      _errorMessage = '游戏声音切换失败：$error';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
