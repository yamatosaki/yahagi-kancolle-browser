import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_port.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_reload_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_launch_config.dart';
import 'package:yahagi_kancolle_browser/src/browser/network_proxy_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_preview.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_port.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/native_activity_game_surface.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_runtime_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';

void main() {
  testWidgets('DMM compatibility receives the complete native login URL', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    const url =
        'https://accounts.dmm.com/service/login/password?return_url=fixture';
    fixture.port.addEvent(_event('pageStarted', generationId: 7, url: url));
    fixture.port.addEvent(_event('pageFinished', generationId: 7, url: url));
    await tester.pump();
    final scripts = fixture.port.executedScripts.where(
      (s) => s.contains('ckcy=1'),
    );
    expect(scripts, hasLength(1));
    expect(scripts.single, contains(url));
    expect(
      fixture.browserController.displayAddress,
      isNot(contains('return_url')),
    );
  });
  testWidgets(
    'shows a decoded popup preview while the native surface is hidden',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();
      fixture.port.addEvent(
        _event('pageStarted', generationId: 7, url: 'https://game.example/'),
      );
      fixture.port.addEvent(
        _event('pageFinished', generationId: 7, url: 'https://game.example/'),
      );
      await _pumpUntil(
        tester,
        () => fixture.port.calls.contains('visible:true'),
      );
      fixture.port.calls.clear();

      unawaited(
        fixture.navigatorKey.currentState!.push<void>(
          RawDialogRoute<void>(
            pageBuilder: (_, _, _) => const Text('dialog'),
            barrierDismissible: true,
            barrierLabel: 'barrier',
            barrierColor: Colors.black54,
          ),
        ),
      );
      await _pumpUntil(
        tester,
        () => fixture.port.calls.contains('visible:false'),
      );

      expect(fixture.previewPort.calls, 1);
      expect(
        find.byKey(const Key('native-game-surface-popup-preview')),
        findsOneWidget,
      );

      fixture.navigatorKey.currentState!.pop();
      await _pumpUntil(
        tester,
        () => fixture.port.calls.contains('visible:true'),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('native-game-surface-popup-preview')),
        findsNothing,
      );
    },
  );

  test(
    'method-channel native port configures frame bridge before navigation',
    () async {
      const nativeChannel = MethodChannel('test/native-frame-reload');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final sequence = <String>[];
      final nativeCalls = <MethodCall>[];
      messenger.setMockMethodCallHandler(nativeChannel, (call) async {
        nativeCalls.add(call);
        if (call.method == 'create') return 9;
        if (call.method == 'loadUri') sequence.add('navigate');
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(nativeChannel, null),
      );
      final events = StreamController<Object?>.broadcast();
      addTearDown(events.close);
      final delegate = MethodChannelNativeGameWebViewPort(
        channel: nativeChannel,
        eventStream: events.stream,
      );
      final frameReload = _FakeFrameReloadPort(
        onConfigure: () => sequence.add('configure'),
      );
      final port = MethodChannelNativeActivityGameWebViewPort(
        delegate: delegate,
        frameReloadPort: frameReload,
      );
      addTearDown(port.dispose);

      await port.create();
      await port.loadUri(Uri.parse('https://www.dmm.com/game'));

      expect(sequence, <String>['configure', 'navigate']);
      expect(await port.reloadGameFrame(), GameFrameReloadResult.reloaded);
      expect(frameReload.reloadCalls, 1);
      expect(
        nativeCalls.map((call) => call.method),
        isNot(contains('reloadGameFrame')),
      );
    },
  );

  test('native startup error exposes platform code and create stage', () {
    final message = nativeWebViewStartupErrorMessage(
      PlatformException(
        code: 'native_webview_create_failed',
        message: 'Native WebView creation failed at configure_web_view.',
        details: <String, Object?>{
          'stage': 'configure_web_view',
          'exceptionType': 'IllegalStateException',
        },
      ),
    );

    expect(
      message,
      '原生 WebView 启动失败 [native_webview_create_failed/configure_web_view] '
      '(IllegalStateException)',
    );
  });

  testWidgets('displays switch rendering mode hint on startup failure', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    fixture.port.createFailure = PlatformException(
      code: 'native_webview_create_failed',
      message: 'Native WebView creation failed.',
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);
    expect(
      find.text('当前设备暂不兼容此模式。请滚动左侧菜单，前往【设置 - 画面与声音】切换渲染模式。'),
      findsOneWidget,
    );
  });

  testWidgets('manual fit resends native bounds before fitting the page', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.calls.clear();

    final operation = fixture.browserController.fitGameScreen();
    await tester.pump();
    await operation;

    expect(
      fixture.port.calls.where((call) => call == 'bounds' || call == 'fit'),
      <String>['bounds', 'fit'],
    );
  });

  testWidgets('resuming the app resynchronizes native game bounds', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await fixture.dispose();
    });
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    fixture.port.calls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(fixture.port.calls, contains('bounds'));
  });

  test(
    'default startup orchestrator delegates network capture audio and frame rate in order',
    () async {
      final calls = <String>[];
      final fixture = await _DefaultOrchestratorFixture.create(calls);
      addTearDown(fixture.dispose);

      final networkResult = await fixture.orchestrator.applyNetworkSettings();
      await fixture.orchestrator.runCaptureStartup(
        waitForSurface: () async => calls.add('surface'),
        isActive: () => true,
        navigate: () async => calls.add('navigate'),
      );
      await fixture.orchestrator.attachAudioPortOnce();
      final frameRateSupported = await fixture.orchestrator
          .attachFrameRatePlatformPort();

      expect(networkResult.success, isTrue);
      expect(frameRateSupported, isTrue);
      expect(calls, <String>[
        'network',
        'surface',
        'capture.supported',
        'capture.configure:true',
        'navigate',
        'audio.supported',
        'audio.muted:false',
        'frame.supported',
        'frame.configure:auto',
      ]);
    },
  );

  test(
    'default startup orchestrator exposes failure then reapplies on retry',
    () async {
      final calls = <String>[];
      final fixture = await _DefaultOrchestratorFixture.create(calls);
      addTearDown(fixture.dispose);
      fixture.networkController.results.addAll(<ProxyResult>[
        const ProxyResult(
          success: false,
          code: 'offline',
          message: 'offline',
          elapsedMs: 0,
        ),
        const ProxyResult(success: true, code: 'ok', message: '', elapsedMs: 0),
      ]);

      final failed = await fixture.orchestrator.applyNetworkSettings();
      final retried = await fixture.orchestrator.applyNetworkSettings();

      expect(failed.success, isFalse);
      expect(retried.success, isTrue);
      expect(calls, <String>['network', 'network']);
    },
  );

  test(
    'default orchestrator shares audio attach and retries unavailable ports',
    () async {
      final calls = <String>[];
      final support = Completer<bool>();
      var audioPortNumber = 0;
      final fixture = await _DefaultOrchestratorFixture.create(
        calls,
        audioPortFactory: () {
          audioPortNumber += 1;
          if (audioPortNumber == 1) return _BlockingAudioPort(support.future);
          return _RecordingAudioPort(calls);
        },
      );
      addTearDown(fixture.dispose);

      final first = fixture.orchestrator.attachAudioPortOnce();
      var secondCompleted = false;
      final second = fixture.orchestrator.attachAudioPortOnce().whenComplete(
        () => secondCompleted = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(secondCompleted, isFalse);

      support.complete(false);
      await Future.wait(<Future<void>>[first, second]);
      await fixture.orchestrator.attachAudioPortOnce();
      expect(audioPortNumber, 2);
    },
  );

  test(
    'default orchestrator serializes capture changes with latest mode last',
    () async {
      final calls = <String>[];
      final firstConfigure = Completer<void>();
      final capturePort = _BlockingCapturePort(firstConfigure);
      final fixture = await _DefaultOrchestratorFixture.create(
        calls,
        capturePortFactory: () => capturePort,
      );
      addTearDown(fixture.dispose);

      final first = fixture.orchestrator.prepareCapture();
      await Future<void>.delayed(Duration.zero);
      await fixture.captureModeController.setMode(CaptureMode.browserOnly);
      final second = fixture.orchestrator.prepareCapture();
      await fixture.captureModeController.setMode(CaptureMode.game);
      final third = fixture.orchestrator.prepareCapture();
      await Future<void>.delayed(Duration.zero);

      expect(capturePort.enabledCalls, <bool>[true]);
      firstConfigure.complete();
      await Future.wait(<Future<void>>[first, second, third]);
      expect(capturePort.enabledCalls.last, isTrue);
    },
  );

  test('default orchestrator reuses one capture allowlist', () async {
    final calls = <String>[];
    final capturePort = _ScriptRecordingCapturePort();
    final fixture = await _DefaultOrchestratorFixture.create(
      calls,
      capturePortFactory: () => capturePort,
    );
    addTearDown(fixture.dispose);

    await fixture.orchestrator.prepareCapture();
    await fixture.orchestrator.prepareCapture();

    const kcwikiOnlyPath = '/kcsapi/api_req_kousyou/remodel_slotlist';
    expect(capturePort.scripts, hasLength(1));
    expect(capturePort.scripts.single, contains(kcwikiOnlyPath));
  });

  testWidgets(
    'subscribes before create and builds a slot without any platform view',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      fixture.port.eventsDuringCreate.addAll(<NativeGameWebViewEvent>[
        _event('created', generationId: 7),
        _event(
          'pageStarted',
          generationId: 7,
          url: 'https://www.dmm.com/early',
        ),
      ]);

      await fixture.pump(tester);
      await tester.pump();

      expect(fixture.port.calls.take(2), <String>['listen', 'create']);
      expect(find.byType(NativeGameSurfaceSlot), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
      expect(find.byType(PlatformViewLink), findsNothing);
      expect(find.byType(AndroidView), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      expect(fixture.statusController.loadState, WebViewLoadState.loading);
      fixture.toolbarController.collapse();
    },
  );

  testWidgets('native surface drives the frame-rate runtime on game pages', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    final frameRateSettings = await GameFrameRateSettingsController.load(
      MemoryGameFrameRateSettingsStore(),
    );
    final frameRatePort = _FakeNativeFrameRateRuntimePort();
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      frameRateSettings.dispose();
      await fixture.dispose();
    });
    await fixture.pump(
      tester,
      frameRateSettingsController: frameRateSettings,
      frameRateRuntimePortFactory: () => frameRatePort,
    );
    await tester.pump();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://osapi.dmm.com/game'),
    );
    fixture.port.addEvent(
      _event(
        'pageFinished',
        generationId: 7,
        url: 'https://osapi.dmm.com/game',
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    fixture.toolbarController.collapse();

    expect(frameRatePort.appliedTargets, contains(GameFrameRateTarget.fps60));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    expect(frameRatePort.appliedTargets.last, GameFrameRateTarget.fps30);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(frameRatePort.appliedTargets.last, GameFrameRateTarget.fps60);
  });

  testWidgets(
    'native surface preserves manual modes across lifecycle changes',
    (tester) async {
      for (final entry in <GameFrameRateMode, GameFrameRateTarget>{
        GameFrameRateMode.stable60: GameFrameRateTarget.fps60,
        GameFrameRateMode.highRefresh: GameFrameRateTarget.highRefresh,
      }.entries) {
        final fixture = _SurfaceFixture();
        final frameRateSettings = await GameFrameRateSettingsController.load(
          MemoryGameFrameRateSettingsStore(entry.key),
        );
        final frameRatePort = _FakeNativeFrameRateRuntimePort();
        addTearDown(() async {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          frameRateSettings.dispose();
          await fixture.dispose();
        });
        await fixture.pump(
          tester,
          frameRateSettingsController: frameRateSettings,
          frameRateRuntimePortFactory: () => frameRatePort,
        );
        await tester.pump();

        fixture.port.addEvent(
          _event(
            'pageStarted',
            generationId: 7,
            url: 'https://osapi.dmm.com/game',
          ),
        );
        fixture.port.addEvent(
          _event(
            'pageFinished',
            generationId: 7,
            url: 'https://osapi.dmm.com/game',
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(frameRatePort.appliedTargets.last, entry.value);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.pump();
        expect(frameRatePort.appliedTargets.last, entry.value);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();
        expect(frameRatePort.appliedTargets.last, entry.value);
      }
    },
  );

  testWidgets('native surface leaves the OOI mode choices untouched', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://ooi.moe/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://ooi.moe/'),
    );
    await tester.pump();
    await tester.pump();

    expect(fixture.port.executedScripts, isEmpty);

    fixture.port.addEvent(
      _event(
        'pageStarted',
        generationId: 7,
        url: 'https://w17k.kancolle-server.com/kcs2/index.html',
      ),
    );
    fixture.port.addEvent(
      _event(
        'pageFinished',
        generationId: 7,
        url: 'https://w17k.kancolle-server.com/kcs2/index.html',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(fixture.port.executedScripts, isEmpty);
    fixture.toolbarController.collapse();
  });

  testWidgets('native visibility follows readiness instead of slot desire', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    expect(fixture.port.calls, contains('visible:false'));
    expect(fixture.port.calls, isNot(contains('visible:true')));

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:true',
    );

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/next'),
    );
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:false',
    );
    fixture.toolbarController.collapse();

    fixture.port.addEvent(
      _event(
        'mainFrameError',
        generationId: 7,
        errorCode: -2,
        description: 'failed',
      ),
    );
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:false',
    );
  });

  testWidgets('page completion fits the native page before becoming ready', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.calls.clear();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();

    expect(fixture.port.calls, contains('fit'));
    expect(fixture.orchestrator.prepareCaptureCalls, greaterThan(0));
    expect(fixture.orchestrator.attachAudioCalls, greaterThan(0));
    expect(find.byKey(const Key('native-game-surface-error')), findsNothing);
    fixture.toolbarController.collapse();
  });

  testWidgets('page completion waits for foreground before finalizing', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await fixture.dispose();
    });
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.calls.clear();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(fixture.port.calls, isNot(contains('fit')));
    expect(fixture.statusController.loadState, isNot(WebViewLoadState.failed));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(fixture.port.calls.where((call) => call == 'fit'), hasLength(1));
    expect(fixture.statusController.loadState, WebViewLoadState.ready);
  });

  testWidgets('terminal page initialization reports the failed stage', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    fixture.port.fitFailures.addAll(<Object>[
      TimeoutException('first attempt'),
      TimeoutException('first retry'),
      TimeoutException('reloaded attempt'),
      TimeoutException('reloaded retry'),
    ]);
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(fixture.browserController.errorMessage, contains('[fitGameScreen]'));
    expect(
      fixture.browserController.errorMessage,
      contains('TimeoutException'),
    );
  });

  testWidgets('page initialization retries once before becoming ready', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    fixture.port.fitFailures.add(StateError('first fit failed'));
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.calls.clear();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(fixture.port.calls.where((call) => call == 'fit'), hasLength(2));
    expect(fixture.port.calls.where((call) => call == 'reload'), isEmpty);
    expect(fixture.statusController.loadState, WebViewLoadState.ready);
  });

  testWidgets('page initialization reloads once after two failures', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    fixture.port.fitFailures.addAll(<Object>[
      StateError('first fit failed'),
      StateError('second fit failed'),
    ]);
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.calls.clear();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(fixture.port.calls.where((call) => call == 'fit'), hasLength(2));
    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
  });

  testWidgets(
    'automatic page recovery stops after one reload and offers manual reload',
    (tester) async {
      final fixture = _SurfaceFixture();
      fixture.port.fitFailures.addAll(<Object>[
        StateError('first attempt'),
        StateError('first retry'),
        StateError('reloaded attempt'),
        StateError('reloaded retry'),
      ]);
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();
      fixture.port.calls.clear();

      fixture.port.addEvent(
        _event('pageStarted', generationId: 7, url: 'https://game.example/'),
      );
      fixture.port.addEvent(
        _event('pageFinished', generationId: 7, url: 'https://game.example/'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      fixture.port.addEvent(
        _event('pageStarted', generationId: 7, url: 'https://game.example/'),
      );
      fixture.port.addEvent(
        _event('pageFinished', generationId: 7, url: 'https://game.example/'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        fixture.port.calls.where((call) => call == 'reload'),
        hasLength(1),
      );
      expect(
        find.byKey(const Key('native-game-surface-page-reload')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('native-game-surface-page-reload')),
      );
      await tester.pump();

      expect(
        fixture.port.calls.where((call) => call == 'reload'),
        hasLength(2),
      );
    },
  );

  testWidgets('route desire stays authoritative when a page becomes ready', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pump();
    await tester.pump();
    fixture.toolbarController.collapse();
    fixture.port.calls.clear();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, isNot(contains('visible:true')));

    fixture.navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, contains('visible:true'));
    fixture.toolbarController.collapse();
  });

  testWidgets('visibility writes are serialized and latest desire wins', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final show = Completer<void>();
    fixture.port.visibilityCompleters.add(show);

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    expect(
      fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
      'visible:true',
    );

    fixture.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pump();
    expect(
      fixture.port.calls.where((call) => call == 'visible:false'),
      hasLength(1),
    );

    show.complete();
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls.last, 'visible:false');
    fixture.toolbarController.collapse();
  });

  testWidgets('dispose queues hide behind an in-flight show before destroy', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final show = Completer<void>();
    fixture.port.visibilityCompleters.add(show);
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    fixture.toolbarController.collapse();
    fixture.port.calls.clear();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(fixture.port.calls, isEmpty);

    show.complete();
    await tester.pump();
    await tester.pump();
    await _pumpUntilDestroyed(tester, fixture.port);
    expect(
      fixture.port.calls,
      containsAllInOrder(<String>['visible:false', 'cancel', 'destroy']),
    );
  });

  testWidgets('a never-ending show times out so terminal hide can destroy', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await tester.pump();
    fixture.port.visibilityCompleters.add(Completer<void>());
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    fixture.toolbarController.collapse();
    fixture.port.calls.clear();

    await tester.pumpWidget(const SizedBox.shrink());
    for (var index = 0; index < 6; index++) {
      await tester.pump(const Duration(milliseconds: 2));
    }
    await _pumpUntilDestroyed(tester, fixture.port);

    expect(
      fixture.port.calls,
      containsAllInOrder(<String>['visible:false', 'cancel', 'destroy']),
    );
  });

  testWidgets('show failure retries, keeps an error overlay, and can recover', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.visibilityFailuresRemaining = 3;

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      fixture.port.calls.where((call) => call == 'visible:true'),
      hasLength(3),
    );
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);
    expect(fixture.port.calls, isNot(contains('destroy')));

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/retry'),
    );
    fixture.port.addEvent(
      _event(
        'pageFinished',
        generationId: 7,
        url: 'https://game.example/retry',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(fixture.port.calls.last, 'visible:true');
    expect(find.byKey(const Key('native-game-surface-error')), findsNothing);
    fixture.toolbarController.collapse();
  });

  testWidgets('exhausted hide retries destroy the native overlay host', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    fixture.port.visibilityFailuresRemaining = 3;

    fixture.port.addEvent(
      _event(
        'mainFrameError',
        generationId: 7,
        errorCode: -2,
        description: 'failed',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      fixture.port.calls.where((call) => call == 'visible:false'),
      hasLength(greaterThanOrEqualTo(3)),
    );
    expect(fixture.port.calls, contains('destroy'));
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);
    fixture.toolbarController.collapse();
  });

  testWidgets('an unexpected event-stream close fails and hides the surface', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    fixture.port.calls.clear();

    await fixture.port.close();
    await tester.pump();

    expect(fixture.statusController.loadState, WebViewLoadState.failed);
    expect(fixture.port.calls, contains('visible:false'));
    expect(tester.takeException(), isNull);
    fixture.toolbarController.collapse();
  });

  testWidgets('does not touch the Android channel without an injected port', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.orchestrator.disposeFailure = StateError('orchestrator failed');

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await fixture.pump(tester, injectPort: false);
      await tester.pump();

      expect(fixture.port.calls, isEmpty);
      expect(find.byType(NativeGameSurfaceSlot), findsOneWidget);
      expect(
        find.byKey(const Key('native-game-surface-error')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    } finally {
      debugPrint = previousDebugPrint;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('rejects incomplete default-orchestrator dependencies at runtime', () {
    expect(
      () => NativeActivityGameSurface(
        statusController: PrototypeStatusController(),
        browserController: GameBrowserController(),
        toolbarController: GameToolbarController(),
        routeObserver: RouteObserver<ModalRoute<dynamic>>(),
      ),
      throwsArgumentError,
    );
  });

  testWidgets('hot update migrates the attached browser controller', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final nextBrowserController = GameBrowserController();
    addTearDown(nextBrowserController.dispose);

    await fixture.pump(tester, browserController: nextBrowserController);
    fixture.port.calls.clear();
    await nextBrowserController.reload();
    expect(fixture.port.calls, contains('reload'));

    fixture.port.calls.clear();
    await fixture.browserController.reload();
    expect(fixture.port.calls, isNot(contains('reload')));
    expect(fixture.browserController.errorMessage, 'WebView 尚未就绪');
  });

  testWidgets('hot update replaces the orchestrator and invalidates old work', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );
    final loadCallsBeforeUpdate = fixture.port.calls
        .where((call) => call.startsWith('load:'))
        .length;
    final oldFinish = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = oldFinish;
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/old'),
    );
    await tester.pump();
    final nextOrchestrator = _FakeStartupOrchestrator();

    await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
    oldFinish.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(fixture.orchestrator.disposeCalls, 1);

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/new'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/new'),
    );
    await tester.pump();
    await tester.pump();
    expect(nextOrchestrator.prepareCaptureCalls, 2);
    expect(nextOrchestrator.applyNetworkCalls, 1);
    expect(
      fixture.port.calls.where((call) => call.startsWith('load:')),
      hasLength(loadCallsBeforeUpdate),
    );
    expect(fixture.statusController.loadState, WebViewLoadState.ready);
    fixture.toolbarController.collapse();
  });

  testWidgets(
    'hot update restarts bootstrap when old network work is pending',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      final oldNetwork = Completer<GameSurfaceNetworkResult>();
      fixture.orchestrator.networkCompleter = oldNetwork;
      await fixture.pump(tester);
      await _pumpUntil(
        tester,
        () => fixture.orchestrator.applyNetworkCalls == 1,
      );
      final nextOrchestrator = _FakeStartupOrchestrator();

      await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
      oldNetwork.complete(const GameSurfaceNetworkResult.success());
      await _pumpUntil(tester, () => nextOrchestrator.applyNetworkCalls == 1);
      await _pumpUntil(
        tester,
        () => fixture.port.calls.any((call) => call.startsWith('load:')),
      );

      expect(nextOrchestrator.prepareCaptureCalls, 1);
      expect(fixture.orchestrator.disposeCalls, 1);
    },
  );

  testWidgets('page finished during bootstrap remains ready after network', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    final network = Completer<GameSurfaceNetworkResult>();
    fixture.orchestrator.networkCompleter = network;
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    network.complete(const GameSurfaceNetworkResult.success());
    for (var index = 0; index < 4; index++) {
      await tester.pump();
    }

    expect(find.byType(CircularProgressIndicator), findsNothing);
    fixture.toolbarController.collapse();
  });

  testWidgets('hot update proceeds after an old network stage times out', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.orchestrator.networkCompleter =
        Completer<GameSurfaceNetworkResult>();
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await _pumpUntil(tester, () => fixture.orchestrator.applyNetworkCalls == 1);
    final nextOrchestrator = _FakeStartupOrchestrator();

    await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
    for (var index = 0; index < 4; index++) {
      await tester.pump(const Duration(milliseconds: 2));
    }

    expect(nextOrchestrator.applyNetworkCalls, 1);
  });

  testWidgets('hot update does not resend an issued load after timeout', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.port.loadCompleter = Completer<void>();
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await _pumpUntil(
      tester,
      () =>
          fixture.port.calls.where((call) => call.startsWith('load:')).length ==
          1,
    );
    final nextOrchestrator = _FakeStartupOrchestrator();

    await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
    for (var index = 0; index < 4; index++) {
      await tester.pump(const Duration(milliseconds: 2));
    }

    expect(
      fixture.port.calls.where((call) => call.startsWith('load:')),
      hasLength(1),
    );
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    expect(
      fixture.port.calls.where((call) => call.startsWith('load:')),
      hasLength(1),
    );
    fixture.toolbarController.collapse();
  });

  testWidgets('hot update retries a failed in-flight initial navigation', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    final oldLoad = Completer<void>();
    fixture.port.loadCompleter = oldLoad;
    fixture.port.loadFailure = StateError('old load failed');
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () =>
          fixture.port.calls.where((call) => call.startsWith('load:')).length ==
          1,
    );
    final nextOrchestrator = _FakeStartupOrchestrator();

    await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://wrong.example/'),
    );
    oldLoad.complete();
    await _pumpUntil(
      tester,
      () =>
          fixture.port.calls.where((call) => call.startsWith('load:')).length ==
          2,
    );

    expect(nextOrchestrator.applyNetworkCalls, 1);
    fixture.toolbarController.collapse();
  });

  testWidgets('pageStarted ack ignores a late load response error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    final response = Completer<void>();
    fixture.port.loadCompleter = response;
    fixture.port.loadFailure = StateError('late response error');
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );

    fixture.port.addEvent(
      _event(
        'pageStarted',
        generationId: 7,
        url: GameLaunchConfig.dmmGameEntry
            .replace(port: 443, fragment: 'ignored')
            .toString(),
      ),
    );
    response.complete();
    await tester.pump();
    await tester.pump();
    final nextOrchestrator = _FakeStartupOrchestrator();
    await fixture.pump(tester, startupOrchestrator: nextOrchestrator);
    await tester.pump();

    expect(
      fixture.port.calls.where((call) => call.startsWith('load:')),
      hasLength(1),
    );
    expect(
      fixture.browserController.loadState,
      isNot(GamePageLoadState.failed),
    );
    fixture.toolbarController.collapse();
  });

  testWidgets('pageStarted before load issue cannot acknowledge navigation', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.port.eventsDuringCreate.add(
      _event(
        'pageStarted',
        generationId: 7,
        url: GameLaunchConfig.dmmGameEntry.toString(),
      ),
    );
    final firstLoad = Completer<void>();
    fixture.port.loadCompleter = firstLoad;
    fixture.port.loadFailure = StateError('initial load failed');
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () =>
          fixture.port.calls.where((call) => call.startsWith('load:')).length ==
          1,
    );

    await fixture.pump(tester, startupOrchestrator: _FakeStartupOrchestrator());
    firstLoad.complete();
    await _pumpUntil(
      tester,
      () =>
          fixture.port.calls.where((call) => call.startsWith('load:')).length ==
          2,
    );

    fixture.toolbarController.collapse();
  });

  testWidgets('hot update replays a pending capture revision', (tester) async {
    final captureModeController = await CaptureModeController.load(
      const _GameCaptureModeStore(),
    );
    addTearDown(captureModeController.dispose);
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester, captureModeController: captureModeController);
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );
    fixture.port.calls.clear();
    final oldCapture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = oldCapture;
    await captureModeController.setMode(CaptureMode.browserOnly);
    await tester.pump();
    final nextOrchestrator = _FakeStartupOrchestrator();

    await fixture.pump(
      tester,
      captureModeController: captureModeController,
      startupOrchestrator: nextOrchestrator,
    );
    await captureModeController.setMode(CaptureMode.game);
    oldCapture.complete();
    await tester.pump();
    await tester.pump();

    expect(nextOrchestrator.prepareCaptureCalls, greaterThanOrEqualTo(2));
    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
  });

  testWidgets(
    'forwards current-generation page events and ignores stale ones',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();

      fixture.port.addEvent(
        _event(
          'pageStarted',
          generationId: 7,
          url: 'https://www.dmm.com/start',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.loading);
      expect(fixture.browserController.loadState, GamePageLoadState.loading);

      fixture.port.addEvent(
        _event('pageFinished', generationId: 6, url: 'https://stale.example/'),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.loading);

      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 7,
          url: 'https://www.dmm.com/ready?token=secret',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.ready);
      expect(fixture.browserController.loadState, GamePageLoadState.ready);
      expect(
        fixture.browserController.displayAddress,
        'https://www.dmm.com/ready',
      );

      fixture.port.addEvent(
        _event(
          'mainFrameError',
          generationId: 7,
          errorCode: -2,
          description: 'network failed',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);

      fixture.port.addEvent(
        _event('navigationBlocked', generationId: 7, scheme: 'intent'),
      );
      await tester.pump();
      expect(fixture.browserController.errorMessage, contains('intent'));

      final finishCalls = fixture.orchestrator.prepareCaptureCalls;
      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 7,
          url: 'https://game.example/late',
        ),
      );
      await tester.pump();
      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);
      expect(fixture.browserController.errorMessage, contains('intent'));
      expect(fixture.orchestrator.prepareCaptureCalls, finishCalls);
      fixture.toolbarController.collapse();
    },
  );

  testWidgets(
    'consecutive errors ignore stale-generation and late page finishes',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();
      final finishCalls = fixture.orchestrator.prepareCaptureCalls;
      final address = fixture.browserController.displayAddress;

      fixture.port.addEvent(
        _event(
          'mainFrameError',
          generationId: 7,
          errorCode: -2,
          description: 'first failure',
        ),
      );
      fixture.port.addEvent(
        _event(
          'mainFrameError',
          generationId: 7,
          errorCode: -3,
          description: 'second failure',
        ),
      );
      fixture.port.addEvent(
        _event(
          'pageStarted',
          generationId: 6,
          url: 'https://stale.example/start',
        ),
      );
      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 6,
          url: 'https://stale.example/finish',
        ),
      );
      fixture.port.addEvent(
        _event(
          'pageFinished',
          generationId: 7,
          url: 'https://game.example/late',
        ),
      );
      await tester.pump();

      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);
      expect(fixture.browserController.errorMessage, 'second failure');
      expect(fixture.browserController.displayAddress, address);
      expect(fixture.orchestrator.prepareCaptureCalls, finishCalls);
      fixture.toolbarController.collapse();
    },
  );

  testWidgets('a new page can recover after a main-frame error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event(
        'mainFrameError',
        generationId: 7,
        errorCode: -2,
        description: 'network failed',
      ),
    );
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/new'),
    );
    await tester.pump();

    expect(fixture.statusController.loadState, WebViewLoadState.loading);
    expect(fixture.browserController.loadState, GamePageLoadState.loading);

    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/new'),
    );
    await tester.pump();
    await tester.pump();

    expect(fixture.statusController.loadState, WebViewLoadState.ready);
    expect(fixture.browserController.loadState, GamePageLoadState.ready);
    expect(find.byKey(const Key('native-game-surface-error')), findsNothing);
    fixture.toolbarController.collapse();
  });

  testWidgets('uses the app route observer to hide and restore the surface', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/'),
    );
    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    await tester.pump();
    fixture.port.calls.clear();

    unawaited(
      fixture.navigatorKey.currentState!.push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const Text('cover'),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, contains('visible:false'));

    fixture.port.calls.clear();
    fixture.navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump();
    expect(fixture.port.calls, contains('visible:true'));
    fixture.toolbarController.collapse();
  });

  testWidgets('renderer recovery reload creates one new generation', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event('renderProcessGone', generationId: 7, didCrash: true),
    );
    await tester.pump();
    fixture.port.addEvent(_event('destroyed', generationId: 7));
    await tester.pump();

    expect(find.byKey(const Key('native-game-surface-reload')), findsOneWidget);
    final createsBefore = fixture.port.calls.where((call) => call == 'create');
    expect(createsBefore, hasLength(1));

    await tester.tap(find.byKey(const Key('native-game-surface-reload')));
    await _pumpUntil(
      tester,
      () => fixture.port.calls.where((call) => call == 'create').length == 2,
    );
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );
    expect(fixture.port.calls.where((call) => call == 'create'), hasLength(2));
  });

  testWidgets(
    'render-process exit reports failure without an automatic recreate',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();

      fixture.port.addEvent(
        _event('renderProcessGone', generationId: 7, didCrash: true),
      );
      await tester.pump();

      expect(fixture.statusController.loadState, WebViewLoadState.failed);
      expect(fixture.browserController.loadState, GamePageLoadState.failed);
      expect(
        fixture.port.calls.where((call) => call == 'create'),
        hasLength(1),
      );
      final networkCalls = fixture.orchestrator.applyNetworkCalls;
      fixture.networkSettingsController.emitChange();
      await tester.pump();
      expect(fixture.orchestrator.applyNetworkCalls, networkCalls);
      expect(fixture.port.calls.where((call) => call == 'reload'), isEmpty);
    },
  );

  testWidgets('every error boundary invalidates a pending startup', (
    tester,
  ) async {
    final boundaries = <({String name, void Function(_FakeNativePort) emit})>[
      (
        name: 'main-frame error',
        emit: (port) => port.addEvent(
          _event(
            'mainFrameError',
            generationId: 7,
            errorCode: -2,
            description: 'network failed',
          ),
        ),
      ),
      (
        name: 'render gone',
        emit: (port) => port.addEvent(
          _event('renderProcessGone', generationId: 7, didCrash: true),
        ),
      ),
      (
        name: 'destroyed',
        emit: (port) => port.addEvent(_event('destroyed', generationId: 7)),
      ),
      (
        name: 'event-channel error',
        emit: (port) => port.addError(StateError('channel failed')),
      ),
    ];

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      for (final boundary in boundaries) {
        final fixture = _SurfaceFixture();
        final network = Completer<GameSurfaceNetworkResult>();
        fixture.orchestrator.networkCompleter = network;
        await fixture.pump(tester);
        await _pumpUntil(
          tester,
          () => fixture.orchestrator.applyNetworkCalls == 1,
        );

        boundary.emit(fixture.port);
        await tester.pump();
        network.complete(const GameSurfaceNetworkResult.success());
        await tester.pump();
        await tester.pump();

        expect(
          fixture.port.calls.where((call) => call.startsWith('load:')),
          isEmpty,
          reason: boundary.name,
        );
        expect(
          fixture.statusController.loadState,
          WebViewLoadState.failed,
          reason: boundary.name,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await fixture.dispose();
      }
    } finally {
      debugPrint = previousDebugPrint;
    }
  });

  testWidgets('a terminal event invalidates a pending page finish', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final audioCalls = fixture.orchestrator.attachAudioCalls;
    final capture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = capture;

    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/'),
    );
    await tester.pump();
    fixture.port.addEvent(
      _event('renderProcessGone', generationId: 7, didCrash: true),
    );
    await tester.pump();
    capture.complete();
    await tester.pump();

    expect(fixture.orchestrator.attachAudioCalls, audioCalls);
    expect(fixture.statusController.loadState, WebViewLoadState.failed);
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);
  });

  testWidgets('a new page invalidates the previous pending page finish', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final audioCalls = fixture.orchestrator.attachAudioCalls;
    final capture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = capture;

    fixture.port.addEvent(
      _event('pageFinished', generationId: 7, url: 'https://game.example/a'),
    );
    await tester.pump();
    fixture.port.addEvent(
      _event('pageStarted', generationId: 7, url: 'https://game.example/b'),
    );
    await tester.pump();
    fixture.toolbarController.collapse();
    capture.complete();
    await tester.pump();

    expect(fixture.orchestrator.attachAudioCalls, audioCalls);
    expect(fixture.statusController.loadState, WebViewLoadState.loading);
  });

  testWidgets('network retry is single-flight and reloads once after success', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.networkSettingsController.settingsValue = const NetworkSettings(
      mode: NetworkMode.httpProxy,
      host: '127.0.0.1',
      port: 8080,
    );
    fixture.orchestrator.networkResult = const GameSurfaceNetworkResult(
      success: false,
      code: 'failed',
      message: 'failed',
    );
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('native-game-surface-error'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.byKey(const Key('native-game-surface-error')), findsOneWidget);

    final retry = Completer<GameSurfaceNetworkResult>();
    fixture.orchestrator.networkCompleter = retry;
    fixture.networkSettingsController.emitChange();
    fixture.networkSettingsController.emitChange();
    await tester.pump();
    expect(fixture.orchestrator.applyNetworkCalls, 2);

    retry.complete(const GameSurfaceNetworkResult.success());
    await tester.pump();
    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
    fixture.networkSettingsController.emitChange();
    await tester.pump();
    expect(fixture.orchestrator.applyNetworkCalls, 2);
  });

  testWidgets('a failed retry reload remains retryable until one success', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.networkSettingsController.settingsValue = const NetworkSettings(
      mode: NetworkMode.httpProxy,
      host: '127.0.0.1',
      port: 8080,
    );
    fixture.orchestrator.networkResult = const GameSurfaceNetworkResult(
      success: false,
      code: 'failed',
      message: 'failed',
    );
    await fixture.pump(tester);
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('native-game-surface-error'))
          .evaluate()
          .isNotEmpty,
    );
    fixture.orchestrator.networkResult =
        const GameSurfaceNetworkResult.success();
    fixture.port.reloadFailure = StateError('reload failed');

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      fixture.networkSettingsController.emitChange();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('native-game-surface-error')),
        findsOneWidget,
      );
      expect(fixture.orchestrator.applyNetworkCalls, 2);

      fixture.port.reloadFailure = null;
      fixture.networkSettingsController.emitChange();
      await tester.pump();
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.orchestrator.applyNetworkCalls, 3);
    expect(fixture.port.successfulReloadCalls, 1);
  });

  for (final failureStage in <String>['capture', 'audio']) {
    testWidgets('$failureStage finish failure retries before reloading', (
      tester,
    ) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _pumpUntil(
        tester,
        () => fixture.port.calls.any((call) => call.startsWith('load:')),
      );
      if (failureStage == 'capture') {
        fixture.orchestrator.prepareCaptureFailure = StateError(
          'capture failed',
        );
      } else {
        fixture.orchestrator.attachAudioFailure = StateError('audio failed');
      }

      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      try {
        fixture.port.addEvent(
          _event('pageStarted', generationId: 7, url: 'https://game.example/'),
        );
        fixture.port.addEvent(
          _event('pageFinished', generationId: 7, url: 'https://game.example/'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
      } finally {
        debugPrint = previousDebugPrint;
      }

      expect(find.byKey(const Key('native-game-surface-error')), findsNothing);
      expect(
        fixture.port.calls.where((call) => call == 'reload'),
        hasLength(1),
      );
      expect(
        fixture.port.calls.lastWhere((call) => call.startsWith('visible:')),
        'visible:false',
      );
      expect(tester.takeException(), isNull);
      fixture.toolbarController.collapse();
    });
  }

  testWidgets('rapid capture changes reload only the final mode', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      const _GameCaptureModeStore(),
    );
    addTearDown(captureModeController.dispose);
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester, captureModeController: captureModeController);
    await _pumpUntil(
      tester,
      () => fixture.port.calls.any((call) => call.startsWith('load:')),
    );
    fixture.port.calls.clear();
    final capture = Completer<void>();
    fixture.orchestrator.prepareCaptureCompleter = capture;

    await captureModeController.setMode(CaptureMode.browserOnly);
    await tester.pump();
    await captureModeController.setMode(CaptureMode.game);
    await tester.pump();
    capture.complete();
    await tester.pump();
    await tester.pump();

    expect(fixture.port.calls.where((call) => call == 'reload'), hasLength(1));
  });

  for (final terminalType in <String>['renderProcessGone', 'destroyed']) {
    testWidgets(
      '$terminalType prevents a pending network retry from reloading',
      (tester) async {
        final fixture = _SurfaceFixture();
        addTearDown(fixture.dispose);
        fixture.networkSettingsController.settingsValue = const NetworkSettings(
          mode: NetworkMode.httpProxy,
          host: '127.0.0.1',
          port: 8080,
        );
        fixture.orchestrator.networkResult = const GameSurfaceNetworkResult(
          success: false,
          code: 'failed',
          message: 'failed',
        );
        await fixture.pump(tester);
        await _pumpUntil(
          tester,
          () => find
              .byKey(const Key('native-game-surface-error'))
              .evaluate()
              .isNotEmpty,
        );

        final retry = Completer<GameSurfaceNetworkResult>();
        fixture.orchestrator.networkCompleter = retry;
        fixture.networkSettingsController.emitChange();
        await tester.pump();
        fixture.port.addEvent(
          terminalType == 'destroyed'
              ? _event('destroyed', generationId: 7)
              : _event('renderProcessGone', generationId: 7, didCrash: true),
        );
        await tester.pump();
        retry.complete(const GameSurfaceNetworkResult.success());
        await tester.pump();

        expect(fixture.port.calls.where((call) => call == 'reload'), isEmpty);
        expect(fixture.statusController.loadState, WebViewLoadState.failed);
      },
    );
  }

  testWidgets('dispose invalidates a pending startup before destruction', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    final network = Completer<GameSurfaceNetworkResult>();
    fixture.orchestrator.networkCompleter = network;
    await fixture.pump(tester);
    await _pumpUntil(tester, () => fixture.orchestrator.applyNetworkCalls == 1);

    await tester.pumpWidget(const SizedBox.shrink());
    network.complete(const GameSurfaceNetworkResult.success());
    await tester.pump();
    await _pumpUntilDestroyed(tester, fixture.port);

    expect(
      fixture.port.calls.where((call) => call.startsWith('load:')),
      isEmpty,
    );
  });

  testWidgets(
    'hide failure cannot block detach-cancel-destroy disposal order',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();
      fixture.port.calls.clear();
      fixture.port.failHide = true;
      fixture.port.beforeCancel = () {
        unawaited(fixture.browserController.reload());
        fixture.port.calls.add(
          fixture.browserController.errorMessage == 'WebView 尚未就绪'
              ? 'detach'
              : 'detach:missing',
        );
      };

      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      try {
        await tester.pumpWidget(const SizedBox());
        await _pumpUntilDestroyed(tester, fixture.port);
      } finally {
        debugPrint = previousDebugPrint;
      }

      final hideIndex = fixture.port.calls.indexOf('visible:false');
      final detachIndex = fixture.port.calls.indexOf('detach');
      final cancelIndex = fixture.port.calls.indexOf('cancel');
      final destroyIndex = fixture.port.calls.indexOf('destroy');
      expect(hideIndex, greaterThanOrEqualTo(0));
      expect(detachIndex, greaterThan(hideIndex));
      expect(cancelIndex, greaterThan(detachIndex));
      expect(destroyIndex, greaterThan(cancelIndex));
    },
  );

  testWidgets('destroy waits for asynchronous event cancellation', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final cancellation = Completer<void>();
    fixture.port.cancelCompleter = cancellation;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(fixture.port.calls, contains('cancel'));
    expect(fixture.port.calls, isNot(contains('destroy')));

    cancellation.complete();
    await _pumpUntilDestroyed(tester, fixture.port);
    expect(
      fixture.port.calls.indexOf('destroy'),
      greaterThan(fixture.port.calls.indexOf('cancel')),
    );
  });

  testWidgets('cancel timeout still destroys and contains a late error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.port.cancelCompleter = Completer<void>();
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await tester.pump();

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      for (var pumpCount = 0; pumpCount < 4; pumpCount++) {
        await tester.pump(const Duration(milliseconds: 2));
      }
      await _pumpUntilDestroyed(tester, fixture.port);
      fixture.port.cancelFailure = StateError('late cancel failure');
      fixture.port.cancelCompleter!.complete();
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('orchestrator timeout still destroys and contains a late error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.orchestrator.disposeCompleter = Completer<void>();
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await tester.pump();

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump(const Duration(milliseconds: 2));
      await _pumpUntilDestroyed(tester, fixture.port);
      fixture.orchestrator.disposeAsyncFailure = StateError(
        'late orchestrator failure',
      );
      fixture.orchestrator.disposeCompleter!.complete();
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('orchestrator cleanup does not delay native destroy', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.orchestrator.disposeCompleter = Completer<void>();
    await fixture.pump(tester, cleanupTimeout: const Duration(seconds: 1));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();

    expect(fixture.port.calls, contains('destroy'));
    expect(fixture.orchestrator.disposeCompleter!.isCompleted, isFalse);
    fixture.orchestrator.disposeCompleter!.complete();
  });

  testWidgets('native dispose timeout is bounded and contains a late error', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    fixture.port.disposeCompleter = Completer<void>();
    await fixture.pump(tester, cleanupTimeout: const Duration(milliseconds: 1));
    await tester.pump();

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump(const Duration(milliseconds: 2));
      expect(
        fixture.port.calls.where((call) => call == 'destroy'),
        hasLength(1),
      );
      fixture.port.disposeFailure = StateError('late destroy failure');
      fixture.port.disposeCompleter!.complete();
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancellation error still allows native destruction', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    final cancellation = Completer<void>();
    fixture.port.cancelCompleter = cancellation;

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(fixture.port.calls, isNot(contains('destroy')));
      fixture.port.cancelFailure = StateError('cancel failed');
      cancellation.complete();
      await _pumpUntilDestroyed(tester, fixture.port);
    } finally {
      debugPrint = previousDebugPrint;
    }
    expect(fixture.port.calls, contains('destroy'));
  });

  testWidgets('cleanup isolates orchestrator and native destroy failures', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.orchestrator.disposeFailure = StateError('orchestrator failed');
    fixture.port.disposeFailure = StateError('destroy failed');

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUntilDestroyed(tester, fixture.port);
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an asynchronous orchestrator dispose failure still destroys', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    fixture.orchestrator.disposeAsyncFailure = StateError(
      'async orchestrator failed',
    );

    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUntilDestroyed(tester, fixture.port);
      await tester.pump();
    } finally {
      debugPrint = previousDebugPrint;
    }

    expect(fixture.port.calls, contains('destroy'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fatal render exit still accepts destroyed and detaches port', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    fixture.port.addEvent(
      _event('renderProcessGone', generationId: 7, didCrash: true),
    );
    fixture.port.addEvent(
      _event(
        'pageStarted',
        generationId: 7,
        url: 'https://game.example/ignored',
      ),
    );
    fixture.port.addEvent(
      _event(
        'pageFinished',
        generationId: 7,
        url: 'https://game.example/ignored',
      ),
    );
    fixture.port.addEvent(
      _event('navigationBlocked', generationId: 7, scheme: 'ignored'),
    );
    await tester.pump();

    expect(fixture.browserController.errorMessage, '游戏渲染进程已退出。');
    expect(fixture.statusController.loadState, WebViewLoadState.failed);

    fixture.port.addEvent(_event('destroyed', generationId: 7));
    await tester.pump();
    fixture.port.calls.clear();
    await fixture.browserController.reload();

    expect(fixture.port.calls, isNot(contains('reload')));
    expect(fixture.browserController.errorMessage, 'WebView 尚未就绪');
    expect(fixture.statusController.loadState, WebViewLoadState.failed);
  });

  testWidgets('disposing an old surface does not detach a newer port', (
    tester,
  ) async {
    final fixture = _SurfaceFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();

    final newerPort = _RecordingBrowserPort();
    fixture.browserController.attachPort(newerPort);
    await tester.pumpWidget(const SizedBox());
    await _pumpUntilDestroyed(tester, fixture.port);

    await fixture.browserController.reload();
    expect(newerPort.reloadCalls, 1);
  });

  testWidgets(
    'a current destroyed event detaches once and stale callbacks stay inert',
    (tester) async {
      final fixture = _SurfaceFixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await tester.pump();

      fixture.port.addEvent(_event('destroyed', generationId: 7));
      await tester.pump();
      final messageAfterDestroy = fixture.browserController.errorMessage;

      fixture.port.addEvent(
        _event('pageFinished', generationId: 7, url: 'https://late.example/'),
      );
      await tester.pump();
      expect(fixture.browserController.errorMessage, messageAfterDestroy);
      expect(
        fixture.browserController.loadState,
        isNot(GamePageLoadState.ready),
      );
    },
  );
}

