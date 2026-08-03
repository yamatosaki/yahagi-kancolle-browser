import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import 'dashboard_card.dart';
import 'operation_progress.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

const _expeditionSummaryTextStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
);

class ExpeditionSummaryCard extends StatelessWidget {
  const ExpeditionSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenExpedition,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenExpedition;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final activeFleets = state.fleets
            .where((f) => f.mission.isActive)
            .toList();

        return DashboardCard(
          title: AppLocalizations.of(context)?.expeditionBrief ?? '远征简报',
          icon: const Icon(Icons.explore_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeFleets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text(
                      '没有正在进行的远征',
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
          ),
        );
      },
    );
  }

  Widget _buildExpeditionItem(String fleet, String mission, Widget time) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenExpedition,
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
