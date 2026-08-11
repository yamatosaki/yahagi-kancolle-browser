import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _hanCharacter = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF]');

class _StringLiteral {
  const _StringLiteral({required this.value, required this.line});

  final String value;
  final int line;
}

List<_StringLiteral> _dartStringLiterals(String source) {
  final literals = <_StringLiteral>[];
  var index = 0;
  var line = 1;

  while (index < source.length) {
    if (source.startsWith('//', index)) {
      final newline = source.indexOf('\n', index + 2);
      if (newline < 0) break;
      index = newline;
      continue;
    }
    if (source.startsWith('/*', index)) {
      final end = source.indexOf('*/', index + 2);
      final stop = end < 0 ? source.length : end + 2;
      line += '\n'.allMatches(source.substring(index, stop)).length;
      index = stop;
      continue;
    }

    final character = source[index];
    if (character != "'" && character != '"') {
      if (character == '\n') line++;
      index++;
      continue;
    }

    final quote = character;
    final startLine = line;
    final triple = source.startsWith(quote * 3, index);
    final delimiter = triple ? quote * 3 : quote;
    index += delimiter.length;
    final buffer = StringBuffer();

    while (index < source.length && !source.startsWith(delimiter, index)) {
      final current = source[index];
      if (current == '\\' && index + 1 < source.length) {
        buffer
          ..write(current)
          ..write(source[index + 1]);
        index += 2;
        continue;
      }
      if (current == '\n') line++;
      buffer.write(current);
      index++;
    }

    literals.add(_StringLiteral(value: buffer.toString(), line: startLine));
    if (index < source.length) index += delimiter.length;
  }

  return literals;
}

Set<String> _reviewedEntries(String path) => File(path)
    .readAsLinesSync()
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty && !line.startsWith('#'))
    .map((line) => jsonDecode(line) as String)
    .toSet();

void main() {
  test('UI source has no unreviewed hardcoded Han string literals', () {
    final files = <File>[
      File('lib/main.dart'),
      ...Directory('lib/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
    ]..sort((left, right) => left.path.compareTo(right.path));
    final allowlist = _reviewedEntries('tool/localization_ui_allowlist.txt');
    final migrationDebt = _reviewedEntries(
      'tool/localization_ui_migration_debt.txt',
    );
    final reviewedEntries = <String>{...allowlist, ...migrationDebt};
    final usedReviewedEntries = <String>{};
    final violations = <String>[];

    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      for (final literal in _dartStringLiterals(file.readAsStringSync())) {
        if (!_hanCharacter.hasMatch(literal.value)) continue;
        final entry = '$path|${literal.value}';
        if (reviewedEntries.contains(entry)) {
          usedReviewedEntries.add(entry);
          continue;
        }
        violations.add(
          '$path:${literal.line} | ${literal.value}\n'
          'DEBT ${jsonEncode(entry)}',
        );
      }
    }

    final staleEntries =
        reviewedEntries.difference(usedReviewedEntries).toList()..sort();
    expect(
      violations,
      isEmpty,
      reason:
          'Move app-owned UI text to AppLocalizations, or add only reviewed '
          'game data/internal diagnostics to the exact allowlist. Existing UI '
          'migration debt must be registered exactly and removed as it is '
          'localized:\n'
          '${violations.join('\n')}',
    );
    expect(
      staleEntries,
      isEmpty,
      reason:
          'Remove stale localization review entries:\n'
          '${staleEntries.map((entry) => 'STALE ${jsonEncode(entry)}').join('\n')}',
    );
  });
}
