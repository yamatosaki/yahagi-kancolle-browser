import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/development/development_dataset.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/localization/ui_locale.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
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

void main() {
  test('Korean is a supported UI locale', () {
    expect(AppLocalizations.delegate.isSupported(const Locale('ko')), isTrue);
    expect(AppLocalizations.supportedLocales, contains(const Locale('ko')));
  });

  testWidgets('regional Chinese and unsupported locales resolve consistently', (
    tester,
  ) async {
    for (final (requested, expected) in [
      (const Locale('zh', 'TW'), 'zh-Hant'),
      (const Locale('zh', 'HK'), 'zh-Hant'),
      (const Locale('zh', 'MO'), 'zh-Hant'),
      (const Locale('zh', 'CN'), 'zh'),
      (const Locale('ko', 'KR'), 'ko'),
      (const Locale('ja', 'JP'), 'ja'),
      (const Locale('en', 'US'), 'en'),
      (const Locale('fr', 'FR'), 'zh'),
    ]) {
      await tester.pumpWidget(
        _app(
          requested,
          Builder(
            builder: (context) =>
                Text(Localizations.localeOf(context).toLanguageTag()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget, reason: '$requested');
    }
  });

  testWidgets(
    'top notices follow the system Korean locale before choosing a language',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      SharedPreferences.setMockInitialValues({});
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
        systemLocaleCode: 'ko',
      );
      final notices = TopNoticeController();
      addTearDown(layout.dispose);
      addTearDown(notices.dispose);
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
          captureDocumentId: 'korean-ui',
          captureDocumentStartedAtEpochMs: 1000,
        ),
      );
      await controller.idle;
      expect(notices.current!.message, contains('개발'));
      expect(notices.current!.message, isNot(contains('开发')));
      notices.hide();
    },
  );

  testWidgets('language selector reflects Korean selected by the system', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
      systemLocaleCode: 'ko',
    );
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    addTearDown(layout.dispose);
    addTearDown(display.dispose);
    await tester.pumpWidget(
      _app(
        const Locale('ko'),
        ScreenSettingsPage(
          layoutSettingsController: layout,
          displayModeController: display,
        ),
      ),
    );
    final menu = tester.widget<DropdownButton<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton<String> &&
            widget.items!.any((item) => item.value == 'zh_Hant'),
      ),
    );
    expect(menu.value, 'ko');
    expect(layout.fontFamilyFallback, contains('sans-serif'));
  });

  testWidgets('Korean can be selected and survives reloading settings', (
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
    final languageMenu = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButton<String> &&
          widget.items!.any((item) => item.value == 'zh_Hant'),
    );
    await tester.tap(languageMenu);
    await tester.pumpAndSettle();
    expect(find.text('한국어'), findsOneWidget);
    await tester.tap(find.text('한국어'));
    await tester.pumpAndSettle();
    final restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(restored.dispose);
    expect(restored.localeCode, 'ko');
    expect(restored.fontFamilyFallback, contains('sans-serif'));
  });

  testWidgets('Korean settings navigation renders without fallback Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Locale('ko'),
        SettingsSegmented(selectedIndex: 0, onChanged: (_) {}),
      ),
    );
    expect(find.text('외관 및 배치'), findsOneWidget);
    expect(find.text('출격 및 전투'), findsOneWidget);
    expect(find.text('네트워크 및 연결'), findsOneWidget);
    expect(find.text('데이터 관리'), findsOneWidget);
    expect(find.text('정보 및 지원'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'data metadata follows all four UI languages and preserves version',
    (tester) async {
      for (final (locale, version, unchecked) in [
        (const Locale('zh'), '数据版本', '尚未检查'),
        (
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          '資料版本',
          '尚未檢查',
        ),
        (const Locale('ja'), 'データバージョン', '未確認'),
        (const Locale('ko'), '데이터 버전', '확인한 적 없음'),
      ]) {
        await tester.pumpWidget(
          _app(
            locale,
            const DataUpdateMetadata(
              version: '2026/10/18/01',
              lastCheckedAt: null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(version), findsOneWidget);
        expect(find.textContaining(unchecked), findsOneWidget);
        expect(find.textContaining('2026-10-18'), findsOneWidget);
      }
    },
  );

  test('Korean preserves original equipment, quest and map names', () {
    final data = DevelopmentDataset.fromJsonString(
      File(
        'assets/data/development/development_snapshot.json',
      ).readAsStringSync(),
    );
    for (final equipment in data.equipment.values) {
      expect(
        equipment.label(const Locale('ko')),
        equipment.names?['ja'] ?? equipment.name,
      );
    }
    for (final item in [...senkaEoCatalog, ...senkaQuestCatalog]) {
      expect(
        senkaCatalogLabel(item, const Locale('ko')),
        senkaCatalogLabel(item, const Locale('ja')),
      );
      expect(
        senkaCatalogMatrixLabel(item, const Locale('ko')),
        senkaCatalogMatrixLabel(item, const Locale('ja')),
      );
    }
  });
}
