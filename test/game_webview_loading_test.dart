import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_reload_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_startup_activity.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_startup_overlay.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_startup_check_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  late _WebViewPlatform platform;
  late List<MethodCall> frameReloadCalls;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
    frameReloadCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(gameFrameReloadMethodChannelName),
          (call) async {
            frameReloadCalls.add(call);
            return null;
          },
        );
  });

  Future<_Fixture> pumpNativePreparation(
    WidgetTester tester,
    _PreparingFrameRatePort? port, {
    Duration timeout = const Duration(seconds: 10),
    bool withSettings = true,
    GameFrameRateSettingsController? settings,
  }) async {
    final fixture = await _Fixture.create();
    final frameRate =
        settings ??
        await GameFrameRateSettingsController.load(
          MemoryGameFrameRateSettingsStore(GameFrameRateMode.stable30),
        );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      fixture.dispose();
      frameRate.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: GameWebView(
          networkSettingsController: fixture.network,
          safetySettingsController: fixture.safety,
          controller: fixture.status,
          browserController: fixture.browser,
          captureModeController: fixture.captureMode,
          audioController: fixture.audio,
          toolbarController: fixture.toolbar,
          gameCaptureController: fixture.capture,
          frameRateSettingsController: withSettings ? frameRate : null,
          frameRatePortFactory: port == null ? null : () => port,
          startupTimeout: timeout,
          startupOrchestratorFactory: () => _Startup(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    return fixture;
  }

  testWidgets(
    'same URL navigation waits for every immediate fit cancellation and keeps binding',
    (tester) async {
      platform.useAndroidController = true;
      const channel = MethodChannel('app.webview/fixed_canvas_scaling');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      final pending = <Completer<void>>[];
      var block = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'cancelPendingFit' && block) {
          final reply = Completer<void>();
          pending.add(reply);
          await reply.future;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final fixture = await _Fixture.create();
      addTearDown(() async {
        for (final reply in pending) {
          if (!reply.isCompleted) reply.complete();
        }
        await tester.pumpWidget(const SizedBox());
        fixture.dispose();
      });
      await tester.pumpWidget(MaterialApp(home: fixture.view));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      const url = 'https://game.example/same';
      platform.controller.presentation = 'game';
      platform.delegate.started(url);
      platform.delegate.finished(url);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(calls, contains('bindFixedCanvas'));
      calls.clear();
      final scriptsBeforeCancellation = platform.controller.scripts.length;
      block = true;
      platform.delegate.started(url);
      final oldFit = fixture.browser.fitGameScreen();
      await tester.pump();
      platform.delegate.started(url);
      final newFit = fixture.browser.fitGameScreen();
      await tester.pump();
      expect(calls, ['cancelPendingFit', 'cancelPendingFit']);
      expect(pending, hasLength(2));
      expect(platform.controller.scripts, hasLength(scriptsBeforeCancellation));
      pending.last.complete();
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(calls, ['cancelPendingFit', 'cancelPendingFit']);
      expect(platform.controller.scripts, hasLength(scriptsBeforeCancellation));
      pending.first.complete();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await Future.wait([oldFit, newFit]);
      expect(calls, [
        'cancelPendingFit',
        'cancelPendingFit',
        'bindFixedCanvas',
      ]);
      expect(calls, isNot(contains('releaseFixedCanvas')));
    },
  );

  testWidgets(
    'native installation acknowledgement gates frame bridge and navigation',
    (tester) async {
      final reply = Completer<void>();
      final port = _PreparingFrameRatePort()..pending = reply;
      await pumpNativePreparation(tester, port);
      await tester.pump(const Duration(milliseconds: 200));
      expect(platform.controller.loads, isEmpty);
      expect(frameReloadCalls, isEmpty);
      expect(port.modes, [GameFrameRateMode.stable30]);
      reply.complete();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(frameReloadCalls.map((call) => call.method), ['configure']);
      expect(platform.controller.loads, hasLength(1));
      expect(port.supportChecks, 0);
      tester.element(find.byType(GameWebView)).markNeedsBuild();
      await tester.pump();
      expect(port.modes, hasLength(1));
      expect(platform.controller.loads, hasLength(1));
    },
  );

  testWidgets(
    'disposing a pending native preparation never configures frame bridge',
    (tester) async {
      final reply = Completer<void>();
      final port = _PreparingFrameRatePort()..pending = reply;
      await pumpNativePreparation(tester, port);
      await tester.pumpWidget(const SizedBox());
      reply.complete();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(frameReloadCalls, isEmpty);
      expect(platform.controller.loads, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native surface readiness is required without a settings controller',
    (tester) async {
      final reply = Completer<void>();
      final port = _PreparingFrameRatePort()..pending = reply;
      await pumpNativePreparation(tester, port, withSettings: false);
      expect(port.modes, [GameFrameRateMode.automatic]);
      expect(frameReloadCalls, isEmpty);
      expect(platform.controller.loads, isEmpty);
      reply.complete();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(frameReloadCalls.map((call) => call.method), ['configure']);
      expect(platform.controller.loads, hasLength(1));
    },
  );

  testWidgets('page error cancels pending readiness before a late success', (
    tester,
  ) async {
    final reply = Completer<void>();
    final port = _PreparingFrameRatePort()..pending = reply;
    await pumpNativePreparation(tester, port);
    platform.delegate.error(
      const WebResourceError(
        errorCode: -2,
        description: 'page interrupted',
        isForMainFrame: true,
      ),
    );
    reply.complete();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(frameReloadCalls, isEmpty);
    expect(platform.controller.loads, isEmpty);
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
  });

  testWidgets(
    'header reload after a page error preserves the installed frame-rate port',
    (tester) async {
      platform.useAndroidController = true;
      final settings = await GameFrameRateSettingsController.load(
        MemoryGameFrameRateSettingsStore(GameFrameRateMode.stable30),
      );
      const frameRateChannel = MethodChannel(
        'app.yahagi.kancollebrowser/game_frame_rate',
      );
      final frameRateCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const scaleChannel = MethodChannel('app.webview/fixed_canvas_scaling');
      messenger.setMockMethodCallHandler(scaleChannel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(scaleChannel, null));
      messenger.setMockMethodCallHandler(frameRateChannel, (call) async {
        frameRateCalls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(frameRateChannel, null),
      );
      final fixture = await pumpNativePreparation(
        tester,
        null,
        settings: settings,
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(platform.controller.loads, hasLength(1));
      const url = 'https://game.example/';
      platform.delegate.started(url);
      platform.delegate.finished(url);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(settings.supported, isTrue);
      expect(find.byType(GameStartupOverlay), findsNothing);

      platform.delegate.httpError?.call(
        HttpResponseError(
          request: WebResourceRequest(uri: Uri.parse(url)),
          response: const WebResourceResponse(uri: null, statusCode: 503),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
      await fixture.browser.reload();
      platform.delegate.started(url);
      platform.delegate.finished(url);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(platform.controller.reloads, 1);
      expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);

      await settings.setMode(GameFrameRateMode.highRefresh);

      expect(settings.supported, isTrue);
      expect(
        frameRateCalls
            .where((call) => call.method == 'configure')
            .map((call) => (call.arguments as Map<Object?, Object?>)['mode']),
        ['stable30', 'highRefresh'],
      );
    },
  );

  testWidgets(
    'timed out frame bridge configuration cannot navigate when it completes',
    (tester) async {
      final reply = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(gameFrameReloadMethodChannelName),
        (call) async {
          frameReloadCalls.add(call);
          await reply.future;
          return null;
        },
      );
      await pumpNativePreparation(
        tester,
        _PreparingFrameRatePort(),
        timeout: const Duration(milliseconds: 50),
      );
      expect(frameReloadCalls.map((call) => call.method), ['configure']);
      expect(platform.controller.loads, isEmpty);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);

      reply.complete();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      expect(platform.controller.loads, isEmpty);
      expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
    },
  );

  testWidgets('native preparation timeout rejects a late success', (
    tester,
  ) async {
    final reply = Completer<void>();
    final port = _PreparingFrameRatePort()..pending = reply;
    await pumpNativePreparation(
      tester,
      port,
      timeout: const Duration(milliseconds: 50),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
    reply.complete();
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(frameReloadCalls, isEmpty);
    expect(platform.controller.loads, isEmpty);
  });

  testWidgets(
    'retry succeeds while the timed out native response stays pending',
    (tester) async {
      final oldReply = Completer<void>();
      addTearDown(() {
        if (!oldReply.isCompleted) oldReply.complete();
      });
      final port = _PreparingFrameRatePort()..pending = oldReply;
      await pumpNativePreparation(
        tester,
        port,
        timeout: const Duration(milliseconds: 50),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
      port.pending = null;
      await tester.tap(find.byKey(const Key('game-webview-page-reload')));
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(platform.controller.loads, hasLength(1));
      expect(frameReloadCalls.map((call) => call.method), ['configure']);
      oldReply.complete();
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(platform.controller.loads, hasLength(1));
    },
  );

  testWidgets(
    'failed native preparation can be retried before first navigation',
    (tester) async {
      final port = _PreparingFrameRatePort()
        ..failure = PlatformException(code: 'multiple_webviews');
      await pumpNativePreparation(tester, port);
      expect(frameReloadCalls, isEmpty);
      expect(platform.controller.loads, isEmpty);
      expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
      port.failure = null;
      await tester.tap(find.byKey(const Key('game-webview-page-reload')));
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(port.modes, [
        GameFrameRateMode.stable30,
        GameFrameRateMode.stable30,
      ]);
      expect(frameReloadCalls.map((call) => call.method), ['configure']);
      expect(platform.controller.loads, hasLength(1));
    },
  );

  testWidgets('unsupported native messaging keeps the browsing fallback', (
    tester,
  ) async {
    final port = _PreparingFrameRatePort()
      ..failure = PlatformException(code: 'frame_rate_unsupported');
    await pumpNativePreparation(tester, port);
    expect(platform.controller.loads, hasLength(1));
    expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
  });

  for (final operation in ['home', 'reload', 'frame', 'back']) {
    testWidgets('toolbar $operation waits for native surface readiness', (
      tester,
    ) async {
      final reply = Completer<void>();
      addTearDown(() {
        if (!reply.isCompleted) reply.complete();
      });
      final port = _PreparingFrameRatePort()..pending = reply;
      final fixture = await pumpNativePreparation(tester, port);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(gameFrameReloadMethodChannelName),
            (call) async {
              frameReloadCalls.add(call);
              return call.method == 'reload' ? 'reloaded' : null;
            },
          );
      final Future<void> request = switch (operation) {
        'home' => fixture.browser.goHome(),
        'reload' => fixture.browser.reload(),
        'frame' => fixture.browser.reloadGameFrame().then((_) {}),
        _ => fixture.browser.goBack(),
      };
      unawaited(request.catchError((Object _, StackTrace _) {}));
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }
      expect(frameReloadCalls, isEmpty);
      expect(platform.controller.loads, isEmpty);
      expect(platform.controller.reloads, 0);
      expect(platform.controller.backs, 0);
      reply.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      await request;
      expect(frameReloadCalls, isNotEmpty);
      if (operation == 'home') expect(platform.controller.loads, isNotEmpty);
      if (operation == 'reload') expect(platform.controller.reloads, 1);
      if (operation == 'frame') {
        expect(
          frameReloadCalls.where((call) => call.method == 'reload'),
          hasLength(1),
        );
      }
      if (operation == 'back') expect(platform.controller.backs, 1);
    });
  }

  Future<_Fixture> pump(
    WidgetTester tester, {
    GameStartupActivityPort? activityPort,
    GameStartupCheckSettingsController? startupCheck,
  }) async {
    final fixture = await _Fixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      fixture.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: fixture.buildView(
          activityPort: activityPort,
          startupCheck: startupCheck,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(platform.controller.loads, hasLength(1));
    return fixture;
  }

  testWidgets('startup feedback waits for 500ms before appearing', (
    tester,
  ) async {
    await pump(tester);
    platform.delegate.started('https://game.example/');
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.byType(GameStartupOverlay), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(GameStartupOverlay), findsOneWidget);
  });

  testWidgets('startup check OFF keeps legacy loading and main-frame retry', (
    tester,
  ) async {
    final startupCheck = await _loadStartupCheck(false);
    addTearDown(startupCheck.dispose);
    final activity = _StartupActivityPort();
    var webViewTaps = 0;
    platform.onTap = () => webViewTaps++;
    await pump(tester, activityPort: activity, startupCheck: startupCheck);
    const url = 'https://play.games.dmm.com/game/kancolle';
    platform.delegate.started(url);
    platform.delegate.progress!(77);
    await tester.pump(const Duration(seconds: 21));
    final spinner = find.byType(CircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(find.byType(GameStartupOverlay), findsNothing);
    expect(activity.reads, 0);
    await tester.tapAt(tester.getCenter(spinner));
    expect(webViewTaps, 0);

    platform.delegate.httpError?.call(
      HttpResponseError(
        request: WebResourceRequest(
          uri: Uri.parse(
            'https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js',
          ),
        ),
        response: const WebResourceResponse(uri: null, statusCode: 503),
      ),
    );
    await tester.pump();
    expect(spinner, findsOneWidget);

    platform.delegate.httpError?.call(
      HttpResponseError(
        request: WebResourceRequest(uri: Uri.parse(url)),
        response: const WebResourceResponse(uri: null, statusCode: 503),
      ),
    );
    await tester.pump();
    final retry = find.byKey(const Key('game-webview-page-reload'));
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    expect(find.byType(GameStartupOverlay), findsNothing);
    expect(find.byType(ElevatedButton), findsNWidgets(2));
    await tester.tap(retry);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(platform.controller.reloads, 1);
    expect(spinner, findsOneWidget);
  });

  testWidgets(
    'toggling startup check off stops polling until the next reload',
    (tester) async {
      final startupCheck = await _loadStartupCheck(true);
      addTearDown(startupCheck.dispose);
      final activity = _StartupActivityPort();
      final fixture = await pump(
        tester,
        activityPort: activity,
        startupCheck: startupCheck,
      );
      const url = 'https://play.games.dmm.com/game/kancolle';
      platform.delegate.started(url);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameStartupOverlay), findsOneWidget);

      await startupCheck.setEnabled(false);
      final reads = activity.reads;
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GameStartupOverlay), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(activity.reads, reads);
      expect(platform.controller.reloads, 0);

      await startupCheck.setEnabled(true);
      platform.delegate.started(url);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(GameStartupOverlay), findsNothing);
      expect(activity.reads, reads);

      await fixture.browser.reload();
      platform.delegate.started(url);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameStartupOverlay), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(activity.reads, greaterThan(reads));
    },
  );

  testWidgets('startup check OFF restores the deadline after an early API', (
    tester,
  ) async {
    final startupCheck = await _loadStartupCheck(true);
    addTearDown(startupCheck.dispose);
    final activity = _StartupActivityPort()
      ..next = const GameStartupActivitySnapshot(
        navigationId: 1,
        requestCount: 11,
        gameResources: true,
        gameApi: true,
      );
    await pump(tester, activityPort: activity, startupCheck: startupCheck);
    platform.delegate.started('https://play.games.dmm.com/game/kancolle');
    await tester.pump(const Duration(seconds: 46));
    expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
    expect(find.byType(GameStartupOverlay), findsNothing);

    await startupCheck.setEnabled(false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(platform.controller.reloads, 0);
    await tester.pump(const Duration(seconds: 46));
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
    expect(find.byType(GameStartupOverlay), findsNothing);
  });

  testWidgets(
    'passive startup stays centered through resources and closes on first API',
    (tester) async {
      final activity = _StartupActivityPort()
        ..next = const GameStartupActivitySnapshot(
          navigationId: 1,
          requestCount: 2,
          gameResources: false,
          gameApi: false,
        );
      var webViewTaps = 0;
      platform.onTap = () => webViewTaps++;
      await pump(tester, activityPort: activity);
      const url = 'https://play.games.dmm.com/game/kancolle';
      platform.delegate.started(url);
      await tester.pump(const Duration(milliseconds: 500));
      final overlay = find.byType(GameStartupOverlay);
      expect(tester.widget<GameStartupOverlay>(overlay).compact, isFalse);
      final card = find.descendant(
        of: overlay,
        matching: find.byType(SingleChildScrollView),
      );
      final center = tester.getCenter(card);
      await tester.tapAt(center);
      expect(webViewTaps, 1);

      activity.next = const GameStartupActivitySnapshot(
        navigationId: 1,
        requestCount: 12,
        gameResources: true,
        gameApi: false,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<GameStartupOverlay>(overlay).compact, isTrue);
      expect(find.text('12 个请求'), findsOneWidget);
      expect(find.text('正在加载游戏资源'), findsOneWidget);
      expect(tester.getCenter(card), center);
      await tester.tapAt(center);
      expect(webViewTaps, 2);

      // Visibility feedback can finish while capture and geometry readiness
      // are still pending.
      platform.controller.presentation = 'pending';
      platform.delegate.finished(url);
      activity.next = const GameStartupActivitySnapshot(
        navigationId: 1,
        requestCount: 13,
        gameResources: true,
        gameApi: true,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlay, findsNothing);
      await tester.pump(const Duration(seconds: 46));
      expect(overlay, findsNothing);
    },
  );

  testWidgets('quick refresh accepts only activity from the refreshed frame', (
    tester,
  ) async {
    final activity = _StartupActivityPort()
      ..next = const GameStartupActivitySnapshot(
        navigationId: 1,
        requestCount: 20,
        gameResources: true,
        gameApi: true,
      );
    final fixture = await pump(tester, activityPort: activity);
    const url = 'https://play.games.dmm.com/game/kancolle';
    platform.controller.presentation = 'game';
    platform.delegate.started(url);
    platform.delegate.finished(url);
    await tester.pump();
    expect(find.byType(GameStartupOverlay), findsNothing);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(gameFrameReloadMethodChannelName),
          (call) async => call.method == 'reload' ? 'reloaded' : null,
        );
    final reload = fixture.browser.reloadGameFrame();
    await tester.pump();
    expect(await reload, GameFrameReloadResult.reloaded);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameStartupOverlay), findsOneWidget);
    expect(find.text('20 个请求'), findsNothing);

    activity.next = const GameStartupActivitySnapshot(
      navigationId: 2,
      requestCount: 4,
      gameResources: true,
      gameApi: false,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('4 个请求'), findsOneWidget);
    activity.next = const GameStartupActivitySnapshot(
      navigationId: 2,
      requestCount: 5,
      gameResources: true,
      gameApi: true,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameStartupOverlay), findsNothing);
  });

  testWidgets('page progress advances and clears the no-progress warning', (
    tester,
  ) async {
    await pump(tester);
    platform.delegate.started('https://game.example/');
    expect(platform.delegate.progress, isNotNull);
    platform.delegate.progress!(31);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .31,
    );

    await tester.pump(const Duration(seconds: 19));
    platform.delegate.progress!(31);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
    platform.delegate.progress!(49);
    await tester.pump();
    expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .49,
    );
  });

  testWidgets('critical Gadget HTTP error reports only the host and code', (
    tester,
  ) async {
    await pump(tester);
    platform.delegate.started('https://play.games.dmm.com/game/kancolle');
    platform.delegate.httpError?.call(
      HttpResponseError(
        request: WebResourceRequest(
          uri: Uri.parse(
            'https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js?token=test-secret',
          ),
        ),
        response: const WebResourceResponse(uri: null, statusCode: 503),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
    expect(
      find.text('w00g.kancolle-server.com', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('游戏启动脚本暂时无法加载'), findsOneWidget);
    expect(find.text('HTTP 503', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('test-secret', findRichText: true),
      findsNothing,
    );
  });

  testWidgets(
    'a login redirect hides the loading card and ignores a Gadget error',
    (tester) async {
      await pump(tester);
      platform.delegate.started('https://play.games.dmm.com/game/kancolle');
      platform.delegate.progress!(79);
      const login = 'https://accounts.dmm.com/service/login/password';
      platform.delegate.started(login);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameStartupOverlay), findsNothing);
      platform.delegate.progress!(10);
      platform.delegate.error(
        const WebResourceError(
          errorCode: -2,
          description: 'net::ERR_NAME_NOT_RESOLVED',
          isForMainFrame: false,
          url: 'https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js',
        ),
      );
      platform.delegate.finished(login);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(find.byType(GameStartupOverlay), findsNothing);
      platform.delegate.progress!(95);
      await tester.pump(const Duration(seconds: 46));
      expect(find.byType(GameStartupOverlay), findsNothing);
    },
  );

  testWidgets('Gadget bootstrap error after early game detection is visible', (
    tester,
  ) async {
    await pump(tester);
    const entry = 'https://play.games.dmm.com/game/kancolle';
    platform.controller.presentation = 'game';
    platform.delegate.started(entry);
    platform.delegate.finished(entry);
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(GameStartupOverlay), findsNothing);
    platform.delegate.error(
      const WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        isForMainFrame: false,
        url: 'https://w00g.kancolle-server.com/gadget_html5/js/kcs_cda.js',
      ),
    );
    await tester.pump();
    expect(find.text('游戏启动脚本暂时无法加载'), findsOneWidget);
    expect(find.text('net::ERR_NAME_NOT_RESOLVED'), findsOneWidget);
  });

  testWidgets('local HTTP probe is actionable on and skipped when off', (
    tester,
  ) async {
    const networkChannel = MethodChannel(
      'app.yahagi.kancollebrowser/network_proxy',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      MethodChannel('app.yahagi.kancollebrowser/game_capture'),
      MethodChannel('app.yahagi.kancollebrowser/game_audio'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final calls = <String>[];
    var proxyReachable = false;
    final pendingProbe = Completer<void>();
    final probeResult = Completer<Map<String, Object?>>();
    var delayProbe = false;
    messenger.setMockMethodCallHandler(networkChannel, (call) async {
      calls.add(call.method);
      if (delayProbe && call.method == 'probeStartupLocalHttpProxy') {
        pendingProbe.complete();
        return probeResult.future;
      }
      return switch (call.method) {
        'applyHttpProxy' => {'success': true, 'code': 'ok'},
        'probeStartupLocalHttpProxy' =>
          proxyReachable
              ? {'success': true, 'code': 'ok'}
              : {
                  'success': false,
                  'code': 'local_http_proxy_unreachable',
                  'details': {'address': '127.0.0.1:8080'},
                },
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(networkChannel, null));
    final fixture = await _Fixture.create(
      networkSettings: const NetworkSettings(
        mode: NetworkMode.httpProxy,
        host: '127.0.0.1',
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      fixture.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(home: fixture.buildView(useDefaultStartup: true)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(platform.controller.loads, isEmpty);
    expect(find.text('无法连接 http本地代理'), findsOneWidget);
    expect(find.text('127.0.0.1:8080'), findsOneWidget);
    expect(find.textContaining('Kanxy'), findsNothing);
    proxyReachable = true;
    await tester.tap(find.byKey(const Key('game-webview-page-reload')));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(platform.controller.loads, hasLength(1));
    expect(find.text('无法连接 http本地代理'), findsNothing);
    expect(
      calls.where((method) => method == 'probeStartupLocalHttpProxy'),
      hasLength(2),
    );

    await tester.pumpWidget(const SizedBox());
    var enabled = false;
    final orchestrator = DefaultGameSurfaceStartupOrchestrator(
      networkSettingsController: fixture.network,
      captureModeController: fixture.captureMode,
      audioController: fixture.audio,
      gameCaptureController: fixture.capture,
      frameRateSettingsController: null,
      startupCheckEnabled: () => enabled,
    );
    addTearDown(orchestrator.dispose);
    calls.clear();
    expect((await orchestrator.applyNetworkSettings()).success, isTrue);
    expect(calls, contains('applyHttpProxy'));
    expect(calls, isNot(contains('probeStartupLocalHttpProxy')));

    enabled = true;
    delayProbe = true;
    final next = orchestrator.applyNetworkSettings();
    await pendingProbe.future;
    enabled = false;
    probeResult.complete({
      'success': false,
      'code': 'local_http_proxy_unreachable',
    });
    expect((await next).success, isTrue);
  });

  testWidgets('failed native bridge preparation must not navigate', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    final frameRate = await GameFrameRateSettingsController.load(
      MemoryGameFrameRateSettingsStore(),
    );
    final startup = _FailingFrameRateStartup();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      fixture.dispose();
      frameRate.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: GameWebView(
          networkSettingsController: fixture.network,
          safetySettingsController: fixture.safety,
          controller: fixture.status,
          browserController: fixture.browser,
          captureModeController: fixture.captureMode,
          audioController: fixture.audio,
          toolbarController: fixture.toolbar,
          gameCaptureController: fixture.capture,
          frameRateSettingsController: frameRate,
          startupOrchestratorFactory: () => startup,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(platform.controller.loads, isEmpty);
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
  });

  testWidgets(
    'platform navigation without callbacks times out and really retries',
    (tester) async {
      await pump(tester);
      await tester.pump(const Duration(seconds: 46));
      expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
      expect(
        tester
            .widget<GameStartupOverlay>(find.byType(GameStartupOverlay))
            .failure,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('game-webview-page-reload')));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(platform.controller.reloads, 1);
    },
  );

  testWidgets('platform main frame error survives a late finish callback', (
    tester,
  ) async {
    await pump(tester);
    platform.delegate.started('https://game.example/');
    platform.delegate.error(
      const WebResourceError(
        errorCode: -2,
        description: 'private error text',
        isForMainFrame: true,
      ),
    );
    await tester.pump();
    platform.delegate.finished('https://game.example/');
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
  });

  testWidgets(
    'platform old main page error cannot hide the current ready page',
    (tester) async {
      await pump(tester);
      platform.delegate.started('https://game.example/old');
      platform.delegate.started('https://game.example/current');
      platform.delegate.finished('https://game.example/current');
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      platform.delegate.error(
        const WebResourceError(
          errorCode: -2,
          description: 'old document error',
          isForMainFrame: true,
          url: 'https://game.example/old',
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
      expect(find.byType(GameStartupOverlay), findsNothing);
    },
  );

  testWidgets('platform child resource error keeps a usable login visible', (
    tester,
  ) async {
    await pump(tester);
    platform.delegate.started(
      'https://accounts.dmm.com/service/login/password',
    );
    platform.delegate.error(
      const WebResourceError(
        errorCode: -2,
        description: 'image unavailable',
        isForMainFrame: false,
      ),
    );
    platform.delegate.finished(
      'https://accounts.dmm.com/service/login/password',
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(GameStartupOverlay), findsNothing);
    expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
  });

  testWidgets('platform body pending does not finish the game load', (
    tester,
  ) async {
    await pump(tester);
    platform.controller.presentation = 'pending';
    platform.delegate.started('https://play.games.dmm.com/game/kancolle');
    platform.delegate.finished('https://play.games.dmm.com/game/kancolle');
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameStartupOverlay), findsOneWidget);
    await tester.pump(const Duration(seconds: 46));
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
    expect(
      tester
          .widget<GameStartupOverlay>(find.byType(GameStartupOverlay))
          .failure,
      isNotNull,
    );
  });

  testWidgets('platform body disappearing after readiness has a new deadline', (
    tester,
  ) async {
    await pump(tester);
    platform.controller.presentation = 'game';
    platform.delegate.started('https://play.games.dmm.com/game/kancolle');
    platform.delegate.finished('https://play.games.dmm.com/game/kancolle');
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(GameStartupOverlay), findsNothing);
    platform.controller.presentation = 'pending';
    platform.controller.channels['YahagiPresentation']!.onMessageReceived(
      const JavaScriptMessage(message: 'pending'),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameStartupOverlay), findsOneWidget);
    await tester.pump(const Duration(seconds: 46));
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
  });

  testWidgets('platform main page HTTP error is retryable', (tester) async {
    await pump(tester);
    platform.delegate.started('https://game.example/');
    platform.delegate.httpError?.call(
      HttpResponseError(
        request: WebResourceRequest(uri: Uri.parse('https://game.example/')),
        response: const WebResourceResponse(uri: null, statusCode: 503),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
  });

  testWidgets('closing a startup error only hides its card until reload', (
    tester,
  ) async {
    var webViewTaps = 0;
    platform.onTap = () => webViewTaps++;
    final fixture = await pump(tester);
    const url = 'https://game.example/';
    void failPage() {
      platform.delegate.started(url);
      platform.delegate.httpError?.call(
        HttpResponseError(
          request: WebResourceRequest(uri: Uri.parse(url)),
          response: const WebResourceResponse(uri: null, statusCode: 503),
        ),
      );
    }

    failPage();
    await tester.pump();
    final close = find.byKey(const Key('game-startup-close'));
    final retry = find.byKey(const Key('game-webview-page-reload'));
    expect(close, findsOneWidget);
    final buttonPosition = tester.getCenter(close);
    final errorMessage = fixture.browser.errorMessage;
    await tester.tap(close);
    await tester.pump();
    expect(find.byType(GameStartupOverlay), findsNothing);
    expect(fixture.browser.loadState, GamePageLoadState.failed);
    expect(fixture.browser.errorMessage, errorMessage);
    expect(platform.controller.loads, hasLength(1));
    expect(platform.controller.reloads, 0);
    await tester.tapAt(buttonPosition);
    expect(webViewTaps, 1);

    await fixture.browser.reload();
    expect(platform.controller.reloads, 1);
    failPage();
    await tester.pump();
    expect(close, findsOneWidget);
    expect(retry, findsOneWidget);
  });

  testWidgets('platform late page command response cannot hide a usable page', (
    tester,
  ) async {
    platform.controllerReply = Completer<void>();
    await pump(tester);
    platform.delegate.started('https://game.example/');
    platform.delegate.finished('https://game.example/');
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(GameStartupOverlay), findsNothing);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
    expect(find.byType(GameStartupOverlay), findsNothing);
    platform.controllerReply!.complete();
    await tester.pump();
  });

  testWidgets(
    'platform presentation message during a probe schedules a fresh read',
    (tester) async {
      await pump(tester);
      final old = Completer<Object>();
      platform.controller.probe = old;
      platform.delegate.started('https://game.example/');
      platform.delegate.finished('https://game.example/');
      await tester.pump();
      platform.controller.channels['YahagiPresentation']!.onMessageReceived(
        const JavaScriptMessage(message: 'game'),
      );
      platform.controller.presentation = 'game';
      platform.controller.probe = null;
      old.complete('pending');
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(find.byType(GameStartupOverlay), findsNothing);
    },
  );

  testWidgets('platform deadline pauses until the app resumes', (tester) async {
    await pump(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 46));
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
  });

  testWidgets('platform new document discards the old presentation result', (
    tester,
  ) async {
    await pump(tester);
    final old = Completer<Object>();
    platform.controller.probe = old;
    platform.delegate.started('https://game.example/old');
    platform.delegate.finished('https://game.example/old');
    await tester.pump();
    platform.delegate.started('https://game.example/current');
    old.complete('game');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameStartupOverlay), findsOneWidget);
    platform.controller.probe = null;
    platform.controller.presentation = 'web';
    platform.delegate.finished('https://game.example/current');
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(GameStartupOverlay), findsNothing);
  });
}

