import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';

import '../fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameState state;
  late NewShipReminderStore store;
  late List<NewShipAlert> published;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = NewShipReminderStore(await SharedPreferences.getInstance());
    published = <NewShipAlert>[];
    state = const GameState(
      memberId: 1001,
      masterShips: <int, MasterShip>{
        1: MasterShip(
          id: 1,
          name: '一号',
          shipTypeId: 2,
          sortNo: 1,
          afterShipId: 2,
        ),
        2: MasterShip(id: 2, name: '一号改', shipTypeId: 2, sortNo: 2),
        4: MasterShip(id: 4, name: '四号', shipTypeId: 2, sortNo: 4),
      },
      ships: <int, OwnedShip>{10: OwnedShip(id: 10, masterId: 2, level: 30)},
    );
  });

  test('battle drop waits for port before publishing', () async {
    final controller = NewShipReminderController(
      stateProvider: () => state,
      store: store,
      onPublish: published.add,
    );

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
        'api_get_ship': <String, Object?>{'api_ship_id': 4},
      }, sequence: 42),
    );
    await controller.idle;
    expect(published, isEmpty);

    controller.accept(
      kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
        'api_ship': [
          {'api_ship_id': 4, 'api_locked': 0},
        ],
      }, sequence: 43),
    );
    await controller.idle;
    expect(published.single.masterIds, <int>[4]);
  });

  test('owned family and excluded family do not publish', () async {
    await store.saveExcludedFamilyIds(1001, <int>{4});
    final controller = NewShipReminderController(
      stateProvider: () => state,
      store: store,
      onPublish: published.add,
    );

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_kousyou/getship', <String, Object?>{
        'api_ship': <String, Object?>{'api_ship_id': 1},
      }, sequence: 50),
    );
    controller.accept(
      kcsapiEvent('/kcsapi/api_req_kousyou/getship', <String, Object?>{
        'api_ship': <String, Object?>{'api_ship_id': 4},
      }, sequence: 51),
    );
    await controller.idle;

    expect(published, isEmpty);
  });

  test('construction publishes an absent family immediately', () async {
    final controller = NewShipReminderController(
      stateProvider: () => state,
      store: store,
      onPublish: published.add,
    );

    controller.accept(
      kcsapiEvent('/kcsapi/api_req_kousyou/getship', <String, Object?>{
        'api_ship': <String, Object?>{'api_ship_id': 4},
      }, sequence: 52),
    );
    await controller.idle;

    expect(published.single.masterIds, <int>[4]);
    expect(published.single.sources, <NewShipAcquisitionSource>{
      NewShipAcquisitionSource.construction,
    });
  });

  test(
    'quest useitem reward does not masquerade as an unowned Mikazuki',
    () async {
      state = state.copyWith(
        masterShips: <int, MasterShip>{
          ...state.masterShips,
          7: const MasterShip(id: 7, name: '三日月', shipTypeId: 2, sortNo: 37),
        },
      );
      final controller = NewShipReminderController(
        stateProvider: () => state,
        store: store,
        onPublish: published.add,
      );
      addTearDown(controller.dispose);

      controller.accept(
        kcsapiEvent('/kcsapi/api_req_quest/clearitemget', <String, Object?>{
          'api_bounus': <Object?>[
            <String, Object?>{
              'api_type': 1,
              'api_count': 1,
              'api_item': <String, Object?>{'api_id': 7, 'api_name': '開発資材'},
            },
          ],
        }, sequence: 53),
      );
      await controller.idle;

      expect(published, isEmpty);
      expect(controller.currentAlert, isNull);
      expect(await store.loadPending(state.memberId), isEmpty);
    },
  );

  test(
    'quest ignores equipment and ship IDs outside awarded bonuses',
    () async {
      final controller = NewShipReminderController(
        stateProvider: () => state,
        store: store,
        onPublish: published.add,
      );
      addTearDown(controller.dispose);
      controller.accept(
        kcsapiEvent('/kcsapi/api_req_quest/clearitemget', <String, Object?>{
          'api_bounus': <Object?>[
            <String, Object?>{
              'api_type': 12,
              'api_item': <String, Object?>{'api_id': 4},
            },
          ],
          'api_unrelated': <String, Object?>{'api_ship_id': 4},
        }, sequence: 54),
      );
      await controller.idle;
      expect(published, isEmpty);
    },
  );

  test(
    'multiple battle drops merge at port and duplicate events are ignored',
    () async {
      state = state.copyWith(
        masterShips: <int, MasterShip>{
          ...state.masterShips,
          5: const MasterShip(id: 5, name: '五号', shipTypeId: 2, sortNo: 5),
        },
      );
      final controller = NewShipReminderController(
        stateProvider: () => state,
        store: store,
        onPublish: published.add,
      );
      final first = kcsapiEvent(
        '/kcsapi/api_req_sortie/battleresult',
        <String, Object?>{
          'api_get_ship': <String, Object?>{'api_ship_id': 4},
        },
        sequence: 60,
      );
      controller.accept(first);
      controller.accept(first);
      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          <String, Object?>{
            'api_get_ship': <String, Object?>{'api_ship_id': 5},
          },
          sequence: 61,
        ),
      );
      controller.accept(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_ship': [
            {'api_ship_id': 4, 'api_locked': 0},
            {'api_ship_id': 5, 'api_locked': 0},
          ],
        }, sequence: 62),
      );
      await controller.idle;

      expect(published, hasLength(1));
      expect(published.single.masterIds, <int>[4, 5]);
    },
  );

  for (final reward
      in <({String path, Object data, NewShipAcquisitionSource source})>[
        (
          path: '/kcsapi/api_req_quest/clearitemget',
          data: <String, Object?>{
            'api_bounus': <Object?>[
              <String, Object?>{
                'api_type': 11,
                'api_item': <String, Object?>{'api_id': 999, 'api_ship_id': 4},
              },
            ],
          },
          source: NewShipAcquisitionSource.questReward,
        ),
      ]) {
    test('${reward.source.name} publishes immediately', () async {
      final controller = NewShipReminderController(
        stateProvider: () => state,
        store: store,
        onPublish: published.add,
      );

      controller.accept(kcsapiEvent(reward.path, reward.data, sequence: 70));
      await controller.idle;

      expect(published.single.masterIds, <int>[4]);
      expect(published.single.sources, <NewShipAcquisitionSource>{
        reward.source,
      });
    });
  }
}
