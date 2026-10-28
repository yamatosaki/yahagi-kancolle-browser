import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import 'game_surface_dialog.dart';

const exitFullscreenSkipConfirmationKey =
    'game_fullscreen_exit_skip_confirmation';

Future<bool> isExitFullscreenConfirmationSkipped([
  SharedPreferences? preferences,
]) async {
  try {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    return prefs.getBool(exitFullscreenSkipConfirmationKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> setExitFullscreenConfirmationSkipped(
  bool value, [
  SharedPreferences? preferences,
]) async {
  try {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(exitFullscreenSkipConfirmationKey, value);
  } catch (_) {
    // Non-fatal if preference saving fails.
  }
}

Future<bool> confirmGameFullscreenExit({
  required BuildContext context,
  SharedPreferences? preferences,
}) async {
  if (await isExitFullscreenConfirmationSkipped(preferences)) {
    return true;
  }
  if (!context.mounted) return false;
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  var skipNextTime = false;
  final confirmed =
      await showGameSurfaceDialog<bool>(
        context: context,
        title: l10n.exitFullscreenConfirmTitle,
        message: l10n.exitFullscreenConfirmDescription,
        checkbox: GameSurfaceDialogCheckbox(
          label: l10n.exitFullscreenSkipConfirmation,
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
            label: l10n.exitFullscreenConfirmAction,
            value: true,
          ),
        ],
        builder: (dialogContext, close) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            key: const Key('fullscreen-exit-confirm-dialog'),
            title: Text(l10n.exitFullscreenConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.exitFullscreenConfirmDescription),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const Key('fullscreen-exit-skip-confirmation'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: skipNextTime,
                  title: Text(l10n.exitFullscreenSkipConfirmation),
                  onChanged: (value) =>
                      setState(() => skipNextTime = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('fullscreen-exit-cancel'),
                onPressed: () => close(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('fullscreen-exit-confirm'),
                onPressed: () => close(true),
                child: Text(l10n.exitFullscreenConfirmAction),
              ),
            ],
          ),
        ),
      ) ??
      false;
  if (!confirmed) return false;
  if (skipNextTime) {
    await setExitFullscreenConfirmationSkipped(true, preferences);
  }
  return true;
}
