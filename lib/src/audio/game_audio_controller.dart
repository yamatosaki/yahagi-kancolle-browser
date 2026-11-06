import 'dart:async';

import 'package:flutter/widgets.dart';

import '../localization/runtime_message_text.dart';
import 'game_audio_port.dart';
import 'game_audio_store.dart';

enum GameAudioAvailability { checking, available, unavailable }

final class GameAudioController extends ChangeNotifier {
  static const _nativeOperationTimeout = Duration(seconds: 5);

  GameAudioController._({
    required this._store,
    required this._isMuted,
    required this._backgroundPlaybackEnabled,
  }) : _savedBackgroundPlaybackEnabled = _backgroundPlaybackEnabled;

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
  bool _isBackgrounded = false;
  bool? _lastAppliedMuted;
  bool? _pendingMuted;
  bool _savedBackgroundPlaybackEnabled;
  int _backgroundRevision = 0;
  int _portGeneration = 0;
  bool _disposed = false;
  Future<void> _nativeTail = Future<void>.value();
  Future<void> _settingsTail = Future<void>.value();
  bool _isBusy = false;
  GameAudioAvailability _availability = GameAudioAvailability.checking;
  String? _errorMessage;
  String? _mutePreferenceErrorMessage;

  bool get isMuted => _isMuted;
  bool get backgroundPlaybackEnabled => _backgroundPlaybackEnabled;
  bool get effectiveMuted =>
      (_pendingMuted ?? _isMuted) ||
      (_isBackgrounded && !_backgroundPlaybackEnabled);
  bool get isBusy => _isBusy;
  GameAudioAvailability get availability => _availability;
  String? get errorMessage {
    final errors = <String>[?_errorMessage, ?_mutePreferenceErrorMessage];
    return errors.isEmpty ? null : errors.join('\n');
  }

  bool get canToggle =>
      _availability == GameAudioAvailability.available && !_isBusy;

  Future<void> attachPort(GameAudioPort port) async {
    if (_disposed) return;
    _port = port;
    final generation = ++_portGeneration;
    // A replaced WebView may never answer its old support or mute request.
    _nativeTail = Future<void>.value();
    _lastAppliedMuted = null;
    _availability = GameAudioAvailability.checking;
    _errorMessage = null;
    try {
      await _enqueueNative(() async {
        if (_disposed || generation != _portGeneration) return;
        final supported = await port.isSupported().timeout(
          _nativeOperationTimeout,
        );
        if (_disposed || generation != _portGeneration) return;
        _availability = supported
            ? GameAudioAvailability.available
            : GameAudioAvailability.unavailable;
        if (supported) await _reconcileNative();
      });
    } catch (error) {
      if (_disposed || generation != _portGeneration) return;
      _availability = GameAudioAvailability.unavailable;
      _errorMessage = '$gameAudioUnavailablePrefix$error';
    }
    if (generation == _portGeneration) _notify();
  }

  Future<void> toggleMuted() async {
    final port = _port;
    if (_disposed || port == null || !canToggle) {
      return;
    }

    final previous = _isMuted;
    final next = !previous;
    _pendingMuted = next;
    _isBusy = true;
    _errorMessage = null;
    _notify();
    await _enqueueSettings(() async {
      try {
        if (_disposed) return;
        Object? nativeError;
        try {
          await _applyEffectiveMuted();
        } catch (error) {
          nativeError = error;
        }
        if (_disposed) return;
        // A failed mute must retain the user's quiet target so a replacement
        // WebView or a later lifecycle retry can still apply it. A successful
        // native change is not undone merely because preference saving fails.
        if (nativeError == null || next) {
          _isMuted = next;
          _pendingMuted = null;
          try {
            await _store.writeMuted(next);
            _mutePreferenceErrorMessage = null;
          } catch (error) {
            _mutePreferenceErrorMessage = '$gameAudioSaveFailedPrefix$error';
          }
        } else {
          // An unmute that fails after a partial native effect must restore
          // the existing mute rather than opening audio on an error path.
          _isMuted = previous;
          _pendingMuted = null;
          try {
            await _applyEffectiveMuted();
          } catch (_) {}
        }
        if (nativeError != null) {
          _errorMessage = next
              ? '$gameAudioMutePendingPrefix$nativeError'
              : '$gameAudioToggleFailedPrefix$nativeError';
        }
      } finally {
        _pendingMuted = null;
        _isBusy = false;
        _notify();
      }
    });
  }

