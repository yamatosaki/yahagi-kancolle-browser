import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_boundary.dart';

void main() {
  testWidgets('wraps the game surface in a stable repaint boundary', (
    tester,
  ) async {
    final parentState = ValueNotifier<int>(0);
    addTearDown(parentState.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: parentState,
          builder: (context, value, child) => GameSurfaceBoundary(
            child: const SizedBox(
              key: Key('isolated-game-surface'),
              width: 1200,
              height: 720,
            ),
          ),
        ),
      ),
    );
    final before = tester.element(
      find.byKey(const Key('isolated-game-surface')),
    );

    parentState.value += 1;
    await tester.pump();

    expect(
      find.byKey(const Key('game-surface-repaint-boundary')),
      findsOneWidget,
    );
    expect(
      identical(
        before,
        tester.element(find.byKey(const Key('isolated-game-surface'))),
      ),
      isTrue,
    );
  });
}
