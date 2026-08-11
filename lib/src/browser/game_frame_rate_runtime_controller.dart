import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../settings/game_frame_rate_settings.dart';
import 'game_frame_rate_policy.dart';

enum GameFrameRateTarget { fps30, fps60 }

abstract interface class GameFrameRateRuntimePort {
  Future<void> apply(GameFrameRateTarget target);

  Future<double?> measuredFps();
}

typedef GameFrameRateTimerFactory =
    Timer Function(Duration duration, void Function(Timer timer) callback);

final class GameFrameRateRuntimeController {
  GameFrameRateRuntimeController({
    required this.settings,
    required this.port,
    GameFrameRatePolicy? policy,
    GameFrameRateTimerFactory? timerFactory,
    void Function(TimingsCallback callback)? addTimingsCallback,
    void Function(TimingsCallback callback)? removeTimingsCallback,
    this.sampleInterval = const Duration(seconds: 1),
    this.samplesPerWindow = 5,
  }) : assert(samplesPerWindow > 0),
       policy = policy ?? GameFrameRatePolicy(mode: settings.mode),
       _timerFactory = timerFactory ?? Timer.periodic,
       _addTimingsCallback =
           addTimingsCallback ?? SchedulerBinding.instance.addTimingsCallback,
       _removeTimingsCallback =
           removeTimingsCallback ??
           SchedulerBinding.instance.removeTimingsCallback {
    settings.addListener(_onSettingsChanged);
    _addTimingsCallback(_timingsCallback);
  }

  final GameFrameRateSettingsController settings;
  final GameFrameRateRuntimePort port;
  final GameFrameRatePolicy policy;
  final GameFrameRateTimerFactory _timerFactory;
  final void Function(TimingsCallback callback) _addTimingsCallback;
  final void Function(TimingsCallback callback) _removeTimingsCallback;
  final Duration sampleInterval;
  final int samplesPerWindow;

  Future<void> _queue = Future<void>.value();
  Timer? _sampleTimer;
  bool _ready = false;
  bool _disposed = false;
  int _sampleTicks = 0;
  late final TimingsCallback _timingsCallback = _onFrameTimings;

  Future<void> get idle => _queue;

  void onPageStarted() {
    if (_disposed) return;
    _ready = false;
    _stopTimer();
    policy.resetWindow();
    _sampleTicks = 0;
  }

  Future<void> onPageReady({bool samplingEnabled = true}) async {
    if (_disposed) return;
    _ready = samplingEnabled;
    _stopTimer();
    policy.resetWindow();
    _sampleTicks = 0;
    if (!samplingEnabled) return;
    _enqueue(_applySelectedMode);
    await idle;
  }

  void recordFlutterFrame(Duration totalSpan) {
    if (!_canSample) return;
    policy.addFlutterFrame(totalSpan);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_canSample) return;
    for (final timing in timings) {
      policy.addFlutterFrame(timing.totalSpan);
    }
  }

  bool get _canSample =>
      !_disposed &&
      _ready &&
      settings.mode == GameFrameRateMode.automatic &&
      !policy.isLockedTo30;

  void _onSettingsChanged() {
    if (_disposed) return;
    policy.setMode(settings.mode);
    _sampleTicks = 0;
    _stopTimer();
    if (_ready) _enqueue(_applySelectedMode);
  }

  Future<void> _applySelectedMode() async {
    if (_disposed || !_ready) return;
    final target = switch (settings.mode) {
      GameFrameRateMode.stable30 => GameFrameRateTarget.fps30,
      GameFrameRateMode.automatic when policy.isLockedTo30 =>
        GameFrameRateTarget.fps30,
      GameFrameRateMode.automatic ||
      GameFrameRateMode.prefer60 => GameFrameRateTarget.fps60,
    };
    try {
      await port.apply(target);
    } catch (_) {
      return;
    }
    if (_canSample) {
      _sampleTimer ??= _timerFactory(sampleInterval, _onSampleTimer);
    }
  }

  void _onSampleTimer(Timer _) {
    if (_canSample) _enqueue(_sampleOnce);
  }

  Future<void> _sampleOnce() async {
    if (!_canSample) return;
    try {
      final fps = await port.measuredFps();
      if (fps != null && fps.isFinite && fps >= 0) {
        policy.addCreateJsSample(fps);
      }
    } catch (_) {
      // A missing or navigating page simply contributes no sample.
    }
    if (!_canSample) return;
    _sampleTicks += 1;
    if (_sampleTicks < samplesPerWindow) return;
    _sampleTicks = 0;
    final decision = policy.completeWindow();
    if (decision == FrameRateDecision.downgradeTo30) {
      _stopTimer();
      try {
        await port.apply(GameFrameRateTarget.fps30);
      } catch (_) {
        // Keep the game page running at whatever frame rate it already uses.
      }
    }
  }

  void _enqueue(Future<void> Function() operation) {
    _queue = _queue.then((_) => operation()).catchError((_) {});
  }

  void _stopTimer() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopTimer();
    settings.removeListener(_onSettingsChanged);
    _removeTimingsCallback(_timingsCallback);
  }
}
