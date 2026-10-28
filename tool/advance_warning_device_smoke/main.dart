// Offline, isolated-APK device probe. Never uses a game account or remote URL.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_reload_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_load_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_surface_slot.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/capture/sortie_warning_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_webview.dart';
import 'package:yahagi_kancolle_browser/src/native_activity_game_surface.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

const smokePort = 18765;
const smokeRevision = 'warning-input-fix-20261025-v1';
YahagiGameRouteObserver? _smokeRouteObserverOverride;
int _smokeRouteObserverEpoch = 0;
final Map<String, int> _smokeDocumentTouches = {};
const actionKeys = [
  'muteCurrentSortieWarning',
  'acknowledgeAdvanceWarning',
  'advanceWarningReloadGame',
  'advanceWarningReloadFrame',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final mode = GameRenderingModeCodec.decode(
    preferences.getString('game.renderingMode'),
  );
  final safety = await SafetySettingsController.load(
    MemorySafetySettingsStore(),
  );
  await safety.setAdvanceWarningTimings(
    AdvanceWarningTimingSettings.battleAndAdvance,
  );
  final captureMode = await CaptureModeController.load(_CaptureModeStore());
  final audio = await GameAudioController.load(
    SharedPreferencesGameAudioStore(),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, smokePort);
  runApp(
    _SmokeApp(
      mode: mode,
      server: server,
      preferences: preferences,
      safety: safety,
      captureMode: captureMode,
      audio: audio,
    ),
  );
}

class _SmokeApp extends StatefulWidget {
  const _SmokeApp({
    required this.mode,
    required this.server,
    required this.preferences,
    required this.safety,
    required this.captureMode,
    required this.audio,
  });

  final GameRenderingMode mode;
  final HttpServer server;
  final SharedPreferences preferences;
  final SafetySettingsController safety;
  final CaptureModeController captureMode;
  final GameAudioController audio;

  @override
  State<_SmokeApp> createState() => _SmokeAppState();
}

class _SmokeAppState extends State<_SmokeApp> {
  final browser = GameBrowserController(
    homeUri: Uri.parse('http://127.0.0.1:$smokePort/fixture'),
  );
  final account = AccountSession(initialMemberId: 1001);
  final capture = GameCaptureController();
  final capturePort = _FixtureCapturePort();
  final warning = SortieWarningSession();
  final status = PrototypeStatusController();
  final toolbar = GameToolbarController()..collapse();
  final network = NetworkSettingsController(store: _NetworkStore());
  final observer = YahagiGameRouteObserver();
  final navigatorKey = GlobalKey<NavigatorState>();
  final surfaceKey = GlobalKey();
  late final _SmokeStartup startup;
  int sequence = 0;
  int outerLoads = 0;
  int innerLoads = 0;
  int fullReloadCalls = 0;
  int frameReloadCalls = 0;
  String? frameReloadResult;
  Map<String, String> telemetry = {};
  final errors = <String>[];
  final loads = <String>[];

  @override
  void initState() {
    super.initState();
    warning.startSortie();
    startup = _SmokeStartup(capture, capturePort);
    widget.server.listen((request) {
      unawaited(
        _serve(request).catchError((Object error, StackTrace stack) {
          errors.add(error.toString());
          request.response.statusCode = 500;
          request.response.write(error.toString());
          return request.response.close();
        }),
      );
    });
  }

  void _warn(String? path) {
    capturePort.eventsController.add(
      CapturedApiEvent(
        path: path == 'result'
            ? '/kcsapi/api_req_sortie/battleresult'
            : '/kcsapi/api_req_map/next',
        responseBody: '{"api_result":1,"api_data":{}}',
        source: CaptureSource.xhr,
        sourceOrigin: 'https://synthetic.kancolle-server.com',
        capturedAt: DateTime.now(),
        sequence: ++sequence,
      ),
    );
  }

