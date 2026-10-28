import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'dashboard_presentation_scope.dart';

@immutable
class DashboardTab {
  const DashboardTab({
    required this.id,
    required this.label,
    required this.title,
    this.icon,
    this.badgeCount = 0,
  });

  final String id;
  final String label;
  final String title;
  final IconData? icon;
  final int badgeCount;
}

class DashboardTabs extends StatefulWidget {
  const DashboardTabs({
    super.key = const Key('dashboard-tabs'),
    required this.tabs,
    required this.selectedId,
    required this.onSelected,
    required this.cardBuilder,
    this.onLongPressTab,
    this.contentPadding = EdgeInsets.zero,
    this.notice,
    this.footer,
  });

  final List<DashboardTab> tabs;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onLongPressTab;
  final Widget Function(String id) cardBuilder;
  final EdgeInsetsGeometry contentPadding;
  final Widget? notice;
  final Widget? footer;

  @override
  State<DashboardTabs> createState() => _DashboardTabsState();
}

class _DashboardTabsState extends State<DashboardTabs> {
  final _scrollControllers = <String, ScrollController>{};
  final _tabAnchors = <String, GlobalKey>{};
  final _tabBarController = ScrollController();
  double? _tabBarWidth;
  double? _tabTextSize;
  TextDirection? _tabDirection;
  bool _revealScheduled = false;

  String? get _selectedId => widget.tabs.isEmpty
      ? null
      : widget.tabs.any((tab) => tab.id == widget.selectedId)
      ? widget.selectedId
      : widget.tabs.first.id;

  @override
  void initState() {
    super.initState();
    _reconcileTabs();
    _revealSelectedTab();
  }

  @override
  void didUpdateWidget(DashboardTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcileTabs();
    final labelsChanged =
        oldWidget.tabs.length != widget.tabs.length ||
        widget.tabs.asMap().entries.any((entry) {
          final oldTab = oldWidget.tabs[entry.key];
          return oldTab.id != entry.value.id ||
              oldTab.label != entry.value.label ||
              oldTab.badgeCount != entry.value.badgeCount ||
              oldTab.icon != entry.value.icon;
        });
    if (oldWidget.selectedId != widget.selectedId || labelsChanged) {
      _revealSelectedTab();
    }
  }

  void _reconcileTabs() {
    final ids = widget.tabs.map((tab) => tab.id).toSet();
    for (final id in _scrollControllers.keys.toList()) {
      if (!ids.contains(id)) _scrollControllers.remove(id)!.dispose();
    }
    _tabAnchors.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _scrollControllers.putIfAbsent(id, () => ScrollController());
      _tabAnchors.putIfAbsent(id, GlobalKey.new);
    }
  }

  void _revealSelectedTab() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) return;
      final tabContext = _tabAnchors[_selectedId]?.currentContext;
      final renderObject = tabContext?.findRenderObject();
      if (tabContext == null || renderObject == null) return;
      // Only move the horizontal tab strip, never an outer dashboard viewport.
      Scrollable.of(tabContext).position.ensureVisible(
        renderObject,
        alignment: .5,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _tabBarController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = _selectedId;
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSize = MediaQuery.textScalerOf(context).scale(12);
        final direction = Directionality.of(context);
        if (_tabBarWidth != constraints.maxWidth ||
            _tabTextSize != textSize ||
            _tabDirection != direction) {
          _tabBarWidth = constraints.maxWidth;
          _tabTextSize = textSize;
          _tabDirection = direction;
          _revealSelectedTab();
        }
        return DashboardPresentationScope(
          tabbed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.tabs.isNotEmpty)
                Material(
                  color: palette.navigation,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: palette.border)),
                    ),
                    child: SingleChildScrollView(
                      key: const Key('dashboard-tab-bar'),
                      controller: _tabBarController,
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: Row(
                        children: [
                          for (final tab in widget.tabs)
                            _tab(context, tab, selected: tab.id == selectedId),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.notice != null) widget.notice!,
              Expanded(
                child: selectedId == null
                    ? SingleChildScrollView(
                        padding: widget.contentPadding,
                        child: widget.footer ?? const SizedBox.shrink(),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final tab in widget.tabs)
                            // Keys must be on the Stack's direct children. An
                            // IndexedStack inserts unkeyed Visibility wrappers,
                            // which replace a moved page instead of reusing it.
                            Offstage(
                              key: ValueKey('dashboard-tab-page-${tab.id}'),
                              offstage: tab.id != selectedId,
                              child: TickerMode(
                                enabled: tab.id == selectedId,
                                child: ExcludeFocus(
                                  excluding: tab.id != selectedId,
                                  child: SingleChildScrollView(
                                    key: PageStorageKey<String>(
                                      'dashboard-tab-scroll-${tab.id}',
                                    ),
                                    controller: _scrollControllers[tab.id],
                                    primary: false,
                                    padding: widget.contentPadding,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        widget.cardBuilder(tab.id),
                                        if (widget.footer != null) ...[
                                          const SizedBox(height: 8),
                                          widget.footer!,
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tab(
    BuildContext context,
    DashboardTab tab, {
    required bool selected,
  }) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.accent : palette.muted;
    void select() => widget.onSelected(tab.id);
    final VoidCallback? edit = widget.onLongPressTab == null
        ? null
        : () => widget.onLongPressTab!(tab.id);

    return Tooltip(
      key: _tabAnchors[tab.id],
      message: tab.title,
      excludeFromSemantics: true,
      // Preserve mouse hover hints without entering the touch gesture arena.
      // Long presses belong to the dashboard layout editing action.
      triggerMode: TooltipTriggerMode.manual,
      child: Semantics(
        label: tab.title,
        value: tab.badgeCount > 0 ? '${tab.badgeCount}' : null,
        button: true,
        selected: selected,
        onTap: select,
        onLongPress: edit,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('dashboard-tab-${tab.id}'),
          onTap: select,
          onLongPress: edit,
          excludeFromSemantics: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accentSurface.withValues(alpha: .32)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: selected ? palette.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (tab.icon != null) ...[
                  Icon(tab.icon, color: color, size: 14),
                  if (tab.label.isNotEmpty) const SizedBox(width: 4),
                ],
                if (tab.label.isNotEmpty)
                  Text(
                    tab.label,
                    maxLines: 1,
                    softWrap: false,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                if (tab.badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: appColor(context, const Color(0xff3c3323)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        tab.badgeCount > 99 ? '99+' : '${tab.badgeCount}',
                        maxLines: 1,
                        softWrap: false,
                        style: appTextStyle(
                          context,
                          const TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffd4a85f),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
