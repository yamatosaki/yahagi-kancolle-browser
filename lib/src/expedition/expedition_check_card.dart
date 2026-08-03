import 'package:flutter/material.dart';

import '../fleet/status_density.dart';
import '../fleet/dashboard_card.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'expedition_evaluator.dart';
import 'expedition_income_calculator.dart';
import 'expedition_rule_catalog.dart';
import 'expedition_strings.dart';

class ExpeditionCheckCard extends StatefulWidget {
  const ExpeditionCheckCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenDetails,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenDetails;

  @override
  State<ExpeditionCheckCard> createState() => _ExpeditionCheckCardState();
}

class _ExpeditionCheckCardState extends State<ExpeditionCheckCard> {
  bool _detailed = false;
  bool _greatSuccess = false;
  int _target = 100;
  int _fleetId = 2;
  int _missionId = 14;

  @override
  Widget build(BuildContext context) {
    final strings = ExpeditionStrings.of(context);
    final phone = isPhoneDensity(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => DashboardCard(
        title: strings.title,
        icon: const Icon(Icons.fact_check_outlined),
        collapsed: widget.collapsed,
        onToggleCollapse: widget.onToggleCollapse,
        borderColor: const Color(0xffb98a28),
        collapseButtonKey: const Key('expedition-check-collapse'),
        trailing: phone ? _detailsPageButton(strings) : null,
        child: _buildContent(context, widget.controller.state, strings),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    GameState state,
    ExpeditionStrings strings,
  ) {
    if (!state.hasPortData || state.fleets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _controls(strings),
          const SizedBox(height: 10),
          _statusBox(strings.waiting, false, neutral: true),
        ],
      );
    }
    final fleets = state.fleets
        .where((fleet) => fleet.shipIds.isNotEmpty)
        .toList();
    if (fleets.isEmpty) {
      return _statusBox(strings.waiting, false, neutral: true);
    }
    final fleet = fleets.cast<Fleet?>().firstWhere(
      (item) => item!.id == _fleetId,
      orElse: () => fleets.first,
    )!;
    final missionId = expeditionRules.containsKey(_missionId)
        ? _missionId
        : expeditionRules.keys.first;
    final evaluation = const ExpeditionEvaluator().evaluate(
      state: state,
      fleet: fleet,
      missionId: missionId,
      greatSuccessTarget: _target,
    );
    final income = ExpeditionIncomeCalculator.forMission(
      mission: state.masterMissions[missionId],
      greatSuccess: _greatSuccess,
      daihatsuBonus: ExpeditionIncomeCalculator.daihatsuBonusForFleet(
        state,
        fleet,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _controls(strings),
        const SizedBox(height: 8),
        _fleetSelector(fleets),
        const SizedBox(height: 7),
        _missionSelector(state, missionId, strings),
        const SizedBox(height: 8),
        if (_greatSuccess)
          Row(
            children: [
              Expanded(
                child: _statusBox(
                  '${strings.normalCheck}：${evaluation.normalPassed ? strings.passed : strings.failed}',
                  evaluation.normalPassed,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statusBox(
                  '${strings.greatSuccess}：${evaluation.greatSuccessPassed ? strings.passed : strings.failed} (${evaluation.greatSuccessRate.toStringAsFixed(2)}%)',
                  evaluation.greatSuccessPassed,
                ),
              ),
            ],
          )
        else
          _statusBox(
            '${strings.normalCheck}：${evaluation.normalPassed ? strings.passed : strings.failed}',
            evaluation.normalPassed,
          ),
        if (_detailed) ...[
          const SizedBox(height: 10),
          _sectionTitle(strings.expectedIncome),
          const SizedBox(height: 5),
          _resourceGrid(income),
          const SizedBox(height: 10),
          _sectionTitle(strings.conditions),
          const SizedBox(height: 5),
          for (final condition in [
            ...evaluation.normalConditions,
            if (_greatSuccess) ...evaluation.greatSuccessConditions,
            evaluation.daihatsuFill,
          ])
            _conditionRow(condition, strings),
        ],
      ],
    );
  }

  Widget _controls(ExpeditionStrings strings) => LayoutBuilder(
    builder: (context, constraints) {
      final showDetailsInControls = !isPhoneDensity(context);
      final controlGroups = <Widget>[
        _segmentGroup(
          key: const Key('expedition-mode-segments'),
          children: [
            _segmentButton(
              label: strings.compact,
              selected: !_detailed,
              onTap: () => setState(() => _detailed = false),
            ),
            _segmentButton(
              label: strings.detailed,
              selected: _detailed,
              onTap: () => setState(() => _detailed = true),
            ),
          ],
        ),
        _segmentGroup(
          key: const Key('expedition-success-segments'),
          children: [
            _segmentButton(
              label: strings.success,
              selected: !_greatSuccess,
              onTap: () => setState(() => _greatSuccess = false),
            ),
            _segmentButton(
              label: strings.greatSuccess,
              selected: _greatSuccess,
              onTap: () => setState(() => _greatSuccess = true),
            ),
          ],
        ),
        if (_greatSuccess) _targetMenu(),
      ];
      final detailsButton = showDetailsInControls
          ? _detailsPageButton(strings)
          : null;
      if (constraints.maxWidth >= 440) {
        return Row(
          children: [
            for (var index = 0; index < controlGroups.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              controlGroups[index],
            ],
            const Spacer(),
            ?detailsButton,
          ],
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [...controlGroups, ?detailsButton],
      );
    },
  );

  Widget _detailsPageButton(ExpeditionStrings strings) => _segmentGroup(
    key: const Key('expedition-details-segment'),
    children: [
      _segmentButton(
        label: strings.detailsPage,
        selected: false,
        command: true,
        onTap: widget.onOpenDetails,
      ),
    ],
  );

  Widget _segmentGroup({
    Key? key,
    required List<Widget> children,
    bool expandChildren = false,
  }) => Container(
    key: key,
    height: 26,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: const Color(0xff10212e),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xff294052)),
    ),
    child: Row(
      mainAxisSize: expandChildren ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final child in children)
          if (expandChildren) Expanded(child: child) else child,
      ],
    ),
  );

  Widget _segmentButton({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool command = false,
  }) => Material(
    key: key,
    color: selected ? const Color(0xff5b4829) : Colors.transparent,
    borderRadius: BorderRadius.circular(5),
    child: InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: selected
                    ? const Color(0xffffcf67)
                    : command
                    ? const Color(0xffd4a85f)
                    : const Color(0xff8197a5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _targetMenu() => PopupMenuButton<int>(
    initialValue: _target,
    onSelected: (value) => setState(() => _target = value),
    color: const Color(0xff1b263b),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xff415a77)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: _segmentGroup(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_target%',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xffdce6eb),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: Color(0xffdce6eb),
              ),
            ],
          ),
        ),
      ],
    ),
    itemBuilder: (context) => [
      for (final value in const [80, 85, 90, 95, 100])
        PopupMenuItem(
          value: value,
          height: 32,
          child: Text(
            '$value%',
            style: const TextStyle(fontSize: 13, color: Color(0xffdce6eb)),
          ),
        ),
    ],
  );

  Widget _fleetSelector(List<Fleet> fleets) => _segmentGroup(
    key: const Key('expedition-fleet-segments'),
    expandChildren: true,
    children: [
      for (final fleet in fleets.take(4))
        _segmentButton(
          key: Key('expedition-fleet-${fleet.id}'),
          label: fleet.name,
          selected: _fleetId == fleet.id,
          onTap: () => setState(() => _fleetId = fleet.id),
        ),
    ],
  );

  Widget _missionSelector(
    GameState state,
    int current,
    ExpeditionStrings strings,
  ) => DropdownButtonFormField<int>(
    initialValue: current,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: strings.selectExpedition,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final id in expeditionRules.keys)
        DropdownMenuItem(
          value: id,
          child: Text(
            '${_displayId(id)} · ${state.masterMissions[id]?.name ?? '远征'}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (value) {
      if (value != null) setState(() => _missionId = value);
    },
  );

  Widget _statusBox(String text, bool passed, {bool neutral = false}) {
    final color = neutral
        ? const Color(0xff244457)
        : passed
        ? const Color(0xff258a52)
        : const Color(0xffc43f4b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '${neutral
            ? '•'
            : passed
            ? '☑'
            : '☒'} $text',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

Widget _sectionTitle(String text) => Text(
  text,
  style: const TextStyle(
    color: Color(0xffd4a85f),
    fontSize: 13,
    fontWeight: FontWeight.w800,
  ),
);

Widget _resourceGrid(ExpeditionIncome income) {
  final values = income.values;
  return Column(
    children: [
      _resourceRow(1, values[0], 2, values[1]),
      const SizedBox(height: 6),
      _resourceRow(3, values[2], 4, values[3]),
      if (income.items.isNotEmpty) ...[
        const SizedBox(height: 6),
        _itemsRow(income.items),
      ],
    ],
  );
}

Widget _resourceRow(int id1, int val1, int id2, int val2) => Row(
  children: [
    Expanded(child: _resourceTile(id1, val1)),
    const SizedBox(width: 6),
    Expanded(child: _resourceTile(id2, val2)),
  ],
);

Widget _itemsRow(List<ExpeditionRewardItem> items) {
  if (items.length == 1) {
    return Row(
      children: [
        Expanded(child: _itemTile(items[0])),
        const SizedBox(width: 6),
        const Expanded(child: SizedBox()),
      ],
    );
  }
  return Row(
    children: [
      Expanded(child: _itemTile(items[0])),
      const SizedBox(width: 6),
      Expanded(child: _itemTile(items[1])),
    ],
  );
}

Widget _resourceTile(int apiId, int value) {
  final assetId = apiId.toString().padLeft(2, '0');
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xff0b1d29),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        Image.asset(
          'assets/images/material/$assetId.png',
          width: 17,
          height: 17,
          filterQuality: FilterQuality.medium,
        ),
        const Spacer(),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

Widget _itemTile(ExpeditionRewardItem item) {
  // Map useitem ID to material asset ID for common items
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

  String kindText = item.kind == ExpeditionRewardKind.greatSuccess
      ? '(大成功获得)'
      : '(有几率获得)';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xff0b1d29),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        if (['05', '06', '07', '08', '10', '11', '12'].contains(assetId))
          Image.asset(
            'assets/images/material/$assetId.png',
            width: 17,
            height: 17,
            filterQuality: FilterQuality.medium,
          )
        else
          Text(
            label ?? '道具',
            style: const TextStyle(color: Color(0xffa8bbc5), fontSize: 12),
          ),
        const SizedBox(width: 4),
        Text(
          kindText,
          style: const TextStyle(color: Color(0xff7792a3), fontSize: 11),
        ),
        const Spacer(),
        Text(
          '${item.count}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

Widget _conditionRow(
  ExpeditionConditionResult condition,
  ExpeditionStrings strings,
) {
  final color = condition.passed
      ? const Color(0xff28d978)
      : condition.auxiliary
      ? const Color(0xffffc247)
      : const Color(0xffff5964);
  return Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
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
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            strings.conditionLabel(condition),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          strings.conditionActual(condition),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _displayId(int id) => switch (id) {
  >= 100 && <= 105 => 'A${id - 99}',
  >= 110 && <= 115 => 'B${id - 109}',
  >= 131 && <= 133 => 'D${id - 130}',
  >= 141 && <= 142 => 'E${id - 140}',
  _ => '$id',
};
