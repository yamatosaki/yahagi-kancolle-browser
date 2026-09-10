import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../settings/battle_status_effect_settings.dart';
import 'dashboard_card.dart';
import 'equipment_type_icon.dart';
import 'fleet_ship_status_capsule.dart';
import 'land_base_air_power.dart';
import 'land_base_status_visuals.dart';
import 'ship_status_style.dart';
import 'ship_status_visuals.dart';
import 'slot_item_portrait.dart';
import 'status_density.dart';

class LandBaseSummaryCard extends StatefulWidget {
  const LandBaseSummaryCard({
    super.key,
    required this.controller,
    required this.collapsed,
    required this.onToggleCollapse,
    this.damagePulseMode = DamagePulseFilter.all,
  });

  final GameStateController controller;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final DamagePulseFilter damagePulseMode;

  @override
  State<LandBaseSummaryCard> createState() => _LandBaseSummaryCardState();
}

class _LandBaseSummaryCardState extends State<LandBaseSummaryCard> {
  int? _selectedAreaId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final l10n =
          AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('zh'));
      final state = widget.controller.state;
      final areaIds =
          state.landBases.map((base) => base.areaId).toSet().toList()..sort();
      if (!areaIds.contains(_selectedAreaId)) {
        _selectedAreaId = areaIds.firstOrNull;
      }
      final areaId = _selectedAreaId;
      final bases = areaId == null
          ? <LandBaseState>[]
          : state.landBases.where((base) => base.areaId == areaId).toList();
      bases.sort((left, right) => left.baseId.compareTo(right.baseId));

      return DashboardCard(
        title: l10n.landBaseBrief,
        icon: const Icon(Icons.flight_rounded),
        collapsed: widget.collapsed,
        onToggleCollapse: widget.onToggleCollapse,
        collapseButtonKey: const Key('land-base-collapse-button'),
        trailing: _LandBaseAreaSwitcher(
          areaIds: areaIds,
          selectedAreaId: areaId,
          onSelected: (selected) => setState(() => _selectedAreaId = selected),
        ),
        child: bases.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    l10n.landBaseNoData,
                    style: const TextStyle(color: Color(0xff8197a5)),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AreaHeading(
                    areaId: areaId!,
                    name:
                        state.masterMapAreas[areaId] ??
                        l10n.landBaseAreaFallback(areaId),
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 4.0;
                      final columnCount = constraints.maxWidth >= 680 ? 2 : 1;
                      final rowWidth =
                          (constraints.maxWidth - gap * (columnCount - 1)) /
                          columnCount;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          for (final base in bases)
                            SizedBox(
                              width: rowWidth,
                              child: LandBaseAirGroupRow(
                                state: state,
                                base: base,
                                damagePulseMode: widget.damagePulseMode,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
      );
    },
  );
}

class _LandBaseAreaSwitcher extends StatelessWidget {
  const _LandBaseAreaSwitcher({
    required this.areaIds,
    required this.selectedAreaId,
    required this.onSelected,
  });

