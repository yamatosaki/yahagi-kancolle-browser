/// Applies reviewed overrides from `overrides/bonuses.json` onto generated
/// rules. Overrides are the only sanctioned way to supplement or correct the
/// normalized dataset (see plan §13).
library;

import 'dart:convert';
import 'dart:io';

import 'dataset_validator.dart' show DatasetReader;
import 'models.dart';

class OverrideEntry {
  final String overrideId;
  final String reason;
  final String primarySourceUrl;
  final String verificationSourceUrl;
  final String reviewedBy;
  final String reviewedAt;
  final String kind; // addRule | removeRuleId | extendRuleId
  final BonusRule? rule;
  final String? ruleId;
  final List<int> addShipIds;
  final List<int> removeShipIds;

  /// Equipment ids whose unresolved entries this override addresses; they
  /// are excluded from the publish gate once reviewed.
  final List<int> resolvesEquipmentIds;

  const OverrideEntry({
    required this.overrideId,
    required this.reason,
    required this.primarySourceUrl,
    required this.verificationSourceUrl,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.kind,
    this.rule,
    this.ruleId,
    this.addShipIds = const [],
    this.removeShipIds = const [],
    this.resolvesEquipmentIds = const [],
  });
}

class OverrideApplyResult {
  final List<BonusRule> rules;
  final List<String> problems;
  const OverrideApplyResult(this.rules, this.problems);
}

List<OverrideEntry> loadOverrides(String path) {
  if (!File(path).existsSync()) return const [];
  final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final out = <OverrideEntry>[];
  for (final o in (raw['overrides'] as List).cast<Map<String, dynamic>>()) {
    final kind = o['kind'] as String;
    out.add(OverrideEntry(
      overrideId: o['overrideId'] as String,
      reason: o['reason'] as String,
      primarySourceUrl: o['primarySourceUrl'] as String,
      verificationSourceUrl: (o['verificationSourceUrl'] as String?) ?? '',
      reviewedBy: o['reviewedBy'] as String,
      reviewedAt: o['reviewedAt'] as String,
      kind: kind,
      rule: kind == 'addRule'
          ? DatasetReader.readRuleJson(o['rule'] as Map<String, dynamic>)
          : null,
      ruleId: o['ruleId'] as String?,
      addShipIds: ((o['addShipIds'] as List?) ?? const []).cast<int>(),
      removeShipIds: ((o['removeShipIds'] as List?) ?? const []).cast<int>(),
      resolvesEquipmentIds:
          ((o['resolvesEquipmentIds'] as List?) ?? const []).cast<int>(),
    ));
  }
  return out;
}

OverrideApplyResult applyOverrides(List<BonusRule> rules, List<OverrideEntry> overrides) {
  final out = List<BonusRule>.of(rules);
  final problems = <String>[];
  for (final o in overrides) {
    switch (o.kind) {
      case 'addRule':
        if (o.rule == null) {
          problems.add('${o.overrideId}: addRule without rule');
          continue;
        }
        out.add(o.rule!);
      case 'removeRuleId':
        final before = out.length;
        out.removeWhere((r) => r.ruleId == o.ruleId);
        if (out.length == before) {
          problems.add('${o.overrideId}: no rule ${o.ruleId} to remove');
        }
      case 'extendRuleId':
        var found = false;
        for (var i = 0; i < out.length; i++) {
          if (out[i].ruleId != o.ruleId) continue;
          found = true;
          final sc = out[i].shipCondition;
          out[i] = BonusRule(
            ruleId: out[i].ruleId,
            equipment: out[i].equipment,
            category: out[i].category,
            shipCondition: ShipCondition(
              shipIds: (sc.shipIds.toSet()..addAll(o.addShipIds)..removeAll(o.removeShipIds)).toList()..sort(),
              baseShipIds: sc.baseShipIds,
              classIds: sc.classIds,
              shipTypeIds: sc.shipTypeIds,
              nationalityIds: sc.nationalityIds,
            ),
            equipmentCondition: out[i].equipmentCondition,
            requires: out[i].requires,
            effect: out[i].effect,
            source: out[i].source,
            notes: [...out[i].notes, 'override:${o.overrideId}'],
          );
        }
        if (!found) {
          problems.add('${o.overrideId}: no rule ${o.ruleId} to extend');
        }
      default:
        problems.add('${o.overrideId}: unknown kind ${o.kind}');
    }
  }
  return OverrideApplyResult(out, problems);
}
