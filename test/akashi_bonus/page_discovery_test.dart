import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import '../../tool/akashi_bonus/lib/page_discovery.dart';

void main() {
  group('discoverWeapons', () {
    test('discovers w266 from the real homepage fragment', () {
      final html = File('test/akashi_bonus/fixtures/homepage_equipment_fragment.html')
          .readAsStringSync();
      final doc = html_parser.parse(html);
      final result = discoverWeapons(doc.body!);
      expect(result.problems, isEmpty);
      expect(result.weapons, hasLength(1));
      final w = result.weapons.single;
      expect(w.equipmentId, 266);
      expect(w.name, '12.7cm連装砲C型改二');
      expect(w.detailUrl, 'https://akashi-list.me/detail/w266.html');
    });

    test('multiple weapons come out numerically sorted', () {
      final doc = html_parser.parse(
          '<body>'
          '<div class="weapon" id="w300"><img alt="300: 装備甲"></div>'
          '<div class="weapon" id="w120"><img alt="120: 装備乙"></div>'
          '<div class="weapon" id="w266"><img alt="266: 装備丙"></div>'
          '</body>');
      final result = discoverWeapons(doc.body!);
      expect(result.problems, isEmpty);
      expect(result.sortedIds, [120, 266, 300]);
    });

    test('duplicate ids are rejected', () {
      final doc = html_parser.parse(
          '<body>'
          '<div class="weapon" id="w120"><img alt="120: 装備"></div>'
          '<div class="weapon" id="w120"><img alt="120: 装備"></div>'
          '</body>');
      final result = discoverWeapons(doc.body!);
      expect(result.weapons, hasLength(1));
      expect(result.problems, contains(contains('duplicate')));
    });

    test('missing alt is rejected', () {
      final doc =
          html_parser.parse('<body><div class="weapon" id="w120"><img></div></body>');
      final result = discoverWeapons(doc.body!);
      expect(result.weapons, isEmpty);
      expect(result.problems, contains(contains('alt')));
    });

    test('malformed id is rejected', () {
      final doc = html_parser.parse(
          '<body><div class="weapon" id="w12"><img alt="12: 装備"></div>'
          '<div class="weapon" id="x300"><img alt="300: 装備"></div></body>');
      final result = discoverWeapons(doc.body!);
      expect(result.weapons, isEmpty);
      expect(result.problems, hasLength(2));
    });
  });
}
