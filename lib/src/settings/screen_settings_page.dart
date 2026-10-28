import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../audio/game_audio_controller.dart';
import '../theme/app_theme.dart';
import '../subtitles/ship_subtitle_settings.dart';
import '../subtitles/ship_subtitle_runtime_controller.dart';
import '../browser/game_toolbar_display_controller.dart';
import 'background_game_retention_controller.dart';
import 'app_exit_settings.dart';
import 'display_mode_controller.dart';
import 'dashboard_display_mode.dart';
import 'display_mode_section.dart';
import 'custom_font_settings_section.dart';
import 'game_frame_rate_settings.dart';
import 'game_rendering_mode_controller.dart';
import 'layout_settings_controller.dart';
import 'camera_avoidance_settings_section.dart';
import 'screen_awake_controller.dart';
import 'game_mouse_wheel_settings.dart';
import 'game_frame_refresh_shortcut_settings.dart';
import 'header_resource_settings.dart';
import 'settings_ui_helpers.dart';
import 'ui_font_size.dart';
import 'hd_layout_settings_section.dart';
import '../fleet/fleet_ui_strings.dart';
import 'settings_organization_strings.dart';

class ScreenSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const ScreenSettingsPage({
    super.key,
    required this.layoutSettingsController,
    required this.displayModeController,
    this.audioController,
    this.shipSubtitleSettingsController,
    this.shipSubtitleRuntimeController,
    this.backgroundGameRetentionController,
    this.toolbarDisplayController,
    this.gameFrameRateSettingsController,
    this.screenAwakeController,
    this.appExitSettingsController,
    this.gameMouseWheelSettingsController,
    this.gameFrameRefreshShortcutSettings,
    this.gameRenderingModeController,
    this.isBattleActive = false,
    this.onEditHeaderResources,
    this.onEditDashboardLayout,
    this.onEditHdLayout,
  });

  final LayoutSettingsController layoutSettingsController;
  final DisplayModeController displayModeController;
  final GameAudioController? audioController;
  final ShipSubtitleSettingsController? shipSubtitleSettingsController;
  final ShipSubtitleRuntimeController? shipSubtitleRuntimeController;
  final BackgroundGameRetentionController? backgroundGameRetentionController;
  final GameToolbarDisplayController? toolbarDisplayController;
  final GameFrameRateSettingsController? gameFrameRateSettingsController;
  final ScreenAwakeController? screenAwakeController;
  final AppExitSettingsController? appExitSettingsController;
  final GameMouseWheelSettingsController? gameMouseWheelSettingsController;
  final GameFrameRefreshShortcutSettings? gameFrameRefreshShortcutSettings;
  final GameRenderingModeController? gameRenderingModeController;
  final bool isBattleActive;
  final VoidCallback? onEditHeaderResources;
  final VoidCallback? onEditDashboardLayout;
  final VoidCallback? onEditHdLayout;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final english = Localizations.localeOf(context).languageCode == 'en';
    String text(String source) => settingsOrganizationText(context, source);
    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            layoutSettingsController,
            displayModeController,
          ]),
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(text('settingsGroupAppearance'), [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SettingsControlRow(
                    label: Text(
                      l10n.language,
                      key: const Key('settings-language-label'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    controlBuilder: (stacked) => DropdownButton<String>(
                      isExpanded: stacked,
                      itemHeight: null,
                      value:
                          layoutSettingsController.localeCode ??
                          l10n.localeName,
                      underline: const SizedBox(),
                      alignment: AlignmentDirectional.centerEnd,
                      items: [
                        DropdownMenuItem(value: 'zh', child: Text(l10n.langZh)),
                        DropdownMenuItem(
                          value: 'zh_Hant',
                          child: Text(l10n.langZhHant),
                        ),
                        DropdownMenuItem(value: 'ja', child: Text(l10n.langJa)),
                        DropdownMenuItem(value: 'ko', child: Text(l10n.langKo)),
                        DropdownMenuItem(value: 'en', child: Text(l10n.langEn)),
                      ],
                      onChanged: (value) {
                        layoutSettingsController.setLocaleCode(value);
                      },
                    ),
                  ),
                ),
                Divider(color: appColor(context, Color(0xff294052)), height: 1),
                Padding(
                  key: const Key('settings-app-theme-row'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SettingsControlRow(
                    label: Text(
                      l10n.themeColorTitle,
                      style: appTextStyle(
                        context,
                        SettingsTileTypography.title,
                      ),
                    ),
                    controlBuilder: (stacked) => DropdownButton<AppThemeMode>(
                      isExpanded: stacked,
                      itemHeight: null,
                      key: const Key('settings-app-theme-dropdown'),
                      value: layoutSettingsController.appThemeMode,
                      underline: const SizedBox(),
                      alignment: AlignmentDirectional.centerEnd,
                      items: [
                        DropdownMenuItem(
                          value: AppThemeMode.dark,
                          child: Text(l10n.themeClassicDark),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.seaSalt,
                          child: Text(l10n.themeSeaSaltTeal),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.skyBlue,
                          child: Text(l10n.themeClearSkyBlue),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          layoutSettingsController.setAppThemeMode(value);
                        }
                      },
                    ),
                  ),
                ),
                if (layoutSettingsController.customFontController
                    case final fonts?) ...[
                  Divider(
                    color: appColor(context, Color(0xff294052)),
                    height: 1,
                  ),
                  CustomFontSettingsSection(
                    controller: fonts,
                    fallbackFonts: {
                      layoutSettingsController.defaultFontFamily,
                      ...layoutSettingsController.fontFamilyFallback,
                    }.toList(),
                  ),
                ],
                Divider(color: appColor(context, Color(0xff294052)), height: 1),
                Padding(
                  key: const Key('settings-ui-font-size-row'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SettingsControlRow(
                    minInlineWidth: 640,
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.uiFontSizeTitle,
                          key: const Key('settings-ui-font-size-label'),
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.title,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.uiFontSizeDescription,
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.description,
                          ),
                        ),
                      ],
                    ),
                    controlBuilder: (stacked) => DropdownButton<UiFontSize>(
                      key: const Key('settings-ui-font-size-dropdown'),
                      isExpanded: stacked,
                      itemHeight: null,
                      value: layoutSettingsController.uiFontSize,
                      underline: const SizedBox(),
                      alignment: AlignmentDirectional.centerEnd,
                      items: [
                        DropdownMenuItem(
                          value: UiFontSize.system,
                          child: Text(l10n.uiFontSizeSystem),
                        ),
                        DropdownMenuItem(
                          value: UiFontSize.small,
                          child: Text(l10n.uiFontSizeSmall),
                        ),
                        DropdownMenuItem(
                          value: UiFontSize.medium,
                          child: Text(l10n.uiFontSizeMedium),
                        ),
                        DropdownMenuItem(
                          value: UiFontSize.large,
                          child: Text(l10n.uiFontSizeLarge),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          layoutSettingsController.setUiFontSize(value);
                        }
                      },
                    ),
                  ),
                ),
                Divider(color: appColor(context, Color(0xff294052)), height: 1),
                Padding(
                  key: const Key('settings-ui-display-size-row'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.uiDisplaySizeTitle,
                              key: const Key('settings-ui-display-size-label'),
                              style: appTextStyle(
                                context,
                                SettingsTileTypography.title,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l10n.uiDisplaySizeDesc,
                              style: appTextStyle(
                                context,
                                SettingsTileTypography.description,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<UiDisplaySize>(
                        key: const Key('settings-ui-display-size-dropdown'),
                        value: layoutSettingsController.uiDisplaySize,
                        underline: const SizedBox(),
                        alignment: AlignmentDirectional.centerEnd,
                        items: [
                          DropdownMenuItem(
                            value: UiDisplaySize.normal,
                            child: Text(l10n.uiDisplaySizeNormal),
                          ),
                          DropdownMenuItem(
                            value: UiDisplaySize.compact,
                            child: Text(l10n.uiDisplaySizeCompact),
                          ),
                          DropdownMenuItem(
                            value: UiDisplaySize.minimal,
                            child: Text(l10n.uiDisplaySizeMinimal),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            layoutSettingsController.setUiDisplaySize(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _section(text('settingsGroupScreenAdaptation'), [
                DisplayModeSection(controller: displayModeController),
                _divider(context),
                HdLayoutSettingsSection(controller: layoutSettingsController),
                _divider(context),
                CameraAvoidanceSettingsSection(
                  controller: layoutSettingsController,
                ),
              ]),
              const SizedBox(height: 24),
              _section(text('settingsGroupLayoutPosition'), [
                buildSwitchTile(
                  title: l10n.autoZoom,
                  titleKey: const Key('settings-auto-zoom-label'),
                  value: layoutSettingsController.autoZoom,
                  onChanged: (v) => layoutSettingsController.setAutoZoom(v),
                ),
                Divider(color: appColor(context, Color(0xff294052)), height: 1),
                buildSliderTile(
                  title: l10n.infoPanelWidth,
                  value:
                      layoutSettingsController.effectiveInformationPanelRatio,
                  min: 0.25,
                  max: 0.5,
                  onChanged:
                      layoutSettingsController.canAdjustInformationPanelRatio
                      ? (v) =>
                            layoutSettingsController.setGameAreaRatio(1.0 - v)
                      : null,
                ),
                _divider(context),
                Padding(
                  key: const Key('settings-workspace-menu-position'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SettingsControlRow(
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.workspaceMenuPosition,
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.title,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.workspaceMenuPositionDesc,
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.description,
                          ),
                        ),
                      ],
                    ),
                    controlBuilder: (stacked) => Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: english
                              ? 112
                              : MediaQuery.textScalerOf(context).scale(28) + 32,
                          child: DropdownButton<String>(
                            isExpanded: true,
                            padding: const EdgeInsets.only(left: 14),
                            underline: const SizedBox.shrink(),
                            value:
                                layoutSettingsController.workspaceMenuPosition,
                            items: [
                              DropdownMenuItem(
                                value: 'top',
                                child: Text(l10n.menuPositionTop),
                              ),
                              DropdownMenuItem(
                                value: 'bottom',
                                child: Text(l10n.menuPositionBottom),
                              ),
                              DropdownMenuItem(
                                value: 'left',
                                child: Text(l10n.menuPositionLeft),
                              ),
                              DropdownMenuItem(
                                value: 'right',
                                child: Text(l10n.menuPositionRight),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                layoutSettingsController
                                    .setWorkspaceMenuPosition(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(color: appColor(context, Color(0xff294052)), height: 1),
                buildActionTile(
                  title: fleetText(context, '功能区位置'),
                  titleKey: const Key('settings-information-panel-left'),
                  subtitle: fleetText(context, '选择功能区显示在左侧或右侧，竖屏保持上下布局。'),
                  trailing: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: english
                            ? 112
                            : MediaQuery.textScalerOf(context).scale(28) + 32,
                        child: DropdownButton<String>(
                          key: const Key('settings-information-panel-position'),
                          isExpanded: true,
                          padding: const EdgeInsets.only(left: 14),
                          underline: const SizedBox.shrink(),
                          value: layoutSettingsController.informationPanelOnLeft
                              ? 'left'
                              : 'right',
                          items: [
                            DropdownMenuItem(
                              value: 'left',
                              child: Text(l10n.menuPositionLeft),
                            ),
                            DropdownMenuItem(
                              value: 'right',
                              child: Text(l10n.menuPositionRight),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              layoutSettingsController
                                  .setInformationPanelOnLeft(value == 'left');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (layoutSettingsController.hdSettings.enabled) ...[
                  Divider(
                    color: appColor(context, Color(0xff294052)),
                    height: 1,
                  ),
                  buildActionTile(
                    title: fleetText(context, '拓展功能区位置'),
                    titleKey: const Key('settings-hd-extension-position-title'),
                    trailing: DropdownButton<String>(
                      key: const Key('settings-hd-extension-position'),
                      underline: const SizedBox.shrink(),
                      value:
                          layoutSettingsController.hdSettings.extensionAboveGame
                          ? 'top'
                          : 'bottom',
                      items: [
                        DropdownMenuItem(
                          value: 'bottom',
                          child: Text(l10n.menuPositionBottom),
                        ),
                        DropdownMenuItem(
                          value: 'top',
                          child: Text(l10n.menuPositionTop),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          layoutSettingsController.setHdExtensionPosition(
                            value,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 24),
              _section(text('settingsGroupContentCustomization'), [
                Padding(
                  key: const Key('settings-briefing-display-row'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SettingsControlRow(
                    minInlineWidth: 640,
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.briefingDisplayTitle,
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.title,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.briefingDisplayDescription,
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.description,
                          ),
                        ),
                      ],
                    ),
                    controlBuilder: (stacked) =>
                        DropdownButton<DashboardDisplayMode>(
                          key: const Key('settings-briefing-display-dropdown'),
                          isExpanded: stacked,
                          itemHeight: null,
                          value: layoutSettingsController.dashboardDisplayMode,
                          underline: const SizedBox(),
                          alignment: AlignmentDirectional.centerEnd,
                          items: [
                            DropdownMenuItem(
                              value: DashboardDisplayMode.accordion,
                              child: Text(l10n.briefingDisplayAccordion),
                            ),
                            DropdownMenuItem(
                              value: DashboardDisplayMode.tabs,
                              child: Text(l10n.briefingDisplayTabs),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              layoutSettingsController.setDashboardDisplayMode(
                                value,
                              );
                            }
                          },
                        ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _section(text('settingsGroupLayoutManagement'), [
                buildSwitchTile(
                  title: l10n.uiLockTitle,
                  titleKey: const Key('settings-ui-lock-switch'),
                  subtitle: l10n.uiLockDesc,
                  value: layoutSettingsController.uiLocked,
                  onChanged: layoutSettingsController.setUiLocked,
                ),
                _divider(context),
                buildActionTile(
                  title: text('settingsResetMenuOrder'),
                  trailing: _resetOrderButton(
                    context,
                    key: const Key('settings-reset-workspace-menu-order'),
                    onPressed: layoutSettingsController.resetWorkspaceMenuOrder,
                    label: l10n.restoreDefaultOrder,
                  ),
                ),
                _divider(context),
                buildActionTile(
                  title: text('settingsResetCardOrder'),
                  trailing: _resetOrderButton(
                    context,
                    key: const Key('settings-reset-dashboard-card-order'),
                    onPressed: layoutSettingsController.resetDashboardCardOrder,
                    label: l10n.restoreDefaultOrder,
                  ),
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildSectionTitle(title),
      buildCard(child: Column(children: children)),
    ],
  );

  Widget _divider(BuildContext context) =>
      Divider(color: appColor(context, const Color(0xff294052)), height: 1);

  Widget _resetOrderButton(
    BuildContext context, {
    required Key key,
    required VoidCallback onPressed,
    required String label,
  }) {
    if (Localizations.localeOf(context).languageCode != 'en') {
      return OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        icon: const Icon(Icons.restore, size: 18),
        label: Text(label),
      );
    }
    return Tooltip(
      message: label,
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
        ),
        child: const Icon(Icons.restore, size: 18),
      ),
    );
  }
}
