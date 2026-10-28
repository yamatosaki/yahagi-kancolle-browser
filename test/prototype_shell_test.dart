import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/layout/display_corners.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/dashboard_display_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_font_size.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/app_exit_settings.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_viewport.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_workspace_visibility.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_display_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_screenshot_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_fullscreen_exit_dialog.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';
import 'package:yahagi_kancolle_browser/src/fleet/land_base_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/repair_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/toolbox_page.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_feedback.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/fleet/dashboard_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_check_summary.dart';
import 'package:yahagi_kancolle_browser/src/layout/flat_style.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/layout/dashboard_tabs.dart';
import 'package:yahagi_kancolle_browser/src/layout/ui_scale.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_workspace_geometry.dart';
import 'fixtures/kcsapi_fixtures.dart';

const _phoneLandscape = Size(873, 393);
const _minimalHeaderHeight = 36.0;
const _minimalNavigationExtent = 41.0;

Future<LayoutSettingsController> _pumpMinimalShell(
  WidgetTester tester, {
  Size size = _phoneLandscape,
  UiDisplaySize uiSize = UiDisplaySize.minimal,
  Widget? gameSurface,
  _NoopBrowserPort? browserPort,
  GameStateController? gameState,
  GameToolbarController? toolbarController,
  TopNoticeController? headerNoticeController,
  LayoutSettingsStore? layoutStore,
  String? localeCode,
  DisplayMode displayMode = DisplayMode.auto,
  GameRenderingModeController? renderingController,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final layout = await LayoutSettingsController.load(
    layoutStore ?? _MemoryLayoutSettingsStore(),
  );
  await layout.setUiDisplaySize(uiSize);
  if (localeCode != null) await layout.setLocaleCode(localeCode);
  final gameStateController = gameState ?? GameStateController();
  addTearDown(gameStateController.dispose);
  await tester.pumpWidget(
    YahagiApp(
      layoutSettingsController: layout,
      gameRenderingModeController: renderingController,
      networkSettingsController: NetworkSettingsController(
        store: _MemoryNetworkSettingsStore(),
      ),
      gadgetBypassController: GadgetBypassController(
        store: _MemoryGadgetBypassStore(),
        port: _FakeGadgetBypassPort(),
      ),
      safetySettingsController: await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      ),
      displayModeController: await DisplayModeController.load(
        MemoryDisplayModeStore(displayMode),
      ),
      controller: PrototypeStatusController(),
      browserController: GameBrowserController(
        port: browserPort ?? _NoopBrowserPort(),
      ),
      captureModeController: await CaptureModeController.load(
        _MemoryModeStore(),
      ),
      gameCaptureController: GameCaptureController(),
      gameStateController: gameStateController,
      battleController: BattleController(
        gameState: () => gameStateController.state,
      ),
      audioController: await GameAudioController.load(_MemoryAudioStore()),
      toolbarController: toolbarController ?? GameToolbarController(),
      headerNoticeController: headerNoticeController,
      gameSurface: gameSurface ?? const ColoredBox(color: Colors.black),
    ),
  );
  await tester.pumpAndSettle();
  return layout;
}

double _headerHeight(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('workspace-content-expanded'))).dy;

double _sidebarWidth(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('workspace-navigation-sidebar'))).width;

Future<void> _tapWorkspaceNavigationItem(
  WidgetTester tester,
  String destinationId,
) async {
  final item = find.byKey(Key('workspace-nav-$destinationId'));
  final navigation = find.byKey(const Key('workspace-navigation-list'));
  await tester.dragUntilVisible(item, navigation, const Offset(0, -50));
  await tester.drag(navigation, const Offset(0, -50));
  await tester.pump();
  await tester.tap(item);
}

