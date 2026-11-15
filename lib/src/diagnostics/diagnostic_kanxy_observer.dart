import 'dart:async';

import 'package:flutter/services.dart';

import 'diagnostic_event.dart';
import 'diagnostic_platform_port.dart';
import 'diagnostic_privacy_policy.dart';
import 'diagnostic_recorder.dart';

final class DiagnosticKanxyObserver {
  DiagnosticKanxyObserver(this._recorder, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannelDiagnosticPlatformPort().channel;

  static const _maxEpochMilliseconds = 8640000000000000;

  final DiagnosticRecorder _recorder;
  final MethodChannel _channel;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    _channel.setMethodCallHandler(_onMethodCall);
    unawaited(_setRecording(true));
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    _channel.setMethodCallHandler(null);
    unawaited(_setRecording(false));
  }

  Future<void> _setRecording(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKanxyRecording', enabled);
    } on MissingPluginException {
      // Diagnostics remain available without the native Kanxy observer.
    } on PlatformException {
      // Keep native diagnostic subscription failures away from game startup.
    }
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    if (call.method != 'kanxyEvent') throw MissingPluginException();
    final arguments = call.arguments;
    if (!_attached ||
        !_recorder.enabled ||
        arguments is! Map<Object?, Object?> ||
        arguments.length != 2) {
      return null;
    }
    final status = DiagnosticKanxyStatus.fromWire(arguments['status']);
    final occurredAtMs = arguments['occurredAtMs'];
    if (status == null ||
        occurredAtMs is! int ||
        occurredAtMs < 0 ||
        occurredAtMs > _maxEpochMilliseconds) {
      return null;
    }
    _recorder.record(
      DiagnosticEvent.kanxy(
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          occurredAtMs,
          isUtc: true,
        ),
        status: status,
      ),
    );
    return null;
  }
}
