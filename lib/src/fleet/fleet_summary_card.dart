import '../settings/fleet_display_options.dart';
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
    this.clock,
    this.visible = defaultFields,
    this.onOpenDisplaySettings,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenFleet;
  final DamagePulseFilter damagePulseFilter;
  final bool moraleSparkleEnabled;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final DateTime Function()? clock;
  final Set<String> visible;
  final VoidCallback? onOpenDisplaySettings;

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
            headerAction: widget.onOpenDisplaySettings == null
                ? null
                : IconButton(
                    key: const Key('fleet-display-settings-button'),
                    tooltip: fleetText(context, '编队简报显示内容'),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 19,
                      color: Color(0xffd4a85f),
                    ),
                    onPressed: widget.onOpenDisplaySettings,
                  ),
            trailing: _FleetSegmentedSwitcher(
              fleets: state.fleets,
              selectedFleetId: _selectedFleetId,
              onSelected: (id) => setState(() => _selectedFleetId = id),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.visible.any(summaryFields.contains)) ...[
                  _FleetSummaryMetrics(
                    visible: widget.visible,
                    state: state,
                    fleetId: _selectedFleetId,
                    metrics: metrics,
                    now: now,
                    moraleRecoveryTimerController:
                        widget.moraleRecoveryTimerController,
                  ),
                  const SizedBox(height: 6),
                ],
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
                      visible: widget.visible,
                      damagePulseFilter: widget.visible.contains('portrait')
                          ? widget.damagePulseFilter
                          : DamagePulseFilter.off,
                      moraleSparkleEnabled:
                          widget.visible.contains('portrait') &&
                          widget.moraleSparkleEnabled,
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
    required this.visible,
    required this.metrics,
    required this.now,
    required this.moraleRecoveryTimerController,
  });

  final GameState state;
  final int fleetId;
  final Set<String> visible;
  final FleetMetrics? metrics;
  final DateTime now;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;

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
    final recoveryValue = fleetMoraleRecoveryDisplay(
      state: state,
      fleetId: fleetId,
      targetAt: moraleRecoveryTimerController?.targetForFleet(fleetId),
      now: now,
      recoveredLabel: requiredL10n.moraleRecovered,
      noValueLabel: noValue,
    );
    final values =
        <(String, String, String)>[
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
                'firepower',
                fleetText(context, '火力'),
                current == null ? noValue : '${current.firepower}',
              ),
              (
                'torpedo',
                fleetText(context, '雷装'),
                current == null ? noValue : '${current.torpedo}',
              ),
              (
                'anti-air',
                fleetText(context, '对空'),
                current == null ? noValue : '${current.antiAir}',
              ),
              (
                'anti-sub',
                fleetText(context, '对潜'),
                current == null ? noValue : '${current.antiSub}',
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
                current == null || current.formula33.isEmpty
                    ? noValue
                    : current.formula33.first.total.toStringAsFixed(2),
              ),
              (
                'minimum-condition',
                fleetText(context, '最低疲劳'),
                current == null ? noValue : '${current.minimumCondition}',
              ),
              (
                'recovery-countdown',
                fleetText(context, '恢复倒计时'),
                recoveryValue,
              ),
            ]
            .where((value) => visible.contains(value.$1))
            .take(maximumSummaryFields)
            .toList();
    if (values.isEmpty) return const SizedBox.shrink();
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