Future<void> _longPressInformationPanel(WidgetTester tester) async {
  final panel = find.byKey(const Key('information-panel'));
  final tabbed = find
      .descendant(
        of: panel,
        matching: find.byKey(const Key('dashboard-tab-bar')),
      )
      .evaluate()
      .isNotEmpty;
  await tester.longPressAt(
    tester.getTopLeft(panel) + Offset(16, tabbed ? 66 : 16),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapBriefingTab(WidgetTester tester, String id) async {
  final tab = find.byKey(Key('dashboard-tab-$id'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> _longPressBriefingTab(WidgetTester tester, String id) async {
  final tab = find.byKey(Key('dashboard-tab-$id'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.longPress(tab);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dashboard-edit-done')), findsOneWidget);
  expect(find.byKey(Key('$id-display-close')), findsNothing);
}

Future<void> _openBriefingModuleSettings(WidgetTester tester, String id) async {
  await _longPressBriefingTab(tester, id);
  final gear = find.byKey(Key('$id-display-settings-button'));
  await tester.ensureVisible(gear);
  await tester.pumpAndSettle();
  await tester.tap(gear);
  await tester.pumpAndSettle();
  expect(find.byKey(Key('$id-display-close')), findsOneWidget);
}

Future<void> _closeBriefingModuleSettings(
  WidgetTester tester,
  String id,
) async {
  await tester.tap(find.byKey(Key('$id-display-close')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dashboard-edit-done')), findsOneWidget);
  await tester.tap(find.byKey(const Key('dashboard-edit-done')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dashboard-tabs')), findsOneWidget);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // These shell scenarios assert Chinese UI; system-English behavior has its
    // own explicit locale integration coverage.
    binding.platformDispatcher.localeTestValue = const Locale('zh');
    binding.platformDispatcher.localesTestValue = const [Locale('zh')];
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
  });

  testWidgets(
    'briefing tabs keep default accordion preferences and hidden selection safe',
    (tester) async {
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
      );
      addTearDown(layout.dispose);
      expect(layout.dashboardDisplayMode, DashboardDisplayMode.accordion);
      expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
      await layout.toggleDashboardCardCollapsed('fleet');
      final collapsed = [...layout.dashboardCardCollapsed];
      await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tabs')), findsOneWidget);
      expect(
        tester
            .widget<FleetSummaryCard>(
              find.byType(FleetSummaryCard, skipOffstage: false),
            )
            .collapsed,
        isFalse,
      );
      await _tapBriefingTab(tester, 'fleet');
      await tester.pumpAndSettle();
      expect(find.byType(FleetSummaryCard), findsOneWidget);
      await layout.toggleDashboardCardHidden('fleet');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tab-fleet')), findsNothing);
      expect(tester.takeException(), isNull);
      await layout.toggleDashboardCardHidden('fleet');
      await tester.pumpAndSettle();
      expect(find.byType(FleetSummaryCard), findsNothing);
      await layout.toggleDashboardCardHidden('fleet');
      await tester.pumpAndSettle();
      await layout.setDashboardDisplayMode(DashboardDisplayMode.accordion);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
      expect(layout.dashboardCardCollapsed, collapsed);
      expect(layout.dashboardCardHidden, contains('fleet'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final uiSize in UiDisplaySize.values) {
    testWidgets('briefing tabs shell smoke at $uiSize', (tester) async {
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        uiSize: uiSize,
      );
      addTearDown(layout.dispose);
      await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tabs')), findsOneWidget);
      for (final id in [
        'battle',
        'fleet',
        'land_base',
        'construction',
        'quests',
        'pre_sortie',
      ]) {
        final tab = find.byKey(Key('dashboard-tab-$id'));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(PreSortieCheckSummary), findsOneWidget);
      await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
      await tester.pumpAndSettle();
      final selectedMap = tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(const Key('sortie-check-mode-maps')),
                  matching: find.byType(Text),
                )
                .first,
          )
          .style
          ?.color;
      await _tapBriefingTab(tester, 'fleet');
      await tester.pumpAndSettle();
      final checkTab = find.byKey(const Key('dashboard-tab-pre_sortie'));
      await tester.ensureVisible(checkTab);
      await tester.tap(checkTab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('sortie-check-mode-maps')),
                    matching: find.byType(Text),
                  )
                  .first,
            )
            .style
            ?.color,
        selectedMap,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'briefing check warnings remain inside their tab without a fixed banner',
    (tester) async {
      final state = GameStateController(
        initialState: const GameState(
          hasMasterData: true,
          hasPortData: true,
          masterShips: {
            101: MasterShip(
              id: 101,
              name: '熊野改',
              shipTypeId: 5,
              maxFuel: 10,
              maxAmmo: 10,
              slotCount: 2,
            ),
          },
          ships: {
            1001: OwnedShip(
              id: 1001,
              masterId: 101,
              level: 64,
              currentHp: 30,
              maxHp: 30,
              currentFuel: 10,
              currentAmmo: 10,
              condition: 49,
              slotIds: [7001],
            ),
          },
          fleets: [
            Fleet(id: 1, name: '第一舰队', shipIds: [1001]),
          ],
        ),
      );
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        gameState: state,
      );
      addTearDown(layout.dispose);
      await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      await tester.pumpAndSettle();
      final warning = find.byKey(const Key('dashboard-tab-warning-notice'));
      expect(warning, findsNothing);
      final checkTab = find.byKey(const Key('dashboard-tab-pre_sortie'));
      await tester.ensureVisible(checkTab);
      await tester.tap(checkTab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pre-sortie-warning-1-main-equipment')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pre-sortie-warning-1-main-equipment')),
        findsNothing,
      );
      expect(warning, findsNothing);
      await tester.tap(find.byKey(const Key('sortie-check-mode-ships')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pre-sortie-warning-1-main-equipment')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('briefing tabs preserve HD separate modules and layout editing', (
    tester,
  ) async {
    final layout = await _pumpMinimalShell(
      tester,
      size: const Size(1200, 700),
      uiSize: UiDisplaySize.normal,
    );
    addTearDown(layout.dispose);
    await layout.setHdEnabled(true);
    await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
    expect(layout.dashboardDisplayMode, DashboardDisplayMode.tabs);
    for (final id in layout.hdSettings.activeModules) {
      expect(find.byKey(Key('dashboard-tab-$id')), findsNothing);
      expect(find.byKey(ValueKey('hd-module-content-$id')), findsOneWidget);
    }
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    await _tapWorkspaceNavigationItem(tester, 'game');
    await tester.pumpAndSettle();
    await _longPressInformationPanel(tester);
    expect(find.byKey(const Key('dashboard-edit-done')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
    await tester.tap(find.byKey(const Key('dashboard-edit-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
    await layout.setHdEnabled(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-tabs')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final uiSize in [UiDisplaySize.normal, UiDisplaySize.minimal]) {
    testWidgets(
      'strict briefing HD round trips preserve saved tabs and ordinary preferences at $uiSize',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        addTearDown(() => SharedPreferences.setMockInitialValues({}));
        var disposals = 0;
        final layout = await _pumpMinimalShell(
          tester,
          size: const Size(1200, 800),
          uiSize: uiSize,
          layoutStore: SharedPreferencesLayoutSettingsStore(),
          gameSurface: _LifecycleProbe(
            key: const Key('strict-hd-tabs-live-game'),
            onDispose: () => disposals++,
          ),
        );
        addTearDown(layout.dispose);
        final game = find.byKey(const Key('strict-hd-tabs-live-game'));
        final originalGame = tester.element(game);
        final order = [
          'quests',
          ...LayoutSettingsStore.defaultDashboardCardOrder.where(
            (id) => id != 'quests',
          ),
        ];
        await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
        await layout.setDashboardCardOrder(order);
        await layout.toggleDashboardCardHidden('construction');
        await layout.toggleDashboardCardCollapsed('fleet');
        final hidden = [...layout.dashboardCardHidden];
        final collapsed = [...layout.dashboardCardCollapsed];
        final visibleOrder = order.where((id) => !hidden.contains(id)).toList();
        await tester.pumpAndSettle();

        void expectLiveGame() {
          expect(tester.element(game), same(originalGame));
          expect(disposals, 0);
          expect(layout.dashboardCardOrder, order);
          expect(layout.dashboardCardHidden, hidden);
          expect(layout.dashboardCardCollapsed, collapsed);
          expect(tester.takeException(), isNull);
        }

        void expectTabs() {
          final tabs = tester.widget<DashboardTabs>(
            find.byKey(const Key('dashboard-tabs')),
          );
          expect(tabs.tabs.map((tab) => tab.id).toList(), visibleOrder);
          expect(
            find.byKey(const Key('dashboard-tab-construction')),
            findsNothing,
          );
          expectLiveGame();
        }

        expectTabs();
        for (final size in [const Size(1200, 800), const Size(390, 844)]) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expectTabs();
          await layout.setHdEnabled(true);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
          expect(layout.dashboardDisplayMode, DashboardDisplayMode.tabs);
          expect(
            find.byKey(
              Key(
                size.width > size.height
                    ? 'hd-bottom-region'
                    : 'hd-portrait-grid',
              ),
            ),
            findsOneWidget,
          );
          expectLiveGame();

          // Changing an ignored preference in HD must still save it, without
          // inserting tabs into either HD layout or changing ordinary cards.
          await layout.setDashboardDisplayMode(DashboardDisplayMode.accordion);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
          expectLiveGame();
          await layout.setHdEnabled(false);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
          expect(layout.dashboardDisplayMode, DashboardDisplayMode.accordion);
          expectLiveGame();

          await layout.setHdEnabled(true);
          await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('dashboard-tabs')), findsNothing);
          final restored = await LayoutSettingsController.load(
            SharedPreferencesLayoutSettingsStore(),
          );
          expect(restored.hdSettings.enabled, isTrue);
          expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
          expect(restored.dashboardCardOrder, order);
          expect(restored.dashboardCardHidden, hidden);
          expect(restored.dashboardCardCollapsed, collapsed);
          restored.dispose();
          expectLiveGame();

          await layout.setHdEnabled(false);
          await tester.pumpAndSettle();
          expectTabs();
        }
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.hdSettings.enabled, isFalse);
        expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
        expect(restored.dashboardCardOrder, order);
        expect(restored.dashboardCardHidden, hidden);
        expect(restored.dashboardCardCollapsed, collapsed);
        restored.dispose();
      },
    );
  }

  testWidgets(
    'strict briefing check warnings stay reachable after a deep map scroll',
    (tester) async {
      final gameState = GameStateController(
        initialState: GameState(
          hasMasterData: true,
          hasPortData: true,
          masterShips: const {
            101: MasterShip(
              id: 101,
              name: '熊野改',
              shipTypeId: 5,
              maxFuel: 10,
              maxAmmo: 10,
              slotCount: 2,
            ),
          },
          ships: {
            for (var id = 1; id <= 4; id++)
              id: OwnedShip(
                id: id,
                masterId: 101,
                level: 64,
                currentHp: 30,
                maxHp: 30,
                currentFuel: 0,
                currentAmmo: 0,
                condition: 18,
                slotIds: const [7001],
              ),
          },
          fleets: [
            for (var id = 1; id <= 4; id++)
              Fleet(id: id, name: '第$id舰队', shipIds: [id]),
          ],
          memberMapInfos: {
            for (var id = 1; id <= 24; id++)
              id: MemberMapInfo(
                id: id,
                mapAreaId: (id - 1) ~/ 6 + 57,
                mapNo: (id - 1) % 6 + 1,
                isEvent: true,
                name: '海域$id',
                requiredDefeatCount: 4,
                defeatCount: 1,
              ),
          },
        ),
      );
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(873, 393),
        uiSize: UiDisplaySize.normal,
        gameState: gameState,
      );
      addTearDown(layout.dispose);
      await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      await tester.pumpAndSettle();
      final notice = find.byKey(const Key('dashboard-tab-warning-notice'));
      expect(notice, findsNothing);
      final checkTab = find.byKey(const Key('dashboard-tab-pre_sortie'));
      await tester.ensureVisible(checkTab);
      await tester.tap(checkTab);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(
              const PageStorageKey<String>('dashboard-tab-scroll-pre_sortie'),
            ),
          )
          .controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(500));
      scroll.jumpTo(500);
      await tester.pump();
      await _tapBriefingTab(tester, 'fleet');
      await tester.pumpAndSettle();
      await tester.ensureVisible(checkTab);
      await tester.tap(checkTab);
      await tester.pumpAndSettle();
      expect(scroll.offset, 500);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.tap(find.byKey(const Key('sortie-check-mode-ships')));
      await tester.pumpAndSettle();
      final firstWarning = find.byKey(const Key('pre-sortie-warning-1-supply'));
      expect(firstWarning.hitTestable(), findsOneWidget);
      await tester.tap(firstWarning);
      await tester.pumpAndSettle();
      expect(find.byType(FleetInformationCenter), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final uiSize in UiDisplaySize.values) {
    testWidgets(
      'strict briefing real cards preserve state across locale theme and rotation at $uiSize',
      (tester) async {
        final gameState = GameStateController(reducer: _HdMinimalStateReducer())
          ..accept(portEvent);
        await gameState.idle;
        var disposals = 0;
        final layout = await _pumpMinimalShell(
          tester,
          size: const Size(1280, 800),
          uiSize: uiSize,
          gameState: gameState,
          gameSurface: _LifecycleProbe(
            key: const Key('strict-briefing-live-game'),
            onDispose: () => disposals++,
          ),
        );
        addTearDown(layout.dispose);
        await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
        await layout.setUiFontSize(UiFontSize.large);
        await layout.setInformationPanelWidth(190);
        await tester.pumpAndSettle();
        final originalGame = tester.element(
          find.byKey(const Key('strict-briefing-live-game')),
        );
        final fleetTab = find.byKey(const Key('dashboard-tab-fleet'));
        await tester.ensureVisible(fleetTab);
        await tester.tap(fleetTab);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fleet-summary-selector-2')));
        await tester.pumpAndSettle();
        final originalFleet = tester.state(find.byType(FleetSummaryCard));
        const locales = ['zh', 'en', 'ja', 'ko', 'zh_Hant'];
        const sizes = [Size(873, 393), Size(390, 844), Size(1280, 800)];
        for (var i = 0; i < locales.length; i++) {
          tester.view.physicalSize = sizes[i % sizes.length];
          await layout.setLocaleCode(locales[i]);
          await layout.setAppThemeMode(
            AppThemeMode.values[i % AppThemeMode.values.length],
          );
          await tester.pumpAndSettle();
          expect(
            tester.state(find.byType(FleetSummaryCard)),
            same(originalFleet),
          );
          expect(find.text('HD舰娘3'), findsOneWidget);
          expect(find.text('HD舰娘1'), findsNothing);
          expect(
            tester.element(find.byKey(const Key('strict-briefing-live-game'))),
            same(originalGame),
          );
          expect(disposals, 0);
          expect(
            tester.takeException(),
            isNull,
            reason: '${locales[i]} / $uiSize',
          );
        }
      },
    );
  }

  testWidgets(
    'strict briefing all hidden restores modules without resetting mode or game',
    (tester) async {
      var disposals = 0;
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        gameSurface: _LifecycleProbe(
          key: const Key('strict-empty-tabs-game'),
          onDispose: () => disposals++,
        ),
      );
      addTearDown(layout.dispose);
      await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      final order = [...layout.dashboardCardOrder];
      for (final id in order) {
        await layout.toggleDashboardCardHidden(id);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-tabs')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-tab-bar')), findsNothing);
      expect(find.byKey(const Key('dashboard-tabs-edit-order')), findsNothing);
      expect(tester.takeException(), isNull);
      await _longPressInformationPanel(tester);
      expect(find.byKey(const Key('dashboard-edit-done')), findsOneWidget);
      for (final id in order) {
        final visibility = find.byKey(Key('dashboard-visibility-$id'));
        await tester.ensureVisible(visibility);
        await tester.pumpAndSettle();
        await tester.tap(visibility);
        await tester.pumpAndSettle();
      }
      expect(layout.dashboardCardHidden, isEmpty);
      await tester.tap(find.byKey(const Key('dashboard-edit-done')));
      await tester.pumpAndSettle();
      expect(layout.dashboardDisplayMode, DashboardDisplayMode.tabs);
      expect(find.byKey(const Key('dashboard-tab-bar')), findsOneWidget);
      expect(
        tester
            .widget<DashboardTabs>(find.byKey(const Key('dashboard-tabs')))
            .tabs
            .map((tab) => tab.id)
            .toList(),
        order,
      );
      expect(disposals, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final uiSize in [UiDisplaySize.normal, UiDisplaySize.minimal]) {
    testWidgets(
      'briefing tabs customize modules and persist drag order at $uiSize',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        addTearDown(() => SharedPreferences.setMockInitialValues({}));
        final layout = await _pumpMinimalShell(
          tester,
          size: const Size(1200, 900),
          uiSize: uiSize,
          layoutStore: SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(layout.dispose);
        await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
        await tester.pumpAndSettle();
        final tabs = find.byKey(const Key('dashboard-tabs'));
        const icons = {
          'battle': Icons.remove_red_eye_outlined,
          'fleet': Icons.directions_boat_filled_outlined,
          'land_base': Icons.flight_rounded,
          'expedition': Icons.explore_outlined,
          'repair': Icons.build_circle_outlined,
          'construction': Icons.handyman_outlined,
          'quests': Icons.assignment_outlined,
          'pre_sortie': Icons.security_outlined,
        };
        for (final entry in icons.entries) {
          final tab = find.byKey(Key('dashboard-tab-${entry.key}'));
          expect(
            find.descendant(of: tab, matching: find.byIcon(entry.value)),
            findsOneWidget,
          );
          await _openBriefingModuleSettings(tester, entry.key);
          await _closeBriefingModuleSettings(tester, entry.key);
          expect(tester.widget<DashboardTabs>(tabs).selectedId, 'battle');
        }
        expect(
          find.byKey(const Key('dashboard-tabs-edit-order')),
          findsNothing,
        );
        final battle = find.byKey(const Key('dashboard-tab-battle'));
        await _openBriefingModuleSettings(tester, 'battle');
        await tester.tap(find.byKey(const Key('battle-capsule-name')));
        await tester.pumpAndSettle();
        await _closeBriefingModuleSettings(tester, 'battle');
        expect(tester.widget<DashboardTabs>(tabs).tabs.first.label, isEmpty);
        expect(
          find.descendant(
            of: battle,
            matching: find.byIcon(Icons.remove_red_eye_outlined),
          ),
          findsOneWidget,
        );
        await layout.setModuleShowName('battle', true);
        await tester.pumpAndSettle();

        final collapsedBefore = [...layout.dashboardCardCollapsed];
        await _longPressBriefingTab(tester, 'battle');
        final source = find.byKey(
          const Key('dashboard-drag-region-construction'),
        );
        expect(source.hitTestable(), findsOneWidget);
        final drag = await tester.startGesture(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 600));
        final target = find.byKey(const Key('dashboard-target-battle'));
        await drag.moveTo(
          tester.getRect(target).topCenter + const Offset(0, 3),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await drag.up();
        await tester.pumpAndSettle();
        expect(layout.dashboardCardOrder.first, 'construction');
        await tester.tap(find.byKey(const Key('dashboard-edit-done')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<DashboardTabs>(tabs).tabs.first.id,
          'construction',
        );
        expect(layout.dashboardCardCollapsed, collapsedBefore);
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.dashboardCardOrder, layout.dashboardCardOrder);
        expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
        restored.dispose();

        await layout.setUiLocked(true);
        await tester.pumpAndSettle();
        final fleet = find.byKey(const Key('dashboard-tab-fleet'));
        await tester.ensureVisible(fleet);
        await tester.longPress(fleet);
        await tester.pump();
        expect(find.byKey(const Key('fleet-display-close')), findsNothing);
        expect(find.byKey(const Key('dashboard-edit-done')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'strict briefing long press persists fleet and module appearance with reachable fallback tabs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 800),
        uiSize: UiDisplaySize.normal,
        layoutStore: SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(layout.dispose);
      await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      await layout.setDashboardCardOrder(
        LayoutSettingsStore.defaultDashboardCardOrder.reversed.toList(),
      );
      await layout.toggleDashboardCardHidden('repair');
      await layout.toggleDashboardCardCollapsed('land_base');
      await tester.pumpAndSettle();
      await _tapBriefingTab(tester, 'quests');
      final order = [...layout.dashboardCardOrder];
      final hidden = [...layout.dashboardCardHidden];
      final collapsed = [...layout.dashboardCardCollapsed];

      DashboardTabs currentTabs() =>
          tester.widget<DashboardTabs>(find.byKey(const Key('dashboard-tabs')));
      DashboardTab tabData(String id) =>
          currentTabs().tabs.singleWhere((tab) => tab.id == id);
      void expectUnchangedLayout() {
        expect(currentTabs().selectedId, 'quests');
        expect(layout.dashboardCardOrder, order);
        expect(layout.dashboardCardHidden, hidden);
        expect(layout.dashboardCardCollapsed, collapsed);
        expect(find.byKey(const Key('dashboard-edit-done')), findsNothing);
        expect(tester.takeException(), isNull);
      }

      Future<void> openSettings(String id) async {
        await _openBriefingModuleSettings(tester, id);
        expect(layout.dashboardCardOrder, order);
        expect(layout.dashboardCardHidden, hidden);
        expect(layout.dashboardCardCollapsed, collapsed);
      }

      Future<void> closeSettings(String id) async {
        await _closeBriefingModuleSettings(tester, id);
        expectUnchangedLayout();
      }

      const icons = {
        'fleet': Icons.directions_boat_filled_outlined,
        'battle': Icons.remove_red_eye_outlined,
      };
      for (final entry in icons.entries) {
        final id = entry.key;
        await openSettings(id);
        await tester.tap(find.byKey(Key('$id-capsule-logo')));
        await tester.pumpAndSettle();
        expect(layout.moduleShowLogo(id), isFalse);
        await closeSettings(id);
        expect(tabData(id).icon, isNull);
        expect(tabData(id).label, isNotEmpty);

        await openSettings(id);
        await tester.tap(find.byKey(Key('$id-capsule-name')));
        await tester.pumpAndSettle();
        expect(layout.moduleShowName(id), isFalse);
        await closeSettings(id);
        expect(tabData(id).label, isEmpty);
        expect(tabData(id).icon, entry.value);
        final restoredHiddenAppearance = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restoredHiddenAppearance.moduleShowLogo(id), isFalse);
        expect(restoredHiddenAppearance.moduleShowName(id), isFalse);
        restoredHiddenAppearance.dispose();

        // Both appearance flags may be off, but the fallback icon must still
        // open the same settings and allow restoring the name independently.
        final tab = find.byKey(Key('dashboard-tab-$id'));
        expect(
          find.descendant(of: tab, matching: find.byIcon(entry.value)),
          findsOneWidget,
        );
        await openSettings(id);
        await tester.tap(find.byKey(Key('$id-capsule-name')));
        await tester.pumpAndSettle();
        await closeSettings(id);
        expect(tabData(id).label, isNotEmpty);
        expect(tabData(id).icon, isNull);
      }

      final restored = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      for (final id in icons.keys) {
        expect(restored.moduleShowLogo(id), isFalse);
        expect(restored.moduleShowName(id), isTrue);
      }
      expect(restored.dashboardDisplayMode, DashboardDisplayMode.tabs);
      expect(restored.dashboardCardOrder, order);
      expect(restored.dashboardCardHidden, hidden);
      expect(restored.dashboardCardCollapsed, collapsed);
      restored.dispose();
      expectUnchangedLayout();
    },
  );

  testWidgets(
    'home header customizer edits the existing resource configuration',
    (tester) async {
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        uiSize: UiDisplaySize.normal,
      );
      addTearDown(layout.dispose);
      await _tapWorkspaceNavigationItem(tester, 'settings');
      await tester.pumpAndSettle();
      await _tapWorkspaceNavigationItem(tester, 'game');
      await tester.pumpAndSettle();
      await tester.longPress(
        find.byKey(const Key('header-resource-material-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('header-resource-edit-mode')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('header-resource-filter')));
      await tester.pumpAndSettle();
      const id = headerFrameRefreshId;
      final row = find.byKey(
        const Key('header-resource-filter-row-frame-refresh'),
      );
      await tester.ensureVisible(row);
      final before = layout.visibleHeaderResourceIds.contains(id);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(layout.visibleHeaderResourceIds.contains(id), !before);
      await tester.tap(find.byKey(const Key('header-resource-filter-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('header-resource-edit-done')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      await _tapWorkspaceNavigationItem(tester, 'game');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('header-resource-frame-refresh')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [UiDisplaySize.normal, UiDisplaySize.minimal]) {
    testWidgets('native home header opens a live checklist: $size', (
      tester,
    ) async {
      const channel = MethodChannel(
        'app.yahagi.kancollebrowser/native_warning',
      );
      final calls = <MethodCall>[];
      final nativeResult = Completer<String?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'show' ? nativeResult.future : null;
          });
      addTearDown(() {
        if (!nativeResult.isCompleted) nativeResult.complete(null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final rendering = await GameRenderingModeController.load(
        MemoryGameRenderingModeStore(
          GameRenderingMode.nativeActivityExperimental,
        ),
      );
      addTearDown(rendering.dispose);
      var gameDisposals = 0;
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        uiSize: size,
        renderingController: rendering,
        gameSurface: _LifecycleProbe(onDispose: () => gameDisposals++),
      );
      addTearDown(layout.dispose);
      await _tapWorkspaceNavigationItem(tester, 'settings');
      await tester.pumpAndSettle();
      await _tapWorkspaceNavigationItem(tester, 'game');
      await tester.pumpAndSettle();
      await tester.longPress(
        find.byKey(const Key('header-resource-material-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('header-resource-filter')));
      await tester.pumpAndSettle();
      final shows = calls.where((call) => call.method == 'show').toList();
      expect(shows, hasLength(1));
      expect((shows.single.arguments as Map)['kind'], 'headerResources');
      expect(find.byType(Dialog), findsNothing);
      expect(gameDisposals, 0);
      await layout.setUiLocked(true);
      await tester.pumpAndSettle();
      final dismisses = calls
          .where((call) => call.method == 'dismiss')
          .toList();
      expect(dismisses, hasLength(1));
      expect((dismisses.single.arguments as Map)['kind'], 'headerResources');
      nativeResult.complete(null);
      await tester.pumpAndSettle();
      expect(gameDisposals, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in [
    GameRenderingMode.standard,
    GameRenderingMode.compatibility,
    GameRenderingMode.canvasCompatibility,
  ]) {
    testWidgets('home header close protects game input: $mode', (tester) async {
      final rendering = await GameRenderingModeController.load(
        MemoryGameRenderingModeStore(mode),
      );
      addTearDown(rendering.dispose);
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        uiSize: UiDisplaySize.normal,
        renderingController: rendering,
      );
      addTearDown(layout.dispose);
      await _tapWorkspaceNavigationItem(tester, 'settings');
      await tester.pumpAndSettle();
      await _tapWorkspaceNavigationItem(tester, 'game');
      await tester.pumpAndSettle();
      await tester.longPress(
        find.byKey(const Key('header-resource-material-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('header-resource-filter')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('header-resource-edit-mode')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('header-resource-filter-done')));
      await tester.pump();
      expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('native header cancels and detaches a replaced layout owner', (
    tester,
  ) async {
    const channel = MethodChannel('app.yahagi.kancollebrowser/native_warning');
    final calls = <MethodCall>[];
    final nativeResult = Completer<String?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'show' ? nativeResult.future : null;
        });
    addTearDown(() {
      if (!nativeResult.isCompleted) nativeResult.complete(null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final rendering = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(
        GameRenderingMode.nativeActivityExperimental,
      ),
    );
    addTearDown(rendering.dispose);
    final browser = _NoopBrowserPort();
    final previous = await _pumpMinimalShell(
      tester,
      size: const Size(1200, 700),
      uiSize: UiDisplaySize.normal,
      renderingController: rendering,
      browserPort: browser,
    );
    addTearDown(previous.dispose);
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    await _tapWorkspaceNavigationItem(tester, 'game');
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('header-resource-material-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-resource-filter')));
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'show'), hasLength(1));
    final replacement = await _pumpMinimalShell(
      tester,
      size: const Size(1200, 700),
      uiSize: UiDisplaySize.normal,
      renderingController: rendering,
      browserPort: browser,
    );
    addTearDown(replacement.dispose);
    expect(calls.where((call) => call.method == 'dismiss'), hasLength(1));
    final updates = calls.where((call) => call.method == 'update').length;
    final fitCalls = browser.fitGameScreenCalls;
    await previous.toggleHeaderResourceVisible(headerSenkaId);
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'update'), hasLength(updates));
    expect(browser.fitGameScreenCalls, fitCalls);
    nativeResult.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final hd in [false, true]) {
    testWidgets('home panel long press opens the live editor: HD=$hd', (
      tester,
    ) async {
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        uiSize: UiDisplaySize.normal,
      );
      addTearDown(layout.dispose);
      if (hd) await layout.setHdEnabled(true);
      await _tapWorkspaceNavigationItem(tester, 'settings');
      await tester.pumpAndSettle();
      await _tapWorkspaceNavigationItem(tester, 'game');
      await tester.pumpAndSettle();
      await _longPressInformationPanel(tester);
      expect(find.byKey(const Key('dashboard-edit-done')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-target-fleet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dashboard-edit-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dashboard-edit-done')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('home panel long press edits the active HD fallback layout', (
    tester,
  ) async {
    final layout = await _pumpMinimalShell(
      tester,
      size: const Size(600, 900),
      uiSize: UiDisplaySize.normal,
      displayMode: DisplayMode.landscape,
    );
    addTearDown(layout.dispose);
    await layout.setHdEnabled(true);
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    await _tapWorkspaceNavigationItem(tester, 'game');
    await tester.pumpAndSettle();
    await _longPressInformationPanel(tester);
    expect(find.byKey(const Key('dashboard-edit-done')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-edit-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard-edit-done')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final uiSize in UiDisplaySize.values) {
    testWidgets('header game refresh reloads the full page in $uiSize', (
      tester,
    ) async {
      final browser = _NoopBrowserPort();
      final layout = await _pumpMinimalShell(
        tester,
        uiSize: uiSize,
        browserPort: browser,
      );
      addTearDown(layout.dispose);
      const refreshId = 'game-refresh';
      final refresh = find.byKey(const Key('header-resource-game-refresh'));
      expect(refresh, findsNothing);
      await layout.setHeaderResourceOrder([
        refreshId,
        ...layout.headerResourceOrder.where((id) => id != refreshId),
      ]);
      await layout.toggleHeaderResourceVisible(refreshId);
      await tester.pumpAndSettle();

      expect(refresh, findsOneWidget);
      expect(
        find.descendant(of: refresh, matching: find.text('刷新游戏')),
        findsOneWidget,
      );
      final reloads = browser.reloadCalls;
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(browser.reloadCalls, reloads + 1);
      expect(find.byType(AlertDialog), findsNothing);

      await layout.toggleHeaderResourceVisible(refreshId);
      await tester.pumpAndSettle();
      expect(refresh, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(390, 844), Size(800, 500)]) {
    testWidgets('English shell dashboard and navigation fit $size', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final timersWereDisabled = GameStateController.disableTimerForTest;
      GameStateController.disableTimerForTest = true;
      addTearDown(
        () => GameStateController.disableTimerForTest = timersWereDisabled,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final layout = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore(),
        systemLocaleCode: 'en',
      );
      // This test explicitly opts into English despite the Chinese setup above.
      await layout.setLocaleCode('en');
      await layout.setHdEnabled(false);
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final game = GameStateController();
      game
        ..accept(start2Event)
        ..accept(portEvent)
        ..accept(slotItemEvent);
      await game.idle;
      final toolbar = GameToolbarController();
      final capture = GameCaptureController();
      final battle = BattleController(gameState: () => game.state);
      final safety = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      final audio = await GameAudioController.load(_MemoryAudioStore());
      addTearDown(layout.dispose);
      addTearDown(display.dispose);
      addTearDown(game.dispose);
      addTearDown(toolbar.dispose);
      addTearDown(capture.dispose);
      addTearDown(battle.dispose);
      addTearDown(safety.dispose);
      addTearDown(audio.dispose);

      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layout,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: safety,
          displayModeController: display,
          controller: PrototypeStatusController(),
          browserController: GameBrowserController(port: _NoopBrowserPort()),
          captureModeController: await CaptureModeController.load(
            _MemoryModeStore(),
          ),
          gameCaptureController: capture,
          gameStateController: game,
          battleController: battle,
          audioController: audio,
          toolbarController: toolbar,
          gameSurface: const ColoredBox(
            key: Key('english-shell-game-surface'),
            color: Colors.black,
          ),
        ),
      );
      // Populated dashboard cards animate continuously; wait only for the
      // shell's finite entrance transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Fleet summary'), findsOneWidget);
      expect(find.text('编队简报'), findsNothing);
      expect(find.text('夕張'), findsWidgets);
      expect(find.bySemanticsLabel('Game'), findsOneWidget);
      expect(find.bySemanticsLabel('Fleet'), findsOneWidget);
      expect(find.bySemanticsLabel('Expedition'), findsOneWidget);
      expect(find.bySemanticsLabel('Quests'), findsOneWidget);
      expect(
        find.byKey(const Key('english-shell-game-surface')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      if (size == const Size(800, 500)) {
        final gameSurface = find.byKey(const Key('english-shell-game-surface'));
        final originalGameElement = tester.element(gameSurface);
        await display.setDisplayMode(DisplayMode.portrait);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(Divider), findsOneWidget);
        expect(find.byType(VerticalDivider), findsNothing);
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(400, 800);
        for (final mode in [
          DisplayMode.auto,
          DisplayMode.landscape,
          DisplayMode.portrait,
        ]) {
          await display.setDisplayMode(mode);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.byType(VerticalDivider),
            mode == DisplayMode.landscape ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(Divider),
            mode == DisplayMode.landscape ? findsNothing : findsOneWidget,
          );
          expect(find.bySemanticsLabel('Fleet'), findsOneWidget);
          expect(tester.element(gameSurface), same(originalGameElement));
          expect(
            tester.takeException(),
            isNull,
            reason: 'English dashboard at 400×800 with $mode',
          );
        }
        tester.view.physicalSize = size;
        await display.setDisplayMode(DisplayMode.auto);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(tester.element(gameSurface), same(originalGameElement));
        expect(find.text('Fleet summary'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      final fleetNavigation = find.byKey(const Key('workspace-nav-fleet'));
      await tester.ensureVisible(fleetNavigation);
      await tester.pump();
      await tester.tap(fleetNavigation);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(FleetInformationCenter), findsOneWidget);
      expect(find.text('夕張'), findsWidgets);
      expect(game.state.fleets.first.name, '第一舰队');
      expect(game.state.masterShips[101]?.name, '夕張');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'system locale changes update the shell unless a language is chosen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final timersWereDisabled = GameStateController.disableTimerForTest;
      GameStateController.disableTimerForTest = true;
      addTearDown(
        () => GameStateController.disableTimerForTest = timersWereDisabled,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      binding.platformDispatcher.localeTestValue = const Locale('ja');
      binding.platformDispatcher.localesTestValue = const [Locale('ja')];
      final layout = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore().._dashboardCardOrder = ['fleet'],
        systemLocaleCode: 'ja',
      );
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final game = GameStateController();
      final toolbar = GameToolbarController();
      final capture = GameCaptureController();
      final battle = BattleController(gameState: () => game.state);
      final safety = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      final audio = await GameAudioController.load(_MemoryAudioStore());
      addTearDown(layout.dispose);
      addTearDown(display.dispose);
      addTearDown(game.dispose);
      addTearDown(toolbar.dispose);
      addTearDown(capture.dispose);
      addTearDown(battle.dispose);
      addTearDown(safety.dispose);
      addTearDown(audio.dispose);
      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layout,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: safety,
          displayModeController: display,
          controller: PrototypeStatusController(),
          browserController: GameBrowserController(port: _NoopBrowserPort()),
          captureModeController: await CaptureModeController.load(
            _MemoryModeStore(),
          ),
          gameCaptureController: capture,
          gameStateController: game,
          battleController: battle,
          audioController: audio,
          toolbarController: toolbar,
          gameSurface: const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();
      expect(layout.localeCode, isNull);
      expect(layout.effectiveLocaleCode, 'ja');
      expect(find.bySemanticsLabel('艦隊'), findsOneWidget);

      binding.platformDispatcher.localeTestValue = const Locale('en');
      binding.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.pumpAndSettle();
      expect(layout.localeCode, isNull);
      expect(layout.effectiveLocaleCode, 'en');
      expect(find.text('Fleet summary'), findsOneWidget);
      expect(find.bySemanticsLabel('Fleet'), findsOneWidget);

      await layout.setLocaleCode('ko');
      await tester.pumpAndSettle();
      binding.platformDispatcher.localeTestValue = const Locale('ja');
      binding.platformDispatcher.localesTestValue = const [Locale('ja')];
      await tester.pumpAndSettle();
      binding.platformDispatcher.localeTestValue = const Locale('en');
      binding.platformDispatcher.localesTestValue = const [Locale('en')];
      await tester.pumpAndSettle();
      expect(layout.localeCode, 'ko');
      expect(layout.effectiveLocaleCode, 'ko');
      expect(find.bySemanticsLabel('함대'), findsOneWidget);
      expect(find.bySemanticsLabel('Fleet'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('section order controller updates the live shell immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final timersWereDisabled = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    addTearDown(
      () => GameStateController.disableTimerForTest = timersWereDisabled,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final game = GameStateController();
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final battle = BattleController(gameState: () => game.state);
    final layout = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore().._dashboardCardOrder = ['battle'],
    );
    final prediction = await BattlePredictionSettingsController.load(
      MemoryBattlePredictionSettingsStore(),
    );
    addTearDown(game.dispose);
    addTearDown(toolbar.dispose);
    addTearDown(capture.dispose);
    addTearDown(battle.dispose);
    addTearDown(layout.dispose);
    addTearDown(prediction.dispose);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        battlePredictionSettingsController: prediction,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: game,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byType(LiveBattleCard);
    expect(card, findsOneWidget);
    expect(
      tester.widget<LiveBattleCard>(card).sectionOrder,
      orderedEquals(defaultBattlePredictionSectionOrder),
    );

    const below = <BattlePredictionSection>[
      BattlePredictionSection.sortieMap,
      BattlePredictionSection.predictionResult,
      BattlePredictionSection.enemyPreview,
    ];
    await prediction.setSectionOrder(below);
    await tester.pumpAndSettle();
    expect(
      tester.widget<LiveBattleCard>(card).sectionOrder,
      orderedEquals(below),
    );
    await prediction.resetSectionOrder();
    await tester.pumpAndSettle();
    expect(
      tester.widget<LiveBattleCard>(card).sectionOrder,
      orderedEquals(defaultBattlePredictionSectionOrder),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('backup maintenance and recovery preserve the game surface', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final timersWereDisabled = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    addTearDown(
      () => GameStateController.disableTimerForTest = timersWereDisabled,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final maintenance = ValueNotifier<Widget?>(null);
    final game = GameStateController();
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final battle = BattleController(gameState: () => game.state);
    final layout = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    addTearDown(maintenance.dispose);
    addTearDown(game.dispose);
    addTearDown(toolbar.dispose);
    addTearDown(capture.dispose);
    addTearDown(battle.dispose);
    addTearDown(layout.dispose);
    var surfaceDisposals = 0;
    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: game,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: _LifecycleProbe(onDispose: () => surfaceDisposals++),
        backupMaintenanceOverlay: maintenance,
      ),
    );
    await tester.pumpAndSettle();
    final shellState = tester.state(find.byType(YahagiShell));
    final surfaceState = tester.state(find.byType(_LifecycleProbe));

    void expectPreservedGameSurface() {
      expect(tester.state(find.byType(YahagiShell)), same(shellState));
      expect(find.byType(_LifecycleProbe), findsOneWidget);
      expect(tester.state(find.byType(_LifecycleProbe)), same(surfaceState));
      expect(surfaceDisposals, 0);
      expect(
        GameWorkspaceActive.of(tester.element(find.byType(_LifecycleProbe))),
        maintenance.value == null,
      );
      expect(tester.takeException(), isNull);
    }

    expectPreservedGameSurface();
    for (var attempt = 0; attempt < 3; attempt++) {
      maintenance.value = const Scaffold(body: Text('Recovering backup'));
      await tester.pumpAndSettle();
      expectPreservedGameSurface();
      expect(find.text('Recovering backup'), findsOneWidget);
      expect(find.text('Retry backup recovery'), findsNothing);

      maintenance.value = const Scaffold(body: Text('Retry backup recovery'));
      await tester.pumpAndSettle();
      expectPreservedGameSurface();
      expect(find.text('Retry backup recovery'), findsOneWidget);
      expect(find.text('Recovering backup'), findsNothing);

      maintenance.value = null;
      await tester.pumpAndSettle();
      expectPreservedGameSurface();
      expect(find.text('Recovering backup'), findsNothing);
      expect(find.text('Retry backup recovery'), findsNothing);
    }
  });

  testWidgets('quest listener survives navigation and orientation changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final timersWereDisabled = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    addTearDown(
      () => GameStateController.disableTimerForTest = timersWereDisabled,
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final game = GameStateController();
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final battle = BattleController(gameState: () => game.state);
    final layout = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    addTearDown(game.dispose);
    addTearDown(toolbar.dispose);
    addTearDown(capture.dispose);
    addTearDown(battle.dispose);
    addTearDown(layout.dispose);
    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: game,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: const SizedBox.expand(),
      ),
    );
    await tester.pumpAndSettle();
    final listener = tester.state(find.byType(QuestCompletionFeedback));
    game.accept(
      kcsapiEvent('/kcsapi/api_get_member/questlist', {
        'api_count': 1,
        'api_page_count': 1,
        'api_exec_count': 1,
        'api_list': [
          {
            'api_no': 9001,
            'api_title': '切页同时完成',
            'api_detail': '',
            'api_category': 1,
            'api_type': 4,
            'api_state': 3,
            'api_progress_flag': 0,
          },
        ],
      }, capturedAt: DateTime.now().toUtc()),
    );
    await game.idle;
    tester
        .widget<WorkspaceNavigation>(find.byType(WorkspaceNavigation))
        .onSelected(5);
    await tester.pumpAndSettle();
    expect(find.text('任务达成：切页同时完成'), findsOneWidget);
    expect(tester.state(find.byType(QuestCompletionFeedback)), same(listener));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(QuestCompletionFeedback)), same(listener));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'HD is opt-in, keeps a single row and preserves game across toggles and rotation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final toolbar = GameToolbarController();
      final capture = GameCaptureController();
      final state = GameStateController();
      final battle = BattleController(gameState: () => state.state);
      addTearDown(toolbar.dispose);
      addTearDown(capture.dispose);
      addTearDown(state.dispose);
      addTearDown(battle.dispose);
      var deactivations = 0;
      var disposals = 0;
      final layout = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore(),
      );
      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layout,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: await SafetySettingsController.load(
            MemorySafetySettingsStore(),
          ),
          displayModeController: await DisplayModeController.load(
            MemoryDisplayModeStore(),
          ),
          controller: PrototypeStatusController(),
          browserController: GameBrowserController(port: _NoopBrowserPort()),
          captureModeController: await CaptureModeController.load(
            _MemoryModeStore(),
          ),
          gameCaptureController: capture,
          gameStateController: state,
          battleController: battle,
          audioController: await GameAudioController.load(_MemoryAudioStore()),
          toolbarController: toolbar,
          gameSurface: _LifecycleProbe(
            key: const Key('fullscreen-probe'),
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Keep the shell's parent fixed: layout notifications must update the
      // workspace without relying on YahagiApp rebuilding its route.
      final shell = tester.widget<YahagiShell>(find.byType(YahagiShell));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      await tester.pumpWidget(
        MaterialApp(
          theme: app.theme,
          locale: app.locale,
          localizationsDelegates: app.localizationsDelegates,
          supportedLocales: app.supportedLocales,
          home: shell,
        ),
      );
      await tester.pumpAndSettle();
      deactivations = 0;
      disposals = 0;
      final game = find.byKey(const Key('fullscreen-probe'));
      final originalElement = tester.element(game);
      final bottom = find.byKey(const Key('hd-bottom-region'));
      for (final size in [
        const Size(800, 600),
        const Size(1280, 800),
        const Size(1024, 768),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final oldGameRect = tester.getRect(game);
        expect(bottom, findsNothing);
        expect(find.byKey(const Key('yahagi-hd-label')), findsNothing);
        await layout.setHdEnabled(true);
        await tester.pumpAndSettle();
        expect(bottom, findsOneWidget);
        expect(find.byKey(const Key('yahagi-hd-label')), findsOneWidget);
        final wasAuto = layout.autoZoom;
        final previousRatio = layout.gameAreaRatio;
        await layout.setAutoZoom(false);
        for (final ratio in [.5, .65, .75]) {
          await layout.setGameAreaRatio(ratio);
          await tester.pumpAndSettle();
          final workspaceWidth = tester
              .getSize(find.byKey(const Key('game-workspace')))
              .width;
          final panelWidth = tester
              .getSize(find.byKey(const Key('workspace-information-panel')))
              .width;
          expect(panelWidth, closeTo((workspaceWidth - 1) * (1 - ratio), .01));
          expect(tester.getSize(bottom).height, greaterThanOrEqualTo(120));
          expect(tester.element(game), same(originalElement));
          expect(tester.takeException(), isNull);
        }
        await layout.setAutoZoom(true);
        await tester.pumpAndSettle();
        expect(layout.effectiveInformationPanelRatio, .33);
        expect(
          tester
              .getSize(find.byKey(const Key('workspace-information-panel')))
              .width,
          closeTo(
            (tester.getSize(find.byKey(const Key('game-workspace'))).width -
                    1) *
                .33,
            .01,
          ),
        );
        expect(tester.element(game), same(originalElement));
        await layout.setGameAreaRatio(previousRatio);
        await layout.setAutoZoom(wasAuto);
        await tester.pumpAndSettle();

        expect(tester.getSize(game).aspectRatio, closeTo(5 / 3, .001));
        expect(
          tester.getRect(game).bottom,
          closeTo(tester.getRect(bottom).top, .01),
        );
        final left = tester.getRect(find.byKey(const Key('hd-slot-left')));
        final previousGameSize = tester.getSize(game);
        await layout.setHdExtensionPosition('top');
        await tester.pumpAndSettle();
        expect(
          tester.getRect(bottom).bottom,
          closeTo(tester.getRect(game).top, .01),
        );
        expect(tester.getSize(game), previousGameSize);
        expect(tester.element(game), same(originalElement));
        await layout.setHdExtensionPosition('bottom');
        await tester.pumpAndSettle();
        final right = tester.getRect(find.byKey(const Key('hd-slot-right')));
        expect(left.top, right.top);
        expect(left.bottom, right.bottom);
        for (final slotKey in ['hd-slot-left', 'hd-slot-right']) {
          final slot = find.byKey(Key(slotKey));
          final card = find
              .descendant(of: slot, matching: find.byType(AnimatedSize))
              .first;
          expect(
            tester.getRect(card).top,
            closeTo(tester.getRect(slot).top, .01),
          );
          expect(
            tester.getRect(card).bottom,
            closeTo(tester.getRect(slot).bottom, .01),
          );
        }

        expect(left.width, closeTo(right.width, .01));
        expect(tester.getSize(bottom).height, greaterThanOrEqualTo(120));
        expect(tester.element(game), same(originalElement));
        await layout.setHdSplit(false);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('hd-slot-wide')), findsOneWidget);
        expect(find.byKey(const Key('hd-slot-left')), findsNothing);
        for (final module in [
          'fleet',
          'expedition',
          'repair',
          'construction',
          'quests',
        ]) {
          await layout.setHdModule('wide', module);
          await tester.pumpAndSettle();
          expect(find.byKey(Key('hd-module-content-$module')), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await layout.setHdSplit(true);
        await layout.setHdEnabled(false);
        await tester.pumpAndSettle();
        expect(bottom, findsNothing);
        expect(find.byKey(const Key('yahagi-hd-label')), findsNothing);
        expect(tester.getRect(game), oldGameRect);
        expect(tester.element(game), same(originalElement));
      }
      await layout.setHdEnabled(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('yahagi-brand-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-slot-left')), findsNothing);
      expect(tester.element(game), same(originalElement));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-slot-left')), findsOneWidget);
      await layout.setInformationPanelOnLeft(true);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('information-panel'))).right,
        lessThanOrEqualTo(tester.getRect(game).left),
      );
      for (final size in [
        const Size(600, 800),
        const Size(800, 1280),
        const Size(915, 412),
        const Size(640, 320),
        const Size(412, 915),
        const Size(393, 873),
        const Size(540, 1200),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(
          bottom,
          size.width > size.height ? findsOneWidget : findsNothing,
        );
        expect(find.byKey(const Key('yahagi-hd-label')), findsOneWidget);
        expect(
          find.byKey(const Key('hd-portrait-grid')),
          size.height >= size.width ? findsOneWidget : findsNothing,
        );
        expect(tester.element(game), same(originalElement));
        expect(tester.takeException(), isNull);
      }
      await layout.setHdEnabled(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hd-portrait-grid')), findsNothing);
      expect(find.byKey(const Key('yahagi-hd-label')), findsNothing);
      expect(tester.element(game), same(originalElement));
      expect(tester.takeException(), isNull);
      expect(deactivations, 0);
      expect(disposals, 0);
    },
  );

  testWidgets('fullscreen restores the same game and panel; back exits first', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      exitFullscreenSkipConfirmationKey: true,
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final state = GameStateController();
    final battle = BattleController(gameState: () => state.state);
    addTearDown(toolbar.dispose);
    addTearDown(capture.dispose);
    addTearDown(state.dispose);
    addTearDown(battle.dispose);
    var deactivations = 0;
    var disposals = 0;
    final appExitSettings = await AppExitSettingsController.load();
    addTearDown(appExitSettings.dispose);
    await tester.pumpWidget(
      YahagiApp(
        appExitSettingsController: appExitSettings,
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: state,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: _LifecycleProbe(
          key: const Key('fullscreen-probe'),
          onDispose: () => disposals++,
          onDeactivate: () => deactivations++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final game = find.byKey(const Key('fullscreen-probe'));
    final gameElement = tester.element(game);
    final originalRect = tester.getRect(game);
    final panel = find.byKey(const Key('information-panel'));
    final panelElement = tester.element(panel);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: panel, matching: find.byType(Scrollable)).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent / 2);
    await tester.pump();
    final offset = scrollable.position.pixels;

    await tester.tap(find.byKey(const Key('yahagi-brand-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);

    for (final useBack in [false, true]) {
      await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(find.byType(WorkspaceNavigation), findsNothing);
      expect(tester.element(game), same(gameElement));
      expect(tester.getSize(game).width, greaterThan(originalRect.width));
      expect(tester.getSize(game).aspectRatio, closeTo(1200 / 720, 0.001));
      if (useBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(const Key('game-exit-fullscreen')));
      }
      await tester.pumpAndSettle();
      expect(tester.element(panel), same(panelElement));
      expect(tester.getRect(game), originalRect);
      expect(scrollable.position.pixels, offset);
      expect(find.byType(WorkspaceNavigation), findsOneWidget);
      expect(deactivations, 0);
      expect(disposals, 0);
    }

    // Rotate while fullscreen and verify the same surface survives both sizes.
    await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
    await tester.pumpAndSettle();
    for (final size in [const Size(412, 915), const Size(915, 412)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final exit = tester.getRect(
        find.byKey(const Key('game-exit-fullscreen')),
      );
      expect(exit.left, greaterThanOrEqualTo(0));
      expect(exit.top, greaterThanOrEqualTo(0));
      expect(exit.right, lessThanOrEqualTo(size.width));
      expect(exit.bottom, lessThanOrEqualTo(size.height));
      expect(tester.element(game), same(gameElement));
      expect(tester.getSize(game).aspectRatio, closeTo(1200 / 720, 0.001));
      expect(panel, findsNothing);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.element(panel), same(panelElement));
    expect(deactivations, 0);
    expect(disposals, 0);

    // A subsequent Back must ask before leaving the app, even with no stored
    // preference (including upgrades from versions without this setting).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-exit-confirm-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-exit-stay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-exit-confirm-dialog')), findsNothing);
    expect(tester.element(game), same(gameElement));
    expect(deactivations, 0);
    expect(disposals, 0);

    // The production app and its root guard share the same persisted setting.
    final route = ModalRoute.of(tester.element(game))!;
    await appExitSettings.setEnabled(false);
    await tester.pumpAndSettle();
    expect(route.popDisposition, RoutePopDisposition.bubble);
    await appExitSettings.setEnabled(true);
    await tester.pumpAndSettle();
    expect(route.popDisposition, RoutePopDisposition.doNotPop);
  });

  test('startup restores formation memory and wires its display setting', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('SharedPreferencesFormationMemoryStore()'));
    expect(source, contains('formationMemory: formationMemoryController'));
    expect(
      source,
      matches(
        RegExp(
          r'showLastFormationHint:\s*widget\s*'
          r'\.battlePredictionSettingsController\s*'
          r'\?\.lastFormationHintEnabled\s*\?\?\s*true',
        ),
      ),
    );
  });

  test('root workspace scaffold does not resize when the keyboard opens', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source,
      matches(RegExp(r'Scaffold\(\s*resizeToAvoidBottomInset: false,')),
    );
  });

  test('app resume does not schedule a platform-view recovery frame', () {
    final source = File('lib/main.dart').readAsStringSync();
    final lifecycleBody = RegExp(
      r'void didChangeAppLifecycleState\(AppLifecycleState state\) \{(.*?)\n  \}',
      dotAll: true,
    ).firstMatch(source)?.group(1);

    expect(lifecycleBody, isNotNull);
    expect(lifecycleBody, isNot(contains('_scheduleWindowMetricsRecovery')));
  });

  testWidgets('foldable IME geometry does not trigger game surface recovery', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final browserPort = _NoopBrowserPort();
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    addTearDown(gameCaptureController.dispose);
    addTearDown(gameStateController.dispose);
    addTearDown(battleController.dispose);
    addTearDown(toolbarController.dispose);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: browserPort),
        captureModeController: captureModeController,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    await tester.pump();
    final callsBeforeIme = browserPort.fitGameScreenCalls;

    tester.view.physicalSize = const Size(1180, 700);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(seconds: 1));

    expect(browserPort.fitGameScreenCalls, callsBeforeIme);

    tester.view.physicalSize = const Size(1160, 700);
    await tester.pump(const Duration(seconds: 1));

    expect(
      browserPort.fitGameScreenCalls,
      callsBeforeIme,
      reason: 'temporary foldable geometry must be ignored while IME is open',
    );

    tester.view.physicalSize = const Size(1200, 700);
    tester.view.resetViewInsets();
    await tester.pump(const Duration(seconds: 1));

    expect(browserPort.fitGameScreenCalls, callsBeforeIme);

    tester.view.physicalSize = const Size(1000, 700);
    await tester.pump(const Duration(seconds: 1));

    expect(
      browserPort.fitGameScreenCalls,
      callsBeforeIme + 4,
      reason: 'real geometry changes must retain the existing recovery passes',
    );
  });

  testWidgets('auto zoom keeps the information panel compact', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final layout = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    final capture = GameCaptureController();
    final state = GameStateController();
    final battle = BattleController(gameState: () => state.state);
    final toolbar = GameToolbarController();
    addTearDown(layout.dispose);
    addTearDown(capture.dispose);
    addTearDown(state.dispose);
    addTearDown(battle.dispose);
    addTearDown(toolbar.dispose);
    await layout.setAutoZoom(true);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: await CaptureModeController.load(
          _MemoryModeStore(),
        ),
        gameCaptureController: capture,
        gameStateController: state,
        battleController: battle,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbar,
        gameSurface: const SizedBox.expand(),
      ),
    );
    await tester.pumpAndSettle();

    final workspace = find.byKey(const Key('game-workspace'));
    final panel = find.byKey(const Key('workspace-information-panel'));
    expect(
      tester.getSize(panel).width / tester.getSize(workspace).width,
      closeTo(0.33, 0.015),
    );
    expect(
      tester.getRect(find.byType(FleetSummaryCard)).left -
          tester.getRect(panel).left,
      closeTo(11, 0.01),
    );
  });

  testWidgets('shows the game surface, information panel, and capture modes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final controller = PrototypeStatusController(
      captureEnabled: () => captureModeController.captureEnabled,
    );
    final layoutSettingsController = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    final safetySettingsController = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    final displayModeController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    final browserController = GameBrowserController(port: _NoopBrowserPort());
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final toolbarDisplayController = await GameToolbarDisplayController.load(
      _MemoryToolbarDisplayStore(),
    );
    final gameScreenshotController = GameScreenshotController(
      _FakeScreenshotPort(),
    );
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController(
      reducer: _ToolboxStateReducer(),
    );
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    final gameCapturePort = _FakeCapturePort(supported: true);
    await gameCaptureController.attach(gameCapturePort, enabled: true);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layoutSettingsController,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: safetySettingsController,
        displayModeController: displayModeController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        toolbarDisplayController: toolbarDisplayController,
        gameScreenshotController: gameScreenshotController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        gameSurface: const ColoredBox(
          key: Key('fake-game-surface'),
          color: Colors.black,
        ),
      ),
    );

    expect(find.byKey(const Key('fake-game-surface')), findsOneWidget);
    final gameSize = tester.getSize(find.byKey(const Key('fake-game-surface')));
    expect(gameSize.width / gameSize.height, closeTo(1200 / 720, 0.001));
    final panel = find.byKey(const Key('information-panel'));
    expect(panel, findsOneWidget);
    final workspaceWidth = tester
        .getSize(find.byKey(const Key('game-workspace')))
        .width;
    final panelWidth = tester.getSize(panel).width;
    expect(panelWidth / workspaceWidth, closeTo(0.5, 0.015));
    for (final informationRatio in <double>[0.25, 0.37, 0.5]) {
      await layoutSettingsController.setGameAreaRatio(1 - informationRatio);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(panel).width / workspaceWidth,
        closeTo(informationRatio, 0.015),
      );
    }
    expect(find.text('功能面板'), findsNothing);
    expect(find.text('编辑顺序'), findsNothing);
    final collapsedBeforeEditing = List<String>.from(
      layoutSettingsController.dashboardCardCollapsed,
    );
    expect(
      tester.widget<FleetSummaryCard>(find.byType(FleetSummaryCard)).collapsed,
      isFalse,
    );
    expect(find.byType(LandBaseSummaryCard), findsOneWidget);
    await tester.longPress(find.byKey(const ValueKey('fleet')));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.byType(LongPressDraggable<String>), findsWidgets);
    expect(
      find.ancestor(
        of: find.byType(FleetSummaryCard),
        matching: find.byType(LongPressDraggable<String>),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(
      tester.widget<FleetSummaryCard>(find.byType(FleetSummaryCard)).collapsed,
      isTrue,
    );
    final dragRegion = find.byKey(const Key('dashboard-drag-region-fleet'));
    expect(dragRegion, findsOneWidget);
    expect(tester.getSize(dragRegion).width, greaterThan(200));
    expect(
      tester.getSize(find.byType(FleetSummaryCard)).width,
      closeTo(tester.getSize(dragRegion).width - 48, 0.01),
    );
    await tester.tap(find.byKey(const Key('dashboard-edit-done')));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(
      tester.widget<FleetSummaryCard>(find.byType(FleetSummaryCard)).collapsed,
      isFalse,
    );
    expect(
      layoutSettingsController.dashboardCardCollapsed,
      collapsedBeforeEditing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('live-battle-card')),
      200,
      scrollable: find
          .descendant(of: panel, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live-battle-card')), findsOneWidget);
    expect(find.text('未卜先知'), findsOneWidget);
    expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('yahagi-brand-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browser-home')), findsOneWidget);
    expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
    expect(find.byKey(const Key('game-audio-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('browser-screenshot')));
    await tester.pumpAndSettle();
    expect(find.textContaining('yahagi-test.png'), findsOneWidget);
    expect(find.byKey(topNoticeKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(topNoticeKey),
        matching: find.byIcon(Icons.check_circle_outline_rounded),
      ),
      findsOneWidget,
    );
    TopNotice.hide(tester.element(find.byType(Scaffold).first));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('yahagi-brand-button')));
    await tester.pumpAndSettle();
    final gameSurfaceElement = tester.element(
      find.byKey(const Key('fake-game-surface')),
    );
    expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
    expect(
      tester.element(find.byKey(const Key('fake-game-surface'))),
      same(gameSurfaceElement),
    );

    tester.view.physicalSize = const Size(900, 900);
    tester.binding.handleMetricsChanged();
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.element(find.byKey(const Key('fake-game-surface'))),
      same(gameSurfaceElement),
    );
    final unfoldedGameRect = tester.getRect(
      find.byKey(const Key('fake-game-surface')),
    );
    expect(
      unfoldedGameRect.width / unfoldedGameRect.height,
      closeTo(1200 / 720, 0.001),
    );
    expect(
      tester.getTopLeft(panel).dy,
      greaterThanOrEqualTo(unfoldedGameRect.bottom),
    );

    tester.view.physicalSize = const Size(1200, 700);
    tester.binding.handleMetricsChanged();
    await tester.pump(const Duration(seconds: 1));
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();

    final settingsLabelX = tester
        .getTopLeft(find.byKey(const Key('settings-language-label')))
        .dx;
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-auto-zoom-label'))).dx,
      closeTo(settingsLabelX, 0.1),
    );
    expect(find.text('应用推荐显示比例（游戏与菜单比例 67:33）'), findsOneWidget);
    expect(find.text('游戏声音'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('游戏声音'), findsOneWidget);
    expect(find.text('后台播放声音'), findsOneWidget);
    expect(find.text('游戏模式（默认）'), findsOneWidget);
    expect(find.text('纯浏览模式'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('大破提醒'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('大破提醒')).dy,
      lessThan(tester.getTopLeft(find.text('舰娘状态反馈')).dy),
    );
    await tester.tap(find.byKey(const Key('settings-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('启用系统通知'), findsOneWidget);
    expect(
      find.byKey(const Key('settings-top-notice-enabled')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('settings-tab-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings-logout-label')));
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-logout-label'))).dx,
      closeTo(settingsLabelX, 0.1),
    );
    await tester.tap(find.byKey(const Key('settings-tab-5')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-logout-label')), findsNothing);
    expect(find.text('纯浏览模式'), findsNothing);
    await tester.tap(find.byKey(const Key('settings-tab-6')));
    await tester.pumpAndSettle();
    expect(find.text('关于 ヤハギ', skipOffstage: false), findsWidgets);
    expect(find.text('安全边界', skipOffstage: false), findsNothing);
    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();
    expect(find.text('资源'), findsNothing);
    for (final key in <String>[
      'workspace-nav-fleet',
      'workspace-nav-expedition',
      'workspace-nav-repair',
      'workspace-nav-construction',
      'workspace-nav-quests',
      'workspace-nav-senka',
      'workspace-nav-battle-records',
      'workspace-nav-tools',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-tools')),
        matching: find.byIcon(Icons.widgets_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-tools')),
        matching: find.byIcon(Icons.handyman_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-construction')),
        matching: find.byIcon(Icons.handyman_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('workspace-nav-tools')));
    await tester.pumpAndSettle();
    expect(find.byType(ToolboxPage), findsOneWidget);
    expect(find.text('等待母港数据'), findsOneWidget);
    gameStateController.accept(
      CapturedApiEvent(
        path: '/toolbox-state-test',
        responseBody: '{}',
        source: CaptureSource.manual,
        capturedAt: DateTime.utc(2026, 8, 31),
      ),
    );
    await gameStateController.idle;
    await tester.pumpAndSettle();
    expect(find.textContaining('"hqlv":77'), findsOneWidget);
    expect(find.byKey(const Key('toolbox-mode-tabs')), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-land-bases-only')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('toolbox-tab-other')));
    await tester.pumpAndSettle();
    expect(find.text('其他功能正在开发中'), findsOneWidget);
    expect(find.textContaining('"hqlv":77'), findsNothing);
    await tester.tap(find.byKey(const Key('toolbox-tab-export')));
    await tester.pumpAndSettle();
    expect(find.text('其他功能正在开发中'), findsNothing);
    expect(find.textContaining('"hqlv":77'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('event-land-bases-only')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('workspace-nav-construction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('construction-mode-development')));
    await tester.pump();
    expect(find.byType(EquipmentDevelopmentPage), findsOneWidget);
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('switches to browser-only mode and shows capture is disabled', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final controller = PrototypeStatusController(
      captureEnabled: () => captureModeController.captureEnabled,
    );
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: controller,
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-tab-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('纯浏览模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('纯浏览模式'));
    await tester.pumpAndSettle();

    expect(captureModeController.mode, CaptureMode.browserOnly);
    expect(
      find.text('纯浏览模式将在重新载入页面后停止数据捕获。', skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('settings-tab-6')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('settings-diagnostics-entry')),
    );
    await tester.tap(find.byKey(const Key('settings-diagnostics-entry')));
    await tester.pumpAndSettle();
    expect(find.text('纯浏览模式 · 数据捕获已关闭', skipOffstage: false), findsOneWidget);
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    toolbarController.dispose();
  });

  testWidgets('shows capture unsupported without removing the game surface', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameCapturePort = _FakeCapturePort(supported: false);
    await gameCaptureController.attach(gameCapturePort, enabled: true);
    final toolbarController = GameToolbarController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: const ColoredBox(
          key: Key('unsupported-game-surface'),
          color: Colors.black,
        ),
      ),
    );

    expect(find.byKey(const Key('unsupported-game-surface')), findsOneWidget);
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-6')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('settings-diagnostics-entry')),
    );
    await tester.tap(find.byKey(const Key('settings-diagnostics-entry')));
    await tester.pumpAndSettle();
    expect(
      find.text('当前 WebView 不支持跨框架捕获', skipOffstage: false),
      findsOneWidget,
    );
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('shows successful port verification for api_result one', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameCapturePort = _FakeCapturePort(supported: true);
    await gameCaptureController.attach(gameCapturePort, enabled: true);
    final toolbarController = GameToolbarController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    gameCapturePort.emit(
      CapturedApiEvent(
        path: '/kcsapi/api_port/port',
        responseBody: '{"api_result":1}',
        source: CaptureSource.xhr,
        capturedAt: DateTime.utc(2026, 7, 30),
      ),
    );
    await tester.pump();

    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-6')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('settings-diagnostics-entry')),
    );
    await tester.tap(find.byKey(const Key('settings-diagnostics-entry')));
    await tester.pumpAndSettle();
    expect(find.text('母港接口验证通过', skipOffstage: false), findsOneWidget);
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('moves the workspace menu without disposing the game surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final layoutSettingsController = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameStateController = GameStateController();
    final senkaStore = _MemorySenkaStore(
      SenkaState.forMonth('2026-08').copyWith(
        rankingHistory: {
          'player': [
            SenkaRankingSnapshot(
              rank: 370,
              senka: 1120,
              capturedAt: DateTime.utc(2026, 8, 11),
              localSenkaAtCapture: 0,
            ),
          ],
        },
      ),
    );
    final senkaController = SenkaController(
      store: senkaStore,
      now: () => DateTime.utc(2026, 8, 11),
    );
    await senkaController.initialize();
    final toolbarController = GameToolbarController();
    var disposeCount = 0;
    var deactivateCount = 0;

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layoutSettingsController,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: GameCaptureController(),
        gameStateController: gameStateController,
        senkaController: senkaController,
        battleController: BattleController(
          gameState: () => gameStateController.state,
        ),
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: _LifecycleProbe(
          key: const Key('side-switch-game-surface'),
          onDispose: () => disposeCount++,
          onDeactivate: () => deactivateCount++,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-senka')),
        matching: find.byIcon(Icons.emoji_events_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('战果：1120（#370）'), findsOneWidget);
    senkaStore.state = SenkaState.forMonth('2026-08').copyWith(
      rankingHistory: {
        'player': [
          SenkaRankingSnapshot(
            rank: 365,
            senka: 1138,
            capturedAt: DateTime.utc(2026, 8, 11, 1),
            localSenkaAtCapture: 0,
          ),
        ],
      },
    );
    await senkaController.initialize();
    await tester.pump();
    expect(find.text('战果：1138（#365）'), findsOneWidget);
    final menuButton = find.byKey(const Key('workspace-nav-game'));
    final gameSurface = find.byKey(const Key('side-switch-game-surface'));
    final originalGameSurfaceElement = tester.element(gameSurface);
    expect(
      tester.getCenter(menuButton).dx,
      lessThan(tester.getCenter(gameSurface).dx),
    );

    for (final size in <Size>[
      const Size(900, 700),
      const Size(1280, 720),
      const Size(700, 900),
      const Size(1400, 720),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(disposeCount, 0);
      expect(deactivateCount, 0);
      expect(tester.element(gameSurface), same(originalGameSurfaceElement));
      final renderedGameSize = tester.getSize(gameSurface);
      expect(
        renderedGameSize.width / renderedGameSize.height,
        closeTo(1200 / 720, 0.001),
      );
    }

    final informationPanel = find.byKey(
      const Key('workspace-information-panel'),
    );
    for (final menuOnRight in <bool>[false, true]) {
      await layoutSettingsController.setWorkspaceMenuOnRight(menuOnRight);
      for (final onLeft in <bool>[true, false]) {
        await layoutSettingsController.setInformationPanelOnLeft(onLeft);
        await tester.pumpAndSettle();
        final panelRect = tester.getRect(informationPanel);
        final gameRect = tester.getRect(gameSurface);
        if (onLeft) {
          expect(panelRect.right, lessThanOrEqualTo(gameRect.left));
        } else {
          expect(panelRect.left, greaterThanOrEqualTo(gameRect.right));
        }
        expect(disposeCount, 0);
        expect(deactivateCount, 0);
        expect(tester.element(gameSurface), same(originalGameSurfaceElement));
        expect(tester.takeException(), isNull);
      }
    }
    await layoutSettingsController.setInformationPanelOnLeft(true);
    tester.view.physicalSize = const Size(700, 900);
    await tester.pumpAndSettle();
    final verticalPanelRect = tester.getRect(informationPanel);
    final verticalGameRect = tester.getRect(gameSurface);
    final verticalNavigationRect = tester.getRect(
      find.byType(WorkspaceNavigation),
    );
    expect(verticalGameRect.width, closeTo(700, 0.01));
    expect(
      verticalPanelRect.top,
      greaterThanOrEqualTo(verticalGameRect.bottom),
    );
    expect(verticalNavigationRect.top, verticalPanelRect.top);
    expect(verticalNavigationRect.bottom, verticalPanelRect.bottom);
    expect(
      verticalNavigationRect.left,
      greaterThanOrEqualTo(verticalPanelRect.right),
    );
    tester.view.physicalSize = const Size(1400, 720);
    await layoutSettingsController.setInformationPanelOnLeft(false);
    await tester.pumpAndSettle();

    await layoutSettingsController.setWorkspaceMenuOnRight(true);
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(menuButton).dx,
      greaterThan(tester.getCenter(gameSurface).dx),
    );
    expect(disposeCount, 0);

    for (final hd in [false, true]) {
      await layoutSettingsController.setHdEnabled(hd);
      for (final size in [const Size(800, 1280), const Size(1280, 800)]) {
        tester.view.physicalSize = size;
        for (final position in ['top', 'bottom', 'left', 'right']) {
          await layoutSettingsController.setWorkspaceMenuPosition(position);
          await tester.pumpAndSettle();
          final nav = tester.getRect(find.byType(WorkspaceNavigation));
          final surface = tester.getRect(gameSurface);
          if (position == 'top' || position == 'bottom') {
            expect(
              nav.height,
              workspaceNavigationExtent(
                layoutSettingsController.workspaceMenuSize,
              ),
            );
            final count = layoutSettingsController.workspaceMenuOrder.length;
            if (nav.width >= count * 50 + 20) {
              final first = tester.getRect(
                find.byKey(
                  ValueKey(
                    'workspace-nav-item-${layoutSettingsController.workspaceMenuOrder.first}',
                  ),
                ),
              );
              final last = tester.getRect(
                find.byKey(
                  ValueKey(
                    'workspace-nav-item-${layoutSettingsController.workspaceMenuOrder.last}',
                  ),
                ),
              );
              expect(
                first.left - nav.left,
                closeTo(nav.right - last.right, .01),
              );
            }

            expect(nav.top, greaterThanOrEqualTo(surface.bottom - .01));
            expect(
              tester
                  .widget<ReorderableListView>(
                    find.byKey(const Key('workspace-navigation-list')),
                  )
                  .scrollDirection,
              Axis.horizontal,
            );
            if (position == 'top' && size.height > size.width) {
              expect(
                nav.bottom,
                lessThanOrEqualTo(tester.getRect(informationPanel).top),
              );
            }
          }
          expect(tester.element(gameSurface), same(originalGameSurfaceElement));
          expect(disposeCount, 0);
          expect(deactivateCount, 0);
          expect(tester.takeException(), isNull);
        }
      }
    }
    await layoutSettingsController.setHdEnabled(false);
    await layoutSettingsController.setWorkspaceMenuOnRight(true);
    tester.view.physicalSize = const Size(1400, 720);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-senka-summary')));
    await tester.pumpAndSettle();

    expect(find.byType(SenkaPage), findsOneWidget);
    final senkaButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('workspace-nav-senka')),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      senkaButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      const Color(0xff2b2c22),
    );

    await tester.tap(find.byKey(const Key('senka-recent-records')));
    await tester.pumpAndSettle();

    expect(find.byType(LogbookPage), findsOneWidget);
    expect(find.byKey(const Key('logbook-table-sortie')), findsOneWidget);

    senkaController.dispose();
    toolbarController.dispose();
  });

  testWidgets('switches to fleet center without disposing the game surface', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController(
      reducer: _RepairNavigationReducer(),
    );
    gameStateController.accept(
      CapturedApiEvent(
        path: '/repair-navigation-test',
        responseBody: '{}',
        source: CaptureSource.manual,
        capturedAt: DateTime.utc(2026, 8, 7),
      ),
    );
    await gameStateController.idle;
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    final toolbarController = GameToolbarController();
    var disposeCount = 0;

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: _LifecycleProbe(
          key: const Key('persistent-game-surface'),
          onDispose: () => disposeCount++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
    await tester.pumpAndSettle();

    expect(find.text('舰队'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-game-surface'), skipOffstage: false),
      findsOneWidget,
    );
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('workspace-nav-expedition')));
    await tester.pumpAndSettle();
    expect(find.text('远征'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-repair')));
    await tester.pumpAndSettle();
    expect(find.text('入渠修理'), findsOneWidget);
    expect(find.text('泊地修理'), findsOneWidget);

    await tester.tap(find.byKey(const Key('repair-mode-anchorage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();
    final repairCard = find.byType(RepairSummaryCard);
    await tester.scrollUntilVisible(
      repairCard,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('information-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    tester
        .widget<RepairSummaryCard>(repairCard)
        .onOpenRepair(
          const RepairDestination(mode: RepairCenterMode.anchorage, fleetId: 2),
        );
    await tester.pumpAndSettle();
    var repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.repairMode, RepairCenterMode.anchorage);
    expect(repairCenter.initialFleetId, 2);

    tester
        .widget<FleetSwitcherBar>(find.byType(FleetSwitcherBar))
        .onFleetSelected!(1);
    await tester.pumpAndSettle();
    repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.initialFleetId, 1);

    await tester.tap(find.byKey(const Key('workspace-nav-construction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-nav-repair')));
    await tester.pumpAndSettle();
    repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.repairMode, RepairCenterMode.anchorage);
    expect(repairCenter.initialFleetId, 1);

    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();
    tester
        .widget<RepairSummaryCard>(repairCard)
        .onOpenRepair(const RepairDestination(mode: RepairCenterMode.dock));
    await tester.pumpAndSettle();
    repairCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(repairCenter.repairMode, RepairCenterMode.dock);
    expect(repairCenter.initialFleetId, isNull);
    final dockTab = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const Key('repair-mode-dock')),
        matching: find.byType(Material),
      ),
    );
    expect(dockTab.color, const Color(0xff5b4829));

    await tester.tap(find.byKey(const Key('workspace-nav-construction')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('workspace-title-construction')))
          .data,
      '建造',
    );

    await tester.tap(find.byKey(const Key('workspace-nav-quests')));
    await tester.pumpAndSettle();
    expect(find.text('任务'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-battle-records')));
    await tester.pumpAndSettle();

    expect(find.text('出击'), findsOneWidget);
    expect(find.text('远征'), findsOneWidget);
    expect(find.text('建造'), findsWidgets);
    expect(find.text('开发'), findsOneWidget);
    expect(find.text('除籍'), findsOneWidget);
    expect(find.text('资源'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-game-surface'), skipOffstage: false),
      findsOneWidget,
    );
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('information-panel')), findsOneWidget);
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('header-resource-anchorage-timer')));
    await tester.pumpAndSettle();

    final anchorageCenter = tester.widget<FleetInformationCenter>(
      find.byType(FleetInformationCenter),
    );
    expect(anchorageCenter.repairMode, RepairCenterMode.anchorage);
    expect(anchorageCenter.initialFleetId, 1);

    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    toolbarController.dispose();
  });

  testWidgets(
    'brand virtual button is only interactive on game workspace and collapses on navigation',
    (tester) async {
      final captureModeController = await CaptureModeController.load(
        _MemoryModeStore(),
      );
      final controller = PrototypeStatusController(
        captureEnabled: () => captureModeController.captureEnabled,
      );
      final layoutSettingsController = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore(),
      );
      final safetySettingsController = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      final displayModeController = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final browserController = GameBrowserController(port: _NoopBrowserPort());
      final audioController = await GameAudioController.load(
        _MemoryAudioStore(),
      );
      final toolbarController = GameToolbarController();
      final toolbarDisplayController = await GameToolbarDisplayController.load(
        _MemoryToolbarDisplayStore(),
      );
      final gameCaptureController = GameCaptureController();
      final gameStateController = GameStateController();
      final battleController = BattleController(
        gameState: () => gameStateController.state,
      );

      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layoutSettingsController,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: safetySettingsController,
          displayModeController: displayModeController,
          controller: controller,
          browserController: browserController,
          captureModeController: captureModeController,
          audioController: audioController,
          toolbarController: toolbarController,
          toolbarDisplayController: toolbarDisplayController,
          gameCaptureController: gameCaptureController,
          gameStateController: gameStateController,
          battleController: battleController,
          gameSurface: const ColoredBox(
            key: Key('fake-game-surface'),
            color: Colors.black,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On Game workspace (index 0)
      final brandButtonFinder = find.byKey(const Key('yahagi-brand-button'));
      expect(brandButtonFinder, findsOneWidget);
      final brandInkWell0 = tester.widget<InkWell>(brandButtonFinder);
      expect(brandInkWell0.onTap, isNotNull);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      // Tap to expand toolbar
      await tester.tap(brandButtonFinder);
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isTrue);
      expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_left),
        ),
        findsOneWidget,
      );

      // Tap again to collapse the toolbar manually.
      await tester.tap(brandButtonFinder);
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isFalse);
      expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      // Expand again before verifying navigation still collapses it.
      await tester.tap(brandButtonFinder);
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isTrue);

      // Switch to fleet workspace (index 1)
      await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
      await tester.pumpAndSettle();
      expect(toolbarController.isVisible, isFalse);
      expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);

      // On non-game workspace, brand button is disabled and chevron is hidden
      final brandInkWell1 = tester.widget<InkWell>(brandButtonFinder);
      expect(brandInkWell1.onTap, isNull);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_left),
        ),
        findsNothing,
      );

      // Switch back to game workspace (index 0)
      await tester.tap(find.byKey(const Key('workspace-nav-game')));
      await tester.pumpAndSettle();
      final brandInkWellGame = tester.widget<InkWell>(brandButtonFinder);
      expect(brandInkWellGame.onTap, isNotNull);
      expect(
        find.descendant(
          of: brandButtonFinder,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      gameStateController.dispose();
      toolbarController.dispose();
    },
  );

  testWidgets(
    'split-screen: forced portrait and landscape switch layout without window resizing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      // Start with a wide window geometry (split-screen: 800 x 500)
      tester.view.physicalSize = const Size(800, 500);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final displayStore = MemoryDisplayModeStore(DisplayMode.auto);
      final displayController = await DisplayModeController.load(displayStore);
      final browserPort = _NoopBrowserPort();
      final browserController = GameBrowserController(port: browserPort);
      final layout = await LayoutSettingsController.load(
        _MemoryLayoutSettingsStore(),
      );
      // Disable HD so that landscape layout uses the standard vertical divider
      await layout.setHdEnabled(false);

      final toolbar = GameToolbarController();
      final capture = GameCaptureController();
      final state = GameStateController();
      final battle = BattleController(gameState: () => state.state);
      addTearDown(toolbar.dispose);
      addTearDown(capture.dispose);
      addTearDown(state.dispose);
      addTearDown(battle.dispose);
      addTearDown(displayController.dispose);
      addTearDown(layout.dispose);

      var deactivations = 0;
      var disposals = 0;
      const probeKey = Key('split-screen-orientation-probe');

      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layout,
          networkSettingsController: NetworkSettingsController(
            store: _MemoryNetworkSettingsStore(),
          ),
          gadgetBypassController: GadgetBypassController(
            store: _MemoryGadgetBypassStore(),
            port: _FakeGadgetBypassPort(),
          ),
          safetySettingsController: await SafetySettingsController.load(
            MemorySafetySettingsStore(),
          ),
          displayModeController: displayController,
          controller: PrototypeStatusController(),
          browserController: browserController,
          captureModeController: await CaptureModeController.load(
            _MemoryModeStore(),
          ),
          gameCaptureController: capture,
          gameStateController: state,
          battleController: battle,
          audioController: await GameAudioController.load(_MemoryAudioStore()),
          toolbarController: toolbar,
          gameSurface: _LifecycleProbe(
            key: probeKey,
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final originalElement = tester.element(find.byKey(probeKey));
      deactivations = 0;
      disposals = 0;

      // 1. Wide split-screen window with auto mode -> Landscape layout (VerticalDivider)
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(deactivations, 0);
      expect(disposals, 0);

      final initialFitCalls = browserPort.fitGameScreenCalls;

      // 2. Force Portrait in split-screen (window size stays 800x500!)
      await displayController.setDisplayMode(DisplayMode.portrait);
      await tester.pumpAndSettle();

      // Layout switches to portrait/vertical layout (Divider)
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(browserPort.fitGameScreenCalls, greaterThan(initialFitCalls));
      expect(
        deactivations,
        0,
        reason: 'PlatformView must not deactivate on portrait switch',
      );
      expect(
        disposals,
        0,
        reason: 'PlatformView must not dispose on portrait switch',
      );
      expect(tester.element(find.byKey(probeKey)), same(originalElement));

      for (final position in ['top', 'bottom']) {
        await layout.setWorkspaceMenuPosition(position);
        await tester.pumpAndSettle();

        final gameRect = tester.getRect(find.byKey(probeKey));
        final navigationRect = tester.getRect(find.byType(WorkspaceNavigation));
        expect(
          gameRect.bottom,
          lessThanOrEqualTo(navigationRect.top + 0.01),
          reason:
              '$position menu must reduce the game viewport instead of clipping its bottom edge',
        );
        expect(gameRect.width / gameRect.height, closeTo(1200 / 720, 0.001));
        expect(tester.element(find.byKey(probeKey)), same(originalElement));
        expect(deactivations, 0);
        expect(disposals, 0);
      }
      await layout.setWorkspaceMenuPosition('left');
      await tester.pumpAndSettle();

      // 3. Tall split-screen window (400 x 800)
      tester.view.physicalSize = const Size(400, 800);
      await displayController.setDisplayMode(DisplayMode.auto);
      await tester.pumpAndSettle();

      // Auto on tall window -> Portrait layout (Divider)
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(deactivations, 0);
      expect(disposals, 0);
      expect(tester.element(find.byKey(probeKey)), same(originalElement));

      final fitCallsBeforeLandscape = browserPort.fitGameScreenCalls;

      // 4. Force Landscape in split-screen (window size stays 400x800!)
      await displayController.setDisplayMode(DisplayMode.landscape);
      await tester.pumpAndSettle();

      // Layout switches to landscape layout (VerticalDivider)
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
      expect(
        browserPort.fitGameScreenCalls,
        greaterThan(fitCallsBeforeLandscape),
      );
      expect(
        deactivations,
        0,
        reason: 'PlatformView must not deactivate on landscape switch',
      );
      expect(
        disposals,
        0,
        reason: 'PlatformView must not dispose on landscape switch',
      );
      expect(tester.element(find.byKey(probeKey)), same(originalElement));

      // 5. Continuous rapid switching in split-screen (portrait -> auto -> landscape -> auto)
      for (final mode in [
        DisplayMode.portrait,
        DisplayMode.auto,
        DisplayMode.landscape,
        DisplayMode.portrait,
        DisplayMode.auto,
      ]) {
        final previousCalls = browserPort.fitGameScreenCalls;
        await displayController.setDisplayMode(mode);
        await tester.pumpAndSettle();

        expect(
          deactivations,
          0,
          reason:
              'Continuous switching to $mode must never deactivate PlatformView',
        );
        expect(
          disposals,
          0,
          reason:
              'Continuous switching to $mode must never dispose PlatformView',
        );
        expect(tester.element(find.byKey(probeKey)), same(originalElement));
        expect(browserPort.fitGameScreenCalls, greaterThan(previousCalls));
      }
    },
  );

  testWidgets('minimal chrome keeps compact navigation and settings geometry', (
    tester,
  ) async {
    final layout = await _pumpMinimalShell(
      tester,
      size: const Size(600, 900),
      uiSize: UiDisplaySize.compact,
    );
    await _tapWorkspaceNavigationItem(tester, 'settings');
    await tester.pumpAndSettle();
    Map<String, Size> geometry() {
      final brand = find.byKey(const Key('yahagi-brand-button'));
      final gameNavigation = find.byKey(const Key('workspace-nav-game'));
      return {
        'brand': tester.getRect(brand).size,
        'brand icon': tester
            .getRect(find.descendant(of: brand, matching: find.byType(Image)))
            .size,
        'brand text': tester
            .getRect(find.descendant(of: brand, matching: find.text('ヤハギ')))
            .size,
        'settings title': tester
            .getRect(find.byKey(const Key('workspace-title-settings')))
            .size,
        'settings tabs': tester.getRect(find.byType(SettingsSegmented)).size,
        for (var index = 0; index < 7; index++)
          'settings tab $index': tester
              .getRect(find.byKey(Key('settings-tab-$index')))
              .size,
        'navigation button': tester
            .getRect(
              find.descendant(
                of: gameNavigation,
                matching: find.byType(IconButton),
              ),
            )
            .size,
        'navigation icon': tester
            .getRect(
              find.descendant(of: gameNavigation, matching: find.byType(Icon)),
            )
            .size,
      };
    }

    for (final position in ['left', 'bottom']) {
      await layout.setUiDisplaySize(UiDisplaySize.compact);
      await layout.setWorkspaceMenuPosition(position);
      await tester.pumpAndSettle();
      final compactNavigation = tester
          .getRect(find.byType(WorkspaceNavigation))
          .size;
      final compactGeometry = geometry();
      final compactHeaderHeight = _headerHeight(tester);
      await layout.setUiDisplaySize(UiDisplaySize.minimal);
      await tester.pumpAndSettle();
      final minimalNavigation = tester
          .getRect(find.byType(WorkspaceNavigation))
          .size;
      expect(
        position == 'left' ? minimalNavigation.width : minimalNavigation.height,
        closeTo(
          position == 'left'
              ? compactNavigation.width
              : compactNavigation.height,
          .001,
        ),
        reason: '$position navigation extent',
      );
      expect(
        geometry(),
        compactGeometry,
        reason: '$position actual control sizes',
      );
      expect(_headerHeight(tester), closeTo(compactHeaderHeight, .001));
      await layout.setUiDisplaySize(UiDisplaySize.compact);
      await tester.pumpAndSettle();
      expect(geometry(), compactGeometry);
      expect(_headerHeight(tester), compactHeaderHeight);
      expect(tester.takeException(), isNull);
    }
  });

  group('settings body keeps original control sizes', () {
    for (final screen in const [Size(600, 840), Size(840, 600)]) {
      testWidgets('across display sizes and HD at $screen', (tester) async {
        var disposals = 0;
        var deactivations = 0;
        const gameKey = Key('settings-body-size-game');
        final layout = await _pumpMinimalShell(
          tester,
          size: screen,
          uiSize: UiDisplaySize.normal,
          gameSurface: _LifecycleProbe(
            key: gameKey,
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        );
        final game = find.byKey(gameKey, skipOffstage: false);
        final originalGame = tester.element(game);
        final language = find.byKey(const Key('settings-language-label'));
        final autoZoom = find.byKey(const Key('settings-auto-zoom-label'));
        final hdSwitch = find.byKey(const Key('settings-hd-mode'));
        final themeDropdown = find.byKey(
          const Key('settings-app-theme-dropdown'),
        );

        void navigate(int index) => tester
            .widget<WorkspaceNavigation>(find.byType(WorkspaceNavigation))
            .onSelected(index);

        Map<String, double> bodyGeometry() => {
          'language label height': tester.getRect(language).height,
          'auto zoom label height': tester.getRect(autoZoom).height,
          'HD switch width': tester.getRect(hdSwitch).width,
          'HD switch height': tester.getRect(hdSwitch).height,
          'theme dropdown height': tester.getRect(themeDropdown).height,
          'language text visual scale':
              tester.getRect(language).height / tester.getSize(language).height,
          'auto zoom text visual scale':
              tester.getRect(autoZoom).height / tester.getSize(autoZoom).height,
        };

        for (final hd in [false, true]) {
          await layout.setHdEnabled(hd);
          navigate(8);
          await tester.pumpAndSettle();
          Map<String, double>? normalGeometry;
          for (final size in [
            UiDisplaySize.normal,
            UiDisplaySize.compact,
            UiDisplaySize.minimal,
            UiDisplaySize.compact,
            UiDisplaySize.minimal,
          ]) {
            await layout.setUiDisplaySize(size);
            await tester.pumpAndSettle();
            final actual = bodyGeometry();
            normalGeometry ??= actual;
            for (final entry in normalGeometry.entries) {
              expect(
                actual[entry.key],
                closeTo(entry.value, .001),
                reason: '$screen HD=$hd $size ${entry.key}',
              );
            }
            for (final control in [
              language,
              autoZoom,
              hdSwitch,
              themeDropdown,
            ]) {
              expect(
                UiScale.of(tester.element(control)),
                1,
                reason:
                    '$screen HD=$hd $size settings control must retain its original scale',
              );
            }
            expect(tester.element(game), same(originalGame));
            expect(disposals, 0);
            expect(deactivations, 0);
          }
          navigate(0);
          await tester.pumpAndSettle();
          expect(tester.element(game), same(originalGame));
          expect(
            find.ancestor(of: game, matching: find.byType(UiScale)),
            findsNothing,
          );
          expect(disposals, 0);
          expect(deactivations, 0);
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('readable minimal layout matrix', () {
    for (final scenario in const [
      (size: Size(360, 800), hd: false, locale: 'zh', textScale: 1.0),
      (size: Size(800, 360), hd: false, locale: 'zh', textScale: 1.3),
      (size: Size(360, 800), hd: true, locale: 'en', textScale: 1.3),
      (size: Size(800, 360), hd: true, locale: 'en', textScale: 1.0),
      (size: Size(600, 840), hd: false, locale: 'en', textScale: 1.3),
      (size: Size(840, 600), hd: false, locale: 'en', textScale: 1.0),
      (size: Size(600, 840), hd: true, locale: 'zh', textScale: 1.0),
      (size: Size(840, 600), hd: true, locale: 'zh', textScale: 1.3),
    ]) {
      testWidgets(
        '${scenario.size} HD=${scenario.hd} ${scenario.locale} text=${scenario.textScale}',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue =
              scenario.textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final reducer = _LayoutAuditStateReducer(scenario.locale);
          final state = GameStateController(reducer: reducer);
          await state.initialize();
          var disposals = 0;
          const gameKey = Key('layout-matrix-game');
          final layout = await _pumpMinimalShell(
            tester,
            size: scenario.size,
            localeCode: scenario.locale,
            uiSize: UiDisplaySize.compact,
            gameState: state,
            gameSurface: _LifecycleProbe(
              key: gameKey,
              onDispose: () => disposals++,
            ),
          );
          await layout.setHdEnabled(scenario.hd);
          await tester.pumpAndSettle();
          final game = find.byKey(gameKey);
          final originalGame = tester.element(game);

          Map<String, double> chromeGeometry() {
            final brandIcon = find.descendant(
              of: find.byKey(const Key('yahagi-brand-button')),
              matching: find.byType(Image),
            );
            final navigation = tester.getRect(find.byType(WorkspaceNavigation));
            return {
              'header height': _headerHeight(tester),
              'navigation extent': layout.workspaceMenuHorizontal
                  ? navigation.height
                  : navigation.width,
              'brand image width': tester.getRect(brandIcon).width,
              'brand image height': tester.getRect(brandIcon).height,
            };
          }

          final oldGeometry = <UiDisplaySize, Map<String, double>>{};
          for (final size in [UiDisplaySize.normal, UiDisplaySize.compact]) {
            await layout.setUiDisplaySize(size);
            await tester.pumpAndSettle();
            oldGeometry[size] = chromeGeometry();
          }
          await layout.setUiDisplaySize(UiDisplaySize.minimal);
          await tester.pumpAndSettle();
          final minimalChrome = chromeGeometry();
          for (final entry in oldGeometry[UiDisplaySize.compact]!.entries) {
            expect(
              minimalChrome[entry.key],
              closeTo(entry.value, .001),
              reason: 'minimal retains compact ${entry.key}',
            );
          }
          // The long-name fixtures exercise the changed flat briefings. The
          // unchanged card modes above use neutral data for their chrome audit.
          reducer.populated = true;
          state.accept(start2Event);
          await state.idle;

          Future<void> showModuleFirst(String module) async {
            await layout.setDashboardCardOrder([
              module,
              ...layout.dashboardCardOrder.where((id) => id != module),
            ]);
            if (scenario.hd) {
              await layout.moveHdModuleToSidebar(module, target: 'battle');
              await layout.moveHdPortraitModule(module, 'battle', false);
            }
            await tester.pumpAndSettle();
          }

          void expectNaturalTextHeight(Finder text) {
            final paragraph = tester.renderObject<RenderParagraph>(text);
            final natural = paragraph.getDryLayout(
              BoxConstraints(maxWidth: paragraph.size.width),
            );
            expect(
              paragraph.size.height,
              greaterThanOrEqualTo(natural.height - .01),
              reason:
                  'text must not be clipped vertically: ${tester.widget<Text>(text).data}',
            );
          }

          void expectEvenTabs(List<String> keys) {
            final rects = [
              for (final key in keys) tester.getRect(find.byKey(Key(key))),
            ];
            for (var i = 0; i < rects.length; i++) {
              expect(rects[i].width, closeTo(rects.first.width, .01));
              expect(rects[i].top, closeTo(rects.first.top, .01));
              if (i > 0) {
                expect(
                  rects[i].left,
                  greaterThanOrEqualTo(rects[i - 1].right - .01),
                );
              }
            }
          }

          void expectTitleClearOfChevron(Finder card) {
            final header = find.descendant(
              of: card,
              matching: find.byKey(const Key('dashboard-card-header')),
            );
            final dashboard = tester.widget<DashboardCard>(
              find.descendant(of: card, matching: find.byType(DashboardCard)),
            );
            final title = find.descendant(
              of: header,
              matching: find.text(dashboard.title),
            );
            final chevron = find.descendant(
              of: header,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Icon &&
                    (widget.icon == Icons.keyboard_arrow_up_rounded ||
                        widget.icon == Icons.keyboard_arrow_down_rounded),
              ),
            );
            final titleRect = tester.getRect(title);
            final chevronRect = tester.getRect(chevron);
            expect(titleRect.right, lessThanOrEqualTo(chevronRect.left + .01));
            expectNaturalTextHeight(title);
          }

          void expectMetricsFit() {
            final metrics = find.byKey(const Key('fleet-summary-metrics'));
            final items = find.descendant(
              of: metrics,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is InkWell &&
                    widget.key is ValueKey<String> &&
                    (widget.key! as ValueKey<String>).value.startsWith(
                      'fleet-summary-metric-',
                    ),
              ),
            );
            expect(items, findsWidgets);
            for (final item in items.evaluate()) {
              final itemFinder = find.byWidget(item.widget);
              final rect = tester.getRect(itemFinder);
              final texts = find.descendant(
                of: itemFinder,
                matching: find.byType(Text),
              );
              expect(texts, findsNWidgets(2));
              final label = tester.getRect(texts.first);
              final value = tester.getRect(texts.last);
              expect(label.right, lessThanOrEqualTo(value.left + .01));
              expect(
                value.right,
                lessThanOrEqualTo(rect.right + .01),
                reason: 'summary value must stay inside its column',
              );
              expect(label.center.dy, closeTo(value.center.dy, .01));
              expectNaturalTextHeight(texts.first);
              expectNaturalTextHeight(texts.last);
            }
          }

          await showModuleFirst('fleet');
          final fleet = find.byType(FleetSummaryCard);
          expect(fleet, findsOneWidget);
          expectTitleClearOfChevron(fleet);
          expectMetricsFit();
          expectEvenTabs([
            for (var id = 1; id <= 4; id++) 'fleet-summary-selector-$id',
          ]);
          final ship = find.byKey(const Key('minimal-ship-row-1'));
          final name = find.byKey(const Key('minimal-name-1'));
          expectNaturalTextHeight(name);
          final nameRect = tester.getRect(name);
          final icons = find.descendant(
            of: ship,
            matching: find.byType(EquipmentTypeIconImage),
          );
          expect(icons, findsNWidgets(4));
          expect(
            nameRect.right,
            lessThanOrEqualTo(tester.getRect(icons.first).left + .01),
          );
          final values = [
            for (final key in [
              'minimal-hp-value-1',
              'minimal-supply-fuel-value-1',
              'minimal-supply-ammo-value-1',
            ])
              find.byKey(Key(key)),
          ];
          for (final value in values) {
            expectNaturalTextHeight(value);
            expect(tester.widget<Text>(value).data, '999/999');
            final valueRect = tester.getRect(value);
            final shipRect = tester.getRect(ship);
            expect(valueRect.left, greaterThanOrEqualTo(shipRect.left - .01));
            expect(valueRect.right, lessThanOrEqualTo(shipRect.right + .01));
            expect(valueRect.bottom, lessThanOrEqualTo(shipRect.bottom + .01));
          }
          expect(
            tester.getRect(values[0]).overlaps(tester.getRect(values[2])),
            isFalse,
          );

          if (scenario.hd && scenario.locale == 'en') {
            await layout.setFleetDisplayFields({
              'equipment',
              'hp',
              'fuel',
              'ammo',
              'bars',
              'level',
              'type',
              'shipSpeed',
              'morale',
              'mechanisms',
              'minimum-condition',
              'recovery-countdown',
            });
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('fleet-summary-metric-minimum-condition')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('fleet-summary-metric-recovery-countdown')),
              findsOneWidget,
            );
            expectMetricsFit();
          }

          await showModuleFirst('land_base');
          final landBase = find.byType(LandBaseSummaryCard);
          expectTitleClearOfChevron(landBase);
          final baseName = find.byKey(const Key('land-base-name-6-1'));
          final baseRect = tester.getRect(baseName);
          expect(baseRect.width, greaterThan(0));
          for (final key in [
            'land-base-air-power-chip-6-1',
            'land-base-range-chip-6-1',
          ]) {
            final metric = find.byKey(Key(key));
            final rect = tester.getRect(metric);
            expect(rect.center.dy, closeTo(baseRect.center.dy, .01));
            expect(rect.left, greaterThanOrEqualTo(baseRect.right - .01));
            expectNaturalTextHeight(
              find.descendant(of: metric, matching: find.byType(Text)),
            );
          }
          final slots = [
            for (var id = 1; id <= 4; id++)
              tester.getRect(find.byKey(Key('land-base-slot-6-1-$id'))),
          ];
          for (var id = 0; id < slots.length; id++) {
            expect(slots[id].width, closeTo(slots.first.width, .01));
            expect(slots[id].top, closeTo(slots.first.top, .01));
            if (id > 0) {
              expect(slots[id].left, greaterThan(slots[id - 1].right));
            }
          }

          await showModuleFirst('repair');
          expectTitleClearOfChevron(find.byType(RepairSummaryCard));
          expectEvenTabs([
            'repair-summary-mode-dock',
            'repair-summary-mode-anchorage',
            'repair-summary-mode-nosaki',
          ]);
          reducer.populated = false;
          state.accept(start2Event);
          await state.idle;
          for (final size in [UiDisplaySize.normal, UiDisplaySize.compact]) {
            await layout.setUiDisplaySize(size);
            await tester.pumpAndSettle();
            final current = chromeGeometry();
            for (final entry in oldGeometry[size]!.entries) {
              expect(
                current[entry.key],
                closeTo(entry.value, .001),
                reason: '$size ${entry.key}',
              );
            }
          }
          expect(
            find.ancestor(of: game, matching: find.byType(UiScale)),
            findsNothing,
          );
          expect(tester.element(game), same(originalGame));
          expect(disposals, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('header first minimal shell', () {
    for (final side in ['left', 'right']) {
      testWidgets('$side rail yields the full header across workspaces', (
        tester,
      ) async {
        const corners = MethodChannel(displayCornersChannelName);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          corners,
          (_) async => <String, Object>{
            'topLeft': 55,
            'topRight': 40,
            'bottomLeft': 24,
            'bottomRight': 24,
          },
        );
        addTearDown(() => messenger.setMockMethodCallHandler(corners, null));
        const gameKey = Key('header-first-game');
        final browser = _NoopBrowserPort();
        final layout = await _pumpMinimalShell(
          tester,
          browserPort: browser,
          gameSurface: const ColoredBox(key: gameKey, color: Colors.black),
        );
        await layout.setWorkspaceMenuPosition(side);
        await tester.pumpAndSettle();
        final brand = find.byKey(const Key('yahagi-brand-button'));
        Finder header() => find
            .ancestor(
              of: brand,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container &&
                    widget.constraints?.minHeight == 36 &&
                    widget.constraints?.maxHeight == 36,
              ),
            )
            .first;
        final rail = find.byKey(const Key('workspace-navigation-sidebar'));
        final firstNavigationItem = find.byKey(const Key('workspace-nav-game'));
        final gameElement = tester.element(find.byKey(gameKey));
        final headerElement = tester.element(header());
        final noticeHost = tester.state(find.byType(QuestCompletionDrawerHost));
        final originalReloads = browser.reloadCalls;
        final firstItemTop = tester.getTopLeft(firstNavigationItem).dy;
        final navigation = tester.widget<WorkspaceNavigation>(
          find.byType(WorkspaceNavigation),
        );
        for (final workspace in [0, 8, 0]) {
          navigation.onSelected(workspace);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(header()),
            rectMoreOrLessEquals(
              const Rect.fromLTWH(0, 0, 873, _minimalHeaderHeight),
            ),
          );
          expect(
            tester.getRect(rail),
            rectMoreOrLessEquals(
              Rect.fromLTWH(
                side == 'left' ? 0 : 873 - _minimalNavigationExtent,
                _minimalHeaderHeight,
                _minimalNavigationExtent,
                393 - _minimalHeaderHeight,
              ),
            ),
          );
          expect(
            tester.getRect(brand).left,
            closeTo(8 + cornerInsetAt(55, 10.5), .01),
          );
          expect(tester.getTopLeft(firstNavigationItem).dy, firstItemTop);
          expect(firstItemTop, greaterThanOrEqualTo(_minimalHeaderHeight));
          expect(
            tester.element(find.byKey(gameKey, skipOffstage: false)),
            same(gameElement),
          );
          expect(tester.element(header()), same(headerElement));
          expect(
            tester.state(find.byType(QuestCompletionDrawerHost)),
            same(noticeHost),
          );
          expect(browser.reloadCalls, originalReloads);
          expect(find.byType(WorkspaceNavigation), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('fixed top resources', () {
    for (final savedPosition in MinimalResourcePosition.values) {
      testWidgets('legacy $savedPosition uses the persistent header', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'layout_minimal_resource_position': savedPosition.name,
        });
        final toolbar = GameToolbarController();
        final notices = TopNoticeController();
        addTearDown(toolbar.dispose);
        addTearDown(notices.dispose);
        const gameKey = Key('fixed-top-resource-game');
        final layout = await _pumpMinimalShell(
          tester,
          layoutStore: SharedPreferencesLayoutSettingsStore(),
          toolbarController: toolbar,
          headerNoticeController: notices,
          gameSurface: const ColoredBox(key: gameKey, color: Colors.black),
        );
        expect(layout.minimalResourcePosition, savedPosition);
        final resource = find.byKey(const Key('header-resource-material-1'));
        final headerSlot = find.byType(QuestCompletionHeaderSlot);
        expect(
          find.descendant(of: headerSlot, matching: resource),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('information-panel-resources')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('minimal-bottom-resource-bar')),
          findsNothing,
        );
        final originalGame = tester.element(find.byKey(gameKey));
        final originalHeader = tester.element(headerSlot);
        final originalHost = tester.state(
          find.byType(QuestCompletionDrawerHost),
        );

        toolbar.reveal();
        notices.show(message: '任务完成', tone: TopNoticeTone.quest);
        final noticeId = notices.notices.single.id;
        await tester.pump(const Duration(milliseconds: 50));
        for (final size in [
          UiDisplaySize.compact,
          UiDisplaySize.normal,
          UiDisplaySize.minimal,
        ]) {
          await layout.setUiDisplaySize(size);
          await tester.pump(const Duration(milliseconds: 40));
          expect(tester.element(find.byKey(gameKey)), same(originalGame));
          expect(tester.element(headerSlot), same(originalHeader));
          expect(
            tester.state(find.byType(QuestCompletionDrawerHost)),
            same(originalHost),
          );
          expect(toolbar.isVisible, isTrue);
          expect(notices.notices.single.id, noticeId);
          expect(
            find.byKey(const Key('quest-completion-drawer')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('information-panel-resources')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('minimal-bottom-resource-bar')),
            findsNothing,
          );
        }
        await tester.tap(find.byKey(const Key('yahagi-brand-button')));
        await tester.pumpAndSettle();
        expect(toolbar.isVisible, isFalse);
        expect(notices.notices.single.id, noticeId);
        notices.hide();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);
        expect(
          find.descendant(of: headerSlot, matching: resource),
          findsOneWidget,
        );
        expect(tester.element(find.byKey(gameKey)), same(originalGame));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('only minimal flattens top resources while preserving icons', (
      tester,
    ) async {
      final layout = await _pumpMinimalShell(
        tester,
        uiSize: UiDisplaySize.compact,
      );
      await layout.setMinimalResourcePosition(MinimalResourcePosition.topBar);
      await tester.pumpAndSettle();
      final resource = find.byKey(const Key('header-resource-material-1'));
      Finder capsule() => find.descendant(
        of: resource,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border != null,
        ),
      );
      expect(capsule(), findsOneWidget);
      final compactSize = tester.getSize(resource);
      final compactDecoration = tester.widget<Container>(capsule()).decoration;
      final resourceIcon = find.descendant(
        of: resource,
        matching: find.byType(Image),
      );
      final compactIcon = tester.widget<Image>(resourceIcon);
      final compactIconSize = tester.getSize(resourceIcon);
      final compactPaintedIconSize = tester.getRect(resourceIcon).size;
      await layout.setUiDisplaySize(UiDisplaySize.minimal);
      await tester.pumpAndSettle();
      expect(capsule(), findsNothing);
      expect(tester.getSize(resource), compactSize);
      expect(tester.widget<Image>(resourceIcon).image, compactIcon.image);
      expect(tester.getSize(resourceIcon), compactIconSize);
      expect(
        tester.getRect(resourceIcon).width,
        closeTo(compactPaintedIconSize.width, .001),
      );
      expect(
        tester.getRect(resourceIcon).height,
        closeTo(compactPaintedIconSize.height, .001),
      );
      expect(
        find.byKey(const Key('header-resource-divider-before-anchorage-timer')),
        findsOneWidget,
      );
      for (final size in [UiDisplaySize.normal, UiDisplaySize.compact]) {
        await layout.setUiDisplaySize(size);
        await tester.pumpAndSettle();
        expect(capsule(), findsOneWidget);
        expect(
          find.byKey(
            const Key('header-resource-divider-before-anchorage-timer'),
          ),
          findsNothing,
        );
        if (size == UiDisplaySize.compact) {
          expect(tester.getSize(resource), compactSize);
          expect(tester.getRect(resourceIcon).size, compactPaintedIconSize);
          expect(
            tester.widget<Container>(capsule()).decoration,
            compactDecoration,
          );
        }
      }
      await layout.setHdEnabled(true);
      await layout.setUiDisplaySize(UiDisplaySize.minimal);
      await tester.pumpAndSettle();
      expect(capsule(), findsNothing);
      expect(tester.getSize(resource), compactSize);
      expect(tester.widget<Image>(resourceIcon).image, compactIcon.image);
      expect(tester.getSize(resourceIcon), compactIconSize);
      expect(
        tester.getRect(resourceIcon).height,
        closeTo(compactPaintedIconSize.height, .001),
      );
      expect(
        find.byKey(const Key('header-resource-divider-before-anchorage-timer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('minimal topbar integration', () {
    testWidgets('brand opens the original toolbar in the persistent header', (
      tester,
    ) async {
      final toolbar = GameToolbarController();
      addTearDown(toolbar.dispose);
      await _pumpMinimalShell(tester, toolbarController: toolbar);

      final brand = find.byKey(const Key('yahagi-brand-button'));
      expect(brand, findsOneWidget);
      expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      final resource = find.byKey(const Key('header-resource-material-1'));
      expect(
        find.descendant(
          of: find.byType(QuestCompletionHeaderSlot),
          matching: resource,
        ),
        findsOneWidget,
      );
      expect(resource, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('information-panel-resources')),
          matching: resource,
        ),
        findsNothing,
      );
      await tester.tap(brand);
      await tester.pumpAndSettle();
      expect(toolbar.isVisible, isTrue);
      final visibleToolbar = find.byKey(const Key('game-toolbar-visible'));
      expect(visibleToolbar, findsOneWidget);
      expect(tester.getRect(visibleToolbar).top, greaterThanOrEqualTo(0));
      expect(
        tester.getRect(visibleToolbar).bottom,
        lessThanOrEqualTo(_minimalHeaderHeight),
      );
      expect(find.byKey(const Key('game-browser-menu-reload')), findsNothing);

      await tester.tap(brand);
      await tester.pumpAndSettle();
      expect(toolbar.isVisible, isFalse);
      expect(visibleToolbar, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'quest notice covers the header toolbar and restores its state',
      (tester) async {
        final toolbar = GameToolbarController(initiallyVisible: true);
        final notices = TopNoticeController();
        addTearDown(toolbar.dispose);
        addTearDown(notices.dispose);
        final layout = await _pumpMinimalShell(
          tester,
          toolbarController: toolbar,
          headerNoticeController: notices,
        );
        final headerSlot = find.byWidgetPredicate(
          (widget) =>
              widget is QuestCompletionHeaderSlot && widget.toolbarVisible,
        );
        for (final position in MinimalResourcePosition.values) {
          await layout.setMinimalResourcePosition(position);
          await tester.pumpAndSettle();
          notices.show(message: '任务完成', tone: TopNoticeTone.quest);
          await tester.pumpAndSettle();
          final drawer = find.byKey(const Key('quest-completion-drawer'));
          expect(drawer, findsOneWidget, reason: '$position');
          expect(
            find.descendant(of: headerSlot, matching: drawer),
            findsOneWidget,
          );
          expect(
            tester.getRect(drawer).bottom,
            lessThanOrEqualTo(_minimalHeaderHeight),
          );
          final contentOpacity = tester.widget<AnimatedOpacity>(
            find
                .descendant(
                  of: headerSlot,
                  matching: find.byType(AnimatedOpacity),
                )
                .first,
          );
          expect(contentOpacity.opacity, 0);
          expect(toolbar.isVisible, isTrue);
          notices.hide();
          await tester.pumpAndSettle();
          expect(drawer, findsNothing);
          expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);
          expect(toolbar.isVisible, isTrue);
        }
        // Changing the toolbar while a notice is visible must determine what
        // returns after dismissal, rather than restoring its earlier state.
        await layout.setMinimalResourcePosition(MinimalResourcePosition.topBar);
        notices.show(message: '任务完成', tone: TopNoticeTone.quest);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('yahagi-brand-button')));
        await tester.pumpAndSettle();
        expect(toolbar.isVisible, isFalse);
        expect(
          find.byKey(const Key('quest-completion-drawer')),
          findsOneWidget,
        );
        notices.hide();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);
        expect(
          find.byKey(const Key('header-resource-material-1')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'size changes during animation preserve game header and notice',
      (tester) async {
        var disposals = 0;
        var deactivations = 0;
        final toolbar = GameToolbarController();
        final notices = TopNoticeController();
        addTearDown(toolbar.dispose);
        addTearDown(notices.dispose);
        final browser = _NoopBrowserPort();
        final layout = await _pumpMinimalShell(
          tester,
          uiSize: UiDisplaySize.normal,
          toolbarController: toolbar,
          headerNoticeController: notices,
          browserPort: browser,
          gameSurface: _LifecycleProbe(
            key: const Key('persistent-integrated-game'),
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        );
        final game = find.byKey(const Key('persistent-integrated-game'));
        final originalGame = tester.element(game);
        final originalHeader = tester.element(
          find.byType(WorkspaceContextHeader, skipOffstage: false),
        );
        final originalHost = tester.state(
          find.byType(QuestCompletionDrawerHost),
        );
        final originalPanelScope = tester.element(
          find
              .ancestor(
                of: find.byType(FleetSummaryCard),
                matching: find.byType(PanelStyleScope),
              )
              .first,
        );
        final originalReloads = browser.reloadCalls;
        toolbar.reveal();
        notices.show(
          message: '同一批任务',
          tone: TopNoticeTone.quest,
          duration: const Duration(seconds: 2),
        );
        final noticeId = notices.notices.single.id;
        await tester.pump(const Duration(milliseconds: 50));

        for (final size in [
          UiDisplaySize.minimal,
          UiDisplaySize.compact,
          UiDisplaySize.normal,
          UiDisplaySize.minimal,
        ]) {
          await layout.setUiDisplaySize(size);
          await tester.pump(const Duration(milliseconds: 40));
          expect(tester.element(game), same(originalGame));
          expect(
            tester.element(
              find.byType(WorkspaceContextHeader, skipOffstage: false),
            ),
            same(originalHeader),
          );
          expect(
            tester.state(find.byType(QuestCompletionDrawerHost)),
            same(originalHost),
          );
          expect(
            tester.element(
              find
                  .ancestor(
                    of: find.byType(FleetSummaryCard),
                    matching: find.byType(PanelStyleScope),
                  )
                  .first,
            ),
            same(originalPanelScope),
          );
          expect(toolbar.isVisible, isTrue);
          expect(notices.notices.single.id, noticeId);
          expect(
            find.byKey(const Key('quest-completion-drawer')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);
          expect(disposals, 0);
          expect(deactivations, 0);
        }
        await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.byKey(const Key('workspace-nav-game')));
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.element(game), same(originalGame));
        expect(disposals, 0);
        expect(deactivations, 0);
        expect(browser.reloadCalls, originalReloads);
        // Navigation retains the established collapse behavior; size changes do
        // not mutate the controller, and returning still uses the same toolbar.
        expect(toolbar.isVisible, isFalse);
        toolbar.reveal();
        await tester.pump(const Duration(milliseconds: 1710));
        expect(notices.notices, isEmpty);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('minimal game shell', () {
    for (final onLeft in [false, true]) {
      testWidgets('极简模块折叠箭头右缘对齐 (onLeft: $onLeft)', (tester) async {
        final layout = await _pumpMinimalShell(tester);
        await layout.setInformationPanelOnLeft(onLeft);
        await tester.pumpAndSettle();
        bool chevron(Widget w) =>
            w is Icon &&
            (w.icon == Icons.keyboard_arrow_up_rounded ||
                w.icon == Icons.keyboard_arrow_down_rounded);
        final cardChevrons = find.descendant(
          of: find.byType(DashboardCard),
          matching: find.byWidgetPredicate(chevron),
        );
        expect(cardChevrons, findsWidgets);
        final alignedRight = tester.getRect(cardChevrons.first).right;
        for (final element in cardChevrons.evaluate()) {
          expect(
            tester.getRect(find.byWidget(element.widget)).right,
            alignedRight,
          );
        }
      });
    }
    testWidgets('极简档模块编辑列表用扁平开关和顶栏', (tester) async {
      await _pumpMinimalShell(tester);
      await tester.longPress(find.byKey(const ValueKey('fleet')));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(
        find.byKey(const Key('dashboard-visibility-fleet')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard-edit-bar')), findsOneWidget);
      final gear = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('fleet-display-settings-button')),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      expect(gear.width, closeTo(flatActionIconSize * minimalUiScale, .001));
      expect(gear.height, closeTo(flatActionIconSize * minimalUiScale, .001));
      expect(tester.takeException(), isNull);
    });
    testWidgets('minimal landscape retains brand header and top resources', (
      tester,
    ) async {
      await _pumpMinimalShell(tester);

      expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
      expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(QuestCompletionHeaderSlot),
          matching: find.byKey(const Key('header-resource-material-1')),
        ),
        findsOneWidget,
      );
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(_sidebarWidth(tester), closeTo(_minimalNavigationExtent, .001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal brand opens and closes the header toolbar', (
      tester,
    ) async {
      await _pumpMinimalShell(tester);

      await tester.tap(find.byKey(const Key('yahagi-brand-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);

      await tester.tap(find.byKey(const Key('yahagi-brand-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal other workspaces keep the rail below the header', (
      tester,
    ) async {
      await _pumpMinimalShell(tester);
      final menuButton = find.byKey(const Key('workspace-nav-fleet'));
      final gameMenuTop = tester.getTopLeft(menuButton).dy;

      await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(_sidebarWidth(tester), closeTo(_minimalNavigationExtent, .001));
      final rail = tester.getRect(
        find.byKey(const Key('workspace-navigation-sidebar')),
      );
      expect(rail.top, closeTo(_minimalHeaderHeight, .001));
      expect(
        rail.height,
        closeTo(_phoneLandscape.height - _minimalHeaderHeight, .001),
      );
      expect(tester.getTopLeft(menuButton).dy, gameMenuTop);
      expect(
        tester.getTopLeft(find.byType(WorkspaceContextHeader)).dx,
        greaterThanOrEqualTo(_minimalNavigationExtent),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'minimal game navigation returns other workspaces to the game',
      (tester) async {
        await _pumpMinimalShell(tester);
        await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('workspace-nav-game')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('game-browser-menu-reload')), findsNothing);
        expect(find.byType(FleetInformationCenter), findsNothing);
        expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('minimal header on other workspaces clears both top corners', (
      tester,
    ) async {
      const corners = MethodChannel(displayCornersChannelName);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        corners,
        (_) async => <String, Object>{
          'topLeft': 55,
          'topRight': 40,
          'bottomLeft': 24,
          'bottomRight': 24,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(corners, null));
      final layout = await _pumpMinimalShell(tester);
      await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
      await tester.pumpAndSettle();
      Rect header() => tester.getRect(find.byType(WorkspaceContextHeader));

      // 页头跨满顶部，品牌与右侧内容分别让开两端圆弧。
      expect(
        tester.getRect(find.byKey(const Key('yahagi-brand-button'))).left,
        closeTo(8 + cornerInsetAt(55, 10.5), 0.01),
      );
      expect(
        header().right,
        lessThanOrEqualTo(_phoneLandscape.width - cornerInsetAt(40, 10.5)),
      );

      await layout.setWorkspaceMenuPosition('bottom');
      await tester.pumpAndSettle();
      expect(header().left, greaterThanOrEqualTo(cornerInsetAt(55, 10.5)));
      expect(
        header().right,
        lessThanOrEqualTo(_phoneLandscape.width - cornerInsetAt(40, 10.5)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal horizontal navigation retains the brand everywhere', (
      tester,
    ) async {
      final layout = await _pumpMinimalShell(tester);
      for (final position in const ['bottom', 'top']) {
        await layout.setWorkspaceMenuPosition(position);
        await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('yahagi-brand-button')),
          findsOneWidget,
          reason: position,
        );
        expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
        await tester.tap(find.byKey(const Key('workspace-nav-game')));
        await tester.pumpAndSettle();
        expect(find.byType(FleetInformationCenter), findsNothing);
        expect(tester.takeException(), isNull, reason: position);
      }
    });

    testWidgets('minimal portrait retains resources in the header', (
      tester,
    ) async {
      await _pumpMinimalShell(tester, size: const Size(393, 873));

      expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(
        find.byKey(const Key('information-panel-resources')),
        findsNothing,
      );
      // The shared header starts with ranking and timer capsules; materials
      // farther along the horizontal list are built when scrolled into view.
      await tester.dragUntilVisible(
        find.byKey(const Key('header-resource-material-1')),
        find.byKey(const Key('header-resource-list')),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(QuestCompletionHeaderSlot),
          matching: find.byKey(const Key('header-resource-material-1')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    double? panelBottomPadding(WidgetTester tester) {
      final finder = find.descendant(
        of: find.byKey(const Key('workspace-information-panel')),
        matching: find.byType(ListView),
      );
      final list = tester.widget<ListView>(finder);
      // The platform safe area is physical space, so it must remain 20dp
      // while the UI's local coordinates become smaller under UiScale.
      return (list.padding! as EdgeInsets).bottom *
          UiScale.of(tester.element(finder));
    }

    testWidgets('minimal portrait panel clears the bottom safe area', (
      tester,
    ) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      tester.view.padding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      await _pumpMinimalShell(tester, size: const Size(393, 873));

      expect(panelBottomPadding(tester), closeTo(20, .001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal landscape with bottom nav leaves panel unpadded', (
      tester,
    ) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      tester.view.padding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      final layout = await _pumpMinimalShell(tester);
      expect(panelBottomPadding(tester), closeTo(20, .001));

      await layout.setWorkspaceMenuPosition('bottom');
      await tester.pumpAndSettle();

      expect(panelBottomPadding(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HD minimal keeps its layout and uses flat modules', (
      tester,
    ) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      tester.view.padding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      var deactivations = 0;
      var disposals = 0;
      final toolbar = GameToolbarController();
      final notices = TopNoticeController();
      addTearDown(toolbar.dispose);
      addTearDown(notices.dispose);
      final state = GameStateController(reducer: _HdMinimalStateReducer());
      await state.initialize();
      state.accept(start2Event);
      await state.idle;
      final browser = _NoopBrowserPort();
      const gameKey = Key('hd-minimal-game');
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(1200, 700),
        uiSize: UiDisplaySize.compact,
        gameState: state,
        browserPort: browser,
        toolbarController: toolbar,
        headerNoticeController: notices,
        gameSurface: _LifecycleProbe(
          key: gameKey,
          onDeactivate: () => deactivations++,
          onDispose: () => disposals++,
        ),
      );
      await layout.setHdEnabled(true);
      await layout.moveHdModuleToSidebar('expedition');
      await layout.moveHdModuleToSidebar('repair', target: 'battle');
      await layout.moveHdModuleToBottom('fleet');
      await layout.setHdModuleSpan('fleet', 2);
      await layout.setHdPortraitSize('repair', 1, 2);
      await tester.pumpAndSettle();
      final game = find.byKey(gameKey);
      final originalGame = tester.element(game);
      final originalHeader = tester.element(
        find.byType(WorkspaceContextHeader),
      );
      final originalHost = tester.state(find.byType(QuestCompletionDrawerHost));
      final originalReloads = browser.reloadCalls;
      void expectAlive() {
        expect(tester.element(game), same(originalGame));
        expect(
          tester.element(find.byType(WorkspaceContextHeader)),
          same(originalHeader),
        );
        expect(
          tester.state(find.byType(QuestCompletionDrawerHost)),
          same(originalHost),
        );
        expect(browser.reloadCalls, originalReloads);
        expect(deactivations, 0);
        expect(disposals, 0);
        expect(tester.takeException(), isNull);
      }

      void expectStyle(Finder card, PanelStyle style) {
        expect(card, findsOneWidget);
        final scope = find
            .ancestor(of: card, matching: find.byType(PanelStyleScope))
            .first;
        expect(tester.widget<PanelStyleScope>(scope).style, style);
      }

      for (final screen in const [Size(1200, 700), Size(700, 1200)]) {
        tester.view.physicalSize = screen;
        for (final position in ['left', 'right', 'top', 'bottom']) {
          await layout.setWorkspaceMenuPosition(position);
          await layout.setUiDisplaySize(UiDisplaySize.compact);
          await tester.pumpAndSettle();
          final compactGame = tester.getRect(game);
          final hdConfiguration = layout.hdSettings;
          await layout.setUiDisplaySize(UiDisplaySize.minimal);
          await tester.pumpAndSettle();
          final minimalGame = tester.getRect(game);
          final workspace = tester.getRect(
            find.byKey(const Key('game-workspace')),
          );
          // The flat briefings grow inside the original HD slots; the compact
          // chrome leaves the game viewport and its aspect ratio unchanged.
          expect(
            minimalGame,
            rectMoreOrLessEquals(compactGame),
            reason: '$screen $position preserves the compact game viewport',
          );
          expect(
            minimalGame.width / minimalGame.height,
            closeTo(compactGame.width / compactGame.height, .001),
            reason: '$screen $position',
          );
          expect(minimalGame.top, greaterThanOrEqualTo(workspace.top));
          expect(
            minimalGame.bottom,
            lessThanOrEqualTo(workspace.bottom + .001),
          );
          if (screen.width > screen.height) {
            final geometry = HdWorkspaceGeometry.forSize(
              workspace.size,
              gameAreaRatio: layout.autoZoom
                  ? .67
                  : layout.gameAreaRatio.clamp(.5, .75),
            );
            final expectedViewport = Rect.fromLTWH(
              workspace.left +
                  (layout.informationPanelOnLeft ? geometry.panelWidth + 1 : 0),
              workspace.top +
                  (layout.hdSettings.extensionAboveGame
                      ? geometry.bottomHeight
                      : 0),
              geometry.gameWidth,
              geometry.gameHeight,
            );
            expect(
              tester.getRect(find.byType(GameSurfaceViewport)),
              rectMoreOrLessEquals(expectedViewport, epsilon: .001),
              reason: '$screen $position HD viewport',
            );
          }
          expect(layout.hdSettings, same(hdConfiguration));
          expect(
            find.ancestor(of: game, matching: find.byType(UiScale)),
            findsNothing,
          );
          expectAlive();
          await layout.setUiDisplaySize(UiDisplaySize.compact);
          await tester.pumpAndSettle();
          expect(tester.getRect(game), rectMoreOrLessEquals(compactGame));
          expectAlive();
        }

        toolbar.reveal();
        notices.show(
          message: 'HD任务完成',
          tone: TopNoticeTone.quest,
          duration: const Duration(minutes: 1),
        );
        final noticeId = notices.notices.single.id;
        for (final size in [
          UiDisplaySize.normal,
          UiDisplaySize.minimal,
          UiDisplaySize.compact,
        ]) {
          await layout.setUiDisplaySize(size);
          await tester.pumpAndSettle();
          final flat = size == UiDisplaySize.minimal;
          final style = flat ? PanelStyle.flat : PanelStyle.card;
          expectStyle(find.byType(FleetSummaryCard), style);
          expectStyle(find.byType(RepairSummaryCard), style);
          if (screen.width > screen.height) {
            final bottom = find.byKey(const Key('hd-bottom-region'));
            expect(bottom, findsOneWidget);
            expect(
              find.descendant(
                of: bottom,
                matching: find.byType(FleetSummaryCard),
              ),
              findsOneWidget,
            );
            expect(find.byKey(const Key('hd-portrait-grid')), findsNothing);
          } else {
            expect(find.byKey(const Key('hd-portrait-grid')), findsOneWidget);
            final cell = find.byKey(const Key('hd-portrait-cell-fleet'));
            final box =
                tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: cell,
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration;
            expect(box.color, flat ? isNull : isNotNull);
            expect(box.borderRadius, flat ? null : BorderRadius.circular(10));
          }
          expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
          expect(find.byKey(const Key('yahagi-hd-label')), findsOneWidget);
          expect(toolbar.isVisible, isTrue);
          expect(notices.notices.single.id, noticeId);
          final drawer = find.byKey(const Key('quest-completion-drawer'));
          expect(drawer, findsOneWidget);
          expect(
            tester.getRect(drawer).bottom,
            lessThanOrEqualTo(_headerHeight(tester)),
          );
          expectAlive();
        }
        notices.hide();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('game-toolbar-visible')), findsOneWidget);
        await tester.tap(find.byKey(const Key('yahagi-brand-button')));
        await tester.pumpAndSettle();
        expect(toolbar.isVisible, isFalse);
        expect(find.byKey(const Key('game-toolbar-visible')), findsNothing);
        expect(
          find.byKey(const Key('header-resource-list')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('header-resource-senka')).hitTestable(),
          findsOneWidget,
        );

        await layout.setUiDisplaySize(UiDisplaySize.minimal);
        await tester.pumpAndSettle();
        if (screen.width > screen.height) {
          final fleet = find.byType(FleetSummaryCard);
          expect(
            tester
                .getSize(find.byKey(const Key('fleet-summary-switcher')))
                .width,
            greaterThan(tester.getSize(fleet).width * .8),
          );
          final first = tester.getRect(
            find.byKey(const Key('minimal-ship-row-1')),
          );
          final second = tester.getRect(
            find.byKey(const Key('minimal-ship-row-2')),
          );
          expect(first.top, second.top);
          expect(second.left, greaterThan(first.right));
        } else {
          final mode = find.byKey(const Key('repair-summary-mode-anchorage'));
          await tester.ensureVisible(mode);
          await tester.tap(mode);
          await tester.pumpAndSettle();
          final fleetTwo = find.byKey(const Key('repair-summary-fleet-2'));
          await tester.ensureVisible(fleetTwo);
          await tester.tap(fleetTwo);
          await tester.pumpAndSettle();
          final selector = find.byKey(
            const Key('repair-summary-fleet-selector'),
          );
          final slot = find.byKey(const Key('repair-summary-anchorage-slot-0'));
          expect(
            tester.getRect(selector).bottom,
            lessThanOrEqualTo(tester.getRect(slot).top),
          );
          expect(
            tester.getSize(selector).width,
            greaterThan(
              tester.getSize(find.byType(RepairSummaryCard)).width * .8,
            ),
          );
          for (final size in [
            UiDisplaySize.compact,
            UiDisplaySize.normal,
            UiDisplaySize.minimal,
          ]) {
            await layout.setUiDisplaySize(size);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('repair-summary-anchorage-slot-0')),
              findsOneWidget,
            );
            expect(
              find.descendant(of: slot, matching: find.text('HD舰娘3')),
              findsOneWidget,
            );
            if (size == UiDisplaySize.minimal) {
              final text = tester.widget<Text>(
                find.descendant(of: fleetTwo, matching: find.byType(Text)),
              );
              expect(text.style?.color, flatAccentColor);
            }
            expectAlive();
          }
        }
        expectAlive();
      }
    });

    testWidgets(
      'minimal enlarges briefings while preserving compact chrome and the game',
      (tester) async {
        var disposals = 0;
        var deactivations = 0;
        final state = GameStateController(reducer: _HdMinimalStateReducer());
        await state.initialize();
        state.accept(start2Event);
        await state.idle;
        final browser = _NoopBrowserPort();
        const gameKey = Key('ui-scale-game');
        final layout = await _pumpMinimalShell(
          tester,
          size: const Size(1200, 700),
          uiSize: UiDisplaySize.compact,
          gameState: state,
          browserPort: browser,
          gameSurface: _LifecycleProbe(
            key: gameKey,
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        );
        final game = find.byKey(gameKey);
        await layout.setDashboardCardOrder([
          'fleet',
          ...layout.dashboardCardOrder.where((id) => id != 'fleet'),
        ]);
        await tester.pumpAndSettle();
        final originalGame = tester.element(game);
        final reloads = browser.reloadCalls;
        final brand = find.byKey(const Key('yahagi-brand-button'));
        final brandText = find.descendant(
          of: brand,
          matching: find.text('ヤハギ'),
        );
        final nav = find.byKey(const Key('workspace-nav-game'));
        final navIcon = find.descendant(of: nav, matching: find.byType(Icon));

        void expectScale(Finder finder, double factor) {
          final element = tester.element(finder);
          expect(UiScale.of(element), factor);
          final local = tester.getSize(finder);
          final painted = tester.getRect(finder).size;
          expect(painted.width, closeTo(local.width * factor, .001));
          expect(painted.height, closeTo(local.height * factor, .001));
        }

        for (final hd in [false, true]) {
          await layout.setHdEnabled(hd);
          if (hd) await layout.moveHdModuleToSidebar('fleet', target: 'battle');
          for (final size in [
            UiDisplaySize.normal,
            UiDisplaySize.compact,
            UiDisplaySize.minimal,
            UiDisplaySize.compact,
            UiDisplaySize.minimal,
          ]) {
            await layout.setUiDisplaySize(size);
            await tester.pumpAndSettle();
            final factor = size == UiDisplaySize.minimal ? minimalUiScale : 1.0;
            final header = size == UiDisplaySize.normal ? 44.0 : 36.0;
            final navigation = size == UiDisplaySize.normal ? 48.0 : 41.0;
            expect(_headerHeight(tester), closeTo(header, .001));
            expect(_sidebarWidth(tester), closeTo(navigation, .001));
            expectScale(brandText, 1);
            expectScale(navIcon, 1);

            final fleet = find.byType(FleetSummaryCard);
            expect(UiScale.of(tester.element(fleet)), factor);
            if (size == UiDisplaySize.minimal) {
              final cardHeader = find.descendant(
                of: fleet,
                matching: find.byKey(const Key('dashboard-card-header')),
              );
              final hp = find.byKey(const Key('minimal-hp-value-1'));
              final ship = find.byKey(const Key('minimal-ship-row-1'));
              expect(tester.getSize(cardHeader).height, flatHeaderHeight);
              expect(
                tester.getRect(cardHeader).height,
                closeTo(flatHeaderHeight * minimalUiScale, .001),
              );
              expectScale(hp, factor);
              expect(
                tester.getRect(ship).height,
                closeTo(tester.getSize(ship).height * factor, .001),
              );
            }
            expect(
              find.ancestor(of: game, matching: find.byType(UiScale)),
              findsNothing,
            );
            expect(tester.element(game), same(originalGame));
            expect(browser.reloadCalls, reloads);
            expect(disposals, 0);
            expect(deactivations, 0);
            expect(tester.takeException(), isNull, reason: '$hd / $size');
          }
        }
      },
    );

    testWidgets(
      'smoke: mode rotation HD and background capture preserve the live game',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          exitFullscreenSkipConfirmationKey: true,
        });
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );
        final state = GameStateController();
        await state.initialize();
        state
          ..accept(start2Event)
          ..accept(portEvent)
          ..accept(slotItemEvent);
        await state.idle;
        final anchor = DateTime.now().toUtc();
        state.nozakiTimer.reset(anchor);
        final finish = anchor
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch;
        Future<void> updateOperations(int count) async {
          for (final (endpoint, data) in <(String, Object)>[
            (
              'ndock',
              [
                for (var id = 1; id <= count; id++)
                  {
                    'api_id': id,
                    'api_state': 1,
                    'api_ship_id': 9000 + id,
                    'api_complete_time': finish,
                  },
              ],
            ),
            (
              'kdock',
              [
                for (var id = 1; id <= count; id++)
                  {
                    'api_id': id,
                    'api_state': 3,
                    'api_created_ship_id': 101,
                    'api_complete_time': 0,
                  },
              ],
            ),
            (
              'deck',
              [
                for (var id = 2; id <= 4; id++)
                  {
                    'api_id': id,
                    'api_mission': id <= count + 1 ? [1, 5, finish] : [0, 0, 0],
                  },
              ],
            ),
          ]) {
            state.accept(kcsapiEvent('/kcsapi/api_get_member/$endpoint', data));
          }
          await state.idle;
        }

        await updateOperations(1);
        var disposals = 0;
        var deactivations = 0;
        final browser = _NoopBrowserPort();
        final notices = TopNoticeController();
        addTearDown(notices.dispose);
        const gameKey = Key('all-modes-smoke-game');
        final layout = await _pumpMinimalShell(
          tester,
          size: const Size(1200, 700),
          uiSize: UiDisplaySize.normal,
          gameState: state,
          browserPort: browser,
          headerNoticeController: notices,
          gameSurface: _LifecycleProbe(
            key: gameKey,
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        );
        final gameElement = tester.element(find.byKey(gameKey));
        final reloads = browser.reloadCalls;
        await layout.reorderWorkspaceMenu(0, 2);
        final menuOrder = List<String>.of(layout.workspaceMenuOrder);
        void expectAlive() {
          expect(tester.element(find.byKey(gameKey)), same(gameElement));
          expect(browser.reloadCalls, reloads);
          expect(disposals, 0);
          expect(deactivations, 0);
          expect(state.nozakiTimer.anchorAt, anchor);
          expect(layout.workspaceMenuOrder, menuOrder);
          expect(tester.takeException(), isNull);
        }

        void expectBadges(String value) {
          for (final id in [
            'repair-active-count',
            'construction-completion-count',
            'expedition-active-count',
          ]) {
            expect(
              find.descendant(
                of: find.byKey(Key(id)),
                matching: find.text(value),
              ),
              findsOneWidget,
              reason: id,
            );
          }
        }

        for (final (size, hd, screen) in [
          (UiDisplaySize.normal, false, const Size(1200, 700)),
          (UiDisplaySize.compact, false, const Size(700, 1200)),
          (UiDisplaySize.minimal, false, const Size(1200, 700)),
          (UiDisplaySize.minimal, true, const Size(700, 1200)),
          (UiDisplaySize.compact, true, const Size(1200, 700)),
          (UiDisplaySize.normal, true, const Size(700, 1200)),
          (UiDisplaySize.minimal, true, const Size(1200, 700)),
        ]) {
          await layout.setUiDisplaySize(size);
          await layout.setHdEnabled(hd);
          tester.view.physicalSize = screen;
          await tester.pumpAndSettle();
          expectAlive();
          expectBadges('①');
        }

        await tester.tap(find.byKey(const Key('yahagi-brand-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await updateOperations(2);
        state.accept(
          kcsapiEvent('/kcsapi/api_get_member/material', [
            {'api_id': 1, 'api_value': 44444},
          ]),
        );
        await state.idle;
        notices.show(
          message: '冒烟测试任务完成',
          tone: TopNoticeTone.quest,
          duration: const Duration(minutes: 1),
        );
        final noticeId = notices.notices.single.id;
        await tester.pump(const Duration(seconds: 2));
        expectAlive();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expectBadges('②');
        expectAlive();
        expect(notices.notices.single.id, noticeId);
        notices.hide();
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('header-resource-material-1')),
            matching: find.text('44444'),
          ),
          findsOneWidget,
        );
        await _tapWorkspaceNavigationItem(tester, 'settings');
        await tester.pumpAndSettle();
        await layout.setUiDisplaySize(UiDisplaySize.compact);
        await tester.pumpAndSettle();
        await _tapWorkspaceNavigationItem(tester, 'game');
        await tester.pumpAndSettle();
        expectBadges('②');
        expectAlive();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('switching compact and minimal keeps game surface alive', (
      tester,
    ) async {
      var disposeCount = 0;
      var deactivateCount = 0;
      final layout = await _pumpMinimalShell(
        tester,
        uiSize: UiDisplaySize.compact,
        gameSurface: _LifecycleProbe(
          key: const Key('minimal-switch-game-surface'),
          onDispose: () => disposeCount++,
          onDeactivate: () => deactivateCount++,
        ),
      );
      final gameSurface = find.byKey(const Key('minimal-switch-game-surface'));
      final originalElement = tester.element(gameSurface);
      expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);

      for (final size in [
        UiDisplaySize.minimal,
        UiDisplaySize.compact,
        UiDisplaySize.minimal,
      ]) {
        await layout.setUiDisplaySize(size);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
        expect(disposeCount, 0);
        expect(deactivateCount, 0);
        expect(tester.element(gameSurface), same(originalElement));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('quest notice covers top resources and restores their state', (
      tester,
    ) async {
      await _pumpMinimalShell(tester);
      final panel = find.byKey(const Key('workspace-information-panel'));
      final slot = find.byType(QuestCompletionHeaderSlot);
      final resource = find.byKey(const Key('header-resource-material-1'));
      final originalResource = tester.element(resource);
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find
                .descendant(of: slot, matching: find.byType(AnimatedOpacity))
                .first,
          )
          .opacity;
      expect(opacity(), 1);
      QuestCompletionDrawerHost.show(
        tester.element(panel),
        '任务完成',
        tone: TopNoticeTone.quest,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: slot,
          matching: find.byKey(const Key('quest-completion-drawer')),
        ),
        findsOneWidget,
      );
      expect(opacity(), 0);
      expect(tester.element(resource), same(originalResource));
      QuestCompletionDrawerHost.hide(tester.element(panel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quest-completion-drawer')), findsNothing);
      expect(opacity(), 1);
      expect(tester.element(resource), same(originalResource));
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal top bar shows resources above the game and panel', (
      tester,
    ) async {
      const corners = MethodChannel(displayCornersChannelName);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        corners,
        (_) async => <String, Object>{
          'topLeft': 55,
          'topRight': 40,
          'bottomLeft': 24,
          'bottomRight': 24,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(corners, null));
      final layout = await _pumpMinimalShell(tester);
      final navItem = find.byKey(const Key('workspace-nav-fleet'));
      final menuTop = tester.getTopLeft(navItem).dy;
      await layout.setMinimalResourcePosition(MinimalResourcePosition.topBar);
      await tester.pumpAndSettle();

      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(
        find.byKey(const Key('header-resource-material-1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
      expect(
        find.byKey(const Key('information-panel-resources')),
        findsNothing,
      );
      expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
      // 资源位置的旧保存值不改变页头下方的导航位置。
      expect(tester.getTopLeft(navItem).dy, menuTop);
      // 保留品牌入口后，资源排在品牌右侧，远端仍让开圆弧。
      final list = tester.getRect(
        find.byKey(const Key('header-resource-list')),
      );
      expect(
        list.left,
        greaterThan(
          tester.getRect(find.byKey(const Key('yahagi-brand-button'))).right,
        ),
      );
      expect(
        list.right,
        lessThanOrEqualTo(_phoneLandscape.width - cornerInsetAt(40, 10.5)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal top bar takes quest notices in the header', (
      tester,
    ) async {
      final layout = await _pumpMinimalShell(tester);
      await layout.setMinimalResourcePosition(MinimalResourcePosition.topBar);
      await tester.pumpAndSettle();
      final panel = find.byKey(const Key('workspace-information-panel'));

      QuestCompletionDrawerHost.show(
        tester.element(panel),
        '任务完成',
        tone: TopNoticeTone.quest,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quest-completion-drawer')), findsOneWidget);
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(const Key('quest-completion-drawer')),
        ),
        findsNothing,
      );
      QuestCompletionDrawerHost.hide(tester.element(panel));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'toggling minimal resource position keeps header game and refits',
      (tester) async {
        var disposeCount = 0;
        var deactivateCount = 0;
        final browserPort = _NoopBrowserPort();
        final layout = await _pumpMinimalShell(
          tester,
          browserPort: browserPort,
          gameSurface: _LifecycleProbe(
            key: const Key('minimal-top-bar-game-surface'),
            onDispose: () => disposeCount++,
            onDeactivate: () => deactivateCount++,
          ),
        );
        final gameSurface = find.byKey(
          const Key('minimal-top-bar-game-surface'),
        );
        final originalElement = tester.element(gameSurface);
        final panelTop = tester
            .getTopLeft(find.byKey(const Key('workspace-information-panel')))
            .dy;

        for (final position in [
          MinimalResourcePosition.topBar,
          MinimalResourcePosition.panel,
          MinimalResourcePosition.topBar,
        ]) {
          final fitCalls = browserPort.fitGameScreenCalls;
          await layout.setMinimalResourcePosition(position);
          await tester.pumpAndSettle();
          expect(browserPort.fitGameScreenCalls, greaterThan(fitCalls));
          expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
          expect(
            tester
                .getTopLeft(
                  find.byKey(const Key('workspace-information-panel')),
                )
                .dy,
            panelTop,
          );
          expect(disposeCount, 0);
          expect(deactivateCount, 0);
          expect(tester.element(gameSurface), same(originalElement));
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('minimal top bar keeps the rail still across workspaces', (
      tester,
    ) async {
      final layout = await _pumpMinimalShell(tester);
      await layout.setMinimalResourcePosition(MinimalResourcePosition.topBar);
      await tester.pumpAndSettle();
      final navItem = find.byKey(const Key('workspace-nav-fleet'));
      final gameNavTop = tester.getTopLeft(navItem).dy;
      await tester.tap(navItem);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('yahagi-brand-button')), findsOneWidget);
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
      expect(tester.getTopLeft(navItem).dy, gameNavTop);
      expect(tester.takeException(), isNull);
    });

    const surfaceProbe = Key('minimal-game-surface-probe');
    Size surfaceSize(WidgetTester tester) =>
        tester.getSize(find.byKey(surfaceProbe, skipOffstage: false));

    testWidgets('minimal keeps the game size while another workspace shows', (
      tester,
    ) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      tester.view.padding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      final layout = await _pumpMinimalShell(
        tester,
        gameSurface: const ColoredBox(key: surfaceProbe, color: Colors.black),
      );
      // 0.75 让游戏受高度限制，导航时仍保持同一块游戏几何。
      await layout.setAutoZoom(false);
      await layout.setGameAreaRatio(0.75);
      await tester.pumpAndSettle();
      final initial = surfaceSize(tester);

      await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
      await tester.pumpAndSettle();
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(surfaceSize(tester), initial);

      await tester.tap(find.byKey(const Key('workspace-nav-game')));
      await tester.pumpAndSettle();
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(surfaceSize(tester), initial);
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal refits the game when the window changed elsewhere', (
      tester,
    ) async {
      final browserPort = _NoopBrowserPort();
      final layout = await _pumpMinimalShell(
        tester,
        browserPort: browserPort,
        gameSurface: const ColoredBox(key: surfaceProbe, color: Colors.black),
      );
      await layout.setAutoZoom(false);
      await layout.setGameAreaRatio(0.75);
      await tester.pumpAndSettle();
      final initial = surfaceSize(tester);

      await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(915, 412);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(surfaceSize(tester), initial);
      final fitCalls = browserPort.fitGameScreenCalls;

      await tester.tap(find.byKey(const Key('workspace-nav-game')));
      await tester.pumpAndSettle();
      expect(surfaceSize(tester), isNot(initial));
      expect(browserPort.fitGameScreenCalls, greaterThan(fitCalls));
      expect(tester.takeException(), isNull);
    });

    GameSurfaceViewport viewport(WidgetTester tester) =>
        tester.widget<GameSurfaceViewport>(
          find.byType(GameSurfaceViewport, skipOffstage: false),
        );

    testWidgets('minimal game reserves the bottom inset only above it', (
      tester,
    ) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      tester.view.padding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      final layout = await _pumpMinimalShell(tester);
      expect(viewport(tester).centerAboveBottomInset, isTrue);

      // 横屏下「上方」导航栏排在游戏列下面，游戏不贴屏幕底边。
      await layout.setWorkspaceMenuPosition('top');
      await tester.pumpAndSettle();
      expect(viewport(tester).centerAboveBottomInset, isFalse);

      await layout.setWorkspaceMenuPosition('bottom');
      await tester.pumpAndSettle();
      expect(viewport(tester).centerAboveBottomInset, isFalse);
      expect(tester.takeException(), isNull);
    });

    Future<void> expectResourcesInHeader(
      WidgetTester tester, {
      String? reason,
    }) async {
      expect(
        _headerHeight(tester),
        closeTo(_minimalHeaderHeight, .001),
        reason: reason,
      );
      expect(
        find.byKey(const Key('information-panel-resources')),
        findsNothing,
        reason: reason,
      );
      expect(
        find.byKey(const Key('minimal-bottom-resource-bar')),
        findsNothing,
        reason: reason,
      );
      final resource = find.byKey(const Key('header-resource-material-1'));
      final resourceList = find.byKey(const Key('header-resource-list'));
      expect(resourceList, findsOneWidget, reason: reason);
      await tester.dragUntilVisible(
        resource,
        resourceList,
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      expect(resource, findsOneWidget, reason: reason);
      expect(
        find.descendant(
          of: find.byType(QuestCompletionHeaderSlot),
          matching: resource,
        ),
        findsOneWidget,
        reason: reason,
      );
    }

    for (final side in const ['left', 'right']) {
      testWidgets('minimal 807x600 keeps one navigation rail ($side)', (
        tester,
      ) async {
        var disposals = 0;
        var deactivations = 0;
        final browser = _NoopBrowserPort();
        const probeKey = Key('minimal-navigation-boundary-game');
        final layout = await _pumpMinimalShell(
          tester,
          size: const Size(800, 500),
          browserPort: browser,
          gameSurface: _LifecycleProbe(
            key: probeKey,
            onDispose: () => disposals++,
            onDeactivate: () => deactivations++,
          ),
        );
        await layout.setWorkspaceMenuPosition(side);
        await tester.pumpAndSettle();
        final originalGame = tester.element(find.byKey(probeKey));
        final originalReloads = browser.reloadCalls;
        expect(find.byType(WorkspaceNavigation), findsOneWidget);

        // The full window is below the 1.35 boundary, while the workspace
        // after reserving the compact header and rail is above it.
        for (final size in const [Size(807, 600), Size(800, 500)]) {
          tester.view.physicalSize = size;
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(tester.element(find.byKey(probeKey)), same(originalGame));
          expect(disposals, 0);
          expect(deactivations, 0);
          expect(browser.reloadCalls, originalReloads);
          expect(find.byType(WorkspaceNavigation), findsOneWidget);
          final sidebar = find.byKey(const Key('workspace-navigation-sidebar'));
          expect(sidebar, findsOneWidget);
          expect(
            tester.getRect(sidebar).top,
            closeTo(_minimalHeaderHeight, .001),
          );
          expect(
            tester.getRect(sidebar).height,
            closeTo(size.height - _minimalHeaderHeight, .001),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets(
      'minimal near-square window keeps header and resource position',
      (tester) async {
        tester.view.viewPadding = const FakeViewPadding(bottom: 20);
        tester.view.padding = const FakeViewPadding(bottom: 20);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        // 扣掉等比放大的侧栏和顶栏后，实际工作区仍为横排。
        await _pumpMinimalShell(tester, size: const Size(770, 560));

        await expectResourcesInHeader(tester);
        expect(find.byKey(const Key('minimal-menu-button')), findsNothing);
        // 常驻顶栏后的工作区仍按实际宽高选择游戏方向。
        expect(viewport(tester).isLandscape, isTrue);
        expect(viewport(tester).centerAboveBottomInset, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('minimal shell follows the workspace orientation near 1.35', (
      tester,
    ) async {
      // 跨过旧的顶栏隐藏阈值时，资源始终保留在顶部。
      await _pumpMinimalShell(tester, size: const Size(757, 560));
      for (final width in const [757.0, 790.0]) {
        tester.view.physicalSize = Size(width, 560);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await expectResourcesInHeader(tester, reason: '$width');
        expect(viewport(tester).isLandscape, isTrue, reason: '$width');
        expect(tester.takeException(), isNull, reason: '$width');
      }

      tester.view.physicalSize = const Size(791, 560);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await expectResourcesInHeader(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('workspace-information-panel')),
          matching: find.byKey(const Key('information-panel-resources')),
        ),
        findsNothing,
      );
      expect(viewport(tester).isLandscape, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal near-square menu move retains the header and refits', (
      tester,
    ) async {
      final browserPort = _NoopBrowserPort();
      final layout = await _pumpMinimalShell(
        tester,
        size: const Size(770, 560),
        browserPort: browserPort,
      );
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));

      // 导航位置会改变游戏空间，但顶栏始终保持。
      final fitCalls = browserPort.fitGameScreenCalls;
      await layout.setWorkspaceMenuPosition('bottom');
      await tester.pumpAndSettle();
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(browserPort.fitGameScreenCalls, greaterThan(fitCalls));
      expect(tester.takeException(), isNull);

      final fitCallsBack = browserPort.fitGameScreenCalls;
      await layout.setWorkspaceMenuPosition('left');
      await tester.pumpAndSettle();
      expect(_headerHeight(tester), closeTo(_minimalHeaderHeight, .001));
      expect(browserPort.fitGameScreenCalls, greaterThan(fitCallsBack));
      expect(tester.takeException(), isNull);
    });

    testWidgets('minimal bottom navigation clears the gesture area', (
      tester,
    ) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      tester.view.padding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      final layout = await _pumpMinimalShell(tester);
      final screenHeight = _phoneLandscape.height;
      final navItem = find.byKey(const Key('workspace-nav-fleet'));

      for (final position in const ['bottom', 'top']) {
        await layout.setWorkspaceMenuPosition(position);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(navItem).bottom,
          lessThanOrEqualTo(screenHeight - 20),
          reason: position,
        );
        expect(tester.takeException(), isNull, reason: position);
      }

      await layout.setWorkspaceMenuPosition('bottom');
      await tester.tap(navItem);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(navItem).bottom,
        lessThanOrEqualTo(screenHeight - 20),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact bottom navigation keeps its height', (tester) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 20);
      tester.view.padding = const FakeViewPadding(bottom: 20);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      final layout = await _pumpMinimalShell(
        tester,
        uiSize: UiDisplaySize.compact,
      );
      await layout.setWorkspaceMenuPosition('bottom');
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(find.byKey(const Key('workspace-navigation-sidebar')))
            .height,
        41,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching compact and minimal keeps info card state', (
      tester,
    ) async {
      final gameState = GameStateController(
        reducer: _RepairNavigationReducer(),
      );
      gameState.accept(
        CapturedApiEvent(
          path: '/repair-navigation-test',
          responseBody: '{}',
          source: CaptureSource.manual,
          capturedAt: DateTime.utc(2026, 8, 7),
        ),
      );
      await gameState.idle;
      final layout = await _pumpMinimalShell(
        tester,
        uiSize: UiDisplaySize.compact,
        gameState: gameState,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fleet-summary-selector-2')));
      await tester.pumpAndSettle();
      final card = find.byType(FleetSummaryCard);
      final state = tester.state(card);

      for (final size in [UiDisplaySize.minimal, UiDisplaySize.compact]) {
        await layout.setUiDisplaySize(size);
        await tester.pumpAndSettle();
        expect(tester.state(card), same(state), reason: '$size');
        expect(tester.takeException(), isNull);
      }
    });

    group('fixed header ignores legacy resource placement', () {
      const probe = Key('fixed-header-legacy-game');
      Rect gameRect(WidgetTester tester) =>
          tester.getRect(find.byKey(probe, skipOffstage: false));
      Rect gameColumn(WidgetTester tester) =>
          tester.getRect(find.byType(GameSurfaceViewport, skipOffstage: false));
      Finder headerResource() => find.descendant(
        of: find.byType(QuestCompletionHeaderSlot),
        matching: find.byKey(const Key('header-resource-material-1')),
      );
      void useBottomInset(WidgetTester tester, double bottom) {
        tester.view.viewPadding = FakeViewPadding(bottom: bottom);
        tester.view.padding = FakeViewPadding(bottom: bottom);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
      }

      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final inset in [0.0, 16.0, 21.0, 24.0]) {
          testWidgets(
            'legacy positions preserve the game and top resources at inset $inset',
            variant: TargetPlatformVariant.only(platform),
            (tester) async {
              useBottomInset(tester, inset);
              final layout = await _pumpMinimalShell(
                tester,
                gameSurface: const ColoredBox(key: probe, color: Colors.black),
              );
              await layout.setAutoZoom(false);
              await layout.setGameAreaRatio(0.75);
              await tester.pumpAndSettle();
              final initialGame = gameRect(tester);
              final initialColumn = gameColumn(tester);
              final initialPadding = panelBottomPadding(tester);
              for (final position in MinimalResourcePosition.values) {
                await layout.setMinimalResourcePosition(position);
                await tester.pumpAndSettle();
                await expectResourcesInHeader(tester, reason: '$position');
                expect(headerResource().hitTestable(), findsOneWidget);
                expect(gameRect(tester), initialGame);
                expect(gameColumn(tester), initialColumn);
                expect(panelBottomPadding(tester), initialPadding);
                final game = gameRect(tester);
                final column = gameColumn(tester);
                expect(column.top, closeTo(_minimalHeaderHeight, .001));
                expect(game.top, greaterThanOrEqualTo(column.top));
                expect(
                  game.bottom,
                  lessThanOrEqualTo(column.bottom - inset + .01),
                );
                expect(game.width / game.height, closeTo(1200 / 720, .001));
                expect(tester.takeException(), isNull);
              }
            },
          );
        }
      }

      testWidgets('top resources remain editable with a legacy bottom value', (
        tester,
      ) async {
        final layout = await _pumpMinimalShell(tester);
        await layout.setMinimalResourcePosition(
          MinimalResourcePosition.bottomBar,
        );
        await layout.setWorkspaceMenuPosition('right');
        await tester.pumpAndSettle();
        await tester.longPress(headerResource());
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(QuestCompletionHeaderSlot),
            matching: find.byKey(const Key('header-resource-edit-mode')),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('minimal-bottom-resource-bar')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('top resource long-press respects the ui lock', (
        tester,
      ) async {
        final layout = await _pumpMinimalShell(tester);
        await layout.setMinimalResourcePosition(
          MinimalResourcePosition.bottomBar,
        );
        await layout.setUiLocked(true);
        await tester.pumpAndSettle();
        await tester.longPress(headerResource());
        await tester.pump();
        expect(
          find.byKey(const Key('header-resource-edit-mode')),
          findsNothing,
        );
        expect(find.text('界面已锁定，布局自定义已禁用，功能切换不受影响'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('legacy bottom value keeps the game size across workspaces', (
        tester,
      ) async {
        final layout = await _pumpMinimalShell(
          tester,
          gameSurface: const ColoredBox(key: probe, color: Colors.black),
        );
        await layout.setAutoZoom(false);
        await layout.setGameAreaRatio(0.75);
        await layout.setMinimalResourcePosition(
          MinimalResourcePosition.bottomBar,
        );
        await tester.pumpAndSettle();
        final initial = gameRect(tester).size;
        final original = tester.element(find.byKey(probe));
        await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
        await tester.pumpAndSettle();
        expect(headerResource(), findsNothing);
        expect(gameRect(tester).size, initial);
        await tester.tap(find.byKey(const Key('workspace-nav-game')));
        await tester.pumpAndSettle();
        await expectResourcesInHeader(tester);
        expect(gameRect(tester).size, initial);
        expect(tester.element(find.byKey(probe)), same(original));
        expect(tester.takeException(), isNull);
      });

      testWidgets('horizontal navigation retains resources in the top header', (
        tester,
      ) async {
        useBottomInset(tester, 21);
        final layout = await _pumpMinimalShell(tester);
        await layout.setMinimalResourcePosition(
          MinimalResourcePosition.bottomBar,
        );
        for (final position in ['bottom', 'top']) {
          await layout.setWorkspaceMenuPosition(position);
          await tester.pumpAndSettle();
          await expectResourcesInHeader(tester, reason: position);
        }
        expect(tester.takeException(), isNull);
      });

      for (final size in [UiDisplaySize.compact, UiDisplaySize.normal]) {
        testWidgets('$size ignores legacy resource positions', (tester) async {
          useBottomInset(tester, 21);
          final layout = await _pumpMinimalShell(
            tester,
            uiSize: size,
            gameSurface: const ColoredBox(key: probe, color: Colors.black),
          );
          final before = gameRect(tester);
          final header = _headerHeight(tester);
          for (final position in MinimalResourcePosition.values) {
            await layout.setMinimalResourcePosition(position);
            await tester.pumpAndSettle();
            expect(headerResource(), findsOneWidget);
            expect(
              find.byKey(const Key('minimal-bottom-resource-bar')),
              findsNothing,
            );
            expect(
              find.byKey(const Key('information-panel-resources')),
              findsNothing,
            );
            expect(gameRect(tester), before);
            expect(_headerHeight(tester), header);
            expect(tester.takeException(), isNull);
          }
        });
      }

      for (final inset in [0.0, 21.0]) {
        testWidgets(
          'changing legacy positions preserves game element at inset $inset',
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
          (tester) async {
            useBottomInset(tester, inset);
            var disposals = 0;
            var deactivations = 0;
            final layout = await _pumpMinimalShell(
              tester,
              gameSurface: _LifecycleProbe(
                key: probe,
                onDispose: () => disposals++,
                onDeactivate: () => deactivations++,
              ),
            );
            final original = tester.element(find.byKey(probe));
            final originalRect = gameRect(tester);
            for (final position in [
              MinimalResourcePosition.bottomBar,
              MinimalResourcePosition.topBar,
              MinimalResourcePosition.bottomBar,
              MinimalResourcePosition.panel,
            ]) {
              await layout.setMinimalResourcePosition(position);
              await tester.pumpAndSettle();
              await expectResourcesInHeader(tester, reason: '$position');
              expect(disposals, 0);
              expect(deactivations, 0);
              expect(tester.element(find.byKey(probe)), same(original));
              expect(gameRect(tester), originalRect);
              expect(tester.takeException(), isNull);
            }
          },
        );

        testWidgets(
          'quest notice restores top resources with legacy bottom at inset $inset',
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
          (tester) async {
            useBottomInset(tester, inset);
            final layout = await _pumpMinimalShell(tester);
            await layout.setMinimalResourcePosition(
              MinimalResourcePosition.bottomBar,
            );
            await tester.pumpAndSettle();
            final originalResource = tester.element(headerResource());
            final panel = find.byKey(const Key('workspace-information-panel'));
            QuestCompletionDrawerHost.show(
              tester.element(panel),
              '任务完成',
              tone: TopNoticeTone.quest,
            );
            await tester.pumpAndSettle();
            final drawer = find.byKey(const Key('quest-completion-drawer'));
            expect(
              find.descendant(
                of: find.byType(QuestCompletionHeaderSlot),
                matching: drawer,
              ),
              findsOneWidget,
            );
            expect(
              tester.getRect(drawer).bottom,
              lessThanOrEqualTo(_minimalHeaderHeight),
            );
            expect(tester.element(headerResource()), same(originalResource));
            expect(
              find.byKey(const Key('minimal-bottom-resource-bar')),
              findsNothing,
            );
            QuestCompletionDrawerHost.hide(tester.element(panel));
            await tester.pumpAndSettle();
            expect(drawer, findsNothing);
            expect(headerResource().hitTestable(), findsOneWidget);
            expect(tester.element(headerResource()), same(originalResource));
            expect(tester.takeException(), isNull);
          },
        );
      }
    });
  });
}

class _LayoutAuditStateReducer extends GameStateReducer {
  _LayoutAuditStateReducer(this.localeCode);
  final String localeCode;
  bool populated = false;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) {
    if (!populated) return GameState.empty;
    final base = _HdMinimalStateReducer().reduce(state, event);
    return base.copyWith(
      masterShips: {
        for (var id = 1; id <= 8; id++)
          999000 + id: MasterShip(
            id: 999000 + id,
            name: localeCode == 'en'
                ? 'Very Long Destroyer Name Mk.II Mod.2 $id'
                : '特别长的舰娘名称排版检查改二$id',
            shipTypeId: 2,
            speed: 10,
            maxFuel: 999,
            maxAmmo: 999,
          ),
      },
      ships: {
        for (var id = 1; id <= 8; id++)
          id: OwnedShip(
            id: id,
            masterId: 999000 + id,
            level: 175,
            currentHp: 999,
            maxHp: 999,
            condition: 49,
            currentFuel: 999,
            currentAmmo: 999,
            slotIds: [for (var slot = 1; slot <= 4; slot++) id * 100 + slot],
            onSlot: const [18, 18, 18, 18],
          ),
      },
      masterSlotItems: {
        for (var slot = 1; slot <= 4; slot++)
          100 + slot: MasterSlotItem(
            id: 100 + slot,
            name: 'Audit aircraft $slot',
            antiAir: 10,
            type: const [0, 0, 6, 6],
          ),
      },
      slotItems: {
        for (var id = 1; id <= 9; id++)
          for (var slot = 1; slot <= 4; slot++)
            id * 100 + slot: OwnedSlotItem(
              id: id * 100 + slot,
              masterId: 100 + slot,
              proficiency: 7,
            ),
      },
      landBases: [
        LandBaseState(
          areaId: 6,
          baseId: 1,
          name: localeCode == 'en'
              ? 'Forward Land Based Air Squadron One'
              : '第一超长名字陆基航空基地',
          actionKind: 1,
          distanceBase: 7,
          currentHp: 200,
          maxHp: 200,
          squadrons: [
            for (var slot = 1; slot <= 4; slot++)
              LandBaseSquadronState(
                squadronId: slot,
                state: 1,
                slotItemId: 900 + slot,
                currentCount: 18,
                maxCount: 18,
              ),
          ],
        ),
      ],
    );
  }
}

class _HdMinimalStateReducer extends GameStateReducer {
  @override
  GameState reduce(GameState state, CapturedApiEvent event) => GameState(
    hasPortData: true,
    hasMasterData: true,
    masterShipTypes: const {2: MasterShipType(id: 2, name: '驱逐')},
    masterShips: {
      for (var id = 1; id <= 8; id++)
        999000 + id: MasterShip(
          id: 999000 + id,
          name: 'HD舰娘$id',
          shipTypeId: 2,
          speed: 10,
          maxFuel: 15,
          maxAmmo: 20,
        ),
    },
    ships: {
      for (var id = 1; id <= 8; id++)
        id: OwnedShip(
          id: id,
          masterId: 999000 + id,
          level: 50,
          currentHp: 20,
          maxHp: 20,
          condition: 49,
          currentFuel: 15,
          currentAmmo: 20,
        ),
    },
    fleets: [
      for (var id = 1; id <= 4; id++)
        Fleet(id: id, name: 'HD舰队$id', shipIds: [id * 2 - 1, id * 2]),
    ],
  );
}

class _RepairNavigationReducer extends GameStateReducer {
  @override
  GameState reduce(GameState state, CapturedApiEvent event) => const GameState(
    fleets: <Fleet>[
      Fleet(id: 1, name: '第一舰队'),
      Fleet(id: 2, name: '第二舰队'),
    ],
    hasPortData: true,
  );
}

class _ToolboxStateReducer extends GameStateReducer {
  @override
  GameState reduce(GameState state, CapturedApiEvent event) => const GameState(
    admiralLevel: 77,
    hasPortData: true,
    hasEquipmentInventory: true,
  );
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({
    super.key,
    required this.onDispose,
    this.onDeactivate,
  });

  final VoidCallback onDispose;
  final VoidCallback? onDeactivate;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void deactivate() {
    widget.onDeactivate?.call();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}

final class _MemoryAudioStore implements GameAudioStore {
  bool? savedMuted;
  bool? savedBackgroundPlayback;

  @override
  Future<bool?> readMuted() async => savedMuted;

  @override
  Future<void> writeMuted(bool muted) async {
    savedMuted = muted;
  }

  @override
  Future<bool?> readBackgroundPlaybackEnabled() async =>
      savedBackgroundPlayback;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {
    savedBackgroundPlayback = enabled;
  }
}

class _MemoryLayoutSettingsStore implements LayoutSettingsStore {
  double _ratio = 0.5;
  double _width = 300;
  bool _autoZoom = false;
  bool _enhancedDamagePulse = true;
  bool _workspaceMenuOnRight = false;
  List<String> _dashboardCardOrder = [
    'fleet',
    'land_base',
    'expedition',
    'repair',
    'construction',
    'quests',
    'battle',
    'pre_sortie',
  ];
  List<String> _dashboardCardCollapsed = [];
  List<String> _dashboardCardHidden = [];

  @override
  Future<double> loadGameAreaRatio() async => _ratio;

  @override
  Future<void> saveGameAreaRatio(double ratio) async => _ratio = ratio;

  @override
  Future<double> loadInformationPanelWidth() async => _width;

  @override
  Future<void> saveInformationPanelWidth(double width) async => _width = width;

  @override
  Future<bool> loadAutoZoom() async => _autoZoom;

  @override
  Future<void> saveAutoZoom(bool autoZoom) async => _autoZoom = autoZoom;

  @override
  Future<bool> loadEnhancedDamagePulse() async => _enhancedDamagePulse;

  @override
  Future<void> saveEnhancedDamagePulse(bool enabled) async {
    _enhancedDamagePulse = enabled;
  }

  @override
  Future<bool> loadWorkspaceMenuOnRight() async => _workspaceMenuOnRight;

  @override
  Future<void> saveWorkspaceMenuOnRight(bool onRight) async {
    _workspaceMenuOnRight = onRight;
  }

  @override
  Future<List<String>> loadDashboardCardOrder() async {
    return _dashboardCardOrder;
  }

  @override
  Future<void> saveDashboardCardOrder(List<String> order) async {
    _dashboardCardOrder = List<String>.from(order);
  }

  @override
  Future<List<String>> loadDashboardCardCollapsed() async {
    return _dashboardCardCollapsed;
  }

  @override
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds) async {
    _dashboardCardCollapsed = List<String>.from(collapsedIds);
  }

  @override
  Future<List<String>> loadDashboardCardHidden() async {
    return _dashboardCardHidden;
  }

  @override
  Future<void> saveDashboardCardHidden(List<String> hiddenIds) async {
    _dashboardCardHidden = List<String>.from(hiddenIds);
  }

  Future<bool> loadAutoZoomEnabled() async => false;

  Future<void> saveAutoZoomEnabled(bool value) async {}

  @override
  Future<String?> loadFontFamily() async => null;

  @override
  Future<void> saveFontFamily(String? value) async {}

  @override
  Future<String?> loadLocaleCode() async => null;

  @override
  Future<void> saveLocaleCode(String? value) async {}
}

final class _MemoryToolbarDisplayStore implements GameToolbarDisplayStore {
  GameToolbarDisplayMode? value;

  @override
  Future<GameToolbarDisplayMode?> read() async => value;

  @override
  Future<void> write(GameToolbarDisplayMode mode) async => value = mode;
}

final class _FakeScreenshotPort implements GameScreenshotPort {
  @override
  Future<String> captureWebView() async => '/pictures/yahagi-test.png';
}

final class _MemoryNetworkSettingsStore implements NetworkSettingsStore {
  NetworkSettings _settings = const NetworkSettings();

  @override
  Future<NetworkSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(NetworkSettings settings) async {
    _settings = settings;
  }
}

final class _NoopBrowserPort implements GameBrowserPort {
  int fitGameScreenCalls = 0;
  int reloadCalls = 0;

  @override
  Future<void> fitGameScreen() async {
    fitGameScreenCalls++;
  }

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> loadUri(Uri uri) async {}

  @override
  Future<void> reload() async {
    reloadCalls++;
  }

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async =>
      GameFrameReloadResult.reloaded;

  @override
  Future<void> showLocalHome() async {}

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}
}

final class _MemoryModeStore implements CaptureModeStore {
  CaptureMode? savedMode;

  @override
  Future<CaptureMode?> read() async => savedMode;

  @override
  Future<void> write(CaptureMode mode) async {
    savedMode = mode;
  }
}

class _MemoryGadgetBypassStore implements GadgetBypassStore {
  GadgetBypassSettings settings = const GadgetBypassSettings();

  @override
  Future<GadgetBypassSettings> load() async => settings;

  @override
  Future<void> save(GadgetBypassSettings settings) async {
    this.settings = settings;
  }
}

class _FakeGadgetBypassPort implements GadgetBypassPort {
  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async {
    return true;
  }

  @override
  Future<GadgetBypassStatus> status() async =>
      const GadgetBypassStatus(enabled: false, endpoint: '', supported: true);

  @override
  Future<bool> clearCache() async => true;

  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async {
    return const GadgetBypassDiagnoseResult(
      w00g: GadgetBypassProbe(reachable: true, elapsedMs: 1),
      endpoint: GadgetBypassProbe(reachable: true, elapsedMs: 1),
      kcsapi: GadgetBypassProbe(reachable: true, elapsedMs: 1),
    );
  }
}

final class _MemorySenkaStore implements SenkaStore {
  _MemorySenkaStore(this.state);

  SenkaState? state;

  @override
  Future<SenkaState?> load() async => state;

  @override
  Future<void> save(SenkaState state) async => this.state = state;
}

final class _FakeCapturePort implements GameCapturePort {
  _FakeCapturePort({required this.supported});

  final bool supported;
  final _controller = StreamController<CapturedApiEvent>.broadcast();

  @override
  Stream<CapturedApiEvent> get events => _controller.stream;

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => supported;

  void emit(CapturedApiEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {}

  Future<void> close() async {
    await _controller.close();
  }
}
