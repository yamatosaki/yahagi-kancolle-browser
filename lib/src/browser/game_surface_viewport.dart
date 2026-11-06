import '../theme/app_palette.dart';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/adaptive_layout.dart';
import '../layout/camera_avoidance.dart';
import '../layout/window_layout_controller.dart';
import '../settings/display_mode_store.dart';

/// Displays the platform game surface while strictly maintaining the
/// KanColle 1200:720 aspect ratio.
///
/// Fullscreen and windowed workspaces keep the complete game visible, leaving
/// space around it when the available window has a different aspect ratio.
///
/// Uses [CustomSingleChildLayout] so that the widget subtree hierarchy above
/// the game surface remains completely stable across fullscreen toggles,
/// orientation changes, and layout resizing, guaranteeing that the platform
/// view is never disposed or recreated during UI reflows.
class GameSurfaceViewport extends StatelessWidget {
  const GameSurfaceViewport({
    super.key,
    required this.child,
    this.aspectRatio = 1200 / 720,
    this.fullscreen = false,
    this.isLandscape = false,
    this.fullscreenFitAxis,
    this.displayMode = DisplayMode.auto,
    this.fitWithinBounds = false,
    this.centerAboveBottomInset = false,
    this.viewPadding,
    this.backgroundColor = const Color(0xff0a1823),
  });

  final Widget child;
  final double aspectRatio;
  final bool fullscreen;
  final bool isLandscape;
  final GameFitAxis? fullscreenFitAxis;
  final DisplayMode displayMode;
  final bool fitWithinBounds;

  /// Centers the game inside the area above the bottom system inset, ignoring
  /// width priority. Left/right insets are deliberately not reserved; the
  /// caller's layout already accounts for them. No effect in fullscreen.
  final bool centerAboveBottomInset;
  final EdgeInsets? viewPadding;
  final Color backgroundColor;

  /// The native slot uses the actual workspace mode for window permission.
  /// A missing viewport leaves callers on the conservative fullscreen policy.
  static bool? fullscreenOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_GameSurfaceViewportMode>()
      ?.fullscreen;

  /// Determines whether width-first alignment should be used.
  ///
  /// Returns true for portrait display mode, vertical workspaces, or compact
  /// windows (such as Android split-screen on a mobile device).
  static bool shouldUseWidthPriority({
    required double width,
    required double height,
    required bool isLandscape,
    DisplayMode displayMode = DisplayMode.auto,
    bool fullscreen = false,
  }) {
    if (displayMode == DisplayMode.portrait) {
      return true;
    }
    if (!isLandscape) {
      return true;
    }
    // Mobile split-screen / compact window width
    if (width <= compactWindowShortestSide) {
      return true;
    }
    // Height-constrained multi-window / foldable unfolded horizontal split
    // (e.g. 768x380, 800x400, 1024x500) where width exceeds standard phone width
    // but vertical space is constrained by multi-window division.
    if (height > 0 &&
        height <= compactWindowShortestSide &&
        (width / height) <= 2.1) {
      return true;
    }
    return false;
  }

