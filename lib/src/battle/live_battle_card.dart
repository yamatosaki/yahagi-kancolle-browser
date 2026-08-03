import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'battle_controller.dart';
import 'battle_models.dart';
import 'battle_pills.dart';
import '../fleet/dashboard_card.dart';
import '../fleet/ship_status_style.dart';
import '../fleet/status_density.dart';
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
                battle.context.nodeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            NodeTypePill(label: battle.context.nodeTypeLabel),
          ],
        ),
      );
    }
    final dropShipId = battle.dropShipMasterId ?? 0;
    final hasDrop = dropShipId > 0;
    final dropShipName = hasDrop
        ? (gameState.masterShips[dropShipId]?.name ?? '舰娘 $dropShipId')
        : '';
    final dropEntries = <String>[
      if (hasDrop) '掉落：$dropShipName',
      if ((battle.dropItemId ?? 0) > 0)
        '掉落：${battle.dropItemName?.trim().isNotEmpty == true ? battle.dropItemName!.trim() : '道具'}',
    ];
    final rawEnemyName = battle.enemyFleetName.isNotEmpty
        ? battle.enemyFleetName
        : '敌方舰队';
    final enemyName = battleEnemyFleetDisplayName(rawEnemyName);
    final enemyCombined =
        battle.enemyEscort.isNotEmpty || rawEnemyName.contains('联合舰队');
    final phone = isPhoneDensity(context);
    final metaChips = _compactMetaChips(battle);

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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        battle.context.nodeLabel,
                        style: const TextStyle(
                          color: Color(0xffffd65c),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          enemyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ).copyWith(
                                color: enemyCombined
                                    ? const Color(0xffff8c78)
                                    : null,
                              ),
                        ),
                      ),
                      if (!phone) ...<Widget>[
                        const SizedBox(width: 8),
                        NodeTypePill(label: battle.context.nodeTypeLabel),
                        if (battle.airSuperiority != null) ...<Widget>[
                          const SizedBox(width: 8),
                          AirSuperiorityPill(label: battle.airSuperiority!),
                        ],
                      ],
                    ],
                  ),
                  if (phone) ...<Widget>[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: <Widget>[
                        NodeTypePill(label: battle.context.nodeTypeLabel),
                        if (battle.airSuperiority != null)
                          AirSuperiorityPill(label: battle.airSuperiority!),
                        for (final chip in metaChips)
                          MetaChip(label: chip.$1, color: chip.$2),
                      ],
                    ),
                  ] else if (metaChips.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final chip in metaChips)
                          MetaChip(label: chip.$1, color: chip.$2),
                      ],
                    ),
                  ],
                  if (dropEntries.isNotEmpty) ...<Widget>[
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
        ),
        const SizedBox(height: 8),
        _CompactFleetGrid(battle: battle),
      ],
    );
  }
}

class _CompactFleetGrid extends StatelessWidget {
  const _CompactFleetGrid({required this.battle});

  final LiveBattle battle;

