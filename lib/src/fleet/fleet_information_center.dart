import 'package:flutter/material.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/fleet_metrics.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'combat_mechanism.dart';
import 'anchorage_repair_view.dart';
import 'equipment_display.dart';
import 'fleet_switcher_bar.dart';
import 'operation_status_views.dart';
import 'ship_portrait.dart';
import 'ship_speed_visual.dart';
import 'ship_status_style.dart';
import 'ship_status_visuals.dart';
import 'status_density.dart';
import '../expedition/expedition_check_page.dart';
import 'expedition_summary_card.dart' show ExpeditionSummaryMode, ExpeditionModeSelector;

export 'fleet_switcher_bar.dart';

AppLocalizations _fleetL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('zh'));

enum FleetInformationPage { fleet, expedition, repair, construction }

class FleetInformationCenter extends StatefulWidget {
  const FleetInformationCenter({
    super.key,
    required this.controller,
    this.page = FleetInformationPage.fleet,
    this.initialFleetId,
    this.showContextHeader = true,
    this.repairMode,
    this.onRepairModeChanged,
    this.showRepairModeTabs = true,
    this.onFleetSelected,
    this.expeditionMode,
    this.onExpeditionModeChanged,
  });

  final GameStateController controller;
  final FleetInformationPage page;
  final int? initialFleetId;
  final bool showContextHeader;
  final RepairCenterMode? repairMode;
  final ValueChanged<RepairCenterMode>? onRepairModeChanged;
  final bool showRepairModeTabs;
  final ValueChanged<int>? onFleetSelected;
  final ExpeditionSummaryMode? expeditionMode;
  final ValueChanged<ExpeditionSummaryMode>? onExpeditionModeChanged;

  @override
  State<FleetInformationCenter> createState() => _FleetInformationCenterState();
}

class _FleetInformationCenterState extends State<FleetInformationCenter> {
  late int _selectedFleetId = widget.initialFleetId ?? 1;

  @override
  void didUpdateWidget(FleetInformationCenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialFleetId;
    if (next != null && next != oldWidget.initialFleetId) {
      _selectedFleetId = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff081521),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showContextHeader &&
                  (widget.page != FleetInformationPage.fleet ||
                      !state.hasPortData))
                _PageHeader(
                  page: widget.page,
                  expeditionMode: widget.expeditionMode,
                  onExpeditionModeChanged: widget.onExpeditionModeChanged,
                ),
              if (!state.hasPortData)
                const Expanded(child: _WaitingState())
              else
                Expanded(
                  child: switch (widget.page) {
                    FleetInformationPage.fleet => _FleetView(
                      state: state,
                      selectedFleetId: _selectedFleetId,
                      onFleetSelected: (id) {
                        setState(() => _selectedFleetId = id);
                      },
                      showContextHeader: widget.showContextHeader,
                    ),
                    FleetInformationPage.expedition => widget.expeditionMode == ExpeditionSummaryMode.check
                        ? ExpeditionCheckPage(
                            controller: widget.controller,
                            showHeader: false,
                            initialFleetId: _selectedFleetId,
                            onBack: () {},
                          )
                        : ExpeditionStatusView(
                            state: state,
                          ),
                    FleetInformationPage.repair => RepairCenterView(
                      controller: widget.controller,
                      initialFleetId: widget.initialFleetId,
                      onFleetSelected: widget.onFleetSelected,
                      mode: widget.repairMode,
                      onModeChanged: widget.onRepairModeChanged,
                      showModeTabs: widget.showRepairModeTabs,
                    ),
                    FleetInformationPage.construction =>
                      ConstructionDockStatusView(state: state),
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.page,
    this.expeditionMode,
    this.onExpeditionModeChanged,
  });

  final FleetInformationPage page;
  final ExpeditionSummaryMode? expeditionMode;
  final ValueChanged<ExpeditionSummaryMode>? onExpeditionModeChanged;

  @override
  Widget build(BuildContext context) {
    final title = switch (page) {
      FleetInformationPage.fleet => AppLocalizations.of(context)?.fleet ?? '舰队',
      FleetInformationPage.expedition =>
        AppLocalizations.of(context)?.expedition ?? '远征',
      FleetInformationPage.repair =>
        AppLocalizations.of(context)?.repair ?? '入渠',
      FleetInformationPage.construction =>
        AppLocalizations.of(context)?.construction ?? '建造',
    };
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xff0d1a26),
        border: Border(bottom: BorderSide(color: Color(0xff294052))),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xffd4a85f),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const Spacer(),
          if (page == FleetInformationPage.expedition && expeditionMode != null && onExpeditionModeChanged != null)
            ExpeditionModeSelector(
              mode: expeditionMode!,
              summaryLabel: '简报',
              checkLabel: '检查',
              onChanged: onExpeditionModeChanged!,
            ),
        ],
      ),
    );
  }
}

class _WaitingState extends StatelessWidget {
  const _WaitingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.radar_outlined, color: Color(0xffd4a85f), size: 42),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context)?.waitingForPortData ?? '等待母港数据',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            AppLocalizations.of(context)?.waitingForPortDataDescription ??
                '进入游戏母港或刷新游戏页面后，这里会自动更新',
            style: const TextStyle(color: Color(0xff8197a5)),
          ),
        ],
      ),
    );
  }
}

class _FleetView extends StatefulWidget {
  const _FleetView({
    required this.state,
    required this.selectedFleetId,
    required this.onFleetSelected,
    required this.showContextHeader,
  });

  final GameState state;
  final int selectedFleetId;
  final ValueChanged<int> onFleetSelected;
  final bool showContextHeader;

  @override
  State<_FleetView> createState() => _FleetViewState();
}

class _FleetViewState extends State<_FleetView> {
  GameState? _lastState;
  GameState? _lastButtonsState;
  int _lastFleetId = 0;
  FleetMetrics? _cachedMetrics;
  List<Fleet>? _cachedFleetButtons;
  int? _selectedShipId;
  int? _selectedEquipmentIndex;

