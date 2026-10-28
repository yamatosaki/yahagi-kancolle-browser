import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../layout/camera_avoidance.dart';
import 'game_surface_input_guard.dart';
import 'game_workspace_visibility.dart';
import 'native_game_surface_visibility.dart';
import 'native_game_webview_contract.dart';

NativeGameWebViewBounds? readNativeGameSurfaceBounds(
  RenderObject? renderObject, {
  required double devicePixelRatio,
}) {
  if (renderObject is! RenderBox || !renderObject.attached) {
    return null;
  }
  return nativeGameSurfaceBoundsFromMetrics(
    size: renderObject.size,
    offset: renderObject.localToGlobal(Offset.zero),
    devicePixelRatio: devicePixelRatio,
  );
}

NativeGameWebViewBounds? nativeGameSurfaceBoundsFromMetrics({
  required Size size,
  required Offset offset,
  required double devicePixelRatio,
}) {
  if (!size.width.isFinite ||
      !size.height.isFinite ||
      size.width <= 0 ||
      size.height <= 0 ||
      !offset.dx.isFinite ||
      !offset.dy.isFinite ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return null;
  }
  return NativeGameWebViewBounds(
    left: offset.dx,
    top: offset.dy,
    width: size.width,
    height: size.height,
    devicePixelRatio: devicePixelRatio,
  );
}

/// A transparent Flutter layout slot whose bounds are mirrored to a native
/// game WebView owned outside of Flutter's widget tree.
final class NativeGameSurfaceSlot extends StatefulWidget {
  const NativeGameSurfaceSlot({
    required this.onBoundsChanged,
    required this.onVisibilityChanged,
    this.onBeforePopupRouteHidden,
    this.onImmediatePopupRouteHidden,
    this.onPopupRouteRevealStarted,
    this.onAfterPopupRouteRevealed,
    this.routeObserver,
    this.boundsSinkIdentity,
    this.boundsRetryLimit = 3,
    super.key,
  }) : assert(boundsRetryLimit > 0);

  final Future<void> Function(NativeGameWebViewBounds bounds) onBoundsChanged;
  final Future<void> Function(bool visible) onVisibilityChanged;
  final Future<void> Function()? onBeforePopupRouteHidden;
  final VoidCallback? onImmediatePopupRouteHidden;
  final VoidCallback? onPopupRouteRevealStarted;
  final VoidCallback? onAfterPopupRouteRevealed;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;
  final Object? boundsSinkIdentity;
  final int boundsRetryLimit;

  @override
  State<NativeGameSurfaceSlot> createState() => _NativeGameSurfaceSlotState();
}

