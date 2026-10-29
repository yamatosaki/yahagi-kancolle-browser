import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/quest/pinned_quests_summary.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/shared_preferences_quest_store.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';

void main() {
  final catalog = QuestCatalog(const [
    QuestCatalogEntry(
      gameId: 912,
      code: 'By3',
      name: '工作艦「明石」護衛任務',
      description: '',
    ),
  ]);

  test('server completion wins across conflicting local snapshots', () {
    for (final flag in [0, 1, 2]) {
      for (final current in [null, 0, 2, 5, 7]) {
        for (final verified in [null, false, true]) {
          final quest = _quest(
            flag: flag,
            current: current,
            verified: verified,
            state: 3,
          );
          final reason = 'flag=$flag local=$current/5 verified=$verified';
          expect(quest.displayProgressLabel, '100%', reason: reason);
          expect(
            catalog.project({quest.id: quest}).byGameId(quest.id).progressLabel,
            '100%',
            reason: reason,
          );
        }
      }
    }
  });

  test('verification alone cannot complete a partial local count', () {
    for (final flag in [1, 2]) {
      for (final current in [0, 2]) {
        for (final verified in [true, null]) {
          final quest = _quest(
            flag: flag,
            current: current,
            verified: verified,
          );
          expect(quest.isLocallyCompleted, isFalse);
          expect(quest.displayProgressLabel, '$current/5');
        }
      }
    }
  });

  test(
    'quest cache roundtrip preserves all smoke scenario priorities',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesQuestStore(memberId: 100);
      for (final scenario in _smokeScenarios) {
        await store.saveQuests({912: scenario.quest});
        final loaded = (await store.loadQuests())[912]!;

        expect(
          loaded.displayProgressLabel,
          scenario.label,
          reason: scenario.name,
        );
        expect(loaded.state, scenario.state, reason: scenario.name);
        expect(loaded.progressFlag, scenario.flag, reason: scenario.name);
        expect(loaded.progressCurrent, scenario.current, reason: scenario.name);
        expect(loaded.progressRequired, scenario.total, reason: scenario.name);
        expect(
          loaded.localCompletionVerified,
          scenario.verified,
          reason: scenario.name,
        );
      }
    },
  );

  for (final progress in [
    (flag: 0, current: 0, state: 2, verified: false, label: '0/5'),
    (flag: 1, current: 0, state: 2, verified: false, label: '0/5'),
    (flag: 2, current: 0, state: 2, verified: false, label: '0/5'),
    (flag: 2, current: 4, state: 2, verified: false, label: '4/5'),
    (flag: 2, current: 5, state: 2, verified: false, label: '5/5'),
    (flag: 2, current: 5, state: 2, verified: true, label: '5/5'),
    (flag: 2, current: 0, state: 3, verified: false, label: '100%'),
  ]) {
    test(
      'catalog progress prefers counts before server completion: $progress',
      () {
        final quest = _quest(
          flag: progress.flag,
          current: progress.current,
          state: progress.state,
          verified: progress.verified,
        );
        final item = catalog.project({quest.id: quest}).byGameId(quest.id);

        expect(item.progressLabel, progress.label);
        expect(quest.exactProgressLabel, '${progress.current}/5');
        expect(quest.isServerCompleted, progress.state == 3);
      },
    );
  }

  for (final flag in [1, 2]) {
    const label = '0/5';
    for (final mode in QuestCenterMode.values) {
      testWidgets('quest center uses $label above flag $flag in $mode', (
        tester,
      ) async {
        final controller = _controller(_quest(flag: flag));
        addTearDown(controller.dispose);
        await controller.initialize();
        await tester.pumpWidget(
          _app(
            QuestCenterPage(
              controller: controller,
              catalog: catalog,
              mode: mode,
              initialQuestId: 912,
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final key in ['quest-card-912', 'quest-detail-panel']) {
          expect(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
        expect(controller.state.quests[912]!.exactProgressLabel, '0/5');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('home quest summary uses local zero above server flag $flag', (
      tester,
    ) async {
      final controller = _controller(_quest(flag: flag));
      addTearDown(controller.dispose);
      await controller.initialize();
      await tester.pumpWidget(
        _app(
          PinnedQuestsSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenQuest: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget);
      expect(find.text(flag == 1 ? '50%+' : '80%+'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in _smokeScenarios) {
    test('progress smoke: ${scenario.name}', () {
      final quest = scenario.quest;
      final item = catalog.project({quest.id: quest}).byGameId(quest.id);

      expect(quest.displayProgressLabel, scenario.label);
      expect(item.progressLabel, scenario.label);
      expect(
        item.status,
        scenario.state == 3 ? QuestStatus.claimable : QuestStatus.inProgress,
      );
      expect(quest.progressCurrent, scenario.current);
      expect(quest.progressRequired, scenario.total);
      expect(quest.isLocallyCompleted, scenario.locallyCompleted);
    });

    for (final mode in QuestCenterMode.values) {
      testWidgets('${scenario.name}: list and detail in $mode', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1180, 720);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = _controller(scenario.quest);
        addTearDown(controller.dispose);
        await controller.initialize();
        await tester.pumpWidget(
          _app(
            QuestCenterPage(
              controller: controller,
              catalog: catalog,
              mode: mode,
              initialQuestId: 912,
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final key in ['quest-card-912', 'quest-detail-panel']) {
          expect(
            _progressText(tester, Key(key), scenario.label).style?.color,
            scenario.color,
          );
        }
        expect(
          find.descendant(
            of: find.byKey(const Key('quest-detail-status-912')),
            matching: find.text(scenario.state == 3 ? '待领取' : '进行中'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final style in PanelStyle.values) {
      testWidgets('${scenario.name}: home summary in $style', (tester) async {
        final controller = _controller(scenario.quest);
        addTearDown(controller.dispose);
        await controller.initialize();
        int? openedQuest;
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: SizedBox(
                width: 280,
                child: PanelStyleScope(
                  style: style,
                  child: PinnedQuestsSummary(
                    controller: controller,
                    collapsed: false,
                    onToggleCollapse: () {},
                    onOpenQuest: (id) => openedQuest = id,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final item = find.byKey(const Key('quest-summary-item-912'));
        expect(
          _progressText(
            tester,
            const Key('quest-summary-item-912'),
            scenario.summary,
          ).style?.color,
          scenario.color,
        );
        await tester.tap(item);
        expect(openedQuest, 912);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final themeMode in AppThemeMode.values) {
    final palette = AppPalette(themeMode);
    for (final style in PanelStyle.values) {
      for (final mode in QuestCenterMode.values) {
        testWidgets(
          'mounted progress updates all three views in $themeMode/$style/$mode',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(1180, 900);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final initial = _quest(flag: 2, current: 4, total: 10);
            final reducer = _QuestSnapshotReducer(initial);
            final controller = _controller(initial, reducer: reducer);
            addTearDown(controller.dispose);
            await controller.initialize();
            await tester.pumpWidget(
              _app(
                PanelStyleScope(
                  style: style,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 280,
                        child: PinnedQuestsSummary(
                          controller: controller,
                          collapsed: false,
                          onToggleCollapse: () {},
                          onOpenQuest: (_) {},
                        ),
                      ),
                      Expanded(
                        child: QuestCenterPage(
                          key: const Key('mounted-quest-page'),
                          controller: controller,
                          catalog: catalog,
                          mode: mode,
                          initialQuestId: 912,
                        ),
                      ),
                    ],
                  ),
                ),
                themeMode: themeMode,
              ),
            );
            await tester.pumpAndSettle();
            final mountedPage = tester.element(
              find.byKey(const Key('mounted-quest-page')),
            );

            for (final progress in [
              (
                current: 4,
                color: palette.isDark ? const Color(0xff8197a5) : palette.muted,
              ),
              (
                current: 5,
                color: palette.isDark ? const Color(0xffd4a85f) : palette.gold,
              ),
              (
                current: 8,
                color: palette.isDark ? const Color(0xff8ec6e8) : palette.info,
              ),
              (
                current: 10,
                color: palette.isDark
                    ? const Color(0xff67d6a3)
                    : palette.success,
              ),
            ]) {
              if (progress.current != 4) {
                reducer.nextQuest = _quest(
                  flag: 2,
                  current: progress.current,
                  total: 10,
                );
                controller.accept(
                  CapturedApiEvent(
                    path: '/quest-progress-display-test',
                    responseBody: '{"api_result":1}',
                    source: CaptureSource.manual,
                    capturedAt: DateTime.now().toUtc(),
                  ),
                );
                await controller.idle;
                await tester.pumpAndSettle();
              }

              final label = '${progress.current}/10';
              for (final key in ['quest-card-912', 'quest-detail-panel']) {
                expect(
                  _progressText(tester, Key(key), label).style?.color,
                  progress.color,
                  reason: '$key at $label',
                );
              }
              expect(
                _progressText(
                  tester,
                  const Key('quest-summary-item-912'),
                  progress.current == 10 ? '$label · 已达成（待确认）' : label,
                ).style?.color,
                progress.color,
                reason: 'summary at $label',
              );
              expect(
                tester.element(find.byKey(const Key('mounted-quest-page'))),
                same(mountedPage),
              );
              expect(controller.lastError, isNull);
              expect(controller.state.quests[912]!.state, 2);
              expect(controller.state.quests[912]!.isServerCompleted, isFalse);
              expect(controller.state.quests[912]!.isLocallyCompleted, isFalse);
              expect(
                find.descendant(
                  of: find.byKey(const Key('quest-detail-status-912')),
                  matching: find.text('进行中'),
                ),
                findsOneWidget,
              );
              expect(find.text('待领取'), findsNothing);
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }
}

const _smokeScenarios = [
  _ProgressScenario(
    'no local data and no server milestone',
    flag: 0,
    current: null,
    total: null,
    label: '＜50%',
    summary: '进行中',
    color: Color(0xff8197a5),
  ),
  _ProgressScenario(
    'server 50 with no local data',
    flag: 1,
    current: null,
    total: null,
    label: '50%+',
    summary: '50%+',
    color: Color(0xffd4a85f),
  ),
  _ProgressScenario(
    'server 80 with no local data',
    flag: 2,
    current: null,
    total: null,
    label: '80%+',
    summary: '80%+',
    color: Color(0xff8ec6e8),
  ),
  _ProgressScenario(
    'local zero without server milestone',
    flag: 0,
    label: '0/5',
    summary: '0/5',
    color: Color(0xff8197a5),
  ),
  _ProgressScenario(
    'local partial count without server milestone',
    flag: 0,
    current: 2,
    label: '2/5',
    summary: '2/5',
    color: Color(0xff8197a5),
  ),
  _ProgressScenario(
    'local zero overrides server 50',
    flag: 1,
    label: '0/5',
    summary: '0/5',
    color: Color(0xff8197a5),
  ),
  _ProgressScenario(
    'local zero overrides server 80',
    flag: 2,
    label: '0/5',
    summary: '0/5',
    color: Color(0xff8197a5),
  ),
  _ProgressScenario(
    'local 80 percent overrides server 50',
    flag: 1,
    current: 4,
    label: '4/5',
    summary: '4/5',
    color: Color(0xff8ec6e8),
  ),
  _ProgressScenario(
    'partial local count overrides server 80',
    flag: 2,
    current: 1,
    label: '1/5',
    summary: '1/5',
    color: Color(0xff8197a5),
  ),
  _ProgressScenario(
    'local count remains visible at equal server percentage',
    flag: 2,
    current: 4,
    label: '4/5',
    summary: '4/5',
    color: Color(0xff8ec6e8),
  ),
  _ProgressScenario(
    'verified local completion remains visible before server completion',
    flag: 2,
    current: 5,
    verified: true,
    locallyCompleted: true,
    label: '5/5',
    summary: '完成',
    color: Color(0xff67d6a3),
  ),
  _ProgressScenario(
    'legacy local completion preserves its existing meaning',
    flag: 2,
    current: 5,
    verified: null,
    locallyCompleted: true,
    label: '5/5',
    summary: '完成',
    color: Color(0xff67d6a3),
  ),
  _ProgressScenario(
    'unverified full count retains pending summary with server milestone',
    flag: 2,
    current: 5,
    label: '5/5',
    summary: '5/5 · 已达成（待确认）',
    color: Color(0xff67d6a3),
  ),
  _ProgressScenario(
    'unverified full count without server milestone stays pending',
    flag: 0,
    current: 5,
    label: '5/5',
    summary: '5/5 · 已达成（待确认）',
    color: Color(0xff67d6a3),
  ),
  _ProgressScenario(
    'server completion overrides local zero even with flag zero',
    state: 3,
    flag: 0,
    label: '100%',
    summary: '完成',
    color: Color(0xff67d6a3),
  ),
  _ProgressScenario(
    'server completion without local data is authoritative',
    state: 3,
    flag: 2,
    current: null,
    total: null,
    label: '100%',
    summary: '完成',
    color: Color(0xff67d6a3),
  ),
  _ProgressScenario(
    'server completion overrides locally verified full count',
    state: 3,
    flag: 2,
    current: 5,
    verified: true,
    locallyCompleted: true,
    label: '100%',
    summary: '完成',
    color: Color(0xff67d6a3),
  ),
];

class _ProgressScenario {
  const _ProgressScenario(
    this.name, {
    required this.flag,
    required this.label,
    required this.summary,
    required this.color,
    this.current = 0,
    this.total = 5,
    this.state = 2,
    this.verified = false,
    this.locallyCompleted = false,
  });

  final String name;
  final int flag;
  final int? current;
  final int? total;
  final int state;
  final bool? verified;
  final bool locallyCompleted;
  final String label;
  final String summary;
  final Color color;

  GameQuest get quest => _quest(
    flag: flag,
    current: current,
    total: total,
    state: state,
    verified: verified,
  );
}

GameQuest _quest({
  required int flag,
  int? current = 0,
  int? total = 5,
  int state = 2,
  bool? verified = false,
}) => GameQuest(
  id: 912,
  title: '工作艦「明石」護衛任務',
  detail: '',
  category: 2,
  type: 5,
  state: state,
  progressFlag: flag,
  progressCurrent: current,
  progressRequired: total,
  localCompletionVerified: verified,
);

GameStateController _controller(GameQuest quest, {GameStateReducer? reducer}) =>
    GameStateController(
      reducer: reducer,
      initialState: GameState(
        quests: {quest.id: quest},
        hasQuestData: true,
        activeQuestCount: 1,
      ),
    );

Text _progressText(WidgetTester tester, Key scope, String label) {
  final finder = find.descendant(
    of: find.byKey(scope),
    matching: find.text(label),
  );
  expect(finder, findsOneWidget);
  return tester.widget<Text>(finder);
}

class _QuestSnapshotReducer extends GameStateReducer {
  _QuestSnapshotReducer(this.nextQuest);

  GameQuest nextQuest;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) =>
      state.copyWith(quests: {nextQuest.id: nextQuest});
}

Widget _app(Widget body, {AppThemeMode themeMode = AppThemeMode.dark}) =>
    MaterialApp(
      theme: ThemeData(extensions: [AppPalette(themeMode)]),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: body),
    );
