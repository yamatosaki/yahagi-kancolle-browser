import 'dart:convert';
import 'dart:io';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
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

GameState b210State(DateTime time) => GameState.empty.copyWith(
  memberId: 100,
  quests: {1033: quest(1033, time)},
  fleets: const [
    Fleet(id: 3, name: 'three', shipIds: [1, 2, 3, 4]),
    Fleet(id: 1, name: 'one', shipIds: [1, 3, 4, -1]),
    Fleet(id: 2, name: 'two', shipIds: [1, 2, 3, 4]),
    Fleet(id: 4, name: 'four'),
  ],
  ships: const {
    1: OwnedShip(id: 1, masterId: 945, level: 99),
    2: OwnedShip(id: 2, masterId: 3, level: 99),
    3: OwnedShip(id: 3, masterId: 1, level: 99),
    4: OwnedShip(id: 4, masterId: 1, level: 99),
  },
  masterShips: const {
    945: MasterShip(id: 945, name: '第百一号輸送艦', shipTypeId: 24),
    3: MasterShip(id: 3, name: '軽巡', shipTypeId: 3),
    1: MasterShip(id: 1, name: '駆逐', shipTypeId: 2),
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
    LiveBattle? battle,
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
      battle: battle,
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

class _B210Capture {
  _B210Capture(GameState initialState, this.now, this.storage)
    : engine = QuestProgressEngine(goals: rules(), storage: storage) {
    state = GameStateController(
      initialState: initialState,
      questProgress: engine,
    );
    battle = BattleController(
      gameState: () => state.state,
      waitForGameState: () => state.idle,
      predictionExecutor: const ImmediateBattlePredictionExecutor(),
    );
    state.questBattleSnapshot = () => battle.current;
    state.questBattleTrusted = () => battle.isPredictionConfirmed;
    pipeline = GameApiEventPipeline(
      consumers: [state, battle],
      settleGameState: () async {
        await state.idle;
        await battle.idle;
        await state.idle;
      },
    );
    addTearDown(state.dispose);
    addTearDown(battle.dispose);
  }

  final DateTime now;
  final MemoryProgress storage;
  final QuestProgressEngine engine;
  late final GameStateController state;
  late final BattleController battle;
  late final GameApiEventPipeline pipeline;
  int _sequence = 0;

  List<int> get counts =>
      engine.stepsFor(1033).map((step) => step.count).toList();

  Future<void> send(
    String path,
    Object? data, {
    Map<String, Object?> params = const {},
  }) async {
    pipeline.add(
      kcsapiEvent(
        '/kcsapi/$path',
        data,
        requestParams: params,
        capturedAt: now.add(Duration(milliseconds: ++_sequence)),
        sequence: _sequence,
      ),
    );
    await pipeline.idle;
    expect(state.lastError, isNull, reason: path);
  }

  Future<void> start({
    int deck = 1,
    int map = 1,
    int node = 1,
    int boss = 13,
    int event = 4,
  }) => send(
    'api_req_map/start',
    {
      'api_maparea_id': 1,
      'api_mapinfo_no': map,
      'api_no': node,
      'api_bosscell_no': boss,
      'api_event_id': event,
    },
    params: {'api_deck_id': deck},
  );

  Future<void> next(int map, int node, {int event = 4, int? color}) =>
      send('api_req_map/next', {
        'api_maparea_id': 1,
        'api_mapinfo_no': map,
        'api_no': node,
        'api_event_id': event,
        'api_color_no': ?color,
      });

  Future<void> phase({
    required int deck,
    required int mainCount,
    int escortCount = 0,
  }) async {
    final raw =
        (jsonDecode(dayBattleEvent.responseBody) as Map)['api_data'] as Map;
    await send(
      escortCount == 0
          ? 'api_req_sortie/battle'
          : 'api_req_combined_battle/battle_water',
      {
        ...raw,
        'api_deck_id': deck,
        'api_f_nowhps': List.filled(mainCount, 30),
        'api_f_maxhps': List.filled(mainCount, 30),
        if (escortCount > 0) ...{
          'api_f_nowhps_combined': List.filled(escortCount, 30),
          'api_f_maxhps_combined': List.filled(escortCount, 30),
        },
      },
    );
    expect(battle.lastError, isNull);
    expect(battle.current!.displayStage, BattleDisplayStage.battle);
  }

  Future<void> result(String rank, {bool combined = false}) => send(
    combined
        ? 'api_req_combined_battle/battleresult'
        : 'api_req_sortie/battleresult',
    {'api_win_rank': rank, 'api_mvp': 1},
  );

  Future<void> port() => send('api_port/port', {
    'api_basic': {'api_member_id': state.state.memberId},
    'api_ship': [
      for (final ship in state.state.ships.values)
        {
          'api_id': ship.id,
          'api_ship_id': ship.masterId,
          'api_lv': ship.level,
          'api_nowhp': 30,
          'api_maxhp': 30,
        },
    ],
    'api_deck_port': [
      for (final fleet in state.state.fleets)
        {'api_id': fleet.id, 'api_name': fleet.name, 'api_ship': fleet.shipIds},
    ],
  });

  Future<void> completeOnServer() => send('api_get_member/questlist', {
    'api_count': 1,
    'api_page_count': 1,
    'api_disp_page': 1,
    'api_exec_count': 1,
    'api_list': [
      {
        'api_no': 1033,
        'api_title': 'B210',
        'api_detail': '',
        'api_category': 2,
        'api_type': 4,
        'api_state': 3,
        'api_progress_flag': 0,
      },
    ],
  });
}

void main() {
  final now = DateTime.utc(2026, 9, 11, 10);
  group('B210 capture smoke', () {
    test(
      'checks actual roster, Boss markers, rank and separate map steps',
      () async {
        final run = _B210Capture(b210State(now), now, MemoryProgress());
        await run.state.initialize();
        await run.start(node: 13, event: 5);
        await run.phase(deck: 1, mainCount: 3);
        expect(run.battle.current!.friendMain.map((ship) => ship.masterId), [
          945,
          1,
          1,
        ]);
        await run.result('S');
        expect(run.battle.records, hasLength(1));
        expect(run.counts, [0, 0, 0, 0]);

        await run.start(deck: 2);
        await run.phase(deck: 2, mainCount: 4);
        expect(run.battle.current!.friendMain.map((ship) => ship.masterId), [
          945,
          3,
          1,
          1,
        ]);
        await run.result('S');
        expect(run.counts, [0, 0, 0, 0], reason: 'non-Boss S');
        await run.next(1, 13, event: 5);
        await run.phase(deck: 2, mainCount: 4);
        await run.result('A');
        expect(run.counts, [0, 0, 0, 0], reason: 'Boss A');

        await run.start(deck: 2);
        await run.send('api_req_map/next', {
          'api_no': 13,
          'api_maparea_id': 0,
          'api_event_id': 4,
        });
        await run.phase(deck: 2, mainCount: 4);
        await run.result('S');
        expect(run.counts, [
          1,
          0,
          0,
          0,
        ], reason: 'Boss cell number retained from start');
        await run.result('S');
        expect(run.counts, [1, 0, 0, 0], reason: 'retransmitted result');

        for (final map in [2, 3, 4]) {
          await run.start(deck: 2, map: map);
          await run.next(
            map,
            15,
            color: map == 2 ? 5 : null,
            event: map == 2 ? 4 : 5,
          );
          await run.phase(deck: 2, mainCount: 4);
          await run.result('S');
          expect(run.counts, [
            for (var step = 1; step <= 4; step++) step <= map ? 1 : 0,
          ]);
        }
        expect(run.state.state.quests[1033]!.isCompleted, isFalse);
        await run.completeOnServer();
        expect(run.state.state.quests[1033]!.isServerCompleted, isTrue);
      },
    );

    test(
      'ignores a stale result after returning to port, including on restore',
      () async {
        final run = _B210Capture(b210State(now), now, MemoryProgress());
        await run.state.initialize();
        await run.start(deck: 2, node: 13, event: 5);
        await run.phase(deck: 2, mainCount: 4);
        await run.port();
        expect(run.state.state.combatState.isActive, isFalse);
        final savedAtPort = MemoryProgress()..values.addAll(run.storage.values);
        await run.result('S');
        expect(run.counts, [0, 0, 0, 0]);

        final reopened = _B210Capture(run.state.state, now, savedAtPort);
        await reopened.state.initialize();
        await reopened.result('S');
        expect(reopened.counts, [0, 0, 0, 0]);
      },
    );

    test('uses the real combined escort roster', () async {
      final run = _B210Capture(
        b210State(now).copyWith(
          combinedFleetType: CombinedFleetType.surfaceTaskForce,
          fleets: const [
            Fleet(id: 1, name: 'main', shipIds: [1, 3, 4]),
            Fleet(id: 2, name: 'escort', shipIds: [2]),
          ],
        ),
        now,
        MemoryProgress(),
      );
      await run.state.initialize();
      expect(run.engine.qualifyingFleetIds(1033, run.state.state), isEmpty);
      await run.start(node: 13, event: 5);
      await run.phase(deck: 1, mainCount: 3, escortCount: 1);
      expect(run.battle.current!.friendEscort.map((ship) => ship.masterId), [
        3,
      ]);
      await run.result('S', combined: true);
      expect(run.counts, [1, 0, 0, 0]);
    });

    test(
      'unknown ranks and unrelated results cannot consume a sortie',
      () async {
        final run = _B210Capture(b210State(now), now, MemoryProgress());
        await run.state.initialize();
        await run.start(deck: 2, node: 13, event: 5);
        await run.phase(deck: 2, mainCount: 4);
        await run.send('api_req_practice/battle_result', {'api_win_rank': 'S'});
        await run.result('?');
        expect(run.counts, [0, 0, 0, 0]);
        await run.send(
          'api_req_hensei/change',
          {},
          params: {'api_id': 2, 'api_ship_idx': 1, 'api_ship_id': -1},
        );
        expect(run.engine.qualifyingFleetIds(1033, run.state.state), [3]);
        await run.result('S');
        expect(run.counts, [1, 0, 0, 0]);
      },
    );

    test('missing deck in capture does not assume the first fleet', () async {
      final initial = b210State(now);
      final run = _B210Capture(
        initial.copyWith(
          fleets: const [
            Fleet(id: 1, name: 'one', shipIds: [1, 2, 3, 4]),
          ],
        ),
        now,
        MemoryProgress(),
      );
      await run.state.initialize();
      await run.send('api_req_map/start', {
        'api_maparea_id': 1,
        'api_mapinfo_no': 1,
        'api_no': 13,
        'api_event_id': 5,
      });
      await run.result('S');
      expect(run.counts, [0, 0, 0, 0]);
    });
  });

  test('B210 fleet hint distinguishes eligible, ineligible and unknown', () {
    final engine = QuestProgressEngine(
      goals: rules(),
      storage: MemoryProgress(),
    );
    final state = b210State(now);

    expect(engine.qualifyingFleetIds(1033, state), [2, 3]);
    expect(
      engine.qualifyingFleetIds(
        1033,
        state.copyWith(fleets: [state.fleets[1]]),
      ),
      isEmpty,
    );
    expect(engine.qualifyingFleetIds(201, state), isNull);
    expect(engine.qualifyingFleetIds(9999, state), isNull);
    expect(engine.qualifyingFleetIds(1033, GameState.empty), isNull);
    expect(engine.qualifyingFleetIds(1033, state.copyWith(ships: {})), isNull);
    final unknownRules = QuestProgressEngine(
      goals: {
        1033: QuestProgressGoal(1033, {
          'battle_boss_win_rank_s': {
            'flagshipId': [945],
            'unsupportedConstraint': true,
          },
        }),
      },
      storage: MemoryProgress(),
    );
    expect(unknownRules.qualifyingFleetIds(1033, state), isNull);
  });

  test('B210 counts the actual 1-1 Boss S fleet at settlement', () async {
    final engine = QuestProgressEngine(
      goals: rules(),
      storage: MemoryProgress(),
    );
    final h = Harness(engine, await engine.restore(b210State(now), now), now);

    await h.battle(11);
    expect(engine.stepsFor(1033).first.count, 0);

    BattleShipSnapshot ship(int id, int position, BattleFleetRole role) =>
        BattleShipSnapshot(
          masterId: id,
          name: '',
          side: BattleSide.friend,
          fleetRole: role,
          position: position,
          initialHp: 20,
          maxHp: 20,
          currentHp: 20,
        );
    Future<void> settle(int deckId, {bool hasLightCruiser = false}) async {
      await h.event(
        'api_req_map/start',
        {
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 13,
          'api_event_id': 5,
        },
        params: {'api_deck_id': deckId},
      );
      await h.event(
        'api_req_sortie/battleresult',
        {'api_win_rank': 'S'},
        battle: LiveBattle(
          context: BattleContext(
            mapAreaId: 1,
            mapInfoNo: 1,
            node: 13,
            deckId: deckId,
          ),
          friendMain: [
            ship(945, 0, BattleFleetRole.main),
            ship(1, 1, BattleFleetRole.main),
            ship(1, 2, BattleFleetRole.main),
            if (hasLightCruiser) ship(3, 3, BattleFleetRole.main),
          ],
        ),
      );
    }

    await settle(2);
    expect(engine.stepsFor(1033).first.count, 0);
    final completeFleets = h.state.fleets;
    h.state = h.state.copyWith(
      fleets: const [
        Fleet(id: 1, name: 'one', shipIds: [1, 2, 3, 4, 999]),
      ],
    );
    await settle(1, hasLightCruiser: true);
    expect(engine.stepsFor(1033).first.count, 0);
    h.state = h.state.copyWith(fleets: completeFleets);
    await settle(1, hasLightCruiser: true);
    expect(engine.stepsFor(1033).map((step) => step.count), [1, 0, 0, 0]);
  });

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
