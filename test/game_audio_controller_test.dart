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

  test('keeps the old state when the native mute call fails', () async {
    final store = _MemoryAudioStore();
    final port = _RecordingAudioPort();
    final controller = await GameAudioController.load(store);
    await controller.attachPort(port);
    port.failSetMuted = true;

    await controller.toggleMuted();

    expect(controller.isMuted, isFalse);
    expect(store.savedMuted, isNull);
    expect(controller.errorMessage, isNotNull);
  });

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
    'background lifecycle never mutes the WebView so the game keeps running',
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
      expect(port.mutedValues, isEmpty);
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
    'a port attached while backgrounded preserves the user sound setting',
    () async {
      final port = _RecordingAudioPort();
      final controller = await GameAudioController.load(_MemoryAudioStore());

      await controller.handleLifecycleState(AppLifecycleState.paused);
      await controller.attachPort(port);

      expect(port.mutedValues, <bool>[false]);
    },
  );
}

final class _MemoryAudioStore implements GameAudioStore {
  bool? savedMuted;
  bool? savedBackgroundPlayback;

  @override
  Future<bool?> readMuted() async => savedMuted;

  @override
  Future<void> writeMuted(bool muted) async {
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
  final List<bool> mutedValues = [];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> setMuted(bool muted) async {
    if (failSetMuted) {
      throw StateError('native mute failed');
    }
    mutedValues.add(muted);
  }
}
