import '../theme/app_palette.dart';
import '../widgets/app_segmented_style.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../development/development_workbench_state_store.dart'
    show DevelopmentWorkbenchMode;
export '../development/development_workbench_state_store.dart'
    show DevelopmentWorkbenchMode;
import '../fleet/fleet_information_center.dart';
import '../fleet/anchorage_repair_view.dart';
import '../fleet/expedition_summary_card.dart'
    show ExpeditionSummaryMode, ExpeditionModeSelector;
import '../expedition/expedition_strings.dart';
import '../fleet/resource_grid.dart';
import '../game_state/game_state.dart';
import '../inventory/owned_inventory_page.dart';
import '../inventory/unowned_inventory_projection.dart';
import '../improvement/improvement_planner_controller.dart';
import '../logbook/logbook_page.dart';
import '../quest/quest_center_page.dart';
import '../settings/layout_settings_controller.dart';
import '../settings/settings_organization_strings.dart';
import '../settings/ui_display_size.dart';
import '../senka/senka_page.dart' show SenkaCenterMode, senkaCenterModeLabel;
import '../senka/senka_state.dart';
import '../toolbox/toolbox_mode.dart';
import '../toolbox/toolbox_mode_tabs.dart';
export '../toolbox/toolbox_mode_tabs.dart' show ToolboxModeTabs;

class WorkspaceContextHeader extends StatelessWidget {
  const WorkspaceContextHeader({
    super.key,
    required this.workspaceIndex,
    required this.state,
    this.senkaState,
    this.onSenkaTap,
    this.anchorageRepairStartedAt,
    this.onAnchorageTimerTap,
    this.nosakiSparkleStartedAt,
    this.onNosakiTimerTap,
    this.onFrameRefreshTap,
    this.onGameRefreshTap,
    required this.selectedFleetId,
    this.onFleetSelected,
    this.inventoryShowShips = true,
    this.inventoryShowOwned = true,
    this.onInventoryOwnershipChanged,
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
    this.questTranslationEnabled = false,
    this.onQuestTranslationChanged,
    this.expeditionMode = ExpeditionSummaryMode.summary,
    this.onExpeditionModeChanged,
    this.constructionMode = ConstructionCenterMode.construction,
    this.onConstructionModeChanged,
    this.developmentMode = DevelopmentWorkbenchMode.calculator,
    this.onDevelopmentModeChanged,
    this.senkaMode = SenkaCenterMode.info,
    this.onSenkaModeChanged,
    this.toolboxMode = ToolboxMode.export,
    this.onToolboxModeChanged,
    this.layoutSettingsController,
    this.uiSize,
    this.flatStyle = false,
  });