  Future<void> setBackgroundPlaybackEnabled(bool enabled) async {
    if (_disposed || _backgroundPlaybackEnabled == enabled) {
      return;
    }
    final revision = ++_backgroundRevision;
    _backgroundPlaybackEnabled = enabled;
    _errorMessage = null;
    _notify();
    await _enqueueSettings(() async {
      if (_disposed || revision != _backgroundRevision) return;
      final previous = _savedBackgroundPlaybackEnabled;
      try {
        await _store.writeBackgroundPlaybackEnabled(enabled);
        _savedBackgroundPlaybackEnabled = enabled;
        await _applyEffectiveMuted();
      } catch (error) {
        if (_disposed || revision != _backgroundRevision) return;
        _backgroundPlaybackEnabled = previous;
        try {
          await _store.writeBackgroundPlaybackEnabled(previous);
          _savedBackgroundPlaybackEnabled = previous;
        } catch (_) {}
        try {
          await _applyEffectiveMuted();
        } catch (_) {}
        if (_disposed || revision != _backgroundRevision) return;
        _errorMessage = '$gameAudioBackgroundSettingFailedPrefix$error';
        _notify();
      }
    });
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (_disposed) return;
    final backgrounded = switch (state) {
      AppLifecycleState.resumed => false,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached ||
      AppLifecycleState.inactive => true,
    };
    if (_isBackgrounded == backgrounded) return;
    _isBackgrounded = backgrounded;
    try {
      await _applyEffectiveMuted();
    } catch (error) {
      _errorMessage = '$gameAudioUnavailablePrefix$error';
      _notify();
    }
  }

  Future<void> _applyEffectiveMuted() => _enqueueNative(_reconcileNative);

  // Commands within one WebView remain ordered. Old WebView and timed-out
  // commands are repaired if their late effect contradicts the latest target.
  Future<void> _reconcileNative() async {
    while (!_disposed && _availability == GameAudioAvailability.available) {
      final port = _port;
      final generation = _portGeneration;
      final muted = effectiveMuted;
      if (port == null || _lastAppliedMuted == muted) return;
      _lastAppliedMuted = null;
      final operation = Future<void>.sync(() => port.setMuted(muted));
      final weakController = WeakReference(this);
      var retired = false;
      void reconcileLateEffect() {
        final controller = weakController.target;
        if (controller == null ||
            controller._disposed ||
            (!retired && generation == controller._portGeneration) ||
            muted == controller.effectiveMuted) {
          return;
        }
        // An error reply can also arrive after the native side effect.
        controller._lastAppliedMuted = null;
        unawaited(controller._applyEffectiveMuted().catchError((Object _) {}));
      }

      unawaited(
        operation.then<void>(
          (_) => reconcileLateEffect(),
          onError: (Object _) => reconcileLateEffect(),
        ),
      );
      try {
        await operation.timeout(_nativeOperationTimeout);
      } on TimeoutException {
        retired = true;
        if (_disposed) return;
        if (generation != _portGeneration) {
          await _settleReplacement();
          return;
        }
        _lastAppliedMuted = null;
        rethrow;
      } catch (_) {
        if (_disposed) return;
        if (generation != _portGeneration) {
          await _settleReplacement();
          return;
        }
        _lastAppliedMuted = null;
        rethrow;
      }
      if (_disposed) return;
      if (generation != _portGeneration) {
        await _settleReplacement();
        return;
      }
      _lastAppliedMuted = muted;
      _errorMessage = null;
      _notify();
    }
  }

  Future<void> _settleReplacement() async {
    await _applyEffectiveMuted().catchError((Object _) {});
  }

  Future<void> _enqueueNative(Future<void> Function() action) {
    final generation = _portGeneration;
    final result = _nativeTail.then<void>((_) async {
      if (_disposed || generation != _portGeneration) return;
      await action();
    });
    _nativeTail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _enqueueSettings(Future<void> Function() action) {
    final result = _settingsTail.then((_) => action());
    _settingsTail = result.catchError((Object _) {});
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_portGeneration;
    _port = null;
    super.dispose();
  }
}
