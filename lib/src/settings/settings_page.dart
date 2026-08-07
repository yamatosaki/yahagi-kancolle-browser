import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
import '../browser/game_toolbar_display_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/game_capture_controller.dart';
import '../prototype_status_controller.dart';
import '../game_state/game_state_controller.dart';
import 'layout_settings_controller.dart';
import 'display_mode_controller.dart';
import 'safety_settings_controller.dart';
import 'network_settings_controller.dart';
import 'release_check_service.dart';
import 'screen_awake_controller.dart';
import '../battle/fcd_map_controller.dart';
import 'screen_settings_page.dart';
import 'sound_settings_page.dart';
import 'battle_settings_page.dart';
import 'network_settings_page_new.dart';
import 'about_support_settings_page.dart';
import 'battle_prediction_settings.dart';
import 'game_frame_rate_settings.dart';

class SettingsPage extends StatelessWidget {
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
    required this.safetySettingsController,
    required this.currentVersion,
    this.releaseChecker,
    this.screenAwakeController,
    this.toolbarDisplayController,
    this.fcdMapController,
    this.showTitle = true,
    this.showDeveloperDiagnostics = false,
    this.battlePredictionSettingsController,
    this.gameFrameRateSettingsController,
    this.selectedIndex = 0,
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
  final SafetySettingsController safetySettingsController;
  final bool showTitle;
  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final ScreenAwakeController? screenAwakeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final FcdMapController? fcdMapController;
  final bool showDeveloperDiagnostics;
  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        ScreenSettingsPage(
          layoutSettingsController: layoutSettingsController,
          displayModeController: displayModeController,
          toolbarDisplayController: toolbarDisplayController,
          captureModeController: captureModeController,
          gameFrameRateSettingsController: gameFrameRateSettingsController,
          screenAwakeController: screenAwakeController,
        ),
        SoundSettingsPage(
          audioController: audioController,
        ),
        BattleSettingsPage(
          battlePredictionSettingsController: battlePredictionSettingsController,
          fcdMapController: fcdMapController,
          safetySettingsController: safetySettingsController,
        ),
        NetworkSettingsPageNew(
          networkSettingsController: networkSettingsController,
          gadgetBypassController: gadgetBypassController,
          gameStateController: gameStateController,
          browserController: browserController,
        ),
        AboutSupportSettingsPage(
          currentVersion: currentVersion,
          releaseChecker: releaseChecker,
          prototypeStatusController: prototypeStatusController,
          browserController: browserController,
          captureModeController: captureModeController,
          gameCaptureController: gameCaptureController,
          showDeveloperDiagnostics: showDeveloperDiagnostics,
        ),
      ],
    );
  }
}
