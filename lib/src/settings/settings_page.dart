import 'package:flutter/material.dart';
import '../widgets/lazy_indexed_stack.dart';

import '../audio/game_audio_controller.dart';
import '../subtitles/ship_subtitle_settings.dart';
import '../subtitles/ship_subtitle_catalog_controller.dart';
import '../subtitles/ship_subtitle_runtime_controller.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
import '../browser/game_toolbar_display_controller.dart';
import '../browser/game_resource_cache_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/game_capture_controller.dart';
import '../diagnostics/diagnostic_controller.dart';
import '../prototype_status_controller.dart';
import '../game_state/game_state_controller.dart';
import '../senka/senka_controller.dart';
import '../kcwiki_report/kcwiki_report_settings.dart';
import 'layout_settings_controller.dart';
import 'display_mode_controller.dart';
import 'safety_settings_controller.dart';
import 'network_settings_controller.dart';
import 'release_check_service.dart';
import 'screen_awake_controller.dart';
import 'app_exit_settings.dart';
import 'game_mouse_wheel_settings.dart';
import 'game_frame_refresh_shortcut_settings.dart';
import '../battle/fcd_map_controller.dart';
import '../quest/quest_catalog_controller.dart';
import '../quest/quest_progress_rules_controller.dart';
import '../toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import '../toolbox/sortie_map_query/enemy_catalog_controller.dart';
import '../improvement/improvement_planner_controller.dart';
import 'screen_settings_page.dart';
import 'game_runtime_settings_page.dart';
import 'battle_settings_page.dart';
import 'notification_settings_controller.dart';
import 'notification_settings_page.dart';
import 'network_settings_page_new.dart';
import 'data_settings_page.dart';
import 'about_support_settings_page.dart';
import 'battle_prediction_settings.dart';
import 'background_game_retention_controller.dart';
import 'game_frame_rate_settings.dart';
import 'game_rendering_mode_controller.dart';
import 'game_connector_controller.dart';
import '../telemetry/telemetry_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.layoutSettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.displayModeController,
    required this.audioController,
    required this.captureModeController,
    required this.browserController,
    required this.gameCaptureController,
    required this.prototypeStatusController,
    required this.gameStateController,
    this.senkaController,
    this.gameResourceCacheController,
    this.kcwikiReportController,
    required this.safetySettingsController,
    this.notificationSettingsController,
    this.backgroundGameRetentionController,
    required this.currentVersion,
    this.releaseChecker,
    this.screenAwakeController,
    this.appExitSettingsController,
    this.gameMouseWheelSettingsController,
    this.shipSubtitleSettingsController,
    this.shipSubtitleCatalogController,
    this.shipSubtitleRuntimeController,
    this.gameFrameRefreshShortcutSettings,
    this.toolbarDisplayController,
    this.fcdMapController,
    this.questCatalogController,
    this.questProgressRulesController,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.improvementPlannerController,
    this.showTitle = true,
    this.showDeveloperDiagnostics = false,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.selectedIndex = 0,
    this.gameRenderingModeController,
    this.gameConnectorController,
    this.isBattleActive = false,
    this.diagnosticController,
    this.telemetryController,
    this.onEditHeaderResources,
    this.onEditDashboardLayout,
    this.onEditHdLayout,
  });

  final LayoutSettingsController layoutSettingsController;
  final NetworkSettingsController networkSettingsController;
  final GadgetBypassController gadgetBypassController;
  final DisplayModeController displayModeController;
  final GameAudioController audioController;
  final CaptureModeController captureModeController;
  final GameBrowserController browserController;
  final GameCaptureController gameCaptureController;
  final PrototypeStatusController prototypeStatusController;
  final GameStateController gameStateController;
  final SenkaController? senkaController;
  final GameResourceCacheController? gameResourceCacheController;
  final KcwikiReportController? kcwikiReportController;
  final SafetySettingsController safetySettingsController;
  final NotificationSettingsController? notificationSettingsController;
  final BackgroundGameRetentionController? backgroundGameRetentionController;
  final bool showTitle;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final AppExitSettingsController? appExitSettingsController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final ShipSubtitleSettingsController? shipSubtitleSettingsController;
  final ShipSubtitleCatalogController? shipSubtitleCatalogController;
  final ShipSubtitleRuntimeController? shipSubtitleRuntimeController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final GameToolbarDisplayController? toolbarDisplayController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final QuestProgressRulesController? questProgressRulesController;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final bool showDeveloperDiagnostics;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final int selectedIndex;
  final GameRenderingModeController? gameRenderingModeController;
  final GameConnectorController? gameConnectorController;
  final bool isBattleActive;
  final DiagnosticController? diagnosticController;
  final TelemetryController? telemetryController;

  final VoidCallback? onEditHeaderResources;
  final VoidCallback? onEditDashboardLayout;
  final VoidCallback? onEditHdLayout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  NotificationSettingsController? _fallbackNotifications;

  @override
  void dispose() {
    _fallbackNotifications?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget;
    final notifications =
        settings.notificationSettingsController ??
        (_fallbackNotifications ??= NotificationSettingsController());
    return LazyIndexedStack(
      index: settings.selectedIndex,
      children: [
        ScreenSettingsPage(
          layoutSettingsController: settings.layoutSettingsController,
          displayModeController: settings.displayModeController,
          onEditHeaderResources: settings.onEditHeaderResources,
          onEditDashboardLayout: settings.onEditDashboardLayout,
          onEditHdLayout: settings.onEditHdLayout,
        ),
        GameRuntimeSettingsPage(
          layoutSettingsController: settings.layoutSettingsController,
          audioController: settings.audioController,
          shipSubtitleSettingsController:
              settings.shipSubtitleSettingsController,
          shipSubtitleRuntimeController: settings.shipSubtitleRuntimeController,
          backgroundGameRetentionController:
              settings.backgroundGameRetentionController,
          gameFrameRateSettingsController:
              settings.gameFrameRateSettingsController,
          screenAwakeController: settings.screenAwakeController,
          appExitSettingsController: settings.appExitSettingsController,
          gameMouseWheelSettingsController:
              settings.gameMouseWheelSettingsController,
          gameFrameRefreshShortcutSettings:
              settings.gameFrameRefreshShortcutSettings,
          gameRenderingModeController: settings.gameRenderingModeController,
          captureModeController: settings.captureModeController,
          isBattleActive: settings.isBattleActive,
        ),
        BattleSettingsPage(
          battlePredictionSettingsController:
              settings.battlePredictionSettingsController,
          safetySettingsController: settings.safetySettingsController,
          notificationSettingsController: notifications,
        ),
        NotificationSettingsPage(
          controller: notifications,
          layoutSettingsController: settings.layoutSettingsController,
        ),
        NetworkSettingsPageNew(
          networkSettingsController: settings.networkSettingsController,
          gadgetBypassController: settings.gadgetBypassController,
          browserController: settings.browserController,
          gameConnectorController: settings.gameConnectorController,
          gameStateController: settings.gameStateController,
        ),
        DataSettingsPage(
          captureModeController: settings.captureModeController,
          browserController: settings.browserController,
          gameCaptureController: settings.gameCaptureController,
          prototypeStatusController: settings.prototypeStatusController,
          gameStateController: settings.gameStateController,
          senkaController: settings.senkaController,
          gameResourceCacheController: settings.gameResourceCacheController,
          kcwikiReportController: settings.kcwikiReportController,
          fcdMapController: settings.fcdMapController,
          questCatalogController: settings.questCatalogController,
          questProgressRulesController: settings.questProgressRulesController,
          sortieMapCatalogController: settings.sortieMapCatalogController,
          enemyCatalogController: settings.enemyCatalogController,
          improvementPlannerController: settings.improvementPlannerController,
          shipSubtitleCatalogController: settings.shipSubtitleCatalogController,
          telemetryController: settings.telemetryController,
        ),
        AboutSupportSettingsPage(
          currentVersion: settings.currentVersion,
          releaseChecker: settings.releaseChecker,
          diagnosticController: settings.diagnosticController,
          showDeveloperDiagnostics: settings.showDeveloperDiagnostics,
          browserController: settings.browserController,
          captureModeController: settings.captureModeController,
          gameCaptureController: settings.gameCaptureController,
          prototypeStatusController: settings.prototypeStatusController,
          gameRenderingModeController: settings.gameRenderingModeController,
        ),
      ],
    );
  }
}
