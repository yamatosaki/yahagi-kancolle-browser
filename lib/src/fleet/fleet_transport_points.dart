import '../game_state/game_state.dart';

class FleetTransportContribution {
  const FleetTransportContribution({
    required this.fleetId,
    required this.points,
  });

  final int fleetId;
  final int points;
}

/// Planned TP for a normal transport operation using the saved equipment loadout.
class FleetTransportPoints {
  FleetTransportPoints._(
    List<FleetTransportContribution> contributions,
    this.kinuBonus,
  ) : contributions = List.unmodifiable(contributions),
      sRank = contributions.fold(kinuBonus, (sum, entry) => sum + entry.points);

  final List<FleetTransportContribution> contributions;
  final int kinuBonus;
  final int sRank;
  int get aRank => sRank * 7 ~/ 10;
  bool get isCombined => contributions.length == 2;

  /// Uses the current combined configuration for fleets one and two.
  static FleetTransportPoints? forFleet(GameState state, Fleet fleet) {
    if (state.combinedFleetType == CombinedFleetType.none ||
        (fleet.id != 1 && fleet.id != 2)) {
      return fromState(state, [fleet]);
    }

    final partnerId = fleet.id == 1 ? 2 : 1;
    for (final partner in state.fleets) {
      if (partner.id == partnerId) {
        return fromState(state, [fleet, partner]);
      }
    }
    return null;
  }

  /// Scores a single fleet or an explicitly paired main and escort fleet.
  /// Incomplete ship or equipment data yields no estimate.
  static FleetTransportPoints? fromState(
    GameState state,
    Iterable<Fleet> fleets,
  ) {
    final sorted = fleets.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    if (sorted.length != 1 &&
        (sorted.length != 2 || sorted.first.id != 1 || sorted.last.id != 2)) {
      return null;
    }

    final contributions = <FleetTransportContribution>[];
    var hasKinu = false;
    for (final fleet in sorted) {
      var points = 0;
      var hasShips = false;
      for (final shipId in fleet.shipIds) {
        if (shipId <= 0) continue;
        final ship = state.ships[shipId];
        if (ship == null) return null;
        final master = state.masterForShip(ship);
        if (master == null || master.shipTypeId <= 0) return null;

        hasShips = true;
        if (master.id == _kinuKaiNiId) hasKinu = true;
        points += _shipTypePoints[master.shipTypeId] ?? 0;
        for (final itemId in [...ship.slotIds, ship.extraSlotId]) {
          if (itemId <= 0) continue;
          final item = state.slotItems[itemId];
          if (item == null) return null;
          final type = state.masterSlotItems[item.masterSlotItemId]?.type;
          if (type == null || type.length < 3 || type[2] <= 0) return null;
          points += _equipmentTypePoints[type[2]] ?? 0;
        }
      }
      if (!hasShips) return null;
      contributions.add(
        FleetTransportContribution(fleetId: fleet.id, points: points),
      );
    }
    return FleetTransportPoints._(contributions, hasKinu ? _kinuBonus : 0);
  }
}

const _kinuKaiNiId = 487;
const _kinuBonus = 8;

const _shipTypePoints = {
  2: 5, // Destroyer
  3: 2, // Light cruiser
  6: 4, // Aviation cruiser
  10: 7, // Aviation battleship
  14: 1, // Aircraft-carrying submarine
  15: 15, // Fleet oiler
  16: 9, // Seaplane tender
  17: 12, // Landing ship
  20: 7, // Submarine tender
  21: 6, // Training cruiser
  22: 15, // Fleet oiler
};

const _equipmentTypePoints = {
  24: 8, // Landing craft
  30: 5, // Transport drum
  43: 1, // Combat rations
  46: 2, // Amphibious tank
};
