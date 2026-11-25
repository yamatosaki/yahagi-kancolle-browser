import 'package:flutter/foundation.dart';

import 'game_mods_library.dart';

Map<String, dynamic> gameModsMap(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};
List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
int _int(Object? value) => value is num ? value.toInt() : 0;

/// A read-only native snapshot. Null totals mean discovery is still in progress.
class GameModsOperationProgress {
  const GameModsOperationProgress({
    required this.operationId,
    required this.operation,
    required this.phase,
    required this.active,
    this.completedPackages = 0,
    this.totalPackages,
    this.currentPackage,
    this.currentFile,
    this.completedFiles,
    this.totalFiles,
    this.completedBytes,
    this.totalBytes,
    this.elapsedMillis = 0,
  });
  final String operationId, operation, phase;
  final bool active;
  final int completedPackages, elapsedMillis;
  final int? totalPackages,
      completedFiles,
      totalFiles,
      completedBytes,
      totalBytes;
  final String? currentPackage, currentFile;

  factory GameModsOperationProgress.fromMap(Map<String, dynamic> map) {
    int? count(String key) =>
        map[key] is num ? (map[key] as num).toInt().clamp(0, 1 << 62) : null;
    return GameModsOperationProgress(
      operationId: map['operationId'] as String? ?? '',
      operation: map['operation'] as String? ?? '',
      phase: map['phase'] as String? ?? 'discover',
      active: map['active'] == true,
      completedPackages: count('completedPackages') ?? 0,
      totalPackages: count('totalPackages'),
      currentPackage: map['currentPackage'] as String?,
      currentFile: map['currentFile'] as String?,
      completedFiles: count('completedFiles'),
      totalFiles: count('totalFiles'),
      completedBytes: count('completedBytes'),
      totalBytes: count('totalBytes'),
      elapsedMillis: count('elapsedMillis') ?? 0,
    );
  }

  double? get fraction {
    if (phase == 'discover') return null;
    for (final (done, total) in [
      (completedBytes, totalBytes),
      (completedFiles, totalFiles),
      (completedPackages, totalPackages),
    ]) {
      if (done != null && total != null && total > 0) {
        return (done / total).clamp(0, 1);
      }
    }
    return null;
  }
}

class GameModsCapabilities {
  const GameModsCapabilities({
    required this.supported,
    this.reason,
    this.archiveUpdateSupported = false,
  });
  final bool supported, archiveUpdateSupported;
  final String? reason;
  factory GameModsCapabilities.fromMap(Map<String, dynamic> map) =>
      GameModsCapabilities(
        supported: map['supported'] == true,
        reason: map['reason'] as String?,
        archiveUpdateSupported: map['archiveUpdateSupported'] == true,
      );
}

class GameModResource {
  const GameModResource({
    required this.id,
    required this.path,
    required this.kind,
    required this.label,
    required this.supported,
    this.reason,
    this.groupId,
    this.sourcePaths = const [],
    this.targetPaths = const [],
  });
  final String id, path, kind, label;
  final bool supported;
  final String? reason, groupId;
  final List<String> sourcePaths, targetPaths;
  bool get isCoordinates => kind == 'coordinates';
  List<String> get targets => targetPaths.isEmpty ? [path] : targetPaths;
  List<String> get sources => sourcePaths.isEmpty ? [path] : sourcePaths;
  factory GameModResource.fromMap(Map<String, dynamic> map) => GameModResource(
    id: map['id'] as String? ?? '',
    path: map['path'] as String? ?? '',
    kind: map['kind'] as String? ?? 'other',
    label: map['label'] as String? ?? '',
    supported: map['supported'] == true,
    reason: map['reason'] as String?,
    groupId: map['groupId'] as String?,
    sourcePaths: _strings(map['sourcePaths']),
    targetPaths: _strings(map['targetPaths']),
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'path': path,
    'kind': kind,
    'label': label,
    'supported': supported,
    'reason': reason,
    'groupId': groupId,
    'sourcePaths': sourcePaths,
    'targetPaths': targets,
  };
}

