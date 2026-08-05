import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_update_service.dart';

String _map(String version, {String destination = 'Y'}) => jsonEncode({
  'meta': {'name': 'map', 'version': version},
  'data': {
    '5-6': {
      'route': {
        '42': ['X', destination],
      },
    },
  },
});

String _meta(String version) => jsonEncode([
  {'name': 'map', 'version': version},
]);

void main() {
  final current = FcdMapDataset.parse(
    _map('2026/07/01/01'),
    minimumMapCount: 1,
  );

  test(
    'does not download map.json when the primary metadata is current',
    () async {
      var requests = 0;
      final service = FcdMapUpdateService(
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, endsWith('/meta.json'));
          expect(
            request.headers['User-Agent'],
            contains('Yahagi-Kancolle-Browser/'),
          );
          expect(request.followRedirects, isFalse);
          return http.Response(_meta('2026/07/01/01'), 200);
        }),
        store: FcdMapStore(_MemoryStorage(_map('2026/07/01/01'))),
        minimumMapCount: 1,
      );

      final result = await service.checkAndUpdate(current: current);

      expect(result, isA<FcdMapUpToDate>());
      expect(requests, 1);
    },
  );

  test('downloads, validates and saves a newer map from one source', () async {
    final storage = _MemoryStorage(_map('2026/07/01/01'));
    final service = FcdMapUpdateService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/meta.json')) {
          return http.Response(_meta('2026/07/28/02'), 200);
        }
        return http.Response(_map('2026/07/28/02'), 200);
      }),
      store: FcdMapStore(storage),
      minimumMapCount: 1,
    );

    final result = await service.checkAndUpdate(current: current);

    expect(result, isA<FcdMapUpdated>());
    expect(
      (result as FcdMapUpdated).dataset.version.toString(),
      '2026/07/28/02',
    );
    expect(
      FcdMapDataset.parse(storage.cached!, minimumMapCount: 1).version,
      result.dataset.version,
    );
    expect(FcdMapState.fromJson(storage.state!).source, isNotEmpty);
  });

  test('falls back from GitHub Raw to jsDelivr', () async {
    final requestedHosts = <String>[];
    final service = FcdMapUpdateService(
      client: MockClient((request) async {
        requestedHosts.add(request.url.host);
        if (request.url.host == 'raw.githubusercontent.com') {
          return http.Response('unavailable', 503);
        }
        if (request.url.path.endsWith('/meta.json')) {
          return http.Response(_meta('2026/07/28/02'), 200);
        }
        return http.Response(_map('2026/07/28/02'), 200);
      }),
      store: FcdMapStore(_MemoryStorage(_map('2026/07/01/01'))),
      minimumMapCount: 1,
    );

    final result = await service.checkAndUpdate(current: current);

    expect(result, isA<FcdMapUpdated>());
    expect(
      requestedHosts,
      containsAllInOrder([
        'raw.githubusercontent.com',
        'cdn.jsdelivr.net',
        'cdn.jsdelivr.net',
      ]),
    );
  });

  test(
    'rejects map content whose version differs from same-source metadata',
    () async {
      final storage = _MemoryStorage(_map('2026/07/01/01'));
      final service = FcdMapUpdateService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/meta.json')) {
            return http.Response(_meta('2026/07/28/02'), 200);
          }
          return http.Response(_map('2026/07/29/01'), 200);
        }),
        store: FcdMapStore(storage),
        minimumMapCount: 1,
      );

      final result = await service.checkAndUpdate(current: current);

      expect(result, isA<FcdMapUpdateFailed>());
      expect(
        (result as FcdMapUpdateFailed).kind,
        FcdMapUpdateFailure.validation,
      );
      expect(storage.cached, isNull);
    },
  );

  test('rejects oversized map responses without replacing the cache', () async {
    final storage = _MemoryStorage(_map('2026/07/01/01'));
    final service = FcdMapUpdateService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/meta.json')) {
          return http.Response(_meta('2026/07/28/02'), 200);
        }
        return http.Response.bytes(List<int>.filled(1025, 65), 200);
      }),
      store: FcdMapStore(storage),
      maxMapBytes: 1024,
      minimumMapCount: 1,
    );

    final result = await service.checkAndUpdate(current: current);

    expect(result, isA<FcdMapUpdateFailed>());
    expect((result as FcdMapUpdateFailed).kind, FcdMapUpdateFailure.validation);
    expect(storage.cached, isNull);
  });

  test(
    'rejects remote metadata that would downgrade the current data',
    () async {
      final service = FcdMapUpdateService(
        client: MockClient(
          (_) async => http.Response(_meta('2026/06/01/01'), 200),
        ),
        store: FcdMapStore(_MemoryStorage(_map('2026/07/01/01'))),
        minimumMapCount: 1,
      );

      final result = await service.checkAndUpdate(current: current);

      expect(result, isA<FcdMapUpdateFailed>());
      expect(
        (result as FcdMapUpdateFailed).kind,
        FcdMapUpdateFailure.validation,
      );
    },
  );

  test(
    'applies one total deadline to a response that keeps dripping',
    () async {
      final client = _DripClient();
      addTearDown(client.close);
      final service = FcdMapUpdateService(
        client: client,
        store: FcdMapStore(_MemoryStorage(_map('2026/07/01/01'))),
        timeout: const Duration(milliseconds: 30),
        minimumMapCount: 1,
      );
      final stopwatch = Stopwatch()..start();

      final result = await service.checkAndUpdate(current: current);

      expect(result, isA<FcdMapUpdateFailed>());
      expect((result as FcdMapUpdateFailed).kind, FcdMapUpdateFailure.network);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(client.sendCount, 2);
      expect(client.cancelCount, 2);
    },
  );
}

final class _DripClient extends http.BaseClient {
  int sendCount = 0;
  int cancelCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCount++;
    Timer? timer;
    late final StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () {
        timer = Timer.periodic(
          const Duration(milliseconds: 5),
          (_) => controller.add(const <int>[32]),
        );
      },
      onCancel: () {
        timer?.cancel();
        cancelCount++;
      },
    );
    return http.StreamedResponse(controller.stream, 200);
  }
}

final class _MemoryStorage implements FcdMapStorage, FcdMapStateStorage {
  _MemoryStorage(this.bundled);

  final String bundled;
  String? cached;
  String? state;

  @override
  Future<String> readBundled() async => bundled;

  @override
  Future<String?> readCached() async => cached;

  @override
  Future<void> writeCached(String rawJson) async => cached = rawJson;

  @override
  Future<String?> readState() async => state;

  @override
  Future<void> writeState(String rawJson) async => state = rawJson;
}
