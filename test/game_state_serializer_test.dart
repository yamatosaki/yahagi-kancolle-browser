import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';

void main() {
  test(
    'ship experience and expansion-slot state survive cache serialization',
    () {
      const state = GameState(
        ships: <int, OwnedShip>{
          7: OwnedShip(
            id: 7,
            masterId: 101,
            level: 51,
            experience: 45000,
            nextExperience: 1200,
            extraSlotId: 503,
          ),
        },
      );

      final restored = GameStateSerializer.deserialize(
        GameStateSerializer.serialize(state),
      );

      expect(restored.ships[7]?.experience, 45000);
      expect(restored.ships[7]?.nextExperience, 1200);
      expect(restored.ships[7]?.extraSlotId, 503);
    },
  );

  test('new-ship identity metadata survives cache serialization', () {
    const state = GameState(
      memberId: 90001,
      masterShips: <int, MasterShip>{
        1: MasterShip(
          id: 1,
          name: '夕立',
          shipTypeId: 2,
          afterShipId: 2,
          powerUp: <int>[3, 0, 1, 2],
        ),
      },
      masterSlotItemTypes: <int, String>{1: '小口径主炮'},
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.memberId, 90001);
    expect(restored.masterShips[1]?.afterShipId, 2);
    expect(restored.masterShips[1]?.powerUp, <int>[3, 0, 1, 2]);
    expect(restored.masterSlotItemTypes[1], '小口径主炮');
  });

  test('ship voice resource mapping survives cache serialization', () {
    const state = GameState(
      masterShips: {
        1: MasterShip(
          id: 1,
          name: '睦月',
          shipTypeId: 2,
          portraitFileName: 'ship1',
          portraitVersion: '7',
        ),
      },
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.masterShips[1]?.portraitFileName, 'ship1');
    expect(restored.masterShips[1]?.portraitVersion, '7');
  });

  test('old ship cache keeps unavailable resource mapping null', () {
    final restored = GameStateSerializer.deserialize(
      '{"masterShips":{"1":{"id":1,"name":"睦月","shipTypeId":2}}}',
    );

    expect(restored.masterShips[1]?.name, '睦月');
    expect(restored.masterShips[1]?.portraitFileName, isNull);
    expect(restored.masterShips[1]?.portraitVersion, isNull);
  });

  test('restoring a cached false ship name keeps the master record', () {
    final restored = GameStateSerializer.deserialize('''
      {"masterShips":{
        "623":{"name":"false","reading":"ゆうばり","maxHp":60},
        "748":{"name":false,"portraitFileName":"ibcavjzuajrb"},
        "411":{"name":"扶桑（战后）"}
      }}
    ''');

    expect(restored.masterShips[623]?.name, 'ゆうばり');
    expect(restored.masterShips[623]?.maxHp, 60);
    expect(restored.masterShips[748]?.name, '#748');
    expect(restored.masterShips[748]?.portraitFileName, 'ibcavjzuajrb');
    expect(restored.masterShips[411]?.name, '扶桑（战后）');
  });

  test('equipment compatibility master data survives cache serialization', () {
    const state = GameState(
      masterShipTypes: <int, MasterShipType>{
        2: MasterShipType(id: 2, name: '驱逐舰', equipTypeIds: <int>{1, 27}),
      },
      masterShips: <int, MasterShip>{
        100: MasterShip(
          id: 100,
          name: '测试舰改',
          shipTypeId: 2,
          classTypeId: 47,
          equipTypeIds: <int>{1, 27},
          limitedEquipmentIdsByType: <int, Set<int>>{
            27: <int>{268},
          },
        ),
      },
      masterSlotItems: <int, MasterSlotItem>{
        268: MasterSlotItem(
          id: 268,
          name: '北方迷彩（＋北方装备）',
          sortNo: 268,
          type: <int>[3, 5, 27, 23, 0],
        ),
      },
      expansionSlotEquipmentTypeIds: <int>{21, 27},
      expansionSlotLimitsByShipId: <int, Set<int>>{
        100: <int>{27},
      },
      expansionSlotSpecialRules: <int, ExpansionSlotSpecialRule>{
        268: ExpansionSlotSpecialRule(
          equipmentMasterId: 268,
          shipMasterIds: <int>{100},
          classTypeIds: <int>{47},
          shipTypeIds: <int>{2},
          minimumImprovement: 7,
        ),
      },
      hasEquipmentCompatibilityData: true,
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.masterShipTypes[2]?.equipTypeIds, <int>{1, 27});
    expect(restored.masterShips[100]?.classTypeId, 47);
    expect(restored.masterShips[100]?.equipTypeIds, <int>{1, 27});
    expect(restored.masterShips[100]?.limitedEquipmentIdsByType[27], <int>{
      268,
    });
    expect(restored.masterSlotItems[268]?.type, <int>[3, 5, 27, 23, 0]);
    expect(restored.expansionSlotEquipmentTypeIds, <int>{21, 27});
    expect(restored.expansionSlotLimitsByShipId[100], <int>{27});
    expect(restored.expansionSlotSpecialRules[268]?.shipMasterIds, <int>{100});
    expect(restored.expansionSlotSpecialRules[268]?.minimumImprovement, 7);
    expect(restored.hasEquipmentCompatibilityData, isTrue);
  });

  test('old cache defaults equipment compatibility rules to empty', () {
    final restored = GameStateSerializer.deserialize('{"admiralLevel":120}');

    expect(restored.expansionSlotEquipmentTypeIds, isEmpty);
    expect(restored.expansionSlotLimitsByShipId, isEmpty);
    expect(restored.expansionSlotSpecialRules, isEmpty);
    expect(restored.hasEquipmentCompatibilityData, isFalse);
  });

  test('MasterShip modernization stats survive cache serialization', () {
    const state = GameState(
      masterShips: <int, MasterShip>{
        690: MasterShip(
          id: 690,
          name: '日進改',
          shipTypeId: 11,
          baseFirepower: 18,
          maxFirepower: 54,
          baseTorpedo: 0,
          maxTorpedo: 75,
          baseAntiAir: 22,
          maxAntiAir: 62,
          baseArmor: 24,
          maxArmor: 46,
          baseLuck: 10,
          maxLuck: 58,
          baseHp: 38,
          maxHp: 44,
        ),
      },
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    final ship = restored.masterShips[690];
    expect(ship, isNotNull);
    expect(ship!.baseFirepower, 18);
    expect(ship.maxFirepower, 54);
    expect(ship.baseTorpedo, 0);
    expect(ship.maxTorpedo, 75);
    expect(ship.baseAntiAir, 22);
    expect(ship.maxAntiAir, 62);
    expect(ship.baseArmor, 24);
    expect(ship.maxArmor, 46);
    expect(ship.baseLuck, 10);
    expect(ship.maxLuck, 58);
    expect(ship.baseHp, 38);
    expect(ship.maxHp, 44);
  });

  test(
    'old MasterShip cache without modernization stats defaults to 0 safely',
    () {
      const legacyJson = '''
    {
      "masterShips": {
        "1": {
          "id": 1,
          "name": "吹雪",
          "shipTypeId": 2
        }
      }
    }
    ''';

      final restored = GameStateSerializer.deserialize(legacyJson);
      final ship = restored.masterShips[1];
      expect(ship, isNotNull);
      expect(ship!.baseFirepower, 0);
      expect(ship.maxFirepower, 0);
      expect(ship.baseTorpedo, 0);
      expect(ship.maxTorpedo, 0);
      expect(ship.baseAntiAir, 0);
      expect(ship.maxAntiAir, 0);
      expect(ship.baseArmor, 0);
      expect(ship.maxArmor, 0);
      expect(ship.baseLuck, 0);
      expect(ship.maxLuck, 0);
      expect(ship.baseHp, 0);
      expect(ship.maxHp, 0);
      expect(ship.remainingModernization(1, 0), isNull);
    },
  );

  test('present zero modernization range survives cache restart', () {
    const state = GameState(
      masterShips: {
        1: MasterShip(
          id: 1,
          name: '戦艦',
          shipTypeId: 9,
          modernizationRangeIndices: {1},
        ),
      },
    );
    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );
    expect(restored.masterShips[1]!.remainingModernization(1, 0), 0);
    expect(restored.masterShips[1]!.remainingModernization(0, 0), isNull);
  });

  test('malformed cached fodder powerUp stays unknown', () {
    const cached =
        '{"masterShips":{"2":{"name":"素材",'
        '"shipTypeId":2,"powerUp":[1,null,0,0]}}}';
    final restored = GameStateSerializer.deserialize(cached);
    expect(restored.masterShips[2]!.powerUp, isEmpty);
  });

  test('malformed cached range index cannot create a false MAX', () {
    const cached =
        '{"masterShips":{"2":{"name":"戦艦",'
        '"shipTypeId":9,"modernizationRangeIndices":[null]}}}';
    final restored = GameStateSerializer.deserialize(cached);
    expect(restored.masterShips[2]!.remainingModernization(0, 0), isNull);
  });

  test('malformed cached modernization values remain unknown', () {
    const cached =
        '{"masterShips":{"2":{"name":"戦艦",'
        '"shipTypeId":9,"baseTorpedo":"bad","maxTorpedo":5,'
        '"baseFirepower":0,"maxFirepower":"bad",'
        '"modernizationRangeIndices":[0,1]}}}';
    final restored = GameStateSerializer.deserialize(cached);
    final master = restored.masterShips[2]!;
    expect(master.remainingModernization(1, 0), isNull);
    expect(master.remainingModernization(0, 0), isNull);
    expect(master.modernizationRangeIndices, isEmpty);
  });

  test('land-base cache keeps identity but drops sortie-only hp', () {
    const state = GameState(
      landBases: <LandBaseState>[
        LandBaseState(
          areaId: 47,
          baseId: 1,
          name: '第一基地航空队',
          actionKind: 1,
          maxHp: 200,
          currentHp: 152,
          lastRaidDamage: 48,
        ),
      ],
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.landBases, hasLength(1));
    expect(restored.landBases.single.areaId, 47);
    expect(restored.landBases.single.baseId, 1);
    expect(restored.landBases.single.name, '第一基地航空队');
    expect(restored.landBases.single.actionKind, 1);
    expect(restored.landBases.single.maxHp, isNull);
    expect(restored.landBases.single.currentHp, isNull);
    expect(restored.landBases.single.lastRaidDamage, 0);
  });

  test('land-base cache keeps distance and squadron state', () {
    const state = GameState(
      landBases: <LandBaseState>[
        LandBaseState(
          areaId: 62,
          baseId: 1,
          name: '第一基地航空队',
          actionKind: 1,
          distanceBase: 7,
          distanceBonus: 1,
          squadrons: <LandBaseSquadronState>[
            LandBaseSquadronState(
              squadronId: 1,
              state: 1,
              slotItemId: 101,
              currentCount: 12,
              maxCount: 18,
              condition: 3,
            ),
          ],
        ),
      ],
      masterMapAreas: <int, String>{62: '反击！第三十一战队的战斗'},
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.landBases.single.effectiveDistance, 8);
    expect(restored.landBases.single.squadrons.single.currentCount, 12);
    expect(restored.landBases.single.squadrons.single.condition, 3);
    expect(restored.masterMapAreas[62], '反击！第三十一战队的战斗');
  });

  test('old cache without land bases remains compatible', () {
    final restored = GameStateSerializer.deserialize('{"admiralLevel":120}');

    expect(restored.admiralLevel, 120);
    expect(restored.landBases, isEmpty);
  });

  test('special item counts survive cache serialization', () {
    const state = GameState(
      useItems: <int, int>{54: 3, 68: 17},
      hasUseItemData: true,
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.hasUseItemData, isTrue);
    expect(restored.useItemCount(54), 3);
    expect(restored.useItemCount(68), 17);
  });

  test('selected map difficulties survive cache serialization', () {
    const state = GameState(mapDifficulties: <int, int>{6202: 3});

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.mapDifficulty(62, 2), 3);
  });

  test('F96 completion prerequisites survive cache serialization', () {
    const state = GameState(
      furnitureCoins: 4000,
      hasFurnitureCoinData: true,
      quests: <int, GameQuest>{
        1101: GameQuest(
          id: 1101,
          title: 'F96',
          detail: '',
          category: 6,
          type: 4,
          state: 2,
          progressFlag: 2,
          progressCurrent: 8,
          progressRequired: 8,
          localCompletionVerified: false,
        ),
      },
    );

    final restored = GameStateSerializer.deserialize(
      GameStateSerializer.serialize(state),
    );

    expect(restored.furnitureCoins, 4000);
    expect(restored.hasFurnitureCoinData, isTrue);
    expect(restored.quests[1101]?.progressCurrent, 8);
    expect(restored.quests[1101]?.progressRequired, 8);
    expect(restored.quests[1101]?.localCompletionVerified, isFalse);
    expect(restored.quests[1101]?.isCompleted, isFalse);
  });

  test('old F96 cache without new fields restores safely', () {
    final restored = GameStateSerializer.deserialize(
      '{"quests":{"1101":{"title":"F96","detail":"",'
      '"category":6,"type":4,"state":2,"progressFlag":2,'
      '"progressCurrent":8,"progressRequired":8}}}',
    );

    expect(restored.furnitureCoins, 0);
    expect(restored.hasFurnitureCoinData, isFalse);
    expect(restored.quests[1101]?.localCompletionVerified, isFalse);
    expect(restored.quests[1101]?.isCompleted, isFalse);
  });

  test('legacy ordinary quest keeps exact-progress completion semantics', () {
    final restored = GameStateSerializer.deserialize(
      '{"quests":{"503":{"title":"repair quest","detail":"",'
      '"category":5,"type":1,"state":2,"progressFlag":2,'
      '"progressCurrent":5,"progressRequired":5}}}',
    );

    expect(restored.quests[503]?.progressCurrent, 5);
    expect(restored.quests[503]?.progressRequired, 5);
    expect(restored.quests[503]?.localCompletionVerified, isNull);
    expect(restored.quests[503]?.isCompleted, isTrue);
  });

  for (final entry in <String, String>{
    'null': 'null',
    'wrong type': '"not-a-bool"',
  }.entries) {
    test('corrupt F96 verification (${entry.key}) restores safely', () {
      final restored = GameStateSerializer.deserialize(
        '{"quests":{"1101":{"title":"F96","detail":"",'
        '"category":6,"type":4,"state":2,"progressFlag":2,'
        '"progressCurrent":8,"progressRequired":8,'
        '"localCompletionVerified":${entry.value}}}}',
      );

      expect(restored.quests[1101]?.localCompletionVerified, isFalse);
      expect(restored.quests[1101]?.isCompleted, isFalse);
    });

    test('corrupt ordinary verification (${entry.key}) keeps semantics', () {
      final restored = GameStateSerializer.deserialize(
        '{"quests":{"503":{"title":"repair quest","detail":"",'
        '"category":5,"type":1,"state":2,"progressFlag":2,'
        '"progressCurrent":5,"progressRequired":5,'
        '"localCompletionVerified":${entry.value}}}}',
      );

      expect(restored.quests[503]?.localCompletionVerified, isNull);
      expect(restored.quests[503]?.isCompleted, isTrue);
    });
  }
}
