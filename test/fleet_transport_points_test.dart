import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_transport_points.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

const mainFleet = Fleet(id: 1, name: 'Main', shipIds: [101, -1]);
const escort = Fleet(id: 2, name: 'Escort', shipIds: [102]);
const thirdFleet = Fleet(id: 3, name: 'Third', shipIds: [103]);

const fleetState = GameState(
  fleets: [mainFleet, escort, thirdFleet],
  masterShips: {
    1: MasterShip(id: 1, name: 'Destroyer', shipTypeId: 2),
    2: MasterShip(id: 2, name: 'Carrier', shipTypeId: 11),
    487: MasterShip(id: 487, name: 'Kinu Kai Ni', shipTypeId: 3),
  },
  ships: {
    101: OwnedShip(id: 101, masterId: 1, level: 99),
    102: OwnedShip(id: 102, masterId: 1, level: 99),
    103: OwnedShip(id: 103, masterId: 2, level: 99),
  },
);

void main() {
  test(
    'counts cargo in normal and extra slots regardless of HP or upgrades',
    () {
      final state = fleetState.copyWith(
        ships: {
          ...fleetState.ships,
          101: const OwnedShip(
            id: 101,
            masterId: 1,
            level: 99,
            currentHp: 1,
            maxHp: 30,
            slotIds: [401, 402, 403, -1, 404],
            extraSlotId: 405,
          ),
        },
        slotItems: const {
          401: OwnedSlotItem(instanceId: 401, masterSlotItemId: 500, level: 10),
          402: OwnedSlotItem(instanceId: 402, masterSlotItemId: 501),
          403: OwnedSlotItem(instanceId: 403, masterSlotItemId: 502),
          404: OwnedSlotItem(instanceId: 404, masterSlotItemId: 503),
          405: OwnedSlotItem(instanceId: 405, masterSlotItemId: 504),
        },
        masterSlotItems: const {
          500: MasterSlotItem(id: 500, name: 'Landing craft', type: [0, 0, 24]),
          501: MasterSlotItem(id: 501, name: 'Drum canister', type: [0, 0, 30]),
          502: MasterSlotItem(
            id: 502,
            name: 'Amphibious tank',
            type: [0, 0, 46],
          ),
          503: MasterSlotItem(id: 503, name: 'Gun', type: [0, 0, 1, 24]),
          504: MasterSlotItem(
            id: 504,
            name: 'Combat rations',
            type: [0, 0, 43],
          ),
        },
      );

      final transport = FleetTransportPoints.forFleet(state, mainFleet)!;
      expect(transport.sRank, 21);
      expect(transport.aRank, 14);
      expect(transport.tankSRank, 15);
      expect(transport.tankARank, 10);
      expect(transport.isCombined, isFalse);
      expect(transport.contributions.single.fleetId, 1);
      expect(transport.contributions.single.points, 21);
    },
  );

  test('both tabs use the same combined total and round A after adding', () {
    final state = fleetState.copyWith(
      combinedFleetType: CombinedFleetType.transportEscort,
    );
    for (final fleet in [mainFleet, escort]) {
      final transport = FleetTransportPoints.forFleet(state, fleet)!;
      expect(transport.isCombined, isTrue);
      expect(transport.sRank, 10);
      expect(transport.aRank, 7);
      expect(transport.tankSRank, 6);
      expect(transport.tankARank, 4);
      expect(transport.contributions.map((entry) => entry.fleetId), [1, 2]);
      expect(transport.contributions.map((entry) => entry.points), [5, 5]);
      expect(transport.contributions.map((entry) => entry.tankPoints), [3, 3]);
    }

    final thirdTransport = FleetTransportPoints.forFleet(state, thirdFleet)!;
    expect(thirdTransport.sRank, 0);
    expect(thirdTransport.isCombined, isFalse);
  });

  test('explicit record fleets get one Kinu bonus across the sortie', () {
    final state = fleetState.copyWith(
      ships: const {
        101: OwnedShip(id: 101, masterId: 487, level: 99),
        102: OwnedShip(id: 102, masterId: 487, level: 99),
      },
    );
    final combined = FleetTransportPoints.fromState(state, [
      escort,
      mainFleet,
    ])!;
    expect(combined.kinuBonus, 8);
    expect(combined.sRank, 12);
    expect(combined.aRank, 8);
    expect(combined.tankSRank, 10);
    expect(combined.tankARank, 7);
    expect(combined.contributions.map((entry) => entry.points), [2, 2]);
    expect(combined.contributions.map((entry) => entry.tankPoints), [1, 1]);

    final single = FleetTransportPoints.fromState(state, [escort])!;
    expect(single.sRank, 10);
    expect(single.aRank, 7);
    expect(single.tankSRank, 9);
    expect(single.tankARank, 6);
  });

  for (final (masterId, category, ordinaryPerItem, tankFourItems) in [
    (576, 24, 8, 96),
    (514, 24, 8, 92),
    (449, 24, 8, 84),
    (355, 24, 8, 80),
    (230, 24, 8, 76),
    (495, 24, 8, 76),
    (482, 24, 8, 76),
    (494, 24, 8, 68),
    (436, 24, 8, 64),
    (166, 24, 8, 56),
    (68, 24, 8, 24),
    (9999, 24, 8, 24),
    (526, 46, 2, 54),
    (167, 46, 2, 50),
    (525, 46, 2, 46),
    (499, 52, 0, 56),
    (498, 52, 0, 36),
    (497, 52, 0, 28),
    (496, 52, 0, 20),
    (75, 30, 5, 15),
    (145, 43, 1, 3),
    (9999, 1, 0, 0),
  ]) {
    test('ordinary and tank cargo values for Master $masterId', () {
      // Four copies expose fractional values. The last is the expansion slot.
      final state = fleetState.copyWith(
        ships: const {
          101: OwnedShip(
            id: 101,
            masterId: 2,
            level: 99,
            slotIds: [701, 702, 703],
            extraSlotId: 704,
          ),
        },
        slotItems: {
          for (final itemId in [701, 702, 703, 704])
            itemId: OwnedSlotItem(
              instanceId: itemId,
              masterSlotItemId: masterId,
              level: 10,
            ),
        },
        masterSlotItems: {
          masterId: MasterSlotItem(
            id: masterId,
            name: 'Fixture item',
            type: [0, 0, category, 24],
          ),
        },
      );
      final result = FleetTransportPoints.fromState(state, [mainFleet])!;
      expect(result.sRank, ordinaryPerItem * 4);
      expect(result.tankSRank, tankFourItems);
      expect(result.tankARank, tankFourItems * 7 ~/ 10);
    });
  }

  test('tank fractions are summed before the per-fleet floor', () {
    final state = _recordedState([
      [
        (type: 2, masterId: 1, equipment: [75, 167]),
      ],
    ]);
    final result = FleetTransportPoints.fromState(state, state.fleets)!;
    expect(result.sRank, 12);
    // Destroyer 3.75 + drum 3.75 + Ka-Mi 12.5.
    expect(result.tankSRank, 20);
    expect(result.tankARank, 14);
  });

  test('matches poi recorded ordinary 205 and tank 446 fleet', () {
    // poooi/plugin-prophet e0deeca, transport.test.ts recorded E-5 fixture.
    final state = _recordedState([
      [
        (type: 22, masterId: 1008, equipment: [56, 56, 107]),
        (type: 17, masterId: 727, equipment: [499, 498, 497]),
        (type: 2, masterId: 548, equipment: [166, 230, 230]),
        (type: 2, masterId: 418, equipment: [495, 449, 230]),
        (type: 2, masterId: 435, equipment: [436, 495, 514]),
        (type: 2, masterId: 434, equipment: [514, 449, 436]),
      ],
      [
        (type: 3, masterId: 693, equipment: [520, 520, 538, 126]),
        (type: 5, masterId: 428, equipment: [50, 362, 279, 118, 483]),
        (type: 2, masterId: 489, equipment: [576, 167, 355]),
        (type: 2, masterId: 568, equipment: [167, 526, 526]),
        (type: 2, masterId: 745, equipment: [366, 366, 449, 575]),
        (type: 2, masterId: 959, equipment: [455, 294, 482]),
      ],
    ]);
    final result = FleetTransportPoints.forFleet(state, state.fleets.first)!;
    expect(result.sRank, 205);
    expect(result.aRank, 143);
    expect(result.tankSRank, 446);
    expect(result.tankARank, 312);
    expect(result.contributions.map((part) => part.tankPoints), [294, 152]);
  });

  test('matches poi recorded tank 468 fleet with Kinu in escort', () {
    final state = _recordedState([
      [
        (type: 9, masterId: 918, equipment: [276, 276, 107, 515]),
        (type: 10, masterId: 411, equipment: [290, 318, 526, 538, 483]),
        (type: 10, masterId: 412, equipment: [290, 290, 526, 471, 483]),
        (type: 7, masterId: 283, equipment: [100, 244, 422, 473, 274]),
        (type: 16, masterId: 348, equipment: [576, 449, 495, 274]),
        (type: 2, masterId: 960, equipment: [576, 449, 495, 517]),
      ],
      [
        (type: 3, masterId: 487, equipment: [166, 166, 436, 173]),
        (type: 2, masterId: 587, equipment: [514, 449, 230]),
        (type: 2, masterId: 667, equipment: [514, 355, 230]),
        (type: 2, masterId: 469, equipment: [436, 482, 230]),
        (type: 2, masterId: 498, equipment: [166, 166, 494]),
        (type: 4, masterId: 146, equipment: [309, 179, 179, 412]),
      ],
    ]);
    final result = FleetTransportPoints.fromState(state, state.fleets)!;
    expect(result.kinuBonus, 8);
    expect(result.tankSRank, 468);
    expect(result.tankARank, 327);
    expect(result.contributions.map((part) => part.tankPoints), [176, 284]);
  });

  test('empty or incomplete fleet data has no score', () {
    final state = fleetState.copyWith(
      combinedFleetType: CombinedFleetType.surfaceTaskForce,
      fleets: [mainFleet, thirdFleet],
    );
    expect(FleetTransportPoints.forFleet(state, mainFleet), isNull);
    expect(FleetTransportPoints.fromState(state, []), isNull);
    expect(
      FleetTransportPoints.fromState(state, [
        const Fleet(id: 4, name: 'Empty', shipIds: [-1, 0]),
      ]),
      isNull,
    );
    expect(
      FleetTransportPoints.fromState(state.copyWith(ships: {}), [mainFleet]),
      isNull,
    );
    expect(
      FleetTransportPoints.fromState(state.copyWith(masterShips: {}), [
        mainFleet,
      ]),
      isNull,
    );
  });

  test('unresolved equipped items or missing categories have no score', () {
    final state = fleetState.copyWith(
      ships: const {
        101: OwnedShip(id: 101, masterId: 1, level: 99, slotIds: [401]),
      },
    );
    expect(FleetTransportPoints.fromState(state, [mainFleet]), isNull);
    final ownedOnly = state.copyWith(
      slotItems: const {
        401: OwnedSlotItem(instanceId: 401, masterSlotItemId: 501),
      },
    );
    expect(FleetTransportPoints.fromState(ownedOnly, [mainFleet]), isNull);
    final noCategory = ownedOnly.copyWith(
      masterSlotItems: const {501: MasterSlotItem(id: 501, name: 'Unknown')},
    );
    expect(FleetTransportPoints.fromState(noCategory, [mainFleet]), isNull);
  });
}

