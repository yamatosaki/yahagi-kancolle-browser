import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/akashi_bonus/lib/dataset_validator.dart';
import '../../tool/akashi_bonus/lib/models.dart';
import '../../tool/akashi_bonus/lib/name_resolver.dart';
import '../../tool/akashi_bonus/lib/reference_calculator.dart';

void main() {
  final master =
      MasterData.fromJsonFile('test/akashi_bonus/fixtures/master_266.json');
  final (rules, _) =
      DatasetReader.read('assets/data/equipment_fit_bonuses.json');
  final calc = ReferenceCalculator(rules, master: master);

  bool hasRadar(EquipmentPredicate p) => p.lineOfSightGte != null;
  bool noRadar(EquipmentPredicate p) => p.lineOfSightGte == null;

  CalcResult run(int shipId, {int count = 1, int star = 0, bool radar = false}) {
    return calc.compute(
      shipId: shipId,
      equipmentCounts: {266: count},
      equipmentStars: {266: star},
      predicateChecker: radar ? hasRadar : noRadar,
    );
  }

  group('single bonus positives (10)', () {
    test('雪風改二 x1: 火力+2 回避+1', () {
      expect(run(656).bonus.stats, {'firepower': 2, 'evasion': 1});
    });
    test('陽炎改二 x1: 火力+2', () {
      expect(run(566).bonus.stats, {'firepower': 2});
    });
    test('白露(42): 火力+1', () {
      expect(run(42).bonus.stats, {'firepower': 1});
    });
    test('夕立改二(144, override 全形态): 火力+1', () {
      expect(run(144).bonus.stats, {'firepower': 1});
    });
    test('丹陽(651, override): 火力+1 回避+1', () {
      expect(run(651).bonus.stats, {'firepower': 1, 'evasion': 1});
    });
    test('時雨改三(961, override): 火力+2 回避+2 命中+1', () {
      expect(run(961).bonus.stats,
          {'firepower': 2, 'evasion': 2, 'accuracy': 1});
    });
    test('雪風改(228): 火力+1 回避+1', () {
      expect(run(228).bonus.stats, {'firepower': 1, 'evasion': 1});
    });
    test('時雨改二(145): 火力+1 回避+1', () {
      expect(run(145).bonus.stats, {'firepower': 1, 'evasion': 1});
    });
    test('磯風乙改(557): 火力+1 回避+1', () {
      expect(run(557).bonus.stats, {'firepower': 1, 'evasion': 1});
    });
    test('秋雲改二(648): 火力+2', () {
      expect(run(648).bonus.stats, {'firepower': 2});
    });
  });

  group('count cases (5)', () {
    test('陽炎改二 x2: 火力+5', () {
      expect(run(566, count: 2).bonus.stats, {'firepower': 5});
    });
    test('陽炎改二 x3: 火力+6', () {
      expect(run(566, count: 3).bonus.stats, {'firepower': 6});
    });
    test('雪風改二 x2: 火力+5 回避+2', () {
      expect(run(656, count: 2).bonus.stats,
          {'firepower': 5, 'evasion': 2});
    });
    test('雪風改二 x3: 火力+6 回避+3', () {
      expect(run(656, count: 3).bonus.stats,
          {'firepower': 6, 'evasion': 3});
    });
    test('天津風改二 x2: 火力+5', () {
      expect(run(951, count: 2).bonus.stats, {'firepower': 5});
    });
  });

  group('improvement cases (5, synthetic rules)', () {
    BonusRule impTableRule() => BonusRule(
          ruleId: 'test-imp-001',
          equipment: const EquipmentRef(ids: [266]),
          category: RuleCategory.improvement,
          effect: ImprovementTableEffect({
            0: const Bonus({'firepower': 2}),
            1: const Bonus({'firepower': 2}),
            2: const Bonus({'firepower': 2}),
            3: const Bonus({'firepower': 2}),
            4: const Bonus({'firepower': 3}),
            5: const Bonus({'firepower': 3}),
            6: const Bonus({'firepower': 3}),
            7: const Bonus({'firepower': 3}),
            8: const Bonus({'firepower': 3}),
            9: const Bonus({'firepower': 3}),
            10: const Bonus({'firepower': 4}),
          }),
          source: const SourceInfo(
            url: 'https://akashi-list.me/detail/w266.html',
            pageName: 'x',
            fetchedAt: 't',
            contentSha256: 'x',
            fragmentHash: 'x',
            sourceGroupLabel: 'x',
            rawEffect: '火力',
          ),
        );
    BonusRule minImpRule() => BonusRule(
          ruleId: 'test-imp-002',
          equipment: const EquipmentRef(ids: [266]),
          category: RuleCategory.improvement,
          equipmentCondition: const EquipmentCondition(minImprovement: 6),
          effect: const PerEquipmentEffect(Bonus({'antiAir': 2})),
          source: const SourceInfo(
            url: 'https://akashi-list.me/detail/w266.html',
            pageName: 'x',
            fetchedAt: 't',
            contentSha256: 'x',
            fragmentHash: 'x',
            sourceGroupLabel: 'x',
            rawEffect: '対空',
          ),
        );
    final impCalc = ReferenceCalculator([impTableRule(), minImpRule()]);

    test('star 0 uses base', () {
      final r = impCalc.compute(
        shipId: 566,
        equipmentCounts: {266: 1},
        equipmentStars: {266: 0},
        predicateChecker: noRadar,
      );
      expect(r.stat('firepower'), 2);
    });
    test('star 3 no improvement', () {
      final r = impCalc.compute(
        shipId: 566,
        equipmentCounts: {266: 1},
        equipmentStars: {266: 3},
        predicateChecker: noRadar,
      );
      expect(r.stat('firepower'), 2);
    });
    test('star 4 threshold', () {
      final r = impCalc.compute(
        shipId: 566,
        equipmentCounts: {266: 1},
        equipmentStars: {266: 4},
        predicateChecker: noRadar,
      );
      expect(r.stat('firepower'), 3);
    });
    test('star 10 max', () {
      final r = impCalc.compute(
        shipId: 566,
        equipmentCounts: {266: 1},
        equipmentStars: {266: 10},
        predicateChecker: noRadar,
      );
      expect(r.stat('firepower'), 4);
    });
    test('minImprovement gate: star 5 no 対空, star 6 yes', () {
      final r5 = impCalc.compute(
        shipId: 566,
        equipmentCounts: {266: 1},
        equipmentStars: {266: 5},
        predicateChecker: noRadar,
      );
      expect(r5.stat('antiAir'), 0);
      final r6 = impCalc.compute(
        shipId: 566,
        equipmentCounts: {266: 1},
        equipmentStars: {266: 6},
        predicateChecker: noRadar,
      );
      expect(r6.stat('antiAir'), 2);
    });
  });

  group('synergy cases (5)', () {
    test('雪風改二 + radar: +2/+3/+1 once', () {
      final r = run(656, radar: true);
      expect(r.bonus.stats,
          {'firepower': 4, 'torpedo': 3, 'evasion': 2});
    });
    test('白露(42) + radar: +1/+3/+1', () {
      final r = run(42, radar: true);
      expect(r.bonus.stats, {'firepower': 2, 'torpedo': 3, 'evasion': 1});
    });
    test('時雨改三(961) + radar: +1/+3/+1 (override)', () {
      final r = run(961, radar: true);
      expect(r.bonus.stats,
          {'firepower': 3, 'torpedo': 3, 'evasion': 3, 'accuracy': 1});
    });
    test('丹陽(651) + radar: +2/+3/+1 (override)', () {
      final r = run(651, radar: true);
      expect(r.bonus.stats,
          {'firepower': 3, 'torpedo': 3, 'evasion': 2});
    });
    test('multi-copy synergy does not repeat (once)', () {
      final r = run(656, count: 3, radar: true);
      expect(r.bonus.stats,
          {'firepower': 8, 'torpedo': 3, 'evasion': 4});
    });
  });

  group('negative / non-trigger cases (5)', () {
    test('雪風改二 without radar: no synergy', () {
      final r = run(656);
      expect(r.bonus.stats, {'firepower': 2, 'evasion': 1});
    });
    test('島風(332) no bonus at all', () {
      final r = run(332);
      expect(r.bonus.stats, isEmpty);
    });
    test('長門(31) no bonus', () {
      final r = run(31);
      expect(r.bonus.stats, isEmpty);
    });
    test('x4 count overflow notes unresolved, uses last known', () {
      final r = run(566, count: 4);
      expect(r.bonus.stats, {'firepower': 6});
      expect(r.notes, isNotEmpty);
      expect(r.notes.first, contains('overflow=unresolved'));
    });
    test('時雨改二 without radar: 火力+1 回避+1 only', () {
      final r = run(145);
      expect(r.bonus.stats, {'firepower': 1, 'evasion': 1});
    });
  });
}
