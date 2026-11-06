import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_reminder_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';

class Fixture {
  final nav = GlobalKey<NavigatorState>();
  var gameDowns = 0;
  late GameSurfaceInputGuardRoute guard;
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => gameDowns++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    guard = GameSurfaceInputGuardRoute(
      context: nav.currentContext!,
      maximumProtectionDuration: const Duration(seconds: 2),
    );
    unawaited(nav.currentState!.push<void>(guard));
    await tester.pump();
    await tester.pump();
  }

  Future<void> keepQuietPending(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tapAt(const Offset(20, 200));
    }
  }
}

class _CoverObserver extends NavigatorObserver {
  final covers = <Route<dynamic>>{};
  bool waitingForBattle = false;
  int uncoveredHandoffs = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ImmediateGameSurfaceCoverRoute) covers.add(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    covers.remove(route);
    if (waitingForBattle && covers.isEmpty) uncoveredHandoffs++;
  }
}

void main() {
  for (final withHandoff in [false, true]) {
    testWidgets(
      'deadline-frame Down revokes removal and resumes at real Up: handoff=$withHandoff',
      (tester) async {
        final f = Fixture();
        await f.mount(tester);
        var handoffDone = false;
        var pushedBeforeGuardRemoval = false;
        if (withHandoff) {
          unawaited(
            GameSurfaceInputGuardRoute.waitUntilReadyForHandoff(
              f.nav.currentState!,
            ).then((_) {
              handoffDone = true;
              pushedBeforeGuardRemoval = f.guard.isActive;
              unawaited(
                f.nav.currentState!.push<void>(
                  GameSafetyDialogRoute(
                    context: f.nav.currentContext!,
                    builder: (_) =>
                        const AlertDialog(title: Text('queued battle')),
                  ),
                ),
              );
            }),
          );
        }
        await f.keepQuietPending(tester);
        tester.binding.scheduleFrameCallback((_) {
          tester.binding.handlePointerEvent(
            const PointerDownEvent(pointer: 81, position: Offset(20, 200)),
          );
        });
        await tester.pump(const Duration(milliseconds: 251));
        expect(f.guard.isActive, isTrue);
        expect(handoffDone, isFalse);
        await tester.pump(const Duration(seconds: 2));
        expect(f.guard.isActive, isTrue);
        tester.binding.handlePointerEvent(
          const PointerUpEvent(pointer: 81, position: Offset(20, 200)),
        );
        await tester.pump();
        await tester.pump();
        expect(f.guard.isActive, isFalse);
        expect(f.gameDowns, 0);
        if (withHandoff) {
          expect(handoffDone, isTrue);
          expect(pushedBeforeGuardRemoval, isTrue);
          expect(find.text('queued battle'), findsOneWidget);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'maximum-triggered handoff preserves cover and navigator teardown clears both tickers',
    (tester) async {
      final f = Fixture();
      await f.mount(tester);
      var handoffDone = false;
      var coverRetained = false;
      unawaited(
        GameSurfaceInputGuardRoute.waitUntilReadyForHandoff(
          f.nav.currentState!,
        ).then((_) {
          handoffDone = true;
          coverRetained = f.guard.isActive;
          unawaited(
            f.nav.currentState!.push<void>(
              GameSafetyDialogRoute(
                context: f.nav.currentContext!,
                builder: (_) => const AlertDialog(title: Text('next battle')),
              ),
            ),
          );
        }),
      );
      await f.keepQuietPending(tester);
      await tester.pump(const Duration(milliseconds: 251));
      await tester.pump();
      expect(handoffDone, isTrue);
      expect(coverRetained, isTrue);
      expect(f.guard.isActive, isFalse);
      expect(find.text('next battle'), findsOneWidget);
      expect(f.gameDowns, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final cancelPointer in [false, true]) {
    testWidgets(
      'zero-duration dismissal covers a battle queued before guard creation: cancel=$cancelPointer',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final observer = _CoverObserver();
        var gameDowns = 0;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [observer],
            home: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => gameDowns++,
              child: const SizedBox.expand(),
            ),
          ),
        );
        final reminder = showGameReminderDialog(
          context: navigator.currentContext!,
          kind: 'surfaceDialog',
          title: 'frame confirmation',
          message: '',
          needsPostTouchProtection: () => false,
          builder: (_, acknowledge) => AlertDialog(
            title: const Text('frame confirmation'),
            actions: [
              TextButton(onPressed: acknowledge, child: const Text('cancel')),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final held = await tester.startGesture(
          tester.getCenter(find.text('frame confirmation')),
          pointer: 101,
        );
        await tester.tap(find.text('cancel'));
        await tester.pump();
        expect(
          GameSurfaceInputGuardRoute.hasActiveFor(navigator.currentState!),
          isFalse,
        );

        observer.waitingForBattle = true;
        var battlePushed = false;
        Future<void> showQueuedBattle() async {
          while (true) {
            // Use the real battle queue's combined wait and immediate recheck.
            // The guard does not exist yet when this first wait is registered.
            await Future.wait<void>([
              GameSafetyDialogRoute.waitUntilInputProtectionIdle(
                navigator.currentState!,
              ),
              GameSurfaceInputGuardRoute.waitUntilReadyForHandoff(
                navigator.currentState!,
              ),
            ]);
            if (GameSafetyDialogRoute.hasInputProtectionFor(
                  navigator.currentState!,
                ) ||
                GameSurfaceInputGuardRoute.hasBlockingForHandoff(
                  navigator.currentState!,
                )) {
              continue;
            }
            unawaited(
              navigator.currentState!.push<void>(
                GameSafetyDialogRoute(
                  context: navigator.currentContext!,
                  builder: (_) =>
                      const AlertDialog(title: Text('queued battle')),
                ),
              ),
            );
            battlePushed = true;
            observer.waitingForBattle = false;
            return;
          }
        }

        unawaited(showQueuedBattle());
        if (cancelPointer) {
          await held.cancel();
        } else {
          await held.up();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        expect(battlePushed, isTrue);
        expect(observer.uncoveredHandoffs, 0);
        expect(find.text('queued battle'), findsOneWidget);
        expect(
          GameSurfaceInputGuardRoute.hasBlockingForHandoff(
            navigator.currentState!,
          ),
          isFalse,
        );
        await tester.pumpAndSettle();
        expect(await reminder.completed, isTrue);
        expect(gameDowns, 0);
      },
    );
  }

  testWidgets('zero-duration handoff still waits for a new held pointer', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final prerequisite = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
    );
    final guard = GameSurfaceInputGuardRoute(
      context: navigator.currentContext!,
      maximumProtectionDuration: Duration.zero,
      releaseAfter: prerequisite.future,
    );
    unawaited(navigator.currentState!.push<void>(guard));
    await tester.pump();
    final pointer = await tester.startGesture(const Offset(100, 100));
    prerequisite.complete();
    await tester.pump();
    expect(guard.isActive, isTrue);
    expect(
      GameSurfaceInputGuardRoute.hasBlockingForHandoff(navigator.currentState!),
      isTrue,
    );
    await pointer.up();
    await tester.pump();
    await tester.pump();
    expect(guard.isActive, isFalse);
  });

  testWidgets('teardown revokes a pending zero-duration prerequisite', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final prerequisite = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
    );
    unawaited(
      navigator.currentState!.push<void>(
        GameSurfaceInputGuardRoute(
          context: navigator.currentContext!,
          maximumProtectionDuration: Duration.zero,
          releaseAfter: prerequisite.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    prerequisite.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
