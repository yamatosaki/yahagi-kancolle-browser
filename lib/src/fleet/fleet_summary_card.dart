import '../widgets/app_segmented_style.dart';
import '../theme/app_palette.dart';
import '../settings/fleet_display_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../battle/battle_controller.dart';
import '../game_state/fleet_metrics.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';
import 'separated_wrap.dart';
import '../layout/flat_empty_text.dart';
import '../layout/flat_style.dart';
import '../layout/flat_text_toggle.dart';
import '../layout/flat_underline_tabs.dart';
import '../layout/hd_dashboard_content.dart';
import 'combat_mechanism.dart';
import 'fleet_ship_minimal_row.dart';
import 'ship_repair_status.dart';
import 'fleet_ui_strings.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'fleet_ship_status_capsule.dart';
import 'fleet_line_of_sight_details.dart';
import '../performance/second_tick_scope.dart';
import '../layout/module_summaries.dart';
import '../layout/panel_style.dart';
import '../settings/battle_status_effect_settings.dart';
import '../settings/module_display_settings.dart';
import 'fleet_air_power_details.dart';
import 'fleet_transport_details.dart';
import 'fleet_transport_points.dart';
import 'morale_recovery_display.dart';
import 'morale_recovery_timer_controller.dart';

class FleetSummaryCard extends StatefulWidget {
  const FleetSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenFleet,
    this.battleController,
    this.onOpenShip,
    this.damagePulseFilter = DamagePulseFilter.all,
    this.moraleSparkleMode = MoraleSparkleMode.blinking,
    this.moraleRecoveryTimerController,
    this.clock,
    this.visible = defaultFields,
    this.twoColumnVisible,
    this.shipTypeLabelMode = FleetShipTypeLabelMode.localizedName,
    this.showLogo = true,
    this.showTitle = true,
    this.onOpenDisplaySettings,
  });

  final GameStateController controller;
  final BattleController? battleController;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenFleet;
  final void Function(int fleetId, int shipId)? onOpenShip;
  final DamagePulseFilter damagePulseFilter;
  final MoraleSparkleMode moraleSparkleMode;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final DateTime Function()? clock;
  final Set<String> visible;
  final Set<String>? twoColumnVisible;
  final FleetShipTypeLabelMode shipTypeLabelMode;
  final bool showLogo;
  final bool showTitle;
  final VoidCallback? onOpenDisplaySettings;

  @override
  State<FleetSummaryCard> createState() => _FleetSummaryCardState();
}

class _FleetSummaryCardState extends State<FleetSummaryCard> {
  int _selectedFleetId = 1;

