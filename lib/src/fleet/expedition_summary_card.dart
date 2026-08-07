import 'package:flutter/material.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'dashboard_card.dart';
import 'operation_progress.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import '../expedition/expedition_check_card.dart';

const _expeditionSummaryTextStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
);

enum ExpeditionSummaryMode { summary, check }

class ExpeditionSummaryCard extends StatefulWidget {
  const ExpeditionSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenExpedition,
    required this.onOpenExpeditionCheck,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenExpedition;
  final ValueChanged<int> onOpenExpeditionCheck;

  @override
  State<ExpeditionSummaryCard> createState() => _ExpeditionSummaryCardState();
}

class _ExpeditionSummaryCardState extends State<ExpeditionSummaryCard> {
  ExpeditionSummaryMode _mode = ExpeditionSummaryMode.summary;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final activeFleets = state.fleets
            .where((f) => f.mission.isActive)
            .toList();

        final strings = AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));

        return DashboardCard(
          title: strings.expeditionBrief,
          icon: const Icon(Icons.explore_outlined),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
          trailing: ExpeditionModeSelector(
            mode: _mode,
            compact: true,
            summaryLabel: '简报',
            checkLabel: '检查',
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          child: _mode == ExpeditionSummaryMode.summary
              ? _buildSummaryContent(state, activeFleets, strings)
              : ExpeditionCheckContent(
                  controller: widget.controller,
                  onOpenDetails: widget.onOpenExpeditionCheck,
                ),
        );
      },
    );
  }

  Widget _buildSummaryContent(GameState state, List<Fleet> activeFleets, AppLocalizations strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeFleets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: Text(
                strings.noActiveExpedition,
                style: _expeditionSummaryTextStyle.copyWith(
                  color: const Color(0xff8197a5),
                ),
              ),
            ),
          )
        else
          ...activeFleets.map((fleet) {
            final mission = state.masterMissions[fleet.mission.missionId];
            final missionName = mission?.name ?? '未知远征';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildExpeditionItem(
                fleet.name,
                missionName,
                OperationCountdownText(
                  completionTime: fleet.mission.completionTime,
                  completedText: '已返母港',
                  style: _expeditionSummaryTextStyle,
                  countingColor: const Color(0xffd4a85f),
                ),
              ),
            );
          }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildExpeditionItem(String fleet, String mission, Widget time) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpenExpedition,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xff0d1a26),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff03a9f4).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fleet,
                  style: _expeditionSummaryTextStyle.copyWith(
                    color: const Color(0xff03a9f4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(mission, style: _expeditionSummaryTextStyle),
              ),
              time,
            ],
          ),
        ),
      ),
    );
  }
}

class ExpeditionModeSelector extends StatelessWidget {
  const ExpeditionModeSelector({
    super.key,
    required this.mode,
    required this.summaryLabel,
    required this.checkLabel,
    required this.onChanged,
    this.compact = false,
  });

  final ExpeditionSummaryMode mode;
  final String summaryLabel;
  final String checkLabel;
  final ValueChanged<ExpeditionSummaryMode> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('expedition-summary-mode-selector'),
      width: compact ? null : 260,
      height: compact ? 26 : 38,
      padding: EdgeInsets.all(compact ? 2 : 3),
      decoration: BoxDecoration(
        color: compact ? const Color(0xff10212e) : const Color(0xff0b202d),
        borderRadius: BorderRadius.circular(compact ? 7 : 20),
        border: Border.all(color: compact ? const Color(0xff294052) : const Color(0xff315064)),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          compact ? _ModeButton(
            key: const Key('expedition-mode-summary'),
            label: summaryLabel,
            compact: compact,
            selected: mode == ExpeditionSummaryMode.summary,
            onTap: () => onChanged(ExpeditionSummaryMode.summary),
          ) : Expanded(
            child: _ModeButton(
              key: const Key('expedition-mode-summary'),
              label: summaryLabel,
              compact: compact,
              selected: mode == ExpeditionSummaryMode.summary,
              onTap: () => onChanged(ExpeditionSummaryMode.summary),
            ),
          ),
          compact ? _ModeButton(
            key: const Key('expedition-mode-check'),
            label: checkLabel,
            compact: compact,
            selected: mode == ExpeditionSummaryMode.check,
            onTap: () => onChanged(ExpeditionSummaryMode.check),
          ) : Expanded(
            child: _ModeButton(
              key: const Key('expedition-mode-check'),
              label: checkLabel,
              compact: compact,
              selected: mode == ExpeditionSummaryMode.check,
              onTap: () => onChanged(ExpeditionSummaryMode.check),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? (compact ? const Color(0xff5b4829) : const Color(0xff8a6628)) : Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 5 : 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 5 : 16),
        onTap: onTap,
        child: compact
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xffffcf67)
                        : const Color(0xff8197a5),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xffffdc88)
                          : const Color(0xff9fb3bf),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