class _WebViewPlatform extends WebViewPlatform {
  late _Controller controller;
  late _Delegate delegate;
  VoidCallback? onTap;
  Completer<void>? controllerReply;
  bool useAndroidController = false;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller =
      (useAndroidController ? _AndroidController(params) : _Controller(params))
        ..loadReply = controllerReply;
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params, onTap);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  final List<Uri> loads = [];
  final scripts = <String>[];
  int reloads = 0;
  int backs = 0;
  String presentation = 'web';
  Completer<Object>? probe;
  Completer<void>? loadReply;
  final Map<String, JavaScriptChannelParams> channels = {};
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loads.add(params.uri);
    await loadReply?.future;
  }

  @override
  Future<void> reload() async {
    reloads++;
  }

  @override
  Future<bool> canGoBack() async => true;

  @override
  Future<void> goBack() async {
    backs++;
  }

  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
  }

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    scripts.add(script);
    return probe == null ? presentation : probe!.future;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}
}

class _AndroidController extends _Controller
    implements AndroidWebViewController {
  _AndroidController(super.params);

  @override
  Future<void> setUseWideViewPort(bool use) async {}

  @override
  Future<String?> getUserAgent() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  late PageEventCallback started;
  late PageEventCallback finished;
  late WebResourceErrorCallback error;
  HttpResponseErrorCallback? httpError;
  ProgressCallback? progress;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    started = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnProgress(ProgressCallback callback) async {
    progress = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    httpError = callback;
  }
}

