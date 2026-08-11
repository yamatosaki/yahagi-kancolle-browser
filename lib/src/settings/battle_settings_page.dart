import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../battle/fcd_map_controller.dart';
import '../quest/quest_catalog_controller.dart';
import '../improvement/improvement_dataset_update_section.dart';
import '../improvement/improvement_planner_controller.dart';
import 'battle_prediction_settings.dart';
import 'battle_prediction_settings_section.dart';
import 'fcd_map_update_section.dart';
import 'quest_catalog_update_section.dart';
import 'safety_settings_controller.dart';
import 'safety_settings_store.dart';
import 'settings_ui_helpers.dart';

class BattleSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const BattleSettingsPage({
    super.key,
    this.battlePredictionSettingsController,
    this.fcdMapController,
    this.questCatalogController,
    required this.safetySettingsController,
    this.improvementPlannerController,
  });

  final BattlePredictionSettingsController? battlePredictionSettingsController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final SafetySettingsController safetySettingsController;
  final ImprovementPlannerController? improvementPlannerController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));

    return Container(
      color: const Color(0xff0d1a26),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildSectionTitle('战斗提醒'),
            buildCard(
              child: AnimatedBuilder(
                animation: safetySettingsController,
                builder: (context, _) => buildSwitchTile(
                  title: '战斗受损震动提醒',
                  subtitle: '我方舰娘在战斗中刚进入中破或大破时震动提醒。',
                  value: safetySettingsController.battleDamageVibrationEnabled,
                  onChanged:
                      safetySettingsController.setBattleDamageVibrationEnabled,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (battlePredictionSettingsController != null) ...<Widget>[
              buildSectionTitle('战斗预测'),
              buildCard(
                child: BattlePredictionSettingsSection(
                  controller: battlePredictionSettingsController!,
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (fcdMapController != null ||
                questCatalogController != null ||
                improvementPlannerController != null) ...[
              buildSectionTitle(l10n.fcdMapSectionTitle),
              buildCard(
                child: Column(
                  children: [
                    if (fcdMapController case final controller?)
                      FcdMapUpdateSection(controller: controller),
                    if (fcdMapController != null &&
                        questCatalogController != null)
                      const Divider(height: 1),
                    if (questCatalogController case final controller?)
                      QuestCatalogUpdateSection(controller: controller),
                    if ((fcdMapController != null ||
                            questCatalogController != null) &&
                        improvementPlannerController != null)
                      const Divider(height: 1),
                    if (improvementPlannerController case final controller?)
                      ImprovementDatasetUpdateSection(controller: controller),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            buildSectionTitle(l10n.gameSafety),
            buildCard(
              child: AnimatedBuilder(
                animation: safetySettingsController,
                builder: (context, _) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.blockSortieTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          DropdownButton<BattleWarningMode>(
                            value: safetySettingsController.battleWarningMode,
                            underline: const SizedBox(),
                            items: [
                              DropdownMenuItem(
                                value: BattleWarningMode.off,
                                child: Text(l10n.battleWarningOff),
                              ),
                              DropdownMenuItem(
                                value: BattleWarningMode.reminder,
                                child: Text(l10n.battleWarningReminder),
                              ),
                              DropdownMenuItem(
                                value: BattleWarningMode.confirm,
                                child: Text(l10n.battleWarningConfirm),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                safetySettingsController.setBattleWarningMode(
                                  value,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
