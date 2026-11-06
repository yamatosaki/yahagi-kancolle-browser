import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/hd_layout_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

const _experience = 'sortie_experience';
const _checks = 'pre_sortie';

void main() {
  test(
    'new and existing layouts place experience right after sortie checks',
    () async {
      const legacyOrder = <String>[
        'battle',
        _checks,
        'fleet',
        'land_base',
        'expedition',
        'repair',
        'construction',
        'quests',
      ];
      SharedPreferences.setMockInitialValues({
        'layout_dashboard_card_order': legacyOrder,
      });
      final normal = await SharedPreferencesLayoutSettingsStore()
          .loadDashboardCardOrder();
      final hd = HdLayoutSettings(
        sidebarOrder: legacyOrder,
        portraitModules: [for (final id in legacyOrder) HdBottomModule(id, 1)],
      );
      for (final order in [
        LayoutSettingsStore.defaultDashboardCardOrder,
        const HdLayoutSettings().orderedModules,
        const HdLayoutSettings().portrait.map((module) => module.id).toList(),
        normal,
        hd.orderedModules,
        hd.portrait.map((module) => module.id).toList(),
      ]) {
        expect(order.where((id) => id == _experience), hasLength(1));
        expect(order.indexOf(_experience), order.indexOf(_checks) + 1);
      }
      expect(normal.where((id) => id != _experience), legacyOrder);
      expect(hd.orderedModules.where((id) => id != _experience), legacyOrder);
    },
  );

  test('experience layout changes survive a settings reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesLayoutSettingsStore();
    final controller = await LayoutSettingsController.load(store);
    addTearDown(controller.dispose);
    await controller.setDashboardCardOrder([
      _experience,
      ...controller.dashboardCardOrder.where((id) => id != _experience),
    ]);
    await controller.toggleDashboardCardHidden(_experience);
    await controller.toggleDashboardCardCollapsed(_experience);
    await controller.setModuleShowLogo(_experience, false);
    await controller.setModuleShowName(_experience, false);
    await controller.moveHdModuleBefore(_experience, 'battle');
    await controller.toggleHdModuleHidden(_experience);
    await controller.moveHdPortraitModule(_experience, 'battle', false);
    await controller.setHdPortraitSize(_experience, 1, 2);
    await controller.toggleHdPortraitHidden(_experience);

    final restored = await LayoutSettingsController.load(store);
    addTearDown(restored.dispose);
    expect(restored.dashboardCardOrder.first, _experience);
    expect(restored.dashboardCardHidden, contains(_experience));
    expect(restored.dashboardCardCollapsed, contains(_experience));
    expect(restored.moduleShowLogo(_experience), isFalse);
    expect(restored.moduleShowName(_experience), isFalse);
    expect(restored.hdSettings.orderedModules.first, _experience);
    expect(restored.hdSettings.hidden, contains(_experience));
    expect(restored.hdSettings.portrait.first.id, _experience);
    expect(restored.hdSettings.portrait.first.span, 2);
    expect(restored.hdSettings.portraitHidden, contains(_experience));
  });
}
