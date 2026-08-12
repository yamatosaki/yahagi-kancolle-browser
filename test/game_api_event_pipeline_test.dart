import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_decoder.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';

void main() {
  test('a prepared envelope is reused even when the raw body is invalid', () {
    final event = _event('/kcsapi/api_get_member/material', 'invalid-json')
        .withDecodedEnvelope(<String, Object?>{
          'api_result': 1,
          'api_data': <String, Object?>{'api_value': 7},
        });

    expect(GameApiDecoder.decodeEventData(event), <String, Object?>{
      'api_value': 7,
    });
    expect(event.apiResult, 1);
  });

  test('a small ordinary response is decoded once before dispatch', () async {
    final consumer = _RecordingConsumer();
    var backgroundDecodeCalls = 0;
    var synchronousDecodeCalls = 0;
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
      decodeEnvelope: (body) async {
        backgroundDecodeCalls += 1;
        return GameApiDecoder.decodeEnvelope(body);
      },
      decodeSmallEnvelope: (body) {
        synchronousDecodeCalls += 1;
        return GameApiDecoder.decodeEnvelope(body);
      },
      backgroundThresholdBytes: 64 * 1024,
    );

    pipeline.add(_event('/kcsapi/api_port/port', _body(1)));
    await pipeline.idle;

    expect(backgroundDecodeCalls, 0);
    expect(synchronousDecodeCalls, 1);
    expect(consumer.events.single.hasDecodedEnvelope, isTrue);
  });

  test('an already prepared small response is not decoded again', () async {
    final consumer = _RecordingConsumer();
    var decodeCalls = 0;
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
      decodeSmallEnvelope: (body) {
        decodeCalls += 1;
        return GameApiDecoder.decodeEnvelope(body);
      },
    );
    final prepared = _event('/kcsapi/api_port/port', 'invalid-json')
        .withDecodedEnvelope(<String, Object?>{
          'api_result': 1,
          'api_data': const <String, Object?>{},
        });

    pipeline.add(prepared);
    await pipeline.idle;

    expect(decodeCalls, 0);
    expect(consumer.events.single, same(prepared));
  });

  test('start2 is predecoded regardless of response size', () async {
    final consumer = _RecordingConsumer();
    var decodeCalls = 0;
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
      decodeEnvelope: (body) async {
        decodeCalls += 1;
        return GameApiDecoder.decodeEnvelope(body);
      },
    );

    pipeline.add(_event('/kcsapi/api_start2/getData', _body(2)));
    await pipeline.idle;

    expect(decodeCalls, 1);
    expect(consumer.events.single.hasDecodedEnvelope, isTrue);
  });

  test(
    'a supported large response is decoded once for all consumers',
    () async {
      final first = _RecordingConsumer();
      final second = _RecordingConsumer();
      var decodeCalls = 0;
      final pipeline = GameApiEventPipeline(
        consumers: <GameApiEventConsumer>[first, second],
        decodeEnvelope: (body) async {
          decodeCalls += 1;
          return GameApiDecoder.decodeEnvelope(body);
        },
        backgroundThresholdBytes: 128,
      );

      pipeline.add(_event('/kcsapi/api_port/port', _body(256)));
      await pipeline.idle;

      expect(decodeCalls, 1);
      expect(first.events.single.hasDecodedEnvelope, isTrue);
      expect(
        second.events.single.decodedEnvelope,
        same(first.events.single.decodedEnvelope),
      );
    },
  );

  test('an unsupported response is not decoded or dispatched', () async {
    final consumer = _RecordingConsumer(
      supportedPaths: const <String>{'/kcsapi/api_port/port'},
    );
    var decodeCalls = 0;
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
      decodeEnvelope: (body) async {
        decodeCalls += 1;
        return GameApiDecoder.decodeEnvelope(body);
      },
      backgroundThresholdBytes: 1,
    );

    pipeline.add(_event('/kcsapi/api_ignored/large', _body(256)));
    await pipeline.idle;

    expect(decodeCalls, 0);
    expect(consumer.events, isEmpty);
  });

  test('events stay ordered while an earlier decode is pending', () async {
    final consumer = _RecordingConsumer();
    final firstDecode = Completer<Map<String, Object?>>();
    var calls = 0;
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
      decodeEnvelope: (body) {
        calls += 1;
        return calls == 1
            ? firstDecode.future
            : Future.value(GameApiDecoder.decodeEnvelope(body));
      },
    );

    pipeline
      ..add(_event('/kcsapi/api_start2/getData', _body(1), sequence: 1))
      ..add(_event('/kcsapi/api_port/port', _body(1), sequence: 2));
    await Future<void>.delayed(Duration.zero);
    expect(consumer.events, isEmpty);

    firstDecode.complete(GameApiDecoder.decodeEnvelope(_body(1)));
    await pipeline.idle;

    expect(consumer.events.map((event) => event.sequence), <int>[1, 2]);
  });

  test(
    'decode failure dispatches the original event and queue recovers',
    () async {
      final consumer = _RecordingConsumer();
      var calls = 0;
      final pipeline = GameApiEventPipeline(
        consumers: <GameApiEventConsumer>[consumer],
        decodeEnvelope: (body) async {
          calls += 1;
          if (calls == 1) throw const FormatException('broken');
          return GameApiDecoder.decodeEnvelope(body);
        },
      );

      pipeline
        ..add(_event('/kcsapi/api_start2/getData', 'broken', sequence: 1))
        ..add(_event('/kcsapi/api_start2/getData', _body(2), sequence: 2));
      await pipeline.idle;

      expect(consumer.events.map((event) => event.sequence), <int>[1, 2]);
      expect(consumer.events.first.hasDecodedEnvelope, isFalse);
      expect(consumer.events.last.hasDecodedEnvelope, isTrue);
    },
  );

  test('dispatch does not wait for a consumer database queue', () async {
    final consumer = _BlockingConsumer();
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
    );
    addTearDown(() async {
      consumer.release();
      await pipeline.idle;
    });

    pipeline
      ..add(_event('/kcsapi/api_port/port', _body(1), sequence: 1))
      ..add(_event('/kcsapi/api_port/port', _body(1), sequence: 2));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(consumer.events.map((event) => event.sequence), <int>[1, 2]);
  });

  test(
    'idle waits for consumer queues after every event is dispatched',
    () async {
      final consumer = _BlockingConsumer();
      final pipeline = GameApiEventPipeline(
        consumers: <GameApiEventConsumer>[consumer],
      );
      pipeline.add(_event('/kcsapi/api_port/port', _body(1)));
      await Future<void>.delayed(Duration.zero);

      var idleCompleted = false;
      final idle = pipeline.idle.then((_) => idleCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(idleCompleted, isFalse);

      consumer.release();
      await idle;
      expect(idleCompleted, isTrue);
    },
  );
}

