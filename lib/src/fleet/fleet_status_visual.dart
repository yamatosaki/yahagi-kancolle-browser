import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'operation_progress.dart';
import 'ship_status_style.dart';

enum FleetOperationalStatus { standby, expedition, returned, empty }

class FleetStatusVisual {
  const FleetStatusVisual(this.status, this.label, this.color);

  final FleetOperationalStatus status;
  final String label;
  final Color color;
}

FleetStatusVisual fleetStatusVisual(Fleet fleet, {DateTime? now}) {
  if (fleet.mission.isActive) {
    if (operationIsCompleted(fleet.mission.completionTime, now: now)) {
      return const FleetStatusVisual(
        FleetOperationalStatus.returned,
        '已返母港',
        Color(0xff03a9f4),
      );
    }
    return const FleetStatusVisual(
      FleetOperationalStatus.expedition,
      '远征中',
      Color(0xffffc940),
    );
  }
  if (fleet.shipIds.isEmpty) {
    return const FleetStatusVisual(
      FleetOperationalStatus.empty,
      '未编成',
      Color(0xff8197a5),
    );
  }
  return const FleetStatusVisual(
    FleetOperationalStatus.standby,
    '母港待命',
    yahagiStatusGreen,
  );
}
