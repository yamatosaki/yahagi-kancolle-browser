import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'battle_prediction_settings.dart';

class BattlePredictionSettingsSection extends StatelessWidget {
  const BattlePredictionSettingsSection({super.key, required this.controller});

  final BattlePredictionSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.battlePredictionEngine,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              l10n.battlePredictionRecommendation,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xff8195a5)),
            ),
            const SizedBox(height: 12),
            SegmentedButton<BattlePredictionMethod>(
              key: const Key('battle-prediction-method'),
              showSelectedIcon: false,
              segments: <ButtonSegment<BattlePredictionMethod>>[
                ButtonSegment<BattlePredictionMethod>(
                  value: BattlePredictionMethod.poi,
                  label: Text(l10n.battlePredictionHighAccuracy),
                ),
                ButtonSegment<BattlePredictionMethod>(
                  value: BattlePredictionMethod.yahagi,
                  label: Text(l10n.battlePredictionLightweight),
                ),
              ],
              selected: <BattlePredictionMethod>{controller.method},
              onSelectionChanged: (selection) {
                controller.setMethod(selection.single);
              },
            ),
            const SizedBox(height: 12),
            Text(
              controller.method == BattlePredictionMethod.poi
                  ? l10n.battlePredictionHighAccuracyDesc
                  : l10n.battlePredictionLightweightDesc,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xff8195a5)),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.battlePredictionNextBattle,
              style: const TextStyle(fontSize: 11, color: Color(0xff8195a5)),
            ),
          ],
        ),
      ),
    );
  }
}
