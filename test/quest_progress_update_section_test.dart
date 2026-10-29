import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_update_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/data_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/quest_progress_update_section.dart';

void main() {
  testWidgets('progress data displays its own version, source and check time', (
    tester,
  ) async {
    final controller = _controller(
      _Updater(Future.value(const QuestProgressUpToDate('2026/10/25/01'))),
      sourceHost: 'raw.githubusercontent.com',
      lastCheckedAt: DateTime.utc(2026, 10, 29, 1, 2, 3),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(QuestProgressUpdateSection(controller: controller)),
    );
    expect(find.text('任务进度资料'), findsOneWidget);
    expect(find.text('数据版本：2026-10-25'), findsOneWidget);
    expect(find.textContaining('来源：raw.githubusercontent.com'), findsOneWidget);
    expect(find.textContaining('上次检查：2026-10-29'), findsOneWidget);
    expect(find.byKey(const Key('quest-catalog-check-button')), findsNothing);
  });

  testWidgets('manual progress checks disable repeats and report up-to-date', (
    tester,
  ) async {
    final completer = Completer<QuestProgressUpdateResult>();
    final updater = _Updater(completer.future);
    final controller = _controller(updater);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(QuestProgressUpdateSection(controller: controller)),
    );
    expect(find.textContaining('Poi（内置）'), findsOneWidget);
    final button = find.byKey(const Key('quest-progress-check-update-button'));
    await tester.tap(button);
    await tester.pump();
    expect(updater.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在检查任务进度资料…'), findsOneWidget);
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    completer.complete(
      const QuestProgressUpToDate(
        '2026/10/25/01',
        sourceHost: 'cdn.jsdelivr.net',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('任务进度资料已经是最新版本'), findsOneWidget);
    expect(find.textContaining('2026/10/25/01'), findsOneWidget);
    expect(find.textContaining('来源：cdn.jsdelivr.net'), findsOneWidget);
  });

  testWidgets('a progress update reports old and new versions after applying', (
    tester,
  ) async {
    final updated = _dataset('2026/10/29/01');
    final controller = _controller(
      _Updater(Future.value(QuestProgressUpdated(updated))),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(QuestProgressUpdateSection(controller: controller)),
    );
    await tester.tap(
      find.byKey(const Key('quest-progress-check-update-button')),
    );
    await tester.pumpAndSettle();
    expect(controller.version, '2026/10/29/01');
    expect(
      find.textContaining('已从 2026/10/25/01 更新至 2026/10/29/01'),
      findsOneWidget,
    );
    expect(find.textContaining('已立即生效'), findsOneWidget);
  });

  for (final failure in QuestProgressUpdateFailure.values) {
    testWidgets('progress $failure errors keep the current version visible', (
      tester,
    ) async {
      final controller = _controller(
        _Updater(
          Future.value(
            QuestProgressUpdateFailed(failure, StateError('not for display')),
          ),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(QuestProgressUpdateSection(controller: controller)),
      );
      await tester.tap(
        find.byKey(const Key('quest-progress-check-update-button')),
      );
      await tester.pumpAndSettle();
      final expected = switch (failure) {
        QuestProgressUpdateFailure.network => '无法连接任务进度资料来源',
        QuestProgressUpdateFailure.validation => '任务进度资料未通过校验',
        QuestProgressUpdateFailure.storage => '无法保存任务进度资料',
      };
      expect(find.textContaining(expected), findsOneWidget);
      expect(find.textContaining('2026/10/25/01'), findsOneWidget);
      expect(find.textContaining('not for display'), findsNothing);
      expect(controller.version, '2026/10/25/01');
    });
  }

  final locales = {
    const Locale('zh'): '任务进度资料',
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'): '任務進度資料',
    const Locale('en'): 'Quest progress data',
    const Locale('ja'): '任務進捗データ',
    const Locale('ko'): '임무 진행 데이터',
  };
  for (final entry in locales.entries) {
    testWidgets('progress update fits a narrow screen in ${entry.key}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _controller(
        _Updater(Future.value(const QuestProgressUpToDate('2026/10/25/01'))),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          QuestProgressUpdateSection(controller: controller),
          locale: entry.key,
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const Key('quest-progress-check-update-button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('data settings opens the independent progress update action', (
    tester,
  ) async {
    final capture = await CaptureModeController.load(_CaptureStore());
    final browser = GameBrowserController();
    final gameCapture = GameCaptureController();
    final prototype = PrototypeStatusController();
    final gameState = GameStateController();
    final updater = _Updater(
      Future.value(const QuestProgressUpToDate('2026/10/25/01')),
    );
    final controller = _controller(updater);
    for (final disposable in [
      capture,
      browser,
      gameCapture,
      prototype,
      gameState,
      controller,
    ]) {
      addTearDown(disposable.dispose);
    }
    await tester.pumpWidget(
      _app(
        DataSettingsPage(
          captureModeController: capture,
          browserController: browser,
          gameCaptureController: gameCapture,
          prototypeStatusController: prototype,
          gameStateController: gameState,
          questProgressRulesController: controller,
        ),
      ),
    );
    expect(
      find.byKey(const Key('quest-progress-check-update-button')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('settings-data-update-quest-progress')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('quest-progress-check-update-button')),
    );
    await tester.pumpAndSettle();
    expect(updater.calls, 1);
    expect(find.textContaining('任务进度资料已经是最新版本'), findsOneWidget);
  });
}

QuestProgressDataset _dataset(String version) =>
    QuestProgressDataset.parsePayload(
      jsonEncode({
        'meta': {'name': 'questgoal', 'version': version},
        'data': {
          '301': {
            'practice_win_a': {'description': 'A', 'required': 3, 'init': 0},
          },
        },
      }),
    );

QuestProgressRulesController _controller(
  _Updater updater, {
  String sourceHost = '',
  DateTime? lastCheckedAt,
}) => QuestProgressRulesController(
  dataset: _dataset('2026/10/25/01'),
  updater: updater,
  sourceHost: sourceHost,
  lastCheckedAt: lastCheckedAt,
);

Widget _app(Widget child, {Locale locale = const Locale('zh')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

final class _Updater implements QuestProgressUpdateClient {
  _Updater(this.result);
  final Future<QuestProgressUpdateResult> result;
  int calls = 0;
  @override
  Future<QuestProgressUpdateResult> checkAndUpdate({
    required QuestProgressDataset current,
  }) {
    calls++;
    return result;
  }
}

final class _CaptureStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => null;
  @override
  Future<void> write(CaptureMode mode) async {}
}