final class _FakeFrameReloadPort implements GameFrameReloadPort {
  _FakeFrameReloadPort({this.onConfigure});

  final void Function()? onConfigure;
  int reloadCalls = 0;

  @override
  Future<void> configure() async => onConfigure?.call();

  @override
  Future<GameFrameReloadResult> reload() async {
    reloadCalls += 1;
    return GameFrameReloadResult.reloaded;
  }
}

NativeGameWebViewEvent _event(
  String type, {
  required int generationId,
  String? url,
  int? errorCode,
  String? description,
  String? scheme,
  bool? didCrash,
}) {
  return NativeGameWebViewEvent.decode(<String, Object?>{
    'type': type,
    'generationId': generationId,
    'url': ?url,
    'errorCode': ?errorCode,
    'description': ?description,
    'scheme': ?scheme,
    'didCrash': ?didCrash,
  });
}

Future<void> _pumpUntilDestroyed(
  WidgetTester tester,
  _FakeNativePort port,
) async {
  for (
    var pumpCount = 0;
    pumpCount < 20 && !port.destroyed.isCompleted;
    pumpCount++
  ) {
    await tester.pump();
  }
  expect(port.destroyed.isCompleted, isTrue, reason: port.calls.toString());
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var pumpCount = 0; pumpCount < 8 && !condition(); pumpCount++) {
    await tester.pump();
  }
  expect(condition(), isTrue);
}

