import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset_store.dart';

void main() {
  QuestProgressDataset data(
    String version,
    Map<String, int> rules, {
    String commit = 'a',
  }) => QuestProgressDataset.parsePayload(
    jsonEncode({
      'meta': {'name': 'questgoal', 'version': version},
      'data': {
        for (final entry in rules.entries)
          entry.key: {
            'type': 1,
            'battle': {'description': 'battle', 'required': entry.value},
          },
      },
    }),
    sourceCommit: commit * 40,
  );

  test(
    'app upgrade retains previously omitted online rules at bundle version',
    () async {
      final original = data('2026/10/01/01', {'201': 1});
      final added = data('2026/10/02/01', {
        '201': 2,
        '9999': 7,
      }).overlayOn(original);
      final omitted = data('2026/10/03/01', {'201': 3}).overlayOn(added);
      final storage = _MemoryStorage();
      final store = QuestProgressDatasetStore(storage);
      await store.save(omitted);

      // The newer app bundles the same upstream revision with a local correction.
      final upgradedBundle = data('2026/10/03/01', {'201': 4}, commit: 'b');
      final restored = await store.loadBestAvailable(upgradedBundle);

      expect(restored.version, upgradedBundle.version);
      expect(restored.sourceCommit, upgradedBundle.sourceCommit);
      expect(restored.rawJson, upgradedBundle.rawJson);
      expect(restored.sha256, upgradedBundle.sha256);
      expect(restored.goals[201]!.raw['battle']['required'], 4);
      expect(restored.goals[9999]?.raw['battle']['required'], 7);
    },
  );

  test(
    'newer bundled data keeps cached missing IDs without downgrading rules',
    () async {
      final storage = _MemoryStorage();
      final store = QuestProgressDatasetStore(storage);
      await store.save(data('2026/10/02/01', {'201': 2, '9999': 7}));
      final newerBundle = data('2026/10/04/01', {
        '201': 4,
        '210': 10,
      }, commit: 'b');
      final restored = await store.loadBestAvailable(newerBundle);

      expect(restored.version, newerBundle.version);
      expect(restored.sourceCommit, newerBundle.sourceCommit);
      expect(restored.rawJson, newerBundle.rawJson);
      expect(restored.sha256, newerBundle.sha256);
      expect(restored.goals[201]!.raw['battle']['required'], 4);
      expect(restored.goals[210]!.raw['battle']['required'], 10);
      expect(restored.goals[9999]?.raw['battle']['required'], 7);
    },
  );
}

class _MemoryStorage implements QuestProgressDatasetStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String raw) async => value = raw;
}
