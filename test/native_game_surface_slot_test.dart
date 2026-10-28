import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_workspace_visibility.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_visibility.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';

void main() {
  group('NativeGameSurfaceVisibility', () {
    test(
      'superseded visibility waiters settle after latest delivery',
      () async {
        final first = Completer<void>();
        final latest = Completer<void>();
        var calls = 0;
        final visibility = NativeGameSurfaceVisibility((_) async {
          calls++;
          if (calls == 1) await first.future;
          if (calls == 2) await latest.future;
        });
        final attach = visibility.setSlotAttached(true);
        var hiddenSettled = false;
        final hide = visibility
            .setRouteVisible(false)
            .then((_) => hiddenSettled = true);
        final show = visibility.setRouteVisible(true);
        first.complete();
        await Future<void>.delayed(Duration.zero);
        expect(calls, 2);
        expect(hiddenSettled, isFalse);
        latest.complete();
        await Future.wait([attach, hide, show]);
        expect(hiddenSettled, isTrue);
        await visibility.dispose();
      },
    );

    test(
      'latest delivery failure reaches superseded visibility waiters',
      () async {
        final first = Completer<void>();
        final latest = Completer<void>();
        var calls = 0;
        final visibility = NativeGameSurfaceVisibility((_) async {
          calls++;
          if (calls == 1) await first.future;
          if (calls == 2) {
            await latest.future;
            throw StateError('injected latest delivery failure');
          }
        });
        final attach = visibility.setSlotAttached(true);
        final errors = <int>[];
        final hide = visibility.setRouteVisible(false).catchError((Object _) {
          errors.add(2);
        });
        final show = visibility.setRouteVisible(true).catchError((Object _) {
          errors.add(3);
        });
        first.complete();
        await Future<void>.delayed(Duration.zero);
        latest.complete();
        await Future.wait([attach, hide, show]);
        expect(errors, [2, 3]);
        await visibility.dispose();
      },
    );

    test('combines route app and slot visibility before reporting', () async {
      final reports = <bool>[];
      final visibility = NativeGameSurfaceVisibility((visible) async {
        reports.add(visible);
      });

      await visibility.setSlotAttached(true);
      await visibility.setRouteVisible(false);
      await visibility.setRouteVisible(true);
      await visibility.setAppVisible(false);
      await visibility.setAppVisible(true);

      expect(reports, <bool>[true, false, true, false, true]);
    });

    test(
      'coalesces superseded changes and recovers after callback failure',
      () async {
        final reports = <bool>[];
        final firstReport = Completer<void>();
        var calls = 0;
        final visibility = NativeGameSurfaceVisibility((visible) async {
          calls++;
          reports.add(visible);
          if (calls == 1) {
            await firstReport.future;
            throw StateError('expected failure');
          }
        });

        final attach = visibility.setSlotAttached(true);
        final hide = visibility.setRouteVisible(false);
        final show = visibility.setRouteVisible(true);
        firstReport.complete();

        await expectLater(attach, throwsStateError);
        await hide;
        await show;

        expect(reports, <bool>[true, true]);
      },
    );

    test('dispose requests false once', () async {
      final reports = <bool>[];
      final visibility = NativeGameSurfaceVisibility((visible) async {
        reports.add(visible);
      });

      await visibility.setSlotAttached(true);
      await visibility.dispose();
      await visibility.dispose();

      expect(reports, <bool>[true, false]);
    });

    test(
      'reports visible for only the true true true truth-table row',
      () async {
        for (final row in <({bool route, bool app, bool attached})>[
          (route: false, app: false, attached: false),
          (route: false, app: false, attached: true),
          (route: false, app: true, attached: false),
          (route: false, app: true, attached: true),
          (route: true, app: false, attached: false),
          (route: true, app: false, attached: true),
          (route: true, app: true, attached: false),
          (route: true, app: true, attached: true),
        ]) {
          final reports = <bool>[];
          final visibility = NativeGameSurfaceVisibility((visible) async {
            reports.add(visible);
          });

          await visibility.setRouteVisible(row.route);
          await visibility.setAppVisible(row.app);
          await visibility.setSlotAttached(row.attached);

          expect(
            reports,
            row.route && row.app && row.attached ? <bool>[true] : isEmpty,
          );
        }
      },
    );

    test('uses an updated callback for subsequent reports', () async {
      final firstCallbackReports = <bool>[];
      final secondCallbackReports = <bool>[];
      final visibility = NativeGameSurfaceVisibility((visible) async {
        firstCallbackReports.add(visible);
      });

      await visibility.setSlotAttached(true);
      visibility.updateCallback((visible) async {
        secondCallbackReports.add(visible);
      });
      await visibility.setRouteVisible(false);
      await visibility.setRouteVisible(true);

      expect(firstCallbackReports, <bool>[true]);
      expect(secondCallbackReports, <bool>[false, true]);
    });

    test('retries a failed false report when dispose is repeated', () async {
      final reports = <bool>[];
      var falseAttempts = 0;
      final visibility = NativeGameSurfaceVisibility((visible) async {
        reports.add(visible);
        if (!visible && ++falseAttempts == 1) {
          throw StateError('expected false failure');
        }
      });

      await visibility.setSlotAttached(true);
      await expectLater(visibility.dispose(), throwsStateError);
      await visibility.dispose();

      expect(reports, <bool>[true, false, false]);
    });

    test(
      'uses the current callback for work queued behind a pending report',
      () async {
        final firstReports = <bool>[];
        final secondReports = <bool>[];
        final firstCompletes = Completer<void>();
        var active = 0;
        var maxActive = 0;
        final visibility = NativeGameSurfaceVisibility((visible) {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          firstReports.add(visible);
          return firstCompletes.future.whenComplete(() => active--);
        });

        final show = visibility.setSlotAttached(true);
        final hide = visibility.setRouteVisible(false);
        visibility.updateCallback((visible) async {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          secondReports.add(visible);
          active--;
        });
        firstCompletes.complete();

        await show;
        await hide;

        expect(firstReports, <bool>[true]);
        expect(secondReports, <bool>[false]);
        expect(maxActive, 1);
      },
    );
  });

  group('NativeGameSurfaceSlot', () {
    testWidgets(
      'reports logical bounds and the Flutter view DPR once attached',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        final bounds = <NativeGameWebViewBounds>[];

        await tester.pumpWidget(
          _slotApp(
            width: 100,
            height: 50,
            onBoundsChanged: (value) async => bounds.add(value),
          ),
        );
        await tester.pump();

        expect(bounds, hasLength(1));
        expect(bounds.single.toMap(), <String, double>{
          'left': 0,
          'top': 0,
          'width': 100,
          'height': 50,
          'devicePixelRatio': 2,
        });
      },
    );

    testWidgets(
      'starts hidden for background lifecycle states and visible for inactive',
      (tester) async {
        addTearDown(() {
          tester.binding.resetInternalState();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        });
        for (final state in <AppLifecycleState>[
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.detached,
        ]) {
          final visibility = <bool>[];
          tester.binding.handleAppLifecycleStateChanged(state);

          await tester.pumpWidget(
            _slotApp(
              onVisibilityChanged: (value) async => visibility.add(value),
              useCurrentLifecycle: true,
            ),
          );
          await tester.pump();
          expect(
            visibility,
            isEmpty,
            reason: 'initial $state must stay hidden',
          );

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(visibility, <bool>[true]);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        }

        final inactiveVisibility = <bool>[];
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpWidget(
          _slotApp(
            onVisibilityChanged: (value) async => inactiveVisibility.add(value),
            useCurrentLifecycle: true,
          ),
        );
        await tester.pump();
        expect(inactiveVisibility, <bool>[
          true,
        ], reason: 'initial inactive state must start visible');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'deduplicates equal bounds and reports changed size position and DPR',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final bounds = <NativeGameWebViewBounds>[];

        await tester.pumpWidget(
          _slotApp(
            width: 100,
            height: 50,
            left: 10,
            top: 20,
            onBoundsChanged: (value) async => bounds.add(value),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(bounds, hasLength(1));

        await tester.pumpWidget(
          _slotApp(
            width: 120,
            height: 50,
            left: 15,
            top: 20,
            onBoundsChanged: (value) async => bounds.add(value),
          ),
        );
        await tester.pump();
        tester.view.devicePixelRatio = 2;
        await tester.pump();

        expect(bounds.map((value) => value.toMap()), <Map<String, double>>[
          <String, double>{
            'left': 10,
            'top': 20,
            'width': 100,
            'height': 50,
            'devicePixelRatio': 1,
          },
          <String, double>{
            'left': 15,
            'top': 20,
            'width': 120,
            'height': 50,
            'devicePixelRatio': 1,
          },
          <String, double>{
            'left': 15,
            'top': 20,
            'width': 120,
            'height': 50,
            'devicePixelRatio': 2,
          },
        ]);
      },
    );

    testWidgets('coalesces repeated metrics changes in one frame', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final bounds = <NativeGameWebViewBounds>[];
      await tester.pumpWidget(
        _slotApp(onBoundsChanged: (value) async => bounds.add(value)),
      );
      await tester.pump();
      tester.view.devicePixelRatio = 2;
      tester.binding.handleMetricsChanged();
      tester.binding.handleMetricsChanged();
      tester.binding.handleMetricsChanged();
      await tester.pump();

      expect(bounds, hasLength(2));
    });

    testWidgets('defers bounds updates until the IME closes', (tester) async {
      addTearDown(tester.view.resetViewInsets);
      final bounds = <NativeGameWebViewBounds>[];
      await tester.pumpWidget(
        _slotApp(
          width: 100,
          onBoundsChanged: (value) async => bounds.add(value),
        ),
      );
      await tester.pump();
      expect(bounds.map((value) => value.width), <double>[100]);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpWidget(
        _slotApp(
          width: 120,
          onBoundsChanged: (value) async => bounds.add(value),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        bounds.map((value) => value.width),
        <double>[100],
        reason: 'the native overlay must not move while text input is active',
      );

      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump();

      expect(bounds.map((value) => value.width), <double>[100, 120]);
    });

    testWidgets('retries failed static bounds on a later frame', (
      tester,
    ) async {
      final visibility = <bool>[];
      var attempts = 0;
      await tester.pumpWidget(
        _slotApp(
          onBoundsChanged: (_) async {
            attempts++;
            if (attempts == 1) {
              throw StateError('expected first bounds failure');
            }
          },
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(visibility, <bool>[true]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stops retrying permanently failed bounds at its limit', (
      tester,
    ) async {
      var attempts = 0;
      final visibility = <bool>[];
      await tester.pumpWidget(
        _slotApp(
          boundsRetryLimit: 3,
          onBoundsChanged: (_) async {
            attempts++;
            throw StateError('expected permanent bounds failure');
          },
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(attempts, 3);
      expect(visibility, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'serializes bounds reports and applies only the latest update',
      (tester) async {
        final firstCompletes = Completer<void>();
        final started = <double>[];
        final applied = <double>[];
        var active = 0;
        var maxActive = 0;
        Future<void> onBounds(NativeGameWebViewBounds bounds) async {
          active++;
          maxActive = active > maxActive ? active : maxActive;
          started.add(bounds.width);
          if (bounds.width == 100) {
            await firstCompletes.future;
          }
          applied.add(bounds.width);
          active--;
        }

        await tester.pumpWidget(_slotApp(onBoundsChanged: onBounds));
        await tester.pump();
        await tester.pumpWidget(
          _slotApp(width: 120, onBoundsChanged: onBounds),
        );
        await tester.pump();
        await tester.pumpWidget(
          _slotApp(width: 140, onBoundsChanged: onBounds),
        );
        await tester.pump();
        expect(started, <double>[100]);

        firstCompletes.complete();
        await tester.pump();
        await tester.pump();

        expect(started, <double>[100, 140]);
        expect(applied, <double>[100, 140]);
        expect(maxActive, 1);
      },
    );

    testWidgets('resends current bounds after its callback sink is replaced', (
      tester,
    ) async {
      final firstSink = <NativeGameWebViewBounds>[];
      final secondSink = <NativeGameWebViewBounds>[];
      await tester.pumpWidget(
        _slotApp(
          boundsSinkIdentity: firstSink,
          onBoundsChanged: (bounds) async => firstSink.add(bounds),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        _slotApp(
          boundsSinkIdentity: secondSink,
          onBoundsChanged: (bounds) async => secondSink.add(bounds),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(firstSink, hasLength(1));
      expect(secondSink, hasLength(1));
      expect(secondSink.single.width, 100);
    });

    testWidgets(
      'uses the new callback for route work queued during replacement',
      (tester) async {
        final firstObserver = RouteObserver<ModalRoute<dynamic>>();
        final secondObserver = RouteObserver<ModalRoute<dynamic>>();
        final navigatorKey = GlobalKey<NavigatorState>();
        final firstReports = <bool>[];
        final secondReports = <bool>[];
        final firstCompletes = Completer<void>();
        await tester.pumpWidget(
          _slotApp(
            navigatorKey: navigatorKey,
            observer: firstObserver,
            onVisibilityChanged: (value) {
              firstReports.add(value);
              return firstCompletes.future;
            },
          ),
        );
        await tester.pump();
        unawaited(
          navigatorKey.currentState!.push<void>(
            MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _slotApp(
            navigatorKey: navigatorKey,
            observer: secondObserver,
            onVisibilityChanged: (value) async => secondReports.add(value),
          ),
        );
        await tester.pump();
        firstCompletes.complete();
        await tester.pump();

        expect(firstReports, <bool>[true]);
        expect(secondReports, <bool>[false]);
      },
    );

    testWidgets('uses a replacement visibility callback after widget update', (
      tester,
    ) async {
      final firstReports = <bool>[];
      final secondReports = <bool>[];
      await tester.pumpWidget(
        _slotApp(onVisibilityChanged: (value) async => firstReports.add(value)),
      );
      await tester.pump();
      await tester.pumpWidget(
        _slotApp(
          onVisibilityChanged: (value) async => secondReports.add(value),
        ),
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(firstReports, <bool>[true]);
      expect(secondReports, <bool>[false, true]);
    });

    testWidgets('contains bounds and visibility callback errors and recovers', (
      tester,
    ) async {
      final visibility = <bool>[];
      var boundsCalls = 0;
      var visibilityCalls = 0;
      Future<void> onBounds(NativeGameWebViewBounds _) async {
        boundsCalls++;
        if (boundsCalls == 2) {
          throw StateError('expected bounds failure');
        }
      }

      await tester.pumpWidget(
        _slotApp(
          onBoundsChanged: onBounds,
          onVisibilityChanged: (value) async {
            visibilityCalls++;
            visibility.add(value);
            if (visibilityCalls == 1) {
              throw StateError('expected visibility failure');
            }
          },
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        _slotApp(
          width: 120,
          onBoundsChanged: onBounds,
          onVisibilityChanged: (value) async {
            visibilityCalls++;
            visibility.add(value);
          },
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        _slotApp(
          width: 120,
          onBoundsChanged: onBounds,
          onVisibilityChanged: (value) async {
            visibilityCalls++;
            visibility.add(value);
          },
        ),
      );
      await tester.pump();

      expect(boundsCalls, greaterThanOrEqualTo(3));
      expect(visibility, <bool>[true, false, true]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'waits for bounds success before showing and retries failures',
      (tester) async {
        final visibility = <bool>[];
        final firstBounds = Completer<void>();
        var attempts = 0;
        await tester.pumpWidget(
          _slotApp(
            onBoundsChanged: (_) async {
              attempts++;
              if (attempts == 1) {
                await firstBounds.future;
                throw StateError('expected bounds failure');
              }
            },
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();
        expect(visibility, isEmpty);

        firstBounds.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);

        expect(attempts, 2);
        expect(visibility, <bool>[true]);
      },
    );

    testWidgets(
      'ignores stale bounds completion after layout changes or disposal',
      (tester) async {
        final visibility = <bool>[];
        final staleBounds = Completer<void>();
        var reports = 0;
        Future<void> onBounds(NativeGameWebViewBounds _) async {
          reports++;
          if (reports == 1) {
            await staleBounds.future;
          }
        }

        await tester.pumpWidget(
          _slotApp(
            onBoundsChanged: onBounds,
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          _slotApp(
            width: 120,
            onBoundsChanged: onBounds,
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();
        expect(visibility, isEmpty);

        staleBounds.complete();
        await tester.pump();
        await tester.pump();
        expect(visibility, <bool>[true]);

        final disposeBounds = Completer<void>();
        await tester.pumpWidget(
          _slotApp(
            width: 140,
            onBoundsChanged: (_) => disposeBounds.future,
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        disposeBounds.complete();
        await tester.pump();

        expect(visibility, <bool>[true, false]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('hides when the game workspace becomes inactive', (
      tester,
    ) async {
      final visibility = <bool>[];
      Future<void> onVisibility(bool value) async => visibility.add(value);

      await tester.pumpWidget(
        _slotApp(onVisibilityChanged: onVisibility, workspaceActive: true),
      );
      await tester.pump();
      expect(visibility, <bool>[true]);

      await tester.pumpWidget(
        _slotApp(onVisibilityChanged: onVisibility, workspaceActive: false),
      );
      await tester.pump();
      expect(visibility, <bool>[true, false]);

      await tester.pumpWidget(
        _slotApp(onVisibilityChanged: onVisibility, workspaceActive: true),
      );
      await tester.pump();
      expect(visibility, <bool>[true, false, true]);
    });

    test(
      'measurement helper rejects unattached non-box and non-finite values',
      () {
        expect(
          readNativeGameSurfaceBounds(
            _UnattachedRenderBox(),
            devicePixelRatio: 1,
          ),
          isNull,
        );
        expect(
          readNativeGameSurfaceBounds(
            _NonBoxRenderObject(),
            devicePixelRatio: 1,
          ),
          isNull,
        );
        expect(
          nativeGameSurfaceBoundsFromMetrics(
            size: const Size(double.infinity, 1),
            offset: Offset.zero,
            devicePixelRatio: 1,
          ),
          isNull,
        );
        expect(
          nativeGameSurfaceBoundsFromMetrics(
            size: const Size(1, 1),
            offset: const Offset(double.nan, 0),
            devicePixelRatio: 1,
          ),
          isNull,
        );
      },
    );

    testWidgets(
      'does not construct invalid bounds and hides an attached zero-area slot',
      (tester) async {
        final bounds = <NativeGameWebViewBounds>[];
        final visibility = <bool>[];

        await tester.pumpWidget(
          _slotApp(
            width: 20,
            height: 10,
            onBoundsChanged: (value) async => bounds.add(value),
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          _slotApp(
            width: 0,
            height: 0,
            onBoundsChanged: (value) async => bounds.add(value),
            onVisibilityChanged: (value) async => visibility.add(value),
          ),
        );
        await tester.pump();

        expect(bounds, hasLength(1));
        expect(visibility, <bool>[true, false]);
      },
    );

    testWidgets('hides when a Navigator route covers it and restores on pop', (
      tester,
    ) async {
      final observer = YahagiGameRouteObserver();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visibility = <bool>[];

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: observer,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(visibility, <bool>[true, false, true]);
    });

    testWidgets('stays visible when a non-modal popup like a menu opens', (
      tester,
    ) async {
      final observer = YahagiGameRouteObserver();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visibility = <bool>[];

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: observer,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      expect(visibility, <bool>[true]);

      // Push a non-modal popup (like PopupMenuButton with no barrier)
      unawaited(
        navigatorKey.currentState!.push<void>(_TestNonModalPopupRoute()),
      );
      await tester.pumpAndSettle();
      // Must stay visible throughout non-modal popup menu
      expect(visibility, <bool>[true]);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(visibility, <bool>[true]);
    });

    testWidgets('hides when a modal dialog opens and restores on pop', (
      tester,
    ) async {
      final observer = YahagiGameRouteObserver();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visibility = <bool>[];

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: observer,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      expect(visibility, <bool>[true]);

      // Push a modal dialog (like showDialog with barrier)
      unawaited(
        navigatorKey.currentState!.push<void>(
          RawDialogRoute<void>(
            pageBuilder: (_, _, _) => const Text('dialog'),
            barrierDismissible: true,
            barrierLabel: 'barrier',
            barrierColor: Colors.black54,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Must hide during modal dialog
      expect(visibility, <bool>[true, false]);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(visibility, <bool>[true, false, true]);
    });

    testWidgets(
      'waits for a popup snapshot before hiding and restores before cleanup',
      (tester) async {
        final observer = YahagiGameRouteObserver();
        final navigatorKey = GlobalKey<NavigatorState>();
        final visibility = <bool>[];
        final sequence = <String>[];
        final prepared = Completer<void>();

        await tester.pumpWidget(
          _slotApp(
            navigatorKey: navigatorKey,
            observer: observer,
            onVisibilityChanged: (value) async {
              visibility.add(value);
              sequence.add('visible:$value');
            },
            onBeforePopupRouteHidden: () async {
              sequence.add('prepare');
              await prepared.future;
            },
            onPopupRouteRevealStarted: () => sequence.add('cancel'),
            onAfterPopupRouteRevealed: () => sequence.add('cleanup'),
          ),
        );
        await tester.pump();

        unawaited(
          navigatorKey.currentState!.push<void>(
            RawDialogRoute<void>(
              pageBuilder: (_, _, _) => const Text('dialog'),
              barrierDismissible: true,
              barrierLabel: 'barrier',
              barrierColor: Colors.black54,
            ),
          ),
        );
        await tester.pump();

        expect(visibility, <bool>[true]);
        expect(sequence, <String>['visible:true', 'prepare']);

        prepared.complete();
        await tester.pumpAndSettle();
        expect(visibility, <bool>[true, false]);

        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();

        expect(visibility, <bool>[true, false, true]);
        expect(sequence, <String>[
          'visible:true',
          'prepare',
          'visible:false',
          'cancel',
          'visible:true',
          'cleanup',
        ]);
      },
    );

    testWidgets('cancels a stale popup hide when the dialog closes quickly', (
      tester,
    ) async {
      final observer = YahagiGameRouteObserver();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visibility = <bool>[];
      final prepared = Completer<void>();
      var cancellations = 0;

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: observer,
          onVisibilityChanged: (value) async => visibility.add(value),
          onBeforePopupRouteHidden: () => prepared.future,
          onPopupRouteRevealStarted: () => cancellations += 1,
        ),
      );
      await tester.pump();

      unawaited(
        navigatorKey.currentState!.push<void>(
          RawDialogRoute<void>(
            pageBuilder: (_, _, _) => const Text('dialog'),
            barrierDismissible: true,
            barrierLabel: 'barrier',
            barrierColor: Colors.black54,
          ),
        ),
      );
      await tester.pump();
      navigatorKey.currentState!.pop();
      await tester.pump();
      prepared.complete();
      await tester.pumpAndSettle();

      expect(cancellations, 1);
      expect(visibility, <bool>[true]);
    });

    for (final nested in [false, true]) {
      testWidgets(
        'immediate safety route hides without waiting for preview nested=$nested',
        (tester) async {
          final observer = YahagiGameRouteObserver();
          final navigatorKey = GlobalKey<NavigatorState>();
          final visibility = <bool>[];
          final prepared = Completer<void>();
          var preparations = 0;
          addTearDown(() async {
            if (!prepared.isCompleted) prepared.complete();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
          await tester.pumpWidget(
            _slotApp(
              navigatorKey: navigatorKey,
              observer: observer,
              onVisibilityChanged: (value) async => visibility.add(value),
              onBeforePopupRouteHidden: () {
                preparations++;
                return prepared.future;
              },
            ),
          );
          await tester.pump();
          if (nested) {
            unawaited(
              navigatorKey.currentState!.push<void>(
                RawDialogRoute<void>(
                  pageBuilder: (_, _, _) => const Text('ordinary popup'),
                  barrierLabel: 'ordinary',
                  barrierColor: Colors.black54,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(visibility, [true]);
          }
          unawaited(
            navigatorKey.currentState!.push<void>(_ImmediateSafetyRoute()),
          );
          await tester.pumpAndSettle();

          expect(visibility, [true, false]);
          expect(preparations, nested ? 1 : 0);
          prepared.complete();
          await tester.pumpAndSettle();
          expect(visibility, [true, false]);

          navigatorKey.currentState!.pop();
          await tester.pumpAndSettle();
          if (nested) {
            expect(visibility, [true, false]);
            navigatorKey.currentState!.pop();
            await tester.pumpAndSettle();
          }
          expect(visibility, [true, false, true]);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('immediate safety listener follows observer replacement once', (
      tester,
    ) async {
      final first = YahagiGameRouteObserver();
      final second = YahagiGameRouteObserver();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visibility = <bool>[];
      var immediateCovers = 0;
      var preparations = 0;
      Widget app(YahagiGameRouteObserver observer) => _slotApp(
        navigatorKey: navigatorKey,
        observer: observer,
        onVisibilityChanged: (visible) async => visibility.add(visible),
        onImmediatePopupRouteHidden: () => immediateCovers++,
        onBeforePopupRouteHidden: () async => preparations++,
      );
      await tester.pumpWidget(app(first));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(second));
      await tester.pumpAndSettle();

      first.didPush(_ImmediateSafetyRoute(), null);
      await tester.pumpAndSettle();
      expect(immediateCovers, 0);
      expect(visibility, [true]);
      unawaited(navigatorKey.currentState!.push<void>(_ImmediateSafetyRoute()));
      await tester.pumpAndSettle();
      expect(
        immediateCovers,
        1,
        reason: 'dedicated notification and didPushNext must not duplicate',
      );
      expect(preparations, 0);
      expect(visibility, [true, false]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      second.didPush(_ImmediateSafetyRoute(), null);
      await tester.pumpAndSettle();
      expect(immediateCovers, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('calibrates route visibility when its observer changes', (
      tester,
    ) async {
      final firstObserver = RouteObserver<ModalRoute<dynamic>>();
      final secondObserver = RouteObserver<ModalRoute<dynamic>>();
      final navigatorKey = GlobalKey<NavigatorState>();
      final visibility = <bool>[];

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: firstObserver,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();
      expect(visibility, <bool>[true, false]);

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: secondObserver,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      expect(visibility, <bool>[true, false]);

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      expect(visibility, <bool>[true, false, true]);

      await tester.pumpWidget(
        _slotApp(
          navigatorKey: navigatorKey,
          observer: secondObserver,
          onVisibilityChanged: (value) async => visibility.add(value),
        ),
      );
      await tester.pump();
      expect(visibility, <bool>[true, false, true, false]);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(visibility, <bool>[true, false, true, false, true]);
    });

    testWidgets(
      'maps background app lifecycle states to hidden and keeps inactive visible',
      (tester) async {
        addTearDown(() {
          tester.binding.resetInternalState();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        });
        final visibility = <bool>[];
        await tester.pumpWidget(
          _slotApp(onVisibilityChanged: (value) async => visibility.add(value)),
        );
        await tester.pump();
        expect(visibility, <bool>[true]);

        // Inactive (e.g. system menu shade pulled down) keeps surface visible.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(visibility, <bool>[true]);

        for (final state in <AppLifecycleState>[
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.detached,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
          await tester.pump();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
        }

        expect(visibility, <bool>[true, false, true, false, true, false, true]);
      },
    );

    testWidgets('hides once when disposed and contains no platform view', (
      tester,
    ) async {
      final visibility = <bool>[];
      await tester.pumpWidget(
        _slotApp(onVisibilityChanged: (value) async => visibility.add(value)),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString().contains('WebViewWidget') ||
              widget.runtimeType.toString().contains('AndroidView') ||
              widget.runtimeType.toString().contains('PlatformViewLink'),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();

      expect(visibility, <bool>[true, false]);
    });
  });
}

final class _NonBoxRenderObject extends RenderObject {
  @override
  Rect get paintBounds => Rect.zero;

  @override
  Rect get semanticBounds => Rect.zero;

  @override
  void debugAssertDoesMeetConstraints() {}

  @override
  void performLayout() {}

  @override
  void performResize() {}

  @override
  void paint(PaintingContext context, Offset offset) {}
}

final class _UnattachedRenderBox extends RenderBox {
  @override
  void performLayout() {}
}

Widget _slotApp({
  double width = 100,
  double height = 50,
  double left = 0,
  double top = 0,
  Future<void> Function(NativeGameWebViewBounds)? onBoundsChanged,
  Future<void> Function(bool)? onVisibilityChanged,
  GlobalKey<NavigatorState>? navigatorKey,
  RouteObserver<ModalRoute<dynamic>>? observer,
  bool useCurrentLifecycle = false,
  int boundsRetryLimit = 3,
  Object? boundsSinkIdentity,
  bool workspaceActive = true,
  Future<void> Function()? onBeforePopupRouteHidden,
  VoidCallback? onImmediatePopupRouteHidden,
  VoidCallback? onPopupRouteRevealStarted,
  VoidCallback? onAfterPopupRouteRevealed,
}) {
  if (!useCurrentLifecycle &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  }
  return MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers: observer == null ? const [] : [observer],
    home: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(left: left, top: top),
        child: SizedBox(
          width: width,
          height: height,
          child: GameWorkspaceActive(
            active: workspaceActive,
            child: NativeGameSurfaceSlot(
              onBoundsChanged: onBoundsChanged ?? _ignoreBounds,
              onVisibilityChanged: onVisibilityChanged ?? _ignoreVisibility,
              routeObserver: observer,
              boundsRetryLimit: boundsRetryLimit,
              boundsSinkIdentity:
                  boundsSinkIdentity ?? _defaultBoundsSinkIdentity,
              onBeforePopupRouteHidden: onBeforePopupRouteHidden,
              onImmediatePopupRouteHidden: onImmediatePopupRouteHidden,
              onPopupRouteRevealStarted: onPopupRouteRevealStarted,
              onAfterPopupRouteRevealed: onAfterPopupRouteRevealed,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _ignoreVisibility(bool _) async {}

Future<void> _ignoreBounds(NativeGameWebViewBounds _) async {}

final Object _defaultBoundsSinkIdentity = Object();

final class _TestNonModalPopupRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 10);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const Text('menu');
}

final class _ImmediateSafetyRoute extends RawDialogRoute<void>
    implements ImmediateGameSurfaceCoverRoute {
  _ImmediateSafetyRoute()
    : super(
        pageBuilder: (_, _, _) => const Text('immediate safety popup'),
        barrierLabel: 'safety',
        barrierColor: Colors.black54,
      );
}
