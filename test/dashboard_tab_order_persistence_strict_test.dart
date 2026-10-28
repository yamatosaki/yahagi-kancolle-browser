import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/dashboard_display_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'repeated tab reordering survives reload without changing customization or HD layout',
    () async {
      final controller = await _load();
      await controller.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      await controller.toggleDashboardCardHidden('repair');
      await controller.toggleDashboardCardCollapsed('fleet');
      await controller.setModuleShowLogo('quests', false);
      await controller.setModuleShowName('battle', false);
      await controller.moveHdModuleToSidebar('construction', target: 'battle');
      await controller.toggleHdModuleHidden('quests');
      final hdLayout = controller.hdSettings.encode();

      const orders = [
        [
          'construction',
          'battle',
          'fleet',
          'land_base',
          'expedition',
          'repair',
          'quests',
          'pre_sortie',
        ],
        [
          'pre_sortie',
          'construction',
          'battle',
          'fleet',
          'land_base',
          'expedition',
          'repair',
          'quests',
        ],
        [
          'pre_sortie',
          'construction',
          'battle',
          'land_base',
          'expedition',
          'repair',
          'quests',
          'fleet',
        ],
      ];
      for (final order in orders) {
        await controller.setDashboardCardOrder(order);
        await controller.setHdEnabled(true);
        final inHd = await _load();
        expect(inHd.hdSettings.enabled, isTrue);
        expect(inHd.dashboardDisplayMode, DashboardDisplayMode.tabs);
        expect(inHd.dashboardCardOrder, order);

        await controller.setHdEnabled(false);
        final restored = await _load();
        expect(restored.dashboardCardOrder, order);
        expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
        expect(restored.dashboardCardHidden, ['repair']);
        expect(restored.dashboardCardCollapsed, ['fleet']);
        expect(restored.moduleShowLogo('quests'), isFalse);
        expect(restored.moduleShowName('battle'), isFalse);
        expect(restored.hdSettings.encode(), hdLayout);
      }
    },
  );

  test('all hidden tabs keep their saved order when one is restored', () async {
    final controller = await _load();
    final order = LayoutSettingsStore.defaultDashboardCardOrder.reversed
        .toList();
    await controller.setDashboardDisplayMode(DashboardDisplayMode.tabs);
    for (final id in LayoutSettingsStore.defaultDashboardCardOrder) {
      await controller.toggleDashboardCardHidden(id);
    }
    await controller.setDashboardCardOrder(order);
    final hidden = await _load();
    expect(hidden.dashboardCardOrder, order);
    expect(
      hidden.dashboardCardHidden,
      unorderedEquals(LayoutSettingsStore.defaultDashboardCardOrder),
    );
    await hidden.toggleDashboardCardHidden('fleet');
    await hidden.setDashboardDisplayMode(DashboardDisplayMode.accordion);
    await hidden.setDashboardDisplayMode(DashboardDisplayMode.tabs);
    final restored = await _load();
    expect(restored.dashboardCardOrder, order);
    expect(restored.dashboardCardHidden, isNot(contains('fleet')));
    expect(restored.dashboardCardHidden, hasLength(order.length - 1));
    expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
  });

  test(
    'legacy duplicate tab IDs recover once while preserving first order and land base migration',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_dashboard_display_mode': 'tabs',
        'layout_dashboard_card_order': <String>[
          'fleet',
          'fleet',
          'retired_module',
          'quests',
          'quests',
        ],
      });
      final restored = await _load();
      expect(restored.dashboardCardOrder, [
        'fleet',
        'land_base',
        'quests',
        'battle',
        'expedition',
        'repair',
        'construction',
        'pre_sortie',
      ]);
      expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
      await restored.setDashboardCardOrder(restored.dashboardCardOrder);
      final reopened = await _load();
      expect(reopened.dashboardCardOrder, restored.dashboardCardOrder);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'layout_dashboard_card_order',
        ),
        restored.dashboardCardOrder,
      );
    },
  );
}

Future<LayoutSettingsController> _load() async {
  final controller = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  addTearDown(controller.dispose);
  return controller;
}
