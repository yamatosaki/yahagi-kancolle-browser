import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  QuestProgressDataset dataset(String version, Map<String, Object?> goals) =>
      QuestProgressDataset.parsePayload(
        jsonEncode({
          'meta': {'name': 'questgoal', 'version': version},
          'data': goals,
        }),
        sourceCommit: 'a' * 40,
      );
  Map<String, Object?> goal(int required) => {
    'type': 1,
    'battle': {'description': 'battle', 'required': required},
  };
  late QuestProgressDataset bundled;
  setUp(() {
    bundled = dataset('2026/10/01/01', {'201': goal(1), '210': goal(10)});
  });

  test('loads a verified newer cache with bundled missing IDs', () async {
    final storage = _Storage();
    final store = QuestProgressDatasetStore(storage);
    await store.save(dataset('2026/10/02/01', {'201': goal(2)}));

    final loaded = await store.loadBestAvailable(bundled);

    expect(loaded.version, '2026/10/02/01');
    expect(loaded.goals[201]!.raw['battle']['required'], 2);
    expect(loaded.goals, contains(210));
  });

  test(
    'persists effective fallback IDs without an unbounded history',
    () async {
      final storage = _Storage();
      final store = QuestProgressDatasetStore(storage);
      final versionA = dataset('2026/10/02/01', {
        '201': goal(2),
        '9999': goal(7),
      }).overlayOn(bundled);
      await store.save(versionA);
      final versionB = dataset('2026/10/03/01', {
        '201': goal(3),
      }).overlayOn(versionA);
      await store.save(versionB);

      final restarted = await QuestProgressDatasetStore(
        storage,
      ).loadBestAvailable(bundled);

      expect(restarted.version, versionB.version);
      expect(restarted.goals[9999]!.raw['battle']['required'], 7);
      expect(restarted.goals, contains(210));
      expect(
        (jsonDecode(storage.value!) as Map).containsKey('fallbacks'),
        isFalse,
      );
    },
  );

  test('same or older cached versions use bundled data', () async {
    for (final version in ['2026/09/30/01', '2026/10/01/01']) {
      final storage = _Storage();
      final store = QuestProgressDatasetStore(storage);
      await store.save(dataset(version, {'201': goal(99)}));
      expect(await store.loadBestAvailable(bundled), same(bundled));
    }
  });

  test('invalid cache data and failed reads use bundled data', () async {
    for (final value in [null, '', '{}', '[1]', '{broken']) {
      final store = QuestProgressDatasetStore(_Storage(value));
      expect(await store.loadBestAvailable(bundled), same(bundled));
    }
    final storage = _Storage()..failRead = true;
    expect(
      await QuestProgressDatasetStore(storage).loadBestAvailable(bundled),
      same(bundled),
    );
  });

  test(
    'hash mismatch and invalid commit reject an otherwise valid cache',
    () async {
      final storage = _Storage();
      final store = QuestProgressDatasetStore(storage);
      await store.save(dataset('2026/10/02/01', {'201': goal(2)}));
      final envelope = jsonDecode(storage.value!) as Map<String, dynamic>;
      envelope['sha256'] = '0' * 64;
      storage.value = jsonEncode(envelope);
      expect(await store.loadBestAvailable(bundled), same(bundled));
      envelope['sha256'] = sha256
          .convert(utf8.encode(envelope['rawJson'] as String))
          .toString();
      envelope['sourceCommit'] = '../master';
      storage.value = jsonEncode(envelope);
      expect(await store.loadBestAvailable(bundled), same(bundled));
    },
  );

  test('write failures propagate while keeping the previous cache', () async {
    final storage = _Storage();
    final store = QuestProgressDatasetStore(storage);
    await store.save(dataset('2026/10/02/01', {'201': goal(2)}));
    final previous = storage.value;
    storage.failWrite = true;

    await expectLater(
      store.save(dataset('2026/10/03/01', {'201': goal(3)})),
      throwsStateError,
    );
    expect(storage.value, previous);
  });

  test('preferences store uses one shared public rule cache key', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesQuestProgressDatasetStorage();
    await storage.write('rules');
    expect(await PreferencesQuestProgressDatasetStorage().read(), 'rules');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), {
      PreferencesQuestProgressDatasetStorage.cacheKey,
    });
  });
}

final class _Storage implements QuestProgressDatasetStorage {
  _Storage([this.value]);
  String? value;
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> write(String raw) async {
    if (failWrite) throw StateError('write failed');
    value = raw;
  }
}
