import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/app_localizations.dart';
import 'game_surface_input_guard.dart';
import 'native_game_warning_dialog.dart';

/// An owned reminder. Successful acknowledgement waits for input protection.
/// Cancellation revokes the result while an already-active guard finishes.
class GameReminderDialogPresentation {
  GameReminderDialogPresentation._({
    required BuildContext context,
    required this.kind,
    required this.title,
    required this.message,
    required this.detail,
    required this.barrierDismissible,
    required this.allowFlutterFallback,
    required this._builder,
    required this._nativePort,
  }) : _context = context,
       _navigator = Navigator.of(context, rootNavigator: true),
       _id = ++_nextId;

  static int _nextId = 0;
  final BuildContext _context;
  final NavigatorState _navigator;
  final Widget Function(BuildContext, VoidCallback acknowledge) _builder;
  final NativeGameWarningDialogPort? _nativePort;
  final int _id;
  final String kind;
  final String title;
  final String message;
  final String? detail;
  final bool barrierDismissible;
  final bool allowFlutterFallback;
  final _completion = Completer<bool>();
  GameSafetyDialogRoute? _route;
  bool _active = true;
  bool _acknowledging = false;
  bool _nativeRequested = false;

  Future<bool> get completed => _completion.future;
  bool get isActive => _active;
  bool get isClosing => _acknowledging;

  void _start() {
    if (_nativePort != null) {
      unawaited(_showNative());
    } else {
      _showFlutter();
    }
  }

  Future<void> _showNative() async {
    final port = _nativePort!;
    _nativeRequested = true;
    try {
      final l10n = AppLocalizations.of(_context);
      final action = await port.show({
        'id': _id,
        'title': title,
        'headline': '',
        'body': [message, if (detail?.isNotEmpty == true) detail!].join('\n\n'),
        'rows': const <String>[],
        'actions': const ['acknowledge'],
        'labels': {
          'acknowledge':
              l10n?.acknowledge ??
              MaterialLocalizations.of(_context).okButtonLabel,
        },
        'enabled': const {'acknowledge': true},
      });
      _nativeRequested = false;
      if (!_active) return;
      if (action == NativeGameWarningAction.acknowledge) {
        // Reminder hosts settle only after their real input guard releases.
        _finish(true);
      } else if (action == null) {
        _finish(false);
      } else {
        throw StateError('Unexpected $kind reminder action: $action');
      }
    } catch (error) {
      if (!_active) return;
      debugPrint('Native $kind reminder unavailable: $error');
      _nativeRequested = false;
      _dismissNative();
      if (!allowFlutterFallback) {
        _finish(false);
        return;
      }
      // A failed show gets one protected fallback. The next independently
      // queued reminder may try the native host again.
      _showFlutter();
    }
  }

  void _showFlutter() {
    if (!_active || !_context.mounted || !_navigator.mounted) {
      _finish(false);
      return;
    }
    unawaited(
      Future.wait<void>([
        GameSurfaceInputGuardRoute.waitUntilIdle(_navigator),
        GameSafetyDialogRoute.waitUntilUnblocked(_navigator),
      ]).then((_) {
        _mutateNavigator(() {
          if (!_active || !_context.mounted || !_navigator.mounted) {
            _finish(false);
            return;
          }
          // Recheck in the same stack as push: a guard or battle warning can
          // have started between the idle Future and this navigator mutation.
          if (GameSurfaceInputGuardRoute.hasActiveFor(_navigator) ||
              GameSafetyDialogRoute.hasBlockingFor(_navigator)) {
            _showFlutter();
            return;
          }
          final route = GameSafetyDialogRoute(
            context: _context,
            barrierDismissible: barrierDismissible,
            blocksOtherReminders: false,
            builder: (context) => PopScope<void>(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _acknowledge();
              },
              child: _builder(context, _acknowledge),
            ),
          );
          _route = route;
          unawaited(_navigator.push<void>(route));
          unawaited(
            route.completed.then((_) {
              if (_active && !_acknowledging) _finish(false);
            }),
          );
        });
      }),
    );
  }

  void _acknowledge() {
    final route = _route;
    if (!_active ||
        _acknowledging ||
        route == null ||
        !route.isCurrent ||
        !_context.mounted ||
        !_navigator.mounted) {
      return;
    }
    _acknowledging = true;
    _beginProtection(route);
  }

  void _beginProtection(GameSafetyDialogRoute route) {
    // Navigator.push synthesizes Cancel for held pointers and discards their
    // hit-test paths. Preserve this route until their real Up/Cancel arrives.
    route.reserveInputProtection();
    _mutateNavigator(() {
      if (!_navigator.mounted || !route.isActive) return;
      route.showReservedInputProtection();
      unawaited(_handoffProtection(route));
    });
  }

  Future<void> _handoffProtection(GameSafetyDialogRoute route) async {
    await route.waitForPointersReleased();
    _mutateNavigator(() {
      if (!_navigator.mounted || !route.isActive) return;
      if (route.activePointers.isNotEmpty) {
        unawaited(_handoffProtection(route));
        return;
      }
      final guard = GameSurfaceInputGuardRoute(
        context: _navigator.overlay!.context,
        initialPointers: route.activePointers,
      );
      // Cover before removing exactly this dialog, never another modal. The
      // navigator's overlay survives the original reminder owner's disposal.
      unawaited(_navigator.push<void>(guard));
      _navigator.removeRoute(route);
      unawaited(_waitForProtection(route, guard));
    });
  }

  Future<void> _waitForProtection(
    GameSafetyDialogRoute route,
    GameSurfaceInputGuardRoute guard,
  ) async {
    await Future.wait<void>([route.completed, guard.completed]);
    if (_active) _finish(_context.mounted && _navigator.mounted);
  }

  /// Cancels only this request and never claims that its reminder was read.
  void cancel() {
    if (!_active) return;
    _finish(false);
    if (_nativeRequested) _dismissNative();
    final route = _route;
    // Once chosen, the protection outlives an obsolete owner/account. Cancelling
    // the read result must not release a held pointer into the game.
    if (_acknowledging) return;
    if (route?.isActive == true && route!.activePointers.isNotEmpty) {
      _beginProtection(route);
      return;
    }
    _mutateNavigator(() {
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    });
  }

  void _dismissNative() {
    final port = _nativePort;
    if (port == null) return;
    unawaited(
      Future<void>.sync(() => port.dismiss(_id)).catchError((Object error) {
        debugPrint('Native $kind reminder dismissal failed: $error');
      }),
    );
  }

  void _finish(bool acknowledged) {
    if (!_active) return;
    _active = false;
    _completion.complete(acknowledged);
  }

  static void _mutateNavigator(VoidCallback action) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.postFrameCallbacks) {
      action();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }
}

GameReminderDialogPresentation showGameReminderDialog({
  required BuildContext context,
  required String kind,
  required String title,
  required String message,
  String? detail,
  bool barrierDismissible = true,
  bool allowFlutterFallback = true,
  required Widget Function(BuildContext, VoidCallback acknowledge) builder,
  NativeGameWarningDialogPort? nativePort,
}) => GameReminderDialogPresentation._(
  context: context,
  kind: kind,
  title: title,
  message: message,
  detail: detail,
  barrierDismissible: barrierDismissible,
  allowFlutterFallback: allowFlutterFallback,
  builder: builder,
  nativePort: nativePort,
).._start();