  /// Computes the layout rectangle for the game surface in width-priority mode.
  ///
  /// Fills the safe width when height permits, otherwise fits the safe height.
  /// Complete content takes precedence over filling a short split window.
  static Rect computeWidthPriorityGameRect({
    required double containerWidth,
    required double containerHeight,
    required double aspectRatio,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return computeContainGameRect(
      containerWidth: containerWidth,
      containerHeight: containerHeight,
      aspectRatio: aspectRatio,
      padding: padding,
    );
  }

  /// Computes the layout rectangle for the game surface in contain mode.
  static Rect computeContainGameRect({
    required double containerWidth,
    required double containerHeight,
    required double aspectRatio,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    final availW = math.max(0.0, containerWidth - padding.horizontal);
    final availH = math.max(0.0, containerHeight - padding.vertical);
    if (availW <= 0 || availH <= 0) {
      // Do not turn an exhausted safe area into an overflowing platform view.
      return Rect.fromLTWH(
        padding.left.clamp(0.0, math.max(0.0, containerWidth)),
        padding.top.clamp(0.0, math.max(0.0, containerHeight)),
        0,
        0,
      );
    }

    final double gameWidth;
    final double gameHeight;
    if (availH > 0 && availW / availH > aspectRatio) {
      gameHeight = availH;
      gameWidth = gameHeight * aspectRatio;
    } else {
      gameWidth = availW;
      gameHeight = aspectRatio > 0 ? gameWidth / aspectRatio : availH;
    }

    final left = padding.left + (availW - gameWidth) / 2;
    final top = padding.top + (availH - gameHeight) / 2;
    return Rect.fromLTWH(left, top, gameWidth, gameHeight);
  }

  /// Fits the preferred window axis as far as both safe dimensions permit.
  /// Complete content takes precedence over filling that axis. Preserve the
  /// game ratio and align the safe bounds and origin to physical pixels.
  static Rect computeAxisFitGameRect({
    required double containerWidth,
    required double containerHeight,
    required double aspectRatio,
    required GameFitAxis axis,
    EdgeInsets padding = EdgeInsets.zero,
    double devicePixelRatio = 1,
  }) {
    final availW = math.max(0.0, containerWidth - padding.horizontal);
    final availH = math.max(0.0, containerHeight - padding.vertical);
    if (availW <= 0 || availH <= 0 || aspectRatio <= 0) {
      return computeContainGameRect(
        containerWidth: containerWidth,
        containerHeight: containerHeight,
        aspectRatio: aspectRatio,
        padding: padding,
      );
    }
    final dpr = devicePixelRatio > 0 && devicePixelRatio.isFinite
        ? devicePixelRatio
        : 1.0;
    double snap(double value) => (value * dpr + .5).floorToDouble() / dpr;
    final safeLeft = (padding.left * dpr).ceilToDouble() / dpr;
    final safeTop = (padding.top * dpr).ceilToDouble() / dpr;
    final safeRight =
        ((containerWidth - padding.right) * dpr).floorToDouble() / dpr;
    final safeBottom =
        ((containerHeight - padding.bottom) * dpr).floorToDouble() / dpr;
    final safeWidth = math.max(0.0, safeRight - safeLeft);
    final safeHeight = math.max(0.0, safeBottom - safeTop);
    final double width;
    final double height;
    if (axis == GameFitAxis.width) {
      width = math.min(safeWidth, safeHeight * aspectRatio);
      height = width / aspectRatio;
    } else {
      height = math.min(safeHeight, safeWidth / aspectRatio);
      width = height * aspectRatio;
    }
    return Rect.fromLTWH(
      snap(safeLeft + (safeWidth - width) / 2),
      snap(safeTop + (safeHeight - height) / 2),
      width,
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = viewPadding ?? MediaQuery.viewPaddingOf(context);
    final centerAbove = centerAboveBottomInset && !fullscreen;
    final camera = CameraAvoidanceScope.maybeOf(context);
    final effectivePadding = centerAbove
        ? EdgeInsets.only(bottom: padding.bottom)
        : EdgeInsets.zero;

    return _GameSurfaceViewportMode(
      fullscreen: fullscreen,
      child: ColoredBox(
        color: appColor(context, backgroundColor),
        child: ClipRect(
          clipper: fullscreen ? _GameSafeAreaClipper(effectivePadding) : null,
          child: CustomSingleChildLayout(
            delegate: _GameSurfaceLayoutDelegate(
              aspectRatio: aspectRatio,
              fullscreen: fullscreen,
              isLandscape: isLandscape,
              fullscreenFitAxis: fullscreenFitAxis,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              displayMode: displayMode,
              fitWithinBounds:
                  fitWithinBounds ||
                  centerAbove ||
                  (camera != null &&
                      camera.enabled &&
                      camera.cutoutEdges.isNotEmpty),
              padding: effectivePadding,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

final class _GameSurfaceViewportMode extends InheritedWidget {
  const _GameSurfaceViewportMode({
    required this.fullscreen,
    required super.child,
  });

  final bool fullscreen;

  @override
  bool updateShouldNotify(_GameSurfaceViewportMode oldWidget) =>
      fullscreen != oldWidget.fullscreen;
}

final class _GameSafeAreaClipper extends CustomClipper<Rect> {
  const _GameSafeAreaClipper(this.padding);
  final EdgeInsets padding;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    padding.left.clamp(0.0, size.width),
    padding.top.clamp(0.0, size.height),
    math.max(0.0, size.width - padding.horizontal),
    math.max(0.0, size.height - padding.vertical),
  );

  @override
  bool shouldReclip(_GameSafeAreaClipper oldClipper) =>
      padding != oldClipper.padding;
}

class _GameSurfaceLayoutDelegate extends SingleChildLayoutDelegate {
  const _GameSurfaceLayoutDelegate({
    required this.aspectRatio,
    required this.fullscreen,
    required this.isLandscape,
    required this.fullscreenFitAxis,
    required this.devicePixelRatio,
    required this.displayMode,
    required this.fitWithinBounds,
    required this.padding,
  });

  final double aspectRatio;
  final bool fullscreen;
  final bool isLandscape;
  final GameFitAxis? fullscreenFitAxis;
  final double devicePixelRatio;
  final DisplayMode displayMode;
  final bool fitWithinBounds;
  final EdgeInsets padding;

  Rect _calculateRect(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return Rect.zero;
    }

    if (fullscreen) {
      return GameSurfaceViewport.computeAxisFitGameRect(
        containerWidth: size.width,
        containerHeight: size.height,
        aspectRatio: aspectRatio,
        axis:
            fullscreenFitAxis ??
            (isLandscape ? GameFitAxis.height : GameFitAxis.width),
        padding: padding,
        devicePixelRatio: devicePixelRatio,
      );
    }

    final isWidthPriority = GameSurfaceViewport.shouldUseWidthPriority(
      width: size.width,
      height: size.height,
      isLandscape: isLandscape,
      displayMode: displayMode,
      fullscreen: fullscreen,
    );

    if (isWidthPriority && !fitWithinBounds) {
      return GameSurfaceViewport.computeWidthPriorityGameRect(
        containerWidth: size.width,
        containerHeight: size.height,
        aspectRatio: aspectRatio,
        padding: padding,
      );
    } else {
      return GameSurfaceViewport.computeContainGameRect(
        containerWidth: size.width,
        containerHeight: size.height,
        aspectRatio: aspectRatio,
        padding: padding,
      );
    }
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final rect = _calculateRect(constraints.biggest);
    return BoxConstraints.tight(Size(rect.width, rect.height));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rect = _calculateRect(size);
    return Offset(rect.left, rect.top);
  }

  @override
  bool shouldRelayout(_GameSurfaceLayoutDelegate oldDelegate) {
    return oldDelegate.aspectRatio != aspectRatio ||
        oldDelegate.fullscreen != fullscreen ||
        oldDelegate.isLandscape != isLandscape ||
        oldDelegate.fullscreenFitAxis != fullscreenFitAxis ||
        oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.displayMode != displayMode ||
        oldDelegate.fitWithinBounds != fitWithinBounds ||
        oldDelegate.padding != padding;
  }
}
