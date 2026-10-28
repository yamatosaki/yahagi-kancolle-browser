import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/quest/pinned_quests_summary.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/shared_preferences_quest_store.dart';

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
          expect(quest.displayProgressLabel, flag == 1 ? '50%+' : '80%+');
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
    (flag: 1, current: 0, state: 2, verified: false, label: '50%+'),
    (flag: 2, current: 0, state: 2, verified: false, label: '80%+'),
    (flag: 2, current: 4, state: 2, verified: false, label: '80%+'),
    (flag: 2, current: 5, state: 2, verified: true, label: '5/5'),
    (flag: 2, current: 0, state: 3, verified: false, label: '100%'),
  ]) {
    test('catalog progress prefers server milestones: $progress', () {
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
    });
  }

  for (final flag in [1, 2]) {
    final label = flag == 1 ? '50%+' : '80%+';
    for (final mode in QuestCenterMode.values) {
      testWidgets('quest center uses $label in $mode', (tester) async {
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

    testWidgets('home quest summary uses $label above local zero', (
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
      expect(find.text('0/5'), findsNothing);
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
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.text(scenario.label),
            ),
            findsOneWidget,
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
          find.descendant(of: item, matching: find.text(scenario.summary)),
          findsOneWidget,
        );
        await tester.tap(item);
        expect(openedQuest, 912);
        expect(tester.takeException(), isNull);
      });
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
  ),
  _ProgressScenario(
    'server 50 with no local data',
    flag: 1,
    current: null,
    total: null,
    label: '50%+',
    summary: '50%+',
  ),
  _ProgressScenario(
    'server 80 with no local data',
    flag: 2,
    current: null,
    total: null,
    label: '80%+',
    summary: '80%+',
  ),
  _ProgressScenario(
    'local partial count without server milestone',
    flag: 0,
    current: 2,
    label: '2/5',
    summary: '2/5',
  ),
  _ProgressScenario(
    'server 50 overrides local zero',
    flag: 1,
    label: '50%+',
    summary: '50%+',
  ),
  _ProgressScenario(
    'server 80 overrides local zero',
    flag: 2,
    label: '80%+',
    summary: '80%+',
  ),
  _ProgressScenario(
    'server milestone takes priority even above local 50 percent',
    flag: 1,
    current: 4,
    label: '50%+',
    summary: '50%+',
  ),
  _ProgressScenario(
    'server 80 overrides incomplete observations',
    flag: 2,
    current: 1,
    label: '80%+',
    summary: '80%+',
  ),
  _ProgressScenario(
    'server 80 also takes priority at equal local percentage',
    flag: 2,
    current: 4,
    label: '80%+',
    summary: '80%+',
  ),
  _ProgressScenario(
    'verified local completion remains visible before server completion',
    flag: 2,
    current: 5,
    verified: true,
    locallyCompleted: true,
    label: '5/5',
    summary: '完成',
  ),
  _ProgressScenario(
    'legacy local completion preserves its existing meaning',
    flag: 2,
    current: 5,
    verified: null,
    locallyCompleted: true,
    label: '5/5',
    summary: '完成',
  ),
  _ProgressScenario(
    'unverified full count retains pending summary with server milestone',
    flag: 2,
    current: 5,
    label: '80%+',
    summary: '5/5 · 已达成（待确认）',
  ),
  _ProgressScenario(
    'unverified full count without server milestone stays pending',
    flag: 0,
    current: 5,
    label: '5/5',
    summary: '5/5 · 已达成（待确认）',
  ),
  _ProgressScenario(
    'server completion overrides local zero even with flag zero',
    state: 3,
    flag: 0,
    label: '100%',
    summary: '完成',
  ),
  _ProgressScenario(
    'server completion without local data is authoritative',
    state: 3,
    flag: 2,
    current: null,
    total: null,
    label: '100%',
    summary: '完成',
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
  ),
];

class _ProgressScenario {
  const _ProgressScenario(
    this.name, {
    required this.flag,
    required this.label,
    required this.summary,
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

GameStateController _controller(GameQuest quest) => GameStateController(
  initialState: GameState(
    quests: {quest.id: quest},
    hasQuestData: true,
    activeQuestCount: 1,
  ),
);

Widget _app(Widget body) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: body),
);