  final int workspaceIndex;
  final GameState state;
  final SenkaState? senkaState;
  final VoidCallback? onSenkaTap;
  final DateTime? anchorageRepairStartedAt;
  final VoidCallback? onAnchorageTimerTap;
  final DateTime? nosakiSparkleStartedAt;
  final VoidCallback? onNosakiTimerTap;
  final VoidCallback? onFrameRefreshTap;
  final VoidCallback? onGameRefreshTap;
  final int selectedFleetId;
  final ValueChanged<int>? onFleetSelected;
  final bool inventoryShowShips;
  final bool inventoryShowOwned;
  final ValueChanged<bool>? onInventoryOwnershipChanged;
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
  final bool questTranslationEnabled;
  final ValueChanged<bool>? onQuestTranslationChanged;
  final ExpeditionSummaryMode expeditionMode;
  final ValueChanged<ExpeditionSummaryMode>? onExpeditionModeChanged;
  final ConstructionCenterMode constructionMode;
  final ValueChanged<ConstructionCenterMode>? onConstructionModeChanged;
  final DevelopmentWorkbenchMode developmentMode;
  final ValueChanged<DevelopmentWorkbenchMode>? onDevelopmentModeChanged;
  final SenkaCenterMode senkaMode;
  final ValueChanged<SenkaCenterMode>? onSenkaModeChanged;
  final ToolboxMode toolboxMode;
  final ValueChanged<ToolboxMode>? onToolboxModeChanged;
  final LayoutSettingsController? layoutSettingsController;
  final UiDisplaySize? uiSize;
  final bool flatStyle;

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
        nosakiSparkleStartedAt: nosakiSparkleStartedAt,
        onNosakiTimerTap: onNosakiTimerTap,
        onFrameRefreshTap: onFrameRefreshTap,
        onGameRefreshTap: onGameRefreshTap,
        settingsController: layoutSettingsController,
        uiSize: uiSize,
        flatStyle: flatStyle,
      );
    }
    if (workspaceIndex == 1) {
      return FleetSwitcherBar(
        fleets: state.fleets,
        selectedFleetId: selectedFleetId,
        state: state,
        anchorageRepairStartedAt: anchorageRepairStartedAt,
        nosakiSparkleStartedAt: nosakiSparkleStartedAt,
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
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffe0b25c)),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
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
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffe0b25c)),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (constructionMode ==
                        ConstructionCenterMode.development) ...[
                      DevelopmentWorkbenchModeTabs(
                        mode: developmentMode,
                        onChanged: onDevelopmentModeChanged ?? (_) {},
                      ),
                      const SizedBox(width: 8),
                    ],
                    ConstructionModeTabs(
                      mode: constructionMode,
                      onChanged: (newMode) {
                        if (newMode == ConstructionCenterMode.development) {
                          onDevelopmentModeChanged?.call(
                            DevelopmentWorkbenchMode.calculator,
                          );
                        }
                        onConstructionModeChanged?.call(newMode);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (workspaceIndex == 5) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final controls = questFilters == null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QuestTranslationToggle(
                      enabled: questTranslationEnabled,
                      compact: constraints.maxWidth < 560,
                      onChanged: onQuestTranslationChanged ?? (_) {},
                    ),
                    const SizedBox(width: 8),
                    QuestModeTabs(
                      mode: questMode,
                      onChanged: onQuestModeChanged ?? (_) {},
                    ),
                  ],
                )
              : QuestHeaderControls(
                  mode: questMode,
                  filters: questFilters!,
                  onModeChanged: onQuestModeChanged ?? (_) {},
                  translationEnabled: questTranslationEnabled,
                  onTranslationChanged: onQuestTranslationChanged ?? (_) {},
                  compactTranslation: constraints.maxWidth < 560,
                );
          if (constraints.maxWidth < 430) {
            return Align(alignment: Alignment.centerRight, child: controls);
          }
          return Row(
            children: [
              Text(
                l10n.quests,
                key: const Key('workspace-title-quest'),
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xffe0b25c)),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: controls),
              ),
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
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffe0b25c)),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
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
      final unowned = inventoryShowOwned
          ? null
          : UnownedInventoryProjection(state);
      return Row(
        children: [
          Text(
            _ownedInventoryTitle(l10n),
            key: const Key('workspace-title-owned-inventory'),
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffe0b25c)),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    OwnedInventoryOwnershipSegmented(
                      showOwned: inventoryShowOwned,
                      onChanged: onInventoryOwnershipChanged ?? (_) {},
                    ),
                    const SizedBox(width: 8),
                    OwnedInventorySegmented(
                      showShips: inventoryShowShips,
                      shipCount: inventoryShowOwned
                          ? state.ships.length
                          : unowned!.unownedShipFamilies.length,
                      equipmentCount: inventoryShowOwned
                          ? state.equipmentCapacityUsed
                          : unowned!.unownedEquipment.length,
                      onChanged: onInventorySectionChanged ?? (_) {},
                    ),
                  ],
                ),
              ),
            ),
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
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, Color(0xffe0b25c)),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
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
      final title = Text(
        l10n.senka,
        key: const Key('workspace-title-senka'),
        style: appTextStyle(
          context,
          TextStyle(
            color: appColor(context, Color(0xffe0b25c)),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      final tabs = SenkaModeTabs(
        mode: senkaMode,
        onChanged: onSenkaModeChanged ?? (_) {},
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 430) {
            return Row(
              children: [
                title,
                const SizedBox(width: 8),
                Expanded(child: tabs),
              ],
            );
          }
          return Row(children: [title, const Spacer(), tabs]);
        },
      );
    }
    if (workspaceIndex == 10) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Keep six readable tabs; narrow headers scroll rather than shrink labels.
          final compact = constraints.maxWidth < 640;
          final tabs = ToolboxModeTabs(
            mode: toolboxMode,
            compact: compact,
            onChanged: onToolboxModeChanged ?? (_) {},
          );
          if (compact) {
            return SizedBox(width: constraints.maxWidth, child: tabs);
          }
          return Row(
            children: [
              Text(
                l10n.toolbox,
                key: const Key('workspace-title-tools'),
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xffe0b25c)),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: tabs),
              ),
            ],
          );
        },
      );
    }

    final page = _workspacePage(workspaceIndex, l10n);
    return Row(
      children: [
        Text(
          page.$2,
          key: Key('workspace-title-${page.$1}'),
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xffe0b25c)),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (workspaceIndex == 2 && onExpeditionModeChanged != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ExpeditionModeSelector(
                mode: expeditionMode,
                summaryLabel: ExpeditionStrings.of(context).modeProgress,
                checkLabel: ExpeditionStrings.of(context).modeCheck,
                onChanged: onExpeditionModeChanged!,
              ),
            ),
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
        10 => ('tools', l10n.toolbox),
        _ => ('unknown', ''),
      };

  static String _ownedInventoryTitle(AppLocalizations l10n) =>
      l10n.ownedInventory;
}

