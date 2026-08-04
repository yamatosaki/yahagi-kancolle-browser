import 'package:flutter/material.dart';

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
          const Text(
            '任务',
            key: Key('workspace-title-quest'),
            style: TextStyle(
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

    final page = _workspacePage(workspaceIndex);
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

  static (String, String) _workspacePage(int index) => switch (index) {
    2 => ('expedition', '远征'),
    3 => ('repair', '入渠'),
    4 => ('construction', '建造'),
    5 => ('quest', '任务'),
    6 => ('logbook', '战斗记录'),
    7 => ('settings', '设置'),
    8 => ('expedition-check', '出击前检查'),
    _ => ('unknown', ''),
  };
}
