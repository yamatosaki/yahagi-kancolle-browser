import '../widgets/app_popup_menu_button.dart';
import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../l10n/app_localizations.dart';
import '../settings/layout_settings_controller.dart';
import '../settings/hd_layout_settings.dart';
import '../settings/ui_display_size.dart';
import '../widgets/top_notice.dart';
import 'hd_dashboard_content.dart';
import 'hd_home_editor.dart';
import 'panel_style.dart';

class HdPortraitGrid extends StatelessWidget {
  const HdPortraitGrid({
    super.key,
    required this.controller,
    required this.editing,
    required this.onEditingChanged,
    required this.cardBuilder,
  });
  final LayoutSettingsController controller;
  final bool editing;
  final ValueChanged<bool> onEditingChanged;
  final Widget Function(String) cardBuilder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final flat = controller.uiDisplaySize.isMinimal;
      final settings = controller.hdSettings;
      final modules = settings.portrait.where(
        (e) => editing || !settings.portraitHidden.contains(e.id),
      );
      final items = modules.toList();
      Widget buildItem(HdBottomModule item) {
        final card = HdModuleColumns(
          columns: item.span,
          child: cardBuilder(item.id),
        );
        if (!editing) return card;
        return DashboardDropTarget(
          key: Key('hd-portrait-target-${item.id}'),
          id: item.id,
          onMove: (id, after) =>
              controller.moveHdPortraitModule(id, item.id, after),
          child: DashboardEditItem(
            id: item.id,
            hidden: settings.portraitHidden.contains(item.id),
            onToggle: () => controller.toggleHdPortraitHidden(item.id),
            action: AppPopupMenuButton<int>(
              key: Key('hd-portrait-width-${item.id}'),
              onSelected: (span) =>
                  controller.setHdPortraitSize(item.id, span ~/ 10, span % 10),
              itemBuilder: (_) => [
                for (final span in [11, 12])
                  CheckedPopupMenuItem(
                    value: span,
                    checked: item.rows * 10 + item.span == span,
                    child: Text('${span ~/ 10}×${span % 10}'),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${item.rows}×${item.span} ▾'),
              ),
            ),
            child: card,
          ),
        );
      }

      final grid = GestureDetector(
        onLongPress: editing
            ? null
            : () {
                if (controller.uiLocked) {
                  final l10n =
                      AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh'));
                  TopNotice.show(context, message: l10n.uiLockedToast);
                  return;
                }
                onEditingChanged(true);
              },
        child: Column(
          key: const Key('hd-portrait-grid'),
          children: [
            if (editing)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    key: const Key('dashboard-edit-reset'),
                    tooltip: AppLocalizations.of(context)!.restoreDefaultOrder,
                    onPressed: controller.resetHdPortraitLayout,
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                  ),
                  IconButton(
                    key: const Key('dashboard-edit-done'),
                    tooltip: AppLocalizations.of(context)!.editDone,
                    onPressed: () => onEditingChanged(false),
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey('hd-portrait-scroll'),
                primary: false,
                padding: const EdgeInsets.all(8),
                child: _PortraitMasonry(
                  spans: [for (final item in items) item.span],
                  ids: [for (final item in items) item.id],
                  editing: editing,
                  children: [
                    for (final item in items)
                      RepaintBoundary(
                        key: ValueKey('hd-portrait-cell-${item.id}'),
                        child: DecoratedBox(
                          decoration: flat
                              ? const BoxDecoration()
                              : BoxDecoration(
                                  color: appColor(
                                    context,
                                    const Color(0xff142735),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: 1,
                            child: buildItem(item),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      return PanelStyleScope(
        style: flat ? PanelStyle.flat : PanelStyle.card,
        child: grid,
      );
    },
  );
}

// Measure natural heights, then align groups. A side below half the height of
// its neighbor can stack one more half-width card; content is never clipped.
class _PortraitMasonry extends MultiChildRenderObjectWidget {
  const _PortraitMasonry({
    required this.spans,
    required this.ids,
    required this.editing,
    required super.children,
  });
  final List<int> spans;
  final List<String> ids;
  final bool editing;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPortraitMasonry(spans, ids, editing);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPortraitMasonry renderObject,
  ) {
    renderObject
      ..ids = ids
      ..editing = editing
      ..spans = spans;
  }
}

class _MasonryParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPortraitMasonry extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MasonryParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MasonryParentData> {
  _RenderPortraitMasonry(this._spans, this.ids, this.editing);
  List<String> ids;
  bool editing;
  Map<String, double>? _naturalHeights;
  List<int> _spans;
  set spans(List<int> value) {
    _spans = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MasonryParentData) {
      child.parentData = _MasonryParentData();
    }
  }

  @override
  void performLayout() {
    final halfWidth = (constraints.maxWidth - 8) / 2;
    final children = <RenderBox>[];
    final heights = <double>[];
    final groupingHeights = <double>[];
    final cache = _naturalHeights ??= <String, double>{};
    var child = firstChild;
    while (child != null) {
      final width = _spans[children.length] == 2
          ? constraints.maxWidth
          : halfWidth;
      child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
      final cacheKey = '${ids[children.length]}:$width';
      if (!editing) cache[cacheKey] = child.size.height;
      final naturalHeight = editing
          ? cache[cacheKey] ?? child.size.height
          : child.size.height;
      children.add(child);
      groupingHeights.add(naturalHeight);
      // Preserve grouping from the normal view, but size the editor from its
      // collapsed controls so the preview stays compact.
      heights.add(child.size.height);
      child = childAfter(child);
    }
    void place(int index, int column, double top, double minHeight) {
      final box = children[index];
      final width = _spans[index] == 2 ? constraints.maxWidth : halfWidth;
      box.layout(
        BoxConstraints(minWidth: width, maxWidth: width, minHeight: minHeight),
        parentUsesSize: true,
      );
      (box.parentData! as _MasonryParentData).offset = Offset(
        column * (halfWidth + 8),
        top,
      );
    }

    var top = 0.0;
    final pending = List<int>.generate(children.length, (i) => i);
    while (pending.isNotEmpty) {
      final left = pending.first;
      if (_spans[left] == 2 || pending.length == 1 || _spans[pending[1]] == 2) {
        place(left, 0, top, heights[left]);
        top += heights[left] + 8;
        pending.removeAt(0);
        continue;
      }
      final right = pending[1];
      final short = groupingHeights[left] < groupingHeights[right]
          ? left
          : right;
      final tall = short == left ? right : left;
      int? next;
      // Do not cross a full-width module. Prefer the next card in the same
      // column when its natural height is below 75% of its neighbor.
      final candidates = <int>[
        if (short == right &&
            pending.length > 3 &&
            _spans[pending[2]] == 1 &&
            _spans[pending[3]] == 1)
          pending[3],
        if (pending.length > 2 && _spans[pending[2]] == 1) pending[2],
      ];
      if (groupingHeights[short] < groupingHeights[tall] * .75 &&
          candidates.isNotEmpty) {
        next = candidates.first;
      }
      var groupHeight = heights[left] > heights[right]
          ? heights[left]
          : heights[right];
      if (next != null) {
        final stackedHeight = heights[short] + 8 + heights[next];
        if (stackedHeight > groupHeight) groupHeight = stackedHeight;
        place(tall, tall == left ? 0 : 1, top, groupHeight);
        place(short, short == left ? 0 : 1, top, heights[short]);
        place(
          next,
          short == left ? 0 : 1,
          top + heights[short] + 8,
          groupHeight - heights[short] - 8,
        );
        pending.remove(next);
      } else {
        place(left, 0, top, groupHeight);
        place(right, 1, top, groupHeight);
      }
      pending.remove(left);
      pending.remove(right);
      top += groupHeight + 8;
    }
    size = constraints.constrain(
      Size(constraints.maxWidth, top > 0 ? top - 8 : 0),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
