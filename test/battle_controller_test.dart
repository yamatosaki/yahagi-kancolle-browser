import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_node_label_resolver.dart';
import 'package:yahagi_kancolle_browser/src/battle/formation_memory.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  test(
    'fleet display starts once and settles on a matching ranked result',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final events = <String>[];
      final controller = BattleController(
        gameState: () => state,
        onFriendlyHpUpdated: (_, _) => events.add('hp'),
        onFleetBattleDisplayStarted: (shipIds) =>
            events.add('started ${shipIds.join(',')}'),
        onFleetBattleDisplaySettled: () => events.add('settled'),
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      addTearDown(controller.dispose);

      state = reducer.reduce(state, mapStartEvent);
      controller
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent)
        ..accept(nightBattleEvent);
      await controller.idle;
      expect(events, ['started 9001,9002', 'hp', 'hp']);

      controller
        ..accept(kcsapiEvent(battleResultEvent.path, {}, sequence: 24))
        ..accept(
          kcsapiEvent(
            battleResultEvent.path,
            {'api_win_rank': 'S'},
            sequence: 25,
            requestParams: {'api_deck_id': '2'},
          ),
        );
      await controller.idle;
      expect(events, ['started 9001,9002', 'hp', 'hp']);

      controller
        ..accept(
          kcsapiEvent(battleResultEvent.path, {
            'api_win_rank': 'A',
          }, sequence: 26),
        )
        ..accept(
          kcsapiEvent(battleResultEvent.path, {
            'api_win_rank': 'A',
          }, sequence: 27),
        );
      await controller.idle;
      expect(events, ['started 9001,9002', 'hp', 'hp', 'settled']);
    },
  );

  group('formation memory', () {
    late GameState state;

    setUp(() {
      final reducer = GameStateReducer();
      state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
    });

    test(
      'map navigation exposes the remembered formation for the node',
      () async {
        final memory = await FormationMemoryController.load(
          MemoryFormationMemoryStore(<String, int>{'1-1-1': 5}),
        );
        final controller = BattleController(
          gameState: () => state,
          formationMemory: memory,
        );
        addTearDown(controller.dispose);

        controller.accept(mapStartEvent);
        await controller.idle;

        expect(controller.current!.lastFormation, 5);
      },
    );

    test('battle phase removes the remembered navigation formation', () async {
      final memory = await FormationMemoryController.load(
        MemoryFormationMemoryStore(<String, int>{'1-1-1': 5}),
      );
      final controller = BattleController(
        gameState: () => state,
        formationMemory: memory,
      );
      addTearDown(controller.dispose);

      controller
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent);
      await controller.idle;

      expect(controller.current!.lastFormation, isNull);
    });

    test('battle result remembers the confirmed friendly formation', () async {
      final store = MemoryFormationMemoryStore();
      final memory = await FormationMemoryController.load(store);
      final controller = BattleController(
        gameState: () => state,
        formationMemory: memory,
      );
      addTearDown(controller.dispose);

      controller
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent)
        ..accept(battleResultEvent);
      await controller.idle;

      expect(memory.formationFor(mapAreaId: 1, mapInfoNo: 1, node: 1), 1);
      expect(store.saveCount, 1);
      expect(controller.records.single.detail, isNotNull);
      expect(
        controller.records.single.detail!.stages.expand(
          (stage) => stage.attacks,
        ),
        isNotEmpty,
      );
    });

    test('practice battle result does not update formation memory', () async {
      final store = MemoryFormationMemoryStore(<String, int>{'1-1-1': 5});
      final memory = await FormationMemoryController.load(store);
      final controller = BattleController(
        gameState: () => state,
        formationMemory: memory,
      );
      addTearDown(controller.dispose);
      final battleBody = jsonDecode(dayBattleEvent.responseBody) as Map;
      final resultBody = jsonDecode(battleResultEvent.responseBody) as Map;

      controller
        ..accept(
          kcsapiEvent(
            '/kcsapi/api_req_practice/battle',
            Map<String, Object?>.from(battleBody['api_data'] as Map),
            sequence: 10001,
          ),
        )
        ..accept(
          kcsapiEvent(
            '/kcsapi/api_req_practice/battle_result',
            Map<String, Object?>.from(resultBody['api_data'] as Map),
            sequence: 10002,
          ),
        );
      await controller.idle;

      expect(store.values, <String, int>{'1-1-1': 5});
      expect(store.saveCount, 0);
    });
  });

  test('recovers after a prediction executor failure', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(
      gameState: () => state,
      predictionExecutor: const _ThrowingPredictionExecutor(),
    );
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;
    expect(controller.lastError, isNotNull);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
        'api_maparea_id': 1,
        'api_mapinfo_no': 1,
        'api_no': 2,
        'api_next': 0,
        'api_event_id': 0,
        'api_event_kind': 0,
      }, sequence: 9999),
    );
    await controller.idle;

    expect(controller.lastError, isNull);
    expect(controller.current?.displayStage, BattleDisplayStage.navigation);
  });

  test('coalesces notifications from consecutive captured events', () async {
    final scheduled = <void Function()>[];
    final controller = BattleController(
      gameState: () => GameState.empty,
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduled.add,
      ),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller
      ..accept(start2Event)
      ..accept(portEvent);
    await controller.idle;

    expect(notifications, 0);
    expect(scheduled, hasLength(1));
    scheduled.single();
    expect(notifications, 1);
  });

  test(
    'alerts once when friendly damage newly reaches moderate damage',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final alerts = _RecordingDamageAlertPort();
      final controller = BattleController(
        gameState: () => state,
        damageAlertPort: alerts,
        battleStatusEffectSettings: () => const BattleStatusEffectSettings(),
      );
      addTearDown(controller.dispose);

      controller
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent);
      await controller.idle;
      expect(alerts.alerts, isEmpty);

      controller.accept(nightBattleEvent);
      await controller.idle;

      expect(alerts.alerts, <BattleDamageAlertSeverity>[
        BattleDamageAlertSeverity.moderate,
      ]);
    },
  );

  test('does not alert in practice or while vibration is disabled', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final alerts = _RecordingDamageAlertPort();
    var settings = const BattleStatusEffectSettings(enabled: false);
    final controller = BattleController(
      gameState: () => state,
      damageAlertPort: alerts,
      battleStatusEffectSettings: () => settings,
    );
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(nightBattleEvent);
    await controller.idle;
    expect(alerts.alerts, isEmpty);

    settings = const BattleStatusEffectSettings();
    controller.accept(
      kcsapiEvent('/kcsapi/api_req_practice/battle', <String, Object?>{
        'api_deck_id': 1,
        'api_f_nowhps': <int>[-1, 30, 15],
        'api_f_maxhps': <int>[-1, 30, 15],
        'api_e_nowhps': <int>[-1, 20],
        'api_e_maxhps': <int>[-1, 20],
        'api_ship_ke': <int>[-1, 501],
        'api_hougeki1': <String, Object?>{
          'api_at_eflag': <int>[1],
          'api_at_list': <int>[0],
          'api_df_list': <Object?>[
            <int>[0],
          ],
          'api_damage': <Object?>[
            <num>[20],
          ],
        },
      }, sequence: 998),
    );
    await controller.idle;
    expect(alerts.alerts, isEmpty);
  });

  test('creates only the POI engine for every battle session', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    var poiFactoryCalls = 0;
    final controller = BattleController(
      gameState: () => state,
      poiEngineFactory:
          ({
            required friendMain,
            required friendEscort,
            required enemyMain,
            required enemyEscort,
          }) {
            poiFactoryCalls += 1;
            return _FixedRankEngine(
              rank: BattleRank.a,
              friendMain: friendMain,
              friendEscort: friendEscort,
              enemyMain: enemyMain,
              enemyEscort: enemyEscort,
            );
          },
    );
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;
    expect(controller.current!.rank, BattleRank.a);

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
    expect(controller.current!.rank, BattleRank.a);
    expect(poiFactoryCalls, 2);
  });

  test('NPC friendly attacks never reduce or publish friendly HP', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final published = <Map<int, int>>[];
    final controller = BattleController(
      gameState: () => state,
      onFriendlyHpUpdated: (hpByShipId, _) => published.add(hpByShipId),
    );
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[30, 15],
          'api_f_maxhps': <int>[30, 15],
          'api_e_nowhps': <int>[50],
          'api_e_maxhps': <int>[50],
          'api_ship_ke': <int>[501],
          'api_friendly_info': <String, Object?>{
            'api_ship_id': <int>[1001],
            'api_ship_lv': <int>[90],
            'api_nowhps': <int>[40],
            'api_maxhps': <int>[40],
          },
          'api_friendly_kouku': <String, Object?>{
            'api_stage3': <String, Object?>{
              'api_edam': <num>[12],
              'api_ebak_flag': <int>[1],
              'api_erai_flag': <int>[0],
              'api_ecl_flag': <int>[1],
              'api_fdam': <num>[9],
              'api_fbak_flag': <int>[1],
              'api_frai_flag': <int>[0],
              'api_fcl_flag': <int>[1],
            },
          },
        }, sequence: 982),
      );
    await controller.idle;

    expect(controller.current!.enemyMain.single.currentHp, 38);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_battle_midnight/battle', <String, Object?>{
        'api_friendly_info': <String, Object?>{
          'api_ship_id': <int>[1001],
          'api_ship_lv': <int>[90],
          'api_nowhps': <int>[40],
          'api_maxhps': <int>[40],
        },
        'api_friendly_battle': <String, Object?>{
          'api_hougeki': <String, Object?>{
            'api_at_list': <int>[0],
            'api_sp_list': <int>[0],
            'api_df_list': <Object?>[
              <int>[0],
            ],
            'api_damage': <Object?>[
              <num>[12],
            ],
          },
        },
      }, sequence: 983),
    );
    await controller.idle;

    expect(controller.current!.friendMain.map((ship) => ship.currentHp), <int>[
      30,
      15,
    ]);
    expect(controller.current!.enemyMain.single.currentHp, 26);
    expect(published.last, <int, int>{9001: 30, 9002: 15});
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

  test('labels an all-submarine enemy fleet as submarine battle', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer
        .reduce(state, portEvent)
        .copyWith(
          masterShips: <int, MasterShip>{
            ...state.masterShips,
            1501: const MasterShip(id: 1501, name: '潜水ヨ級', shipTypeId: 13),
            1502: const MasterShip(id: 1502, name: '伊号潜水艦', shipTypeId: 14),
          },
        );
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[30, 15],
          'api_f_maxhps': <int>[30, 15],
          'api_e_nowhps': <int>[20, 10],
          'api_e_maxhps': <int>[20, 10],
          'api_ship_ke': <int>[1501, 1502],
        }, sequence: 990),
      );
    await controller.idle;

    expect(controller.current!.context.nodeTypeLabel, '潜艇战');
  });

  test('keeps the original node type for a mixed enemy fleet', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer
        .reduce(state, portEvent)
        .copyWith(
          masterShips: <int, MasterShip>{
            ...state.masterShips,
            1501: const MasterShip(id: 1501, name: '潜水ヨ級', shipTypeId: 13),
            1601: const MasterShip(id: 1601, name: '战舰ル級', shipTypeId: 9),
          },
        );
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[30, 15],
          'api_f_maxhps': <int>[30, 15],
          'api_e_nowhps': <int>[20, 90],
          'api_e_maxhps': <int>[20, 90],
          'api_ship_ke': <int>[1501, 1601],
        }, sequence: 991),
      );
    await controller.idle;

    expect(controller.current!.context.nodeTypeLabel, '普通战斗');
  });

  test(
    'map response exposes at most three official enemy preview ships',
    () async {
      final state = GameState(
        masterShips: const <int, MasterShip>{
          1501: MasterShip(id: 1501, name: '潜水ヨ級', shipTypeId: 13),
          1502: MasterShip(id: 1502, name: '潜水カ級', shipTypeId: 13),
          1503: MasterShip(id: 1503, name: '潜水ソ級', shipTypeId: 13),
          1504: MasterShip(id: 1504, name: '潜水ロ級', shipTypeId: 13),
        },
      );
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 2,
          'api_e_deck_info': <Object?>[
            <String, Object?>{
              'api_kind': 1,
              'api_ship_ids': <int>[1501, 1502, 1503, 1504],
            },
          ],
        }, sequence: 989),
      );
      await controller.idle;

      expect(controller.current?.enemyPreviewShips, const <EnemyPreviewShip>[
        EnemyPreviewShip(masterId: 1501, name: '潜水ヨ級'),
        EnemyPreviewShip(masterId: 1502, name: '潜水カ級'),
        EnemyPreviewShip(masterId: 1503, name: '潜水ソ級'),
      ]);
      expect(controller.current?.context.nodeTypeLabel, '潜艇战');
    },
  );

  test(
    'map response exposes escort then main ships for an enemy combined fleet',
    () async {
      const state = GameState(
        masterShips: <int, MasterShip>{
          1601: MasterShip(id: 1601, name: '主力一', shipTypeId: 9),
          1602: MasterShip(id: 1602, name: '主力二', shipTypeId: 9),
          1603: MasterShip(id: 1603, name: '主力三', shipTypeId: 9),
          1701: MasterShip(id: 1701, name: '伴随一', shipTypeId: 2),
          1702: MasterShip(id: 1702, name: '伴随二', shipTypeId: 2),
          1703: MasterShip(id: 1703, name: '伴随三', shipTypeId: 2),
        },
      );
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 2,
          'api_e_deck_info': <Object?>[
            <String, Object?>{
              'api_kind': 1,
              'api_ship_ids': <int>[1601, 1602, 1603],
            },
            <String, Object?>{
              'api_kind': 2,
              'api_ship_ids': <int>[1701, 1702, 1703],
            },
          ],
        }, sequence: 990),
      );
      await controller.idle;

      expect(controller.current?.enemyPreviewShips, const <EnemyPreviewShip>[
        EnemyPreviewShip(
          masterId: 1701,
          name: '伴随一',
          fleetRole: BattleFleetRole.escort,
        ),
        EnemyPreviewShip(
          masterId: 1702,
          name: '伴随二',
          fleetRole: BattleFleetRole.escort,
        ),
        EnemyPreviewShip(
          masterId: 1703,
          name: '伴随三',
          fleetRole: BattleFleetRole.escort,
        ),
        EnemyPreviewShip(masterId: 1601, name: '主力一'),
        EnemyPreviewShip(masterId: 1602, name: '主力二'),
        EnemyPreviewShip(masterId: 1603, name: '主力三'),
      ]);
      expect(controller.current?.enemyPreviewCombined, isTrue);
    },
  );

  test(
    'combined preview preserves fleet roles when enemy master data is missing',
    () async {
      const state = GameState(
        masterShips: <int, MasterShip>{
          1601: MasterShip(id: 1601, name: '主力一', shipTypeId: 9),
          1602: MasterShip(id: 1602, name: '主力二', shipTypeId: 9),
          1603: MasterShip(id: 1603, name: '主力三', shipTypeId: 9),
          1702: MasterShip(id: 1702, name: '伴随二', shipTypeId: 2),
          1703: MasterShip(id: 1703, name: '伴随三', shipTypeId: 2),
        },
      );
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 2,
          'api_e_deck_info': <Object?>[
            <String, Object?>{
              'api_kind': 1,
              'api_ship_ids': <int>[1601, 1602, 1603],
            },
            <String, Object?>{
              'api_kind': 2,
              'api_ship_ids': <int>[1701, 1702, 1703],
            },
          ],
        }, sequence: 991),
      );
      await controller.idle;

      expect(controller.current?.enemyPreviewCombined, isTrue);
      expect(controller.current?.enemyPreviewShips, const <EnemyPreviewShip>[
        EnemyPreviewShip(
          masterId: 1702,
          name: '伴随二',
          fleetRole: BattleFleetRole.escort,
        ),
        EnemyPreviewShip(
          masterId: 1703,
          name: '伴随三',
          fleetRole: BattleFleetRole.escort,
        ),
        EnemyPreviewShip(masterId: 1601, name: '主力一'),
        EnemyPreviewShip(masterId: 1602, name: '主力二'),
        EnemyPreviewShip(masterId: 1603, name: '主力三'),
      ]);
    },
  );

  test('map next exposes land-base raid result in the forecast', () async {
    const state = GameState(
      landBases: <LandBaseState>[
        LandBaseState(areaId: 47, baseId: 1, name: '第一基地航空队'),
        LandBaseState(areaId: 47, baseId: 2, name: '第二基地航空队'),
      ],
    );
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
        'api_maparea_id': 47,
        'api_mapinfo_no': 1,
        'api_no': 4,
        'api_destruction_battle': <String, Object?>{
          'api_f_nowhps': <int>[200, 200],
          'api_f_maxhps': <int>[200, 200],
          'api_air_base_attack': <String, Object?>{
            'api_stage3': <String, Object?>{
              'api_fdam': <num>[48.9, 24.1],
            },
          },
        },
      }, sequence: 990),
    );
    await controller.idle;

    expect(controller.current?.phaseLabel, '基地空袭');
    expect(controller.current?.landBaseRaid?.bases, hasLength(2));
    expect(controller.current?.landBaseRaid?.bases.first.name, '第一基地航空队');
    expect(controller.current?.landBaseRaid?.bases.first.currentHp, 152);
    expect(controller.current?.landBaseRaid?.bases.first.damage, 48);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
        'api_maparea_id': 47,
        'api_mapinfo_no': 1,
        'api_no': 5,
      }, sequence: 991),
    );
    await controller.idle;

    expect(controller.current?.landBaseRaid, isNull);
  });

  test(
    'map next exposes a zero-damage land-base raid without stage3',
    () async {
      const state = GameState(
        landBases: <LandBaseState>[
          LandBaseState(areaId: 62, baseId: 1, name: '第一基地航空队'),
        ],
      );
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 62,
          'api_mapinfo_no': 1,
          'api_no': 19,
          'api_destruction_battle': <String, Object?>{
            'api_f_nowhps': <int>[200],
            'api_f_maxhps': <int>[200],
            'api_air_base_attack': <String, Object?>{
              'api_stage_flag': <int>[1, 0, 0],
              'api_stage1': <String, Object?>{'api_disp_seiku': 1},
            },
          },
        }, sequence: 992),
      );
      await controller.idle;

      expect(controller.current?.phaseLabel, '基地空袭');
      expect(controller.current?.landBaseRaid?.bases, hasLength(1));
      expect(controller.current?.landBaseRaid?.bases.single.currentHp, 200);
      expect(controller.current?.landBaseRaid?.bases.single.damage, 0);
      expect(controller.current?.landBaseRaid?.airSuperiority, '确保');
    },
  );

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
    expect(
      controller.records.single.battle.rewardItems,
      const <BattleRewardItem>[
        BattleRewardItem(
          kind: BattleRewardKind.item,
          id: 44,
          count: 1,
          name: '家具コイン',
        ),
      ],
    );
    expect(controller.records.single.battle.mvpPositions, <int>[0]);
  });

  test(
    'combines normal and multiple event rewards without overwriting',
    () async {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent)
        ..accept(
          kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
            'api_win_rank': 'S',
            'api_get_useitem': <String, Object?>{
              'api_useitem_id': 68,
              'api_useitem_name': '秋刀魚',
            },
            'api_get_exmap_useitem_id': 61,
            'api_get_ship': <String, Object?>{'api_ship_id': 101},
            'api_get_eventitem': <Object?>[
              <String, Object?>{'api_type': 1, 'api_id': 57, 'api_value': 1},
              <String, Object?>{'api_type': 3, 'api_id': 201, 'api_value': 2},
              <String, Object?>{'api_type': 2, 'api_id': 102, 'api_value': 1},
              <String, Object?>{'api_type': 2, 'api_id': 103, 'api_value': 1},
            ],
          }, sequence: 222),
        );
      await controller.idle;

      final battle = controller.current!;
      expect(battle.dropShipMasterId, 101);
      expect(battle.dropShipMasterIds, const <int>[101, 102, 103]);
      expect(battle.rewardItems, const <BattleRewardItem>[
        BattleRewardItem(
          kind: BattleRewardKind.item,
          id: 68,
          count: 1,
          name: '秋刀鱼',
        ),
        BattleRewardItem(
          kind: BattleRewardKind.item,
          id: 61,
          count: 1,
          name: '甲种勋章',
        ),
        BattleRewardItem(
          kind: BattleRewardKind.item,
          id: 57,
          count: 1,
          name: '勋章',
        ),
        BattleRewardItem(
          kind: BattleRewardKind.equipment,
          id: 201,
          count: 2,
          name: '12.7cm 连装炮',
        ),
      ]);
    },
  );

  test('records string extra-map useitem reward from sortie result', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
          'api_win_rank': 'S',
          'api_get_exmap_useitem_id': '57',
        }, sequence: 223),
      );
    await controller.idle;

    expect(controller.current!.rewardItems, const <BattleRewardItem>[
      BattleRewardItem(
        kind: BattleRewardKind.item,
        id: 57,
        count: 1,
        name: '勋章',
      ),
    ]);
  });

  test(
    'records numeric extra-map useitem reward from combined result',
    () async {
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
          kcsapiEvent(
            '/kcsapi/api_req_combined_battle/battle',
            <String, Object?>{
              'api_deck_id': 1,
              'api_f_nowhps': <int>[-1, 30, 15],
              'api_f_maxhps': <int>[-1, 30, 15],
              'api_f_nowhps_combined': <int>[-1, 15],
              'api_f_maxhps_combined': <int>[-1, 15],
              'api_e_nowhps': <int>[-1, 20],
              'api_e_maxhps': <int>[-1, 20],
              'api_ship_ke': <int>[-1, 501],
            },
            sequence: 224,
          ),
        )
        ..accept(
          kcsapiEvent(
            '/kcsapi/api_req_combined_battle/battleresult',
            <String, Object?>{
              'api_win_rank': 'S',
              'api_get_exmap_useitem_id': 57,
            },
            sequence: 225,
          ),
        );
      await controller.idle;

      expect(
        controller.current!.context.combinedFleetType,
        CombinedFleetType.surfaceTaskForce,
      );
      expect(controller.current!.friendEscort, hasLength(1));
      expect(controller.current!.rewardItems.single.id, 57);
      expect(controller.current!.rewardItems.single.name, '勋章');
    },
  );

  test('ignores invalid extra-map useitem reward ids', () async {
    final invalidIds = <Object?>[null, '', 0, -1, 'not-a-number'];

    for (var index = 0; index < invalidIds.length; index++) {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      final controller = BattleController(gameState: () => state);

      controller
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent)
        ..accept(
          kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
            'api_win_rank': 'S',
            'api_get_exmap_useitem_id': invalidIds[index],
          }, sequence: 225 + index),
        );
      await controller.idle;

      expect(
        controller.current!.rewardItems,
        isEmpty,
        reason: 'invalid id ${invalidIds[index]} must be ignored',
      );
      controller.dispose();
    }
  });

  test('map itemget exposes one signed resource group and map items', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
        'api_maparea_id': 2,
        'api_mapinfo_no': 2,
        'api_no': 3,
        'api_event_id': 2,
        'api_itemget': <Object?>[
          <String, Object?>{'api_usemst': 4, 'api_id': 1, 'api_getcount': 80},
          <String, Object?>{'api_usemst': 4, 'api_id': 2, 'api_getcount': 30},
          <String, Object?>{
            'api_usemst': 11,
            'api_id': 11,
            'api_getcount': 1,
            'api_name': '家具箱（中）',
          },
        ],
        'api_itemget_eo_comment': <String, Object?>{
          'api_usemst': 4,
          'api_id': 3,
          'api_getcount': 15,
        },
      }, sequence: 223),
    );
    await controller.idle;

    expect(controller.current!.resourceChanges, const <BattleResourceChange>[
      BattleResourceChange(type: GameResourceType.fuel, amount: 80),
      BattleResourceChange(type: GameResourceType.ammunition, amount: 30),
      BattleResourceChange(type: GameResourceType.steel, amount: 15),
    ]);
    expect(controller.current!.rewardItems, const <BattleRewardItem>[
      BattleRewardItem(
        kind: BattleRewardKind.item,
        id: 11,
        count: 1,
        name: '家具箱（中）',
      ),
    ]);
  });

  test(
    'map happening exposes a negative radar-reduced resource change',
    () async {
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_map/start', <String, Object?>{
          'api_maparea_id': 3,
          'api_mapinfo_no': 2,
          'api_no': 4,
          'api_event_id': 3,
          'api_happening': <String, Object?>{
            'api_icon_id': 2,
            'api_count': 24,
            'api_dentan': 1,
          },
        }, sequence: 224),
      );
      await controller.idle;

      expect(controller.current!.resourceChanges, const <BattleResourceChange>[
        BattleResourceChange(
          type: GameResourceType.ammunition,
          amount: -24,
          radarReduced: true,
        ),
      ]);
    },
  );

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

  test('night battle preserves daytime air superiority', () async {
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
          'api_kouku': <String, Object?>{
            'api_stage1': <String, Object?>{'api_disp_seiku': 2},
          },
        }, sequence: 78),
      );
    await controller.idle;
    expect(controller.current!.airSuperiority, '优势');

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
      }, sequence: 79),
    );
    await controller.idle;

    expect(controller.current!.phaseLabel, '夜战');
    expect(controller.current!.airSuperiority, '优势');

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
        'api_win_rank': 'S',
      }, sequence: 80),
    );
    await controller.idle;

    expect(controller.records.single.battle.airSuperiority, '优势');
  });

  test('night-only battle keeps air superiority unknown', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    controller
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_battle_midnight/battle', <String, Object?>{
          'api_hougeki': <String, Object?>{
            'api_at_eflag': <int>[],
            'api_at_list': <int>[],
            'api_df_list': <Object?>[],
            'api_damage': <Object?>[],
          },
        }, sequence: 81),
      );
    await controller.idle;

    expect(controller.current!.airSuperiority, '未知');
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
    'third fleet sortie stays a seven-ship striking force while fleets one and two are combined',
    () async {
      final state = _strikingForceStateWithCombinedFleet();
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_map/start',
          <String, Object?>{
            'api_maparea_id': 1,
            'api_mapinfo_no': 1,
            'api_no': 1,
          },
          sequence: 300,
          requestParams: <String, Object?>{'api_deck_id': '3'},
        ),
      );
      await controller.idle;

      expect(controller.current!.context.deckId, 3);
      expect(
        controller.current!.context.combinedFleetType,
        CombinedFleetType.none,
      );
      expect(controller.current!.friendMain, hasLength(7));
      expect(controller.current!.friendEscort, isEmpty);
    },
  );

  test(
    'enemy damage to position seven stays on the third-fleet striking force',
    () async {
      final state = _strikingForceStateWithCombinedFleet();
      final controller = BattleController(gameState: () => state);
      addTearDown(controller.dispose);

      controller
        ..accept(
          kcsapiEvent(
            '/kcsapi/api_req_map/start',
            <String, Object?>{
              'api_maparea_id': 1,
              'api_mapinfo_no': 1,
              'api_no': 1,
            },
            sequence: 301,
            requestParams: <String, Object?>{'api_deck_id': '3'},
          ),
        )
        ..accept(
          kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
            'api_deck_id': 3,
            'api_f_nowhps': <int>[-1, 33, 33, 33, 33, 33, 33, 33],
            'api_f_maxhps': <int>[-1, 33, 33, 33, 33, 33, 33, 33],
            'api_e_nowhps': <int>[-1, 20],
            'api_e_maxhps': <int>[-1, 20],
            'api_ship_ke': <int>[-1, 501],
            'api_hougeki1': <String, Object?>{
              'api_at_eflag': <int>[1],
              'api_at_list': <int>[0],
              'api_df_list': <Object?>[
                <int>[6],
              ],
              'api_damage': <Object?>[
                <num>[17],
              ],
            },
          }, sequence: 302),
        );
      await controller.idle;

      expect(controller.current!.friendEscort, isEmpty);
      expect(controller.current!.friendMain[6].currentHp, 16);
      expect(controller.current!.friendMain[6].damageReceived, 17);
    },
  );

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
        controller
          ..accept(mapStartEvent)
          ..accept(kcsapiEvent(scenario.$1, untouchedBattle(), sequence: 33));
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

  test('practice resets map and node context from previous sortie', () async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    // Sortie to 7-1 node 3
    controller.accept(
      kcsapiEvent('/kcsapi/api_req_map/start', <String, Object?>{
        'api_maparea_id': 7,
        'api_mapinfo_no': 1,
        'api_no': 3,
        'api_bosscell_no': 5,
        'api_event_id': 4,
        'api_event_kind': 1,
      }, sequence: 80),
    );
    await controller.idle;
    expect(controller.current!.context.mapAreaId, 7);
    expect(controller.current!.context.mapInfoNo, 1);
    expect(controller.current!.context.node, 3);
    expect(controller.current!.context.practice, isFalse);

    // Return to port
    controller.accept(
      kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{}, sequence: 81),
    );
    await controller.idle;

    // Start practice battle
    controller.accept(
      kcsapiEvent('/kcsapi/api_req_practice/battle', <String, Object?>{
        'api_deck_id': 1,
        'api_f_nowhps': <int>[-1, 30, 15],
        'api_f_maxhps': <int>[-1, 30, 15],
        'api_e_nowhps': <int>[-1, 20],
        'api_e_maxhps': <int>[-1, 20],
        'api_ship_ke': <int>[-1, 501],
      }, sequence: 82),
    );
    await controller.idle;

    expect(controller.current!.context.practice, isTrue);
    expect(controller.current!.context.mapAreaId, 0);
    expect(controller.current!.context.mapInfoNo, 0);
    expect(controller.current!.context.node, 0);
    expect(controller.current!.context.nodeTypeLabel, '普通战斗');
    expect(controller.current!.context.mapLabel, '演习');
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

