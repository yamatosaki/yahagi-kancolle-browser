import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_port.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';

void main() {
  test('defaults to sound on when no preference exists', () async {
    final controller = await GameAudioController.load(_MemoryAudioStore());

    expect(controller.isMuted, isFalse);
    expect(controller.availability, GameAudioAvailability.checking);
  });

  test('restores and applies a saved muted preference when attached', () async {
    final store = _MemoryAudioStore()..savedMuted = true;
    final port = _RecordingAudioPort();
    final controller = await GameAudioController.load(store);

    await controller.attachPort(port);

    expect(controller.isMuted, isTrue);
    expect(controller.availability, GameAudioAvailability.available);
    expect(port.mutedValues, [true]);
  });

  test('toggles through the port before saving and updating state', () async {
    final store = _MemoryAudioStore();
    final port = _RecordingAudioPort();
    final controller = await GameAudioController.load(store);
    await controller.attachPort(port);
    port.mutedValues.clear();

    await controller.toggleMuted();

    expect(port.mutedValues, [true]);
    expect(store.savedMuted, isTrue);
    expect(controller.isMuted, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('retains manual mute intent when the native mute call fails', () async {
    final store = _MemoryAudioStore();
    final port = _RecordingAudioPort();
    final controller = await GameAudioController.load(store);
    await controller.attachPort(port);
    port.failSetMuted = true;

    await controller.toggleMuted();

    expect(controller.isMuted, isTrue);
    expect(controller.effectiveMuted, isTrue);
    expect(store.savedMuted, isTrue);
    expect(controller.errorMessage, isNotNull);

    port.failSetMuted = false;
    await controller.handleLifecycleState(AppLifecycleState.paused);
    await controller.handleLifecycleState(AppLifecycleState.resumed);
    expect(port.actualMuted, isTrue);
    expect(port.requests.skip(1), everyElement(isTrue));
    expect(controller.errorMessage, isNull);
  });

  test(
    'failed preference saving never reopens a successfully muted game',
    () async {
      final store = _MemoryAudioStore()
        ..muteWriteError = StateError('save failed');
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(store);
      addTearDown(controller.dispose);
      await controller.attachPort(port);
      port.requests.clear();

      await controller.toggleMuted();

      expect(controller.isMuted, isTrue);
      expect(controller.effectiveMuted, isTrue);
      expect(port.actualMuted, isTrue);
      expect(port.requests, [true]);
      expect(store.savedMuted, isNull);
      expect(controller.errorMessage, contains('save failed'));
      await controller.handleLifecycleState(AppLifecycleState.paused);
      await controller.handleLifecycleState(AppLifecycleState.resumed);
      expect(port.actualMuted, isTrue);
      expect(port.requests, [true]);
      expect(controller.errorMessage, contains('save failed'));
    },
  );

  test(
    'replacement port preserves manual mute after failed preference saving',
    () async {
      final store = _MemoryAudioStore()
        ..muteWriteError = StateError('save failed');
      final controller = await GameAudioController.load(store);
      addTearDown(controller.dispose);
      await controller.attachPort(_RecordingAudioPort());
      await controller.toggleMuted();
      final replacement = _RecordingAudioPort();

      await controller.attachPort(replacement);

      expect(controller.isMuted, isTrue);
      expect(replacement.requests, [true]);
      expect(replacement.actualMuted, isTrue);
      expect(controller.errorMessage, contains('save failed'));
    },
  );

  test(
    'a failed unmute cannot discard an earlier unsaved mute warning',
    () async {
      final store = _MemoryAudioStore()
        ..savedMuted = false
        ..muteWriteError = StateError('mute save failed');
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(store);
      addTearDown(controller.dispose);
      await controller.attachPort(port);
      await controller.toggleMuted();
      expect(controller.isMuted, isTrue);
      expect(store.savedMuted, isFalse);
      expect(controller.errorMessage, contains('mute save failed'));

      port.failSetMuted = true;
      await controller.toggleMuted();
      expect(controller.isMuted, isTrue);
      expect(store.savedMuted, isFalse);
      final replacement = _RecordingAudioPort();
      await controller.attachPort(replacement);
      await controller.handleLifecycleState(AppLifecycleState.paused);
      await controller.handleLifecycleState(AppLifecycleState.resumed);
      expect(controller.isMuted, isTrue);
      expect(replacement.actualMuted, isTrue);
      expect(controller.errorMessage, contains('mute save failed'));

      // Only a successful preference write can clear the persistence warning.
      store.muteWriteError = null;
      await controller.toggleMuted();
      expect(controller.isMuted, isFalse);
      expect(store.savedMuted, isFalse);
      expect(controller.errorMessage, isNull);
    },
  );

  test(
    'failed unmute restores mute even when the native failure applied first',
    () async {
      final store = _MemoryAudioStore()..savedMuted = true;
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(store);
      addTearDown(controller.dispose);
      await controller.attachPort(port);
      port.requests.clear();
      port.failSetMuted = true;
      port.applyBeforeFailure = true;

      await controller.toggleMuted();

      expect(controller.isMuted, isTrue);
      expect(controller.effectiveMuted, isTrue);
      expect(store.savedMuted, isTrue);
      expect(port.requests, [false, true]);
      expect(port.actualMuted, isTrue);
      expect(controller.errorMessage, contains('native mute failed'));
    },
  );

  test(
    'explicit successful unmute is kept when preference saving fails',
    () async {
      final store = _MemoryAudioStore()
        ..savedMuted = true
        ..muteWriteError = StateError('save failed');
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(store);
      addTearDown(controller.dispose);
      await controller.attachPort(port);
      port.requests.clear();

      await controller.toggleMuted();

      expect(controller.isMuted, isFalse);
      expect(controller.effectiveMuted, isFalse);
      expect(port.actualMuted, isFalse);
      expect(port.requests, [false]);
      expect(store.savedMuted, isTrue);
      expect(controller.errorMessage, contains('save failed'));
      await controller.handleLifecycleState(AppLifecycleState.paused);
      await controller.handleLifecycleState(AppLifecycleState.resumed);
      expect(port.actualMuted, isFalse);
      expect(controller.errorMessage, contains('save failed'));
    },
  );

  test('reports unsupported without changing system or saved state', () async {
    final store = _MemoryAudioStore();
    final port = _RecordingAudioPort()..supported = false;
    final controller = await GameAudioController.load(store);

    await controller.attachPort(port);
    await controller.toggleMuted();

    expect(controller.availability, GameAudioAvailability.unavailable);
    expect(controller.isMuted, isFalse);
    expect(store.savedMuted, isNull);
    expect(port.mutedValues, isEmpty);
  });

  test(
    'background playback defaults off and restores sound on resume',
    () async {
      final store = _MemoryAudioStore();
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(store);
      await controller.attachPort(port);
      port.mutedValues.clear();

      await controller.handleLifecycleState(AppLifecycleState.paused);
      await controller.handleLifecycleState(AppLifecycleState.resumed);

      expect(controller.backgroundPlaybackEnabled, isFalse);
      expect(controller.isMuted, isFalse);
      expect(port.mutedValues, <bool>[true, false]);
    },
  );

  test(
    'background playback defaults off and mutes as soon as app is inactive',
    () async {
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(_MemoryAudioStore());
      await controller.attachPort(port);
      port.mutedValues.clear();

      await controller.handleLifecycleState(AppLifecycleState.inactive);

      expect(port.mutedValues, <bool>[true]);
    },
  );

  test(
    'background playback opt-in persists and leaves sound enabled',
    () async {
      final store = _MemoryAudioStore();
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(store);
      await controller.attachPort(port);

      await controller.setBackgroundPlaybackEnabled(true);
      port.mutedValues.clear();
      await controller.handleLifecycleState(AppLifecycleState.inactive);
      await controller.handleLifecycleState(AppLifecycleState.hidden);
      await controller.handleLifecycleState(AppLifecycleState.paused);

      expect(store.savedBackgroundPlayback, isTrue);
      expect(port.mutedValues, isEmpty);
    },
  );

  test('user mute remains effective after returning to foreground', () async {
    final store = _MemoryAudioStore()..savedMuted = true;
    final port = _RecordingAudioPort();
    final controller = await GameAudioController.load(store);
    await controller.attachPort(port);
    port.mutedValues.clear();

    await controller.handleLifecycleState(AppLifecycleState.detached);
    await controller.handleLifecycleState(AppLifecycleState.resumed);

    expect(controller.isMuted, isTrue);
    expect(port.mutedValues, isEmpty);
  });

  test(
    'a port attached while backgrounded respects background playback setting',
    () async {
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(_MemoryAudioStore());

      await controller.handleLifecycleState(AppLifecycleState.paused);
      await controller.attachPort(port);

      expect(port.mutedValues, <bool>[true]);
    },
  );
}

final class _MemoryAudioStore implements GameAudioStore {
  bool? savedMuted;
  bool? savedBackgroundPlayback;
  Object? muteWriteError;

  @override
  Future<bool?> readMuted() async => savedMuted;

  @override
  Future<void> writeMuted(bool muted) async {
    if (muteWriteError case final error?) throw error;
    savedMuted = muted;
  }

  @override
  Future<bool?> readBackgroundPlaybackEnabled() async =>
      savedBackgroundPlayback;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {
    savedBackgroundPlayback = enabled;
  }
}

final class _RecordingAudioPort implements GameAudioPort {
  bool supported = true;
  bool failSetMuted = false;
  bool applyBeforeFailure = false;
  bool? actualMuted;
  final List<bool> requests = [];
  final List<bool> mutedValues = [];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> setMuted(bool muted) async {
    requests.add(muted);
    if (applyBeforeFailure) actualMuted = muted;
    if (failSetMuted) {
      throw StateError('native mute failed');
    }
    mutedValues.add(muted);
    actualMuted = muted;
  }
}
