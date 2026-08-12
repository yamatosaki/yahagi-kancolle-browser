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

    final compatibilityTop = tester
        .getTopLeft(find.byKey(const Key('rendering-mode-compatibility')))
        .dy;
    final standardTop = tester
        .getTopLeft(find.byKey(const Key('rendering-mode-standard')))
        .dy;
    final canvasTop = tester
        .getTopLeft(find.byKey(const Key('rendering-mode-canvas')))
        .dy;
    expect(compatibilityTop, lessThan(standardTop));
    expect(standardTop, lessThan(canvasTop));

    for (final key in const <Key>[
      Key('rendering-mode-compatibility'),
      Key('rendering-mode-standard'),
      Key('rendering-mode-canvas'),
    ]) {
      final tile = tester.widget<ListTile>(find.byKey(key));
      expect(tile.contentPadding, const EdgeInsets.only(left: 4, right: 16));
      expect(tile.minLeadingWidth, 0);
      expect(tile.horizontalTitleGap, 0);
    }

    final titleLefts = <double>[
      for (final key in const <Key>[
        Key('rendering-mode-compatibility'),
        Key('rendering-mode-standard'),
        Key('rendering-mode-canvas'),
      ])
        tester
            .getTopLeft(
              find
                  .descendant(of: find.byKey(key), matching: find.byType(Text))
                  .first,
            )
            .dx,
    ];
    expect(titleLefts[1], titleLefts[0]);
    expect(titleLefts[2], titleLefts[0]);

    expect(find.text('标准模式（推荐）'), findsOneWidget);
    expect(find.text('高性能模式'), findsOneWidget);
    expect(find.text('兼容模式'), findsOneWidget);
    expect(find.textContaining('性能损耗平均'), findsOneWidget);
    expect(find.textContaining('性能损耗大，可能会卡顿'), findsOneWidget);
    expect(find.textContaining('华为'), findsNothing);
    expect(find.textContaining('荣耀'), findsNothing);
  });

  testWidgets('cancel keeps the current mode', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-standard')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rendering-mode-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('rendering-mode-cancel')));
    await tester.pumpAndSettle();

    expect(state.controller.mode, GameRenderingMode.compatibility);
    expect(state.port.modes, isEmpty);
  });

  testWidgets('confirm rebuilds using the selected mode', (tester) async {
    final state = await createController();
    addTearDown(state.controller.dispose);
    await tester.pumpWidget(app(state.controller));

    await tester.tap(find.byKey(const Key('rendering-mode-standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rendering-mode-confirm')));
    await tester.pumpAndSettle();

    expect(state.controller.mode, GameRenderingMode.standard);
    expect(state.port.modes, [GameRenderingMode.standard]);
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

    await tester.tap(find.byKey(const Key('rendering-mode-standard')));
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
