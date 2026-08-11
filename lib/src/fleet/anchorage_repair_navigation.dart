import '../game_state/game_state.dart';
import 'anchorage_repair_calculator.dart';

int preferredAnchorageRepairFleetId({
  required GameState state,
  required Duration elapsed,
}) {
  final fleetIds = state.fleets.map((fleet) => fleet.id).toList()..sort();
  for (final fleetId in fleetIds) {
    final projection = AnchorageRepairCalculator.project(
      state: state,
      fleetId: fleetId,
      elapsed: elapsed,
    );
    if (projection.rows.any(
      (row) => row.status == AnchorageRepairShipStatus.repairing,
    )) {
      return fleetId;
    }
  }
  return 1;
}
