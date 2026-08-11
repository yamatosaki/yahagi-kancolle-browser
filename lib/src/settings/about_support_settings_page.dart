import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_browser_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/game_capture_controller.dart';
import '../prototype_status_controller.dart';
import 'about_dialog.dart';
import 'diagnostics_section.dart';
import 'release_check_service.dart';
import 'settings_ui_helpers.dart';
import 'game_rendering_mode_controller.dart';

class AboutSupportSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const AboutSupportSettingsPage({
    super.key,
    required this.currentVersion,
    this.releaseChecker,
    required this.prototypeStatusController,
    required this.browserController,
    required this.captureModeController,
    required this.gameCaptureController,
    this.showDeveloperDiagnostics = false,
    this.gameRenderingModeController,
  });

  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final PrototypeStatusController prototypeStatusController;
  final GameBrowserController browserController;
  final CaptureModeController captureModeController;
  final GameCaptureController gameCaptureController;
  final bool showDeveloperDiagnostics;
  final GameRenderingModeController? gameRenderingModeController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: const Color(0xff0d1a26),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildSectionTitle(l10n.aboutApp),
            AboutContentWidget(
              currentVersion: currentVersion,
              releaseChecker: releaseChecker,
            ),
            if (showDeveloperDiagnostics) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.diagnosticsAndAbout),
              buildCard(
                child: DiagnosticsSection(
                  browserController: browserController,
                  captureModeController: captureModeController,
                  gameCaptureController: gameCaptureController,
                  prototypeStatusController: prototypeStatusController,
                  gameRenderingModeController: gameRenderingModeController,
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
