import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/background_game_retention_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_refresh_shortcut_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_runtime_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_awake_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TopNoticeHost(child: Scaffold(body: child)),
);

Future<LayoutSettingsController> _layout() async {
  final layout = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  addTearDown(layout.dispose);
  return layout;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'refresh confirmation switch inverts and persists skip preference',
    (tester) async {
      final layout = await _layout();
      final refresh = await GameFrameRefreshShortcutSettings.load();
      addTearDown(refresh.dispose);
      await tester.pumpWidget(
        _app(
          GameRuntimeSettingsPage(
            layoutSettingsController: layout,
            gameFrameRefreshShortcutSettings: refresh,
          ),
        ),
      );
      final toggle = find.byKey(
        const Key('settings-frame-refresh-confirmation'),
      );
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(refresh.skipHeaderConfirmation, isTrue);
      final reloaded = await GameFrameRefreshShortcutSettings.load();
      addTearDown(reloaded.dispose);
      expect(reloaded.skipHeaderConfirmation, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(refresh.skipHeaderConfirmation, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keep-running controls work without an audio controller', (
    tester,
  ) async {
    final layout = await _layout();
    final awake = await ScreenAwakeController.load(
      SharedPreferencesScreenAwakeStore(),
    );
    final retention = await BackgroundGameRetentionController.load(
      SharedPreferencesBackgroundGameRetentionStore(),
    );
    addTearDown(awake.dispose);
    addTearDown(retention.dispose);
    await tester.pumpWidget(
      _app(
        GameRuntimeSettingsPage(
          layoutSettingsController: layout,
          screenAwakeController: awake,
          backgroundGameRetentionController: retention,
        ),
      ),
    );
    final awakeToggle = find.byKey(const Key('settings-screen-awake'));
    final retentionLabel = find.byKey(
      const Key('settings-background-game-retention'),
    );
    expect(
      tester.getTopLeft(awakeToggle).dy,
      lessThan(tester.getTopLeft(retentionLabel).dy),
    );
    await tester.tap(awakeToggle);
    await tester.pumpAndSettle();
    expect(awake.enabled, isTrue);
    final retentionRow = find
        .ancestor(of: retentionLabel, matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: retentionRow, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
    expect(retention.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'information reading reuses and persists the capture mode selector',
    (tester) async {
      final layout = await _layout();
      final capture = await CaptureModeController.load(
        SharedPreferencesCaptureModeStore(),
      );
      addTearDown(capture.dispose);
      await tester.pumpWidget(
        _app(
          GameRuntimeSettingsPage(
            layoutSettingsController: layout,
            captureModeController: capture,
          ),
        ),
      );
      expect(find.byKey(const Key('capture-mode-selector')), findsOneWidget);
      await tester.tap(find.text('纯浏览模式'));
      await tester.pumpAndSettle();
      expect(capture.mode, CaptureMode.browserOnly);
      final reloaded = await CaptureModeController.load(
        SharedPreferencesCaptureModeStore(),
      );
      addTearDown(reloaded.dispose);
      expect(reloaded.mode, CaptureMode.browserOnly);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'module editors persist normal and HD summary choices independently',
    (tester) async {
      final layout = await _layout();
      await layout.setHdEnabled(true);
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      addTearDown(display.dispose);
      final expectedNormal = {...layout.fleetDisplayFields};
      final expectedHd = {...layout.hdFleetDisplayFields};
      expect(expectedNormal, contains('speed'));
      expect(expectedHd, contains('firepower'));
      var twoColumnEditor = false;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              key: const Key('open-module-fleet-display'),
              onPressed: () => showFleetDisplaySettings(
                context,
                layout,
                twoColumns: twoColumnEditor,
              ),
              child: const Text('Open module display editor'),
            ),
          ),
        ),
      );
      final fleet = find.byKey(const Key('open-module-fleet-display'));
      // Non-summary fields are shared by the existing editors. Editing HD
      // summary choices first also saves its independent summary preference.
      for (final twoColumns in [true, false]) {
        twoColumnEditor = twoColumns;
        await tester.ensureVisible(fleet);
        await tester.tap(fleet);
        await tester.pumpAndSettle();
        final field = twoColumns ? 'firepower' : 'speed';
        final choice = find.byKey(Key('fleet-display-$field'));
        expect(tester.widget<FilterChip>(choice).selected, isTrue);
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        (twoColumns ? expectedHd : expectedNormal).remove(field);
        expect(layout.fleetDisplayFields, expectedNormal);
        expect(layout.hdFleetDisplayFields, expectedHd);
        await tester.tap(find.byKey(const Key('fleet-display-close')));
        await tester.pumpAndSettle();
      }
      final reloaded = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(reloaded.dispose);
      expect(reloaded.fleetDisplayFields, expectedNormal);
      expect(reloaded.hdFleetDisplayFields, expectedHd);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('appearance content omits redundant editor shortcuts', (
    tester,
  ) async {
    final layout = await _layout();
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    addTearDown(display.dispose);
    var headerOpened = 0;
    var dashboardOpened = 0;
    var hdOpened = 0;
    await tester.pumpWidget(
      _app(
        ScreenSettingsPage(
          layoutSettingsController: layout,
          displayModeController: display,
          onEditHeaderResources: () => headerOpened++,
          onEditDashboardLayout: () => dashboardOpened++,
          onEditHdLayout: () => hdOpened++,
        ),
      ),
    );
    for (final locked in [false, true]) {
      await layout.setUiLocked(locked);
      await tester.pumpAndSettle();
      for (final key in [
        'header-resources',
        'fleet-display',
        'module-display',
        'dashboard-layout',
        'hd-layout',
      ]) {
        expect(find.byKey(Key('settings-edit-$key')), findsNothing);
      }
      expect(
        find.byKey(const Key('settings-briefing-display-dropdown')),
        findsOneWidget,
      );
    }
    expect([headerOpened, dashboardOpened, hdOpened], [0, 0, 0]);
    expect(tester.takeException(), isNull);
  });
}
