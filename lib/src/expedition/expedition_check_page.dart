import 'package:flutter/material.dart';

import '../fleet/fleet_switcher_bar.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'expedition_evaluator.dart';
import 'expedition_income_calculator.dart';
import 'expedition_rule_catalog.dart';
import 'expedition_strings.dart';

class ExpeditionCheckPage extends StatefulWidget {
  const ExpeditionCheckPage({
    super.key,
    required this.controller,
    required this.onBack,
    this.initialFleetId,
    this.showHeader = true,
  });
  final GameStateController controller;
  final VoidCallback onBack;
  final int? initialFleetId;
  final bool showHeader;
  @override
  State<ExpeditionCheckPage> createState() => _ExpeditionCheckPageState();
}

class _ExpeditionCheckPageState extends State<ExpeditionCheckPage> {
  late int fleetId = widget.initialFleetId ?? 2;
  int missionId = 14, target = 100;
  bool great = false;
  @override
  Widget build(BuildContext context) {
    final s = ExpeditionStrings.of(context);
    return Material(
      color: const Color(0xff081521),
      child: Column(
        children: [
          if (widget.showHeader)
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xff0d1a26),
                border: Border(bottom: BorderSide(color: Color(0xff294052))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    s.title,
                    style: const TextStyle(
                      color: Color(0xffd4a85f),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.sports_esports_outlined),
                    label: Text(s.back),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) =>
                  _body(context, widget.controller.state, s),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, GameState state, ExpeditionStrings s) {
    final fleets = state.fleets.where((f) => f.shipIds.isNotEmpty).toList();
    if (!state.hasPortData || fleets.isEmpty) {
      return Center(child: Text(s.waiting));
    }
    final fleet = fleets.cast<Fleet?>().firstWhere(
      (f) => f!.id == fleetId,
      orElse: () => fleets.first,
    )!;
    final ev = const ExpeditionEvaluator().evaluate(
      state: state,
      fleet: fleet,
      missionId: missionId,
      greatSuccessTarget: target,
    );
    final income = ExpeditionIncomeCalculator.forMission(
      mission: state.masterMissions[missionId],
      greatSuccess: great,
      daihatsuBonus: ExpeditionIncomeCalculator.daihatsuBonusForFleet(
        state,
        fleet,
      ),
    );
    final mission = state.masterMissions[missionId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xff0a1823),
            border: Border(bottom: BorderSide(color: Color(0xff294052))),
          ),
          child: FleetSwitcherBar(
            fleets: fleets,
            selectedFleetId: fleetId,
            showTitle: false,
            onFleetSelected: (id) => setState(() => fleetId = id),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final normalResult =
                          '${s.normalCheck}: ${ev.normalPassed ? s.passed : s.failed}';
                      final greatResult =
                          '${s.greatSuccess}: ${ev.greatSuccessPassed ? s.passed : s.failed} (${ev.greatSuccessRate.toStringAsFixed(2)}%)';
                      final minimumControlsWidth = great ? 460.0 : 390.0;
                      final estimatedResultsWidth = great ? 350.0 : 150.0;
                      final resultsOnSecondLine =
                          headerConstraints.maxWidth <
                          minimumControlsWidth + estimatedResultsWidth + 12;
                      final controls = _headerControls(
                        state: state,
                        strings: s,
                      );
                      final results = _headerResults(
                        normalText: normalResult,
                        normalPassed: ev.normalPassed,
                        greatText: great ? greatResult : null,
                        greatPassed: ev.greatSuccessPassed,
                        fillAvailableWidth: resultsOnSecondLine,
                      );

                      if (resultsOnSecondLine) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            controls,
                            const SizedBox(height: 8),
                            results,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: controls),
                          const SizedBox(width: 12),
                          results,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  if (c.maxWidth > 760)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _overview(s, mission, income, ev)),
                        const SizedBox(width: 12),
                        Expanded(child: _conditions(s, ev)),
                      ],
                    )
                  else ...[
                    _overview(s, mission, income, ev),
                    const SizedBox(height: 12),
                    _conditions(s, ev),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerControls({
    required GameState state,
    required ExpeditionStrings strings,
  }) {
    return Row(
      key: const Key('expedition-header-controls'),
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: missionId,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final id in expeditionRules.keys)
                DropdownMenuItem(
                  value: id,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_displayId(id)} · ${state.masterMissions[id]?.name ?? '远征'}',
                      key: id == missionId
                          ? const Key('expedition-mission-label')
                          : null,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => missionId = value);
            },
          ),
        ),
        const SizedBox(width: 8),
        _SegmentGroup(
          width: 190,
          children: [
            _SegmentButton(
              label: strings.success,
              selected: !great,
              onTap: () => setState(() => great = false),
            ),
            _SegmentButton(
              label: strings.greatSuccess,
              selected: great,
              onTap: () => setState(() => great = true),
            ),
          ],
        ),
        if (great) ...[
          const SizedBox(width: 8),
          _TargetMenu(
            target: target,
            onSelected: (value) => setState(() => target = value),
          ),
        ],
      ],
    );
  }

  Widget _headerResults({
    required String normalText,
    required bool normalPassed,
    required String? greatText,
    required bool greatPassed,
    required bool fillAvailableWidth,
  }) {
    final normal = _StatusCapsule(
      text: normalText,
      passed: normalPassed,
      scaleTextDown: fillAvailableWidth,
    );
    final greatStatus = greatText == null
        ? null
        : _StatusCapsule(
            text: greatText,
            passed: greatPassed,
            scaleTextDown: fillAvailableWidth,
          );
    return Row(
      key: const Key('expedition-header-results'),
      mainAxisSize: fillAvailableWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (fillAvailableWidth) Expanded(child: normal) else normal,
        if (greatStatus != null) ...[
          const SizedBox(width: 8),
          if (fillAvailableWidth)
            Expanded(flex: 2, child: greatStatus)
          else
            greatStatus,
        ],
      ],
    );
  }

  Widget _overview(
    ExpeditionStrings s,
    MasterMission? mission,
    ExpeditionIncome income,
    ExpeditionEvaluation ev,
  ) => _panel(
    s.timeAndCost,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow(
          s.requiredTime,
          mission == null ? '--' : _duration(mission.duration),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _infoRow(
                s.fuelCost,
                mission == null ? '--' : '${mission.fuelConsumptionPercent}%',
                icon: Image.asset(
                  'assets/images/material/01.png',
                  width: 17,
                  height: 17,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _infoRow(
                s.ammoCost,
                mission == null
                    ? '--'
                    : '${mission.ammunitionConsumptionPercent}%',
                icon: Image.asset(
                  'assets/images/material/02.png',
                  width: 17,
                  height: 17,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle(s.expectedIncome),
        const SizedBox(height: 6),
        _resourceGrid(income),
      ],
    ),
  );
  Widget _conditions(ExpeditionStrings s, ExpeditionEvaluation ev) => _panel(
    s.conditions,
    Column(
      children: [
        for (final c in [
          ...ev.normalConditions,
          if (great) ...ev.greatSuccessConditions,
          ev.daihatsuFill,
        ])
          _conditionRow(c, s),
      ],
    ),
  );
  Widget _panel(String title, Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xff142735),
      border: Border.all(color: const Color(0xff294052)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_sectionTitle(title), const SizedBox(height: 10), child],
    ),
  );
  Widget _infoRow(String label, String value, {Widget? icon}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xff0b1d29),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        if (icon != null) ...[icon, const SizedBox(width: 6)],
        Text(label, style: const TextStyle(color: Color(0xff8fa8b6))),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
  String _duration(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:00';

  String _displayId(int id) => switch (id) {
    >= 100 && <= 105 => 'A${id - 99}',
    >= 110 && <= 115 => 'B${id - 109}',
    >= 131 && <= 133 => 'D${id - 130}',
    >= 141 && <= 142 => 'E${id - 140}',
    _ => '$id',
  };

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xffd4a85f),
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  );

  Widget _resourceGrid(ExpeditionIncome income) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 6) / 2;

        Widget buildTile(Widget iconOrText, int value) => SizedBox(
          width: width,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff0b1d29),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                iconOrText,
                const Spacer(),
                Text(
                  '$value',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );

        Widget buildResource(int id, int value) {
          final assetId = id.toString().padLeft(2, '0');
          return buildTile(
            Image.asset(
              'assets/images/material/$assetId.png',
              width: 17,
              height: 17,
              filterQuality: FilterQuality.medium,
            ),
            value,
          );
        }

        Widget buildItem(ExpeditionRewardItem item) {
          String assetId;
          String? label;
          switch (item.id) {
            case 1:
              assetId = '06';
              break; // Bucket
            case 2:
              assetId = '05';
              break; // Flamethrower
            case 3:
              assetId = '07';
              break; // Dev mat
            case 4:
              assetId = '08';
              break; // Screw
            case 10:
              assetId = '10';
              label = '家具箱(小)';
              break;
            case 11:
              assetId = '11';
              label = '家具箱(中)';
              break;
            case 12:
              assetId = '12';
              label = '家具箱(大)';
              break;
            case 59:
              assetId = '59';
              label = '礼物箱';
              break;
            default:
              assetId = 'unknown';
              label = '道具 ${item.id}';
              break;
          }

          final iconOrText =
              ['05', '06', '07', '08', '10', '11', '12'].contains(assetId)
              ? Image.asset(
                  'assets/images/material/$assetId.png',
                  width: 17,
                  height: 17,
                  filterQuality: FilterQuality.medium,
                )
              : Text(
                  label ?? '道具',
                  style: const TextStyle(
                    color: Color(0xffa8bbc5),
                    fontSize: 12,
                  ),
                );

          String kindText = item.kind == ExpeditionRewardKind.greatSuccess
              ? '(大成功获得)'
              : '(有几率获得)';
          return buildTile(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconOrText,
                const SizedBox(width: 4),
                Text(
                  kindText,
                  style: const TextStyle(
                    color: Color(0xff7792a3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            item.count,
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            buildResource(1, income.values[0]),
            buildResource(2, income.values[1]),
            buildResource(3, income.values[2]),
            buildResource(4, income.values[3]),
            for (final item in income.items) buildItem(item),
          ],
        );
      },
    );
  }

  Widget _conditionRow(
    ExpeditionConditionResult condition,
    ExpeditionStrings s,
  ) {
    final color = condition.passed
        ? const Color(0xff28d978)
        : condition.auxiliary
        ? const Color(0xffffc247)
        : const Color(0xffff5964);
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: condition.auxiliary && !condition.passed
            ? const Color(0xff5a451b)
            : const Color(0xff0b1f2b),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Text(
            condition.passed
                ? '✓'
                : condition.auxiliary
                ? '!'
                : '×',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.conditionLabel(condition),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            s.conditionActual(condition),
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SegmentGroup extends StatelessWidget {
  const _SegmentGroup({required this.children, this.width = 260});
  final List<Widget> children;
  final double width;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: children.map((c) => Expanded(child: c)).toList()),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
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
      ),
    );
  }
}

