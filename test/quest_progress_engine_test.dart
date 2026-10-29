import 'dart:convert';
import 'dart:io';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_tracker.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'fixtures/kcsapi_fixtures.dart';

class MemoryProgress implements QuestProgressStorage {
  final values = <int, String>{};
  bool fail = false;
  bool failRead = false;
  @override
  Future<String?> read(int account) async {
    if (failRead) throw const FileSystemException('unavailable');
    return values[account];
  }

  @override
  Future<void> write(int account, String value) async {
    if (fail) throw const FileSystemException('disk full');
    values[account] = value;
  }
}

class InitialQuestStore implements QuestStore {
  InitialQuestStore(this.quests);
  Map<int, GameQuest> quests;
  @override
  Future<Map<int, GameQuest>> loadQuests() async => quests;
  @override
  Future<void> saveQuests(Map<int, GameQuest> value) async {
    quests = value;
  }

  @override
  Future<void> clearQuests() async {
    quests = {};
  }
}

class InitialStateStore extends GameStateStore {
  InitialStateStore(this.initial);
  final GameState initial;
  @override
  Future<GameState> load() async => initial;
  @override
  void save(GameState state) {}
}

Map<int, QuestProgressGoal> rules() {
  final raw =
      jsonDecode(
            File('assets/data/quest-progress-goals.json').readAsStringSync(),
          )
          as Map;
  return {
    for (final e in raw.entries)
      int.parse(e.key): QuestProgressGoal(
        int.parse(e.key),
        Map<String, dynamic>.from(e.value),
      ),
  };
}

GameQuest quest(int id, DateTime time, {int type = 4, int state = 2}) =>
    GameQuest(
      id: id,
      title: 'task',
      detail: '',
      category: 2,
      type: type,
      state: state,
      progressFlag: 0,
      updatedAt: time,
    );
GameState sample(DateTime time, {int id = 977, int type = 4}) =>
    GameState.empty.copyWith(
      memberId: 100,
      quests: {id: quest(id, time, type: type)},
      fleets: [
        Fleet(id: 1, name: 'one', shipIds: [1, 2, 3, 4, 5, 6]),
      ],
      ships: {
        1: const OwnedShip(id: 1, masterId: 916, level: 99),
        2: const OwnedShip(id: 2, masterId: 546, level: 99),
        for (var i = 3; i <= 6; i++)
          i: OwnedShip(id: i, masterId: i, level: 99),
      },
      masterShips: {
        911: const MasterShip(
          id: 911,
          name: '大和改二',
          shipTypeId: 9,
          afterShipId: 916,
        ),
        916: const MasterShip(id: 916, name: '大和改二重', shipTypeId: 10),
        546: const MasterShip(id: 546, name: '武蔵改二', shipTypeId: 9),
        for (var i = 3; i <= 6; i++)
          i: MasterShip(id: i, name: '駆逐$i', shipTypeId: 2),
      },
    );

class Harness {
  Harness(this.engine, this.state, this.now);
  final QuestProgressEngine engine;
  GameState state;
  DateTime now;
  int seq = 0;
  Future<void> event(
    String path,
    Map<String, Object?> data, {
    Map<String, Object?> params = const {},
    bool reduce = false,
  }) async {
    final e = kcsapiEvent(
      '/kcsapi/$path',
      data,
      requestParams: params,
      capturedAt: now.add(Duration(seconds: seq)),
      sequence: ++seq,
    );
    state = await engine.process(
      state,
      reduce ? GameStateReducer().reduce(state, e) : state,
      e,
    );
  }

  Future<void> battle(
    int map, {
    int cell = 13,
    bool boss = true,
    String rank = 'S',
  }) async {
    await event(
      'api_req_map/start',
      {
        'api_maparea_id': map ~/ 10,
        'api_mapinfo_no': map % 10,
        'api_no': cell,
        'api_event_id': boss ? 5 : 4,
      },
      params: {'api_deck_id': 1},
    );
    await event('api_req_sortie/battleresult', {'api_win_rank': rank});
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 11, 10);
  test('destruction count at goal waits for server confirmation', () async {
    final engine = QuestProgressEngine(
      goals: rules(),
      storage: MemoryProgress(),
    );
    final h = Harness(
      engine,
      await engine.restore(sample(now, id: 609, type: 1), now),
      now,
    );
    final tracker = QuestCompletionTracker(h.state, now: now);

    await h.event(
      'api_req_kousyou/destroyship',
      {},
      params: {'api_ship_id': '1,2'},
    );

    expect(h.state.quests[609]?.exactProgressLabel, '2/2');
    expect(h.state.quests[609]?.isCompleted, isFalse);
    expect(tracker.update(h.state, now: now), isFalse);
  });

