import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/layout/window_layout_controller.dart';

const _channel = MethodChannel('app.yahagi.kancollebrowser/window_layout');

Future<void> _publish(
  String mode,
  bool isLandscape, {
  bool? stable,
  int? width,
  int? height,
  Map<String, num>? stableInsets,
  int? insetsViewWidth,
  int? insetsViewHeight,
}) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('windowLayoutChanged', {
            'mode': mode,
            'isLandscape': isLandscape,
            'stable': ?stable,
            'windowWidth': ?width,
            'windowHeight': ?height,
            'stableInsets': ?stableInsets,
            'insetsViewWidth': ?insetsViewWidth,
            'insetsViewHeight': ?insetsViewHeight,
          }),
        ),
        (_) {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'stable inset pixels are normalized once and bound to the Flutter view',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _channel,
            (_) async => {
              'mode': 'stacked',
              'isLandscape': false,
              'stable': true,
              'windowWidth': 1220,
              'windowHeight': 824,
              'stableInsets': {'left': 0, 'top': 0, 'right': 0, 'bottom': 52},
              'insetsViewWidth': 1220,
              'insetsViewHeight': 824,
            },
          );
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      EdgeInsets? padding(Size size, [double dpr = 3.25]) => controller
          .stableViewPadding(physicalViewSize: size, devicePixelRatio: dpr);
      expect(padding(const Size(1220, 824)), const EdgeInsets.only(bottom: 16));
      expect(padding(const Size(1220, 772)), isNull);
      expect(padding(const Size(1220, 824), 0), isNull);
      await _publish(
        'stacked',
        false,
        stable: false,
        width: 1220,
        height: 824,
        stableInsets: {'left': 0, 'top': 0, 'right': 0, 'bottom': 52},
        insetsViewWidth: 1220,
        insetsViewHeight: 824,
      );
      expect(padding(const Size(1220, 824)), isNull);

      // Windowed Flutter has already excluded the bar. Native projection reports
      // zero, so the same 52px must not be reserved a second time.
      await _publish(
        'stacked',
        false,
        stable: true,
        width: 1220,
        height: 824,
        stableInsets: {'left': 0, 'top': 0, 'right': 0, 'bottom': 0},
        insetsViewWidth: 1220,
        insetsViewHeight: 772,
      );
      expect(
        controller.canSynchronize(
          const Size(1220, 772),
          requireMatchingPhysicalSize: false,
        ),
        isTrue,
      );
      expect(padding(const Size(1220, 772)), EdgeInsets.zero);
      var notifications = 0;
      controller.addListener(() => notifications++);
      await _publish(
        'stacked',
        false,
        stable: true,
        width: 1220,
        height: 824,
        stableInsets: {'left': 0, 'top': 0, 'right': 0, 'bottom': 104},
        insetsViewWidth: 1220,
        insetsViewHeight: 772,
      );
      expect(notifications, 1);
      expect(padding(const Size(1220, 772)), const EdgeInsets.only(bottom: 32));
    },
  );

  test('legacy and malformed inset samples leave topology usable', () {
    for (final insets in [
      null,
      {'bottom': 52},
      {'left': 0, 'top': 0, 'right': 0, 'bottom': -1},
      {'left': 0, 'top': 0, 'right': 0, 'bottom': double.nan},
    ]) {
      final snapshot = WindowLayoutSnapshot.fromMap({
        'mode': 'stacked',
        'isLandscape': false,
        'stableInsets': insets,
        'insetsViewWidth': 1220,
        'insetsViewHeight': 824,
      });
      expect(snapshot?.mode, WindowLayoutMode.stacked);
      expect(snapshot?.physicalStableInsets, isNull);
      expect(snapshot?.insetsViewSize, isNull);
    }
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test(
    'windowed stable permission tolerates system-bar size differences while strict permission does not',
    () async {
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      const flutterSize = Size(1080, 1017);
      await _publish('stacked', false, stable: true, width: 1080, height: 1080);

      expect(controller.canSynchronize(flutterSize), isFalse);
      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: true,
        ),
        isFalse,
      );
      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: false,
        ),
        isTrue,
      );
      expect(controller.canSynchronize(flutterSize), isFalse);
    },
  );

  test(
    'windowed permission still waits for the initial read and native stable state',
    () async {
      final initial = Completer<Map<String, Object>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (_) => initial.future);
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      final initialize = controller.initialize();
      const flutterSize = Size(1080, 1017);

      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: false,
        ),
        isFalse,
        reason: 'Bypassing the size comparison must not bypass initialization',
      );
      initial.complete({
        'mode': 'stacked',
        'isLandscape': false,
        'stable': false,
        'windowWidth': 1080,
        'windowHeight': 1080,
      });
      await initialize;
      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: false,
        ),
        isFalse,
        reason: 'The native window is still resizing after its initial reply',
      );
      await _publish(
        'stacked',
        false,
        stable: false,
        width: 1080,
        height: 1080,
      );
      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: false,
        ),
        isFalse,
      );
      await _publish('stacked', false, stable: true, width: 1080, height: 1080);
      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: false,
        ),
        isTrue,
      );
    },
  );

  test(
    'loose mismatched permission cannot change the remembered fullscreen axis',
    () async {
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      const flutterSize = Size(800, 600);
      await _publish('sideBySide', true, stable: true, width: 800, height: 600);
      expect(controller.canSynchronize(flutterSize), isTrue);
      expect(
        controller.fitAxis(isLandscape: true, physicalSize: flutterSize),
        GameFitAxis.width,
      );

      await _publish('stacked', true, stable: true, width: 800, height: 663);
      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: false,
        ),
        isTrue,
      );
      expect(
        controller.fitAxis(isLandscape: true, physicalSize: flutterSize),
        GameFitAxis.width,
        reason: 'The loose stacked permission must not replace a matching axis',
      );
      await _publish('unknown', true, stable: true, width: 800, height: 600);
      expect(
        controller.fitAxis(isLandscape: true, physicalSize: flutterSize),
        GameFitAxis.width,
      );
    },
  );

  test(
    'loose permission can remember an axis when physical sizes really match',
    () async {
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      const flutterSize = Size(800, 600);
      await _publish('sideBySide', true, stable: true, width: 800, height: 600);
      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: false,
        ),
        isTrue,
      );
      await _publish('unknown', true, stable: true, width: 800, height: 600);
      expect(
        controller.fitAxis(isLandscape: true, physicalSize: flutterSize),
        GameFitAxis.width,
      );
    },
  );

  test(
    'matching native permission records stable axis before a fullscreen build consumes it',
    () async {
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      const size = Size(800, 600);
      await _publish('stacked', true, stable: true, width: 800, height: 600);
      expect(controller.canSynchronize(size), isTrue);
      await _publish('sideBySide', true, stable: true, width: 800, height: 600);
      expect(controller.canSynchronize(size), isTrue);
      await _publish('unknown', true, stable: true, width: 800, height: 600);
      expect(
        controller.fitAxis(isLandscape: true, physicalSize: size),
        GameFitAxis.width,
      );
    },
  );

  test(
    'reads native initial layout and follows split topology independently of orientation',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            expect(call.method, 'getWindowLayout');
            return {'mode': 'sideBySide', 'isLandscape': false};
          });
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.fitAxis(isLandscape: true), GameFitAxis.width);
      await _publish('stacked', true);
      expect(controller.fitAxis(isLandscape: false), GameFitAxis.height);
      await _publish('single', true);
      expect(controller.fitAxis(isLandscape: false), GameFitAxis.height);
      await _publish('single', false);
      expect(controller.fitAxis(isLandscape: true), GameFitAxis.width);
    },
  );

  test('unknown and PiP layouts retain the last stable fit axis', () async {
    final controller = WindowLayoutController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await _publish('sideBySide', true);
    await _publish('unknown', true);
    expect(controller.fitAxis(isLandscape: true), GameFitAxis.width);
    await _publish('stacked', false);
    await _publish('pictureInPicture', false);
    expect(controller.fitAxis(isLandscape: false), GameFitAxis.height);
  });

  test(
    'missing native plugin safely falls back to the caller orientation',
    () async {
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.fitAxis(isLandscape: true), GameFitAxis.height);
      expect(controller.fitAxis(isLandscape: false), GameFitAxis.width);
      await _publish('unknown', false);
      expect(controller.fitAxis(isLandscape: true), GameFitAxis.width);
    },
  );

  test(
    'late initial response cannot overwrite a newer native layout event',
    () async {
      final initial = Completer<Map<String, Object>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (_) => initial.future);
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      final initialize = controller.initialize();
      await _publish('sideBySide', true);
      initial.complete({'mode': 'stacked', 'isLandscape': true});
      await initialize;
      expect(controller.fitAxis(isLandscape: true), GameFitAxis.width);
    },
  );

  test(
    'repeated equivalent native layouts notify once and dispose detaches handler',
    () async {
      final controller = WindowLayoutController();
      await controller.initialize();
      var changes = 0;
      controller.addListener(() => changes++);
      await _publish('stacked', false);
      await _publish('stacked', false);
      expect(changes, 1);
      controller.dispose();
      await _publish('single', true);
      expect(changes, 1);
    },
  );

  test(
    'windowed captioned mode allows fullscreen synchronization when insetsViewSize matches Flutter physical size',
    () async {
      final controller = WindowLayoutController();
      addTearDown(controller.dispose);
      await controller.initialize();
      const flutterSize = Size(973, 438);
      await _publish(
        'stacked',
        true,
        stable: true,
        width: 973,
        height: 462,
        stableInsets: {'left': 0, 'top': 0, 'right': 0, 'bottom': 0},
        insetsViewWidth: 973,
        insetsViewHeight: 438,
      );

      expect(
        controller.canSynchronize(
          flutterSize,
          requireMatchingPhysicalSize: true,
        ),
        isTrue,
      );
      expect(
        controller.fitAxis(isLandscape: true, physicalSize: flutterSize),
        GameFitAxis.height,
      );
    },
  );
}
