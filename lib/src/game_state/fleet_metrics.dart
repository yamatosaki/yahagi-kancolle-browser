import 'dart:math' as math;

import 'game_state.dart';

class Formula33Result {
  const Formula33Result({
    required this.mapModifier,
    required this.ship,
    required this.equipment,
    required this.admiralPenalty,
    required this.emptySlotBonus,
  });

  final double mapModifier;
  final double ship;
  final double equipment;
  final int admiralPenalty;
  final int emptySlotBonus;

  double get total => ship + equipment - admiralPenalty + emptySlotBonus;
}

class FleetMetrics {
  const FleetMetrics({
    required this.shipCount,
    required this.totalLevel,
    required this.firepower,
    required this.torpedo,
    required this.antiAir,
    required this.antiSub,
    required this.lineOfSight,
    required this.formula33,
    required this.averageCondition,
    required this.speedLabel,
    required this.airPower,
  });

  final int shipCount;
  final int totalLevel;
  final int firepower;
  final int torpedo;
  final int antiAir;
  final int antiSub;
  final int lineOfSight;
  final List<Formula33Result> formula33;
  final int averageCondition;
  final String speedLabel;
  final int? airPower;

  factory FleetMetrics.fromState(GameState state, Fleet fleet) {
    final ships = <OwnedShip>[for (final id in fleet.shipIds) ?state.ships[id]];
    var totalLevel = 0;
    var firepower = 0;
    var torpedo = 0;
    var antiAir = 0;
    var antiSub = 0;
    var lineOfSight = 0;
    var formula33Ship = 0.0;
    var formula33EquipmentBase = 0.0;
    var formula33Known = state.admiralLevel > 0;
    var totalCondition = 0;
    int? slowestSpeed;
    var calculatedAirPower = 0;
    var airPowerKnown = true;

    for (final ship in ships) {
      totalLevel += ship.level;
      firepower += ship.firepower;
      torpedo += ship.torpedo;
      antiAir += ship.antiAir;
      antiSub += ship.antiSub;
      lineOfSight += ship.lineOfSight;
      totalCondition += ship.condition;

      var shipPureLineOfSight = ship.lineOfSight.toDouble();
      for (final equipped in state.equipmentForShip(ship)) {
        final master = equipped.master;
        if (master == null) {
          formula33Known = false;
          continue;
        }
        shipPureLineOfSight -= master.lineOfSight;
        final improvement = math.sqrt(equipped.owned.level);
        final typeId = master.type.length > 2 ? master.type[2] : -1;
        formula33EquipmentBase += switch (typeId) {
          8 => master.lineOfSight * 0.8,
          9 => master.lineOfSight * 1.0,
          10 => (master.lineOfSight + 1.2 * improvement) * 1.2,
          11 => (master.lineOfSight + 1.15 * improvement) * 1.1,
          12 || 13 => (master.lineOfSight + 1.25 * improvement) * 0.6,
          _ => master.lineOfSight * 0.6,
        };
      }
      formula33Ship += math.sqrt(math.max(0, shipPureLineOfSight));

      final speed = ship.effectiveSpeed(state.masterForShip(ship));
      if (speed > 0) {
        slowestSpeed = slowestSpeed == null
            ? speed
            : math.min(slowestSpeed, speed);
      }

      for (var index = 0; index < ship.slotIds.length; index++) {
        final ownedId = ship.slotIds[index];
        if (ownedId <= 0) {
          continue;
        }
        final owned = state.slotItems[ownedId];
        final master = owned == null
            ? null
            : state.masterSlotItems[owned.masterId];
        if (master == null) {
          airPowerKnown = false;
          continue;
        }
        final count = index < ship.onSlot.length ? ship.onSlot[index] : 0;
        if (count > 0 && master.antiAir > 0) {
          calculatedAirPower += (math.sqrt(count) * master.antiAir).floor();
        }
      }
    }

    final emptySlotBonus = (2 * math.max(0, fleet.slotCount - ships.length))
        .toInt();
    final admiralPenalty = (state.admiralLevel * 0.4).ceil();
    final formula33 = formula33Known
        ? <Formula33Result>[
            for (final modifier in const <double>[1, 2, 3, 4])
              Formula33Result(
                mapModifier: modifier,
                ship: formula33Ship,
                equipment: formula33EquipmentBase * modifier,
                admiralPenalty: admiralPenalty,
                emptySlotBonus: emptySlotBonus,
              ),
          ]
        : const <Formula33Result>[];

    return FleetMetrics(
      shipCount: ships.length,
      totalLevel: totalLevel,
      firepower: firepower,
      torpedo: torpedo,
      antiAir: antiAir,
      antiSub: antiSub,
      lineOfSight: lineOfSight,
      formula33: formula33,
      averageCondition: ships.isEmpty
          ? 0
          : (totalCondition / ships.length).round(),
      speedLabel: _speedLabel(slowestSpeed),
      airPower: airPowerKnown ? calculatedAirPower : null,
    );
  }

  static String _speedLabel(int? speed) {
    if (speed == null) {
      return '—';
    }
    return switch (speed) {
      >= 20 => '最速',
      >= 15 => '高速+',
      >= 10 => '高速',
      _ => '低速',
    };
  }
}
