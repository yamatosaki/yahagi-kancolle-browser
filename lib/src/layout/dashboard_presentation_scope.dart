import 'package:flutter/widgets.dart';

/// Presentation context for cards rendered as a complete dashboard tab.
class DashboardPresentationScope extends InheritedWidget {
  const DashboardPresentationScope({
    super.key,
    required this.tabbed,
    required super.child,
  });

  final bool tabbed;

  static bool isTabbed(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DashboardPresentationScope>()
          ?.tabbed ??
      false;

  @override
  bool updateShouldNotify(DashboardPresentationScope oldWidget) =>
      oldWidget.tabbed != tabbed;
}
