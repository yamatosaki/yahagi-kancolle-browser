import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_feedback.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

import 'fixtures/kcsapi_fixtures.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/notice/game_info_notice_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';

void main() {
  setUp(() {
    GameStateController.disableTimerForTest = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GameStateController.disableTimerForTest = false);

  Future<void> completeQuest(GameStateController game) async {
    game.accept(
      kcsapiEvent(
        '/kcsapi/api_get_member/questlist',
        {
          'api_exec_count': 1,
          'api_count': 1,
          'api_page_count': 1,
          'api_list': [
            {
              'api_no': 9001,
              'api_title': '测试任务',
              'api_detail': '',
              'api_category': 1,
              'api_type': 4,
              'api_state': 3,
              'api_progress_flag': 0,
            },
          ],
        },
        requestParams: {'yahagi_full_quest_snapshot': 1},
      ),
    );
    await game.idle;
  }

  Future<void> pumpHarness(
    WidgetTester tester, {
    required GameStateController game,
    required LayoutSettingsController layout,
    required TopNoticeController notices,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: QuestCompletionDrawerHost(
          controller: notices,
          child: Column(
            children: [
              const SizedBox(
                height: 44,
                child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
              ),
              Expanded(
                child: QuestCompletionFeedback(
                  controller: game,
                  layoutSettingsController: layout,
                  builder: (_, count) => Text('count:$count'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  for (final succeeded in [false, true]) {
    testWidgets(
      'real improvement pipeline shows result and quest completion: $succeeded',
      (tester) async {
        final game = GameStateController(
          initialState: GameState.empty.copyWith(
            memberId: 100,
            quests: {
              619: GameQuest(
                id: 619,
                title: '装备的改修强化',
                detail: '',
                category: 6,
                type: 1,
                state: 2,
                progressFlag: 0,
                updatedAt: DateTime.now().toUtc(),
              ),
            },
          ),
          questProgress: await tester.runAsync(QuestProgressEngine.load),
        );
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        final notices = TopNoticeController();
        addTearDown(game.dispose);
        addTearDown(layout.dispose);
        addTearDown(notices.dispose);
        await game.initialize();
        await pumpHarness(tester, game: game, layout: layout, notices: notices);
        final info = GameInfoNoticeController(
          stateProvider: () => game.state,
          layoutSettingsController: layout,
          topNoticeController: notices,
        );
        final pipeline = GameApiEventPipeline(
          consumers: [game, info],
          settleGameState: () => game.idle,
        );
        pipeline.add(
          kcsapiEvent(
            '/kcsapi/api_req_kousyou/remodel_slot',
            {'api_remodel_flag': succeeded ? 1 : 0},
            capturedAt: DateTime.now().toUtc(),
          ),
        );
        await pipeline.idle;
        expect(game.lastError, isNull);
        expect(game.state.quests[619]?.isCompleted, isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('任务达成：装备的改修强化'), findsOneWidget);
        expect(find.text(succeeded ? '装备改修成功' : '装备改修失败'), findsOneWidget);
        expect(notices.notices, hasLength(2));
        await tester.pumpWidget(const SizedBox.shrink());
        notices.hide();
      },
    );
  }
  testWidgets('task completion obeys the top notice enabled setting', (
    tester,
  ) async {
    final game = GameStateController();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final notices = TopNoticeController();
    addTearDown(game.dispose);
    addTearDown(layout.dispose);
    addTearDown(notices.dispose);
    await game.initialize();
    await layout.setTopNoticeEnabled(false);
    await pumpHarness(tester, game: game, layout: layout, notices: notices);

    await completeQuest(game);
    await tester.pump();
    await tester.pump();

    expect(notices.notices, isEmpty);
    expect(find.text('count:1'), findsOneWidget);
  });

  testWidgets('task completion uses the configured display duration', (
    tester,
  ) async {
    final game = GameStateController();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final notices = TopNoticeController();
    addTearDown(game.dispose);
    addTearDown(layout.dispose);
    addTearDown(notices.dispose);
    await game.initialize();
    await layout.setTopNoticeDurationSeconds(10);
    await pumpHarness(tester, game: game, layout: layout, notices: notices);

    await completeQuest(game);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));

    expect(notices.current?.message, '任务达成：测试任务');
    await tester.pump(const Duration(seconds: 4));
    expect(notices.current, isNull);
  });

  testWidgets(
    'completion keeps its title across another state update before display',
    (tester) async {
      final game = GameStateController(
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: (callback) => callback(),
        ),
      );
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final notices = TopNoticeController();
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      addTearDown(notices.dispose);
      await game.initialize();
      await pumpHarness(tester, game: game, layout: layout, notices: notices);
      await completeQuest(game);
      await completeQuest(game);
      await tester.pump();
      expect(notices.current?.message, '任务达成：测试任务');
      await tester.pumpWidget(const SizedBox.shrink());
      notices.hide();
    },
  );

  testWidgets(
    'expedition screen entry pipeline shows top notice for unresupplied Fleets 2/3/4 and obeys duration',
    (tester) async {
      final game = GameStateController(
        initialState: GameState.empty.copyWith(
          memberId: 100,
          hasMasterData: true,
          masterShips: const {
            1: MasterShip(
              id: 1,
              name: '吹雪',
              shipTypeId: 2,
              maxFuel: 15,
              maxAmmo: 20,
            ),
          },
          ships: const {
            1: OwnedShip(
              id: 1,
              masterId: 1,
              level: 10,
              currentFuel: 0,
              currentAmmo: 0,
            ),
            2: OwnedShip(
              id: 2,
              masterId: 1,
              level: 10,
              currentFuel: 10,
              currentAmmo: 20,
            ),
            3: OwnedShip(
              id: 3,
              masterId: 1,
              level: 10,
              currentFuel: 15,
              currentAmmo: 20,
            ),
            4: OwnedShip(
              id: 4,
              masterId: 1,
              level: 10,
              currentFuel: 15,
              currentAmmo: 15,
            ),
          },
          fleets: const [
            Fleet(id: 1, name: '第1舰队', shipIds: [1]),
            Fleet(id: 2, name: '第2舰队', shipIds: [2]),
            Fleet(id: 3, name: '第3舰队', shipIds: [3]),
            Fleet(id: 4, name: '第4舰队', shipIds: [4]),
          ],
        ),
      );
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final notices = TopNoticeController();
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      addTearDown(notices.dispose);
      await game.initialize();
      await layout.setTopNoticeDurationSeconds(10);
      await pumpHarness(tester, game: game, layout: layout, notices: notices);

      final info = GameInfoNoticeController(
        stateProvider: () => game.state,
        layoutSettingsController: layout,
        topNoticeController: notices,
      );
      final pipeline = GameApiEventPipeline(
        consumers: [game, info],
        settleGameState: () => game.idle,
      );

      pipeline.add(
        kcsapiEvent('/kcsapi/api_get_member/mission', {
          'api_list_items': [
            {'api_mission_id': 1, 'api_state': 0},
          ],
          'api_limit_time': [0, 0, 0],
        }, capturedAt: DateTime.now().toUtc()),
      );
      await pipeline.idle;
      expect(game.lastError, isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('远征提醒：第 2、4 舰队尚未补给'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      expect(notices.current?.message, '远征提醒：第 2、4 舰队尚未补给');
      await tester.pump(const Duration(seconds: 4));
      expect(notices.current, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      notices.hide();
    },
  );
}
