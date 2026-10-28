import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/localization/ui_locale.dart';
import 'package:yahagi_kancolle_browser/src/notice/game_info_notice_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_catalog.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_catalog_localization.dart';
import 'package:yahagi_kancolle_browser/src/settings/data_update_metadata.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeResolutionCallback: resolveUiLocale,
  home: Scaffold(body: child),
);

Finder _languageMenu() => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButton<String> &&
      widget.items!.any((item) => item.value == 'zh_Hant'),
);

void main() {
  test(
    'English is supported and regional variants use the same UI language',
    () {
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      for (final country in ['US', 'GB', 'AU']) {
        final locale = Locale('en', country);
        expect(uiLocaleStorageCode(locale), 'en');
        expect(
          resolveUiLocale(locale, AppLocalizations.supportedLocales),
          const Locale('en'),
        );
      }
      expect(
        resolveUiLocale(const Locale('fr'), AppLocalizations.supportedLocales),
        const Locale('zh'),
      );
      const explicitSimplified = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'TW',
      );
      expect(uiLocaleStorageCode(explicitSimplified), 'zh');
      expect(
        resolveUiLocale(explicitSimplified, AppLocalizations.supportedLocales),
        const Locale('zh'),
      );
    },
  );

  testWidgets('English selection persists and uses the common font', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    addTearDown(layout.dispose);
    addTearDown(display.dispose);
    await tester.pumpWidget(
      _app(
        const Locale('zh'),
        ScreenSettingsPage(
          layoutSettingsController: layout,
          displayModeController: display,
        ),
      ),
    );
    await tester.tap(_languageMenu());
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    final restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(restored.dispose);
    expect(restored.localeCode, 'en');
    expect(restored.effectiveLocaleCode, 'en');
    expect(restored.fontFamily, 'HarmonyOS_Sans');
    expect(restored.fontFamilyFallback, contains('HarmonyOS_Sans_SC'));
  });

  testWidgets('system English keeps selector and top notices consistent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
      systemLocaleCode: 'en',
    );
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    final notices = TopNoticeController();
    addTearDown(layout.dispose);
    addTearDown(display.dispose);
    addTearDown(notices.dispose);
    await tester.pumpWidget(
      _app(
        const Locale('en', 'GB'),
        ScreenSettingsPage(
          layoutSettingsController: layout,
          displayModeController: display,
        ),
      ),
    );
    expect(tester.widget<DropdownButton<String>>(_languageMenu()).value, 'en');
    final controller = GameInfoNoticeController(
      stateProvider: () => GameState.empty,
      layoutSettingsController: layout,
      topNoticeController: notices,
    );
    addTearDown(controller.dispose);
    controller.accept(
      CapturedApiEvent(
        path: '/kcsapi/api_req_kousyou/createitem',
        responseBody:
            'svdata={"api_result":1,"api_data":{"api_create_flag":0}}',
        capturedAt: DateTime.utc(2026, 10, 18),
        statusCode: 200,
        source: CaptureSource.xhr,
        sourceOrigin: 'http://example.com',
        captureDocumentId: 'english-ui',
        captureDocumentStartedAtEpochMs: 1000,
      ),
    );
    await controller.idle;
    expect(notices.current!.message.toLowerCase(), contains('failed'));
    expect(notices.current!.message, isNot(contains('开发')));
    notices.hide();
  });

  testWidgets('English settings tabs and data metadata fit a narrow viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _app(
        const Locale('en'),
        Column(
          children: [
            SettingsSegmented(selectedIndex: 0, onChanged: (_) {}),
            const DataUpdateMetadata(
              version: '2026/10/18/01',
              lastCheckedAt: null,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sortie & battle'), findsOneWidget);
    expect(find.text('Network & connection'), findsOneWidget);
    expect(find.text('Data management'), findsOneWidget);
    expect(find.textContaining('2026-10-18'), findsOneWidget);
    expect(find.textContaining('数据'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('English UI preserves original equipment, quest and sea-area names', () {
    final data = DevelopmentDataset.fromJsonString(
      File(
        'assets/data/development/development_snapshot.json',
      ).readAsStringSync(),
    );
    for (final equipment in data.equipment.values) {
      expect(
        equipment.label(const Locale('en')),
        equipment.names?['ja'] ?? equipment.name,
      );
    }
    for (final item in [...senkaEoCatalog, ...senkaQuestCatalog]) {
      expect(
        senkaCatalogLabel(item, const Locale('en')),
        senkaCatalogLabel(item, const Locale('ja')),
      );
      expect(
        senkaCatalogMatrixLabel(item, const Locale('en')),
        senkaCatalogMatrixLabel(item, const Locale('ja')),
      );
    }
  });
}
