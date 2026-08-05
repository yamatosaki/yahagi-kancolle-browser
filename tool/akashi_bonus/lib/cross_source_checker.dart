/// Cross-source comparison of the generated rules against:
///   1. ElectronicObserver `FitBonuses.json` (programmatic, type-based)
///   2. WikiWiki equipment pages (semantic spot checks recorded as entries)
///
/// Differences are classified and never auto-applied.
library;

import 'dart:convert';
import 'dart:io';

import 'models.dart';

enum DiffClass {
  akashiNewer('akashi_newer'),
  wikiNewer('wiki_newer'),
  externalNewer('external_newer'),
  sourceMissing('source_missing'),
  formatDifference('format_difference'),
  parserBug('parser_bug'),
  sourceConflict('source_conflict'),
  unresolved('unresolved'),
  matched('matched');

  final String label;
  const DiffClass(this.label);
}

class DiffEntry {
  final int equipmentId;
  final String ruleId;
  final DiffClass kind;
  final String detail;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? resolution;

  const DiffEntry({
    required this.equipmentId,
    required this.ruleId,
    required this.kind,
    required this.detail,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'equipmentId': equipmentId,
        'ruleId': ruleId,
        'kind': kind.label,
        'detail': detail,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (reviewedAt != null) 'reviewedAt': reviewedAt,
        if (resolution != null) 'resolution': resolution,
      };
}

class CrossSourceResult {
  final List<DiffEntry> diffs;
  final Map<String, Object?> meta;
  const CrossSourceResult(this.diffs, this.meta);

  List<DiffEntry> get unreviewed =>
      diffs.where((d) => d.reviewedBy == null).toList();
}

/// Maps an equipment master id to its type ids via `api_type`.
class EoComparator {
  final Map<String, dynamic> eoData;
  final Map<int, List<int>> itemTypes;

  EoComparator(this.eoData, this.itemTypes);

  /// The EO entry list for the equipment type ids of [equipmentId], or null
  /// when EO does not cover those types.
  List<Map<String, dynamic>>? entryForEquipment(int equipmentId) {
    final types = itemTypes[equipmentId];
    if (types == null || types.isEmpty) return null;
    final rawEntries = eoData['entries'] as List? ??
        (eoData.isEmpty ? const <dynamic>[] : <dynamic>[eoData]);
    final entries = rawEntries.cast<Map<String, dynamic>>();
    final hits = <Map<String, dynamic>>[];
    for (final e in entries) {
      final et = (e['types'] as List?)?.cast<num>() ?? const <num>[];
      if (et.any((t) => types.contains(t.toInt()))) {
        hits.add(e);
      }
    }
    return hits.isEmpty ? null : hits;
  }
}

/// Compares [rules] against the EO dataset. Returns classified diffs.
List<DiffEntry> compareWithEo(
  List<BonusRule> rules,
  Map<String, dynamic> eoData,
  Map<int, List<int>> itemTypes,
) {
  final cmp = EoComparator(eoData, itemTypes);
  final diffs = <DiffEntry>[];
  for (final r in rules) {
    if (r.equipment.ids.isEmpty) continue;
    final eid = r.equipment.ids.first;
    final entry = cmp.entryForEquipment(eid);
    if (entry == null) {
      diffs.add(DiffEntry(
        equipmentId: eid,
        ruleId: r.ruleId,
        kind: DiffClass.sourceMissing,
        detail:
            'ElectronicObserver has no bonus entry for equipment $eid types; rule kept from akashi-list',
      ));
      continue;
    }
    // EO entries are type-scoped: compare that EO covers the same ship types.
    for (final e in entry) {
      final eoTypes = (e['types'] as List).cast<num>();
      final shared = eoTypes.where((t) => (itemTypes[eid] ?? []).contains(t.toInt())).toList();
      if (shared.isEmpty) continue;
      final bonuses = (e['bonuses'] as List).cast<Map<String, dynamic>>();
      final shipTypeIds = <int>{
        for (final b in bonuses)
          for (final st in ((b['shipType'] as List?) ?? const <num>[]))
            (st as num).toInt(),
      };
      final ruleStypes = r.shipCondition.shipTypeIds;
      if (ruleStypes.isEmpty) {
        // Rule is ship-scoped; EO is type-scoped. Structural difference.
        diffs.add(DiffEntry(
          equipmentId: eid,
          ruleId: r.ruleId,
          kind: DiffClass.formatDifference,
          detail:
              'EO covers shipTypes $shipTypeIds for type ${shared.first}; akashi rule is ship-scoped',
        ));
        continue;
      }
      final missing = shipTypeIds.difference(ruleStypes.toSet());
      if (missing.isNotEmpty) {
        diffs.add(DiffEntry(
          equipmentId: eid,
          ruleId: r.ruleId,
          kind: DiffClass.sourceConflict,
          detail:
              'EO covers shipTypes ${missing.toList()..sort()} not covered by akashi rule',
        ));
      }
    }
  }
  return diffs;
}

class WikiCrossCheckEntry {
  final int equipmentId;
  final String ruleId;
  final String checkType; // manual | spot
  final String status; // passed | difference
  final String detail;
  final String checkedAt;
  final String checkedBy;
  final DiffClass? diffClass;

  const WikiCrossCheckEntry({
    required this.equipmentId,
    required this.ruleId,
    required this.checkType,
    required this.status,
    required this.detail,
    required this.checkedAt,
    required this.checkedBy,
    this.diffClass,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'equipmentId': equipmentId,
        'ruleId': ruleId,
        'checkType': checkType,
        'status': status,
        'detail': detail,
        'checkedAt': checkedAt,
        'checkedBy': checkedBy,
        if (diffClass != null) 'diffClass': diffClass!.label,
      };
}

class WikiCrossChecker {
  final String checkedBy;
  final String checkedAt;
  WikiCrossChecker({required this.checkedBy, required this.checkedAt});

  List<WikiCrossCheckEntry> entries = [];

  void record({
    required int equipmentId,
    required String ruleId,
    required String checkType,
    required String status,
    required String detail,
    DiffClass? diffClass,
  }) {
    entries.add(WikiCrossCheckEntry(
      equipmentId: equipmentId,
      ruleId: ruleId,
      checkType: checkType,
      status: status,
      detail: detail,
      checkedAt: checkedAt,
      checkedBy: checkedBy,
      diffClass: diffClass,
    ));
  }

  void write(String path) {
    File(path).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(entries.map((e) => e.toJson()).toList())}\n');
  }
}
