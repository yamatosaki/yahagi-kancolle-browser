import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_port.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';

void main() {
  test('timed-out manual mute never rolls back into an unmute command', () {
    fakeAsync((clock) {
      final controller = _load(clock);
      final gate = Completer<void>();
      final effect = _AudioEffect();
      final port = _AudioPort(
        effect,
        apply: (_, attempt) =>
            attempt == 2 ? gate.future : Future<void>.value(),
      );
      unawaited(controller.attachPort(port));
      clock.flushMicrotasks();
      unawaited(controller.toggleMuted());
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 6));

      expect(controller.isMuted, isTrue);
      expect(controller.effectiveMuted, isTrue);
      expect(controller.errorMessage, isNotNull);
      expect(controller.isBusy, isFalse);
      expect(port.requests, [false, true]);
      gate.complete();
      clock.flushMicrotasks();
      expect(effect.muted, isTrue);

      unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
      clock.flushMicrotasks();
      unawaited(controller.handleLifecycleState(AppLifecycleState.resumed));
      clock.flushMicrotasks();
      expect(effect.muted, isTrue);
      expect(port.requests.skip(1), everyElement(isTrue));
      controller.dispose();
    });
  });

  test('late failed manual unmute cannot reopen the restored mute', () {
    fakeAsync((clock) {
      final controller = _load(clock);
      final gate = Completer<void>();
      final effect = _AudioEffect();
      final port = _AudioPort(
        effect,
        apply: (_, attempt) =>
            attempt == 3 ? gate.future : Future<void>.value(),
      );
      unawaited(controller.attachPort(port));
      clock.flushMicrotasks();
      unawaited(controller.toggleMuted());
      clock.flushMicrotasks();
      expect(effect.muted, isTrue);

      unawaited(controller.toggleMuted());
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 6));
      expect(controller.isMuted, isTrue);
      expect(controller.effectiveMuted, isTrue);
      expect(effect.muted, isTrue);
      expect(port.requests, [false, true, false, true]);

      // The old unmute applies only after its timeout and mute restoration.
      // Its late effect must be repaired using the current manual mute target.
      gate.complete();
      clock.flushMicrotasks();
      expect(controller.isMuted, isTrue);
      expect(effect.muted, isTrue);
      expect(port.requests, [false, true, false, true, true]);
      final calls = port.requests.length;
      clock.elapse(const Duration(minutes: 1));
      expect(port.requests, hasLength(calls));
      controller.dispose();
    });
  });

  test('a hung old support probe cannot hold replacement audio attachment', () {
    fakeAsync((clock) {
      final controller = _load(clock);
      final oldProbe = Completer<bool>();
      final effect = _AudioEffect();
      final oldPort = _AudioPort(effect, support: () => oldProbe.future);
      final replacement = _AudioPort(effect);
      var attached = false;
      unawaited(controller.attachPort(oldPort));
      clock.flushMicrotasks();
      unawaited(
        controller.attachPort(replacement).then((_) => attached = true),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 6));

      expect(attached, isTrue);
      expect(controller.availability, GameAudioAvailability.available);
      expect(replacement.requests, <bool>[false]);
      oldProbe.complete(true);
      clock.flushMicrotasks();
      expect(oldPort.requests, isEmpty);
      controller.dispose();
    });
  });

  test('a hung background mute cannot block sound restoration on resume', () {
    fakeAsync((clock) {
      final controller = _load(clock);
      final gate = Completer<void>();
      final effect = _AudioEffect();
      final port = _AudioPort(
        effect,
        apply: (muted, attempt) =>
            attempt == 2 ? gate.future : Future<void>.value(),
      );
      unawaited(controller.attachPort(port));
      clock.flushMicrotasks();
      unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
      clock.flushMicrotasks();
      var resumed = false;
      unawaited(
        controller
            .handleLifecycleState(AppLifecycleState.resumed)
            .then((_) => resumed = true),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 6));

      expect(resumed, isTrue);
      expect(port.requests, <bool>[false, true, false]);
      expect(effect.muted, isFalse);
      gate.complete();
      clock.flushMicrotasks();
      expect(effect.muted, isFalse);
      expect(port.requests, <bool>[false, true, false, false]);
      controller.dispose();
    });
  });

  test(
    'a late foreground unmute is corrected after returning to background',
    () {
      fakeAsync((clock) {
        final controller = _load(clock);
        final gate = Completer<void>();
        final effect = _AudioEffect();
        final port = _AudioPort(
          effect,
          apply: (_, attempt) =>
              attempt == 3 ? gate.future : Future<void>.value(),
        );
        unawaited(controller.attachPort(port));
        clock.flushMicrotasks();
        unawaited(controller.handleLifecycleState(AppLifecycleState.inactive));
        clock.flushMicrotasks();
        unawaited(controller.handleLifecycleState(AppLifecycleState.resumed));
        clock.flushMicrotasks();
        unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 6));

        expect(effect.muted, isTrue);
        expect(port.requests, <bool>[false, true, false, true]);
        gate.complete();
        clock.flushMicrotasks();
        expect(effect.muted, isTrue);
        expect(port.requests, <bool>[false, true, false, true, true]);
        final calls = port.requests.length;
        clock.elapse(const Duration(minutes: 1));
        expect(port.requests, hasLength(calls));
        controller.dispose();
      });
    },
  );

  for (final backgrounded in <bool>[false, true]) {
    test(
      'late error after an audio effect preserves background=$backgrounded',
      () {
        fakeAsync((clock) {
          final controller = _load(clock);
          final gate = Completer<void>();
          final effect = _AudioEffect();
          final heldAttempt = backgrounded ? 3 : 2;
          final port = _AudioPort(
            effect,
            apply: (_, attempt) =>
                attempt == heldAttempt ? gate.future : Future<void>.value(),
          );
          unawaited(controller.attachPort(port));
          clock.flushMicrotasks();
          unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
          clock.flushMicrotasks();
          unawaited(controller.handleLifecycleState(AppLifecycleState.resumed));
          clock.flushMicrotasks();
          if (backgrounded) {
            unawaited(
              controller.handleLifecycleState(AppLifecycleState.paused),
            );
            clock.flushMicrotasks();
          }
          clock.elapse(const Duration(seconds: 6));
          expect(effect.muted, backgrounded);

          effect.muted = !backgrounded;
          gate.completeError(StateError('native failed after applying'));
          clock.flushMicrotasks();
          expect(effect.muted, backgrounded);
          expect(controller.effectiveMuted, backgrounded);
          final calls = port.requests.length;
          clock.elapse(const Duration(minutes: 1));
          expect(port.requests, hasLength(calls));
          controller.dispose();
        });
      },
    );
  }

  test('old same-target acknowledgement cannot hide current audio failure', () {
    fakeAsync((clock) {
      final controller = _load(clock);
      final gate = Completer<void>();
      final effect = _AudioEffect();
      final port = _AudioPort(
        effect,
        effectAfterReply: false,
        apply: (muted, attempt) {
          if (attempt == 4) {
            return Future<void>.error(StateError('new mute denied'));
          }
          effect.muted = muted;
          return attempt == 2 ? gate.future : Future<void>.value();
        },
      );
      unawaited(controller.attachPort(port));
      clock.flushMicrotasks();
      unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
      clock.flushMicrotasks();
      unawaited(controller.handleLifecycleState(AppLifecycleState.resumed));
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 6));
      unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
      clock.flushMicrotasks();
      expect(effect.muted, isFalse);
      expect(controller.errorMessage, isNotNull);
      gate.complete();
      clock.flushMicrotasks();

      expect(effect.muted, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(port.requests, <bool>[false, true, false, true]);
      controller.dispose();
    });
  });

  test('microtask port replacement never skips the new background mute', () {
    for (var microtasks = 0; microtasks < 16; microtasks++) {
      fakeAsync((clock) {
        final controller = _load(clock);
        final gate = Completer<void>();
        final oldPort = _AudioPort(
          _AudioEffect(),
          apply: (_, attempt) =>
              attempt == 2 ? gate.future : Future<void>.value(),
        );
        final replacementEffect = _AudioEffect()..muted = false;
        final replacement = _AudioPort(replacementEffect);
        unawaited(controller.attachPort(oldPort));
        clock.flushMicrotasks();
        unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
        clock.flushMicrotasks();
        gate.complete();
        _afterMicrotasks(microtasks, () {
          unawaited(controller.attachPort(replacement));
        });
        clock.flushMicrotasks();

        expect(
          replacement.requests,
          <bool>[true],
          reason: 'replacement at microtask $microtasks requires a real write',
        );
        expect(replacementEffect.muted, isTrue);
        controller.dispose();
      });
    }
  });

  test('microtask disposal cannot receive a late audio notification', () {
    for (var microtasks = 0; microtasks < 16; microtasks++) {
      fakeAsync((clock) {
        final controller = _load(clock);
        final gate = Completer<void>();
        final port = _AudioPort(
          _AudioEffect(),
          apply: (_, attempt) =>
              attempt == 2 ? gate.future : Future<void>.value(),
        );
        var disposed = false;
        var lateNotifications = 0;
        controller.addListener(() {
          if (disposed) lateNotifications++;
        });
        unawaited(controller.attachPort(port));
        clock.flushMicrotasks();
        unawaited(controller.handleLifecycleState(AppLifecycleState.paused));
        clock.flushMicrotasks();
        gate.complete();
        _afterMicrotasks(microtasks, () {
          disposed = true;
          controller.dispose();
        });
        clock.flushMicrotasks();

        expect(disposed, isTrue);
        expect(
          lateNotifications,
          0,
          reason: 'dispose at microtask $microtasks',
        );
        final calls = port.requests.length;
        clock.elapse(const Duration(minutes: 1));
        expect(port.requests, hasLength(calls));
      });
    }
  });

  test('1000 audio schedules restore the independent lifecycle mute target', () {
    var totalCommands = 0;
    var maximumCommands = 0;
    for (var seed = 0; seed < 1000; seed++) {
      fakeAsync((clock) {
        final random = Random(seed);
        final controller = _load(clock);
        final native = _ScheduledAudioNative();
        final trace = <String>[];
        var expectedBackgrounded = false;
        unawaited(controller.attachPort(_ScheduledAudioPort(native)));
        clock.flushMicrotasks();
        for (var step = 0; step < 40; step++) {
          switch (random.nextInt(10)) {
            case 0 || 1 || 2 || 3:
              final state = AppLifecycleState.values[random.nextInt(5)];
              expectedBackgrounded = state != AppLifecycleState.resumed;
              trace.add('life ${state.name}');
              unawaited(controller.handleLifecycleState(state));
            case 4:
              trace.add('replace port');
              unawaited(controller.attachPort(_ScheduledAudioPort(native)));
            case 5:
              if (native.pending.isNotEmpty) {
                final command =
                    native.pending[random.nextInt(native.pending.length)];
                trace.add('effect #${command.id} ${command.muted}');
                native.apply(command);
              }
            case 6 || 7:
              if (native.pending.isNotEmpty) {
                final command =
                    native.pending[random.nextInt(native.pending.length)];
                final fail = random.nextInt(4) == 0;
                trace.add('ack #${command.id} fail=$fail');
                native.reply(command, fail: fail);
              }
            case 8:
              final seconds = random.nextInt(7);
              trace.add('wait $seconds');
              clock.elapse(Duration(seconds: seconds));
            case 9:
              if (native.commands.isNotEmpty) {
                final command =
                    native.commands[random.nextInt(native.commands.length)];
                if (command.receipt.isCompleted) {
                  trace.add('duplicate #${command.id}');
                  native.reply(command);
                }
              }
          }
          clock.flushMicrotasks();
          expect(
            controller.effectiveMuted,
            expectedBackgrounded,
            reason: 'seed=$seed step=$step independent mute policy',
          );
          expect(
            native.commands.length,
            lessThan(300),
            reason: 'seed=$seed unbounded calls',
          );
        }
        native.succeedNewCommands = true;
        expectedBackgrounded = seed.isOdd;
        unawaited(
          controller.handleLifecycleState(
            expectedBackgrounded
                ? AppLifecycleState.paused
                : AppLifecycleState.resumed,
          ),
        );
        unawaited(controller.attachPort(_ScheduledAudioPort(native)));
        clock.flushMicrotasks();
        for (var step = 0; step < 500 && native.pending.isNotEmpty; step++) {
          native.reply(native.pending[random.nextInt(native.pending.length)]);
          clock.flushMicrotasks();
        }
        clock.elapse(const Duration(seconds: 6));
        expect(
          native.muted,
          expectedBackgrounded,
          reason: 'seed=$seed final native effect\n${trace.join('\n')}',
        );
        expect(
          native.pending,
          isEmpty,
          reason: 'seed=$seed pending native calls',
        );
        expect(controller.availability, GameAudioAvailability.available);
        final calls = native.commands.length;
        totalCommands += calls;
        maximumCommands = max(maximumCommands, calls);
        clock.elapse(const Duration(minutes: 1));
        expect(
          native.commands,
          hasLength(calls),
          reason: 'seed=$seed idle polling',
        );
        controller.dispose();
        clock.flushMicrotasks();
      });
    }
    debugPrint(
      'audio stress: seeds=0..999, actions=40000, nativeCommands=$totalCommands, '
      'maxCommandsPerScenario=$maximumCommands',
    );
  });
}

