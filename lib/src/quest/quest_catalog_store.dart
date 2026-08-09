// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'quest_catalog_dataset.dart';

enum QuestCatalogSource { bundled, cache }

final class LoadedQuestCatalog {
  const LoadedQuestCatalog({required this.dataset, required this.source});

  final QuestCatalogDataset dataset;
  final QuestCatalogSource source;
}

final class QuestCatalogState {
  const QuestCatalogState({
    required this.version,
    required this.source,
    required this.lastCheckedAt,
    required this.result,
  });

  final QuestCatalogVersion version;
  final String source;
  final DateTime? lastCheckedAt;
  final String result;

  factory QuestCatalogState.fromJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] is! Map<String, dynamic> ||
        decoded['source'] is! String ||
        decoded['result'] is! String) {
      throw const FormatException('Quest catalog state is invalid');
    }
    return QuestCatalogState(
      version: QuestCatalogVersion.fromJson(jsonEncode(decoded['version'])),
      source: decoded['source'] as String,
      lastCheckedAt: decoded['lastCheckedAt'] is String
          ? DateTime.tryParse(decoded['lastCheckedAt'] as String)?.toUtc()
          : null,
      result: decoded['result'] as String,
    );
  }

  String toJson() => jsonEncode(<String, Object?>{
    'version': jsonDecode(version.toJson()),
    'source': source,
    'lastCheckedAt': lastCheckedAt?.toUtc().toIso8601String(),
    'result': result,
  });
}

abstract interface class QuestCatalogStorage {
  Future<String> readBundledData();
  Future<String> readBundledMetadata();
  Future<String?> readCachedData();
  Future<String?> readCachedMetadata();
  Future<void> writeCached(QuestCatalogDataset dataset);
}

abstract interface class QuestCatalogStateStorage {
  Future<String?> readState();
  Future<void> writeState(String rawJson);
}

final class BundledOnlyQuestCatalogStorage implements QuestCatalogStorage {
  const BundledOnlyQuestCatalogStorage();

  @override
  Future<String> readBundledData() =>
      rootBundle.loadString(ApplicationQuestCatalogStorage.bundledDataPath);
  @override
  Future<String> readBundledMetadata() =>
      rootBundle.loadString(ApplicationQuestCatalogStorage.bundledMetadataPath);
  @override
  Future<String?> readCachedData() async => null;
  @override
  Future<String?> readCachedMetadata() async => null;
  @override
  Future<void> writeCached(QuestCatalogDataset dataset) => Future<void>.error(
    const FileSystemException('Application support directory is unavailable'),
  );
}

final class QuestCatalogStore {
  const QuestCatalogStore(this.storage, {this.minimumQuestCount = 500});

  final QuestCatalogStorage storage;
  final int minimumQuestCount;

  Future<LoadedQuestCatalog> loadBestAvailable() async {
    final bundled = _parse(
      await storage.readBundledData(),
      await storage.readBundledMetadata(),
    );
    QuestCatalogDataset? cached;
    try {
      final data = await storage.readCachedData();
      final metadata = await storage.readCachedMetadata();
      if (data != null && metadata != null) cached = _parse(data, metadata);
    } catch (_) {
      cached = null;
    }
    if (cached != null && cached.version.compareTo(bundled.version) >= 0) {
      return LoadedQuestCatalog(
        dataset: cached,
        source: QuestCatalogSource.cache,
      );
    }
    return LoadedQuestCatalog(
      dataset: bundled,
      source: QuestCatalogSource.bundled,
    );
  }

  QuestCatalogDataset _parse(String data, String metadata) =>
      QuestCatalogDataset.parse(
        rawJson: data,
        version: QuestCatalogVersion.fromJson(metadata),
        minimumQuestCount: minimumQuestCount,
      );

  Future<void> save(QuestCatalogDataset dataset) =>
      storage.writeCached(dataset);

  Future<QuestCatalogState?> loadState() async {
    if (storage is! QuestCatalogStateStorage) return null;
    try {
      final raw = await (storage as QuestCatalogStateStorage).readState();
      return raw == null ? null : QuestCatalogState.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveState(QuestCatalogState state) async {
    if (storage is QuestCatalogStateStorage) {
      await (storage as QuestCatalogStateStorage).writeState(state.toJson());
    }
  }
}

final class ApplicationQuestCatalogStorage
    implements QuestCatalogStorage, QuestCatalogStateStorage {
  ApplicationQuestCatalogStorage({
    required Future<String> Function() bundledDataReader,
    required Future<String> Function() bundledMetadataReader,
    required this.cacheDataFile,
    required this.cacheMetadataFile,
    required this.stateFile,
    this.minimumQuestCount = 500,
  }) : _bundledDataReader = bundledDataReader,
       _bundledMetadataReader = bundledMetadataReader;

  static const bundledDataPath = 'assets/data/quests-scn.json';
  static const bundledMetadataPath = 'assets/data/quests-meta.json';

  static Future<ApplicationQuestCatalogStorage> create() async {
    final directory = await getApplicationSupportDirectory();
    return ApplicationQuestCatalogStorage(
      bundledDataReader: () => rootBundle.loadString(bundledDataPath),
      bundledMetadataReader: () => rootBundle.loadString(bundledMetadataPath),
      cacheDataFile: File(path.join(directory.path, 'quest-catalog.json')),
      cacheMetadataFile: File(
        path.join(directory.path, 'quest-catalog-meta.json'),
      ),
      stateFile: File(path.join(directory.path, 'quest-catalog-state.json')),
    );
  }

  final Future<String> Function() _bundledDataReader;
  final Future<String> Function() _bundledMetadataReader;
  final File cacheDataFile;
  final File cacheMetadataFile;
  final File stateFile;
  final int minimumQuestCount;

  @override
  Future<String> readBundledData() => _bundledDataReader();
  @override
  Future<String> readBundledMetadata() => _bundledMetadataReader();
  @override
  Future<String?> readCachedData() => _readRecovering(cacheDataFile);
  @override
  Future<String?> readCachedMetadata() => _readRecovering(cacheMetadataFile);
  @override
  Future<String?> readState() => _readRecovering(stateFile);

  @override
  Future<void> writeCached(QuestCatalogDataset dataset) async {
    await _writeAtomically(cacheDataFile, dataset.rawJson);
    await _writeAtomically(cacheMetadataFile, dataset.version.toJson());
    QuestCatalogDataset.parse(
      rawJson: await cacheDataFile.readAsString(),
      version: QuestCatalogVersion.fromJson(
        await cacheMetadataFile.readAsString(),
      ),
      minimumQuestCount: minimumQuestCount,
    );
  }

  @override
  Future<void> writeState(String rawJson) async {
    QuestCatalogState.fromJson(rawJson);
    await _writeAtomically(stateFile, rawJson);
  }

  Future<String?> _readRecovering(File file) async {
    final backup = File('${file.path}.bak');
    if (!await file.exists() && await backup.exists()) {
      await file.parent.create(recursive: true);
      await backup.rename(file.path);
    } else if (await file.exists() && await backup.exists()) {
      await backup.delete();
    }
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> _writeAtomically(File target, String raw) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    try {
      await temporary.writeAsString(raw, flush: true);
      if (await backup.exists()) await backup.delete();
      if (await target.exists()) await target.rename(backup.path);
      try {
        await temporary.rename(target.path);
        if (await backup.exists()) await backup.delete();
      } catch (_) {
        if (await target.exists()) await target.delete();
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
