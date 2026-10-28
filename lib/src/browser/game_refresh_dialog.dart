import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'game_browser_controller.dart';
import 'game_frame_refresh_shortcut_action.dart';
import 'game_surface_dialog.dart';

Future<void> showGameRefreshDialog({
  required BuildContext context,
  required Future<void> Function() onRefreshPage,
  required Future<GameFrameReloadResult> Function() onReloadGame,
}) async {
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  final action = await showGameSurfaceDialog<String>(
    context: context,
    title: l10n.confirmGameRefreshTitle,
    message: l10n.gameRefreshDialogDescription,
    actions: [
      GameSurfaceDialogAction(
        id: 'cancel',
        label: l10n.cancel,
        value: 'cancel',
      ),
      GameSurfaceDialogAction(
        id: 'refreshPage',
        label: l10n.refreshGamePage,
        value: 'refreshPage',
      ),
      GameSurfaceDialogAction(
        id: 'reloadFrame',
        label: l10n.reloadGame,
        value: 'reloadFrame',
      ),
    ],
    builder: (dialogContext, close) => AlertDialog(
      title: Text(l10n.confirmGameRefreshTitle),
      content: Text(l10n.gameRefreshDialogDescription),
      actions: <Widget>[
        TextButton(onPressed: () => close(null), child: Text(l10n.cancel)),
        OutlinedButton(
          key: const Key('refresh-full-page'),
          onPressed: () => close('refreshPage'),
          child: Text(l10n.refreshGamePage),
        ),
        FilledButton(
          key: const Key('reload-game-frame'),
          onPressed: () => close('reloadFrame'),
          child: Text(l10n.reloadGame),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (action == 'refreshPage') {
    await onRefreshPage();
  } else if (action == 'reloadFrame') {
    await runGameFrameRefreshShortcut(context: context, reload: onReloadGame);
  }
}
