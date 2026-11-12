import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_dialog.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';

const _native = MethodChannel('app.yahagi.kancollebrowser/native_warning');
const _guard = Key('game-safety-input-guard');

Widget _host({
  required Widget child,
  bool native = false,
  bool enabled = true,
}) => MaterialApp(
  home: GameDialogPresentationScope(
    nativeActivity: native,
    presentationEnabled: enabled,
    child: Scaffold(body: child),
  ),
);

void main() {
  for (final cancellation in ['back', 'outside']) {
    testWidgets('$cancellation cannot become a stale same-frame confirmation', (
      tester,
    ) async {
      late void Function(bool?) staleClose;
      final decisions = <bool?>[];
      await tester.pumpWidget(
        _host(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => decisions.add(
                await showGameSurfaceDialog<bool>(
                  context: context,
                  title: 'question',
                  builder: (_, close) {
                    staleClose = close;
                    return AlertDialog(
                      title: const Text('question'),
                      actions: [
                        TextButton(
                          onPressed: () => close(true),
                          child: const Text('confirm'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Preserve the old dialog as a held gesture's hit-test target while a
      // different input source cancels it. No frame has replaced its content.
      final held = await tester.startGesture(
        tester.getCenter(find.text('confirm')),
        pointer: 11,
      );
      if (cancellation == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tapAt(const Offset(8, 8));
        await tester.pump();
        expect(find.text('question'), findsOneWidget);
        expect(decisions, isEmpty);
        await tester.binding.handlePopRoute();
      }
      staleClose(true);
      await held.up();
      await tester.pumpAndSettle();
      expect(decisions, [null]);
    });
  }

  for (final protectInputOnDismiss in [false, true]) {
    final wait = protectInputOnDismiss ? 'waits for' : 'does not wait for';
    testWidgets('surface dismissal $wait a held touch', (tester) async {
      const gameButton = Key('game-button');
      const dialogTitle = Key('dialog-title');
      final decisions = <bool?>[];
      var gameTaps = 0;
      await tester.pumpWidget(
        _host(
          child: Stack(
            children: [
              Positioned(
                left: 8,
                top: 8,
                child: TextButton(
                  key: gameButton,
                  onPressed: () => gameTaps++,
                  child: const Text('game'),
                ),
              ),
              Center(
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async => decisions.add(
                      await showGameSurfaceDialog<bool>(
                        context: context,
                        title: 'question',
                        protectInputOnDismiss: protectInputOnDismiss,
                        builder: (_, close) => AlertDialog(
                          title: const Text('question', key: dialogTitle),
                          actions: [
                            TextButton(
                              onPressed: () => close(true),
                              child: const Text('done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final gamePoint = tester.getCenter(find.byKey(gameButton));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(gamePoint);
      expect(gameTaps, 0);
      expect(find.byKey(dialogTitle), findsOneWidget);

      final held = await tester.startGesture(
        tester.getCenter(find.byKey(dialogTitle)),
      );
      try {
        await tester.tap(find.text('done'));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(dialogTitle), findsNothing);
        await tester.tapAt(gamePoint);
        if (protectInputOnDismiss) {
          expect(find.byKey(_guard), findsOneWidget);
          expect(decisions, isEmpty);
          expect(gameTaps, 0);
        } else {
          expect(find.byKey(_guard), findsNothing);
          expect(decisions, [true]);
          expect(gameTaps, 1);
        }
      } finally {
        await held.up();
      }
      await tester.pumpAndSettle();
      expect(decisions, [true]);
    });
  }

  for (final mode in GameRenderingMode.values) {
    testWidgets('${mode.name} settles only the selected result', (
      tester,
    ) async {
      final pending = Completer<Object?>();
      final requests = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_native, (call) async {
            if (call.method == 'show') {
              requests.add(Map<Object?, Object?>.from(call.arguments as Map));
              return pending.future;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_native, null);
      });
      final decisions = <int?>[];
      await tester.pumpWidget(
        _host(
          native: mode.usesActivityWebView,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async => decisions.add(
                await showGameSurfaceDialog<int>(
                  context: context,
                  title: 'choose',
                  actions: const [
                    GameSurfaceDialogAction(
                      id: 'selected',
                      label: 'yes',
                      value: 7,
                    ),
                  ],
                  builder: (_, close) => AlertDialog(
                    title: const Text('choose'),
                    actions: [
                      TextButton(
                        onPressed: () => close(7),
                        child: const Text('yes'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(decisions, isEmpty);
      if (mode.usesActivityWebView) {
        expect(find.byType(AlertDialog), findsNothing);
        expect(requests.single['kind'], 'surfaceDialog');
        expect(requests.single['dismissible'], isFalse);
        expect(requests.single['protectInputOnDismiss'], isNot(false));
        pending.complete({'action': 'selected', 'checked': false});
      } else {
        expect(requests, isEmpty);
        await tester.tap(find.text('yes'));
        expect(decisions, isEmpty);
      }
      await tester.pumpAndSettle();
      expect(decisions, [7]);
    });
  }
}
