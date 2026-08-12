import 'package:flutter/material.dart';
import '../game_state/fleet_metrics.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';
import 'combat_mechanism.dart';
import 'ship_status_style.dart';
import 'ship_repair_status.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'fleet_ship_status_capsule.dart';
import 'fleet_line_of_sight_details.dart';
import '../performance/second_tick_scope.dart';

class FleetSummaryCard extends StatefulWidget {
  const FleetSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenFleet,
    this.damagePulseMode = DamagePulseMode.enhanced,
    this.clock,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenFleet;
  final DamagePulseMode damagePulseMode;
  final DateTime Function()? clock;

  @override
  State<FleetSummaryCard> createState() => _FleetSummaryCardState();
}

class _FleetSummaryCardState extends State<FleetSummaryCard> {
  int _selectedFleetId = 1;

  @override
  Widget build(BuildContext context) {
    return SecondTickBuilder(
      now: widget.clock,
      builder: (context, now, _) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          final fleetIndex = state.fleets.indexWhere(
            (fleet) => fleet.id == _selectedFleetId,
          );
          final selectedFleet = fleetIndex < 0
              ? null
              : state.fleets[fleetIndex];
          final ships = state.shipsForFleet(_selectedFleetId);
          final metrics = selectedFleet == null
              ? null
              : FleetMetrics.fromState(state, selectedFleet);
          final specialAttack = selectedFleet == null
              ? null
              : detectFleetSpecialAttack(state, selectedFleet);
          return DashboardCard(
            title: AppLocalizations.of(context)?.fleetBrief ?? '编队简报',
            icon: const Icon(Icons.directions_boat_filled_outlined),
            collapsed: widget.collapsed,
            onToggleCollapse: widget.onToggleCollapse,
            trailing: _FleetSegmentedSwitcher(
              fleets: state.fleets,
              selectedFleetId: _selectedFleetId,
              onSelected: (id) => setState(() => _selectedFleetId = id),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FleetSummaryMetrics(metrics: metrics),
                const SizedBox(height: 6),
                if (ships.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      '无数据',
                      style: TextStyle(color: Color(0xff8197a5)),
                    ),
                  )
                else
                  for (final ship in ships) ...[
                    FleetShipStatusCapsule(
                      state: state,
                      ship: ship,
                      damagePulseMode: widget.damagePulseMode,
                      repairStatus: shipRepairStatusFor(
                        state: state,
                        shipId: ship.id,
                        anchorageRepairStartedAt:
                            widget.controller.anchorageRepairStartedAt,
                        now: now,
                      ),
                      specialAttack: ship == ships.first ? specialAttack : null,
                      onTap: () => widget.onOpenFleet(_selectedFleetId),
                    ),
                    if (ship != ships.last) const SizedBox(height: 3),
                  ],
              ],
            ),
          );
        },
      ),
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
      key: const Key('fleet-summary-switcher'),
      width: 108,
      height: 22,
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
              key: Key('fleet-summary-selector-${fleet.id}'),
              color: isSelected ? const Color(0xff8a6628) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onSelected(fleet.id),
                borderRadius: BorderRadius.circular(6),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${fleet.id}',
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xffffdc88)
                            : const Color(0xff9fb3bf),
                        fontSize: 10,
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

class _FleetSummaryMetrics extends StatelessWidget {
  const _FleetSummaryMetrics({required this.metrics});

  final FleetMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final noValue = l10n?.noValue ?? '—';
    final current = metrics;
    final airPower = current?.airPower;
    final airPowerMaximum = current?.airPowerMaximum;
    final values = <(String, String, String)>[
      ('speed', l10n?.speed ?? '速度', current?.speedLabel ?? noValue),
      (
        'total-level',
        l10n?.totalLevel ?? '总等级',
        current == null ? noValue : '${current.totalLevel}',
      ),
      (
        'air-power',
        l10n?.airPower ?? '制空',
        airPower == null
            ? noValue
            : airPowerMaximum != null && airPowerMaximum > airPower
            ? '$airPower+'
            : '$airPower',
      ),
      (
        'line-of-sight',
        l10n?.lineOfSight ?? '索敌',
        current == null ? noValue : '${current.lineOfSight}',
      ),
      (
        'minimum-condition',
        l10n?.averageCondition ?? '最低疲劳',
        current == null ? noValue : '${current.minimumCondition}',
      ),
    ];
    return Row(
      key: const Key('fleet-summary-metrics'),
      children: [
        for (var index = 0; index < values.length; index++) ...[
          Expanded(
            child: _FleetSummaryMetric(
              id: values[index].$1,
              label: values[index].$2,
              value: values[index].$3,
              onTap:
                  values[index].$1 == 'line-of-sight' &&
                      current != null &&
                      current.formula33.isNotEmpty
                  ? () => showFleetLineOfSightDetails(context, current)
                  : null,
            ),
          ),
          if (index != values.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _FleetSummaryMetric extends StatelessWidget {
  const _FleetSummaryMetric({
    required this.id,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String id;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: Key('fleet-summary-metric-$id'),
    color: const Color(0xff102331),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(color: Color(0xff294052)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xff8197a5),
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  key: Key('fleet-summary-metric-$id-value'),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xffdce6eb),
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
