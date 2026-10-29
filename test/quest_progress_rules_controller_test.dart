import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_update_service.dart';

void main() {
  QuestProgressDataset dataset(int day) => QuestProgressDataset.parsePayload(
    jsonEncode({
      'meta': {
        'name': 'questgoal',
        'version': '2026/10/${day.toString().padLeft(2, '0')}/01',
      },
      'data': {
        '201': {
          'type': 1,
          'battle': {'description': 'battle', 'required': day},
        },
      },
    }),
  );

  test(
    'deduplicates checks and publishes only after application succeeds',
    () async {
      final pending = Completer<QuestProgressUpdateResult>();
      final adoption = Completer<void>();
      final updater = _Updater(() => pending.future);
      final old = dataset(1);
      final newer = dataset(2);
      final controller = QuestProgressRulesController(
        dataset: old,
        updater: updater,
        now: () => DateTime.utc(2026, 10, 29),
        onUpdated: (value) {
          expect(value.version, newer.version);
          return adoption.future;
        },
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      final first = controller.checkForUpdates();
      final second = controller.checkForUpdates();
      expect(first, same(second));
      expect(controller.isChecking, isTrue);
      pending.complete(
        QuestProgressUpdated(newer, sourceHost: 'raw.githubusercontent.com'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.dataset, same(old));
      expect(controller.isChecking, isTrue);
      adoption.complete();
      await first;

      expect(updater.calls, 1);
      expect(controller.version, newer.version);
      expect(controller.sourceHost, 'raw.githubusercontent.com');
      expect(controller.lastCheckedAt, DateTime.utc(2026, 10, 29));
      expect(controller.lastResult, isA<QuestProgressUpdated>());
      expect(controller.isChecking, isFalse);
      expect(notifications, 2);
      controller.dispose();
    },
  );

  test(
    'failed application keeps the old dataset and allows another check',
    () async {
      final old = dataset(1);
      final controller = QuestProgressRulesController(
        dataset: old,
        updater: _Updater(() async => QuestProgressUpdated(dataset(2))),
        onUpdated: (_) async => throw StateError('storage failed'),
      );
      final result = await controller.checkForUpdates();
      expect(
        (result as QuestProgressUpdateFailed).kind,
        QuestProgressUpdateFailure.storage,
      );
      expect(controller.dataset, same(old));
      expect(controller.isChecking, isFalse);
      expect(
        await controller.checkForUpdates(),
        isA<QuestProgressUpdateFailed>(),
      );
      controller.dispose();
    },
  );

  test(
    'network failures and exceptions preserve active data and source',
    () async {
      final old = dataset(1);
      final controller = QuestProgressRulesController(
        dataset: old,
        updater: _Updater(() => throw StateError('offline')),
        sourceHost: 'cdn.jsdelivr.net',
      );
      expect(
        await controller.checkForUpdates(),
        isA<QuestProgressUpdateFailed>(),
      );
      expect(controller.dataset, same(old));
      expect(controller.sourceHost, 'cdn.jsdelivr.net');
      expect(controller.lastCheckedAt, isNotNull);
      expect(controller.isChecking, isFalse);
      controller.dispose();
    },
  );

  test(
    'dispose during download prevents notification and application',
    () async {
      final result = Completer<QuestProgressUpdateResult>();
      var applied = false;
      final controller = QuestProgressRulesController(
        dataset: dataset(1),
        updater: _Updater(() => result.future),
        onUpdated: (_) async {
          applied = true;
        },
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      final check = controller.checkForUpdates();
      controller.dispose();
      result.complete(QuestProgressUpdated(dataset(2)));
      await check;
      expect(notifications, 1);
      expect(applied, isFalse);
    },
  );

  test('same version result never invokes rule application', () async {
    var applied = false;
    final old = dataset(1);
    final controller = QuestProgressRulesController(
      dataset: old,
      updater: _Updater(() async => QuestProgressUpToDate(old.version)),
      onUpdated: (_) async {
        applied = true;
      },
    );
    expect(await controller.checkForUpdates(), isA<QuestProgressUpToDate>());
    expect(controller.dataset, same(old));
    expect(applied, isFalse);
    controller.dispose();
  });
}

final class _Updater implements QuestProgressUpdateClient {
  _Updater(this.handler);
  final Future<QuestProgressUpdateResult> Function() handler;
  int calls = 0;
  @override
  Future<QuestProgressUpdateResult> checkAndUpdate({
    required QuestProgressDataset current,
  }) {
    calls++;
    return handler();
  }
}
