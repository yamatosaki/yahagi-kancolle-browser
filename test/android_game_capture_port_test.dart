import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/android_game_capture_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/game_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('queries support and configures the native bridge', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isSupported') {
        return true;
      }
      return null;
    });
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);

    expect(await port.isSupported(), isTrue);
    await port.configure(enabled: true, script: 'capture-script');

    expect(calls.map((call) => call.method), <String>[
      'isSupported',
      'configure',
    ]);
    expect(calls.last.arguments, <String, Object?>{
      'enabled': true,
      'script': 'capture-script',
    });
  });

  test('converts a native onCaptureEvent call into an event stream', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);
    final received = port.events.first;

    final completer = Completer<void>();
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('onCaptureEvent', <String, Object?>{
          'version': 1,
          'kind': 'kcsapi_response',
          'method': 'POST',
          'path': '/kcsapi/api_port/port',
          'requestParams': <String, Object?>{},
          'responseBody': 'svdata={"api_result":1}',
          'statusCode': 200,
          'transport': 'xhr',
          'sourceOrigin': 'https://w01y.kancolle-server.com',
          'capturedAt': '2026-07-30T10:00:00.000Z',
          'sequence': 1,
        }),
      ),
      (_) => completer.complete(),
    );
    await completer.future;

    expect((await received).path, '/kcsapi/api_port/port');
  });

  test('treats a missing native implementation as unsupported', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    final port = MethodChannelGameCapturePort(channel: channel);
    addTearDown(port.dispose);

    expect(await port.isSupported(), isFalse);
  });
}
