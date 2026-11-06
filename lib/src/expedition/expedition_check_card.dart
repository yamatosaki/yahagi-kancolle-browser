import '../widgets/app_popup_menu_button.dart';
import '../widgets/app_segmented_style.dart';
import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../account/account_session.dart';

import '../layout/flat_style.dart';
import '../layout/flat_text_toggle.dart';
import '../layout/flat_underline_tabs.dart';
import '../localization/ui_text.dart';
import '../localization/game_name_localizations.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'expedition_evaluator.dart';
import 'expedition_income_calculator.dart';
import 'expedition_mission_picker.dart';
import 'expedition_rule_catalog.dart';
import 'expedition_selection_store.dart';
import 'expedition_strings.dart';
import '../layout/flat_list_row.dart';
import '../layout/panel_style.dart';

class ExpeditionCheckContent extends StatefulWidget {
  const ExpeditionCheckContent({
    super.key,
    required this.controller,
    required this.onOpenDetails,
    this.selectionStore,
    this.accountSession,
  });

  final GameStateController controller;
  final ValueChanged<int> onOpenDetails;
  final ExpeditionSelectionStore? selectionStore;
  final AccountSession? accountSession;

  @override
  State<ExpeditionCheckContent> createState() => _ExpeditionCheckContentState();
}

class _ExpeditionCheckContentState extends State<ExpeditionCheckContent> {
  bool _detailed = false;
  bool _greatSuccess = false;
  int _target = 100;
  int _fleetId = 2;
  int _missionId = 1;
  int _restoreGeneration = 0;
  late final AccountSession _accountSession;
  late final ExpeditionSelectionStore _selectionStore;

  @override
  void initState() {
    super.initState();
    _accountSession = widget.accountSession ?? AccountSession.shared;
    _selectionStore =
        widget.selectionStore ??
        SharedPreferencesExpeditionSelectionStore(
          accountSession: _accountSession,
        );
    _accountSession.addListener(_onAccountChanged);
    _restoreMissionForFleet(_fleetId);
  }

  Future<void> _restoreMissionForFleet(int fleetId) async {
    final generation = ++_restoreGeneration;
    final scope = _accountSession.current;
    if (!scope.isKnown) return;
    final savedMissionId = await _selectionStore.loadMissionId(fleetId);
    if (!mounted ||
        _fleetId != fleetId ||
        generation != _restoreGeneration ||
        !_accountSession.isCurrent(scope)) {
      return;
    }
    final restoredMissionId =
        savedMissionId != null && expeditionRules.containsKey(savedMissionId)
        ? savedMissionId
        : expeditionRules.keys.first;
    if (_missionId == restoredMissionId) return;
    setState(() => _missionId = restoredMissionId);
  }

  void _selectFleet(int fleetId) {
    setState(() {
      _fleetId = fleetId;
      _missionId = expeditionRules.keys.first;
    });
    _restoreMissionForFleet(fleetId);
  }

  void _selectMission(int missionId) {
    _restoreGeneration++;
    setState(() => _missionId = missionId);
    if (_accountSession.current.isKnown) {
      _selectionStore.saveMissionId(_fleetId, missionId);
    }
  }

  void _onAccountChanged() {
    setState(() {
      _fleetId = 2;
      _missionId = expeditionRules.keys.first;
    });
    _restoreMissionForFleet(_fleetId);
  }

  @override
  void dispose() {
    _accountSession.removeListener(_onAccountChanged);
    super.dispose();
  }

  bool get _flat => PanelStyleScope.isFlat(context);

