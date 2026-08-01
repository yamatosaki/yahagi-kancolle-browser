import 'package:flutter_test/flutter_test.dart';
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
      expect(state.masterMissions[5]?.name, '海上護衛任務');
      expect(state.masterMissions[5]?.duration, const Duration(minutes: 90));
      expect(state.ships[9002]?.repairDurationMilliseconds, 5400000);
      expect(state.repairDocks.first.fuelCost, 24);
      expect(state.repairDocks.first.steelCost, 46);
      expect(state.constructionDocks, hasLength(4));
      expect(state.constructionDocks.first.createdShipMasterId, 101);
      expect(state.constructionDocks[2].isLargeConstruction, isTrue);
      expect(state.constructionDocks[3].isLocked, isTrue);
      expect(state.serverOrigin, 'https://w01y.kancolle-server.com');
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
          requestParams: const <String, Object?>{'api_mission_id': '5'},
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
          requestParams: const <String, Object?>{'api_mission_id': '5'},
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
