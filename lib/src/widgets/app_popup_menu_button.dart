import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An anchored menu whose outside barrier consumes touches without dismissing.
class AppPopupMenuButton<T> extends StatefulWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.initialValue,
    this.color,
    this.shape,
    this.child,
    this.tooltip,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final T? initialValue;
  final Color? color;
  final ShapeBorder? shape;
  final Widget? child;
  final String? tooltip;

  @override
  State<AppPopupMenuButton<T>> createState() => _AppPopupMenuButtonState<T>();
}

class _AppPopupMenuButtonState<T> extends State<AppPopupMenuButton<T>> {
  final _anchor = GlobalKey();
  bool _open = false;

  Future<void> _showMenu() async {
    if (_open) return;
    final entries = widget.itemBuilder(context);
    if (entries.isEmpty) return;
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = _anchor.currentContext!.findRenderObject()! as RenderBox;
    final bounds =
        anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size;
    final theme = PopupMenuTheme.of(context);
    _open = true;
    T? selected;
    try {
      selected = await navigator.push<T>(
        _AppPopupMenuRoute<T>(
          entries: entries,
          anchor: bounds,
          initialValue: widget.initialValue,
          themes: InheritedTheme.capture(from: context, to: navigator.context),
          color: widget.color ?? theme.color,
          shape: widget.shape ?? theme.shape,
          elevation: theme.elevation ?? 8,
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
        ),
      );
    } finally {
      _open = false;
    }
    if (mounted && selected != null) widget.onSelected?.call(selected);
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
    child: InkWell(
      key: _anchor,
      onTap: _showMenu,
      child:
          widget.child ??
          const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_vert),
          ),
    ),
  );
}

class _AppPopupMenuRoute<T> extends PopupRoute<T> {
  _AppPopupMenuRoute({
    required this.entries,
    required this.anchor,
    required this.initialValue,
    required this.themes,
    required this.color,
    required this.shape,
    required this.elevation,
    required this.barrierLabel,
  });

  final List<PopupMenuEntry<T>> entries;
  final Rect anchor;
  final T? initialValue;
  final CapturedThemes themes;
  final Color? color;
  final ShapeBorder? shape;
  final double elevation;

  @override
  final String barrierLabel;
  @override
  bool get barrierDismissible => false;
  @override
  Color? get barrierColor => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    double? selectedOffset;
    if (initialValue != null) {
      var offset = 8.0;
      for (final entry in entries) {
        if (entry.represents(initialValue)) {
          selectedOffset = offset + entry.height / 2;
          break;
        }
        offset += entry.height;
      }
    }
    return themes.wrap(
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: CustomSingleChildLayout(
            delegate: _AppPopupMenuLayout(
              anchor: anchor,
              selectedOffset: selectedOffset,
              direction: Directionality.of(context),
              padding:
                  media.padding +
                  EdgeInsets.only(bottom: media.viewInsets.bottom) +
                  const EdgeInsets.all(8),
            ),
            child: Semantics(
              role: SemanticsRole.menu,
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: MaterialLocalizations.of(context).popupMenuLabel,
              child: Material(
                type: MaterialType.card,
                color: color,
                shape:
                    shape ??
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                elevation: elevation,
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: IntrinsicWidth(
                    stepWidth: 56,
                    child: ListBody(
                      children: [
                        for (final entry in entries)
                          if (initialValue != null &&
                              entry.represents(initialValue))
                            ColoredBox(
                              color: Theme.of(context).highlightColor,
                              child: entry,
                            )
                          else
                            entry,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

class _AppPopupMenuLayout extends SingleChildLayoutDelegate {
  const _AppPopupMenuLayout({
    required this.anchor,
    required this.selectedOffset,
    required this.direction,
    required this.padding,
  });
  final Rect anchor;
  final double? selectedOffset;
  final TextDirection direction;
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = (constraints.maxWidth - padding.horizontal).clamp(0.0, 280.0);
    return BoxConstraints(
      minWidth: width.clamp(0.0, 112.0),
      maxWidth: width,
      maxHeight: (constraints.maxHeight - padding.vertical).clamp(
        0.0,
        double.infinity,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = direction == TextDirection.ltr
        ? anchor.left
        : anchor.right - childSize.width;
    final top = selectedOffset == null
        ? anchor.top
        : anchor.center.dy - selectedOffset!;
    return Offset(
      left.clamp(
        padding.left,
        (size.width - padding.right - childSize.width).clamp(
          padding.left,
          double.infinity,
        ),
      ),
      top.clamp(
        padding.top,
        (size.height - padding.bottom - childSize.height).clamp(
          padding.top,
          double.infinity,
        ),
      ),
    );
  }

  @override
  bool shouldRelayout(covariant _AppPopupMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      selectedOffset != oldDelegate.selectedOffset ||
      direction != oldDelegate.direction ||
      padding != oldDelegate.padding;
}