void _afterMicrotasks(int remaining, void Function() action) {
  if (remaining == 0) {
    action();
  } else {
    scheduleMicrotask(() => _afterMicrotasks(remaining - 1, action));
  }
}

GameAudioController _load(FakeAsync clock) {
  GameAudioController? result;
  unawaited(
    GameAudioController.load(_AudioStore()).then((value) => result = value),
  );
  clock.flushMicrotasks();
  return result!;
}

final class _AudioEffect {
  bool? muted;
}

final class _AudioPort implements GameAudioPort {
  _AudioPort(
    this.effect, {
    this.support,
    this.apply,
    this.effectAfterReply = true,
  });

  final _AudioEffect effect;
  final Future<bool> Function()? support;
  final Future<void> Function(bool muted, int attempt)? apply;
  final bool effectAfterReply;
  final List<bool> requests = [];

  @override
  Future<bool> isSupported() => support?.call() ?? Future<bool>.value(true);

  @override
  Future<void> setMuted(bool muted) async {
    requests.add(muted);
    await (apply?.call(muted, requests.length) ?? Future<void>.value());
    if (effectAfterReply) effect.muted = muted;
  }
}

final class _AudioStore implements GameAudioStore {
  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => false;

  @override
  Future<bool?> readMuted() async => false;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {}

