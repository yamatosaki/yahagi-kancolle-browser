import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';

void main() {
  String catalogJson(int count) => jsonEncode(<String, Object?>{
    for (var i = 1; i <= count; i++)
      '$i': <String, Object?>{
        'code': 'A$i',
        'name': '任务 $i',
        'desc': '说明 $i',
        if (i > 1) 'pre': <String>['A${i - 1}'],
      },
  });

  QuestCatalogVersion versionFor(String raw, {int day = 1}) =>
      QuestCatalogVersion(
        committedAt: DateTime.utc(2026, 8, day),
        commitSha: 'a' * 40,
        sha256: sha256.convert(utf8.encode(raw)).toString(),
      );

  test('parses a valid catalog and compares versions by commit time', () {
    final raw = catalogJson(3);
    final dataset = QuestCatalogDataset.parse(
      rawJson: raw,
      version: versionFor(raw),
      minimumQuestCount: 3,
    );
    final latest = QuestCatalogVersion(
      committedAt: DateTime.utc(2026, 8, 9),
      commitSha: 'b' * 40,
      sha256: 'c' * 64,
    );

    expect(latest.compareTo(dataset.version), greaterThan(0));
    expect(dataset.catalog.entries.length, 3);
  });

  test('rejects duplicate quest codes', () {
    final raw = jsonEncode(<String, Object?>{
      '1': <String, Object?>{'code': 'A1', 'name': 'one', 'desc': ''},
      '2': <String, Object?>{'code': 'A1', 'name': 'two', 'desc': ''},
    });
    expect(
      () => QuestCatalogDataset.parse(
        rawJson: raw,
        version: versionFor(raw),
        minimumQuestCount: 2,
      ),
      throwsFormatException,
    );
  });

  test('rejects self references and content hash mismatches', () {
    final raw = jsonEncode(<String, Object?>{
      '1': <String, Object?>{
        'code': 'A1',
        'name': 'one',
        'desc': '',
        'pre': <String>['A1'],
      },
    });
    expect(
      () => QuestCatalogDataset.parse(
        rawJson: raw,
        version: versionFor(raw),
        minimumQuestCount: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => QuestCatalogDataset.parse(
        rawJson: catalogJson(1),
        version: QuestCatalogVersion(
          committedAt: DateTime.utc(2026),
          commitSha: 'a' * 40,
          sha256: '0' * 64,
        ),
        minimumQuestCount: 1,
      ),
      throwsFormatException,
    );
  });

  test('persists display and relation source revisions', () {
    final version = QuestCatalogVersion(
      committedAt: DateTime.utc(2026, 8, 10),
      commitSha: 'a' * 40,
      relationCommitSha: 'b' * 40,
      sha256: 'c' * 64,
    );

    final restored = QuestCatalogVersion.fromJson(version.toJson());

    expect(restored.displayCommitSha, 'a' * 40);
    expect(restored.relationCommitSha, 'b' * 40);
    expect(restored.shortLabel, contains('aaaaaaa/bbbbbbb'));
  });

  test('reads legacy metadata as a single shared revision', () {
    final restored = QuestCatalogVersion.fromJson(
      jsonEncode(<String, Object?>{
        'committedAt': '2026-08-10T00:00:00Z',
        'commitSha': 'a' * 40,
        'sha256': 'b' * 64,
      }),
    );

    expect(restored.displayCommitSha, 'a' * 40);
    expect(restored.relationCommitSha, 'a' * 40);
  });
}
