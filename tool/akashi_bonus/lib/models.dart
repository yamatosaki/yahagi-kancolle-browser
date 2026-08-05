/// Normalized rule models for the akashi-list.me equipment bonus dataset.
///
/// All public fields mirror the canonical JSON emitted by the dataset builder
/// (see assets/data/schema/equipment_fit_bonuses.schema.json). No game logic
/// lives in these models; they are pure data carriers.
library;

const List<String> kStatNames = <String>[
  'firepower',
  'torpedo',
  'antiAir',
  'evasion',
  'accuracy',
  'armor',
  'antiSubmarine',
  'lineOfSight',
  'bombing',
  'range',
];

/// Normalized per-stat integer bonus map. Missing stats are absent; writers
/// must emit 0 for absent stats in the formal JSON.
class Bonus {
  final Map<String, int> stats;

  const Bonus(this.stats);

  factory Bonus.empty() => const Bonus(<String, int>{});

  Bonus operator +(Bonus other) {
    final merged = <String, int>{...stats};
    for (final entry in other.stats.entries) {
      merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
    }
    return Bonus(merged);
  }

  bool get isEmpty => stats.values.every((v) => v == 0);

  Map<String, int> toJson() {
    final out = <String, int>{};
    for (final name in kStatNames) {
      out[name] = stats[name] ?? 0;
    }
    return out;
  }

  /// Compact form: only non-zero stats (used by countTable/increment maps
  /// and byStar tables where the plan's format omits zero stats).
  Map<String, int> toCompactJson() =>
      {for (final e in stats.entries) if (e.value != 0) e.key: e.value};
}

/// Ship condition of a rule, expressed exclusively in master data IDs.
class ShipCondition {
  final List<int> shipIds;
  final List<int> baseShipIds;
  final List<int> classIds;
  final List<int> shipTypeIds;
  final List<int> nationalityIds;

  const ShipCondition({
    this.shipIds = const [],
    this.baseShipIds = const [],
    this.classIds = const [],
    this.shipTypeIds = const [],
    this.nationalityIds = const [],
  });

  static const ShipCondition all = ShipCondition();

  bool get isEmpty =>
      shipIds.isEmpty &&
      baseShipIds.isEmpty &&
      classIds.isEmpty &&
      shipTypeIds.isEmpty &&
      nationalityIds.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'shipIds': shipIds,
        'baseShipIds': baseShipIds,
        'classIds': classIds,
        'shipTypeIds': shipTypeIds,
        'nationalityIds': nationalityIds,
      };
}

/// Equipment referenced by a rule: explicit master ids and/or equipment type
/// ids. At least one of [ids]/[typeIds] must be non-empty once resolved;
/// an unresolvable label keeps only [sourceLabel] and is reported as
/// unresolved instead of being guessed.
class EquipmentRef {
  final List<int> ids;
  final List<int> typeIds;
  final String sourceLabel;

  const EquipmentRef({
    this.ids = const [],
    this.typeIds = const [],
    this.sourceLabel = '',
  });

  bool get isEmpty => ids.isEmpty && typeIds.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'ids': ids,
        'typeIds': typeIds,
      };
}

/// Improvement range of the *rule's own* equipment.
class EquipmentCondition {
  final int minImprovement;
  final int maxImprovement;

  const EquipmentCondition({this.minImprovement = 0, this.maxImprovement = 10});

  Map<String, Object?> toJson() => <String, Object?>{
        'minImprovement': minImprovement,
        'maxImprovement': maxImprovement,
      };
}

/// A predicate over another equipment (synergy partner).
class EquipmentPredicate {
  final int? lineOfSightGte;
  final int? antiAirGte;
  final int? accuracyGte;
  final int? improvementGte;
  final List<int> itemIds;
  final List<int> typeIds;

  const EquipmentPredicate({
    this.lineOfSightGte,
    this.antiAirGte,
    this.accuracyGte,
    this.improvementGte,
    this.itemIds = const [],
    this.typeIds = const [],
  });

  Map<String, Object?> toJson() => <String, Object?>{
        if (lineOfSightGte != null) 'lineOfSightGte': lineOfSightGte,
        if (antiAirGte != null) 'antiAirGte': antiAirGte,
        if (accuracyGte != null) 'accuracyGte': accuracyGte,
        if (improvementGte != null) 'improvementGte': improvementGte,
        if (itemIds.isNotEmpty) 'itemIds': itemIds,
        if (typeIds.isNotEmpty) 'typeIds': typeIds,
      };

  bool get isEmpty =>
      lineOfSightGte == null &&
      antiAirGte == null &&
      accuracyGte == null &&
      improvementGte == null &&
      itemIds.isEmpty &&
      typeIds.isEmpty;
}

/// One requirement of a synergy rule: at least [minCount] pieces of equipment
/// matching [predicate] must be equipped.
class RuleRequirement {
  final String kind;
  final int minCount;
  final EquipmentPredicate predicate;
  final String sourceLabel;

