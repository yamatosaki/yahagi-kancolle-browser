import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_mouse_wheel_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_refresh_shortcut_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_runtime_settings_page.dart';

void main() {
  testWidgets('appearance settings no longer contain runtime controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final wheel = await GameMouseWheelSettingsController.load();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    addTearDown(wheel.dispose);
    addTearDown(layout.dispose);
    addTearDown(display.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenSettingsPage(
          layoutSettingsController: layout,
          displayModeController: display,
          gameMouseWheelSettingsController: wheel,
        ),
      ),
    );
    expect(
      find.byKey(const Key('settings-mouse-wheel-compatibility')),
      findsNothing,
    );
    expect(find.byKey(const Key('settings-top-notice-enabled')), findsNothing);
  });

  for (final locale in [
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('ja'),
  ]) {
    testWidgets(
      'runtime settings can toggle and persist wheel compatibility: $locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final wheel = await GameMouseWheelSettingsController.load();
        final frameRefresh = await GameFrameRefreshShortcutSettings.load();
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(wheel.dispose);
        addTearDown(frameRefresh.dispose);
        addTearDown(layout.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GameRuntimeSettingsPage(
              layoutSettingsController: layout,
              gameMouseWheelSettingsController: wheel,
              gameFrameRefreshShortcutSettings: frameRefresh,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(
          const Key('settings-mouse-wheel-compatibility'),
        );
        await tester.ensureVisible(toggle);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(toggle).value, isTrue);
        expect(wheel.enabled, isTrue);
        final reloaded = await GameMouseWheelSettingsController.load();
        addTearDown(reloaded.dispose);
        expect(reloaded.enabled, isTrue);
        expect(
          find.byKey(const Key('settings-mouse-right-click-frame-refresh')),
          findsNothing,
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(wheel.enabled, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
