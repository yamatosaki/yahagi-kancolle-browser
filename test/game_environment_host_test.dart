import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_environment_host.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';

void main() {
  testWidgets('restart removes the old game for one frame before rebuilding', (
    tester,
  ) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);
    var beforeRestartCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          beforeRestart: () async => beforeRestartCalls += 1,
          gameBuilder: (context, mode, key) => ColoredBox(
            key: key,
            color: Colors.black,
            child: Text('game-${mode.storageName}'),
          ),
        ),
      ),
    );

    expect(find.text('game-compatibility'), findsOneWidget);

    final changing = controller.changeMode(GameRenderingMode.standard);
    await tester.pump();

    expect(find.text('game-standard'), findsNothing);
    expect(find.text('game-compatibility'), findsNothing);
    expect(
      find.byKey(const Key('game-environment-restarting')),
      findsOneWidget,
    );

    await tester.pump();
    expect(find.text('game-standard'), findsOneWidget);
    expect((await changing).status, GameRenderingModeChangeStatus.applied);
    expect(beforeRestartCalls, 1);
  });

  testWidgets('host keeps exactly one game after repeated sequential changes', (
    tester,
  ) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          gameBuilder: (context, mode, key) =>
              SizedBox(key: key, child: Text('game-${mode.storageName}')),
        ),
      ),
    );

    for (final mode in <GameRenderingMode>[
      GameRenderingMode.standard,
      GameRenderingMode.canvasCompatibility,
      GameRenderingMode.compatibility,
    ]) {
      final changing = controller.changeMode(mode);
      await tester.pump();
      expect(find.textContaining('game-'), findsNothing);
      await tester.pump();
      await changing;
      expect(find.text('game-${mode.storageName}'), findsOneWidget);
    }
  });

  testWidgets('disposing the host detaches its restart port', (tester) async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameEnvironmentHost(
          controller: controller,
          gameBuilder: (context, mode, key) => SizedBox(key: key),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    final result = await controller.changeMode(GameRenderingMode.standard);
    expect(result.status, GameRenderingModeChangeStatus.unavailable);
  });
}
