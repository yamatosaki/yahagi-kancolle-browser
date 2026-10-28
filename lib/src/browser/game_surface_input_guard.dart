import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Modal routes that must stop native game input before any preview work.
abstract interface class ImmediateGameSurfaceCoverRoute {}

class GameSafetyDialogRoute extends DialogRoute<void>
    implements ImmediateGameSurfaceCoverRoute {
  factory GameSafetyDialogRoute({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = false,
    bool blocksOtherReminders = true,
  }) {
    late final GameSafetyDialogRoute route;
    route = GameSafetyDialogRoute._(
      context: context,
      barrierDismissible: barrierDismissible,
      blocksOtherReminders: blocksOtherReminders,
      builder: (context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => route._activePointers.add(event.pointer),
        onPointerUp: (event) => route._releasePointer(event.pointer),
        onPointerCancel: (event) => route._releasePointer(event.pointer),
        child: ValueListenableBuilder<bool>(
          valueListenable: route._inputProtectionVisible,
          builder: (context, protecting, _) => protecting
              ? const PopScope<void>(
                  canPop: false,
                  child: SizedBox.expand(key: Key('game-safety-input-guard')),
                )
              : builder(context),
        ),
      ),
    );
    return route;
  }

  GameSafetyDialogRoute._({
    required super.context,
    required super.builder,
    required super.barrierDismissible,
    required this.blocksOtherReminders,
  });

  static final _activeByNavigator = Expando<Set<GameSafetyDialogRoute>>(
    'Game safety dialogs',
  );

  final bool blocksOtherReminders;
  final Set<int> _activePointers = <int>{};
  final _inputProtectionVisible = ValueNotifier(false);
  bool _inputProtectionReserved = false;
  Completer<void>? _pointersReleased;

  Set<int> get activePointers => Set<int>.unmodifiable(_activePointers);

  /// Preserve held fingers' hit-test paths before handing off to another route.
  void reserveInputProtection() => _inputProtectionReserved = true;

  void showReservedInputProtection() {
    if (!_inputProtectionReserved || !isActive) return;
    _inputProtectionVisible.value = true;
    changedInternalState();
  }

  Future<void> waitForPointersReleased() {
    if (_activePointers.isEmpty) return Future<void>.value();
    if (_pointersReleased == null || _pointersReleased!.isCompleted) {
      _pointersReleased = Completer<void>();
    }
    return _pointersReleased!.future;
  }

  void _releasePointer(int pointer) {
    _activePointers.remove(pointer);
    if (_activePointers.isEmpty && _pointersReleased?.isCompleted == false) {
      _pointersReleased!.complete();
    }
  }

  @override
  Color? get barrierColor =>
      _inputProtectionVisible.value ? Colors.transparent : super.barrierColor;

  @override
  bool get barrierDismissible =>
      !_inputProtectionReserved && super.barrierDismissible;

  bool get _blocksReminders => blocksOtherReminders || _inputProtectionReserved;

  static bool hasBlockingFor(NavigatorState navigator) =>
      _activeByNavigator[navigator]?.any((route) => route._blocksReminders) ==
      true;

  /// Only a closing dialog's preserved input target, not an open battle popup.
  static bool hasInputProtectionFor(NavigatorState navigator) =>
      _activeByNavigator[navigator]?.any(
        (route) => route._inputProtectionReserved,
      ) ==
      true;

  static Future<void> waitUntilInputProtectionIdle(
    NavigatorState navigator,
  ) async {
    while (hasInputProtectionFor(navigator)) {
      final routes = _activeByNavigator[navigator]!
          .where((route) => route._inputProtectionReserved)
          .toList();
      await Future.wait<void>(routes.map((route) => route.completed));
    }
  }

  static Future<void> waitUntilUnblocked(NavigatorState navigator) async {
    while (hasBlockingFor(navigator)) {
      final routes = _activeByNavigator[navigator]!
          .where((route) => route._blocksReminders)
          .toList();
      await Future.wait<void>(routes.map((route) => route.completed));
    }
  }

  static Set<int> _activePointersFor(NavigatorState navigator) => {
    for (final route
        in _activeByNavigator[navigator] ?? <GameSafetyDialogRoute>{})
      ...route._activePointers,
  };

  @override
  void install() {
    super.install();
    final owner = navigator!;
    (_activeByNavigator[owner] ??= <GameSafetyDialogRoute>{}).add(this);
    unawaited(completed.then((_) => _activeByNavigator[owner]?.remove(this)));
  }

  @override
  void dispose() {
    _inputProtectionVisible.dispose();
    if (_pointersReleased?.isCompleted == false) _pointersReleased!.complete();
    super.dispose();
  }
}

