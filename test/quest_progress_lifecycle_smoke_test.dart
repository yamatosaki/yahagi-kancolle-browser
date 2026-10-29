import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '403 server milestones rebase counts and live results keep count labels',
    () async {
      final session = await _Session.create();
      addTearDown(session.dispose);
      await session.quest(403);
      session.expectCount(403, 0, 10);

      await session.mission(result: 0);
      session.expectCount(403, 0, 10);
      for (var count = 1; count <= 4; count++) {
        await session.mission();
        session.expectCount(403, count, 10);
      }

      await session.quest(403, flag: 1);
      session.expectCount(403, 5, 10);
      await session.mission();
      session.expectCount(403, 6, 10);
      await session.quest(403, flag: 1);
      session.expectCount(403, 6, 10);
      for (var count = 7; count <= 8; count++) {
        await session.mission();
        session.expectCount(403, count, 10);
      }
      expect(session.controller.state.quests[403]!.progressFlag, 1);

      await session.quest(403, flag: 2);
      session.expectCount(403, 8, 10);
      await session.mission();
      session.expectCount(403, 9, 10);

      // An authoritative lower milestone corrects a stale local estimate.
      await session.quest(403);
      session.expectCount(403, 4, 10);
      await session.mission();
      session.expectCount(403, 5, 10);
      expect(session.engine.persistenceError, isNull);
    },
  );

  test(
    '977 keeps real map counts across 80 percent snapshots and restart',
    () async {
      final storage = _MemoryProgressStorage();
      final first = await _Session.create(storage: storage);
      try {
        await first.quest(977, flag: 2);
        first.expectCount(977, 0, 4);
        expect(first.engine.stepsFor(977).map((step) => step.count), [
          0,
          0,
          0,
          0,
        ]);
        await first.battle(45);
        first.expectCount(977, 1, 4);
        await first.quest(977, flag: 2);
        first.expectCount(977, 1, 4);
        expect(first.engine.stepsFor(977).map((step) => step.count), [
          1,
          0,
          0,
          0,
        ]);
      } finally {
        first.dispose();
      }

      // Restore exclusively from the ledger, with an empty secondary quest cache.
      final restored = await _Session.create(storage: storage);
      addTearDown(restored.dispose);
      restored.expectCount(977, 1, 4);
      expect(restored.controller.state.quests[977]!.progressFlag, 2);
      expect(restored.engine.stepsFor(977).map((step) => step.count), [
        1,
        0,
        0,
        0,
      ]);
      await restored.battle(45);
      restored.expectCount(977, 1, 4);
      await restored.battle(53);
      restored.expectCount(977, 2, 4);
      expect(restored.engine.stepsFor(977).map((step) => step.count), [
        1,
        1,
        0,
        0,
      ]);
      expect(restored.engine.persistenceError, isNull);
    },
  );

  test(
    '977 stop and successful restart preserve counts without counting while off',
    () async {
      final session = await _Session.create();
      addTearDown(session.dispose);
      await session.quest(977);
      await session.battle(45);
      session.expectCount(977, 1, 4);
      await session.event(
        '/kcsapi/api_req_quest/stop',
        {},
        params: {'api_quest_id': 977},
      );
      expect(session.controller.state.quests, isEmpty);
      expect(session.controller.state.availableQuests[977]!.state, 1);
      expect(session.questStore.quests, isEmpty);

      await session.battle(53);
      expect(session.engine.stepsFor(977).map((step) => step.count), [
        1,
        0,
        0,
        0,
      ]);
      expect(session.engine.completedIds(session.now), isEmpty);
      await session.event(
        '/kcsapi/api_req_quest/start',
        {},
        params: {'api_quest_id': 977},
      );
      session.expectCount(977, 1, 4);
      expect(session.controller.state.quests[977]!.isAccepted, isTrue);
      expect(session.questStore.quests[977]!.displayProgressLabel, '1/4');
      await session.battle(53);
      session.expectCount(977, 2, 4);
      expect(session.engine.stepsFor(977).map((step) => step.count), [
        1,
        1,
        0,
        0,
      ]);
    },
  );

  test(
    'server confirmation fills 977 subgoals and claim survives restart',
    () async {
      final storage = _MemoryProgressStorage();
      final questStore = _MemoryQuestStore();
      final session = await _Session.create(
        storage: storage,
        questStore: questStore,
      );
      try {
        await session.quest(977, flag: 2);
        session.expectCount(977, 0, 4);
        await session.quest(977, flag: 2, state: 3);
        final quest = session.controller.state.quests[977]!;
        expect(quest.displayProgressLabel, '100%');
        expect(quest.exactProgressLabel, '4/4');
        expect(quest.isServerCompleted, isTrue);
        expect(session.engine.stepsFor(977).map((step) => step.count), [
          1,
          1,
          1,
          1,
        ]);
        expect(questStore.quests[977]!.displayProgressLabel, '100%');

        await session.event(
          '/kcsapi/api_req_quest/clearitemget',
          {},
          params: {'api_quest_id': 977},
        );
        expect(session.controller.state.quests, isEmpty);
        expect(session.controller.state.availableQuests, isEmpty);
        expect(questStore.quests, isEmpty);
        expect(session.controller.completedQuestIds, {977});
        await session.battle(45);
        expect(session.controller.state.quests, isEmpty);
      } finally {
        session.dispose();
      }

      final restored = await _Session.create(
        storage: storage,
        questStore: questStore,
      );
      addTearDown(restored.dispose);
      expect(restored.controller.state.quests, isEmpty);
      expect(restored.controller.completedQuestIds, {977});
      final item =
          QuestCatalog(const [
                QuestCatalogEntry(
                  gameId: 977,
                  code: 'B182',
                  name: 'task',
                  description: '',
                ),
              ])
              .project(
                restored.controller.state.quests,
                confirmedCompleted: restored.controller.completedQuestIds,
              )
              .byGameId(977);
      expect(item.status, QuestStatus.completed);
      expect(restored.engine.persistenceError, isNull);
    },
  );

  test(
    'start2 and basic account switch never mix counts or claimed history',
    () async {
      final storage = _MemoryProgressStorage();
      final session = await _Session.create(storage: storage);
      addTearDown(session.dispose);
      await session.quest(403);
      await session.mission();
      session.expectCount(403, 1, 10);

      await session.login(200);
      expect(session.controller.state.quests, isEmpty);
      expect(session.controller.completedQuestIds, isEmpty);
      await session.quest(403);
      session.expectCount(403, 0, 10);
      await session.quest(403, state: 3);
      await session.event(
        '/kcsapi/api_req_quest/clearitemget',
        {},
        params: {'api_quest_id': 403},
      );
      expect(session.controller.completedQuestIds, {403});

      await session.login(100);
      session.expectCount(403, 1, 10);
      expect(session.controller.completedQuestIds, isEmpty);
      await session.mission();
      session.expectCount(403, 2, 10);
      final firstLedger = jsonDecode(storage.values[100]!) as Map;
      final secondLedger = jsonDecode(storage.values[200]!) as Map;
      expect(firstLedger['account'], 100);
      expect(secondLedger['account'], 200);
      expect((firstLedger['records'] as Map)['403']['claimed'], isFalse);
      expect((secondLedger['records'] as Map)['403']['claimed'], isTrue);

      await session.login(200);
      expect(session.controller.state.quests, isEmpty);
      expect(session.controller.completedQuestIds, {403});
      expect(session.engine.persistenceError, isNull);
    },
  );
}

