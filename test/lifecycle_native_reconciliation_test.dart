import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_port.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_awake_controller.dart';

void main() {
  test('audio converges after resume overtakes a pending pause', () async {
    final store = _AudioStore();
    final native = _NativeFlag();
    final port = _AudioPort(native);
    final controller = await GameAudioController.load(store);
    addTearDown(controller.dispose);
    await controller.attachPort(port);
    final gate = port.delayNextSet();
    final pause = controller.handleLifecycleState(AppLifecycleState.paused);
    await gate.started.future;
    final resume = controller.handleLifecycleState(AppLifecycleState.resumed);
    gate.release.complete();
    await Future.wait([pause, resume]);
    expect(native.value, isFalse);
    expect(controller.isMuted, isFalse);
    expect(store.muted, isNull);
  });

  test(
    'audio replacement applies after the old native effect completes',
    () async {
      final native = _NativeFlag();
      final old = _AudioPort(native);
      final replacement = _AudioPort(native);
      final controller = await GameAudioController.load(_AudioStore());
      addTearDown(controller.dispose);
      await controller.attachPort(old);
      final gate = old.delayNextSet();
      final pause = controller.handleLifecycleState(AppLifecycleState.paused);
      await gate.started.future;
      final attach = controller.attachPort(replacement);
      final resume = controller.handleLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      gate.release.complete();
      await Future.wait([pause, attach, resume]);
      expect(native.value, isFalse);
      expect(replacement.values.last, isFalse);
      expect(controller.availability, GameAudioAvailability.available);
    },
  );

  test(
    'audio preference failure keeps manual mute through lifecycle changes',
    () async {
      final store = _AudioStore()..muteWriteGate = _Gate();
      final native = _NativeFlag();
      final controller = await GameAudioController.load(store);
      addTearDown(controller.dispose);
      await controller.attachPort(_AudioPort(native));
      final toggle = controller.toggleMuted();
      await store.muteWriteGate!.started.future;
      await controller.handleLifecycleState(AppLifecycleState.paused);
      store.muteWriteGate!.release.completeError(StateError('save failed'));
      await toggle;
      expect(controller.isMuted, isTrue);
      expect(controller.errorMessage, isNotNull);
      expect(
        native.value,
        isTrue,
        reason: 'failed persistence must not erase the manual mute target',
      );
      await controller.handleLifecycleState(AppLifecycleState.resumed);
      expect(native.value, isTrue);
      expect(controller.errorMessage, isNotNull);
    },
  );

  test(
    'audio rapid background policy changes retain the newest preference',
    () async {
      final store = _AudioStore()..backgroundWriteGate = _Gate();
      final controller = await GameAudioController.load(store);
      addTearDown(controller.dispose);
      final native = _NativeFlag();
      await controller.attachPort(_AudioPort(native));
      await controller.handleLifecycleState(AppLifecycleState.paused);
      final first = controller.setBackgroundPlaybackEnabled(true);
      await store.backgroundWriteGate!.started.future;
      final latest = controller.setBackgroundPlaybackEnabled(false);
      store.backgroundWriteGate!.release.complete();
      await Future.wait([first, latest]);
      expect(store.background, isFalse);
      expect(controller.backgroundPlaybackEnabled, isFalse);
      expect(native.value, isTrue);
    },
  );

  test(
    'audio disposed during native call does not notify or enqueue again',
    () async {
      final native = _NativeFlag();
      final port = _AudioPort(native);
      final controller = await GameAudioController.load(_AudioStore());
      await controller.attachPort(port);
      final gate = port.delayNextSet();
      final pause = controller.handleLifecycleState(AppLifecycleState.paused);
      await gate.started.future;
      controller.dispose();
      gate.release.complete();
      await expectLater(pause, completes);
    },
  );

  test('awake converges after resume overtakes pending disable', () async {
    final store = _AwakeStore()..value = true;
    final native = _NativeFlag();
    final port = _AwakePort(native);
    final controller = await ScreenAwakeController.load(store);
    addTearDown(controller.dispose);
    await controller.attachPort(port);
    final gate = port.delayNextSet();
    final pause = controller.handleLifecycleState(AppLifecycleState.paused);
    await gate.started.future;
    final resume = controller.handleLifecycleState(AppLifecycleState.resumed);
    gate.release.complete();
    await Future.wait([pause, resume]);
    expect(native.value, isTrue);
    expect(controller.enabled, isTrue);
    expect(store.value, isTrue);
  });

  test('awake replacement wins after old flag update completes', () async {
    final native = _NativeFlag();
    final old = _AwakePort(native);
    final replacement = _AwakePort(native);
    final controller = await ScreenAwakeController.load(
      _AwakeStore()..value = true,
    );
    addTearDown(controller.dispose);
    await controller.attachPort(old);
    final gate = old.delayNextSet();
    final pause = controller.handleLifecycleState(AppLifecycleState.paused);
    await gate.started.future;
    final attach = controller.attachPort(replacement);
    final resume = controller.handleLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    gate.release.complete();
    await Future.wait([pause, attach, resume]);
    expect(native.value, isTrue);
    expect(replacement.values.last, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('awake rapid preference writes persist the newest value', () async {
    final store = _AwakeStore()..writeGate = _Gate();
    final native = _NativeFlag();
    final controller = await ScreenAwakeController.load(store);
    addTearDown(controller.dispose);
    await controller.attachPort(_AwakePort(native));
    final first = controller.setEnabled(true);
    await store.writeGate!.started.future;
    final latest = controller.setEnabled(false);
    store.writeGate!.release.complete();
    await Future.wait([first, latest]);
    expect(store.value, isFalse);
    expect(controller.enabled, isFalse);
    expect(native.value, isFalse);
  });

  test('awake rollback write failure remains a reported error', () async {
    final store = _AwakeStore()..failWrites = true;
    final controller = await ScreenAwakeController.load(store);
    addTearDown(controller.dispose);
    final native = _NativeFlag();
    await controller.attachPort(_AwakePort(native));
    await expectLater(controller.setEnabled(true), completes);
    expect(controller.enabled, isFalse);
    expect(controller.errorMessage, isNotNull);
    expect(native.value, isFalse);
  });

  test('awake disposed during native call does not notify again', () async {
    final port = _AwakePort(_NativeFlag());
    final controller = await ScreenAwakeController.load(
      _AwakeStore()..value = true,
    );
    await controller.attachPort(port);
    final gate = port.delayNextSet();
    final pause = controller.handleLifecycleState(AppLifecycleState.paused);
    await gate.started.future;
    controller.dispose();
    gate.release.complete();
    await expectLater(pause, completes);
  });
}

class _Gate {
  final started = Completer<void>();
  final release = Completer<void>();
  Future<void> wait() {
    started.complete();
    return release.future;
  }
}

class _NativeFlag {
  bool value = false;
}

class _FlagPort {
  _FlagPort(this.native);
  final _NativeFlag native;
  final values = <bool>[];
  _Gate? _next;
  _Gate delayNextSet() => _next = _Gate();
  Future<void> write(bool value) async {
    final gate = _next;
    _next = null;
    values.add(value);
    if (gate != null) await gate.wait();
    native.value = value;
  }
}

class _AudioPort extends _FlagPort implements GameAudioPort {
  _AudioPort(super.native);
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<void> setMuted(bool value) => write(value);
}

class _AwakePort extends _FlagPort implements ScreenAwakePort {
  _AwakePort(super.native);
  @override
  Future<bool> isEnabled() async => native.value;
  @override
  Future<void> setEnabled(bool value) => write(value);
}

class _AudioStore implements GameAudioStore {
  bool? muted;
  bool? background;
  _Gate? muteWriteGate;
  _Gate? backgroundWriteGate;
  bool _blockedMute = false;
  bool _blockedBackground = false;
  @override
  Future<bool?> readMuted() async => muted;
  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => background;
  @override
  Future<void> writeMuted(bool value) async {
    if (!_blockedMute && muteWriteGate != null) {
      _blockedMute = true;
      await muteWriteGate!.wait();
    }
    muted = value;
  }

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool value) async {
    if (!_blockedBackground && backgroundWriteGate != null) {
      _blockedBackground = true;
      await backgroundWriteGate!.wait();
    }
    background = value;
  }
}

class _AwakeStore implements ScreenAwakeStore {
  bool? value;
  _Gate? writeGate;
  bool _blocked = false;
  bool failWrites = false;
  @override
  Future<bool?> readEnabled() async => value;
  @override
  Future<void> writeEnabled(bool enabled) async {
    if (failWrites) throw StateError('save failed');
    if (!_blocked && writeGate != null) {
      _blocked = true;
      await writeGate!.wait();
    }
    value = enabled;
  }
}
