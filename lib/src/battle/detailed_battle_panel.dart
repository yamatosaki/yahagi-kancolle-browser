import 'package:flutter/material.dart';

import 'battle_ui_text.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/ship_status_style.dart';
import '../fleet/ship_status_visuals.dart';
import '../fleet/status_density.dart';
import '../game_state/game_state.dart';
import '../settings/battle_status_effect_settings.dart';
import 'battle_models.dart';
import 'battle_pills.dart';
import 'battle_ship_details_popover.dart';
import 'land_base_raid_panel.dart';
import 'official_enemy_preview.dart';
import 'prophet_hp_bar.dart';

class DetailedBattlePanel extends StatelessWidget {
  const DetailedBattlePanel({
    super.key,
    required this.battle,
    required this.gameState,
    this.damagePulseMode = DamagePulseFilter.all,
    this.showEnemyPortraits = true,
    this.showLastFormationHint = true,
  });

  final LiveBattle battle;
  final GameState gameState;
  final DamagePulseFilter damagePulseMode;
  final bool showEnemyPortraits;
  final bool showLastFormationHint;

  @override
  Widget build(BuildContext context) {
    final navigation = battle.displayStage == BattleDisplayStage.navigation;
    final enemyPreviewShips =
        battle.enemyPreviewShips ?? const <EnemyPreviewShip>[];
    final friendMainTitle = battle.friendFormation > 0
        ? '我方主力（${formationLabel(battle.friendFormation)}）'
        : '我方主力';
    final enemyMainTitle = battle.enemyFormation > 0
        ? '敌方主力（${formationLabel(battle.enemyFormation)}）'
        : '敌方主力';
    return BattleShipDetailsHost(
      battle: battle,
      child: Column(
        key: const Key('detailed-battle-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (navigation)
            _NavigationOverview(
              battle: battle,
              showLastFormationHint: showLastFormationHint,
            )
          else
            _BattleOverview(battle: battle, gameState: gameState),
          if (navigation && enemyPreviewShips.isNotEmpty) ...[
            const SizedBox(height: 7),
            OfficialEnemyPreview(
              ships: enemyPreviewShips,
              combined: battle.enemyPreviewCombined,
              showPortraits: showEnemyPortraits,
              masterShips: gameState.masterShips,
              serverOrigin: gameState.serverOrigin,
            ),
          ],
          if (navigation && battle.landBaseRaid != null) ...[
            const SizedBox(height: 7),
            LandBaseRaidPanel(result: battle.landBaseRaid!),
          ],
          if (battle.displayStage == BattleDisplayStage.result &&
              !isPhoneDensity(context))
            _DropResult(battle: battle, gameState: gameState),
          const SizedBox(height: 9),
          if (navigation)
            NavigationFriendlyFleets(
              battle: battle,
              damagePulseMode: damagePulseMode,
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
                    damagePulseMode: damagePulseMode,
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
                    damagePulseMode: damagePulseMode,
                  ),
                ),
              ],
            ),
        ],
      ),
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
    required this.damagePulseMode,
  });

  final String mainTitle;
  final List<BattleShipSnapshot> mainShips;
  final String escortTitle;
  final List<BattleShipSnapshot> escortShips;
  final List<int> mvpPositions;
  final DamagePulseFilter damagePulseMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FleetGroup(
          title: mainTitle,
          ships: mainShips,
          mvpPositions: mvpPositions,
          damagePulseMode: damagePulseMode,
        ),
        if (escortShips.isNotEmpty) ...[
          const SizedBox(height: 7),
          _FleetGroup(
            title: escortTitle,
            ships: escortShips,
            mvpPositions: mvpPositions,
            positionOffset: 6,
            damagePulseMode: damagePulseMode,
          ),
        ],
      ],
    );
  }
}

class _NavigationOverview extends StatelessWidget {
  const _NavigationOverview({
    required this.battle,
    required this.showLastFormationHint,
  });

