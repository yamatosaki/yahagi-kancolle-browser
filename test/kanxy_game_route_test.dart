import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/kanxy_game_route.dart';

void main() {
  late List<int> requests;
  late KanxyGameRoute route;

  setUp(() {
    requests = <int>[];
    route = KanxyGameRoute(
      reload: (generation) async {
        requests.add(generation);
        return GameFrameReloadResult.reloaded;
      },
    );
    route.setReady(true);
  });

  test('requires a live confirmed port in the current game document', () async {
    _change(route, generation: 1, readyAt: 200);
    route.accept(_event(_port));
    route.accept(_event(_start));
    route.accept(_event(_port, id: 'other'));
    route.accept(_event(_port, startedAt: 110));
    route.accept(_event(_port, source: CaptureSource.manual));
    route.accept(_event(_port, result: 0));
    await _flush();
    expect(requests, isEmpty);

    route.accept(_event(_port));
    await _flush();
    expect(requests, [1]);

    route.accept(_event(_port));
    route.setReady(false);
    route.setReady(true);
    await _flush();
    expect(requests, [1]);
  });

  test('defers during a sortie and while the game is hidden', () async {
    _confirmPort(route);
    route.accept(_event('/kcsapi/api_req_map/start'));
    _change(route, generation: 1, readyAt: 200);
    route.accept(_event('/kcsapi/api_req_combined_battle/battle_water'));
    route.accept(_event('/kcsapi/api_req_combined_battle/goback_port'));
    await _flush();
    expect(requests, isEmpty);

    route.setReady(false);
    route.accept(_event(_port));
    await _flush();
    expect(requests, isEmpty);

    route.setReady(true);
    await _flush();
    expect(requests, [1]);
  });

  test('coalesces route changes that return to the document route', () async {
    _confirmPort(route);
    _change(route, generation: 1, readyAt: 200);
    _change(route, generation: 2, readyAt: 210, active: false);
    await _flush();
    expect(requests, isEmpty);

    _change(route, generation: 3, readyAt: 220);
    _change(route, generation: 2, readyAt: 210, active: false);
    await _flush();
    expect(requests, [3]);
  });

  test('normal navigation after reconciliation fulfills the change', () async {
    route.setReady(false);
    _confirmPort(route);
    _change(route, generation: 1, readyAt: 200);
    route.invalidateDocument();
    _confirmPort(route);
    route.setReady(true);
    await _flush();
    expect(requests, isEmpty);

    _confirmPort(route, id: 'new', startedAt: 200);
    await _flush();
    expect(requests, isEmpty);

    _change(route, generation: 2, readyAt: 210, active: false);
    await _flush();
    expect(requests, [2]);
  });

  test(
    'identifies the route of a document observed after two changes',
    () async {
      _change(route, generation: 1, readyAt: 200);
      _change(route, generation: 2, readyAt: 300, active: false);
      _confirmPort(route);
      await _flush();
      expect(requests, isEmpty);

      _confirmPort(route, id: 'during-kanxy', startedAt: 250);
      await _flush();
      expect(requests, [2]);
    },
  );

  test('reloads a document that bootstrapped across both VPN states', () async {
    _change(route, generation: 1, readyAt: 200);
    route.accept(_event(_start, startedAt: 250));
    _change(route, generation: 2, readyAt: 300, active: false);
    _change(route, generation: 3, readyAt: 350);
    route.accept(_event(_port, startedAt: 250, capturedAt: 400));
    await _flush();
    expect(requests, [3]);
  });

  test(
    'HTTP loss waits for recovery and reloads an older port only once',
    () async {
      _confirmPort(route, startedAt: 150);
      _change(route, generation: 1, readyAt: 120, http: true);
      _change(route, generation: 2, readyAt: 200, active: false, http: true);
      await _flush();
      expect(requests, isEmpty);

      _change(route, generation: 3, readyAt: 300, http: true);
      await _flush();
      expect(requests, [3]);

      _confirmPort(route, id: 'recovered', startedAt: 350);
      await _flush();
      expect(requests, [3]);
    },
  );

  test(
    'HTTP recovery defers during sortie and leaves fresh documents alone',
    () async {
      _confirmPort(route, startedAt: 150);
      route.accept(_event('/kcsapi/api_req_map/start', startedAt: 150));
      _change(route, generation: 1, readyAt: 300, http: true);
      await _flush();
      expect(requests, isEmpty);

      _confirmPort(route, id: 'fresh', startedAt: 301);
      await _flush();
      expect(requests, isEmpty);
    },
  );

  test(
    'a ready VPN refreshes a surviving document after reattachment',
    () async {
      _confirmPort(route, startedAt: 150);
      route.setReady(false);
      _change(route, generation: 1, readyAt: 200, renewed: true);
      await _flush();
      expect(requests, isEmpty);

      route.setReady(true);
      await _flush();
      expect(requests, [1]);

      _confirmPort(route, id: 'new-vpn-page', startedAt: 201);
      await _flush();
      expect(requests, [1]);
    },
  );

  test('VPN renewal leaves a newly loaded game and a sortie alone', () async {
    _confirmPort(route, startedAt: 150);
    route.accept(_event('/kcsapi/api_req_map/start', startedAt: 150));
    _change(route, generation: 1, readyAt: 200, renewed: true);
    await _flush();
    expect(requests, isEmpty);

    _confirmPort(route, id: 'fresh', startedAt: 201);
    await _flush();
    expect(requests, isEmpty);
  });

  test('VPN restores a stock page opened between HTTP and VPN', () async {
    route.setReady(false);
    _change(route, generation: 1, readyAt: 100, http: true);
    _change(route, generation: 2, readyAt: 150, active: false, http: true);
    _confirmPort(route, startedAt: 160);
    _change(route, generation: 3, readyAt: 200, renewed: true);
    route.setReady(true);
    await _flush();
    expect(requests, [3]);
  });

  test(
    'VPN reloads a confirmed HTTP document without a VPN loss event',
    () async {
      _change(route, generation: 1, readyAt: 100, renewed: true);
      _change(route, generation: 2, readyAt: 200, http: true);
      _confirmPort(route, id: 'http-game', startedAt: 250);
      await _flush();
      expect(requests, isEmpty);

      _change(route, generation: 3, readyAt: 300);
      await _flush();
      expect(requests, [3]);
    },
  );

  test(
    'VPN reloads a document that passed through HTTP before first port',
    () async {
      _change(route, generation: 1, readyAt: 100, renewed: true);
      route.accept(_event(_start, startedAt: 150));
      _change(route, generation: 2, readyAt: 200, http: true);
      _change(route, generation: 3, readyAt: 300);
      await _flush();
      expect(requests, isEmpty);

      route.accept(_event(_port, startedAt: 150, capturedAt: 350));
      await _flush();
      expect(requests, [3]);
    },
  );

  test('a blocked dispatch retries only on a later readiness signal', () async {
    route = KanxyGameRoute(
      reload: (generation) async {
        requests.add(generation);
        return GameFrameReloadResult.blocked;
      },
    );
    _confirmPort(route);
    route.setReady(true);
    _change(route, generation: 1, readyAt: 200);
    await _flush();
    route.setReady(true);
    await _flush();
    expect(requests, [1]);

    route.setReady(false);
    route.setReady(true);
    await _flush();
    expect(requests, [1, 1]);
  });

  test('an old reply cannot discard a newer confirmed document', () async {
    final first = Completer<GameFrameReloadResult>();
    route = KanxyGameRoute(
      reload: (generation) async {
        requests.add(generation);
        return generation == 1 ? first.future : GameFrameReloadResult.reloaded;
      },
    );
    route.setReady(true);
    _confirmPort(route);
    _change(route, generation: 1, readyAt: 200);
    await _flush();

    _confirmPort(route, id: 'new', startedAt: 250);
    _change(route, generation: 2, readyAt: 300, active: false);
    first.complete(GameFrameReloadResult.reloaded);
    await _flush();
    expect(requests, [1, 2]);
  });

  test(
    'capture dispatch can revoke port proof before native is called',
    () async {
      final pendingCapture = Completer<void>();
      route = KanxyGameRoute(
        awaitCaptureDispatch: () => pendingCapture.future,
        reload: (generation) async {
          requests.add(generation);
          return GameFrameReloadResult.reloaded;
        },
      );
      route.setReady(true);
      _confirmPort(route);
      _change(route, generation: 1, readyAt: 200);
      await _flush();
      route.accept(_event('/kcsapi/api_req_map/next'));
      pendingCapture.complete();
      await _flush();
      expect(requests, isEmpty);
    },
  );

  test('leaving port revokes an automatic native request once', () async {
    final first = Completer<GameFrameReloadResult>();
    final cancellations = <int>[];
    route = KanxyGameRoute(
      reload: (generation) async {
        requests.add(generation);
        return requests.length == 1
            ? first.future
            : GameFrameReloadResult.reloaded;
      },
      cancelReload: (generation) async => cancellations.add(generation),
    );
    route.setReady(true);
    _confirmPort(route);
    _change(route, generation: 1, readyAt: 200);
    await _flush();

    route.accept(_event('/kcsapi/api_req_map/start'));
    route.setReady(false);
    first.complete(GameFrameReloadResult.blocked);
    await _flush();
    expect(cancellations, [1]);
    expect(requests, [1]);

    route.setReady(true);
    route.accept(_event(_port));
    await _flush();
    expect(requests, [1, 1]);
  });
}

const _start = '/kcsapi/api_start2/getData';
const _port = '/kcsapi/api_port/port';

CapturedApiEvent _event(
  String path, {
  String id = 'game',
  double startedAt = 100,
  int? capturedAt,
  CaptureSource source = CaptureSource.xhr,
  int result = 1,
}) => CapturedApiEvent(
  path: path,
  responseBody: '',
  decodedEnvelope: {'api_result': result},
  source: source,
  capturedAt: DateTime.fromMillisecondsSinceEpoch(
    capturedAt ?? startedAt.ceil(),
  ),
  captureDocumentId: id,
  captureDocumentStartedAtEpochMs: startedAt,
);

void _confirmPort(
  KanxyGameRoute route, {
  String id = 'game',
  double startedAt = 100,
}) {
  route.accept(_event(_start, id: id, startedAt: startedAt));
  route.accept(_event(_port, id: id, startedAt: startedAt));
}

void _change(
  KanxyGameRoute route, {
  required int generation,
  required int readyAt,
  bool active = true,
  bool http = false,
  bool renewed = false,
}) {
  route.routeChanged({
    'active': active,
    'previous': renewed ? active : !active,
    'generation': generation,
    'readyAt': readyAt,
    'http': http,
    'renewed': renewed,
  });
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
