import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';

void main() {
  Future<
    ({GlobalKey<NavigatorState> navigator, GameSurfaceInputGuardRoute route})
  >
  showGuard(WidgetTester tester, VoidCallback onTap) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: const SizedBox.expand(),
        ),
      ),
    );
    final route = GameSurfaceInputGuardRoute(
      context: navigator.currentContext!,
    );
    unawaited(navigator.currentState!.push<void>(route));
    await tester.pump();
    await tester.pump();
    return (navigator: navigator, route: route);
  }

  testWidgets('quiet protection blocks touch then restores the surface', (
    tester,
  ) async {
    var taps = 0;
    await showGuard(tester, () => taps++);
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
  });

  testWidgets('each repeated touch starts a new quiet interval', (
    tester,
  ) async {
    var taps = 0;
    await showGuard(tester, () => taps++);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(100, 100));
      expect(taps, 0);
      expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    }
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
  });

  testWidgets('a held pointer cannot outlive the protection', (tester) async {
    var taps = 0;
    await showGuard(tester, () => taps++);
    final pointer = await tester.startGesture(const Offset(100, 100));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await pointer.up();
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    expect(taps, 0);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
  });

  testWidgets('cancelled pointers also restart the quiet interval', (
    tester,
  ) async {
    var taps = 0;
    await showGuard(tester, () => taps++);
    final pointer = await tester.startGesture(const Offset(100, 100));
    await tester.pump(const Duration(seconds: 2));
    await pointer.cancel();
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
    expect(taps, 0);
  });

  testWidgets('all held pointers must end before quiet protection starts', (
    tester,
  ) async {
    var taps = 0;
    await showGuard(tester, () => taps++);
    final first = await tester.startGesture(
      const Offset(100, 100),
      pointer: 10,
    );
    final second = await tester.startGesture(
      const Offset(200, 100),
      pointer: 11,
    );
    await first.up();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await second.up();
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
    expect(taps, 0);
  });

  testWidgets('protection also tracks pointers on a newer covering dialog', (
    tester,
  ) async {
    final fixture = await showGuard(tester, () {});
    unawaited(
      fixture.navigator.currentState!.push<void>(
        DialogRoute<void>(
          context: fixture.navigator.currentContext!,
          builder: (_) => const AlertDialog(title: Text('covering warning')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final first = await tester.startGesture(
      tester.getCenter(find.text('covering warning')),
      pointer: 51,
    );
    final second = await tester.startGesture(
      tester.getCenter(find.text('covering warning')) + const Offset(10, 0),
      pointer: 52,
    );
    await first.up();
    await tester.pump(const Duration(seconds: 2));
    expect(fixture.route.isActive, isTrue);
    await second.cancel();
    await tester.pump(const Duration(milliseconds: 599));
    expect(fixture.route.isActive, isTrue);
    await tester.pumpAndSettle();
    expect(fixture.route.isActive, isFalse);
    expect(find.text('covering warning'), findsOneWidget);
  });

  testWidgets(
    'a safety route keeps old pointer paths until a guarded handoff',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
      );
      final context = navigator.currentContext!;
      final warning = GameSafetyDialogRoute(
        context: context,
        builder: (_) => const AlertDialog(title: Text('old warning')),
      );
      unawaited(navigator.currentState!.push<void>(warning));
      await tester.pumpAndSettle();
      final pointer = await tester.startGesture(
        tester.getCenter(find.text('old warning')),
        pointer: 53,
      );
      expect(warning.activePointers, {53});
      warning.reserveInputProtection();
      warning.showReservedInputProtection();
      var released = false;
      warning.waitForPointersReleased().then((_) => released = true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
      expect(released, isFalse);
      await pointer.cancel();
      await tester.pump();
      expect(released, isTrue);
      final guard = GameSurfaceInputGuardRoute(context: context);
      unawaited(navigator.currentState!.push<void>(guard));
      navigator.currentState!.removeRoute(warning);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 599));
      expect(guard.isActive, isTrue);
      await tester.pumpAndSettle();
      expect(guard.isActive, isFalse);
    },
  );

  testWidgets('Back cannot remove the protection early', (tester) async {
    final fixture = await showGuard(tester, () {});
    expect(await fixture.navigator.currentState!.maybePop(), isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fixture.route.isActive, isTrue);
    await tester.pumpAndSettle();
    expect(fixture.route.isActive, isFalse);
  });

  testWidgets('expiry removes itself without dismissing a newer dialog', (
    tester,
  ) async {
    final fixture = await showGuard(tester, () {});
    unawaited(
      fixture.navigator.currentState!.push<void>(
        DialogRoute<void>(
          context: fixture.navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('newer warning')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.route.isActive, isFalse);
    expect(find.text('newer warning'), findsOneWidget);
    fixture.navigator.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('extension prevents an earlier expiry', (tester) async {
    final fixture = await showGuard(tester, () {});
    await tester.pump(const Duration(milliseconds: 500));
    fixture.route.extendProtection();
    await tester.pump(const Duration(milliseconds: 599));
    expect(fixture.route.isActive, isTrue);
    await tester.pumpAndSettle();
    expect(fixture.route.isActive, isFalse);
  });

  testWidgets('extension at completion invalidates the queued removal', (
    tester,
  ) async {
    final fixture = await showGuard(tester, () {});
    var extended = false;
    tester.binding.scheduleFrameCallback((_) {
      extended = true;
      fixture.route.extendProtection();
    });
    await tester.pump(const Duration(milliseconds: 601));
    expect(extended, isTrue);
    expect(fixture.route.isActive, isTrue);
    await tester.pumpAndSettle();
    expect(fixture.route.isActive, isFalse);
  });

  testWidgets('pushing protection removes the old warning in one frame', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
    );
    final warning = GameSafetyDialogRoute(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(content: Text('old warning')),
    );
    unawaited(navigator.currentState!.push<void>(warning));
    await tester.pumpAndSettle();
    final guard = GameSurfaceInputGuardRoute(
      context: navigator.currentContext!,
    );
    unawaited(navigator.currentState!.push<void>(guard));
    navigator.currentState!.removeRoute(warning);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(guard.isActive, isTrue);
    await tester.pumpAndSettle();
    expect(guard.isActive, isFalse);
  });

  testWidgets('cancelling for teardown does not pop a newer dialog', (
    tester,
  ) async {
    final fixture = await showGuard(tester, () {});
    unawaited(
      fixture.navigator.currentState!.push<void>(
        DialogRoute<void>(
          context: fixture.navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('newer warning')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    fixture.route.cancelProtection();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('newer warning'), findsOneWidget);
    expect(fixture.route.isActive, isTrue);
    fixture.navigator.currentState!.removeRoute(fixture.route);
    fixture.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the navigator leaves no protection ticker', (
    tester,
  ) async {
    await showGuard(tester, () {});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'safety dialogs and input guards request immediate native cover',
    (tester) async {
      final fixture = await showGuard(tester, () {});
      expect(fixture.route, isA<ImmediateGameSurfaceCoverRoute>());
      final safety = GameSafetyDialogRoute(
        context: fixture.navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('safety warning')),
      );
      expect(safety, isA<ImmediateGameSurfaceCoverRoute>());
      expect(safety.barrierDismissible, isFalse);
      await tester.pumpAndSettle();
    },
  );
}
