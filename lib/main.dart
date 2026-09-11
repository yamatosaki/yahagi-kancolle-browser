import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'src/settings/fleet_display_settings_section.dart';
import 'src/settings/module_display_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'src/battle/battle_controller.dart';
import 'src/battle/battle_damage_alert.dart';
import 'src/battle/fcd_map_controller.dart';
import 'src/battle/fcd_map_store.dart';
import 'src/battle/fcd_map_update_service.dart';
import 'src/battle/formation_memory.dart';
import 'src/logbook/logbook_database.dart';
import 'src/logbook/logbook_page.dart';
import 'src/battle/live_battle_card.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/gadget_bypass_controller.dart';
import 'src/browser/gadget_bypass_store.dart';
import 'src/browser/game_browser_overlay.dart';
import 'src/browser/game_browser_toolbar.dart';
import 'src/browser/game_refresh_dialog.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/browser/game_toolbar_display_controller.dart';
import 'src/browser/game_screenshot_controller.dart';
import 'src/browser/game_surface_boundary.dart';
import 'src/browser/game_workspace_visibility.dart';
import 'src/browser/game_environment_host.dart';
import 'src/browser/game_application_restart_port.dart';
import 'src/browser/game_resource_cache_controller.dart';
import 'src/browser/game_resource_manifest_builder.dart';
import 'src/browser/game_resource_manifest_consumer.dart';
import 'src/browser/native_game_surface_slot.dart';
import 'src/capture/battle_result_warning_overlay.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/capture/game_capture_port.dart';
import 'src/diagnostics/diagnostic_controller.dart';
import 'src/diagnostics/diagnostic_event.dart';
import 'src/diagnostics/diagnostic_export_service.dart';
import 'src/diagnostics/diagnostic_game_api_observer.dart';
import 'src/diagnostics/diagnostic_performance_monitor.dart';
import 'src/diagnostics/diagnostic_platform_port.dart';
import 'src/diagnostics/diagnostic_recorder.dart';
import 'src/diagnostics/diagnostic_settings_store.dart';
import 'src/diagnostics/diagnostic_storage.dart';
import 'src/development/development_repository.dart';
import 'src/fleet/fleet_information_center.dart';
import 'src/settings/battle_status_effect_settings.dart';
import 'src/fleet/anchorage_repair_navigation.dart';
import 'src/fleet/anchorage_repair_view.dart';
import 'src/fleet/fleet_summary_card.dart';
import 'src/fleet/land_base_summary_card.dart';
import 'src/fleet/expedition_summary_card.dart';
import 'src/fleet/repair_summary_card.dart';
import 'src/fleet/construction_summary_card.dart';
import 'src/fleet/nosaki_sparkle_calculator.dart';
import 'src/fleet/morale_recovery_timer_controller.dart';
import 'src/fleet/pre_sortie_check_summary.dart';