final class _DefaultOrchestratorFixture {
  _DefaultOrchestratorFixture._({
    required this.orchestrator,
    required this.networkController,
    required this.captureModeController,
    required this.audioController,
    required this.frameRateController,
    required this.captureController,
  });

  final DefaultGameSurfaceStartupOrchestrator orchestrator;
  final _RecordingNetworkController networkController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameFrameRateSettingsController frameRateController;
  final GameCaptureController captureController;

  static Future<_DefaultOrchestratorFixture> create(
    List<String> calls, {
    GameCapturePort Function()? capturePortFactory,
    GameAudioPort Function()? audioPortFactory,
  }) async {
    final networkController = _RecordingNetworkController(calls);
    final captureModeController = await CaptureModeController.load(
      const _GameCaptureModeStore(),
    );
    final audioController = await GameAudioController.load(
      const _GameAudioMemoryStore(),
    );
    final frameRateController = await GameFrameRateSettingsController.load(
      MemoryGameFrameRateSettingsStore(),
    );
    final captureController = GameCaptureController();
    final orchestrator = DefaultGameSurfaceStartupOrchestrator(
      networkSettingsController: networkController,
      captureModeController: captureModeController,
      audioController: audioController,
      gameCaptureController: captureController,
      frameRateSettingsController: frameRateController,
      capturePortFactory:
          capturePortFactory ?? () => _RecordingCapturePort(calls),
      audioPortFactory: audioPortFactory ?? () => _RecordingAudioPort(calls),
      frameRatePortFactory: () => _RecordingFrameRatePort(calls),
    );
    return _DefaultOrchestratorFixture._(
      orchestrator: orchestrator,
      networkController: networkController,
      captureModeController: captureModeController,
      audioController: audioController,
      frameRateController: frameRateController,
      captureController: captureController,
    );
  }

