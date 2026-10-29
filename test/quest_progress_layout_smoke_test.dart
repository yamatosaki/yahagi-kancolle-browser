// Synthetic quest states and public assets only. Screenshots are opt-in:
// set QUEST_PROGRESS_SMOKE_DIR before running this file to save PNG previews.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/quest/pinned_quests_summary.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';

const _boundary = Key('quest-progress-smoke-root');
final _outputDirectory = Platform.environment['QUEST_PROGRESS_SMOKE_DIR'];

const _scenes = [
  _Scene(AppThemeMode.dark, PanelStyle.card, Size(390, 844), 1.3),
  _Scene(AppThemeMode.dark, PanelStyle.flat, Size(280, 720), 1.5),
  _Scene(AppThemeMode.seaSalt, PanelStyle.flat, Size(390, 844), 1.3),
  _Scene(AppThemeMode.seaSalt, PanelStyle.card, Size(844, 390), 1.3),
  _Scene(AppThemeMode.skyBlue, PanelStyle.card, Size(280, 720), 1.5),
  _Scene(AppThemeMode.skyBlue, PanelStyle.flat, Size(844, 390), 1.5),
];

const _cases = [
  _Case(9001, '本地零计数', '0/10', '0/10', 0, current: 0, flag: 2),
  _Case(9002, '本地半数', '5/10', '5/10', 1, current: 5),
  _Case(9003, '本地八成', '8/10', '8/10', 2, current: 8, flag: 1),
  _Case(9004, '满数等待服务器确认', '10/10', '10/10 · 已达成（待确认）', 3, current: 10),
  _Case(9005, '服务器已完成', '100%', '完成', 3, current: 0, state: 3),
  _Case(9006, '无本地计数服务器五成', '50%+', '50%+', 1, flag: 1),
  _Case(9007, '无本地计数服务器八成', '80%+', '80%+', 2, flag: 2),
  _Case(9008, '仅有静态目录', '—', '', 0, live: false),
  _Case(9009, '前置关系推算完成', '100%', '', 3, live: false),
];

