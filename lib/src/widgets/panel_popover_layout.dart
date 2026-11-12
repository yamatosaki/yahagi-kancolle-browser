import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Positions a floating card and confines its paint to the information pane.
class PanelPopoverLayout extends StatelessWidget {
  const PanelPopoverLayout({
    super.key,
    required this.anchor,
    required this.viewport,
    required this.child,
  });

  final Rect anchor;
  final Rect? viewport;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The anchor may be below a SafeArea that already consumed its padding.
    final media = MediaQuery.of(Overlay.of(context).context);
    return ClipRect(
      clipper: _PopoverViewportClipper(viewport),
      child: CustomSingleChildLayout(
        delegate: _PopoverPosition(
          anchor: anchor,
          insets: media.padding + media.viewInsets,
          viewport: viewport,
        ),
        child: child,
      ),
    );
  }
}

class _PopoverViewportClipper extends CustomClipper<Rect> {
  const _PopoverViewportClipper(this.viewport);

  final Rect? viewport;

  @override
  Rect getClip(Size size) => viewport ?? (Offset.zero & size);

  @override
  bool shouldReclip(_PopoverViewportClipper oldClipper) =>
      viewport != oldClipper.viewport;
}

class _PopoverPosition extends SingleChildLayoutDelegate {
  const _PopoverPosition({
    required this.anchor,
    required this.insets,
    this.viewport,
  });
  final Rect anchor;
  final EdgeInsets insets;
  final Rect? viewport;

  Rect _bounds(Size size) {
    final safe = Rect.fromLTRB(
      insets.left + 8,
      insets.top + 8,
      math.max(insets.left + 8, size.width - insets.right - 8),
      math.max(insets.top + 8, size.height - insets.bottom - 8),
    );
    // The adjacent Android game WebView can draw above Flutter. Keep the
    // popover inside the information panel's scroll viewport when present.
    final panel = viewport;
    final bounds = panel == null ? safe : safe.intersect(panel.deflate(8));
    return Rect.fromLTWH(
      bounds.left,
      bounds.top,
      math.max(0, bounds.width),
      math.max(0, bounds.height),
    );
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final bounds = _bounds(constraints.biggest);
    final width = math.min(270.0, bounds.width);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: bounds.height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bounds = _bounds(size);
    const gap = 8.0;
    double x;
    double y;
    if (anchor.right + gap + childSize.width <= bounds.right) {
      x = anchor.right + gap;
      y = anchor.top;
    } else if (anchor.left - gap - childSize.width >= bounds.left) {
      x = anchor.left - gap - childSize.width;
      y = anchor.top;
    } else {
      x = anchor.center.dx - childSize.width / 2;
      y = anchor.bottom + gap;
      if (y + childSize.height > bounds.bottom &&
          anchor.top - gap - childSize.height >= bounds.top) {
        y = anchor.top - gap - childSize.height;
      }
    }
    return Offset(
      x.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      y.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopoverPosition oldDelegate) =>
      anchor != oldDelegate.anchor ||
      insets != oldDelegate.insets ||
      viewport != oldDelegate.viewport;
}
