import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_viewport.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';

const _channel = MethodChannel('app.yahagi.kancollebrowser/window_layout');

void main() {
  for (final fullscreen in [false, true]) {
    testWidgets(
      'feedback split bar visibility never resends native bounds, fullscreen=$fullscreen',
      (tester) async {
        const physicalSize = Size(1220, 824);
        const dpr = 3.25;
        final h = await _mount(
          tester,
          fullscreen: fullscreen,
          nativeSize: physicalSize,
          physicalSize: physicalSize,
          devicePixelRatio: dpr,
          pane: physicalSize / dpr,
          // The shell supplies the stable padding; this test independently
          // checks the native slot's response to raw metrics notifications.
          viewPadding: const EdgeInsets.only(bottom: 16),
        );
        final originalSlot = h.slot;
        final originalBounds = h.slot.readStableBounds()!.toMap();
        final originalWrites = h.bounds.length;
        final originalVisibility = [...h.visibility];
        const noise = [
          FakeViewPadding(),
          FakeViewPadding(top: 80),
          FakeViewPadding(bottom: 52),
          FakeViewPadding(top: 80, bottom: 52),
          FakeViewPadding(),
          FakeViewPadding(right: 52),
          FakeViewPadding(top: 80, right: 52),
          FakeViewPadding(bottom: 52, right: 52),
          FakeViewPadding(),
        ];

        // Repeated edge changes include immediate events, animation frames,
        // and the 310ms delayed navigation event observed in the feedback.
        for (var cycle = 0; cycle < 18; cycle++) {
          for (var edge = 0; edge < noise.length; edge++) {
            tester.view.viewPadding = noise[edge];
            await tester.pump();
            await tester.pump(Duration(milliseconds: edge.isEven ? 16 : 310));
            if (edge == 3) await h.publish(physicalSize);
            await tester.pump();
            expect(tester.view.physicalSize, physicalSize);
            expect(tester.view.viewInsets.bottom, 0);
            expect(tester.view.viewInsets.right, 0);
            expect(h.bounds, hasLength(originalWrites));
            expect(h.slot.readStableBounds()!.toMap(), originalBounds);
            expect(h.slot.canSynchronizeBounds, isTrue);
            expect(identical(h.slot, originalSlot), isTrue);
            expect(h.visibility, originalVisibility);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'feedback bar noise cannot postpone a real resize quiet deadline',
    (tester) async {
      const dpr = 3.25;
      final h = await _mount(
        tester,
        nativeSize: const Size(1220, 824),
        physicalSize: const Size(1220, 824),
        devicePixelRatio: dpr,
        pane: const Size(1220, 824) / dpr,
        viewPadding: const EdgeInsets.only(bottom: 16),
      );
      final originalSlot = h.slot;
      final oldWrites = h.bounds.length;
      const resized = Size(1220, 1000);
      h.resize(resized, resized / dpr);
      await h.publish(resized);
      await tester.pump();
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        tester.view.viewPadding = frame.isEven
            ? const FakeViewPadding(bottom: 52)
            : const FakeViewPadding(right: 52);
        await tester.pump();
        expect(h.bounds, hasLength(oldWrites));
        expect(h.slot.canSynchronizeBounds, isFalse);
        expect(h.slot.readStableBounds(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 7));
      expect(h.bounds, hasLength(oldWrites));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(h.bounds, hasLength(oldWrites + 1));
      expect(h.slot.canSynchronizeBounds, isTrue);
      final resizedBounds = h.slot.readStableBounds()!.toMap();
      expect(h.bounds.last.toMap(), resizedBounds);
      expect(identical(h.slot, originalSlot), isTrue);
      expect(
        h.bounds.last.width / h.bounds.last.height,
        closeTo(1200 / 720, .000001),
      );

      // A late duplicate stable report and later bar animation frames must
      // not create a second native fit for the same settled rectangle.
      await h.publish(resized);
      for (var frame = 0; frame < 18; frame++) {
        tester.view.viewPadding = frame.isEven
            ? const FakeViewPadding()
            : const FakeViewPadding(bottom: 52);
        await tester.pump(const Duration(milliseconds: 16));
        expect(h.bounds, hasLength(oldWrites + 1));
        expect(h.slot.readStableBounds()!.toMap(), resizedBounds);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'feedback bar noise waits for delayed native stability without duplicate writes',
    (tester) async {
      const dpr = 3.25;
      final h = await _mount(
        tester,
        nativeSize: const Size(1220, 824),
        physicalSize: const Size(1220, 824),
        devicePixelRatio: dpr,
        pane: const Size(1220, 824) / dpr,
        viewPadding: const EdgeInsets.only(bottom: 16),
      );
      final originalSlot = h.slot;
      final oldWrites = h.bounds.length;
      const resized = Size(1220, 1000);
      h.resize(resized, resized / dpr);
      await h.publish(resized, stable: false);
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        tester.view.viewPadding = frame.isEven
            ? const FakeViewPadding(bottom: 52)
            : const FakeViewPadding();
        await tester.pump(const Duration(milliseconds: 16));
        expect(h.bounds, hasLength(oldWrites));
        expect(h.slot.canSynchronizeBounds, isFalse);
        expect(h.slot.readStableBounds(), isNull);
      }
      await h.publish(resized);
      await tester.pump();
      await tester.pump();
      expect(h.bounds, hasLength(oldWrites + 1));
      expect(h.slot.canSynchronizeBounds, isTrue);
      expect(identical(h.slot, originalSlot), isTrue);
      final finalBounds = h.slot.readStableBounds()!.toMap();
      await h.publish(resized);
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.bounds, hasLength(oldWrites + 1));
      expect(h.slot.readStableBounds()!.toMap(), finalBounds);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failFirstWrite in [false, true]) {
    testWidgets(
      'feedback inset animation preserves an in-flight bounds reply, retry=$failFirstWrite',
      (tester) async {
        const dpr = 3.25;
        final h = await _mount(
          tester,
          nativeSize: const Size(1220, 824),
          physicalSize: const Size(1220, 824),
          devicePixelRatio: dpr,
          pane: const Size(1220, 824) / dpr,
          viewPadding: const EdgeInsets.only(bottom: 16),
        );
        final originalSlot = h.slot;
        final oldWrites = h.bounds.length;
        final reply = Completer<void>();
        h.pendingWrites.add(reply);
        addTearDown(() {
          if (!reply.isCompleted) reply.complete();
        });
        const resized = Size(1220, 1000);
        h.resize(resized, resized / dpr);
        await h.publish(resized);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(h.bounds, hasLength(oldWrites + 1));
        final pendingBounds = h.bounds.last.toMap();

        for (final height in [0, 8, 19, 31, 44, 52, 44, 31, 19, 8, 0]) {
          tester.view.viewPadding = FakeViewPadding(bottom: height.toDouble());
          await tester.pump(const Duration(milliseconds: 16));
          expect(h.bounds, hasLength(oldWrites + 1));
          expect(h.slot.readStableBounds()!.toMap(), pendingBounds);
          expect(identical(h.slot, originalSlot), isTrue);
          expect(tester.view.viewInsets.bottom, 0);
        }
        // The delayed disappearing navigation signal arrives after another
        // full resize quiet interval, while Android's old reply is pending.
        await tester.pump(const Duration(milliseconds: 310));
        await h.publish(resized);
        await tester.pump();
        expect(h.bounds, hasLength(oldWrites + 1));
        if (failFirstWrite) {
          reply.completeError(
            StateError('injected pending bounds failure'),
            StackTrace.empty,
          );
        } else {
          reply.complete();
        }
        await tester.pump();
        await tester.pump();
        await tester.pump();
        final expectedWrites = oldWrites + (failFirstWrite ? 2 : 1);
        expect(h.bounds, hasLength(expectedWrites));
        expect(h.bounds.last.toMap(), pendingBounds);
        expect(h.visibility.last, isTrue);
        expect(identical(h.slot, originalSlot), isTrue);

        for (final width in [0, 8, 19, 31, 44, 52, 44, 31, 19, 8, 0]) {
          tester.view.viewPadding = FakeViewPadding(right: width.toDouble());
          await tester.pump(const Duration(milliseconds: 16));
          expect(h.bounds, hasLength(expectedWrites));
          expect(h.slot.readStableBounds()!.toMap(), pendingBounds);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'windowed pane resizes after quiet despite permanent system-bar size difference',
    (tester) async {
      final h = await _mount(tester, nativeSize: const Size(800, 600));
      expect(h.bounds.last.width, 600);
      final previousCount = h.bounds.length;

      h.resize(const Size(800, 400), const Size(500, 240));
      await h.publish(const Size(800, 424));
      await tester.pump();
      expect(h.bounds, hasLength(previousCount));
      expect(h.slot.canSynchronizeBounds, isFalse);
      expect(h.slot.readStableBounds(), isNull);
      await tester.pump(const Duration(milliseconds: 199));
      expect(h.bounds, hasLength(previousCount));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(h.bounds.length, greaterThan(previousCount));
      expect(h.bounds.last.width, closeTo(400, .001));
      expect(h.bounds.last.height, closeTo(240, .001));
      expect(h.slot.canSynchronizeBounds, isTrue);
      final manualFitBounds = h.slot.readStableBounds();
      expect(manualFitBounds, isNotNull);
      expect(manualFitBounds!.width, closeTo(400, .001));
      expect(manualFitBounds.height, closeTo(240, .001));
    },
  );

  testWidgets(
    'fullscreen still requires exact physical size after window settling',
    (tester) async {
      final h = await _mount(tester, fullscreen: true);
      expect(h.bounds, isEmpty);
      expect(h.slot.canSynchronizeBounds, isFalse);

      h.resize(const Size(800, 400), const Size(500, 240));
      await h.publish(const Size(800, 424));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(h.bounds, isEmpty);
      expect(h.slot.canSynchronizeBounds, isFalse);
      expect(h.slot.readStableBounds(), isNull);

      await h.publish(const Size(800, 400));
      await tester.pumpAndSettle();
      expect(h.bounds, isNotEmpty);
      expect(h.slot.canSynchronizeBounds, isTrue);
      expect(h.slot.readStableBounds()!.width, closeTo(400, .001));
    },
  );

  testWidgets(
    'windowed pane still waits for native stability after Flutter quiet',
    (tester) async {
      final h = await _mount(tester, nativeSize: const Size(800, 600));
      final previousCount = h.bounds.length;
      expect(previousCount, greaterThan(0));

      h.resize(const Size(800, 400), const Size(500, 240));
      await h.publish(const Size(800, 424), stable: false);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(h.bounds, hasLength(previousCount));
      expect(h.slot.canSynchronizeBounds, isFalse);
      expect(h.slot.readStableBounds(), isNull);

      await h.publish(const Size(800, 424));
      await tester.pumpAndSettle();
      expect(h.bounds.length, greaterThan(previousCount));
      expect(h.bounds.last.width, closeTo(400, .001));
      expect(h.slot.canSynchronizeBounds, isTrue);
    },
  );

  testWidgets(
    'fullscreen toggles preserve the native slot state while switching policy',
    (tester) async {
      final h = await _mount(tester);
      final original = h.slot;
      expect(original.canSynchronizeBounds, isTrue);

      h.model.value = (pane: h.model.value.pane, fullscreen: true);
      await tester.pumpAndSettle();
      expect(identical(h.slot, original), isTrue);
      expect(h.slot.canSynchronizeBounds, isFalse);

      h.model.value = (pane: const Size(500, 240), fullscreen: false);
      await tester.pumpAndSettle();
      expect(identical(h.slot, original), isTrue);
      expect(h.slot.canSynchronizeBounds, isTrue);
      expect(h.slot.readStableBounds()!.width, closeTo(400, .001));

      h.model.value = (pane: h.model.value.pane, fullscreen: true);
      await tester.pumpAndSettle();
      expect(identical(h.slot, original), isTrue);
      expect(h.slot.canSynchronizeBounds, isFalse);
      await h.publish(const Size(800, 600));
      await tester.pumpAndSettle();
      expect(identical(h.slot, original), isTrue);
      expect(h.slot.canSynchronizeBounds, isTrue);
    },
  );

  testWidgets(
    'same-rect fullscreen change cannot attach an obsolete pending bounds write',
    (tester) async {
      final h = await _mount(tester, nativeSize: const Size(800, 600));
      final original = h.slot;
      final previousCount = h.bounds.length;
      final oldWrite = Completer<void>();
      final currentWrite = Completer<void>();
      h.pendingWrites.addAll([oldWrite, currentWrite]);
      addTearDown(() {
        if (!oldWrite.isCompleted) oldWrite.complete();
        if (!currentWrite.isCompleted) currentWrite.complete();
      });

      h.resize(const Size(800, 400), const Size(500, 240));
      await h.publish(const Size(800, 400));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(h.bounds, hasLength(previousCount + 1));
      final oldBounds = h.bounds.last;
      expect(h.visibility.last, isFalse);

      h.model.value = (pane: h.model.value.pane, fullscreen: true);
      await tester.pump();
      await tester.pump();
      expect(identical(h.slot, original), isTrue);
      final currentBounds = h.slot.readStableBounds()!;
      expect(currentBounds.left, oldBounds.left);
      expect(currentBounds.top, oldBounds.top);
      expect(currentBounds.width, oldBounds.width);
      expect(currentBounds.height, oldBounds.height);

      oldWrite.complete();
      await tester.pump();
      await tester.pump();
      expect(
        h.visibility.last,
        isFalse,
        reason: 'Only the current fullscreen generation may attach the surface',
      );
      expect(h.bounds, hasLength(previousCount + 2));
      currentWrite.complete();
      await tester.pumpAndSettle();
      expect(h.visibility.last, isTrue);
      expect(identical(h.slot, original), isTrue);
    },
  );

  testWidgets(
    'native split snapshot arriving first still permits the final windowed pane',
    (tester) async {
      final h = await _mount(tester, nativeSize: const Size(800, 600));
      await h.publish(const Size(800, 424));
      await tester.pumpAndSettle();
      expect(
        h.bounds.last.width,
        600,
        reason: 'Native topology cannot change the current Flutter pane',
      );
      final previousCount = h.bounds.length;

      h.resize(const Size(800, 400), const Size(500, 240));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 199));
      expect(h.bounds, hasLength(previousCount));
      expect(h.slot.canSynchronizeBounds, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(h.bounds.length, greaterThan(previousCount));
      expect(h.bounds.last.width, closeTo(400, .001));
      expect(h.slot.canSynchronizeBounds, isTrue);
      expect(h.slot.readStableBounds()!.height, closeTo(240, .001));
    },
  );

  testWidgets(
    'windowed video sequence keeps the full game through split rotation and repeated restore',
    (tester) async {
      final h = await _mount(tester, nativeSize: const Size(800, 600));
      await h.publish(const Size(800, 600), mode: 'single', isLandscape: true);
      await tester.pumpAndSettle();
      final original = h.slot;

      Rect rectOf(NativeGameWebViewBounds bounds) =>
          Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);

      void expectContained(
        NativeGameWebViewBounds bounds,
        Size pane,
        Rect expected,
        String stage,
      ) {
        final rect = rectOf(bounds);
        expect(rect.left, closeTo(expected.left, .001), reason: stage);
        expect(rect.top, closeTo(expected.top, .001), reason: stage);
        expect(rect.width, closeTo(expected.width, .001), reason: stage);
        expect(rect.height, closeTo(expected.height, .001), reason: stage);
        expect(rect.width / rect.height, closeTo(1200 / 720, .001));
        expect(rect.left, greaterThanOrEqualTo(-.001), reason: stage);
        expect(rect.top, greaterThanOrEqualTo(-.001), reason: stage);
        expect(rect.right, lessThanOrEqualTo(pane.width + .001), reason: stage);
        expect(
          rect.bottom,
          lessThanOrEqualTo(pane.height + .001),
          reason: stage,
        );
        expect(bounds.clipLeft, closeTo(0, .001), reason: stage);
        expect(bounds.clipTop, closeTo(0, .001), reason: stage);
        expect(bounds.clipWidth, closeTo(pane.width, .001), reason: stage);
        expect(bounds.clipHeight, closeTo(pane.height, .001), reason: stage);
      }

      expectContained(
        h.bounds.last,
        const Size(600, 360),
        const Rect.fromLTWH(0, 0, 600, 360),
        'initial exact whole window',
      );

      Future<void> transition({
        required String stage,
        required String mode,
        required bool isLandscape,
        required Size physicalSize,
        required Size pane,
        required Rect expected,
        required bool nativeFirst,
      }) async {
        final previousCount = h.bounds.length;
        final previousRect = rectOf(h.bounds.last);
        final nativeSize = Size(physicalSize.width, physicalSize.height + 24);

        if (!nativeFirst) h.resize(physicalSize, pane);
        await h.publish(
          nativeSize,
          stable: false,
          mode: mode,
          isLandscape: isLandscape,
        );
        expect(h.slot.canSynchronizeBounds, isFalse, reason: stage);
        expect(h.slot.readStableBounds(), isNull, reason: stage);
        if (nativeFirst) {
          await h.publish(nativeSize, mode: mode, isLandscape: isLandscape);
          h.resize(physicalSize, pane);
        }
        await tester.pump();
        expect(h.bounds, hasLength(previousCount), reason: stage);
        expect(h.slot.canSynchronizeBounds, isFalse, reason: stage);
        expect(h.slot.readStableBounds(), isNull, reason: stage);

        await tester.pump(const Duration(milliseconds: 99));
        if (!nativeFirst) {
          await h.publish(nativeSize, mode: mode, isLandscape: isLandscape);
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          h.bounds,
          hasLength(previousCount),
          reason: '$stage must wait for all 200ms of Flutter geometry quiet',
        );
        expect(h.slot.canSynchronizeBounds, isFalse, reason: stage);
        expect(h.slot.readStableBounds(), isNull, reason: stage);

        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(h.bounds.length, greaterThan(previousCount), reason: stage);
        expect(rectOf(h.bounds.last), isNot(previousRect), reason: stage);
        expectContained(h.bounds.last, pane, expected, stage);
        expect(h.slot.canSynchronizeBounds, isTrue, reason: stage);
        final manualFitBounds = h.slot.readStableBounds();
        expect(manualFitBounds, isNotNull, reason: stage);
        expectContained(manualFitBounds!, pane, expected, '$stage manual fit');
        expect(identical(h.slot, original), isTrue, reason: stage);
        expect(h.model.value.fullscreen, isFalse, reason: stage);
        expect(
          GameSurfaceViewport.fullscreenOf(h.key.currentContext!),
          isFalse,
          reason: stage,
        );
      }

      await transition(
        stage: 'landscape side-by-side split',
        mode: 'sideBySide',
        isLandscape: true,
        physicalSize: const Size(400, 600),
        pane: const Size(320, 520),
        expected: const Rect.fromLTWH(0, 164, 320, 192),
        nativeFirst: true,
      );
      await transition(
        stage: 'rotate into portrait stacked split',
        mode: 'stacked',
        isLandscape: false,
        physicalSize: const Size(600, 400),
        pane: const Size(520, 300),
        expected: const Rect.fromLTWH(10, 0, 500, 300),
        nativeFirst: false,
      );
      await transition(
        stage: 'leave split for the whole portrait window',
        mode: 'single',
        isLandscape: false,
        physicalSize: const Size(600, 800),
        pane: const Size(520, 700),
        expected: const Rect.fromLTWH(0, 194, 520, 312),
        nativeFirst: true,
      );
      await transition(
        stage: 'enter stacked split again at a different divider position',
        mode: 'stacked',
        isLandscape: false,
        physicalSize: const Size(600, 360),
        pane: const Size(520, 250),
        expected: const Rect.fromLTWH(155 / 3, 0, 1250 / 3, 250),
        nativeFirst: false,
      );
      await transition(
        stage: 'restore the whole portrait window again',
        mode: 'single',
        isLandscape: false,
        physicalSize: const Size(600, 800),
        pane: const Size(520, 700),
        expected: const Rect.fromLTWH(0, 194, 520, 312),
        nativeFirst: true,
      );
    },
  );
}

Future<_Harness> _mount(
  WidgetTester tester, {
  bool fullscreen = false,
  Size nativeSize = const Size(800, 624),
  Size physicalSize = const Size(800, 600),
  double devicePixelRatio = 1,
  Size pane = const Size(600, 360),
  EdgeInsets? viewPadding,
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = physicalSize;
  final h = _Harness(tester, fullscreen, nativeSize, pane);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _channel,
    (_) async => h.nativeLayout,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    h.model.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    );
  });
  final slot = NativeGameSurfaceSlot(
    key: h.key,
    boundsSinkIdentity: h,
    onBoundsChanged: (value) async {
      h.bounds.add(value);
      if (h.pendingWrites.isNotEmpty) await h.pendingWrites.removeAt(0).future;
    },
    onVisibilityChanged: (visible) async => h.visibility.add(visible),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: ValueListenableBuilder(
          valueListenable: h.model,
          child: slot,
          builder: (context, value, child) => SizedBox(
            width: value.pane.width,
            height: value.pane.height,
            child: GameSurfaceViewport(
              fullscreen: value.fullscreen,
              viewPadding: viewPadding,
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

class _Harness {
  _Harness(this.tester, bool fullscreen, Size nativeSize, Size pane)
    : model = ValueNotifier((pane: pane, fullscreen: fullscreen)),
      nativeLayout = _snapshot(nativeSize);

  final WidgetTester tester;
  final ValueNotifier<({Size pane, bool fullscreen})> model;
  final key = GlobalKey<NativeGameSurfaceSlotState>();
  final bounds = <NativeGameWebViewBounds>[];
  final visibility = <bool>[];
  final pendingWrites = <Completer<void>>[];
  Map<String, Object> nativeLayout;
  NativeGameSurfaceSlotState get slot => key.currentState!;

  void resize(Size physicalSize, Size pane) {
    tester.view.physicalSize = physicalSize;
    model.value = (pane: pane, fullscreen: model.value.fullscreen);
  }

  Future<void> publish(
    Size size, {
    bool stable = true,
    String mode = 'stacked',
    bool isLandscape = false,
  }) async {
    nativeLayout = _snapshot(
      size,
      stable: stable,
      mode: mode,
      isLandscape: isLandscape,
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('windowLayoutChanged', nativeLayout),
      ),
      (_) {},
    );
  }

  static Map<String, Object> _snapshot(
    Size size, {
    bool stable = true,
    String mode = 'stacked',
    bool isLandscape = false,
  }) => {
    'mode': mode,
    'isLandscape': isLandscape,
    'stable': stable,
    'windowWidth': size.width,
    'windowHeight': size.height,
  };
}
