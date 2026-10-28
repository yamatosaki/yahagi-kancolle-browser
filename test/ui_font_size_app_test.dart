import 'package:flutter/material.dart';
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
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_display_size.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_font_size.dart';

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });

  testWidgets('saved medium font overrides the system scaler in the real app', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      preferences: <String, Object>{'layout_ui_font_size': 'medium'},
      systemScale: 2,
    );

    _expectAppFontScale(tester, 1);
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    await tester.pump();
    _expectAppFontScale(tester, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (saved, scale) in [('small', .8), ('large', 1.25)]) {
    testWidgets('saved $saved font ignores later system font changes', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        preferences: <String, Object>{'layout_ui_font_size': saved},
        systemScale: 2,
      );

      _expectAppFontScale(tester, scale);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      await tester.pump();
      _expectAppFontScale(tester, scale);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('the default font keeps following system font changes', (
    tester,
  ) async {
    await _pumpApp(tester);
    _expectAppFontScale(tester, 1);
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    await tester.pump();
    _expectAppFontScale(tester, 1.2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(1400, 850), const Size(844, 390)]) {
    testWidgets(
      'settings font dropdown saves without losing the game or density at $size',
      (tester) async {
        final app = await _pumpApp(
          tester,
          preferences: <String, Object>{
            'layout_ui_font_size': 'medium',
            'layout_ui_display_size': 'compact',
          },
          systemScale: 2,
          size: size,
        );
        final game = find.byType(_FontGameProbe, skipOffstage: false);
        final shell = find.byType(YahagiShell);
        final gameBefore = tester.state(game);
        final shellBefore = tester.state(shell);
        final timerAnchor = app.gameState.nozakiTimer.anchorAt;
        final gameStateBefore = app.gameState.state;
        final preferences = await SharedPreferences.getInstance();
        expect(app.layout.uiDisplaySize, UiDisplaySize.compact);

        tester
            .widget<WorkspaceNavigation>(find.byType(WorkspaceNavigation))
            .onSelected(8);
        await tester.pump(const Duration(milliseconds: 350));
        final label = find.byKey(const Key('settings-ui-font-size-label'));
        final dropdown = find.byKey(
          const Key('settings-ui-font-size-dropdown'),
        );
        expect(dropdown, findsOneWidget);
        expect(
          tester.widget<DropdownButton<UiFontSize>>(dropdown).value,
          UiFontSize.medium,
        );

        for (final (font, scale, beforeScale) in [
          (UiFontSize.large, 1.25, 1.0),
          (UiFontSize.small, .8, 1.25),
        ]) {
          await _selectFontSize(tester, font, menuScale: beforeScale);
          expect(app.layout.uiFontSize, font);
          expect(preferences.getString('layout_ui_font_size'), font.name);
          _expectAppFontScale(tester, scale);
          expect(
            MediaQuery.textScalerOf(tester.element(label)).scale(14),
            closeTo(14 * scale, .0001),
          );
        }

        tester.platformDispatcher.textScaleFactorTestValue = 1.2;
        await tester.pump();
        _expectAppFontScale(tester, .8);
        final dialog = showDialog<void>(
          context: tester.element(shell),
          builder: (_) => const AlertDialog(
            content: Text('Font probe', key: Key('font-size-dialog-text')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        final dialogText = find.byKey(const Key('font-size-dialog-text'));
        expect(
          MediaQuery.textScalerOf(tester.element(dialogText)).scale(14),
          closeTo(14 * .8, .0001),
        );
        Navigator.of(tester.element(dialogText)).pop();
        await tester.pump(const Duration(milliseconds: 350));
        await dialog;

        await _selectFontSize(tester, UiFontSize.medium, menuScale: .8);
        _expectAppFontScale(tester, 1);
        await _selectFontSize(tester, UiFontSize.system, menuScale: 1);
        _expectAppFontScale(tester, 1.2);
        expect(app.layout.uiFontSize, UiFontSize.system);
        expect(preferences.getString('layout_ui_font_size'), 'system');
        expect(
          MediaQuery.textScalerOf(tester.element(label)).scale(14),
          closeTo(14 * 1.2, .0001),
        );

        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.uiFontSize, UiFontSize.system);
        expect(restored.uiDisplaySize, UiDisplaySize.compact);
        restored.dispose();
        expect(app.layout.uiDisplaySize, UiDisplaySize.compact);
        expect(preferences.getString('layout_ui_display_size'), 'compact');
        expect(tester.state(game), same(gameBefore));
        expect(tester.state(shell), same(shellBefore));
        expect(app.gameState.state, same(gameStateBefore));
        expect(app.gameState.nozakiTimer.anchorAt, timerAnchor);
        expect(app.browserPort.reloads, 0);
        expect(app.browserPort.frameReloads, 0);

        tester
            .widget<WorkspaceNavigation>(find.byType(WorkspaceNavigation))
            .onSelected(0);
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(_FontGameProbe), findsOneWidget);
        expect(tester.state(game), same(gameBefore));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

void _expectAppFontScale(WidgetTester tester, double scale) {
  for (final target in [
    find.byType(_FontGameProbe, skipOffstage: false),
    find.byType(YahagiShell),
  ]) {
    expect(
      MediaQuery.textScalerOf(tester.element(target)).scale(14),
      closeTo(14 * scale, .0001),
    );
  }
}

Future<void> _selectFontSize(
  WidgetTester tester,
  UiFontSize value, {
  required double menuScale,
}) async {
  final dropdown = find.byKey(const Key('settings-ui-font-size-dropdown'));
  await tester.ensureVisible(dropdown);
  await tester.pump();
  await tester.tap(dropdown);
  await tester.pump(const Duration(milliseconds: 350));
  final option = find
      .byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem<UiFontSize> && widget.value == value,
      )
      .last;
  expect(
    MediaQuery.textScalerOf(tester.element(option)).scale(14),
    closeTo(14 * menuScale, .0001),
  );
  await tester.tap(find.descendant(of: option, matching: find.byType(Text)));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<_AppFixture> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const <String, Object>{},
  double systemScale = 1,
  Size size = const Size(1400, 850),
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final previousTimerSetting = GameStateController.disableTimerForTest;
  GameStateController.disableTimerForTest = true;
  addTearDown(
    () => GameStateController.disableTimerForTest = previousTimerSetting,
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = systemScale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final layout = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  await layout.setWorkspaceMenuPosition('left');
  final gameState = GameStateController();
  gameState.nozakiTimer.reset(
    DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
  );
  final battle = BattleController(gameState: () => gameState.state);
  final toolbar = GameToolbarController();
  final capture = GameCaptureController();
  final browserPort = _CountingBrowserPort();
  final browser = GameBrowserController(port: browserPort);
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
  final display = await DisplayModeController.load(MemoryDisplayModeStore());
  final mode = await CaptureModeController.load(
    SharedPreferencesCaptureModeStore(),
  );
  final audio = await GameAudioController.load(
    SharedPreferencesGameAudioStore(),
  );
  for (final notifier in <ChangeNotifier>[
    layout,
    gameState,
    battle,
    toolbar,
    capture,
    browser,
    status,
    network,
    bypass,
    safety,
    display,
    mode,
    audio,
  ]) {
    addTearDown(notifier.dispose);
  }

  await tester.pumpWidget(
    YahagiApp(
      layoutSettingsController: layout,
      networkSettingsController: network,
      gadgetBypassController: bypass,
      safetySettingsController: safety,
      displayModeController: display,
      controller: status,
      browserController: browser,
      captureModeController: mode,
      gameCaptureController: capture,
      gameStateController: gameState,
      battleController: battle,
      audioController: audio,
      toolbarController: toolbar,
      gameSurface: const _FontGameProbe(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
  return _AppFixture(layout, gameState, browserPort);
}

class _AppFixture {
  _AppFixture(this.layout, this.gameState, this.browserPort);

  final LayoutSettingsController layout;
  final GameStateController gameState;
  final _CountingBrowserPort browserPort;
}

class _CountingBrowserPort implements GameBrowserPort {
  int reloads = 0;
  int frameReloads = 0;

  @override
  Future<void> reload() async {
    reloads++;
  }

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async {
    frameReloads++;
    return GameFrameReloadResult.reloaded;
  }

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> fitGameScreen() async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> loadUri(Uri uri) async {}

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> showLocalHome() async {}
}

class _FontGameProbe extends StatefulWidget {
  const _FontGameProbe();

  @override
  State<_FontGameProbe> createState() => _FontGameProbeState();
}

class _FontGameProbeState extends State<_FontGameProbe> {
  @override
  Widget build(BuildContext context) => const ColoredBox(
    key: Key('font-size-game-pixels'),
    color: Color(0xff123456),
  );
}
