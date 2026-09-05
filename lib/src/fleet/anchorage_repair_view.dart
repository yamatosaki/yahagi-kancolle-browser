import 'package:flutter/material.dart';
import 'fleet_ui_strings.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../performance/second_tick_scope.dart';
import 'anchorage_repair_calculator.dart';
import 'fleet_switcher_bar.dart';
import 'nosaki_sparkle_view.dart';
import 'operation_status_views.dart';
import 'ship_portrait.dart';
import 'status_density.dart';

const _background = Color(0xff081521);
const _surface = Color(0xff0d1a26);
const _surfaceRaised = Color(0xff102532);
const _border = Color(0xff294052);
const _muted = Color(0xff8197a5);
const _green = Color(0xff65d493);
const _yellow = Color(0xffefbd58);
const _red = Color(0xffef6f6c);

enum RepairCenterMode { dock, anchorage, nosaki }

@immutable
class RepairDestination {
  const RepairDestination({required this.mode, this.fleetId});

  final RepairCenterMode mode;
  final int? fleetId;
}

class RepairCenterView extends StatefulWidget {
  const RepairCenterView({
    super.key,
    required this.controller,
    this.mode,
    this.onModeChanged,
    this.showModeTabs = true,
    this.initialFleetId,
    this.onFleetSelected,
  });

  final GameStateController controller;
  final RepairCenterMode? mode;
  final ValueChanged<RepairCenterMode>? onModeChanged;
  final bool showModeTabs;
  final int? initialFleetId;
  final ValueChanged<int>? onFleetSelected;

  @override
  State<RepairCenterView> createState() => _RepairCenterViewState();
}

class _RepairCenterViewState extends State<RepairCenterView> {
  RepairCenterMode _mode = RepairCenterMode.dock;

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode ?? _mode;
    return ColoredBox(
      color: _background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showModeTabs)
            RepairModeTabs(
              mode: mode,
              onChanged: (nextMode) {
                widget.onModeChanged?.call(nextMode);
                if (widget.mode == null) {
                  setState(() => _mode = nextMode);
                }
              },
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => switch (mode) {
                RepairCenterMode.dock => RepairDockStatusView(
                  state: widget.controller.state,
                ),
                RepairCenterMode.anchorage => AnchorageRepairView(
                  controller: widget.controller,
                  initialFleetId: widget.initialFleetId,
                  onFleetSelected: widget.onFleetSelected,
                ),
                RepairCenterMode.nosaki => NosakiSparkleView(
                  controller: widget.controller,
                  initialFleetId: widget.initialFleetId,
                  onFleetSelected: widget.onFleetSelected,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RepairModeTabs extends StatelessWidget {
  const RepairModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final RepairCenterMode mode;
  final ValueChanged<RepairCenterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          key: const Key('repair-mode-segmented'),
          width: 360,
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xff0b202d),
            border: Border.all(color: const Color(0xff315064)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: _RepairModeTab(
                  key: const Key('repair-mode-dock'),
                  label: fleetText(context, '入渠修理'),
                  selected: mode == RepairCenterMode.dock,
                  onTap: () => onChanged(RepairCenterMode.dock),
                ),
              ),
              Expanded(
                child: _RepairModeTab(
                  key: const Key('repair-mode-anchorage'),
                  label: '泊地修理',
                  selected: mode == RepairCenterMode.anchorage,
                  onTap: () => onChanged(RepairCenterMode.anchorage),
                ),
              ),
              Expanded(
                child: _RepairModeTab(
                  key: const Key('repair-mode-nosaki'),
                  label: fleetText(context, '野埼刷闪'),
                  selected: mode == RepairCenterMode.nosaki,
                  onTap: () => onChanged(RepairCenterMode.nosaki),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepairModeTab extends StatelessWidget {
  const _RepairModeTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xff8a6628) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? const Color(0xffffdc88)
                  : const Color(0xff9fb3bf),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class AnchorageRepairView extends StatefulWidget {
  const AnchorageRepairView({
    super.key,
    required this.controller,
    this.initialFleetId,
    this.onFleetSelected,
  });

  final GameStateController controller;
  final int? initialFleetId;
  final ValueChanged<int>? onFleetSelected;

  @override
  State<AnchorageRepairView> createState() => _AnchorageRepairViewState();
}

class _AnchorageRepairViewState extends State<AnchorageRepairView> {
  late int _selectedFleetId =
      widget.initialFleetId ??
      widget.controller.state.fleets.firstOrNull?.id ??
      1;

  @override
  void didUpdateWidget(AnchorageRepairView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFleetId != oldWidget.initialFleetId) {
      _selectedFleetId =
          widget.initialFleetId ??
          widget.controller.state.fleets.firstOrNull?.id ??
          1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecondTickBuilder(
      builder: (context, now, _) => _buildAt(context, now),
    );
  }

  Widget _buildAt(BuildContext context, DateTime now) {
    final state = widget.controller.state;
    final effectiveFleetId =
        state.fleets.any((fleet) => fleet.id == _selectedFleetId)
        ? _selectedFleetId
        : state.fleets.firstOrNull?.id ?? _selectedFleetId;
    final startedAt = widget.controller.anchorageRepairStartedAt;
    final elapsed = startedAt == null || now.isBefore(startedAt)
        ? Duration.zero
        : now.difference(startedAt);
    final projection = AnchorageRepairCalculator.project(
      state: state,
      fleetId: effectiveFleetId,
      elapsed: elapsed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xff0a1823),
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: FleetSwitcherBar(
            fleets: state.fleets,
            selectedFleetId: effectiveFleetId,
            showTitle: false,
            sortieFleetId: state.combatState.isActive
                ? state.combatState.sortieFleetId
                : null,
            onFleetSelected: (id) {
              setState(() => _selectedFleetId = id);
              widget.onFleetSelected?.call(id);
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 14 : 10,
                  vertical: 8,
                ),
                children: [
                  _SummaryGrid(
                    projection: projection,
                    elapsedLabel: startedAt == null || !projection.isReady
                        ? '--:--:--'
                        : _formatDuration(elapsed),
                  ),
                  const SizedBox(height: 8),
                  _AnchorageRepairTable(
                    projection: projection,
                    serverOrigin: state.serverOrigin,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.projection, required this.elapsedLabel});

  final AnchorageRepairProjection projection;
  final String elapsedLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 8.0;
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final height = usesCompactFleetLayout(context) ? 30.0 : 32.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _SummaryCard(
              key: const Key('anchorage-summary-status'),
              width: width,
              height: height,
              label: fleetText(context, '当前状态'),
              value: projection.isReady
                  ? fleetText(context, 'HP 修理准备就绪')
                  : fleetText(context, 'HP 修理未就绪'),
              valueColor: projection.isReady ? _green : _yellow,
            ),
            _SummaryCard(
              key: const Key('anchorage-summary-elapsed'),
              width: width,
              height: height,
              label: fleetText(context, '泊地修理已计时'),
              value: elapsedLabel,
            ),
            _SummaryCard(
              key: const Key('anchorage-summary-capacity'),
              width: width,
              height: height,
              label: fleetText(context, '可修理数量'),
              value: fleetText(
                context,
                '${projection.repairableCount} 艘（修理设施 X ${projection.facilityCount}）',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.width,
    required this.height,
    required this.label,
    required this.value,
    this.valueColor = const Color(0xffedf2f4),
  });

  final double width;
  final double height;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _surfaceRaised,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorageRepairTable extends StatelessWidget {
  const _AnchorageRepairTable({
    required this.projection,
    required this.serverOrigin,
  });

  final AnchorageRepairProjection projection;
  final String serverOrigin;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('anchorage-repair-table'),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TableCells(
            header: true,
            children: [
              Text(fleetText(context, '舰娘')),
              _HpLabel(),
              Text(fleetText(context, '泊地修理状态')),
              Text(fleetText(context, '修理时间')),
              Text(fleetText(context, '单位修理时间')),
              Text(fleetText(context, '预计已回复')),
            ],
          ),
          for (final row in projection.rows)
            _AnchorageTableRow(
              key: Key('anchorage-repair-row-${row.position + 1}'),
              row: row,
              serverOrigin: serverOrigin,
            ),
        ],
      ),
    );
  }
}

class _TableCells extends StatelessWidget {
  const _TableCells({required this.children, this.header = false});

  final List<Widget> children;
  final bool header;

  static const _flexes = <int>[34, 12, 16, 13, 13, 12];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: header ? 32 : 48),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: header ? 4 : 5),
      decoration: BoxDecoration(
        color: header ? _surfaceRaised : _surface,
        border: const Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++)
            Expanded(
              flex: _flexes[index],
              child: DefaultTextStyle(
                style: TextStyle(
                  color: header ? _muted : const Color(0xffdce6eb),
                  fontSize: header ? 11 : 12,
                  fontWeight: header ? FontWeight.w800 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: children[index],
              ),
            ),
        ],
      ),
    );
  }
}