final _catalog = QuestCatalog([
  for (final scenario in _cases)
    QuestCatalogEntry(
      gameId: scenario.id,
      code: 'B${scenario.id}',
      name: scenario.title,
      description: '用于进度显示冒烟的合成任务。',
      prerequisites: scenario.id == 9001 ? const ['B9009'] : const [],
    ),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('QuestSmokeCjk', 'assets/fonts/NotoSansJP-wght.ttf');
    await _loadFont('HarmonyOS_Sans_SC', 'assets/fonts/HarmonyOS_Sans_SC.ttf');
    var directory = File(Platform.resolvedExecutable).parent;
    while (directory.parent.path != directory.path) {
      final font = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (font.existsSync()) {
        await _loadFont('MaterialIcons', font.path);
        break;
      }
      directory = directory.parent;
    }
    if (_outputDirectory != null) {
      await Directory(_outputDirectory!).create(recursive: true);
    }
  });

  for (final scene in _scenes) {
    testWidgets('mixed progress layout and navigation ${scene.name}', (
      tester,
    ) async {
      _setSize(tester, scene.size);
      final controller = GameStateController(
        initialState: GameState(
          quests: {
            for (final scenario in _cases)
              if (scenario.live) scenario.id: scenario.quest,
          },
          hasQuestData: true,
          hasCompleteQuestData: true,
          activeQuestCount: 7,
        ),
      );
      addTearDown(controller.dispose);
      await controller.initialize();

      int? openedQuest;
      await _pump(
        tester,
        scene,
        SingleChildScrollView(
          child: PinnedQuestsSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenQuest: (id) => openedQuest = id,
          ),
        ),
      );
      for (final scenario in _cases.where((scenario) => scenario.live)) {
        final item = find.byKey(Key('quest-summary-item-${scenario.id}'));
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        _expectProgress(tester, item, scenario.summary, scene, scenario.band);
        await tester.tap(item);
        expect(openedQuest, scenario.id);
        expect(tester.takeException(), isNull, reason: scene.name);
      }
      if (scene.theme == AppThemeMode.dark && scene.style == PanelStyle.card) {
        await _capture(tester, '${scene.name}-mixed-summary');
      }

      await _pump(
        tester,
        scene,
        QuestCenterPage(
          controller: controller,
          catalog: _catalog,
          mode: QuestCenterMode.all,
          initialQuestId: 9001,
        ),
      );
      final listPanel = find.byKey(const Key('quest-list-panel'));
      final detailPanel = find.byKey(const Key('quest-detail-panel'));
      final listRect = tester.getRect(listPanel);
      final detailRect = tester.getRect(detailPanel);
      if (scene.size.width > scene.size.height) {
        expect(detailRect.left, greaterThanOrEqualTo(listRect.right));
      } else {
        expect(detailRect.top, greaterThanOrEqualTo(listRect.bottom));
      }
      for (final scenario in _cases) {
        final card = find.byKey(Key('quest-card-${scenario.id}'));
        await tester.scrollUntilVisible(
          card,
          120,
          scrollable: find.descendant(
            of: listPanel,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        _expectProgress(tester, card, scenario.label, scene, scenario.band);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('quest-detail-title-${scenario.id}')),
          findsOneWidget,
        );
        if (scenario.label == '—') {
          expect(
            find.descendant(of: detailPanel, matching: find.text('100%')),
            findsNothing,
          );
        } else {
          _expectProgress(
            tester,
            detailPanel,
            scenario.label,
            scene,
            scenario.band,
          );
        }
        final status = scenario.id == 9008
            ? '状态未知'
            : scenario.id == 9009
            ? '推算完成'
            : scenario.state == 3
            ? '待领取'
            : '进行中';
        expect(
          find.descendant(
            of: find.byKey(Key('quest-detail-status-${scenario.id}')),
            matching: find.text(status),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '${scene.name} $status');
        if (scenario.id == 9003 && scene.size.width > scene.size.height) {
          await _capture(tester, '${scene.name}-mixed-list-detail');
        }
      }

      // Restore the real, public Fq3 ledger rule rather than passing fabricated
      // QuestStepProgress values to the detail view. Each theme exercises all
      // four boundaries using the same layout that passed the mixed-state run.
      if (scene == _scenes[0] || scene == _scenes[3] || scene == _scenes[5]) {
        await _expectRestoredObjectiveBands(tester, scene);
      }
    });
  }
}

