import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_toolbar_display_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/capture_mode_selector.dart';
import 'display_mode_controller.dart';
import 'display_mode_section.dart';
import 'game_frame_rate_settings.dart';
import 'game_frame_rate_settings_section.dart';
import 'game_rendering_mode_controller.dart';
import 'game_rendering_mode_section.dart';
import 'layout_settings_controller.dart';
import 'screen_awake_controller.dart';
import 'settings_ui_helpers.dart';

class ScreenSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const ScreenSettingsPage({
    super.key,
    required this.layoutSettingsController,
    required this.displayModeController,
    this.toolbarDisplayController,
    required this.captureModeController,
    this.gameFrameRateSettingsController,
    this.screenAwakeController,
    this.gameRenderingModeController,
    this.isBattleActive = false,
  });

  final LayoutSettingsController layoutSettingsController;
  final DisplayModeController displayModeController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final CaptureModeController captureModeController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final ScreenAwakeController? screenAwakeController;
  final GameRenderingModeController? gameRenderingModeController;
  final bool isBattleActive;

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
            buildSectionTitle(l10n.layoutSettings),
            buildCard(
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
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.language,
                            key: const Key('settings-language-label'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          DropdownButton<String>(
                            value: layoutSettingsController.localeCode ?? 'zh',
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
                    buildSwitchTile(
                      title: l10n.autoZoom,
                      titleKey: const Key('settings-auto-zoom-label'),
                      value: layoutSettingsController.autoZoom,
                      onChanged: (v) => layoutSettingsController.setAutoZoom(v),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    buildSliderTile(
                      title: l10n.infoPanelWidth,
                      value: layoutSettingsController
                          .effectiveInformationPanelRatio,
                      min: 0.25,
                      max: 0.5,
                      onChanged:
                          layoutSettingsController
                              .canAdjustInformationPanelRatio
                          ? (v) => layoutSettingsController.setGameAreaRatio(
                              1.0 - v,
                            )
                          : null,
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    DisplayModeSection(controller: displayModeController),
                    const Divider(color: Color(0xff294052), height: 1),
                    buildSwitchTile(
                      title: l10n.workspaceMenuOnRight,
                      titleKey: const Key('settings-workspace-menu-right'),
                      subtitle: l10n.workspaceMenuOnRightDesc,
                      value: layoutSettingsController.workspaceMenuOnRight,
                      onChanged:
                          layoutSettingsController.setWorkspaceMenuOnRight,
                      trailingBeforeSwitch: OutlinedButton.icon(
                        key: const Key('settings-reset-workspace-menu-order'),
                        onPressed:
                            layoutSettingsController.resetWorkspaceMenuOrder,
                        icon: const Icon(Icons.restore, size: 18),
                        label: Text(l10n.restoreDefaultOrder),
                      ),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    buildSwitchTile(
                      title: l10n.enhancedDamagePulse,
                      titleKey: const Key('settings-enhanced-damage-pulse'),
                      subtitle: l10n.enhancedDamagePulseDesc,
                      value: layoutSettingsController.enhancedDamagePulse,
                      onChanged:
                          layoutSettingsController.setEnhancedDamagePulse,
                    ),
                    if (toolbarDisplayController != null) ...<Widget>[
                      const Divider(color: Color(0xff294052), height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l10n.gameToolbar,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SegmentedButton<GameToolbarDisplayMode>(
                              showSelectedIcon: false,
                              segments: <ButtonSegment<GameToolbarDisplayMode>>[
                                ButtonSegment<GameToolbarDisplayMode>(
                                  value: GameToolbarDisplayMode.autoHide,
                                  label: Text(l10n.toolbarAutoHide),
                                ),
                                ButtonSegment<GameToolbarDisplayMode>(
                                  value: GameToolbarDisplayMode.persistent,
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
            const SizedBox(height: 24),
            buildSectionTitle(l10n.captureMode),
            buildCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: CaptureModeSelector(controller: captureModeController),
              ),
            ),
            if (gameFrameRateSettingsController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.frameRateSettingsSection),
              buildCard(
                child: GameFrameRateSettingsSection(
                  controller: gameFrameRateSettingsController!,
                ),
              ),
            ],
            if (gameRenderingModeController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.gameRenderingModeTitle),
              buildCard(
                child: GameRenderingModeSection(
                  controller: gameRenderingModeController!,
                  isBattleActive: isBattleActive,
                ),
              ),
            ],
            if (screenAwakeController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.screenAwake),
              buildCard(
                child: AnimatedBuilder(
                  animation: screenAwakeController!,
                  builder: (context, _) => buildSwitchTile(
                    title: l10n.screenAwake,
                    subtitle: l10n.screenAwakeDesc,
                    value: screenAwakeController!.enabled,
                    onChanged: screenAwakeController!.setEnabled,
                  ),
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