class _AnchorageTableRow extends StatelessWidget {
  const _AnchorageTableRow({
    super.key,
    required this.row,
    required this.serverOrigin,
  });

  final AnchorageRepairShipProjection row;
  final String serverOrigin;

  @override
  Widget build(BuildContext context) {
    return _TableCells(
      children: [
        _ShipIdentity(row: row, serverOrigin: serverOrigin),
        _HpValue(ship: row.ship),
        Align(alignment: Alignment.centerLeft, child: _StatusBadge(row.status)),
        Text(_durationOrDash(row.remaining)),
        Text(_durationOrDash(row.unitDuration)),
        Text('＋${row.estimatedRecoveredHp} / ${row.lostHp}'),
      ],
    );
  }
}

class _ShipIdentity extends StatelessWidget {
  const _ShipIdentity({required this.row, required this.serverOrigin});

  final AnchorageRepairShipProjection row;
  final String serverOrigin;

  @override
  Widget build(BuildContext context) {
    final name = row.master?.name ?? fleetText(context, '未知舰娘');
    return Row(
      children: [
        ShipPortrait(
          key: Key('anchorage-repair-portrait-${row.ship.id}'),
          ship: row.master,
          serverOrigin: serverOrigin,
          width: 68,
          height: 34,
          decodeHeight: 68,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: Color(0xffeef3f5),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Lv.${row.ship.level}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HpLabel extends StatelessWidget {
  const _HpLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('♥', style: TextStyle(color: _red)),
        SizedBox(width: 3),
        Text('HP'),
      ],
    );
  }
}

class _HpValue extends StatelessWidget {
  const _HpValue({required this.ship});

  final OwnedShip ship;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('♥', style: TextStyle(color: _red, fontSize: 12)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${ship.currentHp} / ${ship.maxHp}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xffe6edf0),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final AnchorageRepairShipStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AnchorageRepairShipStatus.completed => (
        fleetText(context, '修理已完成'),
        _green,
      ),
      AnchorageRepairShipStatus.repairing => (
        fleetText(context, '正在修理中'),
        _yellow,
      ),
      AnchorageRepairShipStatus.outOfRange => (
        fleetText(context, '超出修理范围'),
        _red,
      ),
      AnchorageRepairShipStatus.unable => (fleetText(context, '无法修理'), _red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _durationOrDash(Duration? duration) =>
    duration == null ? '—' : _formatDuration(duration);

String _formatDuration(Duration duration) {
  final seconds = duration.isNegative ? 0 : duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  final remainder = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}
