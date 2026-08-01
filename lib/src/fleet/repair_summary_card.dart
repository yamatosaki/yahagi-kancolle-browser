import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';
import 'operation_progress.dart';
import 'ship_portrait.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class RepairSummaryCard extends StatelessWidget {
  const RepairSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final docks = state.repairDocks;
        return DashboardCard(
          title: AppLocalizations.of(context)?.repairBrief ?? '入渠简报',
          icon: const Icon(Icons.build_circle_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildRepairSlot(docks.isNotEmpty ? docks[0] : null, state),
                  const SizedBox(width: 8),
                  _buildRepairSlot(docks.length > 1 ? docks[1] : null, state),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRepairSlot(docks.length > 2 ? docks[2] : null, state),
                  const SizedBox(width: 8),
                  _buildRepairSlot(docks.length > 3 ? docks[3] : null, state),
                ],
              ),
              const SizedBox(height: 2),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRepairSlot(RepairDock? dock, GameState state) {
    String name = '未知';
    bool active = false;
    bool disabled = true;
    MasterShip? master;

    if (dock != null) {
      if (dock.isLocked) {
        name = '未知';
        disabled = true;
      } else if (!dock.isRepairing) {
        name = '空闲';
        disabled = false;
      } else {
        final ship = state.ships[dock.shipId];
        master = ship != null ? state.masterShips[ship.masterId] : null;
        name = master?.name ?? '未知';
        disabled = false;
        active = true;
      }
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xff0d1a26),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (master != null) ...[
              ShipPortrait(
                ship: master,
                serverOrigin: state.serverOrigin,
                width: 96,
                height: 32,
              ),
              const SizedBox(width: 6),
            ] else ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xff142735),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Icon(
                    Icons.build_rounded,
                    size: 16,
                    color: disabled
                        ? const Color(0xff4a5c68)
                        : const Color(0xff8197a5),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: disabled
                                ? const Color(0xff4a5c68)
                                : Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (active)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xff4caf50),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (active && dock != null)
                    OperationCountdownText(
                      completionTime: dock.completionTime,
                      completedText: '已完成',
                      completedColor: const Color(0xff4caf50),
                      countingColor: const Color(0xffd4a85f),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    )
                  else ...[
                    const SizedBox(height: 2),
                    Text(
                      disabled ? '锁' : '闲置',
                      style: TextStyle(
                        fontSize: 11,
                        color: disabled
                            ? const Color(0xff4a5c68)
                            : const Color(0xff8197a5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
