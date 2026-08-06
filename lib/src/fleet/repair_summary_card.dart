import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'anchorage_repair_calculator.dart';
import 'anchorage_repair_view.dart';
import 'dashboard_card.dart';
import 'operation_progress.dart';
import 'ship_portrait.dart';

class RepairSummaryCard extends StatefulWidget {
  const RepairSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenRepair,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<RepairDestination> onOpenRepair;

  @override
  State<RepairSummaryCard> createState() => _RepairSummaryCardState();
}

class _RepairSummaryCardState extends State<RepairSummaryCard> {
  RepairCenterMode _mode = RepairCenterMode.dock;
  int? _selectedFleetId;
  Timer? _ticker;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    if (!widget.collapsed) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now().toUtc());
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void didUpdateWidget(RepairSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed && !widget.collapsed) {
      _now = DateTime.now().toUtc();
      _startTicker();
    } else if (!oldWidget.collapsed && widget.collapsed) {
      _stopTicker();
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final strings =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));
        return DashboardCard(
          title: strings.repairBrief,
          icon: const Icon(Icons.build_circle_outlined),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
          trailing: _RepairSummaryModeSelector(
            mode: _mode,
            dockLabel: strings.repairDockMode,
            anchorageLabel: strings.anchorageRepairMode,
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          child: _mode == RepairCenterMode.dock
              ? _buildDockGrid(state, strings)
              : _buildAnchorageSummary(state, strings),
        );
      },
    );
  }

  Widget _buildDockGrid(GameState state, AppLocalizations strings) {
    final docks = state.repairDocks;
    return Column(
      key: const Key('repair-summary-dock-grid'),
      children: [
        Row(
          children: [
            _buildDockSlot(
              1,
              docks.isNotEmpty ? docks[0] : null,
              state,
              strings,
            ),
            const SizedBox(width: 8),
            _buildDockSlot(
              2,
              docks.length > 1 ? docks[1] : null,
              state,
              strings,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDockSlot(
              3,
              docks.length > 2 ? docks[2] : null,
              state,
              strings,
            ),
            const SizedBox(width: 8),
            _buildDockSlot(
              4,
              docks.length > 3 ? docks[3] : null,
              state,
              strings,
            ),
          ],
        ),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildDockSlot(
    int position,
    RepairDock? dock,
    GameState state,
    AppLocalizations strings,
  ) {
    var name = '未知';
    var active = false;
    var disabled = true;
    MasterShip? master;

    if (dock != null) {
      if (dock.isLocked) {
        disabled = true;
      } else if (!dock.isRepairing) {
        name = strings.idle;
        disabled = false;
      } else {
        final ship = state.ships[dock.shipId];
        master = ship == null ? null : state.masterShips[ship.masterId];
        name = master?.name ?? '未知';
        disabled = false;
        active = true;
      }
    }

    final completed =
        active &&
        dock?.completionTime != null &&
        !_now.isBefore(dock!.completionTime!);
    return _RepairCapsule(
      key: Key('repair-summary-dock-slot-$position'),
      state: state,
      master: master,
      name: name,
      disabled: disabled,
      fitFullName: true,
      dotColor: active
          ? (completed ? const Color(0xff4caf50) : const Color(0xffffc940))
          : null,
      detail: active && dock != null
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: OperationCountdownText(
                completionTime: dock.completionTime,
                completedText: strings.completed,
                completedColor: const Color(0xff4caf50),
                countingColor: const Color(0xffd4a85f),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                maxLines: 1,
              ),
            )
          : Text(
              disabled ? '锁' : strings.inactive,
              style: TextStyle(
                fontSize: 11,
                color: disabled
                    ? const Color(0xff4a5c68)
                    : const Color(0xff8197a5),
              ),
            ),
      onTap: () => widget.onOpenRepair(
        const RepairDestination(mode: RepairCenterMode.dock),
      ),
    );
  }

  Widget _buildAnchorageSummary(GameState state, AppLocalizations strings) {
    final visibleFleets = state.fleets.take(4).toList(growable: false);
    final selectedFleet = visibleFleets
        .where((fleet) => fleet.id == _selectedFleetId)
        .firstOrNull;
    final effectiveFleet = selectedFleet ?? visibleFleets.firstOrNull;
    final fleetId = effectiveFleet?.id ?? _selectedFleetId ?? 1;
    final startedAt = widget.controller.anchorageRepairStartedAt;
    final elapsed = startedAt == null || _now.isBefore(startedAt)
        ? Duration.zero
        : _now.difference(startedAt);
    final projection = AnchorageRepairCalculator.project(
      state: state,
      fleetId: fleetId,
      elapsed: elapsed,
    );

    return Column(
      children: [
        _AnchorageFleetSelector(
          fleets: visibleFleets,
          selectedFleetId: fleetId,
          onSelected: (id) => setState(() => _selectedFleetId = id),
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < 3; row++) ...[
          Row(
            children: [
              _buildAnchorageSlot(row * 2, fleetId, state, projection, strings),
              const SizedBox(width: 8),
              _buildAnchorageSlot(
                row * 2 + 1,
                fleetId,
                state,
                projection,
                strings,
              ),
            ],
          ),
          if (row < 2) const SizedBox(height: 8),
        ],
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildAnchorageSlot(
    int position,
    int fleetId,
    GameState state,
    AnchorageRepairProjection projection,
    AppLocalizations strings,
  ) {
    final row = projection.rows
        .where((candidate) => candidate.position == position)
        .firstOrNull;
    if (row == null) {
      return _RepairCapsule(
        key: Key('repair-summary-anchorage-slot-$position'),
        contentKey: const Key('repair-summary-anchorage-slot'),
        state: state,
        name: strings.idle,
        disabled: false,
        detail: Text(
          strings.inactive,
          style: const TextStyle(fontSize: 11, color: Color(0xff8197a5)),
        ),
        onTap: () => widget.onOpenRepair(
          RepairDestination(mode: RepairCenterMode.anchorage, fleetId: fleetId),
        ),
      );
    }

    final visual = _anchorageVisual(row.status, strings, row.remaining);
    return _RepairCapsule(
      key: Key('repair-summary-anchorage-slot-$position'),
      contentKey: const Key('repair-summary-anchorage-slot'),
      state: state,
      master: row.master,
      name: row.master?.name ?? '未知',
      disabled: false,
      fitFullName: true,
      dotColor: visual.color,
      detail: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          visual.label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: visual.color,
          ),
        ),
      ),
      onTap: () => widget.onOpenRepair(
        RepairDestination(mode: RepairCenterMode.anchorage, fleetId: fleetId),
      ),
    );
  }

  ({String label, Color color}) _anchorageVisual(
    AnchorageRepairShipStatus status,
    AppLocalizations strings,
    Duration? remaining,
  ) => switch (status) {
    AnchorageRepairShipStatus.completed => (
      label: strings.completed,
      color: const Color(0xff65d493),
    ),
    AnchorageRepairShipStatus.repairing => (
      label: remaining == null ? strings.repairing : _durationText(remaining),
      color: const Color(0xffefbd58),
    ),
    AnchorageRepairShipStatus.outOfRange => (
      label: strings.outOfRepairRange,
      color: const Color(0xffef6f6c),
    ),
    AnchorageRepairShipStatus.unable => (
      label: strings.unableToRepair,
      color: const Color(0xffef6f6c),
    ),
  };

  String _durationText(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _RepairSummaryModeSelector extends StatelessWidget {
  const _RepairSummaryModeSelector({
    required this.mode,
    required this.dockLabel,
    required this.anchorageLabel,
    required this.onChanged,
  });

  final RepairCenterMode mode;
  final String dockLabel;
  final String anchorageLabel;
  final ValueChanged<RepairCenterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('repair-summary-mode-selector'),
      width: 112,
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xff102331),
        border: Border.all(color: const Color(0xff294052)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              key: const Key('repair-summary-mode-dock'),
              label: dockLabel,
              selected: mode == RepairCenterMode.dock,
              onTap: () => onChanged(RepairCenterMode.dock),
            ),
          ),
          Expanded(
            child: _ModeButton(
              key: const Key('repair-summary-mode-anchorage'),
              label: anchorageLabel,
              selected: mode == RepairCenterMode.anchorage,
              onTap: () => onChanged(RepairCenterMode.anchorage),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xff8a6628) : Colors.transparent,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xffffdc88)
                  : const Color(0xff9fb3bf),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AnchorageFleetSelector extends StatelessWidget {
  const _AnchorageFleetSelector({
    required this.fleets,
    required this.selectedFleetId,
    required this.onSelected,
  });

  final List<Fleet> fleets;
  final int selectedFleetId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('repair-summary-fleet-selector'),
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xff102331),
        border: Border.all(color: const Color(0xff294052)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final fleet in fleets) ...[
            Expanded(
              child: Material(
                key: Key('repair-summary-fleet-${fleet.id}'),
                color: fleet.id == selectedFleetId
                    ? const Color(0xff8a6628)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () => onSelected(fleet.id),
                  borderRadius: BorderRadius.circular(6),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fleet.name,
                        maxLines: 1,
                        style: TextStyle(
                          color: fleet.id == selectedFleetId
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
            ),
            if (fleet != fleets.last) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

class _RepairCapsule extends StatelessWidget {
  const _RepairCapsule({
    super.key,
    required this.state,
    required this.name,
    required this.disabled,
    required this.detail,
    required this.onTap,
    this.master,
    this.dotColor,
    this.fitFullName = false,
    this.contentKey,
  });

  final GameState state;
  final MasterShip? master;
  final String name;
  final bool disabled;
  final Widget detail;
  final VoidCallback onTap;
  final Color? dotColor;
  final bool fitFullName;
  final Key? contentKey;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth - 18;
          final portraitWidth = available >= 138
              ? 96.0
              : (available - 42).clamp(32.0, 96.0).toDouble();
          final iconWidth = portraitWidth < 32 ? portraitWidth : 32.0;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                key: contentKey,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff0d1a26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    if (master != null) ...[
                      ShipPortrait(
                        ship: master!,
                        serverOrigin: state.serverOrigin,
                        width: portraitWidth,
                        height: 32,
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      Container(
                        width: iconWidth,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xff142735),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.build_rounded,
                            size: 16,
                            color: disabled
                                ? const Color(0xff4a5c68)
                                : const Color(0xff8197a5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: fitFullName
                                    ? FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: _nameText(),
                                      )
                                    : _nameText(),
                              ),
                              if (dotColor != null)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          detail,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Text _nameText() => Text(
    name,
    maxLines: 1,
    overflow: fitFullName ? null : TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: disabled ? const Color(0xff4a5c68) : Colors.white,
    ),
  );
}
