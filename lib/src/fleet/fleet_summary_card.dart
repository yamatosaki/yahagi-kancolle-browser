import 'dart:async';

import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';
import 'fleet_status_visual.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class FleetSummaryCard extends StatefulWidget {
  const FleetSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenFleet,
    this.clock,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenFleet;
  final DateTime Function()? clock;

  @override
  State<FleetSummaryCard> createState() => _FleetSummaryCardState();
}

class _FleetSummaryCardState extends State<FleetSummaryCard> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return DashboardCard(
          title: AppLocalizations.of(context)?.fleetBrief ?? '编队简报',
          icon: const Icon(Icons.directions_boat_filled_outlined),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
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
    final visual = fleetStatusVisual(fleet, now: widget.clock?.call());
    return _buildFleetStatus(fleetId, fleet.name, visual.label, visual.color);
  }

  Widget _buildFleetStatus(
    int id,
    String name,
    String status,
    Color statusColor,
  ) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onOpenFleet(id),
          borderRadius: BorderRadius.circular(6),
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
                      key: Key('fleet-status-dot-$id'),
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
        ),
      ),
    );
  }
}
