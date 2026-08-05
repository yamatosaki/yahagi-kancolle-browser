import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import '../../tool/akashi_bonus/lib/dataset_validator.dart';
import '../../tool/akashi_bonus/lib/detail_parser.dart';
import '../../tool/akashi_bonus/lib/models.dart';
import '../../tool/akashi_bonus/lib/name_resolver.dart';
import '../../tool/akashi_bonus/lib/rule_builder.dart';

const String fixturesDir = 'test/akashi_bonus/fixtures';

void main() {
  final master = MasterData.fromJsonFile('$fixturesDir/master_266.json');

  group('w266 end-to-end', () {
    late List<BonusRule> rules;

    setUpAll(() {
      final html =
          File('$fixturesDir/detail_w266.html').readAsStringSync();
      final page = parseDetailDocument(html_parser.parse(html), 266);
      final built = RuleBuilder(master).buildForPage(
        page: page,
        detailUrl: 'https://akashi-list.me/detail/w266.html',
        pageContent: html,
        fetchedAt: '2026-08-04T00:00:00+00:00',
        httpLastModified: null,
      );
      expect(built.unresolved, isEmpty, reason: 'no unresolved for w266');
      rules = built.rules;
    });

    test('generates 10 rules with stable ruleIds', () {
      expect(rules.map((r) => r.ruleId).toList(), [
        'akashi-266-count-001',
        'akashi-266-single-001',
        'akashi-266-single-002',
        'akashi-266-single-003',
        'akashi-266-single-004',
        'akashi-266-single-005',
        'akashi-266-single-006',
        'akashi-266-synergy-001',
        'akashi-266-synergy-002',
        'akashi-266-synergy-003',
        'akashi-266-synergy-004',
      ]);
    });

    test('matches the expected fixture exactly (modulo provenance)', () {
      final expected = jsonDecode(
          File('$fixturesDir/detail_w266_expected.json').readAsStringSync())
          as Map<String, dynamic>;
      final expRules = (expected['rules'] as List).cast<Map<String, dynamic>>();

      Map<String, dynamic> normalize(Map<String, dynamic> r) {
        final src = (r['source'] as Map<String, dynamic>);
        final srcCopy = Map<String, dynamic>.of(src)
          ..remove('fetchedAt')
          ..remove('contentSha256')
          ..remove('fragmentHash');
        final copy = Map<String, dynamic>.of(r);
        copy['source'] = srcCopy;
        return copy;
      }

      final actual = rules.map((r) => normalize(r.toJson())).toList();
      final exp = expRules.map(normalize).toList();
      for (var i = 0; i < exp.length; i++) {
        expect(actual[i], exp[i], reason: 'rule index $i ${exp[i]['ruleId']}');
      }
      expect(actual, hasLength(exp.length));
    });

    test('rule source provenance fields are populated', () {
      for (final r in rules) {
        expect(r.source.url, 'https://akashi-list.me/detail/w266.html');
        expect(r.source.pageName, '12.7cm連装砲C型改二');
        expect(r.source.fetchedAt, isNotEmpty);
        expect(r.source.contentSha256, isNotEmpty);
        expect(r.source.fragmentHash, isNotEmpty);
        expect(r.source.sourceGroupLabel, isNotEmpty);
      }
    });

    test('round-1 validator passes', () {
      final result = DatasetValidator(master).validate(
        rules: rules,
        unresolvedEmpty: true,
      );
      expect(result.issues, isEmpty, reason: result.issues.join('\n'));
    });
  });
}
