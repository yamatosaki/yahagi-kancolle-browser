import 'package:flutter/material.dart';
import '../game_state/fleet_metrics.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';
import 'combat_mechanism.dart';
import 'ship_repair_status.dart';
import 'fleet_ui_strings.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'fleet_ship_status_capsule.dart';
import 'fleet_line_of_sight_details.dart';
import '../performance/second_tick_scope.dart';
import '../settings/layout_settings_store.dart';
import '../settings/battle_status_effect_settings.dart';
import 'fleet_air_power_details.dart';
import 'morale_recovery_display.dart';
import 'morale_recovery_timer_controller.dart';

class FleetSummaryCard extends StatefulWidget {
  const FleetSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenFleet,
    this.damagePulseFilter = DamagePulseFilter.all,
    this.moraleSparkleEnabled = true,
    this.moraleRecoveryTimerController,
    this.moraleMetricMode = FleetMoraleMetricMode.minimumCondition,
    this.onToggleMoraleMetricMode,
    this.clock,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenFleet;
  final DamagePulseFilter damagePulseFilter;
  final bool moraleSparkleEnabled;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final FleetMoraleMetricMode moraleMetricMode;
  final VoidCallback? onToggleMoraleMetricMode;
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
        animation: Listenable.merge([
          widget.controller,
          if (widget.moraleRecoveryTimerController != null)
            widget.moraleRecoveryTimerController!,
        ]),
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
                _FleetSummaryMetrics(
                  state: state,
                  fleetId: _selectedFleetId,
                  metrics: metrics,
                  now: now,
                  moraleRecoveryTimerController:
                      widget.moraleRecoveryTimerController,
                  moraleMetricMode: widget.moraleMetricMode,
                  onToggleMoraleMetricMode: widget.onToggleMoraleMetricMode,
                ),
                const SizedBox(height: 6),
                if (ships.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: Text(
                      fleetText(context, '无数据'),
                      style: TextStyle(color: Color(0xff8197a5)),
                    ),
                  )
                else
                  for (final ship in ships) ...[
                    FleetShipStatusCapsule(
                      state: state,
                      ship: ship,
                      damagePulseFilter: widget.damagePulseFilter,
                      moraleSparkleEnabled: widget.moraleSparkleEnabled,
                      repairStatus: shipRepairStatusFor(
                        state: state,
                        shipId: ship.id,
                        anchorageRepairStartedAt:
                            widget.controller.anchorageRepairStartedAt,
                        nosakiSparkleStartedAt:
                            widget.controller.nosakiSparkleStartedAt,
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
  const _FleetSummaryMetrics({
    required this.state,
    required this.fleetId,
    required this.metrics,
    required this.now,
    required this.moraleRecoveryTimerController,
    required this.moraleMetricMode,
    required this.onToggleMoraleMetricMode,
  });

  final GameState state;
  final int fleetId;
  final FleetMetrics? metrics;
  final DateTime now;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final FleetMoraleMetricMode moraleMetricMode;
  final VoidCallback? onToggleMoraleMetricMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requiredL10n = l10n ?? lookupAppLocalizations(const Locale('zh'));
    final noValue = l10n?.noValue ?? '—';
    final current = metrics;
    final airPower = current?.airPower;
    final airPowerMaximum = current?.airPowerMaximum;
    final hasAirPowerDetails =
        airPower != null &&
        airPowerMaximum != null &&
        current?.airPowerWithoutProficiency != null;
    final showsCountdown =
        moraleRecoveryTimerController != null &&
        moraleMetricMode == FleetMoraleMetricMode.recoveryCountdown;
    final moraleLabel = showsCountdown
        ? requiredL10n.moraleRecoveryCountdown
        : (l10n?.averageCondition ?? '最低疲劳');
    final moraleValue = showsCountdown
        ? fleetMoraleRecoveryDisplay(
            state: state,
            fleetId: fleetId,
            targetAt: moraleRecoveryTimerController?.targetForFleet(fleetId),
            now: now,
            recoveredLabel: requiredL10n.moraleRecovered,
            noValueLabel: '—',
          )
        : (current == null ? noValue : '${current.minimumCondition}');
    final values = <(String, String, String)>[
      (
        'speed',
        l10n?.speed ?? '速度',
        fleetText(context, current?.speedLabel ?? noValue),
      ),
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
      ('minimum-condition', moraleLabel, moraleValue),
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
              semanticLabel: switch (values[index].$1) {
                'air-power' when hasAirPowerDetails =>
                  requiredL10n.showAirPowerDetails,
                'minimum-condition' => requiredL10n.toggleMoraleMetric,
                _ => null,
              },
              onTap:
                  values[index].$1 == 'air-power' &&
                      hasAirPowerDetails &&
                      current != null
                  ? () => showFleetAirPowerDetails(context, current)
                  : values[index].$1 == 'line-of-sight' &&
                        current != null &&
                        current.formula33.isNotEmpty
                  ? () => showFleetLineOfSightDetails(context, current)
                  : values[index].$1 == 'minimum-condition'
                  ? onToggleMoraleMetricMode
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
    this.semanticLabel,
  });

  final String id;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Material(
    key: Key('fleet-summary-metric-$id'),
    color: const Color(0xff102331),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(color: Color(0xff294052)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      button: onTap != null,
      label: semanticLabel,
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
    ),
  );
}
