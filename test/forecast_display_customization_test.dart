import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/dashboard_display_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_display_size.dart';

import 'fixtures/kcsapi_fixtures.dart';

final _map = find.byKey(const Key('sortie-map-section'));
final _enemyPreview = find.byKey(const Key('official-enemy-preview'));
final _navigationFleet = find.byKey(const Key('navigation-friendly-fleets'));
final _rank = find.byKey(const Key('battle-rank-badge'));

CapturedApiEvent _navigation(int node, {required bool start}) => kcsapiEvent(
  '/kcsapi/api_req_map/${start ? 'start' : 'next'}',
  <String, Object?>{
    'api_maparea_id': 2,
    'api_mapinfo_no': 5,
    'api_no': node,
    'api_bosscell_no': 15,
    'api_event_id': 4,
    'api_event_kind': 1,
    'api_e_deck_info': <Object?>[
      <String, Object?>{
        'api_ship_ids': <int>[101, 102],
        'api_deck_type': 0,
      },
    ],
  },
  sequence: start ? 19 : 20,
  requestParams: <String, Object?>{if (start) 'api_deck_id': '1'},
);

Future<void> _settle(WidgetTester tester) async {
  // The map's current-node marker can keep animating after the UI is ready.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump();
}

Future<void> _toggleSection(WidgetTester tester, String section) async {
  await tester.longPress(find.byKey(const Key('dashboard-tab-battle')));
  await _settle(tester);
  final gear = find.byKey(const Key('battle-display-settings-button'));
  expect(gear, findsOneWidget);
  await tester.tap(gear);
  await _settle(tester);

  final option = find.byKey(Key('battle-display-$section'));
  expect(option, findsOneWidget);
  await tester.tap(option);
  await _settle(tester);

  await tester.tap(find.byKey(const Key('battle-display-close')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('dashboard-edit-done')));
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FcdMapDataset maps;
  setUpAll(() async {
    maps = FcdMapDataset.parse(
      await rootBundle.loadString('assets/data/fcd/map.json'),
    );
  });

  for (final mode in ['detailed', 'compact']) {
    testWidgets('Forecast display toggles work independently in $mode mode', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final timersWereDisabled = GameStateController.disableTimerForTest;
      GameStateController.disableTimerForTest = true;
      addTearDown(
        () => GameStateController.disableTimerForTest = timersWereDisabled,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      await layout.setLocaleCode('zh');
      await layout.setUiDisplaySize(UiDisplaySize.normal);
      await layout.setHdEnabled(false);
      await layout.setDashboardCardOrder(['battle']);
      await layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
      final game = GameStateController();
      final battle = BattleController(
        gameState: () => game.state,
        waitForGameState: () => game.idle,
        nodeLabelResolver: maps,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      final browser = GameBrowserController();
      final toolbar = GameToolbarController();
      final capture = GameCaptureController();
      final status = PrototypeStatusController();
      final network = NetworkSettingsController(
        store: SharedPreferencesNetworkSettingsStore(),
      );
      final bypass = GadgetBypassController(
        store: SharedPreferencesGadgetBypassStore(),
        port: MethodChannelGadgetBypassPort(),
      );
      final safety = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final captureMode = await CaptureModeController.load(
        SharedPreferencesCaptureModeStore(),
      );
      final audio = await GameAudioController.load(
        SharedPreferencesGameAudioStore(),
      );
      for (final controller in <ChangeNotifier>[
        layout,
        game,
        battle,
        browser,
        toolbar,
        capture,
        status,
        network,
        bypass,
        safety,
        display,
        captureMode,
        audio,
      ]) {
        addTearDown(controller.dispose);
      }

      Future<void> send(CapturedApiEvent event) async {
        game.accept(event);
        battle.accept(event);
        await game.idle;
        await battle.idle;
      }

      await send(start2Event);
      await send(portEvent);
      await send(_navigation(3, start: true));
      await tester.pumpWidget(
        YahagiApp(
          layoutSettingsController: layout,
          networkSettingsController: network,
          gadgetBypassController: bypass,
          safetySettingsController: safety,
          displayModeController: display,
          controller: status,
          browserController: browser,
          captureModeController: captureMode,
          gameCaptureController: capture,
          gameStateController: game,
          battleController: battle,
          audioController: audio,
          toolbarController: toolbar,
          gameSurface: const SizedBox(),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byKey(Key('battle-mode-$mode')));
      await _settle(tester);

      expect(_map, findsOneWidget);
      expect(_enemyPreview, findsOneWidget);
      expect(_navigationFleet, findsOneWidget);

      await _toggleSection(tester, 'sortieMap');
      expect(_map, findsNothing);
      expect(_enemyPreview, findsOneWidget);
      expect(_navigationFleet, findsOneWidget);

      await _toggleSection(tester, 'enemyPreview');
      expect(_map, findsNothing);
      expect(_enemyPreview, findsNothing);
      expect(_navigationFleet, findsOneWidget);

      await _toggleSection(tester, 'predictionResult');
      expect(_map, findsNothing);
      expect(_enemyPreview, findsNothing);
      expect(_navigationFleet, findsNothing);

      await send(_navigation(5, start: false));
      await _settle(tester);
      expect(battle.sortieMapProgress?.routeIds, [3, 5]);
      expect(battle.current?.enemyPreviewShips, isNotEmpty);
      expect(_map, findsNothing);
      expect(_enemyPreview, findsNothing);

      await _toggleSection(tester, 'sortieMap');
      expect(_map, findsOneWidget);
      expect(
        find.descendant(of: _map, matching: find.text('2-5 · 当前 E')),
        findsOneWidget,
      );
      expect(_enemyPreview, findsNothing);
      expect(_navigationFleet, findsNothing);

      await _toggleSection(tester, 'enemyPreview');
      expect(_map, findsOneWidget);
      expect(_enemyPreview, findsOneWidget);
      expect(_navigationFleet, findsNothing);

      await send(dayBattleEvent);
      await send(battleResultEvent);
      await _settle(tester);
      expect(battle.current?.displayStage, BattleDisplayStage.result);
      expect(battle.records.single.enemyFleetName, 'Test Enemy Fleet');
      expect(_map, findsOneWidget);
      final resultFleet = find.byKey(
        Key(
          mode == 'compact'
              ? 'compact-fleet-grid'
              : 'battle-side-by-side-fleets',
        ),
      );
      expect(_rank, findsNothing);
      expect(resultFleet, findsNothing);

      await _toggleSection(tester, 'predictionResult');
      expect(_map, findsOneWidget);
      expect(_rank, findsOneWidget);
      expect(resultFleet, findsOneWidget);
      expect(find.text('Test Enemy Fleet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
