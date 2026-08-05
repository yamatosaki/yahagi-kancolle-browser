import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../../tool/wiki_bonus/lib/table_expander.dart';

Element table(String html) =>
    html_parser.parse('<table>$html</table>').querySelector('table')!;

void main() {
  group('expandTable', () {
    test('plain 2x2 table stays a 2x2 matrix', () {
      final t = table('<tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr>');
      final m = expandTable(t);
      expect(m.length, 2);
      expect(m[0].length, 2);
      expect(m[0][0]!.text, 'a');
      expect(m[1][1]!.text, 'd');
    });

    test('rowspan=2 cell is duplicated into the next row', () {
      final t = table(
          '<tr><td rowspan="2">a</td><td>b</td></tr><tr><td>c</td></tr>');
      final m = expandTable(t);
      expect(m.length, 2);
      expect(m[0].length, 2);
      expect(m[1].length, 2);
      expect(m[0][0]!.text, 'a');
      expect(m[1][0]!.text, 'a');
      expect(m[1][1]!.text, 'c');
    });

    test('colspan=3 cell is duplicated across columns', () {
      final t = table('<tr><td colspan="3">a</td></tr><tr><td>b</td><td>c</td><td>d</td></tr>');
      final m = expandTable(t);
      expect(m[0].length, 3);
      expect(m[0][0]!.text, 'a');
      expect(m[0][2]!.text, 'a');
      expect(m[1][1]!.text, 'c');
    });

    test('combined rowspan+colspan fills a 2x2 block', () {
      final t = table('<tr><td rowspan="2" colspan="2">a</td><td>b</td></tr><tr><td>c</td></tr>');
      final m = expandTable(t);
      expect(m.length, 2);
      expect(m[0].length, 3);
      expect(m[1].length, 3);
      expect(m[0][0]!.text, 'a');
      expect(m[0][1]!.text, 'a');
      expect(m[1][0]!.text, 'a');
      expect(m[1][1]!.text, 'a');
      expect(m[1][2]!.text, 'c');
    });

    test('rowspan landing in a row with extra cells yields inconsistent widths and throws', () {
      final t = table(
          '<tr><td rowspan="2">a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr>');
      expect(() => expandTable(t), throwsFormatException);
    });

    test('rowspan that overflows the table throws FormatException', () {
      final t = table('<tr><td rowspan="5">a</td><td>b</td></tr><tr><td>c</td></tr>');
      expect(() => expandTable(t), throwsFormatException);
    });

    test('colspan that overflows row width throws FormatException', () {
      final t = table('<tr><td colspan="9">a</td></tr><tr><td>b</td><td>c</td></tr>');
      expect(() => expandTable(t), throwsFormatException);
    });

    test('cell text normalizes newlines and collapses whitespace', () {
      final t = table('<tr><td>foo<br class="spacer">bar</td><td>  a&nbsp;&nbsp;b  </td></tr>');
      final m = expandTable(t);
      expect(m[0][0]!.text, 'foo\nbar');
      expect(m[0][1]!.text, 'a b');
    });

    test('links are captured with href and title, stripped from text', () {
      final t = table(
          '<tr><td>他<a href="/kancolle/%E7%99%BD%E9%9C%B2" title="白露" class="rel-wiki-page">白露</a>型</td></tr>');
      final m = expandTable(t);
      expect(m[0][0]!.text, '他白露型');
      expect(m[0][0]!.links, hasLength(1));
      expect(m[0][0]!.links.single.href, '/kancolle/%E7%99%BD%E9%9C%B2');
      expect(m[0][0]!.links.single.title, '白露');
    });

    test('footnote anchors are removed from text but kept as notes', () {
      final t = table(
          '<tr><td>水上電探<a id="notetext_6" class="note_super tooltip" data-tooltip-content="&lt;p&gt;索敵+5以上の電探&lt;/p&gt;">*6</a></td></tr>');
      final m = expandTable(t);
      expect(m[0][0]!.text, '水上電探');
      expect(m[0][0]!.footnotes, hasLength(1));
      expect(m[0][0]!.footnotes.single.content, '索敵+5以上の電探');
    });

    test('anchor with name=bonus inside table cell does not break parsing', () {
      final t = table('<tr><td><a name="bonus"></a>x</td></tr>');
      final m = expandTable(t);
      expect(m[0][0]!.text, 'x');
    });

    test('th cells are preserved as ordinary cells', () {
      final t = table('<tr><th>装備</th><th>火力</th></tr><tr><td>a</td><td>1</td></tr>');
      final m = expandTable(t);
      expect(m[0][0]!.text, '装備');
      expect(m[0][0]!.isHeader, isTrue);
      expect(m[1][0]!.isHeader, isFalse);
    });

    test('rawHtml is retained for row hashing', () {
      final t = table('<tr><td>+5</td><td></td></tr>');
      final m = expandTable(t);
      expect(m[0][0]!.rawHtml, contains('+5'));
    });

    test('empty table yields zero rows', () {
      final t = table('<tbody></tbody>');
      final m = expandTable(t);
      expect(m, isEmpty);
    });
  });

  group('rowHtmlHash', () {
    test('hashes raw row html', () {
      final t = table('<tr><td>a</td><td>b</td></tr>');
      final h = rowHtmlHash(expandTable(t)[0], 0);
      expect(h, startsWith('sha256:'));
      expect(h.length, greaterThan(70));
    });
  });
}
