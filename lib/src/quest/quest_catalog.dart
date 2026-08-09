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
  const QuestCatalog(this.entries);

  final List<QuestCatalogEntry> entries;

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

  QuestCatalogEntry? byGameId(int gameId) {
    for (final entry in entries) {
      if (entry.gameId == gameId) return entry;
    }
    return null;
  }

  QuestCatalogEntry? byCode(String code) {
    for (final entry in entries) {
      if (entry.code == code) return entry;
    }
    return null;
  }

  List<QuestCatalogEntry> prerequisitesOf(int gameId) {
    final entry = byGameId(gameId);
    if (entry == null) return const <QuestCatalogEntry>[];
    return entry.prerequisites
        .map(byCode)
        .whereType<QuestCatalogEntry>()
        .toList(growable: false);
  }

  List<QuestCatalogEntry> successorsOf(int gameId) => entries
      .where((entry) => entry.prerequisites.contains(byGameId(gameId)?.code))
      .toList(growable: false);

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
  const QuestCatalogProjection(this.items);

  final List<QuestCatalogItem> items;

  QuestCatalogItem byGameId(int gameId) =>
      items.firstWhere((item) => item.gameId == gameId);
}