  void dispose() {
    orchestrator.dispose();
    captureController.dispose();
    frameRateController.dispose();
    audioController.dispose();
    captureModeController.dispose();
    networkController.dispose();
  }
}

final class _ScriptRecordingCapturePort implements GameCapturePort {
  final List<String> scripts = <String>[];
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast();

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async => scripts.add(script);

  @override
  void dispose() => unawaited(_events.close());
}

final class _RecordingNetworkController extends NetworkSettingsController {
  _RecordingNetworkController(this.calls)
    : super(store: _MemoryNetworkSettingsStore());

  final List<String> calls;
  final List<ProxyResult> results = <ProxyResult>[];

  @override
  Future<ProxyResult> applySettings(
    NetworkMode mode,
    String host,
    int port,
  ) async {
    calls.add('network');
    if (results.isNotEmpty) return results.removeAt(0);
    return const ProxyResult(
      success: true,
      code: 'ok',
      message: '',
      elapsedMs: 0,
    );
  }
}

final class _RecordingCapturePort implements GameCapturePort {
  _RecordingCapturePort(this.calls);

  final List<String> calls;
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast();

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async {
    calls.add('capture.supported');
    return true;
  }

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async => calls.add('capture.configure:$enabled');

  @override
  void dispose() => unawaited(_events.close());
}