class DevelopmentWorkbenchModeTabs extends StatelessWidget {
  const DevelopmentWorkbenchModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final DevelopmentWorkbenchMode mode;
  final ValueChanged<DevelopmentWorkbenchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('development-workbench-mode-tabs'),
      width: 190,
      height: AppSegmentedStyle.regularHeight,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: [
          for (final value in DevelopmentWorkbenchMode.values)
            Expanded(
              child: Material(
                color: AppSegmentedStyle.selection(context, mode == value),
                borderRadius: AppSegmentedStyle.itemRadius(),
                child: InkWell(
                  key: Key(switch (value) {
                    DevelopmentWorkbenchMode.calculator =>
                      'development-mode-calculator',
                    DevelopmentWorkbenchMode.formula =>
                      'development-mode-formula',
                  }),
                  borderRadius: AppSegmentedStyle.itemRadius(),
                  onTap: () => onChanged(value),
                  child: Center(
                    child: Text(
                      switch (value) {
                        DevelopmentWorkbenchMode.calculator =>
                          l10n.developmentCalculator,
                        DevelopmentWorkbenchMode.formula =>
                          l10n.developmentFormula,
                      },
                      style: AppSegmentedStyle.textStyle(
                        context,
                        selected: mode == value,
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
      height: AppSegmentedStyle.regularHeight,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: [
          for (final value in ConstructionCenterMode.values)
            Expanded(
              child: Material(
                color: AppSegmentedStyle.selection(context, mode == value),
                borderRadius: AppSegmentedStyle.itemRadius(),
                child: InkWell(
                  key: Key('construction-mode-${value.name}'),
                  borderRadius: AppSegmentedStyle.itemRadius(),
                  onTap: () => onChanged(value),
                  child: Center(
                    child: Text(
                      switch (value) {
                        ConstructionCenterMode.construction =>
                          l10n.construction,
                        ConstructionCenterMode.development => l10n.development,
                        ConstructionCenterMode.improvement => l10n.improvement,
                      },
                      style: AppSegmentedStyle.textStyle(
                        context,
                        selected: mode == value,
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

class SenkaModeTabs extends StatelessWidget {
  const SenkaModeTabs({super.key, required this.mode, required this.onChanged});

  final SenkaCenterMode mode;
  final ValueChanged<SenkaCenterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('senka-mode-tabs'),
      width: 360,
      height: AppSegmentedStyle.regularHeight,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: [
          for (final value in SenkaCenterMode.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == value,
                label: senkaCenterModeLabel(l10n, value),
                excludeSemantics: true,
                child: Material(
                  key: Key('senka-tab-${value.name}'),
                  color: AppSegmentedStyle.selection(context, mode == value),
                  borderRadius: AppSegmentedStyle.itemRadius(),
                  child: InkWell(
                    borderRadius: AppSegmentedStyle.itemRadius(),
                    onTap: () => onChanged(value),
                    child: Center(
                      child: Text(
                        senkaCenterModeLabel(l10n, value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppSegmentedStyle.textStyle(
                          context,
                          selected: mode == value,
                        ),
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
      settingsOrganizationText(context, 'settingsTabRuntime'),
      l10n.settingsTabBattle,
      l10n.settingsTabNotification,
      l10n.settingsTabNetwork,
      l10n.settingsTabData,
      l10n.settingsTabAboutSupport,
    ];
    return Container(
      height: AppSegmentedStyle.regularHeight,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: _SettingsSegmentButton(
                key: Key('settings-tab-$index'),
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
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppSegmentedStyle.selection(context, selected),
    borderRadius: AppSegmentedStyle.itemRadius(),
    child: InkWell(
      onTap: onTap,
      borderRadius: AppSegmentedStyle.itemRadius(),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppSegmentedStyle.textStyle(context, selected: selected),
        ),
      ),
    ),
  );
}