class GameModPackage {
  const GameModPackage({
    required this.id,
    required this.name,
    this.sizeBytes = 0,
    this.importedAt,
    this.resources = const [],
    this.warnings = const [],
    this.pendingRemoval = false,
    this.pendingUpdate = false,
  });
  final String id, name;
  final int sizeBytes;
  final Object? importedAt;
  final List<GameModResource> resources;
  final List<String> warnings;
  final bool pendingRemoval, pendingUpdate;
  factory GameModPackage.fromMap(Map<String, dynamic> map) => GameModPackage(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    sizeBytes: _int(map['sizeBytes']),
    importedAt: map['importedAt'],
    resources: (map['resources'] as List? ?? [])
        .map((r) => GameModResource.fromMap(gameModsMap(r)))
        .toList(growable: false),
    warnings: _strings(map['warnings']),
    pendingRemoval: map['pendingRemoval'] == true,
    pendingUpdate: map['pendingUpdate'] == true,
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'sizeBytes': sizeBytes,
    'importedAt': importedAt,
    'resources': resources.map((r) => r.toMap()).toList(),
    'warnings': warnings,
    'pendingRemoval': pendingRemoval,
    'pendingUpdate': pendingUpdate,
  };
}

class GameModsConfig {
  const GameModsConfig({
    this.master = false,
    this.order = const [],
    this.enabledPackages = const {},
    this.enabledResources = const {},
  });
  final bool master;
  final List<String> order;
  final Set<String> enabledPackages, enabledResources;
  factory GameModsConfig.fromMap(Map<String, dynamic> map) => GameModsConfig(
    master: map['master'] == true,
    order: _strings(map['order']),
    enabledPackages: _strings(map['enabledPackages']).toSet(),
    enabledResources: _strings(map['enabledResources']).toSet(),
  );
  GameModsConfig copyWith({
    bool? master,
    List<String>? order,
    Set<String>? enabledPackages,
    Set<String>? enabledResources,
  }) => GameModsConfig(
    master: master ?? this.master,
    order: order ?? this.order,
    enabledPackages: enabledPackages ?? this.enabledPackages,
    enabledResources: enabledResources ?? this.enabledResources,
  );
  Map<String, dynamic> toMap() => {
    'master': master,
    'order': order,
    'enabledPackages': enabledPackages.toList(),
    'enabledResources': enabledResources.toList(),
  };
  bool sameAs(GameModsConfig other) =>
      master == other.master &&
      listEquals(order, other.order) &&
      setEquals(enabledPackages, other.enabledPackages) &&
      setEquals(enabledResources, other.enabledResources);
}

class GameModsPreflight {
  const GameModsPreflight({
    required this.token,
    required this.name,
    required this.resourceCount,
    required this.supportedCount,
    required this.unsupportedCount,
    this.warnings = const [],
    this.sourceFileCount,
    this.addedCount,
    this.removedCount,
  });
  final String token, name;
  final int resourceCount, supportedCount, unsupportedCount;
  final int? sourceFileCount, addedCount, removedCount;
  int get fileCount => sourceFileCount ?? resourceCount;
  final List<String> warnings;
  factory GameModsPreflight.fromMap(Map<String, dynamic> map) =>
      GameModsPreflight(
        token: map['token'] as String? ?? '',
        name: map['name'] as String? ?? '',
        resourceCount: _int(map['resourceCount']),
        supportedCount: _int(map['supportedCount']),
        unsupportedCount: _int(map['unsupportedCount']),
        warnings: _strings(map['warnings']),
        sourceFileCount: map['sourceFileCount'] is num
            ? _int(map['sourceFileCount'])
            : null,
        addedCount: (map['addedCount'] as num?)?.toInt(),
        removedCount: (map['removedCount'] as num?)?.toInt(),
      );
}

enum GameModsApplyResult { reloaded, noGame, blocked, unsupported, failed }

class GameModsStatus {
  const GameModsStatus({
    this.packages = const [],
    this.draft = const GameModsConfig(),
    this.applied = const GameModsConfig(),
    this.pending = false,
    this.sessionId = 0,
    this.winners = const {},
    this.activeWinners = const {},
    this.hits = const {},
    this.partialHits = const {},
    this.failures = const {},
    this.library = const GameModLibraryStatus(),
  });
  final List<GameModPackage> packages;
  final GameModsConfig draft, applied;
  final bool pending;
  final int sessionId;
  final Map<String, String> winners, activeWinners, failures;
  final Set<String> hits, partialHits;
  final GameModLibraryStatus library;

  /// A fully provided file is counted once even if earlier range reads remain.
  Set<String> get partialOnlyHits => partialHits.difference(hits);
  Iterable<GameModResource> get coordinateResources sync* {
    for (final package in packages) {
      yield* package.resources.where((resource) => resource.isCoordinates);
    }
  }

  bool coordinatesActive(GameModResource resource) =>
      resource.targets.any((target) => activeWinners[target] == resource.id);
  int get providedFileCount {
    final coordinateIds = coordinateResources.map((r) => r.id).toSet();
    return hits.where((id) => !coordinateIds.contains(id)).length;
  }

