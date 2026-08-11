import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'src/battle/battle_controller.dart';
import 'src/battle/battle_damage_alert.dart';
import 'src/battle/fcd_map_controller.dart';
import 'src/battle/fcd_map_store.dart';
import 'src/battle/fcd_map_update_service.dart';
import 'src/logbook/logbook_page.dart';
import 'src/battle/live_battle_card.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/gadget_bypass_controller.dart';
import 'src/browser/gadget_bypass_store.dart';
import 'src/browser/game_browser_overlay.dart';
import 'src/browser/game_browser_toolbar.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/browser/game_toolbar_display_controller.dart';
import 'src/browser/game_screenshot_controller.dart';
import 'src/browser/game_surface_boundary.dart';
import 'src/browser/game_environment_host.dart';
import 'src/capture/battle_result_warning_overlay.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/capture/game_capture_port.dart';
import 'src/fleet/fleet_information_center.dart';
import 'src/fleet/ship_status_style.dart';
import 'src/fleet/anchorage_repair_navigation.dart';
import 'src/fleet/anchorage_repair_view.dart';
import 'src/fleet/fleet_summary_card.dart';
import 'src/fleet/expedition_summary_card.dart';
import 'src/fleet/repair_summary_card.dart';
import 'src/fleet/construction_summary_card.dart';
import 'src/fleet/pre_sortie_check_summary.dart';

