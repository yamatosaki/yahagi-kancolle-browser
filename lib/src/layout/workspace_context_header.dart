import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/fleet_information_center.dart';
import '../fleet/resource_grid.dart';
import '../game_state/game_state.dart';
import '../quest/quest_center_page.dart';

class WorkspaceContextHeader extends StatelessWidget {
  const WorkspaceContextHeader({
    super.key,
    required this.workspaceIndex,
    required this.state,
    required this.selectedFleetId,
    this.onFleetSelected,
  });

  final int workspaceIndex;
  final GameState state;
  final int selectedFleetId;
  final ValueChanged<int>? onFleetSelected;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    if (workspaceIndex == 0) {
      return CompactResourceBar(state: state);
    }
    if (workspaceIndex == 1) {
      return FleetSwitcherBar(
        fleets: state.fleets,
        selectedFleetId: selectedFleetId,
        onFleetSelected: onFleetSelected,
      );
    }
    if (workspaceIndex == 5) {
      return Row(
        children: [
          Text(
            l10n.quests,
            key: const Key('workspace-title-quest'),
            style: const TextStyle(
              color: Color(0xffe0b25c),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          QuestCountSegmentedBar(quests: state.quests.values),
        ],
      );
    }

    final page = _workspacePage(workspaceIndex, l10n);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        page.$2,
        key: Key('workspace-title-${page.$1}'),
        style: const TextStyle(
          color: Color(0xffe0b25c),
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static (String, String) _workspacePage(int index, AppLocalizations l10n) =>
      switch (index) {
        2 => ('expedition', l10n.expedition),
        3 => ('repair', l10n.repair),
        4 => ('construction', l10n.construction),
        5 => ('quest', l10n.quests),
        6 => ('logbook', l10n.battleRecords),
        7 => ('settings', l10n.settings),
        8 => ('expedition-check', l10n.preSortieCheck),
        _ => ('unknown', ''),
      };
}
