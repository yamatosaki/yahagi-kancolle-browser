import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_palette.dart';

enum CameraAvoidanceEdge { left, top, right, bottom }

EdgeInsets _withoutCutoutPadding(
  EdgeInsets padding,
  Set<CameraAvoidanceEdge> edges,
) => EdgeInsets.fromLTRB(
  edges.contains(CameraAvoidanceEdge.left) ? 0 : padding.left,
  edges.contains(CameraAvoidanceEdge.top) ? 0 : padding.top,
  edges.contains(CameraAvoidanceEdge.right) ? 0 : padding.right,
  edges.contains(CameraAvoidanceEdge.bottom) ? 0 : padding.bottom,
);

bool _finiteRect(Rect rect) =>
    rect.left.isFinite &&
    rect.top.isFinite &&
    rect.right.isFinite &&
    rect.bottom.isFinite;

Set<CameraAvoidanceEdge> _cutoutEdges(
  Size size,
  Iterable<DisplayFeature> features, {
  Size? edgePreferenceSize,
}) {
  if (!size.width.isFinite ||
      !size.height.isFinite ||
      size.width <= 0 ||
      size.height <= 0) {
    return const <CameraAvoidanceEdge>{};
  }
  final window = Offset.zero & size;
  final edges = <CameraAvoidanceEdge>{};
  // A corner punch hole belongs to the short edge on Android. Prefer that
  // edge for sub-pixel ties too, so rounding cannot make it jump between axes.
  final preference = edgePreferenceSize ?? size;
  final order = preference.width > preference.height
      ? [
          CameraAvoidanceEdge.left,
          CameraAvoidanceEdge.right,
          CameraAvoidanceEdge.top,
          CameraAvoidanceEdge.bottom,
        ]
      : [
          CameraAvoidanceEdge.top,
          CameraAvoidanceEdge.bottom,
          CameraAvoidanceEdge.left,
          CameraAvoidanceEdge.right,
        ];
  for (final feature in features) {
    final bounds = feature.bounds;
    if (feature.type != DisplayFeatureType.cutout ||
        !_finiteRect(bounds) ||
        bounds.isEmpty ||
        !window.overlaps(bounds)) {
      continue;
    }
    final rect = bounds.intersect(window);
    if (rect.width >= size.width && rect.height >= size.height) continue;
    if (rect.width >= size.width - .5) {
      edges.add(
        rect.top <= size.height - rect.bottom
            ? CameraAvoidanceEdge.top
            : CameraAvoidanceEdge.bottom,
      );
      continue;
    }
    if (rect.height >= size.height - .5) {
      edges.add(
        rect.left <= size.width - rect.right
            ? CameraAvoidanceEdge.left
            : CameraAvoidanceEdge.right,
      );
      continue;
    }
    final gaps = <CameraAvoidanceEdge, double>{
      CameraAvoidanceEdge.left: rect.left,
      CameraAvoidanceEdge.top: rect.top,
      CameraAvoidanceEdge.right: size.width - rect.right,
      CameraAvoidanceEdge.bottom: size.height - rect.bottom,
    };
    final nearest = gaps.values.reduce(math.min);
    edges.add(order.firstWhere((edge) => gaps[edge]! <= nearest + .5));
  }
  return Set.unmodifiable(edges);
}

/// Only explicit cutout geometry identifies a camera side. System bars,
/// waterfall insets and fold/hinge features must not manufacture one.
EdgeInsets cameraAvoidanceInsets({
  required Size size,
  required Iterable<DisplayFeature> displayFeatures,
  required bool enabled,
  required double distance,
}) {
  return _insetsForEdges(
    size,
    _cutoutEdges(size, displayFeatures),
    enabled,
    distance,
  );
}

EdgeInsets _insetsForEdges(
  Size size,
  Set<CameraAvoidanceEdge> edges,
  bool enabled,
  double distance,
) {
  if (!enabled || !distance.isFinite || distance <= 0) return EdgeInsets.zero;
  if (edges.isEmpty) return EdgeInsets.zero;
  final requested = distance.clamp(0.0, 120.0);
  // Retain at least half of each window axis, including malformed multi-cutout
  // reports and very small multi-window transitions.
  final horizontalEdges = [
    CameraAvoidanceEdge.left,
    CameraAvoidanceEdge.right,
  ].where(edges.contains).length;
  final verticalEdges = [
    CameraAvoidanceEdge.top,
    CameraAvoidanceEdge.bottom,
  ].where(edges.contains).length;
  final horizontal = math.min(
    requested,
    size.width / (2 * math.max(1, horizontalEdges)),
  );
  final vertical = math.min(
    requested,
    size.height / (2 * math.max(1, verticalEdges)),
  );
  return EdgeInsets.fromLTRB(
    edges.contains(CameraAvoidanceEdge.left) ? horizontal : 0,
    edges.contains(CameraAvoidanceEdge.top) ? vertical : 0,
    edges.contains(CameraAvoidanceEdge.right) ? horizontal : 0,
    edges.contains(CameraAvoidanceEdge.bottom) ? vertical : 0,
  );
}

