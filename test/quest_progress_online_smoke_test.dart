import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real Poi download validates, overlays, persists and reloads all rules',
    () => HttpOverrides.runZoned(() async {
      final bundled = await QuestProgressDataset.loadBundled();
      final baseline = QuestProgressDataset.parsePayload(
        jsonEncode({
          'meta': {'name': 'questgoal', 'version': '2020/01/01/01'},
          'data': {'403': bundled.goals[403]!.raw},
        }),
      );
      final storage = _MemoryStorage();
      final store = QuestProgressDatasetStore(storage);
      final client = http.Client();
      addTearDown(client.close);
      final updater = QuestProgressUpdateService(client: client, store: store);

      final result = await updater.checkAndUpdate(current: baseline);
      expect(
        result,
        isA<QuestProgressUpdated>(),
        reason: result is QuestProgressUpdateFailed
            ? '${result.kind}: ${result.error}'
            : '$result',
      );
      final updated = (result as QuestProgressUpdated).dataset;
      expect(
        updated.version.compareTo(bundled.version),
        greaterThanOrEqualTo(0),
      );
      expect(updated.goals.length, greaterThanOrEqualTo(432));
      expect(updated.sourceCommit, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(
        result.sourceHost,
        anyOf('raw.githubusercontent.com', 'cdn.jsdelivr.net'),
      );
      final restored = await store.loadBestAvailable(baseline);
      expect(restored.version, updated.version);
      expect(restored.sourceCommit, updated.sourceCommit);
      expect(restored.goals.keys, unorderedEquals(updated.goals.keys));
      for (final id in updated.goals.keys) {
        expect(restored.goals[id]!.raw, updated.goals[id]!.raw, reason: '$id');
      }
    }, createHttpClient: _LiveHttpOverrides().createHttpClient),
    skip: Platform.environment['YAHAGI_RUN_POI_ONLINE_SMOKE'] != '1'
        ? 'Opt-in public network smoke test'
        : false,
    timeout: const Timeout(Duration(seconds: 50)),
  );
}

class _MemoryStorage implements QuestProgressDatasetStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String raw) async => value = raw;
}

class _LiveHttpOverrides extends HttpOverrides {}