  @override
  Widget build(BuildContext context) {
    final friendCombined = battle.friendEscort.isNotEmpty;
    final enemyCombined = battle.enemyEscort.isNotEmpty;
    final mvpPositions = battle.mvpPositions;
    final friendFormation = battle.friendFormation > 0
        ? '（${formationLabel(battle.friendFormation)}）'
        : '';
    final enemyFormation = battle.enemyFormation > 0
        ? '（${formationLabel(battle.enemyFormation)}）'
        : '';
    final friendColumns = <Widget>[];
    final enemyColumns = <Widget>[];
    if (friendCombined) {
      friendColumns.add(
        _CompactFleetColumn(
          keyName: 'friend-main',
          ships: battle.friendMain,
          mvpPositions: mvpPositions,
        ),
      );
      friendColumns.add(
        _CompactFleetColumn(
          keyName: 'friend-escort',
          ships: battle.friendEscort,
          mvpPositions: mvpPositions,
          positionOffset: 6,
        ),
      );
    } else {
      friendColumns.add(
        _CompactFleetColumn(
          keyName: 'friend',
          ships: battle.friendMain,
          mvpPositions: mvpPositions,
        ),
      );
    }
    if (enemyCombined) {
      enemyColumns.add(
        _CompactFleetColumn(
          keyName: 'enemy-escort',
          ships: battle.enemyEscort,
          mvpPositions: const <int>[],
          positionOffset: 6,
        ),
      );
      enemyColumns.add(
        _CompactFleetColumn(
          keyName: 'enemy-main',
          ships: battle.enemyMain,
          mvpPositions: const <int>[],
        ),
      );
    } else {
      enemyColumns.add(
        _CompactFleetColumn(
          keyName: 'enemy',
          ships: battle.enemyMain,
          mvpPositions: const <int>[],
        ),
      );
    }
    final columns = <Widget>[...friendColumns, ...enemyColumns];
    return Column(
      key: const Key('compact-fleet-grid'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              flex: friendColumns.length,
              child: _CompactFleetSideTitle(
                keyName: 'friend',
                title: '我方舰队$friendFormation',
                color: const Color(0xff70c7bc),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              flex: enemyColumns.length,
              child: _CompactFleetSideTitle(
                keyName: 'enemy',
                title: '敌方舰队$enemyFormation',
                color: const Color(0xffff8c78),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < columns.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: 7),
              Expanded(child: columns[index]),
            ],
          ],
        ),
      ],
    );
  }
}

class _CompactFleetSideTitle extends StatelessWidget {
  const _CompactFleetSideTitle({
    required this.keyName,
    required this.title,
    required this.color,
  });

  final String keyName;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('compact-fleet-side-title-$keyName'),
      height: 14,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          title,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CompactFleetColumn extends StatelessWidget {
  const _CompactFleetColumn({
    required this.keyName,
    required this.ships,
    required this.mvpPositions,
    this.positionOffset = 0,
  });

  final String keyName;
  final List<BattleShipSnapshot> ships;
  final List<int> mvpPositions;
  final int positionOffset;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('compact-fleet-col-$keyName'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < ships.length; index++)
          _CompactBarRow(
            ship: ships[index],
            keyName: keyName,
            index: index,
            isMvp: mvpPositions.contains(index + positionOffset),
          ),
      ],
    );
  }
}

class _CompactBarRow extends StatelessWidget {
  const _CompactBarRow({
    required this.ship,
    required this.keyName,
    required this.index,
    required this.isMvp,
  });

  final BattleShipSnapshot ship;
  final String keyName;
  final int index;
  final bool isMvp;

  @override
  Widget build(BuildContext context) {
    final ratio = ship.maxHp <= 0
        ? 0.0
        : (ship.currentHp / ship.maxHp).clamp(0.0, 1.0);
    final hpValueColor = ship.currentHp <= 0
        ? const Color(0xff71818b)
        : shipHpValueColor(ratio);
    final hpBarColor = ship.currentHp <= 0
        ? const Color(0xff71818b)
        : shipHpBarColor(ratio);
    final hpText = ship.damageReceived > 0
        ? '${ship.currentHp} / ${ship.maxHp} (-${ship.damageReceived})'
        : '${ship.currentHp} / ${ship.maxHp}';
    return Padding(
      key: Key('compact-bar-$keyName-$index'),
      padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  hpText,
                  style: TextStyle(
                    color: hpValueColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isMvp) ...<Widget>[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.emoji_events_rounded,
                    key: Key('compact-mvp-$keyName-$index'),
                    size: 9,
                    color: const Color(0xffffd65c),
                  ),
                ],
              ],
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
    );
  }
}

List<(String, Color)> _compactMetaChips(LiveBattle battle) {
  return <(String, Color)>[
    if (battle.context.combinedFleetType != CombinedFleetType.none)
      (battle.context.combinedFleetType.label, const Color(0xff70c7bc)),
    (battle.phaseLabel, const Color(0xff9db2bf)),
    if (battle.engagement > 0)
      (
        engagementLabel(battle.engagement),
        engagementChipColor(battle.engagement),
      ),
  ];
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