  Future<void> _serve(HttpRequest request) async {
    final path = request.uri.path;
    request.response.headers.set('Cache-Control', 'no-store');
    if (path == '/fixture') {
      outerLoads++;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_outerHtml);
    } else if (path == '/game') {
      innerLoads++;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_innerHtml);
    } else if (path == '/telemetry') {
      final documentId = request.uri.queryParameters['documentId'];
      final clicks = int.tryParse(request.uri.queryParameters['clicks'] ?? '0');
      if (documentId != null && documentId.isNotEmpty && clicks != null) {
        final previousClicks = _smokeDocumentTouches[documentId] ?? 0;
        if (clicks > previousClicks) {
          _smokeDocumentTouches[documentId] = clicks;
        }
      }
      final surfaceUnmounted = telemetry['_smokeSurfaceUnmounted'];
      telemetry = Map.of(request.uri.queryParameters);
      if (surfaceUnmounted == '1') {
        telemetry['_smokeSurfaceUnmounted'] = '1';
      }
      request.response.write('ok');
    } else {
      request.response.headers.contentType = ContentType.json;
      switch (path) {
        case '/status':
          request.response.write(jsonEncode(_snapshot()));
        case '/initializeFixtureBridge':
          // Hot-loading the isolated fixture tears down and remounts a native
          // PlatformView. Initialize the real native bridge only after the host
          // has observed the replacement page, then load a fresh document so
          // document-start injection is present before button assertions begin.
          await MethodChannelGameFrameReloadPort().configure();
          await browser.reload();
          request.response.write(jsonEncode({'initialized': true}));
        case '/unmountSurface':
          warning.endSortie();
          setState(() => telemetry['_smokeSurfaceUnmounted'] = '1');
          await WidgetsBinding.instance.endOfFrame;
          request.response.write(
            jsonEncode({'surfaceMounted': false, 'revision': smokeRevision}),
          );
        case '/remountSurface':
          _smokeRouteObserverOverride = YahagiGameRouteObserver();
          _smokeRouteObserverEpoch++;
          setState(() => telemetry.remove('_smokeSurfaceUnmounted'));
          warning.startSortie();
          await WidgetsBinding.instance.endOfFrame;
          request.response.write(
            jsonEncode({'surfaceMounted': true, 'revision': smokeRevision}),
          );
        case '/warn':
          _warn(request.uri.queryParameters['stage']);
          request.response.write(
            jsonEncode({'requested': true, 'sequence': sequence}),
          );
        case '/nextSortie':
          warning.startSortie();
          request.response.write(
            jsonEncode({'generation': warning.generation}),
          );
        case '/mode':
          final name = request.uri.queryParameters['name'];
          if (!GameRenderingMode.values.any((mode) => mode.name == name)) {
            request.response.statusCode = 400;
            request.response.write(
              jsonEncode({'error': 'unknown rendering mode'}),
            );
          } else {
            await widget.preferences.setString('game.renderingMode', name!);
            request.response.write(
              jsonEncode({'savedMode': name, 'restartRequired': true}),
            );
          }
        default:
          request.response.statusCode = 404;
          request.response.write(jsonEncode({'error': 'unknown path'}));
      }
    }
    await request.response.close();
  }

  Map<String, Object?> _snapshot() {
    final buttons = <String, Object?>{};
    var dialogs = 0;
    var previews = 0;
    var inputGuards = 0;
    final inputGuardTypes = <String>{};
    void visit(Element element) {
      final candidate = element.widget;
      final typeName = candidate.runtimeType.toString();
      if (typeName.toLowerCase().contains('inputguard') ||
          typeName.toLowerCase().contains('inputshield') ||
          candidate.key == const Key('game-input-guard') ||
          candidate.key == const Key('game-safety-input-guard')) {
        inputGuards++;
        inputGuardTypes.add(typeName);
      }
      if (candidate is AlertDialog) dialogs++;
      if (candidate.key == const Key('native-game-surface-popup-preview')) {
        previews++;
      }
      for (final key in actionKeys) {
        if (candidate.key == Key(key)) {
          final box = element.findRenderObject();
          if (box is RenderBox && box.hasSize && box.attached) {
            final center = box.localToGlobal(box.size.center(Offset.zero));
            final ratio = View.of(context).devicePixelRatio;
            buttons[key] = {
              'x': (center.dx * ratio).round(),
              'y': (center.dy * ratio).round(),
              'width': (box.size.width * ratio).round(),
              'height': (box.size.height * ratio).round(),
              'enabled':
                  candidate is ButtonStyleButton && candidate.onPressed != null,
            };
          }
        }
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    final box = surfaceKey.currentContext?.findRenderObject();
    Map<String, int>? surface;
    if (box is RenderBox && box.hasSize) {
      final center = box.localToGlobal(box.size.center(Offset.zero));
      final ratio = View.of(context).devicePixelRatio;
      surface = {
        'x': (center.dx * ratio).round(),
        'y': (center.dy * ratio).round(),
      };
    }
    return {
      'revision': smokeRevision,
      'surfaceMounted': telemetry['_smokeSurfaceUnmounted'] != '1',
      'inputGuardCount': inputGuards,
      'inputGuardTypes': inputGuardTypes.toList(),
      'freshObserverOverride': _smokeRouteObserverOverride != null,
      'observerEpoch': _smokeRouteObserverEpoch,
      'canvasTotalTouches': _smokeDocumentTouches.values.fold<int>(
        0,
        (sum, clicks) => sum + clicks,
      ),
      'canvasDocumentTouches': Map<String, int>.of(_smokeDocumentTouches),
      'mode': widget.mode.name,
      'savedMode': widget.preferences.getString('game.renderingMode'),
      'captureState': capture.state.name,
      'browserAttached': browser.hasAttachedPort,
      'loadState': status.loadState.name,
      'pageError': status.errorMessage,
      'dialogCount': dialogs,
      'previewCount': previews,
      'muted': warning.isMuted,
      'generation': warning.generation,
      'sequence': sequence,
      'outerLoads': outerLoads,
      'innerLoads': innerLoads,
      'telemetry': telemetry,
      'fullReloadCalls': fullReloadCalls,
      'frameReloadCalls': frameReloadCalls,
      'frameReloadResult': frameReloadResult,
      'buttons': buttons,
      'surfaceCenter': surface,
      'loads': loads,
      'errors': errors,
    };
  }

  void _loaded(GameLoadEvent event) {
    loads.add(event.phase.name);
    if (loads.length > 50) loads.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final activeObserver = _smokeRouteObserverOverride ?? observer;
    final surface = widget.mode.usesActivityWebView
        ? NativeActivityGameSurface(
            statusController: status,
            browserController: browser,
            toolbarController: toolbar,
            routeObserver: activeObserver,
            startupOrchestrator: startup,
            onLoadEvent: _loaded,
          )
        : GameWebView(
            networkSettingsController: network,
            safetySettingsController: widget.safety,
            controller: status,
            browserController: browser,
            captureModeController: widget.captureMode,
            audioController: widget.audio,
            toolbarController: toolbar,
            gameCaptureController: capture,
            renderingMode: widget.mode,
            startupOrchestratorFactory: () => startup,
            onLoadEvent: _loaded,
          );
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [activeObserver],
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Center(
                  child: Text('OFFLINE WARNING SMOKE — ${widget.mode.name}'),
                ),
              ),
              Expanded(
                child: SizedBox.expand(
                  key: surfaceKey,
                  child: telemetry['_smokeSurfaceUnmounted'] == '1'
                      ? const SizedBox.shrink()
                      : BattleResultWarningOverlay(
                          accountSession: account,
                          warningSession: warning,
                          gameCaptureController: capture,
                          loadSafetyState: () async => _heavyState,
                          safetySettingsController: widget.safety,
                          damageAlertPort: const _NoopAlerts(),
                          onReloadGame: () async {
                            fullReloadCalls++;
                            try {
                              await browser.reload();
                            } catch (error) {
                              errors.add('full reload: $error');
                              rethrow;
                            }
                          },
                          onReloadGameFrame: () async {
                            frameReloadCalls++;
                            final result = await browser.reloadGameFrame();
                            frameReloadResult = result.name;
                            if (result != GameFrameReloadResult.reloaded) {
                              throw StateError(
                                'Frame reload returned ${result.name}',
                              );
                            }
                          },
                          child: surface,
                        ),
                ),
              ),
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _warn(null),
                      child: const Text('Warn'),
                    ),
                    TextButton(
                      onPressed: warning.startSortie,
                      child: const Text('Next sortie'),
                    ),
                    const Text('HTTP 127.0.0.1:18765'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _heavyState = GameState(
  memberId: 1001,
  hasEquipmentInventory: true,
  ships: {
    101: OwnedShip(id: 101, masterId: 1, level: 99, currentHp: 20, maxHp: 20),
    102: OwnedShip(id: 102, masterId: 2, level: 99, currentHp: 2, maxHp: 20),
  },
  fleets: [
    Fleet(id: 1, name: 'synthetic', shipIds: [101, 102]),
  ],
  combatState: CombatState(sortieFleetId: 1, isActive: true),
);

class _FixtureCapturePort implements GameCapturePort {
  final eventsController = StreamController<CapturedApiEvent>.broadcast(
    sync: true,
  );
  @override
  Stream<CapturedApiEvent> get events => eventsController.stream;
  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}
  @override
  Future<bool> isSupported() async => true;
  @override
  void dispose() => unawaited(eventsController.close());
}

class _SmokeStartup implements GameSurfaceStartupOrchestrator {
  _SmokeStartup(this.capture, this.port);
  final GameCaptureController capture;
  final _FixtureCapturePort port;
  bool attached = false;
  @override
  Future<GameSurfaceNetworkResult> applyNetworkSettings() async =>
      const GameSurfaceNetworkResult.success();
  @override
  Future<void> prepareCapture() async {
    if (!attached) {
      await capture.attach(port, enabled: true);
      attached = true;
    }
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

  @override
  Future<void> attachAudioPortOnce() async {}
  @override
  Future<bool> attachFrameRatePlatformPort() async => false;
  @override
  void dispose() {}
}

class _NoopAlerts implements BattleDamageAlertPort {
  const _NoopAlerts();
  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {}
}

class _CaptureModeStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => CaptureMode.game;
  @override
  Future<void> write(CaptureMode mode) async {}
}

class _NetworkStore implements NetworkSettingsStore {
  @override
  Future<NetworkSettings> loadSettings() async => const NetworkSettings();
  @override
  Future<void> saveSettings(NetworkSettings settings) async {}
}

const _outerHtml =
    '''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#102431}iframe{border:0;width:100%;height:100%}</style>
<iframe id="htmlWrap" src="/game"></iframe>''';

const _innerHtml =
    r'''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;overflow:hidden}canvas{width:100%;height:100%;display:block;touch-action:none}</style>
<canvas id="game" width="1200" height="720"></canvas>
<script>
const canvas=document.getElementById('game'), ctx=canvas.getContext('2d');
const documentId=Date.now()+'-'+Math.random().toString(36).slice(2);
let ticks=0,clicks=0;
function frame(){ticks++;ctx.fillStyle='#123947';ctx.fillRect(0,0,1200,720);
ctx.fillStyle='#e4c267';ctx.fillRect((ticks*7)%1100,320,100,100);
ctx.fillStyle='white';ctx.font='34px sans-serif';ctx.fillText('OFFLINE fixture — ticks '+ticks+' / clicks '+clicks,40,80);
ctx.fillText('Tap anywhere on this canvas',40,135);requestAnimationFrame(frame);}
canvas.addEventListener('pointerdown',()=>{clicks++;report();});
function report(){fetch('/telemetry?documentId='+encodeURIComponent(documentId)+'&ticks='+ticks+'&clicks='+clicks+'&at='+Date.now()).catch(()=>{});}
setInterval(report,250);frame();report();
</script>''';
