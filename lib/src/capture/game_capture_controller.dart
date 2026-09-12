import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../bridge/native_game_capture_script.dart'
    show captureSessionIdPlaceholder;
import 'game_capture_port.dart';

final class GameCaptureController extends ChangeNotifier {
  GameCaptureController({
    this.maxResponseBytes = 8 * 1024 * 1024,
    this.onAcceptedEvent,
    this.operationTimeout = const Duration(seconds: 10),
  }) : assert(maxResponseBytes > 0);

  final int maxResponseBytes;
  final ValueChanged<CapturedApiEvent>? onAcceptedEvent;
  final Duration operationTimeout;
  static int _sessionSequence = 0;
  static String _newSessionId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${++_sessionSequence}';
  String _captureSessionId = _newSessionId();
  String get captureSessionId => _captureSessionId;
  String get _sessionScript =>
      _script.replaceAll(captureSessionIdPlaceholder, _captureSessionId);
  final ValueNotifier<int> _eventActivity = ValueNotifier<int>(0);

  GameCapturePort? _port;
  GameCapturePort? _desiredPort;
  StreamSubscription<CapturedApiEvent>? _subscription;
  Future<void>? _configurationDrain;
  Completer<void> _configurationInvalidator = Completer<void>();
  int _configurationRevision = 0;
  int _processedRevision = 0;
  int _streamEpoch = 0;
  bool _streamHealthy = false;
  final Map<int, Completer<void>> _configurationWaiters =
      <int, Completer<void>>{};
  bool _desiredEnabled = false;
  bool _disposed = false;
  bool _repairPending = false;
  bool _repairInFlight = false;

  GameCaptureState _state = GameCaptureState.disabled;
  bool? _configuredEnabled;
  String? _configuredScript;
  String _script = '';
  int _responseBytes = 0;
  int _capturedCount = 0;
  CapturedApiEvent? _latestEvent;
  String? _errorMessage;

  GameCaptureState get state => _state;
  CapturedApiEvent? get latestEvent => _latestEvent;
  int get capturedCount => _capturedCount;
  Listenable get eventActivity => _eventActivity;
  int get responseBytes => _responseBytes;
  String? get errorMessage => _errorMessage;

  /// Invalidate the old document immediately, then install the new document-start
  /// script. Await this before navigating to the next login document.
  Future<void> invalidateSession() {
    if (_disposed) return Future<void>.value();
    _captureSessionId = _newSessionId();
    _latestEvent = null;
    _responseBytes = 0;
    _capturedCount = 0;
    _eventActivity.value = 0;
    notifyListeners();
    return _enqueueConfiguration();
  }

  Future<void> attach(
    GameCapturePort port, {
    required bool enabled,
    String script = '',
  }) async {
    if (_disposed) return;
    _script = script;
    _desiredPort = port;
    _desiredEnabled = enabled;
    await _enqueueConfiguration();
  }

  Future<void> configure({required bool enabled, String? script}) async {
    if (_disposed) return;
    if (script != null) {
      _script = script;
    }
    _desiredEnabled = enabled;
    if (!enabled) {
      _state = GameCaptureState.disabled;
      _errorMessage = null;
      notifyListeners();
    }
    await _enqueueConfiguration();
  }

  Future<void> _enqueueConfiguration() {
    if (_disposed) return Future<void>.value();
    if (!_configurationInvalidator.isCompleted) {
      _configurationInvalidator.complete();
    }
    _configurationInvalidator = Completer<void>();
    final revision = ++_configurationRevision;
    final waiter = Completer<void>();
    _configurationWaiters[revision] = waiter;
    _ensureConfigurationDrain();
    return waiter.future;
  }

