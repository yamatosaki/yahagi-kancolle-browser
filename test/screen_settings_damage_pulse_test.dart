import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_runtime_settings_page.dart';

void main() {
  testWidgets('setting titles and descriptions share the function-area sizes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    addTearDown(layout.dispose);
    addTearDown(display.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenSettingsPage(
          layoutSettingsController: layout,
          displayModeController: display,
        ),
      ),
    );

    for (final (title, description) in <(String, String)>[
      ('功能区位置', '选择功能区显示在左侧或右侧，竖屏保持上下布局。'),
      ('菜单栏位置', '上方位于游戏画面下方。'),
      ('锁定界面布局', '锁定后禁止长按卡片与顶栏资源进入自定义编辑，并禁止拖拽导航栏排序；功能页仍可正常切换'),
    ]) {
      final titleFinder = find.text(title);
      await tester.ensureVisible(titleFinder);
      expect(tester.widget<Text>(titleFinder).style?.fontSize, 14);
      expect(tester.widget<Text>(find.text(description)).style?.fontSize, 12);
    }
  });

  testWidgets('information panel switch and reset affect panel preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await controller.setDashboardCardOrder(
      LayoutSettingsStore.defaultDashboardCardOrder.reversed.toList(),
    );
    await controller.toggleDashboardCardCollapsed('fleet');
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenSettingsPage(
          layoutSettingsController: controller,
          displayModeController: display,
        ),
      ),
    );
    final label = find.byKey(const Key('settings-information-panel-left'));
    await tester.ensureVisible(label);
    await tester.tap(
      find.byKey(const Key('settings-information-panel-position')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('左').last);
    await tester.pumpAndSettle();
    expect(controller.informationPanelOnLeft, isTrue);
    expect(controller.workspaceMenuOnRight, isFalse);
    await tester.ensureVisible(
      find.byKey(const Key('settings-reset-dashboard-card-order')),
    );
    await tester.tap(
      find.byKey(const Key('settings-reset-dashboard-card-order')),
    );
    await tester.pump();
    expect(
      controller.dashboardCardOrder,
      LayoutSettingsStore.defaultDashboardCardOrder,
    );
    expect(controller.dashboardCardCollapsed, contains('fleet'));
    expect(controller.informationPanelOnLeft, isTrue);
    final reloaded = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(
      reloaded.dashboardCardOrder,
      LayoutSettingsStore.defaultDashboardCardOrder,
    );
    expect(reloaded.informationPanelOnLeft, isTrue);
    final extension = find.byKey(const Key('settings-hd-extension-position'));
    expect(extension, findsNothing);
    await controller.setHdEnabled(true);
    await tester.pumpAndSettle();
    await tester.ensureVisible(extension);
    expect(extension, findsOneWidget);
    await tester.tap(extension);
    await tester.pumpAndSettle();
    await tester.tap(find.text('上').last);
    await tester.pumpAndSettle();
    expect(controller.hdSettings.extensionAboveGame, isTrue);
    await controller.setHdEnabled(false);
    await tester.pumpAndSettle();
    expect(extension, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('runtime settings expose background audio playback switch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final layoutController = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final audioController = await GameAudioController.load(
      SharedPreferencesGameAudioStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameRuntimeSettingsPage(
          layoutSettingsController: layoutController,
          audioController: audioController,
        ),
      ),
    );

    final label = find.byKey(const Key('settings-background-audio'));
    await tester.ensureVisible(label);
    expect(label, findsOneWidget);
    expect(find.text('开启后，应用进入后台时游戏声音仍会继续播放。'), findsOneWidget);
    expect(audioController.backgroundPlaybackEnabled, isFalse);

    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(audioController.backgroundPlaybackEnabled, isTrue);
  });

  testWidgets('workspace menu side switch moves preference to the right', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final layoutController = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final displayController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenSettingsPage(
          layoutSettingsController: layoutController,
          displayModeController: displayController,
        ),
      ),
    );

    final label = find.byKey(const Key('settings-workspace-menu-position'));
    expect(label, findsOneWidget);
    expect(layoutController.workspaceMenuOnRight, isFalse);

    final dropdown = find.descendant(
      of: label,
      matching: find.byType(DropdownButton<String>),
    );
    for (final entry in {
      '上': 'top',
      '下': 'bottom',
      '左': 'left',
      '右': 'right',
    }.entries) {
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key).last);
      await tester.pumpAndSettle();
      expect(layoutController.workspaceMenuPosition, entry.value);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('damage pulse switch is consolidated into battle settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final layoutController = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final displayController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScreenSettingsPage(
          layoutSettingsController: layoutController,
          displayModeController: displayController,
        ),
      ),
    );

    final label = find.byKey(const Key('settings-enhanced-damage-pulse'));
    expect(label, findsNothing);
  });

  testWidgets(
    'workspace menu reset button restores the current default order',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final layoutController = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      await layoutController.setWorkspaceMenuOrder(<String>[
        'settings',
        ...LayoutSettingsStore.defaultWorkspaceMenuOrder.where(
          (id) => id != 'settings',
        ),
      ]);
      final displayController = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScreenSettingsPage(
            layoutSettingsController: layoutController,
            displayModeController: displayController,
          ),
        ),
      );

      final reset = find.byKey(
        const Key('settings-reset-workspace-menu-order'),
      );
      expect(reset, findsOneWidget);
      final menuLabel = find.byKey(
        const Key('settings-workspace-menu-position'),
      );
      final menuRow = menuLabel;
      final menuSwitch = find.descendant(
        of: menuRow,
        matching: find.byType(DropdownButton<String>),
      );
      expect(find.descendant(of: menuRow, matching: reset), findsNothing);
      expect(menuSwitch, findsOneWidget);
      final belowReset = find.byKey(
        const Key('settings-reset-dashboard-card-order'),
      );
      expect(
        tester.getRect(reset).left,
        closeTo(tester.getRect(belowReset).left, .1),
      );
      expect(
        tester.getRect(reset).right,
        closeTo(tester.getRect(belowReset).right, .1),
      );
      final dropdown = tester.widget<DropdownButton<String>>(menuSwitch);
      expect(dropdown.underline, isA<SizedBox>());
      expect(dropdown.padding, const EdgeInsets.only(left: 14));

      final lock = find.byKey(const Key('settings-ui-lock-switch'));
      expect(
        tester.getCenter(reset).dy,
        greaterThan(tester.getCenter(lock).dy),
      );
      expect(
        tester.getCenter(belowReset).dy,
        greaterThan(tester.getCenter(reset).dy),
      );
      await tester.ensureVisible(reset);
      await tester.pump();
      await tester.tap(reset);
      await tester.pump();

      expect(
        layoutController.workspaceMenuOrder,
        LayoutSettingsStore.defaultWorkspaceMenuOrder,
      );
    },
  );

  testWidgets(
    'screen settings expose UI display size dropdown and switch size',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final layoutController = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final displayController = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScreenSettingsPage(
            layoutSettingsController: layoutController,
            displayModeController: displayController,
          ),
        ),
      );

      final rowFinder = find.byKey(const Key('settings-ui-display-size-row'));
      await tester.ensureVisible(rowFinder);
      expect(rowFinder, findsOneWidget);
      expect(layoutController.uiDisplaySize, UiDisplaySize.normal);

      final dropdown = find.descendant(
        of: rowFinder,
        matching: find.byType(DropdownButton<UiDisplaySize>),
      );
      expect(dropdown, findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final compactItem = find.text('紧凑').last;
      await tester.tap(compactItem);
      await tester.pumpAndSettle();

      expect(layoutController.uiDisplaySize, UiDisplaySize.compact);
      expect(layoutController.headerUiSize, UiDisplaySize.compact);
      expect(layoutController.workspaceMenuSize, UiDisplaySize.compact);
    },
  );
}