  @override
  void didUpdateWidget(_FleetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFleetId != widget.selectedFleetId) {
      _selectedShipId = null;
      _selectedEquipmentIndex = null;
      return;
    }
    final selectedShipId = _selectedShipId;
    if (selectedShipId == null || identical(oldWidget.state, widget.state)) {
      return;
    }
    final oldFleet = _selectedFleet(
      oldWidget.state.fleets,
      oldWidget.selectedFleetId,
    );
    final nextFleet = _selectedFleet(
      widget.state.fleets,
      widget.selectedFleetId,
    );
    final selectedPosition = oldFleet?.shipIds.indexOf(selectedShipId) ?? -1;
    final nextShipId =
        selectedPosition >= 0 &&
            nextFleet != null &&
            selectedPosition < nextFleet.shipIds.length
        ? nextFleet.shipIds[selectedPosition]
        : null;
    if (nextShipId != selectedShipId) {
      _selectedShipId = nextShipId;
      _selectedEquipmentIndex = null;
    }
  }

  FleetMetrics _metricsFor(GameState state, Fleet fleet) {
    if (_cachedMetrics == null ||
        _lastState != state ||
        _lastFleetId != fleet.id) {
      _cachedMetrics = FleetMetrics.fromState(state, fleet);
      _lastState = state;
      _lastFleetId = fleet.id;
    }
    return _cachedMetrics!;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final fleet = _selectedFleet(state.fleets, widget.selectedFleetId);
    if (fleet == null) {
      return const _WaitingState();
    }
    final ships = state.shipsForFleet(fleet.id);
    final metrics = _metricsFor(state, fleet);
    final specialAttack = detectFleetSpecialAttack(state, fleet);
    if (_lastButtonsState != state) {
      _lastButtonsState = state;
      _cachedFleetButtons = state.fleets.take(4).toList();
    }
    final fleetButtons = _cachedFleetButtons!;
    final selectedShip = ships.isEmpty
        ? null
        : ships.firstWhere(
            (ship) => ship.id == _selectedShipId,
            orElse: () => ships.first,
          );
    final selectedEquipment = selectedShip == null
        ? const <ShipEquipment>[]
        : state.equipmentForShip(selectedShip);
    final selectedEquipmentIndex =
        _selectedEquipmentIndex != null &&
            _selectedEquipmentIndex! >= 0 &&
            _selectedEquipmentIndex! < selectedEquipment.length
        ? _selectedEquipmentIndex
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 14, 14),
      child: Column(
        children: [
          if (widget.showContextHeader) ...[
            FleetSwitcherBar(
              fleets: fleetButtons,
              selectedFleetId: fleet.id,
              sortieFleetId: state.combatState.isActive
                  ? state.combatState.sortieFleetId
                  : null,
              onFleetSelected: widget.onFleetSelected,
            ),
            const SizedBox(height: 10),
          ],
          _MetricsBar(metrics: metrics),
          const SizedBox(height: 10),
          Expanded(
            child: ships.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)?.fleetNoShips ?? '当前舰队没有舰娘',
                      style: const TextStyle(color: Color(0xff8197a5)),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      Widget workspace(double width) {
                        final compact = width < 900;
                        final gap = compact ? 5.0 : 9.0;
                        final rosterWidth = compact
                            ? width * 0.16
                            : width * 0.17;
                        final detailWidth = compact
                            ? width * 0.26
                            : width * 0.265;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: rosterWidth,
                              child: _FleetRosterPanel(
                                key: const Key('fleet-roster-panel'),
                                state: state,
                                ships: ships,
                                selectedShipId: selectedShip!.id,
                                onSelected: (shipId) {
                                  setState(() {
                                    _selectedShipId = shipId;
                                    _selectedEquipmentIndex = null;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: gap),
                            Expanded(
                              child: _FleetFocusPanel(
                                key: const Key('fleet-focus-panel'),
                                state: state,
                                ship: selectedShip,
                                specialAttack: selectedShip.id == ships.first.id
                                    ? specialAttack
                                    : null,
                                selectedEquipmentIndex: selectedEquipmentIndex,
                                onShipDetails: () => setState(
                                  () => _selectedEquipmentIndex = null,
                                ),
                                onEquipmentSelected: (index) => setState(
                                  () => _selectedEquipmentIndex = index,
                                ),
                              ),
                            ),
                            SizedBox(width: gap),
                            SizedBox(
                              width: detailWidth,
                              child: _FleetDetailPanel(
                                key: const Key('fleet-detail-panel'),
                                state: state,
                                ship: selectedShip,
                                equipmentIndex: selectedEquipmentIndex,
                              ),
                            ),
                          ],
                        );
                      }

                      if (constraints.maxWidth < 600) {
                        const designWidth = 740.0;
                        final scale = constraints.maxWidth / designWidth;
                        return SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: designWidth,
                              height: constraints.maxHeight / scale,
                              child: workspace(designWidth),
                            ),
                          ),
                        );
                      }
                      return workspace(constraints.maxWidth);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Fleet? _selectedFleet(List<Fleet> fleets, int id) {
    for (final fleet in fleets) {
      if (fleet.id == id) {
        return fleet;
      }
    }
    return fleets.firstOrNull;
  }
}

class _FleetWorkspacePanel extends StatelessWidget {
  const _FleetWorkspacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff0d202d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff294052)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _FleetRosterPanel extends StatefulWidget {
  const _FleetRosterPanel({
    super.key,
    required this.state,
    required this.ships,
    required this.selectedShipId,
    required this.onSelected,
  });

  final GameState state;
  final List<OwnedShip> ships;
  final int selectedShipId;
  final ValueChanged<int> onSelected;

  @override
  State<_FleetRosterPanel> createState() => _FleetRosterPanelState();
}

