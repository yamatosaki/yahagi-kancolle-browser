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
    this.enableBackdropBlur = true,
    this.interactionEnabled = true,
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
  final bool enableBackdropBlur;
  final bool interactionEnabled;

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
    final toolbarHeight = isLandscapePhone ? 36.0 : (persistent ? 42.0 : 34.0);
    final persistentActionSize = isLandscapePhone
        ? 34.0
        : (persistent ? 40.0 : 28.0);
    final navigationActionSize = isLandscapePhone
        ? 34.0
        : (persistent ? 36.0 : 28.0);
    final toolbar = Container(
      height: toolbarHeight,
      decoration: BoxDecoration(
        color: const Color(0xff0a1622).withValues(alpha: 0.9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(persistent ? 12 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: persistentActionSize,
            child: IconButton(
              key: const Key('game-audio-toggle'),
              padding: EdgeInsets.zero,
              tooltip: isMuted ? l10n.enableGameAudio : l10n.disableGameAudio,
              onPressed: interactionEnabled && audioEnabled
                  ? onToggleMuted
                  : null,
              icon: Icon(
                isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                size: persistent ? 19 : 16,
              ),
            ),
          ),
          SizedBox.square(
            dimension: persistentActionSize,
            child: IconButton(
              key: const Key('browser-screenshot'),
              padding: EdgeInsets.zero,
              tooltip: l10n.takeScreenshot,
              onPressed: interactionEnabled ? onScreenshot : null,
              icon: Icon(
                Icons.camera_alt_outlined,
                size: persistent ? 19 : 16,
                color: const Color(0xffd4a85f),
              ),
            ),
          ),
          SizedBox.square(
            dimension: persistentActionSize,
            child: IconButton(
              key: const Key('browser-fit-screen'),
              padding: EdgeInsets.zero,
              tooltip: l10n.fitGameScreen,
              onPressed: interactionEnabled ? onFitScreen : null,
              icon: Icon(Icons.crop_free, size: persistent ? 18 : 16),
            ),
          ),
          if (loadState == GamePageLoadState.loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const SizedBox(width: 2),
          if (isRealWeb) ...[
            _ToolbarButton(
              key: const Key('browser-back'),
              icon: Icons.arrow_back,
              tooltip: l10n.back,
              onPressed: interactionEnabled ? onBack : null,
              size: navigationActionSize,
            ),
            _ToolbarButton(
              key: const Key('browser-reload'),
              icon: Icons.refresh,
              tooltip: l10n.reload,
              onPressed: interactionEnabled ? onReload : null,
              size: navigationActionSize,
            ),
            _ToolbarButton(
              key: const Key('browser-home'),
              icon: Icons.home_outlined,
              tooltip: l10n.home,
              onPressed: interactionEnabled ? onHome : null,
              size: navigationActionSize,
            ),
          ] else ...[
            _ToolbarButton(
              key: const Key('browser-reload'),
              icon: Icons.refresh,
              tooltip: l10n.reload,
              onPressed: interactionEnabled ? onReload : null,
              size: navigationActionSize,
            ),
            TextButton.icon(
              key: const Key('browser-enter-dmm'),
              onPressed: interactionEnabled ? onEnterDmm : null,
              icon: const Icon(Icons.login, size: 15),
              label: Text(l10n.enterDmm, style: const TextStyle(fontSize: 12)),
            ),
          ],
          if (!persistent)
            SizedBox.square(
              dimension: persistentActionSize,
              child: IconButton(
                key: const Key('browser-toolbar-collapse'),
                padding: EdgeInsets.zero,
                tooltip: l10n.collapseToolbar,
                onPressed: interactionEnabled ? onCollapse : null,
                icon: const Icon(Icons.chevron_left, size: 18),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(persistent ? 12 : 8),
      child: enableBackdropBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: toolbar,
            )
          : toolbar,
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
  final Future<void> Function()? onPressed;
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