  int get writtenCoordinateCount => coordinateResources
      .where((r) => coordinatesActive(r) && hits.contains(r.id))
      .length;
  int get waitingCoordinateCount => coordinateResources
      .where(
        (r) =>
            coordinatesActive(r) &&
            !hits.contains(r.id) &&
            !failures.containsKey(r.id),
      )
      .length;
  factory GameModsStatus.fromMap(Map<String, dynamic> map) => GameModsStatus(
    packages: (map['packages'] as List? ?? [])
        .map((p) => GameModPackage.fromMap(gameModsMap(p)))
        .toList(growable: false),
    draft: GameModsConfig.fromMap(gameModsMap(map['draft'])),
    applied: GameModsConfig.fromMap(gameModsMap(map['applied'])),
    pending: map['pending'] == true,
    sessionId: _int(map['sessionId']),
    winners: gameModsMap(
      map['winners'],
    ).map((k, v) => MapEntry(k, v.toString())),
    activeWinners: gameModsMap(
      map['activeWinners'],
    ).map((k, v) => MapEntry(k, v.toString())),
    hits: _strings(map['hits']).toSet(),
    partialHits: _strings(map['partialHits']).toSet(),
    failures: gameModsMap(
      map['failures'],
    ).map((k, v) => MapEntry(k, v.toString())),
    library: GameModLibraryStatus.fromMap(gameModsMap(map['library'])),
  );
  List<GameModPackage> get orderedPackages {
    final byId = {for (final p in packages) p.id: p};
    return [
      for (final id in draft.order)
        if (byId.containsKey(id)) byId.remove(id)!,
      ...byId.values,
    ];
  }

  GameModPackage? packageForResource(String id) {
    for (final p in packages) {
      if (p.resources.any((r) => r.id == id)) return p;
    }
    return null;
  }

  Map<String, String> resolve(GameModsConfig config) {
    if (!config.master) return {};
    final result = <String, String>{};
    final byId = {for (final p in packages) p.id: p};
    for (final id in config.order) {
      final p = byId[id];
      if (p == null ||
          p.pendingRemoval ||
          !config.enabledPackages.contains(id)) {
        continue;
      }
      for (final r in p.resources) {
        if (r.supported && config.enabledResources.contains(r.id)) {
          for (final target in r.targets) {
            result.putIfAbsent(target, () => r.id);
          }
        }
      }
    }
    return result;
  }

  GameModsConfig _appliedForCurrentPackages(GameModsConfig config) {
    final available = packages.where((p) => !p.pendingRemoval).toList();
    final packageIds = available.map((p) => p.id).toSet();
    final resourceIds = available
        .expand((p) => p.resources)
        .map((r) => r.id)
        .toSet();
    // A newly imported, disabled package is retained after cancel. Its position
    // is appended to the old applied order without creating another edit.
    final order = [
      ...config.order.where(packageIds.contains),
      ...packageIds.where((id) => !config.order.contains(id)),
    ];
    return config.copyWith(
      order: order,
      enabledPackages: config.enabledPackages.intersection(packageIds),
      enabledResources: config.enabledResources.intersection(resourceIds),
    );
  }

  GameModsStatus withDraft(GameModsConfig config) => GameModsStatus(
    packages: packages,
    draft: config,
    applied: applied,
    pending:
        !config.sameAs(_appliedForCurrentPackages(applied)) ||
        packages.any((p) => p.pendingRemoval),
    sessionId: sessionId,
    winners: resolve(config),
    activeWinners: activeWinners,
    hits: hits,
    partialHits: partialHits,
    failures: failures,
    library: library,
  );
  GameModsStatus withRuntimeFrom(GameModsStatus remote) {
    if (remote.sessionId < sessionId) return this;
    return GameModsStatus(
      packages: packages,
      draft: draft,
      applied: remote.applied,
      pending:
          !draft.sameAs(_appliedForCurrentPackages(remote.applied)) ||
          packages.any((p) => p.pendingRemoval),
      sessionId: remote.sessionId,
      winners: resolve(draft),
      activeWinners: remote.activeWinners,
      hits: remote.hits,
      partialHits: remote.partialHits,
      failures: remote.failures,
      library: remote.library,
    );
  }

  Map<String, dynamic> toMap() => {
    'packages': packages.map((p) => p.toMap()).toList(),
    'draft': draft.toMap(),
    'applied': applied.toMap(),
    'pending': pending,
    'sessionId': sessionId,
    'winners': winners,
    'activeWinners': activeWinners,
    'hits': hits.toList(),
    'partialHits': partialHits.toList(),
    'failures': failures,
    'library': library.toMap(),
  };
}
