/// Round-1 structural and provenance checks over the generated dataset.
library;

import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'name_resolver.dart';

class ValidationIssue {
  final String code;
  final String detail;
  const ValidationIssue(this.code, this.detail);
}

class ValidationResult {
  final List<ValidationIssue> issues;
  const ValidationResult(this.issues);

  bool get passed => issues.isEmpty;
}

class DatasetValidator {
  final MasterData master;

  DatasetValidator(this.master);

  ValidationResult validate({
    required List<BonusRule> rules,
    required bool unresolvedEmpty,
  }) {
    final issues = <ValidationIssue>[];

    // ruleId uniqueness.
    final ids = <String>{};
    for (final r in rules) {
      if (!ids.add(r.ruleId)) {
        issues.add(ValidationIssue('ruleId', 'duplicate ruleId ${r.ruleId}'));
      }
      if (!RegExp(r'^akashi-\d+-(single|count|synergy|improvement)-\d{3}$')
          .hasMatch(r.ruleId)) {
        issues.add(ValidationIssue('ruleId', 'malformed ruleId ${r.ruleId}'));
      }
    }

    for (final r in rules) {
      // Equipment ids exist in master.
      for (final eid in r.equipment.ids) {
        if (!master.itemsById.containsKey(eid)) {
          issues.add(ValidationIssue(
              'equipment', '${r.ruleId} references unknown equipment $eid'));
        }
      }
      // Ship ids exist in master.
      final sc = r.shipCondition;
      for (final sid in sc.shipIds) {
        if (!master.shipsById.containsKey(sid)) {
          issues.add(
              ValidationIssue('ship', '${r.ruleId} references unknown ship $sid'));
        }
      }
      for (final cid in sc.classIds) {
        if (!master.shipsByCtype.containsKey(cid)) {
          issues.add(ValidationIssue(
              'class', '${r.ruleId} references unknown ctype $cid'));
        }
      }
      // Stats are integers and in kStatNames.
      void checkBonus(Map<String, int> bonus, String where) {
        for (final e in bonus.entries) {
          if (!kStatNames.contains(e.key)) {
            issues.add(ValidationIssue(
                'stat', '${r.ruleId} $where unknown stat ${e.key}'));
          }
        }
      }

      final eff = r.effect;
      if (eff is PerEquipmentEffect) {
        checkBonus(eff.bonus.stats, 'effect');
      } else if (eff is OnceEffect) {
        checkBonus(eff.bonus.stats, 'effect');
      } else if (eff is CountTableEffect) {
        // increments must accumulate to byCount.
        final byCount = <String, int>{};
        final keys = eff.increments.keys.toList()..sort();
        for (final k in keys) {
          for (final e in eff.increments[k]!.stats.entries) {
            byCount[e.key] = (byCount[e.key] ?? 0) + e.value;
          }
          final expected = eff.byCount[k];
          if (expected == null) {
            issues.add(ValidationIssue(
                'countTable', '${r.ruleId} byCount missing count $k'));
            continue;
          }
          for (final e in expected.stats.entries) {
            if ((byCount[e.key] ?? 0) != e.value) {
              issues.add(ValidationIssue('countTable',
                  '${r.ruleId} byCount[$k] ${e.key} = ${e.value}, expected ${byCount[e.key]}'));
            }
          }
        }
        if (keys.isEmpty || keys.first != 1) {
          issues.add(ValidationIssue(
              'countTable', '${r.ruleId} countTable must start at 1'));
        }
        for (var i = 1; i < keys.length; i++) {
          if (keys[i] != keys[i - 1] + 1) {
            issues.add(ValidationIssue(
                'countTable', '${r.ruleId} count keys not continuous'));
          }
        }
        if (!['unresolved', 'repeat', 'cap'].contains(eff.overflow)) {
          issues.add(ValidationIssue(
              'countTable', '${r.ruleId} bad overflow value ${eff.overflow}'));
        }
      } else if (eff is ImprovementTableEffect) {
        for (final e in eff.byStar.entries) {
          if (e.key < 0 || e.key > 10) {
            issues.add(ValidationIssue(
                'improvementTable', '${r.ruleId} star ${e.key} out of range'));
          }
          checkBonus(e.value.stats, 'byStar[${e.key}]');
        }
      }
      // Source provenance.
      final s = r.source;
      if (s.url.isEmpty ||
          s.fetchedAt.isEmpty ||
          s.contentSha256.isEmpty ||
          s.fragmentHash.isEmpty) {
        issues.add(ValidationIssue(
            'source', '${r.ruleId} missing source provenance'));
      }
      if (!s.url.startsWith('https://akashi-list.me/detail/w')) {
        issues.add(ValidationIssue(
            'source', '${r.ruleId} unexpected source url ${s.url}'));
      }
      // Category/effect mode consistency.
      if (r.category == RuleCategory.count && eff is! CountTableEffect) {
        issues.add(ValidationIssue(
            'category', '${r.ruleId} count category needs countTable effect'));
      }
      if (eff is CountTableEffect && r.category != RuleCategory.count) {
        issues.add(ValidationIssue(
            'category', '${r.ruleId} countTable effect needs count category'));
      }
      if (r.category == RuleCategory.synergy && r.requires.isEmpty) {
        issues.add(ValidationIssue(
            'synergy', '${r.ruleId} synergy rule without requires'));
      }
      if (r.category == RuleCategory.improvement &&
          r.equipmentCondition.minImprovement == 0 &&
          r.equipmentCondition.maxImprovement == 10) {
        // improvement with default range is only legal for improvementTable.
        if (eff is! ImprovementTableEffect) {
          issues.add(ValidationIssue(
              'improvement', '${r.ruleId} improvement without star condition'));
        }
      }
    }

    if (!unresolvedEmpty) {
      issues.add(ValidationIssue(
          'gate', 'unresolved entries exist; dataset must not publish'));
    }
    return ValidationResult(issues);
  }
}

