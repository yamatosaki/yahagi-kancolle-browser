import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../audio/game_audio_controller.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
import '../browser/game_toolbar_display_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/capture_mode_selector.dart';
import '../capture/game_capture_controller.dart';
import '../prototype_status_controller.dart';
import '../game_state/game_state_controller.dart';
import 'diagnostics_section.dart';
import 'layout_settings_controller.dart';
import 'display_mode_controller.dart';
import 'display_mode_section.dart';
import 'safety_settings_controller.dart';
import 'safety_settings_store.dart';
import '../logbook/logbook_database.dart';
import 'about_dialog.dart';
import 'network_settings_controller.dart';
import 'network_settings_section.dart';
import 'gadget_bypass_section.dart';
import 'release_check_service.dart';
import 'screen_awake_controller.dart';
import '../battle/fcd_map_controller.dart';
import 'fcd_map_update_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.layoutSettingsController,
    required this.audioController,
    required this.captureModeController,
    required this.browserController,
    required this.gameCaptureController,
    required this.prototypeStatusController,
    required this.gameStateController,
    required this.safetySettingsController,
    required this.networkSettingsController,
    required this.gadgetBypassController,
    required this.displayModeController,
    this.currentVersion = '1.0.2',
    this.releaseChecker,
    this.screenAwakeController,
    this.toolbarDisplayController,
    this.fcdMapController,
    this.showTitle = true,
    this.showDeveloperDiagnostics = false,
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

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: showTitle
          ? AppBar(
              title: Text(
                l10n.settingsTitle,
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: const Color(0xff0d1a26),
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      body: Container(
        color: const Color(0xff0d1a26),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(l10n.layoutSettings),
              _buildCard(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    layoutSettingsController,
                    displayModeController,
                  ]),
                  builder: (context, _) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.language,
                              key: const Key('settings-language-label'),
                            ),
                            DropdownButton<String>(
                              value:
                                  layoutSettingsController.localeCode ?? 'zh',
                              underline: const SizedBox(),
                              items: [
                                DropdownMenuItem(
                                  value: 'zh',
                                  child: Text(l10n.langZh),
                                ),
                                DropdownMenuItem(
                                  value: 'zh_Hant',
                                  child: Text(l10n.langZhHant),
                                ),
                                DropdownMenuItem(
                                  value: 'ja',
                                  child: Text(l10n.langJa),
                                ),
                              ],
                              onChanged: (value) {
                                layoutSettingsController.setLocaleCode(value);
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      _buildSwitchTile(
                        title: l10n.autoZoom,
                        titleKey: const Key('settings-auto-zoom-label'),
                        value: layoutSettingsController.autoZoom,
                        onChanged: (v) =>
                            layoutSettingsController.setAutoZoom(v),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      _buildSliderTile(
                        title: l10n.infoPanelWidth,
                        value: 1.0 - layoutSettingsController.gameAreaRatio,
                        min: 0.25,
                        max: 0.5,
                        onChanged: (v) =>
                            layoutSettingsController.setGameAreaRatio(1.0 - v),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      DisplayModeSection(controller: displayModeController),
                      if (toolbarDisplayController != null) ...<Widget>[
                        const Divider(color: Color(0xff294052), height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(child: Text(l10n.gameToolbar)),
                              SegmentedButton<GameToolbarDisplayMode>(
                                segments:
                                    <ButtonSegment<GameToolbarDisplayMode>>[
                                      ButtonSegment<GameToolbarDisplayMode>(
                                        value: GameToolbarDisplayMode.autoHide,
                                        label: Text(l10n.toolbarAutoHide),
                                      ),
                                      ButtonSegment<GameToolbarDisplayMode>(
                                        value:
                                            GameToolbarDisplayMode.persistent,
                                        label: Text(l10n.toolbarPersistent),
                                      ),
                                    ],
                                selected: <GameToolbarDisplayMode>{
                                  toolbarDisplayController!.mode,
                                },
                                onSelectionChanged: (selection) {
                                  toolbarDisplayController!.setMode(
                                    selection.single,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (screenAwakeController != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildCard(
                  child: AnimatedBuilder(
                    animation: screenAwakeController!,
                    builder: (context, _) => _buildSwitchTile(
                      title: l10n.screenAwake,
                      subtitle: l10n.screenAwakeDesc,
                      value: screenAwakeController!.enabled,
                      onChanged: screenAwakeController!.setEnabled,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.gameAndSound),
              _buildCard(
                child: AnimatedBuilder(
                  animation: audioController,
                  builder: (context, _) => Column(
                    children: <Widget>[
                      _buildSwitchTile(
                        title: l10n.gameSound,
                        value: !audioController.isMuted,
                        onChanged: (v) {
                          if (audioController.canToggle) {
                            audioController.toggleMuted();
                          }
                        },
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      _buildSwitchTile(
                        title: l10n.backgroundAudio,
                        subtitle: l10n.backgroundAudioDesc,
                        value: audioController.backgroundPlaybackEnabled,
                        onChanged: audioController.setBackgroundPlaybackEnabled,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.captureMode),
              _buildCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CaptureModeSelector(controller: captureModeController),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.gameSafety),
              _buildCard(
                child: AnimatedBuilder(
                  animation: safetySettingsController,
                  builder: (context, _) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.blockSortieTitle),
                            DropdownButton<BattleWarningMode>(
                              value: safetySettingsController.battleWarningMode,
                              underline: const SizedBox(),
                              items: [
                                DropdownMenuItem(
                                  value: BattleWarningMode.off,
                                  child: Text(l10n.battleWarningOff),
                                ),
                                DropdownMenuItem(
                                  value: BattleWarningMode.reminder,
                                  child: Text(l10n.battleWarningReminder),
                                ),
                                DropdownMenuItem(
                                  value: BattleWarningMode.confirm,
                                  child: Text(l10n.battleWarningConfirm),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  safetySettingsController.setBattleWarningMode(
                                    value,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.networkSettings),
              _buildCard(
                child: NetworkSettingsSection(
                  controller: networkSettingsController,
                  onApplySuccess: () {
                    // Reload game page
                    browserController.reload();
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.gadgetBypass),
              _buildCard(
                child: GadgetBypassSection(
                  controller: gadgetBypassController,
                  onReloadRequired: browserController.reload,
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.storageAndCache),
              _buildCard(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        l10n.logoutAndClear,
                        key: const Key('settings-logout-label'),
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        l10n.logoutAndClearDesc,
                        style: const TextStyle(color: Color(0xff8197a5)),
                      ),
                      trailing: const Icon(
                        Icons.logout,
                        color: Color(0xffd4a85f),
                      ),
                      onTap: () {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.logoutSnackbar)),
                          );
                        }
                      },
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    ListTile(
                      title: Text(
                        l10n.clearQuestCache,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        l10n.clearQuestCacheDesc,
                        style: const TextStyle(color: Color(0xff8197a5)),
                      ),
                      trailing: const Icon(
                        Icons.delete_outline,
                        color: Color(0xffd4a85f),
                      ),
                      onTap: () async {
                        await gameStateController.clearQuestsCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.questCacheCleared)),
                          );
                        }
                      },
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    ListTile(
                      title: Text(
                        l10n.clearWebCache,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        l10n.clearWebCacheDesc,
                        style: const TextStyle(color: Color(0xff8197a5)),
                      ),
                      trailing: const Icon(
                        Icons.cleaning_services_outlined,
                        color: Color(0xffd4a85f),
                      ),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              l10n.clearWebCacheConfirmTitle,
                              style: const TextStyle(fontSize: 18),
                            ),
                            content: Text(
                              l10n.clearWebCacheConfirmDesc,
                              style: const TextStyle(height: 1.5, fontSize: 14),
                            ),
                            backgroundColor: const Color(0xff142735),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(
                                    color: Color(0xff8197a5),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  l10n.confirmClear,
                                  style: const TextStyle(
                                    color: Color(0xffd4a85f),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await browserController.clearCache();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.webCacheCleared)),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    ListTile(
                      title: Text(
                        l10n.clearLogbook,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        l10n.clearLogbookDesc,
                        style: const TextStyle(color: Color(0xff8197a5)),
                      ),
                      trailing: const Icon(
                        Icons.delete_forever_outlined,
                        color: Color(0xffd4a85f),
                      ),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              l10n.clearLogbookConfirmTitle,
                              style: const TextStyle(fontSize: 18),
                            ),
                            content: Text(
                              l10n.clearLogbookConfirmDesc,
                              style: const TextStyle(height: 1.5, fontSize: 14),
                            ),
                            backgroundColor: const Color(0xff142735),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(
                                    color: Color(0xff8197a5),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  l10n.confirmClear,
                                  style: const TextStyle(
                                    color: Color(0xffd4a85f),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          try {
                            await LogbookDatabase.instance.clearAll();
                          } catch (error) {
                            debugPrint('清理航海日志失败: $error');
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.logbookCleared)),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (fcdMapController case final controller?) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(l10n.fcdMapSectionTitle),
                _buildCard(child: FcdMapUpdateSection(controller: controller)),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle(l10n.aboutApp),
              _buildCard(
                child: ListTile(
                  title: Text(
                    l10n.aboutApp,
                    style: const TextStyle(fontSize: 15),
                  ),
                  subtitle: Text(
                    (l10n.aboutSubtitle).replaceFirst(
                      RegExp(r'\d+(?:\.\d+){1,2}'),
                      currentVersion,
                    ),
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                  trailing: const Icon(
                    Icons.info_outline,
                    color: Color(0xffd4a85f),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AboutDialogWidget(
                        currentVersion: currentVersion,
                        releaseChecker: releaseChecker,
                      ),
                    );
                  },
                ),
              ),
              if (showDeveloperDiagnostics) ...[
                const SizedBox(height: 24),
                DiagnosticsSection(
                  browserController: browserController,
                  captureModeController: captureModeController,
                  gameCaptureController: gameCaptureController,
                  prototypeStatusController: prototypeStatusController,
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xffd4a85f),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Material(
      color: const Color(0xff142735),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTileTheme(
        data: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          minLeadingWidth: 0,
        ),
        child: child,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    Key? titleKey,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  key: titleKey,
                  style: const TextStyle(fontSize: 15),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xffd4a85f),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15)),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(color: Color(0xffd4a85f)),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: const Color(0xffd4a85f),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