  void _ensureConfigurationDrain() {
    if (_configurationDrain != null || _disposed) return;
    final operation = _drainConfigurations();
    _configurationDrain = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_configurationDrain, operation)) {
          _configurationDrain = null;
        }
        if (!_disposed &&
            (_processedRevision < _configurationRevision || _repairPending)) {
          _ensureConfigurationDrain();
        }
      }),
    );
  }

  Future<void> _drainConfigurations() async {
    while (!_disposed &&
        (_processedRevision < _configurationRevision || _repairPending)) {
      final revision = _configurationRevision;
      final port = _desiredPort;
      final enabled = _desiredEnabled;
      final script = _sessionScript;
      final invalidator = _configurationInvalidator;
      final isRepair = _repairPending;
      if (isRepair) {
        _repairPending = false;
      }

      if (!identical(_port, port)) {
        _streamEpoch += 1;
        _streamHealthy = false;
        try {
          await _subscription?.cancel();
        } catch (error, stackTrace) {
          debugPrint(
            'Capture subscription cancellation failed: $error\n$stackTrace',
          );
        }
        if (!_isCurrentRequest(revision, port)) {
          _completeConfigurationThrough(revision);
          continue;
        }
        _port = port;
        _subscription = null;
        _configuredEnabled = null;
        _configuredScript = null;
        if (port != null) {
          final streamEpoch = _streamEpoch;
          _streamHealthy = true;
          try {
            _subscription = port.events.listen(
              (event) {
                if (_isCurrentStream(port, streamEpoch)) _onEvent(event);
              },
              onError: (Object error, StackTrace stackTrace) {
                _handleStreamTerminal(port, streamEpoch, error);
              },
              onDone: () {
                _handleStreamTerminal(
                  port,
                  streamEpoch,
                  StateError('capture event stream closed'),
                );
              },
            );
          } catch (error) {
            _handleStreamTerminal(port, streamEpoch, error);
          }
          if (!_streamHealthy) {
            _processedRevision = revision;
            _completeConfigurationThrough(revision);
            continue;
          }
        }
      }

      if (isRepair) _repairInFlight = true;
      await _applyConfiguration(revision, port, enabled, script, invalidator);
      if (isRepair) _repairInFlight = false;
      _processedRevision = revision;
      _completeConfigurationThrough(revision);
    }
  }

  Future<void> _applyConfiguration(
    int revision,
    GameCapturePort? port,
    bool enabled,
    String script,
    Completer<void> invalidator,
  ) async {
    if (port == null) {
      if (enabled && _isCurrentConfiguration(revision, port)) {
        _state = GameCaptureState.checking;
        notifyListeners();
      }
      return;
    }

    try {
      if (!enabled) {
        if (_configuredEnabled != false) {
          final result = await _waitForPortOperation(
            port.configure(enabled: false, script: ''),
            invalidator,
            lateRepairCommand: _CaptureConfigurationCommand(
              revision: revision,
              port: port,
              enabled: false,
              script: '',
            ),
          );
          if (!result.completed) return;
          if (result.error case final error?) throw error;
        }
        if (!_isCurrentConfiguration(revision, port)) return;
        _configuredEnabled = false;
        _configuredScript = '';
        _state = GameCaptureState.disabled;
        _errorMessage = null;
        notifyListeners();
        return;
      }

      if (_isCurrentConfiguration(revision, port)) {
        _state = GameCaptureState.checking;
        _errorMessage = null;
        notifyListeners();
      }
      final support = await _waitForPortOperation(
        port.isSupported(),
        invalidator,
      );
      if (!support.completed) return;
      if (support.error case final error?) throw error;
      if (support.value != true) {
        if (!_isCurrentConfiguration(revision, port)) return;
        _state = GameCaptureState.unsupported;
        notifyListeners();
        return;
      }
      if (!_isCurrentConfiguration(revision, port)) return;
      if (_configuredEnabled != true || _configuredScript != script) {
        final result = await _waitForPortOperation(
          port.configure(enabled: true, script: script),
          invalidator,
          lateRepairCommand: _CaptureConfigurationCommand(
            revision: revision,
            port: port,
            enabled: true,
            script: script,
          ),
        );
        if (!result.completed) return;
        if (result.error case final error?) throw error;
      }
      if (!_isCurrentConfiguration(revision, port)) return;
      _configuredEnabled = true;
      _configuredScript = script;
      _state = _latestEvent == null
          ? GameCaptureState.ready
          : GameCaptureState.capturing;
    } catch (error) {
      if (!_isCurrentConfiguration(revision, port)) return;
      _state = GameCaptureState.error;
      _errorMessage = _safeError(error);
    }
    notifyListeners();
  }

  Future<_PortOperationResult<T>> _waitForPortOperation<T>(
    Future<T> operation,
    Completer<void> invalidator, {
    _CaptureConfigurationCommand? lateRepairCommand,
  }) {
    if (lateRepairCommand != null) {
      final weakController = WeakReference<GameCaptureController>(this);
      unawaited(
        operation.then<void>(
          (_) => _handleLatePortCompletion(weakController, lateRepairCommand),
          onError: (Object _, StackTrace _) =>
              _handleLatePortCompletion(weakController, lateRepairCommand),
        ),
      );
    }
    return Future.any(<Future<_PortOperationResult<T>>>[
      operation
          .timeout(operationTimeout)
          .then<_PortOperationResult<T>>(
            (value) => _PortOperationResult<T>.success(value),
            onError: (Object error, StackTrace stackTrace) =>
                _PortOperationResult<T>.failure(error),
          ),
      invalidator.future.then<_PortOperationResult<T>>(
        (_) => _PortOperationResult<T>.interrupted(),
      ),
    ]);
  }

  static void _handleLatePortCompletion(
    WeakReference<GameCaptureController> weakController,
    _CaptureConfigurationCommand command,
  ) {
    final controller = weakController.target;
    if (controller == null || controller._disposed) return;
    if (command.revision > controller._configurationRevision) return;
    final desiredScript = controller._desiredEnabled
        ? controller._sessionScript
        : '';
    if (identical(command.port, controller._desiredPort) &&
        command.enabled == controller._desiredEnabled &&
        command.script == desiredScript) {
      return;
    }
    controller._configuredEnabled = null;
    controller._configuredScript = null;
    if (controller._repairPending || controller._repairInFlight) return;
    controller._repairPending = true;
    controller._ensureConfigurationDrain();
  }

  bool _isCurrentConfiguration(int revision, GameCapturePort? port) {
    return _isCurrentRequest(revision, port) &&
        (port == null || (identical(port, _port) && _streamHealthy));
  }

  bool _isCurrentRequest(int revision, GameCapturePort? port) {
    return !_disposed &&
        revision == _configurationRevision &&
        identical(port, _desiredPort);
  }

  bool _isCurrentStream(GameCapturePort port, int epoch) {
    return !_disposed &&
        _streamHealthy &&
        epoch == _streamEpoch &&
        identical(port, _port) &&
        identical(port, _desiredPort);
  }

  void _handleStreamTerminal(GameCapturePort port, int epoch, Object error) {
    if (!_isCurrentStream(port, epoch)) return;
    _streamHealthy = false;
    _configuredEnabled = null;
    _configuredScript = null;
    _state = GameCaptureState.error;
    _errorMessage = _safeError(error);
    if (!_configurationInvalidator.isCompleted) {
      _configurationInvalidator.complete();
    }
    _completeConfigurationThrough(_configurationRevision);
    notifyListeners();
  }

  void _completeConfigurationThrough(int revision) {
    final completed = _configurationWaiters.keys
        .where((key) => key <= revision)
        .toList(growable: false);
    for (final key in completed) {
      _configurationWaiters.remove(key)?.complete();
    }
  }

  void _onEvent(CapturedApiEvent event) {
    if (_disposed ||
        _configuredEnabled != true ||
        _state == GameCaptureState.disabled ||
        _state == GameCaptureState.unsupported) {
      return;
    }
    if (_script.contains(captureSessionIdPlaceholder) &&
        event.captureSessionId != _captureSessionId) {
      return;
    }

    final eventBytes =
        event.responseByteLength ?? utf8.encode(event.responseBody).length;
    if (eventBytes > maxResponseBytes) {
      return;
    }
    final statusChanged =
        _state != GameCaptureState.capturing || _errorMessage != null;
    _latestEvent = event;
    _responseBytes = eventBytes;
    _capturedCount += 1;
    _state = GameCaptureState.capturing;
    _errorMessage = null;
    onAcceptedEvent?.call(event);
    _eventActivity.value = _capturedCount;
    if (statusChanged) notifyListeners();
  }

  String _safeError(Object error) {
    final type = error.runtimeType.toString();
    return '捕获配置失败（$type）';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _configurationRevision += 1;
    if (!_configurationInvalidator.isCompleted) {
      _configurationInvalidator.complete();
    }
    _desiredPort = null;
    _repairPending = false;
    _port = null;
    _streamEpoch += 1;
    _streamHealthy = false;
    _configuredEnabled = null;
    for (final waiter in _configurationWaiters.values) {
      waiter.complete();
    }
    _configurationWaiters.clear();
    final cancellation = _subscription?.cancel();
    if (cancellation != null) {
      unawaited(cancellation.catchError((Object _) {}));
    }
    _eventActivity.dispose();
    super.dispose();
  }
}

final class _PortOperationResult<T> {
  const _PortOperationResult._({
    required this.completed,
    this.value,
    this.error,
  });

  factory _PortOperationResult.success(T value) =>
      _PortOperationResult<T>._(completed: true, value: value);
  factory _PortOperationResult.failure(Object error) =>
      _PortOperationResult<T>._(completed: true, error: error);
  factory _PortOperationResult.interrupted() =>
      _PortOperationResult<T>._(completed: false);

  final bool completed;
  final T? value;
  final Object? error;
}

final class _CaptureConfigurationCommand {
  const _CaptureConfigurationCommand({
    required this.revision,
    required this.port,
    required this.enabled,
    required this.script,
  });

  final int revision;
  final GameCapturePort port;
  final bool enabled;
  final String script;
}
