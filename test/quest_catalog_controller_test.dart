import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_update_service.dart';

void main() {
  QuestCatalogDataset dataset(String name, int day) {
    final raw = jsonEncode(<String, Object?>{
      '1': <String, Object?>{'code': 'A1', 'name': name, 'desc': ''},
    });
    return QuestCatalogDataset.parse(
      rawJson: raw,
      version: QuestCatalogVersion(
        committedAt: DateTime.utc(2026, 8, day),
        commitSha: day.toRadixString(16).padLeft(40, '0'),
        sha256: sha256.convert(utf8.encode(raw)).toString(),
      ),
      minimumQuestCount: 1,
    );
  }

  test('deduplicates checks and swaps catalog after update', () async {
    final old = dataset('old', 1);
    final newer = dataset('new', 2);
    final completer = Completer<QuestCatalogUpdateResult>();
    final controller = QuestCatalogController(
      dataset: old,
      updater: _Updater(completer.future),
    );

    final first = controller.checkForUpdates();
    final second = controller.checkForUpdates();
    expect(identical(first, second), isTrue);
    expect(controller.isChecking, isTrue);
    completer.complete(QuestCatalogUpdated(newer));
    await first;

    expect(controller.catalog.byGameId(1)?.name, 'new');
    expect(controller.isChecking, isFalse);
    controller.dispose();
  });
}

final class _Updater implements QuestCatalogUpdateClient {
  _Updater(this.result);
  final Future<QuestCatalogUpdateResult> result;

  @override
  Future<QuestCatalogUpdateResult> checkAndUpdate({
    required QuestCatalogDataset current,
  }) => result;
}
