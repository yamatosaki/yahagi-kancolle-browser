import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import '../../tool/akashi_bonus/lib/detail_parser.dart';
import '../../tool/akashi_bonus/lib/models.dart';
import '../../tool/akashi_bonus/lib/name_resolver.dart';
import '../../tool/akashi_bonus/lib/rule_builder.dart';

MasterData testMaster() {
  return MasterData.fromJson({
    'api_mst_ship': [
      {'api_id': 566, 'api_name': '陽炎改二', 'api_ctype': 30, 'api_stype': 2},
      {'api_id': 656, 'api_name': '雪風改二', 'api_ctype': 30, 'api_stype': 2},
      {'api_id': 42, 'api_name': '白露', 'api_ctype': 23, 'api_stype': 2},
      {'api_id': 43, 'api_name': '時雨', 'api_ctype': 23, 'api_stype': 2},
      {'api_id': 145, 'api_name': '時雨改二', 'api_ctype': 23, 'api_stype': 2},
      {'api_id': 228, 'api_name': '雪風改', 'api_ctype': 30, 'api_stype': 2},
      {'api_id': 557, 'api_name': '磯風乙改', 'api_ctype': 30, 'api_stype': 2},
      {'api_id': 398, 'api_name': '秋月改二', 'api_ctype': 20, 'api_stype': 2},
    ],
    'api_mst_slotitem': [
      {'api_id': 266, 'api_name': '12.7cm連装砲C型改二', 'api_type': [1, 1, 1, 1, 0]},
    ],
    'api_mst_stype': [
      {'api_id': 2, 'api_name': '駆逐艦'},
    ],
  });
}

Map<String, Object?> buildForFixture(MasterData master, String fixture, int id) {
  final html = File('test/akashi_bonus/fixtures/$fixture').readAsStringSync();
  final doc = html_parser.parse(html);
  final page = parseDetailDocument(doc, id);
  final result = RuleBuilder(master).buildForPage(
    page: page,
    detailUrl: 'https://akashi-list.me/detail/w$id.html',
    pageContent: html,
    fetchedAt: '2026-08-04T00:00:00+00:00',
    httpLastModified: null,
  );
  return {
    'rules': result.rules.map((r) => r.toJson()).toList(),
    'unresolved': result.unresolved.map((u) => u.toJson()).toList(),
  };
}

