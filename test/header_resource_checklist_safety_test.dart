import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  for (final (checklist, close) in [
    ('header', 'done'),
    ('header', 'back'),
    ('header', 'lock'),
    ('collapsed', 'done'),
  ]) {
    testWidgets(
      '$checklist resource checklist closes on $close with a pointer held',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final settings = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(settings.dispose);
        final bar = GlobalKey<CompactResourceBarState>();
        const gamePoint = Offset(5, 200);
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
                      key: bar,
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
        final Finder dialog;
        if (checklist == 'collapsed') {
          unawaited(bar.currentState!.openCollapsedChecklist());
          dialog = find.byKey(const Key('panel-resource-collapsed-dialog'));
        } else {
          await tester.tap(find.byKey(const Key('header-resource-filter')));
          dialog = find.byKey(const Key('header-resource-filter-dialog'));
        }
        await tester.pumpAndSettle();
        expect(dialog, findsOneWidget);
        await tester.tapAt(gamePoint);
        await tester.pump();
        expect(dialog, findsOneWidget);
        expect(gameTouches, 0);
        final held = await tester.startGesture(tester.getCenter(dialog));
        try {
          if (close == 'done') {
            await tester.tap(
              find.byKey(const Key('header-resource-filter-done')),
            );
          } else if (close == 'lock') {
            await settings.setUiLocked(true);
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pump();
          expect(dialog, findsNothing);
          expect(
            find.byKey(const Key('game-safety-input-guard')),
            findsNothing,
          );
          expect(gameTouches, 0);
          await tester.tapAt(gamePoint);
          expect(gameTouches, 1);
        } finally {
          await held.up();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
