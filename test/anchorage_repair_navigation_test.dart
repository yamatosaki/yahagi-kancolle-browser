import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_navigation.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  test('prefers the lowest fleet id among repairing fleets', () {
    expect(
      preferredAnchorageRepairFleetId(
        state: _stateWithRepairingFleets(<int>{2, 3}),
        elapsed: Duration.zero,
      ),
      2,
    );
  });

  test('selects fleet 3 when it is the only repairing fleet', () {
    expect(
      preferredAnchorageRepairFleetId(
        state: _stateWithRepairingFleets(<int>{3}),
        elapsed: Duration.zero,
      ),
      3,
    );
  });

  test('falls back to fleet 1 when no fleet is repairing', () {
    expect(
      preferredAnchorageRepairFleetId(
        state: _stateWithRepairingFleets(const <int>{}),
        elapsed: Duration.zero,
      ),
      1,
    );
    expect(
      preferredAnchorageRepairFleetId(
        state: const GameState(),
        elapsed: Duration.zero,
      ),
      1,
    );
  });
}

GameState _stateWithRepairingFleets(Set<int> repairingFleetIds) {
  final ships = <int, OwnedShip>{};
  final fleets = <Fleet>[];
  for (final fleetId in <int>[3, 1, 2]) {
    final flagshipId = fleetId * 10 + 1;
    final escortId = fleetId * 10 + 2;
    ships[flagshipId] = OwnedShip(
      id: flagshipId,
      masterId: 187,
      level: 80,
      currentHp: 39,
      maxHp: 39,
    );
    ships[escortId] = OwnedShip(
      id: escortId,
      masterId: 501,
      level: 50,
      currentHp: repairingFleetIds.contains(fleetId) ? 24 : 30,
      maxHp: 30,
      repairDurationMilliseconds: 1830000,
    );
    fleets.add(
      Fleet(
        id: fleetId,
        name: '第 $fleetId 舰队',
        shipIds: <int>[flagshipId, escortId],
      ),
    );
  }
  return GameState(
    hasMasterData: true,
    hasPortData: true,
    masterShips: const <int, MasterShip>{
      187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
      501: MasterShip(id: 501, name: '测试舰', shipTypeId: 9),
    },
    ships: ships,
    fleets: fleets,
  );
}
