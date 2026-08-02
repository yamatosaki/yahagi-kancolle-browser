import 'package:flutter/material.dart';

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
  });
  final GameStateController controller;
  final VoidCallback onBack;
  @override
  State<ExpeditionCheckPage> createState() => _ExpeditionCheckPageState();
}

class _ExpeditionCheckPageState extends State<ExpeditionCheckPage> {
  int fleetId = 2, missionId = 14, target = 100;
  bool great = false;
  @override
  Widget build(BuildContext context) {
    final s = ExpeditionStrings.of(context);
    return Material(
      color: const Color(0xff081521),
      child: Column(
        children: [
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
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in fleets)
                  ChoiceChip(
                    label: Text(f.name),
                    selected: fleetId == f.id,
                    onSelected: (_) => setState(() => fleetId = f.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: missionId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: s.selectExpedition,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final id in expeditionRules.keys)
                  DropdownMenuItem(
                    value: id,
                    child: Text(
                      '${_displayId(id)} · ${state.masterMissions[id]?.name ?? '远征'}',
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => missionId = v);
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(s.success),
                  selected: !great,
                  onSelected: (_) => setState(() => great = false),
                ),
                ChoiceChip(
                  label: Text(s.greatSuccess),
                  selected: great,
                  onSelected: (_) => setState(() => great = true),
                ),
                if (great)
                  for (final v in const [80, 85, 90, 95, 100])
                    ChoiceChip(
                      label: Text('$v%'),
                      selected: target == v,
                      onSelected: (_) => setState(() => target = v),
                    ),
              ],
            ),
            const SizedBox(height: 16),
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
                icon: Image.asset('assets/images/material/01.png', width: 17, height: 17, filterQuality: FilterQuality.medium),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _infoRow(
                s.ammoCost,
                mission == null
                    ? '--'
                    : '${mission.ammunitionConsumptionPercent}%',
                icon: Image.asset('assets/images/material/02.png', width: 17, height: 17, filterQuality: FilterQuality.medium),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle(s.expectedIncome),
        const SizedBox(height: 6),
        _resourceGrid(income),
        const SizedBox(height: 10),
        Text(
          '${s.normalCheck}：${ev.normalPassed ? s.passed : s.failed}',
          style: TextStyle(
            color: ev.normalPassed
                ? const Color(0xff28d978)
                : const Color(0xffff5964),
            fontWeight: FontWeight.w800,
          ),
        ),
        if (great)
          Text(
            '${s.greatSuccess}：${ev.greatSuccessPassed ? s.passed : s.failed} (${ev.greatSuccessRate.toStringAsFixed(2)}%)',
            style: TextStyle(
              color: ev.greatSuccessPassed
                  ? const Color(0xff28d978)
                  : const Color(0xffff5964),
              fontWeight: FontWeight.w800,
            ),
          ),
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
        if (icon != null) ...[
          icon,
          const SizedBox(width: 6),
        ],
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
            case 1: assetId = '06'; break; // Bucket
            case 2: assetId = '05'; break; // Flamethrower
            case 3: assetId = '07'; break; // Dev mat
            case 4: assetId = '08'; break; // Screw
            case 10: assetId = '10'; label = '家具箱(小)'; break;
            case 11: assetId = '11'; label = '家具箱(中)'; break;
            case 12: assetId = '12'; label = '家具箱(大)'; break;
            case 59: assetId = '59'; label = '礼物箱'; break;
            default: assetId = 'unknown'; label = '道具 ${item.id}'; break;
          }

          final iconOrText = ['05', '06', '07', '08', '10', '11', '12'].contains(assetId)
              ? Image.asset(
                  'assets/images/material/$assetId.png',
                  width: 17,
                  height: 17,
                  filterQuality: FilterQuality.medium,
                )
              : Text(label ?? '道具', style: const TextStyle(color: Color(0xffa8bbc5), fontSize: 12));

          String kindText = item.kind == ExpeditionRewardKind.greatSuccess ? '(大成功获得)' : '(有几率获得)';
          return buildTile(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconOrText,
                const SizedBox(width: 4),
                Text(kindText, style: const TextStyle(color: Color(0xff7792a3), fontSize: 11)),
              ]
            ),
            item.count
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
            for (final item in income.items)
              buildItem(item),
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
          Flexible(
            child: Text(
              s.conditionActual(condition),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
