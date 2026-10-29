import 'src/theme/app_palette.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/widgets/app_scroll_behavior.dart';
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
import 'src/battle/battle_models.dart';
import 'src/battle/battle_damage_alert.dart';
import 'src/battle/fcd_map_controller.dart';
import 'src/battle/fcd_map_store.dart';
import 'src/battle/fcd_map_update_service.dart';
import 'src/battle/formation_memory.dart';
import 'src/logbook/logbook_database.dart';
import 'src/fleet/resource_grid.dart';
import 'src/logbook/logbook_page.dart';
import 'src/battle/live_battle_card.dart';
import 'src/audio/game_audio_controller.dart';
import 'src/audio/game_audio_store.dart';
import 'src/browser/game_browser_controller.dart';
import 'src/browser/game_load_event.dart';
import 'src/browser/gadget_bypass_controller.dart';
import 'src/browser/gadget_bypass_store.dart';
import 'src/browser/game_browser_overlay.dart';
import 'src/browser/game_browser_menu.dart';
import 'src/browser/game_browser_toolbar.dart';
import 'src/browser/game_fullscreen_controls.dart';
import 'src/browser/app_exit_guard.dart';
import 'src/settings/app_exit_settings.dart';
import 'src/browser/game_frame_reload_port.dart';
import 'src/browser/game_frame_rate_port.dart';
import 'src/browser/game_refresh_dialog.dart';
import 'src/browser/game_toolbar_controller.dart';
import 'src/browser/game_toolbar_display_controller.dart';
import 'src/browser/game_screenshot_controller.dart';
import 'src/browser/game_surface_boundary.dart';
import 'src/browser/game_surface_viewport.dart';
import 'src/browser/game_workspace_visibility.dart';
import 'src/browser/game_environment_host.dart';
import 'src/browser/game_application_restart_port.dart';
import 'src/browser/game_resource_cache_controller.dart';
import 'src/browser/game_resource_manifest_builder.dart';
import 'src/browser/game_resource_manifest_consumer.dart';
import 'src/subtitles/ship_subtitle_settings.dart';
import 'src/subtitles/ship_subtitle_catalog_controller.dart';
import 'src/subtitles/ship_subtitle_runtime_controller.dart';
import 'src/browser/native_game_surface_slot.dart';
import 'src/browser/native_game_warning_dialog.dart';
import 'src/browser/game_dialog_presentation_scope.dart';
import 'src/browser/game_reminder_dialog.dart';
import 'src/capture/battle_result_warning_overlay.dart';
import 'src/capture/capture_mode_controller.dart';
import 'src/capture/capture_mode_store.dart';
import 'src/capture/game_capture_controller.dart';
import 'src/notice/game_info_notice_controller.dart';
import 'src/notice/debuff_reminder_controller.dart';
import 'src/notice/debuff_reminder_feedback.dart';
import 'src/capture/game_capture_port.dart';
import 'src/diagnostics/diagnostic_controller.dart';
import 'src/diagnostics/diagnostic_event.dart';
import 'src/diagnostics/diagnostic_export_service.dart';
import 'src/diagnostics/diagnostic_game_api_observer.dart';
import 'src/diagnostics/diagnostic_performance_monitor.dart';
import 'src/diagnostics/diagnostic_platform_port.dart';
import 'src/telemetry/telemetry_controller.dart';
import 'src/telemetry/telemetry_service.dart';
import 'src/telemetry/telemetry_settings_store.dart';
import 'src/diagnostics/diagnostic_recorder.dart';
import 'src/diagnostics/diagnostic_settings_store.dart';
import 'src/diagnostics/diagnostic_storage.dart';
import 'src/development/development_repository.dart';
import 'src/fleet/fleet_information_center.dart';
import 'src/settings/battle_status_effect_settings.dart';
import 'src/settings/header_resource_settings.dart';
import 'src/settings/workspace_menu_settings.dart';
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
import 'src/account/account_session.dart';
import 'src/backup/record_backup.dart';
import 'src/localization/record_backup_strings.dart';
import 'src/localization/game_name_catalog.dart';
import 'src/localization/game_name_localizations.dart';
import 'src/game_state/game_api_event_pipeline.dart';
import 'src/game_state/game_state_store.dart';
import 'src/layout/adaptive_layout.dart';
import 'src/layout/display_corners.dart';
import 'src/layout/hd_workspace_geometry.dart';
import 'src/layout/minimal_layout.dart';
import 'src/layout/ui_scale.dart';
import 'src/layout/module_summaries.dart';
import 'src/layout/dashboard_tabs.dart';
import 'src/settings/dashboard_display_mode.dart';
import 'src/layout/game_edge_tap_guard.dart';
import 'src/layout/panel_style.dart';
import 'src/layout/hd_bottom_strip.dart';
import 'src/layout/hd_portrait_grid.dart';
import 'src/fleet/game_mod_portraits.dart';
import 'src/layout/hd_home_editor.dart';
import 'src/layout/workspace_navigation_side.dart';
import 'src/layout/workspace_context_header.dart';
import 'src/layout/window_metrics_change.dart';
import 'src/layout/camera_avoidance.dart';
import 'src/layout/window_metrics_recovery_scheduler.dart';
import 'src/kcwiki_report/kcwiki_report_collector.dart';
import 'src/kcwiki_report/kcwiki_report_consumer.dart';
import 'src/kcwiki_report/kcwiki_report_dispatcher.dart';
import 'src/kcwiki_report/kcwiki_report_settings.dart';
import 'src/kcwiki_report/kcwiki_report_transport.dart';
import 'src/performance/second_tick_scope.dart';
import 'src/inventory/owned_inventory_page.dart';
import 'src/new_ship/new_ship_reminder_controller.dart';
import 'src/new_ship/new_ship_reminder_feedback.dart';
import 'src/new_ship/new_ship_reminder_store.dart';
import 'src/notification/game_notification_coordinator.dart';
import 'src/notification/new_ship_notification.dart';
import 'src/improvement/improvement_dataset_store.dart';
import 'src/improvement/improvement_dataset_update_service.dart';
import 'src/improvement/improvement_favorites_store.dart';
import 'src/improvement/improvement_planner_controller.dart';
import 'src/prototype_status_controller.dart';
import 'src/quest/pinned_quests_summary.dart';
import 'src/quest/quest_completion_badge.dart';
import 'src/quest/quest_completion_feedback.dart';
import 'src/quest/quest_completion_drawer.dart';
import 'src/quest/quest_progress_engine.dart';
import 'src/quest/quest_progress_dataset.dart';
import 'src/quest/quest_progress_dataset_store.dart';
import 'src/quest/quest_progress_rules_controller.dart';
import 'src/quest/quest_progress_update_service.dart';
import 'src/quest/quest_center_page.dart';
import 'src/quest/quest_catalog_controller.dart';
import 'src/quest/quest_catalog_store.dart';
import 'src/quest/quest_catalog_update_service.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_store.dart';
import 'src/toolbox/sortie_map_query/sortie_map_catalog_update_service.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_controller.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_store.dart';
import 'src/toolbox/sortie_map_query/enemy_catalog_update_service.dart';
import 'src/quest/shared_preferences_quest_store.dart';
import 'src/settings/layout_settings_controller.dart';
import 'src/theme/custom_font_controller.dart';
import 'src/settings/layout_settings_store.dart';
import 'src/settings/ui_display_size.dart';
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
import 'src/settings/game_mouse_wheel_settings.dart';
import 'src/settings/game_frame_refresh_shortcut_settings.dart';
import 'src/browser/game_frame_refresh_shortcut_dialog.dart';
import 'src/browser/game_frame_refresh_shortcut_action.dart';
import 'src/toolbox/toolbox_page.dart';
import 'src/toolbox/game_mods/game_mods_controller.dart';
import 'src/localization/runtime_message_text.dart';
import 'src/localization/ui_locale.dart';
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
  final accountSession = AccountSession.shared;
  LogbookDatabase.bindAccountSession(accountSession);
  late final GameApiEventPipeline gameApiEventPipeline;
  late final GameCaptureController gameCaptureController;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final customFontController = await CustomFontController.load();
  final layoutSettingsController = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
    customFontController: customFontController,
    systemLocaleCode: uiLocaleStorageCode(
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
    accountSession: accountSession,
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
  final appExitSettingsController = await AppExitSettingsController.load();
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
    onSessionReset: () async {
      gameApiEventPipeline.invalidatePendingEvents(waitForLoginStart: true);
      accountSession.reset();
      await gameCaptureController.invalidateSession();
    },
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
  final questStore = SharedPreferencesQuestStore(
    accountSession: accountSession,
  );
  final gameStateStore = GameStateStore();
  final questProgressDatasetStore = QuestProgressDatasetStore(
    const PreferencesQuestProgressDatasetStorage(),
  );
  final bundledQuestProgressDataset = await QuestProgressDataset.loadBundled();
  final questProgressDataset = await questProgressDatasetStore
      .loadBestAvailable(bundledQuestProgressDataset);
  final gameStateController = GameStateController(
    accountSession: accountSession,
    questStore: questStore,
    questProgress: QuestProgressEngine(
      goals: questProgressDataset.goals,
      storage: PreferencesQuestProgressStorage(),
    ),
    gameStateStore: gameStateStore,
  );
  await gameStateController.initialize();
  final kcwikiReportController = await KcwikiReportController.load(
    SharedPreferencesKcwikiReportSettingsStore(),
  );
  final gameResourceCacheController = GameResourceCacheController();
  await gameResourceCacheController.initialize(loadStatus: false);
  final senkaController = SenkaController(
    accountSession: accountSession,
    store: await SharedPreferencesSenkaStore.create(
      accountSession: accountSession,
    ),
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
    accountSession: accountSession,
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
  final questProgressRulesController = QuestProgressRulesController(
    dataset: questProgressDataset,
    sourceHost:
        questProgressDataset.version == bundledQuestProgressDataset.version
        ? ''
        : 'github.com',
    updater: QuestProgressUpdateService(
      client: http.Client(),
      store: questProgressDatasetStore,
      appVersion: currentVersion,
    ),
    onUpdated: (dataset) =>
        gameStateController.updateQuestProgressGoals(dataset.goals),
  );
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
  final bundledSortieMapCatalog = await SortieMapCatalog.loadAsset();
  late FileSortieMapCatalogStore sortieMapCatalogStore;
  try {
    sortieMapCatalogStore = await FileSortieMapCatalogStore.create(
      currentAppVersion: currentVersion,
    );
  } catch (error) {
    debugPrint('海域资料目录不可用，改用临时缓存: $error');
    sortieMapCatalogStore = FileSortieMapCatalogStore(
      root: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}yahagi-sortie-catalog',
      ),
      currentAppVersion: currentVersion,
    );
  }
  final cachedSortieMapCatalog = await sortieMapCatalogStore.loadCached();
  final useCachedSortieMapCatalog =
      cachedSortieMapCatalog != null &&
      cachedSortieMapCatalog.data.versionInfo.compareTo(
            bundledSortieMapCatalog.versionInfo,
          ) >=
          0;
  final sortieMapCatalogController = SortieMapCatalogController(
    data: useCachedSortieMapCatalog
        ? cachedSortieMapCatalog.data
        : bundledSortieMapCatalog,
    cacheRoot: useCachedSortieMapCatalog ? cachedSortieMapCatalog.root : null,
    updater: SortieMapCatalogUpdateService(
      client: http.Client(),
      installer: sortieMapCatalogStore,
      appVersion: currentVersion,
    ),
  );
  final bundledEnemyCatalog = await EnemyCatalogData.loadAsset();
  late FileEnemyCatalogStore enemyCatalogStore;
  try {
    enemyCatalogStore = await FileEnemyCatalogStore.create();
  } catch (error) {
    debugPrint('敌舰资料目录不可用，改用临时缓存: $error');
    enemyCatalogStore = FileEnemyCatalogStore(
      cacheFile: File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}yahagi-enemy-catalog.json',
      ),
      bundledReader: () async => bundledEnemyCatalog.rawJson,
    );
  }
  final loadedEnemyCatalog = await enemyCatalogStore.loadBestAvailable();
  final enemyCatalogController = EnemyCatalogController(
    data: loadedEnemyCatalog,
    usesCachedData: loadedEnemyCatalog.revision > bundledEnemyCatalog.revision,
    updater: EnemyCatalogUpdateService(
      client: http.Client(),
      store: enemyCatalogStore,
      appVersion: currentVersion,
    ),
  );
  final battleController = BattleController(
    accountSession: accountSession,
    gameState: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
    onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
    onDamageControlConsumed: gameStateController.applyDamageControlConsumption,
    damageAlertPort: const MethodChannelBattleDamageAlertPort(),
    battleStatusEffectSettings: () =>
        safetySettingsController.battleStatusEffects,
    nodeLabelResolver: fcdMapController,
    formationMemory: formationMemoryController,
  );
  gameStateController.questBattleSnapshot = () => battleController.current;
  gameStateController.questBattleTrusted = () =>
      battleController.isPredictionConfirmed;
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
      baseUri: configuredKcwikiReportEndpoint() ?? Uri(),
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
    accountSession: accountSession,
    controller: kcwikiReportController,
    collector: KcwikiReportCollector(),
    dispatcher: kcwikiReportDispatcher,
    gameState: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
  );
  String notificationLocaleCode() =>
      layoutSettingsController.localeCode ??
      uiLocaleStorageCode(WidgetsBinding.instance.platformDispatcher.locale);
  late final GameNotificationCoordinator notificationCoordinator;
  late final ShipSubtitleCatalogController shipSubtitleCatalogController;
  GameNameCatalog? notificationNameCache;
  GameNameCatalog notificationNames() {
    final bundle = shipSubtitleCatalogController.kc3Bundle;
    final locale = Locale(notificationLocaleCode());
    final cached = notificationNameCache;
    if (cached != null &&
        cached.locale == locale &&
        identical(cached.bundle, bundle)) {
      return cached;
    }
    return notificationNameCache = GameNameCatalog(
      bundle: bundle,
      locale: locale,
    );
  }

  final newShipReminderController = NewShipReminderController(
    accountSession: accountSession,
    stateProvider: () => gameStateController.state,
    waitForGameState: () => gameStateController.idle,
    store: NewShipReminderStore(await SharedPreferences.getInstance()),
    onPublish: (alert) {
      notificationCoordinator.enqueueImmediateAlert(
        buildNewShipNotification(
          alert: alert,
          state: gameStateController.state,
          localeCode: notificationLocaleCode(),
          names: notificationNames(),
        ),
      );
    },
  );
  final headerNoticeController = TopNoticeController();
  final gameInfoNoticeController = GameInfoNoticeController(
    namesProvider: notificationNames,
    stateProvider: () => gameStateController.state,
    accountSession: accountSession,
    layoutSettingsController: layoutSettingsController,
    topNoticeController: headerNoticeController,
  );
  final debuffReminderController = DebuffReminderController(
    accountSession: accountSession,
  );
  gameApiEventPipeline = GameApiEventPipeline(
    settleGameState: () async {
      await gameStateController.idle;
      await battleController.idle;
      await gameStateController.idle;
    },
    consumers: <GameApiEventConsumer>[
      accountSession,
      gameStateController,
      kcwikiReportConsumer,
      gameResourceManifestConsumer,
      senkaController,
      battleController,
      newShipReminderController,
      gameInfoNoticeController,
      debuffReminderController,
    ],
    onBackgroundDecodeFallback: (path) {
      if (!kcwikiReportController.enabled) return;
      kcwikiReportController.recordParseRecovered(
        path: path,
        occurredAt: DateTime.now(),
      );
    },
  );
  gameCaptureController = GameCaptureController(
    onAcceptedEvent: gameApiEventPipeline.add,
    onCaptureInterrupted: () {
      gameApiEventPipeline.invalidateQueuedEvents();
      battleController.invalidateCaptureContinuity();
    },
  );
  final releaseChecker = GitHubReleaseChecker();
  final gameMouseWheelSettingsController =
      await GameMouseWheelSettingsController.load();
  final shipSubtitleSettingsController =
      await ShipSubtitleSettingsController.load();
  shipSubtitleCatalogController = await ShipSubtitleCatalogController.load(
    language: shipSubtitleSettingsController.language,
  );
  final shipSubtitleRuntimeController = ShipSubtitleRuntimeController(
    settings: shipSubtitleSettingsController,
    catalog: shipSubtitleCatalogController,
    layout: layoutSettingsController,
    gameState: gameStateController,
  );
  await shipSubtitleRuntimeController.initialize();
  final gameFrameRefreshShortcutSettings =
      await GameFrameRefreshShortcutSettings.load();
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
  DateTime? browserNavigationStartedAt;
  void recordBrowserState() {
    final state = browserController.loadState;
    if (state == lastBrowserDiagnosticState) return;
    lastBrowserDiagnosticState = state;
    final now = DateTime.now();
    if (state == GamePageLoadState.loading) browserNavigationStartedAt = now;
    final elapsed = browserNavigationStartedAt == null
        ? 0
        : now.difference(browserNavigationStartedAt!).inMilliseconds;
    diagnosticRecorder.record(
      DiagnosticEvent.webViewState(
        occurredAt: now,
        state: state.name,
        durationMs: elapsed < 0 ? 0 : elapsed,
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
    databaseBytes: () => LogbookDatabase.instance.diagnosticFileSizeBytes(),
    webViewHost: diagnosticWebViewHost,
    renderer: diagnosticRenderer,
    generationId: diagnosticGeneration,
    gamePerformanceSnapshot: Platform.isAndroid
        ? const MethodChannelGameFrameRateRuntimePort().performanceSnapshot
        : null,
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
  const telemetrySettingsStore = SharedPreferencesTelemetrySettingsStore();
  final telemetryService = AppTelemetryService(
    telemetryDeckAppID: '685D5F38-DD7D-48CB-896D-88642F96F92D',
    appVersion: currentVersion,
    diagnosticPlatformPort: diagnosticPlatform,
    renderingModeResolver: () => gameRenderingModeController.mode,
  );
  final telemetryController = await TelemetryController.create(
    store: telemetrySettingsStore,
    service: telemetryService,
  );
  const notificationTimerAnchorStore =
      SharedPreferencesNotificationTimerAnchorStore();
  final notificationTimerAnchors = await notificationTimerAnchorStore.load();
  notificationCoordinator = GameNotificationCoordinator(
    accountSession: accountSession,
    gameStateController: gameStateController,
    settingsController: notificationSettingsController,
    localeCodeProvider: notificationLocaleCode,
    namesProvider: notificationNames,
    namesListenable: shipSubtitleCatalogController,
    localeListenable: layoutSettingsController,
    notificationPort: const MethodChannelNotificationPort(),
    initialTimerAnchors: notificationTimerAnchors,
    timerAnchorStore: notificationTimerAnchorStore,
  );
  notificationCoordinator.start();
  RecordBackupService? backupService;
  Object? backupStartupError;
  if (Platform.isAndroid) {
    backupService = RecordBackupService(
      session: accountSession,
      port: const AndroidBackupDocumentPort(),
      senkaStore: senkaController.store as SenkaBackupStore,
      senkaController: senkaController,
    );
    RecordBackupService.shared = backupService;
    try {
      await backupService.start();
    } catch (error) {
      debugPrint('Record backup initialization failed: $error');
      backupStartupError = error;
    }
  }
  final backupMaintenanceOverlay = ValueNotifier<Widget?>(null);
  final app = YahagiApp(
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
    appExitSettingsController: appExitSettingsController,
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
    debuffReminderController: debuffReminderController,
    moraleRecoveryTimerController:
        notificationCoordinator.moraleRecoveryTimerController,
    gameResourceCacheController: gameResourceCacheController,
    senkaController: senkaController,
    battleController: battleController,
    fcdMapController: fcdMapController,
    questCatalogController: questCatalogController,
    questProgressRulesController: questProgressRulesController,
    sortieMapCatalogController: sortieMapCatalogController,
    enemyCatalogController: enemyCatalogController,
    improvementPlannerController: improvementPlannerController,
    currentVersion: currentVersion,
    releaseChecker: releaseChecker,
    screenAwakeController: screenAwakeController,
    headerNoticeController: headerNoticeController,
    gameInfoNoticeController: gameInfoNoticeController,
    gameMouseWheelSettingsController: gameMouseWheelSettingsController,
    shipSubtitleSettingsController: shipSubtitleSettingsController,
    shipSubtitleCatalogController: shipSubtitleCatalogController,
    shipSubtitleRuntimeController: shipSubtitleRuntimeController,
    gameFrameRefreshShortcutSettings: gameFrameRefreshShortcutSettings,
    diagnosticController: diagnosticController,
    telemetryController: telemetryController,
    backupMaintenanceOverlay: backupMaintenanceOverlay,
    nativeWebViewGenerationSink: (value) {
      diagnosticNativeWebViewGeneration = value;
    },
  );
  var mainAppLaunched = false;
  void launchMainApp() {
    mainAppLaunched = true;
    runApp(app);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(gameResourceCacheController.refresh());
      unawaited(fcdMapController.checkForUpdates());
      unawaited(questCatalogController.checkForUpdates());
      unawaited(questProgressRulesController.checkForUpdates());
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (telemetryController.enabled) {
          unawaited(telemetryController.startIfEnabled());
        }
      });
    });
  }

  Future<void> finishBackupMaintenance() async {
    // Keep the document cutoff before reload so only the new game's responses
    // can write to the restored records. The WebView itself stays mounted.
    gameApiEventPipeline.resumeAfterMaintenance();
    try {
      if (mainAppLaunched) await browserController.reload();
      backupMaintenanceOverlay.value = null;
    } catch (error) {
      backupMaintenanceOverlay.value = _BackupRecoveryGate(
        service: backupService!,
        initialError: error,
        onRecovered: () => unawaited(finishBackupMaintenance()),
      );
    }
  }

  backupService?.configureMaintenance(
    begin: () async {
      gameApiEventPipeline.pauseForMaintenance();
      // Keep the live WebView's native message listener installed. The pipeline
      // drops old-document responses and reload starts a new document below.
      gameCaptureController.clearCapturedEvents();
      backupMaintenanceOverlay.value = const _BackupMaintenanceScreen();
      await WidgetsBinding.instance.endOfFrame;
      await gameApiEventPipeline.idle;
      await gameStateController.logbookIdle;
      await senkaController.idle;
    },
    end: () => unawaited(finishBackupMaintenance()),
    blocked: (error) {
      backupMaintenanceOverlay.value = _BackupRecoveryGate(
        service: backupService!,
        initialError: error,
        onRecovered: () => unawaited(finishBackupMaintenance()),
      );
    },
  );
  if (backupService != null) {
    WidgetsBinding.instance.addObserver(
      _BackupLifecycleFlushObserver(
        service: backupService,
        pipeline: gameApiEventPipeline,
        gameState: gameStateController,
      ),
    );
  }

  if (backupStartupError != null && backupService != null) {
    runApp(
      MaterialApp(
        home: _BackupRecoveryGate(
          service: backupService,
          initialError: backupStartupError,
          onRecovered: launchMainApp,
        ),
      ),
    );
  } else {
    launchMainApp();
  }
}