final class _BlockingCapturePort implements GameCapturePort {
  _BlockingCapturePort(this.firstConfigure);

  final Completer<void> firstConfigure;
  final List<bool> enabledCalls = <bool>[];
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast();

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {
    enabledCalls.add(enabled);
    if (enabledCalls.length == 1) await firstConfigure.future;
  }

  @override
  void dispose() => unawaited(_events.close());
}

final class _RecordingAudioPort implements GameAudioPort {
  _RecordingAudioPort(this.calls);

  final List<String> calls;

  @override
  Future<bool> isSupported() async {
    calls.add('audio.supported');
    return true;
  }

  @override
  Future<void> setMuted(bool muted) async => calls.add('audio.muted:$muted');
}

final class _BlockingAudioPort implements GameAudioPort {
  _BlockingAudioPort(this.supported);

  final Future<bool> supported;

  @override
  Future<bool> isSupported() => supported;

  @override
  Future<void> setMuted(bool muted) async {}
}

final class _FakeNativeFrameRateRuntimePort
    implements GameFrameRateRuntimePort {
  final List<GameFrameRateTarget> appliedTargets = <GameFrameRateTarget>[];

  @override
  Future<void> apply(GameFrameRateTarget target) async {
    appliedTargets.add(target);
  }

  @override
  Future<double?> measuredFps() async => 60;
}