import 'src/game_webview.dart';
import 'src/native_activity_game_surface.dart';
import 'src/game_state/game_state_controller.dart';
import 'src/game_state/game_api_event_pipeline.dart';
import 'src/game_state/game_state_store.dart';
import 'src/layout/adaptive_layout.dart';
import 'src/layout/workspace_navigation_side.dart';
import 'src/layout/workspace_context_header.dart';
import 'src/layout/window_metrics_change.dart';
import 'src/layout/window_metrics_recovery_scheduler.dart';
import 'src/kcwiki_report/kcwiki_report_collector.dart';
import 'src/kcwiki_report/kcwiki_report_consumer.dart';
import 'src/kcwiki_report/kcwiki_report_dispatcher.dart';
import 'src/kcwiki_report/kcwiki_report_settings.dart';
import 'src/kcwiki_report/kcwiki_report_transport.dart';
import 'src/performance/second_tick_scope.dart';
import 'src/inventory/owned_inventory_page.dart';
import 'src/new_ship/new_ship_reminder_controller.dart';
import 'src/new_ship/new_ship_reminder_store.dart';
import 'src/notification/game_notification_coordinator.dart';
import 'src/notification/notification_models.dart';
import 'src/improvement/improvement_dataset_store.dart';
import 'src/improvement/improvement_dataset_update_service.dart';
import 'src/improvement/improvement_favorites_store.dart';
import 'src/improvement/improvement_planner_controller.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/pinned_quests_summary.dart';
import 'src/quest/quest_completion_badge.dart';
import 'src/quest/quest_completion_feedback.dart';
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
import 'src/toolbox/toolbox_page.dart';
import 'src/localization/runtime_message_text.dart';
import 'src/settings/background_game_retention_controller.dart';
import 'src/settings/battle_prediction_settings.dart';
import 'src/settings/game_frame_rate_settings.dart';
import 'src/settings/game_connector_controller.dart';
import 'src/settings/game_connector.dart';
import 'src/settings/game_rendering_mode_controller.dart';
import 'src/settings/game_rendering_mode.dart';
import 'src/settings/notification_settings_controller.dart';
import 'src/settings/notification_settings_store.dart';
import 'src/notification/method_channel_notification_port.dart';
import 'src/notification/notification_timer_anchor_store.dart';
import 'src/senka/senka_controller.dart';
import 'src/senka/senka_page.dart';
import 'src/senka/senka_store.dart';
import 'src/widgets/top_notice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
    systemLocaleCode: _localeStorageCode(
      WidgetsBinding.instance.platformDispatcher.locale,
    ),
  );
  final notificationSettingsController = NotificationSettingsController(
    store: const SharedPreferencesNotificationSettingsStore(),
  );
  await notificationSettingsController.initialize();
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
  final formationMemoryController = await FormationMemoryController.load(
    SharedPreferencesFormationMemoryStore(),
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
  final gameConnectorController = await GameConnectorController.load(
    SharedPreferencesGameConnectorStore(),
  );
  final backgroundGameRetentionController =
      await BackgroundGameRetentionController.load(
        SharedPreferencesBackgroundGameRetentionStore(),
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
  final browserController = GameBrowserController(
    homeUri: gameConnectorController.connector.entryUri,
  );
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
  await gameStateController.initialize();
  final kcwikiReportController = await KcwikiReportController.load(
    SharedPreferencesKcwikiReportSettingsStore(),
  );
  final gameResourceCacheController = GameResourceCacheController();
  await gameResourceCacheController.initialize();
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
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;
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
    waitForGameState: () => gameStateController.idle,
    onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
    damageAlertPort: const MethodChannelBattleDamageAlertPort(),
    battleStatusEffectSettings: () =>
        safetySettingsController.battleStatusEffects,
    nodeLabelResolver: fcdMapController,
    formationMemory: formationMemoryController,
  );
  fcdMapController.addListener(battleController.refreshNodeLabel);
  final gameResourceManifestConsumer = GameResourceManifestConsumer(
    controller: gameResourceCacheController,
    ownedShipMasterIds: () => gameStateController.state.ships.values
        .map((ship) => ship.masterId)
        .toSet(),
    ownedSlotItemMasterIds: () => gameStateController.state.slotItems.values
        .map((item) => item.masterId)
        .toSet(),
    staticUrlsLoader: GameResourceStaticCatalog.load,
    waitForGameState: () => gameStateController.idle,
  );
  late final KcwikiReportDispatcher kcwikiReportDispatcher;
  kcwikiReportDispatcher = KcwikiReportDispatcher(
    transportFactory: () => HttpKcwikiReportTransport(
      client: http.Client(),
      baseUri: Uri.parse(
        const String.fromEnvironment(
          'KCWIKI_REPORT_BASE_URL',
          defaultValue: 'http://report2.kcwiki.org:17027',
        ),
      ),
    ),
    onQueued: (module) => kcwikiReportController.recordQueued(
      module: module.wireName,
      occurredAt: DateTime.now(),
    ),
    onResult: (result) => kcwikiReportController.recordResult(
      module: result.module.wireName,
      succeeded: result.accepted,
      occurredAt: DateTime.now(),
      statusCode: result.statusCode,
      failure: switch (result.failure) {
        KcwikiTransportFailure.bodyTooLarge => KcwikiReportFailure.bodyTooLarge,
        KcwikiTransportFailure.timeout => KcwikiReportFailure.timeout,
        KcwikiTransportFailure.network => KcwikiReportFailure.network,
        KcwikiTransportFailure.rejected => KcwikiReportFailure.httpRejected,
        null => null,
      },
    ),
    onDropped: kcwikiReportController.recordDropped,
  );
  final kcwikiReportConsumer = KcwikiReportConsumer(
    controller: kcwikiReportController,
    collector: KcwikiReportCollector(),
    dispatcher: kcwikiReportDispatcher,
    gameState: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
  );
  late final GameNotificationCoordinator notificationCoordinator;
  final newShipReminderController = NewShipReminderController(
    stateProvider: () => gameStateController.state,
    store: NewShipReminderStore(await SharedPreferences.getInstance()),
    onPublish: (alert) {
      final state = gameStateController.state;
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final names = alert.masterIds
          .map(
            (id) => state.masterShips[id]?.name ?? l10n.newShipFallbackName(id),
          )
          .join('、');
      notificationCoordinator.enqueueImmediateAlert(
        ImmediateNotificationItem(
          key: 'new-ship:${alert.key}',
          type: GameNotificationType.newShip,
          occurredAt: alert.occurredAt,
          title: l10n.newShipAlertTitle,
          body: l10n.newShipAlertBody(names),
        ),
      );
    },
  );
  final gameApiEventPipeline = GameApiEventPipeline(
    settleGameState: () async {
      await gameStateController.idle;
      await battleController.idle;
      await gameStateController.idle;
    },
    consumers: <GameApiEventConsumer>[
      gameStateController,
      kcwikiReportConsumer,
      gameResourceManifestConsumer,
      senkaController,
      battleController,
      newShipReminderController,
    ],
    onBackgroundDecodeFallback: (path) {
      if (!kcwikiReportController.enabled) return;
      kcwikiReportController.recordParseRecovered(
        path: path,
        occurredAt: DateTime.now(),
      );
    },
  );
  final gameCaptureController = GameCaptureController(
    onAcceptedEvent: gameApiEventPipeline.add,
  );
  final releaseChecker = GitHubReleaseChecker();
  final screenAwakeController = await ScreenAwakeController.load(
    SharedPreferencesScreenAwakeStore(),
  );
  await screenAwakeController.attachPort(const MethodChannelScreenAwakePort());
  final applicationSupportDirectory = await getApplicationSupportDirectory();
  final temporaryDirectory = await getTemporaryDirectory();
  final diagnosticStorage = DiagnosticStorage(
    directory: Directory(
      p.join(applicationSupportDirectory.path, 'diagnostics'),
    ),
  );
  final diagnosticRecorder = DiagnosticRecorder(
    sink: diagnosticStorage,
    enabled: false,
  );
  const diagnosticPlatform = MethodChannelDiagnosticPlatformPort();
  final diagnosticApiObserver = DiagnosticGameApiObserver(
    recorder: diagnosticRecorder,
  );
  var lastBrowserDiagnosticState = browserController.loadState;
  void recordBrowserState() {
    final state = browserController.loadState;
    if (state == lastBrowserDiagnosticState) return;
    lastBrowserDiagnosticState = state;
    diagnosticRecorder.record(
      DiagnosticEvent.webViewState(
        occurredAt: DateTime.now(),
        state: state.name,
        durationMs: 0,
      ),
    );
  }

  var diagnosticNativeWebViewGeneration = -1;
  DiagnosticWebViewHost diagnosticWebViewHost() {
    final mode = gameRenderingModeController.mode;
    if (!mode.usesActivityWebView) {
      return DiagnosticWebViewHost.flutterPlatformView;
    }
    return diagnosticNativeWebViewGeneration >= 0
        ? DiagnosticWebViewHost.activityDirect
        : DiagnosticWebViewHost.absent;
  }

  DiagnosticGameRenderer diagnosticRenderer() {
    final mode = gameRenderingModeController.mode;
    return mode.usesCanvasRenderer
        ? DiagnosticGameRenderer.canvas
        : DiagnosticGameRenderer.webgl;
  }

  int diagnosticGeneration() => diagnosticNativeWebViewGeneration < 0
      ? 0
      : diagnosticNativeWebViewGeneration;
  final diagnosticPerformanceMonitor = DiagnosticPerformanceMonitor(
    recorder: diagnosticRecorder,
    platform: diagnosticPlatform,
    pendingApiEvents: () => gameApiEventPipeline.pendingEventCount,
    activeApiPath: () => gameApiEventPipeline.activePath,
    backgroundDecodeFallbacks: () =>
        gameApiEventPipeline.backgroundFallbackCount,
    databaseBytes: LogbookDatabase.instance.diagnosticFileSizeBytes,
    webViewHost: diagnosticWebViewHost,
    renderer: diagnosticRenderer,
    generationId: diagnosticGeneration,
  );
  final diagnosticController = DiagnosticController(
    settings: SharedPreferencesDiagnosticSettingsStore(),
    storage: diagnosticStorage,
    recorder: diagnosticRecorder,
    platform: diagnosticPlatform,
    webViewHost: diagnosticWebViewHost,
    renderer: diagnosticRenderer,
    generationId: diagnosticGeneration,
    renderingModeName: () => gameRenderingModeController.mode.storageName,
    exporter: DiagnosticExportService(
      storage: diagnosticStorage,
      exportDirectory: Directory(
        p.join(temporaryDirectory.path, 'diagnostics-export'),
      ),
      platform: diagnosticPlatform,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    ),
    performanceMonitor: diagnosticPerformanceMonitor,
    onAttachObservers: () {
      gameApiEventPipeline.observer = diagnosticApiObserver;
      browserController.addListener(recordBrowserState);
    },
    onDetachObservers: () {
      if (identical(gameApiEventPipeline.observer, diagnosticApiObserver)) {
        gameApiEventPipeline.observer = null;
      }
      browserController.removeListener(recordBrowserState);
    },
  );
  await diagnosticController.initialize();
  const notificationTimerAnchorStore =
      SharedPreferencesNotificationTimerAnchorStore();
  final notificationTimerAnchors = await notificationTimerAnchorStore.load();
  notificationCoordinator = GameNotificationCoordinator(
    gameStateController: gameStateController,
    settingsController: notificationSettingsController,
    localeCodeProvider: () =>
        layoutSettingsController.localeCode ??
        _localeStorageCode(WidgetsBinding.instance.platformDispatcher.locale),
    localeListenable: layoutSettingsController,
    notificationPort: const MethodChannelNotificationPort(),
    initialTimerAnchors: notificationTimerAnchors,
    timerAnchorStore: notificationTimerAnchorStore,
  );
  notificationCoordinator.start();
  runApp(
    YahagiApp(
      layoutSettingsController: layoutSettingsController,
      networkSettingsController: networkSettingsController,
      gadgetBypassController: gadgetBypassController,
      safetySettingsController: safetySettingsController,
      notificationSettingsController: notificationSettingsController,
      battlePredictionSettingsController: battlePredictionSettingsController,
      gameFrameRateSettingsController: gameFrameRateSettingsController,
      gameRenderingModeController: gameRenderingModeController,
      gameConnectorController: gameConnectorController,
      backgroundGameRetentionController: backgroundGameRetentionController,
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
      kcwikiReportController: kcwikiReportController,
      kcwikiReportConsumer: kcwikiReportConsumer,
      gameStateController: gameStateController,
      newShipReminderController: newShipReminderController,
      moraleRecoveryTimerController:
          notificationCoordinator.moraleRecoveryTimerController,
      gameResourceCacheController: gameResourceCacheController,
      senkaController: senkaController,
      battleController: battleController,
      fcdMapController: fcdMapController,
      questCatalogController: questCatalogController,
      improvementPlannerController: improvementPlannerController,
      currentVersion: currentVersion,
      releaseChecker: releaseChecker,
      screenAwakeController: screenAwakeController,
      diagnosticController: diagnosticController,
      nativeWebViewGenerationSink: (value) {
        diagnosticNativeWebViewGeneration = value;
      },
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(fcdMapController.checkForUpdates());
    unawaited(questCatalogController.checkForUpdates());
  });
}

