import 'dart:convert';

import 'package:flutter/services.dart';

import '../game_state/game_state.dart';
import '../game_state/quest_text_normalizer.dart';
import 'quest_catalog_relation_aliases.dart';
import 'quest_reward_corrections.dart';
import 'quest_translation_fallbacks.dart';

enum QuestUnlockState { unlocked, locked, completed, unknown }

enum QuestStatus {
  available,
  inProgress,
  claimable,
  completed,
  locked,
  unknown,
}

class QuestCatalogEntry {
  const QuestCatalogEntry({
    required this.gameId,
    required this.code,
    required this.name,
    required this.description,
    this.translatedName,
    this.translatedDescription,
    this.materials = const <int>[0, 0, 0, 0],
    this.rewards = '',
    this.memo = '',
    this.prerequisites = const <String>[],
  });

  final int gameId;
  final String code;
  final String name;
  final String description;
  final String? translatedName;
  final String? translatedDescription;
  final List<int> materials;
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
    final fallback = questTranslationFallbacks[gameId];
    final rewardJson = correctQuestRewardData(gameId, json);
    return QuestCatalogEntry(
      gameId: gameId,
      code: (json['code'] as String? ?? gameId.toString()).trim(),
      name: json['name'] as String? ?? '',
      description: normalizeQuestDetail(json['desc'] as String? ?? ''),
      translatedName: _nonEmptyString(json['nameZh']) ?? fallback?.name,
      translatedDescription:
          _normalizedNonEmptyString(json['descZh']) ?? fallback?.description,
      materials: _questMaterials(rewardJson['resources']),
      rewards:
          rewardJson['rewards'] as String? ?? json['memo'] as String? ?? '',
      memo: json['memo2'] as String? ?? '',
      prerequisites: (json['pre'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

List<int> _questMaterials(Object? resources) {
  if (resources == null) return const <int>[0, 0, 0, 0];
  if (resources is! List ||
      resources.isEmpty ||
      resources.first is! List ||
      (resources.first as List).length != 4) {
    throw const FormatException('Quest fixed resource rewards are invalid');
  }
  // The second row describes consumables already included in rewards text.
  return List<int>.unmodifiable(
    (resources.first as List).map((value) {
      // Keep legacy blank-cell compatibility after verified corrections above.
      if (value is String && value.trim().isEmpty) return 0;
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          value != value.toInt()) {
        throw const FormatException('Quest fixed resource amount is invalid');
      }
      return value.toInt();
    }),
  );
}

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _normalizedNonEmptyString(Object? value) {
  final text = _nonEmptyString(value);
  return text == null ? null : normalizeQuestDetail(text);
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
    for (final alias in questCatalogRelationAliases.entries) {
      final entry = byGameId[alias.value.gameId];
      if (entry != null && entry.code == alias.value.code) {
        byCode.putIfAbsent(alias.key, () => entry);
      }
    }

    final prerequisitesByGameId = <int, List<QuestCatalogEntry>>{};
    final unresolvedByGameId = <int, List<String>>{};
    for (final entry in byGameId.values) {
      prerequisitesByGameId[entry.gameId] =
          List<QuestCatalogEntry>.unmodifiable(
            entry.prerequisites
                .map((code) => byCode[code])
                .whereType<QuestCatalogEntry>(),
          );
      unresolvedByGameId[entry.gameId] = List<String>.unmodifiable(
        entry.prerequisites.where((code) => !byCode.containsKey(code)),
      );
    }

    final successorsByCode = <String, List<QuestCatalogEntry>>{};
    for (final entry in this.entries) {
      for (final prerequisite in entry.prerequisites.toSet()) {
        final parentCode = byCode[prerequisite]?.code;
        if (parentCode != null) {
          final successors = successorsByCode[parentCode] ??=
              <QuestCatalogEntry>[];
          if (!successors.contains(entry)) successors.add(entry);
        }
      }
    }

    _byGameId = Map<int, QuestCatalogEntry>.unmodifiable(byGameId);
    _byCode = Map<String, QuestCatalogEntry>.unmodifiable(byCode);
    _prerequisitesByGameId = Map<int, List<QuestCatalogEntry>>.unmodifiable(
      prerequisitesByGameId,
    );
    _unresolvedByGameId = Map<int, List<String>>.unmodifiable(
      unresolvedByGameId,
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
  late final Map<int, List<String>> _unresolvedByGameId;
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

  QuestCatalog withTranslationFallbackFrom(QuestCatalog fallback) =>
      QuestCatalog(<QuestCatalogEntry>[
        for (final entry in entries)
          if (fallback.byGameId(entry.gameId) case final local?)
            QuestCatalogEntry(
              gameId: entry.gameId,
              code: entry.code,
              name: entry.name,
              description: entry.description,
              translatedName: entry.translatedName ?? local.translatedName,
              translatedDescription:
                  entry.translatedDescription ?? local.translatedDescription,
              materials: entry.materials,
              rewards: entry.rewards,
              memo: entry.memo.trim().isEmpty ? local.memo : entry.memo,
              prerequisites: entry.prerequisites,
            )
          else
            entry,
      ]);

  List<QuestCatalogEntry> prerequisitesOf(int gameId) =>
      _prerequisitesByGameId[gameId] ?? const <QuestCatalogEntry>[];

  /// Original references whose parent cannot be identified from these sources.
  List<String> unresolvedPrerequisitesOf(int gameId) =>
      _unresolvedByGameId[gameId] ?? const <String>[];

  List<QuestCatalogEntry> successorsOf(int gameId) {
    final code = _byGameId[gameId]?.code;
    if (code == null) return const <QuestCatalogEntry>[];
    return _successorsByCode[code] ?? const <QuestCatalogEntry>[];
  }

  QuestCatalogProjection project(
    Map<int, GameQuest> liveQuests, {
    bool isComplete = true,
    Set<int> confirmedCompleted = const {},
  }) {
    final completed = <int>{...confirmedCompleted};
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

    // Match Quest Info 2's getCompletedQuest: an absent terminal branch
    // with a completed ancestor and no currently available ancestor is
    // inferred complete, including its prerequisites.
    // https://github.com/lawvs/poi-plugin-quest-2/blob/main/src/questHelper.ts
    final gameIds = _byGameId.keys.toList()..sort();
    for (final gameId in gameIds) {
      if (!isComplete ||
          successorsOf(gameId).isNotEmpty ||
          liveQuests.containsKey(gameId) ||
          completed.contains(gameId)) {
        continue;
      }
      final ancestors = <int>{};
      final pending = <int>[gameId];
      var hasUnresolvedAncestor = false;
      while (pending.isNotEmpty) {
        final current = pending.removeLast();
        if (unresolvedPrerequisitesOf(current).isNotEmpty) {
          hasUnresolvedAncestor = true;
        }
        for (final entry in prerequisitesOf(current)) {
          if (ancestors.add(entry.gameId)) pending.add(entry.gameId);
        }
      }
      if (hasUnresolvedAncestor ||
          ancestors.any(liveQuests.containsKey) ||
          !ancestors.any(completed.contains)) {
        continue;
      }
      completed.addAll(ancestors);
      completed.add(gameId);
    }
    locked.removeAll(completed);
    locked.removeAll(liveQuests.keys);

    return QuestCatalogProjection(<QuestCatalogItem>[
      for (final entry in entries)
        QuestCatalogItem(
          entry: entry,
          liveQuest: liveQuests[entry.gameId],
          unlockState: liveQuests.containsKey(entry.gameId)
              ? QuestUnlockState.unlocked
              : completed.contains(entry.gameId)
              ? QuestUnlockState.completed
              : locked.contains(entry.gameId)
              ? QuestUnlockState.locked
              : QuestUnlockState.unknown,
          inferredCompleted:
              completed.contains(entry.gameId) &&
              !liveQuests.containsKey(entry.gameId),
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

  QuestStatus get status {
    if (liveQuest case final live?) {
      return switch (live.state) {
        1 => QuestStatus.available,
        2 => QuestStatus.inProgress,
        3 => QuestStatus.claimable,
        _ => QuestStatus.unknown,
      };
    }
    if (inferredCompleted) return QuestStatus.completed;
    return unlockState == QuestUnlockState.locked
        ? QuestStatus.locked
        : QuestStatus.unknown;
  }

  /// Matches any keyword against original fields and optional display labels.
  /// Keep source case for dictionary lookups before normalizing the result.
  bool matchesSearch(
    List<String> keywords, {
    String Function(String)? displayText,
  }) {
    if (keywords.isEmpty) return true;
    final source = [
      gameId,
      entry.code,
      entry.name,
      entry.description,
      entry.translatedName ?? '',
      entry.translatedDescription ?? '',
      entry.rewards,
      entry.memo,
      liveQuest?.title ?? '',
      liveQuest?.detail ?? '',
    ].join(' ');
    if (keywords.any(source.toLowerCase().contains)) return true;
    final translated = displayText?.call(source).toLowerCase();
    return translated != null && keywords.any(translated.contains);
  }

  /// Poi's ordinary filters group unknown tasks with locked tasks, and
  /// server-confirmed tasks awaiting rewards with inferred completed tasks.
  bool matchesUnlockFilter(QuestUnlockState? filter) => switch (filter) {
    null => true,
    QuestUnlockState.locked =>
      unlockState == QuestUnlockState.locked ||
          unlockState == QuestUnlockState.unknown,
    QuestUnlockState.completed =>
      liveQuest?.isServerCompleted ?? inferredCompleted,
    _ => unlockState == filter,
  };

  int get gameId => entry.gameId;
  String get progressLabel =>
      liveQuest?.displayProgressLabel ?? (inferredCompleted ? '100%' : '—');
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
