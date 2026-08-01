import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../bridge/captured_api_event.dart';
import 'game_capture_port.dart';

const MethodChannel _defaultGameCaptureChannel = MethodChannel(
  'app.yahagi.kancollebrowser/game_capture',
);

GameCapturePort createPlatformGameCapturePort() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return MethodChannelGameCapturePort();
  }
  return const UnsupportedGameCapturePort();
}

final class MethodChannelGameCapturePort implements GameCapturePort {
  MethodChannelGameCapturePort({this.channel = _defaultGameCaptureChannel}) {
    channel.setMethodCallHandler(_onMethodCall);
  }

  final MethodChannel channel;
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast();

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> configure({required bool enabled, required String script}) {
    return channel.invokeMethod<void>('configure', <String, Object?>{
      'enabled': enabled,
      'script': script,
    });
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'onCaptureEvent' || _events.isClosed) {
      return;
    }
    try {
      final decoded = AndroidCaptureEvent.decode(call.arguments);
      if (decoded is CapturedApiEvent) {
        _events.add(decoded);
      }
    } on FormatException {
      // Native validation is repeated in Dart. Invalid messages are ignored
      // without logging their potentially sensitive response body.
    }
  }

  @override
  void dispose() {
    channel.setMethodCallHandler(null);
    unawaited(_events.close());
  }
}

final class UnsupportedGameCapturePort implements GameCapturePort {
  const UnsupportedGameCapturePort();

  @override
  Stream<CapturedApiEvent> get events => const Stream<CapturedApiEvent>.empty();

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => false;

  @override
  void dispose() {}
}