Future<void> _expectRestoredObjectiveBands(
  WidgetTester tester,
  _Scene scene,
) async {
  final raw =
      jsonDecode(
            File('assets/data/quest-progress-goals.json').readAsStringSync(),
          )
          as Map;
  final goal = QuestProgressGoal(663, Map<String, dynamic>.from(raw['663']));
  expect(goal.steps.keys, ['destory_item']);
  expect(goal.steps.values.single['required'], 10);
  final catalog = QuestCatalog(const [
    QuestCatalogEntry(
      gameId: 663,
      code: 'Fq3',
      name: '新型艤装の継続研究',
      description: '公開の任務ルールから復元した進捗を表示。',
    ),
  ]);
  for (final (count, band) in const [(4, 0), (5, 1), (8, 2), (10, 3)]) {
    final now = DateTime.now().toUtc();
    final engine = QuestProgressEngine(
      goals: {663: goal},
      storage: _CachedProgressStorage(
        jsonEncode({
          'account': 100,
          'records': {
            '663': {
              'period': questPeriodKey(goal.type, 5, now),
              'type': 5,
              'ruleRevision': goal.revision,
              'counts': {'destory_item': count},
              'claimed': false,
              'blocked': false,
            },
          },
          'active': [
            {
              'id': 663,
              'title': '新型艤装の継続研究',
              'detail': '',
              'category': 6,
              'type': 5,
              'state': 2,
              'flag': 2,
              'updated': now.toIso8601String(),
            },
          ],
        }),
      ),
    );
    final controller = GameStateController(
      initialState: GameState.empty.copyWith(memberId: 100),
      questProgress: engine,
    );
    try {
      await controller.initialize();
      expect(engine.persistenceError, isNull);
      expect(engine.stepsFor(663).single.count, count);
      expect(engine.stepsFor(663).single.required, 10);
      final quest = controller.state.quests[663]!;
      expect(quest.progressCurrent, count);
      expect(quest.progressRequired, 10);
      expect(quest.isLocallyCompleted, isFalse);
      expect(quest.isServerCompleted, isFalse);
      await _pump(
        tester,
        scene,
        QuestCenterPage(
          key: ValueKey('restored-objective-$count'),
          controller: controller,
          catalog: catalog,
          initialQuestId: 663,
        ),
      );
      final label = '$count/10';
      final detail = find.byKey(const Key('quest-detail-panel'));
      final labels = find.descendant(of: detail, matching: find.text(label));
      // Header and the actual engine-backed objective must agree.
      expect(labels, findsNWidgets(2));
      for (final text in tester.widgetList<Text>(labels)) {
        expect(text.style?.color, _bandColor(scene.theme, band));
      }
      expect(find.text('廃棄'), findsOneWidget);
      await tester.ensureVisible(labels.last);
      await tester.pumpAndSettle();
      expect(labels.last.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '${scene.name} $label');
      if (count == 8) {
        await _capture(tester, '${scene.name}-restored-objective-8-of-10');
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  }
}

void _expectProgress(
  WidgetTester tester,
  Finder scope,
  String label,
  _Scene scene,
  int band,
) {
  final text = find.descendant(of: scope, matching: find.text(label));
  expect(text, findsOneWidget, reason: '${scene.name}: $label');
  expect(tester.widget<Text>(text).style?.color, _bandColor(scene.theme, band));
}

Color _bandColor(AppThemeMode theme, int band) {
  final palette = AppPalette(theme);
  return switch (band) {
    1 => palette.isDark ? const Color(0xffd4a85f) : palette.gold,
    2 => palette.isDark ? const Color(0xff8ec6e8) : palette.info,
    3 => palette.isDark ? const Color(0xff67d6a3) : palette.success,
    _ => palette.muted,
  };
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pump(WidgetTester tester, _Scene scene, Widget body) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: createAppTheme(
        mode: scene.theme,
        fontFamily: 'QuestSmokeCjk',
        fontFamilyFallback: const ['HarmonyOS_Sans_SC'],
      ),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => RepaintBoundary(
        key: _boundary,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scene.scale)),
          child: PanelStyleScope(style: scene.style, child: child!),
        ),
      ),
      home: Scaffold(body: body),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: scene.name);
}

Future<void> _loadFont(String family, String path) async {
  await (FontLoader(family)..addFont(
        Future.value(ByteData.sublistView(await File(path).readAsBytes())),
      ))
      .load();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_outputDirectory == null) return;
  expect(tester.takeException(), isNull, reason: name);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      await File('$_outputDirectory/$name.png').writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

class _CachedProgressStorage implements QuestProgressStorage {
  _CachedProgressStorage(this.value);
  String value;
  @override
  Future<String?> read(int account) async => account == 100 ? value : null;
  @override
  Future<void> write(int account, String next) async => value = next;
}

class _Scene {
  const _Scene(this.theme, this.style, this.size, this.scale);
  final AppThemeMode theme;
  final PanelStyle style;
  final Size size;
  final double scale;
  String get name =>
      '${theme.name}-${style.name}-${size.width.toInt()}x${size.height.toInt()}-${scale}x';
}

class _Case {
  const _Case(
    this.id,
    this.title,
    this.label,
    this.summary,
    this.band, {
    this.current,
    this.flag = 0,
    this.state = 2,
    this.live = true,
  });
  final int id;
  final String title;
  final String label;
  final String summary;
  final int band;
  final int? current;
  final int flag;
  final int state;
  final bool live;
  GameQuest get quest => GameQuest(
    id: id,
    title: title,
    detail: '用于进度显示冒烟的合成任务。',
    category: 2,
    type: 4,
    state: state,
    progressFlag: flag,
    progressCurrent: current,
    progressRequired: current == null ? null : 10,
    localCompletionVerified: false,
  );
}
