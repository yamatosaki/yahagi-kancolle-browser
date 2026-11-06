import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_viewport.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';
import 'package:yahagi_kancolle_browser/src/layout/camera_avoidance.dart';

DisplayFeature feature(
  Rect rect, [
  DisplayFeatureType type = DisplayFeatureType.cutout,
]) => DisplayFeature(
  bounds: rect,
  type: type,
  state: DisplayFeatureState.unknown,
);

EdgeInsets resolve(
  Size size,
  List<DisplayFeature> features,
  double distance, {
  bool enabled = true,
}) => cameraAvoidanceInsets(
  size: size,
  displayFeatures: features,
  enabled: enabled,
  distance: distance,
);

void main() {
  group('camera cutout geometry', () {
    test('disabled, zero distance, and no cutout preserve full coverage', () {
      final cutout = [feature(const Rect.fromLTWH(8, 190, 24, 24))];
      expect(
        resolve(const Size(900, 400), cutout, 48, enabled: false),
        EdgeInsets.zero,
      );
      expect(resolve(const Size(900, 400), cutout, 0), EdgeInsets.zero);
      expect(resolve(const Size(900, 400), [], 48), EdgeInsets.zero);
    });

    test(
      'follows all four cutout edges without adding the system safe inset',
      () {
        const size = Size(900, 400);
        for (final row in <(Rect, EdgeInsets)>[
          (
            const Rect.fromLTWH(8, 190, 24, 24),
            const EdgeInsets.only(left: 17),
          ),
          (
            const Rect.fromLTWH(868, 190, 24, 24),
            const EdgeInsets.only(right: 17),
          ),
          (const Rect.fromLTWH(440, 8, 24, 24), const EdgeInsets.only(top: 17)),
          (
            const Rect.fromLTWH(440, 368, 24, 24),
            const EdgeInsets.only(bottom: 17),
          ),
        ]) {
          expect(resolve(size, [feature(row.$1)], 17), row.$2);
        }
      },
    );

    test('corner cutouts have a stable short-edge tie break', () {
      expect(
        resolve(const Size(900, 400), [
          feature(const Rect.fromLTWH(0, 0, 30, 30)),
        ], 36),
        const EdgeInsets.only(left: 36),
      );
      expect(
        resolve(const Size(400, 900), [
          feature(const Rect.fromLTWH(0, 0, 30, 30)),
        ], 36),
        const EdgeInsets.only(top: 36),
      );
    });

    test('cross-axis spanning notches use their actual obstructed edge', () {
      expect(
        resolve(const Size(900, 400), [
          feature(const Rect.fromLTWH(0, 0, 900, 30)),
        ], 36),
        const EdgeInsets.only(top: 36),
      );
      expect(
        resolve(const Size(400, 900), [
          feature(const Rect.fromLTWH(0, 0, 30, 900)),
        ], 36),
        const EdgeInsets.only(left: 36),
      );
      expect(
        resolve(const Size(900, 400), [
          feature(const Rect.fromLTWH(0, 370, 900, 30)),
        ], 36),
        const EdgeInsets.only(bottom: 36),
      );
    });

    test(
      'one cutout edge can use the full requested distance in normal windows',
      () {
        expect(
          resolve(const Size(900, 400), [
            feature(const Rect.fromLTWH(440, 0, 24, 24)),
          ], 120),
          const EdgeInsets.only(top: 120),
        );
        expect(
          resolve(const Size(400, 900), [
            feature(const Rect.fromLTWH(0, 440, 24, 24)),
          ], 120),
          const EdgeInsets.only(left: 120),
        );
      },
    );

    test(
      'representative brand-style cutout fixtures rotate across all edges',
      () {
        // Synthetic geometry only: these names identify screen-shape families,
        // not measurements or certification of particular commercial devices.
        final profiles = <({String name, List<DisplayFeature> features})>[
          (
            name: 'Pixel-style centered hole',
            features: [feature(const Rect.fromLTWH(188, 8, 24, 24))],
          ),
          (
            name: 'Galaxy-style dual hole',
            features: [feature(const Rect.fromLTWH(310, 8, 64, 24))],
          ),
          (
            name: 'Xiaomi-style corner hole',
            features: [feature(const Rect.fromLTWH(8, 8, 24, 24))],
          ),
          (
            name: 'OPPO-style opposite corner hole',
            features: [feature(const Rect.fromLTWH(368, 8, 24, 24))],
          ),
          (
            name: 'vivo-style teardrop',
            features: [feature(const Rect.fromLTWH(175, 0, 50, 28))],
          ),
          (
            name: 'Huawei-style pill',
            features: [feature(const Rect.fromLTWH(8, 8, 64, 28))],
          ),
          (
            name: 'wide notch',
            features: [feature(const Rect.fromLTWH(140, 0, 120, 30))],
          ),
          (name: 'unobstructed screen', features: []),
        ];
        for (final profile in profiles) {
          var size = const Size(400, 900);
          var features = profile.features;
          var expected = profile.features.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.only(top: 48);
          for (var turn = 0; turn < 4; turn++) {
            expect(
              resolve(size, features, 48),
              expected,
              reason: '${profile.name} quarter turn $turn',
            );
            final oldSize = size;
            size = Size(size.height, size.width);
            features = features
                .map(
                  (f) => feature(
                    Rect.fromLTRB(
                      oldSize.height - f.bounds.bottom,
                      f.bounds.left,
                      oldSize.height - f.bounds.top,
                      f.bounds.right,
                    ),
                    f.type,
                  ),
                )
                .toList();
            expected = EdgeInsets.fromLTRB(
              expected.bottom,
              expected.left,
              expected.top,
              expected.right,
            );
          }
        }
      },
    );

    test(
      'multiple cutouts share one distance and duplicate rectangles do not add',
      () {
        final left = feature(const Rect.fromLTWH(0, 150, 24, 48));
        final right = feature(const Rect.fromLTWH(876, 150, 24, 48));
        expect(
          resolve(const Size(900, 400), [left, left, right], 40),
          const EdgeInsets.symmetric(horizontal: 40),
        );
      },
    );

    test('folds and hinges are not camera cutouts', () {
      expect(
        resolve(const Size(900, 700), [
          feature(const Rect.fromLTWH(450, 0, 0, 700), DisplayFeatureType.fold),
          feature(
            const Rect.fromLTWH(448, 0, 4, 700),
            DisplayFeatureType.hinge,
          ),
        ], 48),
        EdgeInsets.zero,
      );
    });

    test('rejects invalid and off-window cutouts and sanitizes distance', () {
      const size = Size(900, 400);
      final hole = feature(const Rect.fromLTWH(0, 150, 24, 48));
      for (final d in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -1.0,
      ]) {
        expect(resolve(size, [hole], d), EdgeInsets.zero);
      }
      expect(resolve(size, [hole], 999), const EdgeInsets.only(left: 120));
      expect(
        resolve(size, [
          feature(const Rect.fromLTWH(2000, 0, 20, 20)),
          feature(Rect.zero),
        ], 48),
        EdgeInsets.zero,
      );
      expect(resolve(Size.zero, [hole], 48), EdgeInsets.zero);
      expect(
        resolve(const Size(double.infinity, 400), [hole], 48),
        EdgeInsets.zero,
      );
    });

    test(
      'seeded malformed/tiny/multi-cutout stress keeps a usable finite viewport',
      () {
        final random = math.Random(20261021);
        for (var i = 0; i < 12000; i++) {
          final size = Size(
            .25 + random.nextDouble() * 2500,
            .25 + random.nextDouble() * 1800,
          );
          final bounds = <DisplayFeature>[];
          for (var j = 0; j < i % 6; j++) {
            final w = 1 + random.nextDouble() * size.width * .1;
            final h = 1 + random.nextDouble() * size.height * .1;
            final corner = j % 4;
            bounds.add(
              feature(
                Rect.fromLTWH(
                  corner == 1 ? size.width - w : 0,
                  corner == 2 ? size.height - h : 0,
                  w,
                  h,
                ),
              ),
            );
          }
          final inset = resolve(size, bounds, random.nextDouble() * 400 - 20);
          for (final v in [inset.left, inset.top, inset.right, inset.bottom]) {
            expect(
              v.isFinite && v >= 0,
              isTrue,
              reason: 'seed case $i $size $inset',
            );
          }
          expect(inset.horizontal, lessThanOrEqualTo(size.width * .5 + .0001));
          expect(inset.vertical, lessThanOrEqualTo(size.height * .5 + .0001));
        }
      },
    );
  });

  testWidgets(
    'consumes layout once and gives routes the matching local media',
    (tester) async {
      const size = Size(900, 400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late MediaQueryData local;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(left: 32, bottom: 20),
              viewPadding: const EdgeInsets.only(left: 32, bottom: 20),
              displayFeatures: [
                feature(const Rect.fromLTWH(4, 170, 24, 24)),
                feature(
                  const Rect.fromLTWH(450, 0, 0, 400),
                  DisplayFeatureType.fold,
                ),
              ],
            ),
            child: CameraAvoidanceViewport(
              enabled: true,
              distance: 48,
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) {
              local = MediaQuery.of(context);
              return const SizedBox.expand(key: Key('content'));
            },
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('content'))),
        const Offset(48, 0),
      );
      expect(
        tester.getSize(find.byKey(const Key('content'))),
        const Size(852, 400),
      );
      expect(local.size, const Size(852, 400));
      expect(local.viewPadding, const EdgeInsets.only(bottom: 20));
      expect(
        local.displayFeatures.where((f) => f.type == DisplayFeatureType.cutout),
        isEmpty,
      );
      final fold = local.displayFeatures.single;
      expect(fold.type, DisplayFeatureType.fold);
      expect(fold.bounds.left, 402);
    },
  );

  testWidgets(
    'changing camera side preserves Navigator and synchronizes native game bounds',
    (tester) async {
      const size = Size(900, 400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigator = GlobalKey<NavigatorState>();
      final reports = <NativeGameWebViewBounds>[];
      Future<void> pump(bool enabled, bool right, {double keyboard = 0}) async {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                viewInsets: EdgeInsets.only(bottom: keyboard),
                displayFeatures: [
                  feature(Rect.fromLTWH(right ? 872 : 4, 170, 24, 24)),
                ],
              ),
              child: CameraAvoidanceViewport(
                enabled: enabled,
                distance: 48,
                child: child!,
              ),
            ),
            home: NativeGameSurfaceSlot(
              onBoundsChanged: (b) async => reports.add(b),
              onVisibilityChanged: (_) async {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      addTearDown(tester.view.resetViewInsets);
      await pump(false, false);
      final navState = navigator.currentState;
      final slotState = tester.state(find.byType(NativeGameSurfaceSlot));
      await pump(true, false);
      expect(reports.last.left, 48);
      expect(reports.last.width, 852);
      await pump(true, true);
      expect(reports.last.left, 0);
      expect(reports.last.width, 852);
      expect(identical(navigator.currentState, navState), isTrue);
      expect(
        identical(tester.state(find.byType(NativeGameSurfaceSlot)), slotState),
        isTrue,
      );
      await pump(false, true);
      expect(reports.last.width, 900);
      await pump(true, false, keyboard: 120);
      expect(
        reports.last.left,
        48,
        reason: 'intentional camera layout must synchronize even during IME',
      );
      expect(reports.last.width, 852);
      expect(
        identical(tester.state(find.byType(NativeGameSurfaceSlot)), slotState),
        isTrue,
      );
    },
  );

  testWidgets(
    'manual distance owns only camera-side fullscreen padding, including zero',
    (tester) async {
      tester.view.physicalSize = const Size(900, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final distance in [0.0, 1.0, 17.0, 48.0]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: const Size(900, 400),
                viewPadding: const EdgeInsets.only(left: 32, right: 20),
                displayFeatures: [feature(const Rect.fromLTWH(4, 170, 24, 24))],
              ),
              child: CameraAvoidanceViewport(
                enabled: true,
                distance: distance,
                child: child!,
              ),
            ),
            home: const GameSurfaceViewport(
              fullscreen: true,
              isLandscape: true,
              child: SizedBox.expand(key: Key('game')),
            ),
          ),
        );
        final expectedWidth = 400 * 5 / 3;
        final expectedLeft = ((900 - distance - expectedWidth) / 2)
            .roundToDouble();
        expect(
          tester.getTopLeft(find.byKey(const Key('game'))).dx,
          closeTo(distance + expectedLeft, .001),
        );
        expect(
          tester.getSize(find.byKey(const Key('game'))).width,
          closeTo(expectedWidth, .001),
        );
      }
    },
  );

  for (final hasCutout in [false, true]) {
    testWidgets('pure IME size fluctuation stays deferred, cutout=$hasCutout', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final reports = <NativeGameWebViewBounds>[];
      Future<void> onBounds(NativeGameWebViewBounds b) async => reports.add(b);
      Future<void> onVisible(bool _) async {}
      Future<void> pump(double height, double ime) async {
        tester.view.viewInsets = FakeViewPadding(bottom: ime);
        tester.view.physicalSize = Size(900, height);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: Size(900, height),
                viewInsets: EdgeInsets.only(bottom: ime),
                displayFeatures: hasCutout
                    ? [feature(const Rect.fromLTWH(4, 170, 24, 24))]
                    : [],
              ),
              child: CameraAvoidanceViewport(
                enabled: true,
                distance: 48,
                child: child!,
              ),
            ),
            home: NativeGameSurfaceSlot(
              onBoundsChanged: onBounds,
              onVisibilityChanged: onVisible,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await pump(400, 0);
      expect(reports.last.height, 400);
      await pump(368, 120);
      expect(
        reports.last.height,
        400,
        reason: 'a vendor IME fluctuation must not resize the native game',
      );
      await pump(420, 0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(reports.last.height, 420);
    });
  }

  testWidgets('manual small margins are not added again by route SafeArea', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: const Size(900, 400),
            padding: const EdgeInsets.only(left: 40, right: 20),
            viewPadding: const EdgeInsets.only(left: 40, right: 20),
            displayFeatures: [feature(const Rect.fromLTWH(4, 170, 24, 24))],
          ),
          child: CameraAvoidanceViewport(
            enabled: true,
            distance: 12,
            child: child!,
          ),
        ),
        home: const SafeArea(child: SizedBox.expand(key: Key('safe-content'))),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const Key('safe-content'))).dx, 12);
    expect(tester.getSize(find.byKey(const Key('safe-content'))).width, 868);
  });

  testWidgets('full-width notch does not inset DialogRoute a second time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 900),
            padding: const EdgeInsets.only(top: 30),
            viewPadding: const EdgeInsets.only(top: 30),
            displayFeatures: [feature(const Rect.fromLTWH(0, 0, 400, 30))],
          ),
          child: CameraAvoidanceViewport(
            enabled: true,
            distance: 17,
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const Dialog(
                child: SizedBox(height: 100, key: Key('dialog-content')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byKey(const Key('dialog-content'))).dy,
      closeTo(17 + (900 - 17) / 2, .01),
    );
  });

  testWidgets(
    'manual avoidance contains the native game even in height-constrained windows',
    (tester) async {
      tester.view.physicalSize = const Size(456, 180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: const Size(456, 180),
              displayFeatures: [feature(const Rect.fromLTWH(4, 70, 24, 24))],
            ),
            child: CameraAvoidanceViewport(
              enabled: true,
              distance: 48,
              child: child!,
            ),
          ),
          home: const GameSurfaceViewport(
            isLandscape: true,
            child: SizedBox.expand(key: Key('contained-game')),
          ),
        ),
      );
      final game = tester.getRect(find.byKey(const Key('contained-game')));
      expect(game.left, greaterThanOrEqualTo(48));
      expect(game.top, greaterThanOrEqualTo(0));
      expect(game.bottom, lessThanOrEqualTo(180));
      expect(game.width / game.height, closeTo(5 / 3, .0001));
    },
  );

  testWidgets(
    'exhausted non-camera safe area never creates overflowing game bounds',
    (tester) async {
      tester.view.physicalSize = const Size(456, 60);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: const Size(456, 60),
              viewPadding: const EdgeInsets.only(top: 30, bottom: 70),
              displayFeatures: [feature(const Rect.fromLTWH(4, 20, 24, 24))],
            ),
            child: CameraAvoidanceViewport(
              enabled: true,
              distance: 48,
              child: child!,
            ),
          ),
          home: const GameSurfaceViewport(
            centerAboveBottomInset: true,
            isLandscape: true,
            child: SizedBox.expand(key: Key('exhausted-game')),
          ),
        ),
      );
      final game = tester.getRect(find.byKey(const Key('exhausted-game')));
      expect(game.size, Size.zero);
      expect(game.left, inInclusiveRange(48, 456));
      expect(game.top, inInclusiveRange(0, 60));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unchanged corner cutout does not change sides across square IME fluctuations',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late EdgeInsets actual;
      Future<void> pump(double height, bool moved) async {
        // A real quarter turn swaps the complete 800x801 window to 801x800;
        // the IME may then reduce its reported height to 799.
        final width = moved ? 801.0 : 800.0;
        tester.view.physicalSize = Size(width, height);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQueryData(
                size: Size(width, height),
                viewInsets: EdgeInsets.only(bottom: height < 800 ? 200 : 0),
                displayFeatures: [
                  feature(Rect.fromLTWH(moved ? width - 30 : 0, 0, 30, 30)),
                ],
              ),
              child: CameraAvoidanceViewport(
                enabled: true,
                distance: 48,
                child: child!,
              ),
            ),
            home: Builder(
              builder: (context) {
                actual = CameraAvoidanceScope.maybeOf(context)!.insets;
                return const SizedBox.expand();
              },
            ),
          ),
        );
      }

      await pump(801, false);
      expect(actual, const EdgeInsets.only(top: 48));
      await pump(799, false);
      expect(actual, const EdgeInsets.only(top: 48));
      await pump(799, true);
      expect(
        actual,
        const EdgeInsets.only(right: 48),
        reason: 'actual cutout movement must still follow rotation',
      );
    },
  );

  testWidgets('startup zero size cannot poison corner cutout orientation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late EdgeInsets actual;
    Future<void> pump(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              displayFeatures: [feature(const Rect.fromLTWH(0, 0, 30, 30))],
            ),
            child: CameraAvoidanceViewport(
              enabled: true,
              distance: 48,
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) {
              actual = CameraAvoidanceScope.maybeOf(context)!.insets;
              return const SizedBox.expand();
            },
          ),
        ),
      );
    }

    await pump(Size.zero);
    expect(actual, EdgeInsets.zero);
    await pump(const Size(900, 400));
    expect(actual, const EdgeInsets.only(left: 48));
  });
}
