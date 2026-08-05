import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import '../../tool/wiki_bonus/lib/ship_group_parser.dart';
import '../../tool/wiki_bonus/lib/table_expander.dart';

ExpandedCell cell(String html) {
  final table =
      html_parser.parse('<table><tr><td>$html</td></tr></table>').querySelector('table')!;
  return expandTable(table)[0][0]!;
}

void main() {
  group('parseShipGroup', () {
    test('empty cell means all ships', () {
      final r = parseShipGroupSafe(cell(''));
      expect(r, isA<ShipGroupSpec>());
      expect((r as ShipGroupSpec).isAllShips, isTrue);
    });

    test('bare ship links become shipNames', () {
      final r = parseShipGroupSafe(cell(
          '<a href="/kancolle/%E6%99%82%E9%9B%A8%E6%94%B9%E4%BA%8C" title="時雨改二">時雨改二</a><br class="spacer"><a href="/kancolle/%E9%9B%AA%E9%A2%A8%E6%94%B9" title="雪風改">雪風改</a>'));
      final s = r as ShipGroupSpec;
      expect(s.shipNames, containsAll(['時雨改二', '雪風改']));
    });

    test('link + 型 suffix becomes class anchor', () {
      final r = parseShipGroupSafe(cell(
          '<a href="/kancolle/%E7%99%BD%E9%9C%B2" title="白露">白露</a>型'));
      final s = r as ShipGroupSpec;
      expect(s.classAnchors, ['白露']);
    });

    test('two adjacent class groups 白露型朝潮型', () {
      final r = parseShipGroupSafe(cell(
          '<a href="/kancolle/%E7%99%BD%E9%9C%B2" title="白露">白露</a>型<br class="spacer"><a href="/kancolle/%E6%9C%9D%E6%BD%AE" title="朝潮">朝潮</a>型'));
      final s = r as ShipGroupSpec;
      expect(s.classAnchors, ['白露', '朝潮']);
    });

    test('他 prefix + 全艦 + (含X) inclusion', () {
      final r = parseShipGroupSafe(cell(
          '他<a href="/kancolle/%E7%99%BD%E9%9C%B2" title="白露">白露</a>型<a href="/kancolle/%E6%9C%9D%E6%BD%AE" title="朝潮">朝潮</a>型全艦 他<a href="/kancolle/%E9%99%BD%E7%82%8E" title="陽炎">陽炎</a>型(含<a href="/kancolle/%E7%A7%8B%E9%9B%B2%E6%94%B9%E4%BA%8C" title="秋雲改二">秋雲改二</a>)'));
      final s = r as ShipGroupSpec;
      expect(s.othersExcluded, isTrue);
      expect(s.classAnchors, ['白露', '朝潮', '陽炎']);
      expect(s.inclusions, ['秋雲改二']);
    });

    test('glossary term 特型 with (X以外) exclusion spanning link', () {
      final r = parseShipGroupSafe(cell(
          '<a href="/kancolle/%E7%94%A8%E8%AA%9E%E9%9B%862#le765ff7" title="用語集2">特型</a>(<a href="/kancolle/%E6%B7%B1%E9%9B%AA%E6%94%B9%E4%BA%8C" title="深雪改二">深雪改二</a>以外)'));
      final s = r as ShipGroupSpec;
      expect(s.glossaryTerms, ['特型']);
      expect(s.exclusions, ['深雪改二']);
    });

    test('glossary term 特型 + 全艦', () {
      final r = parseShipGroupSafe(cell(
          '<a href="/kancolle/%E7%94%A8%E8%AA%9E%E9%9B%862#le765ff7" title="用語集2">特型</a>全艦'));
      final s = r as ShipGroupSpec;
      expect(s.glossaryTerms, ['特型']);
    });

    test('ship type term 駆逐艦 as plain text', () {
      final r = parseShipGroupSafe(cell('駆逐艦'));
      final s = r as ShipGroupSpec;
      expect(s.shipTypeNames, ['駆逐艦']);
    });

    test('nationality term アメリカ艦', () {
      final r = parseShipGroupSafe(cell('アメリカ艦'));
      final s = r as ShipGroupSpec;
      expect(s.nationalityTerms, ['アメリカ艦']);
    });

    test('sonar style multi-ship cell with ・ separators', () {
      final r = parseShipGroupSafe(cell(
          '<a href="/kancolle/%E7%A5%9E%E9%A2%A8" title="神風">神風</a>・<a href="/kancolle/%E6%98%A5%E9%A2%A8" title="春風">春風</a><br class="spacer"><a href="/kancolle/%E6%99%82%E9%9B%A8" title="時雨">時雨</a>・<a href="/kancolle/%E5%B1%B1%E9%A2%A8" title="山風">山風</a>'));
      final s = r as ShipGroupSpec;
      expect(s.shipNames, ['神風', '春風', '時雨', '山風']);
    });

    test('slash separators 雪風改 / 丹陽', () {
      final r = parseShipGroupSafe(cell(
          '<a href="/kancolle/%E9%9B%AA%E9%A2%A8%E6%94%B9" title="雪風改">雪風改</a> / <a href="/kancolle/%E4%B8%B9%E9%99%BD" title="丹陽">丹陽</a>'));
      final s = r as ShipGroupSpec;
      expect(s.shipNames, ['雪風改', '丹陽']);
    });

    test('unrecognized plain text yields unresolved', () {
      final r = parseShipGroupSafe(cell('その他'));
      expect(r, isA<ShipGroupUnresolved>());
    });

    test('class group without link yields unresolved', () {
      final r = parseShipGroupSafe(cell('白露型'));
      expect(r, isA<ShipGroupUnresolved>());
    });

    test('unterminated parenthesis yields unresolved', () {
      final r = parseShipGroupSafe(cell('(含秋雲改二'));
      expect(r, isA<ShipGroupUnresolved>());
    });
  });

  group('parseEquipmentRef', () {
    test('本装備 means own equipment', () {
      final r = parseEquipmentRef(cell('本装備'));
      expect(r, isA<EquipmentRefOwn>());
    });

    test('link cell means named equipment', () {
      final r = parseEquipmentRef(cell(
          '<a href="/kancolle/61cm%E4%B8%89%E9%80%A3%E8%A3%85%E9%AD%9A%E9%9B%B7" title="61cm三連装魚雷">61cm三連装魚雷</a>'));
      final r2 = r as EquipmentRefNamed;
      expect(r2.names, ['61cm三連装魚雷']);
    });

    test('category label 水上電探', () {
      final r = parseEquipmentRef(cell('水上電探'));
      expect(r, isA<EquipmentRefCategory>());
      expect((r as EquipmentRefCategory).label, '水上電探');
    });

    test('dash means no requirement', () {
      expect(parseEquipmentRef(cell('-')), isNull);
      expect(parseEquipmentRef(cell('')), isNull);
    });
  });
}
