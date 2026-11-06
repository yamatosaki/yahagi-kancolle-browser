import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';
import 'package:yahagi_kancolle_browser/src/layout/camera_avoidance.dart';

const _slotKey = Key('ime-audit-slot');

DisplayFeature _cutout(Rect bounds) => DisplayFeature(
  bounds: bounds,
  type: DisplayFeatureType.cutout,
  state: DisplayFeatureState.unknown,
);

final class _Harness {
  final bounds = <NativeGameWebViewBounds>[];
  final visibility = <bool>[];
  EdgeInsets insets = EdgeInsets.zero;
  Future<void> Function(NativeGameWebViewBounds)? deliver;

  Future<void> onBounds(NativeGameWebViewBounds value) async {
    bounds.add(value);
    await deliver?.call(value);
  }

  Future<void> onVisible(bool value) async => visibility.add(value);

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(900, 400),
    double ime = 0,
    bool enabled = true,
    double distance = 48,
    List<DisplayFeature>? cutouts,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: ime);
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            viewInsets: EdgeInsets.only(bottom: ime),
            displayFeatures:
                cutouts ?? [_cutout(const Rect.fromLTWH(4, 170, 24, 24))],
          ),
          child: CameraAvoidanceViewport(
            enabled: enabled,
            distance: distance,
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) {
            insets = CameraAvoidanceScope.maybeOf(context)!.insets;
            return NativeGameSurfaceSlot(
              key: _slotKey,
              onBoundsChanged: onBounds,
              onVisibilityChanged: onVisible,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void expectSynchronized(WidgetTester tester) {
    final slot = tester.getRect(find.byKey(_slotKey));
    expect(bounds.last.left, slot.left);
    expect(bounds.last.top, slot.top);
    expect(bounds.last.width, slot.width);
    expect(bounds.last.height, slot.height);
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  void restoreView(WidgetTester tester) {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets(
    'rotating camera geometry waits for window settling while manual distance stays immediate',
    (tester) async {
      restoreView(tester);
      final harness = _Harness();
      await harness.pump(tester);
      expect(harness.bounds, hasLength(1));
      await harness.pump(
        tester,
        size: const Size(400, 900),
        cutouts: [_cutout(const Rect.fromLTWH(170, 4, 24, 24))],
      );
      expect(harness.bounds, hasLength(1));
      expect(harness.visibility, [true]);
      await harness.pump(
        tester,
        size: const Size(400, 900),
        distance: 96,
        cutouts: [_cutout(const Rect.fromLTWH(170, 4, 24, 24))],
      );
      expect(harness.bounds, hasLength(2));
      harness.expectSynchronized(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(harness.bounds, hasLength(2));
    },
  );

  testWidgets(
    'camera enable, distance, and edge changes synchronize during IME',
    (tester) async {
      restoreView(tester);
      final harness = _Harness();
      await harness.pump(tester);
      final initialState = tester.state(find.byKey(_slotKey));
      await harness.pump(tester, ime: 140);
      for (final distance in [96.0, 8.0, 0.0, 120.0, 48.0]) {
        await harness.pump(tester, ime: 140, distance: distance);
        harness.expectSynchronized(tester);
      }
      for (final enabled in [false, true, false, true]) {
        await harness.pump(tester, ime: 140, enabled: enabled);
        harness.expectSynchronized(tester);
      }
      for (final rect in [
        const Rect.fromLTWH(872, 170, 24, 24),
        const Rect.fromLTWH(430, 2, 24, 24),
        const Rect.fromLTWH(430, 374, 24, 24),
        const Rect.fromLTWH(4, 170, 24, 24),
      ]) {
        await harness.pump(tester, ime: 140, cutouts: [_cutout(rect)]);
        harness.expectSynchronized(tester);
      }
      expect(
        identical(initialState, tester.state(find.byKey(_slotKey))),
        isTrue,
      );
      await harness.pump(tester);
      harness.expectSynchronized(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delayed camera bounds coalesce without revealing stale geometry',
    (tester) async {
      restoreView(tester);
      final harness = _Harness();
      await harness.pump(tester);
      final gate = Completer<void>();
      var active = 0;
      var maximumActive = 0;
      final applied = <NativeGameWebViewBounds>[];
      harness.deliver = (value) async {
        active++;
        maximumActive = active > maximumActive ? active : maximumActive;
        if (applied.isEmpty) await gate.future;
        applied.add(value);
        active--;
      };
      await harness.pump(tester, ime: 140, distance: 96);
      for (final distance in [8.0, 0.0, 120.0, 48.0]) {
        await harness.pump(tester, ime: 140, distance: distance);
      }
      await harness.pump(
        tester,
        ime: 140,
        cutouts: [_cutout(const Rect.fromLTWH(872, 170, 24, 24))],
      );
      expect(maximumActive, 1);
      expect(applied, isEmpty);
      expect(harness.visibility.last, isFalse);
      gate.complete();
      await tester.pump();
      await tester.pump();
      harness.expectSynchronized(tester);
      expect(applied, hasLength(2));
      expect(applied.last.left, 0);
      expect(applied.last.width, 852);
      expect(harness.visibility.last, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('camera bounds retry during IME and recover latest geometry', (
    tester,
  ) async {
    restoreView(tester);
    final harness = _Harness();
    await harness.pump(tester);
    var failures = 0;
    harness.deliver = (_) async {
      if (failures++ < 2) throw StateError('expected transient bounds failure');
    };
    await harness.pump(tester, ime: 140, distance: 96);
    await tester.pump();
    await tester.pump();
    expect(failures, 3);
    harness.expectSynchronized(tester);
    expect(harness.visibility.last, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid rotations with IME entry and exit finish at current bounds',
    (tester) async {
      restoreView(tester);
      final harness = _Harness();
      await harness.pump(tester);
      final slotState = tester.state(find.byKey(_slotKey));
      final sizes = [
        const Size(900, 400),
        const Size(400, 900),
        const Size(900, 400),
        const Size(400, 900),
      ];
      final cutouts = [
        const Rect.fromLTWH(4, 170, 24, 24),
        const Rect.fromLTWH(170, 4, 24, 24),
        const Rect.fromLTWH(872, 170, 24, 24),
        const Rect.fromLTWH(170, 872, 24, 24),
      ];
      for (var index = 0; index < 64; index++) {
        await harness.pump(
          tester,
          size: sizes[index % sizes.length],
          ime: index % 3 == 0 ? 0 : 140 + (index % 4) * 5,
          distance: 24 + (index % 5) * 12,
          cutouts: [_cutout(cutouts[index % cutouts.length])],
        );
        harness.expectSynchronized(tester);
        expect(harness.visibility.last, isTrue);
        expect(
          identical(slotState, tester.state(find.byKey(_slotKey))),
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transient missing cutout must not poison stationary corner axis', (
    tester,
  ) async {
    restoreView(tester);
    final harness = _Harness();
    final corner = [_cutout(const Rect.fromLTWH(0, 0, 30, 30))];
    await harness.pump(tester, size: const Size(800, 801), cutouts: corner);
    expect(harness.insets, const EdgeInsets.only(top: 48));
    await harness.pump(
      tester,
      size: const Size(800, 799),
      ime: 200,
      cutouts: [],
    );
    await harness.pump(
      tester,
      size: const Size(800, 799),
      ime: 200,
      cutouts: corner,
    );
    await harness.pump(tester, size: const Size(800, 801), cutouts: corner);
    expect(
      harness.insets,
      const EdgeInsets.only(top: 48),
      reason:
          'The physical cutout has returned to the original portrait '
          'geometry after IME; its axis cannot stay at the temporary IME axis.',
    );
    harness.expectSynchronized(tester);
  });

  testWidgets('pure IME clipping of a stationary cutout stays deferred', (
    tester,
  ) async {
    restoreView(tester);
    final harness = _Harness();
    await harness.pump(tester);
    final before = harness.bounds.last;
    final count = harness.bounds.length;
    await harness.pump(tester, size: const Size(900, 160), ime: 240);
    expect(
      harness.bounds,
      hasLength(count),
      reason:
          'A stationary cutout clipped out only by IME shrink must not '
          'force the native viewport into the temporary keyboard dimensions.',
    );
    expect(harness.bounds.last.height, before.height);
  });

  testWidgets('real resize updates the next IME camera window baseline', (
    tester,
  ) async {
    restoreView(tester);
    final harness = _Harness();
    final cutouts = [_cutout(const Rect.fromLTWH(430, 2, 24, 24))];
    await harness.pump(tester, distance: 120, cutouts: cutouts);
    expect(harness.insets.top, 120);
    final count = harness.bounds.length;
    await harness.pump(
      tester,
      size: const Size(900, 160),
      distance: 120,
      cutouts: cutouts,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(harness.bounds, hasLength(count + 1));
    expect(harness.insets.top, 80);
    harness.expectSynchronized(tester);
    final resizedBounds = harness.bounds.last;
    expect(resizedBounds.top, 80);
    expect(resizedBounds.height, 80);
    await harness.pump(
      tester,
      size: const Size(900, 80),
      ime: 80,
      distance: 120,
      cutouts: cutouts,
    );
    expect(harness.insets.top, 40);
    expect(
      harness.bounds,
      hasLength(count + 1),
      reason:
          'The newest non-IME window is 900 by 160, so entering IME must '
          'keep its synchronization inset of 80 rather than reuse the initial '
          '400-high window and manufacture a deliberate change to 120.',
    );
    expect(harness.bounds.last.top, resizedBounds.top);
    expect(harness.bounds.last.height, resizedBounds.height);
  });

  testWidgets('IME side flip retains the complete camera classification window', (
    tester,
  ) async {
    restoreView(tester);
    final harness = _Harness();
    final left = [_cutout(const Rect.fromLTWH(4, 170, 24, 24))];
    final right = [_cutout(const Rect.fromLTWH(872, 170, 24, 24))];
    await harness.pump(tester, cutouts: left);
    expect(harness.insets, const EdgeInsets.only(left: 48));
    final count = harness.bounds.length;
    await harness.pump(
      tester,
      size: const Size(900, 160),
      ime: 240,
      cutouts: left,
    );
    expect(harness.bounds, hasLength(count));
    await harness.pump(
      tester,
      size: const Size(900, 160),
      ime: 240,
      cutouts: right,
    );
    expect(
      harness.insets,
      const EdgeInsets.only(right: 48),
      reason:
          'Cutout movement during IME does not replace the complete '
          '900-by-400 classification window with its 160-high visible portion.',
    );
    expect(harness.bounds, hasLength(count + 1));
    harness.expectSynchronized(tester);
    expect(harness.bounds.last.left, 0);
    expect(harness.bounds.last.width, 852);
  });

  testWidgets(
    'rotation during IME classifies cutout in the rotated full window',
    (tester) async {
      restoreView(tester);
      final harness = _Harness();
      final top = [_cutout(const Rect.fromLTWH(170, 4, 24, 24))];
      await harness.pump(tester, size: const Size(400, 900), cutouts: top);
      expect(harness.insets, const EdgeInsets.only(top: 48));
      final count = harness.bounds.length;
      await harness.pump(
        tester,
        size: const Size(400, 660),
        ime: 240,
        cutouts: top,
      );
      expect(harness.bounds, hasLength(count));
      await harness.pump(
        tester,
        size: const Size(900, 160),
        ime: 240,
        cutouts: [_cutout(const Rect.fromLTWH(4, 170, 24, 24))],
      );
      expect(
        harness.insets,
        const EdgeInsets.only(left: 48),
        reason:
            'The rotated full window is 900 by 400 even though IME leaves '
            'only 160 logical pixels visible; the camera must remain left.',
      );
      expect(harness.bounds, hasLength(count + 1));
      harness.expectSynchronized(tester);
      expect(harness.bounds.last.left, 48);
      expect(harness.bounds.last.width, 852);
    },
  );

  for (final edge in [CameraAvoidanceEdge.top, CameraAvoidanceEdge.bottom]) {
    testWidgets('pure IME half-axis cap stays deferred for $edge', (
      tester,
    ) async {
      restoreView(tester);
      final harness = _Harness();
      final cutouts = [
        _cutout(
          Rect.fromLTWH(430, edge == CameraAvoidanceEdge.top ? 2 : 374, 24, 24),
        ),
      ];
      await harness.pump(tester, distance: 120, cutouts: cutouts);
      final before = harness.bounds.last;
      final count = harness.bounds.length;
      expect(harness.insets.top + harness.insets.bottom, 120);
      await harness.pump(
        tester,
        size: const Size(900, 160),
        ime: 240,
        distance: 120,
        cutouts: cutouts,
      );
      expect(
        edge == CameraAvoidanceEdge.top
            ? harness.insets.top
            : harness.insets.bottom,
        80,
        reason:
            'The actual Flutter inset remains capped to half the current '
            'viewport while keeping the camera on its original edge.',
      );
      expect(
        harness.bounds,
        hasLength(count),
        reason:
            'Half-axis protection caused only by IME shrink must not '
            'force native bounds into the temporary keyboard dimensions.',
      );
      expect(harness.bounds.last.top, before.top);
      expect(harness.bounds.last.height, before.height);
      await harness.pump(tester, distance: 120, cutouts: cutouts);
      harness.expectSynchronized(tester);
    });

    testWidgets(
      'intentional distance still synchronizes under IME cap for $edge',
      (tester) async {
        restoreView(tester);
        final harness = _Harness();
        final cutouts = [
          _cutout(
            Rect.fromLTWH(
              430,
              edge == CameraAvoidanceEdge.top ? 2 : 374,
              24,
              24,
            ),
          ),
        ];
        await harness.pump(tester, distance: 120, cutouts: cutouts);
        final count = harness.bounds.length;
        await harness.pump(
          tester,
          size: const Size(900, 160),
          ime: 240,
          distance: 120,
          cutouts: cutouts,
        );
        expect(harness.bounds, hasLength(count));
        await harness.pump(
          tester,
          size: const Size(900, 160),
          ime: 240,
          distance: 100,
          cutouts: cutouts,
        );
        expect(
          harness.bounds,
          hasLength(count + 1),
          reason:
              'A deliberate distance change must synchronize even though '
              'both distances produce the same actual half-axis cap of 80.',
        );
        harness.expectSynchronized(tester);
        expect(harness.insets.top + harness.insets.bottom, 80);
        await harness.pump(
          tester,
          size: const Size(900, 160),
          ime: 240,
          distance: 100,
          enabled: false,
          cutouts: cutouts,
        );
        harness.expectSynchronized(tester);
        expect(harness.insets, EdgeInsets.zero);
      },
    );
  }
}