  @override
  Future<void> writeMuted(bool muted) async {}
}

final class _AudioCommand {
  _AudioCommand(this.id, this.muted);

  final int id;
  final bool muted;
  final Completer<void> receipt = Completer<void>();
  bool applied = false;
}

final class _ScheduledAudioNative {
  final List<_AudioCommand> commands = [];
  bool? muted;
  bool succeedNewCommands = false;

  List<_AudioCommand> get pending =>
      commands.where((command) => !command.receipt.isCompleted).toList();

  Future<void> setMuted(bool value) {
    final command = _AudioCommand(commands.length, value);
    commands.add(command);
    if (succeedNewCommands) reply(command);
    return command.receipt.future;
  }

  void apply(_AudioCommand command) {
    if (command.applied || command.receipt.isCompleted) return;
    command.applied = true;
    muted = command.muted;
  }

  void reply(_AudioCommand command, {bool fail = false}) {
    if (command.receipt.isCompleted) return;
    if (fail) {
      command.receipt.completeError(StateError('native mute rejected'));
    } else {
      apply(command);
      command.receipt.complete();
    }
  }
}

final class _ScheduledAudioPort implements GameAudioPort {
  _ScheduledAudioPort(this.native);

  final _ScheduledAudioNative native;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> setMuted(bool muted) => native.setMuted(muted);
}
