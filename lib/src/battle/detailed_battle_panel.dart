import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'battle_models.dart';

class DetailedBattlePanel extends StatelessWidget {
  const DetailedBattlePanel({
    super.key,
    required this.battle,
    required this.gameState,
  });

  final LiveBattle battle;
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final navigation = battle.displayStage == BattleDisplayStage.navigation;
    return Column(
      key: const Key('detailed-battle-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (navigation)
          _NavigationOverview(context: battle.context)
        else
          _BattleOverview(battle: battle),
        if (battle.displayStage == BattleDisplayStage.result)
          _DropResult(battle: battle, gameState: gameState),
        const SizedBox(height: 9),
        if (navigation)
          if (battle.friendEscort.isEmpty)
            _FleetGroup(
              title: '我方舰队',
              ships: battle.friendMain,
              mvpPositions: battle.mvpPositions,
            )
          else
            _FleetColumn(
              mainTitle: '我方主力',
              mainShips: battle.friendMain,
              escortTitle: '我方随伴',
              escortShips: battle.friendEscort,
              mvpPositions: battle.mvpPositions,
            )
        else
          Row(
            key: const Key('battle-side-by-side-fleets'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FleetColumn(
                  mainTitle: '我方主力',
                  mainShips: battle.friendMain,
                  escortTitle: '我方随伴',
                  escortShips: battle.friendEscort,
                  mvpPositions: battle.mvpPositions,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _FleetColumn(
                  mainTitle: '敌方主力',
                  mainShips: battle.enemyMain,
                  escortTitle: '敌方护卫',
                  escortShips: battle.enemyEscort,
                  mvpPositions: const <int>[],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _FleetColumn extends StatelessWidget {
  const _FleetColumn({
    required this.mainTitle,
    required this.mainShips,
    required this.escortTitle,
    required this.escortShips,
    required this.mvpPositions,
  });

  final String mainTitle;
  final List<BattleShipSnapshot> mainShips;
  final String escortTitle;
  final List<BattleShipSnapshot> escortShips;
  final List<int> mvpPositions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FleetGroup(
          title: mainTitle,
          ships: mainShips,
          mvpPositions: mvpPositions,
        ),
        if (escortShips.isNotEmpty) ...[
          const SizedBox(height: 7),
          _FleetGroup(
            title: escortTitle,
            ships: escortShips,
            mvpPositions: mvpPositions,
            positionOffset: 6,
          ),
        ],
      ],
    );
  }
}

class _NavigationOverview extends StatelessWidget {
  const _NavigationOverview({required this.context});

  final BattleContext context;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xff10212e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.explore_outlined,
            size: 21,
            color: Color(0xff70c7bc),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${this.context.mapLabel} · ${this.context.nodeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                const Text(
                  '舰队正在前往目标节点',
                  style: TextStyle(color: Color(0xff8197a5), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              if (this.context.combinedFleetType != CombinedFleetType.none)
                _MetaChip(
                  label: this.context.combinedFleetType.label,
                  color: const Color(0xff70c7bc),
                ),
              _MetaChip(
                label: this.context.nodeTypeLabel,
                color: const Color(0xffd4a85f),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BattleOverview extends StatelessWidget {
  const _BattleOverview({required this.battle});

  final LiveBattle battle;

  @override
  Widget build(BuildContext context) {
    final enemyName = battle.enemyFleetName.isEmpty
        ? '${battle.context.mapLabel} · ${battle.context.nodeLabel}'
        : battle.enemyFleetName;
    final details = <String>[
      if (battle.context.combinedFleetType != CombinedFleetType.none)
        battle.context.combinedFleetType.label,
      battle.phaseLabel,
      if (battle.friendFormation > 0) _formationLabel(battle.friendFormation),
      if (battle.enemyFormation > 0)
        '敌 ${_formationLabel(battle.enemyFormation)}',
      if (battle.engagement > 0) _engagementLabel(battle.engagement),
    ];
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xff243343),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xffd4a85f)),
          ),
          child: Text(
            battle.rank.label,
            style: const TextStyle(
              color: Color(0xffffd65c),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                enemyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                details.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xff8fa6b4), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropResult extends StatelessWidget {
  const _DropResult({required this.battle, required this.gameState});

  final LiveBattle battle;
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final entries = <String>[
      if ((battle.dropShipMasterId ?? 0) > 0)
        '掉落：${gameState.masterShips[battle.dropShipMasterId]?.name ?? '舰娘 ${battle.dropShipMasterId}'}',
      if ((battle.dropItemId ?? 0) > 0) '道具 ${battle.dropItemId}',
    ];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('battle-drop-result'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xff18362f),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xff2f7469)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final entry in entries)
            Text(
              entry,
              style: const TextStyle(
                color: Color(0xff83d5c8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _FleetGroup extends StatelessWidget {
  const _FleetGroup({
    required this.title,
    required this.ships,
    required this.mvpPositions,
    this.positionOffset = 0,
  });

  final String title;
  final List<BattleShipSnapshot> ships;
  final List<int> mvpPositions;
  final int positionOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff10212e),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 5),
            child: Text(
              title,
              style: TextStyle(
                color: title.startsWith('敌')
                    ? const Color(0xffff8c78)
                    : const Color(0xff70c7bc),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (var index = 0; index < ships.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Color(0xff203746)),
            _BattleShipRow(
              ship: ships[index],
              absolutePosition: index + positionOffset,
              isMvp: mvpPositions.contains(index + positionOffset),
            ),
          ],
        ],
      ),
    );
  }
}

class _BattleShipRow extends StatelessWidget {
  const _BattleShipRow({
    required this.ship,
    required this.absolutePosition,
    required this.isMvp,
  });

  final BattleShipSnapshot ship;
  final int absolutePosition;
  final bool isMvp;

  @override
  Widget build(BuildContext context) {
    final side = ship.side == BattleSide.friend ? 'friend' : 'enemy';
    final hpColor = _hpColor(ship);
    final ratio = ship.maxHp <= 0
        ? 0.0
        : (ship.currentHp / ship.maxHp).clamp(0.0, 1.0);
    return Padding(
      key: Key('battle-ship-$side-$absolutePosition'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 170;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ship.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isMvp) ...[
                    Icon(
                      Icons.emoji_events_rounded,
                      key: Key('battle-mvp-$side-$absolutePosition'),
                      size: 15,
                      color: const Color(0xffffd65c),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    '伤害 ${ship.damageDealt}',
                    style: const TextStyle(
                      color: Color(0xff9db2bf),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: narrow ? 42 : 48,
                    child: Text(
                      '${ship.currentHp} / ${ship.maxHp}',
                      style: TextStyle(
                        color: hpColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: ratio,
                        color: hpColor,
                        backgroundColor: const Color(0xff263e4d),
                      ),
                    ),
                  ),
                  if (!narrow && ship.side == BattleSide.friend) ...[
                    const SizedBox(width: 7),
                    _FatigueLabel(condition: ship.condition),
                  ],
                ],
              ),
              if (narrow && ship.side == BattleSide.friend) ...[
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: _FatigueLabel(condition: ship.condition),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FatigueLabel extends StatelessWidget {
  const _FatigueLabel({required this.condition});

  final int condition;

  @override
  Widget build(BuildContext context) {
    return Text(
      '疲劳 $condition',
      style: const TextStyle(color: Color(0xff8197a5), fontSize: 9),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _hpColor(BattleShipSnapshot ship) {
  if (ship.currentHp <= 0) {
    return const Color(0xff71818b);
  }
  if (ship.currentHp * 4 <= ship.maxHp) {
    return const Color(0xffff6f68);
  }
  if (ship.currentHp * 2 <= ship.maxHp) {
    return const Color(0xffffc95c);
  }
  return const Color(0xff6fd3a9);
}

String _formationLabel(int value) =>
    const <int, String>{
      1: '单纵阵',
      2: '复纵阵',
      3: '轮形阵',
      4: '梯形阵',
      5: '单横阵',
      6: '警戒阵',
      11: '第一警戒',
      12: '第二警戒',
      13: '第三警戒',
      14: '第四警戒',
    }[value] ??
    '阵型 $value';

String _engagementLabel(int value) =>
    const <int, String>{1: '同航战', 2: '反航战', 3: 'T 字有利', 4: 'T 字不利'}[value] ??
    '航向 $value';
