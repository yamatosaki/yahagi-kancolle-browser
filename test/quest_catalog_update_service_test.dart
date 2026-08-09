import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_update_service.dart';

void main() {
  String raw(String name) => jsonEncode(<String, Object?>{
    '1': <String, Object?>{'code': 'A1', 'name': name, 'desc': ''},
  });

  QuestCatalogDataset dataset(String name, int day, String sha) {
    final data = raw(name);
    return QuestCatalogDataset.parse(
      rawJson: data,
      version: QuestCatalogVersion(
        committedAt: DateTime.utc(2026, 8, day),
        commitSha: sha,
        sha256: sha256.convert(utf8.encode(data)).toString(),
      ),
      minimumQuestCount: 1,
    );
  }

  test('downloads and stores a newer immutable revision', () async {
    final current = dataset('old', 1, 'a' * 40);
    final newerRaw = raw('new');
    final remoteSha = 'b' * 40;
    final storage = _Storage(current);
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com') {
        return http.Response(
          jsonEncode(<Object?>[
            <String, Object?>{
              'sha': remoteSha,
              'commit': <String, Object?>{
                'committer': <String, Object?>{'date': '2026-08-09T00:00:00Z'},
              },
            },
          ]),
          200,
        );
      }
      expect(request.url.path, contains(remoteSha));
      return http.Response(newerRaw, 200);
    });
    final service = QuestCatalogUpdateService(
      client: client,
      store: QuestCatalogStore(storage, minimumQuestCount: 1),
      minimumQuestCount: 1,
    );

    final result = await service.checkAndUpdate(current: current);

    expect(result, isA<QuestCatalogUpdated>());
    expect(storage.saved?.version.commitSha, remoteSha);
  });

  test('uses jsDelivr when the raw download fails', () async {
    final current = dataset('old', 1, 'a' * 40);
    final remoteSha = 'b' * 40;
    final storage = _Storage(current);
    final client = MockClient((request) async {
      if (request.url.host == 'api.github.com') {
        return http.Response(
          '[{"sha":"$remoteSha","commit":{"committer":{"date":"2026-08-09T00:00:00Z"}}}]',
          200,
        );
      }
      if (request.url.host == 'raw.githubusercontent.com') {
        return http.Response('unavailable', 503);
      }
      return http.Response(raw('cdn'), 200);
    });
    final service = QuestCatalogUpdateService(
      client: client,
      store: QuestCatalogStore(storage, minimumQuestCount: 1),
      minimumQuestCount: 1,
    );

    final result = await service.checkAndUpdate(current: current);

    expect(result, isA<QuestCatalogUpdated>());
    expect(result.sourceHost, 'cdn.jsdelivr.net');
  });
}

final class _Storage implements QuestCatalogStorage, QuestCatalogStateStorage {
  _Storage(this.initial);
  final QuestCatalogDataset initial;
  QuestCatalogDataset? saved;
  String? state;

  @override
  Future<String> readBundledData() async => initial.rawJson;
  @override
  Future<String> readBundledMetadata() async => initial.version.toJson();
  @override
  Future<String?> readCachedData() async => saved?.rawJson;
  @override
  Future<String?> readCachedMetadata() async => saved?.version.toJson();
  @override
  Future<void> writeCached(QuestCatalogDataset dataset) async =>
      saved = dataset;
  @override
  Future<String?> readState() async => state;
  @override
  Future<void> writeState(String rawJson) async => state = rawJson;
}