final class _NativeGameSurfaceSlotState extends State<NativeGameSurfaceSlot>
    with WidgetsBindingObserver, RouteAware {
  late final NativeGameSurfaceVisibility _visibility;
  RouteObserver<ModalRoute<dynamic>>? _subscribedObserver;
  EdgeInsets _cameraInsets = EdgeInsets.zero;
  Set<CameraAvoidanceEdge> _cameraEdges = const <CameraAvoidanceEdge>{};
  bool _cameraEnabled = false;
  bool _cameraGeometryKnown = false;
  bool _forceBoundsSyncForCamera = false;
  ModalRoute<dynamic>? _subscribedRoute;
  NativeGameWebViewBounds? _lastBounds;
  NativeGameWebViewBounds? _currentBounds;
  NativeGameWebViewBounds? _queuedBounds;
  NativeGameWebViewBounds? _retryBounds;
  bool _boundsDrainRunning = false;
  bool _boundsRetryScheduled = false;
  bool _boundsRetryExhausted = false;
  int _boundsRetryAttempts = 0;
  int _boundsGeneration = 0;
  bool _resendCurrentBoundsToNewSink = false;
  bool _measureScheduled = false;
  bool _boundsSyncDeferredForIme = false;
  FlutterView? _view;
  bool _synchronizingRouteSubscription = false;
  bool? _workspaceActive;
  bool _popupRouteCoverActive = false;
  int _routeCoverGeneration = 0;

  Object get _effectiveBoundsSinkIdentity =>
      widget.boundsSinkIdentity ?? widget.onBoundsChanged;

  static bool _isAppVisibleForLifecycle(AppLifecycleState? state) {
    return state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  @override
  void initState() {
    super.initState();
    _visibility = NativeGameSurfaceVisibility(widget.onVisibilityChanged);
    WidgetsBinding.instance.addObserver(this);
    _ignoreErrors(
      _visibility.setAppVisible(
        _isAppVisibleForLifecycle(WidgetsBinding.instance.lifecycleState),
      ),
    );
    _scheduleMeasurement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    final camera = CameraAvoidanceScope.maybeOf(context);
    final insets =
        camera?.synchronizationInsets ?? camera?.insets ?? EdgeInsets.zero;
    final edges = camera?.cutoutEdges ?? const <CameraAvoidanceEdge>{};
    final enabled = camera?.enabled ?? false;
    final cameraGeometryChanged =
        _cameraGeometryKnown &&
        (insets != _cameraInsets ||
            ((_cameraEnabled || enabled) &&
                (_cameraEdges.isNotEmpty || edges.isNotEmpty) &&
                (!setEquals(_cameraEdges, edges) ||
                    _cameraEnabled != enabled)));
    _cameraInsets = insets;
    _cameraEdges = edges;
    _cameraEnabled = enabled;
    _cameraGeometryKnown = true;
    if (cameraGeometryChanged) {
      // A deliberate camera viewport change must reach the native WebView
      // even while the IME is visible. Pure keyboard changes remain deferred.
      _forceBoundsSyncForCamera = true;
      _scheduleMeasurement();
    }
    final workspaceActive = GameWorkspaceActive.of(context);
    if (workspaceActive != _workspaceActive) {
      _workspaceActive = workspaceActive;
      _ignoreErrors(_visibility.setWorkspaceVisible(workspaceActive));
    }
    _subscribeToCurrentRoute();
  }

  @override
  void didUpdateWidget(covariant NativeGameSurfaceSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onVisibilityChanged != widget.onVisibilityChanged) {
      _visibility.updateCallback(widget.onVisibilityChanged);
    }
    final oldBoundsSinkIdentity =
        oldWidget.boundsSinkIdentity ?? oldWidget.onBoundsChanged;
    if (oldBoundsSinkIdentity != _effectiveBoundsSinkIdentity &&
        _currentBounds != null) {
      _boundsGeneration++;
      _lastBounds = null;
      _resendCurrentBoundsToNewSink = false;
      _queuedBounds = _currentBounds;
      _ignoreErrors(_visibility.setSlotAttached(false));
      _drainBounds();
    }
    if (oldWidget.routeObserver != widget.routeObserver) {
      _subscribeToCurrentRoute();
    }
    if (_boundsRetryExhausted) {
      _restartBoundsRetries();
    }
    _scheduleMeasurement();
  }

  @override
  void didChangeMetrics() {
    if (_isImeVisible && !_forceBoundsSyncForCamera) {
      _boundsSyncDeferredForIme = true;
      return;
    }
    if (_boundsSyncDeferredForIme) {
      _boundsSyncDeferredForIme = false;
    }
    _restartBoundsRetries();
    _scheduleMeasurement();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ignoreErrors(_visibility.setAppVisible(_isAppVisibleForLifecycle(state)));
  }

  @override
  void didPush() {
    if (_synchronizingRouteSubscription) {
      return;
    }
    _ignoreErrors(_visibility.setRouteVisible(true));
  }

  @override
  void didPop() {
    _ignoreErrors(_visibility.setRouteVisible(false));
  }

  @override
  void didPushNext() {
    final observer = widget.routeObserver;
    // The observer also notifies slots under an already-open popup. Its
    // immediate-cover notification has already hidden this slot exactly once.
    if (observer is YahagiGameRouteObserver &&
        observer.isPushingImmediateCoverRoute) {
      return;
    }
    final popupRoute =
        observer is YahagiGameRouteObserver && observer.isPushingPopupRoute;
    _routeCoverGeneration++;
    if (!popupRoute) {
      _popupRouteCoverActive = false;
      _ignoreErrors(_visibility.setRouteVisible(false));
      return;
    }
    _popupRouteCoverActive = true;
    final prepare = widget.onBeforePopupRouteHidden;
    if (prepare == null) {
      _ignoreErrors(_visibility.setRouteVisible(false));
      return;
    }
    final generation = _routeCoverGeneration;
    unawaited(_preparePopupRouteAndHide(generation, prepare));
  }

  void _onImmediateCover() {
    if (!mounted || _subscribedRoute?.isActive != true) return;
    _routeCoverGeneration++;
    _popupRouteCoverActive = true;
    _ignoreErrors(
      Future<void>.sync(() => widget.onImmediatePopupRouteHidden?.call()),
    );
    _ignoreErrors(_visibility.setRouteVisible(false));
  }

  @override
  void didPopNext() {
    _routeCoverGeneration++;
    final popupRoute = _popupRouteCoverActive;
    _popupRouteCoverActive = false;
    if (popupRoute) {
      widget.onPopupRouteRevealStarted?.call();
    }
    final generation = _routeCoverGeneration;
    final restore = _visibility.setRouteVisible(true);
    if (!popupRoute || widget.onAfterPopupRouteRevealed == null) {
      _ignoreErrors(restore);
      return;
    }
    unawaited(_finishPopupRouteRestore(generation, restore));
  }

  @override
  void dispose() {
    _routeCoverGeneration++;
    _boundsGeneration++;
    _currentBounds = null;
    _queuedBounds = null;
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeFromRoute();
    _ignoreErrors(_visibility.dispose());
    super.dispose();
  }

  Future<void> _preparePopupRouteAndHide(
    int generation,
    Future<void> Function() prepare,
  ) async {
    try {
      await prepare();
    } catch (error, stackTrace) {
      debugPrint(
        'Native game popup preview preparation failed: $error\n$stackTrace',
      );
    }
    if (!mounted ||
        generation != _routeCoverGeneration ||
        !_popupRouteCoverActive) {
      return;
    }
    _ignoreErrors(_visibility.setRouteVisible(false));
  }

  Future<void> _finishPopupRouteRestore(
    int generation,
    Future<void> restore,
  ) async {
    try {
      await restore;
    } catch (error, stackTrace) {
      debugPrint('Native game surface restore failed: $error\n$stackTrace');
      return;
    }
    if (!mounted || generation != _routeCoverGeneration) return;
    widget.onAfterPopupRouteRevealed?.call();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();

  void _subscribeToCurrentRoute() {
    final observer = widget.routeObserver;
    final route = ModalRoute.of(context);
    if (identical(observer, _subscribedObserver) &&
        identical(route, _subscribedRoute)) {
      return;
    }
    _unsubscribeFromRoute();
    if (observer == null || route == null) {
      _ignoreErrors(_visibility.setRouteVisible(true));
      return;
    }
    _synchronizingRouteSubscription = true;
    try {
      observer.subscribe(this, route);
    } finally {
      _synchronizingRouteSubscription = false;
    }
    _subscribedObserver = observer;
    _subscribedRoute = route;
    if (observer is YahagiGameRouteObserver) {
      observer.addImmediateCoverListener(_onImmediateCover);
    }
    _ignoreErrors(_visibility.setRouteVisible(route.isCurrent));
  }

  void _unsubscribeFromRoute() {
    final observer = _subscribedObserver;
    if (observer is YahagiGameRouteObserver) {
      observer.removeImmediateCoverListener(_onImmediateCover);
    }
    _subscribedObserver?.unsubscribe(this);
    _subscribedObserver = null;
    _subscribedRoute = null;
  }

  void _scheduleMeasurement() {
    if (_isImeVisible && !_forceBoundsSyncForCamera) {
      _boundsSyncDeferredForIme = true;
      return;
    }
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (mounted) {
        _measureAndReport();
      }
    });
  }

  void _measureAndReport() {
    if (_isImeVisible && !_forceBoundsSyncForCamera) {
      _boundsSyncDeferredForIme = true;
      return;
    }
    _boundsSyncDeferredForIme = false;
    _forceBoundsSyncForCamera = false;
    final bounds = readNativeGameSurfaceBounds(
      context.findRenderObject(),
      devicePixelRatio: View.of(context).devicePixelRatio,
    );
    if (bounds == null) {
      _invalidateBounds();
      return;
    }

    final changed = !_sameBounds(bounds, _currentBounds);
    if (changed) {
      _currentBounds = bounds;
      _boundsGeneration++;
      _restartBoundsRetries();
      _resendCurrentBoundsToNewSink = false;
    }
    if (_sameBounds(bounds, _lastBounds) &&
        !_boundsDrainRunning &&
        _queuedBounds == null &&
        !_resendCurrentBoundsToNewSink) {
      _ignoreErrors(_visibility.setSlotAttached(true));
      return;
    }
    if (_boundsRetryExhausted && !changed) {
      return;
    }
    if (!changed && _boundsDrainRunning && _queuedBounds == null) {
      return;
    }
    _resendCurrentBoundsToNewSink = false;
    _queuedBounds = bounds;
    _ignoreErrors(_visibility.setSlotAttached(false));
    _drainBounds();
  }

  bool get _isImeVisible => (_view?.viewInsets.bottom ?? 0) > 0;

  void _drainBounds() {
    if (_boundsDrainRunning) {
      return;
    }
    _boundsDrainRunning = true;
    unawaited(_runBoundsDrain());
  }

  Future<void> _runBoundsDrain() async {
    try {
      while (mounted && _queuedBounds != null) {
        final bounds = _queuedBounds!;
        final generation = _boundsGeneration;
        _queuedBounds = null;
        try {
          await widget.onBoundsChanged(bounds);
        } catch (error, stackTrace) {
          debugPrint(
            'Native game surface bounds callback failed: $error\n$stackTrace',
          );
          if (!mounted ||
              generation != _boundsGeneration ||
              !_sameBounds(bounds, _currentBounds)) {
            continue;
          }
          if (!_sameBounds(bounds, _retryBounds)) {
            _retryBounds = bounds;
            _boundsRetryAttempts = 0;
          }
          _boundsRetryAttempts++;
          if (_boundsRetryAttempts < widget.boundsRetryLimit) {
            _scheduleBoundsRetry();
          } else {
            _boundsRetryExhausted = true;
            _ignoreErrors(_visibility.setSlotAttached(false));
          }
          return;
        }
        _retryBounds = null;
        _boundsRetryAttempts = 0;
        if (generation == _boundsGeneration &&
            _sameBounds(bounds, _currentBounds) &&
            _queuedBounds == null) {
          _lastBounds = bounds;
          _ignoreErrors(_visibility.setSlotAttached(true));
        }
      }
    } finally {
      _boundsDrainRunning = false;
      if (mounted && _queuedBounds != null) {
        _drainBounds();
      }
    }
  }

  void _scheduleBoundsRetry() {
    if (_boundsRetryScheduled) {
      return;
    }
    _boundsRetryScheduled = true;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boundsRetryScheduled = false;
      if (!mounted || _boundsRetryExhausted || _currentBounds == null) {
        return;
      }
      _queuedBounds = _currentBounds;
      _drainBounds();
    });
  }

  void _restartBoundsRetries() {
    _boundsRetryExhausted = false;
    _boundsRetryAttempts = 0;
    _retryBounds = null;
  }

  void _invalidateBounds() {
    _boundsGeneration++;
    _currentBounds = null;
    _queuedBounds = null;
    _restartBoundsRetries();
    _ignoreErrors(_visibility.setSlotAttached(false));
  }

  static bool _sameBounds(
    NativeGameWebViewBounds first,
    NativeGameWebViewBounds? second,
  ) {
    return second != null &&
        first.left == second.left &&
        first.top == second.top &&
        first.width == second.width &&
        first.height == second.height &&
        first.devicePixelRatio == second.devicePixelRatio;
  }

  void _ignoreErrors(Future<void> future) {
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        debugPrint('Native game surface callback failed: $error\n$stackTrace');
      }),
    );
  }
}

