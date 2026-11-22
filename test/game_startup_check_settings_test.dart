import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_runtime_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_startup_check_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/settings_page.dart';

const _switchKey = Key('settings-game-startup-check');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'startup checks default on and an explicit false survives reload',
    () async {
      final settings = await GameStartupCheckSettingsController.load();
      addTearDown(settings.dispose);
      expect(settings.enabled, isTrue);
      expect(settings.saving, isFalse);
      expect(
        GameStartupCheckSettingsController.preferenceKey,
        'game.startupCheck',
      );

      await settings.setEnabled(false);

      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      expect(preferences.getBool('game.startupCheck'), isFalse);
      final restored = await GameStartupCheckSettingsController.load();
      addTearDown(restored.dispose);
      expect(restored.enabled, isFalse);
    },
  );

  testWidgets('a rejected write leaves the option on and can be retried', (
    tester,
  ) async {
    final platform = _PendingPreferencesStore();
    SharedPreferencesStorePlatform.instance = platform;
    final startupChecks = await GameStartupCheckSettingsController.load();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(startupChecks.dispose);
    addTearDown(layout.dispose);
    await tester.pumpWidget(
      _app(
        GameRuntimeSettingsPage(
          layoutSettingsController: layout,
          gameStartupCheckSettingsController: startupChecks,
        ),
      ),
    );
    final toggle = find.byKey(_switchKey);

    await tester.tap(toggle);
    await tester.pump();
    expect(startupChecks.saving, isTrue);
    expect(tester.widget<Switch>(toggle).onChanged, isNull);
    platform.result.complete(false);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(find.text('启动检查设置未保存，请重试。'), findsOneWidget);
    final stored = await GameStartupCheckSettingsController.load();
    addTearDown(stored.dispose);
    expect(stored.enabled, isTrue);

    platform.result = Completer<bool>()..complete(true);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(find.text('启动检查设置未保存，请重试。'), findsNothing);
  });

  testWidgets(
    'Settings shows startup checks under game runtime and performance',
    (tester) async {
      final startupChecks = await GameStartupCheckSettingsController.load();
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      final audio = await GameAudioController.load(
        SharedPreferencesGameAudioStore(),
      );
      final capture = await CaptureModeController.load(
        SharedPreferencesCaptureModeStore(),
      );
      final safety = await SafetySettingsController.load(
        SharedPreferencesSafetySettingsStore(),
      );
      final browser = GameBrowserController();
      final gameCapture = GameCaptureController();
      final gameState = GameStateController();
      final prototype = PrototypeStatusController();
      final network = NetworkSettingsController(
        store: SharedPreferencesNetworkSettingsStore(),
      );
      final gadget = GadgetBypassController(
        store: SharedPreferencesGadgetBypassStore(),
        port: MethodChannelGadgetBypassPort(),
      );
      final tab = ValueNotifier(0);
      for (final controller in <ChangeNotifier>[
        startupChecks,
        layout,
        display,
        audio,
        capture,
        safety,
        browser,
        gameCapture,
        gameState,
        prototype,
        network,
        gadget,
        tab,
      ]) {
        addTearDown(controller.dispose);
      }

      await tester.pumpWidget(
        _app(
          ValueListenableBuilder(
            valueListenable: tab,
            builder: (context, index, _) => SettingsPage(
              selectedIndex: index,
              layoutSettingsController: layout,
              networkSettingsController: network,
              gadgetBypassController: gadget,
              displayModeController: display,
              audioController: audio,
              captureModeController: capture,
              browserController: browser,
              gameCaptureController: gameCapture,
              prototypeStatusController: prototype,
              gameStateController: gameState,
              safetySettingsController: safety,
              currentVersion: 'test',
              gameStartupCheckSettingsController: startupChecks,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_switchKey), findsNothing);

      tab.value = 1;
      await tester.pumpAndSettle();
      final runtime = find.byType(GameRuntimeSettingsPage);
      final toggle = find.descendant(
        of: runtime,
        matching: find.byKey(_switchKey),
      );
      expect(toggle, findsOneWidget);
      expect(find.text('启动检查'), findsOneWidget);
      expect(find.textContaining('关闭后使用原来的启动方式'), findsOneWidget);
      expect(find.text('性能与画面'), findsOneWidget);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(startupChecks.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

class _PendingPreferencesStore extends InMemorySharedPreferencesStore {
  _PendingPreferencesStore() : super.empty();

  Completer<bool> result = Completer<bool>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.game.startupCheck' && !await result.future) {
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
