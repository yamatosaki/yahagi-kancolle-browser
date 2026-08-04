import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../audio/game_audio_controller.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/game_browser_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.settingsTitle ?? '设置',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: const Color(0xff0d1a26),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        color: const Color(0xff0d1a26),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle(
                AppLocalizations.of(context)?.layoutSettings ?? '显示与布局',
              ),
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
                              AppLocalizations.of(context)?.language ??
                                  '语言 (Language)',
                            ),
                            DropdownButton<String>(
                              value:
                                  layoutSettingsController.localeCode ?? 'zh',
                              underline: const SizedBox(),
                              items: [
                                DropdownMenuItem(
                                  value: 'zh',
                                  child: Text(
                                    AppLocalizations.of(context)?.langZh ??
                                        '简体中文',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'zh_Hant',
                                  child: Text(
                                    AppLocalizations.of(context)?.langZhHant ??
                                        '繁體中文',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'ja',
                                  child: Text(
                                    AppLocalizations.of(context)?.langJa ??
                                        '日本語',
                                  ),
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
                        title:
                            AppLocalizations.of(context)?.autoZoom ??
                            '自动适应游戏缩放',
                        value: layoutSettingsController.autoZoom,
                        onChanged: (v) =>
                            layoutSettingsController.setAutoZoom(v),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      _buildSliderTile(
                        title:
                            AppLocalizations.of(context)?.infoPanelWidth ??
                            '横屏信息区比例',
                        value: 1.0 - layoutSettingsController.gameAreaRatio,
                        min: 0.25,
                        max: 0.5,
                        onChanged: (v) =>
                            layoutSettingsController.setGameAreaRatio(1.0 - v),
                      ),
                      const Divider(color: Color(0xff294052), height: 1),
                      DisplayModeSection(controller: displayModeController),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                AppLocalizations.of(context)?.gameAndSound ?? '游戏与声音',
              ),
              _buildCard(
                child: AnimatedBuilder(
                  animation: audioController,
                  builder: (context, _) => _buildSwitchTile(
                    title: AppLocalizations.of(context)?.gameSound ?? '游戏声音',
                    value: !audioController.isMuted,
                    onChanged: (v) {
                      if (audioController.canToggle) {
                        audioController.toggleMuted();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                AppLocalizations.of(context)?.captureMode ?? '数据捕获模式',
              ),
              _buildCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CaptureModeSelector(controller: captureModeController),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                AppLocalizations.of(context)?.gameSafety ?? '出击前安全检查',
              ),
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
                            Text(
                              AppLocalizations.of(context)?.blockSortieTitle ??
                                  '战后大破提醒模式',
                            ),
                            DropdownButton<BattleWarningMode>(
                              value: safetySettingsController.battleWarningMode,
                              underline: const SizedBox(),
                              items: [
                                DropdownMenuItem(
                                  value: BattleWarningMode.off,
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.battleWarningOff ??
                                        '关闭',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: BattleWarningMode.reminder,
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.battleWarningReminder ??
                                        '闪烁提醒',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: BattleWarningMode.confirm,
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.battleWarningConfirm ??
                                        '弹框确认',
                                  ),
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
              _buildSectionTitle(
                AppLocalizations.of(context)?.networkSettings ?? '网络设置',
              ),
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
              _buildSectionTitle(
                AppLocalizations.of(context)?.gadgetBypass ?? '游戏客户端绕行',
              ),
              _buildCard(
                child: GadgetBypassSection(
                  controller: gadgetBypassController,
                  onReloadRequired: browserController.reload,
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                AppLocalizations.of(context)?.storageAndCache ?? '存储与缓存',
              ),
              _buildCard(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        AppLocalizations.of(context)?.logoutAndClear ??
                            '退出登录 / 清除账号信息',
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        AppLocalizations.of(context)?.logoutAndClearDesc ??
                            '清除游戏登录状态，下次打开需要重新登录。',
                        style: const TextStyle(color: Color(0xff8197a5)),
                      ),
                      trailing: const Icon(
                        Icons.logout,
                        color: Color(0xffd4a85f),
                      ),
                      onTap: () {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)?.logoutSnackbar ??
                                    '退出登录功能已准备就绪，当前为保护您的测试账号暂未执行清除。',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    ListTile(
                      title: Text(
                        AppLocalizations.of(context)?.clearQuestCache ??
                            '清理任务数据缓存',
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        AppLocalizations.of(context)?.clearQuestCacheDesc ??
                            '清除本地缓存的脱敏任务数据，重启应用后需进入游戏内任务面板重新获取',
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
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                      context,
                                    )?.questCacheCleared ??
                                    '已清除任务数据本地缓存',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    ListTile(
                      title: Text(
                        AppLocalizations.of(context)?.clearWebCache ??
                            '清理游戏 Web 缓存',
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        AppLocalizations.of(context)?.clearWebCacheDesc ??
                            '清除游戏加载的图片、音频等静态资源缓存。',
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
                              AppLocalizations.of(
                                    context,
                                  )?.clearWebCacheConfirmTitle ??
                                  '清理游戏 Web 缓存',
                              style: const TextStyle(fontSize: 18),
                            ),
                            content: Text(
                              AppLocalizations.of(
                                    context,
                                  )?.clearWebCacheConfirmDesc ??
                                  '确定要清除游戏缓存吗？这将会删除已下载的图片、音频等静态资源，下次进入游戏或加载立绘时可能会消耗较多流量和时间。',
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
                                  AppLocalizations.of(context)?.cancel ?? '取消',
                                  style: const TextStyle(
                                    color: Color(0xff8197a5),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  AppLocalizations.of(context)?.confirmClear ??
                                      '确定清除',
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
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                        context,
                                      )?.webCacheCleared ??
                                      '已清理游戏 Web 缓存',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    ListTile(
                      title: Text(
                        AppLocalizations.of(context)?.clearLogbook ??
                            '清理航海日志数据',
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: Text(
                        AppLocalizations.of(context)?.clearLogbookDesc ??
                            '清除本地保存的所有历史战果、资源与远征记录。此操作不可逆。',
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
                              AppLocalizations.of(
                                    context,
                                  )?.clearLogbookConfirmTitle ??
                                  '清理航海日志数据',
                              style: const TextStyle(fontSize: 18),
                            ),
                            content: Text(
                              AppLocalizations.of(
                                    context,
                                  )?.clearLogbookConfirmDesc ??
                                  '确定要清空所有航海日志数据吗？这将会删除您积攒的历史战果和资源统计记录。此操作无法撤销。',
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
                                  AppLocalizations.of(context)?.cancel ?? '取消',
                                  style: const TextStyle(
                                    color: Color(0xff8197a5),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(
                                  AppLocalizations.of(context)?.confirmClear ??
                                      '确定清除',
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
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                        context,
                                      )?.logbookCleared ??
                                      '已清除所有航海日志数据',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                AppLocalizations.of(context)?.aboutApp ?? '关于 ヤハギ',
              ),
              _buildCard(
                child: ListTile(
                  title: Text(
                    AppLocalizations.of(context)?.aboutApp ?? '关于 ヤハギ',
                    style: const TextStyle(fontSize: 15),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)?.aboutSubtitle ??
                        '版本 学习版 1.0 · 免责声明 · 检查更新',
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                  trailing: const Icon(
                    Icons.info_outline,
                    color: Color(0xffd4a85f),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AboutDialogWidget(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              DiagnosticsSection(
                browserController: browserController,
                captureModeController: captureModeController,
                gameCaptureController: gameCaptureController,
                prototypeStatusController: prototypeStatusController,
              ),
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
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Color(0xff8197a5)))
          : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xffd4a85f),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