import 'src/game_webview.dart';
import 'src/game_state/game_state_controller.dart';
import 'src/game_state/game_api_event_pipeline.dart';
import 'src/game_state/game_state_store.dart';
import 'src/layout/adaptive_layout.dart';
import 'src/layout/workspace_navigation_side.dart';
import 'src/layout/workspace_context_header.dart';
import 'src/inventory/owned_inventory_page.dart';
import 'src/improvement/improvement_dataset_store.dart';
import 'src/improvement/improvement_dataset_update_service.dart';
import 'src/improvement/improvement_favorites_store.dart';
import 'src/improvement/improvement_planner_controller.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/pinned_quests_summary.dart';
import 'src/quest/quest_center_page.dart';
import 'src/quest/quest_catalog_controller.dart';
import 'src/quest/quest_catalog_store.dart';
import 'src/quest/quest_catalog_update_service.dart';
import 'src/quest/shared_preferences_quest_store.dart';
import 'src/settings/layout_settings_controller.dart';
import 'src/settings/layout_settings_store.dart';
import 'src/settings/network_settings_controller.dart';
import 'src/settings/network_settings_store.dart';
import 'src/settings/display_mode_controller.dart';
import 'src/settings/display_mode_store.dart';
import 'src/settings/orientation_policy.dart';
import 'src/settings/safety_settings_controller.dart';
import 'src/settings/safety_settings_store.dart';
import 'src/settings/settings_page.dart';
import 'src/settings/release_check_service.dart';
import 'src/settings/startup_update_notice.dart';
import 'src/settings/screen_awake_controller.dart';
import 'src/settings/battle_prediction_settings.dart';
import 'src/settings/game_frame_rate_settings.dart';
import 'src/settings/game_rendering_mode_controller.dart';
import 'src/settings/game_rendering_mode.dart';
import 'src/senka/senka_controller.dart';
import 'src/senka/senka_page.dart';
import 'src/senka/senka_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
    systemLocaleCode: _localeStorageCode(
      WidgetsBinding.instance.platformDispatcher.locale,
    ),
  );
  final networkSettingsController = NetworkSettingsController(
    store: SharedPreferencesNetworkSettingsStore(),
  );
  await networkSettingsController.initialize();
  final gadgetBypassController = await GadgetBypassController.load(
    SharedPreferencesGadgetBypassStore(),
  );
  final safetySettingsController = await SafetySettingsController.load(
    SharedPreferencesSafetySettingsStore(),
  );
  final battlePredictionSettingsController =
      await BattlePredictionSettingsController.load(
        SharedPreferencesBattlePredictionSettingsStore(),
      );
  final displayModeController = await DisplayModeController.load(
    SharedPreferencesDisplayModeStore(),
  );
  final gameFrameRateSettingsController =
      await GameFrameRateSettingsController.load(
        SharedPreferencesGameFrameRateSettingsStore(),
      );
  final gameRenderingModeController = await GameRenderingModeController.load(
    SharedPreferencesGameRenderingModeStore(),
  );
  applyOrientationPolicy(
    currentWindowSize(),
    displayModeController.displayMode,
  );
  final captureModeController = await CaptureModeController.load(
    SharedPreferencesCaptureModeStore(),
  );
  final controller = PrototypeStatusController(
    captureEnabled: () => captureModeController.captureEnabled,
  );
  final browserController = GameBrowserController();
  final audioController = await GameAudioController.load(
    SharedPreferencesGameAudioStore(),
  );
  final toolbarController = GameToolbarController();
  final toolbarDisplayController = await GameToolbarDisplayController.load(
    SharedPreferencesGameToolbarDisplayStore(),
  );
  final gameScreenshotController = GameScreenshotController(
    const MethodChannelGameScreenshotPort(),
  );
  final questStore = SharedPreferencesQuestStore();
  final gameStateStore = GameStateStore();
  final gameStateController = GameStateController(
    questStore: questStore,
    gameStateStore: gameStateStore,
  );
  final senkaController = SenkaController(
    store: await SharedPreferencesSenkaStore.create(),
  );
  await senkaController.initialize();
  ImprovementDatasetStorage improvementStorage;
  try {
    improvementStorage = await ApplicationImprovementDatasetStorage.create();
  } catch (error) {
    debugPrint('改修资料目录不可用，改用内置数据: $error');
    improvementStorage = const BundledOnlyImprovementDatasetStorage();
  }
  final improvementStore = ImprovementDatasetStore(improvementStorage);
  final improvementDataset = await improvementStore.loadBestAvailable();
  final improvementPlannerController = ImprovementPlannerController(
    dataset: improvementDataset,
    favoritesStore: SharedPreferencesImprovementFavoritesStore(),
    updater: ImprovementDatasetUpdateService(
      client: http.Client(),
      store: improvementStore,
    ),
  );
  await improvementPlannerController.loadFavorites();
  final currentVersion = (await PackageInfo.fromPlatform()).version;
  FcdMapStorage fcdMapStorage;
  try {
    fcdMapStorage = await ApplicationFcdMapStorage.create();
  } catch (error) {
    debugPrint('FCD 数据目录不可用，改用内置数据: $error');
    fcdMapStorage = const BundledOnlyFcdMapStorage();
  }
  final fcdMapStore = FcdMapStore(fcdMapStorage);
  final loadedFcdMap = await fcdMapStore.loadBestAvailable();
  if (loadedFcdMap.diagnosticError case final error?) {
    debugPrint('FCD 本地数据降级: $error');
  }
  final loadedFcdMapState = await fcdMapStore.loadState();
  final fcdMapState =
      loadedFcdMapState?.version == loadedFcdMap.dataset.version.toString()
      ? loadedFcdMapState
      : null;
  final fcdMapController = FcdMapController(
    dataset: loadedFcdMap.dataset,
    updater: FcdMapUpdateService(
      client: http.Client(),
      store: fcdMapStore,
      appVersion: currentVersion,
    ),
    lastCheckedAt: fcdMapState?.lastCheckedAt,
    sourceHost: fcdMapState?.source ?? '',
  );
  QuestCatalogStorage questCatalogStorage;
  try {
    questCatalogStorage = await ApplicationQuestCatalogStorage.create();
  } catch (error) {
    debugPrint('任务资料目录不可用，改用内置数据: $error');
    questCatalogStorage = const BundledOnlyQuestCatalogStorage();
  }
  final questCatalogStore = QuestCatalogStore(questCatalogStorage);
  final loadedQuestCatalog = await questCatalogStore.loadBestAvailable();
  final loadedQuestCatalogState = await questCatalogStore.loadState();
  final questCatalogState =
      loadedQuestCatalogState?.version.commitSha ==
          loadedQuestCatalog.dataset.version.commitSha
      ? loadedQuestCatalogState
      : null;
  final questCatalogController = QuestCatalogController(
    dataset: loadedQuestCatalog.dataset,
    updater: QuestCatalogUpdateService(
      client: http.Client(),
      store: questCatalogStore,
      appVersion: currentVersion,
    ),
    lastCheckedAt: questCatalogState?.lastCheckedAt,
    sourceHost: questCatalogState?.source ?? '',
  );
  final battleController = BattleController(
    gameState: () => gameStateController.state,
    onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
    damageAlertPort: const MethodChannelBattleDamageAlertPort(),
    battleDamageVibrationEnabled: () =>
        safetySettingsController.battleDamageVibrationEnabled,
    nodeLabelResolver: fcdMapController,
    predictionMethod: () => battlePredictionSettingsController.method,
  );
  fcdMapController.addListener(battleController.refreshNodeLabel);
  final gameApiEventPipeline = GameApiEventPipeline(
    consumers: <GameApiEventConsumer>[
      gameStateController,
      senkaController,
      battleController,
    ],
  );
  final gameCaptureController = GameCaptureController(
    onAcceptedEvent: gameApiEventPipeline.add,
  );
  final releaseChecker = GitHubReleaseChecker();
  final screenAwakeController = await ScreenAwakeController.load(
    SharedPreferencesScreenAwakeStore(),
  );
  await screenAwakeController.attachPort(const MethodChannelScreenAwakePort());
  runApp(
    YahagiApp(
      layoutSettingsController: layoutSettingsController,
      networkSettingsController: networkSettingsController,
      gadgetBypassController: gadgetBypassController,
      safetySettingsController: safetySettingsController,
      battlePredictionSettingsController: battlePredictionSettingsController,
      gameFrameRateSettingsController: gameFrameRateSettingsController,
      gameRenderingModeController: gameRenderingModeController,
      displayModeController: displayModeController,
      controller: controller,
      browserController: browserController,
      captureModeController: captureModeController,
      audioController: audioController,
      toolbarController: toolbarController,
      toolbarDisplayController: toolbarDisplayController,
      gameScreenshotController: gameScreenshotController,
      gameCaptureController: gameCaptureController,
      gameApiEventPipeline: gameApiEventPipeline,
      gameStateController: gameStateController,
      senkaController: senkaController,
      battleController: battleController,
      fcdMapController: fcdMapController,
      questCatalogController: questCatalogController,
      improvementPlannerController: improvementPlannerController,
      currentVersion: currentVersion,
      releaseChecker: releaseChecker,
      screenAwakeController: screenAwakeController,
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(fcdMapController.checkForUpdates());
    unawaited(questCatalogController.checkForUpdates());
  });
}

