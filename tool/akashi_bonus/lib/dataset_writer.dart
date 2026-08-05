/// Writes the canonical dataset JSON, reports and the run manifest.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

import 'models.dart';
import 'rule_builder.dart';

const String kSchemaVersion = '1';

/// Canonical sha256 of the sorted rules array, ignoring run-specific
/// provenance (fetchedAt, httpLastModified, contentSha256) so that repeated
/// generations of the same source content hash identically.
String rulesCanonicalHash(List<BonusRule> rules) {
  final sorted = List<BonusRule>.of(rules)
    ..sort((a, b) => a.ruleId.compareTo(b.ruleId));
  final json = jsonEncode(sorted.map(_canonicalRuleJson).toList());
  return 'sha256:${sha256.convert(utf8.encode(json))}';
}

Map<String, Object?> _canonicalRuleJson(BonusRule r) {
  final j = r.toJson();
  final src = (j['source'] as Map<String, Object?>).cast<String, Object?>();
  src.remove('fetchedAt');
  src.remove('httpLastModified');
  src.remove('contentSha256');
  return j;
}

class DatasetWriter {
  final String reportsDir;

  DatasetWriter(this.reportsDir);

  void writeJson(String name, Object data) {
    final dir = Directory(reportsDir);
    dir.createSync(recursive: true);
    File('$reportsDir\\$name').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
  }

  void writeDataset(
    String outPath,
    List<BonusRule> rules, {
    required String datasetVersion,
  }) {
    final sorted = List<BonusRule>.of(rules)
      ..sort((a, b) => a.ruleId.compareTo(b.ruleId));
    final json = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'datasetVersion': datasetVersion,
      'sourceName': 'akashi-list.me',
      'secondarySources': [
        'wikiwiki.jp/kancolle',
        'ElectronicObserverEN/Data',
      ],
      'rules': sorted.map((r) => r.toJson()).toList(),
    });
    File(outPath).writeAsStringSync('$json\n');
  }

  void writeManifest(Map<String, Object?> extra) {
    writeJson('run_manifest.json', {
      'generatedAt': DateTime.now().toIso8601String(),
      ...extra,
    });
  }
}

/// Renders unresolved entries as JSON.
Map<String, Object?> unresolvedReport(List<UnresolvedEntry> entries) =>
    <String, Object?>{
      'count': entries.length,
      'items': entries.map((e) => e.toJson()).toList(),
    };
