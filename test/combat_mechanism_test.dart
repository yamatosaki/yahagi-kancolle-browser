import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/combat_mechanism.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_display.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('detectShipCombatMechanisms', () {
    test('detects generic opening ASW from ship ASW and sonar', () {
      final state = _state(
        shipTypeId: 2,
        antiSub: 100,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 1,
            name: 'Type 3 Sonar',
            type: <int>[0, 0, 0, 18, 0],
          ),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).map((item) => item.label),
        contains('先制对潜'),
      );
      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).singleWhere((item) => item.label == '先制对潜').tone,
        MechanismTone.antiSubmarine,
      );
    });

    test('does not report opening ASW below the generic threshold', () {
      final state = _state(
        shipTypeId: 2,
        antiSub: 99,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 1,
            name: 'Type 3 Sonar',
            type: <int>[0, 0, 0, 18, 0],
          ),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).map((item) => item.label),
        isNot(contains('先制对潜')),
      );
    });

    test('detects common anti-air cut-in equipment pattern', () {
      final state = _state(
        shipTypeId: 2,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(
            id: 1,
            name: 'High angle gun',
            type: <int>[0, 0, 1, 16, 0],
          ),
          MasterSlotItem(
            id: 2,
            name: 'AA fire director',
            type: <int>[0, 0, 36, 0, 0],
          ),
          MasterSlotItem(
            id: 3,
            name: 'AA radar',
            antiAir: 2,
            type: <int>[0, 0, 12, 11, 0],
          ),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).map((item) => item.label),
        contains('对空 CI'),
      );
      expect(
        detectShipCombatMechanisms(
          state,
          state.ships[1]!,
        ).singleWhere((item) => item.label == '对空 CI').tone,
        MechanismTone.antiAir,
      );
    });

    test('detects anti-air rocket barrage only on supported ship types', () {
      final carrier = _state(
        shipTypeId: 7,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(id: 274, name: '12cm 30-tube rocket launcher Kai Ni'),
        ],
      );
      final destroyer = _state(
        shipTypeId: 2,
        equipment: const <MasterSlotItem>[
          MasterSlotItem(id: 274, name: '12cm 30-tube rocket launcher Kai Ni'),
        ],
      );

      expect(
        detectShipCombatMechanisms(
          carrier,
          carrier.ships[1]!,
        ).map((item) => item.label),
        contains('对空喷进弹幕'),
      );
      expect(
        detectShipCombatMechanisms(
          destroyer,
          destroyer.ships[1]!,
        ).map((item) => item.label),
        isNot(contains('对空喷进弹幕')),
      );
    });
  });

  test('detects Nelson Touch as a named fleet special attack', () {
    final masters = <int, MasterShip>{
      100: const MasterShip(
        id: 100,
        name: 'Nelson改',
        shipTypeId: 9,
        classTypeId: 88,
      ),
      for (var id = 101; id <= 105; id++)
        id: MasterShip(id: id, name: 'Ship $id', shipTypeId: 2),
    };
    final ships = <int, OwnedShip>{
      for (var id = 1; id <= 6; id++)
        id: OwnedShip(
          id: id,
          masterId: id == 1 ? 100 : 99 + id,
          level: 80,
          currentHp: 40,
          maxHp: 50,
        ),
    };
    final state = GameState(
      masterShips: masters,
      ships: ships,
      fleets: const <Fleet>[
        Fleet(id: 1, name: 'First Fleet', shipIds: <int>[1, 2, 3, 4, 5, 6]),
      ],
    );

    final result = detectFleetSpecialAttack(state, state.fleets.first);

    expect(result?.label, 'Nelson Touch');
    expect(result?.label, isNot(contains('可发动')));
  });
}

GameState _state({
  required int shipTypeId,
  int antiSub = 0,
  required List<MasterSlotItem> equipment,
}) {
  final slotItems = <int, OwnedSlotItem>{};
  final masterSlotItems = <int, MasterSlotItem>{};
  final slotIds = <int>[];
  for (var index = 0; index < equipment.length; index++) {
    final ownedId = index + 10;
    slotIds.add(ownedId);
    slotItems[ownedId] = OwnedSlotItem(
      id: ownedId,
      masterId: equipment[index].id,
    );
    masterSlotItems[equipment[index].id] = equipment[index];
  }
  return GameState(
    masterShips: <int, MasterShip>{
      100: MasterShip(id: 100, name: 'Test ship', shipTypeId: shipTypeId),
    },
    ships: <int, OwnedShip>{
      1: OwnedShip(
        id: 1,
        masterId: 100,
        level: 80,
        antiSub: antiSub,
        currentHp: 30,
        maxHp: 30,
        slotIds: slotIds,
      ),
    },
    masterSlotItems: masterSlotItems,
    slotItems: slotItems,
  );
}
