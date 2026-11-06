import '../theme/app_palette.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/ui_text.dart';
import '../localization/game_name_localizations.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/equipment_type_icon.dart';
import '../game_state/game_state.dart';
import '../inventory/owned_inventory_projection.dart';
import '../widgets/app_segmented_style.dart';
import '../widgets/filter_controls.dart';
import '../widgets/adaptive_input_dialog.dart';
import '../widgets/frozen_data_table.dart';
import 'improvement_dataset.dart';
import 'improvement_planner_controller.dart';
import 'improvement_projection.dart';

double _englishTextLayoutScale(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'en'
    ? math.max(1.0, MediaQuery.textScalerOf(context).scale(11) / 11)
    : 1.0;

class ImprovementPlannerView extends StatelessWidget {
  const ImprovementPlannerView({
    super.key,
    required this.controller,
    required this.state,
  });

  final ImprovementPlannerController controller;
  final GameState state;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: appColor(context, const Color(0xff081923)),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rows = controller.rowsFor(
          state,
          equipmentNameResolver: gameNames(context).equipmentName,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WeekdayFilter(controller: controller),
              const SizedBox(height: 6),
              Expanded(
                child: rows.isEmpty
                    ? const _EmptyState()
                    : _ImprovementTable(
                        rows: rows,
                        controller: controller,
                        state: state,
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _WeekdayFilter extends StatelessWidget {
  const _WeekdayFilter({required this.controller});
  final ImprovementPlannerController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34 * _englishTextLayoutScale(context),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SlidingSegment<int>(
            key: const Key('improvement-weekday-segmented'),
            sliderKey: const Key('improvement-weekday-slider'),
            selected: controller.selectedWeekday,
            segmentWidth: 52 * _englishTextLayoutScale(context),
            options: <_SegmentOption<int>>[
              const _SegmentOption<int>(
                value: improvementAllWeekdays,
                label: '全部',
                key: Key('improvement-weekday-all'),
              ),
              for (var day = 1; day <= 7; day++)
                _SegmentOption<int>(
                  value: day,
                  label: const <String>[
                    '周一',
                    '周二',
                    '周三',
                    '周四',
                    '周五',
                    '周六',
                    '周日',
                  ][day - 1],
                  key: Key('improvement-weekday-$day'),
                ),
            ],
            onChanged: controller.selectWeekday,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            height: 30,
            child: Material(
              color: controller.favoritesOnly
                  ? AppSegmentedStyle.selectedBackground(context)
                  : appColor(context, const Color(0xff102936)),
              shape: CircleBorder(
                side: BorderSide(
                  color: controller.favoritesOnly
                      ? AppSegmentedStyle.selectedBorder(context)
                      : appColor(context, const Color(0xff315064)),
                ),
              ),
              child: InkWell(
                key: const Key('improvement-favorites-only'),
                customBorder: const CircleBorder(),
                onTap: controller.toggleFavoritesOnly,
                child: Icon(
                  controller.favoritesOnly ? Icons.star : Icons.star_border,
                  size: 18,
                  color: appColor(context, Color(0xffffc85a)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          HeaderFilterIconButton(
            key: const Key('improvement-search-button'),
            icon: Icons.search,
            active: controller.hasSearch,
            tooltip: uiText(context, '搜索装备'),
            onPressed: () => _showImprovementSearch(context, controller),
          ),
          const SizedBox(width: 4),
          HeaderFilterIconButton(
            key: const Key('improvement-filter-button'),
            icon: Icons.filter_alt_outlined,
            active: controller.hasFilters,
            tooltip: uiText(context, '筛选装备'),
            onPressed: () => _showImprovementFilters(context, controller),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showImprovementSearch(
  BuildContext context,
  ImprovementPlannerController controller,
) => showDialog<void>(
  barrierDismissible: false,
  context: context,
  builder: (_) => _ImprovementSearchDialog(controller: controller),
);

class _ImprovementSearchDialog extends StatefulWidget {
  const _ImprovementSearchDialog({required this.controller});

  final ImprovementPlannerController controller;

  @override
  State<_ImprovementSearchDialog> createState() =>
      _ImprovementSearchDialogState();
}

class _ImprovementSearchDialogState extends State<_ImprovementSearchDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.query);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveInputDialog(
    title: const UiText('搜索装备'),
    content: TextField(
      key: const Key('improvement-search-field'),
      controller: _textController,
      autofocus: true,
      onChanged: widget.controller.setQuery,
      decoration: InputDecoration(
        hintText: uiText(context, '搜索装备名称'),
        prefixIcon: Icon(Icons.search),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('improvement-search-clear'),
        onPressed: () {
          _textController.clear();
          widget.controller.setQuery('');
        },
        child: const UiText('清除'),
      ),
      FilledButton(
        key: const Key('improvement-search-close'),
        onPressed: () => Navigator.pop(context),
        child: const UiText('完成'),
      ),
    ],
  );
}

Future<void> _showImprovementFilters(
  BuildContext context,
  ImprovementPlannerController controller,
) {
  final content = _ImprovementFilterSheet(controller: controller);
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<void>(
      isDismissible: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: appColor(context, Color(0xff142735)),
      builder: (_) => SafeArea(child: content),
    );
  }
  return showDialog<void>(
    barrierDismissible: false,
    context: context,
    builder: (_) => Dialog(child: SizedBox(width: 520, child: content)),
  );
}

class _ImprovementFilterSheet extends StatelessWidget {
  const _ImprovementFilterSheet({required this.controller});

  final ImprovementPlannerController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final english = Localizations.maybeLocaleOf(context)?.languageCode == 'en';
    const title = UiText(
      '筛选装备',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
    final actions = <Widget>[
      TextButton(
        key: const Key('improvement-filter-clear'),
        onPressed: controller.clearFilters,
        child: const UiText('全部清除'),
      ),
      IconButton(
        key: const Key('improvement-filter-close'),
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ];
    return AnimatedBuilder(
      key: const Key('improvement-filter-sheet'),
      animation: controller,
      builder: (context, _) {
        final body = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (english && _englishTextLayoutScale(context) > 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    if (english)
                      const Expanded(child: title)
                    else ...[
                      title,
                      const Spacer(),
                    ],
                    ...actions,
                  ],
                ),
              const SizedBox(height: 8),
              const UiText('装备分类'),
              const SizedBox(height: 5),
              Wrap(
                runSpacing: 5,
                children: [
                  for (final category in EquipmentInventoryCategory.values)
                    CompactFilterChip(
                      key: Key('improvement-filter-equipment-${category.name}'),
                      label: _equipmentCategoryLabel(category, l10n),
                      selected: controller.equipmentCategory == category,
                      onTap: () => controller.selectEquipmentCategory(category),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const UiText('进化状态'),
              const SizedBox(height: 5),
              Wrap(
                runSpacing: 5,
                children: [
                  for (final option
                      in const <(ImprovementEvolutionFilter, String)>[
                        (ImprovementEvolutionFilter.all, '全部'),
                        (ImprovementEvolutionFilter.evolvable, '可进化'),
                        (ImprovementEvolutionFilter.notEvolvable, '不可进化'),
                      ])
                    CompactFilterChip(
                      key: Key(
                        'improvement-filter-evolution-${option.$1.name}',
                      ),
                      label: uiText(context, option.$2),
                      selected: controller.evolutionFilter == option.$1,
                      onTap: () => controller.selectEvolutionFilter(option.$1),
                    ),
                ],
              ),
            ],
          ),
        );
        return english ? SingleChildScrollView(child: body) : body;
      },
    );
  }
}

String _equipmentCategoryLabel(
  EquipmentInventoryCategory value,
  AppLocalizations l10n,
) => switch (value) {
  EquipmentInventoryCategory.all => l10n.all,
  EquipmentInventoryCategory.mainGun => l10n.equipmentMainGun,
  EquipmentInventoryCategory.secondaryGun => l10n.equipmentSecondaryGun,
  EquipmentInventoryCategory.machineGun => l10n.equipmentMachineGun,
  EquipmentInventoryCategory.torpedo => l10n.equipmentTorpedo,
  EquipmentInventoryCategory.carrierAircraft => l10n.equipmentCarrierAircraft,
  EquipmentInventoryCategory.seaplane => l10n.equipmentSeaplane,
  EquipmentInventoryCategory.landBasedAircraft =>
    l10n.equipmentLandBasedAircraft,
  EquipmentInventoryCategory.antiSubmarine => l10n.antiSub,
  EquipmentInventoryCategory.radar => l10n.equipmentRadar,
  EquipmentInventoryCategory.landingTransport => l10n.equipmentLandingTransport,
  EquipmentInventoryCategory.support => l10n.equipmentSupport,
};

class _SegmentOption<T> {
  const _SegmentOption({
    required this.value,
    required this.label,
    required this.key,
  });
  final T value;
  final String label;
  final Key key;
}

class _SlidingSegment<T> extends StatelessWidget {
  const _SlidingSegment({
    super.key,
    required this.sliderKey,
    required this.selected,
    required this.segmentWidth,
    required this.options,
    required this.onChanged,
  });
  final Key sliderKey;
  final T selected;
  final double segmentWidth;
  final List<_SegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = math.max(
      0,
      options.indexWhere((item) => item.value == selected),
    );
    final scale = _englishTextLayoutScale(context);
    final inset = AppSegmentedStyle.padding(compact: true);
    return SizedBox(
      width: segmentWidth * options.length,
      height: 30 * scale,
      child: DecoratedBox(
        decoration: AppSegmentedStyle.decoration(context, compact: true),
        child: Stack(
          children: [
            AnimatedPositioned(
              key: sliderKey,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              left: selectedIndex * segmentWidth + inset.left,
              top: inset.top,
              width: segmentWidth - inset.horizontal,
              height: 24 * scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppSegmentedStyle.selectedBackground(context),
                  borderRadius: AppSegmentedStyle.itemRadius(compact: true),
                ),
              ),
            ),
            Row(
              children: [
                for (final option in options)
                  SizedBox(
                    width: segmentWidth,
                    height: 28 * scale,
                    child: Material(
                      color: appColor(context, Colors.transparent),
                      child: InkWell(
                        key: option.key,
                        borderRadius: AppSegmentedStyle.itemRadius(
                          compact: true,
                        ),
                        onTap: () => onChanged(option.value),
                        child: Center(
                          child: Text(
                            uiText(context, option.label),
                            style: AppSegmentedStyle.textStyle(
                              context,
                              selected: option.value == selected,
                              compact: true,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImprovementTable extends StatefulWidget {
  const _ImprovementTable({
    required this.rows,
    required this.controller,
    required this.state,
  });
  final List<ImprovementPlannerRow> rows;
  final ImprovementPlannerController controller;
  final GameState state;

  @override
  State<_ImprovementTable> createState() => _ImprovementTableState();
}

class _ImprovementTableState extends State<_ImprovementTable> {
  final Map<int, int> _focusedRouteByEquipment = <int, int>{};

  MasterSlotItem? _master(int id) => widget.state.masterSlotItems[id];
  String _name(int id) =>
      gameNames(context).equipmentName(_master(id)?.name ?? '#$id');
  int _icon(int id) {
    final type = _master(id)?.type ?? const <int>[];
    return type.length > 3 ? type[3] : -1;
  }

  List<ImprovementSecretarySchedule> _secretarySchedules(
    ImprovementPlannerRow row,
  ) {
    final routes = row.upgradeRoutes;
    if (routes.isEmpty) return row.secretarySchedules;
    return <ImprovementSecretarySchedule>[
      for (final route in routes)
        for (final schedule in route.secretarySchedules) schedule,
    ];
  }

  double _routeHeight(int lineCount) => 34.0 + 24.0 * math.max(1, lineCount);

  List<double> _consumeRouteHeights(ImprovementPlannerRow row) => <double>[
    for (final route in row.upgradeRoutes)
      _routeHeight(route.upgrade.items.length),
  ];

  List<double> _secretaryRouteHeights(ImprovementPlannerRow row) => <double>[
    for (final route in row.upgradeRoutes)
      34.0 + math.max(24.0, _secretaryScheduleHeight(route.secretarySchedules)),
  ];

  List<double> _targetRouteHeights(ImprovementPlannerRow row) => <double>[
    for (final _ in row.upgradeRoutes) _routeHeight(1),
  ];

  void _toggleRoute(int equipmentId, int routeIndex) {
    setState(() {
      if (_focusedRouteByEquipment[equipmentId] == routeIndex) {
        _focusedRouteByEquipment.remove(equipmentId);
      } else {
        _focusedRouteByEquipment[equipmentId] = routeIndex;
      }
    });
  }

  double _secretaryScheduleHeight(
    List<ImprovementSecretarySchedule> schedules,
  ) {
    if (schedules.isEmpty) return 20;
    var height = 0.0;
    for (final schedule in schedules) {
      final painter = TextPainter(
        text: TextSpan(
          text: gameNames(
            context,
          ).entityText(schedule.secretaryLabels.join('、')),
          style: appTextStyle(context, _cellStyle),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 154);
      height += math.max(18.0, painter.height) + 4;
    }
    return height;
  }

  double _rowHeight(ImprovementPlannerRow row) {
    final routes = row.upgradeRoutes;
    final routeLaneHeight = routes.length > 1
        ? 8.0 +
              <List<double>>[
                    _consumeRouteHeights(row),
                    _secretaryRouteHeights(row),
                    _targetRouteHeights(row),
                  ]
                  .map(
                    (heights) =>
                        heights.fold<double>(0, (sum, height) => sum + height),
                  )
                  .reduce(math.max)
        : 0.0;
    return math.max(
      FrozenDataTable.minimumRowHeight,
      8 +
          <double>[
            24.0 * (1 + row.entry.stage0.items.length),
            24.0 * (1 + row.entry.stage1.items.length),
            24.0 *
                routes.fold<int>(
                  0,
                  (sum, route) => sum + math.max(1, route.upgrade.items.length),
                ),
            _secretaryScheduleHeight(_secretarySchedules(row)),
            24.0 * math.max(1, routes.length),
            routeLaneHeight,
          ].reduce(math.max),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _englishTextLayoutScale(context);
    final heights = <double>[
      for (final row in widget.rows) _rowHeight(row) * scale,
    ];
    return FrozenDataTable(
      key: const Key('improvement-planner-table'),
      keyPrefix: 'improvement-table',
      rowHeights: heights,
      headerExtent: FrozenDataTable.headerHeight * scale,
      frozenColumnWidths: const <double>[48, 190],
      frozenHeaders: <Widget>[
        if (scale > 1)
          Tooltip(
            message: uiText(context, '收藏'),
            child: Icon(
              Icons.star_border,
              key: Key('improvement-frozen-favorite'),
              size: 18,
              color: appColor(context, Color(0xffb8c9d2)),
            ),
          )
        else
          const _Header(key: Key('improvement-frozen-favorite'), label: '收藏'),
        const _Header(key: Key('improvement-frozen-equipment'), label: '装备名字'),
      ],
      frozenCells: (index) {
        final entry = widget.rows[index].entry;
        final favorite = widget.controller.favoriteEquipmentIds.contains(
          entry.equipmentId,
        );
        return <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: Key('improvement-favorite-${entry.equipmentId}'),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  widget.controller.toggleFavorite(entry.equipmentId),
              icon: Icon(
                favorite ? Icons.star : Icons.star_border,
                size: 18,
                color: appColor(
                  context,
                  favorite ? const Color(0xffffc85a) : const Color(0xff78909c),
                ),
              ),
            ),
          ),
          _EquipmentLine(
            iconId: _icon(entry.equipmentId),
            name: _name(entry.equipmentId),
          ),
        ];
      },
      scrollableColumnWidths: <double>[
        for (final width in const [170, 210, 280, 220, 300, 82, 220])
          width * scale,
      ],
      scrollableHeaders: const <Widget>[
        _Header(
          label: '基础消耗',
          alignmentKey: Key('improvement-header-base-cost-align'),
        ),
        _Header(label: '改修消耗（0 → +6）'),
        _Header(label: '改修消耗（+6 → MAX）'),
        _Header(label: '进化消耗'),
        _Header(label: '秘书舰'),
        _Header(label: '可进化'),
        _Header(label: '进化装备'),
      ],
      scrollableCells: (index) {
        final row = widget.rows[index];
        final entry = row.entry;
        final routes = row.upgradeRoutes;
        final evolvableToday = routes.isNotEmpty;
        final hasMultipleRoutes = routes.length > 1;
        final consumeRouteHeights = hasMultipleRoutes
            ? _consumeRouteHeights(row).map((height) => height * scale).toList()
            : const <double>[];
        final secretaryRouteHeights = hasMultipleRoutes
            ? _secretaryRouteHeights(
                row,
              ).map((height) => height * scale).toList()
            : const <double>[];
        final targetRouteHeights = hasMultipleRoutes
            ? _targetRouteHeights(row).map((height) => height * scale).toList()
            : const <double>[];
        final storedFocusedRoute = _focusedRouteByEquipment[entry.equipmentId];
        final focusedRouteIndex =
            storedFocusedRoute != null && storedFocusedRoute < routes.length
            ? storedFocusedRoute
            : null;
        void onRouteTap(int routeIndex) =>
            _toggleRoute(entry.equipmentId, routeIndex);
        return <Widget>[
          _BaseCostCell(
            cost: entry.baseCost,
            alignmentKey: Key(
              'improvement-cell-base-cost-align-${entry.equipmentId}',
            ),
          ),
          _StageConsumeCell(
            key: Key('improvement-stage-0-${entry.equipmentId}'),
            stageIndex: 0,
            stage: entry.stage0,
            name: _name,
            icon: _icon,
          ),
          _StageConsumeCell(
            key: Key('improvement-stage-1-${entry.equipmentId}'),
            stageIndex: 1,
            stage: entry.stage1,
            name: _name,
            icon: _icon,
          ),
          hasMultipleRoutes
              ? _RouteColumn(
                  equipmentId: entry.equipmentId,
                  column: 'consume',
                  routes: routes,
                  heights: consumeRouteHeights,
                  focusedRouteIndex: focusedRouteIndex,
                  onRouteTap: onRouteTap,
                  contentBuilder: (routeIndex) => _RouteConsumeContent(
                    items: routes[routeIndex].upgrade.items,
                    name: _name,
                    icon: _icon,
                  ),
                )
              : _UpgradeConsumeCell(routes: routes, name: _name, icon: _icon),
          hasMultipleRoutes
              ? _RouteColumn(
                  equipmentId: entry.equipmentId,
                  column: 'secretary',
                  routes: routes,
                  heights: secretaryRouteHeights,
                  focusedRouteIndex: focusedRouteIndex,
                  onRouteTap: onRouteTap,
                  contentBuilder: (routeIndex) => _RouteSecretaryContent(
                    schedules: routes[routeIndex].secretarySchedules,
                    dayKeyPrefix:
                        'improvement-route-secretary-day-${entry.equipmentId}-$routeIndex',
                  ),
                )
              : _SecretaryWrap(
                  wrapKey: Key('improvement-secretaries-${entry.equipmentId}'),
                  schedules: _secretarySchedules(row),
                  dayKeyPrefix:
                      'improvement-secretary-day-${entry.equipmentId}',
                ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: UiText(evolvableToday ? '可进化' : '—', style: _cellStyle),
            ),
          ),
          hasMultipleRoutes
              ? _RouteColumn(
                  equipmentId: entry.equipmentId,
                  column: 'target',
                  routes: routes,
                  heights: targetRouteHeights,
                  focusedRouteIndex: focusedRouteIndex,
                  onRouteTap: onRouteTap,
                  contentBuilder: (routeIndex) {
                    final targetId =
                        routes[routeIndex].upgrade.targetEquipmentId;
                    return _EquipmentLine(
                      iconId: _icon(targetId),
                      name: _name(targetId),
                    );
                  },
                )
              : _Lines(
                  values: <String>[
                    for (final route in routes)
                      _name(route.upgrade.targetEquipmentId),
                  ],
                  leading: <Widget>[
                    for (final route in routes)
                      EquipmentTypeIconImage(
                        iconId: _icon(route.upgrade.targetEquipmentId),
                        width: 20,
                        height: 20,
                      ),
                  ],
                ),
        ];
      },
    );
  }
}

const _cellStyle = TextStyle(
  color: Color(0xffdce8ed),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.1,
);
const _quantityStyle = TextStyle(
  color: Color(0xff58bce8),
  fontSize: 11,
  fontWeight: FontWeight.w800,
  height: 1.1,
);

String _materialDisplayName(ImprovementConsumeItem item) =>
    item.materialName ??
    const <String, String>{
      'ActionReport': '戦闘詳報',
      'emergency-repair-material': '緊急修理資材',
      'fast-build': '高速建造材',
      'kaigai-skill': '海外艦最新技術',
      'kousyo-sigen': '工廠資源',
      'MedalL': '勲章',
      'NeEngine': 'ネ式エンジン',
      'new_gun_material': '新型砲熕兵装資材',
      'new_model_material': '新型兵装資材',
      'new_plane_material': '新型航空兵装資材',
      'new-funsiki-material': '新型噴進装備開発資材',
      'sensui-hokyu': '潜水艦補給物資',
      'skilled_crew': '熟練搭乗員',
    }[item.materialKey] ??
    item.materialKey ??
    '—';

String _localizedMaterialDisplayName(
  BuildContext context,
  ImprovementConsumeItem item,
) {
  final language = Localizations.maybeLocaleOf(context)?.languageCode;
  if (language != 'en' && language != 'ko') return _materialDisplayName(item);
  const names = <String, (String, String)>{
    'ActionReport': ('Action Report', '전투상보'),
    'emergency-repair-material': ('Emergency Repair Material', '긴급수리자재'),
    'fast-build': ('Instant Construction Material', '고속건조재'),
    'kaigai-skill': ('New Overseas Warship Technology', '해외함 최신기술'),
    'kousyo-sigen': ('Arsenal Material', '공창자원'),
    'MedalL': ('Medal', '훈장'),
    'NeEngine': ('Ne Type Engine', 'Ne식 엔진'),
    'new_gun_material': (
      'New Model Gun Mount Improvement Material',
      '신형포공병장자재',
    ),
    'new_model_material': ('New Model Armament Material', '신형병장자재'),
    'new_plane_material': ('New Model Aerial Armament Material', '신형항공병장자재'),
    'new-funsiki-material': (
      'New Model Rocket Development Material',
      '신형분진장비개발자재',
    ),
    'sensui-hokyu': ('Submarine Supply Material', '잠수함 보급물자'),
    'skilled_crew': ('Skilled Crew Member', '숙련탑승원'),
  };
  final value = names[item.materialKey];
  return value == null
      ? _materialDisplayName(item)
      : language == 'ko'
      ? value.$2
      : value.$1;
}

String? _materialIconAsset(String? materialKey) => const <String, String>{
  'ActionReport': 'assets/images/material/useitem_78.png',
  'emergency-repair-material': 'assets/images/material/useitem_91.png',
  'fast-build': 'assets/images/material/useitem_2.png',
  'kaigai-skill': 'assets/images/material/useitem_100.png',
  'kousyo-sigen': 'assets/images/material/useitem_104.png',
  'MedalL': 'assets/images/material/useitem_57.png',
  'NeEngine': 'assets/images/material/useitem_71.png',
  'new_gun_material': 'assets/images/material/useitem_75.png',
  'new_model_material': 'assets/images/material/useitem_94.png',
  'new_plane_material': 'assets/images/material/useitem_77.png',
  'new-funsiki-material': 'assets/images/material/useitem_92.png',
  'sensui-hokyu': 'assets/images/material/useitem_95.png',
  'skilled_crew': 'assets/images/material/useitem_70.png',
}[materialKey];

class _Header extends StatelessWidget {
  const _Header({super.key, required this.label, this.alignmentKey});
  final String label;
  final Key? alignmentKey;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Align(
      key: alignmentKey,
      alignment: Alignment.centerLeft,
      child: Text(
        uiText(context, label),
        style: appTextStyle(
          context,
          TextStyle(
            color: appColor(context, Color(0xffb8c9d2)),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    ),
  );
}

class _EquipmentLine extends StatelessWidget {
  const _EquipmentLine({
    required this.iconId,
    required this.name,
    this.count,
    this.badge,
  });
  final int iconId;
  final String name;
  final int? count;
  final String? badge;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    child: Row(
      children: [
        EquipmentTypeIconImage(iconId: iconId, width: 20, height: 20),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appTextStyle(context, _cellStyle),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 4),
          _ConsumeBadge(label: badge!),
          const SizedBox(width: 5),
        ],
        if (count != null)
          Text('×$count', style: appTextStyle(context, _quantityStyle)),
      ],
    ),
  );
}

class _StageConsumeCell extends StatelessWidget {
  const _StageConsumeCell({
    super.key,
    required this.stageIndex,
    required this.stage,
    required this.name,
    required this.icon,
  });
  final int stageIndex;
  final ImprovementStageCost stage;
  final String Function(int) name;
  final int Function(int) icon;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StageMaterialCostLine(stageIndex: stageIndex, stage: stage),
          for (final item in stage.items)
            _StageConsumeItemLine(item: item, name: name, icon: icon),
        ],
      ),
    ),
  );
}

class _StageMaterialCostLine extends StatelessWidget {
  const _StageMaterialCostLine({required this.stageIndex, required this.stage});

  final int stageIndex;
  final ImprovementStageCost stage;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Row(
      children: [
        Image.asset(
          'assets/images/material/07.png',
          key: Key('improvement-stage-development-icon-$stageIndex'),
          width: 18,
          height: 18,
        ),
        const SizedBox(width: 4),
        Text(
          '${stage.developmentMin} / ${stage.developmentMax}',
          style: appTextStyle(context, _quantityStyle),
        ),
        const SizedBox(width: 14),
        Image.asset(
          'assets/images/material/08.png',
          key: Key('improvement-stage-improvement-icon-$stageIndex'),
          width: 18,
          height: 18,
        ),
        const SizedBox(width: 4),
        Text(
          '${stage.improvementMin} / ${stage.improvementMax}',
          style: appTextStyle(context, _quantityStyle),
        ),
      ],
    ),
  );
}

class _StageConsumeItemLine extends StatelessWidget {
  const _StageConsumeItemLine({
    required this.item,
    required this.name,
    required this.icon,
  });

  final ImprovementConsumeItem item;
  final String Function(int) name;
  final int Function(int) icon;

  @override
  Widget build(BuildContext context) {
    final line = item.equipmentId == null
        ? _MaterialLine(item: item, badge: item.isEveryAttempt ? '每次' : null)
        : _EquipmentLine(
            iconId: icon(item.equipmentId!),
            name: name(item.equipmentId!),
            count: item.count,
            badge: item.isEveryAttempt ? '每次' : null,
          );
    if (item.isEveryAttempt) {
      return line;
    }
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _ConsumeBadge(label: _starRangeLabel(item)),
        ),
        Expanded(child: line),
      ],
    );
  }
}

String _starRangeLabel(ImprovementConsumeItem item) {
  final from = item.starFrom!;
  final destination = item.starTo == 9 ? 'MAX' : '+${item.starTo! + 1}';
  return '+$from→$destination';
}

class _ConsumeBadge extends StatelessWidget {
  const _ConsumeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: appColor(context, const Color(0xff8b5e12)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      uiText(context, label),
      maxLines: 1,
      style: appTextStyle(
        context,
        TextStyle(
          color: appColor(context, Color(0xffffd56a)),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    ),
  );
}

typedef _RouteContentBuilder = Widget Function(int routeIndex);

class _RouteColumn extends StatelessWidget {
  const _RouteColumn({
    required this.equipmentId,
    required this.column,
    required this.routes,
    required this.heights,
    required this.focusedRouteIndex,
    required this.onRouteTap,
    required this.contentBuilder,
  });

  final int equipmentId;
  final String column;
  final List<ImprovementUpgradeRoute> routes;
  final List<double> heights;
  final int? focusedRouteIndex;
  final ValueChanged<int> onRouteTap;
  final _RouteContentBuilder contentBuilder;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (var routeIndex = 0; routeIndex < routes.length; routeIndex++)
          _RouteLane(
            routeKey: Key('improvement-route-$equipmentId-$column-$routeIndex'),
            routeIndex: routeIndex,
            height: heights[routeIndex],
            focusedRouteIndex: focusedRouteIndex,
            onTap: () => onRouteTap(routeIndex),
            child: contentBuilder(routeIndex),
          ),
      ],
    ),
  );
}

class _RouteLane extends StatelessWidget {
  const _RouteLane({
    required this.routeKey,
    required this.routeIndex,
    required this.height,
    required this.focusedRouteIndex,
    required this.onTap,
    required this.child,
  });

  final Key routeKey;
  final int routeIndex;
  final double height;
  final int? focusedRouteIndex;
  final VoidCallback onTap;
  final Widget child;

  Color get _color => const <Color>[
    Color(0xff58bce8),
    Color(0xffffad5c),
    Color(0xff8ed081),
    Color(0xffc792ea),
  ][routeIndex % 4];

  String get _label {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return routeIndex < letters.length
        ? letters[routeIndex]
        : '${routeIndex + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final scale = _englishTextLayoutScale(context);
    final isFocused = focusedRouteIndex == routeIndex;
    final isDimmed = focusedRouteIndex != null && !isFocused;
    return AnimatedOpacity(
      key: routeKey,
      duration: const Duration(milliseconds: 160),
      opacity: isDimmed ? 0.32 : 1,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Material(
            color: appColor(context, Colors.transparent),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(7),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                decoration: BoxDecoration(
                  color: appColor(
                    context,
                    _color.withValues(alpha: isFocused ? 0.18 : 0.08),
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: appColor(
                      context,
                      _color.withValues(alpha: isFocused ? 1 : 0.66),
                    ),
                    width: isFocused ? 2 : 1,
                  ),
                  boxShadow: isFocused
                      ? <BoxShadow>[
                          BoxShadow(
                            color: appColor(
                              context,
                              _color.withValues(alpha: 0.24),
                            ),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18 * scale,
                          height: 18 * scale,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: appColor(
                              context,
                              _color.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: appColor(context, _color),
                            ),
                          ),
                          child: Text(
                            _label,
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: _color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        UiText(
                          '路线 $_label',
                          style: TextStyle(
                            color: appColor(context, _color),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteConsumeContent extends StatelessWidget {
  const _RouteConsumeContent({
    required this.items,
    required this.name,
    required this.icon,
  });

  final List<ImprovementConsumeItem> items;
  final String Function(int) name;
  final int Function(int) icon;

  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const _EmptyCell()
      : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final item in items)
              item.equipmentId == null
                  ? _MaterialLine(item: item)
                  : _EquipmentLine(
                      iconId: icon(item.equipmentId!),
                      name: name(item.equipmentId!),
                      count: item.count,
                    ),
          ],
        );
}

class _RouteSecretaryContent extends StatelessWidget {
  const _RouteSecretaryContent({
    required this.schedules,
    required this.dayKeyPrefix,
  });

  final List<ImprovementSecretarySchedule> schedules;
  final String dayKeyPrefix;

  @override
  Widget build(BuildContext context) => schedules.isEmpty
      ? const _EmptyCell()
      : Align(
          alignment: Alignment.centerLeft,
          child: _SecretaryScheduleList(
            schedules: schedules,
            dayKeyPrefix: dayKeyPrefix,
          ),
        );
}

class _UpgradeConsumeCell extends StatelessWidget {
  const _UpgradeConsumeCell({
    required this.routes,
    required this.name,
    required this.icon,
  });
  final List<ImprovementUpgradeRoute> routes;
  final String Function(int) name;
  final int Function(int) icon;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const _EmptyCell();
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final route in routes)
          for (final item in route.upgrade.items)
            item.equipmentId == null
                ? _MaterialLine(item: item)
                : _EquipmentLine(
                    iconId: icon(item.equipmentId!),
                    name: name(item.equipmentId!),
                    count: item.count,
                  ),
      ],
    );
  }
}

class _MaterialLine extends StatelessWidget {
  const _MaterialLine({required this.item, this.badge});
  final ImprovementConsumeItem item;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final iconAsset = _materialIconAsset(item.materialKey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          if (iconAsset != null) ...[
            Image.asset(
              iconAsset,
              key: ValueKey<String>(
                'improvement-material-icon-${item.materialKey}',
              ),
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              _localizedMaterialDisplayName(context, item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appTextStyle(context, _cellStyle),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 4),
            _ConsumeBadge(label: badge!),
            const SizedBox(width: 5),
          ],
          Text('×${item.count}', style: appTextStyle(context, _quantityStyle)),
        ],
      ),
    );
  }
}

class _BaseCostCell extends StatelessWidget {
  const _BaseCostCell({required this.cost, this.alignmentKey});
  final ImprovementResourceCost cost;
  final Key? alignmentKey;
  @override
  Widget build(BuildContext context) {
    final values = <int>[cost.fuel, cost.ammo, cost.steel, cost.bauxite];
    return Align(
      key: alignmentKey,
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/material/0${index + 1}.png',
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 1),
                  Text(
                    '${values[index]}',
                    style: appTextStyle(context, _cellStyle),
                  ),
                ],
              ),
              if (index != values.length - 1) const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.values, this.leading = const <Widget>[]});
  final List<String> values;
  final List<Widget> leading;
  @override
  Widget build(BuildContext context) => values.isEmpty
      ? const _EmptyCell()
      : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < values.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    if (index < leading.length) ...[
                      leading[index],
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        values[index],
                        style: appTextStyle(context, _cellStyle),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
}

class _SecretaryWrap extends StatelessWidget {
  const _SecretaryWrap({
    required this.wrapKey,
    required this.schedules,
    required this.dayKeyPrefix,
  });
  final Key wrapKey;
  final List<ImprovementSecretarySchedule> schedules;
  final String dayKeyPrefix;

  @override
  Widget build(BuildContext context) => schedules.isEmpty
      ? const _EmptyCell()
      : Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: _SecretaryScheduleList(
              key: wrapKey,
              schedules: schedules,
              dayKeyPrefix: dayKeyPrefix,
            ),
          ),
        );
}

class _SecretaryScheduleList extends StatelessWidget {
  const _SecretaryScheduleList({
    super.key,
    required this.schedules,
    required this.dayKeyPrefix,
  });

  static const _weekdayOrder = <int>[7, 1, 2, 3, 4, 5, 6];
  static const _weekdayLabels = <String>['日', '一', '二', '三', '四', '五', '六'];

  final List<ImprovementSecretarySchedule> schedules;
  final String dayKeyPrefix;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var groupIndex = 0; groupIndex < schedules.length; groupIndex++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              for (
                var dayIndex = 0;
                dayIndex < _weekdayOrder.length;
                dayIndex++
              ) ...[
                if (dayIndex > 0) const SizedBox(width: 1),
                _SecretaryDayCell(
                  key: Key(
                    '$dayKeyPrefix-$groupIndex-${_weekdayOrder[dayIndex]}',
                  ),
                  label: _weekdayLabels[dayIndex],
                  active: schedules[groupIndex].weekdays.contains(
                    _weekdayOrder[dayIndex],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gameNames(
                    context,
                  ).entityText(schedules[groupIndex].secretaryLabels.join('、')),
                  softWrap: true,
                  style: appTextStyle(context, _cellStyle),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _SecretaryDayCell extends StatelessWidget {
  const _SecretaryDayCell({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 16 * _englishTextLayoutScale(context),
    height: 18 * _englishTextLayoutScale(context),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: appColor(
        context,
        active ? const Color(0xff258b68) : const Color(0xff37434a),
      ),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Text(
      label,
      style: appTextStyle(
        context,
        TextStyle(
          color: active ? const Color(0xffe5fff4) : const Color(0xff8fa0a8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    ),
  );
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text('—', style: appTextStyle(context, _cellStyle)),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: UiText(
      '当天没有符合条件的改修装备',
      style: TextStyle(
        color: appColor(context, Color(0xff8da5b2)),
        fontSize: 13,
      ),
    ),
  );
}
