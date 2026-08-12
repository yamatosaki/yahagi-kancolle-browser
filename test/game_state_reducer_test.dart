import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/fleet_metrics.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  group('GameStateReducer', () {
    test('start2 followed by port builds a linked game state', () {
      final reducer = GameStateReducer();

      var state = reducer.reduce(GameState.empty, start2Event);
      state = reducer.reduce(state, portEvent);
      state = reducer.reduce(state, slotItemEvent);

      expect(state.hasMasterData, isTrue);
      expect(state.hasPortData, isTrue);
      expect(state.admiralLevel, 120);
      expect(state.resource(GameResourceType.fuel), 123260);
      expect(state.resource(GameResourceType.improvementMaterial), 24);
      expect(state.fleets, hasLength(4));
      expect(state.fleets.first.shipIds, <int>[9001, 9002]);
      expect(state.fleets.first.slotCount, 6);
      expect(state.masterShips[state.ships[9001]!.masterId]!.name, '夕張');
      expect(state.repairDocks.first.shipId, 9002);
      expect(
        state.equipmentForShip(state.ships[9001]!).first.master?.name,
        '12.7cm 连装炮',
      );
      final gun = state.masterSlotItems[201]!;
      expect(gun.firepower, 3);
      expect(gun.antiAir, 2);
      expect(gun.accuracy, 1);
      expect(gun.range, 1);
      expect(state.masterShips[101]?.portraitVersion, '7');
      expect(state.masterShips[101]?.classTypeId, 34);
      expect(state.masterShips[101]?.buildTimeMinutes, 60);
      expect(state.masterShips[101]?.slotCount, 4);
      expect(state.masterMissions[5]?.name, '海上護衛任務');
      expect(state.masterMissions[5]?.duration, const Duration(minutes: 90));
      expect(state.masterMissions[5]?.displayNumber, '05');
      expect(state.masterMissions[5]?.fuelConsumptionPercent, 50);
      expect(state.masterMissions[5]?.ammunitionConsumptionPercent, 0);
      expect(state.mapName(2, 3), '东部奥廖尔海');
      expect(state.ships[9002]?.repairDurationMilliseconds, 5400000);
      expect(state.ships[9001]?.armor, 46);
      expect(state.ships[9001]?.evasion, 80);
      expect(state.ships[9001]?.luck, 41);
      expect(state.ships[9001]?.speed, 15);
      expect(state.repairDocks.first.fuelCost, 24);
      expect(state.repairDocks.first.steelCost, 46);
      expect(state.constructionDocks, hasLength(4));
      expect(state.constructionDocks.first.createdShipMasterId, 101);
      expect(state.constructionDocks[2].isLargeConstruction, isTrue);
      expect(state.constructionDocks[3].isLocked, isTrue);
      expect(state.serverOrigin, 'https://w01y.kancolle-server.com');
      expect(state.ships[9001]?.range, 4);
    });

    test('material update changes only resources', () {
      final reducer = GameStateReducer();
      final initial = reducer.reduce(
        reducer.reduce(GameState.empty, start2Event),
        portEvent,
      );
      final updated = reducer.reduce(
        initial,
        kcsapiEvent('/kcsapi/api_get_member/material', <Object?>[
          <String, Object?>{'api_id': 1, 'api_value': 999},
        ]),
      );

      expect(updated.resource(GameResourceType.fuel), 999);
      expect(updated.resource(GameResourceType.ammunition), 138649);
      expect(updated.ships, same(initial.ships));
      expect(updated.fleets, same(initial.fleets));
    });

    test('map metadata keeps operation title and selected difficulty', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
          'api_mst_mapinfo': <Object?>[
            <String, Object?>{
              'api_id': 622,
              'api_maparea_id': 62,
              'api_no': 2,
              'api_name': '南沙諸島沖',
              'api_opetext': 'オルモック沖/サンベルナルジノ海峡沖',
            },
          ],
        }),
      );

      expect(state.mapName(62, 2), '南沙諸島沖/オルモック沖/サンベルナルジノ海峡沖');

      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/mapinfo', <String, Object?>{
          'api_map_info': <Object?>[
            <String, Object?>{
              'api_id': 622,
              'api_eventmap': <String, Object?>{'api_selected_rank': 3},
            },
          ],
        }),
      );

      expect(state.mapDifficulty(62, 2), 3);
    });

    test('useitem endpoint captures special item counts', () {
      final state = GameStateReducer().reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_get_member/useitem', <Object?>[
          <String, Object?>{'api_id': 54, 'api_count': 7},
          <String, Object?>{'api_id': 68, 'api_count': 19},
        ]),
      );

      expect(state.hasUseItemData, isTrue);
      expect(state.useItemCount(54), 7);
      expect(state.useItemCount(68), 19);
      expect(state.useItemCount(61), 0);
    });

    test('require info captures embedded special item counts', () {
      final state = GameStateReducer().reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_get_member/require_info', <String, Object?>{
          'api_useitem': <Object?>[
            <String, Object?>{'api_id': 61, 'api_count': 2},
          ],
        }),
      );

      expect(state.hasUseItemData, isTrue);
      expect(state.useItemCount(61), 2);
    });

    test('mapinfo captures land bases and map next applies raid damage', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_get_member/mapinfo', <String, Object?>{
          'api_map_info': const <Object?>[],
          'api_air_base': <Object?>[
            <String, Object?>{
              'api_area_id': 47,
              'api_rid': 1,
              'api_name': '第一基地航空队',
              'api_action_kind': 1,
            },
            <String, Object?>{
              'api_area_id': 47,
              'api_rid': 2,
              'api_name': '第二基地航空队',
              'api_action_kind': 2,
            },
            <String, Object?>{
              'api_area_id': 6,
              'api_rid': 1,
              'api_name': '其他海域基地',
              'api_action_kind': 0,
            },
          ],
        }),
      );

      expect(state.landBases, hasLength(3));
      final firstBase = state.landBases.firstWhere(
        (base) => base.areaId == 47 && base.baseId == 1,
      );
      expect(firstBase.name, '第一基地航空队');
      expect(firstBase.actionKind, 1);

      state = reducer.reduce(
        state,
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
        }),
      );

      final raidedBases = state.landBases
          .where((base) => base.areaId == 47)
          .toList();
      final otherArea = state.landBases.singleWhere((base) => base.areaId == 6);
      expect(raidedBases[0].currentHp, 152);
      expect(raidedBases[0].maxHp, 200);
      expect(raidedBases[0].lastRaidDamage, 48);
      expect(raidedBases[1].currentHp, 176);
      expect(raidedBases[1].lastRaidDamage, 24);
      expect(otherArea.currentHp, isNull);
    });

    test('land-base raid accepts nested JSON and port clears transient hp', () {
      final reducer = GameStateReducer();
      var state = const GameState(
        landBases: <LandBaseState>[
          LandBaseState(areaId: 47, baseId: 1, name: '第一基地航空队'),
        ],
      );

      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 47,
          'api_mapinfo_no': 1,
          'api_no': 4,
          'api_destruction_battle': <String, Object?>{
            'api_f_nowhps': <int>[200],
            'api_f_maxhps': <int>[200],
            'api_air_base_attack': '{"api_stage3":{"api_fdam":[48.9]}}',
          },
        }),
      );

      expect(state.landBases.single.currentHp, 152);
      expect(state.landBases.single.lastRaidDamage, 48);

      state = reducer.reduce(state, portEvent);

      expect(state.landBases.single.currentHp, isNull);
      expect(state.landBases.single.maxHp, isNull);
      expect(state.landBases.single.lastRaidDamage, 0);
    });

    test('land-base raid records zero damage when stage3 is absent', () {
      final reducer = GameStateReducer();
      var state = const GameState(
        landBases: <LandBaseState>[
          LandBaseState(areaId: 62, baseId: 1, name: '第一基地航空队'),
        ],
      );

      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 62,
          'api_mapinfo_no': 1,
          'api_no': 19,
          'api_destruction_battle': <String, Object?>{
            'api_f_nowhps': <int>[200],
            'api_f_maxhps': <int>[200],
            'api_air_base_attack': <String, Object?>{
              'api_stage_flag': <int>[1, 0, 0],
              'api_stage1': <String, Object?>{'api_disp_seiku': 3},
            },
          },
        }),
      );

      expect(state.landBases.single.maxHp, 200);
      expect(state.landBases.single.currentHp, 200);
      expect(state.landBases.single.lastRaidDamage, 0);
    });

    test(
      'formation change removes a ship immediately without a port refresh',
      () {
        final reducer = GameStateReducer();
        var state = reducer.reduce(
          reducer.reduce(GameState.empty, start2Event),
          portEvent,
        );

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_hensei/change',
            null,
            includeApiData: false,
            requestParams: const <String, Object?>{
              'api_id': '1',
              'api_ship_idx': '1',
              'api_ship_id': '-1',
            },
          ),
        );

        expect(state.fleets.first.shipIds, <int>[9001]);
      },
    );

    test(
      'formation change moves and swaps ships between fleets immediately',
      () {
        final reducer = GameStateReducer();
        var state = reducer.reduce(
          reducer.reduce(GameState.empty, start2Event),
          portEvent,
        );
        state = reducer.reduce(
          state,
          kcsapiEvent('/kcsapi/api_get_member/deck', <Object?>[
            <String, Object?>{
              'api_id': 1,
              'api_name': '第一舰队',
              'api_ship': <int>[9001, -1, -1, -1, -1, -1],
              'api_mission': <int>[0, 0, 0, 0],
            },
            <String, Object?>{
              'api_id': 2,
              'api_name': '第二舰队',
              'api_ship': <int>[9002, -1, -1, -1, -1, -1],
              'api_mission': <int>[0, 0, 0, 0],
            },
          ]),
        );

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_hensei/change',
            null,
            includeApiData: false,
            requestParams: const <String, Object?>{
              'api_id': '1',
              'api_ship_idx': '0',
              'api_ship_id': '9002',
            },
          ),
        );

        expect(state.fleets[0].shipIds, <int>[9002]);
        expect(state.fleets[1].shipIds, <int>[9001]);
      },
    );

    test('formation preset replaces its fleet immediately', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        reducer.reduce(GameState.empty, start2Event),
        portEvent,
      );

      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_hensei/preset_select', <String, Object?>{
          'api_id': 1,
          'api_name': '第一舰队',
          'api_ship': <int>[9002, -1, -1, -1, -1, -1],
          'api_mission': <int>[0, 0, 0, 0],
        }),
      );

      expect(state.fleets.first.shipIds, <int>[9002]);
    });

    test(
      'incremental member endpoints replace only their owned collection',
      () {
        final reducer = GameStateReducer();
        var state = reducer.reduce(
          reducer.reduce(GameState.empty, start2Event),
          portEvent,
        );
        final originalResources = state.resources;

        state = reducer.reduce(
          state,
          kcsapiEvent('/kcsapi/api_get_member/deck', <Object?>[
            <String, Object?>{
              'api_id': 1,
              'api_name': '更新后的第一舰队',
              'api_ship': <int>[9001, -1],
              'api_mission': <int>[0, 0, 0, 0],
            },
          ]),
        );
        state = reducer.reduce(
          state,
          kcsapiEvent('/kcsapi/api_get_member/ship2', <String, Object?>{
            'api_ship_data': <Object?>[
              <String, Object?>{
                'api_id': 9001,
                'api_ship_id': 101,
                'api_lv': 51,
                'api_nowhp': 30,
                'api_maxhp': 30,
              },
            ],
            'api_deck_data': <Object?>[
              <String, Object?>{
                'api_id': 1,
                'api_name': '更新后的第一舰队',
                'api_ship': <int>[9001, -1],
                'api_mission': <int>[0, 0, 0, 0],
              },
            ],
          }),
        );
        state = reducer.reduce(state, slotItemEvent);
        state = reducer.reduce(
          state,
          kcsapiEvent('/kcsapi/api_get_member/ndock', <Object?>[
            <String, Object?>{
              'api_id': 1,
              'api_state': 0,
              'api_ship_id': 0,
              'api_complete_time': 0,
            },
          ]),
        );
        state = reducer.reduce(
          state,
          kcsapiEvent('/kcsapi/api_get_member/kdock', <Object?>[
            <String, Object?>{
              'api_id': 1,
              'api_state': 0,
              'api_created_ship_id': 0,
              'api_complete_time': 0,
              'api_item1': 0,
              'api_item2': 0,
              'api_item3': 0,
              'api_item4': 0,
              'api_item5': 0,
            },
          ]),
        );

        expect(state.fleets.single.name, '更新后的第一舰队');
        expect(state.ships[9001]?.level, 51);
        expect(state.slotItems, hasLength(4));
        expect(state.repairDocks.single.isRepairing, isFalse);
        expect(state.constructionDocks.single.isBuilding, isFalse);
        expect(state.resources, same(originalResources));
      },
    );

    test('unknown paths preserve the same state instance', () {
      final reducer = GameStateReducer();
      final state = reducer.reduce(GameState.empty, portEvent);

      final result = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_member/unknown', <String, Object?>{}),
      );

      expect(result, same(state));
    });

    test('tracks combined fleet type from port and formation changes', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_combined_flag': 1,
        }),
      );

      expect(state.combinedFleetType, CombinedFleetType.carrierTaskForce);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_hensei/combined',
          const <String, Object?>{},
          requestParams: const <String, Object?>{'api_combined_type': '2'},
        ),
      );
      expect(state.combinedFleetType, CombinedFleetType.surfaceTaskForce);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_hensei/combined',
          const <String, Object?>{},
          requestParams: const <String, Object?>{'api_combined_type': '0'},
        ),
      );
      expect(state.combinedFleetType, CombinedFleetType.none);
    });

    test('records construction start only from a create response', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        reducer.reduce(GameState.empty, start2Event),
        portEvent,
      );
      expect(state.constructionDocks.first.startedAt, isNull);

      final startedAt = DateTime.utc(2026, 7, 30, 10);
      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_kousyou/createship',
          <String, Object?>{
            'api_kdock': <String, Object?>{
              'api_id': 1,
              'api_state': 2,
              'api_created_ship_id': 101,
              'api_complete_time': 1785412800000,
              'api_item1': 30,
              'api_item2': 30,
              'api_item3': 30,
              'api_item4': 30,
              'api_item5': 1,
            },
          },
          requestParams: const <String, Object?>{'api_kdock_id': 1},
          capturedAt: startedAt,
        ),
      );

      expect(state.constructionDocks.first.startedAt, startedAt);
      expect(state.constructionDocks, hasLength(4));
    });

    test('charge updates resources and supplied ships immediately', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, portEvent);

      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_req_hokyu/charge', <String, Object?>{
          'api_material': <int>[120000, 130000, 220000, 74000],
          'api_ship': <Object?>[
            <String, Object?>{
              'api_id': 9001,
              'api_fuel': 30,
              'api_bull': 40,
              'api_onslot': <int>[0, 2, 0],
            },
          ],
        }),
      );

      expect(state.ships[9001]?.currentFuel, 30);
      expect(state.ships[9001]?.currentAmmo, 40);
      expect(state.ships[9001]?.level, 50);
      expect(state.resource(GameResourceType.fuel), 120000);
      expect(state.resource(GameResourceType.bauxite), 74000);
      expect(state.resource(GameResourceType.instantBuild), 799);
    });

    test('mission start marks the selected fleet active immediately', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, portEvent);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_mission/start',
          const <String, Object?>{'api_complatetime': 1785416400000},
          requestParams: const <String, Object?>{
            'api_deck_id': '3',
            'api_mission_id': '5',
          },
        ),
      );

      final fleet = state.fleets.firstWhere((fleet) => fleet.id == 3);
      expect(fleet.mission.isActive, isTrue);
      expect(fleet.mission.missionId, 5);
      expect(
        fleet.mission.completionTime,
        DateTime.fromMillisecondsSinceEpoch(1785416400000, isUtc: true),
      );
    });

    test('instant repair clears the dock and restores ship hp immediately', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, portEvent);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_nyukyo/speedchange',
          const <String, Object?>{},
          includeApiData: false,
          requestParams: const <String, Object?>{'api_ndock_id': '1'},
        ),
      );

      expect(state.repairDocks.first.isRepairing, isFalse);
      expect(state.ships[9002]?.currentHp, state.ships[9002]?.maxHp);
      expect(state.resource(GameResourceType.instantRepair), 707);
    });

    test(
      'repair start updates dock and resource costs without port refresh',
      () {
        final reducer = GameStateReducer();
        var state = reducer.reduce(GameState.empty, portEvent);
        state = reducer.reduce(
          state,
          kcsapiEvent('/kcsapi/api_get_member/ship2', <Object?>[
            <String, Object?>{
              'api_id': 9002,
              'api_ship_id': 102,
              'api_lv': 44,
              'api_nowhp': 8,
              'api_maxhp': 15,
              'api_cond': 32,
              'api_fuel': 8,
              'api_bull': 10,
              'api_slot': <int>[7003, -1],
              'api_onslot': <int>[0, 0],
              'api_ndock_time': 5400000,
              'api_ndock_item': <int>[24, 0, 46, 0],
            },
          ]),
        );

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_nyukyo/start',
            const <String, Object?>{},
            includeApiData: false,
            requestParams: const <String, Object?>{
              'api_ndock_id': '2',
              'api_ship_id': '9002',
              'api_highspeed': '0',
            },
          ),
        );

        expect(state.repairDocks[1].shipId, 9002);
        expect(state.repairDocks[1].isRepairing, isTrue);
        expect(state.repairDocks[1].fuelCost, 24);
        expect(state.repairDocks[1].steelCost, 46);
        expect(state.resource(GameResourceType.fuel), 123236);
        expect(state.resource(GameResourceType.steel), 220204);
      },
    );

    test('instant construction marks its dock completed immediately', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, portEvent);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_kousyou/createship_speedchange',
          const <String, Object?>{},
          requestParams: const <String, Object?>{'api_kdock_id': '1'},
        ),
      );

      expect(state.constructionDocks.first.state, 3);
      expect(
        state.constructionDocks.first.isCompletedAt(DateTime.utc(2026)),
        isTrue,
      );
      expect(state.resource(GameResourceType.instantBuild), 798);
    });

    test('getship adds the ship and equipment and clears the dock', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, portEvent);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_kousyou/getship',
          <String, Object?>{
            'api_ship': <String, Object?>{
              'api_id': 9003,
              'api_ship_id': 101,
              'api_lv': 1,
              'api_nowhp': 30,
              'api_maxhp': 30,
              'api_cond': 40,
              'api_fuel': 15,
              'api_bull': 20,
              'api_slot': <int>[7100, -1, -1],
              'api_onslot': <int>[0, 0, 0],
            },
            'api_slotitem': <Object?>[
              <String, Object?>{
                'api_id': 7100,
                'api_slotitem_id': 201,
                'api_level': 0,
                'api_alv': 0,
              },
            ],
            'api_kdock': <Object?>[
              <String, Object?>{
                'api_id': 1,
                'api_state': 0,
                'api_created_ship_id': 0,
                'api_complete_time': 0,
                'api_item1': 0,
                'api_item2': 0,
                'api_item3': 0,
                'api_item4': 0,
                'api_item5': 0,
              },
            ],
          },
          requestParams: const <String, Object?>{'api_kdock_id': '1'},
        ),
      );

      expect(state.ships[9003]?.level, 1);
      expect(state.slotItems[7100]?.masterId, 201);
      expect(state.constructionDocks.first.isBuilding, isFalse);
    });

    test('slot exchange replaces the changed ship immediately', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, portEvent);
      final original = state.ships[9001]!;

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_kaisou/slot_exchange_index',
          <String, Object?>{
            'api_ship_data': <String, Object?>{
              'api_id': original.id,
              'api_ship_id': original.masterId,
              'api_lv': original.level,
              'api_nowhp': original.currentHp,
              'api_maxhp': original.maxHp,
              'api_cond': original.condition,
              'api_fuel': original.currentFuel,
              'api_bull': original.currentAmmo,
              'api_slot': <int>[7002, 7001, 7004],
              'api_onslot': original.onSlot,
            },
          },
        ),
      );

      expect(state.ships[9001]?.slotIds, <int>[7002, 7001, 7004]);
      expect(state.ships[9002]?.level, 44);
    });

    test(
      'equipment changes update slots before the following ship3 refresh',
      () {
        final reducer = GameStateReducer();
        var state = reducer.reduce(GameState.empty, portEvent);

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_kaisou/slotset',
            const <String, Object?>{},
            requestParams: const <String, Object?>{
              'api_id': '9002',
              'api_item_id': '7999',
              'api_slot_idx': '1',
            },
          ),
        );
        expect(state.ships[9002]?.slotIds, <int>[7003, 7999]);

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_kaisou/slotset_ex',
            const <String, Object?>{},
            requestParams: const <String, Object?>{
              'api_id': '9002',
              'api_item_id': '7998',
            },
          ),
        );
        expect(state.ships[9002]?.extraSlotId, 7998);

        state = reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_kaisou/unsetslot_all',
            const <String, Object?>{},
            requestParams: const <String, Object?>{'api_id': '9002'},
          ),
        );
        expect(state.ships[9002]?.slotIds, <int>[-1, -1]);
        expect(state.ships[9002]?.extraSlotId, 7998);
      },
    );

    test('ship3 speed refresh immediately changes the whole fleet speed', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        reducer.reduce(GameState.empty, start2Event),
        portEvent,
      );
      expect(
        FleetMetrics.fromState(state, state.fleets.first).speedLabel,
        '高速',
      );

      final previous = state.ships[9002]!;
      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/ship3', <String, Object?>{
          'api_ship_data': <Object?>[
            <String, Object?>{
              'api_id': previous.id,
              'api_ship_id': previous.masterId,
              'api_lv': previous.level,
              'api_nowhp': previous.currentHp,
              'api_maxhp': previous.maxHp,
              'api_cond': previous.condition,
              'api_fuel': previous.currentFuel,
              'api_bull': previous.currentAmmo,
              'api_soku': 15,
              'api_slot': previous.slotIds,
              'api_onslot': previous.onSlot,
              'api_slot_ex': previous.extraSlotId,
            },
          ],
        }),
      );

      expect(state.ships[9002]?.speed, 15);
      expect(
        FleetMetrics.fromState(state, state.fleets.first).speedLabel,
        '高速+',
      );
    });

    test('merges accepted quests and preserves server progress bands', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        GameState.empty,
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          <String, Object?>{
            'api_count': 3,
            'api_exec_count': 3,
            'api_list': <Object?>[
              <String, Object?>{
                'api_no': 201,
                'api_category': 2,
                'api_type': 2,
                'api_state': 2,
                'api_progress_flag': 1,
                'api_title': '敵艦隊を撃破せよ！',
                'api_detail': '敵艦隊を捕捉、これを撃破せよ！',
                'api_get_material': <int>[50, 50, 0, 0],
              },
              <String, Object?>{
                'api_no': 402,
                'api_category': 4,
                'api_type': 3,
                'api_state': 3,
                'api_progress_flag': 2,
                'api_title': '海上通商破壊作戦',
                'api_detail': '輸送船を撃沈せよ。',
                'api_get_material': <int>[500, 0, 400, 0],
              },
              -1,
            ],
          },
          requestParams: const <String, Object?>{'api_page_no': '1'},
        ),
      );

      expect(state.quests, hasLength(2));
      expect(state.quests[201]?.progressLabel, '服务器进度 50% 以上');
      expect(state.quests[201]?.progressPercentLabel, '50%+');
      expect(state.quests[402]?.isCompleted, isTrue);
      expect(state.quests[402]?.progressLabel, '已完成');
      expect(state.quests[402]?.progressPercentLabel, '100%');
      expect(state.quests[402]?.materials, <int>[500, 0, 400, 0]);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          <String, Object?>{
            'api_count': 3,
            'api_exec_count': 3,
            'api_list': <Object?>[
              <String, Object?>{
                'api_no': 303,
                'api_category': 3,
                'api_type': 1,
                'api_state': 2,
                'api_progress_flag': 2,
                'api_title': '演習で練度向上！',
                'api_detail': '本日中に演習を行え。',
                'api_get_material': <int>[0, 50, 0, 0],
              },
            ],
          },
          requestParams: const <String, Object?>{'api_page_no': '2'},
        ),
      );

      expect(state.quests.keys, containsAll(<int>[201, 402, 303]));
      expect(state.quests[303]?.progressLabel, '服务器进度 80% 以上');
      expect(state.quests[303]?.progressPercentLabel, '80%+');
      expect(
        const GameQuest(
          id: 1,
          title: '',
          detail: '',
          category: 1,
          type: 1,
          state: 2,
          progressFlag: 0,
        ).progressPercentLabel,
        '＜50%',
      );
    });

    test('partial quest pages do not guess which cached quest is stale', () {
      final reducer = GameStateReducer();
      final staleTime = DateTime.utc(2026, 7, 29);
      final state = GameState(
        quests: <int, GameQuest>{
          101: GameQuest(
            id: 101,
            title: 'stale one',
            detail: '',
            category: 1,
            type: 1,
            state: 2,
            progressFlag: 0,
            updatedAt: staleTime,
          ),
          900: GameQuest(
            id: 900,
            title: 'active quest on another page',
            detail: '',
            category: 1,
            type: 1,
            state: 2,
            progressFlag: 0,
            updatedAt: staleTime,
          ),
        },
      );

      final next = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/questlist', <String, Object?>{
          'api_exec_count': 2,
          'api_list': <Object?>[
            <String, Object?>{
              'api_no': 201,
              'api_category': 2,
              'api_type': 2,
              'api_state': 2,
              'api_progress_flag': 0,
              'api_title': 'current',
              'api_detail': '',
            },
          ],
        }),
      );

      expect(next.hasQuestData, isTrue);
      expect(next.activeQuestCount, 2);
      expect(next.quests.keys, containsAll(<int>[101, 900, 201]));
    });

    test('complete quest snapshot replaces stale cached quests atomically', () {
      final reducer = GameStateReducer();
      final state = GameState(
        quests: <int, GameQuest>{
          101: GameQuest(
            id: 101,
            title: 'completed in another browser',
            detail: '',
            category: 1,
            type: 1,
            state: 2,
            progressFlag: 0,
            updatedAt: DateTime.utc(2026, 7, 29),
          ),
          900: GameQuest(
            id: 900,
            title: 'still active',
            detail: '',
            category: 1,
            type: 1,
            state: 2,
            progressFlag: 0,
            updatedAt: DateTime.utc(2026, 7, 29),
          ),
        },
      );

      final next = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_get_member/questlist',
          <String, Object?>{
            'api_exec_count': 1,
            'api_list': <Object?>[
              <String, Object?>{
                'api_no': 900,
                'api_category': 1,
                'api_type': 1,
                'api_state': 2,
                'api_progress_flag': 0,
                'api_title': 'still active',
                'api_detail': '',
              },
            ],
          },
          requestParams: const <String, Object?>{
            'yahagi_full_quest_snapshot': '1',
          },
        ),
      );

      expect(next.hasQuestData, isTrue);
      expect(next.activeQuestCount, 1);
      expect(next.quests.keys, <int>[900]);
    });

    test('claiming an unknown quest still corrects the active count', () {
      final reducer = GameStateReducer();
      final state = GameState(
        hasQuestData: true,
        activeQuestCount: 2,
        quests: const <int, GameQuest>{},
      );

      final next = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_quest/clearitemget',
          const <String, Object?>{},
          includeApiData: false,
          requestParams: const <String, Object?>{'api_quest_id': '999'},
        ),
      );

      expect(next.activeQuestCount, 1);
    });

    test('known quest goals count observed API events exactly', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_get_member/questlist', <String, Object?>{
          'api_exec_count': 1,
          'api_list': <Object?>[
            <String, Object?>{
              'api_no': 503,
              'api_category': 5,
              'api_type': 1,
              'api_state': 2,
              'api_progress_flag': 0,
              'api_title': 'repair quest',
              'api_detail': '',
            },
          ],
        }),
      );

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_nyukyo/start',
          const <String, Object?>{},
          includeApiData: false,
          requestParams: const <String, Object?>{
            'api_ndock_id': '1',
            'api_ship_id': '999',
            'api_highspeed': '0',
          },
        ),
      );

      expect(state.quests[503]?.exactProgressLabel, '1/5');
    });

    test('known quest becomes locally completed immediately', () {
      final reducer = GameStateReducer();
      var state = GameState(
        hasQuestData: true,
        activeQuestCount: 1,
        quests: <int, GameQuest>{
          503: GameQuest(
            id: 503,
            title: 'repair quest',
            detail: '',
            category: 5,
            type: 1,
            state: 2,
            progressFlag: 2,
            progressCurrent: 4,
            progressRequired: 5,
          ),
        },
      );

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_nyukyo/start',
          const <String, Object?>{},
          includeApiData: false,
          requestParams: const <String, Object?>{
            'api_ndock_id': '1',
            'api_ship_id': '999',
            'api_highspeed': '0',
          },
        ),
      );

      expect(state.quests, contains(503));
      expect(state.activeQuestCount, 1);
      expect(state.quests[503]?.exactProgressLabel, '5/5');
      expect(state.quests[503]?.isCompleted, isTrue);
      expect(state.quests[503]?.progressPercentLabel, '100%');
    });

    test('server quest sync recalibrates local completion', () {
      final reducer = GameStateReducer();
      final state = GameState(
        hasQuestData: true,
        activeQuestCount: 1,
        quests: <int, GameQuest>{
          503: GameQuest(
            id: 503,
            title: 'repair quest',
            detail: '',
            category: 5,
            type: 1,
            state: 2,
            progressFlag: 2,
            progressCurrent: 5,
            progressRequired: 5,
          ),
        },
      );

      final next = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/questlist', <String, Object?>{
          'api_exec_count': 1,
          'api_list': <Object?>[
            <String, Object?>{
              'api_no': 503,
              'api_category': 5,
              'api_type': 1,
              'api_state': 2,
              'api_progress_flag': 0,
              'api_title': 'repair quest',
              'api_detail': '',
            },
          ],
        }),
      );

      expect(next.quests[503]?.isCompleted, isFalse);
      expect(next.quests[503]?.progressCurrent, lessThan(5));
    });

    group('F96 live completion', () {
      GameState f96State({
        int furnitureCoins = 4000,
        bool hasFurnitureCoinData = true,
        int masterId4Count = 4,
        int masterId6Count = 4,
        int discardedMasterId = 2,
      }) {
        final slotItems = <int, OwnedSlotItem>{
          100: OwnedSlotItem(id: 100, masterId: discardedMasterId),
          for (var index = 0; index < masterId4Count; index++)
            400 + index: OwnedSlotItem(id: 400 + index, masterId: 4),
          for (var index = 0; index < masterId6Count; index++)
            600 + index: OwnedSlotItem(id: 600 + index, masterId: 6),
        };
        return GameState(
          furnitureCoins: furnitureCoins,
          hasFurnitureCoinData: hasFurnitureCoinData,
          slotItems: slotItems,
          hasQuestData: true,
          activeQuestCount: 1,
          quests: const <int, GameQuest>{
            1101: GameQuest(
              id: 1101,
              title: 'F96',
              detail: '',
              category: 6,
              type: 4,
              state: 2,
              progressFlag: 2,
              progressCurrent: 7,
              progressRequired: 8,
            ),
          },
        );
      }

      GameState destroyLastRequiredGun(GameState state) {
        return GameStateReducer().reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_kousyou/destroyitem2',
            const <String, Object?>{},
            requestParams: const <String, Object?>{'api_slotitem_ids': '100'},
          ),
        );
      }

      test('F96 completes after the eighth required gun is destroyed', () {
        final next = destroyLastRequiredGun(f96State());

        expect(next.slotItems, isNot(contains(100)));
        expect(next.quests[1101]?.exactProgressLabel, '8/8');
        expect(next.quests[1101]?.isCompleted, isTrue);
      });

      test('F96 does not complete with insufficient furniture coins', () {
        final next = destroyLastRequiredGun(f96State(furnitureCoins: 3999));

        expect(next.slotItems, isNot(contains(100)));
        expect(next.quests[1101]?.exactProgressLabel, '8/8');
        expect(next.quests[1101]?.isCompleted, isFalse);
      });

      test('F96 requires four of both prepared equipment types', () {
        final cases = <String, GameState>{
          'master ID 4': f96State(masterId4Count: 3),
          'master ID 6': f96State(masterId6Count: 3),
        };

        for (final entry in cases.entries) {
          final next = destroyLastRequiredGun(entry.value);

          expect(next.slotItems, isNot(contains(100)), reason: entry.key);
          expect(
            next.quests[1101]?.exactProgressLabel,
            '8/8',
            reason: entry.key,
          );
          expect(next.quests[1101]?.isCompleted, isFalse, reason: entry.key);
        }
      });

      test('F96 ignores destroyed equipment with another master ID', () {
        final next = destroyLastRequiredGun(f96State(discardedMasterId: 1));

        expect(next.slotItems, isNot(contains(100)));
        expect(next.quests[1101]?.exactProgressLabel, '7/8');
        expect(next.quests[1101]?.isCompleted, isFalse);
      });

      test('F96 does not complete before furniture coins are synced', () {
        final next = destroyLastRequiredGun(
          f96State(hasFurnitureCoinData: false),
        );

        expect(next.slotItems, isNot(contains(100)));
        expect(next.quests[1101]?.exactProgressLabel, '8/8');
        expect(next.quests[1101]?.isCompleted, isFalse);
      });

      test('F96 revalidates after furniture coins are synced', () {
        final reducer = GameStateReducer();
        final pending = destroyLastRequiredGun(
          f96State(hasFurnitureCoinData: false),
        );

        final next = reducer.reduce(
          pending,
          kcsapiEvent(
            '/kcsapi/api_get_member/require_info',
            const <String, Object?>{
              'api_basic': <String, Object?>{
                'api_level': 120,
                'api_fcoin': 4000,
              },
            },
          ),
        );

        expect(next.furnitureCoins, 4000);
        expect(next.hasFurnitureCoinData, isTrue);
        expect(next.quests[1101]?.isCompleted, isTrue);
      });

      test('F96 server state recalibrates stale local completion', () {
        final reducer = GameStateReducer();
        final completed = destroyLastRequiredGun(f96State());

        GameState syncQuest(int state) => reducer.reduce(
          completed,
          kcsapiEvent('/kcsapi/api_get_member/questlist', <String, Object?>{
            'api_exec_count': 1,
            'api_list': <Object?>[
              <String, Object?>{
                'api_no': 1101,
                'api_category': 6,
                'api_type': 4,
                'api_state': state,
                'api_progress_flag': state == 3 ? 0 : 2,
                'api_title': 'F96',
                'api_detail': '',
              },
            ],
          }),
        );

        final active = syncQuest(2);
        expect(active.quests[1101]?.exactProgressLabel, '7/8');
        expect(active.quests[1101]?.isCompleted, isFalse);

        final serverCompleted = syncQuest(3);
        expect(serverCompleted.quests[1101]?.exactProgressLabel, '8/8');
        expect(serverCompleted.quests[1101]?.isCompleted, isTrue);
      });

      test('F96 counts unique target instances in a batch only once', () {
        final state = GameState(
          furnitureCoins: 4000,
          hasFurnitureCoinData: true,
          slotItems: <int, OwnedSlotItem>{
            100: const OwnedSlotItem(id: 100, masterId: 2),
            101: const OwnedSlotItem(id: 101, masterId: 2),
            for (var index = 0; index < 4; index++)
              400 + index: OwnedSlotItem(id: 400 + index, masterId: 4),
            for (var index = 0; index < 4; index++)
              600 + index: OwnedSlotItem(id: 600 + index, masterId: 6),
          },
          hasQuestData: true,
          activeQuestCount: 1,
          quests: const <int, GameQuest>{
            1101: GameQuest(
              id: 1101,
              title: 'F96',
              detail: '',
              category: 6,
              type: 4,
              state: 2,
              progressFlag: 1,
              progressCurrent: 5,
              progressRequired: 8,
              localCompletionVerified: false,
            ),
          },
        );

        final next = GameStateReducer().reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_req_kousyou/destroyitem2',
            const <String, Object?>{},
            requestParams: const <String, Object?>{
              'api_slotitem_ids': '100,101,100',
            },
          ),
        );

        expect(next.slotItems, isNot(contains(100)));
        expect(next.slotItems, isNot(contains(101)));
        expect(next.quests[1101]?.exactProgressLabel, '7/8');
        expect(next.quests[1101]?.isCompleted, isFalse);
      });
    });

    test('rejects invalid api result without replacing state', () {
      final reducer = GameStateReducer();
      final state = reducer.reduce(GameState.empty, portEvent);

      expect(
        () => reducer.reduce(
          state,
          kcsapiEvent(
            '/kcsapi/api_get_member/material',
            const <Object?>[],
            apiResult: 0,
          ),
        ),
        throwsA(isA<GameApiParseException>()),
      );
      expect(state.resource(GameResourceType.fuel), 123260);
    });

    test('accepts expedition result so the controller records it', () {
      final reducer = GameStateReducer();
      final state = reducer.reduce(
        GameState.empty,
        kcsapiEvent(
          '/kcsapi/api_req_mission/result',
          <String, Object?>{
            'api_clear_result': 1,
            'api_quest_name': '敵艦隊を撃破せよ！',
            'api_get_material': <int>[100, 0, 0, 0],
          },
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      );

      expect(state.updatedAt, isNotNull);
    });

    test('clears the returned fleet mission after expedition result', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(GameState.empty, portEvent);
      final returningFleet = state.fleets.firstWhere(
        (fleet) => fleet.mission.missionId == 5,
      );
      expect(returningFleet.mission.isActive, isTrue);

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_mission/result',
          <String, Object?>{
            'api_clear_result': 1,
            'api_get_material': <int>[100, 0, 0, 0],
          },
          requestParams: <String, Object?>{
            'api_deck_id': '${returningFleet.id}',
          },
        ),
      );

      final clearedFleet = state.fleets.firstWhere(
        (fleet) => fleet.id == returningFleet.id,
      );
      expect(clearedFleet.mission.isActive, isFalse);
      expect(clearedFleet.mission.missionId, 0);
      expect(state.fleets.every((fleet) => !fleet.mission.isActive), isTrue);
    });
  });
}
