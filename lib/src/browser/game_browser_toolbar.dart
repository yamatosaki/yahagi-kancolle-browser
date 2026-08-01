import 'dart:ui';
import 'package:flutter/material.dart';

import 'game_browser_controller.dart';

class GameBrowserToolbar extends StatelessWidget {
  const GameBrowserToolbar({
    super.key,
    required this.mode,
    required this.loadState,
    required this.displayAddress,
    required this.onBack,
    required this.onReload,
    required this.onHome,
    required this.onEnterDmm,
    required this.isMuted,
    required this.audioEnabled,
    required this.onToggleMuted,
    required this.onCollapse,
    required this.onFitScreen,
    this.onScreenshot,
  });

  final GameBrowserMode mode;
  final GamePageLoadState loadState;
  final String displayAddress;
  final Future<void> Function() onBack;
  final Future<void> Function() onReload;
  final Future<void> Function() onHome;
  final Future<void> Function() onEnterDmm;
  final bool isMuted;
  final bool audioEnabled;
  final Future<void> Function() onToggleMuted;
  final VoidCallback onCollapse;
  final VoidCallback onFitScreen;
  final VoidCallback? onScreenshot;

  @override
  Widget build(BuildContext context) {
    final isRealWeb = mode == GameBrowserMode.realWeb;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xff0a1622).withValues(alpha: 0.65),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              if (isRealWeb) ...[
                _ToolbarButton(
                  key: const Key('browser-back'),
                  icon: Icons.arrow_back,
                  tooltip: '返回',
                  onPressed: onBack,
                ),
                _ToolbarButton(
                  key: const Key('browser-reload'),
                  icon: Icons.refresh,
                  tooltip: '刷新',
                  onPressed: onReload,
                ),
                _ToolbarButton(
                  key: const Key('browser-home'),
                  icon: Icons.home_outlined,
                  tooltip: '回到主页',
                  onPressed: onHome,
                ),
              ] else
                TextButton.icon(
                  key: const Key('browser-enter-dmm'),
                  onPressed: onEnterDmm,
                  icon: const Icon(Icons.login, size: 17),
                  label: const Text('DMM 登录测试'),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Color(0xff70c7bc),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xff9bb0bb),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (loadState == GamePageLoadState.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                const SizedBox(width: 2),
              IconButton(
                key: const Key('game-audio-toggle'),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                tooltip: isMuted ? '开启游戏声音' : '关闭游戏声音',
                onPressed: audioEnabled ? onToggleMuted : null,
                icon: Icon(
                  isMuted
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  size: 19,
                ),
              ),
              IconButton(
                key: const Key('browser-screenshot'),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                tooltip: '一键截图',
                onPressed: onScreenshot ?? () {},
                icon: const Icon(
                  Icons.camera_alt_outlined,
                  size: 19,
                  color: Color(0xffd4a85f),
                ),
              ),
              IconButton(
                key: const Key('browser-fit-screen'),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                tooltip: '修复显示（自适应屏幕）',
                onPressed: onFitScreen,
                icon: const Icon(Icons.crop_free, size: 18),
              ),
              IconButton(
                key: const Key('browser-toolbar-collapse'),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                tooltip: '收起工具栏',
                onPressed: onCollapse,
                icon: const Icon(Icons.keyboard_arrow_up, size: 22),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onPressed,
      hoverColor: const Color(0xffd4a85f).withValues(alpha: 0.15),
      splashColor: const Color(0xffd4a85f).withValues(alpha: 0.2),
      icon: Icon(icon, size: 18),
    );
  }
}
