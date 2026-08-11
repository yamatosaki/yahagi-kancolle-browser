import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import '../fleet/dashboard_card.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class PinnedQuestsSummary extends StatelessWidget {
  const PinnedQuestsSummary({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenQuest,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenQuest;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final quests = controller.state.quests.values;
        final pinnedQuests = quests.where((q) => q.isAccepted).toList();
        final state = controller.state;
        final missingQuestCount = state.hasQuestData
            ? (state.activeQuestCount - pinnedQuests.length).clamp(
                0,
                state.activeQuestCount,
              )
            : 1;
        final l10n =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));

        return DashboardCard(
          title: l10n.questBrief,
          icon: const Icon(Icons.assignment_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pinnedQuests.isEmpty &&
                  (!state.hasQuestData || state.activeQuestCount == 0))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text(
                      state.hasQuestData
                          ? l10n.noPinnedQuests
                          : l10n.questsNeedSync,
                      style: const TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else ...<Widget>[
                ...pinnedQuests.map(
                  (q) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onOpenQuest(q.id),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff0d1a26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: q.categoryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                q.categoryLabel,
                                style: TextStyle(
                                  color: q.categoryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q.title,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getProgressText(q),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getProgressColor(q),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                for (var index = 0; index < missingQuestCount; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      l10n.questsNeedSync,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 2),
            ],
          ),
        );
      },
    );
  }

  String _getProgressText(GameQuest q) {
    if (q.isCompleted) return '完成';
    if (q.state == 2) {
      if (q.progressFlag == 1) return '50%';
      if (q.progressFlag == 2) return '80%';
      return '进行中';
    }
    return '';
  }

  Color _getProgressColor(GameQuest q) {
    if (q.isCompleted) return const Color(0xff4caf50);
    if (q.state == 2 && q.progressFlag > 0) return const Color(0xffd4a85f);
    return const Color(0xff8197a5);
  }
}
