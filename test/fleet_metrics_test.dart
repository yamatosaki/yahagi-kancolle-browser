import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/fleet_metrics.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test('calculates totals and uses the slowest ship as fleet speed', () {
    const fleet = Fleet(id: 1, name: '第一舰队', shipIds: <int>[9001, 9002]);
    const state = GameState(
      masterShips: <int, MasterShip>{
        101: MasterShip(id: 101, name: '甲', shipTypeId: 2, speed: 10),
        102: MasterShip(id: 102, name: '乙', shipTypeId: 3, speed: 15),
      },
      ships: <int, OwnedShip>{
        9001: OwnedShip(
          id: 9001,
          masterId: 101,
          level: 80,
          condition: 49,
          firepower: 58,
          torpedo: 40,
          antiAir: 44,
          antiSub: 30,
          lineOfSight: 20,
        ),
        9002: OwnedShip(
          id: 9002,
          masterId: 102,
          level: 64,
          condition: 35,
          firepower: 40,
          torpedo: 60,
          antiAir: 30,
          antiSub: 45,
          lineOfSight: 18,
        ),
      },
    );

    final metrics = FleetMetrics.fromState(state, fleet);

    expect(metrics.totalLevel, 144);
    expect(metrics.firepower, 98);
    expect(metrics.torpedo, 100);
    expect(metrics.speedLabel, '高速');
    expect(metrics.averageCondition, 42);
  });

  test('returns unknown air power when an equipped item is unresolved', () {
    const fleet = Fleet(id: 1, name: '第一舰队', shipIds: <int>[9001]);
    const state = GameState(
      masterShips: <int, MasterShip>{
        101: MasterShip(id: 101, name: '甲', shipTypeId: 2, speed: 10),
      },
      ships: <int, OwnedShip>{
        9001: OwnedShip(
          id: 9001,
          masterId: 101,
          level: 1,
          slotIds: <int>[7001],
          onSlot: <int>[18],
        ),
      },
    );

    expect(FleetMetrics.fromState(state, fleet).airPower, isNull);
  });

  test('uses equipment-modified owned ship speed before master speed', () {
    const fleet = Fleet(id: 1, name: '第一舰队', shipIds: <int>[9001]);
    const state = GameState(
      masterShips: <int, MasterShip>{
        101: MasterShip(id: 101, name: '岛风改', shipTypeId: 2, speed: 10),
      },
      ships: <int, OwnedShip>{
        9001: OwnedShip(id: 9001, masterId: 101, level: 94, speed: 15),
      },
    );

    expect(FleetMetrics.fromState(state, fleet).speedLabel, '高速+');
  });

  test('calculates Yahagi-compatible formula 33 for map modifiers 1 to 4', () {
    const fleet = Fleet(
      id: 1,
      name: '第一舰队',
      shipIds: <int>[9001, 9002],
      slotCount: 6,
    );
    const state = GameState(
      admiralLevel: 120,
      masterShips: <int, MasterShip>{
        101: MasterShip(id: 101, name: '甲', shipTypeId: 2),
        102: MasterShip(id: 102, name: '乙', shipTypeId: 3),
      },
      masterSlotItems: <int, MasterSlotItem>{
        201: MasterSlotItem(
          id: 201,
          name: '水侦',
          lineOfSight: 5,
          type: <int>[5, 7, 10, 10, 0],
        ),
      },
      slotItems: <int, OwnedSlotItem>{
        7001: OwnedSlotItem(id: 7001, masterId: 201),
      },
      ships: <int, OwnedShip>{
        9001: OwnedShip(
          id: 9001,
          masterId: 101,
          level: 50,
          lineOfSight: 22,
          slotIds: <int>[7001],
        ),
        9002: OwnedShip(id: 9002, masterId: 102, level: 44, lineOfSight: 18),
      },
    );

    final metrics = FleetMetrics.fromState(state, fleet);

    expect(metrics.lineOfSight, 40);
    expect(metrics.formula33, hasLength(4));
    expect(metrics.formula33[0].total, closeTo(-25.6343, 0.0001));
    expect(metrics.formula33[1].total, closeTo(-19.6343, 0.0001));
    expect(metrics.formula33[2].total, closeTo(-13.6343, 0.0001));
    expect(metrics.formula33[3].total, closeTo(-7.6343, 0.0001));
  });

  test('does not fabricate formula 33 before admiral level is captured', () {
    const fleet = Fleet(id: 1, name: '第一舰队');
    const state = GameState();

    expect(FleetMetrics.fromState(state, fleet).formula33, isEmpty);
  });
}