class _BackupLifecycleFlushObserver with WidgetsBindingObserver {
  _BackupLifecycleFlushObserver({
    required this.service,
    required this.pipeline,
    required this.gameState,
  });

  final RecordBackupService service;
  final GameApiEventPipeline pipeline;
  final GameStateController gameState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (!service.hasDirectory || service.maintenanceActive) return;
    try {
      await pipeline.idle;
      await gameState.logbookIdle;
      await service.flush();
    } catch (error) {
      debugPrint('Backup lifecycle flush failed: $error');
    }
  }
}

class _BackupRecoveryGate extends StatefulWidget {
  const _BackupRecoveryGate({
    required this.service,
    required this.initialError,
    required this.onRecovered,
  });

  final RecordBackupService service;
  final Object initialError;
  final VoidCallback onRecovered;

  @override
  State<_BackupRecoveryGate> createState() => _BackupRecoveryGateState();
}

class _BackupRecoveryGateState extends State<_BackupRecoveryGate> {
  late Object _error = widget.initialError;
  bool _busy = false;

  Future<void> _retry({required bool chooseFolder}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final wasMaintenance = widget.service.maintenanceActive;
      if (chooseFolder &&
          !await widget.service.reselectDirectoryForRecovery()) {
        return;
      }
      await widget.service.start();
      await widget.service.recoverPendingRestores();
      if (!wasMaintenance) widget.onRecovered();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = RecordBackupStrings.of(context);
    final journalCorrupt =
        _error is FormatException ||
        '$_error'.contains('Restore completion marker mismatch');
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.recoveryPending),
              const SizedBox(height: 12),
              Text('$_error'),
              const SizedBox(height: 12),
              Text(
                journalCorrupt
                    ? strings.recoveryCorruptAdvice
                    : strings.recoveryRetryAdvice,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _retry(chooseFolder: false),
                child: Text(strings.retryRestore),
              ),
              if (!journalCorrupt)
                TextButton(
                  onPressed: _busy ? null : () => _retry(chooseFolder: true),
                  child: Text(strings.reselectFolder),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupMaintenanceScreen extends StatelessWidget {
  const _BackupMaintenanceScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(RecordBackupStrings.of(context).restoring),
        ],
      ),
    ),
  );
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
    this.appExitSettingsController,
    required this.displayModeController,
    required this.controller,
    required this.browserController,
    required this.captureModeController,
    required this.audioController,
    required this.toolbarController,
    required this.gameCaptureController,
    this.gameApiEventPipeline,
    this.newShipReminderController,
    this.debuffReminderController,
    this.kcwikiReportController,
    this.kcwikiReportConsumer,
    required this.gameStateController,
    this.moraleRecoveryTimerController,
    this.gameResourceCacheController,
    this.senkaController,
    required this.battleController,
    this.fcdMapController,
    this.questCatalogController,
    this.questProgressRulesController,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.improvementPlannerController,
    this.gameSurface,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
    this.screenAwakeController,
    this.headerNoticeController,
    this.gameInfoNoticeController,
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.shipSubtitleSettingsController,
    this.shipSubtitleCatalogController,
    this.shipSubtitleRuntimeController,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.showDeveloperDiagnostics = false,
    this.diagnosticController,
    this.telemetryController,
    this.gameRouteObserver,
    this.nativeWebViewGenerationSink,
    this.backupMaintenanceOverlay,
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
  final AppExitSettingsController? appExitSettingsController;
  final DisplayModeController displayModeController;
  final PrototypeStatusController controller;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameAudioController audioController;
  final GameToolbarController toolbarController;
  final GameCaptureController gameCaptureController;
  final GameApiEventPipeline? gameApiEventPipeline;
  final NewShipReminderController? newShipReminderController;
  final DebuffReminderController? debuffReminderController;
  final KcwikiReportController? kcwikiReportController;
  final KcwikiReportConsumer? kcwikiReportConsumer;
  final GameStateController gameStateController;
  final MoraleRecoveryTimerController? moraleRecoveryTimerController;
  final GameResourceCacheController? gameResourceCacheController;
  final SenkaController? senkaController;
  final BattleController battleController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final QuestProgressRulesController? questProgressRulesController;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final Widget? gameSurface;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final TopNoticeController? headerNoticeController;
  final GameInfoNoticeController? gameInfoNoticeController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final ShipSubtitleSettingsController? shipSubtitleSettingsController;
  final ShipSubtitleCatalogController? shipSubtitleCatalogController;
  final ShipSubtitleRuntimeController? shipSubtitleRuntimeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final bool showDeveloperDiagnostics;
  final DiagnosticController? diagnosticController;
  final TelemetryController? telemetryController;
  final RouteObserver<ModalRoute<dynamic>>? gameRouteObserver;
  final void Function(int)? nativeWebViewGenerationSink;
  final ValueListenable<Widget?>? backupMaintenanceOverlay;

  @override
  Widget build(BuildContext context) {
    battleController.bindFriendlyHpUpdater(
      gameStateController.applyFriendlyBattleHp,
    );
    battleController.bindDamageControlUpdater(
      gameStateController.applyDamageControlConsumption,
    );
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        layoutSettingsController,
        safetySettingsController,
        ?toolbarDisplayController,
        ?gameRenderingModeController,
        ?backupMaintenanceOverlay,
      ]),
      builder: (context, _) {
        final routeObserver = gameRouteObserver ?? yahagiGameRouteObserver;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => DisplayCornersHost(
            child: GameNameLocalizationScope(
              controller: shipSubtitleCatalogController,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  boldText: true,
                  textScaler: layoutSettingsController.uiFontSize
                      .resolveTextScaler(MediaQuery.textScalerOf(context)),
                ),
                child: CameraAvoidanceViewport(
                  enabled: layoutSettingsController.cameraAvoidanceEnabled,
                  distance: layoutSettingsController.cameraAvoidanceDistance,
                  child: Stack(
                    children: [
                      child ?? const SizedBox.shrink(),
                      if (backupMaintenanceOverlay?.value case final overlay?)
                        Positioned.fill(child: overlay),
                    ],
                  ),
                ),
              ),
            ),
          ),
          scrollBehavior: const AppScrollBehavior(),
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
          localeResolutionCallback: resolveUiLocale,
          navigatorObservers: <NavigatorObserver>[routeObserver],
          theme: createAppTheme(
            mode: layoutSettingsController.appThemeMode,
            fontFamily: layoutSettingsController.fontFamily,
            fontFamilyFallback: layoutSettingsController.fontFamilyFallback,
          ),
          home: TopNoticeHost(
            child: _withDebuffReminders(
              StartupUpdateNotice(
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
                    appExitSettingsController: appExitSettingsController,
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
                    moraleRecoveryTimerController:
                        moraleRecoveryTimerController,
                    gameResourceCacheController: gameResourceCacheController,
                    senkaController: senkaController,
                    battleController: battleController,
                    fcdMapController: fcdMapController,
                    questCatalogController: questCatalogController,
                    questProgressRulesController: questProgressRulesController,
                    sortieMapCatalogController: sortieMapCatalogController,
                    enemyCatalogController: enemyCatalogController,
                    improvementPlannerController: improvementPlannerController,
                    currentVersion: currentVersion,
                    releaseChecker: releaseChecker,
                    screenAwakeController: screenAwakeController,
                    gameMouseWheelSettingsController:
                        gameMouseWheelSettingsController,
                    gameFrameRefreshShortcutSettings:
                        gameFrameRefreshShortcutSettings,
                    shipSubtitleSettingsController:
                        shipSubtitleSettingsController,
                    shipSubtitleCatalogController:
                        shipSubtitleCatalogController,
                    shipSubtitleRuntimeController:
                        shipSubtitleRuntimeController,
                    toolbarDisplayController: toolbarDisplayController,
                    gameScreenshotController: gameScreenshotController,
                    headerNoticeController: headerNoticeController,
                    gameInfoNoticeController: gameInfoNoticeController,
                    showDeveloperDiagnostics: showDeveloperDiagnostics,
                    diagnosticController: diagnosticController,
                    telemetryController: telemetryController,
                    gameSurface: Builder(
                      builder: (context) => GameWorkspaceActive(
                        active:
                            GameWorkspaceActive.of(context) &&
                            backupMaintenanceOverlay?.value == null,
                        child: _buildGameSurface(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _withDebuffReminders(Widget child) {
    final scopedChild = GameDialogPresentationScope(
      nativeActivity:
          gameRenderingModeController?.mode.usesActivityWebView == true,
      presentationEnabled: !(gameRenderingModeController?.isBusy ?? false),
      child: child,
    );
    final reminder = debuffReminderController;
    final settings = notificationSettingsController;
    final notices = headerNoticeController;
    if (reminder == null || settings == null || notices == null) {
      return scopedChild;
    }
    return DebuffReminderFeedback(
      controller: reminder,
      nativeWarningDialogPort:
          gameRenderingModeController?.mode.usesActivityWebView == true &&
              !(gameRenderingModeController?.isBusy ?? false)
          ? const MethodChannelNativeGameWarningDialogPort.forReminder('debuff')
          : null,
      presentationEnabled: !(gameRenderingModeController?.isBusy ?? false),
      settingsController: settings,
      headerNoticeController: notices,
      topNoticeDuration: () =>
          Duration(seconds: layoutSettingsController.topNoticeDurationSeconds),
      child: scopedChild,
    );
  }

  Widget _buildGameSurface() {
    Widget withBattleWarning(Widget child, {GameRenderingMode? mode}) =>
        BattleResultWarningOverlay(
          nativeWarningDialogPort: mode?.usesActivityWebView == true
              ? const MethodChannelNativeGameWarningDialogPort()
              : null,
          accountSession: gameStateController.accountSession,
          gameCaptureController: gameCaptureController,
          loadSafetyState: () async {
            await gameApiEventPipeline?.dispatchIdle;
            await battleController.idle;
            await gameStateController.idle;
            return gameStateController.state;
          },
          safetyEventAccepted: (event, state) {
            if (gameApiEventPipeline?.wasEventAccepted(event) != true) {
              return false;
            }
            if (!isPostBattleSafetyEvent(event)) return true;
            final battle = battleController.current;
            final combat = state.combatState;
            return battle != null &&
                battleController.lastError == null &&
                battle.displayStage == BattleDisplayStage.result &&
                !battle.context.practice &&
                combat.isActive &&
                battle.context.deckId == combat.sortieFleetId &&
                battle.context.mapAreaId == combat.mapArea &&
                battle.context.mapInfoNo == combat.mapInfo &&
                battle.context.node == combat.currentNode;
          },
          safetySettingsController: safetySettingsController,
          damageControlStateTrusted: () =>
              battleController.isDamageControlStateTrusted,
          warningSession: battleController.warningSession,
          damageControlNoticeEnabled: () =>
              layoutSettingsController.topNoticeEnabled,
          onReloadGame: () async {
            if (!browserController.hasAttachedPort) {
              throw StateError('Game browser unavailable');
            }
            await browserController.reload();
          },
          onReloadGameFrame: () async {
            final result = await browserController.reloadGameFrame();
            if (result != GameFrameReloadResult.reloaded) {
              throw StateError('Game frame refresh unavailable');
            }
          },
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
        withBattleWarning: (child) => withBattleWarning(child, mode: mode),
      ),
    );
  }

  Widget _buildNativeActivityGameSurface(Key key) => NativeActivityGameSurface(
    key: key,
    onGenerationChanged: nativeWebViewGenerationSink,
    onLoadEvent: (event) => _recordGameLoadEvent(
      event,
      GameRenderingMode.nativeActivityExperimental,
    ),
    onRenderProcessGone: (didCrash) => diagnosticController?.recorder.record(
      DiagnosticEvent.fixedError(
        occurredAt: DateTime.now(),
        component: DiagnosticComponent.webView,
        errorType: didCrash ? 'rendererCrash' : 'rendererKilled',
        code: DiagnosticErrorCode.renderProcessGone,
        webViewHost: DiagnosticWebViewHost.activityDirect,
      ),
    ),
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
        onLoadEvent: (event) => _recordGameLoadEvent(event, renderingMode),
        networkSettingsController: networkSettingsController,
        safetySettingsController: safetySettingsController,
        controller: controller,
        browserController: browserController,
        captureModeController: captureModeController,
        audioController: audioController,
        toolbarController: toolbarController,
        gameCaptureController: gameCaptureController,
        frameRateSettingsController: gameFrameRateSettingsController,
        mouseWheelSettingsController: gameMouseWheelSettingsController,
        renderingMode:
            renderingMode ??
            gameRenderingModeController?.mode ??
            GameRenderingMode.compatibility,
      );

  void _recordGameLoadEvent(
    GameLoadEvent event,
    GameRenderingMode? requestedMode,
  ) {
    final diagnostics = diagnosticController;
    if (diagnostics == null || !diagnostics.recorder.enabled) return;
    final mode =
        requestedMode ??
        gameRenderingModeController?.mode ??
        GameRenderingMode.compatibility;
    diagnostics.recorder.record(
      DiagnosticEvent.gameLoad(
        occurredAt: DateTime.now(),
        event: event,
        webViewHost: mode.usesActivityWebView
            ? DiagnosticWebViewHost.activityDirect
            : DiagnosticWebViewHost.flutterPlatformView,
        renderingMode: mode.name,
        generationId: mode.usesActivityWebView
            ? diagnostics.generationId?.call()
            : null,
      ),
    );
  }

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
    this.appExitSettingsController,
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
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.shipSubtitleSettingsController,
    this.shipSubtitleCatalogController,
    this.shipSubtitleRuntimeController,
    this.toolbarDisplayController,
    this.gameScreenshotController,
    this.headerNoticeController,
    this.gameInfoNoticeController,
    this.fcdMapController,
    this.questCatalogController,
    this.questProgressRulesController,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.improvementPlannerController,
    this.showDeveloperDiagnostics = false,
    this.diagnosticController,
    this.telemetryController,
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
  final AppExitSettingsController? appExitSettingsController;
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
  final QuestProgressRulesController? questProgressRulesController;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final ShipSubtitleSettingsController? shipSubtitleSettingsController;
  final ShipSubtitleCatalogController? shipSubtitleCatalogController;
  final ShipSubtitleRuntimeController? shipSubtitleRuntimeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameScreenshotController? gameScreenshotController;
  final TopNoticeController? headerNoticeController;
  final GameInfoNoticeController? gameInfoNoticeController;
  final bool showDeveloperDiagnostics;
  final DiagnosticController? diagnosticController;
  final TelemetryController? telemetryController;

  @override
  State<YahagiShell> createState() => _YahagiShellState();
}

class _YahagiShellState extends State<YahagiShell> with WidgetsBindingObserver {
  bool _hdEditing = false;
  final _settingsInformationPanelKey = GlobalKey<_InformationPanelState>();
  static const _gameFrameReloadChannel = MethodChannel(
    gameFrameReloadMethodChannelName,
  );
  final WindowMetricsRecoveryScheduler _windowMetricsRecoveryScheduler =
      WindowMetricsRecoveryScheduler();
  WindowMetricsChangeTracker? _windowMetricsChangeTracker;
  int _workspaceIndex = 0;
  bool _gameFullscreen = false;
  bool _layoutFitScheduled = false;
  Size? _normalWorkspaceSize;
  bool _gameWorkspaceSizeFrozen = false;
  int? _expeditionCheckFleetId;
  int? _fleetCenterInitialFleetId;
  int? _repairCenterInitialFleetId;
  int? _questCenterInitialQuestId;
  bool _inventoryShowShips = true;
  bool _inventoryShowOwned = true;
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
  CompositionImageDraftController? _compositionDraftController;
  final GameModsController _gameModsController = GameModsController();
  final DevelopmentRepository _developmentRepository = DevelopmentRepository();
  BackgroundGameRetentionCoordinator? _backgroundGameRetentionCoordinator;
  GameReminderDialogPresentation? _headerResourceSettingsPresentation;
  bool? _headerResourceSettingsNative;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_gameModsController.initialize());
    widget.displayModeController.addListener(_onDisplayModeChanged);
    widget.layoutSettingsController.addListener(_onLayoutSettingsChanged);
    widget.gameRenderingModeController?.addListener(_onHeaderDialogModeChanged);
    _gameFrameReloadChannel.setMethodCallHandler(
      _handleNativeGameFrameReloadMessage,
    );
    if (widget.backgroundGameRetentionController case final controller?) {
      _backgroundGameRetentionCoordinator = BackgroundGameRetentionCoordinator(
        controller: controller,
        toolbarController: widget.toolbarController,
        port:
            widget.backgroundGameRetentionPort ??
            const MethodChannelBackgroundGameRetentionPort(),
        onFailure: (error) => widget.diagnosticController?.recorder.record(
          DiagnosticEvent.fixedError(
            occurredAt: DateTime.now(),
            component: DiagnosticComponent.platform,
            errorType: error.runtimeType.toString(),
            code: DiagnosticErrorCode.operationFailed,
          ),
        ),
      );
    }
    _applyOrientationPolicy();
  }

  @override
  void dispose() {
    _headerResourceSettingsPresentation?.cancel();
    widget.gameRenderingModeController?.removeListener(
      _onHeaderDialogModeChanged,
    );
    _gameFrameReloadChannel.setMethodCallHandler(null);
    widget.displayModeController.removeListener(_onDisplayModeChanged);
    widget.layoutSettingsController.removeListener(_onLayoutSettingsChanged);
    widget.kcwikiReportConsumer?.dispose();
    widget.gameInfoNoticeController?.dispose();
    _questFilters.dispose();
    _gameModsController.dispose();
    _windowMetricsRecoveryScheduler.dispose();
    _backgroundGameRetentionCoordinator?.dispose();
    widget.telemetryController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant YahagiShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutSettingsController != widget.layoutSettingsController) {
      _headerResourceSettingsPresentation?.cancel();
      oldWidget.layoutSettingsController.removeListener(
        _onLayoutSettingsChanged,
      );
      widget.layoutSettingsController.addListener(_onLayoutSettingsChanged);
    }
    if (oldWidget.gameRenderingModeController !=
        widget.gameRenderingModeController) {
      oldWidget.gameRenderingModeController?.removeListener(
        _onHeaderDialogModeChanged,
      );
      widget.gameRenderingModeController?.addListener(
        _onHeaderDialogModeChanged,
      );
      _headerResourceSettingsPresentation?.cancel();
    }
  }

  void _onHeaderDialogModeChanged() {
    final mode = widget.gameRenderingModeController;
    if (mode?.isBusy == true ||
        (_headerResourceSettingsNative != null &&
            _headerResourceSettingsNative !=
                (mode?.mode.usesActivityWebView == true))) {
      _headerResourceSettingsPresentation?.cancel();
    }
  }

  Future<void> _handleNativeGameFrameReloadMessage(MethodCall call) async {
    if (call.method != 'shortcutResult' || !mounted) return;
    GameFrameReloadResult result;
    try {
      result = decodeGameFrameReloadResult(call.arguments as String?);
    } catch (_) {
      result = GameFrameReloadResult.blocked;
    }
    final message = gameFrameReloadErrorMessage(
      AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('zh')),
      result,
    );
    if (message != null && mounted) {
      TopNotice.show(context, message: message, tone: TopNoticeTone.error);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _windowMetricsChangeTracker ??= WindowMetricsChangeTracker(
      WindowMetricsSnapshot.fromView(View.of(context)),
    );
  }

  void _onLayoutSettingsChanged() {
    if (!mounted) return;
    if (widget.layoutSettingsController.uiLocked) {
      _headerResourceSettingsPresentation?.cancel();
    }
    // The route may keep the shell's parent unchanged. Rebuild the workspace
    // explicitly so manual panel ratios apply without navigating or resizing.
    setState(() {
      if (!widget.layoutSettingsController.hdSettings.enabled ||
          widget.layoutSettingsController.uiLocked) {
        _hdEditing = false;
      }
    });
    if (_layoutFitScheduled) return;
    _layoutFitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutFitScheduled = false;
      if (mounted) {
        widget.browserController.fitGameScreen().catchError((Object _) {});
      }
    });
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    widget.layoutSettingsController.updateSystemLocaleCode(
      uiLocaleStorageCode(locales?.firstOrNull),
    );
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

  void _onDisplayModeChanged() {
    _applyOrientationPolicy();
    if (mounted) {
      setState(() {});
      _fitGameScreenAfterFrame();
    }
  }

  void _fitGameScreenAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.browserController.fitGameScreen().catchError((Object _) {});
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
      if (_gameFullscreen) _setGameFullscreen(false);
    }
    if (_workspaceIndex != index) {
      setState(() => _workspaceIndex = index);
    }
  }

  void _openDashboardLayoutSettings() {
    if (widget.layoutSettingsController.uiLocked) return;
    _selectWorkspace(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.layoutSettingsController.uiLocked) {
        _settingsInformationPanelKey.currentState?.beginEditing();
      }
    });
  }

  Future<void> _openHeaderResourceSettings() async {
    if (widget.layoutSettingsController.uiLocked ||
        widget.gameRenderingModeController?.isBusy == true ||
        _headerResourceSettingsPresentation?.isActive == true) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final native =
        widget.gameRenderingModeController?.mode.usesActivityWebView == true;
    _headerResourceSettingsNative = native;
    final presentation = native
        ? showHeaderResourceChecklist(
            context: context,
            controller: widget.layoutSettingsController,
            stateProvider: () => widget.gameStateController.state,
            senkaProvider: () =>
                widget.senkaController?.state.playerRankingRow.senka,
            rankProvider: () =>
                widget.senkaController?.state.playerRankingRow.rank,
            anchorageRepairStartedAtProvider: () =>
                widget.gameStateController.anchorageRepairStartedAt,
            nosakiSparkleStartedAtProvider: () =>
                widget.gameStateController.nosakiSparkleStartedAt,
            valueChanges: Listenable.merge([
              widget.gameStateController,
              ?widget.senkaController,
            ]),
            nativeActivity: true,
            presentationEnabled: true,
          )
        : showGameReminderDialog(
            context: context,
            kind: 'headerEditor',
            title: l10n.selectHeaderVisibleItems,
            message: '',
            builder: (dialogContext, acknowledge) => Dialog(
              backgroundColor: appColor(dialogContext, const Color(0xff142735)),
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(l10n.selectHeaderVisibleItems)),
                          IconButton(
                            key: const Key('settings-header-editor-close'),
                            tooltip: MaterialLocalizations.of(
                              dialogContext,
                            ).closeButtonTooltip,
                            onPressed: acknowledge,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CompactResourceBar(
                        state: widget.gameStateController.state,
                        settingsController: widget.layoutSettingsController,
                        initiallyEditing: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
    if (presentation == null) {
      _headerResourceSettingsNative = null;
      return;
    }
    _headerResourceSettingsPresentation = presentation;
    try {
      await presentation.completed;
    } finally {
      if (identical(_headerResourceSettingsPresentation, presentation)) {
        _headerResourceSettingsPresentation = null;
        _headerResourceSettingsNative = null;
      }
    }
  }

  Duration _elapsedSince(DateTime? startedAt) {
    final now = DateTime.now().toUtc();
    return startedAt == null || now.isBefore(startedAt)
        ? Duration.zero
        : now.difference(startedAt);
  }

  void _openRepairCenter(RepairCenterMode mode, int? fleetId) {
    setState(() {
      _repairCenterMode = mode;
      _repairCenterInitialFleetId = fleetId;
    });
    _selectWorkspace(3);
  }

  void _openAnchorageRepairCenter() {
    final controller = widget.gameStateController;
    _openRepairCenter(
      RepairCenterMode.anchorage,
      preferredAnchorageRepairFleetId(
        state: controller.state,
        elapsed: _elapsedSince(controller.anchorageRepairStartedAt),
      ),
    );
  }

  void _openNosakiRepairCenter() {
    final controller = widget.gameStateController;
    _openRepairCenter(
      RepairCenterMode.nosaki,
      NosakiSparkleCalculator.preferredNosakiSparkleFleetId(
        state: controller.state,
        elapsed: _elapsedSince(controller.nosakiSparkleStartedAt),
      ),
    );
  }

  GameBrowserActions _browserActions(BuildContext context) =>
      GameBrowserActions(
        mode: widget.browserController.mode,
        interactionEnabled:
            !(widget.gameRenderingModeController?.isBusy ?? false),
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
        onFitScreen: () async {
          try {
            await widget.browserController.fitGameScreen();
          } catch (_) {
            if (!context.mounted) return;
            TopNotice.show(
              context,
              message: AppLocalizations.of(context)!.gameStatusErrorDesc,
            );
          }
        },
        onEnterFullscreen: () => _setGameFullscreen(true),
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
                final isSuccess = result.path != null;
                final tone = isSuccess
                    ? TopNoticeTone.success
                    : TopNoticeTone.error;
                TopNotice.show(context, message: message, tone: tone);
              },
        uiLocked: widget.layoutSettingsController.uiLocked,
        onToggleUiLock: () {
          final next = !widget.layoutSettingsController.uiLocked;
          unawaited(widget.layoutSettingsController.setUiLocked(next));
          if (context.mounted) {
            final l10n = AppLocalizations.of(context)!;
            TopNotice.show(
              context,
              message: next ? l10n.uiLockedToast : l10n.uiUnlockedToast,
            );
          }
        },
      );

  void _setGameFullscreen(bool fullscreen) {
    if (_gameFullscreen == fullscreen) return;
    setState(() => _gameFullscreen = fullscreen);
    _fitGameScreenAfterFrame();
  }

  Future<void> _refreshGameFromHeader() async {
    if (widget.gameRenderingModeController?.isBusy ?? false) return;
    await widget.browserController.reload();
  }

  Future<void> _refreshGameFrameFromHeader() async {
    final settings = widget.gameFrameRefreshShortcutSettings;
    if (settings == null ||
        !await confirmGameFrameRefreshShortcut(
          context: context,
          settings: settings,
        ) ||
        !mounted) {
      return;
    }
    await runGameFrameRefreshShortcut(
      context: context,
      reload: widget.browserController.reloadGameFrame,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminder = widget.newShipReminderController;
    if (reminder == null) return _buildShell(context);
    return AnimatedBuilder(
      animation: Listenable.merge([?widget.gameRenderingModeController]),
      builder: (context, _) => NewShipReminderFeedback(
        controller: reminder,
        stateProvider: () => widget.gameStateController.state,
        nativeWarningDialogPort:
            widget.gameRenderingModeController?.mode.usesActivityWebView ==
                    true &&
                !(widget.gameRenderingModeController?.isBusy ?? false)
            ? const MethodChannelNativeGameWarningDialogPort.forReminder(
                'newShip',
              )
            : null,
        presentationEnabled:
            !(widget.gameRenderingModeController?.isBusy ?? false),
        child: _buildShell(context),
      ),
    );
  }

  Widget _buildShell(BuildContext context) {
    final screenDisplayMode = widget.displayModeController.displayMode;
    final windowSize = MediaQuery.sizeOf(context);
    final menuHorizontal =
        widget.layoutSettingsController.workspaceMenuHorizontal;
    final menuTop =
        widget.layoutSettingsController.workspaceMenuPosition == 'top';
    final menuOnRight = widget.layoutSettingsController.workspaceMenuOnRight;
    final hdPortrait =
        widget.layoutSettingsController.hdSettings.enabled &&
        (screenDisplayMode == DisplayMode.portrait ||
            (screenDisplayMode != DisplayMode.landscape &&
                windowSize.height >= windowSize.width));
    final hdWindow =
        screenDisplayMode != DisplayMode.portrait &&
        usesHdLandscape(
          windowSize,
          enabled: widget.layoutSettingsController.hdSettings.enabled,
        );
    final hd = hdWindow || hdPortrait;
    final uiSize = effectiveUiDisplaySize(
      widget.layoutSettingsController.uiDisplaySize,
      hd: hd,
    );
    final uiScale = uiSize.isMinimal ? minimalUiScale : 1.0;
    // Minimal keeps compact chrome; only information content is enlarged.
    final shellHeaderHeight = topHeaderHeight(uiSize);
    // HD keeps its own viewport and safe-area geometry while its modules can
    // use the minimal panel style.
    final flatShell = usesFlatPanel(size: uiSize, hd: hd) && !hd;
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    // A horizontal bar on the bottom screen edge sits between the content and
    // the gesture area, so in the flat layout the bar clears the gesture area
    // itself and the content above it does not.
    final navigationGestureInset = flatShell && menuHorizontal
        ? bottomSafeArea
        : 0.0;
    final contentTouchesBottom = !(menuHorizontal && !menuTop);
    // Resources use the persistent header in every display size. Judge
    // the side rail against the same remaining space the game receives.
    final shellNavigationExtent = workspaceNavigationExtent(uiSize);
    final minimalShellWorkspace = Size(
      windowSize.width - (menuHorizontal ? 0 : shellNavigationExtent),
      windowSize.height -
          (menuHorizontal && !menuTop
              ? shellNavigationExtent + navigationGestureInset
              : 0) -
          shellHeaderHeight,
    );
    final minimalGameLayout = usesMinimalShell(
      size: uiSize,
      isLandscape: !usesVerticalWorkspace(
        minimalShellWorkspace,
        screenDisplayMode,
      ),
      hd: hd,
    );
    // 极简横排工作区的导航始终在顶栏下方、游戏和信息栏旁边。
    final minimalSideNavigation = minimalGameLayout && !menuHorizontal;

    Widget buildWorkspaceNavigation(
      int completedCount, {
      required bool atScreenBottom,
      bool leftAtEdge = true,
      bool rightAtEdge = true,
    }) => WorkspaceNavigation(
      controller: widget.layoutSettingsController,
      selectedIndex: _workspaceIndex,
      onRight: menuOnRight,
      onSelected: _selectWorkspace,
      completedQuestCount: completedCount,
      gameStateController: widget.gameStateController,
      hd: hd,
      endInsets:
          // 顶部横向导航栏在非游戏页排在顶栏下面，碰不到屏幕角。
          (minimalGameLayout && atScreenBottom
              ? minimalNavigationInsets(
                  corners: DisplayCorners.of(context),
                  bottomSafeArea: bottomSafeArea,
                  horizontal: menuHorizontal,
                  onRight: menuOnRight,
                  leftAtEdge: leftAtEdge,
                  rightAtEdge: rightAtEdge,
                )
              : EdgeInsets.zero) +
          EdgeInsets.only(bottom: atScreenBottom ? navigationGestureInset : 0),
    );

    Widget buildNavigationSidebar(int completedCount) => Visibility(
      key: const Key('workspace-navigation-sidebar'),
      visible: !_gameFullscreen,
      maintainState: true,
      maintainFocusability: true,
      child: buildWorkspaceNavigation(completedCount, atScreenBottom: !menuTop),
    );

    Widget buildHeaderToolbar() => AnimatedBuilder(
      animation: Listenable.merge([
        widget.browserController,
        widget.audioController,
        ?widget.gameRenderingModeController,
        widget.layoutSettingsController,
      ]),
      builder: (context, _) {
        final actions = _browserActions(context);
        return GameBrowserToolbar(
          compact: uiSize.isCompactOrSmaller,
          enableBackdropBlur:
              widget.gameRenderingModeController?.mode.enablesToolbarBlur ??
              true,
          interactionEnabled: actions.interactionEnabled,
          mode: actions.mode,
          loadState: widget.browserController.loadState,
          displayAddress: widget.browserController.displayAddress,
          onBack: actions.onBack,
          onReload: actions.onReload,
          onHome: actions.onHome,
          onEnterDmm: actions.onEnterDmm,
          isMuted: actions.isMuted,
          audioEnabled: actions.audioEnabled,
          onToggleMuted: actions.onToggleMuted,
          onCollapse: widget.toolbarController.collapse,
          onFitScreen: actions.onFitScreen,
          onEnterFullscreen: actions.onEnterFullscreen,
          onScreenshot: actions.onScreenshot,
          uiLocked: actions.uiLocked,
          onToggleUiLock: actions.onToggleUiLock,
          persistent: false,
        );
      },
    );

    final logbookMenuExtent = shellNavigationExtent;
    final logbookOccupiedInsets = menuHorizontal
        ? EdgeInsets.only(
            bottom: menuTop ? 0 : logbookMenuExtent + navigationGestureInset,
          )
        : menuOnRight
        ? EdgeInsets.only(right: logbookMenuExtent)
        : EdgeInsets.only(left: logbookMenuExtent);
    final panelAlignedNavigation =
        _workspaceIndex == 0 &&
        // Keep navigation beside both panels when the remaining workspace is
        // side by side, even if the whole window crosses the portrait cutoff.
        !minimalSideNavigation &&
        (menuTop ||
            (!menuHorizontal &&
                !hdWindow &&
                usesVerticalWorkspace(windowSize, screenDisplayMode)));

    final shell = Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppExitGuard(
        settingsController: widget.appExitSettingsController,
        fullscreen: _gameFullscreen,
        onExitFullscreen: () => _setGameFullscreen(false),
        child: SafeArea(
          left: false,
          right: false,
          top: false,
          bottom: false,
          child: GameFullscreenControls(
            active: _gameFullscreen,
            useNativeOverlay: Platform.isAndroid,
            onExit: () => _setGameFullscreen(false),
            onUnavailable: () {
              _setGameFullscreen(false);
              TopNotice.show(
                context,
                message: AppLocalizations.of(
                  context,
                )!.gameFullscreenUnavailable,
              );
            },
            child: QuestCompletionDrawerHost(
              controller: widget.headerNoticeController,
              fullscreen: _gameFullscreen,
              nativeQuestOverlay: Platform.isAndroid,
              child: QuestCompletionFeedback(
                controller: widget.gameStateController,
                layoutSettingsController: widget.layoutSettingsController,
                builder: (context, completedCount) => _SideRailColumn(
                  rail: null,
                  railOnRight: menuOnRight,
                  children: [
                    Visibility(
                      visible: !_gameFullscreen,
                      maintainState: true,
                      maintainFocusability: true,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          widget.toolbarController,
                          widget.layoutSettingsController,
                        ]),
                        builder: (context, _) {
                          final isCompact = uiSize.isCompactOrSmaller;
                          final headerHeight = topHeaderHeight(uiSize);
                          final isGameWorkspace = _workspaceIndex == 0;
                          final isToolbarVisible =
                              isGameWorkspace &&
                              widget.toolbarController.isVisible;
                          final corners = DisplayCorners.of(context);
                          final sidePadding = isCompact ? 8.0 : 10.0;
                          // Compact header icons are centered at 15dp; keep
                          // the bar's ends clear of the corner arc there.
                          final contentTop = (shellHeaderHeight - 15) / 2;
                          return UiScale(
                            scale: 1,
                            child: Container(
                              height: headerHeight,
                              padding: minimalGameLayout
                                  ? EdgeInsets.only(
                                      left:
                                          sidePadding +
                                          cornerInsetAt(
                                            corners.topLeft,
                                            contentTop,
                                          ),
                                      right:
                                          sidePadding +
                                          cornerInsetAt(
                                            corners.topRight,
                                            contentTop,
                                          ),
                                    )
                                  : EdgeInsets.symmetric(
                                      horizontal: sidePadding,
                                    ),
                              decoration: BoxDecoration(
                                color: appColor(
                                  context,
                                  const Color(0xff122431),
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: appColor(context, Color(0xff294052)),
                                  ),
                                ),
                              ),
                              child: TooltipVisibility(
                                visible: false,
                                child: Row(
                                  children: [
                                    ...[
                                      Material(
                                        color: appColor(
                                          context,
                                          isToolbarVisible
                                              ? const Color(0xff1a3447)
                                              : Colors.transparent,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          key: const Key('yahagi-brand-button'),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          onTap: isGameWorkspace
                                              ? widget.toolbarController.toggle
                                              : null,
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                  isCompact ? 2 : 4,
                                                  isCompact ? 2 : 6,
                                                  isCompact ? 6 : 8,
                                                  isCompact ? 2 : 6,
                                                ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Image.asset(
                                                    'assets/app_icon.png',
                                                    width: isCompact ? 26 : 30,
                                                    height: isCompact ? 26 : 30,
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.none,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: isCompact ? 2 : 4,
                                                ),
                                                Text(
                                                  'ヤハギ',
                                                  style: appTextStyle(
                                                    context,
                                                    TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: isCompact
                                                          ? 13
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                if (hdWindow || hdPortrait) ...[
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'HD',
                                                    key: const Key(
                                                      'yahagi-hd-label',
                                                    ),
                                                    style: TextStyle(
                                                      color: appColor(
                                                        context,
                                                        const Color(0xffffd54f),
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: isCompact
                                                          ? 12
                                                          : null,
                                                    ),
                                                  ),
                                                ],
                                                if (isGameWorkspace) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    isToolbarVisible
                                                        ? Icons.chevron_left
                                                        : Icons.chevron_right,
                                                    size: isCompact ? 14 : 16,
                                                    color: appColor(
                                                      context,
                                                      isToolbarVisible
                                                          ? const Color(
                                                              0xffd4a85f,
                                                            )
                                                          : const Color(
                                                              0xff8197a5,
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isCompact ? 6 : 8),
                                    ],
                                    Expanded(
                                      child: SizedBox(
                                        height: headerHeight,
                                        child: QuestCompletionHeaderSlot(
                                          toolbarVisible: isToolbarVisible,
                                          child: Stack(
                                            alignment: Alignment.centerLeft,
                                            children: [
                                              AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                opacity: isToolbarVisible
                                                    ? 0.0
                                                    : 1.0,
                                                child: IgnorePointer(
                                                  ignoring: isToolbarVisible,
                                                  // Retain the existing element
                                                  // path when hot reloading from
                                                  // the legacy resource layouts.
                                                  child: Visibility(
                                                    maintainState: true,
                                                    child: AnimatedBuilder(
                                                      animation: Listenable.merge(<
                                                        Listenable
                                                      >[
                                                        widget
                                                            .gameStateController,
                                                        if (widget
                                                                .senkaController !=
                                                            null)
                                                          widget
                                                              .senkaController!,
                                                      ]),
                                                      builder: (context, _) => WorkspaceContextHeader(
                                                        workspaceIndex:
                                                            _workspaceIndex,
                                                        state: widget
                                                            .gameStateController
                                                            .state,
                                                        senkaState: widget
                                                            .senkaController
                                                            ?.state,
                                                        onSenkaTap:
                                                            widget.senkaController ==
                                                                null
                                                            ? null
                                                            : () =>
                                                                  _selectWorkspace(
                                                                    9,
                                                                  ),
                                                        onFrameRefreshTap:
                                                            widget.gameFrameRefreshShortcutSettings ==
                                                                null
                                                            ? null
                                                            : _refreshGameFrameFromHeader,
                                                        onGameRefreshTap:
                                                            _refreshGameFromHeader,
                                                        anchorageRepairStartedAt: widget
                                                            .gameStateController
                                                            .anchorageRepairStartedAt,
                                                        onAnchorageTimerTap:
                                                            _openAnchorageRepairCenter,
                                                        nosakiSparkleStartedAt: widget
                                                            .gameStateController
                                                            .nosakiSparkleStartedAt,
                                                        onNosakiTimerTap:
                                                            _openNosakiRepairCenter,
                                                        layoutSettingsController:
                                                            widget
                                                                .layoutSettingsController,
                                                        flatStyle:
                                                            uiSize.isMinimal &&
                                                            isGameWorkspace,
                                                        uiSize:
                                                            uiSize.isMinimal &&
                                                                isGameWorkspace
                                                            ? UiDisplaySize
                                                                  .compact
                                                            : uiSize,
                                                        selectedFleetId:
                                                            _fleetCenterInitialFleetId ??
                                                            1,
                                                        onFleetSelected: (fleetId) {
                                                          setState(() {
                                                            _fleetCenterInitialFleetId =
                                                                fleetId;
                                                          });
                                                        },
                                                        inventoryShowShips:
                                                            _inventoryShowShips,
                                                        inventoryShowOwned:
                                                            _inventoryShowOwned,
                                                        onInventoryOwnershipChanged:
                                                            (value) {
                                                              setState(
                                                                () =>
                                                                    _inventoryShowOwned =
                                                                        value,
                                                              );
                                                            },
                                                        onInventorySectionChanged:
                                                            (value) {
                                                              setState(
                                                                () =>
                                                                    _inventoryShowShips =
                                                                        value,
                                                              );
                                                            },
                                                        logbookTabIndex:
                                                            _logbookTabIndex,
                                                        onLogbookTabChanged:
                                                            (value) {
                                                              setState(
                                                                () =>
                                                                    _logbookTabIndex =
                                                                        value,
                                                              );
                                                            },
                                                        settingsTabIndex:
                                                            _settingsTabIndex,
                                                        onSettingsTabChanged:
                                                            (value) {
                                                              setState(
                                                                () =>
                                                                    _settingsTabIndex =
                                                                        value,
                                                              );
                                                            },
                                                        repairMode:
                                                            _repairCenterMode,
                                                        onRepairModeChanged:
                                                            (mode) {
                                                              setState(
                                                                () =>
                                                                    _repairCenterMode =
                                                                        mode,
                                                              );
                                                            },
                                                        questMode:
                                                            _questCenterMode,
                                                        questFilters:
                                                            _questFilters,
                                                        questTranslationEnabled:
                                                            _questTranslationEnabled,
                                                        onQuestTranslationChanged:
                                                            (enabled) {
                                                              setState(
                                                                () =>
                                                                    _questTranslationEnabled =
                                                                        enabled,
                                                              );
                                                            },
                                                        onQuestModeChanged: (mode) {
                                                          setState(
                                                            () =>
                                                                _questCenterMode =
                                                                    mode,
                                                          );
                                                        },
                                                        expeditionMode:
                                                            _expeditionCenterMode,
                                                        onExpeditionModeChanged:
                                                            (mode) {
                                                              setState(
                                                                () =>
                                                                    _expeditionCenterMode =
                                                                        mode,
                                                              );
                                                            },
                                                        constructionMode:
                                                            _constructionCenterMode,
                                                        onConstructionModeChanged: (mode) {
                                                          setState(() {
                                                            _constructionCenterMode =
                                                                mode;
                                                            if (mode ==
                                                                ConstructionCenterMode
                                                                    .development) {
                                                              _developmentWorkbenchMode =
                                                                  DevelopmentWorkbenchMode
                                                                      .calculator;
                                                            }
                                                          });
                                                        },
                                                        developmentMode:
                                                            _developmentWorkbenchMode,
                                                        onDevelopmentModeChanged:
                                                            (mode) {
                                                              setState(
                                                                () =>
                                                                    _developmentWorkbenchMode =
                                                                        mode,
                                                              );
                                                            },
                                                        senkaMode:
                                                            _senkaCenterMode,
                                                        toolboxMode:
                                                            _toolboxMode,
                                                        onToolboxModeChanged:
                                                            (mode) {
                                                              setState(
                                                                () =>
                                                                    _toolboxMode =
                                                                        mode,
                                                              );
                                                            },
                                                        onSenkaModeChanged: (mode) {
                                                          setState(
                                                            () =>
                                                                _senkaCenterMode =
                                                                    mode,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IgnorePointer(
                                                ignoring: !isToolbarVisible,
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 240,
                                                  ),
                                                  reverseDuration:
                                                      const Duration(
                                                        milliseconds: 200,
                                                      ),
                                                  transitionBuilder:
                                                      (child, animation) {
                                                        final slide =
                                                            Tween<Offset>(
                                                              begin:
                                                                  const Offset(
                                                                    -0.2,
                                                                    0,
                                                                  ),
                                                              end: Offset.zero,
                                                            ).animate(
                                                              CurvedAnimation(
                                                                parent:
                                                                    animation,
                                                                curve: Curves
                                                                    .easeOutCubic,
                                                              ),
                                                            );
                                                        return FadeTransition(
                                                          opacity: animation,
                                                          child:
                                                              SlideTransition(
                                                                position: slide,
                                                                child: child,
                                                              ),
                                                        );
                                                      },
                                                  child: isToolbarVisible
                                                      ? KeyedSubtree(
                                                          key: const Key(
                                                            'game-toolbar-visible',
                                                          ),
                                                          child:
                                                              buildHeaderToolbar(),
                                                        )
                                                      : const SizedBox.shrink(
                                                          key: Key(
                                                            'game-toolbar-hidden',
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Flex(
                        direction: menuHorizontal
                            ? Axis.vertical
                            : Axis.horizontal,
                        verticalDirection: menuHorizontal && !menuTop
                            ? VerticalDirection.up
                            : VerticalDirection.down,
                        textDirection: workspaceNavigationTextDirection(
                          menuOnRight: widget
                              .layoutSettingsController
                              .workspaceMenuOnRight,
                        ),
                        children: [
                          if (!panelAlignedNavigation)
                            buildNavigationSidebar(completedCount),
                          Expanded(
                            key: const Key('workspace-content-expanded'),
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
                                        builder: (context, actualConstraints) {
                                          // The header and navigation around
                                          // this offstage subtree may differ
                                          // on other workspaces; freeze it so
                                          // the native surface keeps the
                                          // bounds the game was fitted to.
                                          if (_workspaceIndex != 0) {
                                            _gameWorkspaceSizeFrozen = true;
                                          } else if (!_gameFullscreen) {
                                            final size =
                                                actualConstraints.biggest;
                                            // A window change while frozen was
                                            // refitted against the old size.
                                            if (_gameWorkspaceSizeFrozen &&
                                                size != _normalWorkspaceSize) {
                                              _fitGameScreenAfterFrame();
                                            }
                                            _gameWorkspaceSizeFrozen = false;
                                            _normalWorkspaceSize = size;
                                          }
                                          final workspaceSize =
                                              _normalWorkspaceSize ??
                                              actualConstraints.biggest;
                                          final constraints =
                                              BoxConstraints.tight(
                                                workspaceSize,
                                              );
                                          final gameAreaRatio =
                                              widget
                                                  .layoutSettingsController
                                                  .autoZoom
                                              ? 0.67
                                              : widget
                                                    .layoutSettingsController
                                                    .gameAreaRatio
                                                    .clamp(0.5, 0.75);
                                          final hdGeometry = hdWindow
                                              ? HdWorkspaceGeometry.forSize(
                                                  constraints.biggest,
                                                  gameAreaRatio: gameAreaRatio,
                                                )
                                              : null;
                                          final isLandscape =
                                              hdGeometry != null ||
                                              !usesVerticalWorkspace(
                                                Size(
                                                  constraints.maxWidth,
                                                  constraints.maxHeight,
                                                ),
                                                screenDisplayMode,
                                              );
                                          final gameFlex =
                                              (gameAreaRatio * 1000).round();
                                          // Only a side rail leaves the game
                                          // column on the bottom screen edge;
                                          // a stacked workspace puts the
                                          // panel there. Not tied to the
                                          // workspace index so the rect holds
                                          // while the game is offstage.
                                          final gameTouchesBottom =
                                              flatShell &&
                                              isLandscape &&
                                              !menuHorizontal;
                                          final portraitGamePanelExtra =
                                              portraitGamePanelExtraExtent(
                                                displayMode: widget
                                                    .toolbarDisplayController
                                                    ?.mode,
                                                renderingMode: widget
                                                    .gameRenderingModeController
                                                    ?.mode,
                                              );
                                          final gameSurfaceWrapper =
                                              GameSurfaceViewport(
                                                aspectRatio: 1200 / 720,
                                                fullscreen: _gameFullscreen,
                                                isLandscape: isLandscape,
                                                displayMode: screenDisplayMode,
                                                fitWithinBounds:
                                                    menuHorizontal &&
                                                    !_gameFullscreen,
                                                centerAboveBottomInset:
                                                    gameTouchesBottom,
                                                child: GameSurfaceBoundary(
                                                  child: widget.gameSurface,
                                                ),
                                              );
                                          final gameWidget = GameBrowserOverlay(
                                            controller:
                                                widget.toolbarController,
                                            gameSurface: gameSurfaceWrapper,
                                          );

                                          Widget buildInfo({
                                            String? module,
                                          }) => _InformationPanel(
                                            key: module == null
                                                ? _settingsInformationPanelKey
                                                : null,
                                            questCatalogController:
                                                widget.questCatalogController,
                                            hdEditing: _hdEditing,
                                            onHdEditingChanged: (editing) =>
                                                setState(
                                                  () => _hdEditing =
                                                      editing &&
                                                      !widget
                                                          .layoutSettingsController
                                                          .uiLocked,
                                                ),
                                            hd:
                                                hdGeometry != null ||
                                                hdPortrait,
                                            hdPortrait: hdPortrait,
                                            singleModule: module,
                                            bottomSafeArea:
                                                flatShell &&
                                                    contentTouchesBottom
                                                ? bottomSafeArea
                                                : 0,
                                            excludedModules:
                                                hdGeometry != null &&
                                                    module == null
                                                ? widget
                                                      .layoutSettingsController
                                                      .hdSettings
                                                      .activeModules
                                                      .toSet()
                                                : const {},
                                            layoutSettingsController:
                                                widget.layoutSettingsController,
                                            safetySettingsController:
                                                widget.safetySettingsController,
                                            controller: widget.controller,
                                            browserController:
                                                widget.browserController,
                                            captureModeController:
                                                widget.captureModeController,
                                            gameCaptureController:
                                                widget.gameCaptureController,
                                            gameStateController:
                                                widget.gameStateController,
                                            moraleRecoveryTimerController: widget
                                                .moraleRecoveryTimerController,
                                            battleController:
                                                widget.battleController,
                                            battlePredictionSettingsController:
                                                widget
                                                    .battlePredictionSettingsController,
                                            onOpenFleet: (fleetId) {
                                              setState(() {
                                                _fleetCenterInitialFleetId =
                                                    fleetId;
                                              });
                                              _selectWorkspace(1);
                                            },
                                            onOpenRepair: (destination) {
                                              setState(() {
                                                _repairCenterMode =
                                                    destination.mode;
                                                _repairCenterInitialFleetId =
                                                    destination.fleetId;
                                              });
                                              _selectWorkspace(3);
                                            },
                                            onOpenConstruction: () =>
                                                _selectWorkspace(4),
                                            onOpenExpedition: () =>
                                                _selectWorkspace(2),
                                            onOpenQuest: (questId) {
                                              setState(() {
                                                _questCenterInitialQuestId =
                                                    questId;
                                              });
                                              _selectWorkspace(5);
                                            },
                                            onOpenExpeditionCheck: (fleetId) {
                                              setState(() {
                                                _expeditionCheckFleetId =
                                                    fleetId;
                                                _expeditionCenterMode =
                                                    ExpeditionSummaryMode.check;
                                              });
                                              _selectWorkspace(2);
                                            },
                                          );

                                          const dividerExtent = 1.0;
                                          final availableWidth =
                                              constraints.maxWidth -
                                              dividerExtent;
                                          final gamePanelExtent =
                                              hdGeometry?.gameWidth ??
                                              (isLandscape
                                                  ? availableWidth *
                                                        gameFlex /
                                                        1000
                                                  : (constraints.maxWidth *
                                                                720 /
                                                                1200 +
                                                            portraitGamePanelExtra)
                                                        .clamp(
                                                          0.0,
                                                          constraints
                                                                  .maxHeight -
                                                              dividerExtent,
                                                        )
                                                        .toDouble());

                                          final infoOnLeft =
                                              isLandscape &&
                                              widget
                                                  .layoutSettingsController
                                                  .informationPanelOnLeft;
                                          final infoPanelExtent =
                                              availableWidth - gamePanelExtent;
                                          final infoWidget = Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(
                                                child: PanelGameEdgeScope(
                                                  edge: panelGameEdgeFor(
                                                    isLandscape: isLandscape,
                                                    infoOnLeft: infoOnLeft,
                                                  ),
                                                  child: buildInfo(),
                                                ),
                                              ),
                                            ],
                                          );
                                          final menuNavigationExtent =
                                              shellNavigationExtent;

                                          // In landscape the "top" bar is laid
                                          // out under the game column, on the
                                          // bottom screen edge.
                                          final topMenuExtent = menuTop
                                              ? menuNavigationExtent +
                                                    (isLandscape
                                                        ? navigationGestureInset
                                                        : 0)
                                              : 0.0;
                                          final extensionAboveGame = widget
                                              .layoutSettingsController
                                              .hdSettings
                                              .extensionAboveGame;
                                          final topMenuY =
                                              (hdGeometry == null
                                                  ? null
                                                  : (extensionAboveGame
                                                        ? 0.0
                                                        : hdGeometry
                                                              .gameHeight)) ??
                                              (isLandscape
                                                  ? constraints.maxHeight -
                                                        topMenuExtent
                                                  : gamePanelExtent +
                                                        dividerExtent);
                                          return Stack(
                                            children: [
                                              Positioned(
                                                left:
                                                    !_gameFullscreen &&
                                                        infoOnLeft
                                                    ? infoPanelExtent +
                                                          dividerExtent
                                                    : 0,
                                                top:
                                                    !_gameFullscreen &&
                                                        hdGeometry != null &&
                                                        extensionAboveGame
                                                    ? hdGeometry.bottomHeight
                                                    : 0,
                                                width: _gameFullscreen
                                                    ? actualConstraints.maxWidth
                                                    : (isLandscape
                                                          ? gamePanelExtent
                                                          : constraints
                                                                .maxWidth),
                                                height: _gameFullscreen
                                                    ? actualConstraints
                                                          .maxHeight
                                                    : (isLandscape
                                                          ? (hdGeometry
                                                                    ?.gameHeight ??
                                                                constraints
                                                                        .maxHeight -
                                                                    topMenuExtent)
                                                          : gamePanelExtent),
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: appColor(
                                                      context,
                                                      Color(0xff0a1823),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: appColor(
                                                          context,
                                                          Colors.black38,
                                                        ),
                                                        offset: isLandscape
                                                            ? Offset(
                                                                infoOnLeft
                                                                    ? -2
                                                                    : 2,
                                                                0,
                                                              )
                                                            : const Offset(
                                                                0,
                                                                2,
                                                              ),
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
                                                top: isLandscape
                                                    ? 0
                                                    : gamePanelExtent,
                                                width: isLandscape
                                                    ? dividerExtent
                                                    : constraints.maxWidth,
                                                height: isLandscape
                                                    ? constraints.maxHeight
                                                    : dividerExtent,
                                                child: Offstage(
                                                  offstage: _gameFullscreen,
                                                  child: isLandscape
                                                      ? VerticalDivider(
                                                          width: dividerExtent,
                                                          thickness:
                                                              dividerExtent,
                                                          color: appColor(
                                                            context,
                                                            Color(0xff294052),
                                                          ),
                                                        )
                                                      : Divider(
                                                          height: dividerExtent,
                                                          thickness:
                                                              dividerExtent,
                                                          color: appColor(
                                                            context,
                                                            Color(0xff294052),
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              Positioned(
                                                left: isLandscape
                                                    ? (infoOnLeft
                                                          ? 0
                                                          : gamePanelExtent +
                                                                dividerExtent)
                                                    : (panelAlignedNavigation &&
                                                              !menuHorizontal &&
                                                              !widget
                                                                  .layoutSettingsController
                                                                  .workspaceMenuOnRight
                                                          ? menuNavigationExtent
                                                          : 0),
                                                top: isLandscape
                                                    ? 0
                                                    : gamePanelExtent +
                                                          dividerExtent +
                                                          topMenuExtent,
                                                width: math.max(
                                                  0.0,
                                                  isLandscape
                                                      ? infoPanelExtent
                                                      : constraints.maxWidth -
                                                            (panelAlignedNavigation &&
                                                                    !menuHorizontal
                                                                ? menuNavigationExtent
                                                                : 0),
                                                ),
                                                height: math.max(
                                                  0.0,
                                                  isLandscape
                                                      ? constraints.maxHeight
                                                      : constraints.maxHeight -
                                                            gamePanelExtent -
                                                            dividerExtent -
                                                            topMenuExtent,
                                                ),
                                                child: Offstage(
                                                  offstage: _gameFullscreen,
                                                  child: TickerMode(
                                                    enabled: !_gameFullscreen,
                                                    child: Padding(
                                                      key: const Key(
                                                        'workspace-information-panel',
                                                      ),
                                                      padding: isLandscape
                                                          ? (infoOnLeft
                                                                ? const EdgeInsets.only(
                                                                    right: 2,
                                                                  )
                                                                : const EdgeInsets.only(
                                                                    left: 2,
                                                                  ))
                                                          : const EdgeInsets.only(
                                                              top: 4,
                                                            ),
                                                      child: infoWidget,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (hdGeometry != null)
                                                Positioned(
                                                  key: const Key(
                                                    'hd-bottom-region',
                                                  ),
                                                  left: infoOnLeft
                                                      ? infoPanelExtent +
                                                            dividerExtent
                                                      : 0,
                                                  top:
                                                      (extensionAboveGame
                                                          ? 0.0
                                                          : hdGeometry
                                                                .gameHeight) +
                                                      topMenuExtent,
                                                  width: hdGeometry.gameWidth,
                                                  height: math.max(
                                                    0.0,
                                                    hdGeometry.bottomHeight -
                                                        topMenuExtent,
                                                  ),
                                                  child: Offstage(
                                                    offstage: _gameFullscreen,
                                                    child: TickerMode(
                                                      enabled: !_gameFullscreen,
                                                      child: HdBottomStrip(
                                                        editing: _hdEditing,
                                                        onStartEditing:
                                                            widget
                                                                .layoutSettingsController
                                                                .uiLocked
                                                            ? null
                                                            : () => setState(
                                                                () =>
                                                                    _hdEditing =
                                                                        true,
                                                              ),
                                                        controller: widget
                                                            .layoutSettingsController,
                                                        moduleBuilder:
                                                            (module) =>
                                                                buildInfo(
                                                                  module:
                                                                      module,
                                                                ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (panelAlignedNavigation &&
                                                  !_gameFullscreen)
                                                Positioned(
                                                  left: menuHorizontal
                                                      ? (isLandscape &&
                                                                infoOnLeft
                                                            ? infoPanelExtent +
                                                                  dividerExtent
                                                            : 0)
                                                      : (widget
                                                                .layoutSettingsController
                                                                .workspaceMenuOnRight
                                                            ? constraints
                                                                      .maxWidth -
                                                                  menuNavigationExtent
                                                            : 0),
                                                  top: menuHorizontal
                                                      ? topMenuY
                                                      : gamePanelExtent +
                                                            dividerExtent,
                                                  width: menuHorizontal
                                                      ? (isLandscape
                                                            ? gamePanelExtent
                                                            : constraints
                                                                  .maxWidth)
                                                      : menuNavigationExtent,
                                                  height: menuHorizontal
                                                      ? topMenuExtent
                                                      : math.max(
                                                          0.0,
                                                          constraints
                                                                  .maxHeight -
                                                              gamePanelExtent -
                                                              dividerExtent,
                                                        ),
                                                  child:
                                                      buildWorkspaceNavigation(
                                                        completedCount,
                                                        atScreenBottom:
                                                            menuHorizontal &&
                                                            isLandscape,
                                                        leftAtEdge: !infoOnLeft,
                                                        rightAtEdge: infoOnLeft,
                                                      ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                UiScale(
                                  // Settings keep standard control sizes in every mode.
                                  scale: _workspaceIndex == 8 ? 1.0 : uiScale,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (_workspaceIndex == 1)
                                        FleetInformationCenter(
                                          controller:
                                              widget.gameStateController,
                                          moraleRecoveryTimerController: widget
                                              .moraleRecoveryTimerController,
                                          moraleMetricMode: widget
                                              .layoutSettingsController
                                              .fleetMoraleMetricMode,
                                          onToggleMoraleMetricMode: widget
                                              .layoutSettingsController
                                              .toggleFleetMoraleMetricMode,
                                          damagePulseMode: widget
                                              .safetySettingsController
                                              .battleStatusEffects
                                              .pulseFilterFor(
                                                BattleEffectSurface.fleet,
                                              ),
                                          moraleSparkleMode: widget
                                              .safetySettingsController
                                              .battleStatusEffects
                                              .sparkleModeFor(
                                                BattleEffectSurface.fleet,
                                              ),
                                          page: FleetInformationPage.fleet,
                                          initialFleetId:
                                              _fleetCenterInitialFleetId,
                                          showContextHeader: false,
                                        ),
                                      if (_workspaceIndex == 2)
                                        FleetInformationCenter(
                                          controller:
                                              widget.gameStateController,
                                          page: FleetInformationPage.expedition,
                                          initialFleetId:
                                              _expeditionCheckFleetId,
                                          onFleetSelected: (fleetId) {
                                            setState(() {
                                              _expeditionCheckFleetId = fleetId;
                                            });
                                          },
                                          showContextHeader: false,
                                          expeditionMode: _expeditionCenterMode,
                                          onExpeditionModeChanged: (mode) {
                                            setState(
                                              () =>
                                                  _expeditionCenterMode = mode,
                                            );
                                          },
                                        ),
                                      if (_workspaceIndex == 3)
                                        FleetInformationCenter(
                                          controller:
                                              widget.gameStateController,
                                          page: FleetInformationPage.repair,
                                          initialFleetId:
                                              _repairCenterInitialFleetId,
                                          onFleetSelected: (fleetId) {
                                            setState(() {
                                              _repairCenterInitialFleetId =
                                                  fleetId;
                                            });
                                          },
                                          showContextHeader: false,
                                          repairMode: _repairCenterMode,
                                          onRepairModeChanged: (mode) {
                                            setState(
                                              () => _repairCenterMode = mode,
                                            );
                                          },
                                          showRepairModeTabs: false,
                                        ),
                                      if (_workspaceIndex == 4)
                                        FleetInformationCenter(
                                          controller:
                                              widget.gameStateController,
                                          page:
                                              FleetInformationPage.construction,
                                          showContextHeader: false,
                                          constructionMode:
                                              _constructionCenterMode,
                                          developmentRepository:
                                              _developmentRepository,
                                          developmentMode:
                                              _developmentWorkbenchMode,
                                          onDevelopmentModeChanged: (mode) {
                                            setState(
                                              () => _developmentWorkbenchMode =
                                                  mode,
                                            );
                                          },
                                          improvementController: widget
                                              .improvementPlannerController,
                                        ),
                                      if (_workspaceIndex == 5)
                                        QuestCenterPage(
                                          controller:
                                              widget.gameStateController,
                                          displayMode: screenDisplayMode,
                                          catalogController:
                                              widget.questCatalogController,
                                          initialQuestId:
                                              _questCenterInitialQuestId,
                                          showTitle: false,
                                          mode: _questCenterMode,
                                          filterController: _questFilters,
                                          translationEnabled:
                                              _questTranslationEnabled,
                                          onTranslationChanged: (enabled) {
                                            setState(
                                              () => _questTranslationEnabled =
                                                  enabled,
                                            );
                                          },
                                          onModeChanged: (mode) {
                                            setState(
                                              () => _questCenterMode = mode,
                                            );
                                          },
                                        ),
                                      if (_workspaceIndex == 6)
                                        LogbookPage(
                                          battleController:
                                              widget.battleController,
                                          occupiedInsets: logbookOccupiedInsets,
                                          selectedTabIndex: _logbookTabIndex,
                                          onTabChanged: (value) {
                                            setState(
                                              () => _logbookTabIndex = value,
                                            );
                                          },
                                        ),
                                      if (_workspaceIndex == 7)
                                        OwnedInventoryPage(
                                          controller:
                                              widget.gameStateController,
                                          reminderController:
                                              widget.newShipReminderController,
                                          showOwned: _inventoryShowOwned,
                                          onOwnershipChanged: (value) {
                                            setState(
                                              () => _inventoryShowOwned = value,
                                            );
                                          },
                                          showShips: _inventoryShowShips,
                                          onSectionChanged: (value) {
                                            setState(
                                              () => _inventoryShowShips = value,
                                            );
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
                                          audioController:
                                              widget.audioController,
                                          captureModeController:
                                              widget.captureModeController,
                                          browserController:
                                              widget.browserController,
                                          gameCaptureController:
                                              widget.gameCaptureController,
                                          kcwikiReportController:
                                              widget.kcwikiReportController,
                                          prototypeStatusController:
                                              widget.controller,
                                          gameStateController:
                                              widget.gameStateController,
                                          senkaController:
                                              widget.senkaController,
                                          gameResourceCacheController: widget
                                              .gameResourceCacheController,
                                          safetySettingsController:
                                              widget.safetySettingsController,
                                          notificationSettingsController: widget
                                              .notificationSettingsController,
                                          battlePredictionSettingsController: widget
                                              .battlePredictionSettingsController,
                                          gameFrameRateSettingsController: widget
                                              .gameFrameRateSettingsController,
                                          gameRenderingModeController: widget
                                              .gameRenderingModeController,
                                          gameConnectorController:
                                              widget.gameConnectorController,
                                          backgroundGameRetentionController: widget
                                              .backgroundGameRetentionController,
                                          appExitSettingsController:
                                              widget.appExitSettingsController,
                                          isBattleActive:
                                              widget.battleController.session !=
                                                  null &&
                                              !widget
                                                  .battleController
                                                  .session!
                                                  .completed,
                                          displayModeController:
                                              widget.displayModeController,
                                          currentVersion: widget.currentVersion,
                                          releaseChecker: widget.releaseChecker,
                                          screenAwakeController:
                                              widget.screenAwakeController,
                                          gameMouseWheelSettingsController: widget
                                              .gameMouseWheelSettingsController,
                                          gameFrameRefreshShortcutSettings: widget
                                              .gameFrameRefreshShortcutSettings,
                                          shipSubtitleSettingsController: widget
                                              .shipSubtitleSettingsController,
                                          shipSubtitleCatalogController: widget
                                              .shipSubtitleCatalogController,
                                          shipSubtitleRuntimeController: widget
                                              .shipSubtitleRuntimeController,
                                          toolbarDisplayController:
                                              widget.toolbarDisplayController,
                                          fcdMapController:
                                              widget.fcdMapController,
                                          questCatalogController:
                                              widget.questCatalogController,
                                          questProgressRulesController: widget
                                              .questProgressRulesController,
                                          sortieMapCatalogController:
                                              widget.sortieMapCatalogController,
                                          enemyCatalogController:
                                              widget.enemyCatalogController,
                                          improvementPlannerController: widget
                                              .improvementPlannerController,
                                          showTitle: false,
                                          showDeveloperDiagnostics:
                                              widget.showDeveloperDiagnostics,
                                          diagnosticController:
                                              widget.diagnosticController,
                                          telemetryController:
                                              widget.telemetryController,
                                          selectedIndex: _settingsTabIndex,
                                          onEditHeaderResources:
                                              _openHeaderResourceSettings,
                                          onEditDashboardLayout:
                                              _openDashboardLayoutSettings,
                                          onEditHdLayout:
                                              widget
                                                  .layoutSettingsController
                                                  .hdSettings
                                                  .enabled
                                              ? _openDashboardLayoutSettings
                                              : null,
                                        ),
                                      if (_workspaceIndex == 9 &&
                                          widget.senkaController != null)
                                        SenkaPage(
                                          controller: widget.senkaController!,
                                          accountSession:
                                              widget
                                                  .gameStateController
                                                  .accountSession ??
                                              LogbookDatabase.accountSession,
                                          mode: _senkaCenterMode,
                                          onOpenSortieLog: () {
                                            setState(
                                              () => _logbookTabIndex = 0,
                                            );
                                            _selectWorkspace(6);
                                          },
                                        ),
                                      if (_workspaceIndex == 10)
                                        AnimatedBuilder(
                                          animation: widget.gameStateController,
                                          builder: (context, _) => ToolboxPage(
                                            state: widget
                                                .gameStateController
                                                .state,
                                            mode: _toolboxMode,
                                            gameModsController:
                                                _gameModsController,
                                            compositionDraftController:
                                                _compositionDraftController ??=
                                                    CompositionImageDraftController(),
                                            sortieMapCatalogController: widget
                                                .sortieMapCatalogController,
                                            enemyCatalogController:
                                                widget.enemyCatalogController,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return GameModPortraitScope(
      controller: _gameModsController.portraits,
      child: shell,
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
    this.hd = false,
    this.leading,
    this.endInsets = EdgeInsets.zero,
  });

  final LayoutSettingsController controller;
  final int selectedIndex;
  final bool onRight;
  final ValueChanged<int> onSelected;
  final int completedQuestCount;
  final GameStateController? gameStateController;
  final DateTime Function()? clock;
  final bool hd;

  /// Pinned before the reorderable destinations and never part of the order.
  final Widget? leading;

  /// Room left at both ends for screen corners and the bottom system inset.
  /// Insets across the bar's thickness add to it instead of squeezing items.
  final EdgeInsets endInsets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final menuSize = effectiveUiDisplaySize(controller.uiDisplaySize, hd: hd);
    const scale = 1.0;
    final localEndInsets = endInsets * (1 / scale);
    final menuExtent = workspaceNavigationExtent(menuSize);
    final isCompact = menuSize.isCompactOrSmaller;
    final itemExtent = isCompact ? 50.0 : 52.0;
    return UiScale(
      scale: scale,
      child: SecondTickBuilder(
        now: clock,
        enabled: false,
        builder: (context, now, _) => Container(
          width: controller.workspaceMenuHorizontal
              ? null
              : menuExtent + localEndInsets.horizontal,
          height: controller.workspaceMenuHorizontal
              ? menuExtent + localEndInsets.vertical
              : null,
          decoration: BoxDecoration(
            color: appColor(context, Color(0xff0a1823)),
            border: controller.workspaceMenuHorizontal
                ? Border(
                    top: BorderSide(
                      color: appColor(context, Color(0xff294052)),
                    ),
                    bottom: BorderSide(
                      color: appColor(context, Color(0xff294052)),
                    ),
                  )
                : workspaceNavigationBorder(
                    context: context,
                    menuOnRight: onRight,
                  ),
          ),
          child: Padding(
            padding: localEndInsets,
            child: Flex(
              direction: controller.workspaceMenuHorizontal
                  ? Axis.horizontal
                  : Axis.vertical,
              children: [
                ?leading,
                Expanded(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      controller,
                      ?gameStateController,
                    ]),
                    builder: (context, _) {
                      final destinations = _workspaceDestinations(l10n);
                      final ordered = controller.workspaceMenuOrder
                          .map((id) => destinations[id])
                          .whereType<_WorkspaceDestination>()
                          .toList(growable: false);
                      return UiScale(
                        scale: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final centeredPadding =
                                (constraints.maxWidth -
                                    ordered.length * itemExtent * scale) /
                                2;
                            return ReorderableListView.builder(
                              key: const Key('workspace-navigation-list'),
                              scrollDirection:
                                  controller.workspaceMenuHorizontal
                                  ? Axis.horizontal
                                  : Axis.vertical,
                              padding: controller.workspaceMenuHorizontal
                                  ? EdgeInsets.symmetric(
                                      horizontal: centeredPadding > 10 * scale
                                          ? centeredPadding
                                          : 10 * scale,
                                    )
                                  : EdgeInsets.symmetric(
                                      vertical: (isCompact ? 10 : 8) * scale,
                                    ),
                              buildDefaultDragHandles: false,
                              itemCount: ordered.length,
                              onReorderItem: controller.uiLocked
                                  ? (_, _) {}
                                  : controller.reorderWorkspaceMenu,
                              itemBuilder: (context, index) {
                                final destination = ordered[index];
                                final navState = gameStateController?.state;
                                void handleTap() {
                                  onSelected(destination.pageIndex);
                                }

                                int countAt(DateTime at) =>
                                    switch (destination.id) {
                                      'quests' => completedQuestCount,
                                      'expedition' =>
                                        navState == null
                                            ? 0
                                            : activeExpeditionFleets(
                                                navState,
                                                at,
                                              ).length,
                                      'construction' =>
                                        navState == null
                                            ? 0
                                            : completedConstructionCount(
                                                navState,
                                                at,
                                              ),
                                      'repair' =>
                                        navState == null
                                            ? 0
                                            : busyRepairDocks(
                                                navState,
                                                at,
                                              ).length,
                                      _ => 0,
                                    };
                                Widget buttonForCount(
                                  int count,
                                ) => _NavigationButton(
                                  key: Key('workspace-nav-${destination.id}'),
                                  icon: destination.icon,
                                  label: destination.label,
                                  horizontal:
                                      controller.workspaceMenuHorizontal,
                                  menuSize: menuSize,
                                  completedCount: count,
                                  countKey: Key(switch (destination.id) {
                                    'repair' => 'repair-active-count',
                                    'expedition' => 'expedition-active-count',
                                    'quests' => 'quest-completion-count',
                                    _ => '${destination.id}-completion-count',
                                  }),
                                  countLabel: destination.id == 'quests'
                                      ? null
                                      : destination.label,
                                  selected:
                                      selectedIndex == destination.pageIndex,
                                  onTap: handleTap,
                                );
                                final timedBadge = switch (destination.id) {
                                  'expedition' ||
                                  'construction' ||
                                  'repair' => true,
                                  _ => false,
                                };
                                Widget button;
                                if (timedBadge) {
                                  // Only a changed badge count needs a new
                                  // button. Data, selection and preferences
                                  // recreate this cache in the parent builder.
                                  int? previousCount;
                                  Widget? cachedButton;
                                  button = SecondTickBuilder(
                                    now: clock,
                                    enabled: gameStateController != null,
                                    builder: (context, tick, _) {
                                      final count = countAt(tick);
                                      if (cachedButton == null ||
                                          previousCount != count) {
                                        previousCount = count;
                                        cachedButton = buttonForCount(count);
                                      }
                                      return cachedButton!;
                                    },
                                  );
                                } else {
                                  button = buttonForCount(countAt(now));
                                }

                                return UiScale(
                                  key: ValueKey(
                                    'workspace-nav-item-${destination.id}',
                                  ),
                                  scale: scale,
                                  child: SizedBox(
                                    width: controller.workspaceMenuHorizontal
                                        ? itemExtent
                                        : null,
                                    height: controller.workspaceMenuHorizontal
                                        ? null
                                        : itemExtent,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: handleTap,
                                      child: Center(
                                        child:
                                            ReorderableDelayedDragStartListener(
                                              index: index,
                                              enabled: !controller.uiLocked,
                                              child: button,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 保留既有 Flex → 带 key 的 Expanded → Column 祖先链，导航移到顶栏下方时
/// 热重载和切档都不会重新挂载游戏的平台视图。
class _SideRailColumn extends StatelessWidget {
  const _SideRailColumn({
    required this.rail,
    required this.railOnRight,
    required this.children,
  });

  final Widget? rail;
  final bool railOnRight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Flex(
    direction: Axis.horizontal,
    textDirection: workspaceNavigationTextDirection(menuOnRight: railOnRight),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ?rail,
      Expanded(
        key: const Key('workspace-side-rail-body'),
        child: Column(children: children),
      ),
    ],
  );
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
    this.horizontal = true,
    this.menuSize = UiDisplaySize.normal,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int completedCount;
  final Key countKey;
  final String? countLabel;
  final bool horizontal;
  final UiDisplaySize menuSize;

  @override
  Widget build(BuildContext context) {
    final isCompact = menuSize.isCompactOrSmaller;
    final btnSize = horizontal
        ? (isCompact ? const Size(42, 35) : const Size(44, 40))
        : (isCompact ? const Size(35, 42) : const Size(40, 44));
    final iconSize = isCompact ? 20.0 : 22.0;
    return Semantics(
      label: label,
      child: SizedBox(
        width: btnSize.width,
        height: btnSize.height,
        child: IconButton(
          onPressed: onTap,
          style: IconButton.styleFrom(
            fixedSize: btnSize,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: horizontal
                ? const EdgeInsets.only(top: 7.0)
                : EdgeInsets.zero,
            foregroundColor: appColor(
              context,
              selected ? const Color(0xffd4a85f) : const Color(0xff8197a5),
            ),
            backgroundColor: appColor(
              context,
              selected ? const Color(0xff2b2c22) : Colors.transparent,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          icon: QuestCompletionBadge(
            count: completedCount,
            countKey: countKey,
            semanticLabel: countLabel == null
                ? null
                : "$countLabel: $completedCount",
            child: Icon(icon, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _InformationPanel extends StatefulWidget {
  const _InformationPanel({
    super.key,
    this.questCatalogController,
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
    this.hd = false,
    this.hdPortrait = false,
    this.hdEditing = false,
    this.onHdEditingChanged,
    this.singleModule,
    this.excludedModules = const {},
    this.bottomSafeArea = 0,
  });

  final bool hd;
  final double bottomSafeArea;
  final QuestCatalogController? questCatalogController;
  final bool hdPortrait;
  final bool hdEditing;
  final ValueChanged<bool>? onHdEditingChanged;
  final String? singleModule;
  final Set<String> excludedModules;
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
  final Set<String> _hdCollapsed = {};
  String? _selectedTabId;

  bool _canCustomizeTabs() {
    if (!widget.layoutSettingsController.uiLocked) return true;
    final l10n = AppLocalizations.of(context)!;
    TopNotice.show(context, message: l10n.uiLockedToast);
    return false;
  }

  void _editTabOrder() {
    if (_canCustomizeTabs()) beginEditing();
  }

  IconData _tabIcon(String id) => switch (id) {
    'battle' => Icons.remove_red_eye_outlined,
    'fleet' => Icons.directions_boat_filled_outlined,
    'land_base' => Icons.flight_rounded,
    'expedition' => Icons.explore_outlined,
    'repair' => Icons.build_circle_outlined,
    'construction' => Icons.handyman_outlined,
    'quests' => Icons.assignment_outlined,
    'pre_sortie' => Icons.security_outlined,
    _ => Icons.dashboard_outlined,
  };

  void beginEditing() {
    if (!mounted || widget.layoutSettingsController.uiLocked) return;
    if (widget.hd) {
      widget.onHdEditingChanged?.call(true);
    } else {
      setState(() => _isEditing = true);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.layoutSettingsController.addListener(_handleLayoutSettingsChanged);
  }

  @override
  void didUpdateWidget(covariant _InformationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutSettingsController != widget.layoutSettingsController) {
      oldWidget.layoutSettingsController.removeListener(
        _handleLayoutSettingsChanged,
      );
      widget.layoutSettingsController.addListener(_handleLayoutSettingsChanged);
    }
    if (oldWidget.hd != widget.hd || widget.layoutSettingsController.uiLocked) {
      _isEditing = false;
    }
  }

  @override
  void dispose() {
    widget.layoutSettingsController.removeListener(
      _handleLayoutSettingsChanged,
    );
    super.dispose();
  }

  void _handleLayoutSettingsChanged() {
    if (!mounted) return;
    if (widget.layoutSettingsController.uiLocked && _isEditing) {
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiScale(
      scale: widget.layoutSettingsController.uiDisplaySize.isMinimal
          ? minimalUiScale
          : 1.0,
      child: Container(
        key: widget.singleModule == null
            ? const Key('information-panel')
            : ValueKey('hd-module-content-${widget.singleModule}'),
        decoration: BoxDecoration(
          color: appColor(
            context,
            widget.singleModule == null
                ? const Color(0xff0d1a26)
                : Colors.transparent,
          ),
          border: widget.singleModule == null
              ? Border(
                  left: BorderSide(color: appColor(context, Color(0xff294052))),
                )
              : null,
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
            final flat = usesFlatPanel(
              size: widget.layoutSettingsController.uiDisplaySize,
              hd: widget.hd,
            );
            final localBottomSafeArea =
                widget.bottomSafeArea / UiScale.of(context);
            final hasError =
                widget.browserController.loadState ==
                    GamePageLoadState.failed ||
                widget.gameCaptureController.state == GameCaptureState.error ||
                widget.gameCaptureController.state ==
                    GameCaptureState.unsupported;

            final editing =
                (widget.hd ? widget.hdEditing : _isEditing) &&
                !widget.layoutSettingsController.uiLocked;
            final tabbed =
                widget.layoutSettingsController.dashboardDisplayMode ==
                    DashboardDisplayMode.tabs &&
                !widget.hd &&
                !widget.layoutSettingsController.hdSettings.enabled &&
                !editing &&
                widget.singleModule == null &&
                !widget.hdPortrait;
            final collapsedIds =
                widget.layoutSettingsController.dashboardCardCollapsed;
            final hiddenIds = widget.hd
                ? widget.layoutSettingsController.hdSettings.hidden
                : widget.layoutSettingsController.dashboardCardHidden.toSet();
            final cardOrder = widget.singleModule != null
                ? [widget.singleModule!]
                : widget.hd
                ? widget.layoutSettingsController.hdSettings.orderedModules
                : widget.layoutSettingsController.dashboardCardOrder;
            final validCards = cardOrder
                .where(
                  (id) => LayoutSettingsStore.defaultDashboardCardOrder
                      .contains(id),
                )
                .toList();
            final visibleOrder = validCards
                .where(
                  (id) =>
                      !widget.excludedModules.contains(id) &&
                      (widget.singleModule != null || !hiddenIds.contains(id)),
                )
                .toList();
            Widget buildCard(String id) {
              final isCollapsed = tabbed
                  ? false
                  : widget.hd
                  ? editing || _hdCollapsed.contains(id)
                  : editing || collapsedIds.contains(id);
              void toggle() {
                if (widget.hd) {
                  setState(() {
                    if (!_hdCollapsed.remove(id)) _hdCollapsed.add(id);
                  });
                } else {
                  widget.layoutSettingsController.toggleDashboardCardCollapsed(
                    id,
                  );
                }
              }

              final fleetTwoColumns =
                  widget.hd &&
                  (widget.hdPortrait
                          ? widget.layoutSettingsController.hdSettings.portrait
                          : widget.layoutSettingsController.hdSettings.bottom)
                      .any(
                        (module) => module.id == 'fleet' && module.span == 2,
                      );
              final child = switch (id) {
                'fleet' => FleetSummaryCard(
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'fleet',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'fleet',
                  ),
                  twoColumnVisible:
                      widget.layoutSettingsController.hdFleetDisplayFields,
                  onOpenDisplaySettings: editing
                      ? () => showFleetDisplaySettings(
                          context,
                          widget.layoutSettingsController,
                          twoColumns: fleetTwoColumns,
                        )
                      : null,
                  visible: widget.layoutSettingsController.fleetDisplayFields,
                  shipTypeLabelMode:
                      widget.layoutSettingsController.fleetShipTypeLabelMode,
                  controller: widget.gameStateController,
                  moraleRecoveryTimerController:
                      widget.moraleRecoveryTimerController,
                  damagePulseFilter: widget
                      .safetySettingsController
                      .battleStatusEffects
                      .pulseFilterFor(BattleEffectSurface.fleet),
                  moraleSparkleMode: widget
                      .safetySettingsController
                      .battleStatusEffects
                      .sparkleModeFor(BattleEffectSurface.fleet),
                  collapsed: isCollapsed,
                  onToggleCollapse: editing ? () {} : toggle,
                  onOpenFleet: widget.onOpenFleet,
                ),
                'land_base' => LandBaseSummaryCard(
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'land_base',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'land_base',
                  ),
                  visible: widget.layoutSettingsController.moduleDisplayFields(
                    'land_base',
                  ),
                  onOpenDisplaySettings: editing
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
                  onToggleCollapse: editing ? () {} : toggle,
                ),
                'expedition' => ExpeditionSummaryCard(
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'expedition',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'expedition',
                  ),
                  visible: widget.layoutSettingsController.moduleDisplayFields(
                    'expedition',
                  ),
                  onOpenDisplaySettings: editing
                      ? () => showModuleDisplaySettings(
                          context,
                          widget.layoutSettingsController,
                          'expedition',
                        )
                      : null,
                  controller: widget.gameStateController,
                  collapsed: isCollapsed,
                  onToggleCollapse: editing ? () {} : toggle,
                  onOpenExpedition: widget.onOpenExpedition,
                  onOpenExpeditionCheck: widget.onOpenExpeditionCheck,
                ),

                'repair' => RepairSummaryCard(
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'repair',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'repair',
                  ),
                  visible: widget.layoutSettingsController.moduleDisplayFields(
                    'repair',
                  ),
                  onOpenDisplaySettings: editing
                      ? () => showModuleDisplaySettings(
                          context,
                          widget.layoutSettingsController,
                          'repair',
                        )
                      : null,
                  controller: widget.gameStateController,
                  collapsed: isCollapsed,
                  onToggleCollapse: editing ? () {} : toggle,
                  onOpenRepair: widget.onOpenRepair,
                ),
                'construction' => ConstructionSummaryCard(
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'construction',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'construction',
                  ),
                  visible: widget.layoutSettingsController.moduleDisplayFields(
                    'construction',
                  ),
                  onOpenDisplaySettings: editing
                      ? () => showModuleDisplaySettings(
                          context,
                          widget.layoutSettingsController,
                          'construction',
                        )
                      : null,
                  controller: widget.gameStateController,
                  collapsed: isCollapsed,
                  onToggleCollapse: editing ? () {} : toggle,
                  onOpenConstruction: widget.onOpenConstruction,
                ),
                'quests' => PinnedQuestsSummary(
                  catalogController: widget.questCatalogController,
                  visible: widget.layoutSettingsController.moduleDisplayFields(
                    'quests',
                  ),
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'quests',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'quests',
                  ),
                  onOpenDisplaySettings: editing
                      ? () => showModuleDisplaySettings(
                          context,
                          widget.layoutSettingsController,
                          'quests',
                        )
                      : null,
                  controller: widget.gameStateController,
                  collapsed: isCollapsed,
                  onToggleCollapse: editing ? () {} : toggle,
                  onOpenQuest: widget.onOpenQuest,
                ),
                'battle' => LiveBattleCard(
                  key: const PageStorageKey('dashboard-live-battle'),
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'battle',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'battle',
                  ),
                  onOpenDisplaySettings: editing
                      ? () => showModuleDisplaySettings(
                          context,
                          widget.layoutSettingsController,
                          'battle',
                        )
                      : null,
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
                  sectionOrder:
                      widget.battlePredictionSettingsController?.sectionOrder,
                  damagePulseMode: widget
                      .safetySettingsController
                      .battleStatusEffects
                      .pulseFilterFor(BattleEffectSurface.prediction),
                  collapsed: isCollapsed,
                  onToggleCollapse: editing ? () {} : toggle,
                ),
                'pre_sortie' => PreSortieCheckSummary(
                  key: const PageStorageKey('dashboard-pre-sortie'),
                  showLogo: widget.layoutSettingsController.moduleShowLogo(
                    'pre_sortie',
                  ),
                  showTitle: widget.layoutSettingsController.moduleShowName(
                    'pre_sortie',
                  ),
                  onOpenDisplaySettings: editing
                      ? () => showModuleDisplaySettings(
                          context,
                          widget.layoutSettingsController,
                          'pre_sortie',
                        )
                      : null,
                  controller: widget.gameStateController,
                  settingsController: widget.layoutSettingsController,
                  collapsed: isCollapsed,
                  onToggleCollapse: editing ? () {} : toggle,
                  onOpenFleet: widget.onOpenFleet,
                ),
                _ => const SizedBox.shrink(),
              };

              Widget finalChild = Padding(
                padding:
                    widget.singleModule == null && !widget.hdPortrait && !flat
                    ? const EdgeInsets.only(bottom: 6)
                    : EdgeInsets.zero,
                // Always wrapped: toggling the wrapper would change the cards'
                // parent type and reset their selection state.
                child: PanelStyleScope(
                  style: flat ? PanelStyle.flat : PanelStyle.card,
                  child: child,
                ),
              );

              return KeyedSubtree(key: ValueKey(id), child: finalChild);
            }

            if (widget.hdPortrait) {
              return HdPortraitGrid(
                controller: widget.layoutSettingsController,
                editing: editing,
                onEditingChanged: (value) =>
                    widget.onHdEditingChanged?.call(value),
                cardBuilder: buildCard,
              );
            }

            if (widget.singleModule == null && editing) {
              final controller = widget.layoutSettingsController;
              final modules = validCards
                  .where((id) => !widget.excludedModules.contains(id))
                  .toList();
              return PanelStyleScope(
                style: flat ? PanelStyle.flat : PanelStyle.card,
                child: DashboardEditor(
                  modules: modules,
                  hidden: hiddenIds,
                  cardBuilder: buildCard,
                  onToggle: (id) => widget.hd
                      ? controller.toggleHdModuleHidden(id)
                      : controller.toggleDashboardCardHidden(id),
                  onReset: () => widget.hd
                      ? controller.resetHdLayout()
                      : controller.resetDashboardCardOrder(),
                  onDone: () => widget.hd
                      ? widget.onHdEditingChanged?.call(false)
                      : setState(() => _isEditing = false),
                  onMove: (id, target, after) {
                    if (widget.hd) {
                      controller.moveHdModuleToSidebar(
                        id,
                        target: target,
                        after: after,
                      );
                    } else {
                      final order = [...validCards]..remove(id);
                      final index = target == null ? -1 : order.indexOf(target);
                      order.insert(
                        index < 0 ? order.length : index + (after ? 1 : 0),
                        id,
                      );
                      controller.setDashboardCardOrder(order);
                    }
                  },
                ),
              );
            }

            if (widget.singleModule != null) {
              return GestureDetector(
                onLongPress: editing
                    ? null
                    : () {
                        if (widget.layoutSettingsController.uiLocked) {
                          final l10n =
                              AppLocalizations.of(context) ??
                              lookupAppLocalizations(const Locale('zh'));
                          TopNotice.show(context, message: l10n.uiLockedToast);
                          return;
                        }
                        widget.onHdEditingChanged?.call(true);
                      },
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    key: ValueKey('hd-scroll-${widget.singleModule}'),
                    primary: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: buildCard(widget.singleModule!),
                    ),
                  ),
                ),
              );
            }

            return GestureDetector(
              onLongPress: editing
                  ? null
                  : () {
                      if (widget.layoutSettingsController.uiLocked) {
                        final l10n =
                            AppLocalizations.of(context) ??
                            lookupAppLocalizations(const Locale('zh'));
                        TopNotice.show(context, message: l10n.uiLockedToast);
                        return;
                      }
                      if (widget.hd) {
                        widget.onHdEditingChanged?.call(true);
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
              child: tabbed
                  ? Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        final selectedId = visibleOrder.contains(_selectedTabId)
                            ? _selectedTabId!
                            : visibleOrder.firstOrNull;
                        // A hidden selection falls back permanently; restoring
                        // that module later must not unexpectedly switch tabs.
                        _selectedTabId = selectedId;
                        return DashboardTabs(
                          tabs: [
                            for (final id in visibleOrder)
                              DashboardTab(
                                id: id,
                                label:
                                    !widget.layoutSettingsController
                                        .moduleShowName(id)
                                    ? ''
                                    : switch (id) {
                                        'battle' => l10n.briefingTabForecast,
                                        'fleet' => l10n.briefingTabFleet,
                                        'land_base' => l10n.briefingTabLandBase,
                                        'expedition' =>
                                          l10n.briefingTabExpedition,
                                        'repair' => l10n.briefingTabRepair,
                                        'construction' =>
                                          l10n.briefingTabConstruction,
                                        'quests' => l10n.briefingTabQuests,
                                        'pre_sortie' =>
                                          l10n.briefingTabPreSortie,
                                        _ => id,
                                      },
                                icon:
                                    widget.layoutSettingsController
                                            .moduleShowLogo(id) ||
                                        !widget.layoutSettingsController
                                            .moduleShowName(id)
                                    ? _tabIcon(id)
                                    : null,
                                title: switch (id) {
                                  'battle' => l10n.forecast,
                                  'fleet' => l10n.fleetBrief,
                                  'land_base' => l10n.landBaseBrief,
                                  'expedition' => l10n.expeditionBrief,
                                  'repair' => l10n.repairBrief,
                                  'construction' => l10n.constructionBrief,
                                  'quests' => l10n.questBrief,
                                  'pre_sortie' => l10n.preSortieCheck,
                                  _ => id,
                                },
                              ),
                          ],
                          selectedId: selectedId ?? '',
                          onSelected: (id) =>
                              setState(() => _selectedTabId = id),
                          onLongPressTab: (_) => _editTabOrder(),
                          cardBuilder: buildCard,
                          contentPadding: flat
                              ? EdgeInsets.only(bottom: localBottomSafeArea)
                              : EdgeInsets.fromLTRB(
                                  8,
                                  8,
                                  8,
                                  localBottomSafeArea,
                                ),
                          footer: hasError
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: _InfoCard(
                                    title: l10n.gameStatusError,
                                    subtitle: runtimeMessageText(
                                      context,
                                      widget
                                              .gameCaptureController
                                              .errorMessage ??
                                          widget
                                              .browserController
                                              .errorMessage ??
                                          l10n.gameStatusErrorDesc,
                                    ),
                                    warning: true,
                                  ),
                                )
                              : null,
                        );
                      },
                    )
                  : ListView(
                      primary: widget.hd ? false : null,
                      key: widget.singleModule == null
                          ? null
                          : ValueKey('hd-scroll-${widget.singleModule}'),
                      padding: widget.singleModule != null
                          ? EdgeInsets.zero
                          : widget.hd
                          ? const EdgeInsets.all(8)
                          : flat
                          ? EdgeInsets.only(bottom: localBottomSafeArea)
                          : EdgeInsets.fromLTRB(8, 8, 8, localBottomSafeArea),
                      children: [
                        for (final id in visibleOrder) buildCard(id),
                        if (hasError && widget.singleModule == null)
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
        color: appColor(
          context,
          warning ? const Color(0xff3a292b) : const Color(0xff142735),
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: appColor(
            context,
            warning ? const Color(0xff75484a) : Colors.transparent,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: appColor(context, Color(0xff8197a5)),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
