import 'package:flutter/material.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import '../game_state/fleet_metrics.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'combat_mechanism.dart';
import 'equipment_display.dart';
import 'fleet_status_visual.dart';
import 'operation_status_views.dart';
import 'ship_portrait.dart';
import 'ship_status_style.dart';
import 'status_density.dart';

enum FleetInformationPage { fleet, expedition, repair, construction }

class FleetInformationCenter extends StatefulWidget {
  const FleetInformationCenter({
    super.key,
    required this.controller,
    this.page = FleetInformationPage.fleet,
    this.initialFleetId,
  });

  final GameStateController controller;
  final FleetInformationPage page;
  final int? initialFleetId;

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
              _PageHeader(updatedAt: state.updatedAt, page: widget.page),
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
                    ),
                    FleetInformationPage.expedition => ExpeditionStatusView(
                      state: state,
                    ),
                    FleetInformationPage.repair => RepairDockStatusView(
                      state: state,
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
  const _PageHeader({required this.updatedAt, required this.page});

  final DateTime? updatedAt;
  final FleetInformationPage page;

  @override
  Widget build(BuildContext context) {
    final localTime = updatedAt?.toLocal();
    final timeLabel = localTime == null
        ? AppLocalizations.of(context)?.waitingForData ?? '等待数据'
        : '${AppLocalizations.of(context)?.updatedAt ?? '更新'} ${_two(localTime.hour)}:${_two(localTime.minute)}:${_two(localTime.second)}';
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
          Text(
            timeLabel,
            style: const TextStyle(color: Color(0xff8197a5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
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
  });

  final GameState state;
  final int selectedFleetId;
  final ValueChanged<int> onFleetSelected;

  @override
  State<_FleetView> createState() => _FleetViewState();
}

class _FleetViewState extends State<_FleetView> {
  GameState? _lastState;
  GameState? _lastButtonsState;
  int _lastFleetId = 0;
  FleetMetrics? _cachedMetrics;
  List<Fleet>? _cachedFleetButtons;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              for (final item in fleetButtons) ...[
                Expanded(
                  child: _FleetButton(
                    key: Key('fleet-button-${item.id}'),
                    fleet: item,
                    selected: item.id == fleet.id,
                    onTap: () => widget.onFleetSelected(item.id),
                  ),
                ),
                if (item != fleetButtons.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
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
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: ships.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _ShipRow(
                      state: state,
                      ship: ships[index],
                      specialAttack: index == 0 ? specialAttack : null,
                    ),
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

class _FleetButton extends StatelessWidget {
  const _FleetButton({
    super.key,
    required this.fleet,
    required this.selected,
    required this.onTap,
  });

  final Fleet fleet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final phone = usesCompactFleetLayout(context);
    final status = fleetStatusVisual(fleet);
    return Material(
      color: selected ? const Color(0xff3a3020) : const Color(0xff102331),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: BoxConstraints(minHeight: phone ? 34 : 56),
          padding: EdgeInsets.symmetric(
            horizontal: phone ? 4 : 11,
            vertical: phone ? 3 : 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? const Color(0xff8d7040)
                  : const Color(0xff294052),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  key: Key('fleet-name-cell-${fleet.id}'),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fleet.name,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xfff0c675)
                              : const Color(0xffe1e9ed),
                          fontWeight: FontWeight.w700,
                          fontSize: phone ? 12 : 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  key: Key('fleet-status-cell-${fleet.id}'),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: Key('fleet-selector-status-dot-${fleet.id}'),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: phone ? 4 : 6),
                          Text(
                            status.label,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: phone ? 9 : 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        metrics.airPower?.toString() ?? noValue,
      ),
      (
        AppLocalizations.of(context)?.lineOfSight ?? '索敌',
        formula33.isEmpty ? noValue : formula33.first.total.toStringAsFixed(2),
      ),
      (
        AppLocalizations.of(context)?.averageCondition ?? '平均疲劳',
        '${metrics.averageCondition}',
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
              key: index == 7 ? const Key('fleet-los-metric') : null,
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
          height: compact ? 34 : 50,
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  '33式',
                  style: TextStyle(
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
  const _ShipRow({required this.state, required this.ship, this.specialAttack});

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
                                            color: (master?.speed ?? 0) >= 10
                                                ? const Color(0xff164c48)
                                                : const Color(0xff3b4650),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            (master?.speed ?? 0) >= 10
                                                ? (AppLocalizations.of(
                                                        context,
                                                      )?.highSpeed ??
                                                      '高速')
                                                : (AppLocalizations.of(
                                                        context,
                                                      )?.lowSpeed ??
                                                      '低速'),
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              color: (master?.speed ?? 0) >= 10
                                                  ? const Color(0xff7ed8cf)
                                                  : const Color(0xffc1ccd2),
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
                                            '疲劳 ${ship.condition}',
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
                                            speed: master?.speed ?? 0,
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
  const _SpeedBadge({required this.speed});

  final int speed;

  @override
  Widget build(BuildContext context) {
    final isFast = speed >= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isFast ? const Color(0xff164c48) : const Color(0xff3b4650),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isFast
            ? AppLocalizations.of(context)?.highSpeed ?? '高速'
            : AppLocalizations.of(context)?.lowSpeed ?? '低速',
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: isFast ? const Color(0xff7ed8cf) : const Color(0xffc1ccd2),
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
