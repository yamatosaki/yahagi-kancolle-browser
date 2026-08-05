import 'package:flutter/widgets.dart';

import 'game_audio_port.dart';
import 'game_audio_store.dart';

enum GameAudioAvailability { checking, available, unavailable }

final class GameAudioController extends ChangeNotifier {
  GameAudioController._({
    required this._store,
    required this._isMuted,
    required this._backgroundPlaybackEnabled,
  });

  static Future<GameAudioController> load(GameAudioStore store) async {
    final savedMuted = await store.readMuted();
    final savedBackgroundPlayback = await store.readBackgroundPlaybackEnabled();
    return GameAudioController._(
      store: store,
      isMuted: savedMuted ?? false,
      backgroundPlaybackEnabled: savedBackgroundPlayback ?? false,
    );
  }

  final GameAudioStore _store;

  GameAudioPort? _port;
  bool _isMuted;
  bool _backgroundPlaybackEnabled;
  bool _isForeground = true;
  bool? _lastAppliedMuted;
  bool _isBusy = false;
  GameAudioAvailability _availability = GameAudioAvailability.checking;
  String? _errorMessage;

  bool get isMuted => _isMuted;
  bool get backgroundPlaybackEnabled => _backgroundPlaybackEnabled;
  bool get effectiveMuted =>
      _isMuted || (!_backgroundPlaybackEnabled && !_isForeground);
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
      await port.setMuted(effectiveMuted);
      _lastAppliedMuted = effectiveMuted;
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
    final previousEffective = effectiveMuted;
    final nextEffective =
        next || (!_backgroundPlaybackEnabled && !_isForeground);
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await port.setMuted(nextEffective);
      _lastAppliedMuted = nextEffective;
      try {
        await _store.writeMuted(next);
      } catch (_) {
        await port.setMuted(previousEffective);
        _lastAppliedMuted = previousEffective;
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

  Future<void> setBackgroundPlaybackEnabled(bool enabled) async {
    if (_backgroundPlaybackEnabled == enabled) {
      return;
    }
    final previous = _backgroundPlaybackEnabled;
    _backgroundPlaybackEnabled = enabled;
    _errorMessage = null;
    notifyListeners();
    try {
      await _store.writeBackgroundPlaybackEnabled(enabled);
      await _applyEffectiveMuted();
    } catch (error) {
      _backgroundPlaybackEnabled = previous;
      _errorMessage = '后台声音设置失败：$error';
      try {
        await _store.writeBackgroundPlaybackEnabled(previous);
        await _applyEffectiveMuted();
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    final foreground = state == AppLifecycleState.resumed;
    if (_isForeground == foreground) {
      return;
    }
    _isForeground = foreground;
    await _applyEffectiveMuted();
  }

  Future<void> _applyEffectiveMuted() async {
    final port = _port;
    final muted = effectiveMuted;
    if (port == null ||
        _availability != GameAudioAvailability.available ||
        _lastAppliedMuted == muted) {
      return;
    }
    try {
      await port.setMuted(muted);
      _lastAppliedMuted = muted;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = '当前设备无法控制游戏声音：$error';
    }
    notifyListeners();
  }
}
