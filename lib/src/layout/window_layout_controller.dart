import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

enum GameFitAxis { width, height }

enum WindowLayoutMode { single, sideBySide, stacked, unknown, pictureInPicture }

@immutable
final class WindowLayoutSnapshot {
  const WindowLayoutSnapshot({
    required this.mode,
    required this.isLandscape,
    this.stable = true,
    this.physicalSize,
    this.physicalStableInsets,
    this.insetsViewSize,
  });

  static WindowLayoutSnapshot? fromMap(Object? value) {
    if (value is! Map || value['isLandscape'] is! bool) return null;
    final mode = switch (value['mode']) {
      'single' => WindowLayoutMode.single,
      'sideBySide' => WindowLayoutMode.sideBySide,
      'stacked' => WindowLayoutMode.stacked,
      'pictureInPicture' => WindowLayoutMode.pictureInPicture,
      _ => WindowLayoutMode.unknown,
    };
    final rawInsets = value['stableInsets'];
    final rawWidth = value['insetsViewWidth'];
    final rawHeight = value['insetsViewHeight'];
    final validInsets =
        rawInsets is Map &&
        ['left', 'top', 'right', 'bottom'].every((edge) {
          final inset = rawInsets[edge];
          return inset is num && inset.isFinite && inset >= 0;
        }) &&
        rawWidth is num &&
        rawWidth.isFinite &&
        rawWidth > 0 &&
        rawHeight is num &&
        rawHeight.isFinite &&
        rawHeight > 0;
    return WindowLayoutSnapshot(
      mode: mode,
      isLandscape: value['isLandscape'] as bool,
      stable: value['stable'] != false,
      physicalSize: value['windowWidth'] is num && value['windowHeight'] is num
          ? Size(
              (value['windowWidth'] as num).toDouble(),
              (value['windowHeight'] as num).toDouble(),
            )
          : null,
      physicalStableInsets: validInsets
          ? EdgeInsets.fromLTRB(
              (rawInsets['left'] as num).toDouble(),
              (rawInsets['top'] as num).toDouble(),
              (rawInsets['right'] as num).toDouble(),
              (rawInsets['bottom'] as num).toDouble(),
            )
          : null,
      insetsViewSize: validInsets
          ? Size(rawWidth.toDouble(), rawHeight.toDouble())
          : null,
    );
  }

  final WindowLayoutMode mode;
  final bool isLandscape;
  final bool stable;
  final Size? physicalSize;
  final EdgeInsets? physicalStableInsets;
  final Size? insetsViewSize;

  GameFitAxis? get stableFitAxis => switch (mode) {
    WindowLayoutMode.sideBySide => GameFitAxis.width,
    WindowLayoutMode.stacked => GameFitAxis.height,
    WindowLayoutMode.single =>
      isLandscape ? GameFitAxis.height : GameFitAxis.width,
    WindowLayoutMode.unknown || WindowLayoutMode.pictureInPicture => null,
  };
}

/// Android supplies split topology; a compact window's shape cannot identify
/// whether another app is alongside it or above it.
final class WindowLayoutController extends ChangeNotifier {
  static WindowLayoutController? _shared;
  static int _sharedUsers = 0;

  static WindowLayoutController acquire() {
    final controller = _shared ??= WindowLayoutController();
    _sharedUsers++;
    unawaited(controller.initialize());
    return controller;
  }

  static void release(WindowLayoutController controller) {
    assert(identical(controller, _shared) && _sharedUsers > 0);
    if (--_sharedUsers == 0) {
      _shared = null;
      controller.dispose();
    }
  }

  WindowLayoutController({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('app.yahagi.kancollebrowser/window_layout');

  final MethodChannel _channel;
  WindowLayoutSnapshot? _layout;
  GameFitAxis? _stableFitAxis;
  GameFitAxis? _pendingFallbackAxis;
  bool _initialReadCompleted = false;
  bool _initialized = false;
  bool _disposed = false;
  int _nativeEventGeneration = 0;

  bool canSynchronize(
    Size? physicalSize, {
    bool requireMatchingPhysicalSize = true,
  }) {
    // WindowMetrics covers the entire Android window. In windowed mode its
    // system bars can sit outside the Flutter surface, so the sizes can differ
    // permanently even after both sides finish resizing.

    final nativePhysicalSize = _layout?.insetsViewSize ?? _layout?.physicalSize;

    final sizeMatches =
        nativePhysicalSize == null ||
        nativePhysicalSize == physicalSize ||
        _layout?.physicalSize == physicalSize;
    final permitted =
        _initialReadCompleted &&
        (_layout?.stable ?? true) &&
        (!requireMatchingPhysicalSize || sizeMatches);
    if (permitted && sizeMatches) {
      // Only matching native geometry may update the fullscreen fit axis.
      _stableFitAxis = _layout?.stableFitAxis ?? _stableFitAxis;
    }
    return permitted;
  }

  /// Insets ignoring system-bar visibility, relative to the Flutter surface.
  /// The native window can include bars already outside that surface.
  EdgeInsets? stableViewPadding({
    required Size physicalViewSize,
    required double devicePixelRatio,
  }) {
    final layout = _layout;
    final insets = layout?.physicalStableInsets;
    if (!_initialReadCompleted ||
        layout?.stable != true ||
        insets == null ||
        layout!.insetsViewSize != physicalViewSize ||
        !devicePixelRatio.isFinite ||
        devicePixelRatio <= 0) {
      return null;
    }
    return insets / devicePixelRatio;
  }

  GameFitAxis fitAxis({required bool isLandscape, Size? physicalSize}) {
    final fallback = (_layout?.isLandscape ?? isLandscape)
        ? GameFitAxis.height
        : GameFitAxis.width;
    if (!canSynchronize(physicalSize)) {
      return _stableFitAxis ?? (_pendingFallbackAxis ??= fallback);
    }
    _pendingFallbackAxis = null;
    _stableFitAxis = _layout?.stableFitAxis ?? _stableFitAxis;
    return _stableFitAxis ?? fallback;
  }

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'windowLayoutChanged' || _disposed) return;
      _nativeEventGeneration++;
      if (WindowLayoutSnapshot.fromMap(call.arguments) != null) {
        _initialReadCompleted = true;
      }
      _update(call.arguments);
    });
    final generation = _nativeEventGeneration;
    try {
      final initial = await _channel.invokeMethod<Map>('getWindowLayout');
      if (!_disposed && generation == _nativeEventGeneration) _update(initial);
    } on MissingPluginException {
      // Widget tests and other platforms use the current orientation fallback.
    } on PlatformException {
      // Native layout discovery may be unavailable during activity startup.
    } finally {
      if (!_disposed) {
        _initialReadCompleted = true;
        notifyListeners();
      }
    }
  }

  void _update(Object? value) {
    final next = WindowLayoutSnapshot.fromMap(value);
    if (next == null ||
        (next.mode == _layout?.mode &&
            next.isLandscape == _layout?.isLandscape &&
            next.stable == _layout?.stable &&
            next.physicalSize == _layout?.physicalSize &&
            next.physicalStableInsets == _layout?.physicalStableInsets &&
            next.insetsViewSize == _layout?.insetsViewSize)) {
      return;
    }
    _layout = next;
    if (next.stable && next.physicalSize == null) {
      _stableFitAxis = next.stableFitAxis ?? _stableFitAxis;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_initialized) _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