  final LiveBattle battle;
  final bool showLastFormationHint;

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
                BattleUiText(
                  battle.context.forecastNodeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                if (showLastFormationHint && battle.lastFormation != null)
                  LastFormationPill(formation: battle.lastFormation!),
                if (battle.context.combinedFleetType != CombinedFleetType.none)
                  MetaChip(
                    label: battle.context.combinedFleetType.label,
                    color: const Color(0xff70c7bc),
                  ),
                if (battle.resourceChanges.isNotEmpty)
                  ResourceChangesPill(changes: battle.resourceChanges),
                if (battle.rewardItems.isNotEmpty)
                  RewardItemsPill(items: battle.rewardItems),
                if (battle.resourceChanges.isEmpty &&
                    battle.rewardItems.isEmpty)
                  NodeTypePill(label: battle.context.nodeTypeLabel),
              ],
            ),
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
      if (battle.phaseLabel != battle.context.nodeTypeLabel)
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
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final dropShipNames = <String>[
      for (final id in battle.effectiveDropShipMasterIds)
        gameState.masterShips[id]?.name ?? 'ID: $id',
    ];
    final dropShipName = dropShipNames.isEmpty
        ? null
        : l10n.dropLabel(dropShipNames.join('、'));
    final dropEntries = <String>[?dropShipName];
    return Row(
      children: [
        if (battle.rank != BattleRank.unknown) ...<Widget>[
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
                nodeLabel: battle.context.forecastNodeLabel,
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
              if (phone && battle.rewardItems.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                RewardItemsPill(items: battle.rewardItems),
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
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final entries = <String>[
      if (battle.effectiveDropShipMasterIds.isNotEmpty)
        l10n.dropLabel(
          battle.effectiveDropShipMasterIds
              .map((id) => gameState.masterShips[id]?.name ?? 'ID: $id')
              .join('、'),
        ),
    ];
    if (entries.isEmpty && battle.rewardItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('battle-drop-result'),
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: <Widget>[
          for (final entry in entries) DropPill(text: entry),
          if (battle.rewardItems.isNotEmpty)
            RewardItemsPill(items: battle.rewardItems),
        ],
      ),
    );
  }
}

class NavigationFriendlyFleets extends StatelessWidget {
  const NavigationFriendlyFleets({
    super.key,
    required this.battle,
    required this.damagePulseMode,
  });

  final LiveBattle battle;
  final DamagePulseFilter damagePulseMode;

  @override
  Widget build(BuildContext context) {
    final content = battle.friendEscort.isEmpty
        ? _FleetGroup(
            title: '我方舰队',
            ships: battle.friendMain,
            mvpPositions: battle.mvpPositions,
            damagePulseMode: damagePulseMode,
          )
        : Row(
            key: const Key('navigation-combined-fleets'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _FleetGroup(
                  title: '我方主力',
                  ships: battle.friendMain,
                  mvpPositions: battle.mvpPositions,
                  damagePulseMode: damagePulseMode,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _FleetGroup(
                  title: '我方随伴',
                  ships: battle.friendEscort,
                  mvpPositions: battle.mvpPositions,
                  positionOffset: 6,
                  damagePulseMode: damagePulseMode,
                ),
              ),
            ],
          );
    return KeyedSubtree(
      key: const Key('navigation-friendly-fleets'),
      child: content,
    );
  }
}

class _FleetGroup extends StatelessWidget {
  const _FleetGroup({
    required this.title,
    required this.ships,
    required this.mvpPositions,
    required this.damagePulseMode,
    this.positionOffset = 0,
  });

  final String title;
  final List<BattleShipSnapshot> ships;
  final List<int> mvpPositions;
  final DamagePulseFilter damagePulseMode;
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
            child: BattleUiText(
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
            BattleShipDetailsTap(
              ship: ships[index],
              child: _BattleShipRow(
                ship: ships[index],
                absolutePosition: index + positionOffset,
                isMvp: mvpPositions.contains(index + positionOffset),
                damagePulseMode: damagePulseMode,
              ),
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
    required this.damagePulseMode,
  });

  final BattleShipSnapshot ship;
  final int absolutePosition;
  final bool isMvp;
  final DamagePulseFilter damagePulseMode;

  @override
  Widget build(BuildContext context) {
    final isEscaped = ship.isEscaped;
    final side = ship.side == BattleSide.friend ? 'friend' : 'enemy';
    final ratio = ship.maxHp <= 0
        ? 0.0
        : (ship.currentHp / ship.maxHp).clamp(0.0, 1.0);
    final isZeroHp = ship.currentHp <= 0;
    final hpValueColor = isEscaped
        ? yahagiStatusZeroHp
        : shipHpValueColor(ratio, isZeroHp: isZeroHp);
    final hpBarColor = isEscaped
        ? yahagiStatusZeroHp
        : shipHpBarColor(ratio, isZeroHp: isZeroHp);
    final hpText = isEscaped
        ? '${ship.currentHp} / ${ship.maxHp} (退避)'
        : (ship.damageReceived > 0
              ? '${ship.currentHp} / ${ship.maxHp} (-${ship.damageReceived})'
              : '${ship.currentHp} / ${ship.maxHp}');

    Widget hpContent({double opacity = 1, bool pulsing = false}) {
      if (isEscaped) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: BattleUiText(
            '退避',
            style: TextStyle(
              color: Color(0xff8197a5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
      return Opacity(
        key: pulsing
            ? Key('battle-damage-hp-pulse-$side-$absolutePosition')
            : null,
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hpText,
                style: TextStyle(
                  color: hpValueColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            ProphetHpBar(
              value: ratio,
              color: hpBarColor,
              backgroundColor: const Color(0xff263e4d),
            ),
          ],
        ),
      );
    }

    Widget rowContent(Widget hp, {Widget? background}) => Stack(
      children: <Widget>[
        if (background != null) Positioned.fill(child: background),
        Padding(
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isEscaped ? const Color(0xff8197a5) : null,
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
              Expanded(flex: 2, child: hp),
            ],
          ),
        ),
      ],
    );

    final shouldPulse =
        !isEscaped &&
        ship.currentHp > 0 &&
        ship.maxHp > 0 &&
        ship.currentHp * 4 <= ship.maxHp * 3;
    if (!shouldPulse) {
      return rowContent(hpContent());
    }
    return DamagePulseBuilder(
      currentHp: ship.currentHp,
      maxHp: ship.maxHp,
      filter: damagePulseMode,
      normalColor: hpBarColor,
      builder: (context, spec, phase) {
        final hpOpacity =
            spec.minFrameOpacity + phase * (1 - spec.minFrameOpacity);
        final minRowOpacity = spec.maxTintOpacity > 0
            ? spec.minTintOpacity
            : 0.035;
        final maxRowOpacity = spec.maxTintOpacity > 0
            ? spec.maxTintOpacity
            : 0.12;
        final rowOpacity =
            minRowOpacity + phase * (maxRowOpacity - minRowOpacity);
        return rowContent(
          hpContent(opacity: hpOpacity, pulsing: true),
          background: Opacity(
            key: Key('battle-damage-row-pulse-$side-$absolutePosition'),
            opacity: rowOpacity,
            child: ColoredBox(color: spec.color),
          ),
        );
      },
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
