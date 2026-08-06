import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_node_label_resolver.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  test('map response creates a navigation snapshot before battle', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller.accept(mapStartEvent);
    await controller.idle;

    expect(controller.current, isNotNull);
    expect(controller.current!.phaseLabel, '航行中');
    expect(controller.current!.context.nodeLabel, '节点 1');
    expect(controller.current!.context.nodeTypeLabel, '普通战斗');
    expect(controller.current!.friendMain, hasLength(2));
    expect(controller.current!.friendMain.first.condition, 49);
    expect(controller.current!.enemyShips, isEmpty);
    expect(controller.current!.rank, BattleRank.unknown);
  });

  test('falls back to internal ids instead of inventing alphabetic labels', () {
    expect(const BattleContext(node: 1).nodeLabel, '节点 1');
    expect(const BattleContext(node: 26).nodeLabel, '节点 26');
    expect(const BattleContext(node: 27).nodeLabel, '节点 27');
    expect(
      const BattleContext(node: 55, nodeDisplayLabel: 'Y').nodeLabel,
      'Y点',
    );
  });

  test('resolves an event node label by map and internal id', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(
      gameState: () => state,
      nodeLabelResolver: const MapBattleNodeLabelResolver(<String, String>{
        '99-2-55': 'Y',
      }),
    );
    addTearDown(controller.dispose);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_map/start', <String, Object?>{
        'api_maparea_id': 99,
        'api_mapinfo_no': 2,
        'api_no': 55,
      }, sequence: 29),
    );
    await controller.idle;

    expect(controller.current!.context.node, 55);
    expect(controller.current!.context.nodeLabel, 'Y点');
  });

  test('refreshes only the live node label after map data changes', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final labels = <String, String>{};
    final controller = BattleController(
      gameState: () => state,
      nodeLabelResolver: MapBattleNodeLabelResolver(labels),
    );
    addTearDown(controller.dispose);

    controller.accept(mapStartEvent);
    controller.accept(dayBattleEvent);
    await controller.idle;
    final before = controller.current!;
    final hpBefore = before.friendShips.map((ship) => ship.currentHp).toList();
    final sessionBefore = controller.session;
    expect(before.context.nodeLabel, '节点 1');

    labels['1-1-1'] = 'A';
    controller.refreshNodeLabel();

    expect(controller.current!.context.nodeLabel, 'A点');
    expect(
      controller.current!.friendShips.map((ship) => ship.currentHp),
      hpBefore,
    );
    expect(controller.current!.phaseLabel, before.phaseLabel);
    expect(identical(controller.session, sessionBefore), isTrue);

    labels.clear();
    controller.refreshNodeLabel();
    expect(controller.current!.context.nodeLabel, '节点 1');
    expect(identical(controller.session, sessionBefore), isTrue);
  });

  test('turns a live forecast into an authoritative battle record', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);

    controller.accept(mapStartEvent);
    controller.accept(dayBattleEvent);
    await controller.idle;

    expect(controller.current, isNotNull);
    expect(controller.current!.status, LiveBattleStatus.forecast);
    expect(controller.current!.friendShips.first.currentHp, 18);
    expect(controller.current!.enemyShips.first.currentHp, 0);
    expect(controller.current!.mvpCandidate?.name, '夕張');
    expect(controller.records, isEmpty);

    controller.accept(battleResultEvent);
    await controller.idle;

    expect(controller.current!.status, LiveBattleStatus.confirmed);
    expect(controller.current!.rank, BattleRank.s);
    expect(controller.records, hasLength(1));
    expect(controller.records.single.enemyFleetName, 'Test Enemy Fleet');
    expect(controller.records.single.dropShipMasterId, 102);
    expect(controller.records.single.battle.dropItemId, 44);
    expect(controller.records.single.battle.dropItemName, '家具コイン');
    expect(controller.records.single.battle.mvpPositions, <int>[0]);
  });

  test('ignores a duplicate captured sequence', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);

    controller.accept(mapStartEvent);
    controller.accept(dayBattleEvent);
    controller.accept(dayBattleEvent);
    await controller.idle;

    expect(controller.current!.friendShips.first.currentHp, 18);
  });

  test('night battle continues from the daytime ending hp', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);

    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(nightBattleEvent);
    await controller.idle;

    expect(controller.current!.phaseLabel, '夜战');
    expect(controller.current!.friendShips.first.currentHp, 13);
  });

  test(
    'maps real battle arrays with their leading sentinel correctly',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller
        ..accept(mapStartEvent)
        ..accept(
          kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
            'api_deck_id': 1,
            'api_f_nowhps': <int>[-1, 30, 15],
            'api_f_maxhps': <int>[-1, 30, 15],
            'api_e_nowhps': <int>[-1, 20, 10],
            'api_e_maxhps': <int>[-1, 20, 10],
            'api_ship_ke': <int>[-1, 501, 502],
          }, sequence: 30),
        );
      await controller.idle;

      expect(
        controller.current!.friendShips.map((ship) => ship.currentHp),
        <int>[30, 15],
      );
      expect(
        controller.current!.enemyShips.map((ship) => ship.currentHp),
        <int>[20, 10],
      );
    },
  );

  test('combined navigation includes the escort fleet and its type', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer
        .reduce(state, portEvent)
        .copyWith(combinedFleetType: CombinedFleetType.carrierTaskForce);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller.accept(mapStartEvent);
    await controller.idle;

    expect(
      controller.current!.context.combinedFleetType,
      CombinedFleetType.carrierTaskForce,
    );
    expect(controller.current!.friendEscort, hasLength(1));
  });

  test(
    'enemy-only combined battle does not invent a friendly escort',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller
        ..accept(mapStartEvent)
        ..accept(
          kcsapiEvent(
            '/kcsapi/api_req_combined_battle/ec_battle',
            <String, Object?>{
              'api_deck_id': 1,
              'api_f_nowhps': <int>[-1, 30, 15],
              'api_f_maxhps': <int>[-1, 30, 15],
              'api_e_nowhps': <int>[-1, 20],
              'api_e_maxhps': <int>[-1, 20],
              'api_ship_ke': <int>[-1, 501],
              'api_e_nowhps_combined': <int>[-1, 18],
              'api_e_maxhps_combined': <int>[-1, 18],
              'api_ship_ke_combined': <int>[-1, 502],
            },
            sequence: 31,
          ),
        );
      await controller.idle;

      expect(controller.current!.friendEscort, isEmpty);
      expect(controller.current!.enemyEscort, hasLength(1));
    },
  );

  test('predicts one MVP for each friendly combined fleet', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer
        .reduce(state, portEvent)
        .copyWith(combinedFleetType: CombinedFleetType.surfaceTaskForce);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_combined_battle/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[-1, 30, 15],
          'api_f_maxhps': <int>[-1, 30, 15],
          'api_f_nowhps_combined': <int>[-1, 15],
          'api_f_maxhps_combined': <int>[-1, 15],
          'api_e_nowhps': <int>[-1, 30],
          'api_e_maxhps': <int>[-1, 30],
          'api_ship_ke': <int>[-1, 501],
          'api_hougeki1': <String, Object?>{
            'api_at_eflag': <int>[0, 0],
            'api_at_list': <int>[0, 6],
            'api_df_list': <Object?>[
              <int>[0],
              <int>[0],
            ],
            'api_damage': <Object?>[
              <num>[4],
              <num>[7],
            ],
          },
        }, sequence: 32),
      );
    await controller.idle;

    expect(controller.current!.mvpPositions, <int>[0, 6]);
  });

  test(
    'waits for the official result rank for every battle node type',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      Map<String, Object?> untouchedBattle() => <String, Object?>{
        'api_deck_id': 1,
        'api_f_nowhps': <int>[-1, 30, 15],
        'api_f_maxhps': <int>[-1, 30, 15],
        'api_e_nowhps': <int>[-1, 20, 10],
        'api_e_maxhps': <int>[-1, 20, 10],
        'api_ship_ke': <int>[-1, 501, 502],
      };

      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_sortie/ld_airbattle',
          untouchedBattle(),
          sequence: 33,
        ),
      );
      await controller.idle;
      expect(controller.current!.rank, BattleRank.unknown);

      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_sortie/airbattle',
          untouchedBattle(),
          sequence: 34,
        ),
      );
      await controller.idle;
      expect(controller.current!.rank, BattleRank.unknown);
    },
  );

  test('a sunk daytime enemy is not recreated by the night packet', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[-1, 30, 15],
          'api_f_maxhps': <int>[-1, 30, 15],
          'api_e_nowhps': <int>[-1, 10],
          'api_e_maxhps': <int>[-1, 10],
          'api_ship_ke': <int>[-1, 501],
          'api_hougeki1': <String, Object?>{
            'api_at_eflag': <int>[0],
            'api_at_list': <int>[0],
            'api_df_list': <Object?>[
              <int>[0],
            ],
            'api_damage': <Object?>[
              <num>[10],
            ],
          },
        }, sequence: 70),
      )
      ..accept(
        kcsapiEvent('/kcsapi/api_req_battle_midnight/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_e_nowhps': <int>[-1, 10],
          'api_e_maxhps': <int>[-1, 10],
          'api_ship_ke': <int>[-1, 501],
        }, sequence: 71),
      );
    await controller.idle;

    expect(controller.current!.enemyMain.single.currentHp, 0);
  });

  test('preserves zero hp from the battle start arrays', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
        'api_deck_id': 1,
        'api_f_nowhps': <int>[-1, 30, 15],
        'api_f_maxhps': <int>[-1, 30, 15],
        'api_e_nowhps': <int>[-1, 0],
        'api_e_maxhps': <int>[-1, 10],
        'api_ship_ke': <int>[-1, 501],
      }, sequence: 72),
    );
    await controller.idle;

    expect(controller.current!.enemyMain.single.currentHp, 0);
  });

  test(
    'keeps the authoritative result rank without local reinterpretation',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller
        ..accept(mapStartEvent)
        ..accept(
          kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
            'api_deck_id': 1,
            'api_f_nowhps': <int>[-1, 30, 15],
            'api_f_maxhps': <int>[-1, 30, 15],
            'api_e_nowhps': <int>[-1, 10],
            'api_e_maxhps': <int>[-1, 10],
            'api_ship_ke': <int>[-1, 501],
          }, sequence: 73),
        )
        ..accept(
          kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
            'api_win_rank': 'S',
          }, sequence: 74),
        );
      await controller.idle;

      expect(controller.current!.rank, BattleRank.s);
    },
  );

  test(
    'does not confirm or persist a result without an active battle',
    () async {
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
          'api_win_rank': 'S',
        }, sequence: 75),
      );
      await controller.idle;

      expect(controller.current, isNull);
      expect(controller.records, isEmpty);
    },
  );
}
