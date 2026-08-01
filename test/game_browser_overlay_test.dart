import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_overlay.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';

void main() {
  testWidgets(
    'uses an invisible 160 by 40 swipe zone without arrow affordance',
    (tester) async {
      final controller = GameToolbarController();
      controller.collapse();

      await tester.pumpWidget(_TestApp(controller: controller));

      expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
      expect(find.byKey(const Key('game-toolbar-swipe-zone')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('game-toolbar-swipe-zone'))),
        const Size(160, 40),
      );
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('reveals only after a sufficiently long downward swipe', (
    tester,
  ) async {
    final controller = GameToolbarController();
    controller.collapse();

    await tester.pumpWidget(_TestApp(controller: controller));

    final zone = find.byKey(const Key('game-toolbar-swipe-zone'));
    await tester.drag(zone, const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(controller.isVisible, isFalse);

    await tester.drag(zone, const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(controller.isVisible, isTrue);
    controller.dispose();
  });

  testWidgets('rejects a swipe with excessive horizontal movement', (
    tester,
  ) async {
    final controller = GameToolbarController();
    controller.collapse();

    await tester.pumpWidget(_TestApp(controller: controller));

    await tester.drag(
      find.byKey(const Key('game-toolbar-swipe-zone')),
      const Offset(60, 40),
    );
    await tester.pumpAndSettle();

    expect(controller.isVisible, isFalse);
    controller.dispose();
  });

  testWidgets('overlay visibility never changes the game surface size', (
    tester,
  ) async {
    final controller = GameToolbarController();
    controller.collapse();

    await tester.pumpWidget(_TestApp(controller: controller));
    final gameFinder = find.byKey(const Key('fake-game-surface'));
    final hiddenSize = tester.getSize(gameFinder);

    controller.reveal();
    await tester.pumpAndSettle();

    expect(tester.getSize(gameFinder), hiddenSize);
    controller.dispose();
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.controller});

  final GameToolbarController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: GameBrowserOverlay(
            controller: controller,
            gameSurface: const ColoredBox(
              key: Key('fake-game-surface'),
              color: Colors.black,
            ),
            toolbar: const ColoredBox(
              key: Key('fake-toolbar'),
              color: Colors.blue,
              child: SizedBox(height: 48),
            ),
          ),
        ),
      ),
    );
  }
}
