import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../settings/game_frame_refresh_shortcut_settings.dart';
import 'game_surface_dialog.dart';

Future<bool> confirmGameFrameRefreshShortcut({
  required BuildContext context,
  required GameFrameRefreshShortcutSettings settings,
}) async {
  if (settings.skipHeaderConfirmation) return true;
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  var skipNextTime = false;
  final confirmed =
      await showGameSurfaceDialog<bool>(
        context: context,
        title: l10n.frameRefreshShortcutConfirmTitle,
        message: l10n.frameRefreshShortcutConfirmDescription,
        checkbox: GameSurfaceDialogCheckbox(
          label: l10n.frameRefreshShortcutSkipConfirmation,
          onChanged: (value) => skipNextTime = value,
        ),
        actions: [
          GameSurfaceDialogAction(
            id: 'cancel',
            label: l10n.cancel,
            value: false,
          ),
          GameSurfaceDialogAction(
            id: 'confirm',
            label: l10n.frameRefreshShortcutConfirmAction,
            value: true,
          ),
        ],
        builder: (dialogContext, close) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            key: const Key('frame-refresh-confirm-dialog'),
            title: Text(l10n.frameRefreshShortcutConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.frameRefreshShortcutConfirmDescription),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const Key('frame-refresh-skip-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: skipNextTime,
                  title: Text(l10n.frameRefreshShortcutSkipConfirmation),
                  onChanged: (value) =>
                      setState(() => skipNextTime = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('frame-refresh-cancel'),
                onPressed: () => close(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('frame-refresh-confirm'),
                onPressed: () => close(true),
                child: Text(l10n.frameRefreshShortcutConfirmAction),
              ),
            ],
          ),
        ),
      ) ??
      false;
  if (!confirmed) return false;
  if (skipNextTime) await settings.setSkipHeaderConfirmation(true);
  return true;
}
