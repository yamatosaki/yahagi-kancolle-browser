import '../theme/app_palette.dart';
import '../localization/game_name_localizations.dart';
import 'package:flutter/material.dart';

import 'battle_ui_text.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/ship_status_style.dart';
import '../fleet/equipment_type_icon.dart';
import '../fleet/ship_status_visuals.dart';
import '../fleet/status_density.dart';
import '../game_state/game_state.dart';
import '../layout/flat_style.dart';
import '../layout/panel_style.dart';
import '../settings/battle_prediction_settings.dart';
import '../settings/battle_status_effect_settings.dart';
import 'battle_fleet_block.dart';
import 'battle_models.dart';
import 'battle_pills.dart';
import 'battle_prediction_sections.dart';
import 'battle_ship_details_popover.dart';
import 'land_base_raid_panel.dart';
import 'official_enemy_preview.dart';
import 'prophet_hp_bar.dart';

class DetailedBattlePanel extends StatelessWidget {
  const DetailedBattlePanel({
    super.key,
    required this.battle,
    required this.gameState,
    this.latestGameState,
    this.damagePulseMode = DamagePulseFilter.all,
    this.showEnemyPortraits = true,
    this.showLastFormationHint = true,
    this.enemyPreviewPosition = EnemyPreviewPosition.above,
    this.sectionOrder,
    this.mapSection,
  });

