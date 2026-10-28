import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_runtime_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/subtitles/ship_subtitle_catalog.dart';
import 'package:yahagi_kancolle_browser/src/subtitles/ship_subtitle_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/subtitles/ship_subtitle_port.dart';
import 'package:yahagi_kancolle_browser/src/subtitles/ship_subtitle_runtime_controller.dart';
import 'package:yahagi_kancolle_browser/src/subtitles/ship_subtitle_settings.dart';
import 'package:yahagi_kancolle_browser/src/subtitles/ship_subtitle_language.dart';
import 'package:yahagi_kancolle_browser/src/subtitles/ship_subtitle_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'runtime settings show runtime failure and retry without restart',
    (tester) async {
      GameStateController.disableTimerForTest = true;
      addTearDown(() => GameStateController.disableTimerForTest = false);
      var supported = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shipSubtitleChannel,
        (call) async => call.method == 'isSupported' ? supported : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          shipSubtitleChannel,
          null,
        ),
      );
      final settings = await ShipSubtitleSettingsController.load();
      await settings.setEnabled(true);
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final catalog = ShipSubtitleCatalogController(
        data: ShipSubtitleCatalog(
          version: '2026101805',
          quotes: {
            '1': {'1': '台词'},
          },
        ),
        updater: _OfflineUpdater(),
      );
      final game = GameStateController(initialState: const GameState());
      final runtime = ShipSubtitleRuntimeController(
        settings: settings,
        catalog: catalog,
        layout: layout,
        gameState: game,
      );
      addTearDown(runtime.dispose);
      addTearDown(settings.dispose);
      addTearDown(layout.dispose);
      addTearDown(catalog.dispose);
      addTearDown(game.dispose);
      await runtime.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GameRuntimeSettingsPage(
              layoutSettingsController: layout,
              shipSubtitleSettingsController: settings,
              shipSubtitleRuntimeController: runtime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('当前 WebView 不支持字幕，请更新系统 WebView 后重新检测。'),
        findsOneWidget,
      );
      final retry = find.byKey(const Key('settings-ship-subtitle-retry'));
      await tester.ensureVisible(retry);
      supported = true;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('尚未取得舰娘语音资料，请在游戏模式重新载入游戏。'), findsOneWidget);
      expect(settings.enabled, isTrue);
      expect(tester.takeException(), isNull);
      runtime.dispose();
    },
  );

  testWidgets(
    'actual runtime settings expose opt-in and conditional subtitle choices',
    (tester) async {
      final settings = await ShipSubtitleSettingsController.load();
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(settings.dispose);
      addTearDown(layout.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GameRuntimeSettingsPage(
              layoutSettingsController: layout,
              shipSubtitleSettingsController: settings,
            ),
          ),
        ),
      );
      final toggle = find.byKey(const Key('settings-ship-subtitles'));
      await tester.ensureVisible(toggle);
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(
        find.byKey(const Key('settings-ship-subtitle-font-size')),
        findsNothing,
      );
      final language = find.byKey(const Key('settings-ship-subtitle-language'));
      expect(language, findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-ship-subtitle-font-size')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(language).dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const Key('settings-ship-subtitle-font-size')),
              )
              .dy,
        ),
      );
      await tester.ensureVisible(language);
      await tester.tap(language);
      await tester.pumpAndSettle();
      await tester.tap(find.text('日本語').hitTestable());
      await tester.pumpAndSettle();
      expect(settings.language, ShipSubtitleLanguage.japanese);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _OfflineUpdater implements ShipSubtitleUpdateClient {
  @override
  Future<ShipSubtitleUpdateResult> checkAndUpdate({
    required ShipSubtitleCatalog current,
  }) async => ShipSubtitleUpToDate(current, sourceHost: '');
}
