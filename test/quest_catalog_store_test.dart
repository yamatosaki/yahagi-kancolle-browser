import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_store.dart';

void main() {
  String raw(String name) => jsonEncode(<String, Object?>{
    '1': <String, Object?>{'code': 'A1', 'name': name, 'desc': ''},
  });

  QuestCatalogVersion version(String data, int day) => QuestCatalogVersion(
    committedAt: DateTime.utc(2026, 8, day),
    commitSha: day.toRadixString(16).padLeft(40, '0'),
    sha256: sha256.convert(utf8.encode(data)).toString(),
  );

  test(
    'loads newer valid cache and falls back when cache is invalid',
    () async {
      final bundled = raw('bundled');
      final cached = raw('cached');
      final storage = _MemoryStorage(
        bundledData: bundled,
        bundledMetadata: version(bundled, 1).toJson(),
        cachedData: cached,
        cachedMetadata: version(cached, 2).toJson(),
      );
      final store = QuestCatalogStore(storage, minimumQuestCount: 1);

      expect(
        (await store.loadBestAvailable()).source,
        QuestCatalogSource.cache,
      );
      storage.cachedData = '{broken';
      expect(
        (await store.loadBestAvailable()).source,
        QuestCatalogSource.bundled,
      );
    },
  );

  test('recovers valid backup after interrupted replacement', () async {
    final directory = await Directory.systemTemp.createTemp('quest-store-');
    addTearDown(() => directory.delete(recursive: true));
    final dataFile = File(
      '${directory.path}${Platform.pathSeparator}quest.json',
    );
    final metaFile = File(
      '${directory.path}${Platform.pathSeparator}meta.json',
    );
    final old = raw('old');
    await File('${dataFile.path}.bak').writeAsString(old);
    await File('${metaFile.path}.bak').writeAsString(version(old, 1).toJson());
    final storage = ApplicationQuestCatalogStorage(
      bundledDataReader: () async => old,
      bundledMetadataReader: () async => version(old, 1).toJson(),
      cacheDataFile: dataFile,
      cacheMetadataFile: metaFile,
      stateFile: File('${directory.path}${Platform.pathSeparator}state.json'),
      minimumQuestCount: 1,
    );

    expect(await storage.readCachedData(), old);
    expect(await dataFile.exists(), isTrue);
    expect(await File('${dataFile.path}.bak').exists(), isFalse);
  });

  test('persists update state separately', () async {
    final storage = _MemoryStorage(
      bundledData: raw('bundled'),
      bundledMetadata: version(raw('bundled'), 1).toJson(),
    );
    final store = QuestCatalogStore(storage, minimumQuestCount: 1);
    final state = QuestCatalogState(
      version: version(raw('bundled'), 1),
      source: 'raw.githubusercontent.com',
      lastCheckedAt: DateTime.utc(2026, 8, 9),
      result: 'updated',
    );

    await store.saveState(state);
    expect((await store.loadState())?.result, 'updated');
  });
}

final class _MemoryStorage
    implements QuestCatalogStorage, QuestCatalogStateStorage {
  _MemoryStorage({
    required this.bundledData,
    required this.bundledMetadata,
    this.cachedData,
    this.cachedMetadata,
  });

  final String bundledData;
  final String bundledMetadata;
  String? cachedData;
  String? cachedMetadata;
  String? state;

  @override
  Future<String> readBundledData() async => bundledData;
  @override
  Future<String> readBundledMetadata() async => bundledMetadata;
  @override
  Future<String?> readCachedData() async => cachedData;
  @override
  Future<String?> readCachedMetadata() async => cachedMetadata;
  @override
  Future<void> writeCached(QuestCatalogDataset dataset) async {
    cachedData = dataset.rawJson;
    cachedMetadata = dataset.version.toJson();
  }

  @override
  Future<String?> readState() async => state;
  @override
  Future<void> writeState(String rawJson) async => state = rawJson;
}
