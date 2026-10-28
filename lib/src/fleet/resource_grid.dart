import 'dart:async';

import 'dart:math' as math;

import '../theme/app_palette.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'fleet_ui_strings.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import '../browser/game_dialog_presentation_scope.dart';
import '../browser/game_reminder_dialog.dart';
import '../browser/native_game_resource_checklist.dart';
import '../layout/display_corners.dart';
import '../layout/flat_collapse_chevron.dart';
import '../layout/ui_scale.dart';
import '../settings/header_resource_settings.dart';
import '../settings/layout_settings_controller.dart';
import '../performance/second_tick_scope.dart';
import '../widgets/top_notice.dart';
import 'anchorage_repair_calculator.dart';
import 'header_resource_catalog.dart';

class ResourceGrid extends StatelessWidget {
  const ResourceGrid({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 450 ? 2 : 4;

        const spacing = 4.0;
        final available =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final itemWidth = available.clamp(0.0, double.infinity);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final type in GameResourceType.values)
              SizedBox(
                width: itemWidth,
                child: Tooltip(
                  message: fleetText(context, type.label),
                  child: _ResourceItem(type: type, value: state.resource(type)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResourceItem extends StatelessWidget {
  const _ResourceItem({required this.type, required this.value});

  final GameResourceType type;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('resource-item-${type.apiId}'),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff142735)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appColor(context, Color(0xff315064))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Image.asset(
            _assetPath(type),
            key: Key('resource-icon-${type.apiId}'),
            width: 17,
            height: 17,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value?.toString() ?? '—',
                maxLines: 1,
                softWrap: false,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xffdce6eb)),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _assetPath(GameResourceType type) =>
      'assets/images/material/${type.apiId.toString().padLeft(2, '0')}.png';
}

enum ResourceBarLayout { strip, staticStrip, grid }

/// 借用信息栏模块的折叠列表持久化网格的折叠状态。
const panelResourcesCollapseId = 'panel-resources';

class CompactResourceBar extends StatefulWidget {
  const CompactResourceBar({
    super.key,
    required this.state,
    this.senka,
    this.rank,
    this.anchorageRepairStartedAt,
    this.nosakiSparkleStartedAt,
    this.settingsController,
    this.onSenkaTap,
    this.onAnchorageTimerTap,
    this.onNosakiTimerTap,
    this.onFrameRefreshTap,
    this.onGameRefreshTap,
    this.layout = ResourceBarLayout.strip,
    this.gridPadding = EdgeInsets.zero,
    this.gridCornerRadii = (left: 0, right: 0),
    this.uiSize,
    this.flatStyle = false,
    this.initiallyEditing = false,
  });

  final GameState state;
  final double? senka;
  final int? rank;
  final DateTime? anchorageRepairStartedAt;
  final DateTime? nosakiSparkleStartedAt;
  final LayoutSettingsController? settingsController;
  final VoidCallback? onSenkaTap;
  final VoidCallback? onAnchorageTimerTap;
  final VoidCallback? onNosakiTimerTap;
  final VoidCallback? onFrameRefreshTap;
  final VoidCallback? onGameRefreshTap;

  /// grid 用于游戏页没有顶栏时把资源放进信息栏；strip 是顶栏里的横向滚动条；
  /// staticStrip 是只展示的单行，放不下时整行缩小而不滚动。
  final ResourceBarLayout layout;
  final EdgeInsets gridPadding;

  /// 网格贴着屏幕顶角那侧要避让的圆角半径，不贴角的一侧为 0。
  final ({double left, double right}) gridCornerRadii;

  /// Overrides the settings size, e.g. HD lays minimal out as compact.
  final UiDisplaySize? uiSize;

  /// Flat strip styling is independent of compact sizing; grids ignore it.
  final bool flatStyle;

  /// Allows the settings entry to open the same editor used by a long press.
  final bool initiallyEditing;

  @override
  State<CompactResourceBar> createState() => CompactResourceBarState();
}

class CompactResourceBarState extends State<CompactResourceBar> {
  static const Map<String, ({int useItemId, int rate})> _furnitureBoxCoinRates =
      <String, ({int useItemId, int rate})>{
        'useitem-10': (useItemId: 10, rate: 200),
        'useitem-11': (useItemId: 11, rate: 400),
        'useitem-12': (useItemId: 12, rate: 700),
      };

  late final ScrollController _scrollController = ScrollController();
  final Set<String> _furnitureBoxCoinModeIds = <String>{};
  bool _showTheoreticalFurnitureCoins = false;
  bool _editing = false;
  final _checklistValueChanges = ValueNotifier(0);
  GameReminderDialogPresentation? _resourceChecklist;
  GameDialogPresentationScope? _dialogPresentation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = GameDialogPresentationScope.maybeOf(context);
    final previous = _dialogPresentation;
    if (previous?.nativeActivity != next?.nativeActivity ||
        previous?.presentationEnabled != next?.presentationEnabled ||
        previous?.nativeChecklistPort != next?.nativeChecklistPort) {
      _cancelResourceChecklist();
    }
    _dialogPresentation = next;
  }

  /// Opens the same choices as the header filter without entering edit mode.
  Future<void> openHeaderChecklist() async {
    final controller = widget.settingsController;
    if (!mounted || controller == null || controller.uiLocked) return;
    await _showResourceFilter(controller);
  }

  Future<void> openCollapsedChecklist() async {
    final controller = widget.settingsController;
    if (!mounted || controller == null || controller.uiLocked) return;
    await _showCollapsedItemsPicker(controller);
  }

  void _cancelResourceChecklist() {
    final presentation = _resourceChecklist;
    _resourceChecklist = null;
    presentation?.cancel();
  }

  Future<void> _trackResourceChecklist(
    GameReminderDialogPresentation? presentation,
  ) async {
    if (presentation == null) return;
    _resourceChecklist = presentation;
    await presentation.completed;
    if (identical(_resourceChecklist, presentation)) _resourceChecklist = null;
  }

  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _editing =
        widget.initiallyEditing && widget.settingsController?.uiLocked != true;
    widget.settingsController?.addListener(_handleSettingsChanged);
  }

  @override
  void didUpdateWidget(covariant CompactResourceBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsController != widget.settingsController) {
      _cancelResourceChecklist();
      oldWidget.settingsController?.removeListener(_handleSettingsChanged);
      widget.settingsController?.addListener(_handleSettingsChanged);
    }
    if (widget.settingsController?.uiLocked == true) {
      _cancelResourceChecklist();
      _editing = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checklistValueChanges.value++;
    });
  }

  @override
  void dispose() {
    _cancelResourceChecklist();
    widget.settingsController?.removeListener(_handleSettingsChanged);
    _checklistValueChanges.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (!mounted) return;
    if (widget.settingsController?.uiLocked == true) _cancelResourceChecklist();
    if (widget.settingsController?.uiLocked == true && _editing) {
      setState(() => _editing = false);
    }
  }

  void _toggleFurnitureBoxCoinMode(String id) {
    setState(() {
      if (!_furnitureBoxCoinModeIds.remove(id)) {
        _furnitureBoxCoinModeIds.add(id);
      }
    });
  }

  void _toggleTheoreticalFurnitureCoins() {
    setState(() {
      _showTheoreticalFurnitureCoins = !_showTheoreticalFurnitureCoins;
    });
  }

  int? _headerResourceValue(String id, HeaderResourceSpec spec) {
    final value = spec.value(widget.state);
    if (id == headerFurnitureCoinId && _showTheoreticalFurnitureCoins) {
      if (value == null || !widget.state.hasUseItemData) return null;
      var total = value;
      for (final box in _furnitureBoxCoinRates.values) {
        total += widget.state.useItemCount(box.useItemId)! * box.rate;
      }
      return total;
    }
    final box = _furnitureBoxCoinModeIds.contains(id)
        ? _furnitureBoxCoinRates[id]
        : null;
    return value == null || box == null ? value : value * box.rate;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        event.scrollDelta.dx != 0 ||
        event.scrollDelta.dy == 0 ||
        !_scrollController.hasClients) {
      return;
    }
    // The child Scrollable keeps priority for native horizontal/Shift scrolling.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!_scrollController.hasClients) return;
      _scrollController.position.pointerScroll(event.scrollDelta.dy);
    });
  }

  String get _anchorageElapsed {
    if (!AnchorageRepairCalculator.hasReadyFleet(widget.state)) {
      return '--:--:--';
    }
    return formatAnchorageRepairElapsed(widget.anchorageRepairStartedAt, _now);
  }

  String get _nosakiElapsed {
    return formatNosakiSparkleElapsed(widget.nosakiSparkleStartedAt, _now);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.settingsController;
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _buildWithClock(controller),
      );
    }
    return _buildWithClock(null);
  }

  List<String> _orderedDisplayIds(LayoutSettingsController? controller) {
    final order = controller?.headerResourceOrder ?? allHeaderResourceIds;
    if (_editing && controller?.uiLocked != true) return order;
    final visible =
        (controller?.visibleHeaderResourceIds ??
                defaultVisibleHeaderResourceIds)
            .toSet();
    return [
      for (final id in order)
        if (visible.contains(id)) id,
    ];
  }

  bool _visibleTimerNeedsTick(LayoutSettingsController? controller) {
    var ids = _orderedDisplayIds(controller);
    if (widget.layout == ResourceBarLayout.grid && _gridCollapsed(controller)) {
      ids = _collapsedGridIds(ids, controller);
    }
    if (widget.nosakiSparkleStartedAt != null &&
        ids.contains(headerNosakiTimerId)) {
      return true;
    }
    return widget.anchorageRepairStartedAt != null &&
        ids.contains(headerAnchorageTimerId) &&
        AnchorageRepairCalculator.hasReadyFleet(widget.state);
  }

  // Settings and editor changes must update the subscription as well as the
  // displayed items. Re-enabling reads the scope's current absolute time.
  Widget _buildWithClock(LayoutSettingsController? controller) =>
      SecondTickBuilder(
        enabled: _visibleTimerNeedsTick(controller),
        builder: (context, now, _) {
          _now = now;
          return _buildBar(controller);
        },
      );

  Widget _buildBar(LayoutSettingsController? controller) {
    final uiSize =
        widget.uiSize ?? controller?.uiDisplaySize ?? UiDisplaySize.normal;
    final isCompact = uiSize.isCompactOrSmaller;
    final barHeight = headerCapsuleHeight(uiSize);
    final separatorWidth = isCompact && !uiSize.isMinimal ? 5.0 : 6.0;
    final resourceScale = UiScale.of(context);

    final visible =
        (controller?.visibleHeaderResourceIds ??
                defaultVisibleHeaderResourceIds)
            .toSet();
    final isEditing = _editing && controller?.uiLocked != true;
    final ids = _orderedDisplayIds(controller);
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    if (widget.layout == ResourceBarLayout.grid) {
      return _buildGrid(
        ids,
        controller: controller,
        l10n: l10n,
        uiSize: uiSize,
      );
    }
    if (widget.layout == ResourceBarLayout.staticStrip && !isEditing) {
      return _HeaderFlatStripScope(
        enabled: widget.flatStyle,
        child: _buildStaticStrip(
          ids,
          controller: controller,
          l10n: l10n,
          uiSize: uiSize,
          separatorWidth: separatorWidth,
        ),
      );
    }
    return _HeaderFlatStripScope(
      enabled: widget.flatStyle,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: SizedBox(
          height: barHeight,
          child: isEditing
              ? Row(
                  key: const Key('header-resource-edit-mode'),
                  children: [
                    _EditButton(
                      key: const Key('header-resource-reset'),
                      icon: Icons.restart_alt_rounded,
                      tooltip: l10n.restoreDefaultOrder,
                      size: barHeight,
                      iconSize: isCompact ? 16 : 18,
                      onPressed: controller?.resetHeaderResources,
                    ),
                    const SizedBox(width: 4),
                    _EditButton(
                      key: const Key('header-resource-edit-done'),
                      icon: Icons.check_rounded,
                      tooltip: l10n.editDone,
                      size: barHeight,
                      iconSize: isCompact ? 16 : 18,
                      onPressed: () => setState(() => _editing = false),
                    ),
                    const SizedBox(width: 4),
                    _EditButton(
                      key: const Key('header-resource-filter'),
                      icon: Icons.filter_alt_rounded,
                      tooltip: l10n.filterVisibleItems,
                      size: barHeight,
                      iconSize: isCompact ? 16 : 18,
                      onPressed: controller == null
                          ? null
                          : () => _showResourceFilter(controller),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      // ReorderableListView measures drag positions in physical
                      // coordinates; scale its items rather than its viewport.
                      child: UiScale(
                        scale: 1,
                        child: ReorderableListView.builder(
                          scrollController: _scrollController,
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.horizontal,
                          buildDefaultDragHandles: false,
                          itemCount: ids.length,
                          onReorderItem: (oldIndex, newIndex) {
                            if (controller == null) return;
                            final reordered = List<String>.from(ids);
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(
                              newIndex.clamp(0, reordered.length),
                              item,
                            );
                            controller.setHeaderResourceOrder(reordered);
                          },
                          itemBuilder: (context, index) {
                            final id = ids[index];
                            return UiScale(
                              key: ValueKey('header-resource-edit-$id'),
                              scale: resourceScale,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index + 1 < ids.length
                                      ? separatorWidth
                                      : 0,
                                ),
                                child: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: _buildEditableItem(
                                    id,
                                    visible: visible.contains(id),
                                    uiSize: uiSize,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  controller: _scrollController,
                  key: const Key('header-resource-list'),
                  padding: EdgeInsets.zero,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  itemCount: ids.length,
                  separatorBuilder: (context, index) => _stripSeparator(
                    context,
                    width: separatorWidth,
                    nextId: ids[index + 1],
                  ),
                  itemBuilder: (context, index) {
                    final id = ids[index];
                    return _buildInteractiveItem(
                      id,
                      controller: controller,
                      l10n: l10n,
                      uiSize: uiSize,
                      width: uiSize.isMinimal
                          ? _stripNaturalWidth(context, id, uiSize: uiSize)
                          : _stripItemWidth(id, isCompact),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _stripSeparator(
    BuildContext context, {
    required double width,
    required String nextId,
  }) => SizedBox(
    width: width,
    child: widget.flatStyle
        ? Center(
            child: Container(
              key: Key('header-resource-divider-before-$nextId'),
              width: 1,
              height: 14,
              color: appColor(context, const Color(0xff315064)),
            ),
          )
        : null,
  );

  static const double _gridSpacing = 4;
  static const int _gridColumns = 4;
  static const double _gridRunSpacing = 2;
  static const double _gridToggleExtent = 24;
  static const double _gridToggleMaxOverhang = 8;

  // 13dp 图标 + 2dp 间隙 + 40dp 数值位：六位数值缩放仍在 0.9 以上。
  static const double _gridMinReadableCellWidth = 55;

  static bool _isWideGridItem(String id) =>
      id == headerSenkaId ||
      id == headerAnchorageTimerId ||
      id == headerNosakiTimerId ||
      id == headerFrameRefreshId ||
      id == headerGameRefreshId ||
      id == headerShipCapacityId ||
      id == headerEquipmentCapacityId;

  static List<String> _defaultCollapsedGridIds(List<String> ids) =>
      ids.where((id) => !_isWideGridItem(id)).take(_gridColumns).toList();

  /// 折叠后显示的项，按 [ids] 的顺序；用户没选过时取前 4 个普通资源。
  static List<String> _collapsedGridIds(
    List<String> ids,
    LayoutSettingsController? controller,
  ) {
    final chosen = controller?.collapsedPanelResourceIds?.toSet();
    if (chosen == null) return _defaultCollapsedGridIds(ids);
    return [
      for (final id in ids)
        if (chosen.contains(id)) id,
    ];
  }

  bool _localGridCollapsed = false;

  bool _gridCollapsed(LayoutSettingsController? controller) =>
      controller?.dashboardCardCollapsed.contains(panelResourcesCollapseId) ??
      _localGridCollapsed;

  void _toggleGridCollapsed(LayoutSettingsController? controller) {
    if (controller == null) {
      setState(() => _localGridCollapsed = !_localGridCollapsed);
    } else {
      controller.toggleDashboardCardCollapsed(panelResourcesCollapseId);
    }
  }

  static String? _gridPartner(String id) => switch (id) {
    headerAnchorageTimerId => headerNosakiTimerId,
    headerNosakiTimerId => headerAnchorageTimerId,
    headerShipCapacityId => headerEquipmentCapacityId,
    headerEquipmentCapacityId => headerShipCapacityId,
    _ => null,
  };

  // 宽项和普通资源分组成行，换类时另起一行，两类项都保持用户排的顺序。宽项按
  // 自然宽度贪心装行（各行可用宽度因圆角内缩而不同），相邻的泊地与野埼、舰娘与
  // 装备容量作为一个整体装行，免得被行尾截成两半；一整行都放不下这一对时才拆开。
  // 普通资源按列数分行，列能上下对齐。
  static List<List<String>> _gridRows(
    List<String> ids,
    int columns, {
    required double Function(int row) rowWidth,
    required double Function(String id) naturalWidth,
  }) {
    final rows = <List<String>>[];
    var row = <String>[];
    var used = 0.0;
    void flush() {
      if (row.isEmpty) return;
      rows.add(row);
      row = <String>[];
      used = 0;
    }

    void addWide(List<String> unit) {
      final width =
          unit.fold(0.0, (sum, id) => sum + naturalWidth(id)) +
          _gridSpacing * (unit.length - 1);
      if (row.isNotEmpty &&
          (!_isWideGridItem(row.first) ||
              used + _gridSpacing + width > rowWidth(rows.length))) {
        flush();
      }
      if (unit.length > 1 && width > rowWidth(rows.length)) {
        for (final id in unit) {
          addWide([id]);
        }
        return;
      }
      used = (row.isEmpty ? 0 : used + _gridSpacing) + width;
      row.addAll(unit);
    }

    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      if (_isWideGridItem(id)) {
        final paired = i + 1 < ids.length && ids[i + 1] == _gridPartner(id);
        addWide(paired ? [id, ids[++i]] : [id]);
        continue;
      }
      if (row.isNotEmpty &&
          (_isWideGridItem(row.first) || row.length == columns)) {
        flush();
      }
      row.add(id);
    }
    flush();
    return rows;
  }

  /// 网格项内容不缩放时需要的宽度。
  double _gridNaturalWidth(
    BuildContext context,
    String id, {
    required HeaderUiSize uiSize,
  }) {
    if (id == headerFrameRefreshId || id == headerGameRefreshId) {
      return _HeaderRefreshPill(
        id: id,
        uiSize: uiSize,
      ).gridNaturalWidth(context);
    }
    final wide = _buildGridWideItem(id);
    assert(wide != null, 'no grid natural width for $id');
    return wide?.naturalWidth(context) ?? 0;
  }

  Widget _buildGrid(
    List<String> ids, {
    required LayoutSettingsController? controller,
    required AppLocalizations l10n,
    required HeaderUiSize uiSize,
  }) {
    final collapsed = _gridCollapsed(controller);
    final padding = widget.gridPadding;
    final radii = widget.gridCornerRadii;
    // 极简游戏页没有顶栏，网格顶边就是屏幕顶边。圆弧在每行图标顶线处的切入量各
    // 不相同：大圆角下首行要让得比 45° 的固定量多，后几行则几乎不必让。
    ({double left, double right}) cornerInsets(int row) {
      final iconTop =
          padding.top +
          row * (_headerGridItemHeight + _gridRunSpacing) +
          (_headerGridItemHeight - _headerGridIconSize) / 2;
      return (
        left: cornerInsetAt(radii.left, iconTop),
        right: cornerInsetAt(radii.right, iconTop),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(0.0, constraints.maxWidth - padding.horizontal);
        double rowWidth(int row) {
          final insets = cornerInsets(row);
          return math.max(0.0, width - insets.left - insets.right);
        }

        final naturalWidths = <String, double>{};
        double naturalWidth(String id) => naturalWidths[id] ??=
            _gridNaturalWidth(context, id, uiSize: uiSize);

        double plainCellWidth(int row, int columns) => math.max(
          0.0,
          (rowWidth(row) - _gridSpacing * (columns - 1)) / columns,
        );

        var columns = _gridColumns;
        final shown = collapsed ? _collapsedGridIds(ids, controller) : ids;
        List<List<String>> packRows() => _gridRows(
          shown,
          columns,
          rowWidth: rowWidth,
          naturalWidth: naturalWidth,
        );
        var rows = packRows();
        if (collapsed) {
          // 折叠后行数少、靠近网格顶边，屏幕圆角切得多；普通资源的首行挤不下
          // 可读的数值就改成两列。
          final plainRow = rows.indexWhere(
            (row) => !_isWideGridItem(row.first),
          );
          if (plainRow >= 0 &&
              rows[plainRow].length > 2 &&
              plainCellWidth(plainRow, columns) < _gridMinReadableCellWidth) {
            columns = 2;
            rows = packRows();
          }
        }
        // 折叠按钮压在末行右端，向右伸进留白（至多 8）以少占末格；点击框必须留
        // 在 Stack 内才能被点到，所以伸出量受末行右侧留白限制。
        final toggleRight =
            padding.right + cornerInsets(math.max(0, rows.length - 1)).right;
        final toggleOverhang = math.min(_gridToggleMaxOverhang, toggleRight);
        final toggleReserve = _gridToggleExtent - toggleOverhang;

        Widget buildRow(int index) {
          final row = rows[index];
          final last = index == rows.length - 1;
          final available = rowWidth(index);
          final List<double> cellWidths;
          if (_isWideGridItem(row.first)) {
            // 余量平分给各格让行仍满宽；宽项行总是满的，是末行时要给按钮让位。
            final natural = [for (final id in row) naturalWidth(id)];
            final used =
                natural.fold(0.0, (sum, w) => sum + w) +
                _gridSpacing * (row.length - 1);
            final extra =
                (available - (last ? toggleReserve : 0) - used) / row.length;
            cellWidths = [for (final w in natural) math.max(0.0, w + extra)];
          } else {
            final cell = plainCellWidth(index, columns);
            // 末行没排满时按钮落在空位里，排满了才让末格让出按钮的位置。
            final reserve = last && row.length == columns ? toggleReserve : 0.0;
            cellWidths = [
              for (var i = 0; i < row.length; i++)
                i == row.length - 1 ? math.max(0.0, cell - reserve) : cell,
            ];
          }
          return Padding(
            padding: EdgeInsets.only(left: cornerInsets(index).left),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gridSpacing),
                  _buildInteractiveItem(
                    row[i],
                    controller: controller,
                    l10n: l10n,
                    uiSize: uiSize,
                    width: cellWidths[i],
                  ),
                ],
              ],
            ),
          );
        }

        return Stack(
          key: const Key('information-panel-resources'),
          children: [
            Padding(
              padding: padding,
              child: _HeaderGridScope(
                // 折叠后可能一行都没有（只剩宽项或全部隐藏），仍要留出完整的
                // 按钮高度，否则按钮被 Stack 裁掉就再也展不开。
                child: Container(
                  width: width,
                  constraints: BoxConstraints(
                    minHeight: rows.isEmpty ? _gridToggleExtent : 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: _gridRunSpacing),
                        buildRow(i),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: toggleRight - toggleOverhang,
              bottom: padding.bottom,
              child: _buildGridToggle(
                controller,
                collapsed: collapsed,
                l10n: l10n,
                iconInset: toggleOverhang,
              ),
            ),
          ],
        );
      },
    );
  }

  // 折叠与信息栏模块一样不受界面锁影响：锁只禁止改布局，不禁止收起内容。
  Widget _buildGridToggle(
    LayoutSettingsController? controller, {
    required bool collapsed,
    required AppLocalizations l10n,
    required double iconInset,
  }) {
    // 图标右缘与各行右缘对齐，伸进内边距的只是点击框。
    return FlatCollapseChevron(
      key: const Key('information-panel-resources-toggle'),
      collapsed: collapsed,
      label: collapsed
          ? l10n.panelResourcesExpand
          : l10n.panelResourcesCollapse,
      onTap: () => _toggleGridCollapsed(controller),
      width: _gridToggleExtent,
      // 点击框贴着末行底边，比 20dp 的行高出 4dp；图标对齐末行的中线。
      iconAlignment: const Alignment(1, 4 / 9),
      iconInset: iconInset,
    );
  }

  Widget _buildStaticStrip(
    List<String> ids, {
    required LayoutSettingsController? controller,
    required AppLocalizations l10n,
    required HeaderUiSize uiSize,
    required double separatorWidth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barHeight = headerCapsuleHeight(uiSize);
        final height = constraints.hasBoundedHeight
            ? math.min(constraints.maxHeight, barHeight)
            : barHeight;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            key: const Key('header-resource-line'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < ids.length; i++) ...[
                if (i > 0)
                  _stripSeparator(
                    context,
                    width: separatorWidth,
                    nextId: ids[i],
                  ),
                SizedBox(
                  height: height,
                  child: _buildInteractiveItem(
                    ids[i],
                    controller: controller,
                    l10n: l10n,
                    uiSize: uiSize,
                    width: _stripNaturalWidth(context, ids[i], uiSize: uiSize),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 横条项按实际渲染的横条样式测出的不缩放宽度。
  double _stripNaturalWidth(
    BuildContext context,
    String id, {
    required HeaderUiSize uiSize,
  }) {
    if (_buildDisplayItem(id, uiSize: uiSize) case final _NaturallySized item) {
      return item.naturalWidth(context);
    }
    assert(false, 'no strip natural width for $id');
    return _stripItemWidth(id, uiSize.isCompactOrSmaller);
  }

  double _stripItemWidth(String id, bool isCompact) => switch (id) {
    headerSenkaId => isCompact ? 132 : 142,
    headerAnchorageTimerId => isCompact ? 118 : 128,
    headerNosakiTimerId => isCompact ? 118 : 128,
    headerFrameRefreshId || headerGameRefreshId => isCompact ? 88 : 98,
    headerShipCapacityId => isCompact ? 108 : 118,
    headerEquipmentCapacityId => isCompact ? 126 : 138,
    _ => isCompact ? 74 : 82,
  };

  Widget _buildInteractiveItem(
    String id, {
    required LayoutSettingsController? controller,
    required AppLocalizations l10n,
    required HeaderUiSize uiSize,
    required double width,
  }) {
    return GestureDetector(
      key: Key('header-resource-$id'),
      behavior: HitTestBehavior.opaque,
      onTap: id == headerFurnitureCoinId
          ? _toggleTheoreticalFurnitureCoins
          : _furnitureBoxCoinRates.containsKey(id)
          ? () => _toggleFurnitureBoxCoinMode(id)
          : switch (id) {
              headerSenkaId => widget.onSenkaTap,
              headerAnchorageTimerId => widget.onAnchorageTimerTap,
              headerNosakiTimerId => widget.onNosakiTimerTap,
              headerFrameRefreshId => widget.onFrameRefreshTap,
              headerGameRefreshId => widget.onGameRefreshTap,
              _ => null,
            },
      onLongPress: () {
        if (controller?.uiLocked == true) {
          TopNotice.show(context, message: l10n.uiLockedToast);
        } else if (widget.layout != ResourceBarLayout.grid) {
          setState(() => _editing = true);
        } else if (controller != null) {
          _showCollapsedItemsPicker(controller);
        }
      },
      child: Tooltip(
        message: switch (id) {
          headerSenkaId => fleetText(context, '战果'),
          headerAnchorageTimerId => fleetText(context, '泊地修理计时'),
          headerNosakiTimerId => fleetText(context, '野埼刷闪计时'),
          headerFrameRefreshId => l10n.frameRefreshShortcutLabel,
          headerGameRefreshId => l10n.advanceWarningReloadGame,
          headerShipCapacityId => l10n.shipGirl,
          headerEquipmentCapacityId => l10n.equipment,
          _ => fleetText(context, headerResourceById[id]!.label),
        },
        triggerMode:
            id == headerSenkaId ||
                id == headerAnchorageTimerId ||
                id == headerNosakiTimerId ||
                id == headerFrameRefreshId ||
                id == headerGameRefreshId ||
                id == headerFurnitureCoinId ||
                _furnitureBoxCoinRates.containsKey(id)
            ? TooltipTriggerMode.manual
            : TooltipTriggerMode.tap,
        child: SizedBox(
          width: width,
          child: _buildDisplayItem(id, uiSize: uiSize),
        ),
      ),
    );
  }

  _HeaderGridValue? _buildGridWideItem(String id) {
    const dim = Color(0xff9fb3bf);
    const bright = Color(0xffdce6eb);
    switch (id) {
      case headerSenkaId:
        return _HeaderGridValue(
          key: const Key('header-senka-summary'),
          icon: Icons.emoji_events_rounded,
          label: fleetText(context, '战果'),
          value: '${_formatSenka(widget.senka)}(#${widget.rank ?? '--'})',
          color: const Color(0xffe0b25c),
        );
      case headerAnchorageTimerId:
        final elapsed = _anchorageElapsed;
        return _HeaderGridValue(
          key: const Key('header-anchorage-timer-summary'),
          icon: Icons.anchor,
          label: fleetText(context, '泊地修理计时'),
          value: _gridTimerText(elapsed),
          color: elapsed == '--:--:--' ? dim : bright,
        );
      case headerNosakiTimerId:
        final elapsed = _nosakiElapsed;
        return _HeaderGridValue(
          key: const Key('header-nosaki-timer-summary'),
          icon: Icons.auto_awesome,
          label: fleetText(context, '野埼刷闪计时'),
          value: _gridTimerText(elapsed),
          color: elapsed == '--:--:--' ? dim : bright,
        );
      case headerShipCapacityId || headerEquipmentCapacityId:
        final ships = id == headerShipCapacityId;
        final capacity = _capacity(id);
        return _HeaderGridValue(
          key: Key(
            ships ? 'header-ship-capacity' : 'header-equipment-capacity',
          ),
          icon: ships
              ? Icons.directions_boat_filled_rounded
              : Icons.build_rounded,
          label: capacity.label,
          value: '${capacity.current ?? '—'}/${capacity.maximum ?? '—'}',
          color: bright,
        );
    }
    return null;
  }

  // 空闲时网格只留短横线，省下的宽度让别的宽项能挤进同一行。
  static String _gridTimerText(String elapsed) =>
      elapsed == '--:--:--' ? '--' : elapsed;

  Widget _buildDisplayItem(
    String id, {
    HeaderUiSize uiSize = HeaderUiSize.normal,
  }) {
    if (widget.layout == ResourceBarLayout.grid) {
      final wide = _buildGridWideItem(id);
      if (wide != null) return wide;
    }
    if (id == headerSenkaId) {
      return _HeaderSenkaSummary(
        senka: widget.senka,
        rank: widget.rank,
        uiSize: uiSize,
      );
    }
    if (id == headerAnchorageTimerId) {
      return _HeaderAnchorageTimerSummary(
        elapsed: _anchorageElapsed,
        uiSize: uiSize,
      );
    }
    if (id == headerNosakiTimerId) {
      return _HeaderNosakiTimerSummary(elapsed: _nosakiElapsed, uiSize: uiSize);
    }
    if (id == headerFrameRefreshId || id == headerGameRefreshId) {
      return _HeaderRefreshPill(id: id, uiSize: uiSize);
    }
    if (id == headerShipCapacityId || id == headerEquipmentCapacityId) {
      return _buildCapacityPill(id, uiSize: uiSize);
    }
    final spec = headerResourceById[id]!;
    return _HeaderResourceItem(
      spec: spec,
      value: _headerResourceValue(id, spec),
      valuePrefix: id == headerFurnitureCoinId && _showTheoreticalFurnitureCoins
          ? '≈'
          : '',
      showFurnitureCoinSuffix: _furnitureBoxCoinModeIds.contains(id),
      uiSize: uiSize,
    );
  }

  Widget _buildEditableItem(
    String id, {
    required bool visible,
    HeaderUiSize uiSize = HeaderUiSize.normal,
  }) {
    final isCompact = uiSize.isCompactOrSmaller;
    if (id == headerSenkaId) {
      return _EditableHeaderSenkaItem(
        senka: widget.senka,
        rank: widget.rank,
        visible: visible,
        uiSize: uiSize,
      );
    }
    if (id == headerAnchorageTimerId) {
      return _EditableHeaderAnchorageTimerItem(
        elapsed: _anchorageElapsed,
        visible: visible,
        uiSize: uiSize,
      );
    }
    if (id == headerNosakiTimerId) {
      return _EditableHeaderNosakiTimerItem(
        elapsed: _nosakiElapsed,
        visible: visible,
        uiSize: uiSize,
      );
    }
    if (id == headerFrameRefreshId || id == headerGameRefreshId) {
      return _EditableHeaderCapacityItem(
        width: isCompact ? 88 : 98,
        visible: visible,
        child: _HeaderRefreshPill(id: id, uiSize: uiSize),
      );
    }
    if (id == headerShipCapacityId || id == headerEquipmentCapacityId) {
      return _EditableHeaderCapacityItem(
        width: id == headerShipCapacityId
            ? (isCompact ? 108 : 118)
            : (isCompact ? 126 : 138),
        visible: visible,
        child: _buildCapacityPill(id, uiSize: uiSize),
      );
    }
    final spec = headerResourceById[id]!;
    return _EditableHeaderResourceItem(
      spec: spec,
      value: _headerResourceValue(id, spec),
      valuePrefix: id == headerFurnitureCoinId && _showTheoreticalFurnitureCoins
          ? '≈'
          : '',
      showFurnitureCoinSuffix: _furnitureBoxCoinModeIds.contains(id),
      visible: visible,
      uiSize: uiSize,
    );
  }

  ({String label, int? current, int? maximum}) _capacity(String id) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final ships = id == headerShipCapacityId;
    return (
      label: ships ? l10n.shipGirl : l10n.equipment,
      current: widget.state.hasPortData
          ? (ships
                ? widget.state.ships.length
                : widget.state.equipmentCapacityUsed)
          : null,
      maximum: ships
          ? widget.state.maxShipCount
          : widget.state.maxEquipmentCount,
    );
  }

  Widget _buildCapacityPill(
    String id, {
    HeaderUiSize uiSize = HeaderUiSize.normal,
  }) {
    final capacity = _capacity(id);
    return _HeaderCapacityPill(
      key: Key(
        id == headerShipCapacityId
            ? 'header-ship-capacity'
            : 'header-equipment-capacity',
      ),
      label: capacity.label,
      current: capacity.current,
      maximum: capacity.maximum,
      uiSize: uiSize,
    );
  }

  _ResourceChecklistData _checklistData() => _ResourceChecklistData(
    state: widget.state,
    senka: widget.senka,
    rank: widget.rank,
    anchorageRepairStartedAt: widget.anchorageRepairStartedAt,
    nosakiSparkleStartedAt: widget.nosakiSparkleStartedAt,
  );

  Future<void> _showResourceFilter(LayoutSettingsController controller) {
    if (_resourceChecklist?.isActive == true) return Future<void>.value();
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return _trackResourceChecklist(
      _presentResourceChecklist(
        context: context,
        controller: controller,
        title: l10n.selectHeaderVisibleItems,
        kind: 'headerResources',
        ids: () => controller.headerResourceOrder,
        checked: () => controller.visibleHeaderResourceIds.toSet(),
        onToggle: controller.toggleHeaderResourceVisible,
        data: _checklistData,
        valueChanges: _checklistValueChanges,
      ),
    );
  }

  Future<void> _showCollapsedItemsPicker(LayoutSettingsController controller) {
    if (_resourceChecklist?.isActive == true) return Future<void>.value();
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    List<String> visibleIds() {
      final visible = controller.visibleHeaderResourceIds.toSet();
      return [
        for (final id in controller.headerResourceOrder)
          if (visible.contains(id)) id,
      ];
    }

    Future<void> reset() => controller.setCollapsedPanelResourceIds(null);
    return _trackResourceChecklist(
      _presentResourceChecklist(
        context: context,
        controller: controller,
        key: const Key('panel-resource-collapsed-dialog'),
        title: l10n.panelResourcesCollapsedItems,
        kind: 'collapsedResources',
        ids: visibleIds,
        checked: () => _collapsedGridIds(visibleIds(), controller).toSet(),
        onToggle: (id) {
          final next = {
            ...controller.collapsedPanelResourceIds ??
                _defaultCollapsedGridIds(visibleIds()),
          };
          if (!next.remove(id)) next.add(id);
          return controller.setCollapsedPanelResourceIds(next.toList());
        },
        onReset: reset,
        resetLabel: l10n.panelResourcesCollapsedItemsReset,
        data: _checklistData,
        valueChanges: _checklistValueChanges,
      ),
    );
  }
}

/// The settings entry can open the same editor even when the header is hidden.
/// The owner cancels the returned presentation when its own lifetime ends.
GameReminderDialogPresentation? showHeaderResourceChecklist({
  required BuildContext context,
  required LayoutSettingsController controller,
  required GameState Function() stateProvider,
  double? senka,
  int? rank,
  DateTime? anchorageRepairStartedAt,
  DateTime? nosakiSparkleStartedAt,
  double? Function()? senkaProvider,
  int? Function()? rankProvider,
  DateTime? Function()? anchorageRepairStartedAtProvider,
  DateTime? Function()? nosakiSparkleStartedAtProvider,
  Listenable? valueChanges,
  bool? nativeActivity,
  bool? presentationEnabled,
  NativeGameResourceChecklistPort? nativeChecklistPort,
}) {
  if (!context.mounted) return null;
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  return _presentResourceChecklist(
    context: context,
    controller: controller,
    title: l10n.selectHeaderVisibleItems,
    kind: 'headerResources',
    ids: () => controller.headerResourceOrder,
    checked: () => controller.visibleHeaderResourceIds.toSet(),
    onToggle: controller.toggleHeaderResourceVisible,
    data: () => _ResourceChecklistData(
      state: stateProvider(),
      senka: senkaProvider != null ? senkaProvider() : senka,
      rank: rankProvider != null ? rankProvider() : rank,
      anchorageRepairStartedAt: anchorageRepairStartedAtProvider != null
          ? anchorageRepairStartedAtProvider()
          : anchorageRepairStartedAt,
      nosakiSparkleStartedAt: nosakiSparkleStartedAtProvider != null
          ? nosakiSparkleStartedAtProvider()
          : nosakiSparkleStartedAt,
    ),
    valueChanges: valueChanges,
    nativeActivity: nativeActivity,
    presentationEnabled: presentationEnabled,
    nativeChecklistPort: nativeChecklistPort,
  );
}

GameReminderDialogPresentation? _presentResourceChecklist({
  required BuildContext context,
  required LayoutSettingsController controller,
  required String title,
  required String kind,
  required List<String> Function() ids,
  required Set<String> Function() checked,
  required FutureOr<void> Function(String) onToggle,
  required _ResourceChecklistData Function() data,
  Key? key,
  FutureOr<void> Function()? onReset,
  String? resetLabel,
  Listenable? valueChanges,
  bool? nativeActivity,
  bool? presentationEnabled,
  NativeGameResourceChecklistPort? nativeChecklistPort,
}) {
  if (!context.mounted) return null;
  final scope = GameDialogPresentationScope.maybeOf(context);
  if (controller.uiLocked ||
      !(presentationEnabled ?? scope?.presentationEnabled ?? true)) {
    return null;
  }
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  final revision = ValueNotifier(0);
  GameReminderDialogPresentation? presentation;
  bool canEdit() =>
      context.mounted && !controller.uiLocked && presentation?.isActive == true;
  void applyChange(FutureOr<void> Function() change) {
    unawaited(
      Future<void>.sync(change).catchError(
        (Object error) => debugPrint('Resource checklist save failed: $error'),
      ),
    );
  }

  final native = (nativeActivity ?? scope?.nativeActivity ?? false)
      ? NativeGameResourceChecklistAdapter(
          kind: kind,
          port:
              nativeChecklistPort ??
              scope?.nativeChecklistPort ??
              const MethodChannelNativeGameResourceChecklistPort(),
          items: () {
            final values = data();
            final selected = checked();
            return [
              for (final id in ids())
                values.item(context, id, checked: selected.contains(id)),
            ];
          },
          isCurrent: canEdit,
          onToggle: onToggle,
          onReset: onReset,
          doneLabel: l10n.editDone,
          resetLabel: resetLabel,
        )
      : null;
  var disposed = false;
  void refresh() {
    if (disposed) return;
    if (!context.mounted || controller.uiLocked) {
      presentation?.cancel();
      return;
    }
    revision.value++;
    native?.updateCurrent();
  }

  controller.addListener(refresh);
  if (!identical(valueChanges, controller)) valueChanges?.addListener(refresh);
  // A timer can start while the editor is already open. Keep this short-lived
  // presentation subscribed until its owner or input protection completes.
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  presentation = showGameReminderDialog(
    context: context,
    kind: kind,
    title: title,
    message: '',
    nativePort: native,
    builder: (dialogContext, acknowledge) => Dialog(
      key: key ?? const Key('header-resource-filter-dialog'),
      backgroundColor: appColor(dialogContext, const Color(0xff102532)),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: appColor(dialogContext, const Color(0xff315064)),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: appColor(dialogContext, const Color(0xffe0b25c)),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onReset != null)
                    IconButton(
                      key: const Key('panel-resource-collapsed-reset'),
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      tooltip: resetLabel,
                      onPressed: () {
                        if (canEdit()) applyChange(onReset);
                      },
                      icon: Icon(
                        Icons.restart_alt_rounded,
                        color: appColor(dialogContext, const Color(0xffe0b25c)),
                      ),
                    ),
                  IconButton(
                    key: const Key('header-resource-filter-done'),
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    tooltip: l10n.editDone,
                    onPressed: acknowledge,
                    icon: Icon(
                      Icons.check_rounded,
                      color: appColor(dialogContext, const Color(0xffe0b25c)),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: appColor(dialogContext, const Color(0xff294052)),
            ),
            Flexible(
              child: AnimatedBuilder(
                animation: revision,
                builder: (context, _) {
                  final values = data();
                  final visible = ids();
                  final selected = checked();
                  return ListView.builder(
                    key: const Key('header-resource-filter-list'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final id = visible[index];
                      return values.row(
                        context,
                        id,
                        checked: selected.contains(id),
                        onChanged: () {
                          if (canEdit()) applyChange(() => onToggle(id));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  unawaited(
    presentation.completed.then((_) {
      disposed = true;
      timer.cancel();
      controller.removeListener(refresh);
      if (!identical(valueChanges, controller)) {
        valueChanges?.removeListener(refresh);
      }
      native?.dispose();
      revision.dispose();
    }),
  );
  return presentation;
}

final class _ResourceChecklistData {
  const _ResourceChecklistData({
    required this.state,
    this.senka,
    this.rank,
    this.anchorageRepairStartedAt,
    this.nosakiSparkleStartedAt,
  });
  final GameState state;
  final double? senka;
  final int? rank;
  final DateTime? anchorageRepairStartedAt;
  final DateTime? nosakiSparkleStartedAt;

  IconData? _icon(String id) => switch (id) {
    headerSenkaId => Icons.emoji_events_rounded,
    headerAnchorageTimerId => Icons.anchor_rounded,
    headerNosakiTimerId => Icons.restaurant_rounded,
    headerFrameRefreshId || headerGameRefreshId => Icons.refresh_rounded,
    headerShipCapacityId => Icons.directions_boat_filled_rounded,
    headerEquipmentCapacityId => Icons.build_rounded,
    _ => null,
  };

  Color _iconColor(BuildContext context, String id) => appColor(
    context,
    id == headerSenkaId ? const Color(0xffe0b25c) : const Color(0xff9fb3bf),
  );

  String get anchorageElapsed => !AnchorageRepairCalculator.hasReadyFleet(state)
      ? '--:--:--'
      : formatAnchorageRepairElapsed(
          anchorageRepairStartedAt,
          DateTime.now().toUtc(),
        );
  String get nosakiElapsed => formatNosakiSparkleElapsed(
    nosakiSparkleStartedAt,
    DateTime.now().toUtc(),
  );

  Map<String, Object?> item(
    BuildContext context,
    String id, {
    required bool checked,
  }) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final (label, value) = switch (id) {
      headerSenkaId => (
        fleetText(context, '战果'),
        '${_formatSenka(senka)}（#${rank ?? '--'}）',
      ),
      headerAnchorageTimerId => (fleetText(context, '泊地计时'), anchorageElapsed),
      headerNosakiTimerId => (fleetText(context, '野埼计时'), nosakiElapsed),
      headerFrameRefreshId => (l10n.frameRefreshShortcutLabel, ''),
      headerGameRefreshId => (l10n.advanceWarningReloadGame, ''),
      headerShipCapacityId => (
        l10n.shipGirl,
        '${state.hasPortData ? state.ships.length : '—'} / ${state.maxShipCount ?? '—'}',
      ),
      headerEquipmentCapacityId => (
        l10n.equipment,
        '${state.hasPortData ? state.equipmentCapacityUsed : '—'} / ${state.maxEquipmentCount ?? '—'}',
      ),
      _ => (
        fleetText(context, headerResourceById[id]!.label),
        headerResourceById[id]!.value(state)?.toString() ?? '—',
      ),
    };
    final icon = _icon(id);
    return {
      'id': id,
      'label': label,
      'value': value,
      'checked': checked,
      if (icon == null)
        'iconAsset': headerResourceById[id]!.assetPath
      else ...{
        'iconCodePoint': icon.codePoint,
        'iconColor': _iconColor(context, id).toARGB32(),
      },
    };
  }

  Widget row(
    BuildContext context,
    String id, {
    required bool checked,
    required VoidCallback onChanged,
  }) {
    final values = item(context, id, checked: checked);
    final icon = _icon(id);
    return _HeaderResourceFilterRow(
      id: id,
      label: values['label']! as String,
      value: values['value']! as String,
      icon: icon == null
          ? Image.asset(
              headerResourceById[id]!.assetPath,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            )
          : Icon(icon, size: 20, color: _iconColor(context, id)),
      valueColor: id == headerSenkaId
          ? const Color(0xffe0b25c)
          : [
              headerFrameRefreshId,
              headerGameRefreshId,
              headerShipCapacityId,
              headerEquipmentCapacityId,
            ].contains(id)
          ? const Color(0xffdce6eb)
          : const Color(0xff9fb3bf),
      checked: checked,
      onChanged: onChanged,
    );
  }
}

// 信息栏网格里的资源项没有胶囊，字号也固定，靠它与顶栏 strip 区分。
class _HeaderGridScope extends InheritedWidget {
  const _HeaderGridScope({required super.child});

  @override
  bool updateShouldNotify(_HeaderGridScope oldWidget) => false;
}

class _HeaderFlatStripScope extends InheritedWidget {
  const _HeaderFlatStripScope({required this.enabled, required super.child});

  final bool enabled;

  @override
  bool updateShouldNotify(_HeaderFlatStripScope oldWidget) =>
      enabled != oldWidget.enabled;
}

bool _inHeaderGrid(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_HeaderGridScope>() != null;

const double _headerGridFontSize = 11;

double _headerFontSize(BuildContext context, double stripSize) =>
    _inHeaderGrid(context) ? _headerGridFontSize : stripSize;

// 网格没有胶囊边框要包住，行高贴着 11 号字收紧，省下信息栏的纵向空间。
const double _headerGridItemHeight = 20;

const double _headerGridIconSize = 12;

double _headerTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

// 向上取整再留 1dp，免得测量与实际排版的小数差让数值在格子边上缩放抖动。
double _headerNaturalWidth(double contentWidth) =>
    contentWidth.ceilToDouble() + 1;

/// 能报出内容不缩放时所需宽度的资源项；网格装行和极简横条按它定格宽。
abstract interface class _NaturallySized {
  double naturalWidth(BuildContext context);
}

double _headerStripItemHeight(bool isCompact) => isCompact ? 26 : 30;

double _headerItemHeight(BuildContext context, bool isCompact) =>
    _inHeaderGrid(context)
    ? _headerGridItemHeight
    : _headerStripItemHeight(isCompact);

// 网格按宽项的实际宽度装行，「战果：」这类文字前缀换成小图标，同一行能多放
// 一项；完整名称由外层 Tooltip 和图标的读屏标签提供。
class _HeaderGridValue extends StatelessWidget implements _NaturallySized {
  const _HeaderGridValue({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  static const double _iconGap = 3;

  TextStyle get _style => TextStyle(
    color: color,
    fontSize: _headerGridFontSize,
    fontWeight: FontWeight.w700,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  double naturalWidth(BuildContext context) => _headerNaturalWidth(
    _headerGridIconSize + _iconGap + _headerTextWidth(context, value, _style),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _headerGridItemHeight,
    child: Row(
      children: [
        Icon(
          icon,
          size: _headerGridIconSize,
          color: appColor(context, color),
          semanticLabel: label,
        ),
        const SizedBox(width: _iconGap),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: appTextStyle(context, _style),
            ),
          ),
        ),
      ],
    ),
  );
}

// 极简档的顶栏要把空间让给数值，所以不画胶囊底色和边框。
BoxDecoration? _headerPillDecoration(
  BuildContext context,
  HeaderUiSize uiSize, {
  bool grid = false,
}) {
  if (grid ||
      uiSize.isMinimal ||
      context
              .dependOnInheritedWidgetOfExactType<_HeaderFlatStripScope>()
              ?.enabled ==
          true) {
    return null;
  }
  return BoxDecoration(
    color: appColor(context, const Color(0xff142735)),
    borderRadius: BorderRadius.circular(uiSize.isCompactOrSmaller ? 7 : 8),
    border: Border.all(color: appColor(context, const Color(0xff315064))),
  );
}

class _HeaderRefreshPill extends StatelessWidget implements _NaturallySized {
  const _HeaderRefreshPill({
    required this.id,
    this.uiSize = HeaderUiSize.normal,
  });

  final String id;
  final HeaderUiSize uiSize;

  bool get _isCompact => uiSize.isCompactOrSmaller;
  double get _horizontalPadding => _isCompact ? 6 : 8;
  double get _iconSize => _isCompact ? 15 : 17;
  double get _iconGap => _isCompact ? 3 : 4;

  String _label(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return id == headerFrameRefreshId
        ? l10n.frameRefreshShortcutLabel
        : l10n.advanceWarningReloadGame;
  }

  static TextStyle _style(double fontSize) => TextStyle(
    color: const Color(0xffdce6eb),
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
  );

  double _naturalWidthAt(BuildContext context, double fontSize) =>
      _headerNaturalWidth(
        _horizontalPadding * 2 +
            _iconSize +
            _iconGap +
            _headerTextWidth(context, _label(context), _style(fontSize)),
      );

  double gridNaturalWidth(BuildContext context) =>
      _naturalWidthAt(context, _headerGridFontSize);

  @override
  double naturalWidth(BuildContext context) =>
      _naturalWidthAt(context, _stripFontSize);

  double get _stripFontSize => _isCompact ? 11 : 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('header-$id'),
      height: _headerItemHeight(context, _isCompact),
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: _headerPillDecoration(
        context,
        uiSize,
        grid: _inHeaderGrid(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.refresh_rounded,
            size: _iconSize,
            color: appColor(context, const Color(0xffd4a85f)),
          ),
          SizedBox(width: _iconGap),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _label(context),
                maxLines: 1,
                style: appTextStyle(
                  context,
                  _style(_headerFontSize(context, _stripFontSize)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 横条里只有一行文字的胶囊项；文字和样式在一处，测量与渲染不会走样。
abstract class _HeaderTextPill extends StatelessWidget
    implements _NaturallySized {
  const _HeaderTextPill({super.key, required this.uiSize, this.pillKey});

  final HeaderUiSize uiSize;
  final Key? pillKey;

  String text(BuildContext context);
  Color get color;

  /// 普通、紧凑档的固定宽度；极简档由外层按自然宽度约束。
  double? get width => null;

  bool get _isCompact => uiSize.isCompactOrSmaller;
  double get _horizontalPadding => _isCompact ? 6 : 8;

  TextStyle get _style => TextStyle(
    color: color,
    fontSize: _isCompact ? 11.5 : 12.5,
    fontWeight: FontWeight.w700,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  double naturalWidth(BuildContext context) => _headerNaturalWidth(
    _horizontalPadding * 2 + _headerTextWidth(context, text(context), _style),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: pillKey,
      width: width,
      height: _headerStripItemHeight(_isCompact),
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: _headerPillDecoration(context, uiSize),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text(context),
          maxLines: 1,
          softWrap: false,
          style: appTextStyle(context, _style),
        ),
      ),
    );
  }
}

class _HeaderCapacityPill extends _HeaderTextPill {
  const _HeaderCapacityPill({
    super.key,
    required this.label,
    required this.current,
    required this.maximum,
    super.uiSize = HeaderUiSize.normal,
  });

  final String label;
  final int? current;
  final int? maximum;

  @override
  String text(BuildContext context) =>
      '$label: ${current ?? '—'} / ${maximum ?? '—'}';

  @override
  Color get color => const Color(0xffdce6eb);
}

String formatAnchorageRepairElapsed(DateTime? startedAt, DateTime now) {
  if (startedAt == null) return '--:--:--';
  final normalizedStart = startedAt.toUtc();
  final normalizedNow = now.toUtc();
  final elapsed = normalizedNow.isBefore(normalizedStart)
      ? Duration.zero
      : normalizedNow.difference(normalizedStart);
  final hours = elapsed.inHours.toString().padLeft(2, '0');
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String formatNosakiSparkleElapsed(DateTime? startedAt, DateTime now) {
  if (startedAt == null) return '--:--:--';
  final normalizedStart = startedAt.toUtc();
  final normalizedNow = now.toUtc();
  final elapsed = normalizedNow.isBefore(normalizedStart)
      ? Duration.zero
      : normalizedNow.difference(normalizedStart);
  final hours = elapsed.inHours.toString().padLeft(2, '0');
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class _HeaderAnchorageTimerSummary extends _HeaderTextPill {
  const _HeaderAnchorageTimerSummary({
    required this.elapsed,
    super.uiSize = HeaderUiSize.normal,
  }) : super(pillKey: const Key('header-anchorage-timer-summary'));

  final String elapsed;

  @override
  String text(BuildContext context) => fleetText(context, '泊地：$elapsed');

  @override
  Color get color =>
      elapsed != '--:--:--' ? const Color(0xffdce6eb) : const Color(0xff9fb3bf);

  @override
  double get width => _isCompact ? 118 : 128;
}

class _HeaderNosakiTimerSummary extends _HeaderTextPill {
  const _HeaderNosakiTimerSummary({
    required this.elapsed,
    super.uiSize = HeaderUiSize.normal,
  }) : super(pillKey: const Key('header-nosaki-timer-summary'));

  final String elapsed;

  @override
  String text(BuildContext context) => fleetText(context, '野埼：$elapsed');

  @override
  Color get color =>
      elapsed != '--:--:--' ? const Color(0xffdce6eb) : const Color(0xff9fb3bf);

  @override
  double get width => _isCompact ? 118 : 128;
}

class _HeaderSenkaSummary extends _HeaderTextPill {
  const _HeaderSenkaSummary({
    required this.senka,
    required this.rank,
    super.uiSize = HeaderUiSize.normal,
  }) : super(pillKey: const Key('header-senka-summary'));

  final double? senka;
  final int? rank;

  @override
  String text(BuildContext context) =>
      fleetText(context, '战果：${_formatSenka(senka)}（#${rank ?? '--'}）');

  @override
  Color get color => const Color(0xffe0b25c);

  @override
  double get width => _isCompact ? 132 : 142;
}

String _formatSenka(double? value) {
  if (value == null) return '--';
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

class _HeaderResourceItem extends StatelessWidget implements _NaturallySized {
  const _HeaderResourceItem({
    required this.spec,
    required this.value,
    this.valuePrefix = '',
    this.showFurnitureCoinSuffix = false,
    this.uiSize = HeaderUiSize.normal,
  });

  final HeaderResourceSpec spec;
  final int? value;
  final String valuePrefix;
  final bool showFurnitureCoinSuffix;
  final HeaderUiSize uiSize;

  bool get _isCompact => uiSize.isCompactOrSmaller;

  // 网格四列很窄，又没有胶囊要留边，去掉内边距、缩小图标，尽量不缩数值。
  ({double padding, double iconSize, double gap}) _metrics(bool grid) => grid
      ? (padding: 0, iconSize: 13, gap: 2)
      : _isCompact
      ? (padding: 4, iconSize: 15, gap: 3)
      : (padding: 5, iconSize: 17, gap: 4);

  String _text(BuildContext context) {
    if (value == null) return '—';
    final suffix = showFurnitureCoinSuffix
        ? fleetText(context, '家具コイン').replaceFirst('家具', '')
        : '';
    return '$valuePrefix$value$suffix';
  }

  TextStyle _style(BuildContext context) => TextStyle(
    color: const Color(0xffdce6eb),
    fontSize: _headerFontSize(context, _isCompact ? 11.5 : 12.5),
    fontWeight: FontWeight.w700,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  double naturalWidth(BuildContext context) {
    final metrics = _metrics(_inHeaderGrid(context));
    return _headerNaturalWidth(
      metrics.padding * 2 +
          metrics.iconSize +
          metrics.gap +
          _headerTextWidth(context, _text(context), _style(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = _inHeaderGrid(context);
    final metrics = _metrics(grid);
    return Container(
      height: _headerItemHeight(context, _isCompact),
      padding: EdgeInsets.symmetric(horizontal: metrics.padding),
      decoration: _headerPillDecoration(context, uiSize, grid: grid),
      child: Row(
        children: [
          Image.asset(
            spec.assetPath,
            width: metrics.iconSize,
            height: metrics.iconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(width: metrics.gap),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.hardEdge,
              child: Text(
                _text(context),
                maxLines: 1,
                style: appTextStyle(context, _style(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableHeaderResourceItem extends StatelessWidget {
  const _EditableHeaderResourceItem({
    required this.spec,
    required this.value,
    required this.valuePrefix,
    required this.showFurnitureCoinSuffix,
    required this.visible,
    this.uiSize = HeaderUiSize.normal,
  });

  final HeaderResourceSpec spec;
  final int? value;
  final String valuePrefix;
  final bool showFurnitureCoinSuffix;
  final bool visible;
  final HeaderUiSize uiSize;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: uiSize.isCompactOrSmaller ? 74 : 82,
      child: _HeaderResourceItem(
        spec: spec,
        value: value,
        valuePrefix: valuePrefix,
        showFurnitureCoinSuffix: showFurnitureCoinSuffix,
        uiSize: uiSize,
      ),
    ),
  );
}

class _EditableHeaderSenkaItem extends StatelessWidget {
  const _EditableHeaderSenkaItem({
    required this.senka,
    required this.rank,
    required this.visible,
    this.uiSize = HeaderUiSize.normal,
  });

  final double? senka;
  final int? rank;
  final bool visible;
  final HeaderUiSize uiSize;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: uiSize.isCompactOrSmaller ? 132 : 142,
      child: _HeaderSenkaSummary(senka: senka, rank: rank, uiSize: uiSize),
    ),
  );
}

class _EditableHeaderAnchorageTimerItem extends StatelessWidget {
  const _EditableHeaderAnchorageTimerItem({
    required this.elapsed,
    required this.visible,
    this.uiSize = HeaderUiSize.normal,
  });

  final String elapsed;
  final bool visible;
  final HeaderUiSize uiSize;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: uiSize.isCompactOrSmaller ? 118 : 128,
      child: _HeaderAnchorageTimerSummary(elapsed: elapsed, uiSize: uiSize),
    ),
  );
}

class _EditableHeaderNosakiTimerItem extends StatelessWidget {
  const _EditableHeaderNosakiTimerItem({
    required this.elapsed,
    required this.visible,
    this.uiSize = HeaderUiSize.normal,
  });

  final String elapsed;
  final bool visible;
  final HeaderUiSize uiSize;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(
      width: uiSize.isCompactOrSmaller ? 118 : 128,
      child: _HeaderNosakiTimerSummary(elapsed: elapsed, uiSize: uiSize),
    ),
  );
}

class _EditableHeaderCapacityItem extends StatelessWidget {
  const _EditableHeaderCapacityItem({
    required this.width,
    required this.visible,
    required this.child,
  });

  final double width;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: visible ? 1 : 0.42,
    child: SizedBox(width: width, child: child),
  );
}

class _HeaderResourceFilterRow extends StatelessWidget {
  const _HeaderResourceFilterRow({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
    required this.checked,
    required this.onChanged,
  });

  final String id;
  final String label;
  final String value;
  final Widget icon;
  final Color valueColor;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final labelStyle = appTextStyle(
      context,
      TextStyle(
        color: appColor(context, const Color(0xffdce6eb)),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
    final valueStyle = appTextStyle(
      context,
      TextStyle(
        color: appColor(context, valueColor),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
    return Material(
      key: Key('header-resource-filter-row-$id'),
      color: appColor(context, Colors.transparent),
      child: InkWell(
        onTap: onChanged,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: Transform.scale(
                    scale: 0.84,
                    child: Checkbox(
                      key: Key('header-resource-visible-$id'),
                      value: checked,
                      onChanged: (_) => onChanged(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
              icon,
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final labelText = Text(label, style: labelStyle);
                      final valueText = Text(value, style: valueStyle);
                      // Keep full-size text readable on narrow screens: long
                      // labels and values flow onto separate lines as needed.
                      final fitsInline =
                          value.isEmpty ||
                          _headerTextWidth(context, label, labelStyle) +
                                  6 +
                                  _headerTextWidth(
                                    context,
                                    value,
                                    valueStyle,
                                  ) <=
                              constraints.maxWidth;
                      if (!fitsInline) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [labelText, valueText],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: labelText),
                          if (value.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            valueText,
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 30,
    this.iconSize = 18,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: IconButton(
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: iconSize,
        color: appColor(context, Color(0xffe0b25c)),
      ),
    ),
  );
}
