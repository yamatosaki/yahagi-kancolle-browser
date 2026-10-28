import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_page_alignment_script.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';

void main() {
  late _WebViewPlatform platform;
  final calls = <MethodCall>[];
  final frameRateCalls = <MethodCall>[];
  Completer<void>? bindGate;
  const scaling = MethodChannel('app.webview/fixed_canvas_scaling');
  const frameRate = MethodChannel('app.yahagi.kancollebrowser/game_frame_rate');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
    calls.clear();
    frameRateCalls.clear();
    bindGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(scaling, (call) async {
        calls.add(call);
        if (call.method == 'bindFixedCanvas') await bindGate?.future;
        return null;
      })
      ..setMockMethodCallHandler(frameRate, (call) async {
        frameRateCalls.add(call);
        return null;
      })
      ..setMockMethodCallHandler(
        const MethodChannel(gameFrameReloadMethodChannelName),
        (_) async => null,
      );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(scaling, null)
      ..setMockMethodCallHandler(frameRate, null)
      ..setMockMethodCallHandler(
        const MethodChannel(gameFrameReloadMethodChannelName),
        null,
      );
  });

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump();
    }
  }

  Future<_Fixture> pump(WidgetTester tester) async {
    final fixture = await _Fixture.create();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      fixture.dispose();
    });
    await tester.pumpWidget(MaterialApp(home: fixture.view));
    await drain(tester);
    expect(frameRateCalls.map((call) => call.method), ['configure']);
    expect(frameRateCalls.single.arguments, {'mode': 'auto'});
    expect(platform.controller.loads, hasLength(1));
    return fixture;
  }

  void notify(String state) {
    platform.controller.channels['YahagiPresentation']!.onMessageReceived(
      JavaScriptMessage(message: state),
    );
  }

  Future<void> finish(WidgetTester tester, String url, String state) async {
    platform.controller.presentation = state;
    platform.delegate.started(url);
    platform.delegate.finished(url);
    await drain(tester);
  }

  test('new installs default to the Activity WebView path', () {
    expect(GameRenderingModeCodec.decode(null).usesActivityWebView, isTrue);
    for (final mode in [
      GameRenderingMode.standard,
      GameRenderingMode.compatibility,
      GameRenderingMode.canvasCompatibility,
    ]) {
      expect(mode.usesPlatformView, isTrue);
    }
  });

  testWidgets(
    'Android platform entry binds on initial and delayed game detection',
    (tester) async {
      final fixture = await pump(tester);
      await finish(
        tester,
        'https://play.games.dmm.com/game/kancolle',
        'pending',
      );
      expect(calls, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      platform.controller.presentation = 'game';
      notify('game');
      await drain(tester);
      expect(calls.map((call) => call.method), ['bindFixedCanvas']);
      expect(calls.single.arguments, {
        'contentWidth': 1200,
        'contentHeight': 720,
      });
      expect(platform.controller.probes, contains(gamePageAlignmentScript));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fixture.toolbar.stage, GameSurfaceStage.game);
      await finish(
        tester,
        'https://w17k.kancolle-server.com/kcs2/index.html',
        'game',
      );
      expect(
        calls.where((call) => call.method == 'bindFixedCanvas'),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'Android platform web presentations release native fit through OOI and login flow',
    (tester) async {
      final fixture = await pump(tester);
      await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
      for (final url in [
        'https://accounts.dmm.com/service/login/password',
        'https://ooi.moe/',
        'https://ooi.moe/kancolle',
        'https://ooi.moe/poi',
        'https://external.example/',
      ]) {
        calls.clear();
        await finish(tester, url, 'web');
        expect(calls.map((call) => call.method), [
          'releaseFixedCanvas',
        ], reason: url);
        expect(fixture.toolbar.stage, GameSurfaceStage.login, reason: url);
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: url,
        );
      }
      await finish(tester, 'https://ooi.moe/kcs2/index.php', 'game');
      expect(calls.last.method, 'bindFixedCanvas');
      // The DOM probe can report a visible purchase dialog without navigation.
      platform.controller.presentation = 'web';
      notify('web');
      await drain(tester);
      expect(calls.last.method, 'releaseFixedCanvas');
      platform.controller.presentation = 'game';
      notify('game');
      await drain(tester);
      expect(calls.last.method, 'bindFixedCanvas');
    },
  );

  testWidgets(
    'Android platform manual fit reapplies native fit in the same game document',
    (tester) async {
      final fixture = await pump(tester);
      await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
      final before = calls
          .where((call) => call.method == 'bindFixedCanvas')
          .length;
      final fit = fixture.browser.fitGameScreen();
      await drain(tester);
      await fit;
      expect(platform.controller.loads, hasLength(1));
      expect(platform.controller.reloads, 0);
      expect(
        calls.where((call) => call.method == 'bindFixedCanvas'),
        hasLength(before + 1),
        reason:
            'An explicit fit must restore effective zoom even when presentation is still game.',
      );
    },
  );

  testWidgets(
    'Android platform runtime game-fit action rechecks and refits the current document',
    (tester) async {
      await pump(tester);
      await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
      final beforeProbes = platform.controller.probes.length;
      final beforeFits = calls
          .where((call) => call.method == 'bindFixedCanvas')
          .length;
      notify('game-fit');
      await drain(tester);
      expect(
        platform.controller.probes.length,
        greaterThan(beforeProbes),
        reason:
            'The alignment runtime sends game-fit for an explicit same-document restore.',
      );
      expect(
        calls.where((call) => call.method == 'bindFixedCanvas'),
        hasLength(beforeFits + 1),
      );
    },
  );

  testWidgets(
    'page finish installs the runtime after an earlier read-only probe',
    (tester) async {
      await pump(tester);
      final pending = Completer<Object>();
      platform.controller.probe = pending;
      platform.delegate.started('https://play.games.dmm.com/game/kancolle');
      notify('game');
      await tester.pump();
      platform.delegate.finished('https://play.games.dmm.com/game/kancolle');
      await tester.pump();
      platform.controller.probe = null;
      platform.controller.presentation = 'game';
      pending.complete('pending');
      await drain(tester);
      expect(platform.controller.probes, contains(gamePageAlignmentScript));
      expect(calls.last.method, 'bindFixedCanvas');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'Android platform manual fit queued during a probe reaches the native host',
    (tester) async {
      final fixture = await pump(tester);
      await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
      final pending = Completer<Object>();
      platform.controller.probe = pending;
      notify('game');
      await tester.pump();
      final before = calls.length;
      final fit = fixture.browser.fitGameScreen();
      platform.controller.probe = null;
      pending.complete('game');
      await drain(tester);
      await fit;
      expect(calls.length, greaterThan(before));
      expect(calls.last.method, 'bindFixedCanvas');
      expect(platform.controller.loads, hasLength(1));
    },
  );

  for (final asynchronous in [false, true]) {
    testWidgets(
      'runtime ${asynchronous ? "asynchronous" : "synchronous"} game-fit echo reaches a stable bound',
      (tester) async {
        final fixture = await pump(tester);
        var injections = 0;
        platform.controller.onRuntimeProbe = () {
          injections++;
          if (injections > 2) {
            throw StateError('A bridge echo must not reinject the runtime.');
          }
          if (asynchronous) {
            Timer(const Duration(milliseconds: 1), () => notify('game-fit'));
          } else {
            notify('game-fit');
          }
        };
        await finish(
          tester,
          'https://play.games.dmm.com/game/kancolle',
          'game',
        );
        await tester.pump(const Duration(milliseconds: 2));
        await drain(tester);
        expect(injections, 1);
        expect(calls.length, inInclusiveRange(1, 2));
        final fit = fixture.browser.fitGameScreen();
        await drain(tester);
        await tester.pump(const Duration(milliseconds: 2));
        await drain(tester);
        await fit;
        expect(injections, 2);
        expect(calls.length, inInclusiveRange(2, 4));
        expect(platform.controller.maximumConcurrentProbes, 1);
        final stopped = calls.length;
        await tester.pump(const Duration(seconds: 1));
        await drain(tester);
        expect(calls.length, stopped);
      },
    );
  }

  testWidgets(
    'late game-fit action on a login document only releases game fitting',
    (tester) async {
      final fixture = await pump(tester);
      await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
      await finish(
        tester,
        'https://accounts.dmm.com/service/login/password',
        'web',
      );
      calls.clear();
      notify('game-fit');
      await drain(tester);
      expect(calls, isEmpty);
      final fit = fixture.browser.fitGameScreen();
      await drain(tester);
      await fit;
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'manual retry queued behind a failed probe still reaches native fitting',
    (tester) async {
      final fixture = await pump(tester);
      await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
      final pending = Completer<Object>();
      platform.controller.probe = pending;
      notify('game');
      await tester.pump();
      final before = calls.length;
      final outcome = fixture.browser.fitGameScreen().then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      platform.controller.probe = null;
      pending.completeError(StateError('old presentation probe failed'));
      await drain(tester);
      expect(await outcome, isNull);
      expect(calls.length, before + 1);
      expect(calls.last.method, 'bindFixedCanvas');
    },
  );

  testWidgets('manual retry queued behind a failed native fit still executes', (
    tester,
  ) async {
    final fixture = await pump(tester);
    await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
    final pending = Completer<void>();
    bindGate = pending;
    final before = calls.length;
    notify('game-fit');
    await drain(tester);
    expect(calls.length, before + 1);
    final outcome = fixture.browser.fitGameScreen().then<Object?>(
      (_) => null,
      onError: (Object error) => error,
    );
    bindGate = null;
    pending.completeError(PlatformException(code: 'old_native_fit_failed'));
    await drain(tester);
    expect(await outcome, isNull);
    expect(calls.length, before + 2);
    expect(calls.last.method, 'bindFixedCanvas');
  });

  testWidgets(
    'failed fit without a queued request propagates and does not retry',
    (tester) async {
      final fixture = await pump(tester);
      await finish(tester, 'https://play.games.dmm.com/game/kancolle', 'game');
      final pending = Completer<void>();
      bindGate = pending;
      final before = calls.length;
      final outcome = fixture.browser.fitGameScreen().then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      await drain(tester);
      bindGate = null;
      pending.completeError(PlatformException(code: 'native_fit_failed'));
      await drain(tester);
      expect(await outcome, isA<PlatformException>());
      await tester.pump(const Duration(seconds: 1));
      await drain(tester);
      expect(calls.length, before + 1);
    },
  );

  for (final dispose in [false, true]) {
    testWidgets(
      'failed probe does not retry queued work after ${dispose ? "dispose" : "navigation"}',
      (tester) async {
        final fixture = await pump(tester);
        await finish(
          tester,
          'https://play.games.dmm.com/game/kancolle',
          'game',
        );
        final pending = Completer<Object>();
        platform.controller.probe = pending;
        notify('game');
        await tester.pump();
        final outcome = fixture.browser.fitGameScreen().then<Object?>(
          (_) => null,
          onError: (Object error) => error,
        );
        if (dispose) {
          await tester.pumpWidget(const SizedBox());
        } else {
          platform.delegate.started(
            'https://accounts.dmm.com/service/login/password',
          );
        }
        calls.clear();
        platform.controller.probe = null;
        pending.completeError(StateError('retired presentation failed'));
        await drain(tester);
        expect(await outcome, isA<StateError>());
        expect(calls, isEmpty);
      },
    );
  }

  testWidgets(
    'Android platform ignores a stale probe after navigation and disposal',
    (tester) async {
      await pump(tester);
      final old = Completer<Object>();
      platform.controller.probe = old;
      platform.delegate.started('https://play.games.dmm.com/game/kancolle');
      platform.delegate.finished('https://play.games.dmm.com/game/kancolle');
      await tester.pump();
      platform.delegate.started(
        'https://accounts.dmm.com/service/login/password',
      );
      old.complete('game');
      await drain(tester);
      expect(calls.where((call) => call.method == 'bindFixedCanvas'), isEmpty);
      platform.controller.probe = null;
      platform.controller.presentation = 'web';
      platform.delegate.finished(
        'https://accounts.dmm.com/service/login/password',
      );
      await drain(tester);
      expect(calls.last.method, 'releaseFixedCanvas');
      final delayed = Completer<Object>();
      platform.controller.probe = delayed;
      notify('game');
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      calls.clear();
      notify('game-fit');
      delayed.complete('game');
      await drain(tester);
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class _WebViewPlatform extends WebViewPlatform {
  late _Controller controller;
  late _Delegate delegate;
  Completer<void>? controllerReply;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _Controller(params)..loadReply = controllerReply;
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _Controller extends PlatformWebViewController
    implements AndroidWebViewController {
  _Controller(super.params) : super.implementation();
  final List<Uri> loads = [];
  final List<String> probes = [];
  VoidCallback? onRuntimeProbe;
  int concurrentProbes = 0;
  int maximumConcurrentProbes = 0;
  @override
  Future<void> setUseWideViewPort(bool useWideViewPort) async {}
  @override
  Future<String?> getUserAgent() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  int reloads = 0;
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
  Future<void> runJavaScript(String script) async {}
  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    probes.add(script);
    concurrentProbes++;
    if (concurrentProbes > maximumConcurrentProbes) {
      maximumConcurrentProbes = concurrentProbes;
    }
    try {
      if (script == gamePageAlignmentScript) onRuntimeProbe?.call();
      return await (probe?.future ?? Future<Object>.value(presentation));
    } finally {
      concurrentProbes--;
    }
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}
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
