import 'dart:math' as math;

import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import '../layout/dashboard_editing_scope.dart';
import '../layout/dashboard_presentation_scope.dart';
import '../layout/flat_collapse_chevron.dart';
import '../layout/flat_style.dart';
import '../layout/panel_style.dart';
import 'fleet_ui_strings.dart';

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.child,
    this.showLogo = true,
    this.showTitle = true,
    this.titleBadge,
    this.trailing,
    this.padding,
    this.borderColor,
    this.collapseButtonKey,
    this.headerAction,
    this.collapsedSummary,
  });

  final String title;
  final Widget icon;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final Widget child;
  final bool showLogo;
  final bool showTitle;
  final Widget? titleBadge;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Key? collapseButtonKey;
  final Widget? headerAction;

  /// 保留调用方传入的折叠摘要；当前标题不再展示摘要文字。
  final String? collapsedSummary;

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
    final palette = AppPalette.of(context);
    final tabbed =
        DashboardPresentationScope.isTabbed(context) &&
        !DashboardEditingScope.isEditing(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        padding: flat
            ? EdgeInsets.fromLTRB(6, 0, 6, collapsed ? 0 : 4)
            : padding ??
                  EdgeInsets.fromLTRB(
                    14,
                    collapsed ? 8 : 10,
                    10,
                    collapsed ? 8 : 10,
                  ),
        decoration: flat
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: palette.isDark ? flatDividerColor : palette.border,
                  ),
                ),
              )
            : BoxDecoration(
                color: appColor(context, const Color(0xff142735)),
                borderRadius: BorderRadius.circular(10),
                border: borderColor != null
                    ? Border.all(color: appColor(context, borderColor!))
                    : null,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tabbed &&
                (headerAction != null ||
                    (!collapsed && (titleBadge != null || trailing != null))))
              _tabbedHeaderControls()
            else if (!tabbed)
              LayoutBuilder(
                builder: (context, constraints) {
                  // English titles are long, but the flat header ellipsizes them
                  // instead of wrapping so the collapse button never leaves view.
                  if (flat) {
                    return SizedBox(
                      key: const Key('dashboard-card-header'),
                      height: DashboardEditingScope.isEditing(context)
                          ? flatEditRowHeight
                          : flatHeaderHeight,
                      child: _flatHeader(context),
                    );
                  }
                  if (Localizations.maybeLocaleOf(context)?.languageCode ==
                          'en' &&
                      (constraints.maxWidth < 400 ||
                          MediaQuery.textScalerOf(context).scale(14) > 14)) {
                    final header = _englishHeader(context);
                    if (constraints.maxWidth < 220) {
                      return SingleChildScrollView(
                        // Cards keep their own state in the slot their
                        // PageStorageKey derives; an unkeyed scroll view would
                        // restore that value as its offset and throw.
                        key: const PageStorageKey(
                          'dashboard-card-header-scroll',
                        ),
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: 220, child: header),
                      );
                    }
                    return header;
                  }
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: constraints.maxWidth < 220
                          ? 220
                          : constraints.maxWidth,
                      child: Row(
                        children: [
                          if (showLogo) ...[
                            IconTheme(
                              data: IconThemeData(
                                size: 16,
                                color: appColor(context, Color(0xffd4a85f)),
                              ),
                              child: icon,
                            ),
                            if (showTitle) const SizedBox(width: 6),
                          ],
                          if (showTitle)
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        title,
                                        style: appTextStyle(
                                          context,
                                          _titleStyle(false),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!collapsed && titleBadge != null) ...[
                                    const SizedBox(width: 8),
                                    titleBadge!,
                                  ],
                                ],
                              ),
                            )
                          else ...[
                            const Spacer(),
                            if (!collapsed && titleBadge != null) ...[
                              titleBadge!,
                              const SizedBox(width: 8),
                            ],
                          ],
                          if (!collapsed && trailing != null) ...[
                            trailing!,
                            const SizedBox(width: 3),
                          ],
                          ?headerAction,
                          _collapseButton(context),
                        ],
                      ),
                    ),
                  );
                },
              ),
            if (!collapsed) ...[const SizedBox(height: 0), child],
          ],
        ),
      ),
    );
  }

  // The enclosing tab already names the module. Keep only its controls here,
  // using their natural height and width so larger text is never scaled down.
  Widget _tabbedHeaderControls() => SingleChildScrollView(
    key: const PageStorageKey('dashboard-card-tab-controls-scroll'),
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!collapsed && titleBadge != null) ...[
          titleBadge!,
          if (trailing != null || headerAction != null)
            const SizedBox(width: 8),
        ],
        if (!collapsed && trailing != null) ...[
          trailing!,
          if (headerAction != null) const SizedBox(width: 3),
        ],
        ?headerAction,
      ],
    ),
  );

  // Scaling the whole row would shrink the title whenever one child (badge,
  // switcher, gear) is taller than the 24dp header, so only that child scales.
  Widget _flatHeader(BuildContext context) {
    Widget fit(Widget w, double height, AlignmentGeometry alignment) =>
        SizedBox(
          height: height,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: w,
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) => _flatHeaderRow(
        context,
        fit,
        _flatTrailingMaxWidth(constraints.maxWidth),
      ),
    );
  }

  // The switcher is rigid so the title gives way first, but narrow English
  // labels outgrow the row; capping it lets its FittedBox shrink instead of
  // pushing the collapse button out, while a few title letters stay visible.
  double _flatTrailingMaxWidth(double width) {
    const logo = 13.0 + 6;
    const minTitle = 24.0;
    return math.max(
      0,
      width -
          (showLogo ? logo : 0) -
          (showTitle ? minTitle : 0) -
          (headerAction != null ? flatHeaderHeight : 0) -
          _flatChevronWidth -
          3,
    );
  }

  Widget _flatHeaderRow(
    BuildContext context,
    Widget Function(Widget, double, AlignmentGeometry) fit,
    double trailingMaxWidth,
  ) {
    return Row(
      children: [
        if (showLogo) ...[
          IconTheme(
            data: IconThemeData(
              size: 13,
              color: appColor(context, flatAccentColor),
            ),
            child: icon,
          ),
          if (showTitle) const SizedBox(width: 6),
        ],
        if (showTitle)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appTextStyle(context, _titleStyle(true)),
                    ),
                  ),
                  if (!collapsed && titleBadge != null) ...[
                    const SizedBox(width: 8),
                    // Rigid so the title shrinks first (a Flexible badge would
                    // cap the title at half too); the cap stops it overflowing
                    // once the title is gone.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(0, (constraints.maxWidth - 8) / 2),
                      ),
                      child: fit(titleBadge!, 22, Alignment.centerLeft),
                    ),
                  ],
                ],
              ),
            ),
          )
        else if (!collapsed && titleBadge != null) ...[
          // A Flexible badge next to a Spacer would split the free space and
          // leave a gap after the trailing controls; Align keeps it flush.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              heightFactor: 1,
              child: fit(titleBadge!, 22, Alignment.centerRight),
            ),
          ),
          const SizedBox(width: 8),
        ] else
          const Spacer(),
        if (!collapsed && trailing != null) ...[
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: trailingMaxWidth),
            child: fit(trailing!, 22, Alignment.centerRight),
          ),
          const SizedBox(width: 3),
        ],
        if (headerAction != null) fit(headerAction!, 24, Alignment.center),
        if (!DashboardEditingScope.isEditing(context) &&
            !DashboardPresentationScope.isTabbed(context))
          FlatCollapseChevron(
            key: collapseButtonKey,
            collapsed: collapsed,
            label: _collapseLabel(context),
            onTap: onToggleCollapse,
            width: _flatChevronWidth,
          ),
      ],
    );
  }

  // The resource grid's 24dp toggle overhangs into the 6dp panel padding; the
  // card has no room to overhang, so it widens leftwards to the same 30dp.
  static const double _flatChevronWidth = 30;

  TextStyle _titleStyle(bool flat) => TextStyle(
    color: const Color(0xffd4a85f),
    fontWeight: FontWeight.w700,
    fontSize: flat ? flatRowFontSize : 14,
  );

  Widget _englishHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          if (showLogo) ...[
            IconTheme(
              data: IconThemeData(
                size: 16,
                color: appColor(context, Color(0xffd4a85f)),
              ),
              child: icon,
            ),
            if (showTitle) const SizedBox(width: 6),
          ],
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (showTitle)
                  Text(title, style: appTextStyle(context, _titleStyle(false))),
                if (!collapsed && titleBadge != null) titleBadge!,
              ],
            ),
          ),
          ?headerAction,
          _collapseButton(context),
        ],
      ),
      if (!collapsed && trailing != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SingleChildScrollView(
            key: const PageStorageKey('dashboard-card-trailing-scroll'),
            scrollDirection: Axis.horizontal,
            child: trailing!,
          ),
        ),
    ],
  );

  String _collapseLabel(BuildContext context) => collapsed
      ? fleetText(context, '展开$title')
      : fleetText(context, '折叠$title');

  Widget _collapseButton(BuildContext context) =>
      DashboardPresentationScope.isTabbed(context)
      ? const SizedBox.shrink()
      : Semantics(
          label: _collapseLabel(context),
          child: IconButton(
            key: collapseButtonKey,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerRight,
            onPressed: onToggleCollapse,
            icon: Icon(
              collapsed
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 20,
              color: appColor(context, Color(0xff8fa8b6)),
            ),
          ),
        );
}