/// Window-relative content bounds remain available to native overlays even
/// though the Navigator and its MediaQuery now use the inset local viewport.
final class CameraAvoidanceScope extends InheritedWidget {
  const CameraAvoidanceScope({
    super.key,
    required this.insets,
    required this.windowSize,
    required this.enabled,
    this.cutoutEdges = const <CameraAvoidanceEdge>{},
    this.synchronizationInsets,
    this.requestedDistance,
    required super.child,
  });

  final EdgeInsets insets;
  final Size windowSize;
  final bool enabled;
  final Set<CameraAvoidanceEdge> cutoutEdges;

  /// Uses the pre-IME window to distinguish a deliberate camera adjustment
  /// from margins capped only by temporary keyboard constraints.
  final EdgeInsets? synchronizationInsets;

  /// Keeps an intentional setting change distinguishable from the same
  /// distance moving to another edge or being capped by a resized window.
  final double? requestedDistance;

  static CameraAvoidanceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CameraAvoidanceScope>();

  /// An enabled manual setting owns the cutout edge, including distance zero.
  /// Preserve unrelated navigation/status-bar padding on other edges.
  EdgeInsets gameViewPadding(EdgeInsets padding) =>
      !enabled ? padding : _withoutCutoutPadding(padding, cutoutEdges);

  /// Apply the same window-to-local conversion as this scope's MediaQuery.
  EdgeInsets localViewPadding(EdgeInsets windowPadding) =>
      gameViewPadding(_remaining(windowPadding, insets));

  @override
  bool updateShouldNotify(CameraAvoidanceScope oldWidget) =>
      oldWidget.insets != insets ||
      oldWidget.windowSize != windowSize ||
      oldWidget.enabled != enabled ||
      oldWidget.synchronizationInsets != synchronizationInsets ||
      oldWidget.requestedDistance != requestedDistance ||
      !setEquals(oldWidget.cutoutEdges, cutoutEdges);
}

EdgeInsets _remaining(EdgeInsets original, EdgeInsets consumed) =>
    EdgeInsets.fromLTRB(
      math.max(0, original.left - consumed.left),
      math.max(0, original.top - consumed.top),
      math.max(0, original.right - consumed.right),
      math.max(0, original.bottom - consumed.bottom),
    );

List<DisplayFeature> _localFeatures(
  List<DisplayFeature> features,
  Rect viewport, {
  bool removeCutouts = false,
}) {
  final local = <DisplayFeature>[];
  for (final feature in features) {
    if (removeCutouts && feature.type == DisplayFeatureType.cutout) {
      continue;
    }
    final rect = feature.bounds;
    if (!_finiteRect(rect) ||
        rect.width < 0 ||
        rect.height < 0 ||
        rect.right < viewport.left ||
        rect.left > viewport.right ||
        rect.bottom < viewport.top ||
        rect.top > viewport.bottom) {
      continue;
    }
    final intersection = Rect.fromLTRB(
      math.max(rect.left, viewport.left),
      math.max(rect.top, viewport.top),
      math.min(rect.right, viewport.right),
      math.min(rect.bottom, viewport.bottom),
    );
    if (feature.type == DisplayFeatureType.cutout && intersection.isEmpty) {
      continue;
    }
    // Zero-width/height folds and hinges are meaningful display features.
    local.add(
      DisplayFeature(
        bounds: intersection.shift(-viewport.topLeft),
        type: feature.type,
        state: feature.state,
      ),
    );
  }
  return List.unmodifiable(local);
}

final class CameraAvoidanceViewport extends StatefulWidget {
  const CameraAvoidanceViewport({
    super.key,
    required this.enabled,
    required this.distance,
    required this.child,
  });

  final bool enabled;
  final double distance;
  final Widget child;

