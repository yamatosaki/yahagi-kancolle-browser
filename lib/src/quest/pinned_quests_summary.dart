import '../theme/app_palette.dart';
import '../localization/game_name_localizations.dart';
import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import '../fleet/dashboard_card.dart';
import '../layout/flat_empty_text.dart';
import '../layout/flat_style.dart';
import '../layout/hd_dashboard_content.dart';
import '../layout/flat_list_row.dart';
import '../layout/module_summaries.dart';
import '../layout/panel_style.dart';
import '../settings/module_display_settings.dart';
import 'quest_catalog_controller.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class PinnedQuestsSummary extends StatelessWidget {
  const PinnedQuestsSummary({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenQuest,
    this.showLogo = true,
    this.showTitle = true,
    this.onOpenDisplaySettings,
    this.catalogController,
    this.visible = const {'type', 'number', 'name', 'progress'},
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onOpenQuest;
  final bool showLogo;
  final bool showTitle;
  final VoidCallback? onOpenDisplaySettings;
  final QuestCatalogController? catalogController;
  final Set<String> visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, catalogController]),
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
        final flat = PanelStyleScope.isFlat(context);

        return DashboardCard(
          collapsedSummary: collapsed ? questSummary(l10n, state) : null,
          headerAction: moduleDisplayGear(
            context,
            'quests',
            onOpenDisplaySettings,
          ),
          title: l10n.questBrief,
          icon: const Icon(Icons.assignment_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          showLogo: showLogo,
          showTitle: showTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pinnedQuests.isEmpty &&
                  (!state.hasQuestData || state.activeQuestCount == 0))
                flat
                    ? FlatEmptyText(
                        state.hasQuestData
                            ? l10n.noPinnedQuests
                            : l10n.questsNeedSync,
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Text(
                            state.hasQuestData
                                ? l10n.noPinnedQuests
                                : l10n.questsNeedSync,
                            style: TextStyle(
                              color: appColor(context, const Color(0xff8197a5)),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
              else ...<Widget>[
                if (visible.isNotEmpty)
                  HdDashboardItems(
                    spacing: flat ? 0 : 3,
                    runSpacing: flat ? 0 : 3,
                    children: pinnedQuests
                        .map(
                          (q) => flat
                              ? _flatRow(context, l10n, q)
                              : Material(
                                  key: Key('quest-summary-item-${q.id}'),
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => onOpenQuest(q.id),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: appColor(
                                          context,
                                          const Color(0xff0d1a26),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: _standardRow(context, l10n, q),
                                    ),
                                  ),
                                ),
                        )
                        .toList(),
                  ),
                for (var index = 0; index < missingQuestCount; index++)
                  flat
                      ? FlatEmptyText(l10n.questsNeedSync)
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            l10n.questsNeedSync,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: appColor(context, const Color(0xff8197a5)),
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

  Widget _standardRow(
    BuildContext context,
    AppLocalizations l10n,
    GameQuest q,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      Widget tag(String text, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: appColor(context, q.categoryColor.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: appColor(context, q.categoryColor),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      final tags = <Widget>[
        if (visible.contains('type')) tag(_categoryLabel(l10n, q)),
        if (visible.contains('type') && visible.contains('number'))
          const SizedBox(width: 4),
        if (visible.contains('number'))
          tag(
            catalogController?.catalog.byGameId(q.id)?.code ?? '#${q.id}',
            key: Key('quest-summary-number-${q.id}'),
          ),
      ];
      final showName = visible.contains('name');
      final progress = visible.contains('progress')
          ? _getProgressText(q, l10n)
          : '';
      final gap = (constraints.maxWidth * .025).clamp(0.0, 6.0);
      // Keep badges and progress visible; the name receives the remaining
      // width. Only constrained badges/status scale down, never onto a new row.
      return Row(
        children: [
          if (tags.isNotEmpty) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    constraints.maxWidth *
                    (showName || progress.isNotEmpty ? .45 : 1),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: tags),
              ),
            ),
            if (showName || progress.isNotEmpty) SizedBox(width: gap),
          ],
          Expanded(
            child: showName
                ? Text(
                    gameNames(context).entityText(q.title),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appColor(context, const Color(0xffecf3f5)),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (progress.isNotEmpty) ...[
            if (showName || tags.isNotEmpty) SizedBox(width: gap),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    constraints.maxWidth *
                    (showName || tags.isNotEmpty ? .45 : 1),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  progress,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: appColor(context, _getProgressColor(q)),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    },
  );

  String _categoryLabel(AppLocalizations l10n, GameQuest q) =>
      switch (q.category) {
        1 => l10n.questFormation,
        2 || 8 || 9 || 10 => l10n.questSortie,
        3 => l10n.questExercise,
        4 => l10n.expedition,
        5 => l10n.questSupplyRepair,
        6 || 11 => l10n.questFactory,
        7 => l10n.questRemodeling,
        _ => l10n.questOther,
      };

  Widget _flatRow(BuildContext context, AppLocalizations l10n, GameQuest q) {
    Widget tag(Key? key, String text) =>
        flatRowText(context, text, key: key, color: q.categoryColor);
    final showType = visible.contains('type');
    final showNumber = visible.contains('number');
    final progress = visible.contains('progress')
        ? _getProgressText(q, l10n)
        : '';
    return KeyedSubtree(
      key: Key('quest-summary-item-${q.id}'),
      child: FlatListRow(
        onTap: () => onOpenQuest(q.id),
        tags: [
          if (showType) tag(null, _categoryLabel(l10n, q)),
          if (showNumber)
            tag(
              Key('quest-summary-number-${q.id}'),
              catalogController?.catalog.byGameId(q.id)?.code ?? '#${q.id}',
            ),
        ],
        name: visible.contains('name')
            ? flatRowText(
                context,
                gameNames(context).entityText(q.title),
                color: const Color(0xffecf3f5),
              )
            : null,
        trailing: progress.isEmpty
            ? null
            : flatRowTrailing(
                flatRowText(
                  context,
                  progress,
                  color: q.isCompleted ? flatDoneColor : _getProgressColor(q),
                ),
              ),
      ),
    );
  }

  String _getProgressText(GameQuest q, AppLocalizations l10n) {
    if (q.isCompleted) return l10n.done;
    if (q.exactProgressLabel case final progress?) {
      if (q.progressRequired != null &&
          q.progressRequired! > 0 &&
          q.progressCurrent != null &&
          q.progressCurrent! >= q.progressRequired!) {
        return '$progress · ${l10n.questAwaitingConfirmation}';
      }
    }
    if (q.exactProgressLabel != null) return q.displayProgressLabel;
    if (q.state == 2) {
      if (q.progressFlag == 1 || q.progressFlag == 2) {
        return q.displayProgressLabel;
      }
      return l10n.inProgress;
    }
    return '';
  }

  Color _getProgressColor(GameQuest q) {
    if (q.isCompleted) return const Color(0xff4caf50);
    if (q.state == 2 && q.progressFlag > 0) return const Color(0xffd4a85f);
    return const Color(0xff8197a5);
  }
}
