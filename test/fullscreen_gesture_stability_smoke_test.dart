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

  testWidgets(
    'captioned window fills and centers the game on entering fullscreen',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const physicalSize = Size(973, 438);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        _channel,
        (_) async => {
          'mode': 'stacked',
          'isLandscape': true,
          'stable': true,
          // The native window includes a caption above the Flutter surface.
          'windowWidth': 973,
          'windowHeight': 462,
          'insetsViewWidth': 973,
          'insetsViewHeight': 438,
          'stableInsets': {'left': 0, 'top': 0, 'right': 0, 'bottom': 0},
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = physicalSize;
      tester.view.viewPadding = const FakeViewPadding();
      tester.view.padding = const FakeViewPadding();
      tester.view.viewInsets = const FakeViewPadding();

      final harness = await _Harness.load();
      for (final notifier in harness.notifiers) {
        addTearDown(notifier.dispose);
      }
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      final slot = find.byType(NativeGameSurfaceSlot);
      final originalElement = tester.element(slot);
      Rect lastReportedRect() {
        final bounds = harness.bounds.last;
        expect(bounds.devicePixelRatio, 1);
        return Rect.fromLTWH(
          bounds.left,
          bounds.top,
          bounds.width,
          bounds.height,
        );
      }

      final windowedRect = tester.getRect(slot);
      expect(harness.bounds, isNotEmpty);
      expect(lastReportedRect(), windowedRect);
      final windowedWrites = harness.bounds.length;

      await tester.tap(find.byKey(const Key('yahagi-brand-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      const fullscreenRect = Rect.fromLTWH(122, 0, 730, 438);
      expect(windowedRect, isNot(fullscreenRect));
      expect(tester.element(slot), same(originalElement));
      final actualFullscreenRect = tester.getRect(slot);
      expect(actualFullscreenRect, fullscreenRect);
      expect(harness.bounds.length, greaterThan(windowedWrites));
      expect(lastReportedRect(), actualFullscreenRect);
      expect(
        (actualFullscreenRect.left -
                (physicalSize.width - actualFullscreenRect.right))
            .abs(),
        lessThanOrEqualTo(1),
      );
      final fullscreenWrites = harness.bounds.length;

      // These points are fixed in physical pixels at DPR=1. The inner points
      // remain clear of the simulated system bars and the exit control.
      const gamePoints = [
        Offset(487, 219),
        Offset(126, 219),
        Offset(848, 219),
        Offset(487, 86),
        Offset(487, 380),
      ];
      const gutterPoints = [Offset(116, 219), Offset(858, 219)];
      for (final padding in const [
        FakeViewPadding(),
        FakeViewPadding(top: 80),
        FakeViewPadding(top: 80, bottom: 52),
        FakeViewPadding(bottom: 52),
        FakeViewPadding(),
      ]) {
        tester.view.viewPadding = padding;
        tester.view.padding = padding;
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(slot), fullscreenRect);
        expect(harness.bounds, hasLength(fullscreenWrites));
        final tapsBefore = harness.taps[0];
        for (final point in gamePoints) {
          await tester.tapAt(point);
        }
        expect(harness.taps[0], tapsBefore + gamePoints.length);
        for (final point in gutterPoints) {
          await tester.tapAt(point);
        }
        expect(harness.taps[0], tapsBefore + gamePoints.length);
      }

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(tester.element(slot), same(originalElement));
      expect(tester.getRect(slot), windowedRect);
      expect(harness.bounds.length, greaterThan(fullscreenWrites));
      expect(lastReportedRect(), windowedRect);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'true fullscreen mode ignores top status bar and bottom gesture bar transient popups without jitter or touch offset',
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

      // Enter fullscreen:
      await tester.tap(find.byKey(const Key('yahagi-brand-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
      await tester.pumpAndSettle();

      final slotFinder = find.byType(NativeGameSurfaceSlot);
      expect(slotFinder, findsOneWidget);
      final initialRect = tester.getRect(slotFinder);
      final initialBoundsWrites = harness.bounds.length;

      // True fullscreen fills viewport height (1080 / 2.75) with 5:3 aspect ratio
      expect(initialRect.height, physicalSize.height / dpr);
      expect(
        initialRect.width,
        closeTo(initialRect.height * (1200 / 720), 0.001),
      );
      expect(initialRect.top, 0);
      expect(initialRect.bottom, physicalSize.height / dpr);

      // Verify tap hit-testing at center before gestures:
      await tester.tap(find.byType(_Probe), warnIfMissed: false);
      await tester.pump();
      expect(harness.taps[0], 1);

      // Simulate Android gestures:
      // 1. Top status bar pull-down (transient status bar appears)
      // 2. Bottom navigation gesture / 3-button pill (transient nav bar appears)
      // 3. Both visible simultaneously
      // 4. Return to zero
      const transientSequence = [
        FakeViewPadding(top: 80),
        FakeViewPadding(top: 80, bottom: 52),
        FakeViewPadding(bottom: 52),
        FakeViewPadding(right: 52),
        FakeViewPadding(top: 80, bottom: 52, right: 52),
        FakeViewPadding(),
      ];

      for (var cycle = 0; cycle < 5; cycle++) {
        for (final transient in transientSequence) {
          tester.view.viewPadding = transient;
          tester.view.padding = transient;

          for (final elapsed in const [
            Duration.zero,
            Duration(milliseconds: 16),
            Duration(milliseconds: 100),
            Duration(milliseconds: 200),
            Duration(milliseconds: 310),
            Duration(seconds: 1),
          ]) {
            await tester.pump(elapsed);

            // Zero Jitter: Game surface rect must remain absolutely identical
            final currentRect = tester.getRect(slotFinder);
            expect(
              currentRect.left,
              initialRect.left,
              reason: 'Left edge must not jitter during $transient at $elapsed',
            );
            expect(
              currentRect.top,
              initialRect.top,
              reason: 'Top edge must not jitter during $transient at $elapsed',
            );
            expect(
              currentRect.width,
              initialRect.width,
              reason: 'Width must not jitter during $transient at $elapsed',
            );
            expect(
              currentRect.height,
              initialRect.height,
              reason: 'Height must not jitter during $transient at $elapsed',
            );

            // Zero Redundant Refit / Bounds updates:
            expect(
              harness.bounds,
              hasLength(initialBoundsWrites),
              reason: 'Transient bar must not resend bounds to native layer',
            );

            // Tap hit-testing test:
            final tapsBefore = harness.taps[0];
            await tester.tap(find.byType(_Probe), warnIfMissed: false);
            await tester.pump();
            expect(
              harness.taps[0],
              tapsBefore + 1,
              reason: 'Touch coordinates must not misalign during $transient',
            );
          }
        }
      }

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'split-screen mode preserves fullscreen stability and avoids jitter during system bar activity',
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

      // Enter fullscreen:
      await tester.tap(find.byKey(const Key('yahagi-brand-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-enter-fullscreen')));
      await tester.pumpAndSettle();

      final slotFinder = find.byType(NativeGameSurfaceSlot);
      final initialRect = tester.getRect(slotFinder);
      final initialWrites = harness.bounds.length;

      // In split screen, ensure game aspect ratio is strictly 5:3
      expect(
        initialRect.width / initialRect.height,
        closeTo(1200 / 720, 0.001),
      );

      // Fluctuate system bars:
      for (final transient in const [
        FakeViewPadding(bottom: 52),
        FakeViewPadding(),
        FakeViewPadding(top: 80, bottom: 52),
        FakeViewPadding(right: 52),
        FakeViewPadding(),
      ]) {
        tester.view.viewPadding = transient;
        tester.view.padding = transient;
        for (final elapsed in const [
          Duration.zero,
          Duration(milliseconds: 16),
          Duration(milliseconds: 200),
          Duration(seconds: 1),
        ]) {
          await tester.pump(elapsed);
          final currentRect = tester.getRect(slotFinder);
          expect(currentRect, initialRect);
          expect(harness.bounds, hasLength(initialWrites));

          final tapsBefore = harness.taps[0];
          await tester.tap(find.byType(_Probe), warnIfMissed: false);
          await tester.pump();
          expect(harness.taps[0], tapsBefore + 1);
        }
      }

      expect(tester.takeException(), isNull);
    },
  );
}