/// Returns true if [route] obscures or overlays the screen in a way that requires
/// hiding the underlying native game WebView (e.g. full-screen [PageRoute], modal [DialogRoute],
/// or [ModalBottomSheetRoute]).
/// Returns false for non-modal popup overlays like [PopupMenuButton] or dropdown menus.
bool shouldRouteHideGameSurface(Route<dynamic>? route) {
  if (route == null) return false;
  if (route is ImmediateGameSurfaceCoverRoute) return true;
  if (route is PageRoute<dynamic>) return true;
  if (route is RawDialogRoute<dynamic>) return true;
  if (route is ModalBottomSheetRoute<dynamic>) return true;
  if (route is ModalRoute<dynamic>) {
    final barrierColor = route.barrierColor;
    if (barrierColor != null &&
        barrierColor != Colors.transparent &&
        (barrierColor.a * 255.0).round().clamp(0, 255) > 0) {
      return true;
    }
  }
  return false;
}

/// A [RouteObserver] that only notifies [RouteAware.didPushNext] and [RouteAware.didPopNext]
/// for modal routes (such as full-screen pages or modal dialogs), preventing lightweight non-modal
/// overlays (like popup menus and dropdowns) from accidentally hiding the native game surface.
class YahagiGameRouteObserver extends RouteObserver<ModalRoute<dynamic>> {
  Route<dynamic>? _routeBeingPushed;
  Route<dynamic>? _topRoute;
  final Set<VoidCallback> _immediateCoverListeners = <VoidCallback>{};

