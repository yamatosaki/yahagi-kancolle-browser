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
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';
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

const _channel = MethodChannel('app.yahagi.kancollebrowser/window_layout');

class _Probe extends StatefulWidget {
  const _Probe({required this.onBounds, required this.onTap});
  final Future<void> Function(NativeGameWebViewBounds) onBounds;
  final VoidCallback onTap;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    child: NativeGameSurfaceSlot(
      onBoundsChanged: widget.onBounds,
      onVisibilityChanged: (_) async {},
    ),
  );
}

class _Harness {
  _Harness(this.app, this.notifiers, this.bounds, this.taps);
  final YahagiApp app;
  final List<ChangeNotifier> notifiers;
  final List<NativeGameWebViewBounds> bounds;
  final List<int> taps;

  static Future<_Harness> load() async {
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final gameState = GameStateController();
    final battle = BattleController(gameState: () => gameState.state);
    final toolbar = GameToolbarController();
    final capture = GameCaptureController();
    final browser = GameBrowserController();
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
    final bounds = <NativeGameWebViewBounds>[];
    final taps = <int>[0];

    return _Harness(
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
        gameSurface: _Probe(
          onBounds: (value) async => bounds.add(value),
          onTap: () => taps[0]++,
        ),
      ),
      [
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
      ],
      bounds,
      taps,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // These synthetic sequences exercise the distinct navigation bar states.
  // Lower split and landscape begin hidden. Upper split receives one visible
  // report while its native stable inset remains zero.
  final lowerSplitVisibility = List.generate(19, (index) => index.isOdd);
  const upperSplitVisibility = [true];
  final landscapeVisibility = List.generate(11, (index) => index.isOdd);

  group('Lower-split screen IME fluctuation smoke tests', () {
    testWidgets(
      'lower-split replay: other app IME keyboard popups do not jitter game surface in fullscreen',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        const dpr = 3.25;
        const physicalSize = Size(1220, 824);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          _channel,
          (_) async => {
            'mode': 'stacked',
            'isLandscape': false,
            'stable': true,
            'windowWidth': physicalSize.width.toInt(),
            'windowHeight': physicalSize.height.toInt(),
            'stableInsets': {'left': 0, 'top': 0, 'right': 0, 'bottom': 52},
            'insetsViewWidth': physicalSize.width.toInt(),
            'insetsViewHeight': physicalSize.height.toInt(),
          },
        );
        addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = physicalSize;
        tester.view.viewPadding = const FakeViewPadding();
        tester.view.padding = const FakeViewPadding();
        tester.view.viewInsets = const FakeViewPadding();

        final harness = await _Harness.load();
        for (final n in harness.notifiers) {
          addTearDown(n.dispose);
        }

        await tester.pumpWidget(harness.app);
        await tester.pumpAndSettle();

        // Enter fullscreen
        await tester.tap(find.byKey(const Key('yahagi-brand-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
        await tester.pumpAndSettle();

        final slotFinder = find.byType(NativeGameSurfaceSlot);
        expect(slotFinder, findsOneWidget);
        final initialRect = tester.getRect(slotFinder);
        final initialBoundsCount = harness.bounds.length;

        int transitions = 0;
        bool? lastNav;
        for (final navVisible in lowerSplitVisibility) {
          if (lastNav != navVisible) {
            lastNav = navVisible;
            transitions++;
            final padding = navVisible
                ? const FakeViewPadding(bottom: 52)
                : const FakeViewPadding();
            tester.view.viewPadding = padding;
            tester.view.padding = padding;
            await tester.pump();

            final currentRect = tester.getRect(slotFinder);
            expect(
              currentRect,
              initialRect,
              reason: 'Fullscreen: surface jittered at state $transitions',
            );
            expect(
              harness.bounds.length,
              initialBoundsCount,
              reason:
                  'Fullscreen: unexpected bounds resend at state $transitions',
            );

            // Tap check
            final tapsBefore = harness.taps[0];
            await tester.tap(find.byType(_Probe), warnIfMissed: false);
            await tester.pump();
            expect(
              harness.taps[0],
              tapsBefore + 1,
              reason: 'Fullscreen: tap hit-testing must remain accurate',
            );
          }
        }

        expect(transitions, greaterThan(10));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'lower-split replay: other app IME keyboard popups do not jitter game surface in normal windowed mode',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        const dpr = 3.25;
        const physicalSize = Size(1220, 824);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          _channel,
          (_) async => {
            'mode': 'stacked',
            'isLandscape': false,
            'stable': true,
            'windowWidth': physicalSize.width.toInt(),
            'windowHeight': physicalSize.height.toInt(),
            'stableInsets': {'left': 0, 'top': 0, 'right': 0, 'bottom': 52},
            'insetsViewWidth': physicalSize.width.toInt(),
            'insetsViewHeight': physicalSize.height.toInt(),
          },
        );
        addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = physicalSize;
        tester.view.viewPadding = const FakeViewPadding(bottom: 52);
        tester.view.padding = const FakeViewPadding(bottom: 52);
        tester.view.viewInsets = const FakeViewPadding();

        final harness = await _Harness.load();
        for (final n in harness.notifiers) {
          addTearDown(n.dispose);
        }

        await tester.pumpWidget(harness.app);
        await tester.pumpAndSettle();

        // Normal mode (NOT fullscreen)
        final slotFinder = find.byType(NativeGameSurfaceSlot);
        expect(slotFinder, findsOneWidget);
        final initialRect = tester.getRect(slotFinder);
        final initialBoundsCount = harness.bounds.length;

        int transitions = 0;
        bool? lastNav;
        for (final navVisible in lowerSplitVisibility) {
          if (lastNav != navVisible) {
            lastNav = navVisible;
            transitions++;
            final padding = navVisible
                ? const FakeViewPadding(bottom: 52)
                : const FakeViewPadding();
            tester.view.viewPadding = padding;
            tester.view.padding = padding;
            await tester.pump();

            final currentRect = tester.getRect(slotFinder);
            expect(
              currentRect,
              initialRect,
              reason: 'Normal mode: surface jittered at state $transitions',
            );
            expect(
              harness.bounds.length,
              initialBoundsCount,
              reason:
                  'Normal mode: unexpected bounds resend at state $transitions',
            );

            // Tap check
            final tapsBefore = harness.taps[0];
            await tester.tap(find.byType(_Probe), warnIfMissed: false);
            await tester.pump();
            expect(
              harness.taps[0],
              tapsBefore + 1,
              reason: 'Normal mode: tap hit-testing must remain accurate',
            );
          }
        }

        expect(transitions, greaterThan(10));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'lower-split fallback (no native stable insets): transient nav bar does not jitter game surface',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        const dpr = 3.25;
        const physicalSize = Size(1220, 824);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          _channel,
          (_) async => throw MissingPluginException(),
        );
        addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = physicalSize;
        tester.view.viewPadding = const FakeViewPadding();
        tester.view.padding = const FakeViewPadding();
        tester.view.viewInsets = const FakeViewPadding();

        final harness = await _Harness.load();
        for (final n in harness.notifiers) {
          addTearDown(n.dispose);
        }

        await tester.pumpWidget(harness.app);
        await tester.pumpAndSettle();

        final slotFinder = find.byType(NativeGameSurfaceSlot);
        expect(slotFinder, findsOneWidget);
        final initialRect = tester.getRect(slotFinder);
        final initialBoundsCount = harness.bounds.length;

        int transitions = 0;
        bool? lastNav;
        for (final navVisible in lowerSplitVisibility) {
          if (lastNav != navVisible) {
            lastNav = navVisible;
            transitions++;
            final padding = navVisible
                ? const FakeViewPadding(bottom: 52)
                : const FakeViewPadding();
            tester.view.viewPadding = padding;
            tester.view.padding = padding;
            await tester.pump();

            final currentRect = tester.getRect(slotFinder);
            expect(
              currentRect,
              initialRect,
              reason: 'Fallback mode: surface jittered at state $transitions',
            );
            expect(
              harness.bounds.length,
              initialBoundsCount,
              reason:
                  'Fallback mode: unexpected bounds resend at state $transitions',
            );

            // Tap check
            final tapsBefore = harness.taps[0];
            await tester.tap(find.byType(_Probe), warnIfMissed: false);
            await tester.pump();
            expect(
              harness.taps[0],
              tapsBefore + 1,
              reason: 'Fallback mode: tap hit-testing must remain accurate',
            );
          }
        }

        expect(transitions, greaterThan(10));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'upper-split replay: other app IME keyboard popups do not jitter game surface',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        const dpr = 3.25;
        const physicalSize = Size(1220, 824);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          _channel,
          (_) async => {
            'mode': 'stacked',
            'isLandscape': false,
            'stable': true,
            'windowWidth': physicalSize.width.toInt(),
            'windowHeight': physicalSize.height.toInt(),
            'stableInsets': {'left': 0, 'top': 0, 'right': 0, 'bottom': 0},
            'insetsViewWidth': physicalSize.width.toInt(),
            'insetsViewHeight': physicalSize.height.toInt(),
          },
        );
        addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = physicalSize;
        tester.view.viewPadding = const FakeViewPadding();
        tester.view.padding = const FakeViewPadding();
        tester.view.viewInsets = const FakeViewPadding();

        final harness = await _Harness.load();
        for (final n in harness.notifiers) {
          addTearDown(n.dispose);
        }

        await tester.pumpWidget(harness.app);
        await tester.pumpAndSettle();

        final slotFinder = find.byType(NativeGameSurfaceSlot);
        expect(slotFinder, findsOneWidget);
        final initialRect = tester.getRect(slotFinder);
        final initialBoundsCount = harness.bounds.length;

        int transitions = 0;
        bool? lastNav;
        for (final navVisible in upperSplitVisibility) {
          if (lastNav != navVisible) {
            lastNav = navVisible;
            transitions++;
            final padding = navVisible
                ? const FakeViewPadding(bottom: 52)
                : const FakeViewPadding();
            tester.view.viewPadding = padding;
            tester.view.padding = padding;
            await tester.pump();

            final currentRect = tester.getRect(slotFinder);
            expect(
              currentRect,
              initialRect,
              reason: 'Upper split: surface jittered at state $transitions',
            );
            expect(
              harness.bounds.length,
              initialBoundsCount,
              reason:
                  'Upper split: unexpected bounds resend at state $transitions',
            );

            // Tap check
            final tapsBefore = harness.taps[0];
            await tester.tap(find.byType(_Probe), warnIfMissed: false);
            await tester.pump();
            expect(
              harness.taps[0],
              tapsBefore + 1,
              reason: 'Upper-split: tap hit-testing must remain accurate',
            );
          }
        }

        expect(transitions, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'landscape fullscreen replay: IME popups do not jitter true fullscreen game surface',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        const dpr = 2.75;
        const physicalSize = Size(2400, 1080);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          _channel,
          (_) async => {
            'mode': 'single',
            'isLandscape': true,
            'stable': true,
            'windowWidth': physicalSize.width.toInt(),
            'windowHeight': physicalSize.height.toInt(),
            'stableInsets': {'left': 0, 'top': 0, 'right': 0, 'bottom': 0},
            'insetsViewWidth': physicalSize.width.toInt(),
            'insetsViewHeight': physicalSize.height.toInt(),
          },
        );
        addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = physicalSize;
        tester.view.viewPadding = const FakeViewPadding();
        tester.view.padding = const FakeViewPadding();
        tester.view.viewInsets = const FakeViewPadding();

        final harness = await _Harness.load();
        for (final n in harness.notifiers) {
          addTearDown(n.dispose);
        }

        await tester.pumpWidget(harness.app);
        await tester.pumpAndSettle();

        // Enter fullscreen
        await tester.tap(find.byKey(const Key('yahagi-brand-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
        await tester.pumpAndSettle();

        final slotFinder = find.byType(NativeGameSurfaceSlot);
        expect(slotFinder, findsOneWidget);
        final initialRect = tester.getRect(slotFinder);
        final initialBoundsCount = harness.bounds.length;

        int transitions = 0;
        bool? lastNav;
        for (final navVisible in landscapeVisibility) {
          if (lastNav != navVisible) {
            lastNav = navVisible;
            transitions++;
            // In landscape, navigation bar appears on right (or bottom)
            final padding = navVisible
                ? const FakeViewPadding(right: 52)
                : const FakeViewPadding();
            tester.view.viewPadding = padding;
            tester.view.padding = padding;
            await tester.pump();

            final currentRect = tester.getRect(slotFinder);
            expect(
              currentRect,
              initialRect,
              reason: 'Landscape: surface jittered at state $transitions',
            );
            expect(
              harness.bounds.length,
              initialBoundsCount,
              reason:
                  'Landscape: unexpected bounds resend at state $transitions',
            );

            // Tap check
            final tapsBefore = harness.taps[0];
            await tester.tap(find.byType(_Probe), warnIfMissed: false);
            await tester.pump();
            expect(
              harness.taps[0],
              tapsBefore + 1,
              reason: 'Landscape: tap hit-testing must remain accurate',
            );
          }
        }

        expect(transitions, greaterThan(10));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
