import 'package:flutter/material.dart';

import '../fleet/ship_status_style.dart';
import '../fleet/status_density.dart';
import '../game_state/game_state.dart';
import 'battle_models.dart';
import 'battle_pills.dart';

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
    final friendMainTitle = battle.friendFormation > 0
        ? '我方主力（${formationLabel(battle.friendFormation)}）'
        : '我方主力';
    final enemyMainTitle = battle.enemyFormation > 0
        ? '敌方主力（${formationLabel(battle.enemyFormation)}）'
        : '敌方主力';
    return Column(
      key: const Key('detailed-battle-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (navigation)
          _NavigationOverview(context: battle.context)
        else
          _BattleOverview(battle: battle, gameState: gameState),
        if (battle.displayStage == BattleDisplayStage.result &&
            !isPhoneDensity(context))
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
            Row(
              key: const Key('navigation-combined-fleets'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _FleetGroup(
                    title: '我方主力',
                    ships: battle.friendMain,
                    mvpPositions: battle.mvpPositions,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _FleetGroup(
                    title: '我方随伴',
                    ships: battle.friendEscort,
                    mvpPositions: battle.mvpPositions,
                    positionOffset: 6,
                  ),
                ),
              ],
            )
        else
          Row(
            key: const Key('battle-side-by-side-fleets'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FleetColumn(
                  mainTitle: friendMainTitle,
                  mainShips: battle.friendMain,
                  escortTitle: '我方随伴',
                  escortShips: battle.friendEscort,
                  mvpPositions: battle.mvpPositions,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _FleetColumn(
                  mainTitle: enemyMainTitle,
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
                  this.context.nodeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
                MetaChip(
                  label: this.context.combinedFleetType.label,
                  color: const Color(0xff70c7bc),
                ),
              NodeTypePill(label: this.context.nodeTypeLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _BattleOverview extends StatelessWidget {
  const _BattleOverview({required this.battle, required this.gameState});

  final LiveBattle battle;
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneDensity(context);
    final rawEnemyName = battle.enemyFleetName.isEmpty
        ? '敌方舰队'
        : battle.enemyFleetName;
    final enemyName = battleEnemyFleetDisplayName(rawEnemyName);
    final enemyCombined =
        battle.enemyEscort.isNotEmpty || rawEnemyName.contains('联合舰队');
    final details = <(String, Color)>[
      if (battle.context.combinedFleetType != CombinedFleetType.none)
        (battle.context.combinedFleetType.label, const Color(0xff70c7bc)),
      (battle.phaseLabel, battlePhaseChipColor(battle.phaseLabel)),
      if (battle.engagement > 0)
        (
          engagementLabel(battle.engagement),
          engagementChipColor(battle.engagement),
        ),
    ];
    final statusPills = <Widget>[
      NodeTypePill(label: battle.context.nodeTypeLabel),
      if (battle.airSuperiority != null)
        AirSuperiorityPill(label: battle.airSuperiority!),
      for (final detail in details)
        MetaChip(label: detail.$1, color: detail.$2),
    ];
    final dropShipId = battle.dropShipMasterId ?? 0;
    final dropShipName = dropShipId > 0
        ? '掉落：${gameState.masterShips[dropShipId]?.name ?? '舰娘 $dropShipId'}'
        : null;
    final dropEntries = <String>[
      ?dropShipName,
      if ((battle.dropItemId ?? 0) > 0)
        '掉落：${battle.dropItemName?.trim().isNotEmpty == true ? battle.dropItemName!.trim() : '道具'}',
    ];
    return Row(
      children: [
        if (battle.status == LiveBattleStatus.confirmed) ...<Widget>[
          BattleRankBadge(
            rank: battle.rank,
            size: phone ? 50 : 48,
            fontSize: phone ? 21 : 20,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdaptiveBattleHeader(
                nodeLabel: battle.context.nodeLabel,
                enemyName: enemyName,
                enemyStyle: TextStyle(
                  color: enemyCombined ? const Color(0xffff8c78) : null,
                  fontSize: phone ? 13 : null,
                  fontWeight: phone ? FontWeight.w600 : FontWeight.w800,
                ),
              ),
              if (statusPills.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Wrap(spacing: 4, runSpacing: 4, children: statusPills),
              ],
              if (phone && dropEntries.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final entry in dropEntries) DropPill(text: entry),
                  ],
                ),
              ],
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
      if ((battle.dropItemId ?? 0) > 0)
        '掉落：${battle.dropItemName?.trim().isNotEmpty == true ? battle.dropItemName!.trim() : '道具'}',
    ];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('battle-drop-result'),
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: <Widget>[for (final entry in entries) DropPill(text: entry)],
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
    final ratio = ship.maxHp <= 0
        ? 0.0
        : (ship.currentHp / ship.maxHp).clamp(0.0, 1.0);
    final isZeroHp = ship.currentHp <= 0;
    final hpValueColor = shipHpValueColor(ratio, isZeroHp: isZeroHp);
    final hpBarColor = shipHpBarColor(ratio, isZeroHp: isZeroHp);
    return Padding(
      key: Key('battle-ship-$side-$absolutePosition'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Tooltip(
                    message: ship.name,
                    child: Text(
                      ship.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (isMvp) ...<Widget>[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.emoji_events_rounded,
                    key: Key('battle-mvp-$side-$absolutePosition'),
                    size: 13,
                    color: const Color(0xffffd65c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    ship.damageReceived > 0
                        ? '${ship.currentHp} / ${ship.maxHp} (-${ship.damageReceived})'
                        : '${ship.currentHp} / ${ship.maxHp}',
                    style: TextStyle(
                      color: hpValueColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: ratio,
                    color: hpBarColor,
                    backgroundColor: const Color(0xff263e4d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Engagement colors: ordinary engagements yellow, T outcomes semantic.
Color engagementChipColor(int value) {
  if (value == 3) return const Color(0xff6fd3a9);
  if (value == 4) return const Color(0xffff6f68);
  if (value == 1 || value == 2) return const Color(0xffffc95c);
  return const Color(0xff9db2bf);
}
