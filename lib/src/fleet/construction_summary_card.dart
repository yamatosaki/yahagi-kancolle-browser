import 'package:flutter/material.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import 'dashboard_card.dart';
import '../settings/module_display_settings.dart';
import 'fleet_ui_strings.dart';
import 'operation_progress.dart';
import 'ship_portrait.dart';

import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class ConstructionSummaryCard extends StatelessWidget {
  const ConstructionSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenConstruction,
    this.visible = const {'portrait', 'empty'},
    this.onOpenDisplaySettings,
  });

  final Set<String> visible;
  final VoidCallback? onOpenDisplaySettings;
  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenConstruction;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final docks = state.constructionDocks;
        return DashboardCard(
          headerAction: moduleDisplayGear(
            context,
            'construction',
            onOpenDisplaySettings,
          ),
          title: AppLocalizations.of(context)?.constructionBrief ?? '建造简报',
          icon: const Icon(Icons.handyman_outlined),
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          child: ModuleSlotGrid(
            emptyLabel: '暂无建造',
            children: [
              for (var i = 0; i < 4; i++)
                if (visible.contains('empty') ||
                    (docks.length > i && docks[i].isBuilding))
                  _buildConstructionSlot(
                    docks.length > i ? docks[i] : null,
                    state,
                    i + 1,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConstructionSlot(
    ConstructionDock? dock,
    GameState state,
    int position,
  ) {
    String name = '未知';
    bool active = false;
    bool disabled = true;
    MasterShip? master;

    if (dock != null) {
      if (dock.isLocked) {
        name = '未知';
        disabled = true;
      } else if (!dock.isBuilding) {
        name = '空闲';
        disabled = false;
      } else {
        master = state.masterShips[dock.createdShipMasterId];
        name = master?.name ?? '建中';
        disabled = false;
        active = true;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final inline =
            !visible.contains('portrait') && constraints.maxWidth >= 180;
        final available = constraints.maxWidth - 18;
        final portraitWidth = available >= 138
            ? 96.0
            : (available - 42).clamp(32.0, 96.0).toDouble();
        final iconWidth = portraitWidth < 32 ? portraitWidth : 32.0;
        final completed =
            active &&
            dock != null &&
            dock.isCompletedAt(DateTime.now().toUtc());
        final statusDotColor = completed
            ? const Color(0xff4caf50)
            : const Color(0xffffc940);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenConstruction,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xff0d1a26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  if (visible.contains('portrait')) ...[
                    if (master != null) ...[
                      ShipPortrait(
                        ship: master,
                        serverOrigin: state.serverOrigin,
                        width: portraitWidth,
                        height: 32,
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      Container(
                        width: iconWidth,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xff142735),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.handyman_rounded,
                            size: 16,
                            color: disabled
                                ? const Color(0xff4a5c68)
                                : const Color(0xff8197a5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                  Expanded(
                    child: Flex(
                      direction: inline ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: inline
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _constructionTextPart(
                          !inline,
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${visible.contains('empty') ? '' : '$position · '}${master == null ? fleetText(context, name) : name}',
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
                                  decoration: BoxDecoration(
                                    color: statusDotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (inline) const SizedBox(width: 6),
                        if (active && dock != null)
                          _constructionTextPart(
                            !inline,
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: OperationCountdownText(
                                completionTime: dock.completionTime,
                                completedText: fleetText(context, '已完成'),
                                completedColor: const Color(0xff4caf50),
                                countingColor: const Color(0xffd4a85f),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 2),
                          Text(
                            fleetText(context, disabled ? '锁' : '闲置'),
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
          ),
        );
      },
    );
  }
}

Widget _constructionTextPart(bool portrait, Widget child) =>
    portrait ? child : Expanded(child: child);