class _View extends PlatformWebViewWidget {
  _View(super.params, this.onTap) : super.implementation();

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: const SizedBox.expand(),
  );
}

class _Fixture {
  _Fixture(this.network, this.safety, this.captureMode, this.audio);
  final NetworkSettingsController network;
  final SafetySettingsController safety;
  final CaptureModeController captureMode;
  final GameAudioController audio;
  final status = PrototypeStatusController();
  final browser = GameBrowserController(
    homeUri: Uri.parse('https://game.example/'),
  );
  final toolbar = GameToolbarController();
  final capture = GameCaptureController();
  static Future<_Fixture> create({NetworkSettings? networkSettings}) async {
    final network = NetworkSettingsController(
      store: _NetworkStore(networkSettings ?? const NetworkSettings()),
    );
    if (networkSettings != null) await network.initialize();
    return _Fixture(
      network,
      await SafetySettingsController.load(MemorySafetySettingsStore()),
      await CaptureModeController.load(SharedPreferencesCaptureModeStore()),
      await GameAudioController.load(SharedPreferencesGameAudioStore()),
    );
  }

  Widget get view => buildView();

  Widget buildView({
    bool useDefaultStartup = false,
    GameStartupActivityPort? activityPort,
    GameStartupCheckSettingsController? startupCheck,
  }) => GameWebView(
    networkSettingsController: network,
    safetySettingsController: safety,
    controller: status,
    browserController: browser,
    captureModeController: captureMode,
    audioController: audio,
    toolbarController: toolbar,
    gameCaptureController: capture,
    startupOrchestratorFactory: useDefaultStartup ? null : () => _Startup(),
    startupActivityPort:
        activityPort ?? const MethodChannelGameStartupActivityPort(),
    gameStartupCheckSettingsController: startupCheck,
  );
  void dispose() {
    network.dispose();
    safety.dispose();
    captureMode.dispose();
    audio.dispose();
    status.dispose();
    browser.dispose();
    toolbar.dispose();
    capture.dispose();
  }
}

