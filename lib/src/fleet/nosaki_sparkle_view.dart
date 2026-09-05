import 'package:flutter/material.dart';
import 'fleet_ui_strings.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../performance/second_tick_scope.dart';
import 'fleet_switcher_bar.dart';
import 'nosaki_sparkle_calculator.dart';
import 'ship_portrait.dart';
import 'status_density.dart';

const _surface = Color(0xff0d1a26);
const _surfaceRaised = Color(0xff102532);
const _border = Color(0xff294052);
const _muted = Color(0xff8197a5);
const _green = Color(0xff65d493);
const _yellow = Color(0xffefbd58);
const _sparkleGold = Color(0xffffd859);
const _red = Color(0xffef6f6c);
const _blue = Color(0xff65b3e6);

class NosakiSparkleView extends StatefulWidget {
  const NosakiSparkleView({
    super.key,
    required this.controller,
    this.initialFleetId,
    this.onFleetSelected,
  });

  final GameStateController controller;
  final int? initialFleetId;
  final ValueChanged<int>? onFleetSelected;

  @override
  State<NosakiSparkleView> createState() => _NosakiSparkleViewState();
}

class _NosakiSparkleViewState extends State<NosakiSparkleView> {
  late int _selectedFleetId =
      widget.initialFleetId ??
      widget.controller.state.fleets.firstOrNull?.id ??
      1;

