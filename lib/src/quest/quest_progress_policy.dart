/// Local constraints that must survive every bundled or downloaded Poi update.
/// Revisions invalidate progress counted before the corresponding tightening.
Map<String, dynamic> applyQuestProgressPolicy(
  int id,
  Map<String, dynamic> source,
) {
  final raw = Map<String, dynamic>.from(source);
  const migratedIds = {
    249,
    337,
    339,
    345,
    346,
    354,
    355,
    356,
    357,
    362,
    368,
    371,
    373,
    375,
    377,
    875,
    888,
    903,
    904,
    912,
    928,
    975,
    977,
    1018,
    1045,
  };
  final minimumRevision = switch (id) {
    373 || 977 => 2,
    318 || 350 || 372 || 1005 || 1138 => 1,
    _ => migratedIds.contains(id) ? 1 : 0,
  };
  final revision = (raw['revision'] as int?) ?? 0;
  if (minimumRevision > revision) raw['revision'] = minimumRevision;
  if ({318, 977, 1005}.contains(id)) raw['fuzzy'] = true;

  const frenchIds = [492, 935, 965, 962, 491, 1051, 1053, 1055];
  for (final entry in raw.entries.toList()) {
    if (entry.value is! Map) continue;
    final step = Map<String, dynamic>.from(entry.value as Map);
    switch (id) {
      case 372:
        _requireCompanions(step, 'escortshiptype', [10], 2);
        _requireCompanions(step, 'escortshiptype', [2], 2);
      case 373:
        // Keep all incoming alternatives and add the local condition with AND.
        // Replacing the OR group could broaden a future, narrower ID set.
        _requireCompanions(step, 'escortshipIdAll', frenchIds, 2);
    }
    raw[entry.key] = step;
  }
  return raw;
}

void _requireCompanions(
  Map<String, dynamic> step,
  String key,
  List<int> allowed,
  int required,
) {
  final groups = [
    for (final group in step[key] as List? ?? const [])
      List<dynamic>.from(group as List),
  ];
  for (final group in groups) {
    final ids = group[0] as List;
    if (ids.length != allowed.length || !ids.toSet().containsAll(allowed)) {
      continue;
    }
    if ((group[1] as int) < required) group[1] = required;
    if (group.length == 2) {
      group.add(true);
    } else {
      group[2] = true;
    }
    step[key] = groups;
    return;
  }
  groups.add([allowed, required, true]);
  step[key] = groups;
}
