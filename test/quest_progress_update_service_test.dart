import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_update_service.dart';

void main() {
  final commit = 'b' * 40;
  String payload(String version, {int required = 2}) => jsonEncode({
    'meta': {'name': 'questgoal', 'version': version},
    'data': {
      '201': {
        'type': 1,
        'battle': {'description': 'battle', 'required': required},
      },
    },
  });
  String metadata([String? sha]) => jsonEncode([
    {'sha': sha ?? commit},
  ]);
  late QuestProgressDataset current;
  late _Storage storage;
  setUp(() {
    current = QuestProgressDataset.parsePayload(
      jsonEncode({
        'meta': {'name': 'questgoal', 'version': '2026/10/01/01'},
        'data': {
          '201': {
            'type': 1,
            'battle': {'description': 'battle', 'required': 1},
          },
          '210': {
            'type': 1,
            'battle': {'description': 'battle', 'required': 10},
          },
        },
      }),
      sourceCommit: 'a' * 40,
    );
    storage = _Storage();
  });
  QuestProgressUpdateService service(
    http.Client client, {
    int maximumDataBytes = 2 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 1),
  }) => QuestProgressUpdateService(
    client: client,
    store: QuestProgressDatasetStore(storage),
    maximumDataBytes: maximumDataBytes,
    timeout: timeout,
  );

  test(
    'downloads immutable commit, overlays IDs and stores before returning',
    () async {
      final requests = <Uri>[];
      final updater = service(
        MockClient((request) async {
          requests.add(request.url);
          expect(request.followRedirects, isFalse);
          if (request.url.host == 'api.github.com') {
            expect(request.url.queryParameters, {
              'path': 'assets/data/fcd/questgoal.json',
              'per_page': '1',
            });
            return http.Response(metadata(), 200);
          }
          expect(
            request.url.path,
            '/poooi/poi/$commit/assets/data/fcd/questgoal.json',
          );
          return http.Response(payload('2026/10/02/01'), 200);
        }),
      );

      final result = await updater.checkAndUpdate(current: current);

      expect(result, isA<QuestProgressUpdated>());
      final updated = (result as QuestProgressUpdated).dataset;
      expect(updated.goals[201]!.raw['battle']['required'], 2);
      expect(updated.goals, contains(210));
      expect(updated.sourceCommit, commit);
      expect(result.sourceHost, 'raw.githubusercontent.com');
      expect(storage.value, isNotNull);
      expect(requests, hasLength(2));
    },
  );

  test(
    'same version returns up to date without replacing or caching rules',
    () async {
      final updater = service(
        MockClient(
          (request) async => http.Response(
            request.url.host == 'api.github.com'
                ? metadata()
                : payload(current.version, required: 99),
            200,
          ),
        ),
      );
      final result = await updater.checkAndUpdate(current: current);
      expect(result, isA<QuestProgressUpToDate>());
      expect((result as QuestProgressUpToDate).version, current.version);
      expect(storage.value, isNull);
    },
  );

  test('older versions are rejected without writes', () async {
    final updater = service(
      MockClient(
        (request) async => http.Response(
          request.url.host == 'api.github.com'
              ? metadata()
              : payload('2026/09/30/01'),
          200,
        ),
      ),
    );
    final result = await updater.checkAndUpdate(current: current);
    expect(result, isA<QuestProgressUpdateFailed>());
    expect(
      (result as QuestProgressUpdateFailed).kind,
      QuestProgressUpdateFailure.validation,
    );
    expect(storage.value, isNull);
  });

  test('uses only same commit CDN fallback after raw HTTP failure', () async {
    final updater = service(
      MockClient((request) async {
        switch (request.url.host) {
          case 'api.github.com':
            return http.Response(metadata(), 200);
          case 'raw.githubusercontent.com':
            return http.Response('{"error":"try later"}', 503);
          case 'cdn.jsdelivr.net':
            expect(
              request.url.path,
              '/gh/poooi/poi@$commit/assets/data/fcd/questgoal.json',
            );
            return http.Response(payload('2026/10/02/01'), 200);
          default:
            fail('Unexpected URL ${request.url}');
        }
      }),
    );
    final result = await updater.checkAndUpdate(current: current);
    expect(result, isA<QuestProgressUpdated>());
    expect(result.sourceHost, 'cdn.jsdelivr.net');
  });

  test(
    'HTTP error bodies and redirects are never interpreted or followed',
    () async {
      final requests = <Uri>[];
      final updater = service(
        MockClient((request) async {
          requests.add(request.url);
          if (request.url.host == 'api.github.com') {
            return http.Response(metadata(), 200);
          }
          return http.Response(
            payload('2026/10/02/01'),
            302,
            headers: {'location': 'https://evil.test/rules'},
          );
        }),
      );
      final result = await updater.checkAndUpdate(current: current);
      expect(
        (result as QuestProgressUpdateFailed).kind,
        QuestProgressUpdateFailure.network,
      );
      expect(requests.map((uri) => uri.host), everyElement(isNot('evil.test')));
      expect(storage.value, isNull);
    },
  );

  test(
    'invalid commit metadata and malformed rule schema fail validation',
    () async {
      for (final invalid in [
        '[]',
        metadata('../master'),
        '{"message":"rate limit"}',
      ]) {
        final result = await service(
          MockClient((_) async => http.Response(invalid, 200)),
        ).checkAndUpdate(current: current);
        expect(
          (result as QuestProgressUpdateFailed).kind,
          QuestProgressUpdateFailure.validation,
        );
      }
      final result = await service(
        MockClient(
          (request) async => http.Response(
            request.url.host == 'api.github.com'
                ? metadata()
                : '{"meta":{"name":"questgoal","version":"2026/10/02/01"},"data":{"201":false}}',
            200,
          ),
        ),
      ).checkAndUpdate(current: current);
      expect(
        (result as QuestProgressUpdateFailed).kind,
        QuestProgressUpdateFailure.validation,
      );
      expect(storage.value, isNull);
    },
  );

  test(
    'limits accumulated received bytes without trusting content length',
    () async {
      final updater = service(
        _StreamingClient((request) async {
          final bytes = utf8.encode(
            request.url.host == 'api.github.com' ? metadata() : ' ' * 600,
          );
          return http.StreamedResponse(
            Stream.fromIterable([bytes.sublist(0, 30), bytes.sublist(30)]),
            200,
          );
        }),
        maximumDataBytes: 400,
      );
      final result = await updater.checkAndUpdate(current: current);
      expect(
        (result as QuestProgressUpdateFailed).kind,
        QuestProgressUpdateFailure.validation,
      );
      expect(storage.value, isNull);
    },
  );

  test('times out while waiting for response headers', () async {
    final updater = service(
      _StreamingClient((_) => Completer<http.StreamedResponse>().future),
      timeout: const Duration(milliseconds: 20),
    );
    final result = await updater.checkAndUpdate(current: current);
    expect(
      (result as QuestProgressUpdateFailed).kind,
      QuestProgressUpdateFailure.network,
    );
  });

  test('enforces a total stream deadline despite frequent chunks', () async {
    final updater = service(
      _StreamingClient((request) async {
        if (request.url.host == 'api.github.com') {
          return http.StreamedResponse(
            Stream.value(utf8.encode(metadata())),
            200,
          );
        }
        return http.StreamedResponse(
          Stream<int>.periodic(
            const Duration(milliseconds: 30),
            (_) => 32,
          ).take(10).map((byte) => [byte]),
          200,
        );
      }),
      timeout: const Duration(milliseconds: 80),
    );
    final result = await updater.checkAndUpdate(current: current);
    expect(
      (result as QuestProgressUpdateFailed).kind,
      QuestProgressUpdateFailure.network,
    );
    expect(storage.value, isNull);
  });

  test(
    'all storage exceptions are reported without an updated result',
    () async {
      storage.failWrite = true;
      final result = await service(
        MockClient(
          (request) async => http.Response(
            request.url.host == 'api.github.com'
                ? metadata()
                : payload('2026/10/02/01'),
            200,
          ),
        ),
      ).checkAndUpdate(current: current);
      expect(
        (result as QuestProgressUpdateFailed).kind,
        QuestProgressUpdateFailure.storage,
      );
      expect(storage.value, isNull);
    },
  );

  test('offline failures preserve previously verified cached rules', () async {
    await QuestProgressDatasetStore(storage).save(current);
    final cached = storage.value;
    final result = await service(
      MockClient((_) async => throw http.ClientException('offline')),
    ).checkAndUpdate(current: current);
    expect(
      (result as QuestProgressUpdateFailed).kind,
      QuestProgressUpdateFailure.network,
    );
    expect(storage.value, cached);
  });
}

final class _Storage implements QuestProgressDatasetStorage {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String raw) async {
    if (failWrite) throw StateError('full');
    value = raw;
  }
}

final class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
