import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('GameState', () {
    test('resolves owned ships from deck instance ids', () {
      final state = GameState(
        masterShips: const <int, MasterShip>{
          101: MasterShip(id: 101, name: '夕張', shipTypeId: 2),
        },
        ships: const <int, OwnedShip>{
          9001: OwnedShip(id: 9001, masterId: 101, level: 50),
        },
        fleets: const <Fleet>[
          Fleet(id: 1, name: '第一舰队', shipIds: <int>[9001]),
        ],
      );

      expect(state.shipsForFleet(1).single.id, 9001);
      expect(state.masterForShip(state.ships[9001]!)?.name, '夕張');
      expect(state.resource(GameResourceType.fuel), isNull);
    });

    test('resolves equipment through owned and master ids', () {
      final state = GameState(
        masterSlotItems: const <int, MasterSlotItem>{
          201: MasterSlotItem(id: 201, name: '12.7cm 连装炮'),
        },
        slotItems: const <int, OwnedSlotItem>{
          7001: OwnedSlotItem(id: 7001, masterId: 201, level: 4),
        },
        ships: const <int, OwnedShip>{
          9001: OwnedShip(
            id: 9001,
            masterId: 101,
            level: 50,
            slotIds: <int>[7001, -1],
          ),
        },
      );

      final equipment = state.equipmentForShip(state.ships[9001]!);

      expect(equipment, hasLength(1));
      expect(equipment.single.owned.id, 7001);
      expect(equipment.single.master?.name, '12.7cm 连装炮');
    });

    test('keeps all eight resource types in stable game id order', () {
      expect(GameResourceType.values.map((type) => type.apiId), <int>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
      expect(GameResourceType.values.last.label, '改修资材');
    });

    test('keeps operation metadata and dock state through copyWith', () {
      final mission = MasterMission(
        id: 5,
        name: '海上護衛任務',
        duration: const Duration(minutes: 90),
      );
      final repairDock = RepairDock(
        id: 1,
        state: 1,
        shipId: 9002,
        fuelCost: 24,
        steelCost: 46,
      );
      final constructionDock = ConstructionDock(
        id: 1,
        state: 2,
        createdShipMasterId: 101,
        completionTime: DateTime.utc(2026, 7, 30, 11),
        startedAt: DateTime.utc(2026, 7, 30, 10),
        fuel: 30,
        ammunition: 30,
        steel: 30,
        bauxite: 30,
        developmentMaterial: 1,
      );
      final state = GameState(
        masterMissions: <int, MasterMission>{mission.id: mission},
        repairDocks: <RepairDock>[repairDock],
        constructionDocks: <ConstructionDock>[constructionDock],
        ships: const <int, OwnedShip>{
          9002: OwnedShip(
            id: 9002,
            masterId: 102,
            level: 44,
            repairDurationMilliseconds: 5400000,
          ),
        },
      );

      final copied = state.copyWith(admiralLevel: 120);

      expect(copied.masterMissions[5]?.name, '海上護衛任務');
      expect(copied.masterMissions[5]?.duration, const Duration(minutes: 90));
      expect(copied.repairDocks.single.fuelCost, 24);
      expect(copied.repairDocks.single.steelCost, 46);
      expect(copied.ships[9002]?.repairDurationMilliseconds, 5400000);
      expect(copied.constructionDocks.single.isBuilding, isTrue);
      expect(copied.constructionDocks.single.isLargeConstruction, isFalse);
      expect(copied.constructionDocks.single.startedAt, isNotNull);
    });

    test('recognizes locked and large construction docks', () {
      const locked = ConstructionDock(id: 2, state: -1);
      const large = ConstructionDock(
        id: 3,
        state: 2,
        fuel: 6000,
        ammunition: 7000,
        steel: 7000,
        bauxite: 2000,
        developmentMaterial: 20,
      );

      expect(locked.isLocked, isTrue);
      expect(locked.isBuilding, isFalse);
      expect(large.isLargeConstruction, isTrue);
    });

    test('recognizes a completed construction without a recorded start', () {
      final dock = ConstructionDock(id: 1, state: 3, createdShipMasterId: 101);

      expect(dock.isCompletedAt(DateTime.utc(2026, 7, 30, 9)), isTrue);
    });
  });
}