/// Reads the formal dataset JSON back from disk for validation.
class DatasetReader {
  static (List<BonusRule>, String datasetVersion) read(String path) {
    final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final rules = <BonusRule>[];
    for (final r in (raw['rules'] as List).cast<Map<String, dynamic>>()) {
      rules.add(readRuleJson(r));
    }
    return (rules, (raw['datasetVersion'] as String?) ?? '');
  }

  static BonusRule readRuleJson(Map<String, dynamic> r) => _ruleFromJson(r);

  static BonusRule _ruleFromJson(Map<String, dynamic> r) {
    final equip = r['equipment'] as Map<String, dynamic>;
    final sc = r['shipCondition'] as Map<String, dynamic>;
    final ec = r['equipmentCondition'] as Map<String, dynamic>;
    final eff = r['effect'] as Map<String, dynamic>;
    final src = r['source'] as Map<String, dynamic>;

    Effect effect;
    switch (eff['mode'] as String) {
      case 'perEquipment':
        effect = PerEquipmentEffect(_bonus(eff['bonus'] as Map<String, dynamic>));
      case 'once':
        effect = OnceEffect(_bonus(eff['bonus'] as Map<String, dynamic>));
      case 'countTable':
        final inc = <int, Bonus>{};
        final byCount = <int, Bonus>{};
        (eff['increments'] as Map<String, dynamic>).forEach((k, v) {
          inc[int.parse(k)] = _bonus(v as Map<String, dynamic>);
        });
        (eff['byCount'] as Map<String, dynamic>).forEach((k, v) {
          byCount[int.parse(k)] = _bonus(v as Map<String, dynamic>);
        });
        effect = CountTableEffect(inc, byCount,
            overflow: (eff['overflow'] as String?) ?? 'unresolved');
      case 'improvementTable':
        final byStar = <int, Bonus>{};
        (eff['byStar'] as Map<String, dynamic>).forEach((k, v) {
          byStar[int.parse(k)] = _bonus(v as Map<String, dynamic>);
        });
        effect = ImprovementTableEffect(byStar);
      default:
        effect = UnresolvedEffect((eff['note'] as String?) ?? 'unknown');
    }

    return BonusRule(
      ruleId: r['ruleId'] as String,
      equipment: EquipmentRef(
        ids: (equip['ids'] as List).cast<int>(),
        typeIds: (equip['typeIds'] as List).cast<int>(),
      ),
      category: RuleCategory.tryParse(r['category'] as String)!,
      shipCondition: ShipCondition(
        shipIds: (sc['shipIds'] as List).cast<int>(),
        baseShipIds: (sc['baseShipIds'] as List).cast<int>(),
        classIds: (sc['classIds'] as List).cast<int>(),
        shipTypeIds: (sc['shipTypeIds'] as List).cast<int>(),
        nationalityIds: (sc['nationalityIds'] as List).cast<int>(),
      ),
      equipmentCondition: EquipmentCondition(
        minImprovement: (ec['minImprovement'] as num?)?.toInt() ?? 0,
        maxImprovement: (ec['maxImprovement'] as num?)?.toInt() ?? 10,
      ),
      requires: [
        for (final req in (r['requires'] as List).cast<Map<String, dynamic>>())
          RuleRequirement(
            kind: (req['kind'] as String?) ?? 'equipmentPredicate',
            minCount: (req['minCount'] as num?)?.toInt() ?? 1,
            predicate: _predicate(req['predicate'] as Map<String, dynamic>),
            sourceLabel: (req['sourceLabel'] as String?) ?? '',
          ),
      ],
      effect: effect,
      source: SourceInfo(
        url: src['url'] as String,
        pageName: src['pageName'] as String,
        fetchedAt: src['fetchedAt'] as String,
        httpLastModified: src['httpLastModified'] as String?,
        contentSha256: src['contentSha256'] as String,
        fragmentHash: src['fragmentHash'] as String,
        sourceGroupLabel: (src['sourceGroupLabel'] as String?) ?? '',
        rawEffect: (src['rawEffect'] as String?) ?? '',
        rawCondition: src['rawCondition'] as String?,
        annotation: src['annotation'] as String?,
      ),
      notes: (r['notes'] as List?)?.cast<String>() ?? const [],
    );
  }

  static Bonus _bonus(Map<String, dynamic> m) =>
      Bonus({for (final e in m.entries) e.key: (e.value as num).toInt()});

  static EquipmentPredicate _predicate(Map<String, dynamic> m) =>
      EquipmentPredicate(
        lineOfSightGte: (m['lineOfSightGte'] as num?)?.toInt(),
        antiAirGte: (m['antiAirGte'] as num?)?.toInt(),
        accuracyGte: (m['accuracyGte'] as num?)?.toInt(),
        improvementGte: (m['improvementGte'] as num?)?.toInt(),
        itemIds: (m['itemIds'] as List?)?.cast<int>() ?? const [],
        typeIds: (m['typeIds'] as List?)?.cast<int>() ?? const [],
      );
}
