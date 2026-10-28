import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/workspace_menu_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  test(
    'menu position migrates legacy side and persists all four positions',
    () async {
      SharedPreferences.setMockInitialValues({
        'layout_workspace_menu_on_right': true,
      });
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      expect(controller.workspaceMenuPosition, 'right');
      for (final position in ['top', 'bottom', 'left', 'right']) {
        await controller.setWorkspaceMenuPosition(position);
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.workspaceMenuPosition, position);
        expect(
          restored.workspaceMenuHorizontal,
          position == 'top' || position == 'bottom',
        );
        restored.dispose();
      }
    },
  );

  test('minimal ui display size persists across reloads', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.setUiDisplaySize(UiDisplaySize.minimal);
    final restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(restored.uiDisplaySize, UiDisplaySize.minimal);
  });

  test('unknown stored ui display size falls back to normal', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'layout_ui_display_size': 'bogus',
    });
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.uiDisplaySize, UiDisplaySize.normal);
  });

  test('minimal resource position defaults to panel and persists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.minimalResourcePosition, MinimalResourcePosition.panel);
    var notified = 0;
    controller.addListener(() => notified++);
    await controller.setMinimalResourcePosition(MinimalResourcePosition.topBar);
    expect(notified, 1);
    final restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(restored.minimalResourcePosition, MinimalResourcePosition.topBar);
  });

  test('minimal resource position persists the bottom bar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.setMinimalResourcePosition(
      MinimalResourcePosition.bottomBar,
    );
    final restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(restored.minimalResourcePosition, MinimalResourcePosition.bottomBar);
  });

  test(
    'unknown stored minimal resource position falls back to panel',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_minimal_resource_position': 'bogus',
      });
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.minimalResourcePosition, MinimalResourcePosition.panel);
    },
  );

  test('collapsed panel resources default to null and persist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.collapsedPanelResourceIds, isNull);
    var notified = 0;
    controller.addListener(() => notified++);
    await controller.setCollapsedPanelResourceIds([
      headerShipCapacityId,
      'material-2',
    ]);
    expect(notified, 1);
    var restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(restored.collapsedPanelResourceIds, [
      headerShipCapacityId,
      'material-2',
    ]);

    await restored.setCollapsedPanelResourceIds(const <String>[]);
    restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(restored.collapsedPanelResourceIds, isEmpty);

    await restored.setCollapsedPanelResourceIds(null);
    restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(restored.collapsedPanelResourceIds, isNull);
  });

  test('collapsed panel resources drop unknown and duplicate ids', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'layout_minimal_collapsed_resource_ids': <String>[
        'material-1',
        'bogus',
        'material-1',
        headerSenkaId,
      ],
    });
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.collapsedPanelResourceIds, ['material-1', headerSenkaId]);
  });

  test('information panel defaults right and persists both sides', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.informationPanelOnLeft, isFalse);
    for (final onLeft in <bool>[true, false]) {
      await controller.setInformationPanelOnLeft(onLeft);
      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.informationPanelOnLeft, onLeft);
    }
  });

  test(
    'fleet morale metric mode defaults and persists across reloads',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(
        controller.fleetMoraleMetricMode,
        FleetMoraleMetricMode.minimumCondition,
      );

      await controller.toggleFleetMoraleMetricMode();
      expect(
        controller.fleetMoraleMetricMode,
        FleetMoraleMetricMode.recoveryCountdown,
      );
      expect(notifications, 1);

      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(
        controller.fleetMoraleMetricMode,
        FleetMoraleMetricMode.recoveryCountdown,
      );
    },
  );

  test('workspace menu defaults left and persists moving right', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.workspaceMenuOnRight, isFalse);

    await controller.setWorkspaceMenuOnRight(true);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.workspaceMenuOnRight, isTrue);
  });

  test(
    'workspace menu order persists and restores the current default',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(
        controller.workspaceMenuOrder,
        LayoutSettingsStore.defaultWorkspaceMenuOrder,
      );
      expect(
        controller.workspaceMenuOrder,
        containsAllInOrder(<String>['owned-inventory', 'tools', 'settings']),
      );

      await controller.reorderWorkspaceMenu(0, 1);
      expect(controller.workspaceMenuOrder.take(2), <String>['fleet', 'game']);

      final custom = <String>[
        'settings',
        ...LayoutSettingsStore.defaultWorkspaceMenuOrder.where(
          (id) => id != 'settings',
        ),
      ];
      await controller.setWorkspaceMenuOrder(custom);
      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.workspaceMenuOrder, custom);

      await controller.resetWorkspaceMenuOrder();
      expect(
        controller.workspaceMenuOrder,
        LayoutSettingsStore.defaultWorkspaceMenuOrder,
      );
    },
  );

  test(
    'workspace menu order drops unknowns and appends missing entries',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_workspace_menu_order': <String>[
          'quests',
          'unknown',
          'game',
          'quests',
        ],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(controller.workspaceMenuOrder.take(2), <String>['quests', 'game']);
      expect(
        controller.workspaceMenuOrder.toSet(),
        LayoutSettingsStore.defaultWorkspaceMenuOrder.toSet(),
      );
      expect(
        controller.workspaceMenuOrder,
        hasLength(LayoutSettingsStore.defaultWorkspaceMenuOrder.length),
      );
      expect(controller.workspaceMenuOrder, contains('tools'));
    },
  );

  test(
    'legacy complete menu inserts tools immediately before settings',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_workspace_menu_order': <String>[
          'game',
          'fleet',
          'expedition',
          'repair',
          'construction',
          'quests',
          'senka',
          'battle-records',
          'owned-inventory',
          'settings',
        ],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      final toolsIndex = controller.workspaceMenuOrder.indexOf('tools');
      expect(toolsIndex, controller.workspaceMenuOrder.indexOf('settings') - 1);
      expect(controller.workspaceMenuOrder[toolsIndex - 1], 'owned-inventory');
    },
  );

  test('enhanced damage pulse defaults on and persists changes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.enhancedDamagePulse, isTrue);

    await controller.setEnhancedDamagePulse(false);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.enhancedDamagePulse, isFalse);
  });

  test('land-base card follows fleet in defaults and legacy orders', () async {
    expect(
      LayoutSettingsStore.defaultDashboardCardOrder,
      containsAllInOrder(<String>['fleet', 'land_base', 'expedition']),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'layout_dashboard_card_order': <String>[
        'battle',
        'fleet',
        'expedition',
        'repair',
        'construction',
        'quests',
        'pre_sortie',
      ],
    });
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(
      controller.dashboardCardOrder,
      containsAllInOrder(<String>['fleet', 'land_base', 'expedition']),
    );
  });

  test('recommended ratio locks the information panel at 33 percent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'layout_game_area_ratio': 0.58,
      'layout_auto_zoom': true,
    });
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.effectiveInformationPanelRatio, 0.33);
    expect(controller.canAdjustInformationPanelRatio, isFalse);

    await controller.setAutoZoom(false);

    expect(controller.effectiveInformationPanelRatio, closeTo(0.42, 0.0001));
    expect(controller.canAdjustInformationPanelRatio, isTrue);
    expect(controller.gameAreaRatio, 0.58);
  });

  test('reorder can move a middle dashboard card after the final card', () {
    expect(reorderDashboardCards(<String>['a', 'b', 'c', 'd'], 1, 3), <String>[
      'a',
      'c',
      'd',
      'b',
    ]);
  });

  test('reorder can move the final dashboard card upward', () {
    expect(reorderDashboardCards(<String>['a', 'b', 'c', 'd'], 3, 1), <String>[
      'a',
      'd',
      'b',
      'c',
    ]);
  });

  test(
    'header resources default to senka followed by eight materials',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(controller.headerResourceOrder, contains(headerFrameRefreshId));
      expect(
        controller.visibleHeaderResourceIds,
        isNot(contains(headerFrameRefreshId)),
      );
      expect(controller.headerResourceOrder.first, headerSenkaId);
      expect(controller.visibleHeaderResourceIds, <String>[
        headerSenkaId,
        'anchorage-timer',
        'nosaki-timer',
        headerShipCapacityId,
        headerEquipmentCapacityId,
        'material-1',
        'material-2',
        'material-3',
        'material-4',
        'material-5',
        'material-6',
        'material-7',
        'material-8',
      ]);
    },
  );

  test(
    'furniture coin defaults hidden between material 8 and furniture box',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(
        controller.visibleHeaderResourceIds,
        isNot(contains(headerFurnitureCoinId)),
      );
      final coinIndex = controller.headerResourceOrder.indexOf(
        headerFurnitureCoinId,
      );
      expect(controller.headerResourceOrder[coinIndex - 1], 'material-8');
      expect(controller.headerResourceOrder[coinIndex + 1], 'useitem-10');
    },
  );

  test(
    'legacy resource order migrates furniture coin without showing it',
    () async {
      final legacyOrder = <String>[
        for (final id in allHeaderResourceIds)
          if (id != headerFurnitureCoinId) id,
      ];
      const legacyVisible = <String>[headerSenkaId, 'material-8', 'useitem-10'];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_resource_order': legacyOrder,
        'layout_visible_header_resource_ids': legacyVisible,
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final coinIndex = controller.headerResourceOrder.indexOf(
        headerFurnitureCoinId,
      );

      expect(controller.headerResourceOrder[coinIndex - 1], 'material-8');
      expect(controller.headerResourceOrder[coinIndex + 1], 'useitem-10');
      expect(controller.visibleHeaderResourceIds, legacyVisible);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('layout_header_resource_order'),
        controller.headerResourceOrder,
      );
      expect(
        prefs.getStringList('layout_visible_header_resource_ids'),
        legacyVisible,
      );
    },
  );

  test(
    'legacy header order adds senka first without reordering resources',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_resource_order': <String>['material-2', 'material-1'],
        'layout_visible_header_resource_ids': <String>['material-2'],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );

      expect(controller.headerResourceOrder.take(8), <String>[
        headerSenkaId,
        'anchorage-timer',
        'nosaki-timer',
        headerFrameRefreshId,
        headerGameRefreshId,
        headerShipCapacityId,
        headerEquipmentCapacityId,
        'material-2',
      ]);
      expect(controller.visibleHeaderResourceIds, <String>[
        headerSenkaId,
        'anchorage-timer',
        'nosaki-timer',
        'material-2',
        headerShipCapacityId,
        headerEquipmentCapacityId,
      ]);
    },
  );

  test(
    'complete legacy header order inserts capacities after timers',
    () async {
      final legacyOrder = <String>[
        for (final id in allHeaderResourceIds)
          if (id != headerShipCapacityId && id != headerEquipmentCapacityId) id,
      ];
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_resource_order': legacyOrder,
        'layout_visible_header_resource_ids': <String>[
          headerSenkaId,
          headerAnchorageTimerId,
          headerNosakiTimerId,
          'material-1',
          'material-2',
        ],
      });

      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final nosakiIndex = controller.headerResourceOrder.indexOf(
        headerNosakiTimerId,
      );
      expect(
        controller.headerResourceOrder.sublist(
          nosakiIndex + 1,
          nosakiIndex + 5,
        ),
        <String>[
          headerFrameRefreshId,
          headerGameRefreshId,
          headerShipCapacityId,
          headerEquipmentCapacityId,
        ],
      );
      expect(
        controller.headerResourceOrder.where(legacyOrder.contains),
        legacyOrder,
      );
    },
  );

  test('header resource order and visibility persist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    await controller.setHeaderResourceOrder(<String>[
      'useitem-68',
      ...controller.headerResourceOrder.where((id) => id != 'useitem-68'),
    ]);
    await controller.toggleHeaderResourceVisible('useitem-68');
    await controller.toggleHeaderResourceVisible('material-1');

    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.headerResourceOrder.first, 'useitem-68');
    expect(controller.visibleHeaderResourceIds, contains('useitem-68'));
    expect(controller.visibleHeaderResourceIds, isNot(contains('material-1')));

    await controller.toggleHeaderResourceVisible(headerShipCapacityId);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(
      controller.visibleHeaderResourceIds,
      isNot(contains(headerShipCapacityId)),
    );
  });

  test('capacity capsule order persists after customization', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    await controller.setHeaderResourceOrder(<String>[
      headerEquipmentCapacityId,
      ...controller.headerResourceOrder.where(
        (id) => id != headerEquipmentCapacityId,
      ),
    ]);
    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );

    expect(controller.headerResourceOrder.first, headerEquipmentCapacityId);
  });

  test('header UI size defaults to normal and persists compact', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.headerUiSize, HeaderUiSize.normal);

    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setHeaderUiSize(HeaderUiSize.compact);
    expect(controller.headerUiSize, HeaderUiSize.compact);
    expect(notifications, 1);

    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.headerUiSize, HeaderUiSize.compact);
  });

  test('workspace menu size defaults to normal and persists compact', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.workspaceMenuSize, WorkspaceMenuSize.normal);

    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setWorkspaceMenuSize(WorkspaceMenuSize.compact);
    expect(controller.workspaceMenuSize, WorkspaceMenuSize.compact);
    expect(notifications, 1);

    controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(controller.workspaceMenuSize, WorkspaceMenuSize.compact);
  });

  test(
    'UI display size unifies header and menu sizes and persists across reloads',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.uiDisplaySize, UiDisplaySize.normal);
      expect(controller.headerUiSize, HeaderUiSize.normal);
      expect(controller.workspaceMenuSize, WorkspaceMenuSize.normal);

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setUiDisplaySize(UiDisplaySize.compact);
      expect(controller.uiDisplaySize, UiDisplaySize.compact);
      expect(controller.headerUiSize, HeaderUiSize.compact);
      expect(controller.workspaceMenuSize, WorkspaceMenuSize.compact);
      expect(notifications, 1);

      controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.uiDisplaySize, UiDisplaySize.compact);
      expect(controller.headerUiSize, HeaderUiSize.compact);
      expect(controller.workspaceMenuSize, WorkspaceMenuSize.compact);
    },
  );

  group('UI display size migration and fallback', () {
    test('migrates legacy header-only compact setting', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_ui_size': 'compact',
      });
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.uiDisplaySize, UiDisplaySize.compact);
    });

    test('migrates legacy menu-only compact setting', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_workspace_menu_size': 'compact',
      });
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.uiDisplaySize, UiDisplaySize.compact);
    });

    test('compact takes precedence when legacy settings differ', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_header_ui_size': 'normal',
        'layout_workspace_menu_size': 'compact',
      });
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.uiDisplaySize, UiDisplaySize.compact);
    });

    test('direct setting takes precedence over legacy settings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'layout_ui_display_size': 'normal',
        'layout_header_ui_size': 'compact',
        'layout_workspace_menu_size': 'compact',
      });
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(controller.uiDisplaySize, UiDisplaySize.normal);
    });

    test(
      'gracefully falls back to normal on corrupted or unknown values',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'layout_ui_display_size': 'super_giant_unknown_mode',
        });
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(controller.uiDisplaySize, UiDisplaySize.normal);
      },
    );
  });
}
