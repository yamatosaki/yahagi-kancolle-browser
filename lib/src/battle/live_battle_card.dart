import '../widgets/app_segmented_style.dart';
import '../theme/app_palette.dart';
import '../localization/game_name_localizations.dart';
import 'package:flutter/material.dart';

import 'battle_detail_strings.dart';
import 'battle_ui_text.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import '../layout/flat_list_row.dart';
import '../layout/flat_style.dart';
import '../layout/module_summaries.dart';

import 'battle_controller.dart';
import 'battle_models.dart';
import 'battle_pills.dart';
import 'battle_prediction_sections.dart';
import 'battle_ship_details_popover.dart';
import '../fleet/dashboard_card.dart';
import '../fleet/ship_status_style.dart';
import '../fleet/ship_status_visuals.dart';
import '../fleet/status_density.dart';
import '../layout/flat_text_toggle.dart';
import '../layout/panel_style.dart';
import '../game_state/game_state.dart';
import '../settings/battle_prediction_settings.dart';
import '../settings/battle_status_effect_settings.dart';
import '../settings/module_display_settings.dart';
import 'detailed_battle_panel.dart';
import 'land_base_raid_panel.dart';
import 'official_enemy_preview.dart';
import 'prophet_hp_bar.dart';
import 'sortie_map_section.dart';

enum BattlePanelMode { compact, detailed }

class LiveBattleCard extends StatefulWidget {
  const LiveBattleCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    this.damagePulseMode = DamagePulseFilter.all,
    this.showEnemyPortraits = true,
    this.showLastFormationHint = true,
    this.enemyPreviewPosition = EnemyPreviewPosition.above,
    this.sectionOrder,
    this.visibleSections = BattlePredictionSection.values,
    this.showLogo = true,
    this.showTitle = true,
    this.onOpenDisplaySettings,
  });

  final BattleController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final DamagePulseFilter damagePulseMode;
  final bool showEnemyPortraits;
  final bool showLastFormationHint;
  final EnemyPreviewPosition enemyPreviewPosition;
  final List<BattlePredictionSection>? sectionOrder;
  final Iterable<BattlePredictionSection> visibleSections;
  final bool showLogo;
  final bool showTitle;
  final VoidCallback? onOpenDisplaySettings;

  @override
  State<LiveBattleCard> createState() => _LiveBattleCardState();
}

class _LiveBattleCardState extends State<LiveBattleCard> {
  BattlePanelMode _mode = BattlePanelMode.detailed;
  bool _modeRestored = false;
  bool _mapExpanded = true;
  bool _mapExpansionRestored = false;
  SortieMapSection? _cachedMapSection;

  static const _mapExpansionStorageId = 'prophet-sortie-map-expanded';

