import 'dart:io';
import 'package:html/parser.dart' as html_parser;

void main() {
  final src = File(r'G:\kancolle project\yahagi-kancolle-browser\tool\akashi_bonus\cache\raw\detail_368.html').readAsStringSync();
  final doc = html_parser.parse(src);
  final bc = doc.querySelector('.bonus-contents');
  if (bc == null) { stdout.writeln('no bonus-contents'); return; }
  var i = 0;
  for (final f in bc.querySelectorAll('td.fit')) {
    stdout.writeln('--- fit ${i++} ---');
    for (final sm in f.children) {
      final cls = sm.className;
      final sunits = sm.querySelectorAll('sunit').map((s) => s.text ?? '').toList();
      final targets = sm.querySelectorAll('span.sm').map((s) => s.text ?? '').toList();
      if (sunits.isEmpty && targets.isEmpty) continue;
      if (sunits.isNotEmpty) stdout.writeln('   <span class="$cls"> $sunits');
      if (targets.isNotEmpty) stdout.writeln('   TARGET: $targets');
    }
  }
}
