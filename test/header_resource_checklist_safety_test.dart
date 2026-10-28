import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  for (final close in ['done', 'outside', 'back', 'held-back', 'held-cancel']) {
    testWidgets(
      '$close protects the game after closing the resource checklist',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(settings.dispose);
        var gameTouches = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => gameTouches++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: CompactResourceBar(
                      state: const GameState(),
                      settingsController: settings,
                      initiallyEditing: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('header-resource-filter')));
        await tester.pumpAndSettle();
        final held = close.startsWith('held-')
            ? await tester.startGesture(
                tester.getCenter(
                  find.text(
                    lookupAppLocalizations(
                      const Locale('zh'),
                    ).selectHeaderVisibleItems,
                  ),
                ),
                pointer: 91,
              )
            : null;
        if (close == 'done') {
          await tester.tap(
            find.byKey(const Key('header-resource-filter-done')),
          );
        } else if (close == 'outside') {
          await tester.tapAt(const Offset(5, 200));
        } else if (close == 'held-cancel') {
          await settings.setUiLocked(true);
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pump();
        expect(
          find.byKey(const Key('game-safety-input-guard')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(5, 200));
        expect(gameTouches, 0);
        if (held != null) {
          await tester.pump(const Duration(seconds: 2));
          expect(
            find.byKey(const Key('game-safety-input-guard')),
            findsOneWidget,
          );
          expect(gameTouches, 0);
          await held.up();
          await tester.pump(const Duration(milliseconds: 599));
          expect(
            find.byKey(const Key('game-safety-input-guard')),
            findsOneWidget,
          );
        }
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(5, 200));
        expect(gameTouches, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