class _FleetRosterPanelState extends State<_FleetRosterPanel>
    with TickerProviderStateMixin {
  late final AnimationController _damagePulse;
  late final AnimationController _sparklePulse;

  @override
  void initState() {
    super.initState();
    _damagePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _sparklePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _damagePulse.dispose();
    _sparklePulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FleetWorkspacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: widget.ships.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ship = widget.ships[index];
                return _FleetRosterShipCapsule(
                  state: widget.state,
                  ship: ship,
                  selected: ship.id == widget.selectedShipId,
                  damagePulse: _damagePulse,
                  sparklePulse: _sparklePulse,
                  onTap: () => widget.onSelected(ship.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetRosterShipCapsule extends StatelessWidget {
  const _FleetRosterShipCapsule({
    required this.state,
    required this.ship,
    required this.selected,
    required this.damagePulse,
    required this.sparklePulse,
    required this.onTap,
  });

  final GameState state;
  final OwnedShip ship;
  final bool selected;
  final Animation<double> damagePulse;
  final Animation<double> sparklePulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hpRatio = ship.maxHp <= 0
        ? 0.0
        : (ship.currentHp / ship.maxHp).clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 3,
          child: Container(
            key: Key('fleet-roster-ship-${ship.id}'),
            decoration: BoxDecoration(
              color: const Color(0xff142735),
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xffd4a85f).withValues(alpha: 0.42),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    key: Key('fleet-roster-portrait-${ship.id}'),
                    borderRadius: BorderRadius.circular(10),
                    child: LayoutBuilder(
                      builder: (context, constraints) => ShipPortrait(
                        ship: state.masterForShip(ship),
                        serverOrigin: state.serverOrigin,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      ),
                    ),
                  ),
                ),
                ShipHpFrame(
                  key: Key('fleet-hp-outer-frame-${ship.id}'),
                  shipId: ship.id,
                  ratio: hpRatio,
                  color: shipHpBarColor(hpRatio, isZeroHp: ship.currentHp <= 0),
                  pulses: ship.currentHp > 0 && hpRatio <= 0.75,
                  animation: damagePulse,
                ),
                ShipMoraleMark(
                  key: Key('fleet-morale-mark-${ship.id}'),
                  shipId: ship.id,
                  value: ship.condition,
                  sparklePulse: sparklePulse,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _FleetFocusPanel extends StatelessWidget {
  const _FleetFocusPanel({
    super.key,
    required this.state,
    required this.ship,
    required this.specialAttack,
    required this.selectedEquipmentIndex,
    required this.onShipDetails,
    required this.onEquipmentSelected,
  });

  final GameState state;
  final OwnedShip ship;
  final EquipmentMechanismDisplay? specialAttack;
  final int? selectedEquipmentIndex;
  final VoidCallback onShipDetails;
  final ValueChanged<int> onEquipmentSelected;

  @override
  Widget build(BuildContext context) {
    final master = state.masterForShip(ship);
    final type = state.typeForShip(ship);
    final equipment = state.equipmentForShip(ship);
    final hpRatio = _ShipRow._ratio(ship.currentHp, ship.maxHp);
    final fuelRatio = _ShipRow._ratio(ship.currentFuel, master?.maxFuel ?? 0);
    final ammoRatio = _ShipRow._ratio(ship.currentAmmo, master?.maxAmmo ?? 0);
    final mechanisms = detectShipCombatMechanisms(state, ship);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final narrow = constraints.maxWidth < 430;
        final portraitSize = narrow
            ? const Size(60, 28)
            : compact
            ? const Size(68, 32)
            : const Size(96, 42);
        final sectionGap = narrow ? 4.0 : (compact ? 6.0 : 10.0);
        final headerHeight = narrow ? 52.0 : (compact ? 58.0 : 66.0);
        final meterHeight = narrow ? 15.0 : 16.0;
        final metaHeight = narrow ? 14.0 : 18.0;
        return _FleetWorkspacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: const Color(0xff142735),
                child: InkWell(
                  onTap: onShipDetails,
                  child: Container(
                    key: Key('fleet-focus-ship-${ship.id}'),
                    height: headerHeight,
                    padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 4 : (compact ? 6 : 8),
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, identityConstraints) {
                                    final portraitWidth =
                                        (identityConstraints.maxWidth * 0.35)
                                            .clamp(0.0, portraitSize.width)
                                            .toDouble();
                                    final portraitHeight =
                                        portraitSize.height *
                                        portraitWidth /
                                        portraitSize.width;
                                    return Row(
                                      children: [
                                        SizedBox(
                                          key: Key(
                                            'fleet-focus-portrait-${ship.id}',
                                          ),
                                          width: portraitWidth,
                                          height: portraitHeight,
                                          child: ShipPortrait(
                                            ship: master,
                                            serverOrigin: state.serverOrigin,
                                            width: portraitWidth,
                                            height: portraitHeight,
                                          ),
                                        ),
                                        SizedBox(width: sectionGap),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                master?.name ?? '未知舰娘',
                                                maxLines: 1,
                                                softWrap: false,
                                                style: TextStyle(
                                                  fontSize: narrow
                                                      ? 11
                                                      : (compact ? 14 : 17),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Next ${ship.nextExperience}',
                                                maxLines: 1,
                                                softWrap: false,
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xff8197a5,
                                                  ),
                                                  fontSize: narrow
                                                      ? 7
                                                      : (compact ? 9 : 10),
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              _CompactStatusMeter(
                                height: meterHeight,
                                icon: Icon(
                                  Icons.favorite_rounded,
                                  key: Key('fleet-focus-hp-icon-${ship.id}'),
                                  color: const Color(0xffef5a5a),
                                  size: 14,
                                ),
                                value: '${ship.currentHp}/${ship.maxHp}',
                                ratio: hpRatio,
                                valueColor: shipHpValueColor(
                                  hpRatio,
                                  isZeroHp: ship.currentHp <= 0,
                                ),
                                barColor: shipHpBarColor(
                                  hpRatio,
                                  isZeroHp: ship.currentHp <= 0,
                                ),
                                valueKey: Key(
                                  'fleet-focus-hp-value-${ship.id}',
                                ),
                                trackKey: Key(
                                  'fleet-focus-hp-track-${ship.id}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: sectionGap),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                key: Key('fleet-focus-meta-${ship.id}'),
                                height: metaHeight,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      key: Key(
                                        'fleet-focus-meta-content-${ship.id}',
                                      ),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Lv. ${ship.level}',
                                          style: const TextStyle(
                                            color: Color(0xffa9bac4),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          type?.name ?? '未知舰种',
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Color(0xffa9bac4),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        _MiniBadge(
                                          key: Key(
                                            'fleet-focus-speed-${ship.id}',
                                          ),
                                          text: ShipSpeedVisual.fromSpeed(
                                            ship.effectiveSpeed(master),
                                          ).label,
                                          color: ShipSpeedVisual.fromSpeed(
                                            ship.effectiveSpeed(master),
                                          ).foreground,
                                        ),
                                        for (final mechanism in mechanisms.take(
                                          1,
                                        )) ...[
                                          const SizedBox(width: 4),
                                          _MiniBadge(
                                            text: mechanism.label,
                                            color:
                                                mechanism.tone ==
                                                    MechanismTone.antiAir
                                                ? const Color(0xffffc861)
                                                : const Color(0xff8ec6e8),
                                          ),
                                        ],
                                        if (specialAttack != null) ...[
                                          const SizedBox(width: 4),
                                          const _MiniBadge(
                                            text: '特殊攻击',
                                            color: Color(0xffff8b88),
                                          ),
                                        ],
                                        const SizedBox(width: 4),
                                        _MiniBadge(
                                          text: '疲劳 ${ship.condition}',
                                          color: shipFatigueColor(
                                            ship.condition,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              _CompactStatusMeter(
                                height: meterHeight,
                                icon: Image.asset(
                                  'assets/images/material/01.png',
                                  key: Key('fleet-focus-fuel-icon-${ship.id}'),
                                  width: 14,
                                  height: 14,
                                ),
                                value:
                                    '${ship.currentFuel}/${master?.maxFuel ?? 0}',
                                ratio: fuelRatio,
                                valueColor: shipSupplyValueColor(fuelRatio),
                                barColor: shipSupplyBarColor(fuelRatio),
                                valueKey: Key(
                                  'fleet-focus-fuel-value-${ship.id}',
                                ),
                                trackKey: Key(
                                  'fleet-focus-fuel-track-${ship.id}',
                                ),
                              ),
                              _CompactStatusMeter(
                                height: meterHeight,
                                icon: Image.asset(
                                  'assets/images/material/02.png',
                                  width: 14,
                                  height: 14,
                                ),
                                value:
                                    '${ship.currentAmmo}/${master?.maxAmmo ?? 0}',
                                ratio: ammoRatio,
                                valueColor: shipSupplyValueColor(ammoRatio),
                                barColor: shipSupplyBarColor(ammoRatio),
                                valueKey: Key(
                                  'fleet-focus-ammo-value-${ship.id}',
                                ),
                                trackKey: Key(
                                  'fleet-focus-ammo-track-${ship.id}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xff294052)),
              Expanded(
                key: const Key('fleet-equipment-list'),
                child: equipment.isEmpty
                    ? Center(
                        child: Text(
                          _fleetL10n(context).equipmentDataWaiting,
                          style: const TextStyle(color: Color(0xff8197a5)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: equipment.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 5),
                        itemBuilder: (context, index) => _CompactEquipmentRow(
                          ship: ship,
                          equipment: equipment[index],
                          index: index,
                          selected: selectedEquipmentIndex == index,
                          onTap: () => onEquipmentSelected(index),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CompactStatusMeter extends StatelessWidget {
  const _CompactStatusMeter({
    this.height = 18,
    required this.icon,
    required this.value,
    required this.ratio,
    required this.valueColor,
    required this.barColor,
    required this.valueKey,
    required this.trackKey,
  });

  final double height;
  final Widget icon;
  final String value;
  final double ratio;
  final Color valueColor;
  final Color barColor;
  final Key valueKey;
  final Key trackKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: icon)),
          const SizedBox(width: 3),
          SizedBox(
            width: 50,
            child: Text(
              value,
              key: valueKey,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: valueColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              key: trackKey,
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: ratio.clamp(0, 1),
                color: barColor,
                backgroundColor: const Color(0xff263f4d),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactEquipmentRow extends StatelessWidget {
  const _CompactEquipmentRow({
    required this.ship,
    required this.equipment,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final OwnedShip ship;
  final ShipEquipment equipment;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final master = equipment.master;
    final isAircraft = _ShipRow._isAircraft(master);
    final onSlot = isAircraft && index < ship.onSlot.length
        ? ship.onSlot[index]
        : null;
    return Material(
      color: selected ? const Color(0xff1a303d) : const Color(0xff102331),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          key: Key('fleet-equipment-row-${ship.id}-$index'),
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xff8d7040)
                  : const Color(0xff294052),
            ),
          ),
          child: Row(
            children: [
              _EquipmentTypeIcon(
                imageKey: Key('fleet-equipment-icon-${ship.id}-$index'),
                slotKey: onSlot == null
                    ? null
                    : Key('fleet-equipment-slot-${ship.id}-$index'),
                iconId: _ShipRow._equipmentIconId(master),
                onSlot: onSlot,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Wrap(
                  key: Key('fleet-equipment-title-flow-${ship.id}-$index'),
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      master?.name ?? '未知装备',
                      key: Key('fleet-equipment-name-${ship.id}-$index'),
                      style: const TextStyle(
                        color: Color(0xffe1e9ed),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (equipment.owned.level > 0) ...[
                      Text(
                        '★${equipment.owned.level}',
                        key: Key(
                          'fleet-equipment-improvement-${ship.id}-$index',
                        ),
                        style: const TextStyle(
                          color: Color(0xff5daea6),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (isAircraft && equipment.owned.proficiency > 0) ...[
                      Image.asset(
                        'assets/images/airplane/alv${equipment.owned.proficiency.clamp(1, 7)}.png',
                        key: Key(
                          'fleet-equipment-proficiency-${ship.id}-$index',
                        ),
                        width: 18,
                        height: 16,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xffd4a85f),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetDetailPanel extends StatelessWidget {
  const _FleetDetailPanel({
    super.key,
    required this.state,
    required this.ship,
    required this.equipmentIndex,
  });

  final GameState state;
  final OwnedShip ship;
  final int? equipmentIndex;

  @override
  Widget build(BuildContext context) {
    final equipment = state.equipmentForShip(ship);
    final selected =
        equipmentIndex != null && equipmentIndex! < equipment.length
        ? equipment[equipmentIndex!]
        : null;
    return _FleetWorkspacePanel(
      child: selected == null
          ? _ShipParameterDetails(state: state, ship: ship)
          : _SelectedEquipmentDetails(
              state: state,
              ship: ship,
              equipment: selected,
              index: equipmentIndex!,
            ),
    );
  }
}

class _ShipParameterDetails extends StatelessWidget {
  const _ShipParameterDetails({required this.state, required this.ship});

  final GameState state;
  final OwnedShip ship;

  @override
  Widget build(BuildContext context) {
    final master = state.masterForShip(ship);
    final stats = <(String, String)>[
      ('耐久', '${ship.maxHp}'),
      ('火力', '${ship.firepower}'),
      ('装甲', '${ship.armor}'),
      ('雷装', '${ship.torpedo}'),
      ('回避', '${ship.evasion}'),
      ('对空', '${ship.antiAir}'),
      ('搭载', '${ship.onSlot.fold<int>(0, (sum, value) => sum + value)}'),
      ('对潜', '${ship.antiSub}'),
      ('速力', ShipSpeedVisual.fromSpeed(ship.effectiveSpeed(master)).label),
      ('索敌', '${ship.lineOfSight}'),
      ('射程', _rangeText(ship.effectiveRange(master))),
      ('运', '${ship.luck}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xff102331),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stats[index].$1,
                      style: const TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    stats[index].$2,
                    style: const TextStyle(
                      color: Color(0xffe1e9ed),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _rangeText(int range) => switch (range) {
    1 => '短',
    2 => '中',
    3 => '长',
    4 => '超长',
    _ => '—',
  };
}

class _SelectedEquipmentDetails extends StatelessWidget {
  const _SelectedEquipmentDetails({
    required this.state,
    required this.ship,
    required this.equipment,
    required this.index,
  });

  final GameState state;
  final OwnedShip ship;
  final ShipEquipment equipment;
  final int index;

  @override
  Widget build(BuildContext context) {
    final master = equipment.master;
    final bonuses = master == null
        ? const <String, int>{}
        : equipmentVisibleBonuses(
            item: master,
            shipName: state.masterForShip(ship)?.name ?? '',
          );
    final stats = master == null
        ? const <EquipmentStatDisplay>[]
        : equipmentStatDisplays(master, bonuses: bonuses);
    final aircraft = _ShipRow._isAircraft(master);
    final onSlot = aircraft && index < ship.onSlot.length
        ? ship.onSlot[index]
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _EquipmentTypeIcon(
                imageKey: Key('fleet-detail-equipment-icon-${ship.id}-$index'),
                iconId: _ShipRow._equipmentIconId(master),
                onSlot: onSlot,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Wrap(
                  key: Key(
                    'fleet-detail-equipment-title-flow-${ship.id}-$index',
                  ),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  runSpacing: 3,
                  children: [
                    Text(
                      master?.name ?? '未知装备',
                      key: Key('fleet-detail-equipment-name-${ship.id}-$index'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (equipment.owned.level > 0)
                      Text(
                        '★${equipment.owned.level}',
                        key: Key(
                          'fleet-detail-equipment-improvement-${ship.id}-$index',
                        ),
                        style: const TextStyle(
                          color: Color(0xff5daea6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (aircraft && equipment.owned.proficiency > 0)
                      Image.asset(
                        'assets/images/airplane/alv${equipment.owned.proficiency.clamp(1, 7)}.png',
                        key: Key(
                          'fleet-detail-equipment-proficiency-${ship.id}-$index',
                        ),
                        width: 20,
                        height: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: stats.length,
            itemBuilder: (context, index) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xff102331),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stats[index].label,
                      style: const TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (stats[index].value.isNotEmpty)
                    Text(
                      stats[index].value,
                      style: const TextStyle(
                        color: Color(0xffe1e9ed),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (kShowEquipmentVisibleBonuses &&
                      stats[index].bonus != 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '↑+${stats[index].bonus}',
                      key: Key('fleet-equipment-bonus-$index'),
                      style: const TextStyle(
                        color: Color(0xff63b8ff),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricsBar extends StatelessWidget {
  const _MetricsBar({required this.metrics});

  final FleetMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final formula33 = metrics.formula33;
    final noValue = AppLocalizations.of(context)?.noValue ?? '无';
    final values = <(String, String)>[
      (AppLocalizations.of(context)?.speed ?? '速度', metrics.speedLabel),
      (
        AppLocalizations.of(context)?.totalLevel ?? '总等级',
        '${metrics.totalLevel}',
      ),
      (AppLocalizations.of(context)?.firepower ?? '火力', '${metrics.firepower}'),
      (AppLocalizations.of(context)?.torpedo ?? '雷装', '${metrics.torpedo}'),
      (AppLocalizations.of(context)?.antiAir ?? '对空', '${metrics.antiAir}'),
      (AppLocalizations.of(context)?.antiSub ?? '对潜', '${metrics.antiSub}'),
      (
        AppLocalizations.of(context)?.airPower ?? '制空',
        metrics.airPower == null
            ? noValue
            : metrics.airPowerMaximum != null &&
                  metrics.airPowerMaximum! > metrics.airPower!
            ? '${metrics.airPower}+'
            : '${metrics.airPower}',
      ),
      (
        AppLocalizations.of(context)?.lineOfSight ?? '索敌',
        formula33.isEmpty ? noValue : formula33.first.total.toStringAsFixed(2),
      ),
      (
        AppLocalizations.of(context)?.averageCondition ?? '最低疲劳',
        '${metrics.minimumCondition}',
      ),
    ];
    final phone = usesCompactFleetLayout(context);
    return Row(
      children: [
        for (var index = 0; index < values.length; index++) ...[
          Expanded(
            child: _metricCell(
              context,
              label: values[index].$1,
              value: values[index].$2,
              key: switch (index) {
                0 => const Key('fleet-speed-metric'),
                7 => const Key('fleet-los-metric'),
                _ => null,
              },
              onTap: index == 7 && formula33.isNotEmpty
                  ? () => _showLineOfSightDetails(context)
                  : null,
              compact: phone,
            ),
          ),
          if (index != values.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }

  Widget _metricCell(
    BuildContext context, {
    required String label,
    required String value,
    Key? key,
    VoidCallback? onTap,
    bool compact = false,
  }) {
    return Material(
      key: key,
      color: const Color(0xff102331),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: compact ? 34 : 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: const Color(0xff8197a5),
                    fontSize: compact ? 9 : 11,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: compact ? 3 : 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: const Color(0xffdce6eb),
                    fontSize: compact ? 12 : 14,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLineOfSightDetails(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff142735),
        title: Text(
          AppLocalizations.of(context)?.losDetails ?? '索敌详情',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Formula33DetailRow(
              label: AppLocalizations.of(context)?.totalLos ?? '总索敌',
              value: '${metrics.lineOfSight}',
            ),
            const Divider(color: Color(0xff294052)),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  _fleetL10n(context).formula33,
                  style: const TextStyle(
                    color: Color(0xffdce6eb),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (final result in metrics.formula33)
              _Formula33DetailRow(
                label: '× ${result.mapModifier.toInt()}',
                value: result.total.toStringAsFixed(2),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.close ?? '关闭'),
          ),
        ],
      ),
    );
  }
}

class _Formula33DetailRow extends StatelessWidget {
  const _Formula33DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xff9fb4bf)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xffe1e9ed),
              fontWeight: FontWeight.w800,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShipRow extends StatelessWidget {
  const _ShipRow({
    required this.state,
    required this.ship,
    required this.specialAttack,
  });

  static const _phoneStatusValueStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  final GameState state;
  final OwnedShip ship;
  final EquipmentMechanismDisplay? specialAttack;

  @override
  Widget build(BuildContext context) {
    final master = state.masterForShip(ship);
    final type = state.typeForShip(ship);
    final equipment = state.equipmentForShip(ship);
    final hpRatio = ship.maxHp <= 0 ? 0.0 : ship.currentHp / ship.maxHp;
    final fuelRatio = _ratio(ship.currentFuel, master?.maxFuel ?? 0);
    final ammoRatio = _ratio(ship.currentAmmo, master?.maxAmmo ?? 0);
    final needsSupply =
        ship.currentFuel < (master?.maxFuel ?? 0) ||
        ship.currentAmmo < (master?.maxAmmo ?? 0);
    final mechanisms = detectShipCombatMechanisms(state, ship);
    final specialMechanism = specialAttack == null
        ? null
        : EquipmentMechanismDisplay(
            label: AppLocalizations.of(context)?.specialAttack ?? '特殊攻击',
            description:
                '${specialAttack!.label}\n\n${specialAttack!.description}',
            tone: MechanismTone.specialAttack,
          );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isCompact = viewportWidth < 900;
    final portraitWidth = shipCardPortraitWidth(context);
    final identityWidth = isCompact ? 108.0 : 130.0;
    final healthWidth = isCompact ? 260.0 : 360.0;
    final supplyWidth = isCompact ? 210.0 : 272.0;
    final columnGap = isCompact ? 8.0 : 12.0;
    final statusColumnGap = columnGap + 24;

    if (usesCompactFleetLayout(context) ||
        MediaQuery.sizeOf(context).shortestSide < 700) {
      return Material(
        key: Key('ship-row-${ship.id}'),
        color: const Color(0xff142735),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: MediaQuery.removePadding(
          context: context,
          removeLeft: true,
          removeRight: true,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(0, 2, 10, 2),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            collapsedIconColor: const Color(0xff8197a5),
            iconColor: const Color(0xffd4a85f),
            trailing: const SizedBox(
              width: 18,
              child: Icon(
                Icons.expand_more,
                size: 16,
                color: Color(0xff8197a5),
              ),
            ),
            title: LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.maxWidth;
                final speedVisual = ShipSpeedVisual.fromSpeed(
                  ship.effectiveSpeed(master),
                );
                final maxCompactPortraitWidth = (available * 0.30).clamp(
                  56.0,
                  180.0,
                );
                final compactPortraitWidth = portraitWidth
                    .clamp(56.0, maxCompactPortraitWidth)
                    .toDouble();
                final nameWidth = (available * 0.17).clamp(40.0, 60.0);
                final resourceWidth =
                    ((available - compactPortraitWidth - nameWidth - 27) / 2.3)
                        .clamp(48.0, 200.0);
                final gap = 4.0;
                final identityStatusGap = viewportWidth < 400 ? 8.0 : 30.0;
                final showMechanisms = constraints.maxWidth >= 420;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ShipPortrait(
                      key: Key('ship-portrait-${ship.id}'),
                      ship: master,
                      serverOrigin: state.serverOrigin,
                      width: compactPortraitWidth,
                      height: shipCardPortraitHeight,
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: nameWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              master?.name ??
                                  (AppLocalizations.of(context)?.unknownShip ??
                                      '未知舰娘'),
                              key: Key('ship-identity-name-${ship.id}'),
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Next ${ship.nextExperience}',
                              key: Key('ship-identity-next-${ship.id}'),
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                color: Color(0xff8197a5),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: identityStatusGap),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 20,
                            child: Row(
                              key: Key('ship-identity-top-${ship.id}'),
                              children: [
                                Text(
                                  'Lv. ${ship.level}',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: _phoneStatusValueStyle.copyWith(
                                    color: const Color(0xffa9bac4),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: speedVisual.background,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            speedVisual.label,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              color: speedVisual.foreground,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (showMechanisms) ...[
                                          for (final mechanism
                                              in mechanisms) ...[
                                            const SizedBox(width: 5),
                                            _phoneMechanismChip(
                                              mechanism: mechanism,
                                            ),
                                          ],
                                          if (specialMechanism != null) ...[
                                            const SizedBox(width: 5),
                                            _phoneMechanismChip(
                                              mechanism: specialMechanism,
                                              special: true,
                                            ),
                                          ],
                                        ],
                                        const SizedBox(width: 5),
                                        Container(
                                          key: Key('ship-fatigue-${ship.id}'),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: shipFatigueColor(
                                              ship.condition,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            _fleetL10n(
                                              context,
                                            ).fatigueValue(ship.condition),
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              color: shipFatigueColor(
                                                ship.condition,
                                              ),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 20,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.favorite_rounded,
                                  key: Key('ship-status-hp-icon-${ship.id}'),
                                  color: const Color(0xffdd514c),
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                SizedBox(
                                  width: 32,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${ship.currentHp}/${ship.maxHp}',
                                      key: Key(
                                        'ship-status-hp-value-${ship.id}',
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: _phoneStatusValueStyle.copyWith(
                                        color: shipHpValueColor(
                                          hpRatio,
                                          isZeroHp: ship.currentHp <= 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      key: Key('ship-status-hp-${ship.id}'),
                                      minHeight: 5,
                                      value: hpRatio,
                                      color: shipHpBarColor(
                                        hpRatio,
                                        isZeroHp: ship.currentHp <= 0,
                                      ),
                                      backgroundColor: const Color(0xff263e4d),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: resourceWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            child: _phoneResourceBar(
                              icon: Image.asset(
                                'assets/images/material/01.png',
                                key: Key('ship-status-fuel-icon-${ship.id}'),
                                width: 12,
                                height: 12,
                                filterQuality: FilterQuality.medium,
                              ),
                              valueKey: Key(
                                'ship-status-fuel-value-${ship.id}',
                              ),
                              barKey: Key('ship-status-fuel-${ship.id}'),
                              value:
                                  '${ship.currentFuel}/${master?.maxFuel ?? 0}',
                              ratio: fuelRatio,
                              valueColor: shipSupplyValueColor(fuelRatio),
                              barColor: shipSupplyBarColor(fuelRatio),
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 20,
                            child: _phoneResourceBar(
                              icon: Image.asset(
                                'assets/images/material/02.png',
                                key: Key('ship-status-ammo-icon-${ship.id}'),
                                width: 12,
                                height: 12,
                                filterQuality: FilterQuality.medium,
                              ),
                              valueKey: Key(
                                'ship-status-ammo-value-${ship.id}',
                              ),
                              barKey: Key('ship-status-ammo-${ship.id}'),
                              value:
                                  '${ship.currentAmmo}/${master?.maxAmmo ?? 0}',
                              ratio: ammoRatio,
                              valueColor: shipSupplyValueColor(ammoRatio),
                              barColor: shipSupplyBarColor(ammoRatio),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            children: [
              if (equipment.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context)?.equipmentDataWaiting ??
                        '装备数据等待更新',
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                )
              else
                _EquipmentDetails(ship: ship, equipment: equipment),
            ],
          ),
        ),
      );
    }

    return Material(
      key: Key('ship-row-${ship.id}'),
      color: const Color(0xff142735),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
        childrenPadding: EdgeInsets.fromLTRB(
          portraitWidth + identityWidth + columnGap * 2 + 8,
          0,
          14,
          10,
        ),
        collapsedIconColor: const Color(0xff8197a5),
        iconColor: const Color(0xffd4a85f),
        title: Row(
          children: [
            ShipPortrait(
              key: Key('ship-portrait-${ship.id}'),
              ship: master,
              serverOrigin: state.serverOrigin,
              width: portraitWidth,
              height: shipCardPortraitHeight,
            ),
            SizedBox(width: columnGap),
            Expanded(
              child: SizedBox(
                height: shipCardPortraitHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: SizedBox(
                        key: Key('ship-identity-${ship.id}'),
                        width: identityWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              master?.name ??
                                  AppLocalizations.of(context)?.unknownShip ??
                                  '未知舰娘',
                              key: Key('ship-identity-name-${ship.id}'),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Next ${ship.nextExperience}',
                              key: Key('ship-identity-next-${ship.id}'),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff8197a5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: identityWidth + columnGap,
                      width: healthWidth + statusColumnGap + supplyWidth,
                      top: 4,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 22,
                            child: Row(
                              key: Key('ship-status-top-line-${ship.id}'),
                              children: [
                                Expanded(
                                  child: ClipRect(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: Row(
                                        key: Key(
                                          'ship-identity-top-${ship.id}',
                                        ),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Lv. ${ship.level}',
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xffa9bac4),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 110,
                                            ),
                                            child: Text(
                                              type?.name ??
                                                  AppLocalizations.of(
                                                    context,
                                                  )?.unknownShipType ??
                                                  '未知舰种',
                                              maxLines: 1,
                                              softWrap: false,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xffa9bac4),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          _SpeedBadge(
                                            key: Key('ship-speed-${ship.id}'),
                                            speed: ship.effectiveSpeed(master),
                                          ),
                                          for (final mechanism
                                              in mechanisms) ...[
                                            const SizedBox(width: 6),
                                            _MechanismChip(
                                              mechanism: mechanism,
                                            ),
                                          ],
                                          if (specialMechanism != null) ...[
                                            const SizedBox(width: 6),
                                            _MechanismChip(
                                              mechanism: specialMechanism,
                                              isSpecialAttack: true,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (needsSupply) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message:
                                        AppLocalizations.of(
                                          context,
                                        )?.needsSupply ??
                                        '需要补给',
                                    child: Icon(
                                      Icons.storage_rounded,
                                      key: Key(
                                        'ship-supply-warning-${ship.id}',
                                      ),
                                      color: const Color(0xffd79b45),
                                      size: 17,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                _ConditionBadge(
                                  key: Key('ship-fatigue-${ship.id}'),
                                  value: ship.condition,
                                ),
                                SizedBox(width: columnGap),
                                SizedBox(
                                  width: supplyWidth,
                                  child: _ShipStatusBar(
                                    key: Key('ship-status-fuel-${ship.id}'),
                                    semanticLabel:
                                        AppLocalizations.of(context)?.fuel ??
                                        '燃料',
                                    icon: Image.asset(
                                      'assets/images/material/01.png',
                                      key: Key(
                                        'ship-status-fuel-icon-${ship.id}',
                                      ),
                                      width: 18,
                                      height: 18,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                    valueKey: Key(
                                      'ship-status-fuel-value-${ship.id}',
                                    ),
                                    value:
                                        '${ship.currentFuel}/${master?.maxFuel ?? 0}',
                                    ratio: fuelRatio,
                                    valueColor: shipSupplyValueColor(fuelRatio),
                                    barColor: shipSupplyBarColor(fuelRatio),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 22,
                            child: Row(
                              key: Key('ship-status-bottom-line-${ship.id}'),
                              children: [
                                SizedBox(
                                  key: Key('ship-health-area-${ship.id}'),
                                  width: healthWidth,
                                  child: _ShipStatusBar(
                                    key: Key('ship-status-hp-${ship.id}'),
                                    semanticLabel:
                                        AppLocalizations.of(context)?.hp ??
                                        '血量',
                                    icon: Icon(
                                      key: Key(
                                        'ship-status-hp-icon-${ship.id}',
                                      ),
                                      Icons.favorite_rounded,
                                      color: const Color(0xffdd514c),
                                      size: 16,
                                    ),
                                    valueKey: Key(
                                      'ship-status-hp-value-${ship.id}',
                                    ),
                                    value: '${ship.currentHp}/${ship.maxHp}',
                                    ratio: hpRatio,
                                    valueColor: shipHpValueColor(
                                      hpRatio,
                                      isZeroHp: ship.currentHp <= 0,
                                    ),
                                    barColor: shipHpBarColor(
                                      hpRatio,
                                      isZeroHp: ship.currentHp <= 0,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(width: columnGap),
                                SizedBox(
                                  width: supplyWidth,
                                  child: _ShipStatusBar(
                                    key: Key('ship-status-ammo-${ship.id}'),
                                    semanticLabel:
                                        AppLocalizations.of(context)?.ammo ??
                                        '弹药',
                                    icon: Image.asset(
                                      'assets/images/material/02.png',
                                      key: Key(
                                        'ship-status-ammo-icon-${ship.id}',
                                      ),
                                      width: 18,
                                      height: 18,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                    valueKey: Key(
                                      'ship-status-ammo-value-${ship.id}',
                                    ),
                                    value:
                                        '${ship.currentAmmo}/${master?.maxAmmo ?? 0}',
                                    ratio: ammoRatio,
                                    valueColor: shipSupplyValueColor(ammoRatio),
                                    barColor: shipSupplyBarColor(ammoRatio),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        children: [
          if (equipment.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)?.equipmentDataWaiting ??
                    '装备数据等待更新',
                style: const TextStyle(color: Color(0xff8197a5)),
              ),
            )
          else
            _EquipmentDetails(ship: ship, equipment: equipment),
        ],
      ),
    );
  }

  Widget _phoneMechanismChip({
    required EquipmentMechanismDisplay mechanism,
    bool special = false,
  }) {
    final Color backgroundColor;
    final Color foregroundColor;
    if (special) {
      backgroundColor = const Color(0xff5a2528);
      foregroundColor = const Color(0xffff8b88);
    } else {
      backgroundColor = switch (mechanism.tone) {
        MechanismTone.antiAir => const Color(0xff4b3a1d),
        MechanismTone.specialAttack => const Color(0xff5a2528),
        MechanismTone.neutral ||
        MechanismTone.antiSubmarine => const Color(0xff29445a),
      };
      foregroundColor = switch (mechanism.tone) {
        MechanismTone.antiAir => const Color(0xffffc861),
        MechanismTone.specialAttack => const Color(0xffff8b88),
        MechanismTone.neutral ||
        MechanismTone.antiSubmarine => const Color(0xff8ec6e8),
      };
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mechanism.label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _phoneResourceBar({
    required Widget icon,
    required Key valueKey,
    required Key barKey,
    required String value,
    required double ratio,
    required Color valueColor,
    required Color barColor,
  }) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 2),
        SizedBox(
          width: 32,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: valueKey,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: _phoneStatusValueStyle.copyWith(color: valueColor),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              key: barKey,
              minHeight: 5,
              value: ratio,
              color: barColor,
              backgroundColor: const Color(0xff263e4d),
            ),
          ),
        ),
      ],
    );
  }

  static double _ratio(int current, int maximum) {
    return maximum <= 0 ? 0 : (current / maximum).clamp(0, 1);
  }

  static bool _isAircraft(MasterSlotItem? item) {
    if (item == null || item.type.length < 3) {
      return false;
    }
    final typeId = item.type[2];
    return (typeId >= 6 && typeId <= 11) ||
        (typeId >= 25 && typeId <= 26) ||
        (typeId >= 47 && typeId <= 48) ||
        (typeId >= 56 && typeId <= 59) ||
        const <int>{41, 45, 94}.contains(typeId);
  }

  static int _equipmentIconId(MasterSlotItem? item) {
    if (item == null || item.type.length < 4) {
      return -1;
    }
    return item.type[3];
  }
}

class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge({super.key, required this.speed});

  final int speed;

  @override
  Widget build(BuildContext context) {
    final visual = ShipSpeedVisual.fromSpeed(speed);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        visual.label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: visual.foreground,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EquipmentDetails extends StatelessWidget {
  const _EquipmentDetails({required this.ship, required this.equipment});

  final OwnedShip ship;
  final List<ShipEquipment> equipment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final phoneLike =
            isPhoneDensity(context) ||
            MediaQuery.sizeOf(context).shortestSide < 700;
        final useTwoColumns = phoneLike
            ? constraints.maxWidth >= 300
            : constraints.maxWidth >= 500;
        final cardWidth = useTwoColumns
            ? (constraints.maxWidth - spacing - 0.1) / 2
            : constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var index = 0; index < equipment.length; index++)
                  SizedBox(
                    width: cardWidth,
                    child: _EquipmentCard(
                      key: Key('equipment-card-${ship.id}-$index'),
                      ship: ship,
                      equipment: equipment[index],
                      index: index,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MechanismChip extends StatelessWidget {
  const _MechanismChip({required this.mechanism, this.isSpecialAttack = false});

  final EquipmentMechanismDisplay mechanism;
  final bool isSpecialAttack;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (mechanism.tone) {
      MechanismTone.antiAir => const Color(0xff4b3a1d),
      MechanismTone.specialAttack => const Color(0xff5a2528),
      MechanismTone.neutral ||
      MechanismTone.antiSubmarine => const Color(0xff29445a),
    };
    final foregroundColor = switch (mechanism.tone) {
      MechanismTone.antiAir => const Color(0xffffc861),
      MechanismTone.specialAttack => const Color(0xffff8b88),
      MechanismTone.neutral ||
      MechanismTone.antiSubmarine => const Color(0xff8ec6e8),
    };
    return Material(
      color: isSpecialAttack ? const Color(0xff5a2528) : backgroundColor,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text(
            mechanism.label,
            style: TextStyle(
              color: isSpecialAttack
                  ? const Color(0xffff8b88)
                  : foregroundColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff142735),
        title: Text(
          mechanism.label,
          style: TextStyle(
            color: isSpecialAttack
                ? const Color(0xffff8b88)
                : switch (mechanism.tone) {
                    MechanismTone.antiAir => const Color(0xffffc861),
                    MechanismTone.specialAttack => const Color(0xffff8b88),
                    MechanismTone.neutral ||
                    MechanismTone.antiSubmarine => const Color(0xff8ec6e8),
                  },
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          mechanism.description,
          style: const TextStyle(color: Color(0xffc2d0d7), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.gotIt ?? '知道了'),
          ),
        ],
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    super.key,
    required this.ship,
    required this.equipment,
    required this.index,
  });

  final OwnedShip ship;
  final ShipEquipment equipment;
  final int index;

  @override
  Widget build(BuildContext context) {
    final master = equipment.master;
    final stats = master == null
        ? const <EquipmentStatDisplay>[]
        : equipmentStatDisplays(master);
    final isAircraft = _ShipRow._isAircraft(master);
    final onSlot = isAircraft && index < ship.onSlot.length
        ? ship.onSlot[index]
        : null;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: const Color(0xff102331),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff294052)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EquipmentTypeIcon(
                imageKey: Key('equipment-icon-${ship.id}-$index'),
                slotKey: onSlot == null
                    ? null
                    : Key('equipment-onslot-${ship.id}-$index'),
                iconId: _ShipRow._equipmentIconId(master),
                onSlot: onSlot,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  master?.name ??
                      AppLocalizations.of(context)?.unknownEquipment ??
                      '未知装备',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffe1e9ed),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (equipment.owned.level > 0) ...[
                const SizedBox(width: 4),
                Row(
                  key: Key('equipment-improvement-${ship.id}-$index'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xff5daea6),
                      size: 15,
                    ),
                    const SizedBox(width: 1),
                    Text(
                      '${equipment.owned.level}',
                      style: const TextStyle(
                        color: Color(0xff5daea6),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (isAircraft &&
                  equipment.owned.proficiency >= 1 &&
                  equipment.owned.proficiency <= 7) ...[
                const SizedBox(width: 3),
                Image.asset(
                  'assets/images/airplane/alv${equipment.owned.proficiency}.png',
                  key: Key('equipment-proficiency-${ship.id}-$index'),
                  width: 20,
                  height: 18,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          if (stats.isEmpty)
            Text(
              AppLocalizations.of(context)?.noAdditionalStats ?? '暂无附加属性',
              style: const TextStyle(color: Color(0xff6f8795), fontSize: 11),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: [
                for (final stat in stats)
                  Text(
                    '${stat.label} ${stat.value}',
                    style: const TextStyle(
                      color: Color(0xff9fb2bd),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EquipmentTypeIcon extends StatelessWidget {
  const _EquipmentTypeIcon({
    required this.imageKey,
    required this.iconId,
    this.slotKey,
    this.onSlot,
  });

  final Key imageKey;
  final Key? slotKey;
  final int iconId;
  final int? onSlot;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/slotitem/$iconId.png',
      key: imageKey,
      width: 26,
      height: 26,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/slotitem/-1.png',
        width: 26,
        height: 26,
        filterQuality: FilterQuality.medium,
      ),
    );

    if (onSlot == null) {
      return SizedBox(width: 30, height: 30, child: Center(child: image));
    }

    return SizedBox(
      key: slotKey,
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 3, top: 3, child: image),
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              '$onSlot',
              style: const TextStyle(
                color: Color(0xffe7f0f4),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                shadows: <Shadow>[
                  Shadow(color: Color(0xff081521), blurRadius: 3),
                  Shadow(
                    color: Color(0xff081521),
                    blurRadius: 1,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  const _ConditionBadge({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final color = shipFatigueColor(value);
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        '${AppLocalizations.of(context)?.fatigue ?? '疲劳'} $value',
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ShipStatusBar extends StatelessWidget {
  const _ShipStatusBar({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.valueKey,
    required this.value,
    required this.ratio,
    required this.valueColor,
    required this.barColor,
  });

  final String semanticLabel;
  final Widget icon;
  final Key valueKey;
  final String value;
  final double ratio;
  final Color valueColor;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Tooltip(
            message: semanticLabel,
            child: SizedBox(width: 24, child: Center(child: icon)),
          ),
          SizedBox(
            width: 50,
            child: Text(
              key: valueKey,
              value,
              maxLines: 1,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              color: barColor,
              backgroundColor: const Color(0xff263f4d),
            ),
          ),
        ],
      ),
    );
  }
}
