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
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';
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
      expect(find.byType(CircularProgressIndicator), findsNothing);

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

  Future<_Fixture> pump(WidgetTester tester) async {
    final fixture = await _Fixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      fixture.dispose();
    });
    await tester.pumpWidget(MaterialApp(home: fixture.view));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(platform.controller.loads, hasLength(1));
    return fixture;
  }

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
      expect(find.byType(CircularProgressIndicator), findsNothing);
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
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 46));
    expect(find.byKey(const Key('game-webview-page-reload')), findsOneWidget);
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
    expect(find.byType(CircularProgressIndicator), findsNothing);
    platform.controller.presentation = 'pending';
    platform.controller.channels['YahagiPresentation']!.onMessageReceived(
      const JavaScriptMessage(message: 'pending'),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(const Key('game-webview-page-reload')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
      expect(find.byType(CircularProgressIndicator), findsNothing);
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
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    platform.controller.probe = null;
    platform.controller.presentation = 'web';
    platform.delegate.finished('https://game.example/current');
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _WebViewPlatform extends WebViewPlatform {
  late _Controller controller;
  late _Delegate delegate;
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
  ) => _View(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  final List<Uri> loads = [];
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
  Future<void> runJavaScript(String script) async {}
  @override
  Future<Object> runJavaScriptReturningResult(String script) async =>
      probe == null ? presentation : probe!.future;
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
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {
    httpError = callback;
  }
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
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
  static Future<_Fixture> create() async => _Fixture(
    NetworkSettingsController(store: _NetworkStore()),
    await SafetySettingsController.load(MemorySafetySettingsStore()),
    await CaptureModeController.load(SharedPreferencesCaptureModeStore()),
    await GameAudioController.load(SharedPreferencesGameAudioStore()),
  );
  Widget get view => GameWebView(
    networkSettingsController: network,
    safetySettingsController: safety,
    controller: status,
    browserController: browser,
    captureModeController: captureMode,
    audioController: audio,
    toolbarController: toolbar,
    gameCaptureController: capture,
    startupOrchestratorFactory: () => _Startup(),
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

class _NetworkStore implements NetworkSettingsStore {
  @override
  Future<NetworkSettings> loadSettings() async => const NetworkSettings();
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
