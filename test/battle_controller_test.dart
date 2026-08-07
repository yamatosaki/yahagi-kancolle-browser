import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_node_label_resolver.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  test('locks the selected prediction engine for one battle session', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    var method = BattlePredictionMethod.poi;
    final controller = BattleController(
      gameState: () => state,
      predictionMethod: () => method,
      poiEngineFactory: _fixedEngineFactory(BattleRank.a),
      yahagiEngineFactory: _fixedEngineFactory(BattleRank.b),
    );
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;
    expect(controller.current!.rank, BattleRank.a);

    method = BattlePredictionMethod.yahagi;
    controller.accept(nightBattleEvent);
    await controller.idle;
    expect(controller.current!.rank, BattleRank.a);

    controller
      ..accept(
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 2,
        }, sequence: 980),
      )
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', const <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[-1, 30, 15],
          'api_f_maxhps': <int>[-1, 30, 15],
          'api_e_nowhps': <int>[-1, 20],
          'api_e_maxhps': <int>[-1, 20],
          'api_ship_ke': <int>[-1, 501],
        }, sequence: 981),
      );
    await controller.idle;
    expect(controller.current!.rank, BattleRank.b);
  });
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
    expect(controller.current!.rank, BattleRank.a);
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
    expect(controller.current!.rank, BattleRank.a);
  });

  test('night battle refreshes the daytime forecast rank', () async {
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
          'api_e_nowhps': <int>[-1, 20],
          'api_e_maxhps': <int>[-1, 20],
          'api_ship_ke': <int>[-1, 501],
        }, sequence: 76),
      );
    await controller.idle;
    expect(controller.current!.rank, BattleRank.d);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_battle_midnight/battle', <String, Object?>{
        'api_hougeki': <String, Object?>{
          'api_at_eflag': <int>[0],
          'api_at_list': <int>[0],
          'api_df_list': <Object?>[
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[20],
          ],
        },
      }, sequence: 77),
    );
    await controller.idle;

    expect(controller.current!.phaseLabel, '夜战');
    expect(controller.current!.enemyMain.single.currentHp, 0);
    expect(controller.current!.rank, BattleRank.ss);
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
    'predicts air raid and ordinary battle ranks from the battle packet',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      Map<String, Object?> untouchedBattle() => <String, Object?>{
        'api_deck_id': 1,
        'api_f_nowhps': <int>[-1, 30, 15],
        'api_f_maxhps': <int>[-1, 30, 15],
        'api_e_nowhps': <int>[-1, 20, 10],
        'api_e_maxhps': <int>[-1, 20, 10],
        'api_ship_ke': <int>[-1, 501, 502],
      };

      for (final scenario in <(String, BattleRank)>[
        ('/kcsapi/api_req_sortie/ld_airbattle', BattleRank.ss),
        ('/kcsapi/api_req_sortie/airbattle', BattleRank.d),
      ]) {
        final controller = BattleController(gameState: () => state);
        controller.accept(
          kcsapiEvent(scenario.$1, untouchedBattle(), sequence: 33),
        );
        await controller.idle;
        expect(controller.current!.rank, scenario.$2);
        controller.dispose();
      }
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
    'keeps an authoritative non-S result without local reinterpretation',
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
            'api_win_rank': 'A',
          }, sequence: 74),
        );
      await controller.idle;

      expect(controller.current!.rank, BattleRank.a);
    },
  );

  test(
    'normalizes an official S rank to SS when the fleet is untouched',
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
            'api_e_nowhps': <int>[-1, 20],
            'api_e_maxhps': <int>[-1, 20],
            'api_ship_ke': <int>[-1, 501],
          }, sequence: 78),
        )
        ..accept(
          kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
            'api_win_rank': 'S',
          }, sequence: 79),
        );
      await controller.idle;

      expect(controller.current!.status, LiveBattleStatus.confirmed);
      expect(controller.current!.rank, BattleRank.ss);
    },
  );

  test('practice night battle refreshes the daytime forecast rank', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_practice/battle', <String, Object?>{
        'api_deck_id': 1,
        'api_f_nowhps': <int>[-1, 30, 15],
        'api_f_maxhps': <int>[-1, 30, 15],
        'api_e_nowhps': <int>[-1, 20],
        'api_e_maxhps': <int>[-1, 20],
        'api_ship_ke': <int>[-1, 501],
      }, sequence: 78),
    );
    await controller.idle;
    expect(controller.current!.rank, BattleRank.d);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_practice/midnight_battle', <String, Object?>{
        'api_hougeki': <String, Object?>{
          'api_at_eflag': <int>[0],
          'api_at_list': <int>[0],
          'api_df_list': <Object?>[
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[20],
          ],
        },
      }, sequence: 79),
    );
    await controller.idle;

    expect(controller.current!.phaseLabel, '夜战');
    expect(controller.current!.enemyMain.single.currentHp, 0);
    expect(controller.current!.rank, BattleRank.ss);
  });

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

BattlePredictionEngineFactory _fixedEngineFactory(BattleRank rank) =>
    ({
      required friendMain,
      required friendEscort,
      required enemyMain,
      required enemyEscort,
    }) => _FixedRankEngine(
      rank: rank,
      friendMain: friendMain,
      friendEscort: friendEscort,
      enemyMain: enemyMain,
      enemyEscort: enemyEscort,
    );

final class _FixedRankEngine implements BattlePredictionEngine {
  const _FixedRankEngine({
    required this.rank,
    required this.friendMain,
    required this.friendEscort,
    required this.enemyMain,
    required this.enemyEscort,
  });

  final BattleRank rank;
  final List<BattleShipSnapshot> friendMain;
  final List<BattleShipSnapshot> friendEscort;
  final List<BattleShipSnapshot> enemyMain;
  final List<BattleShipSnapshot> enemyEscort;

  @override
  BattlePrediction append({
    required String path,
    required Map<String, Object?> data,
  }) => BattlePrediction(
    friendMain: friendMain,
    friendEscort: friendEscort,
    enemyMain: enemyMain,
    enemyEscort: enemyEscort,
    rank: rank,
  );
}