  bool get isPushingPopupRoute => _routeBeingPushed is PopupRoute<dynamic>;
  bool get isPushingImmediateCoverRoute =>
      _routeBeingPushed is ImmediateGameSurfaceCoverRoute;

  void addImmediateCoverListener(VoidCallback listener) =>
      _immediateCoverListeners.add(listener);

  void removeImmediateCoverListener(VoidCallback listener) =>
      _immediateCoverListeners.remove(listener);

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _topRoute = topRoute;
    super.didChangeTop(topRoute, previousTopRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    // RouteObserver only reports pops. Removing the top modal must also reveal
    // the game, while removing a covered route must keep the surface hidden.
    if (identical(route, _topRoute) && previousRoute?.isCurrent == true) {
      didPop(route, previousRoute);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!shouldRouteHideGameSurface(route)) {
      super.didPush(route, null);
      return;
    }
    _routeBeingPushed = route;
    try {
      if (isPushingImmediateCoverRoute) {
        for (final listener in _immediateCoverListeners.toList()) {
          listener();
        }
      }
      super.didPush(route, previousRoute);
    } finally {
      _routeBeingPushed = null;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!shouldRouteHideGameSurface(route)) {
      super.didPop(route, null);
      return;
    }
    super.didPop(route, previousRoute);
  }
}
