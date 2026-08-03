import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
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
    expect(controller.current!.context.nodeLabel, 'A点');
    expect(controller.current!.context.nodeTypeLabel, '普通战斗');
    expect(controller.current!.friendMain, hasLength(2));
    expect(controller.current!.friendMain.first.condition, 49);
    expect(controller.current!.enemyShips, isEmpty);
    expect(controller.current!.rank, BattleRank.unknown);
  });

  test('map node numbers use Yahagi-style alphabetic labels', () {
    expect(const BattleContext(node: 1).nodeLabel, 'A点');
    expect(const BattleContext(node: 3).nodeLabel, 'C点');
    expect(const BattleContext(node: 26).nodeLabel, 'Z点');
    expect(const BattleContext(node: 27).nodeLabel, 'AA点');
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

  test('uses air-raid rank rules only for long-distance air battles', () async {
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
    expect(controller.current!.rank, BattleRank.ss);

    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_sortie/airbattle',
        untouchedBattle(),
        sequence: 34,
      ),
    );
    await controller.idle;
    expect(controller.current!.rank, BattleRank.d);
  });
}
