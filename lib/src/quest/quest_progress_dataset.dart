import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';

import 'quest_progress_policy.dart';
import 'quest_progress_rules.dart';

/// A validated Poi FCD payload and the effective rules after local policy.
class QuestProgressDataset {
  QuestProgressDataset._({
    required this.version,
    required this.rawJson,
    required this.sourceCommit,
    required Map<int, QuestProgressGoal> goals,
  }) : sha256 = _digest(rawJson),
       goals = Map.unmodifiable(goals);

  final String version;
  final String rawJson;
  final String sourceCommit;
  final String sha256;
  final Map<int, QuestProgressGoal> goals;

  static QuestProgressDataset parsePayload(
    String rawJson, {
    String sourceCommit = '',
  }) {
    final payload = _object(jsonDecode(rawJson), 'payload');
    _only(payload, {'meta', 'data'}, 'payload');
    final meta = _object(payload['meta'], 'meta');
    _only(meta, {'name', 'version'}, 'meta');
    if (meta['name'] != 'questgoal') {
      throw const FormatException('Expected the Poi questgoal dataset');
    }
    final version = _version(meta['version']);
    final data = _object(payload['data'], 'data');
    if (data.isEmpty) throw const FormatException('Empty questgoal dataset');
    final goals = <int, QuestProgressGoal>{};
    for (final entry in data.entries) {
      if (!RegExp(r'^[1-9][0-9]*$').hasMatch(entry.key)) {
        throw FormatException('Invalid quest ID ${entry.key}');
      }
      final id = int.tryParse(entry.key);
      if (id == null || !_positive(id)) {
        throw FormatException('Invalid quest ID ${entry.key}');
      }
      final goal = _object(entry.value, 'quest $id');
      _validateGoal(goal, id);
      goals[id] = _goal(id, goal);
    }
    return QuestProgressDataset._(
      version: version,
      rawJson: rawJson,
      sourceCommit: sourceCommit,
      goals: goals,
    );
  }

  static QuestProgressDataset fromBundledData({
    required String rawJson,
    required String metadataJson,
  }) {
    final meta = _object(jsonDecode(metadataJson), 'bundle metadata');
    final version = _version(meta['version']);
    final commit = meta['sourceCommit'];
    if (commit is! String || !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      throw const FormatException('Invalid bundled source commit');
    }
    if (meta['sha256'] != _digest(rawJson)) {
      throw const FormatException('Bundled questgoal digest mismatch');
    }
    final data = _object(jsonDecode(rawJson), 'bundled goals');
    return parsePayload(
      jsonEncode({
        'meta': {'name': 'questgoal', 'version': version},
        'data': data,
      }),
      sourceCommit: commit,
    );
  }

  static Future<QuestProgressDataset> loadBundled() async => fromBundledData(
    rawJson: await rootBundle.loadString(
      'assets/data/quest-progress-goals.json',
    ),
    metadataJson: await rootBundle.loadString(
      'assets/data/quest-progress-meta.json',
    ),
  );

  /// Poi may omit rules from an update. Preserve those already available.
  /// Equal and older versions cannot replace an installed dataset.
  QuestProgressDataset overlayOn(QuestProgressDataset fallback) {
    if (version.compareTo(fallback.version) <= 0) return fallback;
    final merged = <int, QuestProgressGoal>{...fallback.goals};
    for (final entry in goals.entries) {
      final previousRevision = fallback.goals[entry.key]?.revision ?? 0;
      final raw = Map<String, dynamic>.from(entry.value.raw);
      if (previousRevision > entry.value.revision) {
        raw['revision'] = previousRevision;
      }
      merged[entry.key] = _goal(entry.key, raw);
    }
    return QuestProgressDataset._(
      version: version,
      rawJson: rawJson,
      sourceCommit: sourceCommit,
      goals: merged,
    );
  }
}

QuestProgressGoal _goal(int id, Map<String, dynamic> raw) => QuestProgressGoal(
  id,
  _freeze(applyQuestProgressPolicy(id, raw)) as Map<String, dynamic>,
);

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freeze(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

String _digest(String raw) =>
    crypto.sha256.convert(utf8.encode(raw)).toString();

Map<String, dynamic> _object(dynamic value, String location) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Expected an object at $location');
  }
  return Map<String, dynamic>.from(value);
}

void _only(Map<String, dynamic> value, Set<String> allowed, String location) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw FormatException('Unknown field at $location');
  }
}

