import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

Future<LayoutSettingsController> _settings() async {
  SharedPreferences.setMockInitialValues({});
  final settings = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  addTearDown(settings.dispose);
  return settings;
}

Widget _app(Widget child, {Locale locale = const Locale('zh')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

void main() {
  testWidgets('player can enable game refresh through the header checklist', (
    tester,
  ) async {
    final settings = await _settings();
    await settings.setHeaderResourceOrder([
      headerGameRefreshId,
      ...settings.headerResourceOrder.where((id) => id != headerGameRefreshId),
    ]);
    var gameRefreshes = 0;
    var frameRefreshes = 0;
    await tester.pumpWidget(
      _app(
        CompactResourceBar(
          state: const GameState(),
          settingsController: settings,
          onGameRefreshTap: () => gameRefreshes++,
          onFrameRefreshTap: () => frameRefreshes++,
        ),
      ),
    );
    final refresh = find.byKey(const Key('header-resource-game-refresh'));
    expect(refresh, findsNothing);
    await tester.longPress(find.byKey(const Key('header-resource-senka')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('header-resource-edit-game-refresh')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('header-resource-filter')));
    await tester.pumpAndSettle();
    final checkbox = find.byKey(
      const Key('header-resource-visible-game-refresh'),
    );
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    await tester.tap(find.byKey(const Key('header-resource-filter-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-resource-edit-done')));
    await tester.pumpAndSettle();
    expect(refresh, findsOneWidget);
    expect(gameRefreshes, 0);
    await tester.tap(refresh);
    expect((gameRefreshes, frameRefreshes), (1, 0));
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('refresh buttons fit narrow layouts in $locale', (
      tester,
    ) async {
      final settings = await _settings();
      await settings.setHeaderResourceOrder([
        headerFrameRefreshId,
        headerGameRefreshId,
      ]);
      for (final id in allHeaderResourceIds) {
        final selected =
            id == headerFrameRefreshId || id == headerGameRefreshId;
        if (settings.visibleHeaderResourceIds.contains(id) != selected) {
          await settings.toggleHeaderResourceVisible(id);
        }
      }
      var gameRefreshes = 0;
      var frameRefreshes = 0;
      for (final layout in ResourceBarLayout.values) {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 190,
              child: CompactResourceBar(
                state: const GameState(),
                settingsController: settings,
                layout: layout,
                flatStyle: true,
                onGameRefreshTap: () => gameRefreshes++,
                onFrameRefreshTap: () => frameRefreshes++,
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final refresh = find.byKey(const Key('header-resource-game-refresh'));
        if (layout == ResourceBarLayout.strip) {
          await tester.ensureVisible(refresh);
          await tester.pumpAndSettle();
        }
        final label = lookupAppLocalizations(locale).advanceWarningReloadGame;
        expect(
          find.descendant(of: refresh, matching: find.text(label)),
          findsOneWidget,
        );
        await tester.tap(refresh);
        await tester.pump();
        expect(frameRefreshes, 0);
        expect(tester.takeException(), isNull, reason: '$layout');
      }
      expect(gameRefreshes, ResourceBarLayout.values.length);
    });
  }
}
