import 'dart:async';

import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'fleet_ship_status_capsule.dart';

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
  int _selectedFleetId = 1;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FleetSegmentedSwitcher(
                fleets: state.fleets,
                selectedFleetId: _selectedFleetId,
                onSelected: (id) => setState(() => _selectedFleetId = id),
              ),
              const SizedBox(height: 8),
              if (state.shipsForFleet(_selectedFleetId).isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const Text('无数据', style: TextStyle(color: Color(0xff8197a5))),
                )
              else
                for (final ship in state.shipsForFleet(_selectedFleetId)) ...[
                  FleetShipStatusCapsule(
                    state: state,
                    ship: ship,
                    onTap: () => widget.onOpenFleet(_selectedFleetId),
                  ),
                  if (ship != state.shipsForFleet(_selectedFleetId).last)
                    const SizedBox(height: 3),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _FleetSegmentedSwitcher extends StatelessWidget {
  const _FleetSegmentedSwitcher({
    required this.fleets,
    required this.selectedFleetId,
    required this.onSelected,
  });

  final List<Fleet> fleets;
  final int selectedFleetId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final visibleFleets = fleets.take(4).toList();
    return Container(
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xff102331),
        border: Border.all(color: const Color(0xff294052)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: visibleFleets.map((fleet) {
          final isSelected = fleet.id == selectedFleetId;
          return Expanded(
            child: Material(
              color: isSelected ? const Color(0xff8a6628) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onSelected(fleet.id),
                borderRadius: BorderRadius.circular(6),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      fleet.name,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xffffdc88)
                            : const Color(0xff9fb3bf),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
