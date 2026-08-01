import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';

void main() {
  group('GameCaptureController', () {
    test('game mode configures the port and forwards valid events', () async {
      final port = _FakeGameCapturePort(supported: true);
      final forwarded = <CapturedApiEvent>[];
      final controller = GameCaptureController(onAcceptedEvent: forwarded.add);
      addTearDown(() async {
        controller.dispose();
        await port.close();
      });

      await controller.attach(port, enabled: true);
      port.emit(_event(sequence: 1));
      await Future<void>.delayed(Duration.zero);

      expect(port.configurations, <bool>[true]);
      expect(controller.state, GameCaptureState.capturing);
      expect(controller.events, hasLength(1));
      expect(controller.events.single.sequence, 1);
      expect(forwarded.single.sequence, 1);
    });

    test('browser-only mode rejects events arriving after disable', () async {
      final port = _FakeGameCapturePort(supported: true);
      final controller = GameCaptureController();
      addTearDown(() async {
        controller.dispose();
        await port.close();
      });

      await controller.attach(port, enabled: true);
      await controller.configure(enabled: false);
      port.emit(_event(sequence: 1));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state, GameCaptureState.disabled);
      expect(controller.events, isEmpty);
    });

    test('unsupported platform keeps a stable unsupported state', () async {
      final port = _FakeGameCapturePort(supported: false);
      final controller = GameCaptureController();
      addTearDown(() async {
        controller.dispose();
        await port.close();
      });

      await controller.attach(port, enabled: true);

      expect(controller.state, GameCaptureState.unsupported);
      expect(port.configurations, isEmpty);
    });

    test('repeated configuration is idempotent', () async {
      final port = _FakeGameCapturePort(supported: true);
      final controller = GameCaptureController();
      addTearDown(() async {
        controller.dispose();
        await port.close();
      });

      await controller.attach(port, enabled: true);
      await controller.configure(enabled: true);
      await controller.configure(enabled: false);
      await controller.configure(enabled: false);

      expect(port.configurations, <bool>[true, false]);
    });

    test('evicts oldest events by count and response byte limit', () async {
      final port = _FakeGameCapturePort(supported: true);
      final controller = GameCaptureController(
        maxEvents: 2,
        maxResponseBytes: 7,
      );
      addTearDown(() async {
        controller.dispose();
        await port.close();
      });

      await controller.attach(port, enabled: true);
      port
        ..emit(_event(sequence: 1, body: '1234'))
        ..emit(_event(sequence: 2, body: '5678'))
        ..emit(_event(sequence: 3, body: 'abc'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.events.map((event) => event.sequence), <int>[2, 3]);
      expect(controller.responseBytes, 7);
    });
  });
}

CapturedApiEvent _event({required int sequence, String body = '{}'}) {
  return CapturedApiEvent(
    method: 'POST',
    path: '/kcsapi/api_port/port',
    requestParams: const <String, Object?>{},
    responseBody: body,
    statusCode: 200,
    source: CaptureSource.xhr,
    sourceOrigin: 'https://w01y.kancolle-server.com',
    capturedAt: DateTime.utc(2026, 7, 30),
    sequence: sequence,
  );
}

final class _FakeGameCapturePort implements GameCapturePort {
  _FakeGameCapturePort({required this.supported});

  final bool supported;
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast();

  final List<bool> configurations = <bool>[];

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {
    configurations.add(enabled);
  }

  @override
  Future<bool> isSupported() async => supported;

  @override
  void dispose() {}

  void emit(CapturedApiEvent event) {
    _events.add(event);
  }

  Future<void> close() => _events.close();
}