  @override
  void didUpdateWidget(covariant LiveBattleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _cachedMapSection = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_mapExpansionRestored) {
      final storedExpansion = PageStorage.maybeOf(
        context,
      )?.readState(context, identifier: _mapExpansionStorageId);
      if (storedExpansion is bool) _mapExpanded = storedExpansion;
      _mapExpansionRestored = true;
    }
    if (_modeRestored) return;
    final storedMode = PageStorage.maybeOf(context)?.readState(context);
    if (storedMode is String) {
      _mode = BattlePanelMode.values.firstWhere(
        (mode) => mode.name == storedMode,
        orElse: () => _mode,
      );
    }
    _modeRestored = true;
  }

  void _setMode(BattlePanelMode mode) {
    setState(() => _mode = mode);
    PageStorage.maybeOf(context)?.writeState(context, mode.name);
  }

  void _toggleMapExpanded() {
    setState(() => _mapExpanded = !_mapExpanded);
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _mapExpanded, identifier: _mapExpansionStorageId);
  }

  SortieMapSection? _buildMapSection(
    LiveBattle? battle, {
    required bool showCurrentNode,
  }) {
    // Avoid loading map geometry until the card can display it.
    if (widget.collapsed ||
        !widget.visibleSections.contains(BattlePredictionSection.sortieMap) ||
        battle?.context.practice == true) {
      _cachedMapSection = null;
      return null;
    }
    final progress = widget.controller.sortieMapProgress;
    if (progress == null) {
      _cachedMapSection = null;
      return null;
    }
    final geometry = widget.controller.sortieMapGeometry;
    final currentNodeLabel =
        battle != null &&
            battle.context.mapAreaId == progress.mapAreaId &&
            battle.context.mapInfoNo == progress.mapInfoNo &&
            battle.context.node == progress.currentRouteId
        ? battle.context.nodeDisplayLabel
        : null;
    final cached = _cachedMapSection;
    if (cached != null &&
        identical(cached.progress, progress) &&
        identical(cached.geometry, geometry) &&
        cached.currentNodeLabel == currentNodeLabel &&
        cached.showCurrentNode == showCurrentNode &&
        cached.expanded == _mapExpanded) {
      return cached;
    }
    // Reuse only the immutable widget, so its elements still receive inherited
    // locale, text scale, theme and layout updates normally.
    return _cachedMapSection = SortieMapSection(
      progress: progress,
      geometry: geometry,
      expanded: _mapExpanded,
      onToggleExpanded: _toggleMapExpanded,
      currentNodeLabel: currentNodeLabel,
      showCurrentNode: showCurrentNode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final battle = widget.controller.current;
        final idle = battle == null || battle.friendShips.isEmpty;
        // Flat battle and navigation headers already name the current node.
        final mapSection = _buildMapSection(
          battle,
          showCurrentNode: !flat || idle,
        );
        return DashboardCard(
          key: const Key('live-battle-card'),
          collapsedSummary: widget.collapsed
              ? battleSummary(BattleDetailStrings.of(context), battle)
              : null,
          title: AppLocalizations.of(context)?.forecast ?? '未卜先知',
          icon: const Icon(Icons.remove_red_eye_outlined),
          collapsed: widget.collapsed,
          onToggleCollapse: widget.onToggleCollapse,
          showLogo: widget.showLogo,
          showTitle: widget.showTitle,
          headerAction: moduleDisplayGear(
            context,
            'battle',
            widget.onOpenDisplaySettings,
          ),
          titleBadge: idle
              ? (flat ? null : const _IdleBadge())
              : _StatusBadge(battle: battle),
          trailing: _ModeSwitch(mode: _mode, onChanged: _setMode),
          child: Column(
            key: widget.collapsed
                ? const Key('live-battle-collapsed')
                : const Key('live-battle-expanded'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.controller.isPredictionConfirmed)
                Padding(
                  key: const Key('battle-unconfirmed-warning'),
                  padding: EdgeInsets.only(bottom: flat ? flatSectionGap : 8),
                  child: Text(
                    (AppLocalizations.of(context) ??
                            lookupAppLocalizations(const Locale('zh')))
                        .battlePredictionUnconfirmed,
                    style: TextStyle(
                      color: appColor(context, const Color(0xffffc95c)),
                      fontSize: flat ? flatRowFontSize : 12,
                    ),
                  ),
                ),
              if (idle) ...[
                if (mapSection != null) ...[
                  mapSection,
                  SizedBox(height: flat ? flatSectionGap : 9),
                ],
                const _IdleBattleContent(),
              ] else if (_mode == BattlePanelMode.detailed)
                DetailedBattlePanel(
                  battle: battle,
                  gameState: widget.controller.gameStateSnapshot,
                  latestGameState: () => widget.controller.gameStateSnapshot,
                  damagePulseMode: widget.damagePulseMode,
                  showEnemyPortraits: widget.showEnemyPortraits,
                  showLastFormationHint: widget.showLastFormationHint,
                  enemyPreviewPosition: widget.enemyPreviewPosition,
                  sectionOrder: widget.sectionOrder,
                  visibleSections: widget.visibleSections,
                  mapSection: mapSection,
                )
              else
                BattleShipDetailsHost(
                  battle: battle,
                  latestGameState: () => widget.controller.gameStateSnapshot,
                  child: _CompactBattlePanel(
                    battle: battle,
                    gameState: widget.controller.gameStateSnapshot,
                    damagePulseMode: widget.damagePulseMode,
                    showLastFormationHint: widget.showLastFormationHint,
                    enemyPreviewPosition: widget.enemyPreviewPosition,
                    sectionOrder: widget.sectionOrder,
                    visibleSections: widget.visibleSections,
                    mapSection: mapSection,
                  ),
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
    final flat = PanelStyleScope.isFlat(context);
    if (flat) {
      // BattleUiText 在显示时按语言本地化标签，共享组件只渲染 Text，所以这里先转换。
      final strings = BattleDetailStrings.of(context);
      return FlatTextToggle(
        options: [
          FlatTextToggleOption(
            key: const Key('battle-mode-compact'),
            label: strings.localize(
              AppLocalizations.of(context)?.compact ?? '紧凑',
            ),
            selected: mode == BattlePanelMode.compact,
            onTap: () => onChanged(BattlePanelMode.compact),
          ),
          FlatTextToggleOption(
            key: const Key('battle-mode-detailed'),
            label: strings.localize(
              AppLocalizations.of(context)?.detailed ?? '完整',
            ),
            selected: mode == BattlePanelMode.detailed,
            onTap: () => onChanged(BattlePanelMode.detailed),
          ),
        ],
      );
    }
    return Container(
      height: AppSegmentedStyle.compactHeight,
      padding: AppSegmentedStyle.padding(compact: true),
      decoration: AppSegmentedStyle.decoration(context, compact: true),
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
      color: AppSegmentedStyle.selection(context, selected),
      borderRadius: AppSegmentedStyle.itemRadius(compact: true),
      child: InkWell(
        borderRadius: AppSegmentedStyle.itemRadius(compact: true),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: BattleUiText(
            label,
            style: AppSegmentedStyle.textStyle(
              context,
              selected: selected,
              compact: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBattlePanel extends StatelessWidget {
  const _CompactBattlePanel({
    required this.battle,
    required this.gameState,
    required this.damagePulseMode,
    required this.showLastFormationHint,
    required this.enemyPreviewPosition,
    required this.visibleSections,
    this.sectionOrder,
    this.mapSection,
  });

  final LiveBattle battle;
  final GameState gameState;
  final DamagePulseFilter damagePulseMode;
  final bool showLastFormationHint;
  final EnemyPreviewPosition enemyPreviewPosition;
  final List<BattlePredictionSection>? sectionOrder;
  final Iterable<BattlePredictionSection> visibleSections;
  final Widget? mapSection;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneDensity(context);
    final flat = PanelStyleScope.isFlat(context);
    final navigation = battle.displayStage == BattleDisplayStage.navigation;
    if (navigation) {
      final navigationHeader = Container(
        key: const Key('battle-navigation-header'),
        padding: flat
            ? const EdgeInsets.symmetric(vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: flat
            ? null
            : BoxDecoration(
                color: appColor(context, const Color(0xff10212e)),
                borderRadius: BorderRadius.circular(7),
              ),
        child: flat
            ? FlatNavigationHeader(
                battle: battle,
                showLastFormationHint: showLastFormationHint,
              )
            : Row(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 18,
                    color: appColor(context, const Color(0xff70c7bc)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BattleUiText(
                      battle.context.forecastNodeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Wrap(
                      spacing: 5,
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
      final raid = battle.landBaseRaid;
      final previewShips =
          battle.enemyPreviewShips ?? const <EnemyPreviewShip>[];
      final enemyPreview = OfficialEnemyPreview(
        ships: previewShips,
        combined: battle.enemyPreviewCombined,
      );
      final friendlyFleets = NavigationFriendlyFleets(
        battle: battle,
        damagePulseMode: damagePulseMode,
      );
      return Column(
        key: const Key('compact-battle-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          navigationHeader,
          SizedBox(height: flat ? flatSectionGap : 7),
          BattlePredictionSections(
            order: sectionOrder,
            visibleSections: visibleSections,
            legacyEnemyPreviewPosition: enemyPreviewPosition,
            sortieMap: mapSection,
            enemyPreview: previewShips.isNotEmpty ? enemyPreview : null,
            predictionResult: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (raid != null) ...[
                  LandBaseRaidPanel(result: raid, compact: true),
                  SizedBox(height: flat ? flatSectionGap : 9),
                ],
                friendlyFleets,
              ],
            ),
          ),
        ],
      );
    }
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final dropShipNames = <String>[
      for (final id in battle.effectiveDropShipMasterIds)
        gameNames(
          context,
        ).shipName(gameState.masterShips[id]?.name ?? 'ID: $id', shipId: id),
    ];
    final dropEntries = <String>[
      if (dropShipNames.isNotEmpty) l10n.dropLabel(dropShipNames.join('、')),
    ];
    final rawEnemyName = battle.enemyFleetName.isNotEmpty
        ? battle.enemyFleetName
        : '敌方舰队';
    final enemyName = rawEnemyName;
    final enemyCombined =
        battle.enemyEscort.isNotEmpty || rawEnemyName.contains('联合舰队');
    // Flat shows the engagement on the formation line above the fleets.
    final metaChips = _compactMetaChips(battle, includeEngagement: !flat);
    final statusPills = <Widget>[
      for (final label in battle.context.nodeTypeLabels)
        NodeTypePill(label: label),
      if (battle.airSuperiority != null)
        AirSuperiorityPill(label: battle.airSuperiority!),
      for (final chip in metaChips) MetaChip(label: chip.$1, color: chip.$2),
      for (final entry in dropEntries) DropPill(text: entry),
    ];

    return Column(
      key: const Key('compact-battle-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BattlePredictionSections(
          order: sectionOrder,
          visibleSections: visibleSections,
          legacyEnemyPreviewPosition: enemyPreviewPosition,
          sortieMap: mapSection,
          predictionResult: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (battle.rank != BattleRank.unknown) ...<Widget>[
                    _RankBadge(rank: battle.rank, phone: phone, flat: flat),
                    SizedBox(width: flat ? 8 : 11),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdaptiveBattleHeader(
                          nodeLabel: battle.context.forecastNodeLabel,
                          nodeFontSize: flat ? 12 : 16,
                          enemyName: enemyName,
                          enemyNameIsFallback: battle.enemyFleetName.isEmpty,
                          enemyStyle: TextStyle(
                            fontSize: flat ? 11 : (phone ? 13 : 14),
                            fontWeight: FontWeight.w600,
                            color: appColor(
                              context,
                              enemyCombined ? const Color(0xffff8c78) : null,
                            ),
                          ),
                        ),
                        if (flat) ...<Widget>[
                          const SizedBox(height: 2),
                          BattleTagLine(
                            battle: battle,
                            nodeLabel: battle.context.forecastNodeLabel,
                            metaLabels: [for (final chip in metaChips) chip.$1],
                          ),
                          BattleDropLine(
                            dropEntries: dropEntries,
                            rewardItems: battle.rewardItems,
                          ),
                        ] else if (statusPills.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: statusPills,
                          ),
                        ],
                        if (!flat && battle.rewardItems.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          RewardItemsPill(items: battle.rewardItems),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: flat ? flatSectionGap : 8),
              _CompactFleetGrid(
                battle: battle,
                damagePulseMode: damagePulseMode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactFleetGrid extends StatelessWidget {
  const _CompactFleetGrid({
    required this.battle,
    required this.damagePulseMode,
  });

  final LiveBattle battle;
  final DamagePulseFilter damagePulseMode;

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
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
          damagePulseMode: damagePulseMode,
        ),
      );
      friendColumns.add(
        _CompactFleetColumn(
          keyName: 'friend-escort',
          ships: battle.friendEscort,
          mvpPositions: mvpPositions,
          positionOffset: 6,
          damagePulseMode: damagePulseMode,
        ),
      );
    } else {
      friendColumns.add(
        _CompactFleetColumn(
          keyName: 'friend',
          ships: battle.friendMain,
          mvpPositions: mvpPositions,
          damagePulseMode: damagePulseMode,
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
          damagePulseMode: damagePulseMode,
        ),
      );
      enemyColumns.add(
        _CompactFleetColumn(
          keyName: 'enemy-main',
          ships: battle.enemyMain,
          mvpPositions: const <int>[],
          damagePulseMode: damagePulseMode,
        ),
      );
    } else {
      enemyColumns.add(
        _CompactFleetColumn(
          keyName: 'enemy',
          ships: battle.enemyMain,
          mvpPositions: const <int>[],
          damagePulseMode: damagePulseMode,
        ),
      );
    }
    Widget side(
      String keyName,
      String title,
      Color color,
      List<Widget> columns,
    ) => Expanded(
      flex: columns.length,
      child: Container(
        padding: flat ? EdgeInsets.zero : const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: flat
            ? null
            : BoxDecoration(
                color: appColor(context, const Color(0xff10212e)),
                borderRadius: BorderRadius.circular(8),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!flat) ...<Widget>[
              _CompactFleetSideTitle(
                keyName: keyName,
                title: title,
                color: appColor(context, color),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (
                  var index = 0;
                  index < columns.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) const SizedBox(width: 7),
                  Expanded(child: columns[index]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    final grid = Row(
      key: const Key('compact-fleet-grid'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        side(
          'friend',
          '我方舰队$friendFormation',
          const Color(0xff70c7bc),
          friendColumns,
        ),
        SizedBox(width: flat ? 6 : 7),
        side(
          'enemy',
          '敌方舰队$enemyFormation',
          const Color(0xffff8c78),
          enemyColumns,
        ),
      ],
    );
    if (!flat) return grid;
    final strings = BattleDetailStrings.of(context);
    final formationLine = _FlatFormationLine(
      key: const Key('compact-formation-line'),
      friend: battle.friendFormation > 0
          ? strings.localize(formationLabel(battle.friendFormation))
          : null,
      engagement: battle.engagement > 0
          ? strings.localize(engagementLabel(battle.engagement))
          : null,
      enemy: battle.enemyFormation > 0
          ? strings.localize(formationLabel(battle.enemyFormation))
          : null,
    );
    if (formationLine.isEmpty) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[formationLine, const SizedBox(height: 2), grid],
    );
  }
}

/// Replaces the two flat side titles: friend formation, engagement and enemy
/// formation in one line, falling back to centered wrapping text rather than
/// truncating any of them.
class _FlatFormationLine extends StatelessWidget {
  const _FlatFormationLine({
    super.key,
    required this.friend,
    required this.engagement,
    required this.enemy,
  });

  final String? friend;
  final String? engagement;
  final String? enemy;

  bool get isEmpty => friend == null && engagement == null && enemy == null;

  static const double _gap = 8;
  static const TextStyle _baseStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _friendStyle = TextStyle(color: Color(0xff70c7bc));
  static const TextStyle _engagementStyle = TextStyle(color: Color(0xffdfe8ee));
  static const TextStyle _enemyStyle = TextStyle(color: Color(0xffff8c78));

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final textDirection = Directionality.of(context);
    final measureStyle = DefaultTextStyle.of(context).style.merge(_baseStyle);
    double widthOf(String? text) {
      if (text == null) return 0;
      final painter = TextPainter(
        text: TextSpan(text: text, style: measureStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    Widget label(String? text, TextStyle style) => text == null
        ? const SizedBox.shrink()
        : Text(text, maxLines: 1, style: _baseStyle.merge(style));

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final friendWidth = widthOf(friend);
        final enemyWidth = widthOf(enemy);
        if (engagement != null) {
          // Equal side slots keep the engagement centered on the line even
          // when one formation is missing or the two differ in width.
          final side = (maxWidth - widthOf(engagement)) / 2 - _gap;
          if (friendWidth <= side && enemyWidth <= side) {
            return Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: label(friend, _friendStyle),
                  ),
                ),
                const SizedBox(width: _gap),
                label(engagement, _engagementStyle),
                const SizedBox(width: _gap),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: label(enemy, _enemyStyle),
                  ),
                ),
              ],
            );
          }
        } else if (friendWidth + _gap + enemyWidth <= maxWidth) {
          return Row(
            children: <Widget>[
              label(friend, _friendStyle),
              const Spacer(),
              label(enemy, _enemyStyle),
            ],
          );
        }
        final segments = <(String, TextStyle)>[
          if (friend != null) (friend!, _friendStyle),
          if (engagement != null) (engagement!, _engagementStyle),
          if (enemy != null) (enemy!, _enemyStyle),
        ];
        return Text.rich(
          appTextSpan(
            context,
            TextSpan(
              style: _baseStyle,
              children: <InlineSpan>[
                for (var index = 0; index < segments.length; index++) ...[
                  if (index > 0) flatSegmentSeparator,
                  TextSpan(text: segments[index].$1, style: segments[index].$2),
                ],
              ],
            ),
          ),
          textAlign: TextAlign.center,
        );
      },
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
        child: BattleUiText(
          title,
          maxLines: 1,
          softWrap: false,
          style: appTextStyle(
            context,
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
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
    required this.damagePulseMode,
    this.positionOffset = 0,
  });

  final String keyName;
  final List<BattleShipSnapshot> ships;
  final List<int> mvpPositions;
  final DamagePulseFilter damagePulseMode;
  final int positionOffset;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('compact-fleet-col-$keyName'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < ships.length; index++)
          BattleShipDetailsTap(
            ship: ships[index],
            child: _CompactBarRow(
              ship: ships[index],
              keyName: keyName,
              index: index,
              isMvp: mvpPositions.contains(index + positionOffset),
              damagePulseMode: damagePulseMode,
            ),
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
    required this.damagePulseMode,
  });

  final BattleShipSnapshot ship;
  final String keyName;
  final int index;
  final bool isMvp;
  final DamagePulseFilter damagePulseMode;

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
    final isEscaped = ship.isEscaped;
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
      final hpNumber = Opacity(
        key: pulsing ? Key('compact-damage-hp-number-$keyName-$index') : null,
        opacity: opacity,
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
      );
      final hpBar = Opacity(
        key: pulsing ? Key('compact-damage-hp-bar-$keyName-$index') : null,
        opacity: opacity,
        child: ProphetHpBar(
          value: ratio,
          color: appColor(context, hpBarColor),
          backgroundColor: appColor(context, const Color(0xff263e4d)),
          height: flat ? 4 : 6,
        ),
      );
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                hpNumber,
                if (isMvp) ...<Widget>[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.emoji_events_rounded,
                    key: Key('compact-mvp-$keyName-$index'),
                    size: 9,
                    color: appColor(context, Color(0xffffd65c)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          hpBar,
        ],
      );
      return pulsing
          ? KeyedSubtree(
              key: Key('compact-damage-hp-pulse-$keyName-$index'),
              child: content,
            )
          : content;
    }

    final shouldPulse =
        !isEscaped &&
        ship.currentHp > 0 &&
        ship.maxHp > 0 &&
        ship.currentHp * 4 <= ship.maxHp * 3;
    return Padding(
      key: Key('compact-bar-$keyName-$index'),
      padding: flat
          ? const EdgeInsets.symmetric(vertical: 1)
          : const EdgeInsets.fromLTRB(6, 3, 6, 3),
      child: shouldPulse
          ? DamagePulseBuilder(
              currentHp: ship.currentHp,
              maxHp: ship.maxHp,
              filter: damagePulseMode,
              normalColor: hpBarColor,
              builder: (context, spec, phase) => hpContent(
                opacity:
                    spec.minFrameOpacity + phase * (1 - spec.minFrameOpacity),
                pulsing: true,
              ),
            )
          : hpContent(),
    );
  }
}

List<(String, Color)> _compactMetaChips(
  LiveBattle battle, {
  required bool includeEngagement,
}) {
  return <(String, Color)>[
    if (battle.context.combinedFleetType != CombinedFleetType.none)
      (battle.context.combinedFleetType.label, const Color(0xff70c7bc)),
    if (!battle.context.nodeTypeLabels.contains(battle.phaseLabel))
      (battle.phaseLabel, battlePhaseChipColor(battle.phaseLabel)),
    if (includeEngagement && battle.engagement > 0)
      (
        engagementLabel(battle.engagement),
        engagementChipColor(battle.engagement),
      ),
  ];
}

/// 标题行右侧的状态徽章：卡片档是胶囊，扁平档只留文字。
class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.color,
    required this.background,
    required this.label,
  });

  final Color color;
  final Color background;
  final Widget Function(TextStyle style) label;

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
    final text = label(
      TextStyle(
        color: appColor(context, color),
        fontSize: flat ? flatSmallFontSize : 11,
        fontWeight: FontWeight.w700,
      ),
    );
    if (flat) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: appColor(context, background),
        borderRadius: BorderRadius.circular(8),
      ),
      child: text,
    );
  }
}

class _IdleBadge extends StatelessWidget {
  const _IdleBadge();

  @override
  Widget build(BuildContext context) => _HeaderBadge(
    color: const Color(0xff9db2bf),
    background: const Color(0xff203443),
    label: (style) =>
        Text(AppLocalizations.of(context)?.standby ?? '待机', style: style),
  );
}

class _IdleBattleContent extends StatelessWidget {
  const _IdleBattleContent();

  @override
  Widget build(BuildContext context) {
    final flat = PanelStyleScope.isFlat(context);
    final text = AppLocalizations.of(context)?.waitingForSortieData ?? '等待出击数据';
    if (flat) {
      return Padding(
        key: const Key('battle-idle-content'),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: FlatIconLine(
          icon: Icons.explore_outlined,
          color: const Color(0xff70c7bc),
          child: Text(
            text,
            style: TextStyle(
              color: appColor(context, flatMutedColor),
              fontSize: flatRowFontSize,
            ),
          ),
        ),
      );
    }
    return Container(
      key: const Key('battle-idle-content'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff10212e)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(
            Icons.explore_outlined,
            size: 18,
            color: appColor(context, Color(0xff70c7bc)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: appColor(context, const Color(0xff9db2bf)),
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
    return _HeaderBadge(
      color: foreground,
      background: background,
      label: (style) => BattleUiText(label, style: style),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.phone,
    required this.flat,
  });

  final BattleRank rank;
  final bool phone;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return BattleRankBadge(
      rank: rank,
      size: flat ? 28 : (phone ? 50 : 48),
      fontSize: flat ? 12 : (phone ? 21 : 20),
    );
  }
}
