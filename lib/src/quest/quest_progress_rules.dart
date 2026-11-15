import '../game_state/game_state.dart';

const _questFleetIdFields = {
  'flagshipId',
  'secondshipId',
  'escortshipId',
  'escortshipIdAll',
};

const _questFleetFields = {
  ..._questFleetIdFields,
  'flagship',
  'secondship',
  'escortship',
  'shipNamesAll',
  'flagshiptype',
  'escortshiptype',
  'flagshipclass',
  'secondshipclass',
  'escortshipclass',
  'fleetlimit',
  'banshiptype',
};

bool questStepUsesShipIds(Map<String, dynamic> step) =>
    step.keys.any(_questFleetIdFields.contains);

const _knownQuestStepFields = {
  ..._questFleetFields,
  'description',
  'required',
  'init',
  'shipType',
  'maparea',
  'mission',
  'times',
  'slotitemType2',
  'slotitemId',
  'mapcell',
  'materialShipType',
  'materialShipMinCount',
};

String questPeriodKey(int ruleType, int apiType, DateTime now) {
  final date = now.toUtc().add(const Duration(hours: 4));
  final day = DateTime.utc(date.year, date.month, date.day);
  final type = ruleType == 0
      ? switch (apiType) {
          1 => 1,
          2 => 2,
          3 => 3,
          _ => 0,
        }
      : ruleType;
  if (type == 1 || type == 8 || type == 9) return 'd:${day.toIso8601String()}';
  if (type == 2) {
    return 'w:${day.subtract(Duration(days: day.weekday - 1)).toIso8601String()}';
  }
  if (type == 3) return 'm:${date.year}-${date.month}';
  if (type == 4) return 'q:${(date.year * 12 + date.month) ~/ 3}';
  if (type >= 101 && type <= 112) {
    return 'y:${date.month >= type - 100 ? date.year : date.year - 1}';
  }
  return 'once';
}

class QuestProgressGoal {
  QuestProgressGoal(this.id, this.raw);
  final int id;
  final Map<String, dynamic> raw;
  int get type => (raw['type'] as num?)?.toInt() ?? 0;
  int get revision => (raw['revision'] as num?)?.toInt() ?? 0;
  Map<String, Map<String, dynamic>> get steps => {
    for (final e in raw.entries)
      if (e.value is Map) e.key: Map<String, dynamic>.from(e.value as Map),
  };
  List<Map<String, dynamic>>? get fleetSteps {
    final subgoals = steps.values;
    if (subgoals.any(
      (step) => !step.keys.every(_knownQuestStepFields.contains),
    )) {
      return null;
    }
    return subgoals
        .where((step) => step.keys.any(_questFleetFields.contains))
        .toList(growable: false);
  }

  // Incomplete fleet/equipment rules may provide reference counts, but those
  // counts cannot prove completion. Unknown constraints also fail closed when
  // restoring counts written by an older version of the rule engine.
  bool get completeOnCount =>
      raw['fuzzy'] != true &&
      steps.isNotEmpty &&
      steps.entries.every((step) {
        final event = step.key.split('@').first;
        return !{
              'destory_item',
              'destroy_ship',
              'remodel_ship',
            }.contains(event) &&
            step.value.keys.every(_knownQuestStepFields.contains);
      });
}

class QuestProgressEvent {
  const QuestProgressEvent(
    this.kind, {
    this.delta = 1,
    this.options = const {},
    this.ships = const [],
  });
  final String kind;
  final int delta;
  final Map<String, dynamic> options;
  final List<MasterShip> ships;
}

bool matchesQuestStep(Map<String, dynamic> goal, QuestProgressEvent event) {
  if (goal.keys.any((k) => !_knownQuestStepFields.contains(k))) return false;
  for (final key in [
    'shipType',
    'maparea',
    'mission',
    'times',
    'slotitemType2',
    'slotitemId',
    'mapcell',
  ]) {
    if (goal[key] case final List allowed) {
      if (!allowed.contains(event.options[key])) return false;
    }
  }
  if (goal['materialShipType'] case final List allowed) {
    final types = event.options['materialShipTypes'] as List? ?? const [];
    if (types.where(allowed.contains).length <
        (goal['materialShipMinCount'] as num? ?? 3)) {
      return false;
    }
  }
  final shipIds = event.options['shipIds'] is List
      ? event.options['shipIds'] as List
      : const [];
  return matchesQuestFleet(goal, event.ships, shipIds: shipIds) == true;
}