  void _openShip(int shipId) {
    final onOpenShip = widget.onOpenShip;
    if (onOpenShip == null) {
      widget.onOpenFleet(_selectedFleetId);
    } else {
      onOpenShip(_selectedFleetId, shipId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (widget.moraleRecoveryTimerController != null)
          widget.moraleRecoveryTimerController!,
      ]),
      builder: (context, _) {
        final state = widget.controller.fleetDisplayState;
        final summaryVisible = HdModuleColumns.of(context) == 2
            ? widget.twoColumnVisible ??
                  {...widget.visible, 'firepower', 'anti-sub'}
            : widget.visible;
        final fleetIndex = state.fleets.indexWhere(
          (fleet) => fleet.id == _selectedFleetId,
        );
        final selectedFleet = fleetIndex < 0 ? null : state.fleets[fleetIndex];
        final ships = state.shipsForFleet(_selectedFleetId);
        final metrics = selectedFleet == null
            ? null
            : FleetMetrics.fromState(state, selectedFleet);
        final transportPoints =
            selectedFleet != null &&
                !widget.collapsed &&
                summaryVisible.contains('transport-points')
            ? FleetTransportPoints.forFleet(state, selectedFleet)
            : null;
        final specialAttack = selectedFleet == null
            ? null
            : detectFleetSpecialAttack(state, selectedFleet);
        final twoColumns = HdModuleColumns.of(context) > 1;
        final flat = PanelStyleScope.isFlat(context);
        // Keep the ship subtree until captured data, preferences, locale, or
        // repair badges change. Only morale/countdown metrics need every tick.
        Localizations.localeOf(context);
        Widget? cachedShips;
        Widget? cachedSwitcher;
        Map<int, ShipRepairStatus>? cachedRepairStatuses;
        final recoveryDeadline = summaryVisible.contains('recovery-countdown')
            ? widget.moraleRecoveryTimerController?.targetForFleet(
                _selectedFleetId,
              )
            : null;
        final anchorageTicks =
            widget.controller.anchorageRepairStartedAt != null;
        // Fleet metrics depend on captured state, not the ticking clock.
        return SecondTickBuilder(
          now: widget.clock,
          enabled:
              !widget.collapsed && (anchorageTicks || recoveryDeadline != null),
          // Recovery alone no longer needs refreshes once it reaches zero.
          // Preserve the existing repair-status clock while anchorage runs.
          stopAt: !anchorageTicks ? recoveryDeadline : null,
          builder: (context, now, _) {
            final repairStatuses = widget.collapsed
                ? const <int, ShipRepairStatus>{}
                : shipRepairStatusesFor(
                    state: state,
                    anchorageRepairStartedAt:
                        widget.controller.anchorageRepairStartedAt,
                    nosakiSparkleStartedAt:
                        widget.controller.nosakiSparkleStartedAt,
                    now: now,
                  );
            if (!mapEquals(cachedRepairStatuses, repairStatuses)) {
              cachedShips = null;
              cachedSwitcher = null;
              cachedRepairStatuses = repairStatuses;
            }
            final fleetSwitcher = cachedSwitcher ??= _FleetSummarySwitcher(
              state: state,
              repairStatuses: repairStatuses,
              battleController: widget.battleController,
              selectedFleetId: _selectedFleetId,
              onSelected: (id) => setState(() => _selectedFleetId = id),
            );
            Widget minimalShipAt(int index) => FleetShipMinimalRow(
              state: state,
              ship: ships[index],
              visible: widget.visible,
              shipTypeLabelMode: widget.shipTypeLabelMode,
              damagePulseFilter: widget.damagePulseFilter,
              moraleSparkleMode: widget.moraleSparkleMode,
              repairStatus: repairStatuses[ships[index].id],
              specialAttack: index == 0 ? specialAttack : null,
              onTap: () => _openShip(ships[index].id),
            );
            return DashboardCard(
              title: AppLocalizations.of(context)?.fleetBrief ?? '编队简报',
              collapsedSummary: widget.collapsed
                  ? fleetSummary(
                      AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('zh')),
                      state,
                      _selectedFleetId,
                    )
                  : null,
              icon: const Icon(Icons.directions_boat_filled_outlined),
              collapsed: widget.collapsed,
              onToggleCollapse: widget.onToggleCollapse,
              showLogo: widget.showLogo,
              showTitle: widget.showTitle,
              headerAction: widget.onOpenDisplaySettings == null
                  ? null
                  : displaySettingsGear(
                      context,
                      key: const Key('fleet-display-settings-button'),
                      tooltip: fleetText(
                        context,
                        FleetUiKeys.fleetSummaryDisplay,
                      ),
                      onPressed: widget.onOpenDisplaySettings!,
                    ),
              trailing: twoColumns && !flat
                  ? SizedBox(width: 108, child: fleetSwitcher)
                  : null,
              child: _FleetSummaryBody(
                switcher: twoColumns && !flat ? null : fleetSwitcher,
                metrics: summaryVisible.any(summaryFields.contains)
                    ? _FleetSummaryMetrics(
                        visible: summaryVisible,
                        state: state,
                        fleetId: _selectedFleetId,
                        metrics: metrics,
                        transportPoints: transportPoints,
                        now: now,
                        moraleRecoveryTimerController:
                            widget.moraleRecoveryTimerController,
                      )
                    : null,
                ships: cachedShips ??= ships.isEmpty
                    ? flat
                          ? FlatEmptyText(fleetText(context, '无数据'))
                          : Container(
                              padding: const EdgeInsets.all(16),
                              alignment: Alignment.center,
                              child: Text(
                                fleetText(context, '无数据'),
                                style: TextStyle(
                                  color: appColor(
                                    context,
                                    const Color(0xff8197a5),
                                  ),
                                ),
                              ),
                            )
                    : flat
                    ? twoColumns
                          ? HdDashboardItems(
                              spacing: 1,
                              runSpacing: 1,
                              children: [
                                for (var i = 0; i < ships.length; i++)
                                  minimalShipAt(i),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < ships.length; i++) ...[
                                  if (i > 0)
                                    SizedBox(
                                      height: 1,
                                      child: ColoredBox(
                                        color: appColor(
                                          context,
                                          flatDividerColor,
                                        ),
                                      ),
                                    ),
                                  minimalShipAt(i),
                                ],
                              ],
                            )
                    : HdDashboardItems(
                        children: [
                          for (final ship in ships)
                            FleetShipStatusCapsule(
                              state: state,
                              ship: ship,
                              visible: widget.visible,
                              shipTypeLabelMode: widget.shipTypeLabelMode,
                              damagePulseFilter:
                                  widget.visible.contains('portrait')
                                  ? widget.damagePulseFilter
                                  : DamagePulseFilter.off,
                              moraleSparkleMode:
                                  widget.visible.contains('portrait')
                                  ? widget.moraleSparkleMode
                                  : MoraleSparkleMode.off,
                              repairStatus: repairStatuses[ship.id],
                              specialAttack: ship == ships.first
                                  ? specialAttack
                                  : null,
                              onTap: () => _openShip(ship.id),
                            ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Wide HD cards keep their summary in a narrow rail beside the ship grid.
class _FleetSummaryBody extends StatelessWidget {
  const _FleetSummaryBody({
    this.switcher,
    required this.metrics,
    required this.ships,
  });
  final Widget? switcher;
  final Widget? metrics;
  final Widget ships;
  @override
  Widget build(BuildContext context) {
    if (HdModuleColumns.of(context) > 1 && !PanelStyleScope.isFlat(context)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: metrics),
          const SizedBox(width: 6),
          Expanded(child: ships),
        ],
      );
    }
    final flat = PanelStyleScope.isFlat(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?switcher,
        if (metrics != null) ...[
          if (switcher != null) SizedBox(height: flat ? flatRowSpacing : 4),
          metrics!,
          SizedBox(height: flat ? flatRowSpacing : 6),
        ] else if (flat && switcher != null)
          const SizedBox(height: 2),
        ships,
      ],
    );
  }
}

class _FleetSummarySwitcher extends StatelessWidget {
  const _FleetSummarySwitcher({
    required this.state,
    required this.repairStatuses,
    required this.battleController,
    required this.selectedFleetId,
    required this.onSelected,
  });

  final GameState state;
  final Map<int, ShipRepairStatus> repairStatuses;
  final BattleController? battleController;
  final int selectedFleetId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final battle = battleController;
    if (battle == null) return _buildTabs(context);
    return AnimatedBuilder(
      animation: battle,
      builder: (context, _) => _buildTabs(context),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final palette = AppPalette.of(context);
    final practiceFleetId = battleController?.activePracticeFleetId;
    final combat = state.combatState;
    final sortieFleetId =
        combat.isActive && battleController?.current?.context.practice != true
        ? combat.sortieFleetId
        : null;
    const switcherKey = Key('fleet-summary-switcher');
    final options = [
      for (final fleet in state.fleets.take(4))
        FlatTextToggleOption(
          key: Key('fleet-summary-selector-${fleet.id}'),
          label: _fleetSelectorLabel(fleet),
          selected: fleet.id == selectedFleetId,
          backgroundColor: _fleetTabBackground(
            palette,
            state,
            fleet,
            sortieFleetId: sortieFleetId,
            practiceFleetId: practiceFleetId,
            repairStatuses: repairStatuses,
          ),
          onTap: () => onSelected(fleet.id),
        ),
    ];
    if (PanelStyleScope.isFlat(context)) {
      return FlatUnderlineTabs(key: switcherKey, options: options);
    }
    final radius = AppSegmentedStyle.itemRadius(compact: true);
    return Container(
      key: switcherKey,
      height: AppSegmentedStyle.compactHeight,
      padding: AppSegmentedStyle.padding(compact: true),
      decoration: AppSegmentedStyle.decoration(context, compact: true),
      child: Row(
        children: options.map((option) {
          final isSelected = option.selected;
          final background = option.backgroundColor;
          return Expanded(
            child: Material(
              key: option.key,
              color:
                  background ??
                  AppSegmentedStyle.selection(context, isSelected),
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: isSelected && background != null
                    ? BorderSide(
                        color: AppSegmentedStyle.selectedBorder(context),
                      )
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: option.onTap,
                borderRadius: radius,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      option.label,
                      style:
                          AppSegmentedStyle.textStyle(
                            context,
                            selected: isSelected,
                            compact: true,
                          ).copyWith(
                            color: !isSelected && background != null
                                ? palette.foreground
                                : null,
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

Color? _fleetTabBackground(
  AppPalette palette,
  GameState state,
  Fleet fleet, {
  required int? sortieFleetId,
  required int? practiceFleetId,
  required Map<int, ShipRepairStatus> repairStatuses,
}) {
  final onSortie =
      fleet.id == sortieFleetId ||
      (sortieFleetId == 1 &&
          fleet.id == 2 &&
          state.combinedFleetType != CombinedFleetType.none);
  if (onSortie || fleet.id == practiceFleetId) {
    return palette.color(const Color(0xff5a2528));
  }
  if (fleet.mission.isActive ||
      state.pendingExpeditionSupplyShipIds.values.any(
        (shipIds) => fleet.shipIds.any(shipIds.contains),
      )) {
    return palette.isDark ? const Color(0xff203e5c) : palette.infoSurface;
  }

  final green = palette.isDark
      ? const Color(0xff214630)
      : palette.successSurface;
  if (fleet.shipIds.any((id) {
    final status = repairStatuses[id];
    return status == ShipRepairStatus.anchorage ||
        status == ShipRepairStatus.nosakiSparkle;
  })) {
    return green;
  }

  var supplyKnown = fleet.shipIds.isNotEmpty;
  for (final id in fleet.shipIds) {
    final ship = state.ships[id];
    final master = ship == null ? null : state.masterForShip(ship);
    if (ship == null ||
        master == null ||
        (master.maxFuel <= 0 && master.maxAmmo <= 0)) {
      supplyKnown = false;
      continue;
    }
    if (ship.currentFuel < master.maxFuel ||
        ship.currentAmmo < master.maxAmmo) {
      return palette.isDark ? const Color(0xff4d3f1a) : palette.goldSurface;
    }
  }
  if (!supplyKnown) return null;
  return green;
}

String _fleetSelectorLabel(Fleet fleet) =>
    fleetSelectorLabelModeSetting == FleetSelectorLabelMode.number ||
        fleet.name.trim().isEmpty
    ? '${fleet.id}'
    : fleet.name;

class _FleetSummaryMetrics extends StatelessWidget {
  const _FleetSummaryMetrics({
    required this.state,
    required this.fleetId,
    required this.visible,
    required this.metrics,
    required this.transportPoints,
    required this.now,
    required this.moraleRecoveryTimerController,
  });

  final GameState state;
  final int fleetId;
  final Set<String> visible;
  final FleetMetrics? metrics;
  final FleetTransportPoints? transportPoints;
  final DateTime now;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requiredL10n = l10n ?? lookupAppLocalizations(const Locale('zh'));
    final noValue = l10n?.noValue ?? '—';
    final current = metrics;
    final transport = transportPoints;
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
    final twoColumns = HdModuleColumns.of(context) == 2;
    final metricFields = visible;
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
                'transport-points',
                requiredL10n.fleetTransportPoints,
                transport == null
                    ? noValue
                    : requiredL10n.fleetTransportPairedValues(
                        transport.sRank,
                        transport.tankSRank,
                      ),
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
            .where((value) => metricFields.contains(value.$1))
            .take(twoColumns ? 7 : maximumSummaryFields)
            .toList();
    if (values.isEmpty) return const SizedBox.shrink();
    String? semanticLabelAt(int index) => switch (values[index].$1) {
      'air-power' when hasAirPowerDetails => requiredL10n.showAirPowerDetails,
      'transport-points' when transport != null =>
        requiredL10n.fleetShowTransportDetails,
      _ => null,
    };
    Widget metricAt(int index, {bool flat = false}) {
      final (id, label, value) = values[index];
      final semanticLabel = semanticLabelAt(index);
      Widget buildMetric(VoidCallback? onTap) => flat
          ? _FlatSummaryMetric(
              id: id,
              label: label,
              value: value,
              semanticLabel: semanticLabel,
              onTap: onTap,
            )
          : _FleetSummaryMetric(
              id: id,
              label: label,
              value: value,
              semanticLabel: semanticLabel,
              onTap: onTap,
            );
      if (id == 'line-of-sight' &&
          current != null &&
          current.formula33.isNotEmpty) {
        return FleetLineOfSightDetails(metrics: current, builder: buildMetric);
      }
      if (id == 'air-power' && hasAirPowerDetails && current != null) {
        return FleetAirPowerDetails(metrics: current, builder: buildMetric);
      }
      if (id == 'transport-points' && transport != null) {
        return FleetTransportDetails(points: transport, builder: buildMetric);
      }
      return buildMetric(null);
    }

    if (PanelStyleScope.isFlat(context)) {
      return SeparatedWrap(
        key: const Key('fleet-summary-metrics'),
        separator: '·',
        style: TextStyle(
          color: appColor(context, const Color(0xff4f6676)),
          fontSize: 10,
        ),
        children: [
          for (var index = 0; index < values.length; index++)
            metricAt(index, flat: true),
        ],
      );
    }
    final vertical = HdModuleColumns.of(context) > 1;
    return Flex(
      key: const Key('fleet-summary-metrics'),
      direction: vertical ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (vertical)
            metricAt(index)
          else
            Expanded(
              flex: values[index].$1 == 'transport-points' ? 2 : 1,
              child: metricAt(index),
            ),
          if (index != values.length - 1)
            SizedBox(width: vertical ? 0 : 4, height: vertical ? 3 : 0),
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
    color: appColor(context, Color(0xff102331)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(color: appColor(context, Color(0xff294052))),
    ),
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: HdModuleColumns.of(context) > 1 ? 26 : 28,
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
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xff8197a5)),
                        fontSize: 8,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
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
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xffdce6eb)),
                        fontSize: 8,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
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

class _FlatSummaryMetric extends StatelessWidget {
  const _FlatSummaryMetric({
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
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semanticLabel,
    child: InkWell(
      key: Key('fleet-summary-metric-$id'),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = constraints.maxWidth.clamp(0.0, 3.0);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: appColor(context, const Color(0xff8197a5)),
                    fontSize: 10,
                  ),
                ),
              ),
              SizedBox(width: gap),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth - gap,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    key: Key('fleet-summary-metric-$id-value'),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: appColor(context, const Color(0xffdce6eb)),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
