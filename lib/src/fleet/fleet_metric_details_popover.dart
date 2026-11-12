import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../browser/game_dialog_presentation_scope.dart';
import '../browser/game_workspace_visibility.dart';
import '../theme/app_palette.dart';
import '../widgets/panel_popover_layout.dart';

/// Anchors read-only fleet details without a modal route or input guard.
class FleetMetricDetailsPopover extends StatefulWidget {
  const FleetMetricDetailsPopover({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.cardKey,
    required this.closeKey,
    required this.children,
    required this.builder,
    this.viewportContext,
  });

  final String title;
  final String closeLabel;
  final Key cardKey;
  final Key closeKey;
  final List<Widget> children;
  final Widget Function(VoidCallback toggle) builder;
  final BuildContext? viewportContext;

  @override
  State<FleetMetricDetailsPopover> createState() =>
      _FleetMetricDetailsPopoverState();
}

class _FleetMetricDetailsPopoverState extends State<FleetMetricDetailsPopover>
    with WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  final _focus = FocusNode();
  ({Rect anchor, Rect? viewport})? _geometry;
  ScrollPosition? _scroll;
  LocalHistoryEntry? _history;
  bool _available = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspaceActive = GameWorkspaceActive.of(context);
    final routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final paneActive = TickerMode.valuesOf(context).enabled;
    final presentationEnabled =
        GameDialogPresentationScope.maybeOf(context)?.presentationEnabled ??
        true;
    _available =
        workspaceActive && routeCurrent && paneActive && presentationEnabled;
  }

  @override
  void didChangeMetrics() => _close();

  ({Rect anchor, Rect? viewport})? _measure(ScrollableState? scrollable) {
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.attached) return null;

    Rect? bounds(BuildContext target) {
      if (!target.mounted) return null;
      final box = target.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return null;
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(overlay),
        Offset.zero & box.size,
      );
      return rect.isFinite && !rect.isEmpty ? rect : null;
    }

    final anchor = bounds(context);
    if (anchor == null) return null;
    final viewportContext = widget.viewportContext ?? scrollable?.context;
    final viewport = viewportContext == null ? null : bounds(viewportContext);
    if (viewportContext != null && viewport == null) return null;
    return (anchor: anchor, viewport: viewport);
  }

  void _toggle() {
    if (_geometry != null) {
      _close();
      return;
    }
    if (!_available) return;
    final scrollable = Scrollable.maybeOf(context);
    final geometry = _measure(scrollable);
    if (geometry == null) return;
    _geometry = geometry;
    _scroll = scrollable?.position;
    _scroll?.addListener(_close);
    final route = ModalRoute.of(context);
    if (route != null) {
      final history = LocalHistoryEntry(
        onRemove: () {
          _history = null;
          _close();
        },
      );
      _history = history;
      route.addLocalHistoryEntry(history);
    }
    _portal.show();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _geometry != null && _available) _focus.requestFocus();
    });
  }

  void _detach() {
    _scroll?.removeListener(_close);
    _scroll = null;
    final history = _history;
    _history = null;
    history?.remove();
  }

  void _close() {
    if (_geometry == null) return;
    _geometry = null;
    _portal.hide();
    _detach();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geometry = null;
    _detach();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_geometry != null) {
      // Pane resizing and workspace changes can invalidate the cached anchor.
      final scrollable = Scrollable.maybeOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _geometry != null &&
            (!_available || _geometry != _measure(scrollable))) {
          _close();
        }
      });
    }
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final geometry = _geometry;
        if (!_available || geometry == null) return const SizedBox.shrink();
        return PanelPopoverLayout(
          anchor: geometry.anchor,
          viewport: geometry.viewport,
          child: TapRegion(
            groupId: this,
            onTapOutside: (_) => _close(),
            child: Focus(
              focusNode: _focus,
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _close();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: _MetricDetailsCard(
                title: widget.title,
                closeLabel: widget.closeLabel,
                cardKey: widget.cardKey,
                closeKey: widget.closeKey,
                onClose: _close,
                children: widget.children,
              ),
            ),
          ),
        );
      },
      child: TapRegion(groupId: this, child: widget.builder(_toggle)),
    );
  }
}

class _MetricDetailsCard extends StatefulWidget {
  const _MetricDetailsCard({
    required this.title,
    required this.closeLabel,
    required this.cardKey,
    required this.closeKey,
    required this.onClose,
    required this.children,
  });

  final String title;
  final String closeLabel;
  final Key cardKey;
  final Key closeKey;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  State<_MetricDetailsCard> createState() => _MetricDetailsCardState();
}

class _MetricDetailsCardState extends State<_MetricDetailsCard> {
  // The card must not restore or overwrite the surrounding fleet pane's offset.
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: widget.cardKey,
      color: appColor(context, const Color(0xff192f3d)),
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: appColor(context, const Color(0xff4f6676))),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: _scroll,
        primary: false,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: appTextStyle(
                      context,
                      const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: widget.closeKey,
                  onPressed: widget.onClose,
                  tooltip: widget.closeLabel,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            ...widget.children,
          ],
        ),
      ),
    );
  }
}

class FleetMetricDetailRow extends StatelessWidget {
  const FleetMetricDetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: appTextStyle(
                context,
                TextStyle(color: appColor(context, Color(0xff9fb4bf))),
              ),
            ),
          ),
          Text(
            value,
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffe1e9ed)),
                fontWeight: FontWeight.w800,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
