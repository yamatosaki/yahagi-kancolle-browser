// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'fcd_map_dataset.dart';

enum FcdMapSource { bundled, cache, empty }

final class LoadedFcdMap {
  const LoadedFcdMap({
    required this.dataset,
    required this.source,
    this.diagnosticError,
  });

  final FcdMapDataset dataset;
  final FcdMapSource source;
  final String? diagnosticError;
}

final class FcdMapState {
  const FcdMapState({
    required this.version,
    required this.source,
    required this.lastCheckedAt,
    required this.result,
  });

  final String version;
  final String source;
  final DateTime? lastCheckedAt;
  final String result;

  factory FcdMapState.fromJson(String rawJson) {
    final value = jsonDecode(rawJson);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('FCD state root must be an object');
    }
    final version = value['version'];
    final source = value['source'];
    final result = value['result'];
    final checked = value['lastCheckedAt'];
    if (version is! String || source is! String || result is! String) {
      throw const FormatException('FCD state fields are invalid');
    }
    FcdMapVersion.parse(version);
    return FcdMapState(
      version: version,
      source: source,
      lastCheckedAt: checked is String ? DateTime.tryParse(checked) : null,
      result: result,
    );
  }

  String toJson() => jsonEncode(<String, Object?>{
    'version': version,
    'source': source,
    'lastCheckedAt': lastCheckedAt?.toUtc().toIso8601String(),
    'result': result,
  });
}

abstract interface class FcdMapStorage {
  Future<String> readBundled();

  Future<String?> readCached();

  Future<void> writeCached(String rawJson);
}

abstract interface class FcdMapStateStorage {
  Future<String?> readState();

  Future<void> writeState(String rawJson);
}

final class BundledOnlyFcdMapStorage implements FcdMapStorage {
  const BundledOnlyFcdMapStorage();

  @override
  Future<String> readBundled() =>
      rootBundle.loadString(ApplicationFcdMapStorage.bundledAssetPath);

  @override
  Future<String?> readCached() async => null;

  @override
  Future<void> writeCached(String rawJson) => Future<void>.error(
    const FileSystemException('FCD application data directory is unavailable'),
  );
}

final class FcdMapStore {
  const FcdMapStore(this.storage, {this.minimumMapCount = 50});

  final FcdMapStorage storage;
  final int minimumMapCount;

  Future<LoadedFcdMap> loadBestAvailable() async {
    FcdMapDataset? cached;
    FcdMapDataset? bundled;
    final errors = <String>[];
    try {
      final rawCached = await storage.readCached();
      if (rawCached != null) {
        cached = FcdMapDataset.parse(
          rawCached,
          minimumMapCount: minimumMapCount,
        );
      }
    } catch (error) {
      errors.add('cache: ${error.runtimeType}');
    }
    try {
      bundled = FcdMapDataset.parse(
        await storage.readBundled(),
        minimumMapCount: minimumMapCount,
      );
    } catch (error) {
      errors.add('bundled: ${error.runtimeType}');
    }

    if (cached != null &&
        (bundled == null || cached.version.compareTo(bundled.version) >= 0)) {
      return LoadedFcdMap(
        dataset: cached,
        source: FcdMapSource.cache,
        diagnosticError: errors.isEmpty ? null : errors.join(', '),
      );
    }
    if (bundled != null) {
      return LoadedFcdMap(
        dataset: bundled,
        source: FcdMapSource.bundled,
        diagnosticError: errors.isEmpty ? null : errors.join(', '),
      );
    }
    return LoadedFcdMap(
      dataset: FcdMapDataset.empty(),
      source: FcdMapSource.empty,
      diagnosticError: errors.join(', '),
    );
  }

  Future<FcdMapState?> loadState() async {
    if (storage is! FcdMapStateStorage) return null;
    final stateStorage = storage as FcdMapStateStorage;
    try {
      final raw = await stateStorage.readState();
      return raw == null ? null : FcdMapState.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(FcdMapDataset dataset) =>
      storage.writeCached(dataset.rawJson);

  Future<void> saveState(FcdMapState state) async {
    if (storage is FcdMapStateStorage) {
      final stateStorage = storage as FcdMapStateStorage;
      await stateStorage.writeState(state.toJson());
    }
  }
}

final class ApplicationFcdMapStorage
    implements FcdMapStorage, FcdMapStateStorage {
  ApplicationFcdMapStorage({
    required Future<String> Function() bundledReader,
    required this.cacheFile,
    File? stateFile,
    Future<void> Function()? beforeReplace,
    this.minimumMapCount = 50,
  }) : _bundledReader = bundledReader,
       stateFile =
           stateFile ??
           File(path.join(cacheFile.parent.path, 'fcd-map-state.json')),
       _beforeReplace = beforeReplace;

  static const bundledAssetPath = 'assets/data/fcd/map.json';

  static Future<ApplicationFcdMapStorage> create() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return ApplicationFcdMapStorage(
      bundledReader: () => rootBundle.loadString(bundledAssetPath),
      cacheFile: File(path.join(supportDirectory.path, 'fcd-map.json')),
      stateFile: File(path.join(supportDirectory.path, 'fcd-map-state.json')),
    );
  }

  final Future<String> Function() _bundledReader;
  final Future<void> Function()? _beforeReplace;
  final File cacheFile;
  final File stateFile;
  final int minimumMapCount;

  @override
  Future<String> readBundled() => _bundledReader();

  @override
  Future<String?> readCached() async {
    await _recoverBackup(cacheFile, validateDataset: true);
    if (!await cacheFile.exists()) return null;
    return cacheFile.readAsString();
  }

  @override
  Future<String?> readState() async {
    await _recoverBackup(stateFile, validateDataset: false);
    if (!await stateFile.exists()) return null;
    return stateFile.readAsString();
  }

  @override
  Future<void> writeCached(String rawJson) => _writeAtomically(
    cacheFile,
    rawJson,
    (raw) => FcdMapDataset.parse(raw, minimumMapCount: minimumMapCount),
  );

  @override
  Future<void> writeState(String rawJson) =>
      _writeAtomically(stateFile, rawJson, FcdMapState.fromJson);

  Future<void> _writeAtomically(
    File target,
    String rawJson,
    Object? Function(String) validate,
  ) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    try {
      await temporary.writeAsString(rawJson, flush: true);
      validate(await temporary.readAsString());
      await _beforeReplace?.call();

      if (await backup.exists()) await backup.delete();
      final hadPrevious = await target.exists();
      if (hadPrevious) await target.rename(backup.path);
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

  Future<void> _recoverBackup(
    File target, {
    required bool validateDataset,
  }) async {
    final backup = File('${target.path}.bak');
    if (!await backup.exists()) return;
    if (await target.exists()) {
      try {
        _validateRecovered(
          await target.readAsString(),
          validateDataset: validateDataset,
        );
        await backup.delete();
        return;
      } catch (_) {
        _validateRecovered(
          await backup.readAsString(),
          validateDataset: validateDataset,
        );
        await target.delete();
        await backup.rename(target.path);
        return;
      }
    }
    final raw = await backup.readAsString();
    _validateRecovered(raw, validateDataset: validateDataset);
    await backup.rename(target.path);
  }

  void _validateRecovered(String raw, {required bool validateDataset}) {
    if (validateDataset) {
      FcdMapDataset.parse(raw, minimumMapCount: minimumMapCount);
    } else {
      FcdMapState.fromJson(raw);
    }
  }
}