  const RuleRequirement({
    this.kind = 'equipmentPredicate',
    this.minCount = 1,
    required this.predicate,
    this.sourceLabel = '',
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'minCount': minCount,
        'predicate': predicate.toJson(),
        'sourceLabel': sourceLabel,
      };
}

/// The effect of a rule.
sealed class Effect {
  const Effect();
  Map<String, Object?> toJson();
}

/// perEquipment: every equipped copy of the equipment adds the bonus.
class PerEquipmentEffect extends Effect {
  final Bonus bonus;
  const PerEquipmentEffect(this.bonus);
  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'mode': 'perEquipment',
        'bonus': bonus.toJson(),
      };
}

/// once: the bonus applies once regardless of how many copies are equipped.
class OnceEffect extends Effect {
  final Bonus bonus;
  const OnceEffect(this.bonus);
  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'mode': 'once',
        'bonus': bonus.toJson(),
      };
}

/// countTable: the bonus depends on the equipped count (x1/x2/x3 rows).
/// [increments] is the per-copy increment as written by the source;
/// [byCount] is the cumulative total at each count.
class CountTableEffect extends Effect {
  final Map<int, Bonus> increments;
  final Map<int, Bonus> byCount;
  final String overflow;
  const CountTableEffect(this.increments, this.byCount, {this.overflow = 'unresolved'});
  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'mode': 'countTable',
        'increments': increments.map((k, v) => MapEntry('$k', v.toCompactJson())),
        'byCount': byCount.map((k, v) => MapEntry('$k', v.toCompactJson())),
        'overflow': overflow,
      };
}

/// improvementTable: the bonus at each improvement star level (★1..★10).
/// Values are the totals as stated by the source at that star level.
class ImprovementTableEffect extends Effect {
  final Map<int, Bonus> byStar;
  const ImprovementTableEffect(this.byStar);
  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'mode': 'improvementTable',
        'byStar': byStar.map((k, v) => MapEntry('$k', v.toCompactJson())),
      };
}

/// Effect that could not be interpreted; kept with the source text so the
/// dataset never silently drops it.
class UnresolvedEffect extends Effect {
  final String note;
  final Map<String, Object?>? raw;
  const UnresolvedEffect(this.note, {this.raw});
  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'mode': 'unresolved',
        'note': note,
      };
}

enum RuleCategory {
  single,
  count,
  synergy,
  improvement;

  static RuleCategory? tryParse(String s) {
    switch (s) {
      case 'single':
        return RuleCategory.single;
      case 'count':
        return RuleCategory.count;
      case 'synergy':
        return RuleCategory.synergy;
      case 'improvement':
        return RuleCategory.improvement;
    }
    return null;
  }
}

/// Provenance of one rule row.
class SourceInfo {
  final String url;
  final String pageName;
  final String fetchedAt;
  final String? httpLastModified;
  final String contentSha256;
  final String fragmentHash;
  final String sourceGroupLabel;
  final String rawEffect;
  final String? rawCondition;
  final String? annotation;

  const SourceInfo({
    required this.url,
    required this.pageName,
    required this.fetchedAt,
    required this.contentSha256,
    required this.fragmentHash,
    required this.sourceGroupLabel,
    required this.rawEffect,
    this.httpLastModified,
    this.rawCondition,
    this.annotation,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'url': url,
        'pageName': pageName,
        'fetchedAt': fetchedAt,
        'httpLastModified': httpLastModified,
        'contentSha256': contentSha256,
        'fragmentHash': fragmentHash,
        'sourceGroupLabel': sourceGroupLabel,
        'rawEffect': rawEffect,
        if (rawCondition != null) 'rawCondition': rawCondition,
        if (annotation != null) 'annotation': annotation,
      };
}

/// One normalized rule.
class BonusRule {
  final String ruleId;
  final EquipmentRef equipment;
  final RuleCategory category;
  final ShipCondition shipCondition;
  final EquipmentCondition equipmentCondition;
  final List<RuleRequirement> requires;
  final Effect effect;
  final SourceInfo source;
  final List<String> notes;

  const BonusRule({
    required this.ruleId,
    required this.equipment,
    required this.category,
    this.shipCondition = const ShipCondition(),
    this.equipmentCondition = const EquipmentCondition(),
    this.requires = const [],
    required this.effect,
    required this.source,
    this.notes = const [],
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'ruleId': ruleId,
        'equipment': equipment.toJson(),
        'category': category.name,
        'shipCondition': shipCondition.toJson(),
        'equipmentCondition': equipmentCondition.toJson(),
        'requires': requires.map((r) => r.toJson()).toList(),
        'effect': effect.toJson(),
        if (notes.isNotEmpty) 'notes': notes,
        'source': source.toJson(),
      };
}
