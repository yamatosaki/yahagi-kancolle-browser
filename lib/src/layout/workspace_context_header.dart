import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fleet/fleet_information_center.dart';
import '../fleet/anchorage_repair_view.dart';
import '../fleet/expedition_summary_card.dart'
    show ExpeditionSummaryMode, ExpeditionModeSelector;
import '../fleet/resource_grid.dart';
import '../game_state/game_state.dart';
import '../inventory/owned_inventory_page.dart';
import '../improvement/improvement_planner_controller.dart';
import '../logbook/logbook_page.dart';
import '../quest/quest_center_page.dart';
import '../settings/layout_settings_controller.dart';
import '../senka/senka_state.dart';

class WorkspaceContextHeader extends StatelessWidget {
  const WorkspaceContextHeader({
    super.key,
    required this.workspaceIndex,
    required this.state,
    this.senkaState,
    this.onSenkaTap,
    this.anchorageRepairStartedAt,
    this.onAnchorageTimerTap,
    required this.selectedFleetId,
    this.onFleetSelected,
    this.inventoryShowShips = true,
    this.onInventorySectionChanged,
    this.logbookTabIndex = 0,
    this.onLogbookTabChanged,
    this.settingsTabIndex = 0,
    this.onSettingsTabChanged,
    this.repairMode = RepairCenterMode.dock,
    this.onRepairModeChanged,
    this.questMode = QuestCenterMode.active,
    this.onQuestModeChanged,
    this.questFilters,
    this.expeditionMode = ExpeditionSummaryMode.summary,
    this.onExpeditionModeChanged,
    this.constructionMode = ConstructionCenterMode.construction,
    this.onConstructionModeChanged,
    this.layoutSettingsController,
  });

  final int workspaceIndex;
  final GameState state;
  final SenkaState? senkaState;
  final VoidCallback? onSenkaTap;
  final DateTime? anchorageRepairStartedAt;
  final VoidCallback? onAnchorageTimerTap;
  final int selectedFleetId;
  final ValueChanged<int>? onFleetSelected;
  final bool inventoryShowShips;
  final ValueChanged<bool>? onInventorySectionChanged;
  final int logbookTabIndex;
  final ValueChanged<int>? onLogbookTabChanged;
  final int settingsTabIndex;
  final ValueChanged<int>? onSettingsTabChanged;
  final RepairCenterMode repairMode;
  final ValueChanged<RepairCenterMode>? onRepairModeChanged;
  final QuestCenterMode questMode;
  final ValueChanged<QuestCenterMode>? onQuestModeChanged;
  final QuestFilterController? questFilters;
  final ExpeditionSummaryMode expeditionMode;
  final ValueChanged<ExpeditionSummaryMode>? onExpeditionModeChanged;
  final ConstructionCenterMode constructionMode;
  final ValueChanged<ConstructionCenterMode>? onConstructionModeChanged;
  final LayoutSettingsController? layoutSettingsController;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    if (workspaceIndex == 0) {
      final playerRanking = senkaState?.playerRankingRow;
      return CompactResourceBar(
        state: state,
        senka: playerRanking?.senka,
        rank: playerRanking?.rank,
        onSenkaTap: onSenkaTap,
        anchorageRepairStartedAt: anchorageRepairStartedAt,
        onAnchorageTimerTap: onAnchorageTimerTap,
        settingsController: layoutSettingsController,
      );
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
    if (workspaceIndex == 4) {
      return Row(
        children: [
          Text(
            l10n.construction,
            key: const Key('workspace-title-construction'),
            style: const TextStyle(
              color: Color(0xffe0b25c),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          ConstructionModeTabs(
            mode: constructionMode,
            onChanged: onConstructionModeChanged ?? (_) {},
          ),
        ],
      );
    }
    if (workspaceIndex == 5) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final controls = questFilters == null
              ? QuestModeTabs(
                  mode: questMode,
                  onChanged: onQuestModeChanged ?? (_) {},
                )
              : QuestHeaderControls(
                  mode: questMode,
                  filters: questFilters!,
                  onModeChanged: onQuestModeChanged ?? (_) {},
                );
          if (constraints.maxWidth < 430) {
            return Align(
              alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: controls),
            );
          }
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
              controls,
            ],
          );
        },
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
    if (workspaceIndex == 8) {
      return Row(
        children: [
          Text(
            l10n.settings,
            key: const Key('workspace-title-settings'),
            style: const TextStyle(
              color: Color(0xffe0b25c),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SettingsSegmented(
              selectedIndex: settingsTabIndex,
              onChanged: onSettingsTabChanged ?? (_) {},
            ),
          ),
        ],
      );
    }
    if (workspaceIndex == 9) {
      return Row(
        children: [
          Text(
            l10n.senka,
            key: const Key('workspace-title-senka'),
            style: const TextStyle(
              color: Color(0xffe0b25c),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
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
            summaryLabel: l10n.briefing,
            checkLabel: l10n.check,
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
        9 => ('senka', l10n.senka),
        _ => ('unknown', ''),
      };

  static String _ownedInventoryTitle(AppLocalizations l10n) =>
      l10n.ownedInventory;
}

class ConstructionModeTabs extends StatelessWidget {
  const ConstructionModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
  });
  final ConstructionCenterMode mode;
  final ValueChanged<ConstructionCenterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('construction-mode-tabs'),
      width: 260,
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final value in ConstructionCenterMode.values)
            Expanded(
              child: Material(
                color: mode == value
                    ? const Color(0xff8a6628)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: Key('construction-mode-${value.name}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(value),
                  child: Center(
                    child: Text(
                      value == ConstructionCenterMode.construction
                          ? l10n.construction
                          : l10n.improvement,
                      style: TextStyle(
                        color: mode == value
                            ? const Color(0xffffdc88)
                            : const Color(0xff9fb3bf),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsSegmented extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = <String>[
      l10n.settingsTabScreen,
      l10n.settingsTabSound,
      l10n.settingsTabBattle,
      l10n.settingsTabNetwork,
      l10n.settingsTabAboutSupport,
    ];
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: _SettingsSegmentButton(
                selected: index == selectedIndex,
                label: labels[index],
                onTap: () => onChanged(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsSegmentButton extends StatelessWidget {
  const _SettingsSegmentButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xff8a6628) : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xffffdc88) : const Color(0xff9fb3bf),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}