final RouteObserver<ModalRoute<dynamic>> yahagiGameRouteObserver =
    YahagiGameRouteObserver();

bool shouldUsePersistentGameToolbar({
  required GameToolbarDisplayMode? displayMode,
  required GameRenderingMode? renderingMode,
}) {
  return displayMode == GameToolbarDisplayMode.persistent ||
      (renderingMode?.usesActivityWebView ?? false);
}

double portraitGamePanelExtraExtent({
  required GameToolbarDisplayMode? displayMode,
  required GameRenderingMode? renderingMode,
}) {
  if (renderingMode?.usesActivityWebView ?? false) {
    return 10;
  }
  return displayMode == GameToolbarDisplayMode.persistent ? 42 : 0;
}

Widget buildGameSurfaceForRenderingMode({
  required GameRenderingMode mode,
  required Key key,
  required Widget Function(Key key) buildNativeActivityGameSurface,
  required Widget Function(Key key, GameRenderingMode mode) buildGameWebView,
  required Widget Function(Widget child) withBattleWarning,
}) {
  if (mode.usesActivityWebView) {
    return withBattleWarning(buildNativeActivityGameSurface(key));
  }
  return withBattleWarning(buildGameWebView(key, mode));
}

class YahagiApp extends StatelessWidget {
  const YahagiApp({
    super.key,
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.safetySettingsController,
    this.notificationSettingsController,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.gameRenderingModeController,
    this.gameConnectorController,
    this.backgroundGameRetentionController,
    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    this.gameApiEventPipeline,
    this.newShipReminderController,
    this.kcwikiReportController,
    this.kcwikiReportConsumer,
    required this.gameStateController,
    this.moraleRecoveryTimerController,
    this.gameResourceCacheController,
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
    this.diagnosticController,
    this.gameRouteObserver,
    this.nativeWebViewGenerationSink,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final SafetySettingsController safetySettingsController;
  final NotificationSettingsController? notificationSettingsController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final GameRenderingModeController? gameRenderingModeController;
  final GameConnectorController? gameConnectorController;
  final BackgroundGameRetentionController? backgroundGameRetentionController;
  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameApiEventPipeline? gameApiEventPipeline;
  final NewShipReminderController? newShipReminderController;
  final KcwikiReportController? kcwikiReportController;
  final KcwikiReportConsumer? kcwikiReportConsumer;
  final GameStateController gameStateController;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final GameResourceCacheController? gameResourceCacheController;
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
  final DiagnosticController? diagnosticController;
  final RouteObserver<ModalRoute<dynamic>>? gameRouteObserver;
  final void Function(int)? nativeWebViewGenerationSink;

  @override
  Widget build(BuildContext context) {
    battleController.bindFriendlyHpUpdater(
      gameStateController.applyFriendlyBattleHp,
    );
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        layoutSettingsController,
        safetySettingsController,
        ?toolbarDisplayController,
        ?gameRenderingModeController,
      ]),
      builder: (context, _) {
        final routeObserver = gameRouteObserver ?? yahagiGameRouteObserver;
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
          navigatorObservers: <NavigatorObserver>[routeObserver],
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
          home: TopNoticeHost(
            child: StartupUpdateNotice(
              checker: releaseChecker ?? GitHubReleaseChecker(),
              currentVersion: currentVersion,
              enabled: releaseChecker != null,
              child: SecondTickScope(
                child: YahagiShell(
                  layoutSettingsController: layoutSettingsController,
                  networkSettingsController: networkSettingsController,
                  gadgetBypassController: gadgetBypassController,
                  safetySettingsController: safetySettingsController,
                  notificationSettingsController:
                      notificationSettingsController,
                  battlePredictionSettingsController:
                      battlePredictionSettingsController,
                  gameFrameRateSettingsController:
                      gameFrameRateSettingsController,
                  gameRenderingModeController: gameRenderingModeController,
                  gameConnectorController: gameConnectorController,
                  backgroundGameRetentionController:
                      backgroundGameRetentionController,
                  displayModeController: displayModeController,
                  controller: controller,
                  browserController: browserController,
                  captureModeController: captureModeController,
                  audioController: audioController,
                  toolbarController: toolbarController,
                  gameCaptureController: gameCaptureController,
                  kcwikiReportController: kcwikiReportController,
                  kcwikiReportConsumer: kcwikiReportConsumer,
                  gameStateController: gameStateController,
                  newShipReminderController: newShipReminderController,
                  moraleRecoveryTimerController: moraleRecoveryTimerController,
                  gameResourceCacheController: gameResourceCacheController,
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
                  diagnosticController: diagnosticController,
                  gameSurface: _buildGameSurface(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameSurface() {
    Widget withBattleWarning(Widget child) => BattleResultWarningOverlay(
      gameCaptureController: gameCaptureController,
      loadSafetyState: () async {
        await gameApiEventPipeline?.dispatchIdle;
        await battleController.idle;
        await gameStateController.idle;
        return gameStateController.state;
      },
      safetySettingsController: safetySettingsController,
      damageAlertPort: const MethodChannelBattleDamageAlertPort(),
      child: child,
    );

    if (gameSurface case final injected?) {
      return withBattleWarning(injected);
    }
    final renderingController = gameRenderingModeController;
    if (renderingController == null) {
      return buildGameSurfaceForRenderingMode(
        mode: GameRenderingMode.compatibility,
        key: const GlobalObjectKey('yahagi_game_webview'),
        buildNativeActivityGameSurface: _buildNativeActivityGameSurface,
        buildGameWebView: (key, mode) =>
            _buildGameWebView(key, renderingMode: mode),
        withBattleWarning: withBattleWarning,
      );
    }
    return GameEnvironmentHost(
      controller: renderingController,
      beforeRestart: _waitForCaptureQueues,
      applicationRestartPort: const MethodChannelGameApplicationRestartPort(),
      gameBuilder: (context, mode, key) => buildGameSurfaceForRenderingMode(
        mode: mode,
        key: key,
        buildNativeActivityGameSurface: _buildNativeActivityGameSurface,
        buildGameWebView: (key, mode) =>
            _buildGameWebView(key, renderingMode: mode),
        withBattleWarning: withBattleWarning,
      ),
    );
  }

  Widget _buildNativeActivityGameSurface(Key key) => NativeActivityGameSurface(
    key: key,
    onGenerationChanged: nativeWebViewGenerationSink,
    statusController: controller,
    browserController: browserController,
    toolbarController: toolbarController,
    routeObserver: gameRouteObserver ?? yahagiGameRouteObserver,
    networkSettingsController: networkSettingsController,
    captureModeController: captureModeController,
    audioController: audioController,
    gameCaptureController: gameCaptureController,
    frameRateSettingsController: gameFrameRateSettingsController,
  );

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
            GameRenderingMode.compatibility,
      );

  Future<void> _waitForCaptureQueues() async {
    try {
      await (() async {
        await Future.wait<void>([
          ?gameApiEventPipeline?.idle,
          gameStateController.idle,
          ?senkaController?.idle,
          battleController.idle,
        ]);
        // Snapshot this queue only after all captures have scheduled their logs.
        await gameStateController.logbookIdle;
      })().timeout(const Duration(seconds: 5));
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
    this.notificationSettingsController,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.gameRenderingModeController,
    this.gameConnectorController,
    this.backgroundGameRetentionController,
    this.backgroundGameRetentionPort,
    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameSurface,
    required this.gameCaptureController,
    this.kcwikiReportController,
    this.kcwikiReportConsumer,
    required this.gameStateController,
    this.newShipReminderController,
    this.moraleRecoveryTimerController,
    this.gameResourceCacheController,
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
    this.diagnosticController,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final SafetySettingsController safetySettingsController;
  final NotificationSettingsController? notificationSettingsController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final GameRenderingModeController? gameRenderingModeController;
  final GameConnectorController? gameConnectorController;
  final BackgroundGameRetentionController? backgroundGameRetentionController;
  final BackgroundGameRetentionPort? backgroundGameRetentionPort;
  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final Widget gameSurface;
  final GameCaptureController gameCaptureController;
  final KcwikiReportController? kcwikiReportController;
  final KcwikiReportConsumer? kcwikiReportConsumer;
  final GameStateController gameStateController;
  final NewShipReminderController? newShipReminderController;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final GameResourceCacheController? gameResourceCacheController;
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
  final DiagnosticController? diagnosticController;

  @override
  State<YahagiShell> createState() => _YahagiShellState();
}

class _YahagiShellState extends State<YahagiShell> with WidgetsBindingObserver {
  final WindowMetricsRecoveryScheduler _windowMetricsRecoveryScheduler =
      WindowMetricsRecoveryScheduler();
  WindowMetricsChangeTracker? _windowMetricsChangeTracker;
  int _workspaceIndex = 0;
  int? _expeditionCheckFleetId;
  int? _fleetCenterInitialFleetId;
  int? _repairCenterInitialFleetId;
  int? _questCenterInitialQuestId;
  bool _inventoryShowShips = true;
  bool _inventoryShowOwned = true;
  bool _newShipDialogScheduled = false;
  int _logbookTabIndex = 0;
  int _settingsTabIndex = 0;
  RepairCenterMode _repairCenterMode = RepairCenterMode.dock;
  QuestCenterMode _questCenterMode = QuestCenterMode.active;
  bool _questTranslationEnabled = false;
  final QuestFilterController _questFilters = QuestFilterController();
  ExpeditionSummaryMode _expeditionCenterMode = ExpeditionSummaryMode.summary;
  ConstructionCenterMode _constructionCenterMode =
      ConstructionCenterMode.construction;
  DevelopmentWorkbenchMode _developmentWorkbenchMode =
      DevelopmentWorkbenchMode.calculator;
  SenkaCenterMode _senkaCenterMode = SenkaCenterMode.info;
  ToolboxMode _toolboxMode = ToolboxMode.export;
  final DevelopmentRepository _developmentRepository = DevelopmentRepository();
  BackgroundGameRetentionCoordinator? _backgroundGameRetentionCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.displayModeController.addListener(_applyOrientationPolicy);
    widget.layoutSettingsController.addListener(_onLayoutSettingsChanged);
    widget.newShipReminderController?.addListener(_handleNewShipAlert);
    if (widget.backgroundGameRetentionController case final controller?) {
      _backgroundGameRetentionCoordinator = BackgroundGameRetentionCoordinator(
        controller: controller,
        toolbarController: widget.toolbarController,
        port:
            widget.backgroundGameRetentionPort ??
            const MethodChannelBackgroundGameRetentionPort(),
      );
    }
    _applyOrientationPolicy();
  }

  @override
  void dispose() {
    widget.displayModeController.removeListener(_applyOrientationPolicy);
    widget.layoutSettingsController.removeListener(_onLayoutSettingsChanged);
    widget.newShipReminderController?.removeListener(_handleNewShipAlert);
    widget.kcwikiReportConsumer?.dispose();
    _questFilters.dispose();
    _windowMetricsRecoveryScheduler.dispose();
    _backgroundGameRetentionCoordinator?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleNewShipAlert() {
    final controller = widget.newShipReminderController;
    final alert = controller?.currentAlert;
    if (alert == null || _newShipDialogScheduled || !mounted) return;
    _newShipDialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = widget.gameStateController.state;
      final l10n = AppLocalizations.of(context)!;
      final names = alert.masterIds
          .map(
            (id) => state.masterShips[id]?.name ?? l10n.newShipFallbackName(id),
          )
          .toList(growable: false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('new-ship-alert-dialog'),
          title: Text(l10n.newShipAlertTitle),
          content: Text(l10n.newShipAlertBody(names.join('、'))),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.acknowledge),
            ),
          ],
        ),
      );
      controller?.acknowledge(alert.key);
      _newShipDialogScheduled = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _windowMetricsChangeTracker ??= WindowMetricsChangeTracker(
      WindowMetricsSnapshot.fromView(View.of(context)),
    );
  }

  void _onLayoutSettingsChanged() {
    widget.browserController.fitGameScreen().catchError((Object _) {});
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final current = WindowMetricsSnapshot.fromView(View.of(context));
    final tracker = _windowMetricsChangeTracker;
    if (tracker != null) {
      final change = tracker.update(current);
      if (change == WindowMetricsChange.imeOnly) {
        _windowMetricsRecoveryScheduler.cancel();
        return;
      }
      if (change == WindowMetricsChange.unchanged) {
        return;
      }
    } else {
      _windowMetricsChangeTracker = WindowMetricsChangeTracker(current);
    }
    _applyOrientationPolicy();
    _scheduleWindowMetricsRecovery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.audioController.handleLifecycleState(state);
    widget.screenAwakeController?.handleLifecycleState(state);
    _backgroundGameRetentionCoordinator?.handleLifecycleState(state);
  }

  void _scheduleWindowMetricsRecovery() {
    _windowMetricsRecoveryScheduler.schedule(() {
      if (!mounted) return;
      final tracker = _windowMetricsChangeTracker;
      if (tracker?.isImeVisible ?? false) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (tracker?.isImeVisible ?? false) return;
        tracker?.markCurrentGeometryStable();
        widget.browserController.fitGameScreen().catchError((Object _) {});
      });
    });
  }

  void _applyOrientationPolicy() {
    applyOrientationPolicy(
      currentWindowSize(),
      widget.displayModeController.displayMode,
    );
  }

  void _selectWorkspace(int index) {
    if (index != 0) {
      widget.toolbarController.collapse();
    }
    if (_workspaceIndex != index) {
      setState(() => _workspaceIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildHeaderToolbar() => AnimatedBuilder(
      animation: Listenable.merge([
        widget.browserController,
        widget.audioController,
        ?widget.gameRenderingModeController,
      ]),
      builder: (context, _) => GameBrowserToolbar(
        enableBackdropBlur:
            widget.gameRenderingModeController?.mode.enablesToolbarBlur ?? true,
        interactionEnabled:
            !(widget.gameRenderingModeController?.isBusy ?? false),
        mode: widget.browserController.mode,
        loadState: widget.browserController.loadState,
        displayAddress: widget.browserController.displayAddress,
        onBack: () async {
          await widget.browserController.goBack();
        },
        onReload: () async {
          await showGameRefreshDialog(
            context: context,
            onRefreshPage: widget.browserController.reload,
            onReloadGame: widget.browserController.reloadGameFrame,
          );
        },
        onHome: () async {
          await widget.browserController.goHome();
        },
        onEnterDmm: () async {
          await widget.browserController.enterDmmLoginTest();
        },
        isMuted: widget.audioController.isMuted,
        audioEnabled: widget.audioController.canToggle,
        onToggleMuted: () async {
          await widget.audioController.toggleMuted();
        },
        onCollapse: widget.toolbarController.collapse,
        onFitScreen: () {
          widget.browserController.fitGameScreen();
        },
        onScreenshot: widget.gameScreenshotController == null
            ? null
            : () async {
                final l10n = AppLocalizations.of(context)!;
                TopNotice.show(context, message: l10n.screenshotSaving);
                await WidgetsBinding.instance.endOfFrame;
                if (!context.mounted) return;
                final result = await widget.gameScreenshotController!.capture();
                if (!context.mounted) return;
                final message = result.path != null
                    ? l10n.screenshotSaved(result.path!)
                    : result.errorMessage == null
                    ? l10n.screenshotFailed
                    : '${l10n.screenshotFailed}\n${result.errorMessage}';
                TopNotice.show(
                  context,
                  message: message,
                  tone: result.path != null
                      ? TopNoticeTone.success
                      : TopNoticeTone.error,
                );
              },
        persistent: false,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        left: false,
        right: false,
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                color: Color(0xff122431),
                border: Border(bottom: BorderSide(color: Color(0xff294052))),
              ),
              child: AnimatedBuilder(
                animation: widget.toolbarController,
                builder: (context, _) {
                  final isGameWorkspace = _workspaceIndex == 0;
                  final isToolbarVisible =
                      isGameWorkspace && widget.toolbarController.isVisible;
                  return Row(
                    children: [
                      Material(
                        color: isToolbarVisible
                            ? const Color(0xff1a3447)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          key: const Key('yahagi-brand-button'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: isGameWorkspace
                              ? widget.toolbarController.toggle
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
                                if (isGameWorkspace) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    isToolbarVisible
                                        ? Icons.chevron_left
                                        : Icons.chevron_right,
                                    size: 16,
                                    color: isToolbarVisible
                                        ? const Color(0xffd4a85f)
                                        : const Color(0xff8197a5),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isToolbarVisible ? 0.0 : 1.0,
                              child: IgnorePointer(
                                ignoring: isToolbarVisible,
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
                                        : () => _selectWorkspace(9),
                                    anchorageRepairStartedAt: widget
                                        .gameStateController
                                        .anchorageRepairStartedAt,
                                    onAnchorageTimerTap: () {
                                      final startedAt = widget
                                          .gameStateController
                                          .anchorageRepairStartedAt;
                                      final now = DateTime.now().toUtc();
                                      final elapsed =
                                          startedAt == null ||
                                              now.isBefore(startedAt)
                                          ? Duration.zero
                                          : now.difference(startedAt);
                                      final fleetId =
                                          preferredAnchorageRepairFleetId(
                                            state: widget
                                                .gameStateController
                                                .state,
                                            elapsed: elapsed,
                                          );
                                      setState(() {
                                        _repairCenterMode =
                                            RepairCenterMode.anchorage;
                                        _repairCenterInitialFleetId = fleetId;
                                      });
                                      _selectWorkspace(3);
                                    },
                                    nosakiSparkleStartedAt: widget
                                        .gameStateController
                                        .nosakiSparkleStartedAt,
                                    onNosakiTimerTap: () {
                                      final startedAt = widget
                                          .gameStateController
                                          .nosakiSparkleStartedAt;
                                      final now = DateTime.now().toUtc();
                                      final elapsed =
                                          startedAt == null ||
                                              now.isBefore(startedAt)
                                          ? Duration.zero
                                          : now.difference(startedAt);
                                      final fleetId =
                                          NosakiSparkleCalculator.preferredNosakiSparkleFleetId(
                                            state: widget
                                                .gameStateController
                                                .state,
                                            elapsed: elapsed,
                                          );
                                      setState(() {
                                        _repairCenterMode =
                                            RepairCenterMode.nosaki;
                                        _repairCenterInitialFleetId = fleetId;
                                      });
                                      _selectWorkspace(3);
                                    },
                                    layoutSettingsController:
                                        widget.layoutSettingsController,
                                    selectedFleetId:
                                        _fleetCenterInitialFleetId ?? 1,
                                    onFleetSelected: (fleetId) {
                                      setState(() {
                                        _fleetCenterInitialFleetId = fleetId;
                                      });
                                    },
                                    inventoryShowShips: _inventoryShowShips,
                                    inventoryShowOwned: _inventoryShowOwned,
                                    onInventoryOwnershipChanged: (value) {
                                      setState(
                                        () => _inventoryShowOwned = value,
                                      );
                                    },
                                    onInventorySectionChanged: (value) {
                                      setState(
                                        () => _inventoryShowShips = value,
                                      );
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
                                    questTranslationEnabled:
                                        _questTranslationEnabled,
                                    onQuestTranslationChanged: (enabled) {
                                      setState(
                                        () =>
                                            _questTranslationEnabled = enabled,
                                      );
                                    },
                                    onQuestModeChanged: (mode) {
                                      setState(() => _questCenterMode = mode);
                                    },
                                    expeditionMode: _expeditionCenterMode,
                                    onExpeditionModeChanged: (mode) {
                                      setState(
                                        () => _expeditionCenterMode = mode,
                                      );
                                    },
                                    constructionMode: _constructionCenterMode,
                                    onConstructionModeChanged: (mode) {
                                      setState(() {
                                        _constructionCenterMode = mode;
                                        if (mode ==
                                            ConstructionCenterMode
                                                .development) {
                                          _developmentWorkbenchMode =
                                              DevelopmentWorkbenchMode
                                                  .calculator;
                                        }
                                      });
                                    },
                                    developmentMode: _developmentWorkbenchMode,
                                    onDevelopmentModeChanged: (mode) {
                                      setState(
                                        () => _developmentWorkbenchMode = mode,
                                      );
                                    },
                                    senkaMode: _senkaCenterMode,
                                    toolboxMode: _toolboxMode,
                                    onToolboxModeChanged: (mode) {
                                      setState(() => _toolboxMode = mode);
                                    },
                                    onSenkaModeChanged: (mode) {
                                      setState(() => _senkaCenterMode = mode);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: !isToolbarVisible,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                reverseDuration: const Duration(
                                  milliseconds: 200,
                                ),
                                transitionBuilder: (child, animation) {
                                  final slide =
                                      Tween<Offset>(
                                        begin: const Offset(-0.2, 0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      );
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: isToolbarVisible
                                    ? KeyedSubtree(
                                        key: const Key('game-toolbar-visible'),
                                        child: buildHeaderToolbar(),
                                      )
                                    : const SizedBox.shrink(
                                        key: Key('game-toolbar-hidden'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: Row(
                textDirection: workspaceNavigationTextDirection(
                  menuOnRight:
                      widget.layoutSettingsController.workspaceMenuOnRight,
                ),
                children: [
                  QuestCompletionFeedback(
                    controller: widget.gameStateController,
                    builder: (context, completedCount) => WorkspaceNavigation(
                      controller: widget.layoutSettingsController,
                      selectedIndex: _workspaceIndex,
                      onRight:
                          widget.layoutSettingsController.workspaceMenuOnRight,
                      onSelected: _selectWorkspace,
                      completedQuestCount: completedCount,
                      gameStateController: widget.gameStateController,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GameWorkspaceActive(
                          active: _workspaceIndex == 0,
                          child: TickerMode(
                            enabled: _workspaceIndex == 0,
                            child: Offstage(
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
                                  final gameFlex = (gameAreaRatio * 1000)
                                      .round();
                                  final portraitGamePanelExtra =
                                      portraitGamePanelExtraExtent(
                                        displayMode: widget
                                            .toolbarDisplayController
                                            ?.mode,
                                        renderingMode: widget
                                            .gameRenderingModeController
                                            ?.mode,
                                      );
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
                                  final gameWidget = GameBrowserOverlay(
                                    controller: widget.toolbarController,
                                    gameSurface: gameSurfaceWrapper,
                                  );

                                  final infoWidget = _InformationPanel(
                                    layoutSettingsController:
                                        widget.layoutSettingsController,
                                    safetySettingsController:
                                        widget.safetySettingsController,
                                    controller: widget.controller,
                                    browserController: widget.browserController,
                                    captureModeController:
                                        widget.captureModeController,
                                    gameCaptureController:
                                        widget.gameCaptureController,
                                    gameStateController:
                                        widget.gameStateController,
                                    moraleRecoveryTimerController:
                                        widget.moraleRecoveryTimerController,
                                    battleController: widget.battleController,
                                    battlePredictionSettingsController: widget
                                        .battlePredictionSettingsController,
                                    onOpenFleet: (fleetId) {
                                      setState(() {
                                        _fleetCenterInitialFleetId = fleetId;
                                      });
                                      _selectWorkspace(1);
                                    },
                                    onOpenRepair: (destination) {
                                      setState(() {
                                        _repairCenterMode = destination.mode;
                                        _repairCenterInitialFleetId =
                                            destination.fleetId;
                                      });
                                      _selectWorkspace(3);
                                    },
                                    onOpenConstruction: () =>
                                        _selectWorkspace(4),
                                    onOpenExpedition: () => _selectWorkspace(2),
                                    onOpenQuest: (questId) {
                                      setState(() {
                                        _questCenterInitialQuestId = questId;
                                      });
                                      _selectWorkspace(5);
                                    },
                                    onOpenExpeditionCheck: (fleetId) {
                                      setState(() {
                                        _expeditionCheckFleetId = fleetId;
                                        _expeditionCenterMode =
                                            ExpeditionSummaryMode.check;
                                      });
                                      _selectWorkspace(2);
                                    },
                                  );

                                  const dividerExtent = 1.0;
                                  final availableWidth =
                                      constraints.maxWidth - dividerExtent;
                                  final gamePanelExtent = isLandscape
                                      ? availableWidth * gameFlex / 1000
                                      : (constraints.maxWidth * 720 / 1200 +
                                                portraitGamePanelExtra)
                                            .clamp(
                                              0.0,
                                              constraints.maxHeight -
                                                  dividerExtent,
                                            )
                                            .toDouble();

                                  final infoOnLeft =
                                      isLandscape &&
                                      widget
                                          .layoutSettingsController
                                          .informationPanelOnLeft;
                                  final infoPanelExtent =
                                      availableWidth - gamePanelExtent;

                                  return Stack(
                                    children: [
                                      Positioned(
                                        left: infoOnLeft
                                            ? infoPanelExtent + dividerExtent
                                            : 0,
                                        top: 0,
                                        width: isLandscape
                                            ? gamePanelExtent
                                            : constraints.maxWidth,
                                        height: isLandscape
                                            ? constraints.maxHeight
                                            : gamePanelExtent,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: const Color(0xff0a1823),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black38,
                                                offset: isLandscape
                                                    ? Offset(
                                                        infoOnLeft ? -2 : 2,
                                                        0,
                                                      )
                                                    : const Offset(0, 2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: gameWidget,
                                        ),
                                      ),
                                      Positioned(
                                        left: isLandscape
                                            ? (infoOnLeft
                                                  ? infoPanelExtent
                                                  : gamePanelExtent)
                                            : 0,
                                        top: isLandscape ? 0 : gamePanelExtent,
                                        width: isLandscape
                                            ? dividerExtent
                                            : constraints.maxWidth,
                                        height: isLandscape
                                            ? constraints.maxHeight
                                            : dividerExtent,
                                        child: isLandscape
                                            ? const VerticalDivider(
                                                width: dividerExtent,
                                                thickness: dividerExtent,
                                                color: Color(0xff294052),
                                              )
                                            : const Divider(
                                                height: dividerExtent,
                                                thickness: dividerExtent,
                                                color: Color(0xff294052),
                                              ),
                                      ),
                                      Positioned(
                                        left: isLandscape
                                            ? (infoOnLeft
                                                  ? 0
                                                  : gamePanelExtent +
                                                        dividerExtent)
                                            : 0,
                                        top: isLandscape
                                            ? 0
                                            : gamePanelExtent + dividerExtent,
                                        right: infoOnLeft
                                            ? gamePanelExtent + dividerExtent
                                            : 0,
                                        bottom: 0,
                                        child: Padding(
                                          key: const Key(
                                            'workspace-information-panel',
                                          ),
                                          padding: isLandscape
                                              ? (infoOnLeft
                                                    ? const EdgeInsets.only(
                                                        right: 4,
                                                      )
                                                    : const EdgeInsets.only(
                                                        left: 4,
                                                      ))
                                              : const EdgeInsets.only(top: 4),
                                          child: infoWidget,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_workspaceIndex == 1)
                          FleetInformationCenter(
                            controller: widget.gameStateController,
                            moraleRecoveryTimerController:
                                widget.moraleRecoveryTimerController,
                            moraleMetricMode: widget
                                .layoutSettingsController
                                .fleetMoraleMetricMode,
                            onToggleMoraleMetricMode: widget
                                .layoutSettingsController
                                .toggleFleetMoraleMetricMode,
                            damagePulseMode: widget
                                .safetySettingsController
                                .battleStatusEffects
                                .pulseFilterFor(BattleEffectSurface.fleet),
                            moraleSparkleEnabled: widget
                                .safetySettingsController
                                .battleStatusEffects
                                .sparkleEnabledFor(BattleEffectSurface.fleet),
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
                            developmentRepository: _developmentRepository,
                            developmentMode: _developmentWorkbenchMode,
                            onDevelopmentModeChanged: (mode) {
                              setState(() => _developmentWorkbenchMode = mode);
                            },
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
                            translationEnabled: _questTranslationEnabled,
                            onTranslationChanged: (enabled) {
                              setState(
                                () => _questTranslationEnabled = enabled,
                              );
                            },
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
                            reminderController:
                                widget.newShipReminderController,
                            showOwned: _inventoryShowOwned,
                            onOwnershipChanged: (value) {
                              setState(() => _inventoryShowOwned = value);
                            },
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
                            kcwikiReportController:
                                widget.kcwikiReportController,
                            prototypeStatusController: widget.controller,
                            gameStateController: widget.gameStateController,
                            senkaController: widget.senkaController,
                            gameResourceCacheController:
                                widget.gameResourceCacheController,
                            safetySettingsController:
                                widget.safetySettingsController,
                            notificationSettingsController:
                                widget.notificationSettingsController,
                            battlePredictionSettingsController:
                                widget.battlePredictionSettingsController,
                            gameFrameRateSettingsController:
                                widget.gameFrameRateSettingsController,
                            gameRenderingModeController:
                                widget.gameRenderingModeController,
                            gameConnectorController:
                                widget.gameConnectorController,
                            backgroundGameRetentionController:
                                widget.backgroundGameRetentionController,
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
                            diagnosticController: widget.diagnosticController,
                            selectedIndex: _settingsTabIndex,
                          ),
                        if (_workspaceIndex == 9 &&
                            widget.senkaController != null)
                          SenkaPage(
                            controller: widget.senkaController!,
                            mode: _senkaCenterMode,
                            onOpenSortieLog: () {
                              setState(() => _logbookTabIndex = 0);
                              _selectWorkspace(6);
                            },
                          ),
                        if (_workspaceIndex == 10)
                          AnimatedBuilder(
                            animation: widget.gameStateController,
                            builder: (context, _) => ToolboxPage(
                              state: widget.gameStateController.state,
                              mode: _toolboxMode,
                            ),
                          ),
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

class WorkspaceNavigation extends StatelessWidget {
  const WorkspaceNavigation({
    super.key,
    required this.controller,
    required this.selectedIndex,
    required this.onRight,
    required this.onSelected,
    this.completedQuestCount = 0,
    this.gameStateController,
    this.clock,
  });

  final LayoutSettingsController controller;
  final int selectedIndex;
  final bool onRight;
  final ValueChanged<int> onSelected;
  final int completedQuestCount;
  final GameStateController? gameStateController;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SecondTickBuilder(
      now: clock,
      enabled: gameStateController != null,
      builder: (context, now, _) => Container(
        width: 58,
        decoration: BoxDecoration(
          color: const Color(0xff0a1823),
          border: workspaceNavigationBorder(menuOnRight: onRight),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            controller,
            if (gameStateController != null) gameStateController!,
          ]),
          builder: (context, _) {
            final destinations = _workspaceDestinations(l10n);
            final ordered = controller.workspaceMenuOrder
                .map((id) => destinations[id])
                .whereType<_WorkspaceDestination>()
                .toList(growable: false);
            return ReorderableListView.builder(
              key: const Key('workspace-navigation-list'),
              padding: const EdgeInsets.symmetric(vertical: 10),
              buildDefaultDragHandles: false,
              itemCount: ordered.length,
              onReorderItem: controller.reorderWorkspaceMenu,
              itemBuilder: (context, index) {
                final destination = ordered[index];
                return SizedBox(
                  key: ValueKey('workspace-nav-item-${destination.id}'),
                  height: 50,
                  child: Center(
                    child: ReorderableDelayedDragStartListener(
                      index: index,
                      child: _NavigationButton(
                        key: Key('workspace-nav-${destination.id}'),
                        icon: destination.icon,
                        label: destination.label,
                        completedCount: switch (destination.id) {
                          'quests' => completedQuestCount,
                          'construction' =>
                            gameStateController?.state.constructionDocks
                                    .where((dock) => dock.isCompletedAt(now))
                                    .length ??
                                0,
                          'repair' =>
                            gameStateController?.state.repairDocks
                                    .where(
                                      (dock) =>
                                          dock.isRepairing &&
                                          (dock.completionTime == null ||
                                              now.isBefore(
                                                dock.completionTime!,
                                              )),
                                    )
                                    .length ??
                                0,
                          _ => 0,
                        },
                        countKey: Key(
                          '${destination.id == 'repair' ? 'repair-active' : '${destination.id == 'quests' ? 'quest' : destination.id}-completion'}-count',
                        ),
                        countLabel: destination.id == 'quests'
                            ? null
                            : destination.label,
                        selected: selectedIndex == destination.pageIndex,
                        onTap: () => onSelected(destination.pageIndex),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

final class _WorkspaceDestination {
  const _WorkspaceDestination({
    required this.id,
    required this.pageIndex,
    required this.icon,
    required this.label,
  });

  final String id;
  final int pageIndex;
  final IconData icon;
  final String label;
}

Map<String, _WorkspaceDestination> _workspaceDestinations(
  AppLocalizations l10n,
) => <String, _WorkspaceDestination>{
  'game': _WorkspaceDestination(
    id: 'game',
    pageIndex: 0,
    icon: Icons.videogame_asset_outlined,
    label: l10n.game,
  ),
  'fleet': _WorkspaceDestination(
    id: 'fleet',
    pageIndex: 1,
    icon: Icons.directions_boat_outlined,
    label: l10n.fleet,
  ),
  'expedition': _WorkspaceDestination(
    id: 'expedition',
    pageIndex: 2,
    icon: Icons.explore_outlined,
    label: l10n.expedition,
  ),
  'repair': _WorkspaceDestination(
    id: 'repair',
    pageIndex: 3,
    icon: Icons.build_circle_outlined,
    label: l10n.repair,
  ),
  'construction': _WorkspaceDestination(
    id: 'construction',
    pageIndex: 4,
    icon: Icons.handyman_outlined,
    label: l10n.construction,
  ),
  'quests': _WorkspaceDestination(
    id: 'quests',
    pageIndex: 5,
    icon: Icons.assignment_outlined,
    label: l10n.quests,
  ),
  'senka': _WorkspaceDestination(
    id: 'senka',
    pageIndex: 9,
    icon: Icons.emoji_events_outlined,
    label: l10n.senka,
  ),
  'battle-records': _WorkspaceDestination(
    id: 'battle-records',
    pageIndex: 6,
    icon: Icons.menu_book_outlined,
    label: l10n.battleRecords,
  ),
  'owned-inventory': _WorkspaceDestination(
    id: 'owned-inventory',
    pageIndex: 7,
    icon: Icons.inventory_2_outlined,
    label: l10n.ownedInventory,
  ),
  'tools': _WorkspaceDestination(
    id: 'tools',
    pageIndex: 10,
    icon: Icons.widgets_outlined,
    label: l10n.toolbox,
  ),
  'settings': _WorkspaceDestination(
    id: 'settings',
    pageIndex: 8,
    icon: Icons.settings_outlined,
    label: l10n.settings,
  ),
};

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.completedCount = 0,
    this.countKey = const Key("quest-completion-count"),
    this.countLabel,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int completedCount;
  final Key countKey;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.manual,
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
        icon: QuestCompletionBadge(
          count: completedCount,
          countKey: countKey,
          semanticLabel: countLabel == null
              ? null
              : "$countLabel: $completedCount",
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _InformationPanel extends StatefulWidget {
  const _InformationPanel({
    required this.layoutSettingsController,
    required this.safetySettingsController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.gameCaptureController,
    required this.gameStateController,
    required this.moraleRecoveryTimerController,
    required this.battleController,
    required this.battlePredictionSettingsController,
    required this.onOpenFleet,
    required this.onOpenRepair,
    required this.onOpenConstruction,
    required this.onOpenExpedition,
    required this.onOpenQuest,
    required this.onOpenExpeditionCheck,
  });

  final LayoutSettingsController layoutSettingsController;
  final SafetySettingsController safetySettingsController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameCaptureController gameCaptureController;
  final GameStateController gameStateController;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final BattleController battleController;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
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
          widget.safetySettingsController,
          widget.browserController,
          widget.gameCaptureController,
          if (widget.battlePredictionSettingsController != null)
            widget.battlePredictionSettingsController!,
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
                onOpenDisplaySettings: _isEditing
                    ? () => showFleetDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                      )
                    : null,
                visible: widget.layoutSettingsController.fleetDisplayFields,
                controller: widget.gameStateController,
                moraleRecoveryTimerController:
                    widget.moraleRecoveryTimerController,
                damagePulseFilter: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .pulseFilterFor(BattleEffectSurface.fleet),
                moraleSparkleEnabled: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .sparkleEnabledFor(BattleEffectSurface.fleet),
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
                onOpenFleet: widget.onOpenFleet,
              ),
              'land_base' => LandBaseSummaryCard(
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'land_base',
                ),
                onOpenDisplaySettings: _isEditing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'land_base',
                      )
                    : null,
                controller: widget.gameStateController,
                damagePulseMode: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .pulseFilterFor(BattleEffectSurface.fleet),
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
              ),
              'expedition' => ExpeditionSummaryCard(
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'expedition',
                ),
                onOpenDisplaySettings: _isEditing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'expedition',
                      )
                    : null,
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
                onOpenExpedition: widget.onOpenExpedition,
                onOpenExpeditionCheck: widget.onOpenExpeditionCheck,
              ),

              'repair' => RepairSummaryCard(
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'repair',
                ),
                onOpenDisplaySettings: _isEditing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'repair',
                      )
                    : null,
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
                onOpenRepair: widget.onOpenRepair,
              ),
              'construction' => ConstructionSummaryCard(
                visible: widget.layoutSettingsController.moduleDisplayFields(
                  'construction',
                ),
                onOpenDisplaySettings: _isEditing
                    ? () => showModuleDisplaySettings(
                        context,
                        widget.layoutSettingsController,
                        'construction',
                      )
                    : null,
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
                onOpenConstruction: widget.onOpenConstruction,
              ),
              'quests' => PinnedQuestsSummary(
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
                onOpenQuest: widget.onOpenQuest,
              ),
              'battle' => LiveBattleCard(
                key: const PageStorageKey('dashboard-live-battle'),
                controller: widget.battleController,
                showEnemyPortraits:
                    widget
                        .battlePredictionSettingsController
                        ?.enemyPortraitsEnabled ??
                    true,
                showLastFormationHint:
                    widget
                        .battlePredictionSettingsController
                        ?.lastFormationHintEnabled ??
                    true,
                damagePulseMode: widget
                    .safetySettingsController
                    .battleStatusEffects
                    .pulseFilterFor(BattleEffectSurface.prediction),
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
              ),
              'pre_sortie' => PreSortieCheckSummary(
                key: const PageStorageKey('dashboard-pre-sortie'),
                controller: widget.gameStateController,
                collapsed: isCollapsed,
                onToggleCollapse: _isEditing ? () {} : toggle,
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
                            child: IgnorePointer(
                              ignoring: !{
                                'fleet',
                                'land_base',
                                'repair',
                                'construction',
                                'expedition',
                              }.contains(id),
                              child: child,
                            ),
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
                            subtitle: runtimeMessageText(
                              context,
                              widget.gameCaptureController.errorMessage ??
                                  widget.browserController.errorMessage ??
                                  AppLocalizations.of(
                                    context,
                                  )!.gameStatusErrorDesc,
                            ),
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