/// Null means the fleet data is insufficient to check this composition.
bool? matchesQuestFleet(
  Map<String, dynamic> goal,
  List<MasterShip> ships, {
  List shipIds = const [],
}) {
  var incomplete = false;
  bool canMatch(bool? match) {
    incomplete |= match == null;
    return match != false;
  }

  bool idMatches(int index, List allowed) {
    if (index >= shipIds.length || shipIds[index] is! List) return false;
    return (shipIds[index] as List).any(
      (id) => id is int && id > 0 && allowed.contains(id),
    );
  }

  for (final pair in [(0, 'flagshipId'), (1, 'secondshipId')]) {
    if (goal[pair.$2] case final List allowed) {
      if (!idMatches(pair.$1, allowed)) return false;
    }
  }
  bool idGroupMatches(dynamic raw) {
    final group = raw as List;
    final first = group.length > 2 && group[2] == true ? 1 : 0;
    var count = 0;
    for (var i = first; i < shipIds.length; i++) {
      if (idMatches(i, group[0] as List)) count++;
    }
    return count >= (group[1] as num);
  }

  if (goal['escortshipId'] case final List alternatives) {
    if (alternatives.isNotEmpty && !alternatives.any(idGroupMatches)) {
      return false;
    }
  }
  if (goal['escortshipIdAll'] case final List groups) {
    if (!groups.every(idGroupMatches)) return false;
  }
  if (ships.isEmpty &&
      goal.keys.any(
        (k) => {
          'flagship',
          'secondship',
          'escortship',
          'shipNamesAll',
          'flagshiptype',
          'flagshipclass',
          'secondshipclass',
          'escortshipclass',
          'escortshiptype',
          'banshiptype',
          'fleetlimit',
        }.contains(k),
      )) {
    return false;
  }
  bool? nameMatches(MasterShip ship, List names) => ship.name.trim().isEmpty
      ? null
      : names.any((name) => ship.name.contains(name.toString()));
  bool? numberMatches(int id, List allowed) =>
      id <= 0 ? null : allowed.contains(id);

  for (final pair in [(0, 'flagship'), (1, 'secondship')]) {
    if (goal[pair.$2] case final List names) {
      if (ships.length <= pair.$1 ||
          !canMatch(nameMatches(ships[pair.$1], names))) {
        return false;
      }
    }
  }
  for (final pair in [
    (0, 'flagshiptype'),
    (0, 'flagshipclass'),
    (1, 'secondshipclass'),
  ]) {
    if (goal[pair.$2] case final List allowed) {
      if (ships.length <= pair.$1) return false;
      if (!canMatch(
        numberMatches(
          pair.$2.endsWith('type')
              ? ships[pair.$1].shipTypeId
              : ships[pair.$1].classTypeId,
          allowed,
        ),
      )) {
        return false;
      }
    }
  }
  bool? groupMatches(dynamic raw, String kind) {
    final group = raw as List;
    final allowed = group[0] as List;
    final required = group[1] as num;
    final candidates = group.length > 2 && group[2] == true
        ? ships.skip(1)
        : ships;
    var matches = 0, unknown = 0;
    for (final ship in candidates) {
      final match = kind == 'name'
          ? nameMatches(ship, allowed)
          : numberMatches(
              kind == 'type' ? ship.shipTypeId : ship.classTypeId,
              allowed,
            );
      if (match == true) matches++;
      if (match == null) unknown++;
    }
    if (matches >= required) return true;
    return matches + unknown < required ? false : null;
  }

  if (goal['escortship'] case final List alternatives
      when alternatives.isNotEmpty) {
    final matches = alternatives
        .map((group) => groupMatches(group, 'name'))
        .toSet();
    if (!matches.contains(true)) {
      if (!matches.contains(null)) return false;
      incomplete = true;
    }
  }
  for (final pair in [
    ('shipNamesAll', 'name'),
    ('escortshiptype', 'type'),
    ('escortshipclass', 'class'),
  ]) {
    if (goal[pair.$1] case final List groups) {
      if (!groups.every((group) => canMatch(groupMatches(group, pair.$2)))) {
        return false;
      }
    }
  }
  if (goal['fleetlimit'] case final num limit) {
    if (ships.length > limit) return false;
  }
  if (goal['banshiptype'] case final List banned) {
    for (final ship in ships) {
      final bannedType = numberMatches(ship.shipTypeId, banned);
      if (bannedType == true) return false;
      incomplete |= bannedType == null;
    }
  }
  return incomplete ? null : true;
}
