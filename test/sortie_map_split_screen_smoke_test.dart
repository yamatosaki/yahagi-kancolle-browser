import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_geometry.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_update_service.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_viewport.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_display_size.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _portrait = Size(360, 800);
const _landscape = Size(800, 360);
const _captureKey = Key('map-split-smoke-capture');
const _mapCanvas = Key('sortie-map-canvas');
const _logicalCanvas = Key('sortie-map-logical-canvas');

// These scenarios mount YahagiApp, feed captured API events into its real game
// and battle controllers, and measure the actual workspace. Only the native
// WebView and network updater are replaced; no split/map layout is reproduced.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late FcdMapDataset dataset;
  setUpAll(() async {
    dataset = FcdMapDataset.parse(
      await rootBundle.loadString('assets/data/fcd/map.json'),
    );
    await (FontLoader(
      'HarmonyOS_Sans_SC',
    )..addFont(rootBundle.load('assets/fonts/HarmonyOS_Sans_SC.ttf'))).load();
  });

  for (final gameRatio in [.5, .75]) {
    for (final (name, metricId, titleText, closeKey) in const [
      ('LOS', 'line-of-sight', '索敌详情', 'fleet-los-details-close'),
      ('air power', 'air-power', '制空详情', 'fleet-air-power-details-close'),
    ]) {
      testWidgets(
        'landscape game accepts the first tap outside $name details ($gameRatio)',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final previousTimerSetting = GameStateController.disableTimerForTest;
          GameStateController.disableTimerForTest = true;
          addTearDown(
            () =>
                GameStateController.disableTimerForTest = previousTimerSetting,
          );
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = _landscape;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          const nativeDialogs = MethodChannel(
            'app.yahagi.kancollebrowser/native_warning',
          );
          final messenger = tester.binding.defaultBinaryMessenger;
          final nativeDialogCalls = <String>[];
          messenger.setMockMethodCallHandler(nativeDialogs, (call) async {
            nativeDialogCalls.add(call.method);
            if (call.method == 'show') {
              throw PlatformException(code: 'no-native-dialog-test-host');
            }
            return null;
          });
          addTearDown(
            () => messenger.setMockMethodCallHandler(nativeDialogs, null),
          );

          final fixture = await _AppFixture.load(dataset, UiDisplaySize.normal);
          for (final notifier in fixture.notifiers) {
            addTearDown(notifier.dispose);
          }
          await fixture.layout.setAutoZoom(false);
          await fixture.layout.setGameAreaRatio(gameRatio);
          await fixture.layout.setFleetDisplayFields({
            'air-power',
            'line-of-sight',
          });
          fixture.game.accept(slotItemEvent);
          await fixture.game.idle;
          await tester.pumpWidget(
            RepaintBoundary(key: _captureKey, child: fixture.app),
          );
          await _settle(tester);

          _expectSplit(
            tester,
            landscape: true,
            hd: false,
            infoRatio: 1 - gameRatio,
          );
          final surface = find.byType(_GameProbe);
          final gameState = tester.state<_GameProbeState>(surface);
          final gameBounds = tester.getRect(surface);
          final gamePixelBounds = _wholePixelBounds(gameBounds);
          final gamePixels = await _readPixels(tester, gamePixelBounds);
          expect(gamePixels.take(4), [0x07, 0x16, 0x21, 0xff]);

          final metric = find.byKey(Key('fleet-summary-metric-$metricId'));
          final title = find.text(titleText);
          final close = find.byKey(Key(closeKey));
          for (final dismissWithGameTap in [true, false, true]) {
            await Scrollable.ensureVisible(
              tester.element(metric),
              alignment: .5,
            );
            await tester.pump();
            await tester.tap(metric);
            await _settle(tester);
            expect(title, findsOneWidget);
            expect(tester.state(surface), same(gameState));
            expect(tester.getRect(surface), gameBounds);
            final openPixels = await _readPixels(tester, gamePixelBounds);

            final tapsBefore = gameState.taps;
            if (dismissWithGameTap) {
              await tester.tapAt(gameBounds.center);
            } else {
              await tester.tap(close);
              await tester.pump();
              expect(title, findsNothing);
              await tester.tapAt(gameBounds.center);
            }
            await _settle(tester);
            expect(gameState.taps, tapsBefore + 1);
            expect(title, findsNothing);
            expect(tester.state(surface), same(gameState));
            expect(tester.getRect(surface), gameBounds);
            expect(listEquals(openPixels, gamePixels), isTrue);
            expect(
              listEquals(
                await _readPixels(tester, gamePixelBounds),
                gamePixels,
              ),
              isTrue,
            );
            expect(tester.takeException(), isNull);
          }
          if (metricId == 'air-power') {
            final losMetric = find.byKey(
              const Key('fleet-summary-metric-line-of-sight'),
            );
            final losTitle = find.text('索敌详情');
            // Leave room below the shared row so the current card does not
            // physically cover either metric during the switch.
            await Scrollable.ensureVisible(tester.element(losMetric));
            await _settle(tester);
            for (final (trigger, opened, closed) in [
              (losMetric, losTitle, title),
              (metric, title, losTitle),
              (losMetric, losTitle, title),
            ]) {
              expect(trigger.hitTestable(), findsOneWidget);
              await tester.tap(trigger);
              await _settle(tester);
              expect(opened, findsOneWidget);
              expect(closed, findsNothing);
              expect(tester.state(surface), same(gameState));
              expect(tester.getRect(surface), gameBounds);
              expect(
                listEquals(
                  await _readPixels(tester, gamePixelBounds),
                  gamePixels,
                ),
                isTrue,
              );
            }
            final tapsBefore = gameState.taps;
            await tester.tapAt(gameBounds.center);
            await _settle(tester);
            expect(gameState.taps, tapsBefore + 1);
            expect(losTitle, findsNothing);
            expect(title, findsNothing);
            expect(tester.takeException(), isNull);
          }
          expect(nativeDialogCalls, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final gameRatio in [.5, .75]) {
    testWidgets(
      'landscape game accepts the first gesture outside ship details ($gameRatio)',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final previousTimerSetting = GameStateController.disableTimerForTest;
        GameStateController.disableTimerForTest = true;
        addTearDown(
          () => GameStateController.disableTimerForTest = previousTimerSetting,
        );
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = _landscape;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final fixture = await _AppFixture.load(dataset, UiDisplaySize.normal);
        for (final notifier in fixture.notifiers) {
          addTearDown(notifier.dispose);
        }
        await fixture.layout.setAutoZoom(false);
        await fixture.layout.setGameAreaRatio(gameRatio);
        fixture.game
          ..accept(slotItemEvent)
          ..accept(mapStartEvent)
          ..accept(dayBattleEvent);
        await fixture.game.idle;
        fixture.battle
          ..accept(mapStartEvent)
          ..accept(dayBattleEvent);
        await fixture.battle.idle;
        await tester.pumpWidget(
          RepaintBoundary(key: _captureKey, child: fixture.app),
        );
        await _settle(tester);

        _expectSplit(
          tester,
          landscape: true,
          hd: false,
          infoRatio: 1 - gameRatio,
        );
        final surface = find.byType(_GameProbe);
        final gameState = tester.state<_GameProbeState>(surface);
        final gameBounds = tester.getRect(surface);
        final popover = find.byKey(const Key('battle-ship-details-popover'));
        final gamePixelBounds = _wholePixelBounds(gameBounds);
        final gamePixels = await _readPixels(tester, gamePixelBounds);
        expect(gamePixels.take(4), [0x07, 0x16, 0x21, 0xff]);

        for (final compact in [false, true]) {
          if (compact) {
            final toggle = find.byKey(const Key('battle-mode-compact'));
            await Scrollable.ensureVisible(
              tester.element(toggle),
              alignment: .5,
            );
            await tester.pump();
            await tester.tap(toggle);
            await _settle(tester);
          }
          final ship = find
              .ancestor(
                of: find.byKey(
                  Key(
                    compact ? 'compact-bar-friend-0' : 'battle-ship-friend-0',
                  ),
                ),
                matching: find.byType(InkWell),
              )
              .first;
          for (final drag in [false, true]) {
            await Scrollable.ensureVisible(tester.element(ship), alignment: .5);
            await tester.pump();
            await tester.tap(ship);
            await _settle(tester);
            expect(
              find.descendant(of: popover, matching: find.text('12.7cm 连装炮')),
              findsOneWidget,
            );
            expect(tester.getRect(popover).left, greaterThan(gameBounds.right));
            expect(tester.state(surface), same(gameState));
            expect(tester.getRect(surface), gameBounds);
            expect(
              listEquals(
                await _readPixels(tester, gamePixelBounds),
                gamePixels,
              ),
              isTrue,
              reason: 'Opening ship details must leave the game visible',
            );

            final taps = gameState.taps;
            final drags = gameState.drags;
            if (drag) {
              await tester.dragFrom(gameBounds.center, const Offset(60, 0));
            } else {
              await tester.tapAt(gameBounds.center);
            }
            await _settle(tester);
            expect(gameState.taps, taps + (drag ? 0 : 1));
            expect(gameState.drags, drags + (drag ? 1 : 0));
            expect(popover, findsNothing);
            expect(tester.state(surface), same(gameState));
            expect(tester.getRect(surface), gameBounds);
            expect(
              listEquals(
                await _readPixels(tester, gamePixelBounds),
                gamePixels,
              ),
              isTrue,
              reason: 'Dismissing ship details must leave the game visible',
            );
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final uiSize in [UiDisplaySize.normal, UiDisplaySize.minimal]) {
    testWidgets(
      'real ${uiSize.name} split keeps sortie maps through ratios and rotation',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final previousTimerSetting = GameStateController.disableTimerForTest;
        GameStateController.disableTimerForTest = true;
        addTearDown(
          () => GameStateController.disableTimerForTest = previousTimerSetting,
        );
        binding.platformDispatcher.localeTestValue = const Locale('zh');
        binding.platformDispatcher.localesTestValue = const [Locale('zh')];
        addTearDown(binding.platformDispatcher.clearLocaleTestValue);
        addTearDown(binding.platformDispatcher.clearLocalesTestValue);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = _portrait;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final fixture = await _AppFixture.load(dataset, uiSize);
        for (final notifier in fixture.notifiers) {
          addTearDown(notifier.dispose);
        }
        final semantics = tester.ensureSemantics();
        try {
          final ordinary = dataset.geometryFor(mapAreaId: 1, mapInfoNo: 6)!;
          final dense = dataset.geometryFor(mapAreaId: 62, mapInfoNo: 5)!;
          expect(dense.spots.length, greaterThan(45));
          await fixture.navigate(1, 6, ordinary, start: true);
          await tester.pumpWidget(
            RepaintBoundary(key: _captureKey, child: fixture.app),
          );
          await _settle(tester);
          final shellState = tester.state(find.byType(YahagiShell));
          final gameState = tester.state(find.byType(_GameProbe));
          final shipCount = fixture.game.state.ships.length;
          final ordinaryReference = _expectMap(tester, ordinary);
          await _capture(tester, '${uiSize.name}-portrait-1-6');

          await fixture.navigate(62, 5, dense, start: true);
          await _settle(tester);
          expect(fixture.battle.sortieMapProgress!.mapKey, '62-5');
          final denseReference = _expectMap(tester, dense);
          final originalProgress = fixture.battle.sortieMapProgress;
          final observedWidths = <double>[];

          for (final hd in [false, true]) {
            await fixture.layout.setHdEnabled(hd);
            await fixture.layout.setAutoZoom(false);
            for (final size in [_landscape, _portrait]) {
              tester.view.physicalSize = size;
              for (final infoRatio in [.25, .35, .50]) {
                await fixture.layout.setGameAreaRatio(1 - infoRatio);
                await _settle(tester);
                final reason = '${uiSize.name} HD=$hd $size info=$infoRatio';
                _expectSplit(
                  tester,
                  landscape: size == _landscape,
                  hd: hd,
                  infoRatio: infoRatio,
                  reason: reason,
                );
                final map = _expectMap(tester, dense, denseReference, reason);
                observedWidths.add(map.displayRect.width);
                expect(
                  fixture.layout.effectiveInformationPanelRatio,
                  closeTo(infoRatio, .00001),
                  reason: reason,
                );
                expect(
                  fixture.battle.sortieMapProgress,
                  same(originalProgress),
                );
                expect(
                  tester.state(find.byType(YahagiShell)),
                  same(shellState),
                );
                expect(tester.state(find.byType(_GameProbe)), same(gameState));
                expect(fixture.game.state.ships.length, shipCount);
                expect(tester.takeException(), isNull, reason: reason);
                if (!hd &&
                    ((size == _landscape && infoRatio != .35) ||
                        (size == _portrait && infoRatio == .35))) {
                  if (size == _landscape && infoRatio == .5) {
                    await _revealMap(tester);
                    _expectMap(tester, dense, denseReference, reason);
                  }
                  await _capture(
                    tester,
                    '${uiSize.name}-${size == _landscape ? 'landscape' : 'portrait'}'
                    '-info${(infoRatio * 100).round()}-62-5',
                  );
                }
              }
            }

            // Auto zoom uses 67:33, while retaining the last manual 50:50 value.
            // Turning it off must restore that value without losing map progress.
            tester.view.physicalSize = _landscape;
            await fixture.layout.setAutoZoom(true);
            await _settle(tester);
            _expectSplit(tester, landscape: true, hd: hd, infoRatio: .33);
            _expectMap(tester, dense, denseReference);
            expect(fixture.layout.canAdjustInformationPanelRatio, isFalse);
            expect(fixture.layout.gameAreaRatio, .5);
            expect(fixture.battle.sortieMapProgress, same(originalProgress));
            await fixture.layout.setAutoZoom(false);
            await _settle(tester);
            _expectSplit(tester, landscape: true, hd: hd, infoRatio: .5);
            _expectMap(tester, dense, denseReference);
            expect(fixture.layout.canAdjustInformationPanelRatio, isTrue);
            expect(tester.takeException(), isNull);
          }
          expect(
            observedWidths.reduce(math.max) - observedWidths.reduce(math.min),
            greaterThan(40),
            reason: 'The actual app must exercise visibly different map scales',
          );

          // Display settings also override the same physical portrait window.
          await fixture.layout.setHdEnabled(false);
          tester.view.physicalSize = _portrait;
          await fixture.display.setDisplayMode(DisplayMode.landscape);
          await _settle(tester);
          _expectSplit(tester, landscape: true, hd: false, infoRatio: .5);
          _expectMap(tester, dense, denseReference);
          await fixture.display.setDisplayMode(DisplayMode.portrait);
          await _settle(tester);
          _expectSplit(tester, landscape: false, hd: false, infoRatio: .5);
          _expectMap(tester, dense, denseReference);
          await fixture.display.setDisplayMode(DisplayMode.auto);

          // A real next-node capture updates this mounted map, and a subsequent
          // map/start replaces its geometry while keeping the split preferences.
          final current = dense.routes[fixture.routeId]!;
          final nextRoute = dense.routes.entries.firstWhere(
            (entry) => entry.value.from == current.to,
            orElse: () => dense.routes.entries.firstWhere(
              (entry) => entry.key > 0 && entry.key != fixture.routeId,
            ),
          );
          await fixture.navigate(62, 5, dense, routeId: nextRoute.key);
          await _settle(tester);
          expect(
            fixture.battle.sortieMapProgress!.currentRouteId,
            nextRoute.key,
          );
          expect(
            fixture.battle.sortieMapProgress!.routeIds,
            contains(nextRoute.key),
          );
          _expectMap(tester, dense);
          await fixture.navigate(1, 6, ordinary, start: true);
          await _settle(tester);
          expect(fixture.battle.sortieMapProgress!.mapKey, '1-6');
          _expectMap(tester, ordinary, ordinaryReference);
          expect(fixture.layout.gameAreaRatio, .5);
          expect(fixture.layout.autoZoom, isFalse);
          expect(fixture.display.displayMode, DisplayMode.auto);
          expect(tester.state(find.byType(YahagiShell)), same(shellState));
          expect(tester.state(find.byType(_GameProbe)), same(gameState));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
  await tester.pump();
}

// Compare every full pixel of the game picture, excluding fractional edges.
Rect _wholePixelBounds(Rect bounds) => Rect.fromLTRB(
  bounds.left.ceilToDouble(),
  bounds.top.ceilToDouble(),
  bounds.right.floorToDouble(),
  bounds.bottom.floorToDouble(),
);

Future<Uint8List> _readPixels(WidgetTester tester, Rect bounds) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final layer = boundary.debugLayer! as OffsetLayer;
  final crop = bounds.shift(-boundary.localToGlobal(Offset.zero));
  final pixels = await tester.runAsync(() async {
    final image = await layer.toImage(crop);
    try {
      final bytes = (await image.toByteData())!;
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  });
  return pixels!;
}

Future<void> _revealMap(WidgetTester tester) async {
  final finder = find.byKey(_mapCanvas);
  final context = tester.element(finder);
  final scrollable = Scrollable.of(context, axis: Axis.vertical);
  await Scrollable.ensureVisible(context, alignment: 1);
  await _settle(tester);
  Rect globalBounds(RenderBox box) => Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
  final map = globalBounds(tester.renderObject<RenderBox>(finder));
  final viewport = globalBounds(
    scrollable.context.findRenderObject()! as RenderBox,
  );
  expect(map.bottom, lessThanOrEqualTo(viewport.bottom + .01));
  expect(map.bottom, greaterThan(viewport.top));
  if (map.height <= viewport.height) {
    expect(map.top, greaterThanOrEqualTo(viewport.top - .01));
  }
}

void _expectSplit(
  WidgetTester tester, {
  required bool landscape,
  required bool hd,
  required double infoRatio,
  String? reason,
}) {
  final workspace = tester.getRect(find.byKey(const Key('game-workspace')));
  final game = tester.getRect(find.byType(GameSurfaceViewport));
  final panel = tester.getRect(
    find.byKey(const Key('workspace-information-panel')),
  );
  final surface = tester.getRect(find.byType(_GameProbe));
  expect(surface.size.aspectRatio, closeTo(5 / 3, .00001), reason: reason);
  expect(game.inflate(.01).contains(surface.topLeft), isTrue, reason: reason);
  expect(
    game.inflate(.01).contains(surface.bottomRight),
    isTrue,
    reason: reason,
  );
  expect(game.top, closeTo(workspace.top, .01), reason: reason);
  if (landscape) {
    expect(
      panel.width,
      closeTo((workspace.width - 1) * infoRatio, .01),
      reason: reason,
    );
    expect(
      game.width,
      closeTo((workspace.width - 1) * (1 - infoRatio), .01),
      reason: reason,
    );
    expect(panel.left, closeTo(game.right + 1, .01), reason: reason);
    expect(panel.top, closeTo(workspace.top, .01), reason: reason);
    expect(panel.height, closeTo(workspace.height, .01), reason: reason);
    if (hd) {
      final bottom = tester.getRect(find.byKey(const Key('hd-bottom-region')));
      expect(bottom.top, closeTo(game.bottom, .01), reason: reason);
      expect(bottom.bottom, closeTo(workspace.bottom, .01), reason: reason);
      expect(bottom.width, closeTo(game.width, .01), reason: reason);
      expect(bottom.height, greaterThanOrEqualTo(120 - .01), reason: reason);
    } else {
      expect(game.height, closeTo(workspace.height, .01), reason: reason);
      expect(find.byKey(const Key('hd-bottom-region')), findsNothing);
    }
  } else {
    // Portrait uses a complete width-fitted 5:3 game. The information slider
    // retains its preference for landscape; it does not squeeze game height.
    expect(game.width, closeTo(workspace.width, .01), reason: reason);
    expect(
      game.height,
      closeTo(
        math.min(workspace.width * 3 / 5 + 10, workspace.height - 1),
        .01,
      ),
      reason: reason,
    );
    expect(panel.top, closeTo(game.bottom + 1, .01), reason: reason);
    expect(panel.bottom, closeTo(workspace.bottom, .01), reason: reason);
    expect(panel.right, closeTo(workspace.right, .01), reason: reason);
    expect(find.byKey(const Key('hd-bottom-region')), findsNothing);
  }
}

class _MapSnapshot {
  const _MapSnapshot(this.displayRect, this.nodes, this.labels);
  final Rect displayRect;
  final Map<String, Offset> nodes;
  final List<Rect> labels;
}

_MapSnapshot _expectMap(
  WidgetTester tester,
  FcdMapGeometry geometry, [
  _MapSnapshot? reference,
  String? reason,
]) {
  final viewport = find.byKey(_mapCanvas);
  expect(viewport, findsOneWidget, reason: reason);
  final paintFinder = find.descendant(
    of: find.byKey(_logicalCanvas),
    matching: find.byType(CustomPaint),
  );
  expect(paintFinder, findsOneWidget, reason: reason);
  final box = tester.renderObject<RenderBox>(paintFinder);
  expect(box.size, const Size(326, 240), reason: reason);
  final origin = box.localToGlobal(Offset.zero);
  final scaleX = (box.localToGlobal(const Offset(1, 0)) - origin).distance;
  final scaleY = (box.localToGlobal(const Offset(0, 1)) - origin).distance;
  // Global bounds include both FittedBox and the minimal style's UiScale.
  final displayRect = Rect.fromPoints(
    origin,
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
  final viewportBox = tester.renderObject<RenderBox>(viewport);
  final viewportRect = Rect.fromPoints(
    viewportBox.localToGlobal(Offset.zero),
    viewportBox.localToGlobal(viewportBox.size.bottomRight(Offset.zero)),
  );
  expect(displayRect.size.aspectRatio, closeTo(326 / 240, .00001));
  expect(scaleX, closeTo(scaleY, .00001), reason: reason);
  expect(displayRect.width, closeTo(326 * scaleX, .00001), reason: reason);
  expect(displayRect.left, closeTo(viewportRect.left, .00001), reason: reason);
  expect(displayRect.top, closeTo(viewportRect.top, .00001), reason: reason);
  expect(
    displayRect.width,
    closeTo(viewportRect.width, .00001),
    reason: reason,
  );
  expect(
    displayRect.height,
    closeTo(viewportRect.height, .00001),
    reason: reason,
  );

  final nodes = <String, Offset>{};
  for (final element
      in find
          .descendant(of: viewport, matching: find.byType(Semantics))
          .evaluate()) {
    final semantics = element.widget as Semantics;
    final label = semantics.properties.label?.split(' · ').first;
    if (!geometry.spots.containsKey(label)) continue;
    final nodeBox = element.renderObject! as RenderBox;
    final center = nodeBox.localToGlobal(nodeBox.size.center(Offset.zero));
    nodes[label!] = box.globalToLocal(center);
    final nodeRect = Rect.fromPoints(
      nodeBox.localToGlobal(Offset.zero),
      nodeBox.localToGlobal(nodeBox.size.bottomRight(Offset.zero)),
    );
    expect(nodeRect.width, closeTo(20 * scaleX, .00001), reason: reason);
    expect(nodeRect.height, closeTo(20 * scaleY, .00001), reason: reason);
    if (reference != null) {
      expect(
        (nodes[label]! - reference.nodes[label]!).distance,
        lessThan(.00001),
        reason: '$reason node $label retains its logical position',
      );
    }
  }
  expect(nodes.keys, unorderedEquals(geometry.spots.keys), reason: reason);
  final canvas = TestRecordingCanvas();
  tester.widget<CustomPaint>(paintFinder).painter!.paint(canvas, box.size);
  final labels = <Rect>[];
  for (final call in canvas.invocations) {
    if (call.invocation.memberName != #drawParagraph) continue;
    final paragraph = call.invocation.positionalArguments[0] as ui.Paragraph;
    final at = call.invocation.positionalArguments[1] as Offset;
    final logical = at & Size(paragraph.width, paragraph.height);
    labels.add(logical);
    final actual = Rect.fromPoints(
      box.localToGlobal(logical.topLeft),
      box.localToGlobal(logical.bottomRight),
    );
    expect(actual.width, closeTo(logical.width * scaleX, .00001));
    expect(actual.height, closeTo(logical.height * scaleY, .00001));
  }
  expect(labels, hasLength(geometry.spots.length), reason: reason);
  if (reference != null) {
    expect(labels, reference.labels, reason: '$reason letters retain layout');
    final relativeScale = displayRect.width / reference.displayRect.width;
    expect(
      displayRect.height / reference.displayRect.height,
      closeTo(relativeScale, .00001),
      reason: '$reason letters, markers and semantics share one scale',
    );
  }
  return _MapSnapshot(displayRect, nodes, labels);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final output = Platform.environment['MAP_SPLIT_SMOKE_OUTPUT'];
  if (output == null || output.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(output);
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}

class _AppFixture {
  _AppFixture(
    this.app,
    this.layout,
    this.display,
    this.game,
    this.battle,
    this.notifiers,
  );

  final YahagiApp app;
  final LayoutSettingsController layout;
  final DisplayModeController display;
  final GameStateController game;
  final BattleController battle;
  final List<ChangeNotifier> notifiers;
  int _sequence = 100;
  int routeId = 0;

  static Future<_AppFixture> load(
    FcdMapDataset dataset,
    UiDisplaySize uiSize,
  ) async {
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await layout.setLocaleCode('zh');
    await layout.setUiDisplaySize(uiSize);
    await layout.setWorkspaceMenuPosition('left');
    await layout.setHdEnabled(false);
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    final rendering = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(),
    );
    expect(rendering.mode.usesActivityWebView, isTrue);
    final game = GameStateController();
    game
      ..accept(start2Event)
      ..accept(portEvent);
    await game.idle;
    final maps = FcdMapController(
      dataset: dataset,
      updater: const _BundledMapUpdater(),
    );
    final battle = BattleController(
      gameState: () => game.state,
      waitForGameState: () => game.idle,
      nodeLabelResolver: maps,
      predictionExecutor: const ImmediateBattlePredictionExecutor(),
    );
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
    final mode = await CaptureModeController.load(
      SharedPreferencesCaptureModeStore(),
    );
    final audio = await GameAudioController.load(
      SharedPreferencesGameAudioStore(),
    );
    return _AppFixture(
      YahagiApp(
        layoutSettingsController: layout,
        displayModeController: display,
        gameRenderingModeController: rendering,
        networkSettingsController: network,
        gadgetBypassController: bypass,
        safetySettingsController: safety,
        controller: status,
        browserController: browser,
        captureModeController: mode,
        gameCaptureController: capture,
        gameStateController: game,
        battleController: battle,
        fcdMapController: maps,
        audioController: audio,
        toolbarController: toolbar,
        gameSurface: const _GameProbe(),
      ),
      layout,
      display,
      game,
      battle,
      [
        layout,
        display,
        rendering,
        game,
        battle,
        maps,
        toolbar,
        capture,
        browser,
        status,
        network,
        bypass,
        safety,
        mode,
        audio,
      ],
    );
  }

  Future<void> navigate(
    int area,
    int number,
    FcdMapGeometry geometry, {
    bool start = false,
    int? routeId,
  }) async {
    this.routeId =
        routeId ??
        geometry.routes.entries
            .firstWhere((entry) => entry.key > 0 && entry.value.from != null)
            .key;
    final event = kcsapiEvent(
      '/kcsapi/api_req_map/${start ? 'start' : 'next'}',
      <String, Object?>{
        'api_maparea_id': area,
        'api_mapinfo_no': number,
        'api_no': this.routeId,
        'api_event_id': 4,
        'api_event_kind': 1,
      },
      sequence: _sequence++,
      requestParams: start
          ? <String, Object?>{
              'api_maparea_id': '$area',
              'api_mapinfo_no': '$number',
              'api_deck_id': '1',
            }
          : const <String, Object?>{},
    );
    game.accept(event);
    battle.accept(event);
    await game.idle;
    await battle.idle;
  }
}

class _GameProbe extends StatefulWidget {
  const _GameProbe();
  @override
  State<_GameProbe> createState() => _GameProbeState();
}

class _GameProbeState extends State<_GameProbe> {
  int taps = 0;
  int drags = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => taps++,
    onHorizontalDragEnd: (_) => drags++,
    child: const ColoredBox(color: Color(0xff071621)),
  );
}

final class _BundledMapUpdater implements FcdMapUpdateClient {
  const _BundledMapUpdater();
  @override
  Future<FcdMapUpdateResult> checkAndUpdate({
    required FcdMapDataset current,
  }) async => FcdMapUpToDate(current.version);
}
