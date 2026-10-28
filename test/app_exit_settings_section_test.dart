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
import 'package:yahagi_kancolle_browser/src/settings/app_exit_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/app_exit_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_runtime_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/settings_page.dart';

const _toggleKey = Key('settings-confirm-before-exit');

Widget _localized(Widget child, [Locale locale = const Locale('zh')]) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in [
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    const Locale('ja'),
  ]) {
    testWidgets(
      'runtime settings expose localized operation protection: $locale',
      (tester) async {
        final exit = await AppExitSettingsController.load();
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        final display = await DisplayModeController.load(
          MemoryDisplayModeStore(),
        );
        addTearDown(exit.dispose);
        addTearDown(layout.dispose);
        addTearDown(display.dispose);
        await tester.pumpWidget(
          _localized(
            GameRuntimeSettingsPage(
              layoutSettingsController: layout,
              appExitSettingsController: exit,
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(locale);
        final toggle = find.byKey(_toggleKey);
        expect(toggle, findsOneWidget);
        await tester.ensureVisible(toggle);
        expect(find.text(l10n.operationProtectionTitle), findsOneWidget);
        expect(find.text(l10n.confirmBeforeExitTitle), findsOneWidget);
        expect(find.text(l10n.confirmBeforeExitDescription), findsOneWidget);
        expect(tester.widget<Switch>(toggle).value, isTrue);
        final protectionCard = tester.widget<Material>(
          find.ancestor(of: toggle, matching: find.byType(Material)).first,
        );
        expect(protectionCard.borderRadius, BorderRadius.circular(12));
        expect(find.byKey(const Key('settings-ui-lock-switch')), findsNothing);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(toggle).value, isFalse);
        await (await SharedPreferences.getInstance()).reload();
        final reloaded = await AppExitSettingsController.load();
        addTearDown(reloaded.dispose);
        expect(reloaded.enabled, isFalse);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(exit.enabled, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'section disables the switch during save and shows a retryable error',
    (tester) async {
      final platform = _PendingPreferencesStore();
      SharedPreferencesStorePlatform.instance = platform;
      final exit = await AppExitSettingsController.load();
      addTearDown(exit.dispose);
      await tester.pumpWidget(
        _localized(AppExitSettingsSection(controller: exit)),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(_toggleKey);
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<Switch>(toggle).onChanged, isNull);
      platform.writeResult.complete(false);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
      expect(find.text('防误退设置保存失败，请重试。'), findsOneWidget);
      platform.writeResult = Completer<bool>()..complete(true);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(find.text('防误退设置保存失败，请重试。'), findsNothing);
    },
  );

  testWidgets('SettingsPage forwards its exit controller to the runtime page', (
    tester,
  ) async {
    final exit = await AppExitSettingsController.load();
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
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
    for (final controller in <ChangeNotifier>[
      exit,
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
    ]) {
      addTearDown(controller.dispose);
    }
    await tester.pumpWidget(
      _localized(
        SettingsPage(
          selectedIndex: 1,
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
          appExitSettingsController: exit,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final screen = tester.widget<GameRuntimeSettingsPage>(
      find.byType(GameRuntimeSettingsPage),
    );
    expect(identical(screen.appExitSettingsController, exit), isTrue);
    expect(find.byKey(_toggleKey), findsOneWidget);
    await tester.ensureVisible(find.byKey(_toggleKey));
    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(exit.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _PendingPreferencesStore extends InMemorySharedPreferencesStore {
  _PendingPreferencesStore() : super.empty();

  Completer<bool> writeResult = Completer<bool>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!await writeResult.future) return false;
    return super.setValue(valueType, key, value);
  }
}
