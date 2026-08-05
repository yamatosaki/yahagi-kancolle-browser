/// Minimal reference calculator used by round-4 tests to verify the dataset
/// semantics end to end. Not intended for the Flutter app.
library;

import 'models.dart';
import 'name_resolver.dart';

class CalcResult {
  final Bonus bonus;
  final List<String> notes;
  final int rulesApplied;
  const CalcResult(this.bonus, this.notes, this.rulesApplied);

  int stat(String name) => bonus.stats[name] ?? 0;
}

typedef PredicateChecker = bool Function(EquipmentPredicate predicate);

class ReferenceCalculator {
  final List<BonusRule> rules;
  final MasterData? master;

  const ReferenceCalculator(this.rules, {this.master});

  /// Computes the fit bonus for [shipId] given equipped equipment counts,
  /// star levels and a predicate checker for synergy requirements.
  CalcResult compute({
    required int shipId,
    required Map<int, int> equipmentCounts,
    required Map<int, int> equipmentStars,
    required PredicateChecker predicateChecker,
  }) {
    var total = Bonus.empty();
    final notes = <String>[];
    var applied = 0;

    for (final r in rules) {
      if (r.equipment.ids.isEmpty) continue;
      final equipId = r.equipment.ids.first;
      final count = equipmentCounts[equipId] ?? 0;
      if (count <= 0) continue;
      if (!_shipMatches(r.shipCondition, shipId)) continue;
      final star = equipmentStars[equipId] ?? 0;
      final ec = r.equipmentCondition;
      if (star < ec.minImprovement || star > ec.maxImprovement) continue;
      if (r.requires.any((req) => !predicateChecker(req.predicate))) continue;

      final eff = r.effect;
      if (eff is PerEquipmentEffect) {
        total = total + _scale(eff.bonus, count);
        applied++;
      } else if (eff is OnceEffect) {
        total = total + eff.bonus;
        applied++;
      } else if (eff is CountTableEffect) {
        final maxCount = eff.byCount.keys.isNotEmpty
            ? (eff.byCount.keys.reduce((a, b) => a > b ? a : b))
            : 0;
        if (count > maxCount && eff.overflow != 'repeat') {
          notes.add(
              '${r.ruleId}: count $count exceeds table (max $maxCount), overflow=${eff.overflow}');
        }
        final at = eff.byCount[count] ?? eff.byCount[maxCount];
        if (at != null) {
          total = total + at;
          applied++;
        }
      } else if (eff is ImprovementTableEffect) {
        final starKey = star.clamp(0, 10);
        final at = eff.byStar[starKey];
        if (at != null) {
          total = total + at;
          applied++;
        }
      }
    }
    final normalized = Bonus({
      for (final e in total.stats.entries)
        if (e.value != 0) e.key: e.value,
    });
    return CalcResult(normalized, notes, applied);
  }

  bool _shipMatches(ShipCondition sc, int shipId) {
    if (sc.isEmpty) return true;
    if (sc.shipIds.contains(shipId)) return true;
    if (master != null && sc.classIds.isNotEmpty) {
      final ct = master!.ctypeByShip[shipId];
      if (ct != null && sc.classIds.contains(ct)) return true;
    }
    if (master != null && sc.shipTypeIds.isNotEmpty) {
      final st = master!.shipsById[shipId]?['api_stype'];
      if (st != null && sc.shipTypeIds.contains(st)) return true;
    }
    return false;
  }

  Bonus _scale(Bonus b, int count) {
    if (count <= 1) return b;
    return Bonus({
      for (final e in b.stats.entries) e.key: e.value * count,
    });
  }
}

/// Default predicate checker for 266: 水上電探 = lineOfSight >= 5.
bool surfaceRadarLoSPredicate(EquipmentPredicate p) =>
    p.lineOfSightGte != null;
