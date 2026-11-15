import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/game_state/master_ship_names.dart';

const _base = GameState(
  memberId: 1001,
  masterShips: {1: MasterShip(id: 1, name: 'ship', shipTypeId: 2)},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'bundled names restore all affected Kanxy variants from cache',
    () async {
      const expected = {
        26: '扶桑',
        115: '夕張',
        139: '矢矧',
        286: '扶桑改',
        293: '夕張改',
        307: '矢矧改',
        411: '扶桑改二',
        622: '夕張改二',
        623: '夕張改二特',
        624: '夕張改二丁',
        663: '矢矧改二',
        668: '矢矧改二乙',
        748: '扶桑改二補',
      };
      SharedPreferences.setMockInitialValues({
        'game_state.shared.v1': jsonEncode({
          'masterShips': {
            for (final id in expected.keys)
              '$id': {'name': 'false', 'portraitFileName': 'portrait-$id'},
          },
        }),
      });
      final names = await MasterShipNames.loadBundled();
      final restored = await GameStateStore(masterShipNames: names).load();

      for (final entry in expected.entries) {
        final ship = restored.masterShips[entry.key];
        expect(ship?.name, entry.value);
        expect(ship?.portraitFileName, 'portrait-${entry.key}');
      }
    },
  );

  final changes = <String, GameState>{
    'masterShips': _base.copyWith(
      masterShips: {2: const MasterShip(id: 2, name: 'new', shipTypeId: 2)},
    ),
    'masterShipTypes': _base.copyWith(
      masterShipTypes: {2: const MasterShipType(id: 2, name: 'type')},
    ),
    'masterSlotItems': _base.copyWith(
      masterSlotItems: {
        1: const MasterSlotItem(id: 1, name: 'item', type: [1, 2]),
      },
    ),
    'masterSlotItemTypes': _base.copyWith(
      masterSlotItemTypes: {1: 'equipment type'},
    ),
    'expansionSlotEquipmentTypeIds': _base.copyWith(
      expansionSlotEquipmentTypeIds: {1},
    ),
    'expansionSlotSpecialRules': _base.copyWith(
      expansionSlotSpecialRules: {
        1: const ExpansionSlotSpecialRule(
          equipmentMasterId: 1,
          shipMasterIds: {1},
        ),
      },
    ),
    'expansionSlotLimitsByShipId': _base.copyWith(
      expansionSlotLimitsByShipId: {
        1: {2},
      },
    ),
    'hasEquipmentCompatibilityData': _base.copyWith(
      hasEquipmentCompatibilityData: true,
    ),
    'masterMissions': _base.copyWith(
      masterMissions: {
        1: const MasterMission(
          id: 1,
          name: 'mission',
          duration: Duration(minutes: 5),
        ),
      },
    ),
    'masterMapInfos': _base.copyWith(
      masterMapInfos: {
        11: const MasterMapInfo(id: 11, mapAreaId: 1, mapNo: 1, name: 'map'),
      },
    ),
    'masterMapAreas': _base.copyWith(masterMapAreas: {1: 'area'}),
    'hasMasterData': _base.copyWith(hasMasterData: true),
  };

  test(
    'personal updates do not rewrite or leak into the shared cache',
    () async {
      final writes = <String>[];
      final store = GameStateStore(
        saveDelay: const Duration(hours: 1),
        writeString: (prefs, key, value) async {
          writes.add(key);
          return prefs.setString(key, value);
        },
      );
      store.save(_base);
      await store.flush();
      writes.clear();
      store.save(
        _base.copyWith(
          resources: {GameResourceType.fuel: 200},
          ships: {1: const OwnedShip(id: 1, masterId: 1, level: 1)},
        ),
      );
      await store.flush();
      expect(writes, ['account.1001.game_state.v1']);
      final prefs = await SharedPreferences.getInstance();
      final shared =
          jsonDecode(prefs.getString('game_state.shared.v1')!) as Map;
      expect(shared.keys, isNot(contains('memberId')));
      expect(shared.keys, isNot(contains('resources')));
      expect(shared.keys, isNot(contains('ships')));
      final personal =
          jsonDecode(prefs.getString('account.1001.game_state.v1')!) as Map;
      expect(personal.keys, isNot(contains('masterShips')));
      expect(
        (await store.loadForAccount(1001)).resource(GameResourceType.fuel),
        200,
      );
    },
  );

  for (final change in changes.entries) {
    test(
      'an independent ${change.key} change persists shared content',
      () async {
        final writes = <String>[];
        final store = GameStateStore(
          saveDelay: const Duration(hours: 1),
          writeString: (prefs, key, value) async {
            writes.add(key);
            return prefs.setString(key, value);
          },
        );
        store.save(_base);
        await store.flush();
        final prefs = await SharedPreferences.getInstance();
        final before =
            jsonDecode(prefs.getString('game_state.shared.v1')!) as Map;
        writes.clear();
        store.save(change.value);
        await store.flush();
        final after =
            jsonDecode(prefs.getString('game_state.shared.v1')!) as Map;
        expect(writes, contains('game_state.shared.v1'));
        expect(after[change.key], isNot(equals(before[change.key])));
        writes.clear();
        store.save(
          change.value.copyWith(resources: {GameResourceType.fuel: 300}),
        );
        await store.flush();
        expect(writes, ['account.1001.game_state.v1']);
      },
    );
  }

  for (final entry in <String, MasterShip>{
    'portraitFileName': _base.masterShips[1]!.copyWith(
      portraitFileName: 'ship1',
    ),
    'portraitVersion': _base.masterShips[1]!.copyWith(portraitVersion: '7'),
  }.entries) {
    test('a later ${entry.key} update persists in the shared cache', () async {
      final writes = <String>[];
      final store = GameStateStore(
        saveDelay: const Duration(hours: 1),
        writeString: (prefs, key, value) async {
          writes.add(key);
          return prefs.setString(key, value);
        },
      );
      store.save(_base);
      await store.flush();
      writes.clear();

      final updated = _base.copyWith(masterShips: {1: entry.value});
      store.save(updated);
      await store.flush();

      expect(writes, contains('game_state.shared.v1'));
      final restored = await GameStateStore().load();
      expect(
        restored.masterShips[1]?.portraitFileName,
        entry.value.portraitFileName,
      );
      expect(
        restored.masterShips[1]?.portraitVersion,
        entry.value.portraitVersion,
      );

      writes.clear();
      store.save(updated.copyWith(resources: {GameResourceType.fuel: 300}));
      await store.flush();
      expect(writes, ['account.1001.game_state.v1']);
    });
  }

  test(
    'in-place map and nested list changes cannot bypass dirty detection',
    () async {
      final power = <int>[1, 2, 0, 0];
      final masters = <int, MasterShip>{
        1: MasterShip(id: 1, name: 'ship', shipTypeId: 2, powerUp: power),
      };
      final state = _base.copyWith(masterShips: masters);
      final store = GameStateStore(saveDelay: const Duration(hours: 1));
      store.save(state);
      await store.flush();
      power[0] = 9;
      masters[2] = const MasterShip(id: 2, name: 'new', shipTypeId: 2);
      store.save(state);
      await store.flush();
      final loaded = await store.loadForAccount(1001);
      expect(loaded.masterShips.keys, [1, 2]);
      expect(loaded.masterShips[1]!.powerUp, [9, 2, 0, 0]);
    },
  );

  test(
    'reordered set values do not rewrite unchanged shared definitions',
    () async {
      final writes = <String>[];
      final store = GameStateStore(
        saveDelay: const Duration(hours: 1),
        writeString: (prefs, key, value) async {
          writes.add(key);
          return prefs.setString(key, value);
        },
      );
      store.save(
        _base.copyWith(
          expansionSlotEquipmentTypeIds: {1, 2},
          expansionSlotLimitsByShipId: {
            1: {2, 3},
          },
        ),
      );
      await store.flush();
      writes.clear();
      store.save(
        _base.copyWith(
          expansionSlotEquipmentTypeIds: {2, 1},
          expansionSlotLimitsByShipId: {
            1: {3, 2},
          },
        ),
      );
      await store.flush();
      expect(writes, ['account.1001.game_state.v1']);
    },
  );

  test(
    'shared retry and newer snapshots remain ordered behind a slow write',
    () async {
      final gate = Completer<void>();
      final started = Completer<void>();
      var fail = true;
      final store = GameStateStore(
        saveDelay: const Duration(hours: 1),
        writeString: (prefs, key, value) async {
          if (key == 'game_state.shared.v1' && fail) {
            fail = false;
            started.complete();
            await gate.future;
            return false;
          }
          return prefs.setString(key, value);
        },
      );
      store.save(_base);
      final first = store.flush();
      await started.future;
      store.save(changes['masterMapAreas']!.copyWith(memberId: 2002));
      final second = store.flush();
      gate.complete();
      await Future.wait([first, second]);
      final a = await store.loadForAccount(1001);
      final b = await store.loadForAccount(2002);
      expect(a.memberId, 1001);
      expect(b.memberId, 2002);
      expect(a.masterMapAreas, {1: 'area'});
      expect(b.masterMapAreas, {1: 'area'});
    },
  );

  test('old shared cache without optional fields remains readable', () async {
    SharedPreferences.setMockInitialValues({
      'game_state.legacy_migrated.v1': true,
      'game_state.shared.v1':
          '{"masterShips":{"1":{"id":1,"name":"old","shipTypeId":2}}}',
      'account.1001.game_state.v1': '{"memberId":1001,"resources":{"1":99}}',
    });
    final loaded = await GameStateStore().loadForAccount(1001);
    expect(loaded.masterShips[1]?.name, 'old');
    expect(loaded.masterShips[1]?.portraitFileName, isNull);
    expect(loaded.masterShips[1]?.portraitVersion, isNull);
    expect(loaded.masterMapInfos, isEmpty);
    expect(loaded.hasMasterData, isFalse);
    expect(loaded.canExportFleet, isFalse);
    expect(loaded.resource(GameResourceType.fuel), 99);
  });

  test(
    'master map metadata round trips without enabling live export flags',
    () async {
      final store = GameStateStore(saveDelay: const Duration(hours: 1));
      store.save(
        changes['masterMapInfos']!.copyWith(
          hasMasterData: true,
          hasPortData: true,
          hasEquipmentInventory: true,
        ),
      );
      await store.flush();
      final loaded = await store.loadForAccount(1001);
      expect(loaded.masterMapInfos[11]?.name, 'map');
      expect(loaded.hasMasterData, isFalse);
      expect(loaded.canExportFleet, isFalse);
    },
  );
}