  final LiveBattle battle;
  final GameState gameState;
  final GameState Function()? latestGameState;
  final DamagePulseFilter damagePulseMode;
  final bool showEnemyPortraits;
  final bool showLastFormationHint;
  final EnemyPreviewPosition enemyPreviewPosition;
  final List<BattlePredictionSection>? sectionOrder;
  final Widget? mapSection;

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
    final navigation = battle.displayStage == BattleDisplayStage.navigation;
    final enemyPreviewShips =
        battle.enemyPreviewShips ?? const <EnemyPreviewShip>[];
    final enemyPreview = OfficialEnemyPreview(
      ships: enemyPreviewShips,
      combined: battle.enemyPreviewCombined,
      showPortraits: showEnemyPortraits,
      masterShips: gameState.masterShips,
      serverOrigin: gameState.serverOrigin,
    );
    final friendlyFleets = NavigationFriendlyFleets(
      battle: battle,
      damagePulseMode: damagePulseMode,
    );
    final friendMainTitle = battle.friendFormation > 0
        ? '我方主力（${formationLabel(battle.friendFormation)}）'
        : '我方主力';
    final enemyMainTitle = battle.enemyFormation > 0
        ? '敌方主力（${formationLabel(battle.enemyFormation)}）'
        : '敌方主力';
    return BattleShipDetailsHost(
      battle: battle,
      latestGameState: latestGameState,
      child: Column(
        key: const Key('detailed-battle-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (navigation) ...[
            _NavigationOverview(
              battle: battle,
              showLastFormationHint: showLastFormationHint,
            ),
            SizedBox(height: flat ? flatSectionGap : 7),
          ],
          BattlePredictionSections(
            order: sectionOrder,
            legacyEnemyPreviewPosition: enemyPreviewPosition,
            sortieMap: mapSection,
            enemyPreview: navigation && enemyPreviewShips.isNotEmpty
                ? enemyPreview
                : null,
            predictionResult: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (navigation) ...[
                  if (battle.landBaseRaid case final raid?) ...[
                    LandBaseRaidPanel(result: raid),
                    const SizedBox(height: 9),
                  ],
                  friendlyFleets,
                ] else ...[
                  _BattleOverview(battle: battle, gameState: gameState),
                  const SizedBox(height: 9),
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
              ],
            ),
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
    if (PanelStyleScope.isFlat(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: FlatNavigationHeader(
          battle: battle,
          showLastFormationHint: showLastFormationHint,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: appColor(context, const Color(0xff10212e)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.explore_outlined,
            size: 21,
            color: appColor(context, Color(0xff70c7bc)),
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
              children: navigationHeaderPills(
                battle,
                showLastFormationHint: showLastFormationHint,
              ),
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
    final enemyName = rawEnemyName;
    final enemyCombined =
        battle.enemyEscort.isNotEmpty || rawEnemyName.contains('联合舰队');
    final details = <(String, Color)>[
      if (battle.context.combinedFleetType != CombinedFleetType.none)
        (battle.context.combinedFleetType.label, const Color(0xff70c7bc)),
      if (!battle.context.nodeTypeLabels.contains(battle.phaseLabel))
        (battle.phaseLabel, battlePhaseChipColor(battle.phaseLabel)),
      if (battle.engagement > 0)
        (
          engagementLabel(battle.engagement),
          engagementChipColor(battle.engagement),
        ),
    ];
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final dropShipNames = <String>[
      for (final id in battle.effectiveDropShipMasterIds)
        gameNames(
          context,
        ).shipName(gameState.masterShips[id]?.name ?? 'ID: $id', shipId: id),
    ];
    final dropShipName = dropShipNames.isEmpty
        ? null
        : l10n.dropLabel(dropShipNames.join('、'));
    final dropEntries = <String>[?dropShipName];
    final statusPills = <Widget>[
      for (final label in battle.context.nodeTypeLabels)
        NodeTypePill(label: label),
      if (battle.airSuperiority != null)
        AirSuperiorityPill(label: battle.airSuperiority!),
      for (final detail in details)
        MetaChip(label: detail.$1, color: detail.$2),
      for (final entry in dropEntries) DropPill(text: entry),
    ];
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
                enemyNameIsFallback: battle.enemyFleetName.isEmpty,
                enemyStyle: TextStyle(
                  color: appColor(
                    context,
                    enemyCombined ? const Color(0xffff8c78) : null,
                  ),
                  fontSize: phone ? 13 : null,
                  fontWeight: phone ? FontWeight.w600 : FontWeight.w800,
                ),
              ),
              if (statusPills.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Wrap(spacing: 4, runSpacing: 4, children: statusPills),
              ],
              if (battle.rewardItems.isNotEmpty) ...<Widget>[
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
            showDamageControlUsed: false,
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
                  showDamageControlUsed: false,
                  title: '我方主力',
                  ships: battle.friendMain,
                  mvpPositions: battle.mvpPositions,
                  damagePulseMode: damagePulseMode,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _FleetGroup(
                  showDamageControlUsed: false,
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
    this.showDamageControlUsed = true,
  });

  final String title;
  final List<BattleShipSnapshot> ships;
  final List<int> mvpPositions;
  final DamagePulseFilter damagePulseMode;
  final int positionOffset;
  final bool showDamageControlUsed;

  @override
  Widget build(BuildContext context) {
    return BattleFleetBlock(
      title: BattleUiText(
        title,
        style: battleFleetTitleStyle.copyWith(
          color: title.startsWith('敌')
              ? const Color(0xffff8c78)
              : const Color(0xff70c7bc),
        ),
      ),
      rows: [
        for (var index = 0; index < ships.length; index++)
          BattleShipDetailsTap(
            ship: ships[index],
            child: _BattleShipRow(
              showDamageControlUsed: showDamageControlUsed,
              ship: ships[index],
              absolutePosition: index + positionOffset,
              isMvp: mvpPositions.contains(index + positionOffset),
              damagePulseMode: damagePulseMode,
            ),
          ),
      ],
    );
  }
}

class _BattleShipRow extends StatelessWidget {
  const _BattleShipRow({
    required this.showDamageControlUsed,
    required this.ship,
    required this.absolutePosition,
    required this.isMvp,
    required this.damagePulseMode,
  });

  final bool showDamageControlUsed;
  final BattleShipSnapshot ship;
  final int absolutePosition;
  final bool isMvp;
  final DamagePulseFilter damagePulseMode;

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
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
        return Align(
          alignment: Alignment.centerLeft,
          child: BattleUiText(
            '退避',
            style: appTextStyle(
              context,
              TextStyle(
                color: Color(0xff8197a5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
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
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: hpValueColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            ProphetHpBar(
              value: ratio,
              color: appColor(context, hpBarColor),
              backgroundColor: appColor(context, const Color(0xff263e4d)),
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
          padding: flat
              ? const EdgeInsets.symmetric(vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: _BattleShipName(
                  ship: ship,
                  showDamageControlUsed: showDamageControlUsed,
                  isMvp: isMvp,
                  absolutePosition: absolutePosition,
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
            child: ColoredBox(color: appColor(context, spec.color)),
          ),
        );
      },
    );
  }
}

class _BattleShipName extends StatelessWidget {
  const _BattleShipName({
    required this.ship,
    required this.showDamageControlUsed,
    required this.isMvp,
    required this.absolutePosition,
  });

  final BattleShipSnapshot ship;
  final bool showDamageControlUsed;
  final bool isMvp;
  final int absolutePosition;

  @override
  Widget build(BuildContext context) {
    final name = gameNames(context).shipName(ship.name, shipId: ship.masterId);
    final damageControls =
        showDamageControlUsed && ship.side == BattleSide.friend
        ? ship.damageControlUsedThisBattle
              .where((id) => id == 42 || id == 43)
              .toList()
        : const <int>[];
    final side = ship.side == BattleSide.friend ? 'friend' : 'enemy';
    final markers = <Widget>[
      for (var index = 0; index < damageControls.length; index++)
        EquipmentTypeIconImage(
          key: ValueKey('battle-damage-control-$side-$absolutePosition-$index'),
          iconId: 14,
          width: 16,
          height: 16,
        ),
      if (isMvp)
        Icon(
          Icons.emoji_events_rounded,
          key: Key('battle-mvp-$side-$absolutePosition'),
          size: 13,
          color: appColor(context, const Color(0xffffd65c)),
        ),
    ];
    final label = Tooltip(
      message: name,
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: appTextStyle(
          context,
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ship.isEscaped ? const Color(0xff8197a5) : null,
          ),
        ),
      ),
    );
    if (markers.isEmpty) return label;
    final gap = damageControls.isEmpty ? 2.0 : 4.0;
    final markerWidth =
        damageControls.length * 16 +
        (isMvp ? 13 : 0) +
        (markers.length - 1) * 4;
    return LayoutBuilder(
      builder: (context, constraints) {
        final icons = Wrap(spacing: 4, runSpacing: 2, children: markers);
        if (markerWidth + gap > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [label, const SizedBox(height: 2), icons],
          );
        }
        return Row(
          children: [
            Flexible(child: label),
            SizedBox(width: gap),
            icons,
          ],
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
