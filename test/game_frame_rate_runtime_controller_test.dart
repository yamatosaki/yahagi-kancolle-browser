import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_runtime_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';

void main() {
  test('does not sample before the game page is ready', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    fixture.runtime.onPageStarted();

    expect(fixture.timer, isNull);
    expect(fixture.port.measurementCalls, 0);
    expect(fixture.port.appliedTargets, isEmpty);
  });

  test(
    'automatic mode starts at 60 and samples at most once per tick',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      await fixture.runtime.onPageReady();
      fixture.timer!.fire();
      await fixture.runtime.idle;

      expect(fixture.port.appliedTargets, <GameFrameRateTarget>[
        GameFrameRateTarget.fps60,
      ]);
      expect(fixture.port.measurementCalls, 1);
    },
  );

  test('two unstable windows apply 30 FPS once and lock the session', () async {
    final fixture = await _Fixture.create(
      measurements: <double>[49, 48, 47, 55, 56, 49, 48, 47, 55, 56],
    );
    addTearDown(fixture.dispose);

    await fixture.runtime.onPageReady();
    for (var index = 0; index < 10; index++) {
      fixture.timer!.fire();
      await fixture.runtime.idle;
    }

    expect(fixture.port.appliedTargets, <GameFrameRateTarget>[
      GameFrameRateTarget.fps60,
      GameFrameRateTarget.fps30,
    ]);
    expect(fixture.timer!.isActive, isFalse);

    fixture.runtime.onPageStarted();
    await fixture.runtime.onPageReady();
    expect(fixture.port.appliedTargets.last, GameFrameRateTarget.fps30);
  });

  test(
    'records Flutter timings only while automatic sampling is active',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);

      fixture.runtime.recordFlutterFrame(const Duration(milliseconds: 40));
      expect(fixture.runtime.policy.flutterFrameCount, 0);

      await fixture.runtime.onPageReady();
      fixture.runtime.recordFlutterFrame(const Duration(milliseconds: 40));
      expect(fixture.runtime.policy.flutterFrameCount, 1);
    },
  );

  test('a player mode change applies immediately without reloading', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    await fixture.runtime.onPageReady();

    await fixture.settings.setMode(GameFrameRateMode.stable30);
    await fixture.runtime.idle;

    expect(fixture.port.appliedTargets.last, GameFrameRateTarget.fps30);
    expect(fixture.timer!.isActive, isFalse);
  });

  test('dispose cancels timers and unregisters the timings callback', () async {
    final fixture = await _Fixture.create();
    await fixture.runtime.onPageReady();

    fixture.runtime.dispose();

    expect(fixture.timer!.isActive, isFalse);
    expect(fixture.removedTimingCallback, same(fixture.addedTimingCallback));
    fixture.settings.dispose();
  });
}

final class _Fixture {
  _Fixture._({
    required this.settings,
    required this.port,
    required this.runtime,
    required this.timerFactory,
  });

  final GameFrameRateSettingsController settings;
  final _FakeRuntimePort port;
  final GameFrameRateRuntimeController runtime;
  final _FakeTimerFactory timerFactory;
  TimingsCallback? get addedTimingCallback => timerFactory.addedTimingCallback;
  TimingsCallback? get removedTimingCallback =>
      timerFactory.removedTimingCallback;

  _FakeTimer? get timer => timerFactory.timer;

  static Future<_Fixture> create({
    List<double> measurements = const <double>[],
  }) async {
    final settings = await GameFrameRateSettingsController.load(
      MemoryGameFrameRateSettingsStore(),
    );
    final port = _FakeRuntimePort(measurements);
    final timerFactory = _FakeTimerFactory();
    final runtime = GameFrameRateRuntimeController(
      settings: settings,
      port: port,
      timerFactory: timerFactory.call,
      addTimingsCallback: (callback) =>
          timerFactory.addedTimingCallback = callback,
      removeTimingsCallback: (callback) =>
          timerFactory.removedTimingCallback = callback,
    );
    final fixture = _Fixture._(
      settings: settings,
      port: port,
      runtime: runtime,
      timerFactory: timerFactory,
    );
    return fixture;
  }

  void dispose() {
    runtime.dispose();
    settings.dispose();
  }
}

final class _FakeRuntimePort implements GameFrameRateRuntimePort {
  _FakeRuntimePort(List<double> measurements)
    : _measurements = List<double>.of(measurements);

  final List<double> _measurements;
  final List<GameFrameRateTarget> appliedTargets = <GameFrameRateTarget>[];
  int measurementCalls = 0;

  @override
  Future<void> apply(GameFrameRateTarget target) async {
    appliedTargets.add(target);
  }

  @override
  Future<double?> measuredFps() async {
    measurementCalls += 1;
    return _measurements.isEmpty ? 60 : _measurements.removeAt(0);
  }
}

final class _FakeTimerFactory {
  _FakeTimer? timer;
  TimingsCallback? addedTimingCallback;
  TimingsCallback? removedTimingCallback;

  Timer call(Duration duration, void Function(Timer timer) callback) {
    return timer = _FakeTimer(callback);
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function(Timer timer) _callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _tick += 1;
    _callback(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}
