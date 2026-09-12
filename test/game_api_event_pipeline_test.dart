import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_decoder.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';

void main() {
  test(
    'new game document rejects old port, unstamped events and late old start2',
    () async {
      final consumer = _RecordingConsumer();
      final pipeline = GameApiEventPipeline(
        consumers: [consumer],
        decodeEnvelope: (body) async => GameApiDecoder.decodeEnvelope(body),
      );
      pipeline.add(
        _documentEvent('/kcsapi/api_start2/getData', 'old', 1000, 1),
      );
      pipeline.add(_documentEvent('/kcsapi/api_port/port', 'old', 1000, 2));
      pipeline.add(
        _documentEvent('/kcsapi/api_start2/getData', 'new', 2000, 3),
      );
      pipeline.add(_documentEvent('/kcsapi/api_port/port', 'old', 1000, 4));
      pipeline.add(
        _documentEvent('/kcsapi/api_start2/getData', 'old', 1000, 5),
      );
      pipeline.add(
        _documentEvent('/kcsapi/api_start2/getData', 'even-older', 900, 6),
      );
      pipeline.add(_event('/kcsapi/api_port/port', _body(1), sequence: 7));
      pipeline.add(_documentEvent('/kcsapi/api_port/port', 'new', 2000, 8));
      await pipeline.idle;
      expect(consumer.events.map((e) => e.sequence), [1, 2, 3, 8]);
      expect(
        pipeline.isCurrentDocument(
          _documentEvent('/kcsapi/api_req_map/next', 'old', 1000, 9),
        ),
        isFalse,
      );
      expect(
        pipeline.isCurrentDocument(
          _documentEvent('/kcsapi/api_req_map/next', 'new', 2000, 10),
        ),
        isTrue,
      );
    },
  );

  test(
    'failed new-document start cannot invalidate the active document',
    () async {
      final consumer = _RecordingConsumer();
      final pipeline = GameApiEventPipeline(
        consumers: [consumer],
        decodeEnvelope: (body) async => GameApiDecoder.decodeEnvelope(body),
      );
      pipeline.add(
        _documentEvent('/kcsapi/api_start2/getData', 'old', 1000, 1),
      );
      pipeline.add(
        _documentEvent(
          '/kcsapi/api_start2/getData',
          'new',
          2000,
          2,
        ).withDecodedEnvelope({'api_result': 0}),
      );
      pipeline.add(_documentEvent('/kcsapi/api_port/port', 'new', 2000, 3));
      pipeline.add(_documentEvent('/kcsapi/api_port/port', 'old', 1000, 4));
      await pipeline.idle;
      expect(consumer.events.map((e) => e.sequence), [1, 4]);
    },
  );
  test('session invalidation discards decoding and queued responses', () async {
    final consumer = _RecordingConsumer();
    final decode = Completer<Map<String, Object?>>();
    final started = Completer<void>();
    final pipeline = GameApiEventPipeline(
      consumers: [consumer],
      decodeEnvelope: (_) {
        started.complete();
        return decode.future;
      },
    );
    pipeline.add(_event('/kcsapi/api_start2/getData', _body(1), sequence: 1));
    pipeline.add(_event('/kcsapi/api_port/port', _body(1), sequence: 2));
    await started.future;
    pipeline.invalidatePendingEvents();
    pipeline.add(_event('/kcsapi/api_port/port', _body(1), sequence: 3));
    decode.complete(GameApiDecoder.decodeEnvelope(_body(1)));
    await pipeline.idle;
    expect(consumer.events.map((e) => e.sequence), [3]);
    expect(pipeline.pendingEventCount, 0);
  });

  test(
    'leaving login rejects late old responses until a successful new start',
    () async {
      final consumer = _RecordingConsumer();
      final pipeline = GameApiEventPipeline(
        consumers: [consumer],
        decodeEnvelope: (body) async => GameApiDecoder.decodeEnvelope(body),
      );
      pipeline.invalidatePendingEvents(waitForLoginStart: true);
      pipeline.add(
        _event('/kcsapi/api_get_member/basic', _body(1), sequence: 1),
      );
      pipeline.add(
        _event('/kcsapi/api_start2/getData', '{"api_result":0}', sequence: 2),
      );
      pipeline.add(_event('/kcsapi/api_port/port', _body(1), sequence: 3));
      pipeline.add(_event('/kcsapi/api_start2/getData', _body(1), sequence: 4));
      pipeline.add(_event('/kcsapi/api_port/port', _body(1), sequence: 5));
      await pipeline.idle;
      expect(consumer.events.map((e) => e.sequence), [4, 5]);
    },
  );
  test('failed API responses never reach state consumers', () async {
    final consumer = _RecordingConsumer();
    final pipeline = GameApiEventPipeline(consumers: [consumer]);
    pipeline.add(
      _event(
        '/kcsapi/api_port/port',
        'svdata={"api_result":0,"api_data":{}}',
        sequence: 1,
      ),
    );
    pipeline.add(_event('/kcsapi/api_port/port', _body(0), sequence: 2));
    await pipeline.idle;
    expect(consumer.events.map((event) => event.sequence), [2]);
  });
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
    'a hung background decode falls back synchronously and preserves order',
    () async {
      final consumer = _RecordingConsumer();
      final observer = _RecordingPipelineObserver();
      final never = Completer<Map<String, Object?>>();
      var syncCalls = 0;
      final pipeline = GameApiEventPipeline(
        consumers: <GameApiEventConsumer>[consumer],
        observer: observer,
        decodeEnvelope: (_) => never.future,
        decodeSmallEnvelope: (body) {
          syncCalls += 1;
          return GameApiDecoder.decodeEnvelope(body);
        },
        backgroundDecodeTimeout: const Duration(milliseconds: 10),
      );

      pipeline
        ..add(_event('/kcsapi/api_start2/getData', _body(1), sequence: 1))
        ..add(_event('/kcsapi/api_port/port', _body(2), sequence: 2));
      await pipeline.idle.timeout(const Duration(seconds: 1));

      expect(consumer.events.map((event) => event.sequence), <int>[1, 2]);
      expect(syncCalls, 2);
      expect(observer.timings.first.usedSynchronousFallback, isTrue);
      expect(pipeline.pendingEventCount, 0);
      expect(pipeline.activePath, isNull);
      expect(pipeline.backgroundFallbackCount, 1);
    },
  );

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

  test('a failed synchronous fallback releases the following event', () async {
    final consumer = _RecordingConsumer();
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
      decodeEnvelope: (_) => Completer<Map<String, Object?>>().future,
      decodeSmallEnvelope: (body) {
        if (body == 'broken') throw const FormatException('broken');
        return GameApiDecoder.decodeEnvelope(body);
      },
      backgroundDecodeTimeout: const Duration(milliseconds: 10),
    );

    pipeline
      ..add(_event('/kcsapi/api_start2/getData', 'broken', sequence: 1))
      ..add(_event('/kcsapi/api_port/port', _body(2), sequence: 2));
    await pipeline.idle.timeout(const Duration(seconds: 1));

    expect(consumer.events.map((event) => event.sequence), <int>[1, 2]);
    expect(consumer.events.first.hasDecodedEnvelope, isFalse);
    expect(consumer.events.last.hasDecodedEnvelope, isTrue);
    expect(pipeline.pendingEventCount, 0);
  });

  test('pending depth is accurate without a diagnostic observer', () async {
    final decode = Completer<Map<String, Object?>>();
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[_RecordingConsumer()],
      decodeEnvelope: (_) => decode.future,
    );

    pipeline.add(_event('/kcsapi/api_start2/getData', _body(1)));
    expect(pipeline.pendingEventCount, 1);
    await Future<void>.delayed(Duration.zero);
    expect(pipeline.activePath, '/kcsapi/api_start2/getData');

    decode.complete(GameApiDecoder.decodeEnvelope(_body(1)));
    await pipeline.idle;
    expect(pipeline.pendingEventCount, 0);
    expect(pipeline.activePath, isNull);
  });

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

  test('dispatchIdle does not wait for unrelated consumer work', () async {
    final consumer = _BlockingConsumer();
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[consumer],
    );
    addTearDown(() async {
      consumer.release();
      await pipeline.idle;
    });

    pipeline.add(_event('/kcsapi/api_port/port', _body(1), sequence: 7));
    await pipeline.dispatchIdle.timeout(const Duration(seconds: 1));

    expect(consumer.events.map((event) => event.sequence), <int>[7]);
    var fullIdleCompleted = false;
    final fullIdle = pipeline.idle.then((_) => fullIdleCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(fullIdleCompleted, isFalse);

    consumer.release();
    await fullIdle;
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

  test(
    'observer receives scalar timings and pending depth returns to zero',
    () async {
      final observer = _RecordingPipelineObserver();
      final pipeline = GameApiEventPipeline(
        consumers: <GameApiEventConsumer>[_RecordingConsumer()],
        observer: observer,
      );

      pipeline.add(_event('/kcsapi/api_port/port', _body(4)));
      expect(pipeline.pendingEventCount, 1);
      await pipeline.idle;

      expect(pipeline.pendingEventCount, 0);
      expect(observer.timings.single.path, '/kcsapi/api_port/port');
      expect(observer.timings.single.responseBytes, greaterThan(0));
      expect(observer.timings.single.toString(), isNot(contains('padding')));
    },
  );
}

final class _RecordingPipelineObserver implements GameApiPipelineObserver {
  final List<GameApiTiming> timings = <GameApiTiming>[];

  @override
  void onCompleted(GameApiTiming timing) => timings.add(timing);
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

CapturedApiEvent _documentEvent(
  String path,
  String id,
  double startedAt,
  int sequence,
) => CapturedApiEvent(
  path: path,
  responseBody: _body(1),
  source: CaptureSource.fetch,
  capturedAt: DateTime.utc(2026, 9, 12),
  sequence: sequence,
  captureDocumentId: id,
  captureDocumentStartedAtEpochMs: startedAt,
);

String _body(int paddingLength) => jsonEncode(<String, Object?>{
  'api_result': 1,
  'api_data': <String, Object?>{
    'padding': List<String>.filled(paddingLength, 'x').join(),
  },
});
