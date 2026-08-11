import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_section.dart';

void main() {
  Future<({GameRenderingModeController controller, _RestartPort port})>
  createController() async {
    final controller = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    final port = _RestartPort();
    controller.attachRestartPort(port);
    return (controller: controller, port: port);
  }

  Widget app(
    GameRenderingModeController controller, {
    bool isBattleActive = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GameRenderingModeSection(
          controller: controller,
          isBattleActive: isBattleActive,
        ),
      ),
    );
  }

  testWidgets('shows all three rendering modes', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);

    await tester.pumpWidget(app(state.controller));

    expect(find.byKey(const Key('rendering-mode-standard')), findsOneWidget);
    expect(
      find.byKey(const Key('rendering-mode-compatibility')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('rendering-mode-canvas')), findsOneWidget);
  });

  testWidgets('cancel keeps the current mode', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-compatibility')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rendering-mode-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('rendering-mode-cancel')));
    await tester.pumpAndSettle();

    expect(state.controller.mode, GameRenderingMode.standard);
    expect(state.port.modes, isEmpty);
  });

  testWidgets('confirm rebuilds using the selected mode', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-compatibility')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rendering-mode-confirm')));
    await tester.pumpAndSettle();

    expect(state.controller.mode, GameRenderingMode.compatibility);
    expect(state.port.modes, [GameRenderingMode.compatibility]);
  });

  testWidgets('battle state adds a stronger warning', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller, isBattleActive: true));

    await tester.tap(find.byKey(const Key('rendering-mode-canvas')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('rendering-mode-battle-warning')),
      findsOneWidget,
    );
  });

  testWidgets('busy state disables additional changes', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    state.port.blockNextRestart = true;
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-compatibility')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rendering-mode-confirm')));
    await tester.pump();

    expect(find.byKey(const Key('rendering-mode-progress')), findsOneWidget);
    final canvasTile = tester.widget<ListTile>(
      find.byKey(const Key('rendering-mode-canvas')),
    );
    expect(canvasTile.onTap, isNull);

    state.port.completeRestart();
    await tester.pumpAndSettle();
  });
}

final class _RestartPort implements GameEnvironmentRestartPort {
  final modes = <GameRenderingMode>[];
  bool blockNextRestart = false;
  Completer<void>? _restartCompleter;

  @override
  Future<void> restart(GameRenderingMode mode) async {
    modes.add(mode);
    if (!blockNextRestart) return;
    blockNextRestart = false;
    _restartCompleter = Completer<void>();
    await _restartCompleter!.future;
  }

  void completeRestart() => _restartCompleter?.complete();
}
