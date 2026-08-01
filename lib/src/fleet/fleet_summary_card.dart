import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class FleetSummaryCard extends StatelessWidget {
  const FleetSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return DashboardCard(
          title: AppLocalizations.of(context)?.fleetBrief ?? '编队简报',
          icon: const Icon(Icons.directions_boat_filled_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildDynamicFleetStatus(1, state),
                  const SizedBox(width: 8),
                  _buildDynamicFleetStatus(2, state),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildDynamicFleetStatus(3, state),
                  const SizedBox(width: 8),
                  _buildDynamicFleetStatus(4, state),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDynamicFleetStatus(int fleetId, GameState state) {
    final fleetIndex = fleetId - 1;
    if (fleetIndex >= state.fleets.length) {
      return _buildFleetStatus(fleetId, '舰队', '未知', const Color(0xff8197a5));
    }

    final fleet = state.fleets[fleetIndex];
    if (fleet.mission.isActive) {
      return _buildFleetStatus(
        fleetId,
        fleet.name,
        '远征中',
        const Color(0xff03a9f4),
      );
    } else if (fleet.shipIds.isEmpty) {
      return _buildFleetStatus(
        fleetId,
        fleet.name,
        '无舰娘',
        const Color(0xff8197a5),
      );
    } else {
      return _buildFleetStatus(
        fleetId,
        fleet.name,
        '母港待机',
        const Color(0xff4caf50),
      );
    }
  }

  Widget _buildFleetStatus(
    int id,
    String name,
    String status,
    Color statusColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xff0d1a26),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xff8197a5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