class _Session {
  _Session(this.controller, this.engine, this.questStore);

  final GameStateController controller;
  final QuestProgressEngine engine;
  final _MemoryQuestStore questStore;
  final DateTime now = DateTime.now().toUtc();
  int sequence = 0;

  static Future<_Session> create({
    _MemoryProgressStorage? storage,
    _MemoryQuestStore? questStore,
  }) async {
    final raw =
        jsonDecode(
              File('assets/data/quest-progress-goals.json').readAsStringSync(),
            )
            as Map;
    final engine = QuestProgressEngine(
      goals: {
        for (final id in [403, 977])
          id: QuestProgressGoal(
            id,
            Map<String, dynamic>.from(raw['$id'] as Map),
          ),
      },
      storage: storage ?? _MemoryProgressStorage(),
    );
    final store = questStore ?? _MemoryQuestStore();
    final controller = GameStateController(
      initialState: GameState.empty.copyWith(
        memberId: 100,
        fleets: [
          Fleet(id: 1, name: 'one', shipIds: [1, 2, 3, 4, 5, 6]),
        ],
        ships: {
          for (var id = 1; id <= 6; id++)
            id: OwnedShip(id: id, masterId: id, level: 99),
        },
        masterShips: {
          1: const MasterShip(id: 1, name: '大和改二重', shipTypeId: 10),
          2: const MasterShip(id: 2, name: '武蔵改二', shipTypeId: 9),
          for (var id = 3; id <= 6; id++)
            id: MasterShip(id: id, name: '駆逐$id', shipTypeId: 2),
        },
      ),
      questProgress: engine,
      questStore: store,
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: (callback) => callback(),
      ),
    );
    await controller.initialize();
    return _Session(controller, engine, store);
  }

  Future<void> event(
    String path,
    Object? data, {
    Map<String, Object?> params = const {},
  }) async {
    controller.accept(
      kcsapiEvent(
        path,
        data,
        requestParams: params,
        capturedAt: now.add(Duration(milliseconds: ++sequence)),
        sequence: sequence,
      ),
    );
    await controller.idle;
    expect(controller.lastError, isNull, reason: path);
  }

  Future<void> quest(int id, {int flag = 0, int state = 2}) =>
      event('/kcsapi/api_get_member/questlist', {
        'api_count': 1,
        'api_page_count': 1,
        'api_disp_page': 1,
        'api_exec_count': state >= 2 ? 1 : 0,
        'api_list': [
          {
            'api_no': id,
            'api_title': 'task',
            'api_detail': '',
            'api_category': id == 403 ? 4 : 2,
            'api_type': id == 403 ? 1 : 4,
            'api_state': state,
            'api_progress_flag': flag,
          },
        ],
      });

  Future<void> mission({int result = 1}) =>
      event('/kcsapi/api_req_mission/result', {'api_clear_result': result});

  Future<void> battle(int map) async {
    await event(
      '/kcsapi/api_req_map/start',
      {
        'api_maparea_id': map ~/ 10,
        'api_mapinfo_no': map % 10,
        'api_no': 13,
        'api_event_id': 5,
      },
      params: {'api_deck_id': 1},
    );
    await event('/kcsapi/api_req_sortie/battleresult', {'api_win_rank': 'S'});
  }

  Future<void> login(int memberId) async {
    await event('/kcsapi/api_start2/getData', {});
    expect(controller.state.memberId, 0);
    await event('/kcsapi/api_get_member/basic', {'api_member_id': memberId});
    expect(controller.state.memberId, memberId);
  }

  void expectCount(int id, int current, int required) {
    final quest = controller.state.quests[id]!;
    expect(quest.progressCurrent, current);
    expect(quest.progressRequired, required);
    expect(quest.exactProgressLabel, '$current/$required');
    expect(quest.displayProgressLabel, '$current/$required');
  }

  void dispose() => controller.dispose();
}

class _MemoryProgressStorage implements QuestProgressStorage {
  final values = <int, String>{};

  @override
  Future<String?> read(int account) async => values[account];

  @override
  Future<void> write(int account, String value) async {
    values[account] = value;
  }
}

class _MemoryQuestStore implements QuestStore {
  Map<int, GameQuest> quests = {};

  @override
  Future<Map<int, GameQuest>> loadQuests() async => Map.of(quests);

  @override
  Future<void> saveQuests(Map<int, GameQuest> value) async {
    quests = Map.of(value);
  }

  @override
  Future<void> clearQuests() async => quests.clear();
}
