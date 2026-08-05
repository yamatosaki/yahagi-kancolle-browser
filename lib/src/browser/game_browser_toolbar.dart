import 'dart:ui';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

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
    this.persistent = false,
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
  final bool persistent;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final isRealWeb = mode == GameBrowserMode.realWeb;
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscapePhone =
        persistent &&
        screenSize.width > screenSize.height &&
        screenSize.shortestSide < 600;
    final toolbarHeight = isLandscapePhone ? 36.0 : (persistent ? 42.0 : 48.0);
    final persistentActionSize = isLandscapePhone ? 34.0 : 40.0;
    final navigationActionSize = isLandscapePhone ? 34.0 : 36.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: toolbarHeight,
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
                  tooltip: l10n.back,
                  onPressed: onBack,
                  size: navigationActionSize,
                ),
                _ToolbarButton(
                  key: const Key('browser-reload'),
                  icon: Icons.refresh,
                  tooltip: l10n.reload,
                  onPressed: onReload,
                  size: navigationActionSize,
                ),
                _ToolbarButton(
                  key: const Key('browser-home'),
                  icon: Icons.home_outlined,
                  tooltip: l10n.home,
                  onPressed: onHome,
                  size: navigationActionSize,
                ),
              ] else
                TextButton.icon(
                  key: const Key('browser-enter-dmm'),
                  onPressed: onEnterDmm,
                  icon: const Icon(Icons.login, size: 17),
                  label: Text(l10n.enterDmm),
                ),
              if (!persistent) ...<Widget>[
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
              ],
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
              SizedBox.square(
                dimension: persistentActionSize,
                child: IconButton(
                  key: const Key('game-audio-toggle'),
                  padding: EdgeInsets.zero,
                  tooltip: isMuted
                      ? l10n.enableGameAudio
                      : l10n.disableGameAudio,
                  onPressed: audioEnabled ? onToggleMuted : null,
                  icon: Icon(
                    isMuted
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                    size: 19,
                  ),
                ),
              ),
              SizedBox.square(
                dimension: persistentActionSize,
                child: IconButton(
                  key: const Key('browser-screenshot'),
                  padding: EdgeInsets.zero,
                  tooltip: l10n.takeScreenshot,
                  onPressed: onScreenshot,
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 19,
                    color: Color(0xffd4a85f),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: persistentActionSize,
                child: IconButton(
                  key: const Key('browser-fit-screen'),
                  padding: EdgeInsets.zero,
                  tooltip: l10n.fitGameScreen,
                  onPressed: onFitScreen,
                  icon: const Icon(Icons.crop_free, size: 18),
                ),
              ),
              if (!persistent)
                IconButton(
                  key: const Key('browser-toolbar-collapse'),
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: l10n.collapseToolbar,
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
    this.size = 36,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        onPressed: onPressed,
        hoverColor: const Color(0xffd4a85f).withValues(alpha: 0.15),
        splashColor: const Color(0xffd4a85f).withValues(alpha: 0.2),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}
