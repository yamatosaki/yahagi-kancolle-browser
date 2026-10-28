import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_environment_host.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_reload_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/capture/sortie_warning_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

// This matrix mounts the production mode selector, environment host and warning.
// The platform-view branch mounts the real GameWebView and records its Android
// composition parameters and user agent. OS WebViews are replaced at the plugin
// boundary; GPU/Chromium rendering is covered by the separate device smoke run.
void main() {
  for (final mode in GameRenderingMode.values) {
    for (final path in [
      '/kcsapi/api_req_map/next',
      '/kcsapi/api_req_sortie/battleresult',
    ]) {
      for (final button in [
        'acknowledgeAdvanceWarning',
        'muteCurrentSortieWarning',
        'advanceWarningReloadGame',
        'advanceWarningReloadFrame',
      ]) {
        testWidgets('${mode.name} $path $button smoke', (tester) async {
          SharedPreferences.setMockInitialValues({});
          final platform = _Platform();
          WebViewPlatform.instance = platform;
          var frameReloads = 0;
          final messenger = tester.binding.defaultBinaryMessenger;
          const frameChannel = MethodChannel(gameFrameReloadMethodChannelName);
          const scalingChannel = MethodChannel(
            'app.webview/fixed_canvas_scaling',
          );
          messenger
            ..setMockMethodCallHandler(frameChannel, (call) async {
              if (call.method == 'reload') {
                frameReloads++;
                return 'reloaded';
              }
              return null;
            })
            ..setMockMethodCallHandler(scalingChannel, (_) async => null);
          final fixture = await _Fixture.create(mode);
          await fixture.capture.attach(fixture.capturePort, enabled: true);
          final observer = YahagiGameRouteObserver();
          final visibility = <bool>[];
          var previewVisible = false;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            fixture.dispose();
            messenger
              ..setMockMethodCallHandler(frameChannel, null)
              ..setMockMethodCallHandler(scalingChannel, null);
          });
          await tester.pumpWidget(
            MaterialApp(
              navigatorObservers: [observer],
              home: GameEnvironmentHost(
                controller: fixture.rendering,
                gameBuilder: (_, selectedMode, key) =>
                    buildGameSurfaceForRenderingMode(
                      mode: selectedMode,
                      key: key,
                      buildNativeActivityGameSurface: (surfaceKey) {
                        fixture.browser.attachPort(fixture.nativePort);
                        return NativeGameSurfaceSlot(
                          key: surfaceKey,
                          routeObserver: observer,
                          onBoundsChanged: (_) async {},
                          onVisibilityChanged: (visible) async =>
                              visibility.add(visible),
                          onBeforePopupRouteHidden: () async =>
                              previewVisible = true,
                          onAfterPopupRouteRevealed: () =>
                              previewVisible = false,
                        );
                      },
                      buildGameWebView: (surfaceKey, selectedMode) =>
                          GameWebView(
                            key: surfaceKey,
                            networkSettingsController: fixture.network,
                            safetySettingsController: fixture.safety,
                            controller: fixture.status,
                            browserController: fixture.browser,
                            captureModeController: fixture.captureMode,
                            audioController: fixture.audio,
                            toolbarController: fixture.toolbar,
                            gameCaptureController: fixture.capture,
                            renderingMode: selectedMode,
                            startupOrchestratorFactory: () => _Startup(),
                            // This fixture replaces OS WebViews at the plugin
                            // boundary; native frame-rate setup is tested there.
                            frameRatePortFactory: () =>
                                const UnsupportedGameFrameRatePort(),
                          ),
                      withBattleWarning: (child) => BattleResultWarningOverlay(
                        accountSession: fixture.account,
                        gameCaptureController: fixture.capture,
                        loadSafetyState: () async => _sortie,
                        safetySettingsController: fixture.safety,
                        warningSession: fixture.session,
                        damageAlertPort: const _Alerts(),
                        onReloadGame: fixture.browser.reload,
                        onReloadGameFrame: () async {
                          final result = await fixture.browser
                              .reloadGameFrame();
                          if (result != GameFrameReloadResult.reloaded) {
                            throw StateError('frame reload unavailable');
                          }
                        },
                        child: child,
                      ),
                    ),
              ),
            ),
          );
          await _drain(tester);
          final surfaceKey = ValueKey('game-webview-${mode.storageName}-0');
          final originalSurface = tester.element(find.byKey(surfaceKey));
          if (mode.usesActivityWebView) {
            expect(find.byType(GameWebView), findsNothing);
            expect(find.byType(NativeGameSurfaceSlot), findsOneWidget);
            expect(visibility, [true]);
          } else {
            expect(find.byType(GameWebView), findsOneWidget);
            expect(platform.controller.loads, hasLength(1));
            final params =
                platform.widgetParams as AndroidWebViewWidgetCreationParams;
            expect(
              params.displayWithHybridComposition,
              mode.usesHybridComposition,
            );
            expect(platform.cookies.acceptsThirdPartyCookies, isTrue);
            final userAgent = platform.controller.userAgent!;
            if (mode.usesCanvasRenderer) {
              expect(userAgent, contains('Safari/'));
              expect(userAgent, isNot(contains('Chrome/')));
            } else {
              expect(userAgent, contains('Chrome/140.0.7339.0'));
            }
            platform.delegate.started('https://game.example/');
            platform.delegate.finished('https://game.example/');
            await _drain(tester);
            expect(find.byType(CircularProgressIndicator), findsNothing);
          }

          final baselineBarriers = find.byType(ModalBarrier).evaluate().length;
          fixture.capturePort.add(kcsapiEvent(path, const {}));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          if (mode.usesActivityWebView) {
            expect(visibility, [true, false]);
            expect(previewVisible, isFalse);
          }
          await tester.tap(find.byKey(Key(button)));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(ModalBarrier), findsNWidgets(baselineBarriers));
          expect(tester.element(find.byKey(surfaceKey)), same(originalSurface));
          expect(fixture.session.isMuted, button == 'muteCurrentSortieWarning');
          if (mode.usesActivityWebView) {
            expect(visibility, [true, false, true]);
            expect(previewVisible, isFalse);
            expect(
              fixture.nativePort.reloads,
              button == 'advanceWarningReloadGame' ? 1 : 0,
            );
            expect(
              fixture.nativePort.frameReloads,
              button == 'advanceWarningReloadFrame' ? 1 : 0,
            );
          } else {
            expect(
              platform.controller.reloads,
              button == 'advanceWarningReloadGame' ? 1 : 0,
            );
            expect(frameReloads, button == 'advanceWarningReloadFrame' ? 1 : 0);
            if (button == 'advanceWarningReloadGame') {
              platform.delegate.started('https://game.example/');
              platform.delegate.finished('https://game.example/');
              await _drain(tester);
            }
            expect(find.byType(CircularProgressIndicator), findsNothing);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump();
  }
}

const _sortie = GameState(
  memberId: 1001,
  hasEquipmentInventory: true,
  ships: {
    101: OwnedShip(id: 101, masterId: 1, level: 99, currentHp: 20, maxHp: 20),
    102: OwnedShip(id: 102, masterId: 2, level: 99, currentHp: 2, maxHp: 20),
  },
  fleets: [
    Fleet(id: 1, name: '第一舰队', shipIds: [101, 102]),
  ],
  combatState: CombatState(sortieFleetId: 1, isActive: true),
);

class _Platform extends WebViewPlatform {
  late _Controller controller;
  late _Delegate delegate;
  late PlatformWebViewWidgetCreationParams widgetParams;
  final cookies = _Cookies(const PlatformWebViewCookieManagerCreationParams());
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _Controller(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _Delegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    widgetParams = params;
    return _View(params);
  }

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => cookies;
}

class _Controller extends PlatformWebViewController
    implements AndroidWebViewController {
  _Controller(super.params) : super.implementation();
  final loads = <Uri>[];
  int reloads = 0;
  String? userAgent;
  @override
  int get webViewIdentifier => 17;
  @override
  Future<void> setUseWideViewPort(bool value) async {}
  @override
  Future<String?> getUserAgent() async =>
      'Mozilla/5.0 (Linux; Android 16; wv) AppleWebKit/537.36 Version/4.0 Chrome/140.0.7339.0 Mobile Safari/537.36';
  @override
  Future<void> setUserAgent(String? value) async => userAgent = value;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      loads.add(params.uri);
  @override
  Future<void> reload() async => reloads++;
  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}
  @override
  Future<void> runJavaScript(String script) async {}
  @override
  Future<Object> runJavaScriptReturningResult(String script) async => 'web';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cookies extends PlatformWebViewCookieManager
    implements AndroidWebViewCookieManager {
  _Cookies(super.params) : super.implementation();
  bool acceptsThirdPartyCookies = false;
  @override
  Future<void> setAcceptThirdPartyCookies(
    AndroidWebViewController controller,
    bool accept,
  ) async => acceptsThirdPartyCookies = accept;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  late PageEventCallback started;
  late PageEventCallback finished;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async =>
      started = callback;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      finished = callback;
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {}
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _Fixture {
  _Fixture(this.safety, this.captureMode, this.audio, this.rendering);
  final SafetySettingsController safety;
  final CaptureModeController captureMode;
  final GameAudioController audio;
  final GameRenderingModeController rendering;
  final network = NetworkSettingsController(store: _NetworkStore());
  final status = PrototypeStatusController();
  final browser = GameBrowserController(
    homeUri: Uri.parse('https://game.example/'),
  );
  final toolbar = GameToolbarController();
  final capture = GameCaptureController();
  final capturePort = _CapturePort();
  final account = AccountSession(initialMemberId: 1001);
  final session = SortieWarningSession();
  final nativePort = _NativeBrowserPort();
  static Future<_Fixture> create(GameRenderingMode mode) async {
    final fixture = _Fixture(
      await SafetySettingsController.load(MemorySafetySettingsStore()),
      await CaptureModeController.load(SharedPreferencesCaptureModeStore()),
      await GameAudioController.load(SharedPreferencesGameAudioStore()),
      await GameRenderingModeController.load(
        MemoryGameRenderingModeStore(mode),
      ),
    );
    await fixture.safety.setBattleWarningMode(BattleWarningMode.confirm);
    await fixture.safety.setAdvanceWarningTimings(
      AdvanceWarningTimingSettings.battleAndAdvance,
    );
    return fixture;
  }

  void dispose() {
    network.dispose();
    safety.dispose();
    captureMode.dispose();
    audio.dispose();
    rendering.dispose();
    status.dispose();
    browser.dispose();
    toolbar.dispose();
    capture.dispose();
    capturePort.dispose();
    account.dispose();
    session.dispose();
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

class _CapturePort implements GameCapturePort {
  final _events = StreamController<CapturedApiEvent>.broadcast(sync: true);
  @override
  Stream<CapturedApiEvent> get events => _events.stream;
  void add(CapturedApiEvent event) => _events.add(event);
  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}
  @override
  Future<bool> isSupported() async => true;
  @override
  void dispose() => unawaited(_events.close());
}

class _Alerts implements BattleDamageAlertPort {
  const _Alerts();
  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {}
}

class _NativeBrowserPort implements GameBrowserPort {
  int reloads = 0;
  int frameReloads = 0;
  @override
  Future<void> reload() async => reloads++;
  @override
  Future<GameFrameReloadResult> reloadGameFrame() async {
    frameReloads++;
    return GameFrameReloadResult.reloaded;
  }

  @override
  Future<void> loadUri(Uri uri) async {}
  @override
  Future<void> showLocalHome() async {}
  @override
  Future<bool> canGoBack() async => false;
  @override
  Future<void> goBack() async {}
  @override
  Future<void> runJavaScript(String javascript) async {}
  @override
  Future<void> fitGameScreen() async {}
  @override
  Future<void> clearCache() async {}
  @override
  Future<void> clearSession() async {}
}
