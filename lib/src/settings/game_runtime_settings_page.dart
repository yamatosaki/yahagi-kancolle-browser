import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../audio/game_audio_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/capture_mode_selector.dart';
import '../localization/runtime_message_text.dart';
import '../subtitles/ship_subtitle_runtime_controller.dart';
import '../subtitles/ship_subtitle_settings.dart';
import '../subtitles/ship_subtitle_settings_section.dart';
import '../theme/app_palette.dart';
import 'app_exit_settings.dart';
import 'app_exit_settings_section.dart';
import 'background_game_retention_controller.dart';
import 'game_frame_rate_settings.dart';
import 'game_frame_rate_settings_section.dart';
import 'game_frame_refresh_shortcut_settings.dart';
import 'game_mouse_wheel_settings.dart';
import 'game_mouse_wheel_settings_section.dart';
import 'game_rendering_mode_controller.dart';
import 'game_rendering_mode_section.dart';
import 'layout_settings_controller.dart';
import 'screen_awake_controller.dart';
import 'settings_organization_strings.dart';
import 'settings_ui_helpers.dart';

class GameRuntimeSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const GameRuntimeSettingsPage({
    super.key,
    required this.layoutSettingsController,
    this.gameFrameRateSettingsController,
    this.gameRenderingModeController,
    this.audioController,
    this.shipSubtitleSettingsController,
    this.shipSubtitleRuntimeController,
    this.backgroundGameRetentionController,
    this.screenAwakeController,
    this.appExitSettingsController,
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.captureModeController,
    this.isBattleActive = false,
  });

  final LayoutSettingsController layoutSettingsController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final GameRenderingModeController? gameRenderingModeController;
  final GameAudioController? audioController;
  final ShipSubtitleSettingsController? shipSubtitleSettingsController;
  final ShipSubtitleRuntimeController? shipSubtitleRuntimeController;
  final BackgroundGameRetentionController? backgroundGameRetentionController;
  final ScreenAwakeController? screenAwakeController;
  final AppExitSettingsController? appExitSettingsController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final CaptureModeController? captureModeController;
  final bool isBattleActive;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    String text(String source) => settingsOrganizationText(context, source);
    final groups = <Widget>[
      if (gameFrameRateSettingsController != null ||
          gameRenderingModeController != null)
        _section(text('settingsGroupPerformanceRendering'), [
          if (gameFrameRateSettingsController case final frameRate?)
            GameFrameRateSettingsSection(controller: frameRate),
          if (gameRenderingModeController case final rendering?) ...[
            if (gameFrameRateSettingsController != null) _divider(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.gameRenderingModeTitle,
                style: appTextStyle(context, SettingsTileTypography.title),
              ),
            ),
            GameRenderingModeSection(
              controller: rendering,
              isBattleActive: isBattleActive,
            ),
          ],
        ]),
      if (audioController case final audio?)
        _section(l10n.gameAndSound, [
          AnimatedBuilder(
            animation: audio,
            builder: (context, _) => Column(
              children: [
                buildSwitchTile(
                  title: l10n.gameSound,
                  value: !audio.isMuted,
                  onChanged: (value) {
                    if (audio.canToggle) audio.toggleMuted();
                  },
                ),
                _divider(context),
                buildSwitchTile(
                  title: l10n.backgroundAudio,
                  titleKey: const Key('settings-background-audio'),
                  subtitle: l10n.backgroundAudioDesc,
                  value: audio.backgroundPlaybackEnabled,
                  onChanged: audio.setBackgroundPlaybackEnabled,
                ),
              ],
            ),
          ),
        ]),
      if (shipSubtitleSettingsController case final subtitles?)
        _section(text('settingsGroupSubtitles'), [
          ShipSubtitleSettingsSection(
            controller: subtitles,
            runtimeController: shipSubtitleRuntimeController,
          ),
        ]),
      if (screenAwakeController != null ||
          backgroundGameRetentionController != null)
        _section(text('settingsGroupScreenBackground'), [
          if (screenAwakeController case final awake?)
            AnimatedBuilder(
              animation: awake,
              builder: (context, _) => buildSwitchTile(
                title: l10n.screenAwake,
                switchKey: const Key('settings-screen-awake'),
                subtitle: l10n.screenAwakeDesc,
                value: awake.enabled,
                onChanged: awake.setEnabled,
              ),
            ),
          if (backgroundGameRetentionController case final retention?) ...[
            if (screenAwakeController != null) _divider(context),
            AnimatedBuilder(
              animation: retention,
              builder: (context, _) => buildSwitchTile(
                title: l10n.backgroundGameRetention,
                titleKey: const Key('settings-background-game-retention'),
                subtitle: switch (retention.errorMessage) {
                  final error? => runtimeMessageText(context, error),
                  null => l10n.backgroundGameRetentionDesc,
                },
                value: retention.enabled,
                onChanged: retention.setEnabled,
              ),
            ),
          ],
        ]),
      if (appExitSettingsController != null ||
          gameMouseWheelSettingsController != null ||
          gameFrameRefreshShortcutSettings != null)
        _section(l10n.operationProtectionTitle, [
          if (appExitSettingsController case final exit?)
            AppExitSettingsSection(controller: exit),
          if (gameMouseWheelSettingsController case final wheel?) ...[
            if (appExitSettingsController != null) _divider(context),
            GameMouseWheelSettingsSection(controller: wheel),
          ],
          if (gameFrameRefreshShortcutSettings case final refresh?) ...[
            if (appExitSettingsController != null ||
                gameMouseWheelSettingsController != null)
              _divider(context),
            AnimatedBuilder(
              animation: refresh,
              builder: (context, _) => Column(
                children: [
                  buildSwitchTile(
                    title: text('settingsFrameRefreshConfirm'),
                    switchKey: const Key('settings-frame-refresh-confirmation'),
                    subtitle: text('settingsFrameRefreshConfirmDescription'),
                    value: !refresh.skipHeaderConfirmation,
                    onChanged: refresh.saving
                        ? null
                        : (value) => refresh.setSkipHeaderConfirmation(!value),
                  ),
                  if (refresh.saveFailed)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        text('settingsFrameRefreshConfirmSaveFailed'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ]),
      if (captureModeController case final capture?)
        _section(text('settingsGroupInformationCapture'), [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CaptureModeSelector(controller: capture),
          ),
        ]),
    ];
    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < groups.length; index++) ...[
              if (index > 0) const SizedBox(height: 24),
              groups[index],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildSectionTitle(title),
      buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ],
  );

  Widget _divider(BuildContext context) =>
      Divider(color: appColor(context, const Color(0xff294052)), height: 1);
}