typedef _RecordedShip = ({int type, int masterId, List<int> equipment});

GameState _recordedState(List<List<_RecordedShip>> recordedFleets) {
  final fleets = <Fleet>[];
  final ships = <int, OwnedShip>{};
  final masterShips = <int, MasterShip>{};
  final items = <int, OwnedSlotItem>{};
  final masterItems = <int, MasterSlotItem>{};
  for (final (fleetIndex, recordedShips) in recordedFleets.indexed) {
    final shipIds = <int>[];
    for (final recorded in recordedShips) {
      final shipId = ships.length + 1;
      final itemIds = <int>[];
      for (final masterItemId in recorded.equipment) {
        final itemId = items.length + 1;
        itemIds.add(itemId);
        items[itemId] = OwnedSlotItem(
          instanceId: itemId,
          masterSlotItemId: masterItemId,
        );
        masterItems[masterItemId] = MasterSlotItem(
          id: masterItemId,
          name: 'Item $masterItemId',
          type: [0, 0, _recordedEquipmentCategory(masterItemId)],
        );
      }
      shipIds.add(shipId);
      ships[shipId] = OwnedShip(
        id: shipId,
        masterId: recorded.masterId,
        level: 99,
        slotIds: itemIds,
      );
      masterShips[recorded.masterId] = MasterShip(
        id: recorded.masterId,
        name: 'Ship $shipId',
        shipTypeId: recorded.type,
      );
    }
    fleets.add(Fleet(id: fleetIndex + 1, name: 'Fleet', shipIds: shipIds));
  }
  return GameState(
    fleets: fleets,
    ships: ships,
    masterShips: masterShips,
    slotItems: items,
    masterSlotItems: masterItems,
    combinedFleetType: fleets.length == 2
        ? CombinedFleetType.transportEscort
        : CombinedFleetType.none,
  );
}

int _recordedEquipmentCategory(int masterId) {
  if (const {
    68,
    166,
    193,
    230,
    355,
    408,
    409,
    436,
    449,
    482,
    494,
    495,
    514,
    576,
  }.contains(masterId)) {
    return 24;
  }
  if (const {167, 525, 526}.contains(masterId)) return 46;
  if (const {496, 497, 498, 499}.contains(masterId)) return 52;
  if (const {145, 150, 241}.contains(masterId)) return 43;
  return masterId == 75 ? 30 : 1;
}
