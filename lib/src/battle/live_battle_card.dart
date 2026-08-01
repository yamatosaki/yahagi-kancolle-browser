import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'battle_controller.dart';
import 'battle_models.dart';
import '../fleet/dashboard_card.dart';
import '../game_state/game_state.dart';
import 'detailed_battle_panel.dart';

enum BattlePanelMode { compact, detailed }

class LiveBattleCard extends StatefulWidget {
  const LiveBattleCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  final BattleController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  @override
  State<LiveBattleCard> createState() => _LiveBattleCardState();
}

class _LiveBattleCardState extends State<LiveBattleCard> {
  BattlePanelMode _mode = BattlePanelMode.detailed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final battle = widget.controller.current;
        final idle = battle == null || battle.friendShips.isEmpty;
        return DashboardCard(
          key: const Key('live-battle-card'),
          title: AppLocalizations.of(context)?.forecast ?? '未卜先知',
          icon: const Icon(Icons.remove_red_eye_outlined),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
          titleBadge: idle ? const _IdleBadge() : _StatusBadge(battle: battle),
          trailing: _ModeSwitch(
            mode: _mode,
            onChanged: (mode) {
              setState(() {
                _mode = mode;
              });
            },
          ),
          borderColor: idle
              ? const Color(0xff294052)
              : battle.status == LiveBattleStatus.forecast
              ? const Color(0xff8b6a2b)
              : const Color(0xff2f7469),
          child: Column(
            key: widget.collapsed
                ? const Key('live-battle-collapsed')
                : const Key('live-battle-expanded'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (idle)
                const _IdleBattleContent()
              else if (_mode == BattlePanelMode.detailed)
                DetailedBattlePanel(
                  battle: battle,
                  gameState: widget.controller.gameStateSnapshot,
                )
              else
                _CompactBattlePanel(
                  battle: battle,
                  gameState: widget.controller.gameStateSnapshot,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final BattlePanelMode mode;
  final ValueChanged<BattlePanelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xff10212e),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xff294052)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            key: const Key('battle-mode-compact'),
            label: AppLocalizations.of(context)?.compact ?? '紧凑',
            selected: mode == BattlePanelMode.compact,
            onTap: () => onChanged(BattlePanelMode.compact),
          ),
          _ModeButton(
            key: const Key('battle-mode-detailed'),
            label: AppLocalizations.of(context)?.detailed ?? '完整',
            selected: mode == BattlePanelMode.detailed,
            onTap: () => onChanged(BattlePanelMode.detailed),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xff5b4829) : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Padding(
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
        ),
      ),
    );
  }
}

class _CompactBattlePanel extends StatelessWidget {
  const _CompactBattlePanel({required this.battle, required this.gameState});

  final LiveBattle battle;
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final navigation = battle.displayStage == BattleDisplayStage.navigation;
    if (navigation) {
      return Container(
        key: const Key('compact-battle-panel'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff10212e),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.explore_outlined,
              size: 18,
              color: Color(0xff70c7bc),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${battle.context.mapLabel} · ${battle.context.nodeLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              battle.context.nodeTypeLabel,
              style: const TextStyle(
                color: Color(0xffd4a85f),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    final dropShipName =
        battle.dropShipMasterId != null && battle.dropShipMasterId! > 0
        ? (gameState.masterShips[battle.dropShipMasterId]?.name ?? '未知')
        : '未知';

    return Column(
      key: const Key('compact-battle-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _RankBadge(rank: battle.rank),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${battle.context.mapLabel} · ${battle.context.nodeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (battle.airSuperiority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff294052),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '制空: ${battle.airSuperiority}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xff9db2bf),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    battle.enemyFleetName.isNotEmpty
                        ? battle.enemyFleetName
                        : '敌方舰队',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffd4a85f),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    battle.status == LiveBattleStatus.forecast
                        ? '掉落预测: $dropShipName'
                        : '掉落: $dropShipName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff8197a5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            _FleetSummary(
              label: '我方',
              ships: battle.friendShips,
              color: const Color(0xff70c7bc),
            ),
            const SizedBox(width: 8),
            _FleetSummary(
              label: '敌方',
              ships: battle.enemyShips,
              color: const Color(0xffff8c78),
            ),
          ],
        ),
      ],
    );
  }
}

class _IdleBadge extends StatelessWidget {
  const _IdleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xff203443),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppLocalizations.of(context)?.standby ?? '待机',
        style: TextStyle(
          color: Color(0xff9db2bf),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IdleBattleContent extends StatelessWidget {
  const _IdleBattleContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xff10212e),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.explore_outlined,
            size: 18,
            color: Color(0xff70c7bc),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)?.waitingForSortieData ?? '等待出击数据',
              style: const TextStyle(
                color: Color(0xff9db2bf),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.battle});

  final LiveBattle battle;

  @override
  Widget build(BuildContext context) {
    final navigation = battle.displayStage == BattleDisplayStage.navigation;
    final forecast = battle.status == LiveBattleStatus.forecast;
    final label = navigation
        ? '航向'
        : forecast
        ? '预判'
        : '已确认';
    final foreground = navigation
        ? const Color(0xff70c7bc)
        : forecast
        ? const Color(0xffffc95c)
        : const Color(0xff83d5c8);
    final background = navigation
        ? const Color(0xff18343c)
        : forecast
        ? const Color(0xff4a3b21)
        : const Color(0xff183e38);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final BattleRank rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xff243343),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xffd4a85f)),
      ),
      child: Text(
        rank.label,
        style: const TextStyle(
          color: Color(0xffffd65c),
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FleetSummary extends StatelessWidget {
  const _FleetSummary({
    required this.label,
    required this.ships,
    required this.color,
  });

  final String label;
  final List<BattleShipSnapshot> ships;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final alive = ships.where((ship) => !ship.isSunk).length;
    final critical = ships.where((ship) => ship.isHeavilyDamaged).length;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xff10212e),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Text(
              '$label $alive/${ships.length}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (critical > 0)
              Text(
                '大破 $critical',
                style: const TextStyle(color: Color(0xffff8c78), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
