import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_browser_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/game_capture_controller.dart';
import '../diagnostics/diagnostic_controller.dart';
import '../prototype_status_controller.dart';
import 'about_dialog.dart';
import 'diagnostic_user_section.dart';
import 'diagnostics_section.dart';
import 'game_rendering_mode_controller.dart';
import 'settings_detail_page.dart';
import 'settings_organization_strings.dart';
import 'release_check_service.dart';
import 'settings_ui_helpers.dart';

class AboutSupportSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const AboutSupportSettingsPage({
    super.key,
    required this.currentVersion,
    this.releaseChecker,
    this.diagnosticController,
    this.showDeveloperDiagnostics = false,
    this.browserController,
    this.captureModeController,
    this.gameCaptureController,
    this.prototypeStatusController,
    this.gameRenderingModeController,
  });

  final String currentVersion;
  final ReleaseChecker? releaseChecker;
  final DiagnosticController? diagnosticController;
  final bool showDeveloperDiagnostics;
  final GameBrowserController? browserController;
  final CaptureModeController? captureModeController;
  final GameCaptureController? gameCaptureController;
  final PrototypeStatusController? prototypeStatusController;
  final GameRenderingModeController? gameRenderingModeController;

  bool get _hasDeveloperDiagnostics =>
      showDeveloperDiagnostics &&
      browserController != null &&
      captureModeController != null &&
      gameCaptureController != null &&
      prototypeStatusController != null;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildSectionTitle(l10n.aboutApp),
            AboutContentWidget(
              currentVersion: currentVersion,
              releaseChecker: releaseChecker,
              supportSection: _diagnosticEntry(context, l10n),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget? _diagnosticEntry(BuildContext context, AppLocalizations l10n) {
    if (diagnosticController == null && !_hasDeveloperDiagnostics) return null;
    final title = settingsOrganizationText(
      context,
      'settingsGroupDiagnosticsSupport',
    );
    final entry = buildActionTile(
      key: const Key('settings-diagnostics-entry'),
      title: title,
      subtitle: l10n.diagnosticLoggingDesc,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openSettingsDetail(
        context,
        title: title,
        child: Column(
          children: [
            if (diagnosticController case final diagnostics?) ...[
              AnimatedBuilder(
                animation: diagnostics,
                builder: (context, _) => buildSwitchTile(
                  switchKey: const Key('diagnosticLoggingSwitch'),
                  title: l10n.diagnosticLoggingTitle,
                  subtitle: l10n.diagnosticLoggingDesc,
                  value: diagnostics.enabled,
                  onChanged: diagnostics.setEnabled,
                ),
              ),
              const Divider(height: 1),
              DiagnosticUserSection(controller: diagnostics),
            ],
            if (_hasDeveloperDiagnostics) ...[
              if (diagnosticController != null) const Divider(height: 1),
              DiagnosticsSection(
                browserController: browserController!,
                captureModeController: captureModeController!,
                gameCaptureController: gameCaptureController!,
                prototypeStatusController: prototypeStatusController!,
                gameRenderingModeController: gameRenderingModeController,
              ),
            ],
          ],
        ),
      ),
    );
    return Column(children: [const Divider(height: 1), entry]);
  }
}