/// Swallows a burst of touches after a safety action, until input is quiet.
///
/// Its route transition is immediate so the preceding warning can disappear
/// immediately. A separate navigator-owned animation clocks the quiet period
/// without real timers or depending on the covered page's ticker mode.
class GameSurfaceInputGuardRoute extends RawDialogRoute<void>
    implements ImmediateGameSurfaceCoverRoute {
  static final _activeByNavigator = Expando<Set<GameSurfaceInputGuardRoute>>(
    'Game input guards',
  );

  static bool hasActiveFor(NavigatorState navigator) =>
      _activeByNavigator[navigator]?.isNotEmpty == true;

  static bool hasBlockingForHandoff(NavigatorState navigator) =>
      _activeByNavigator[navigator]?.any(
        (route) =>
            route.isActive && !route._disposed && !route._readyForHandoff,
      ) ==
      true;

  /// A queued safety modal can cover the surface before the quiet guard leaves.
  /// A new contact revokes readiness, so every caller must recheck before push.
  static Future<void> waitUntilReadyForHandoff(NavigatorState navigator) async {
    while (hasBlockingForHandoff(navigator)) {
      final routes = _activeByNavigator[navigator]!
          .where(
            (route) =>
                route.isActive && !route._disposed && !route._readyForHandoff,
          )
          .toList();
      await Future.wait<void>(routes.map((route) => route._handoffReady));
    }
  }

  /// Waits for all real guard overlays, including ones owned by battle warnings.
  /// A new guard registered while waiting is included in the next iteration.
  static Future<void> waitUntilIdle(NavigatorState navigator) async {
    while (hasActiveFor(navigator)) {
      final routes = _activeByNavigator[navigator]!.toList();
      await Future.wait<void>(routes.map((route) => route.completed));
    }
  }

  factory GameSurfaceInputGuardRoute({
    required BuildContext context,
    Iterable<int> initialPointers = const <int>[],
  }) {
    late final GameSurfaceInputGuardRoute route;
    route = GameSurfaceInputGuardRoute._(
      initialPointers: {
        ...initialPointers,
        ...GameSafetyDialogRoute._activePointersFor(
          Navigator.of(context, rootNavigator: true),
        ),
      },
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (_, _, _) => PopScope<void>(
        canPop: false,
        child: Listener(
          key: const Key('game-safety-input-guard'),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
      ),
    );
    return route;
  }

  GameSurfaceInputGuardRoute._({
    required super.pageBuilder,
    required Set<int> initialPointers,
    required String barrierLabel,
  }) : _activePointers = initialPointers,
       super(
         barrierLabel: barrierLabel,
         barrierColor: Colors.transparent,
         barrierDismissible: false,
         settings: const RouteSettings(name: 'yahagi.gameInputGuard'),
         transitionDuration: Duration.zero,
         transitionBuilder: (_, _, _, child) => child,
       );

  static const protectionDuration = Duration(milliseconds: 600);

  final Set<int> _activePointers;
  AnimationController? _quietController;
  bool _cancelled = false;
  bool _disposed = false;
  int _quietGeneration = 0;
  bool _readyForHandoff = false;
  bool _hasHandoffWaiter = false;
  Completer<void> _handoffSignal = Completer<void>();

  Future<void> get _handoffReady {
    _hasHandoffWaiter = true;
    return _handoffSignal.future;
  }

  /// Starts a fresh quiet interval, or pauses it while a pointer is held.
  void extendProtection() {
    if (_disposed || _cancelled) return;
    _quietGeneration++;
    _readyForHandoff = false;
    if (_handoffSignal.isCompleted) {
      _handoffSignal = Completer<void>();
      _hasHandoffWaiter = false;
    }
    if (_activePointers.isNotEmpty) {
      _quietController?.stop();
    } else {
      _quietController?.forward(from: 0);
    }
  }

  /// Stops expiry for owner teardown. The owner still removes this route.
  void cancelProtection() {
    if (_disposed || _cancelled) return;
    _cancelled = true;
    _quietGeneration++;
    _activePointers.clear();
    _quietController?.stop();
  }

  void _onPointerEvent(PointerEvent event) {
    if (_disposed || _cancelled) return;
    if (event is PointerDownEvent) {
      _activePointers.add(event.pointer);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _activePointers.remove(event.pointer);
    } else {
      return;
    }
    extendProtection();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _disposed || _cancelled) return;
    final generation = _quietGeneration;
    scheduleMicrotask(() {
      if (_disposed ||
          _cancelled ||
          generation != _quietGeneration ||
          _activePointers.isNotEmpty ||
          !isActive) {
        return;
      }
      _readyForHandoff = true;
      if (!_handoffSignal.isCompleted) _handoffSignal.complete();
      void removeIfStillQuiet() {
        if (!_disposed &&
            !_cancelled &&
            generation == _quietGeneration &&
            _activePointers.isEmpty &&
            isActive) {
          navigator?.removeRoute(this);
        }
      }

      if (_hasHandoffWaiter) {
        // Drain ready-Future continuations before removal. They synchronously
        // push the next modal, keeping native visibility covered throughout.
        scheduleMicrotask(() {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => removeIfStillQuiet(),
          );
          WidgetsBinding.instance.ensureVisualUpdate();
        });
      } else {
        removeIfStillQuiet();
      }
    });
  }

  @override
  void install() {
    super.install();
    final owner = navigator!;
    (_activeByNavigator[owner] ??= <GameSurfaceInputGuardRoute>{}).add(this);
    unawaited(completed.then((_) => _activeByNavigator[owner]?.remove(this)));
    // The original dialog may already own a pointer's hit-test path. Global
    // routing keeps its eventual Up/Cancel observable after that widget leaves.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    _quietController = AnimationController(
      vsync: navigator!,
      duration: protectionDuration,
      debugLabel: 'Game safety input protection',
    )..addStatusListener(_onAnimationStatus);
  }

  @override
  TickerFuture didPush() {
    final transition = super.didPush();
    if (!_cancelled && _activePointers.isEmpty) _quietController?.forward();
    return transition;
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_handoffSignal.isCompleted) _handoffSignal.complete();
    _quietGeneration++;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    _quietController
      ?..removeStatusListener(_onAnimationStatus)
      ..dispose();
    _quietController = null;
    super.dispose();
  }
}