void main() {
  final master = testMaster();

  group('RuleBuilder with fixtures', () {
    test('single_bonus: perEquipment single rule', () {
      final out = buildForFixture(master, 'single_bonus.html', 300);
      expect(out['unresolved'], isEmpty);
      final rules = out['rules'] as List;
      expect(rules, hasLength(1));
      final r = rules.single as Map<String, dynamic>;
      expect(r['ruleId'], 'akashi-300-single-001');
      expect(r['category'], 'single');
      expect(r['equipment'], {'ids': [300], 'typeIds': []});
      expect((r['effect'] as Map)['mode'], 'perEquipment');
      expect(((r['effect'] as Map)['bonus'] as Map)['firepower'], 2);
      final sc = r['shipCondition'] as Map;
      expect(sc['shipIds'], [42, 43]);
      expect(sc['classIds'], isEmpty);
      final src = r['source'] as Map;
      expect(src['sourceGroupLabel'], '白露型');
      expect(src['rawEffect'], '火力+2');
    });

    test('count_bonus: countTable with increments and cumulative', () {
      final out = buildForFixture(master, 'count_bonus.html', 301);
      expect(out['unresolved'], isEmpty);
      final r = (out['rules'] as List).single as Map<String, dynamic>;
      expect(r['ruleId'], 'akashi-301-count-001');
      final eff = r['effect'] as Map;
      expect(eff['mode'], 'countTable');
      expect(eff['increments'], {
        '1': {'firepower': 2},
        '2': {'firepower': 3},
        '3': {'firepower': 1},
      });
      expect(eff['byCount'], {
        '1': {'firepower': 2},
        '2': {'firepower': 5},
        '3': {'firepower': 6},
      });
      expect(eff['overflow'], 'unresolved');
    });

    test('conditional_only: のみ split into sub-rule', () {
      final out = buildForFixture(master, 'conditional_only_bonus.html', 302);
      expect(out['unresolved'], isEmpty);
      final rules = (out['rules'] as List).cast<Map<String, dynamic>>();
      expect(rules, hasLength(2));
      final fire = rules.firstWhere(
          (r) => (r['source'] as Map)['rawEffect'] == '火力+1');
      expect(((fire['shipCondition'] as Map)['shipIds']), [566, 656]);
      final eva = rules.firstWhere(
          (r) => (r['source'] as Map)['rawEffect'] == '回避+1(雪風改二のみ)');
      expect((eva['shipCondition'] as Map)['shipIds'], [656]);
      expect(eva['source']['rawCondition'], '(雪風改二のみ)');
      expect(((eva['effect'] as Map)['bonus'] as Map)['evasion'], 1);
    });

    test('improvement_bonus: ★4〜 becomes improvement category', () {
      final out = buildForFixture(master, 'improvement_bonus.html', 303);
      expect(out['unresolved'], isEmpty);
      final rules = (out['rules'] as List).cast<Map<String, dynamic>>();
      expect(rules, hasLength(2));
      for (final r in rules) {
        expect(r['category'], 'improvement');
        final ec = r['equipmentCondition'] as Map;
        expect(ec['minImprovement'], 4);
      }
      final fire = rules.firstWhere(
          (r) => ((r['effect'] as Map)['bonus'] as Map)['firepower'] == 5);
      expect((fire['shipCondition'] as Map)['shipIds'], [398]);
    });

    test('synergy_bonus: once mode with radar predicate', () {
      final out = buildForFixture(master, 'synergy_bonus.html', 304);
      expect(out['unresolved'], isEmpty);
      final rules = (out['rules'] as List).cast<Map<String, dynamic>>();
      expect(rules, hasLength(2));
      final syn = rules.firstWhere((r) => r['ruleId'] == 'akashi-304-synergy-001');
      expect((syn['effect'] as Map)['mode'], 'once');
      final req = (syn['requires'] as List).single as Map;
      expect(req['sourceLabel'], '水上電探');
      expect((req['predicate'] as Map)['lineOfSightGte'], 5);
      final b = syn['effect'] as Map;
      expect((b['bonus'] as Map)['torpedo'], 3);
    });

    test('negative_bonus: negative value kept', () {
      final out = buildForFixture(master, 'negative_bonus.html', 305);
      expect(out['unresolved'], isEmpty);
      final r = (out['rules'] as List).single as Map<String, dynamic>;
      expect(((r['effect'] as Map)['bonus'] as Map)['firepower'], -1);
    });

    test('unknown_ship_group: unresolved target, no rules', () {
      final out = buildForFixture(master, 'unknown_ship_group.html', 307);
      expect(out['rules'], isEmpty);
      final unresolved = (out['unresolved'] as List).cast<Map<String, dynamic>>();
      expect(unresolved, hasLength(1));
      expect(unresolved.single['kind'], 'target');
      expect(unresolved.single['detail'], contains('謎の艦群'));
    });

    test('missing_bonus_contents: no_bonus, not an error', () {
      final out = buildForFixture(master, 'missing_bonus_contents.html', 308);
      expect(out['rules'], isEmpty);
      expect(out['unresolved'], isEmpty);
    });
  });

  group('TargetGroupResolver', () {
    test('resolves explicit ship names and tipbody groups', () {
      final resolver = TargetGroupResolver(master, {
        '陽炎型改二': ['陽炎改二', '雪風改二'],
      });
      final r = resolver.resolve('雪風改二');
      expect(r, isA<TargetResolved>());
      expect((r as TargetResolved).shipIds, [656]);
      final g = resolver.resolve('陽炎型改二');
      expect((g as TargetResolved).shipIds, [566, 656]);
      expect(g.sourceLabel, '陽炎型改二');
    });

    test('strict class label resolves via master ctype', () {
      final resolver = TargetGroupResolver(master, const {});
      final r = resolver.resolve('白露型');
      expect(r, isA<TargetResolved>());
      final t = r as TargetResolved;
      expect(t.shipIds, [42, 43, 145]);
      expect(t.classIds, [23]);
    });

    test('unknown token is unresolved', () {
      final resolver = TargetGroupResolver(master, const {});
      expect(resolver.resolve('謎の艦群'), isA<TargetUnresolved>());
    });

    test('ambiguous tipbody ship name is unresolved', () {
      final resolver = TargetGroupResolver(master, const {});
      expect(resolver.resolve('無い名前'), isA<TargetUnresolved>());
    });
  });
}
