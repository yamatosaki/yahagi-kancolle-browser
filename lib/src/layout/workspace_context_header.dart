import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/fleet_information_center.dart';
import '../fleet/anchorage_repair_view.dart';
import '../fleet/expedition_summary_card.dart' show ExpeditionSummaryMode, ExpeditionModeSelector;
import '../fleet/resource_grid.dart';
import '../game_state/game_state.dart';
import '../inventory/owned_inventory_page.dart';
import '../logbook/logbook_page.dart';
import '../quest/quest_center_page.dart';

class WorkspaceContextHeader extends StatelessWidget {
  const WorkspaceContextHeader({
    super.key,
    required this.workspaceIndex,
    required this.state,
    required this.selectedFleetId,
    this.onFleetSelected,
    this.inventoryShowShips = true,
    this.onInventorySectionChanged,
    this.logbookTabIndex = 0,
    this.onLogbookTabChanged,
    this.repairMode = RepairCenterMode.dock,
    this.onRepairModeChanged,
    this.expeditionMode = ExpeditionSummaryMode.summary,
    this.onExpeditionModeChanged,
  });

  final int workspaceIndex;
  final GameState state;
  final int selectedFleetId;
  final ValueChanged<int>? onFleetSelected;
  final bool inventoryShowShips;
  final ValueChanged<bool>? onInventorySectionChanged;
  final int logbookTabIndex;
  final ValueChanged<int>? onLogbookTabChanged;
  final RepairCenterMode repairMode;
  final ValueChanged<RepairCenterMode>? onRepairModeChanged;
  final ExpeditionSummaryMode expeditionMode;
  final ValueChanged<ExpeditionSummaryMode>? onExpeditionModeChanged;

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
        sortieFleetId: state.combatState.isActive
            ? state.combatState.sortieFleetId
            : null,
        onFleetSelected: onFleetSelected,
      );
    }
    if (workspaceIndex == 3) {
      return Row(
        children: [
          Text(
            l10n.repair,
            key: const Key('workspace-title-repair-fleet'),
            style: const TextStyle(
              color: Color(0xffe0b25c),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: RepairModeTabs(
              mode: repairMode,
              onChanged: onRepairModeChanged ?? (_) {},
            ),
          ),
        ],
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
    if (workspaceIndex == 6) {
      return Row(
        children: [
          Text(
            l10n.battleRecords,
            key: const Key('workspace-title-logbook'),
            style: const TextStyle(
              color: Color(0xffe0b25c),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: LogbookSegmented(
              selectedIndex: logbookTabIndex,
              onChanged: onLogbookTabChanged ?? (_) {},
            ),
          ),
        ],
      );
    }
    if (workspaceIndex == 7) {
      return Row(
        children: [
          Text(
            _ownedInventoryTitle(l10n),
            key: const Key('workspace-title-owned-inventory'),
            style: const TextStyle(
              color: Color(0xffe0b25c),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          OwnedInventorySegmented(
            showShips: inventoryShowShips,
            shipCount: state.ships.length,
            equipmentCount: state.slotItems.length,
            onChanged: onInventorySectionChanged ?? (_) {},
          ),
        ],
      );
    }

    final page = _workspacePage(workspaceIndex, l10n);
    return Row(
      children: [
        Text(
          page.$2,
          key: Key('workspace-title-${page.$1}'),
          style: const TextStyle(
            color: Color(0xffe0b25c),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (workspaceIndex == 2 && onExpeditionModeChanged != null) ...[
          const Spacer(),
          ExpeditionModeSelector(
            mode: expeditionMode,
            summaryLabel: '简报',
            checkLabel: '检查',
            onChanged: onExpeditionModeChanged!,
          ),
        ],
      ],
    );
  }

  static (String, String) _workspacePage(int index, AppLocalizations l10n) =>
      switch (index) {
        2 => ('expedition', l10n.expedition),
        3 => ('repair', l10n.repair),
        4 => ('construction', l10n.construction),
        5 => ('quest', l10n.quests),
        6 => ('logbook', l10n.battleRecords),
        8 => ('settings', l10n.settings),
        9 => ('expedition-check', l10n.preSortieCheck),
        _ => ('unknown', ''),
      };

  static String _ownedInventoryTitle(AppLocalizations l10n) =>
      l10n.localeName.startsWith('ja')
      ? '保有一覧'
      : l10n.localeName.contains('Hant')
      ? '持有一覽'
      : '持有一览';
}
