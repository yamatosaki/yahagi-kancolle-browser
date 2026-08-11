import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'game_frame_rate_settings.dart';

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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SegmentedButton<GameFrameRateMode>(
              key: const Key('game-frame-rate-mode'),
              segments: <ButtonSegment<GameFrameRateMode>>[
                ButtonSegment<GameFrameRateMode>(
                  value: GameFrameRateMode.automatic,
                  label: Text(l10n.gameFrameRateAutomatic),
                ),
                ButtonSegment<GameFrameRateMode>(
                  value: GameFrameRateMode.stable30,
                  label: Text(l10n.gameFrameRateStable30),
                ),
                ButtonSegment<GameFrameRateMode>(
                  value: GameFrameRateMode.prefer60,
                  label: Text(l10n.gameFrameRatePrefer60),
                ),
              ],
              selected: <GameFrameRateMode>{controller.mode},
              onSelectionChanged: controller.supported == false
                  ? null
                  : (selection) {
                      unawaited(controller.setMode(selection.single));
                    },
            ),
            const SizedBox(height: 8),
            Text(
              controller.supported == false
                  ? l10n.gameFrameRateUnsupported
                  : switch (controller.mode) {
                      GameFrameRateMode.automatic =>
                        l10n.gameFrameRateAutomaticDesc,
                      GameFrameRateMode.stable30 =>
                        l10n.gameFrameRateStable30Desc,
                      GameFrameRateMode.prefer60 =>
                        l10n.gameFrameRatePrefer60Desc,
                    },
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xff8197a5)),
            ),
          ],
        ),
      ),
    );
  }
}