final class _RecordingFrameRatePort implements GameFrameRatePort {
  _RecordingFrameRatePort(this.calls);

  final List<String> calls;

  @override
  Future<bool> isSupported() async {
    calls.add('frame.supported');
    return true;
  }

  @override
  Future<void> configure(GameFrameRateMode mode) async =>
      calls.add('frame.configure:${mode.wireName}');
}

final class _GameCaptureModeStore implements CaptureModeStore {
  const _GameCaptureModeStore();

  @override
  Future<CaptureMode?> read() async => CaptureMode.game;

  @override
  Future<void> write(CaptureMode mode) async {}
}

final class _GameAudioMemoryStore implements GameAudioStore {
  const _GameAudioMemoryStore();

  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => false;

  @override
  Future<bool?> readMuted() async => false;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {}

  @override
  Future<void> writeMuted(bool muted) async {}
}

final class _SurfaceFixture {
  _SurfaceFixture()
    : statusController = PrototypeStatusController(),
      browserController = GameBrowserController() {
    toolbarController = GameToolbarController()..collapse();
  }

  final PrototypeStatusController statusController;
  final GameBrowserController browserController;
  late final GameToolbarController toolbarController;
  final networkSettingsController = _TestNetworkSettingsController();
  final port = _FakeNativePort();
  final previewPort = _FakePreviewPort();
  final orchestrator = _FakeStartupOrchestrator();
  final observer = YahagiGameRouteObserver();
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pump(
    WidgetTester tester, {
    bool injectPort = true,
    Duration? cleanupTimeout,
    Duration? pageInitializationTimeout,
    CaptureModeController? captureModeController,
    GameBrowserController? browserController,
    GameSurfaceStartupOrchestrator? startupOrchestrator,
    GameFrameRateSettingsController? frameRateSettingsController,
    GameFrameRateRuntimePort Function()? frameRateRuntimePortFactory,
  }) {
    if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    return tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: <NavigatorObserver>[observer],
        home: SizedBox(
          width: 800,
          height: 480,
          child: NativeActivityGameSurface(
            statusController: statusController,
            browserController: browserController ?? this.browserController,
            toolbarController: toolbarController,
            routeObserver: observer,
            networkSettingsController: networkSettingsController,
            captureModeController: captureModeController,
            portFactory: injectPort ? () => port : null,
            startupOrchestrator: startupOrchestrator ?? orchestrator,
            frameRateSettingsController: frameRateSettingsController,
            frameRateRuntimePortFactory: frameRateRuntimePortFactory,
            previewPort: previewPort,
            previewDecoder: (bytes, _) async => MemoryImage(bytes),
            cleanupTimeout: cleanupTimeout,
            pageInitializationTimeout: pageInitializationTimeout,
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    statusController.dispose();
    browserController.dispose();
    toolbarController.dispose();
    networkSettingsController.dispose();
  }
}

final class _FakePreviewPort implements NativeGameSurfacePreviewPort {
  int calls = 0;

  @override
  Future<Uint8List> capturePreview() async {
    calls += 1;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
      'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
  }
}

final class _FakeNativePort implements NativeActivityGameWebViewPort {
  _FakeNativePort() {
    _events = StreamController<NativeGameWebViewEvent>(
      sync: true,
      onListen: () => calls.add('listen'),
      onCancel: () async {
        beforeCancel?.call();
        calls.add('cancel');
        await cancelCompleter?.future;
        if (cancelFailure case final failure?) throw failure;
      },
    );
  }

  late final StreamController<NativeGameWebViewEvent> _events;
  final List<String> calls = <String>[];
  final List<String> executedScripts = <String>[];
  final Completer<void> destroyed = Completer<void>();
  VoidCallback? beforeCancel;
  Completer<void>? cancelCompleter;
  Object? createFailure;
  Object? cancelFailure;
  Object? disposeFailure;
  Completer<void>? disposeCompleter;
  Object? reloadFailure;
  Completer<void>? loadCompleter;
  Object? loadFailure;
  int successfulReloadCalls = 0;
  final List<Completer<void>> fitCompleters = <Completer<void>>[];
  final List<Object> fitFailures = <Object>[];
  final List<Completer<void>> visibilityCompleters = <Completer<void>>[];
  int visibilityFailuresRemaining = 0;
  bool failHide = false;
  final List<NativeGameWebViewEvent> eventsDuringCreate =
      <NativeGameWebViewEvent>[];

  @override
  Stream<NativeGameWebViewEvent> get events => _events.stream;

  void addEvent(NativeGameWebViewEvent event) => _events.add(event);

  void addError(Object error) => _events.addError(error, StackTrace.current);

  @override
  Future<int> create() async {
    calls.add('create');
    if (createFailure case final failure?) throw failure;
    for (final event in eventsDuringCreate) {
      _events.add(event);
    }
    return 7;
  }

  @override
  Future<void> setBounds(NativeGameWebViewBounds bounds) async {
    calls.add('bounds');
  }

  @override
  Future<void> setVisible(bool visible) async {
    calls.add('visible:$visible');
    if (visibilityCompleters.isNotEmpty) {
      await visibilityCompleters.removeAt(0).future;
    }
    if (visibilityFailuresRemaining > 0) {
      visibilityFailuresRemaining -= 1;
      throw StateError('visibility failed');
    }
    if (!visible && failHide) throw StateError('hide failed');
  }

  @override
  Future<void> dispose() async {
    calls.add('destroy');
    if (!destroyed.isCompleted) destroyed.complete();
    await disposeCompleter?.future;
    if (disposeFailure case final failure?) throw failure;
  }

  Future<void> close() async {
    if (!_events.isClosed) unawaited(_events.close());
  }

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> fitGameScreen() async {
    calls.add('fit');
    if (fitCompleters.isNotEmpty) {
      await fitCompleters.removeAt(0).future;
    }
    if (fitFailures.isNotEmpty) {
      throw fitFailures.removeAt(0);
    }
  }

  @override
  Future<void> goBack() async {}

  @override
  Future<void> loadUri(Uri uri) async {
    calls.add('load:${uri.host}');
    final blocker = loadCompleter;
    loadCompleter = null;
    await blocker?.future;
    final failure = loadFailure;
    loadFailure = null;
    if (failure != null) throw failure;
  }

  @override
  Future<void> reload() async {
    calls.add('reload');
    if (reloadFailure case final failure?) throw failure;
    successfulReloadCalls += 1;
  }

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async {
    calls.add('reloadGameFrame');
    return GameFrameReloadResult.reloaded;
  }

  @override
  Future<void> runJavaScript(String javascript) async {
    executedScripts.add(javascript);
  }

  @override
  Future<void> showLocalHome() async {}
}

final class _FakeStartupOrchestrator implements GameSurfaceStartupOrchestrator {
  int applyNetworkCalls = 0;
  int prepareCaptureCalls = 0;
  int attachAudioCalls = 0;
  GameSurfaceNetworkResult networkResult =
      const GameSurfaceNetworkResult.success();
  Completer<GameSurfaceNetworkResult>? networkCompleter;
  Completer<void>? prepareCaptureCompleter;
  Completer<void>? disposeCompleter;
  Object? disposeFailure;
  Object? disposeAsyncFailure;
  Object? prepareCaptureFailure;
  Object? attachAudioFailure;
  int disposeCalls = 0;

  @override
  Future<bool> attachFrameRatePlatformPort() async => true;

  @override
  Future<void> attachAudioPortOnce() async {
    attachAudioCalls += 1;
    if (attachAudioFailure case final failure?) throw failure;
  }

  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async {
    applyNetworkCalls++;
    return networkCompleter?.future ?? networkResult;
  }

  @override
  FutureOr<void> dispose() {
    disposeCalls += 1;
    if (disposeFailure case final failure?) throw failure;
    if (disposeCompleter case final completer?) {
      return completer.future.then((_) {
        if (disposeAsyncFailure case final failure?) throw failure;
      });
    }
    if (disposeAsyncFailure case final failure?) {
      return Future<void>.microtask(() => throw failure);
    }
  }

  @override
  Future<void> prepareCapture() async {
    prepareCaptureCalls += 1;
    await prepareCaptureCompleter?.future;
    if (prepareCaptureFailure case final failure?) throw failure;
  }

  @override
  Future<void> runCaptureStartup({
    required Future<void> Function() waitForSurface,
    required bool Function() isActive,
    required Future<void> Function() navigate,
  }) async {
    await waitForSurface();
    if (isActive()) await prepareCapture();
    if (isActive()) await navigate();
  }
}

final class _TestNetworkSettingsController extends NetworkSettingsController {
  _TestNetworkSettingsController()
    : super(store: _MemoryNetworkSettingsStore());

  NetworkSettings settingsValue = const NetworkSettings();

  @override
  NetworkSettings get settings => settingsValue;

  void emitChange() => notifyListeners();
}

final class _MemoryNetworkSettingsStore implements NetworkSettingsStore {
  @override
  Future<NetworkSettings> loadSettings() async => const NetworkSettings();

  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}

final class _RecordingBrowserPort implements GameBrowserPort {
  int reloadCalls = 0;

  @override
  Future<void> reload() async => reloadCalls += 1;

  @override
  Future<GameFrameReloadResult> reloadGameFrame() async =>
      GameFrameReloadResult.reloaded;

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> fitGameScreen() async {}

  @override
  Future<void> goBack() async {}

  @override
  Future<void> loadUri(Uri uri) async {}

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> showLocalHome() async {}
}
