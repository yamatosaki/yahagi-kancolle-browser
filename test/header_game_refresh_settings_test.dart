import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

const _gameRefreshId = 'game-refresh';

Future<LayoutSettingsController> _loadSettings() async {
  final controller = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'game refresh is configurable after frame refresh and hidden by default',
    () async {
      final controller = await _loadSettings();
      final frameIndex = controller.headerResourceOrder.indexOf(
        headerFrameRefreshId,
      );

      expect(controller.headerResourceOrder, contains(_gameRefreshId));
      expect(
        controller.headerResourceOrder.sublist(frameIndex, frameIndex + 3),
        <String>[headerFrameRefreshId, _gameRefreshId, headerShipCapacityId],
      );
      expect(
        controller.visibleHeaderResourceIds,
        isNot(contains(_gameRefreshId)),
      );
    },
  );

  test(
    'complete legacy custom order migrates game refresh without changing choices',
    () async {
      // A complete pre-game-refresh preference, including a user-moved refresh.
      const legacyOrder = <String>[
        'useitem-95',
        'material-2',
        'senka',
        'ship-capacity',
        'furniture-coin',
        'anchorage-timer',
        'material-8',
        'equipment-capacity',
        'nosaki-timer',
        'material-1',
        'material-3',
        'frame-refresh',
        'useitem-10',
        'material-4',
        'material-5',
        'material-6',
        'material-7',
        'useitem-11',
        'useitem-12',
        'useitem-54',
        'useitem-57',
        'useitem-59',
        'useitem-61',
        'useitem-68',
        'useitem-70',
        'useitem-75',
        'useitem-77',
        'useitem-78',
        'useitem-94',
        'useitem-100',
      ];
      const legacyVisible = <String>[
        'material-2',
        'frame-refresh',
        'useitem-95',
        'ship-capacity',
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_resource_order': legacyOrder,
        'layout_visible_header_resource_ids': legacyVisible,
      });
      final expectedOrder = List<String>.from(legacyOrder)
        ..insert(legacyOrder.indexOf('frame-refresh') + 1, _gameRefreshId);

      final controller = await _loadSettings();

      expect(controller.headerResourceOrder, expectedOrder);
      expect(controller.visibleHeaderResourceIds, legacyVisible);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('layout_header_resource_order'),
        expectedOrder,
      );
      expect(
        prefs.getStringList('layout_visible_header_resource_ids'),
        legacyVisible,
      );

      final restored = await _loadSettings();
      expect(restored.headerResourceOrder, expectedOrder);
      expect(restored.visibleHeaderResourceIds, legacyVisible);
    },
  );

  test('game refresh visibility and custom position survive reloads', () async {
    final controller = await _loadSettings();
    final originalVisible = List<String>.from(
      controller.visibleHeaderResourceIds,
    );

    await controller.toggleHeaderResourceVisible(_gameRefreshId);
    final customOrder = <String>[
      _gameRefreshId,
      ...controller.headerResourceOrder.where((id) => id != _gameRefreshId),
    ];
    await controller.setHeaderResourceOrder(customOrder);

    final restored = await _loadSettings();
    expect(restored.headerResourceOrder, customOrder);
    expect(restored.visibleHeaderResourceIds, <String>[
      ...originalVisible,
      _gameRefreshId,
    ]);

    await restored.toggleHeaderResourceVisible(_gameRefreshId);

    final hidden = await _loadSettings();
    expect(hidden.headerResourceOrder, customOrder);
    expect(hidden.visibleHeaderResourceIds, originalVisible);
    expect(hidden.visibleHeaderResourceIds, isNot(contains(_gameRefreshId)));
  });

  test(
    'reset hides game refresh and restores its default position on reload',
    () async {
      final controller = await _loadSettings();
      final defaultOrder = List<String>.from(controller.headerResourceOrder);
      final defaultVisible = List<String>.from(
        controller.visibleHeaderResourceIds,
      );
      await controller.toggleHeaderResourceVisible(_gameRefreshId);
      await controller.setHeaderResourceOrder(<String>[
        _gameRefreshId,
        ...defaultOrder.where((id) => id != _gameRefreshId),
      ]);

      await controller.resetHeaderResources();

      final restored = await _loadSettings();
      expect(restored.headerResourceOrder, defaultOrder);
      expect(restored.visibleHeaderResourceIds, defaultVisible);
      expect(
        restored.visibleHeaderResourceIds,
        isNot(contains(_gameRefreshId)),
      );
      expect(restored.headerResourceOrder, contains(_gameRefreshId));
      expect(
        restored.headerResourceOrder.indexOf(_gameRefreshId),
        restored.headerResourceOrder.indexOf(headerFrameRefreshId) + 1,
      );
    },
  );
}