final class _RecordingDamageAlertPort implements BattleDamageAlertPort {
  final List<BattleDamageAlertSeverity> alerts = <BattleDamageAlertSeverity>[];

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {
    alerts.add(severity);
  }
}

final class _ThrowingPredictionExecutor implements BattlePredictionExecutor {
  const _ThrowingPredictionExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async {
    throw StateError('prediction failed');
  }
}

GameState _strikingForceStateWithCombinedFleet() {
  final ships = <int, OwnedShip>{
    101: const OwnedShip(
      id: 101,
      masterId: 101,
      level: 1,
      currentHp: 33,
      maxHp: 33,
    ),
    201: const OwnedShip(
      id: 201,
      masterId: 201,
      level: 1,
      currentHp: 33,
      maxHp: 33,
    ),
    for (var index = 0; index < 7; index++)
      301 + index: OwnedShip(
        id: 301 + index,
        masterId: 301 + index,
        level: 1,
        currentHp: 33,
        maxHp: 33,
      ),
  };
  return GameState(
    ships: ships,
    fleets: <Fleet>[
      const Fleet(id: 1, name: 'Fleet 1', shipIds: <int>[101]),
      const Fleet(id: 2, name: 'Fleet 2', shipIds: <int>[201]),
      Fleet(
        id: 3,
        name: 'Striking Force',
        shipIds: <int>[for (var index = 0; index < 7; index++) 301 + index],
        slotCount: 7,
      ),
    ],
    combinedFleetType: CombinedFleetType.surfaceTaskForce,
  );
}

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