  final List<int> areaIds;
  final int? selectedAreaId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('land-base-area-switcher'),
    constraints: const BoxConstraints(minWidth: 42, maxWidth: 150),
    height: 22,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: const Color(0xff102331),
      border: Border.all(color: const Color(0xff294052)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final areaId in areaIds)
          Material(
            key: Key('land-base-area-selector-$areaId'),
            color: areaId == selectedAreaId
                ? const Color(0xff8a6628)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: () => onSelected(areaId),
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '$areaId',
                    style: TextStyle(
                      color: areaId == selectedAreaId
                          ? const Color(0xffffdc88)
                          : const Color(0xff9fb3bf),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AreaHeading extends StatelessWidget {
  const _AreaHeading({required this.areaId, required this.name});

  final int areaId;
  final String name;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          '[$areaId] $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xffdce6eb),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class LandBaseAirGroupRow extends StatelessWidget {
  const LandBaseAirGroupRow({
    super.key,
    required this.state,
    required this.base,
    this.damagePulseMode = DamagePulseFilter.all,
  });

  final GameState state;
  final LandBaseState base;
  final DamagePulseFilter damagePulseMode;

  String get _keySuffix => '${base.areaId}-${base.baseId}';

  @override
  Widget build(BuildContext context) {
    final maximumHp = base.maxHp ?? 200;
    final currentHp = base.currentHp ?? maximumHp;
    final hpRatio = maximumHp <= 0
        ? 0.0
        : (currentHp / maximumHp).clamp(0.0, 1.0);
    final fatigue = landBaseFatigueLevel(
      base.squadrons.map((squadron) => squadron.condition),
    );
    final airPower = LandBaseAirPower.calculate(state: state, base: base);
    final portraitMaster = _portraitMaster(state, base);

    return Container(
      key: Key('land-base-row-$_keySuffix'),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xff1c3547),
        border: Border.all(color: const Color(0xff4c6b84), width: 1.2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 460;
          final portraitSize = fleetStatusPortraitSize(constraints.maxWidth);
          final portraitWidth = portraitSize.width;
          final portraitHeight = portraitSize.height;
          final hpTrackHeight =
              fleetStatusMeterHeight(constraints.maxWidth) * 0.45;
          final fatigueFaceSize = (portraitHeight * 0.34)
              .clamp(14.0, 20.0)
              .toDouble();
          final sectionGap = narrow ? 5.0 : 7.0;
          final statusWidth = narrow ? 68.0 : 80.0;
          final maximumSlotWidth = narrow ? 38.0 : 44.0;
          final slotWidth =
              ((constraints.maxWidth -
                          portraitWidth -
                          statusWidth -
                          sectionGap * 2 -
                          6) /
                      4)
                  .clamp(0.0, maximumSlotWidth)
                  .toDouble();
          final l10n =
              AppLocalizations.of(context) ??
              lookupAppLocalizations(const Locale('zh'));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 20,
                child: Row(
                  key: Key('land-base-identity-line-$_keySuffix'),
                  children: <Widget>[
                    Flexible(
                      fit: FlexFit.loose,
                      child: _LandBaseNameChip(
                        key: Key('land-base-name-$_keySuffix'),
                        label: base.name,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _LandBaseActionChip(
                      key: Key('land-base-action-chip-$_keySuffix'),
                      label: _actionLabel(base.actionKind, l10n),
                      color: _actionColor(base.actionKind),
                    ),
                    const SizedBox(width: 3),
                    _LandBaseInfoChip(
                      key: Key('land-base-air-power-chip-$_keySuffix'),
                      label: '${l10n.airPower} ${airPower.displayValue}',
                      color: const Color(0xffd4a74e),
                    ),
                    const SizedBox(width: 3),
                    _LandBaseInfoChip(
                      key: Key('land-base-range-chip-$_keySuffix'),
                      label: '${l10n.landBaseRange} ${base.effectiveDistance}',
                      color: const Color(0xff70b8d8),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: <Widget>[
                  SizedBox(
                    key: Key('land-base-portrait-$_keySuffix'),
                    width: portraitWidth,
                    height: portraitHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SlotItemPortrait(
                            item: portraitMaster,
                            serverOrigin: state.serverOrigin,
                            width: portraitWidth,
                            height: portraitHeight,
                          ),
                        ),
                        ShipHpFrame(
                          key: Key('land-base-portrait-hp-frame-$_keySuffix'),
                          shipId: base.areaId * 10 + base.baseId,
                          currentHp: currentHp,
                          maxHp: maximumHp,
                          color: shipHpBarColor(
                            hpRatio,
                            isZeroHp: currentHp <= 0,
                          ),
                          filter: damagePulseMode,
                          strokeWidth: 2,
                        ),
                        if (fatigue != LandBaseFatigueLevel.none)
                          Positioned(
                            right: 4,
                            top: 0,
                            child: FatigueFace(
                              level: fatigue == LandBaseFatigueLevel.red
                                  ? FatigueFaceLevel.red
                                  : FatigueFaceLevel.yellow,
                              size: fatigueFaceSize,
                              faceKey: Key(
                                'land-base-fatigue-face-$_keySuffix',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: sectionGap),
                  if (narrow)
                    SizedBox(
                      width: statusWidth,
                      child: _LandBaseStatusColumn(
                        keySuffix: _keySuffix,
                        currentHp: currentHp,
                        maximumHp: maximumHp,
                        hpRatio: hpRatio,
                        height: portraitHeight > 34 ? portraitHeight : 34,
                        trackHeight: hpTrackHeight,
                      ),
                    )
                  else
                    Expanded(
                      child: _LandBaseStatusColumn(
                        keySuffix: _keySuffix,
                        currentHp: currentHp,
                        maximumHp: maximumHp,
                        hpRatio: hpRatio,
                        height: portraitHeight > 34 ? portraitHeight : 34,
                        trackHeight: hpTrackHeight,
                      ),
                    ),
                  SizedBox(width: sectionGap),
                  Row(
                    key: Key('land-base-squadron-strip-$_keySuffix'),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (
                        var squadronId = 1;
                        squadronId <= 4;
                        squadronId++
                      ) ...[
                        if (squadronId > 1) const SizedBox(width: 2),
                        SizedBox(
                          width: slotWidth,
                          child: _LandBaseSquadronSlot(
                            state: state,
                            squadron: _squadron(base, squadronId),
                            areaId: base.areaId,
                            baseId: base.baseId,
                            squadronId: squadronId,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LandBaseStatusColumn extends StatelessWidget {
  const _LandBaseStatusColumn({
    required this.keySuffix,
    required this.currentHp,
    required this.maximumHp,
    required this.hpRatio,
    required this.height,
    required this.trackHeight,
  });

  final String keySuffix;
  final int currentHp;
  final int maximumHp;
  final double hpRatio;
  final double height;
  final double trackHeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: Key('land-base-status-column-$keySuffix'),
    height: height,
    child: _LandBaseStackedHpMeter(
      currentHp: currentHp,
      maximumHp: maximumHp,
      hpRatio: hpRatio,
      trackHeight: trackHeight,
      iconKey: Key('land-base-hp-icon-$keySuffix'),
      valueKey: Key('land-base-hp-value-$keySuffix'),
      trackKey: Key('land-base-hp-meter-$keySuffix'),
    ),
  );
}

class _LandBaseInfoChip extends StatelessWidget {
  const _LandBaseInfoChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      maxLines: 1,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700),
    ),
  );
}

class _LandBaseNameChip extends StatelessWidget {
  const _LandBaseNameChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0xff102331),
      border: Border.all(color: const Color(0xff4c6b84)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xffe8f1f5),
        fontSize: 8,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LandBaseActionChip extends StatelessWidget {
  const _LandBaseActionChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      border: Border.all(color: color.withValues(alpha: 0.42)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700),
    ),
  );
}

class _LandBaseStackedHpMeter extends StatelessWidget {
  const _LandBaseStackedHpMeter({
    required this.currentHp,
    required this.maximumHp,
    required this.hpRatio,
    required this.trackHeight,
    required this.iconKey,
    required this.valueKey,
    required this.trackKey,
  });

  final int currentHp;
  final int maximumHp;
  final double hpRatio;
  final double trackHeight;
  final Key iconKey;
  final Key valueKey;
  final Key trackKey;

  @override
  Widget build(BuildContext context) {
    final hpColor = shipHpBarColor(hpRatio, isZeroHp: currentHp <= 0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          key: valueKey,
          children: <Widget>[
            Icon(
              Icons.favorite_rounded,
              key: iconKey,
              color: const Color(0xffef5a5a),
              size: 10,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$currentHp/$maximumHp',
                  style: TextStyle(
                    color: shipHpValueColor(hpRatio, isZeroHp: currentHp <= 0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            key: trackKey,
            height: trackHeight,
            color: const Color(0xff294052),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: hpRatio,
              heightFactor: 1,
              child: ColoredBox(color: hpColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandBaseSquadronSlot extends StatelessWidget {
  const _LandBaseSquadronSlot({
    required this.state,
    required this.squadron,
    required this.areaId,
    required this.baseId,
    required this.squadronId,
  });

  final GameState state;
  final LandBaseSquadronState? squadron;
  final int areaId;
  final int baseId;
  final int squadronId;

  @override
  Widget build(BuildContext context) {
    final owned = squadron == null
        ? null
        : state.slotItems[squadron!.slotItemId];
    final master = owned == null
        ? null
        : state.masterSlotItems[owned.masterSlotItemId];
    final iconId = master != null && master.type.length > 3
        ? master.type[3]
        : -1;
    final fatigue = landBaseFatigueLevel(<int>[
      if (squadron != null) squadron!.condition,
    ]);
    final fatigueColor = landBaseFatigueColor(fatigue);
    final relocating = squadron?.state == 2;
    final missing =
        squadron != null &&
        squadron!.maxCount > 0 &&
        squadron!.currentCount < squadron!.maxCount;
    final countFontSize = isNearSquareLargeDisplay(context) ? 10.0 : 8.0;
    final suffix = '$areaId-$baseId-$squadronId';
    final content = Container(
      key: Key('land-base-slot-$suffix'),
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xff102331),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: missing
              ? const Color(0xffef775f)
              : fatigueColor?.withValues(alpha: 0.9) ?? const Color(0xff294052),
        ),
        boxShadow: fatigueColor == null
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: fatigueColor.withValues(alpha: 0.42),
                  blurRadius: fatigue == LandBaseFatigueLevel.red ? 7 : 4,
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = (constraints.maxWidth - 8).clamp(20.0, 26.0);
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              EquipmentTypeIconImage(
                key: Key('land-base-slot-icon-$suffix'),
                iconId: iconId,
                width: iconSize,
                height: iconSize,
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  key: Key('land-base-slot-count-$suffix'),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xcc102331),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    squadron == null ? '—' : '${squadron!.currentCount}',
                    style: TextStyle(
                      color: missing
                          ? const Color(0xffff8b78)
                          : const Color(0xffe8f1f5),
                      fontSize: countFontSize,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return relocating
        ? Opacity(
            key: Key('land-base-slot-relocating-$suffix'),
            opacity: 0.38,
            child: content,
          )
        : content;
  }
}

MasterSlotItem? _portraitMaster(GameState state, LandBaseState base) {
  for (final squadron in base.squadrons) {
    final owned = state.slotItems[squadron.slotItemId];
    final master = owned == null
        ? null
        : state.masterSlotItems[owned.masterSlotItemId];
    if (master != null) return master;
  }
  return null;
}

LandBaseSquadronState? _squadron(LandBaseState base, int id) {
  for (final squadron in base.squadrons) {
    if (squadron.squadronId == id) return squadron;
  }
  return null;
}

String _actionLabel(int actionKind, AppLocalizations l10n) =>
    switch (actionKind) {
      1 => l10n.landBaseActionSortie,
      2 => l10n.landBaseActionAirDefense,
      3 => l10n.landBaseActionRetreat,
      4 => l10n.landBaseActionRest,
      _ => l10n.standby,
    };

Color _actionColor(int actionKind) => switch (actionKind) {
  1 => const Color(0xffef7777),
  2 => const Color(0xff69aee8),
  3 => const Color(0xff9ca8b2),
  4 => const Color(0xff70c697),
  _ => const Color(0xffb7c4cc),
};
