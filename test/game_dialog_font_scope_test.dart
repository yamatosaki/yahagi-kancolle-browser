import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_style.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_feedback.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';
import 'package:yahagi_kancolle_browser/src/notice/debuff_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/notice/debuff_reminder_feedback.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/theme/custom_font_controller.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('app reminder owners share the selected native dialog font', (
    tester,
  ) async {
    const fontPath = '/data/user/0/test/fonts/selected.ttf';
    SharedPreferences.setMockInitialValues({
      'custom_font_selection_v1': jsonEncode({
        'id': 'a' * 64,
        'name': 'Selected test font',
        'path': fontPath,
      }),
    });
    final owned = <ChangeNotifier>[];
    T own<T extends ChangeNotifier>(T value) {
      owned.add(value);
      return value;
    }

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final controller in owned.reversed) {
        controller.dispose();
      }
    });
    final requests = <Map<Object?, Object?>>[];
    const channel = MethodChannel('app.yahagi.kancollebrowser/native_warning');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'show') {
        requests.add(Map<Object?, Object?>.from(call.arguments as Map));
        return 'acknowledge';
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final fonts = own(
      await CustomFontController.load(
        loader: (_) async {},
        port: _NoopFontPort(),
      ),
    );
    final layout = own(
      await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
        customFontController: fonts,
      ),
    );
    final game = own(GameStateController());
    final debuff = own(DebuffReminderController(vibrate: () async {}));
    debuff.accept(
      kcsapiEvent('/kcsapi/api_port/port', {
        'api_event_object': {'api_m_flag2': 1},
      }),
    );
    await debuff.idle;
    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layout,
        networkSettingsController: own(
          NetworkSettingsController(
            store: SharedPreferencesNetworkSettingsStore(),
          ),
        ),
        gadgetBypassController: own(
          GadgetBypassController(
            store: SharedPreferencesGadgetBypassStore(),
            port: MethodChannelGadgetBypassPort(),
          ),
        ),
        safetySettingsController: own(
          await SafetySettingsController.load(MemorySafetySettingsStore()),
        ),
        displayModeController: own(
          await DisplayModeController.load(MemoryDisplayModeStore()),
        ),
        gameRenderingModeController: own(
          await GameRenderingModeController.load(
            MemoryGameRenderingModeStore(),
          ),
        ),
        controller: own(PrototypeStatusController()),
        browserController: own(GameBrowserController()),
        captureModeController: own(
          await CaptureModeController.load(SharedPreferencesCaptureModeStore()),
        ),
        audioController: own(
          await GameAudioController.load(SharedPreferencesGameAudioStore()),
        ),
        toolbarController: own(GameToolbarController()),
        gameCaptureController: own(GameCaptureController()),
        gameStateController: game,
        battleController: own(BattleController(gameState: () => game.state)),
        newShipReminderController: own(
          NewShipReminderController(
            stateProvider: () => game.state,
            store: NewShipReminderStore(await SharedPreferences.getInstance()),
            onPublish: (_) {},
          ),
        ),
        debuffReminderController: debuff,
        notificationSettingsController: own(NotificationSettingsController()),
        headerNoticeController: own(TopNoticeController()),
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single['kind'], 'debuff');
    expect(
      (requests.single['presentation'] as Map)['customFontPath'],
      fontPath,
    );
    for (final owner in [
      find.byType(DebuffReminderFeedback),
      find.byType(NewShipReminderFeedback),
      find.byType(BattleResultWarningOverlay),
    ]) {
      expect(owner, findsOneWidget);
      expect(
        resolveGameDialogPresentation(tester.element(owner))['customFontPath'],
        fontPath,
      );
    }
  });
}

class _NoopFontPort implements CustomFontPort {
  @override
  Future<CustomFontDescriptor?> importFont() async => null;

  @override
  Future<void> removeFont(String id) async {}
}