class _StartupActivityPort implements GameStartupActivityPort {
  GameStartupActivitySnapshot? next;
  int reads = 0;

  @override
  Future<GameStartupActivitySnapshot?> snapshot({
    required bool nativeActivity,
  }) async {
    reads++;
    return next;
  }
}

Future<GameStartupCheckSettingsController> _loadStartupCheck(bool enabled) {
  SharedPreferences.setMockInitialValues({
    GameStartupCheckSettingsController.preferenceKey: enabled,
  });
  return GameStartupCheckSettingsController.load();
}

class _NetworkStore implements NetworkSettingsStore {
  const _NetworkStore(this.settings);

  final NetworkSettings settings;

  @override
  Future<NetworkSettings> loadSettings() async => settings;
  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}

class _Startup implements GameSurfaceStartupOrchestrator {
  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async =>
      const GameSurfaceNetworkResult.success();
  @override
  Future<void> runCaptureStartup({
    required Future<void> Function() waitForSurface,
    required bool Function() isActive,
    required Future<void> Function() navigate,
  }) async {
    await waitForSurface();
    if (isActive()) await navigate();
  }

  @override
  Future<void> prepareCapture() async {}
  @override
  Future<void> attachAudioPortOnce() async {}
  @override
  Future<bool> attachFrameRatePlatformPort() async => false;
  @override
  void dispose() {}
}

class _FailingFrameRateStartup extends _Startup {
  @override
  Future<bool> attachFrameRatePlatformPort() async {
    throw PlatformException(code: 'webview_not_found');
  }
}

class _PreparingFrameRatePort implements GameFrameRatePort {
  final List<GameFrameRateMode> modes = [];
  Completer<void>? pending;
  Object? failure;
  int supportChecks = 0;

  @override
  Future<bool> isSupported() async {
    supportChecks++;
    return true;
  }

  @override
  Future<void> configure(GameFrameRateMode mode) async {
    modes.add(mode);
    await pending?.future;
    if (failure case final error?) throw error;
  }
}