  @override
  Widget build(BuildContext context) {
    final strings = ExpeditionStrings.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) =>
          _buildContent(context, widget.controller.state, strings),
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
          SizedBox(height: _flat ? flatSectionGap : 10),
          _statusBox(
            strings.waiting,
            false,
            neutral: true,
            onTap: () => widget.onOpenDetails(_fleetId),
          ),
        ],
      );
    }
    final fleets = state.fleets
        .where((fleet) => fleet.shipIds.isNotEmpty)
        .toList();
    if (fleets.isEmpty) {
      return _statusBox(
        strings.waiting,
        false,
        neutral: true,
        onTap: () => widget.onOpenDetails(_fleetId),
      );
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
    final flat = _flat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _controls(strings),
        SizedBox(height: flat ? flatSectionGap : 8),
        _fleetSelector(fleets),
        SizedBox(height: flat ? flatRowSpacing : 7),
        _missionSelector(state, missionId),
        SizedBox(height: flat ? flatSectionGap : 8),
        if (_greatSuccess && flat) ...[
          _statusBox(
            '${strings.normalCheck}：${evaluation.normalPassed ? strings.passed : strings.failed}',
            evaluation.normalPassed,
            onTap: () => widget.onOpenDetails(_fleetId),
          ),
          _statusBox(
            evaluation.greatSuccessPassed
                ? '${strings.greatSuccess}：${strings.passed} (${evaluation.greatSuccessRate.toStringAsFixed(2)}%)'
                : '${strings.greatSuccess}：${strings.failed}',
            evaluation.greatSuccessPassed,
            onTap: () => widget.onOpenDetails(_fleetId),
          ),
        ] else if (_greatSuccess)
          Row(
            children: [
              Expanded(
                child: _statusBox(
                  '${strings.normalCheck}：${evaluation.normalPassed ? strings.passed : strings.failed}',
                  evaluation.normalPassed,
                  onTap: () => widget.onOpenDetails(_fleetId),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statusBox(
                  evaluation.greatSuccessPassed
                      ? '${strings.greatSuccess}：${strings.passed} (${evaluation.greatSuccessRate.toStringAsFixed(2)}%)'
                      : '${strings.greatSuccess}：${strings.failed}',
                  evaluation.greatSuccessPassed,
                  onTap: () => widget.onOpenDetails(_fleetId),
                ),
              ),
            ],
          )
        else
          _statusBox(
            '${strings.normalCheck}：${evaluation.normalPassed ? strings.passed : strings.failed}',
            evaluation.normalPassed,
            onTap: () => widget.onOpenDetails(_fleetId),
          ),
        if (_detailed) ...[
          SizedBox(height: flat ? 6 : 10),
          _sectionTitle(context, strings.expectedIncome, flat),
          SizedBox(height: flat ? flatRowSpacing : 5),
          _resourceGrid(context, income, flat),
          SizedBox(height: flat ? 6 : 10),
          _sectionTitle(context, strings.conditions, flat),
          SizedBox(height: flat ? flatRowSpacing : 5),
          for (final condition in [
            ...evaluation.normalConditions,
            if (_greatSuccess) ...evaluation.greatSuccessConditions,
            evaluation.daihatsuFill,
          ])
            _conditionRow(context, condition, strings, flat),
        ],
      ],
    );
  }

  Widget _controls(ExpeditionStrings strings) => LayoutBuilder(
    builder: (context, constraints) {
      final controlGroups = <Widget>[
        _segments(
          key: const Key('expedition-mode-segments'),
          options: [
            FlatTextToggleOption(
              key: const Key('expedition-mode-compact'),
              label: strings.compact,
              selected: !_detailed,
              onTap: () => setState(() => _detailed = false),
            ),
            FlatTextToggleOption(
              key: const Key('expedition-mode-detailed'),
              label: strings.detailed,
              selected: _detailed,
              onTap: () => setState(() => _detailed = true),
            ),
          ],
        ),
        _segments(
          key: const Key('expedition-success-segments'),
          options: [
            FlatTextToggleOption(
              key: const Key('expedition-success-normal'),
              label: strings.success,
              selected: !_greatSuccess,
              onTap: () => setState(() => _greatSuccess = false),
            ),
            FlatTextToggleOption(
              key: const Key('expedition-success-great'),
              label: strings.greatSuccess,
              selected: _greatSuccess,
              onTap: () => setState(() => _greatSuccess = true),
            ),
          ],
        ),
        if (_greatSuccess) _targetMenu(),
      ];
      if (constraints.maxWidth >= 440 && !_flat) {
        return Row(
          children: [
            for (var index = 0; index < controlGroups.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              controlGroups[index],
            ],
            const Spacer(),
          ],
        );
      }
      return Wrap(
        spacing: _flat ? 10 : 8,
        runSpacing: _flat ? 2 : 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [...controlGroups],
      );
    },
  );

  Widget _segments({
    Key? key,
    required List<FlatTextToggleOption> options,
    bool expandChildren = false,
  }) {
    if (_flat) {
      return expandChildren
          ? FlatUnderlineTabs(key: key, options: options)
          : FlatTextToggle(key: key, options: options);
    }
    return _cardSegmentGroup(
      key: key,
      expandChildren: expandChildren,
      children: [
        for (final option in options)
          _cardSegmentButton(
            key: option.key,
            label: option.label,
            selected: option.selected,
            onTap: option.onTap,
          ),
      ],
    );
  }

  Widget _cardSegmentGroup({
    Key? key,
    required List<Widget> children,
    required bool expandChildren,
  }) => Container(
    key: key,
    height: AppSegmentedStyle.compactHeight,
    padding: AppSegmentedStyle.padding(compact: true),
    decoration: AppSegmentedStyle.decoration(context, compact: true),
    child: Row(
      mainAxisSize: expandChildren ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final child in children)
          if (expandChildren) Expanded(child: child) else child,
      ],
    ),
  );

  Widget _cardSegmentButton({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool command = false,
  }) => Material(
    key: key,
    color: AppSegmentedStyle.selection(context, selected),
    borderRadius: AppSegmentedStyle.itemRadius(compact: true),
    child: InkWell(
      borderRadius: AppSegmentedStyle.itemRadius(compact: true),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style:
                      AppSegmentedStyle.textStyle(
                        context,
                        selected: selected,
                        compact: true,
                      ).copyWith(
                        color: command && !selected
                            ? appColor(context, const Color(0xffd4a85f))
                            : null,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _targetMenu() => AppPopupMenuButton<int>(
    initialValue: _target,
    onSelected: (value) => setState(() => _target = value),
    color: appColor(context, const Color(0xff1b263b)),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: appColor(context, Color(0xff415a77))),
      borderRadius: BorderRadius.circular(4),
    ),
    child: _targetMenuFrame(
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _flat ? 0 : 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_target%',
              style: TextStyle(
                fontSize: _flat ? flatSmallFontSize : 10,
                color: appColor(
                  context,
                  _flat ? flatAccentColor : const Color(0xffdce6eb),
                ),
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: appColor(
                context,
                _flat ? flatAccentColor : const Color(0xffdce6eb),
              ),
            ),
          ],
        ),
      ),
    ),
    itemBuilder: (context) => [
      for (final value in const [80, 85, 90, 95, 100])
        PopupMenuItem(
          value: value,
          height: 32,
          child: Text(
            '$value%',
            style: appTextStyle(
              context,
              TextStyle(
                fontSize: 13,
                color: appColor(context, Color(0xffdce6eb)),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _targetMenuFrame(Widget child) => _flat
      ? child
      : _cardSegmentGroup(children: [child], expandChildren: false);

  Widget _fleetSelector(List<Fleet> fleets) => _segments(
    key: const Key('expedition-fleet-segments'),
    expandChildren: true,
    options: [
      for (final fleet in fleets.take(4))
        FlatTextToggleOption(
          key: Key('expedition-fleet-${fleet.id}'),
          label: fleet.name,
          selected: _fleetId == fleet.id,
          onTap: () => _selectFleet(fleet.id),
        ),
    ],
  );

  Widget _missionSelector(GameState state, int current) =>
      ExpeditionMissionPicker(
        missions: state.masterMissions,
        missionIds: expeditionRules.keys,
        selectedMissionId: current,
        selectedTextKey: const Key('expedition-mission-name'),
        compact: true,
        onSelected: _selectMission,
      );

  Widget _statusBox(
    String text,
    bool passed, {
    bool neutral = false,
    VoidCallback? onTap,
  }) {
    if (_flat) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            text,
            key: const Key('expedition-status-text'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: flatRowTextStyle(
              context,
              color: neutral
                  ? flatMutedColor
                  : passed
                  ? flatDoneColor
                  : _flatFailColor,
            ),
          ),
        ),
      );
    }
    final color = neutral
        ? const Color(0xff244457)
        : passed
        ? const Color(0xff258a52)
        : const Color(0xffc43f4b);
    return LayoutBuilder(
      builder: (context, constraints) => Material(
        color: appColor(context, color),
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              text,
              key: const Key('expedition-status-text'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: appTextStyle(
                context,
                TextStyle(
                  fontSize: _expeditionSummaryTextSize(constraints.maxWidth),
                  fontWeight: FontWeight.w700,
                  color: neutral
                      ? appColor(context, Colors.white)
                      : appOnAccentColor(context, Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _expeditionSummaryTextSize(double availableWidth) =>
    availableWidth < 340 ? 11 : 12;

// 复用条件行里的未通过红，扁平档不新增配色。
const _flatFailColor = Color(0xffff5964);

Widget _sectionTitle(BuildContext context, String text, bool flat) => Text(
  text,
  style: TextStyle(
    color: appColor(context, const Color(0xffd4a85f)),
    fontSize: flat ? 11 : 13,
    fontWeight: flat ? FontWeight.w700 : FontWeight.w800,
  ),
);

Widget _resourceGrid(BuildContext context, ExpeditionIncome income, bool flat) {
  final values = income.values;
  final gap = flat ? 2.0 : 6.0;
  return Column(
    children: [
      _resourceRow(context, 1, values[0], 2, values[1], flat),
      SizedBox(height: gap),
      _resourceRow(context, 3, values[2], 4, values[3], flat),
      if (income.items.isNotEmpty) ...[
        SizedBox(height: gap),
        _itemsRow(context, income.items, flat),
      ],
    ],
  );
}

Widget _resourceRow(
  BuildContext context,
  int id1,
  int val1,
  int id2,
  int val2,
  bool flat,
) => Row(
  children: [
    Expanded(child: _resourceTile(context, id1, val1, flat)),
    SizedBox(width: flat ? 8 : 6),
    Expanded(child: _resourceTile(context, id2, val2, flat)),
  ],
);

Widget _itemsRow(
  BuildContext context,
  List<ExpeditionRewardItem> items,
  bool flat,
) {
  final gap = SizedBox(width: flat ? 8 : 6);
  if (items.length == 1) {
    return Row(
      children: [
        Expanded(child: _itemTile(context, items[0], flat)),
        gap,
        const Expanded(child: SizedBox()),
      ],
    );
  }
  return Row(
    children: [
      Expanded(child: _itemTile(context, items[0], flat)),
      gap,
      Expanded(child: _itemTile(context, items[1], flat)),
    ],
  );
}

Widget _resourceTile(BuildContext context, int apiId, int value, bool flat) {
  final assetId = apiId.toString().padLeft(2, '0');
  if (flat) {
    return Row(
      children: [
        Image.asset(
          'assets/images/material/$assetId.png',
          width: 13,
          height: 13,
          filterQuality: FilterQuality.medium,
        ),
        const Spacer(),
        Text('$value', style: flatRowTextStyle(context)),
      ],
    );
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: appColor(context, Color(0xff0b1d29)),
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

Widget _itemTile(BuildContext context, ExpeditionRewardItem item, bool flat) {
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
  if (flat) {
    return Row(
      children: [
        if (['05', '06', '07', '08', '10', '11', '12'].contains(assetId))
          Image.asset(
            'assets/images/material/$assetId.png',
            width: 13,
            height: 13,
            filterQuality: FilterQuality.medium,
          )
        else
          Flexible(
            child: UiText(
              label ?? '道具',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: appColor(context, flatMutedColor),
                fontSize: flatRowFontSize,
              ),
            ),
          ),
        const SizedBox(width: 4),
        Flexible(
          child: UiText(
            kindText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: appColor(context, flatMutedColor),
              fontSize: flatRowFontSize,
            ),
          ),
        ),
        const Spacer(),
        Text('${item.count}', style: flatRowTextStyle(context)),
      ],
    );
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: appColor(context, Color(0xff0b1d29)),
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
          UiText(
            label ?? '道具',
            style: TextStyle(
              color: appColor(context, Color(0xffa8bbc5)),
              fontSize: 12,
            ),
          ),
        const SizedBox(width: 4),
        UiText(
          kindText,
          style: TextStyle(
            color: appColor(context, Color(0xff7792a3)),
            fontSize: 11,
          ),
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
  BuildContext context,
  ExpeditionConditionResult condition,
  ExpeditionStrings strings,
  bool flat,
) {
  final color = condition.passed
      ? const Color(0xff28d978)
      : condition.auxiliary
      ? const Color(0xffffc247)
      : const Color(0xffff5964);
  if (flat) {
    return FlatListRow(
      tags: [
        Text(
          condition.passed
              ? '✓'
              : condition.auxiliary
              ? '!'
              : '×',
          style: flatRowTextStyle(context, color: color),
        ),
      ],
      name: Text(
        gameNames(context).entityText(strings.conditionLabel(condition)),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: flatRowTextStyle(context),
      ),
      trailing: flatRowTrailing(
        Text(
          strings.conditionActual(condition),
          maxLines: 1,
          style: flatRowTextStyle(context, color: color),
        ),
      ),
    );
  }
  return Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: appColor(
        context,
        condition.auxiliary && !condition.passed
            ? const Color(0xff5a451b)
            : const Color(0xff0b1f2b),
      ),
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
          style: appTextStyle(
            context,
            TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            gameNames(context).entityText(strings.conditionLabel(condition)),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          strings.conditionActual(condition),
          style: appTextStyle(
            context,
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
