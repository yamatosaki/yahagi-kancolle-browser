import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_collector.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_consumer.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_dispatcher.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_request.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_settings.dart';
import 'package:yahagi_kancolle_browser/src/kcwiki_report/kcwiki_report_transport.dart';

void main() {
  setUp(() => AccountSession.shared.selectMember(1001));

  test(
    'a synchronous wait callback failure does not escape the consumer',
    () async {
      final harness = await _Harness.create(
        enabled: true,
        waitForGameState: () => throw StateError('unavailable reducer'),
      );
      addTearDown(harness.dispose);
      expect(() => harness.consumer.accept(_mapStart), returnsNormally);
      await harness.consumer.idle;
      expect(harness.controller.status.droppedCount, 1);
      expect(harness.transport.sent, isEmpty);
    },
  );

  test('switching accounts discards queued report work', () async {
    final gate = Completer<void>();
    final harness = await _Harness.create(
      enabled: true,
      waitForGameState: () => gate.future,
    );
    addTearDown(harness.dispose);
    harness.consumer.accept(_mapStart);
    AccountSession.shared.selectMember(2002);
    gate.complete();
    await harness.consumer.idle;
    expect(harness.transport.sent, isEmpty);
  });
  test('disabled consumer rejects every KCWiki event', () async {
    final harness = await _Harness.create(enabled: false);
    addTearDown(harness.dispose);

    expect(harness.consumer.supportsPath(_mapStart.path), isFalse);
    harness.consumer.accept(_mapStart);
    await harness.consumer.idle;
    expect(harness.transport.sent, isEmpty);
  });

  test('accept returns before game-state wait and upload finish', () async {
    final gate = Completer<void>();
    final harness = await _Harness.create(
      enabled: true,
      waitForGameState: () => gate.future,
    );
    addTearDown(harness.dispose);

    harness.consumer.accept(_mapStart);

    expect(harness.consumer.pendingEventCount, 1);
    expect(harness.transport.sent, isEmpty);
    gate.complete();
    await harness.consumer.idle;
    expect(harness.transport.sent, hasLength(1));
  });

  test('disabling clears queued reports and session state', () async {
    final gate = Completer<void>();
    final harness = await _Harness.create(
      enabled: true,
      waitForGameState: () => gate.future,
    );
    addTearDown(harness.dispose);
    harness.consumer.accept(_mapStart);

    await harness.controller.setEnabled(false);
    gate.complete();
    await harness.consumer.idle;

    expect(harness.transport.sent, isEmpty);
    expect(harness.dispatcher.pendingCount, 0);
  });

  test(
    'status notifications do not cancel an active reporting session',
    () async {
      final gate = Completer<void>();
      final harness = await _Harness.create(
        enabled: true,
        waitForGameState: () => gate.future,
      );
      addTearDown(harness.dispose);
      harness.consumer.accept(_mapStart);

      harness.controller.recordResult(
        module: 'quest',
        succeeded: true,
        occurredAt: DateTime.utc(2026, 8, 25),
        statusCode: 204,
      );
      gate.complete();
      await harness.consumer.idle;

      expect(harness.transport.sent, hasLength(1));
    },
  );

  test('report failure never stops another pipeline consumer', () async {
    final controller = await KcwikiReportController.load(
      MemoryKcwikiReportSettingsStore(true),
    );
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => _MemoryTransport(),
    );
    final reporter = KcwikiReportConsumer(
      controller: controller,
      collector: KcwikiReportCollector(),
      dispatcher: dispatcher,
      gameState: () => throw StateError('broken report state'),
      waitForGameState: () async {},
    );
    final recorder = _Recorder();
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[reporter, recorder],
    );
    addTearDown(reporter.dispose);
    addTearDown(controller.dispose);

    pipeline.add(_mapStart);
    await pipeline.idle;

    expect(recorder.events, <CapturedApiEvent>[_mapStart]);
    expect(controller.status.droppedCount, 1);
  });
}

final class _Harness {
  _Harness._({
    required this.controller,
    required this.dispatcher,
    required this.consumer,
    required this.transport,
  });

  final KcwikiReportController controller;
  final KcwikiReportDispatcher dispatcher;
  final KcwikiReportConsumer consumer;
  final _MemoryTransport transport;

  static Future<_Harness> create({
    required bool enabled,
    Future<void> Function()? waitForGameState,
  }) async {
    final controller = await KcwikiReportController.load(
      MemoryKcwikiReportSettingsStore(enabled),
    );
    final transport = _MemoryTransport();
    final dispatcher = KcwikiReportDispatcher(
      transportFactory: () => transport,
    );
    final consumer = KcwikiReportConsumer(
      controller: controller,
      collector: KcwikiReportCollector(),
      dispatcher: dispatcher,
      gameState: () => const GameState(
        memberId: 1001,
        admiralLevel: 100,
        fleets: <Fleet>[Fleet(id: 1, name: 'fleet', shipIds: <int>[])],
      ),
      waitForGameState: waitForGameState ?? () async {},
    );
    return _Harness._(
      controller: controller,
      dispatcher: dispatcher,
      consumer: consumer,
      transport: transport,
    );
  }

  void dispose() {
    consumer.dispose();
    controller.dispose();
  }
}

final class _MemoryTransport implements KcwikiReportTransport {
  final List<KcwikiReportRequest> sent = <KcwikiReportRequest>[];

  @override
  Future<KcwikiTransportResult> send(KcwikiReportRequest request) async {
    sent.add(request);
    return const KcwikiTransportResult.accepted(statusCode: 204);
  }

  @override
  void close() {}
}

final class _Recorder implements GameApiEventConsumer {
  final List<CapturedApiEvent> events = <CapturedApiEvent>[];

  @override
  void accept(CapturedApiEvent event) => events.add(event);

  @override
  Future<void> get idle async {}

  @override
  bool supportsPath(String path) => true;
}

final envelope = <String, Object?>{
  'api_result': 1,
  'api_data': <String, Object?>{
    'api_no': 1,
    'api_maparea_id': 1,
    'api_mapinfo_no': 1,
    'api_cell_data': <Object?>[],
  },
};

final _mapStart = CapturedApiEvent(
  path: '/kcsapi/api_req_map/start',
  requestParams: const <String, Object?>{'api_deck_id': '1'},
  responseBody: jsonEncode(envelope),
  source: CaptureSource.manual,
  capturedAt: DateTime.utc(2026, 8, 25),
  decodedEnvelope: envelope,
);
