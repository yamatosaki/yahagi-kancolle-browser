import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import 'game_capture_port.dart';

final class GameCaptureController extends ChangeNotifier {
  GameCaptureController({
    this.maxEvents = 32,
    this.maxResponseBytes = 16 * 1024 * 1024,
    this.onAcceptedEvent,
  }) : assert(maxEvents > 0),
       assert(maxResponseBytes > 0);

  final int maxEvents;
  final int maxResponseBytes;
  final ValueChanged<CapturedApiEvent>? onAcceptedEvent;
  final List<CapturedApiEvent> _events = <CapturedApiEvent>[];

  GameCapturePort? _port;
  StreamSubscription<CapturedApiEvent>? _subscription;

  GameCaptureState _state = GameCaptureState.disabled;
  bool? _configuredEnabled;
  String _script = '';
  int _responseBytes = 0;
  String? _errorMessage;

  GameCaptureState get state => _state;
  List<CapturedApiEvent> get events => List.unmodifiable(_events);

  int get responseBytes => _responseBytes;
  String? get errorMessage => _errorMessage;

  Future<void> attach(
    GameCapturePort port, {
    required bool enabled,
    String script = '',
  }) async {
    _script = script;
    if (identical(_port, port)) {
      await configure(enabled: enabled, script: script);
      return;
    }

    await _subscription?.cancel();
    _port = port;
    _subscription = port.events.listen(_onEvent);

    _configuredEnabled = null;
    await configure(enabled: enabled, script: script);
  }

  Future<void> configure({required bool enabled, String? script}) async {
    if (script != null) {
      _script = script;
    }
    final port = _port;
    if (!enabled) {
      _state = GameCaptureState.disabled;
      _errorMessage = null;
      notifyListeners();
      if (port != null && _configuredEnabled != false) {
        try {
          await port.configure(enabled: false, script: '');
          _configuredEnabled = false;
        } catch (error) {
          _state = GameCaptureState.error;
          _errorMessage = _safeError(error);
          notifyListeners();
        }
      }
      return;
    }

    if (port == null) {
      _state = GameCaptureState.checking;
      notifyListeners();
      return;
    }
    if (_configuredEnabled == true) {
      return;
    }

    _state = GameCaptureState.checking;
    _errorMessage = null;
    notifyListeners();
    try {
      if (!await port.isSupported()) {
        _state = GameCaptureState.unsupported;
        notifyListeners();
        return;
      }
      await port.configure(enabled: true, script: _script);
      _configuredEnabled = true;
      _state = _events.isEmpty
          ? GameCaptureState.ready
          : GameCaptureState.capturing;
    } catch (error) {
      _state = GameCaptureState.error;
      _errorMessage = _safeError(error);
    }
    notifyListeners();
  }

  void _onEvent(CapturedApiEvent event) {
    if (_configuredEnabled != true ||
        _state == GameCaptureState.disabled ||
        _state == GameCaptureState.unsupported) {
      return;
    }

    final eventBytes = utf8.encode(event.responseBody).length;
    if (eventBytes > maxResponseBytes) {
      return;
    }
    _events.add(event);
    _responseBytes += eventBytes;
    while (_events.length > maxEvents || _responseBytes > maxResponseBytes) {
      final removed = _events.removeAt(0);
      _responseBytes -= utf8.encode(removed.responseBody).length;
    }
    _state = GameCaptureState.capturing;
    _errorMessage = null;
    onAcceptedEvent?.call(event);
    notifyListeners();
  }

  String _safeError(Object error) {
    final type = error.runtimeType.toString();
    return '捕获配置失败（$type）';
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