  @override
  State<CameraAvoidanceViewport> createState() =>
      _CameraAvoidanceViewportState();
}

final class _CameraAvoidanceViewportState
    extends State<CameraAvoidanceViewport> {
  Set<Rect> _previousCutouts = const <Rect>{};
  Size? _edgePreferenceSize;
  Size? _cameraWindowSize;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? constraints.biggest
            : media.size;
        final cutouts = media.displayFeatures
            .where((f) => f.type == DisplayFeatureType.cutout)
            .map((f) => f.bounds)
            .toSet();
        final imeVisible = media.viewInsets.bottom > 0;
        if (size.width.isFinite &&
            size.height.isFinite &&
            size.width > 0 &&
            size.height > 0) {
          final previousWindow = _cameraWindowSize;
          if (previousWindow == null || !imeVisible) {
            _cameraWindowSize = size;
          } else if (size.width != previousWindow.width) {
            // A quarter turn swaps the full window dimensions even when an
            // IME-resized Flutter surface reports only the remaining height.
            _cameraWindowSize =
                size.width == previousWindow.height &&
                    size.height <= previousWindow.width
                ? Size(previousWindow.height, previousWindow.width)
                : size;
          }
          if (_edgePreferenceSize == null ||
              (!setEquals(cutouts, _previousCutouts) &&
                  (cutouts.isNotEmpty || !imeVisible))) {
            _edgePreferenceSize = _cameraWindowSize;
          }
          // Some IME transitions temporarily omit the cutout report. Keep
          // the last known geometry until a non-IME frame or a moved cutout.
          if (cutouts.isNotEmpty || !imeVisible) {
            _previousCutouts = cutouts;
          }
        }
        // A size-only IME or multi-window update cannot move a stationary
        // corner camera between axes. Reconsider ties when the cutout itself
        // moves, as it does during real screen rotation.
        final cameraWindowSize = imeVisible ? _cameraWindowSize ?? size : size;
        final cutoutFeatures = imeVisible && cutouts.isEmpty
            ? _previousCutouts.map(
                (bounds) => DisplayFeature(
                  bounds: bounds,
                  type: DisplayFeatureType.cutout,
                  state: DisplayFeatureState.unknown,
                ),
              )
            : media.displayFeatures;
        final cutoutEdges = _cutoutEdges(
          cameraWindowSize,
          cutoutFeatures,
          edgePreferenceSize: _edgePreferenceSize,
        );
        final handledEdges = widget.enabled
            ? cutoutEdges
            : const <CameraAvoidanceEdge>{};
        final insets = _insetsForEdges(
          size,
          cutoutEdges,
          widget.enabled,
          widget.distance,
        );
        final viewport = Rect.fromLTWH(
          insets.left,
          insets.top,
          math.max(0, size.width - insets.horizontal),
          math.max(0, size.height - insets.vertical),
        );
        final localMedia = insets == EdgeInsets.zero && handledEdges.isEmpty
            ? media
            : media.copyWith(
                size: viewport.size,
                padding: _withoutCutoutPadding(
                  _remaining(media.padding, insets),
                  handledEdges,
                ),
                viewPadding: _withoutCutoutPadding(
                  _remaining(media.viewPadding, insets),
                  handledEdges,
                ),
                viewInsets: _remaining(media.viewInsets, insets),
                systemGestureInsets: _remaining(
                  media.systemGestureInsets,
                  insets,
                ),
                // The manual setting now owns cutout avoidance. Keeping a full-width
                // notch here would make DialogRoute's DisplayFeatureSubScreen add it
                // back, independently of SafeArea. Folding features remain meaningful.
                displayFeatures: _localFeatures(
                  media.displayFeatures,
                  viewport,
                  removeCutouts: handledEdges.isNotEmpty,
                ),
              );
        // Keep this exact hierarchy with the feature both on and off. Replacing
        // ancestors would recreate the Navigator and persistent platform view.
        return ColoredBox(
          color: AppPalette.of(context).background,
          child: CameraAvoidanceScope(
            insets: insets,
            windowSize: size,
            enabled: widget.enabled,
            cutoutEdges: cutoutEdges,
            synchronizationInsets: _insetsForEdges(
              cameraWindowSize,
              cutoutEdges,
              widget.enabled,
              widget.distance,
            ),
            requestedDistance: widget.distance,
            child: Padding(
              padding: insets,
              child: MediaQuery(data: localMedia, child: widget.child),
            ),
          ),
        );
      },
    );
  }
}
