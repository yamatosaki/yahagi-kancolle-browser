import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_decoder.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';
import 'package:yahagi_kancolle_browser/src/notice/debuff_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

import '../fixtures/kcsapi_fixtures.dart';

void main() {
  final dialog = find.byKey(const Key('new-ship-alert-dialog'));

  testWidgets('real app presents a server debuff cue in the default dialog', (
    tester,
  ) async {
    final harness = await _mountApp(tester);
    await harness.send(
      kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
        'api_destruction_battle': <String, Object?>{'api_m2': 1},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debuff-reminder-dialog')), findsOneWidget);
    expect(find.text('削甲提醒'), findsOneWidget);
    expect(find.textContaining('基地防空'), findsOneWidget);
    expect(dialog, findsNothing);
    expect(harness.vibrations.length, 1);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(harness.debuff.currentAlert, isNull);
  });

  testWidgets('real app switches to top notices without losing ship alerts', (
    tester,
  ) async {
    final harness = await _mountApp(tester);
    await harness.notifications.setDebuffReminderStyle(
      DebuffReminderStyle.topNotice,
    );
    await harness.send(
      kcsapiEvent('/kcsapi/api_req_sortie/battleresult', <String, Object?>{
        'api_m2': 1,
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debuff-reminder-dialog')), findsNothing);
    expect(find.textContaining('战斗结算'), findsOneWidget);
    expect(harness.vibrations.length, 1);
    await harness.send(_reward(sequence: 2));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    expect(find.byKey(const Key('debuff-reminder-dialog')), findsNothing);
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
  });

  for (final changeAccount in [false, true]) {
    testWidgets(
      'simultaneous ship and debuff dialogs ${changeAccount ? 'clear on account change' : 'can both be acknowledged'}',
      (tester) async {
        final harness = await _mountApp(tester);
        await harness.send(_reward(sequence: 1));
        await harness.send(
          kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
            'api_destruction_battle': <String, Object?>{'api_m2': 1},
          }, sequence: 2),
        );
        await tester.pumpAndSettle();
        final debuffDialog = find.byKey(const Key('debuff-reminder-dialog'));
        expect(debuffDialog, findsOneWidget);
        expect(dialog, findsOneWidget);
        expect(harness.vibrations, hasLength(1));
        if (changeAccount) {
          await harness.send(_accountTransition('basic', sequence: 3));
          await tester.pumpAndSettle();
          expect(debuffDialog, findsNothing);
          expect(dialog, findsNothing);
          expect(harness.debuff.alerts, isEmpty);
        } else {
          await tester.tap(
            find.descendant(
              of: debuffDialog,
              matching: find.byType(FilledButton),
            ),
          );
          await tester.pumpAndSettle();
          expect(debuffDialog, findsNothing);
          expect(dialog, findsOneWidget);
          await tester.tap(
            find.descendant(of: dialog, matching: find.byType(FilledButton)),
          );
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('English dashboard headers fit before and during a ship dialog', (
    tester,
  ) async {
    // This real shell layout previously left only 84 px for the battle header.
    final harness = await _mountApp(tester, localeCode: 'en');
    expect(find.text('Battle prediction'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.send(_reward(sequence: 1));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    expect(find.text('New unowned ship found'), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('三日月')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final transition in <String>['start2', 'basic', 'port']) {
    testWidgets('$transition cancels a ship dialog before its first frame', (
      tester,
    ) async {
      final harness = await _mountApp(tester);
      await harness.send(_reward(sequence: 10));
      expect(harness.reminder.currentAlert, isNotNull);

      // Do not pump: the shell has only queued its post-frame dialog callback.
      await harness.send(_accountTransition(transition, sequence: 11));
      expect(harness.reminder.currentAlert, isNull);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
    });

    testWidgets('$transition closes an already visible ship dialog', (
      tester,
    ) async {
      final harness = await _mountApp(tester);
      await harness.send(_reward(sequence: 20));
      expect(harness.reminder.currentAlert, isNotNull);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);

      await harness.send(_accountTransition(transition, sequence: 21));
      expect(harness.reminder.currentAlert, isNull);
      await tester.pumpAndSettle();

      expect(dialog, findsNothing);
    });
  }

  testWidgets('new account can show and acknowledge its own ship dialog', (
    tester,
  ) async {
    final harness = await _mountApp(tester);
    await harness.send(_reward(sequence: 30));
    expect(harness.reminder.currentAlert, isNotNull);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);

    await harness.send(_accountTransition('basic', sequence: 31));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    await harness.send(_reward(sequence: 32, masterId: 9));
    expect(harness.reminder.currentAlert, isNotNull);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('吹雪')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('三日月')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(harness.reminder.currentAlert, isNull);
  });
}

Future<_Harness> _mountApp(
  WidgetTester tester, {
  String localeCode = 'zh',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 700);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final game = GameStateController(gameStateStore: _SeededGameStateStore());
  await game.initialize();
  final reminder = NewShipReminderController(
    stateProvider: () => game.state,
    store: NewShipReminderStore(await SharedPreferences.getInstance()),
    waitForGameState: () => game.idle,
    onPublish: (_) {},
  );
  final battle = BattleController(gameState: () => game.state);
  final layout = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  await layout.setLocaleCode(localeCode);
  final safety = await SafetySettingsController.load(
    MemorySafetySettingsStore(),
  );
  final display = await DisplayModeController.load(MemoryDisplayModeStore());
  final captureMode = await CaptureModeController.load(
    SharedPreferencesCaptureModeStore(),
  );
  final audio = await GameAudioController.load(
    SharedPreferencesGameAudioStore(),
  );
  final network = NetworkSettingsController(
    store: SharedPreferencesNetworkSettingsStore(),
  );
  final gadget = GadgetBypassController(
    store: SharedPreferencesGadgetBypassStore(),
    port: _NoopGadgetBypassPort(),
  );
  final status = PrototypeStatusController();
  final browser = GameBrowserController(port: _NoopBrowserPort());
  final toolbar = GameToolbarController();
  final capture = GameCaptureController();
  final accountSession = AccountSession(initialMemberId: 1001);
  final vibrations = <int>[];
  final debuff = DebuffReminderController(
    accountSession: accountSession,
    vibrate: () async => vibrations.add(1),
  );
  final notifications = NotificationSettingsController();
  await notifications.initialize();
  final headerNotices = TopNoticeController();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (final controller in <ChangeNotifier>[
      reminder,
      debuff,
      accountSession,
      notifications,
      headerNotices,
      battle,
      layout,
      safety,
      display,
      captureMode,
      audio,
      network,
      gadget,
      status,
      browser,
      toolbar,
      capture,
      game,
    ]) {
      controller.dispose();
    }
  });
  await tester.pumpWidget(
    YahagiApp(
      layoutSettingsController: layout,
      networkSettingsController: network,
      gadgetBypassController: gadget,
      safetySettingsController: safety,
      displayModeController: display,
      controller: status,
      browserController: browser,
      captureModeController: captureMode,
      audioController: audio,
      toolbarController: toolbar,
      gameCaptureController: capture,
      gameStateController: game,
      battleController: battle,
      newShipReminderController: reminder,
      debuffReminderController: debuff,
      notificationSettingsController: notifications,
      headerNoticeController: headerNotices,
      gameSurface: const ColoredBox(color: Colors.black),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(
    reminder,
    GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[accountSession, game, reminder, debuff],
      decodeEnvelope: (body) async => GameApiDecoder.decodeEnvelope(body),
      settleGameState: () => game.idle,
    ),
    debuff,
    notifications,
    vibrations,
  );
}

class _Harness {
  _Harness(
    this.reminder,
    this.pipeline,
    this.debuff,
    this.notifications,
    this.vibrations,
  );
  final NewShipReminderController reminder;
  final GameApiEventPipeline pipeline;
  final DebuffReminderController debuff;
  final NotificationSettingsController notifications;
  final List<int> vibrations;

  Future<void> send(CapturedApiEvent event) async {
    pipeline.add(event);
    await pipeline.idle;
  }
}

CapturedApiEvent _reward({required int sequence, int masterId = 7}) =>
    kcsapiEvent('/kcsapi/api_req_quest/clearitemget', <String, Object?>{
      'api_bounus': <Object?>[
        <String, Object?>{
          'api_type': 11,
          'api_count': 1,
          'api_item': <String, Object?>{'api_ship_id': masterId},
        },
      ],
    }, sequence: sequence);

CapturedApiEvent _accountTransition(String type, {required int sequence}) {
  if (type == 'start2') {
    return kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
      'api_mst_ship': <Object?>[],
    }, sequence: sequence);
  }
  final basic = <String, Object?>{'api_member_id': '2002', 'api_level': 1};
  return kcsapiEvent(
    type == 'port' ? '/kcsapi/api_port/port' : '/kcsapi/api_get_member/basic',
    type == 'port'
        ? <String, Object?>{'api_basic': basic, 'api_ship': <Object?>[]}
        : basic,
    sequence: sequence,
  );
}

class _SeededGameStateStore extends GameStateStore {
  @override
  Future<GameState> load() async => const GameState(
    memberId: 1001,
    hasMasterData: true,
    hasPortData: true,
    masterShips: <int, MasterShip>{
      7: MasterShip(id: 7, name: '三日月', shipTypeId: 2, sortNo: 7),
      9: MasterShip(id: 9, name: '吹雪', shipTypeId: 2, sortNo: 9),
    },
  );

  @override
  void save(GameState state) {}
}

final class _NoopBrowserPort implements GameBrowserPort {
  @override
  Future<void> fitGameScreen() async {}
  @override
  Future<bool> canGoBack() async => false;
  @override
  Future<void> goBack() async {}
  @override
  Future<void> loadUri(Uri uri) async {}
  @override
  Future<void> reload() async {}
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

class _NoopGadgetBypassPort implements GadgetBypassPort {
  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async => true;
  @override
  Future<GadgetBypassStatus> status() async =>
      const GadgetBypassStatus(enabled: false, endpoint: '', supported: true);
  @override
  Future<bool> clearCache() async => true;
  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async =>
      const GadgetBypassDiagnoseResult(
        w00g: GadgetBypassProbe(reachable: true, elapsedMs: 1),
        endpoint: GadgetBypassProbe(reachable: true, elapsedMs: 1),
        kcsapi: GadgetBypassProbe(reachable: true, elapsedMs: 1),
      );
}
