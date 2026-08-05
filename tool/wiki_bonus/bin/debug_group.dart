import 'package:html/parser.dart' as html_parser;

import '../lib/ship_group_parser.dart';
import '../lib/table_expander.dart';

void main() {
  final html = '他<a href="/kancolle/%E7%99%BD%E9%9C%B2" title="白露">白露</a>型<a href="/kancolle/%E6%9C%9D%E6%BD%AE" title="朝潮">朝潮</a>型全艦 他<a href="/kancolle/%E9%99%BD%E7%82%8E" title="陽炎">陽炎</a>型(含<a href="/kancolle/%E7%A7%8B%E9%9B%B2%E6%94%B9%E4%BA%8C" title="秋雲改二">秋雲改二</a>)';
  final table = html_parser.parse('<table><tr><td>$html</td></tr></table>')
      .querySelector('table')!;
  final cell = expandTable(table)[0][0]!;
  print('text: "${cell.text}"');
  var i = 0;
  for (final s in cell.segments) {
    print('seg$i: isLink=${s.isLink} title=${s.title} text="${s.text}"');
    i++;
  }
  final r = parseShipGroupSafe(cell);
  if (r is ShipGroupSpec) {
    print('classAnchors: ${r.classAnchors} ships: ${r.shipNames} incl: ${r.inclusions} excl: ${r.exclusions} others: ${r.othersExcluded}');
  } else {
    print('unresolved: ${(r as ShipGroupUnresolved).reason}');
  }
}
