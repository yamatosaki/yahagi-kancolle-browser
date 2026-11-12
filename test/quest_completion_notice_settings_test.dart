import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_feedback.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/top_notice_kind.dart';
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

  testWidgets('task completion switch suppresses only the notice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'top_notice_kind_questCompletion': false,
    });
    final game = GameStateController();
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
    await tester.pump();
    await tester.pump();

    expect(layout.topNoticeEnabled, isTrue);
    expect(find.text('count:1'), findsOneWidget);
    expect(notices.notices, isEmpty);
  });

  testWidgets(
    'a rejected pending prediction can still notify after re-enable',
    (tester) async {
      GameState questState(int state, int progress) => GameState(
        memberId: 100,
        quests: {
          503: GameQuest(
            id: 503,
            title: '入渠任务',
            detail: '',
            category: 5,
            type: 1,
            state: state,
            progressFlag: 0,
            progressCurrent: progress,
            progressRequired: 1,
          ),
        },
      );
      final accepted = questState(2, 0);
      final game = GameStateController(
        initialState: accepted,
        reducer: _QuestSnapshotReducer([
          questState(2, 1),
          accepted,
          questState(3, 1),
        ]),
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

      Future<void> nextSnapshot() async {
        game.accept(kcsapiEvent('/kcsapi/api_get_member/questlist', const {}));
        await game.idle;
      }

      await nextSnapshot();
      expect(game.state.quests[503]?.isLocallyCompleted, isTrue);
      await layout.setTopNoticeKindEnabled(
        TopNoticeKind.questCompletion,
        false,
      );
      await nextSnapshot();
      expect(game.state.quests[503]?.isCompleted, isFalse);
      await tester.pump();
      expect(notices.notices, isEmpty);

      await layout.setTopNoticeKindEnabled(TopNoticeKind.questCompletion, true);
      await nextSnapshot();
      await tester.pump();
      expect(notices.current?.message, '任务达成：入渠任务');
      notices.hide();
    },
  );

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
    'sortie screen entry renders default notices and rechecks after resupply',
    (tester) async {
      final store = SharedPreferencesLayoutSettingsStore();
      final saved = await LayoutSettingsController.load(store);
      await saved.setTopNoticeDurationSeconds(10);
      saved.dispose();

      OwnedShip ship(int id, {required int hp, required int fuel}) => OwnedShip(
        id: id,
        masterId: 1,
        level: 10,
        currentHp: hp,
        maxHp: 32,
        currentFuel: fuel,
        currentAmmo: 20,
      );
      final game = GameStateController(
        initialState: GameState.empty.copyWith(
          memberId: 100,
          hasMasterData: true,
          maxShipCount: 8,
          masterShips: const {
            1: MasterShip(
              id: 1,
              name: '吹雪',
              shipTypeId: 2,
              maxFuel: 15,
              maxAmmo: 20,
            ),
          },
          ships: {
            1: ship(1, hp: 8, fuel: 15),
            2: ship(2, hp: 1, fuel: 14),
            3: ship(3, hp: 1, fuel: 14),
            4: ship(4, hp: 9, fuel: 14),
            5: ship(5, hp: 32, fuel: 15),
          },
          fleets: const [
            Fleet(id: 1, name: '第1舰队', shipIds: [1]),
            Fleet(id: 2, name: '第2舰队', shipIds: [2, 5]),
            Fleet(
              id: 3,
              name: '第3舰队',
              shipIds: [3],
              mission: FleetMission(state: 1),
            ),
            Fleet(id: 4, name: '第4舰队', shipIds: [4]),
          ],
          repairDocks: const [RepairDock(id: 1, state: 1, shipId: 5)],
        ),
      );
      final layout = await LayoutSettingsController.load(store);
      final notices = TopNoticeController();
      final info = GameInfoNoticeController(
        stateProvider: () => game.state,
        layoutSettingsController: layout,
        topNoticeController: notices,
      );
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      addTearDown(notices.dispose);
      addTearDown(info.dispose);
      await game.initialize();
      await pumpHarness(tester, game: game, layout: layout, notices: notices);

      final pipeline = GameApiEventPipeline(
        consumers: [game, info],
        settleGameState: () => game.idle,
      );
      final now = DateTime.now().toUtc();
      var sequence = 0;
      Future<void> send(String path, Map<String, Object?> data) async {
        sequence++;
        pipeline.add(
          kcsapiEvent(
            path,
            data,
            sequence: sequence,
            capturedAt: now.add(Duration(milliseconds: sequence)),
          ),
        );
        await pipeline.idle;
        expect(game.lastError, isNull);
        await tester.pump();
      }

      Future<void> enterSortie() => send('/kcsapi/api_get_member/mapinfo', {
        'api_map_info': [
          {'api_id': 11, 'api_cleared': 1},
        ],
      });

      const heavy = '出击提醒：第 1 舰队有大破舰';
      const supply = '出击提醒：第 4 舰队尚未补给';
      const capacity = '船位仅剩 3 个，请注意母港容量';
      Iterable<String> messages() =>
          notices.notices.map((item) => item.message);
      Finder headerMessage(String message) => find.descendant(
        of: find.byKey(const Key('header-notice-scroll')),
        matching: find.text(message),
      );

      await enterSortie();
      expect(game.state.memberMapInfos[101]?.cleared, isTrue);
      expect(messages(), [heavy, supply, capacity]);
      await tester.pump(const Duration(milliseconds: 9999));
      for (final message in [heavy, supply, capacity]) {
        expect(headerMessage(message), findsOneWidget);
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(messages(), isEmpty);

      await send('/kcsapi/api_req_hokyu/charge', {
        'api_ship': [
          {'api_id': 4, 'api_fuel': 15, 'api_bull': 20},
        ],
      });
      expect(game.state.ships[4]?.currentFuel, 15);
      await enterSortie();
      expect(messages(), [heavy, capacity]);
      expect(headerMessage(supply), findsNothing);
      notices.hide();

      await layout.setTopNoticeEnabled(false);
      await enterSortie();
      expect(messages(), isEmpty);
      expect(headerMessage(heavy), findsNothing);
    },
  );

  testWidgets(
    'expedition screen entry renders heavy damage and supply notices together',
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
              currentHp: 1,
              maxHp: 32,
              currentFuel: 0,
              currentAmmo: 0,
            ),
            2: OwnedShip(
              id: 2,
              masterId: 1,
              level: 10,
              currentHp: 8,
              maxHp: 32,
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
              currentHp: 7,
              maxHp: 31,
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
      addTearDown(info.dispose);
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
      expect(find.text('远征提醒：第 2、4 舰队有大破舰'), findsOneWidget);
      expect(find.text('远征提醒：第 2、4 舰队尚未补给'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      expect(notices.notices.map((notice) => notice.message), [
        '远征提醒：第 2、4 舰队有大破舰',
        '远征提醒：第 2、4 舰队尚未补给',
      ]);
      await tester.pump(const Duration(seconds: 4));
      expect(notices.current, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      notices.hide();
    },
  );

  for (final (description, missionId, accepted, enabled, warns) in [
    (
      'accepted launch with an unqualified fleet warns by default',
      21,
      true,
      true,
      true,
    ),
    (
      'accepted launch with a qualified fleet stays quiet',
      1,
      true,
      true,
      false,
    ),
    (
      'accepted launch with its reminder disabled stays quiet',
      21,
      true,
      false,
      false,
    ),
    ('rejected launch stays quiet', 21, false, true, false),
  ]) {
    testWidgets('expedition dispatch: $description', (tester) async {
      if (!enabled) {
        SharedPreferences.setMockInitialValues({
          'top_notice_kind_expeditionSuccess': false,
        });
      }
      const master = MasterShip(
        id: 1,
        name: '吹雪',
        shipTypeId: 2,
        maxFuel: 15,
        maxAmmo: 20,
      );
      OwnedShip ship(int id) => OwnedShip(
        id: id,
        masterId: master.id,
        level: 20,
        currentHp: 30,
        maxHp: 30,
        condition: 49,
        currentFuel: master.maxFuel,
        currentAmmo: master.maxAmmo,
      );
      final game = GameStateController(
        initialState: GameState.empty.copyWith(
          memberId: 100,
          hasMasterData: true,
          masterShips: const {1: master},
          ships: {
            for (final id in [1, 2, 3]) id: ship(id),
          },
          fleets: const [
            Fleet(id: 2, name: '第2舰队', shipIds: [1]),
            Fleet(id: 3, name: '第3舰队', shipIds: [2, 3]),
          ],
        ),
      );
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final notices = TopNoticeController();
      final info = GameInfoNoticeController(
        stateProvider: () => game.state,
        layoutSettingsController: layout,
        topNoticeController: notices,
      );
      addTearDown(game.dispose);
      addTearDown(layout.dispose);
      addTearDown(notices.dispose);
      addTearDown(info.dispose);
      await game.initialize();
      await layout.setTopNoticeDurationSeconds(10);
      await pumpHarness(tester, game: game, layout: layout, notices: notices);

      final pipeline = GameApiEventPipeline(
        consumers: [game, info],
        settleGameState: () => game.idle,
      );
      final now = DateTime.now().toUtc();
      final completion = now
          .add(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      pipeline.add(
        kcsapiEvent(
          '/kcsapi/api_req_mission/start',
          {'api_complatetime': completion},
          apiResult: accepted ? 1 : 0,
          requestParams: {'api_deck_id': '3', 'api_mission_id': '$missionId'},
          capturedAt: now,
        ),
      );
      await pipeline.idle;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final dispatched = game.state.fleets.singleWhere(
        (fleet) => fleet.id == 3,
      );
      expect(game.lastError, isNull);
      expect(dispatched.mission.isActive, accepted);
      if (accepted) {
        expect(dispatched.mission.missionId, missionId);
        expect(
          dispatched.mission.completionTime?.millisecondsSinceEpoch,
          completion,
        );
      }
      expect(game.state.fleets.first.mission.isActive, isFalse);
      if (!warns) {
        expect(notices.notices, isEmpty);
        return;
      }

      const message = '第 3 舰队执行的 21 号远征可能失败';
      final headerMessage = find.descendant(
        of: find.byKey(const Key('header-notice-scroll')),
        matching: find.text(message),
      );
      expect(notices.notices, hasLength(1));
      expect(notices.current?.tone, TopNoticeTone.warning);
      expect(headerMessage, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 9749));
      expect(headerMessage, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(notices.notices, isEmpty);
    });
  }
}

class _QuestSnapshotReducer extends GameStateReducer {
  _QuestSnapshotReducer(List<GameState> snapshots)
    : _snapshots = snapshots.iterator;

  final Iterator<GameState> _snapshots;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) {
    if (!_snapshots.moveNext()) throw StateError('No more quest snapshots');
    return _snapshots.current;
  }
}