final class _RecordingConsumer implements GameApiEventConsumer {
  _RecordingConsumer({this.supportedPaths});

  final Set<String>? supportedPaths;
  final List<CapturedApiEvent> events = <CapturedApiEvent>[];

  @override
  void accept(CapturedApiEvent event) => events.add(event);

  @override
  Future<void> get idle => Future<void>.value();

  @override
  bool supportsPath(String path) => supportedPaths?.contains(path) ?? true;
}

final class _BlockingConsumer implements GameApiEventConsumer {
  final List<CapturedApiEvent> events = <CapturedApiEvent>[];
  final Completer<void> _idle = Completer<void>();

  @override
  void accept(CapturedApiEvent event) => events.add(event);

  @override
  Future<void> get idle => _idle.future;

  @override
  bool supportsPath(String path) => true;

  void release() {
    if (!_idle.isCompleted) _idle.complete();
  }
}

CapturedApiEvent _event(String path, String body, {int sequence = 0}) {
  return CapturedApiEvent(
    path: path,
    responseBody: body,
    source: CaptureSource.fetch,
    capturedAt: DateTime.utc(2026, 8, 12),
    sequence: sequence,
  );
}

String _body(int paddingLength) => jsonEncode(<String, Object?>{
  'api_result': 1,
  'api_data': <String, Object?>{
    'padding': List<String>.filled(paddingLength, 'x').join(),
  },
});