String _version(dynamic value) {
  if (value is! String ||
      !RegExp(r'^[0-9]{4}/[0-9]{2}/[0-9]{2}/[0-9]{2}$').hasMatch(value)) {
    throw const FormatException('Invalid Poi FCD version');
  }
  final parts = value.split('/').map(int.parse).toList();
  final day = DateTime.utc(parts[0], parts[1], parts[2]);
  if (parts[0] < 2000 ||
      day.year != parts[0] ||
      day.month != parts[1] ||
      day.day != parts[2]) {
    throw const FormatException('Invalid Poi FCD version date');
  }
  return value;
}

bool _positive(dynamic value) =>
    value is int && value > 0 && value <= 0x7fffffff;
bool _nonnegative(dynamic value) =>
    value is int && value >= 0 && value <= 0x7fffffff;
bool _period(dynamic value) =>
    value is int &&
    ({0, 1, 2, 3, 4, 8, 9}.contains(value) || value >= 101 && value <= 112);

const _events = {
  'battle',
  'battle_boss',
  'battle_boss_win',
  'battle_boss_win_rank_a',
  'battle_boss_win_rank_s',
  'battle_rank_s',
  'battle_win',
  'create_item',
  'create_ship',
  'destory_item',
  'destroy_ship',
  'mission_success',
  'practice',
  'practice_win',
  'practice_win_a',
  'practice_win_s',
  'reach_mapcell',
  'remodel_item',
  'remodel_ship',
  'repair',
  'sally',
  'sinking',
  'supply',
};
const _integerArrays = {
  'shipType',
  'maparea',
  'times',
  'slotitemType2',
  'slotitemId',
  'mapcell',
  'materialShipType',
  'flagshipId',
  'secondshipId',
  'flagshiptype',
  'flagshipclass',
  'secondshipclass',
  'banshiptype',
};
const _groups = {
  'escortshipId',
  'escortshipIdAll',
  'escortshiptype',
  'escortshipclass',
};

void _validateGoal(Map<String, dynamic> goal, int id) {
  var steps = 0;
  for (final entry in goal.entries) {
    final value = entry.value;
    switch (entry.key) {
      case 'type':
      case 'resetInterval':
        if (!_period(value)) throw FormatException('Invalid period for $id');
      case 'revision':
        if (!_nonnegative(value)) {
          throw FormatException('Invalid revision for $id');
        }
      case 'fuzzy':
        if (value is! bool) throw FormatException('Invalid fuzzy flag for $id');
      default:
        final key = entry.key.split('@');
        if (!_events.contains(key.first) ||
            key.length > 2 ||
            key.length == 2 &&
                (key.last.isEmpty ||
                    key.last.contains(RegExp(r'[\x00-\x1f]')))) {
          throw FormatException('Unknown quest event ${entry.key}');
        }
        final step = _object(value, 'quest $id / ${entry.key}');
        _validateStep(step, id);
        steps++;
    }
  }
  if (steps == 0) throw FormatException('Quest $id has no subgoals');
}

bool _ids(dynamic value) =>
    value is List &&
    value.isNotEmpty &&
    value.every(_positive) &&
    value.toSet().length == value.length;

void _validateStep(Map<String, dynamic> step, int id) {
  if (step['description'] is! String ||
      (step['description'] as String).trim().isEmpty ||
      !_positive(step['required'])) {
    throw FormatException('Invalid description or required count for $id');
  }
  for (final entry in step.entries) {
    final value = entry.value;
    switch (entry.key) {
      case 'description':
      case 'required':
        break;
      case 'init':
        if (!_nonnegative(value) ||
            (value as int) > (step['required'] as int)) {
          throw FormatException('Invalid initial count for $id');
        }
      case 'materialShipMinCount':
      case 'fleetlimit':
        if (!_positive(value) || (value as int) > 6) {
          throw FormatException('Invalid fleet count for $id');
        }
      case 'mission':
        if (value is! List ||
            value.isEmpty ||
            value.any((name) => name is! String || name.trim().isEmpty) ||
            value.toSet().length != value.length) {
          throw FormatException('Invalid expedition names for $id');
        }
      default:
        if (_integerArrays.contains(entry.key)) {
          if (!_ids(value)) throw FormatException('Invalid ID list for $id');
        } else if (_groups.contains(entry.key)) {
          if (value is! List || value.isEmpty) {
            throw FormatException('Invalid fleet groups for $id');
          }
          for (final group in value) {
            if (group is! List ||
                group.length < 2 ||
                group.length > 3 ||
                !_ids(group[0]) ||
                !_positive(group[1]) ||
                (group[1] as int) > 6 ||
                group.length == 3 && group[2] is! bool) {
              throw FormatException('Invalid fleet group for $id');
            }
          }
        } else {
          throw FormatException('Unknown quest constraint ${entry.key}');
        }
    }
  }
}
