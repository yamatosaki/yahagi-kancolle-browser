import 'package:flutter/widgets.dart';

import '../layout/flat_style.dart';
import '../layout/panel_style.dart';
import '../settings/battle_prediction_settings.dart';

/// Keeps each available feature together while honoring the shared display order.
class BattlePredictionSections extends StatelessWidget {
  const BattlePredictionSections({
    super.key,
    this.order,
    this.visibleSections = BattlePredictionSection.values,
    this.legacyEnemyPreviewPosition = EnemyPreviewPosition.above,
    this.sortieMap,
    this.enemyPreview,
    required this.predictionResult,
  });

  final List<BattlePredictionSection>? order;
  final Iterable<BattlePredictionSection> visibleSections;
  final EnemyPreviewPosition legacyEnemyPreviewPosition;
  final Widget? sortieMap;
  final Widget? enemyPreview;
  final Widget predictionResult;

  @override
  Widget build(BuildContext context) {
    final sections = <BattlePredictionSection, Widget?>{
      BattlePredictionSection.sortieMap: sortieMap,
      BattlePredictionSection.enemyPreview: enemyPreview,
      BattlePredictionSection.predictionResult: predictionResult,
    };
    final effectiveOrder = normalizeBattlePredictionSectionOrder(
      order ??
          (legacyEnemyPreviewPosition == EnemyPreviewPosition.above
              ? defaultBattlePredictionSectionOrder
              : const [
                  BattlePredictionSection.sortieMap,
                  BattlePredictionSection.predictionResult,
                  BattlePredictionSection.enemyPreview,
                ]),
    );
    final gap = PanelStyleScope.isFlat(context) ? flatSectionGap : 9.0;
    final children = <Widget>[];
    for (final section in effectiveOrder) {
      final content = sections[section];
      if (content == null || !visibleSections.contains(section)) continue;
      if (children.isNotEmpty) children.add(SizedBox(height: gap));
      children.add(
        KeyedSubtree(
          key: ValueKey('battle-prediction-section-${section.name}'),
          child: content,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
