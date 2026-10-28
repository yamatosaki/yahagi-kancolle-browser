import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/dashboard_display_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';

const _preferenceKey = 'layout_dashboard_display_mode';
const _dropdownKey = Key('settings-briefing-display-dropdown');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'legacy stores retain accordion and support in-memory changes',
    () async {
      final controller = await LayoutSettingsController.load(_LegacyStore());
      addTearDown(controller.dispose);
      expect(controller.dashboardDisplayMode, DashboardDisplayMode.accordion);
      await controller.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      expect(controller.dashboardDisplayMode, DashboardDisplayMode.tabs);
    },
  );

  test('missing and malformed preferences default to accordion', () async {
    for (final saved in <Object?>[null, '', 'unknown', 42, true]) {
      SharedPreferences.setMockInitialValues({_preferenceKey: ?saved});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.dashboardDisplayMode, DashboardDisplayMode.accordion);
      controller.dispose();
    }
  });

  test('mode survives reload without changing card preferences', () async {
    final order = LayoutSettingsStore.defaultDashboardCardOrder.reversed
        .toList();
    const hidden = ['construction', 'repair'];
    const collapsed = ['fleet', 'land_base'];
    SharedPreferences.setMockInitialValues({
      'layout_dashboard_card_order': order,
      'layout_dashboard_card_hidden': hidden,
      'layout_dashboard_card_collapsed': collapsed,
    });
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    for (final mode in [
      DashboardDisplayMode.tabs,
      DashboardDisplayMode.accordion,
    ]) {
      final saved = controller.setDashboardDisplayMode(mode);
      expect(controller.dashboardDisplayMode, mode);
      await saved;
      final restored = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(restored.dashboardDisplayMode, mode);
      expect(restored.dashboardCardOrder, order);
      expect(restored.dashboardCardHidden, hidden);
      expect(restored.dashboardCardCollapsed, collapsed);
      restored.dispose();
    }
    expect(notifications, 2);
    await controller.setDashboardDisplayMode(DashboardDisplayMode.accordion);
    expect(notifications, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_preferenceKey), 'accordion');
    expect(prefs.getStringList('layout_dashboard_card_order'), order);
    expect(prefs.getStringList('layout_dashboard_card_hidden'), hidden);
    expect(prefs.getStringList('layout_dashboard_card_collapsed'), collapsed);
  });

  test(
    'rapid changes save in order and failures retain the confirmed mode',
    () async {
      final store = _ControlledStore();
      final controller = await LayoutSettingsController.load(store);
      addTearDown(controller.dispose);
      final first = controller.setDashboardDisplayMode(
        DashboardDisplayMode.tabs,
      );
      final second = controller.setDashboardDisplayMode(
        DashboardDisplayMode.accordion,
      );
      await Future.wait([first, second]);
      expect(store.saved, DashboardDisplayMode.accordion);
      expect(store.maximumConcurrentWrites, 1);
      store.fail = true;
      await controller.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      expect(controller.dashboardDisplayMode, DashboardDisplayMode.accordion);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'briefing selection fits a narrow screen and persists through HD in $locale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 780);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        final display = await DisplayModeController.load(
          MemoryDisplayModeStore(),
        );
        addTearDown(controller.dispose);
        addTearDown(display.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: ScreenSettingsPage(
                layoutSettingsController: controller,
                displayModeController: display,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(locale);
        final dropdown = find.byKey(_dropdownKey);
        expect(find.text(l10n.briefingDisplayTitle), findsOneWidget);
        expect(find.text(l10n.briefingDisplayDescription), findsOneWidget);
        expect(l10n.briefingDisplayDescription, contains('HD'));
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DropdownButton<DashboardDisplayMode>>(dropdown)
              .isExpanded,
          isTrue,
        );
        expect(
          tester.widget<DropdownButton<DashboardDisplayMode>>(dropdown).value,
          DashboardDisplayMode.accordion,
        );
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        expect(find.text(l10n.briefingDisplayAccordion).last, findsOneWidget);
        await tester.tap(find.text(l10n.briefingDisplayTabs).last);
        await tester.pumpAndSettle();
        expect(controller.dashboardDisplayMode, DashboardDisplayMode.tabs);
        expect(
          tester.widget<DropdownButton<DashboardDisplayMode>>(dropdown).value,
          DashboardDisplayMode.tabs,
        );
        expect(
          (await SharedPreferences.getInstance()).getString(_preferenceKey),
          'tabs',
        );
        final hdSwitch = find.byKey(const Key('settings-hd-mode'));
        await tester.ensureVisible(hdSwitch);
        await tester.pumpAndSettle();
        await tester.tap(hdSwitch);
        await tester.pumpAndSettle();
        expect(controller.hdSettings.enabled, isTrue);
        expect(controller.dashboardDisplayMode, DashboardDisplayMode.tabs);
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        expect(
          tester.widget<DropdownButton<DashboardDisplayMode>>(dropdown).value,
          DashboardDisplayMode.tabs,
        );
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(restored.dispose);
        expect(restored.hdSettings.enabled, isTrue);
        expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ControlledStore extends SharedPreferencesLayoutSettingsStore {
  DashboardDisplayMode saved = DashboardDisplayMode.accordion;
  int activeWrites = 0;
  int maximumConcurrentWrites = 0;
  bool fail = false;

  @override
  Future<DashboardDisplayMode> loadDashboardDisplayMode() async => saved;

  @override
  Future<void> saveDashboardDisplayMode(DashboardDisplayMode mode) async {
    activeWrites++;
    if (activeWrites > maximumConcurrentWrites) {
      maximumConcurrentWrites = activeWrites;
    }
    await Future<void>.delayed(
      Duration(milliseconds: mode == DashboardDisplayMode.tabs ? 20 : 1),
    );
    activeWrites--;
    if (fail) throw StateError('disk unavailable');
    saved = mode;
  }
}

class _LegacyStore implements LayoutSettingsStore {
  @override
  Future<double> loadGameAreaRatio() async => .7;
  @override
  Future<double> loadInformationPanelWidth() async => 300;
  @override
  Future<bool> loadAutoZoom() async => true;
  @override
  Future<bool> loadEnhancedDamagePulse() async => false;
  @override
  Future<bool> loadWorkspaceMenuOnRight() async => false;
  @override
  Future<List<String>> loadDashboardCardOrder() async =>
      LayoutSettingsStore.defaultDashboardCardOrder;
  @override
  Future<List<String>> loadDashboardCardCollapsed() async => [];
  @override
  Future<List<String>> loadDashboardCardHidden() async => [];
  @override
  Future<String?> loadFontFamily() async => null;
  @override
  Future<String?> loadLocaleCode() async => null;
  @override
  Future<void> saveFontFamily(String? fontFamily) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
