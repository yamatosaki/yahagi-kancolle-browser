import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_refresh_shortcut_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_refresh_shortcut_settings.dart';

const _guard = Key('game-safety-input-guard');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final close in ['confirm']) {
    testWidgets('frame $close cannot keep the UI locked by repeated taps', (
      tester,
    ) async {
      final fixture = await _Fixture.mount(tester);
      await fixture.close(tester, close);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tapAt(const Offset(20, 200));
        expect(fixture.gameTouches, 0);
      }
      await tester.pump(const Duration(milliseconds: 251));
      await tester.pump();
      expect(find.byKey(_guard), findsNothing);
      expect(fixture.decisions, [close == 'confirm']);
      await tester.tapAt(const Offset(20, 200));
      expect(fixture.gameTouches, 1);
    });
  }

  for (final close in ['cancel', 'back']) {
    testWidgets('a single frame $close restores input without a quiet delay', (
      tester,
    ) async {
      final fixture = await _Fixture.mount(tester);
      await fixture.close(tester, close);
      expect(find.byKey(_guard), findsNothing);
      expect(fixture.decisions, [false]);
      expect(fixture.gameTouches, 0);
      await tester.tapAt(const Offset(20, 200));
      expect(fixture.gameTouches, 1);
    });

    testWidgets('frame $close waits for held fingers then restores input', (
      tester,
    ) async {
      final fixture = await _Fixture.mount(tester);
      final control = find.byKey(const Key('frame-refresh-skip-confirmation'));
      final point = tester.getCenter(control);
      final route =
          ModalRoute.of(tester.element(control))! as GameSafetyDialogRoute;
      final first = await tester.startGesture(point, pointer: 81);
      final second = await tester.startGesture(
        point + const Offset(10, 0),
        pointer: 82,
      );
      expect(route.activePointers, containsAll([81, 82]));
      await fixture.close(tester, close);
      await tester.pump(const Duration(seconds: 3));
      expect(fixture.decisions, isEmpty);
      expect(find.byKey(_guard), findsOneWidget);
      await first.up();
      await tester.pump();
      expect(fixture.decisions, isEmpty);
      await second.cancel();
      await tester.pump();
      await tester.pump();
      // Allow the covered handoff frame, without advancing a 600 ms timer.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(find.byKey(_guard), findsNothing);
      expect(fixture.decisions, [false]);
      expect(fixture.gameTouches, 0);
      await tester.tapAt(const Offset(20, 200));
      expect(fixture.gameTouches, 1);
    });
  }

  for (final action in ['cancel', 'confirm']) {
    testWidgets('outside taps keep frame confirmation usable before $action', (
      tester,
    ) async {
      final fixture = await _Fixture.mount(tester);
      for (var i = 0; i < 4; i++) {
        await fixture.close(tester, 'outside');
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          find.byKey(const Key('frame-refresh-confirm-dialog')),
          findsOneWidget,
        );
        expect(find.byKey(_guard), findsNothing);
        expect(fixture.decisions, isEmpty);
        expect(fixture.gameTouches, 0);
      }
      final held = await tester.startGesture(const Offset(5, 5), pointer: 91);
      await tester.pump(const Duration(seconds: 3));
      await held.up();
      await fixture.close(tester, action);
      await tester.pumpAndSettle();
      expect(fixture.decisions, [action == 'confirm']);
      expect(fixture.gameTouches, 0);
      await tester.tapAt(const Offset(20, 200));
      expect(fixture.gameTouches, 1);
    });
  }

  testWidgets('the limit still swallows all held fingers until their release', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester);
    await fixture.close(tester, 'confirm');
    final first = await tester.startGesture(const Offset(20, 200), pointer: 71);
    final second = await tester.startGesture(
      const Offset(40, 200),
      pointer: 72,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(_guard), findsOneWidget);
    expect(fixture.decisions, isEmpty);
    await first.up();
    await tester.pump();
    expect(find.byKey(_guard), findsOneWidget);
    await second.cancel();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_guard), findsNothing);
    expect(fixture.decisions, [true]);
    expect(fixture.gameTouches, 0);
    await tester.tapAt(const Offset(20, 200));
    expect(fixture.gameTouches, 1);
  });
}

class _Fixture {
  final decisions = <bool>[];
  var gameTouches = 0;

  static Future<_Fixture> mount(WidgetTester tester) async {
    final fixture = _Fixture();
    final settings = await GameFrameRefreshShortcutSettings.load();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => fixture.gameTouches++,
              child: SizedBox.expand(
                child: Center(
                  child: TextButton(
                    onPressed: () async => fixture.decisions.add(
                      await confirmGameFrameRefreshShortcut(
                        context: context,
                        settings: settings,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<void> close(WidgetTester tester, String action) async {
    switch (action) {
      case 'confirm':
        await tester.tap(find.byKey(const Key('frame-refresh-confirm')));
      case 'cancel':
        await tester.tap(find.byKey(const Key('frame-refresh-cancel')));
      case 'outside':
        await tester.tapAt(const Offset(5, 5));
      case 'back':
        await tester.binding.handlePopRoute();
    }
    await tester.pump();
    await tester.pump();
    if (action != 'confirm') {
      // One rendered handoff frame is allowed; no quiet interval is required.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
    }
  }
}
