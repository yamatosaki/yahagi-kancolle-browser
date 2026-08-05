import 'dart:io';

import 'package:html/parser.dart' as html_parser;

void main(List<String> args) {
  final file = File(args.first);
  final doc = html_parser.parse(file.readAsStringSync());
  var h3 = doc.querySelector('h3');
  while (h3 != null) {
    if ((h3.text ?? '').contains('装備ボーナスについて')) break;
    h3 = h3.nextElementSibling;
  }
  if (h3 == null) {
    stdout.writeln('h3 bonus not found');
    return;
  }
  stdout.writeln('FOUND h3: ${h3.text}');
  var el = h3.nextElementSibling;
  var idx = 0;
  while (el != null && el.localName != 'h3') {
    if (el.localName == 'table') {
      stdout.writeln('--- table #$idx ---');
      dumpTable(el);
      idx++;
    } else if (el.localName == 'ul' || el.localName == 'div' || el.localName == 'p') {
      final t = el.querySelector('table');
      if (t != null) {
        stdout.writeln('--- table #$idx (in ${el.localName}) ---');
        dumpTable(t);
        idx++;
      }
    }
    el = el.nextElementSibling;
  }
}

void dumpTable(dynamic table) {
  var ri = 0;
  for (final tr in table.querySelectorAll('tr')) {
    final cells = <String>[];
    for (final c in tr.children) {
      var text = (c.text ?? '').replaceAll('\u00a0', ' ').trim();
      if (text.length > 50) text = text.substring(0, 50) + '...';
      final rs = c.attributes['rowspan'] ?? '';
      final cs = c.attributes['colspan'] ?? '';
      final links = c.querySelectorAll('a').map((a) => a.attributes['href'] ?? '').join('|');
      cells.add('${c.localName}[$rs x $cs]:"$text"{$links}');
    }
    stdout.writeln('row$ri: ${cells.join(' || ')}');
    ri++;
    if (ri > 26) break;
  }
  stdout.writeln('total rows: ${table.querySelectorAll('tr').length}');
}