class YahagiApp extends StatelessWidget {
  const YahagiApp({
    super.key,
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.safetySettingsController,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.gameRenderingModeController,
    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    this.gameApiEventPipeline,
    required this.gameStateController,
    this.senkaController,
    required this.battleController,
    this.fcdMapController,
    this.questCatalogController,
    this.improvementPlannerController,
    this.gameSurface,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
    this.screenAwakeController,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.showDeveloperDiagnostics = false,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final SafetySettingsController safetySettingsController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final GameRenderingModeController? gameRenderingModeController;
  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameApiEventPipeline? gameApiEventPipeline;
  final GameStateController gameStateController;
  final SenkaController? senkaController;
  final BattleController battleController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final Widget? gameSurface;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final bool showDeveloperDiagnostics;

  @override
  Widget build(BuildContext context) {
    battleController.bindFriendlyHpUpdater(
      gameStateController.applyFriendlyBattleHp,
    );
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        layoutSettingsController,
        ?toolbarDisplayController,
        ?gameRenderingModeController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ヤハギ',
          locale: layoutSettingsController.localeCode != null
              ? (layoutSettingsController.localeCode == 'zh_Hant'
                    ? const Locale.fromSubtags(
                        languageCode: 'zh',
                        scriptCode: 'Hant',
                      )
                    : Locale(layoutSettingsController.localeCode!))
              : null,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: layoutSettingsController.fontFamily,
            fontFamilyFallback: layoutSettingsController.fontFamilyFallback,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xffd4a85f),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xff0a1823),
            useMaterial3: true,
          ),
          home: StartupUpdateNotice(
            checker: releaseChecker ?? GitHubReleaseChecker(),
            currentVersion: currentVersion,
            enabled: releaseChecker != null,
            child: YahagiShell(
              layoutSettingsController: layoutSettingsController,
              networkSettingsController: networkSettingsController,
              gadgetBypassController: gadgetBypassController,
              safetySettingsController: safetySettingsController,
              battlePredictionSettingsController:
                  battlePredictionSettingsController,
              gameFrameRateSettingsController: gameFrameRateSettingsController,
              gameRenderingModeController: gameRenderingModeController,
              displayModeController: displayModeController,
              controller: controller,
              browserController: browserController,
              captureModeController: captureModeController,
              audioController: audioController,
              toolbarController: toolbarController,
              gameCaptureController: gameCaptureController,
              gameStateController: gameStateController,
              senkaController: senkaController,
              battleController: battleController,
              fcdMapController: fcdMapController,
              questCatalogController: questCatalogController,
              improvementPlannerController: improvementPlannerController,
              currentVersion: currentVersion,
              releaseChecker: releaseChecker,
              screenAwakeController: screenAwakeController,
              toolbarDisplayController: toolbarDisplayController,
              gameScreenshotController: gameScreenshotController,
              showDeveloperDiagnostics: showDeveloperDiagnostics,
              gameSurface: _buildGameSurface(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameSurface() {
    Widget withBattleWarning(Widget child) => BattleResultWarningOverlay(
      gameCaptureController: gameCaptureController,
      battleController: battleController,
      safetySettingsController: safetySettingsController,
      child: child,
    );

    if (gameSurface case final injected?) {
      return withBattleWarning(injected);
    }
    final renderingController = gameRenderingModeController;
    if (renderingController == null) {
      return withBattleWarning(
        _buildGameWebView(const GlobalObjectKey('yahagi_game_webview')),
      );
    }
    return GameEnvironmentHost(
      controller: renderingController,
      beforeRestart: _waitForCaptureQueues,
      gameBuilder: (context, mode, key) =>
          withBattleWarning(_buildGameWebView(key, renderingMode: mode)),
    );
  }

  Widget _buildGameWebView(Key key, {GameRenderingMode? renderingMode}) =>
      GameWebView(
        key: key,
        networkSettingsController: networkSettingsController,
        safetySettingsController: safetySettingsController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        frameRateSettingsController: gameFrameRateSettingsController,
        renderingMode:
            renderingMode ??
            gameRenderingModeController?.mode ??
            GameRenderingMode.standard,
      );

  Future<void> _waitForCaptureQueues() async {
    try {
      await Future.wait<void>([
        ?gameApiEventPipeline?.idle,
        gameStateController.idle,
        ?senkaController?.idle,
        battleController.idle,
      ]).timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint(
        'Timed out waiting for capture queues before WebView rebuild.',
      );
    }
  }
}

String _localeStorageCode(Locale locale) {
  if (locale.languageCode == 'ja') return 'ja';
  if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
    return 'zh_Hant';
  }
  return 'zh';
}

class YahagiShell extends StatefulWidget {
  const YahagiShell({
    super.key,
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.safetySettingsController,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.gameRenderingModeController,
    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameSurface,
    required this.gameCaptureController,
    required this.gameStateController,
    this.senkaController,
    required this.battleController,
    required this.currentVersion,
    this.releaseChecker,
    this.screenAwakeController,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.fcdMapController,
    this.questCatalogController,
    this.improvementPlannerController,
    this.showDeveloperDiagnostics = false,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final SafetySettingsController safetySettingsController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final GameRenderingModeController? gameRenderingModeController;
  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final Widget gameSurface;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final SenkaController? senkaController;
  final BattleController battleController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final bool showDeveloperDiagnostics;

  @override
  State<YahagiShell> createState() => _YahagiShellState();
}

class _YahagiShellState extends State<YahagiShell> with WidgetsBindingObserver {
  int _workspaceIndex = 0;
  int? _expeditionCheckFleetId;
  int? _fleetCenterInitialFleetId;
  int? _repairCenterInitialFleetId;
  int? _questCenterInitialQuestId;
  bool _inventoryShowShips = true;
  int _logbookTabIndex = 0;
  int _settingsTabIndex = 0;
  RepairCenterMode _repairCenterMode = RepairCenterMode.dock;
  QuestCenterMode _questCenterMode = QuestCenterMode.active;
  final QuestFilterController _questFilters = QuestFilterController();
  ExpeditionSummaryMode _expeditionCenterMode = ExpeditionSummaryMode.summary;
  ConstructionCenterMode _constructionCenterMode =
      ConstructionCenterMode.construction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.displayModeController.addListener(_applyOrientationPolicy);
    widget.layoutSettingsController.addListener(_onLayoutSettingsChanged);
    _applyOrientationPolicy();
  }

  @override
  void dispose() {
    widget.displayModeController.removeListener(_applyOrientationPolicy);
    widget.layoutSettingsController.removeListener(_onLayoutSettingsChanged);
    _questFilters.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onLayoutSettingsChanged() {
    widget.browserController
        .runJavaScript(
          'if(window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();',
        )
        .catchError((Object _) {});
  }

  @override
  void didChangeMetrics() {
    _applyOrientationPolicy();
    widget.browserController
        .runJavaScript(
          'if(window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();',
        )
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.audioController.handleLifecycleState(state);
    widget.screenAwakeController?.handleLifecycleState(state);
  }

  void _applyOrientationPolicy() {
    applyOrientationPolicy(
      currentWindowSize(),
      widget.displayModeController.displayMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        left: false,
        right: false,
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                color: Color(0xff122431),
                border: Border(bottom: BorderSide(color: Color(0xff294052))),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/app_icon.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ヤハギ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        widget.gameStateController,
                        if (widget.senkaController != null)
                          widget.senkaController!,
                      ]),
                      builder: (context, _) => WorkspaceContextHeader(
                        workspaceIndex: _workspaceIndex,
                        state: widget.gameStateController.state,
                        senkaState: widget.senkaController?.state,
                        onSenkaTap: widget.senkaController == null
                            ? null
                            : () => setState(() => _workspaceIndex = 9),
                        anchorageRepairStartedAt:
                            widget.gameStateController.anchorageRepairStartedAt,
                        onAnchorageTimerTap: () {
                          final startedAt = widget
                              .gameStateController
                              .anchorageRepairStartedAt;
                          final now = DateTime.now().toUtc();
                          final elapsed =
                              startedAt == null || now.isBefore(startedAt)
                              ? Duration.zero
                              : now.difference(startedAt);
                          final fleetId = preferredAnchorageRepairFleetId(
                            state: widget.gameStateController.state,
                            elapsed: elapsed,
                          );
                          setState(() {
                            _repairCenterMode = RepairCenterMode.anchorage;
                            _repairCenterInitialFleetId = fleetId;
                            _workspaceIndex = 3;
                          });
                        },
                        layoutSettingsController:
                            widget.layoutSettingsController,
                        selectedFleetId: _fleetCenterInitialFleetId ?? 1,
                        onFleetSelected: (fleetId) {
                          setState(() {
                            _fleetCenterInitialFleetId = fleetId;
                          });
                        },
                        inventoryShowShips: _inventoryShowShips,
                        onInventorySectionChanged: (value) {
                          setState(() => _inventoryShowShips = value);
                        },
                        logbookTabIndex: _logbookTabIndex,
                        onLogbookTabChanged: (value) {
                          setState(() => _logbookTabIndex = value);
                        },
                        settingsTabIndex: _settingsTabIndex,
                        onSettingsTabChanged: (value) {
                          setState(() => _settingsTabIndex = value);
                        },
                        repairMode: _repairCenterMode,
                        onRepairModeChanged: (mode) {
                          setState(() => _repairCenterMode = mode);
                        },
                        questMode: _questCenterMode,
                        questFilters: _questFilters,
                        onQuestModeChanged: (mode) {
                          setState(() => _questCenterMode = mode);
                        },
                        expeditionMode: _expeditionCenterMode,
                        onExpeditionModeChanged: (mode) {
                          setState(() => _expeditionCenterMode = mode);
                        },
                        constructionMode: _constructionCenterMode,
                        onConstructionModeChanged: (mode) {
                          setState(() => _constructionCenterMode = mode);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                textDirection: workspaceNavigationTextDirection(
                  menuOnRight:
                      widget.layoutSettingsController.workspaceMenuOnRight,
                ),
                children: [
                  _WorkspaceNavigation(
                    selectedIndex: _workspaceIndex,
                    onRight:
                        widget.layoutSettingsController.workspaceMenuOnRight,
                    onSelected: (index) {
                      setState(() => _workspaceIndex = index);
                    },
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Offstage(
                          offstage: _workspaceIndex != 0,
                          child: LayoutBuilder(
                            key: const Key('game-workspace'),
                            builder: (context, constraints) {
                              final isLandscape = !usesVerticalWorkspace(
                                Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                              );
                              final gameAreaRatio =
                                  widget.layoutSettingsController.autoZoom
                                  ? 0.65
                                  : widget
                                        .layoutSettingsController
                                        .gameAreaRatio
                                        .clamp(0.5, 0.75);
                              final gameFlex = (gameAreaRatio * 1000).round();
                              final informationFlex = 1000 - gameFlex;
                              final persistentToolbar =
                                  widget.toolbarDisplayController?.mode ==
                                  GameToolbarDisplayMode.persistent;
                              final gameSurfaceWrapper = ColoredBox(
                                color: const Color(0xff0a1823),
                                child: Center(
                                  child: AspectRatio(
                                    aspectRatio: 1200 / 720,
                                    child: GameSurfaceBoundary(
                                      child: widget.gameSurface,
                                    ),
                                  ),
                                ),
                              );
                              Widget buildToolbar(
                                bool persistent,
                              ) => AnimatedBuilder(
                                animation: Listenable.merge([
                                  widget.browserController,
                                  widget.audioController,
                                  ?widget.gameRenderingModeController,
                                ]),
                                builder: (context, _) => GameBrowserToolbar(
                                  enableBackdropBlur:
                                      widget
                                          .gameRenderingModeController
                                          ?.mode
                                          .enablesToolbarBlur ??
                                      true,
                                  interactionEnabled:
                                      !(widget
                                              .gameRenderingModeController
                                              ?.isBusy ??
                                          false),
                                  mode: widget.browserController.mode,
                                  loadState: widget.browserController.loadState,
                                  displayAddress:
                                      widget.browserController.displayAddress,
                                  onBack: widget.browserController.goBack,
                                  onReload: widget.browserController.reload,
                                  onHome: widget.browserController.goHome,
                                  onEnterDmm: widget
                                      .browserController
                                      .enterDmmLoginTest,
                                  isMuted: widget.audioController.isMuted,
                                  audioEnabled:
                                      widget.audioController.canToggle,
                                  onToggleMuted:
                                      widget.audioController.toggleMuted,
                                  onCollapse: widget.toolbarController.collapse,
                                  onFitScreen: () =>
                                      widget.browserController.runJavaScript(
                                        'if(window.__yahagiMobileAlignGame) window.__yahagiMobileAlignGame();',
                                      ),
                                  onScreenshot:
                                      widget.gameScreenshotController == null
                                      ? null
                                      : () async {
                                          final l10n = AppLocalizations.of(
                                            context,
                                          )!;
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          messenger
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n.screenshotSaving,
                                                ),
                                              ),
                                            );
                                          await WidgetsBinding
                                              .instance
                                              .endOfFrame;
                                          if (!context.mounted) return;
                                          final result = await widget
                                              .gameScreenshotController!
                                              .capture();
                                          if (!context.mounted) return;
                                          final message = result.path != null
                                              ? l10n.screenshotSaved(
                                                  result.path!,
                                                )
                                              : result.errorMessage == null
                                              ? l10n.screenshotFailed
                                              : '${l10n.screenshotFailed}\n'
                                                    '${result.errorMessage}';
                                          messenger
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(content: Text(message)),
                                            );
                                        },
                                  persistent: persistent,
                                ),
                              );
                              final gameWidget = persistentToolbar
                                  ? Column(
                                      key: const Key(
                                        'persistent-game-toolbar-layout',
                                      ),
                                      children: <Widget>[
                                        SizedBox(
                                          height: 42,
                                          child: buildToolbar(true),
                                        ),
                                        if (isLandscape)
                                          Expanded(child: gameSurfaceWrapper)
                                        else
                                          gameSurfaceWrapper,
                                      ],
                                    )
                                  : GameBrowserOverlay(
                                      controller: widget.toolbarController,
                                      gameSurface: gameSurfaceWrapper,
                                      toolbar: buildToolbar(false),
                                    );

                              final infoWidget = _InformationPanel(
                                layoutSettingsController:
                                    widget.layoutSettingsController,
                                controller: widget.controller,
                                browserController: widget.browserController,
                                captureModeController:
                                    widget.captureModeController,
                                gameCaptureController:
                                    widget.gameCaptureController,
                                gameStateController: widget.gameStateController,
                                battleController: widget.battleController,
                                onOpenFleet: (fleetId) {
                                  setState(() {
                                    _fleetCenterInitialFleetId = fleetId;
                                    _workspaceIndex = 1;
                                  });
                                },
                                onOpenRepair: (destination) {
                                  setState(() {
                                    _repairCenterMode = destination.mode;
                                    _repairCenterInitialFleetId =
                                        destination.fleetId;
                                    _workspaceIndex = 3;
                                  });
                                },
                                onOpenConstruction: () {
                                  setState(() => _workspaceIndex = 4);
                                },
                                onOpenExpedition: () {
                                  setState(() => _workspaceIndex = 2);
                                },
                                onOpenQuest: (questId) {
                                  setState(() {
                                    _questCenterInitialQuestId = questId;
                                    _workspaceIndex = 5;
                                  });
                                },
                                onOpenExpeditionCheck: (fleetId) {
                                  setState(() {
                                    _expeditionCheckFleetId = fleetId;
                                    _expeditionCenterMode =
                                        ExpeditionSummaryMode.check;
                                    _workspaceIndex = 2;
                                  });
                                },
                              );

                              return isLandscape
                                  ? Row(
                                      children: [
                                        Expanded(
                                          flex: gameFlex,
                                          child: DecoratedBox(
                                            decoration: const BoxDecoration(
                                              color: Color(0xff0a1823),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black38,
                                                  offset: Offset(2, 0),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: gameWidget,
                                          ),
                                        ),
                                        const VerticalDivider(
                                          width: 1,
                                          thickness: 1,
                                          color: Color(0xff294052),
                                        ),
                                        Expanded(
                                          flex: informationFlex,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                            ),
                                            child: infoWidget,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        DecoratedBox(
                                          decoration: const BoxDecoration(
                                            color: Color(0xff0a1823),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black38,
                                                offset: Offset(0, 2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: gameWidget,
                                        ),
                                        const Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Color(0xff294052),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: infoWidget,
                                          ),
                                        ),
                                      ],
                                    );
                            },
                          ),
                        ),
                        if (_workspaceIndex == 1)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            damagePulseMode:
                                widget
                                    .layoutSettingsController
                                    .enhancedDamagePulse
                                ? DamagePulseMode.enhanced
                                : DamagePulseMode.normal,
                            page: FleetInformationPage.fleet,
                            initialFleetId: _fleetCenterInitialFleetId,
                            showContextHeader: false,
                          ),
                        if (_workspaceIndex == 2)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            page: FleetInformationPage.expedition,
                            initialFleetId: _expeditionCheckFleetId,
                            showContextHeader: false,
                            expeditionMode: _expeditionCenterMode,
                            onExpeditionModeChanged: (mode) {
                              setState(() => _expeditionCenterMode = mode);
                            },
                          ),
                        if (_workspaceIndex == 3)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            page: FleetInformationPage.repair,
                            initialFleetId: _repairCenterInitialFleetId,
                            onFleetSelected: (fleetId) {
                              setState(() {
                                _repairCenterInitialFleetId = fleetId;
                              });
                            },
                            showContextHeader: false,
                            repairMode: _repairCenterMode,
                            onRepairModeChanged: (mode) {
                              setState(() => _repairCenterMode = mode);
                            },
                            showRepairModeTabs: false,
                          ),
                        if (_workspaceIndex == 4)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            page: FleetInformationPage.construction,
                            showContextHeader: false,
                            constructionMode: _constructionCenterMode,
                            improvementController:
                                widget.improvementPlannerController,
                          ),
                        if (_workspaceIndex == 5)
                          QuestCenterPage(
                            controller: widget.gameStateController,
                            catalogController: widget.questCatalogController,
                            initialQuestId: _questCenterInitialQuestId,
                            showTitle: false,
                            mode: _questCenterMode,
                            filterController: _questFilters,
                            onModeChanged: (mode) {
                              setState(() => _questCenterMode = mode);
                            },
                          ),
                        if (_workspaceIndex == 6)
                          LogbookPage(
                            battleController: widget.battleController,
                            selectedTabIndex: _logbookTabIndex,
                            onTabChanged: (value) {
                              setState(() => _logbookTabIndex = value);
                            },
                          ),
                        if (_workspaceIndex == 7)
                          OwnedInventoryPage(
                            controller: widget.gameStateController,
                            showShips: _inventoryShowShips,
                            onSectionChanged: (value) {
                              setState(() => _inventoryShowShips = value);
                            },
                            showSectionControl: false,
                          ),
                        if (_workspaceIndex == 8)
                          SettingsPage(
                            layoutSettingsController:
                                widget.layoutSettingsController,
                            networkSettingsController:
                                widget.networkSettingsController,
                            gadgetBypassController:
                                widget.gadgetBypassController,
                            audioController: widget.audioController,
                            captureModeController: widget.captureModeController,
                            browserController: widget.browserController,
                            gameCaptureController: widget.gameCaptureController,
                            prototypeStatusController: widget.controller,
                            gameStateController: widget.gameStateController,
                            safetySettingsController:
                                widget.safetySettingsController,
                            battlePredictionSettingsController:
                                widget.battlePredictionSettingsController,
                            gameFrameRateSettingsController:
                                widget.gameFrameRateSettingsController,
                            gameRenderingModeController:
                                widget.gameRenderingModeController,
                            isBattleActive:
                                widget.battleController.session != null &&
                                !widget.battleController.session!.completed,
                            displayModeController: widget.displayModeController,
                            currentVersion: widget.currentVersion,
                            releaseChecker: widget.releaseChecker,
                            screenAwakeController: widget.screenAwakeController,
                            toolbarDisplayController:
                                widget.toolbarDisplayController,
                            fcdMapController: widget.fcdMapController,
                            questCatalogController:
                                widget.questCatalogController,
                            improvementPlannerController:
                                widget.improvementPlannerController,
                            showTitle: false,
                            showDeveloperDiagnostics:
                                widget.showDeveloperDiagnostics,
                            selectedIndex: _settingsTabIndex,
                          ),
                        if (_workspaceIndex == 9 &&
                            widget.senkaController != null)
                          SenkaPage(controller: widget.senkaController!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({
    required this.selectedIndex,
    required this.onRight,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool onRight;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 58,
      decoration: BoxDecoration(
        color: const Color(0xff0a1823),
        border: workspaceNavigationBorder(menuOnRight: onRight),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _NavigationButton(
                      key: const Key('workspace-nav-game'),
                      icon: Icons.videogame_asset_outlined,
                      label: l10n.game,
                      selected: selectedIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-fleet'),
                      icon: Icons.directions_boat_outlined,
                      label: l10n.fleet,
                      selected: selectedIndex == 1,
                      onTap: () => onSelected(1),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-expedition'),
                      icon: Icons.explore_outlined,
                      label: l10n.expedition,
                      selected: selectedIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-repair'),
                      icon: Icons.build_circle_outlined,
                      label: l10n.repair,
                      selected: selectedIndex == 3,
                      onTap: () => onSelected(3),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-construction'),
                      icon: Icons.handyman_outlined,
                      label: l10n.construction,
                      selected: selectedIndex == 4,
                      onTap: () => onSelected(4),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-quests'),
                      icon: Icons.assignment_outlined,
                      label: l10n.quests,
                      selected: selectedIndex == 5,
                      onTap: () => onSelected(5),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-senka'),
                      icon: Icons.emoji_events_outlined,
                      label: l10n.senka,
                      selected: selectedIndex == 9,
                      onTap: () => onSelected(9),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-battle-records'),
                      icon: Icons.menu_book_outlined,
                      label: l10n.battleRecords,
                      selected: selectedIndex == 6,
                      onTap: () => onSelected(6),
                    ),
                    const SizedBox(height: 8),
                    _NavigationButton(
                      key: const Key('workspace-nav-owned-inventory'),
                      icon: Icons.inventory_2_outlined,
                      label: l10n.ownedInventory,
                      selected: selectedIndex == 7,
                      onTap: () => onSelected(7),
                    ),
                    const Spacer(),
                    _NavigationButton(
                      key: const Key('workspace-nav-settings'),
                      icon: Icons.settings_outlined,
                      label: l10n.settings,
                      selected: selectedIndex == 8,
                      onTap: () => onSelected(8),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          foregroundColor: selected
              ? const Color(0xffd4a85f)
              : const Color(0xff8197a5),
          backgroundColor: selected
              ? const Color(0xff2b2c22)
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _InformationPanel extends StatefulWidget {
  const _InformationPanel({
    required this.layoutSettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.gameCaptureController,
    required this.gameStateController,
    required this.battleController,
    required this.onOpenFleet,
    required this.onOpenRepair,
    required this.onOpenConstruction,
    required this.onOpenExpedition,
    required this.onOpenQuest,
    required this.onOpenExpeditionCheck,
  });

  final LayoutSettingsController layoutSettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final BattleController battleController;
  final ValueChanged<int> onOpenFleet;
  final ValueChanged<RepairDestination> onOpenRepair;
  final VoidCallback onOpenConstruction;
  final VoidCallback onOpenExpedition;
  final ValueChanged<int> onOpenQuest;
  final ValueChanged<int> onOpenExpeditionCheck;

  @override
  State<_InformationPanel> createState() => _InformationPanelState();
}

class _InformationPanelState extends State<_InformationPanel> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('information-panel'),
      decoration: const BoxDecoration(
        color: Color(0xff0d1a26),
        border: Border(left: BorderSide(color: Color(0xff294052))),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.layoutSettingsController,
          widget.browserController,
          widget.gameCaptureController,
        ]),
        builder: (context, _) {
          final hasError =
              widget.browserController.loadState == GamePageLoadState.failed ||
              widget.gameCaptureController.state == GameCaptureState.error ||
              widget.gameCaptureController.state ==
                  GameCaptureState.unsupported;

          final collapsedIds =
              widget.layoutSettingsController.dashboardCardCollapsed;
          final hiddenIds = widget.layoutSettingsController.dashboardCardHidden;
          final cardOrder = widget.layoutSettingsController.dashboardCardOrder;
          final validCards = cardOrder
              .where(
                (id) =>
                    LayoutSettingsStore.defaultDashboardCardOrder.contains(id),
              )
              .toList();
          final visibleOrder = validCards
              .where((id) => !hiddenIds.contains(id))
              .toList();
          final cardIndexes = <String, int>{
            for (var index = 0; index < validCards.length; index++)
              validCards[index]: index,
          };
          Widget buildCard(String id) {
            final isCollapsed = _isEditing || collapsedIds.contains(id);
            void toggle() => widget.layoutSettingsController
                .toggleDashboardCardCollapsed(id);
            final child = switch (id) {
              'fleet' => FleetSummaryCard(
                controller: widget.gameStateController,
                damagePulseMode:
                    widget.layoutSettingsController.enhancedDamagePulse
                    ? DamagePulseMode.enhanced
                    : DamagePulseMode.normal,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
                onOpenFleet: widget.onOpenFleet,
              ),
              'expedition' => ExpeditionSummaryCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
                onOpenExpedition: widget.onOpenExpedition,
                onOpenExpeditionCheck: widget.onOpenExpeditionCheck,
              ),

              'repair' => RepairSummaryCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
                onOpenRepair: widget.onOpenRepair,
              ),
              'construction' => ConstructionSummaryCard(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
                onOpenConstruction: widget.onOpenConstruction,
              ),
              'quests' => PinnedQuestsSummary(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
                onOpenQuest: widget.onOpenQuest,
              ),
              'battle' => LiveBattleCard(
                controller: widget.battleController,
                damagePulseMode:
                    widget.layoutSettingsController.enhancedDamagePulse
                    ? DamagePulseMode.enhanced
                    : DamagePulseMode.normal,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
              ),
              'pre_sortie' => PreSortieCheckSummary(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: toggle,
                onOpenFleet: widget.onOpenFleet,
              ),
              _ => const SizedBox.shrink(),
            };

            Widget finalChild = Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: child,
            );

            if (_isEditing) {
              final isHidden = hiddenIds.contains(id);
              finalChild = Opacity(
                opacity: isHidden ? 0.5 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: !isHidden,
                        activeColor: const Color(0xffd4a85f),
                        checkColor: Colors.black,
                        side: const BorderSide(
                          color: Color(0xff8fa8b6),
                          width: 2,
                        ),
                        onChanged: (_) => widget.layoutSettingsController
                            .toggleDashboardCardHidden(id),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ReorderableDelayedDragStartListener(
                          index: cardIndexes[id] ?? 0,
                          child: Container(
                            key: Key('dashboard-drag-region-$id'),
                            color: Colors.transparent,
                            child: IgnorePointer(child: child),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return KeyedSubtree(key: ValueKey(id), child: finalChild);
          }

          return GestureDetector(
            onLongPress: _isEditing
                ? null
                : () => setState(() => _isEditing = true),
            child: _isEditing
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            key: const Key('dashboard-edit-reset'),
                            tooltip: AppLocalizations.of(
                              context,
                            )!.restoreDefaultOrder,
                            onPressed: () {
                              widget.layoutSettingsController
                                  .resetDashboardCardOrder();
                            },
                            icon: const Icon(
                              Icons.settings_backup_restore_rounded,
                            ),
                            color: const Color(0xff8197a5),
                          ),
                          IconButton(
                            key: const Key('dashboard-edit-done'),
                            tooltip: AppLocalizations.of(context)?.editDone,
                            onPressed: () => setState(() => _isEditing = false),
                            icon: const Icon(Icons.check_rounded),
                            color: const Color(0xffd4a85f),
                          ),
                        ],
                      ),
                      Expanded(
                        child: ReorderableListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) {
                            final order = reorderDashboardCards(
                              validCards,
                              oldIndex,
                              newIndex,
                            );
                            widget.layoutSettingsController
                                .setDashboardCardOrder(order);
                          },
                          children: [
                            for (final id in validCards) buildCard(id),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    children: [
                      for (final id in visibleOrder) buildCard(id),
                      if (hasError)
                        Padding(
                          key: const ValueKey('error_card'),
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _InfoCard(
                            title: AppLocalizations.of(
                              context,
                            )!.gameStatusError,
                            subtitle:
                                widget.gameCaptureController.errorMessage ??
                                widget.browserController.errorMessage ??
                                AppLocalizations.of(
                                  context,
                                )!.gameStatusErrorDesc,
                            warning: true,
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    this.warning = false,
  });

  final String title;
  final String subtitle;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: warning ? const Color(0xff3a292b) : const Color(0xff142735),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: warning ? const Color(0xff75484a) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xff8197a5), height: 1.35),
          ),
        ],
      ),
    );
  }
}