  @override
  void didUpdateWidget(NosakiSparkleView oldWidget) {
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
    final startedAt = widget.controller.nosakiSparkleStartedAt;
    final elapsed = startedAt == null || now.isBefore(startedAt)
        ? Duration.zero
        : now.difference(startedAt);
    final projection = NosakiSparkleCalculator.project(
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
                  _NosakiSummaryGrid(
                    projection: projection,
                    elapsed: elapsed,
                    hasTimer: startedAt != null,
                  ),
                  const SizedBox(height: 8),
                  _NosakiSparkleTable(
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

class _NosakiSummaryGrid extends StatelessWidget {
  const _NosakiSummaryGrid({
    required this.projection,
    required this.elapsed,
    required this.hasTimer,
  });

  final NosakiSparkleProjection projection;
  final Duration elapsed;
  final bool hasTimer;

  @override
  Widget build(BuildContext context) {
    final statusValue = projection.isReady
        ? fleetText(context, '母港给粮就绪中')
        : (projection.unreadyReason ?? fleetText(context, '未就绪'));
    final statusColor = projection.isReady ? _green : _yellow;

    final timerValue = !hasTimer || !projection.isReady
        ? '--:--:--'
        : _formatDuration(elapsed);

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
            _NosakiSummaryCard(
              key: const Key('nosaki-summary-status'),
              width: width,
              height: height,
              label: fleetText(context, '当前状态'),
              value: fleetText(context, statusValue),
              valueColor: statusColor,
            ),
            _NosakiSummaryCard(
              key: const Key('nosaki-summary-elapsed'),
              width: width,
              height: height,
              label: fleetText(context, '刷闪计时'),
              value: timerValue,
              valueColor: hasTimer && projection.isReady
                  ? _sparkleGold
                  : const Color(0xffedf2f4),
            ),
            _NosakiSummaryCard(
              key: const Key('nosaki-summary-capacity'),
              width: width,
              height: height,
              label: fleetText(context, '预估消耗'),
              valueWidget: projection.isReady
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fleetText(
                            context,
                            '${projection.eligibleShipCount} 艘（${projection.fuelCostPerTick} ',
                          ),
                          style: const TextStyle(
                            color: Color(0xffedf2f4),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Image.asset(
                          'assets/images/material/01.png',
                          width: 14,
                          height: 14,
                          filterQuality: FilterQuality.medium,
                        ),
                        Text(
                          fleetText(context, '/次）'),
                          style: TextStyle(
                            color: Color(0xffedf2f4),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      fleetText(context, '0 艘'),
                      style: TextStyle(
                        color: Color(0xffedf2f4),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NosakiSummaryCard extends StatelessWidget {
  const _NosakiSummaryCard({
    super.key,
    required this.width,
    required this.height,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor = const Color(0xffedf2f4),
  });

  final double width;
  final double height;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final content =
        valueWidget ??
        Text(
          value ?? '',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );

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
            content,
          ],
        ),
      ),
    );
  }
}

class _NosakiSparkleTable extends StatelessWidget {
  const _NosakiSparkleTable({
    required this.projection,
    required this.serverOrigin,
  });

  final NosakiSparkleProjection projection;
  final String serverOrigin;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('nosaki-sparkle-table'),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _NosakiTableCells(
            header: true,
            children: [
              Text(fleetText(context, '舰娘')),
              _HpLabel(),
              Text(fleetText(context, '当前疲劳')),
              Text(fleetText(context, '状态')),
              Text(fleetText(context, '预估满闪 (54)')),
              Text(fleetText(context, '单次增量')),
            ],
          ),
          for (final row in projection.rows)
            _NosakiTableRow(
              key: Key('nosaki-sparkle-row-${row.position + 1}'),
              row: row,
              serverOrigin: serverOrigin,
            ),
        ],
      ),
    );
  }
}

class _NosakiTableCells extends StatelessWidget {
  const _NosakiTableCells({required this.children, this.header = false});

  final List<Widget> children;
  final bool header;

  static const _flexes = <int>[32, 12, 13, 15, 15, 13];

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

class _NosakiTableRow extends StatelessWidget {
  const _NosakiTableRow({
    super.key,
    required this.row,
    required this.serverOrigin,
  });

  final NosakiShipSparkleProjection row;
  final String serverOrigin;

  @override
  Widget build(BuildContext context) {
    return _NosakiTableCells(
      children: [
        _NosakiShipIdentity(row: row, serverOrigin: serverOrigin),
        _NosakiHpValue(ship: row.ship),
        _NosakiCondBadge(condition: row.currentCond),
        Align(
          alignment: Alignment.centerLeft,
          child: _NosakiStatusBadge(
            status: row.status,
            reason: row.statusReason,
          ),
        ),
        _TimeToTarget(row: row),
        Text(row.gainCond > 0 ? '+${row.gainCond} Cond' : '—'),
      ],
    );
  }
}

class _NosakiShipIdentity extends StatelessWidget {
  const _NosakiShipIdentity({required this.row, required this.serverOrigin});

  final NosakiShipSparkleProjection row;
  final String serverOrigin;

  @override
  Widget build(BuildContext context) {
    final name = row.master?.name ?? fleetText(context, '未知舰娘');
    final posLabel = row.position == 0
        ? fleetText(context, '旗舰')
        : (row.position == 1
              ? fleetText(context, '2号舰')
              : fleetText(context, '${row.position + 1}号位'));

    return Row(
      children: [
        ShipPortrait(
          key: Key('nosaki-sparkle-portrait-${row.ship.id}'),
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
                'Lv.${row.ship.level} · $posLabel',
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

class _NosakiHpValue extends StatelessWidget {
  const _NosakiHpValue({required this.ship});

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
            '${ship.currentHp}/${ship.maxHp}',
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

class _NosakiCondBadge extends StatelessWidget {
  const _NosakiCondBadge({required this.condition});

  final int condition;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, icon) = switch (condition) {
      >= 50 => (
        _sparkleGold.withValues(alpha: 0.16),
        _sparkleGold,
        _sparkleGold.withValues(alpha: 0.45),
        '★ ',
      ),
      < 20 => (
        _red.withValues(alpha: 0.16),
        _red,
        _red.withValues(alpha: 0.45),
        '',
      ),
      < 30 => (
        _yellow.withValues(alpha: 0.16),
        _yellow,
        _yellow.withValues(alpha: 0.45),
        '',
      ),
      _ => (
        Colors.white.withValues(alpha: 0.08),
        const Color(0xffd2dee4),
        Colors.white.withValues(alpha: 0.15),
        '',
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$icon$condition',
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeToTarget extends StatelessWidget {
  const _TimeToTarget({required this.row});

  final NosakiShipSparkleProjection row;

  @override
  Widget build(BuildContext context) {
    if (row.status == NosakiSparkleShipStatus.nosakiSelf) {
      return const Text('—');
    }
    if (row.status == NosakiSparkleShipStatus.completed) {
      return Text(
        fleetText(context, '已达成 54'),
        style: TextStyle(color: _sparkleGold),
      );
    }
    if (row.estimatedTimeTo54 == null) {
      return const Text('—');
    }
    final mins = row.estimatedTimeTo54!.inMinutes;
    return Text(fleetText(context, '$mins 分 (${row.neededTicks}次)'));
  }
}

class _NosakiStatusBadge extends StatelessWidget {
  const _NosakiStatusBadge({required this.status, this.reason});

  final NosakiSparkleShipStatus status;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      NosakiSparkleShipStatus.sparkling => (fleetText(context, '刷闪中'), _yellow),
      NosakiSparkleShipStatus.completed => (fleetText(context, '已刷闪'), _green),
      NosakiSparkleShipStatus.nosakiSelf => (fleetText(context, '给粮舰'), _green),
      NosakiSparkleShipStatus.docked => (fleetText(context, '入渠中'), _blue),
      NosakiSparkleShipStatus.unable => (
        reason ?? fleetText(context, '条件不符'),
        _red,
      ),
      NosakiSparkleShipStatus.unready => (
        reason ?? fleetText(context, '未就绪'),
        _red,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        fleetText(context, label),
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

String _formatDuration(Duration duration) {
  final seconds = duration.isNegative ? 0 : duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  final remainder = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}
