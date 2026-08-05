import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_store.dart';

String _dataset(String version, {String destination = 'Y'}) =>
    '''
{"meta":{"name":"map","version":"$version"},"data":{"5-6":{"route":{"42":["X","$destination"]}}}}
''';

void main() {
  test('prefers a valid cache over the bundled snapshot', () async {
    final storage = _MemoryStorage(
      bundled: _dataset('2026/07/01/01'),
      cached: _dataset('2026/07/28/02'),
    );
    final loaded = await FcdMapStore(
      storage,
      minimumMapCount: 1,
    ).loadBestAvailable();

    expect(loaded.source, FcdMapSource.cache);
    expect(loaded.dataset.version, FcdMapVersion.parse('2026/07/28/02'));
  });

  test('falls back to the bundled snapshot when cache is invalid', () async {
    final storage = _MemoryStorage(
      bundled: _dataset('2026/07/01/01'),
      cached: '{broken',
    );
    final loaded = await FcdMapStore(
      storage,
      minimumMapCount: 1,
    ).loadBestAvailable();

    expect(loaded.source, FcdMapSource.bundled);
    expect(loaded.dataset.version, FcdMapVersion.parse('2026/07/01/01'));
  });

  test(
    'does not choose an older valid cache over the bundled snapshot',
    () async {
      final storage = _MemoryStorage(
        bundled: _dataset('2026/07/28/02'),
        cached: _dataset('2026/07/01/01'),
      );
      final loaded = await FcdMapStore(
        storage,
        minimumMapCount: 1,
      ).loadBestAvailable();

      expect(loaded.source, FcdMapSource.bundled);
      expect(loaded.dataset.version, FcdMapVersion.parse('2026/07/28/02'));
    },
  );

  test('uses a valid cache even when the bundled snapshot is broken', () async {
    final loaded = await FcdMapStore(
      _MemoryStorage(bundled: '{broken', cached: _dataset('2026/07/28/02')),
      minimumMapCount: 1,
    ).loadBestAvailable();

    expect(loaded.source, FcdMapSource.cache);
    expect(loaded.diagnosticError, contains('bundled'));
  });

  test('returns an empty resolver when cache and bundle are broken', () async {
    final loaded = await FcdMapStore(
      _MemoryStorage(bundled: '{broken', cached: '{also broken'),
      minimumMapCount: 1,
    ).loadBestAvailable();

    expect(loaded.source, FcdMapSource.empty);
    expect(loaded.dataset.routeCount, 0);
    expect(
      loaded.dataset.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 42),
      isNull,
    );
  });

  test('a failed cache write leaves the previous file readable', () async {
    final directory = await Directory.systemTemp.createTemp('fcd-store-test-');
    addTearDown(() => directory.delete(recursive: true));
    final cacheFile = File(
      '${directory.path}${Platform.pathSeparator}map.json',
    );
    await cacheFile.writeAsString(_dataset('2026/07/01/01'));
    final storage = ApplicationFcdMapStorage(
      bundledReader: () async => _dataset('2026/07/01/01'),
      cacheFile: cacheFile,
      beforeReplace: () => throw const FileSystemException('simulated'),
      minimumMapCount: 1,
    );

    expect(
      () => storage.writeCached(_dataset('2026/07/28/02')),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      FcdMapDataset.parse(
        await cacheFile.readAsString(),
        minimumMapCount: 1,
      ).version,
      FcdMapVersion.parse('2026/07/01/01'),
    );
  });

  test(
    'atomically replaces the cache after validating the temporary file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fcd-store-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final cacheFile = File(
        '${directory.path}${Platform.pathSeparator}map.json',
      );
      await cacheFile.writeAsString(_dataset('2026/07/01/01'));
      final storage = ApplicationFcdMapStorage(
        bundledReader: () async => _dataset('2026/07/01/01'),
        cacheFile: cacheFile,
        minimumMapCount: 1,
      );

      await storage.writeCached(_dataset('2026/07/28/02'));

      expect(
        FcdMapDataset.parse(
          await cacheFile.readAsString(),
          minimumMapCount: 1,
        ).version,
        FcdMapVersion.parse('2026/07/28/02'),
      );
      expect(File('${cacheFile.path}.tmp').existsSync(), isFalse);
      expect(File('${cacheFile.path}.bak').existsSync(), isFalse);
    },
  );

  test('recovers a backup left by an interrupted replacement', () async {
    final directory = await Directory.systemTemp.createTemp('fcd-store-test-');
    addTearDown(() => directory.delete(recursive: true));
    final cacheFile = File(
      '${directory.path}${Platform.pathSeparator}map.json',
    );
    await File(
      '${cacheFile.path}.bak',
    ).writeAsString(_dataset('2026/07/01/01'));
    final storage = ApplicationFcdMapStorage(
      bundledReader: () async => _dataset('2026/07/01/01'),
      cacheFile: cacheFile,
      minimumMapCount: 1,
    );

    expect(await storage.readCached(), contains('2026/07/01/01'));
    expect(await cacheFile.exists(), isTrue);
    expect(await File('${cacheFile.path}.bak').exists(), isFalse);
  });

  test('persists update source and last-check state separately', () async {
    final directory = await Directory.systemTemp.createTemp('fcd-store-test-');
    addTearDown(() => directory.delete(recursive: true));
    final storage = ApplicationFcdMapStorage(
      bundledReader: () async => _dataset('2026/07/01/01'),
      cacheFile: File('${directory.path}${Platform.pathSeparator}fcd-map.json'),
      minimumMapCount: 1,
    );
    final store = FcdMapStore(storage, minimumMapCount: 1);
    final checkedAt = DateTime.utc(2026, 8, 5, 14, 30);

    await store.saveState(
      FcdMapState(
        version: '2026/07/28/02',
        source: 'raw.githubusercontent.com',
        lastCheckedAt: checkedAt,
        result: 'upToDate',
      ),
    );

    final state = await store.loadState();
    expect(state?.source, 'raw.githubusercontent.com');
    expect(state?.lastCheckedAt, checkedAt);
  });
}

final class _MemoryStorage implements FcdMapStorage {
  _MemoryStorage({required this.bundled, this.cached});

  final String bundled;
  String? cached;

  @override
  Future<String> readBundled() async => bundled;

  @override
  Future<String?> readCached() async => cached;

  @override
  Future<void> writeCached(String rawJson) async {
    cached = rawJson;
  }
}