  test('server contradiction blocks a locally full multi-step quest', () async {
    final engine = QuestProgressEngine(
      goals: {
        999: QuestProgressGoal(999, {
          'type': 1,
          'create_ship': {'required': 1, 'init': 0},
          'remodel_item': {'required': 1, 'init': 0},
        }),
      },
      storage: MemoryProgress(),
    );
    final h = Harness(
      engine,
      await engine.restore(sample(now, id: 999, type: 1), now),
      now,
    );
    await h.event('api_req_kousyou/createship', {});
    await h.event('api_req_kousyou/remodel_slot', {'api_remodel_flag': 0});
    expect(h.state.quests[999]?.isCompleted, isTrue);
    await h.event('api_get_member/questlist', {
      'api_list': [
        {
          'api_no': 999,
          'api_title': 'task',
          'api_detail': '',
          'api_category': 2,
          'api_type': 1,
          'api_state': 2,
          'api_progress_flag': 0,
        },
      ],
    }, reduce: true);
    expect(h.state.quests[999]?.exactProgressLabel, '2/2');
    expect(h.state.quests[999]?.isCompleted, isFalse);
  });
  test(
    'equipment improvement attempts complete Fd6 even when they fail',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final initial = sample(now, id: 619, type: 1);
      final h = Harness(engine, await engine.restore(initial, now), now);
      final tracker = QuestCompletionTracker(h.state, now: now);

      await h.event('api_req_kousyou/remodel_slot', {'api_remodel_flag': 0});

      expect(h.state.quests[619]?.exactProgressLabel, '1/1');
      expect(h.state.quests[619]?.isCompleted, isTrue);
      expect(tracker.update(h.state, now: now), isTrue);
    },
  );

  test(
    'unavailable cache preserves live quests and clearing removes saved counts',
    () async {
      final store = MemoryProgress()..failRead = true;
      final engine = QuestProgressEngine(goals: rules(), storage: store);
      final h = Harness(engine, await engine.restore(sample(now), now), now);
      expect(h.state.quests[977]!.exactProgressLabel, '0/4');
      expect(engine.persistenceError, isNotNull);
      store.failRead = false;
      await h.battle(45);
      await engine.clear();
      final restored = await QuestProgressEngine(
        goals: rules(),
        storage: store,
      ).restore(sample(now), now);
      expect(restored.quests, isEmpty);
    },
  );
  test(
    'annual quests without counting rules expire live and after restart',
    () async {
      final before = DateTime.utc(2026, 8, 31, 19);
      final after = DateTime.utc(2026, 8, 31, 21);
      final store = MemoryProgress();
      final engine = QuestProgressEngine(goals: rules(), storage: store);
      final h = Harness(
        engine,
        await engine.restore(sample(before, id: 99999, type: 5), before),
        before,
      );
      await h.event('api_get_member/questlist', {
        'api_list': [
          {'api_no': 99999, 'api_label_type': 109},
        ],
      });
      expect(engine.expire(h.state, after).quests, isEmpty);
      final restored = await QuestProgressEngine(
        goals: rules(),
        storage: store,
      ).restore(sample(after, id: 99999, type: 5), after);
      expect(restored.quests, isEmpty);
    },
  );
  test(
    'application controller routes results to tracking before notifying UI',
    () async {
      GameStateController.disableTimerForTest = true;
      addTearDown(() => GameStateController.disableTimerForTest = false);
      final clock = DateTime.now().toUtc();
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final controller = GameStateController(
        questProgress: engine,
        gameStateStore: InitialStateStore(
          sample(clock).copyWith(hasPortData: true),
        ),
        questStore: InitialQuestStore(sample(clock).quests),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final tracker = QuestCompletionTracker(controller.state, now: clock);
      var sequence = 0;
      for (final map in [45, 53, 72, 65]) {
        controller.accept(
          kcsapiEvent(
            '/kcsapi/api_req_map/start',
            {
              'api_maparea_id': map ~/ 10,
              'api_mapinfo_no': map % 10,
              'api_no': map == 72 ? 15 : 13,
              'api_event_id': 5,
            },
            requestParams: {'api_deck_id': 1},
            capturedAt: clock,
            sequence: ++sequence,
          ),
        );
        await controller.idle;
        controller.accept(
          kcsapiEvent(
            '/kcsapi/api_req_sortie/battleresult',
            {'api_win_rank': 'S'},
            capturedAt: clock,
            sequence: ++sequence,
          ),
        );
        await controller.idle;
        expect(controller.lastError, isNull);
      }
      expect(controller.state.quests[977]!.exactProgressLabel, '4/4');
      expect(controller.state.quests[977]!.isCompleted, isFalse);
      expect(tracker.update(controller.state, now: clock), isFalse);
      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          {
            'api_list': [
              {
                'api_no': 977,
                'api_title': 'task',
                'api_detail': '',
                'api_category': 2,
                'api_type': 4,
                'api_state': 3,
                'api_progress_flag': 2,
              },
            ],
          },
          capturedAt: clock,
          sequence: ++sequence,
        ),
      );
      await controller.idle;
      expect(controller.lastError, isNull);
      expect(controller.state.quests[977]!.isServerCompleted, isTrue);
      expect(tracker.update(controller.state, now: clock), true);
      expect(tracker.update(controller.state, now: clock), false);
    },
  );
  test(
    'sinking counts use trusted enemy HP and ship types, not total sunk number',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final h = Harness(
        engine,
        await engine.restore(sample(now, id: 218, type: 1), now),
        now,
      );
      h.state = h.state.copyWith(
        masterShips: {
          ...h.state.masterShips,
          501: const MasterShip(id: 501, name: 'enemy', shipTypeId: 15),
        },
      );
      await h.event(
        'api_req_map/start',
        {
          'api_maparea_id': 2,
          'api_mapinfo_no': 2,
          'api_no': 3,
          'api_event_id': 4,
        },
        params: {'api_deck_id': 1},
      );
      const battle = LiveBattle(
        context: BattleContext(mapAreaId: 2, mapInfoNo: 2, node: 3, deckId: 1),
        enemyMain: [
          BattleShipSnapshot(
            masterId: 501,
            name: 'enemy',
            side: BattleSide.enemy,
            fleetRole: BattleFleetRole.main,
            position: 0,
            initialHp: 30,
            maxHp: 30,
            currentHp: 0,
          ),
          BattleShipSnapshot(
            masterId: 501,
            name: 'enemy',
            side: BattleSide.enemy,
            fleetRole: BattleFleetRole.main,
            position: 1,
            initialHp: 30,
            maxHp: 30,
            currentHp: 10,
          ),
        ],
      );
      h.state = await engine.process(
        h.state,
        h.state,
        kcsapiEvent(
          '/kcsapi/api_req_sortie/battleresult',
          {'api_win_rank': 'A'},
          capturedAt: now,
          sequence: 10,
        ),
        battle: battle,
        battleTrusted: true,
      );
      expect(h.state.quests[218]!.exactProgressLabel, '1/3');
      await h.event('api_req_map/next', {
        'api_maparea_id': 2,
        'api_mapinfo_no': 2,
        'api_no': 3,
        'api_event_id': 4,
      });
      h.state = await engine.process(
        h.state,
        h.state,
        kcsapiEvent(
          '/kcsapi/api_req_sortie/battleresult',
          {'api_win_rank': 'A'},
          capturedAt: now,
          sequence: 11,
        ),
        battle: battle,
        battleTrusted: false,
      );
      expect(h.state.quests[218]!.exactProgressLabel, '1/3');
    },
  );
  test('quarterly completion notification resets with its task period', () {
    final goal = QuestProgressGoal(9999, {
      'type': 4,
      'battle': {'required': 1, 'init': 0},
    });
    final engine = QuestProgressEngine(
      goals: {9999: goal},
      storage: MemoryProgress(),
    );
    final before = DateTime.utc(2026, 8, 31, 19),
        after = DateTime.utc(2026, 8, 31, 21);
    GameQuest done(DateTime t) => GameQuest(
      id: 9999,
      title: '',
      detail: '',
      category: 2,
      type: 5,
      state: 2,
      progressFlag: 0,
      progressCurrent: 1,
      progressRequired: 1,
      updatedAt: t,
    );
    final state = sample(before).copyWith(quests: {9999: done(before)});
    final tracker = QuestCompletionTracker(
      state,
      now: before,
      periodFor: engine.periodFor,
    );
    expect(tracker.update(state.copyWith(quests: {}), now: after), false);
    expect(
      tracker.update(state.copyWith(quests: {9999: done(after)}), now: after),
      true,
    );
  });
  test(
    'single target aligns 50/80 percent while multi target never guesses maps',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final h = Harness(
        engine,
        await engine.restore(sample(now, id: 403, type: 2), now),
        now,
      );
      Future<void> server(int flag, {int state = 2}) async {
        final old = h.state.quests[403]!;
        h.state = h.state.copyWith(
          quests: {
            403: GameQuest(
              id: 403,
              title: old.title,
              detail: '',
              category: 4,
              type: 2,
              state: state,
              progressFlag: flag,
              updatedAt: now,
            ),
          },
        );
        await h.event('api_get_member/questlist', {
          'api_list': [
            {'api_no': 403, 'api_state': state, 'api_progress_flag': flag},
          ],
        });
      }

      await server(1);
      expect(h.state.quests[403]!.exactProgressLabel, '5/10');
      await h.event('api_req_mission/result', {'api_clear_result': 1});
      expect(h.state.quests[403]!.exactProgressLabel, '6/10');
      await server(1);
      expect(h.state.quests[403]!.exactProgressLabel, '6/10');
      await server(2);
      expect(h.state.quests[403]!.exactProgressLabel, '8/10');
      await server(0);
      expect(h.state.quests[403]!.exactProgressLabel, '4/10');
      await server(2, state: 3);
      expect(h.state.quests[403]!.exactProgressLabel, '10/10');
      final other = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final multi = Harness(
        other,
        await other.restore(
          sample(now).copyWith(
            quests: {
              977: GameQuest(
                id: 977,
                title: 'test',
                detail: '',
                category: 2,
                type: 4,
                state: 2,
                progressFlag: 2,
                updatedAt: now,
              ),
            },
          ),
          now,
        ),
        now,
      );
      await multi.event('api_get_member/questlist', {
        'api_list': [
          {'api_no': 977, 'api_progress_flag': 2},
        ],
      });
      expect(multi.state.quests[977]!.progressCurrent, 0);
    },
  );
  test(
    'monthly daily streak resets partial count without expiring task',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final h = Harness(
        engine,
        await engine.restore(sample(now, id: 311, type: 3), now),
        now,
      );
      await h.event('api_req_practice/battle', {'api_deck_id': 1});
      await h.event('api_req_practice/battle_result', {'api_win_rank': 'S'});
      expect(h.state.quests[311]!.progressCurrent, 1);
      h.state = engine.expire(h.state, now.add(const Duration(days: 1)));
      expect(h.state.quests.containsKey(311), true);
      expect(h.state.quests[311]!.progressCurrent, 0);
    },
  );
  test(
    'cache restores server completed subgoals and corrupt data does not crash',
    () async {
      final store = MemoryProgress();
      store.values[100] = 'broken';
      final engine = QuestProgressEngine(goals: rules(), storage: store);
      final state = await engine.restore(
        sample(now).copyWith(quests: {977: quest(977, now, state: 3)}),
        now,
      );
      expect(state.quests[977]!.exactProgressLabel, '4/4');
    },
  );
  test(
    'B182 counts each correct boss once, survives restart and waits for server completion',
    () async {
      final store = MemoryProgress();
      var engine = QuestProgressEngine(goals: rules(), storage: store);
      var h = Harness(engine, await engine.restore(sample(now), now), now);
      final tracker = QuestCompletionTracker(h.state, now: now);
      await h.battle(45, rank: 'A');
      await h.battle(45, boss: false);
      await h.battle(72, cell: 7);
      expect(h.state.quests[977]!.progressCurrent, 0);
      final validMusashi = h.state.ships[2]!;
      h.state = h.state.copyWith(
        ships: {
          ...h.state.ships,
          2: const OwnedShip(id: 2, masterId: 148, level: 99),
        },
        masterShips: {
          ...h.state.masterShips,
          148: const MasterShip(
            id: 148,
            name: '武蔵改',
            shipTypeId: 9,
            afterShipId: 546,
          ),
        },
      );
      await h.battle(45);
      expect(h.state.quests[977]!.progressCurrent, 0);
      h.state = h.state.copyWith(ships: {...h.state.ships, 2: validMusashi});
      await h.battle(45);
      await h.battle(45);
      await h.battle(53);
      expect(h.state.quests[977]!.progressCurrent, 2);
      expect(tracker.update(h.state, now: now), false);
      engine = QuestProgressEngine(goals: rules(), storage: store);
      h = Harness(
        engine,
        await engine.restore(h.state, now),
        now.add(const Duration(minutes: 2)),
      );
      expect(h.state.quests[977]!.progressCurrent, 2);
      await h.battle(72, cell: 15);
      await h.battle(65);
      expect(h.state.quests[977]!.exactProgressLabel, '4/4');
      expect(h.state.quests[977]!.isLocallyCompleted, false);
      expect(h.state.quests[977]!.isCompleted, false);
      expect(tracker.update(h.state, now: now), false);
      expect(engine.stepsFor(977).map((s) => s.count), [1, 1, 1, 1]);
      await h.event('api_get_member/questlist', {
        'api_list': [
          {'api_no': 977},
        ],
      });
      // Poi marks this rule fuzzy, so local counts and incomplete server
      // snapshots can never prove completion.
      expect(h.state.quests[977]!.isLocallyCompleted, false);
      expect(tracker.update(h.state, now: now), false);
      await h.event('api_get_member/questlist', {
        'api_list': [
          {
            'api_no': 977,
            'api_title': 'task',
            'api_detail': '',
            'api_category': 2,
            'api_type': 4,
            'api_state': 3,
            'api_progress_flag': 2,
          },
        ],
      }, reduce: true);
      expect(h.state.quests[977]!.isServerCompleted, true);
      expect(h.state.quests[977]!.exactProgressLabel, '4/4');
      expect(tracker.update(h.state, now: now), true);
      expect(tracker.update(h.state, now: now), false);
    },
  );
  test(
    'claim history survives restart and appears as completed without inference',
    () async {
      final store = MemoryProgress();
      var engine = QuestProgressEngine(goals: rules(), storage: store);
      final h = Harness(engine, await engine.restore(sample(now), now), now);
      await h.event(
        'api_req_quest/clearitemget',
        {},
        params: {'api_quest_id': 977},
        reduce: true,
      );
      expect(h.state.quests.containsKey(977), false);
      expect(engine.completedIds(now), {977});
      engine = QuestProgressEngine(goals: rules(), storage: store);
      await engine.restore(h.state, now);
      expect(engine.completedIds(now), {977});
      final catalog = QuestCatalog([
        QuestCatalogEntry.fromJson(977, {'code': 'B182'}),
      ]);
      expect(
        catalog
            .project(
              {},
              isComplete: false,
              confirmedCompleted: engine.completedIds(now),
            )
            .items
            .single
            .status,
        QuestStatus.completed,
      );
    },
  );
  test('account switches never mix counters or claimed history', () async {
    final store = MemoryProgress();
    final engine = QuestProgressEngine(goals: rules(), storage: store);
    final h = Harness(engine, await engine.restore(sample(now), now), now);
    await h.battle(45);
    final old = h.state;
    h.state = await engine.process(
      old,
      old.copyWith(memberId: 200),
      kcsapiEvent('/kcsapi/api_port/port', {}, capturedAt: now),
    );
    expect(h.state.quests, isEmpty);
    expect(engine.completedIds(now), isEmpty);
    h.state = await engine.process(
      h.state,
      h.state.copyWith(memberId: 100),
      kcsapiEvent('/kcsapi/api_port/port', {}, capturedAt: now),
    );
    expect(h.state.quests[977]!.progressCurrent, 1);
  });
  test(
    'same account relogin restores active quest counts after start2',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final h = Harness(engine, await engine.restore(sample(now), now), now);
      await h.battle(45);
      await h.event('api_start2/getData', {}, reduce: true);
      expect(h.state.memberId, 0);
      await h.event('api_get_member/basic', {
        'api_member_id': 100,
      }, reduce: true);
      expect(h.state.quests[977]!.progressCurrent, 1);
      await h.event('api_port/port', {
        'api_basic': {'api_member_id': 100},
      }, reduce: true);
      expect(h.state.quests[977]!.progressCurrent, 1);
    },
  );
  test(
    'unaccepted quests, failed requests and retransmitted results do not count',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final h = Harness(
        engine,
        await engine.restore(
          sample(now).copyWith(quests: {977: quest(977, now, state: 1)}),
          now,
        ),
        now,
      );
      await h.battle(45);
      expect(h.state.quests[977]!.progressCurrent, 0);
      h.state = h.state.copyWith(
        quests: {977: h.state.quests[977]!.withState(2)},
      );
      await h.battle(45);
      await h.event('api_req_sortie/battleresult', {'api_win_rank': 'S'});
      expect(h.state.quests[977]!.progressCurrent, 1);
      final failed = kcsapiEvent(
        '/kcsapi/api_req_quest/clearitemget',
        {},
        apiResult: 0,
        requestParams: {'api_quest_id': 977},
        capturedAt: now,
      );
      h.state = await engine.process(h.state, h.state, failed);
      expect(engine.completedIds(now), isEmpty);
    },
  );
  test(
    'old reducer and rule engine do not double count and batch actions count correctly',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final h = Harness(
        engine,
        await engine.restore(sample(now, id: 607, type: 1), now),
        now,
      );
      await h.event('api_req_kousyou/createitem', {
        'api_get_items': [{}, {}],
      }, reduce: true);
      expect(h.state.quests[607]!.progressCurrent, 3);
      await h.event('api_req_kousyou/createitem', {
        'api_get_items': [{}],
      }, reduce: true);
      expect(h.state.quests[607]!.progressCurrent, 4);
      expect(h.state.quests[607]!.isCompleted, true);
    },
  );
  test(
    'stop preserves subgoals but stops counting until accepted again',
    () async {
      final engine = QuestProgressEngine(
        goals: rules(),
        storage: MemoryProgress(),
      );
      final h = Harness(engine, await engine.restore(sample(now), now), now);
      await h.battle(45);
      await h.event(
        'api_req_quest/stop',
        {},
        params: {'api_quest_id': 977},
        reduce: true,
      );
      await h.battle(53);
      expect(engine.stepsFor(977)[1].count, 0);
      h.state = h.state.copyWith(quests: {977: quest(977, now)});
      await h.battle(53);
      expect(h.state.quests[977]!.progressCurrent, 2);
    },
  );
  test(
    'disk failure cannot prevent live completion and save retries',
    () async {
      final store = MemoryProgress()..fail = true;
      final engine = QuestProgressEngine(goals: rules(), storage: store);
      final h = Harness(
        engine,
        await engine.restore(sample(now, id: 201, type: 1), now),
        now,
      );
      await h.battle(11);
      expect(h.state.quests[201]!.isCompleted, true);
      expect(engine.persistenceError, isNotNull);
      store.fail = false;
      await h.event('api_req_hokyu/charge', {});
      expect(engine.persistenceError, isNull);
      expect(store.values[100], isNotNull);
    },
  );
  test(
    'period boundaries respect 05:00 JST, Monday, quarters and yearly month',
    () {
      final before = DateTime.utc(2026, 8, 31, 19, 59),
          after = DateTime.utc(2026, 8, 31, 20);
      for (final type in [1, 3, 4, 109]) {
        expect(
          questPeriodKey(type, 4, before),
          isNot(questPeriodKey(type, 4, after)),
        );
      }
      expect(questPeriodKey(0, 4, before), questPeriodKey(0, 4, after));
      expect(
        questPeriodKey(2, 4, DateTime.utc(2026, 9, 6, 19, 59)),
        isNot(questPeriodKey(2, 4, DateTime.utc(2026, 9, 6, 20))),
      );
    },
  );
  test(
    'daily active progress and claims expire, one-time history stays',
    () async {
      final store = MemoryProgress();
      var engine = QuestProgressEngine(goals: rules(), storage: store);
      final h = Harness(
        engine,
        await engine.restore(sample(now, id: 201, type: 1), now),
        now,
      );
      await h.battle(11);
      await h.event(
        'api_req_quest/clearitemget',
        {},
        params: {'api_quest_id': 201},
        reduce: true,
      );
      expect(engine.completedIds(now), {201});
      engine = QuestProgressEngine(goals: rules(), storage: store);
      final restored = await engine.restore(
        h.state,
        now.add(const Duration(days: 1)),
      );
      expect(engine.completedIds(now.add(const Duration(days: 1))), isEmpty);
      expect(restored.quests, isEmpty);
    },
  );
  test('all rule fields are understood; unknown constraints fail closed', () {
    final goal = {'required': 1, 'unsupportedConstraint': true};
    expect(matchesQuestStep(goal, const QuestProgressEvent('battle')), false);
    expect(
      matchesQuestStep({'fleetlimit': 4}, const QuestProgressEvent('battle')),
      false,
    );
    final all = rules();
    expect(all.length, 432);
    expect(all[977]!.steps.length, 4);
  });
}
