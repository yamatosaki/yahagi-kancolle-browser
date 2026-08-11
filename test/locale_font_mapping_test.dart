import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  test(
    'maps simplified, traditional, and Japanese locales to regional fonts',
    () async {
      final store = _MemoryLayoutStore();
      final controller = await LayoutSettingsController.load(store);

      await controller.setLocaleCode('zh');
      expect(controller.fontFamily, 'HarmonyOS_Sans_SC');
      expect(controller.fontFamilyFallback, contains('NotoSansJP'));

      await controller.setLocaleCode('zh_Hant');
      expect(controller.fontFamily, 'HarmonyOS_Sans_TC');

      await controller.setLocaleCode('ja');
      expect(controller.fontFamily, 'NotoSansJP');
      expect(controller.fontFamilyFallback.first, 'HarmonyOS_Sans_TC');
    },
  );

  test(
    'migrates a saved TC font when the selected locale is Japanese',
    () async {
      final store = _MemoryLayoutStore()
        ..localeCode = 'ja'
        ..fontFamily = 'HarmonyOS_Sans_TC';

      final controller = await LayoutSettingsController.load(store);

      expect(controller.fontFamily, 'NotoSansJP');
    },
  );
}

final class _MemoryLayoutStore implements LayoutSettingsStore {
  String? localeCode;
  String? fontFamily;

  @override
  Future<double> loadGameAreaRatio() async => 0.65;
  @override
  Future<void> saveGameAreaRatio(double ratio) async {}
  @override
  Future<double> loadInformationPanelWidth() async => 390;
  @override
  Future<void> saveInformationPanelWidth(double width) async {}
  @override
  Future<bool> loadAutoZoom() async => true;
  @override
  Future<void> saveAutoZoom(bool autoZoom) async {}
  @override
  Future<bool> loadEnhancedDamagePulse() async => true;
  @override
  Future<void> saveEnhancedDamagePulse(bool enabled) async {}
  @override
  Future<bool> loadWorkspaceMenuOnRight() async => false;
  @override
  Future<void> saveWorkspaceMenuOnRight(bool onRight) async {}
  @override
  Future<List<String>> loadDashboardCardOrder() async => <String>[];
  @override
  Future<void> saveDashboardCardOrder(List<String> order) async {}
  @override
  Future<List<String>> loadDashboardCardCollapsed() async => <String>[];
  @override
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds) async {}
  @override
  Future<List<String>> loadDashboardCardHidden() async => <String>[];
  @override
  Future<void> saveDashboardCardHidden(List<String> hiddenIds) async {}
  @override
  Future<String?> loadFontFamily() async => fontFamily;
  @override
  Future<void> saveFontFamily(String? value) async => fontFamily = value;
  @override
  Future<String?> loadLocaleCode() async => localeCode;
  @override
  Future<void> saveLocaleCode(String? value) async => localeCode = value;
}
