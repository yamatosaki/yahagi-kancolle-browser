import 'dart:convert';

import 'package:flutter/services.dart';

import '../game_state/game_state.dart';

enum QuestUnlockState { unlocked, locked }

class QuestCatalogEntry {
  const QuestCatalogEntry({
    required this.gameId,
    required this.code,
    required this.name,
    required this.description,
    this.rewards = '',
    this.memo = '',
    this.prerequisites = const <String>[],
  });

  final int gameId;
  final String code;
  final String name;
  final String description;
  final String rewards;
  final String memo;
  final List<String> prerequisites;

  int get category {
    final match = RegExp(r'[A-G]').firstMatch(code);
    return switch (match?.group(0)) {
      'A' => 1,
      'B' => 2,
      'C' => 3,
      'D' => 4,
      'E' => 5,
      'F' => 6,
      'G' => 7,
      _ => 0,
    };
  }

  int get period {
    final prefix = code.replaceFirst(RegExp(r'\d+$'), '').toLowerCase();
    if (prefix.endsWith('d')) return 1;
    if (prefix.endsWith('w')) return 2;
    if (prefix.endsWith('m')) return 3;
    if (prefix.endsWith('q')) return 5;
    if (prefix.endsWith('y')) return 6;
    return 4;
  }

  factory QuestCatalogEntry.fromJson(int gameId, Map<String, Object?> json) {
    return QuestCatalogEntry(
      gameId: gameId,
      code: (json['code'] as String? ?? gameId.toString()).trim(),
      name: json['name'] as String? ?? '',
      description: json['desc'] as String? ?? '',
      rewards: json['rewards'] as String? ?? json['memo'] as String? ?? '',
      memo: json['memo2'] as String? ?? '',
      prerequisites: (json['pre'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class QuestCatalog {
  QuestCatalog(List<QuestCatalogEntry> entries)
    : entries = List<QuestCatalogEntry>.unmodifiable(entries) {
    final byGameId = <int, QuestCatalogEntry>{};
    final byCode = <String, QuestCatalogEntry>{};
    for (final entry in this.entries) {
      // Keep the original linear lookup behavior when malformed upstream data
      // contains a duplicate id or code: the first entry wins.
      byGameId.putIfAbsent(entry.gameId, () => entry);
      byCode.putIfAbsent(entry.code, () => entry);
    }

    final prerequisitesByGameId = <int, List<QuestCatalogEntry>>{};
    for (final entry in byGameId.values) {
      prerequisitesByGameId[entry.gameId] =
          List<QuestCatalogEntry>.unmodifiable(
            entry.prerequisites
                .map((code) => byCode[code])
                .whereType<QuestCatalogEntry>(),
          );
    }

    final successorsByCode = <String, List<QuestCatalogEntry>>{};
    for (final entry in this.entries) {
      for (final prerequisite in entry.prerequisites.toSet()) {
        (successorsByCode[prerequisite] ??= <QuestCatalogEntry>[]).add(entry);
      }
    }

    _byGameId = Map<int, QuestCatalogEntry>.unmodifiable(byGameId);
    _byCode = Map<String, QuestCatalogEntry>.unmodifiable(byCode);
    _prerequisitesByGameId = Map<int, List<QuestCatalogEntry>>.unmodifiable(
      prerequisitesByGameId,
    );
    _successorsByCode = Map<String, List<QuestCatalogEntry>>.unmodifiable({
      for (final relation in successorsByCode.entries)
        relation.key: List<QuestCatalogEntry>.unmodifiable(relation.value),
    });
  }

  final List<QuestCatalogEntry> entries;
  late final Map<int, QuestCatalogEntry> _byGameId;
  late final Map<String, QuestCatalogEntry> _byCode;
  late final Map<int, List<QuestCatalogEntry>> _prerequisitesByGameId;
  late final Map<String, List<QuestCatalogEntry>> _successorsByCode;

  static Future<QuestCatalog> loadAsset({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(
      'assets/data/quests-scn.json',
    );
    final decoded = jsonDecode(source) as Map<String, Object?>;
    final entries = <QuestCatalogEntry>[
      for (final item in decoded.entries)
        if (int.tryParse(item.key) case final gameId?)
          QuestCatalogEntry.fromJson(
            gameId,
            (item.value as Map<Object?, Object?>).map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
    ]..sort((a, b) => a.gameId.compareTo(b.gameId));
    return QuestCatalog(entries);
  }

  QuestCatalogEntry? byGameId(int gameId) => _byGameId[gameId];

  QuestCatalogEntry? byCode(String code) => _byCode[code];

  List<QuestCatalogEntry> prerequisitesOf(int gameId) =>
      _prerequisitesByGameId[gameId] ?? const <QuestCatalogEntry>[];

  List<QuestCatalogEntry> successorsOf(int gameId) {
    final code = _byGameId[gameId]?.code;
    if (code == null) return const <QuestCatalogEntry>[];
    return _successorsByCode[code] ?? const <QuestCatalogEntry>[];
  }

  QuestCatalogProjection project(Map<int, GameQuest> liveQuests) {
    final completed = <int>{};
    final locked = <int>{};

    void walkPrerequisites(int gameId) {
      for (final entry in prerequisitesOf(gameId)) {
        if (completed.add(entry.gameId)) walkPrerequisites(entry.gameId);
      }
    }

    void walkSuccessors(int gameId) {
      for (final entry in successorsOf(gameId)) {
        if (locked.add(entry.gameId)) walkSuccessors(entry.gameId);
      }
    }

    for (final gameId in liveQuests.keys) {
      walkPrerequisites(gameId);
      walkSuccessors(gameId);
    }
    locked.removeAll(completed);
    locked.removeAll(liveQuests.keys);

    return QuestCatalogProjection(<QuestCatalogItem>[
      for (final entry in entries)
        QuestCatalogItem(
          entry: entry,
          liveQuest: liveQuests[entry.gameId],
          unlockState: locked.contains(entry.gameId)
              ? QuestUnlockState.locked
              : QuestUnlockState.unlocked,
          inferredCompleted: completed.contains(entry.gameId),
        ),
    ]);
  }
}

class QuestCatalogItem {
  const QuestCatalogItem({
    required this.entry,
    required this.liveQuest,
    required this.unlockState,
    required this.inferredCompleted,
  });

  final QuestCatalogEntry entry;
  final GameQuest? liveQuest;
  final QuestUnlockState unlockState;
  final bool inferredCompleted;

  int get gameId => entry.gameId;
  String get progressLabel =>
      liveQuest?.progressPercentLabel ?? (inferredCompleted ? '100%' : '＜50%');
}

class QuestCatalogProjection {
  QuestCatalogProjection(List<QuestCatalogItem> items)
    : items = List<QuestCatalogItem>.unmodifiable(items) {
    final byGameId = <int, QuestCatalogItem>{};
    for (final item in this.items) {
      byGameId.putIfAbsent(item.gameId, () => item);
    }
    _byGameId = Map<int, QuestCatalogItem>.unmodifiable(byGameId);
  }

  final List<QuestCatalogItem> items;
  late final Map<int, QuestCatalogItem> _byGameId;

  QuestCatalogItem byGameId(int gameId) {
    final item = _byGameId[gameId];
    if (item == null) throw StateError('No element');
    return item;
  }
}