class _TargetMenu extends StatelessWidget {
  const _TargetMenu({required this.target, required this.onSelected});
  final int target;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: target,
      onSelected: onSelected,
      color: const Color(0xff1b263b),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xff415a77)),
        borderRadius: BorderRadius.circular(9),
      ),
      itemBuilder: (context) => [
        for (final v in const [80, 85, 90, 95, 100])
          PopupMenuItem(
            value: v,
            height: 32,
            child: Text(
              '$v%',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xffdce6eb),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      child: Container(
        key: const Key('expedition-target-menu'),
        width: 82,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: const Color(0xff0b202d),
          border: Border.all(color: const Color(0xff315064)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$target%',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xffdce6eb),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Color(0xffdce6eb),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCapsule extends StatelessWidget {
  const _StatusCapsule({
    required this.text,
    required this.passed,
    this.scaleTextDown = false,
  });

  final String text;
  final bool passed;
  final bool scaleTextDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: passed ? const Color(0xff182c25) : const Color(0xff2d1720),
        border: Border.all(
          color: passed ? const Color(0xff294d35) : const Color(0xff4c202d),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: FittedBox(
        fit: scaleTextDown ? BoxFit.scaleDown : BoxFit.none,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 13,
            color: passed ? const Color(0xff67b579) : const Color(0xffc5525c),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
