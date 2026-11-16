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
      expect(transport.contributions.map((entry) => entry.fleetId), [1, 2]);
      expect(transport.contributions.map((entry) => entry.points), [5, 5]);
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
    expect(combined.contributions.map((entry) => entry.points), [2, 2]);

    final single = FleetTransportPoints.fromState(state, [escort])!;
    expect(single.sRank, 10);
    expect(single.aRank, 7);
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
