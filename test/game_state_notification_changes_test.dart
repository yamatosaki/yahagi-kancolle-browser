import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/sortie_damage_control_ledger.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GameStateController.disableTimerForTest = true);
  tearDown(() => GameStateController.disableTimerForTest = false);

  test(
    'notification consumers observe every commit before the UI frame',
    () async {
      final scheduled = <void Function()>[];
      final controller = GameStateController(
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: scheduled.add,
        ),
      );
      addTearDown(controller.dispose);
      final observed = <int?>[];
      controller.notificationChanges.addListener(
        () => observed.add(controller.state.resource(GameResourceType.fuel)),
      );
      var uiNotifications = 0;
      controller.addListener(() => uiNotifications++);

      controller
        ..accept(
          kcsapiEvent('/kcsapi/api_get_member/material', [
            {'api_id': 1, 'api_value': 111},
          ]),
        )
        ..accept(
          kcsapiEvent('/kcsapi/api_get_member/material', [
            {'api_id': 1, 'api_value': 222},
          ], sequence: 2),
        );
      await controller.idle;

      expect(observed, [111, 222]);
      expect(uiNotifications, 0);
      expect(scheduled, hasLength(1));
      scheduled.single();
      expect(uiNotifications, 1);
      expect(observed, [111, 222]);
    },
  );

  testWidgets('paused rendering does not delay state notifications', (
    tester,
  ) async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    addTearDown(() {
      binding.resetInternalState();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    var notifications = 0;
    controller.notificationChanges.addListener(() => notifications++);
    var uiNotifications = 0;
    controller.addListener(() => uiNotifications++);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(binding.framesEnabled, isFalse);

    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/material', [
        {'api_id': 1, 'api_value': 321},
      ]),
    );
    await controller.idle;

    expect(controller.state.resource(GameResourceType.fuel), 321);
    expect(notifications, 1);
    expect(uiNotifications, 0);
    expect(binding.hasScheduledFrame, isFalse);
  });

  test(
    'manual broadcasts remain available to notification consumers',
    () async {
      final scheduled = <void Function()>[];
      final controller = GameStateController(
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: scheduled.add,
        ),
      );
      addTearDown(controller.dispose);
      var stateNotifications = 0;
      var uiNotifications = 0;
      controller.notificationChanges.addListener(() => stateNotifications++);
      controller.addListener(() => uiNotifications++);

      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/material', [
          {'api_id': 1, 'api_value': 321},
        ]),
      );
      await controller.idle;
      controller.notifyListeners();

      expect(stateNotifications, 2);
      expect(uiNotifications, 1);
      scheduled.single();
      expect(stateNotifications, 2);
      expect(uiNotifications, 2);
    },
  );

  test(
    'quest goal transitions retain their synchronous UI broadcast',
    () async {
      final scheduled = <void Function()>[];
      final controller = GameStateController(
        initialState: GameState(quests: {1: _quest}),
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: scheduled.add,
        ),
      );
      addTearDown(controller.dispose);
      final completedStates = <bool>[];
      var uiNotifications = 0;
      controller.notificationChanges.addListener(
        () => completedStates.add(controller.state.quests[1]!.isCompleted),
      );
      controller.addListener(() => uiNotifications++);

      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/questlist', {
          'api_count': 1,
          'api_page_count': 1,
          'api_list': [
            {
              'api_no': 1,
              'api_title': 'Task',
              'api_detail': '',
              'api_category': 1,
              'api_type': 1,
              'api_state': 3,
              'api_progress_flag': 0,
            },
          ],
        }),
      );
      await controller.idle;

      expect(completedStates, [true]);
      expect(uiNotifications, 1);
      expect(scheduled, isEmpty);
    },
  );

  test('parse errors only update the coalesced UI signal', () async {
    final scheduled = <void Function()>[];
    final controller = GameStateController(
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduled.add,
      ),
    );
    addTearDown(controller.dispose);
    var stateNotifications = 0;
    var uiNotifications = 0;
    controller.notificationChanges.addListener(() => stateNotifications++);
    controller.addListener(() => uiNotifications++);

    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/material', [], apiResult: 0),
    );
    await controller.idle;

    expect(controller.state, same(GameState.empty));
    expect(controller.lastError, isNotNull);
    expect(stateNotifications, 0);
    expect(uiNotifications, 0);
    scheduled.single();
    expect(stateNotifications, 0);
    expect(uiNotifications, 1);
  });

  test(
    'cache restore and clearing publish the committed quest state',
    () async {
      final controller = GameStateController(
        questStore: _MemoryQuestStore({1: _quest}),
      );
      addTearDown(controller.dispose);
      final observed = <Set<int>>[];
      controller.notificationChanges.addListener(
        () => observed.add(controller.state.quests.keys.toSet()),
      );

      await controller.initialize();
      await controller.clearQuestsCache();

      expect(observed, [
        {1},
        <int>{},
      ]);
    },
  );

  test('game cache restoration publishes the restored state', () async {
    final store = _DelayedGameStateStore();
    final controller = GameStateController(gameStateStore: store);
    addTearDown(controller.dispose);
    final observed = <int?>[];
    controller.notificationChanges.addListener(
      () => observed.add(controller.state.resource(GameResourceType.fuel)),
    );

    store.loadResult.complete(
      GameState(
        resources: const {GameResourceType.fuel: 999},
        hasPortData: true,
      ),
    );
    await controller.initialize();

    expect(observed, [999]);
  });

  test('quest progress restoration publishes its final state', () async {
    final controller = GameStateController(
      initialState: GameState(memberId: 1, hasCompleteQuestData: true),
      questProgress: QuestProgressEngine(
        goals: {},
        storage: _MemoryProgressStorage(),
      ),
    );
    addTearDown(controller.dispose);
    final observed = <bool>[];
    controller.notificationChanges.addListener(
      () => observed.add(controller.state.hasCompleteQuestData),
    );

    await controller.initialize();

    expect(observed, [false]);
  });

  testWidgets('periodic quest expiration publishes the cleared state', (
    tester,
  ) async {
    GameStateController.disableTimerForTest = false;
    final expiredQuest = GameQuest(
      id: 1,
      title: 'Expired task',
      detail: '',
      category: 1,
      type: 1,
      state: 2,
      progressFlag: 0,
      updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    );
    final controller = GameStateController(
      initialState: GameState(
        quests: {1: expiredQuest},
        availableQuests: {1: expiredQuest},
      ),
    );
    try {
      final observed = <Set<int>>[];
      controller.notificationChanges.addListener(
        () => observed.add(controller.state.quests.keys.toSet()),
      );

      await tester.pump(const Duration(minutes: 1));

      expect(observed, [<int>{}]);
      expect(controller.state.availableQuests, isEmpty);
    } finally {
      controller.dispose();
    }
  });

  test(
    'account reset invalidates a queued capture before broadcasting',
    () async {
      final session = AccountSession(initialMemberId: 1);
      addTearDown(session.dispose);
      final scheduled = <void Function()>[];
      final controller = GameStateController(
        initialState: GameState(memberId: 1),
        accountSession: session,
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: scheduled.add,
        ),
      );
      addTearDown(controller.dispose);
      final observed = <int>[];
      controller.notificationChanges.addListener(
        () => observed.add(controller.state.memberId),
      );

      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/material', [
          {'api_id': 1, 'api_value': 321},
        ]),
      );
      session.reset();
      await controller.idle;

      expect(observed, [0]);
      expect(controller.state.resource(GameResourceType.fuel), isNull);
      expect(scheduled, isEmpty);
    },
  );

  test('battle state commits notify before the shared UI frame', () async {
    final scheduled = <void Function()>[];
    final controller = GameStateController(
      initialState: GameState(
        combatState: const CombatState(isActive: true),
        ships: const {
          1: OwnedShip(
            id: 1,
            masterId: 1,
            level: 1,
            currentHp: 10,
            maxHp: 10,
            slotIds: [11],
          ),
        },
      ),
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduled.add,
      ),
    );
    addTearDown(controller.dispose);
    final observedHp = <int>[];
    final observedEquipment = <int>[];
    controller.notificationChanges.addListener(() {
      observedHp.add(controller.state.ships[1]!.currentHp);
      observedEquipment.add(controller.state.ships[1]!.slotIds.single);
    });
    var uiNotifications = 0;
    controller.addListener(() => uiNotifications++);

    controller.applyFriendlyBattleHp({1: 5}, DateTime.utc(2026));
    controller.applyDamageControlConsumption({
      1: [const DamageControlEquipmentRef(instanceId: 11, masterId: 42)],
    }, DateTime.utc(2026));
    await controller.idle;

    expect(observedHp, [5, 5]);
    expect(observedEquipment, [11, -1]);
    expect(uiNotifications, 0);
    expect(scheduled, hasLength(1));
    scheduled.single();
    expect(uiNotifications, 1);
    expect(observedHp, [5, 5]);
  });

  test(
    'notification listeners can enqueue the next capture in order',
    () async {
      final scheduled = <void Function()>[];
      final controller = GameStateController(
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: scheduled.add,
        ),
      );
      addTearDown(controller.dispose);
      final observed = <int?>[];
      controller.notificationChanges.addListener(() {
        observed.add(controller.state.resource(GameResourceType.fuel));
        if (observed.length == 1) {
          controller.accept(
            kcsapiEvent('/kcsapi/api_get_member/material', [
              {'api_id': 1, 'api_value': 222},
            ], sequence: 2),
          );
        }
      });

      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/material', [
          {'api_id': 1, 'api_value': 111},
        ]),
      );
      await controller.idle;
      await controller.idle;

      expect(observed, [111, 222]);
      expect(scheduled, hasLength(1));
    },
  );

  test(
    'dispose suppresses queued captures, frame callbacks, and cache restore',
    () async {
      final scheduled = <void Function()>[];
      final store = _DelayedGameStateStore();
      final controller = GameStateController(
        gameStateStore: store,
        captureNotifications: FrameNotificationCoalescer(
          scheduleFrame: scheduled.add,
        ),
      );
      var stateNotifications = 0;
      var uiNotifications = 0;
      controller.notificationChanges.addListener(() => stateNotifications++);
      controller.addListener(() => uiNotifications++);
      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/material', [
          {'api_id': 1, 'api_value': 111},
        ]),
      );
      await controller.idle;
      expect(stateNotifications, 1);

      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/material', [
          {'api_id': 1, 'api_value': 222},
        ], sequence: 2),
      );
      controller.dispose();
      scheduled.single();
      store.loadResult.complete(GameState(hasPortData: true));
      await controller.idle;
      await controller.initialize();

      expect(stateNotifications, 1);
      expect(uiNotifications, 0);
      expect(controller.state.resource(GameResourceType.fuel), 111);
    },
  );
}

const _quest = GameQuest(
  id: 1,
  title: 'Task',
  detail: '',
  category: 1,
  type: 1,
  state: 2,
  progressFlag: 0,
);

final class _MemoryQuestStore implements QuestStore {
  _MemoryQuestStore(this.quests);
  Map<int, GameQuest> quests;

  @override
  Future<Map<int, GameQuest>> loadQuests() async => quests;

  @override
  Future<void> saveQuests(Map<int, GameQuest> value) async => quests = value;

  @override
  Future<void> clearQuests() async => quests = {};
}

final class _DelayedGameStateStore extends GameStateStore {
  final loadResult = Completer<GameState>();

  @override
  Future<GameState> load() => loadResult.future;

  @override
  void save(GameState state) {}
}

final class _MemoryProgressStorage implements QuestProgressStorage {
  @override
  Future<String?> read(int account) async => null;

  @override
  Future<void> write(int account, String value) async {}
}
