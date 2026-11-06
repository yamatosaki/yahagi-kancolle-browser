import '../theme/app_palette.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'game_frame_rate_settings.dart';
import 'settings_ui_helpers.dart';
import '../widgets/app_segmented_style.dart';

class GameFrameRateSettingsSection extends StatelessWidget {
  const GameFrameRateSettingsSection({super.key, required this.controller});

  final GameFrameRateSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.gameFrameRateTitle,
              style: appTextStyle(context, SettingsTileTypography.title),
            ),
            const SizedBox(height: 10),
            SegmentedButton<GameFrameRateMode>(
              key: const Key('game-frame-rate-mode'),
              style: AppSegmentedStyle.materialStyle(context),
              segments: <ButtonSegment<GameFrameRateMode>>[
                ButtonSegment<GameFrameRateMode>(
                  value: GameFrameRateMode.automatic,
                  label: Text(l10n.gameFrameRateAutomatic),
                ),
                ButtonSegment<GameFrameRateMode>(
                  value: GameFrameRateMode.stable60,
                  label: Text(l10n.gameFrameRateStable60),
                ),
                ButtonSegment<GameFrameRateMode>(
                  value: GameFrameRateMode.stable30,
                  label: Text(l10n.gameFrameRateStable30),
                ),
                ButtonSegment<GameFrameRateMode>(
                  value: GameFrameRateMode.highRefresh,
                  label: Text(l10n.gameFrameRateHighRefresh),
                ),
              ],
              selected: <GameFrameRateMode>{controller.mode},
              onSelectionChanged: controller.supported == false
                  ? null
                  : (selection) =>
                        unawaited(_selectMode(context, l10n, selection.single)),
            ),
            const SizedBox(height: 8),
            Text(
              controller.supported == false
                  ? l10n.gameFrameRateUnsupported
                  : switch (controller.mode) {
                      GameFrameRateMode.automatic =>
                        l10n.gameFrameRateAutomaticDesc,
                      GameFrameRateMode.stable60 =>
                        l10n.gameFrameRateStable60Desc,
                      GameFrameRateMode.stable30 =>
                        l10n.gameFrameRateStable30Desc,
                      GameFrameRateMode.highRefresh =>
                        l10n.gameFrameRateHighRefreshDesc,
                    },
              style: appTextStyle(context, SettingsTileTypography.description),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMode(
    BuildContext context,
    AppLocalizations l10n,
    GameFrameRateMode mode,
  ) async {
    if (mode == controller.mode) return;
    if (mode == GameFrameRateMode.highRefresh) {
      final confirmed = await showDialog<bool>(
        barrierDismissible: false,
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.gameFrameRateHighRefreshDialogTitle),
          content: Text(l10n.gameFrameRateHighRefreshDialogBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.gameFrameRateHighRefreshDialogConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await controller.setMode(mode);
  }
}
