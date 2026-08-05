import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_display_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_screenshot_controller.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';

void main() {
  testWidgets('shows the game surface, information panel, and capture modes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final controller = PrototypeStatusController(
      captureEnabled: () => captureModeController.captureEnabled,
    );
    final layoutSettingsController = await LayoutSettingsController.load(
      _MemoryLayoutSettingsStore(),
    );
    final safetySettingsController = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    final displayModeController = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    final browserController = GameBrowserController(port: _NoopBrowserPort());
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final toolbarDisplayController = await GameToolbarDisplayController.load(
      _MemoryToolbarDisplayStore(),
    );
    final gameScreenshotController = GameScreenshotController(
      _FakeScreenshotPort(),
    );
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    final gameCapturePort = _FakeCapturePort(supported: true);
    await gameCaptureController.attach(gameCapturePort, enabled: true);

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: layoutSettingsController,
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: safetySettingsController,
        displayModeController: displayModeController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        toolbarDisplayController: toolbarDisplayController,
        gameScreenshotController: gameScreenshotController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        gameSurface: const ColoredBox(
          key: Key('fake-game-surface'),
          color: Colors.black,
        ),
      ),
    );

    expect(find.byKey(const Key('fake-game-surface')), findsOneWidget);
    final gameSize = tester.getSize(find.byKey(const Key('fake-game-surface')));
    expect(gameSize.width / gameSize.height, closeTo(1200 / 720, 0.001));
    final panel = find.byKey(const Key('information-panel'));
    expect(panel, findsOneWidget);
    final workspaceWidth = tester
        .getSize(find.byKey(const Key('game-workspace')))
        .width;
    final panelWidth = tester.getSize(panel).width;
    expect(panelWidth / workspaceWidth, closeTo(0.5, 0.015));
    for (final informationRatio in <double>[0.25, 0.37, 0.5]) {
      await layoutSettingsController.setGameAreaRatio(1 - informationRatio);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(panel).width / workspaceWidth,
        closeTo(informationRatio, 0.015),
      );
    }
    expect(find.text('功能面板'), findsNothing);
    expect(find.text('编辑顺序'), findsNothing);
    await tester.longPress(find.byKey(const ValueKey('fleet')));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.byType(ReorderableDelayedDragStartListener), findsWidgets);
    final dragRegion = find.byKey(const Key('dashboard-drag-region-fleet'));
    expect(dragRegion, findsOneWidget);
    expect(tester.getSize(dragRegion).width, greaterThan(200));
    await tester.tap(find.byKey(const Key('dashboard-edit-done')));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('live-battle-card')),
      200,
      scrollable: find
          .descendant(of: panel, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live-battle-card')), findsOneWidget);
    expect(find.text('未卜先知'), findsOneWidget);
    expect(find.byKey(const Key('browser-home')), findsOneWidget);
    expect(find.byKey(const Key('game-browser-overlay')), findsOneWidget);
    expect(find.byKey(const Key('game-audio-toggle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('browser-screenshot')));
    await tester.pumpAndSettle();
    expect(find.textContaining('yahagi-test.png'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await toolbarDisplayController.setMode(GameToolbarDisplayMode.persistent);
    await tester.pumpAndSettle();
    final persistentLayout = find.byKey(
      const Key('persistent-game-toolbar-layout'),
    );
    expect(persistentLayout, findsOneWidget);
    expect(find.byKey(const Key('game-browser-overlay')), findsNothing);
    expect(
      tester.getTopLeft(persistentLayout).dy,
      closeTo(tester.getTopLeft(panel).dy, 0.1),
    );
    expect(
      tester.getSize(persistentLayout).width + tester.getSize(panel).width,
      lessThanOrEqualTo(workspaceWidth),
    );
    await tester.tap(find.byKey(const Key('workspace-nav-settings')));
    await tester.pumpAndSettle();

    final settingsLabelX = tester
        .getTopLeft(find.byKey(const Key('settings-language-label')))
        .dx;
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-auto-zoom-label'))).dx,
      closeTo(settingsLabelX, 0.1),
    );
    expect(find.text('自动缩放游戏画面（默认推荐 65：35）'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings-logout-label')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('settings-logout-label'))).dx,
      closeTo(settingsLabelX, 0.1),
    );

    expect(find.text('游戏模式（默认）'), findsOneWidget);
    expect(find.text('纯浏览模式'), findsOneWidget);
    expect(find.text('后台播放声音'), findsOneWidget);
    expect(find.text('关于 ヤハギ', skipOffstage: false), findsWidgets);
    expect(find.text('诊断与关于', skipOffstage: false), findsNothing);
    expect(find.text('安全边界', skipOffstage: false), findsNothing);
    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();
    expect(find.text('资源'), findsNothing);
    for (final key in <String>[
      'workspace-nav-fleet',
      'workspace-nav-expedition',
      'workspace-nav-repair',
      'workspace-nav-construction',
      'workspace-nav-quests',
      'workspace-nav-battle-records',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('switches to browser-only mode and shows capture is disabled', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final controller = PrototypeStatusController(
      captureEnabled: () => captureModeController.captureEnabled,
    );
    final audioController = await GameAudioController.load(_MemoryAudioStore());
    final toolbarController = GameToolbarController();
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: controller,
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    await tester.tap(find.byKey(const Key('workspace-nav-settings')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('纯浏览模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('纯浏览模式'));
    await tester.pumpAndSettle();

    expect(captureModeController.mode, CaptureMode.browserOnly);
    expect(find.text('纯浏览模式 · 数据捕获已关闭', skipOffstage: false), findsOneWidget);
    expect(
      find.text('纯浏览模式将在重新载入页面后停止数据捕获。', skipOffstage: false),
      findsOneWidget,
    );
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    toolbarController.dispose();
  });

  testWidgets('shows capture unsupported without removing the game surface', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameCapturePort = _FakeCapturePort(supported: false);
    await gameCaptureController.attach(gameCapturePort, enabled: true);
    final toolbarController = GameToolbarController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: const ColoredBox(
          key: Key('unsupported-game-surface'),
          color: Colors.black,
        ),
      ),
    );

    expect(find.byKey(const Key('unsupported-game-surface')), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-nav-settings')));
    await tester.pumpAndSettle();
    expect(
      find.text('当前 WebView 不支持跨框架捕获', skipOffstage: false),
      findsOneWidget,
    );
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('shows successful port verification for api_result one', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameCapturePort = _FakeCapturePort(supported: true);
    await gameCaptureController.attach(gameCapturePort, enabled: true);
    final toolbarController = GameToolbarController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        showDeveloperDiagnostics: true,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: const ColoredBox(color: Colors.black),
      ),
    );
    gameCapturePort.emit(
      CapturedApiEvent(
        path: '/kcsapi/api_port/port',
        responseBody: '{"api_result":1}',
        source: CaptureSource.xhr,
        capturedAt: DateTime.utc(2026, 7, 30),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('workspace-nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('母港接口验证通过', skipOffstage: false), findsOneWidget);
    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    await gameCapturePort.close();
    toolbarController.dispose();
  });

  testWidgets('switches to fleet center without disposing the game surface', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _MemoryModeStore(),
    );
    final gameCaptureController = GameCaptureController();
    final gameStateController = GameStateController();
    final battleController = BattleController(
      gameState: () => gameStateController.state,
    );
    final toolbarController = GameToolbarController();
    var disposeCount = 0;

    await tester.pumpWidget(
      YahagiApp(
        layoutSettingsController: await LayoutSettingsController.load(
          _MemoryLayoutSettingsStore(),
        ),
        networkSettingsController: NetworkSettingsController(
          store: _MemoryNetworkSettingsStore(),
        ),
        gadgetBypassController: GadgetBypassController(
          store: _MemoryGadgetBypassStore(),
          port: _FakeGadgetBypassPort(),
        ),
        safetySettingsController: await SafetySettingsController.load(
          MemorySafetySettingsStore(),
        ),
        displayModeController: await DisplayModeController.load(
          MemoryDisplayModeStore(),
        ),
        controller: PrototypeStatusController(),
        browserController: GameBrowserController(port: _NoopBrowserPort()),
        captureModeController: captureModeController,
        gameCaptureController: gameCaptureController,
        gameStateController: gameStateController,
        battleController: battleController,
        audioController: await GameAudioController.load(_MemoryAudioStore()),
        toolbarController: toolbarController,
        gameSurface: _LifecycleProbe(
          key: const Key('persistent-game-surface'),
          onDispose: () => disposeCount++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('workspace-nav-fleet')));
    await tester.pumpAndSettle();

    expect(find.text('舰队'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-game-surface'), skipOffstage: false),
      findsOneWidget,
    );
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('workspace-nav-expedition')));
    await tester.pumpAndSettle();
    expect(find.text('远征'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-repair')));
    await tester.pumpAndSettle();
    expect(find.text('入渠'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-construction')));
    await tester.pumpAndSettle();
    expect(find.text('建造'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-quests')));
    await tester.pumpAndSettle();
    expect(find.text('任务'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace-nav-battle-records')));
    await tester.pumpAndSettle();

    expect(find.text('本次出击'), findsOneWidget);
    expect(
      find.byKey(const Key('persistent-game-surface'), skipOffstage: false),
      findsOneWidget,
    );
    expect(disposeCount, 0);

    await tester.tap(find.byKey(const Key('workspace-nav-game')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('information-panel')), findsOneWidget);
    expect(disposeCount, 0);

    gameCaptureController.dispose();
    gameStateController.dispose();
    battleController.dispose();
    toolbarController.dispose();
  });
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({super.key, required this.onDispose});

  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}

final class _MemoryAudioStore implements GameAudioStore {
  bool? savedMuted;
  bool? savedBackgroundPlayback;

  @override
  Future<bool?> readMuted() async => savedMuted;

  @override
  Future<void> writeMuted(bool muted) async {
    savedMuted = muted;
  }

  @override
  Future<bool?> readBackgroundPlaybackEnabled() async =>
      savedBackgroundPlayback;

  @override
  Future<void> writeBackgroundPlaybackEnabled(bool enabled) async {
    savedBackgroundPlayback = enabled;
  }
}

class _MemoryLayoutSettingsStore implements LayoutSettingsStore {
  double _ratio = 0.5;
  double _width = 300;
  bool _autoZoom = false;
  List<String> _dashboardCardOrder = [
    'fleet',
    'expedition',
    'repair',
    'construction',
    'quests',
    'battle',
    'pre_sortie',
  ];
  List<String> _dashboardCardCollapsed = [];
  List<String> _dashboardCardHidden = [];

  @override
  Future<double> loadGameAreaRatio() async => _ratio;

  @override
  Future<void> saveGameAreaRatio(double ratio) async => _ratio = ratio;

  @override
  Future<double> loadInformationPanelWidth() async => _width;

  @override
  Future<void> saveInformationPanelWidth(double width) async => _width = width;

  @override
  Future<bool> loadAutoZoom() async => _autoZoom;

  @override
  Future<void> saveAutoZoom(bool autoZoom) async => _autoZoom = autoZoom;

  @override
  Future<List<String>> loadDashboardCardOrder() async {
    return _dashboardCardOrder;
  }

  @override
  Future<void> saveDashboardCardOrder(List<String> order) async {
    _dashboardCardOrder = List<String>.from(order);
  }

  @override
  Future<List<String>> loadDashboardCardCollapsed() async {
    return _dashboardCardCollapsed;
  }

  @override
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds) async {
    _dashboardCardCollapsed = List<String>.from(collapsedIds);
  }

  @override
  Future<List<String>> loadDashboardCardHidden() async {
    return _dashboardCardHidden;
  }

  @override
  Future<void> saveDashboardCardHidden(List<String> hiddenIds) async {
    _dashboardCardHidden = List<String>.from(hiddenIds);
  }

  Future<bool> loadAutoZoomEnabled() async => false;

  Future<void> saveAutoZoomEnabled(bool value) async {}

  @override
  Future<String?> loadFontFamily() async => null;

  @override
  Future<void> saveFontFamily(String? value) async {}

  @override
  Future<String?> loadLocaleCode() async => null;

  @override
  Future<void> saveLocaleCode(String? value) async {}
}

final class _MemoryToolbarDisplayStore implements GameToolbarDisplayStore {
  GameToolbarDisplayMode? value;

  @override
  Future<GameToolbarDisplayMode?> read() async => value;

  @override
  Future<void> write(GameToolbarDisplayMode mode) async => value = mode;
}

final class _FakeScreenshotPort implements GameScreenshotPort {
  @override
  Future<String> captureWebView() async => '/pictures/yahagi-test.png';
}

final class _MemoryNetworkSettingsStore implements NetworkSettingsStore {
  NetworkSettings _settings = const NetworkSettings();

  @override
  Future<NetworkSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(NetworkSettings settings) async {
    _settings = settings;
  }
}

final class _NoopBrowserPort implements GameBrowserPort {
  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<void> goBack() async {}

  @override
  Future<void> loadUri(Uri uri) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<void> showLocalHome() async {}

  @override
  Future<void> runJavaScript(String javascript) async {}

  @override
  Future<void> clearCache() async {}
}

final class _MemoryModeStore implements CaptureModeStore {
  CaptureMode? savedMode;

  @override
  Future<CaptureMode?> read() async => savedMode;

  @override
  Future<void> write(CaptureMode mode) async {
    savedMode = mode;
  }
}

class _MemoryGadgetBypassStore implements GadgetBypassStore {
  GadgetBypassSettings settings = const GadgetBypassSettings();

  @override
  Future<GadgetBypassSettings> load() async => settings;

  @override
  Future<void> save(GadgetBypassSettings settings) async {
    this.settings = settings;
  }
}

class _FakeGadgetBypassPort implements GadgetBypassPort {
  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async {
    return true;
  }

  @override
  Future<GadgetBypassStatus> status() async =>
      const GadgetBypassStatus(enabled: false, endpoint: '', supported: true);

  @override
  Future<bool> clearCache() async => true;

  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async {
    return const GadgetBypassDiagnoseResult(
      w00g: GadgetBypassProbe(reachable: true, elapsedMs: 1),
      endpoint: GadgetBypassProbe(reachable: true, elapsedMs: 1),
      kcsapi: GadgetBypassProbe(reachable: true, elapsedMs: 1),
    );
  }
}

final class _FakeCapturePort implements GameCapturePort {
  _FakeCapturePort({required this.supported});

  final bool supported;
  final _controller = StreamController<CapturedApiEvent>.broadcast();

  @override
  Stream<CapturedApiEvent> get events => _controller.stream;

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => supported;

  void emit(CapturedApiEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {}

  Future<void> close() async {
    await _controller.close();
  }
}
