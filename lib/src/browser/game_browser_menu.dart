import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../layout/display_corners.dart';
import 'game_browser_controller.dart';

/// The browser commands shared by the header toolbar and the minimal-size
/// overlay menu, so both surfaces run exactly the same callbacks.
class GameBrowserActions {
  const GameBrowserActions({
    required this.mode,
    required this.interactionEnabled,
    required this.onBack,
    required this.onReload,
    required this.onHome,
    required this.onEnterDmm,
    required this.isMuted,
    required this.audioEnabled,
    required this.onToggleMuted,
    required this.onFitScreen,
    this.onEnterFullscreen,
    this.onScreenshot,
    this.uiLocked = false,
    this.onToggleUiLock,
  });

  final GameBrowserMode mode;
  final bool interactionEnabled;
  final Future<void> Function() onBack;
  final Future<void> Function() onReload;
  final Future<void> Function() onHome;
  final Future<void> Function() onEnterDmm;
  final bool isMuted;
  final bool audioEnabled;
  final Future<void> Function() onToggleMuted;
  final VoidCallback onFitScreen;
  final VoidCallback? onEnterFullscreen;
  final VoidCallback? onScreenshot;
  final bool uiLocked;
  final VoidCallback? onToggleUiLock;
}

Future<void> showGameBrowserMenu(
  BuildContext context,
  GameBrowserActions actions,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) => _GameBrowserMenu(actions: actions),
  );
}

const _regularColors = (
  background: Color(0xff15232f),
  border: Color(0xff3a4b5a),
  icon: Color(0xffe3e9ee),
);

const _warningColors = (
  background: Color(0xff3a2b1e),
  border: Color(0xff7a5a2c),
  icon: Color(0xfff0c27a),
);

class _GameBrowserMenu extends StatelessWidget {
  const _GameBrowserMenu({required this.actions});

  final GameBrowserActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final closeInset = 8 + cornerInset(DisplayCorners.of(context).topRight);
    final isRealWeb = actions.mode == GameBrowserMode.realWeb;

    VoidCallback? dismissThen(FutureOr<void> Function()? action) {
      if (!actions.interactionEnabled || action == null) return null;
      return () async {
        final route = ModalRoute.of(context);
        // The menu is still visible while it fades out; a second tap must not
        // pop the route underneath it.
        if (route == null || !route.isCurrent) return;
        Navigator.of(context).pop();
        // Running the action only after the menu has fully left keeps a
        // follow-up popup (the refresh confirm) from stacking on top of it.
        await route.completed;
        await action();
      };
    }

    final toolButtons = [
      _MenuButton(
        key: const Key('game-browser-menu-mute'),
        icon: actions.isMuted
            ? Icons.volume_off_outlined
            : Icons.volume_up_outlined,
        label: actions.isMuted ? l10n.browserMenuUnmute : l10n.browserMenuMute,
        tooltip: actions.isMuted ? l10n.enableGameAudio : l10n.disableGameAudio,
        onPressed: actions.audioEnabled
            ? dismissThen(actions.onToggleMuted)
            : null,
      ),
      _MenuButton(
        key: const Key('game-browser-menu-screenshot'),
        icon: Icons.camera_alt_outlined,
        label: l10n.browserMenuScreenshot,
        tooltip: l10n.takeScreenshot,
        onPressed: dismissThen(actions.onScreenshot),
      ),
      _MenuButton(
        key: const Key('game-browser-menu-fit'),
        icon: Icons.crop_free,
        label: l10n.browserMenuFit,
        tooltip: l10n.fitGameScreen,
        onPressed: dismissThen(actions.onFitScreen),
      ),
      _MenuButton(
        key: const Key('game-browser-menu-fullscreen'),
        icon: Icons.open_in_full_rounded,
        label: l10n.browserMenuFullscreen,
        tooltip: l10n.enterGameFullscreen,
        onPressed: dismissThen(actions.onEnterFullscreen),
      ),
      if (actions.onToggleUiLock case final onToggleUiLock?)
        _MenuButton(
          key: const Key('game-browser-menu-lock'),
          icon: actions.uiLocked ? Icons.lock : Icons.lock_open,
          iconColor: actions.uiLocked ? const Color(0xffffd54f) : null,
          label: actions.uiLocked ? l10n.unlockUi : l10n.lockUi,
          tooltip: actions.uiLocked ? l10n.unlockUi : l10n.lockUi,
          onPressed: dismissThen(onToggleUiLock),
        ),
    ];

    // Mirrors GameBrowserToolbar: back/home only exist on the real site, and
    // the local page offers the explicit DMM entry instead.
    final pageButtons = [
      if (isRealWeb)
        _MenuButton(
          key: const Key('game-browser-menu-back'),
          icon: Icons.arrow_back,
          label: l10n.back,
          tooltip: l10n.back,
          warning: true,
          onPressed: dismissThen(actions.onBack),
        ),
      _MenuButton(
        key: const Key('game-browser-menu-reload'),
        icon: Icons.refresh,
        label: l10n.reload,
        tooltip: l10n.reload,
        warning: true,
        onPressed: dismissThen(actions.onReload),
      ),
      if (isRealWeb)
        _MenuButton(
          key: const Key('game-browser-menu-home'),
          icon: Icons.home_outlined,
          label: l10n.browserMenuHome,
          tooltip: l10n.home,
          warning: true,
          onPressed: dismissThen(actions.onHome),
        )
      else
        _MenuButton(
          key: const Key('game-browser-menu-dmm'),
          icon: Icons.login,
          label: 'DMM',
          tooltip: l10n.enterDmm,
          warning: true,
          onPressed: dismissThen(actions.onEnterDmm),
        ),
    ];

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: toolButtons,
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: pageButtons,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.browserMenuDismissHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: closeInset,
            right: closeInset,
            child: IconButton(
              key: const Key('game-browser-menu-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              color: Colors.white70,
              icon: const Icon(Icons.close),
              onPressed: () {
                final route = ModalRoute.of(context);
                if (route != null && route.isCurrent) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.warning = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool warning;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = warning ? _warningColors : _regularColors;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: SizedBox.square(
                      dimension: 52,
                      child: Icon(
                        icon,
                        size: 22,
                        color: iconColor ?? colors.icon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
