import 'dart:async';

import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import '../game_state/game_api_event_pipeline.dart';
import 'game_browser_controller.dart';

/// Refreshes a live game document when Android changes the Kanxy route.
final class KanxyGameRoute implements GameApiEventConsumer {
  KanxyGameRoute({
    required this._reload,
    this._cancelReload,
    this._awaitCaptureDispatch,
  });

  static const _start = '/kcsapi/api_start2/getData';
  static const _port = '/kcsapi/api_port/port';

  final Future<GameFrameReloadResult> Function(int generation) _reload;
  final Future<void> Function(int generation)? _cancelReload;
  final Future<void> Function()? _awaitCaptureDispatch;
  final _changes =
      <
        ({
          bool active,
          bool previous,
          int generation,
          int readyAt,
          bool http,
          bool renewed,
        })
      >[];
  ({String id, double startedAt})? _document;
  int? _firstPortAt;
  double _latestDocumentStartedAt = 0;
  bool _ready = false;
  bool _atPort = false;
  bool _scheduled = false;
  bool _reloading = false;
  int _signal = 0;
  int _lastAttemptSignal = -1;
  int? _reloadedGeneration;
  int? _inFlightGeneration;

  @override
  bool supportsPath(String path) =>
      GameCapturePathCatalog.battle.contains(path);

  @override
  void accept(CapturedApiEvent event) {
    if (!supportsPath(event.path) || event.source == CaptureSource.manual) {
      return;
    }
    final id = event.captureDocumentId;
    final startedAt = event.captureDocumentStartedAtEpochMs;
    if (id == null ||
        id.isEmpty ||
        startedAt == null ||
        !startedAt.isFinite ||
        event.apiResult != 1) {
      return;
    }
    final document = (id: id, startedAt: startedAt);
    if (event.path == _start) {
      if (document != _document && startedAt <= _latestDocumentStartedAt) {
        return;
      }
      if (document != _document) _firstPortAt = null;
      _document = document;
      _latestDocumentStartedAt = startedAt;
      _leavePort();
    } else if (document == _document) {
      if (event.path == _port) {
        _firstPortAt ??= event.capturedAt.millisecondsSinceEpoch;
        _atPort = true;
        _signalDrain();
      } else {
        _leavePort();
      }
    }
  }

  void invalidateDocument() {
    _document = null;
    _firstPortAt = null;
    _leavePort();
  }

  void setReady(bool ready) {
    if (ready == _ready) return;
    _ready = ready;
    if (ready) {
      _signalDrain();
    } else {
      _cancelPendingReload();
    }
  }

  void routeChanged(Object? arguments) {
    if (arguments case {
      'active': final bool active,
      'previous': final bool previous,
      'generation': final int generation,
      'readyAt': final int readyAt,
    } when generation > (_changes.lastOrNull?.generation ?? 0) && readyAt > 0) {
      final options = arguments as Map;
      final http = options['http'] == true;
      final renewed = !http && active && previous && options['renewed'] == true;
      if (active == previous && !renewed) return;
      _changes.add((
        active: active,
        previous: previous,
        generation: generation,
        readyAt: readyAt,
        http: http,
        renewed: renewed,
      ));
      if (http && !active) _cancelPendingReload();
      _signalDrain();
    }
  }

  @override
  Future<void> get idle => Future<void>.value();

  void _leavePort() {
    _atPort = false;
    _cancelPendingReload();
  }

  void _cancelPendingReload() {
    final generation = _inFlightGeneration;
    final cancel = _cancelReload;
    if (generation == null || cancel == null) return;
    _inFlightGeneration = null;
    unawaited(_cancelOnNative(cancel, generation));
  }

  Future<void> _cancelOnNative(
    Future<void> Function(int generation) cancel,
    int generation,
  ) async {
    try {
      await cancel(generation);
    } catch (_) {
      // Native may already have completed the reload or detached the WebView.
    }
  }

  void _signalDrain() {
    _signal++;
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_scheduled || _reloading || !_ready || !_atPort || _changes.isEmpty) {
      return;
    }
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      unawaited(_reloadIfNeeded());
    });
  }

  Future<void> _reloadIfNeeded() async {
    var consideredSignal = _signal;
    _reloading = true;
    try {
      if (_awaitCaptureDispatch case final awaitDispatch?) {
        await awaitDispatch();
      }
      consideredSignal = _signal;
      final document = _document;
      if (document == null ||
          !_ready ||
          !_atPort ||
          _lastAttemptSignal == consideredSignal) {
        return;
      }
      final change = _changes.last;
      // The explicit proxy remains selected while its listener is down.
      // Refresh a surviving document only once the proxy can serve it again.
      final documentIsCurrent = change.http || change.renewed
          ? !change.active || document.startedAt >= change.readyAt
          : _documentUsesVpnRoute(document.startedAt, change.active);
      if (_reloadedGeneration == change.generation || documentIsCurrent) {
        return;
      }

      _lastAttemptSignal = consideredSignal;
      _inFlightGeneration = change.generation;
      final result = await _reload(change.generation);
      _inFlightGeneration = null;
      if (result == GameFrameReloadResult.reloaded) {
        _reloadedGeneration = change.generation;
        if (_document == document) invalidateDocument();
      }
    } catch (_) {
      // A later port, visibility or route change may make the reload possible.
    } finally {
      _inFlightGeneration = null;
      _reloading = false;
      if (consideredSignal != _signal) _scheduleDrain();
    }
  }

  bool _documentUsesVpnRoute(double startedAt, bool active) {
    if (_routeAt(startedAt) != active) return false;
    final firstPortAt = _firstPortAt;
    // A document can load resources on different routes before its first port.
    return firstPortAt == null ||
        !_changes.any(
          (change) =>
              change.readyAt > startedAt &&
              change.readyAt <= firstPortAt &&
              (change.http ? change.active && active : change.active != active),
        );
  }

  bool _routeAt(double documentStartedAt) {
    for (final change in _changes.reversed) {
      if (documentStartedAt < change.readyAt) continue;
      if (!change.http) return change.active;
      // Verified HTTP can supersede an unpublished VPN-off event.
      if (change.active) return false;
    }
    return _changes.firstWhere((change) => !change.http).previous;
  }
}
