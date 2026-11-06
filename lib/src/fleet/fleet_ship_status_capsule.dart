import '../theme/app_palette.dart';
import '../settings/fleet_display_options.dart';
import 'package:flutter/material.dart';
import '../localization/game_name_localizations.dart';
import '../battle/prophet_hp_bar.dart';
import 'fleet_ui_strings.dart';
import 'fleet_ship_type_label.dart';

import '../game_state/game_state.dart';
import '../settings/battle_status_effect_settings.dart';
import 'combat_mechanism.dart';
import 'equipment_type_icon.dart';
import 'ship_portrait.dart';
import 'ship_repair_status.dart';
import 'ship_speed_visual.dart';
import 'ship_status_style.dart';
import 'equipment_display.dart';
import 'ship_status_visuals.dart';

Size fleetStatusPortraitSize(double maxWidth) => maxWidth < 430
    ? const Size(60, 28)
    : maxWidth < 520
    ? const Size(68, 32)
    : const Size(96, 42);

double fleetStatusMeterHeight(double maxWidth) => maxWidth < 430 ? 15 : 16;

class FleetShipStatusCapsule extends StatefulWidget {
  const FleetShipStatusCapsule({
    super.key,
    required this.state,
    required this.ship,
    this.damagePulseFilter = DamagePulseFilter.all,
    this.moraleSparkleMode = MoraleSparkleMode.blinking,
    this.repairStatus,
    this.specialAttack,
    this.onTap,
    this.visible = defaultFields,
    this.shipTypeLabelMode = FleetShipTypeLabelMode.localizedName,
  });

  final GameState state;
  final OwnedShip ship;
  final DamagePulseFilter damagePulseFilter;
  final MoraleSparkleMode moraleSparkleMode;
  final ShipRepairStatus? repairStatus;
  final EquipmentMechanismDisplay? specialAttack;
  final VoidCallback? onTap;
  final Set<String> visible;
  final FleetShipTypeLabelMode shipTypeLabelMode;

  @override
  State<FleetShipStatusCapsule> createState() => _FleetShipStatusCapsuleState();
}

class _FleetShipStatusCapsuleState extends State<FleetShipStatusCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparklePulse;
  MoraleSparkleMode get effectiveSparkleMode =>
      show('portrait') ? widget.moraleSparkleMode : MoraleSparkleMode.off;
  bool get effectiveSparkleEnabled =>
      effectiveSparkleMode != MoraleSparkleMode.off;
  DamagePulseFilter get effectiveDamagePulseFilter =>
      show('portrait') ? widget.damagePulseFilter : DamagePulseFilter.off;

  void _syncSparkleAnimation() {
    if (effectiveSparkleMode == MoraleSparkleMode.blinking &&
        widget.ship.condition >= 50) {
      if (!_sparklePulse.isAnimating) _sparklePulse.repeat();
    } else {
      _sparklePulse.stop();
    }
  }

  @override
  void didUpdateWidget(FleetShipStatusCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSparkleAnimation();
  }

  @override
  void reassemble() {
    super.reassemble();
    _syncSparkleAnimation();
  }

  @override
  void initState() {
    super.initState();
    _sparklePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _syncSparkleAnimation();
  }

  @override
  void dispose() {
    _sparklePulse.dispose();
    super.dispose();
  }

  static double _ratio(int current, int max) {
    if (max <= 0) return 0;
    return (current / max).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final ship = widget.ship;
    final onTap = widget.onTap;

    final master = state.masterForShip(ship);
    final typeLabel = fleetShipTypeLabel(
      context,
      state,
      master,
      widget.shipTypeLabelMode,
    );
    final hpRatio = _ratio(ship.currentHp, ship.maxHp);
    final isDamaged = shipUsesDamagedPortrait(ship);
    final fuelRatio = _ratio(ship.currentFuel, master?.maxFuel ?? 0);
    final ammoRatio = _ratio(ship.currentAmmo, master?.maxAmmo ?? 0);
    final equipment = state.equipmentForShip(ship);
    final shipMechanisms = detectShipCombatMechanisms(state, ship);
    final allMechanisms = <EquipmentMechanismDisplay>[
      ...shipMechanisms,
      if (widget.specialAttack != null) widget.specialAttack!,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final narrow = constraints.maxWidth < 430;
        final portraitSize = fleetStatusPortraitSize(constraints.maxWidth);
        final sectionGap = narrow ? 6.0 : (compact ? 8.0 : 12.0);
        final meterHeight = fleetStatusMeterHeight(constraints.maxWidth);

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: appColor(
                  context,
                  Color(0xff1c3547),
                ), // Brighter background
                border: Border.all(
                  color: appColor(context, Color(0xff4c6b84)),
                  width: 1.2,
                ), // Brighter & slightly thicker border
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: appColor(context, Colors.black45), // Stronger shadow
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: appColor(context, Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: narrow ? 4 : (compact ? 6 : 8),
                      right: narrow ? 4 : (compact ? 6 : 8),
                      top: 3,
                      bottom: 2,
                    ),
                    child: LayoutBuilder(
                      builder: (context, identityConstraints) {
                        final portraitWidth =
                            (identityConstraints.maxWidth * 0.35)
                                .clamp(0.0, portraitSize.width)
                                .toDouble();
                        final portraitHeight =
                            portraitSize.height *
                            portraitWidth /
                            portraitSize.width;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_badges(
                                  typeLabel,
                                  master,
                                  allMechanisms,
                                ).isNotEmpty ||
                                (show('equipment') &&
                                    equipment.isNotEmpty)) ...[
                              SizedBox(
                                height: 16,
                                child: Row(
                                  children: [
                                    if (_badges(
                                      typeLabel,
                                      master,
                                      allMechanisms,
                                    ).isNotEmpty)
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: _spaced(
                                              _badges(
                                                typeLabel,
                                                master,
                                                allMechanisms,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (show('equipment'))
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              identityConstraints.maxWidth *
                                              (_badges(
                                                    typeLabel,
                                                    master,
                                                    allMechanisms,
                                                  ).isEmpty
                                                  ? 1
                                                  : .5),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            key: Key('equipment-${ship.id}'),
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              for (final eq in equipment)
                                                if (eq.master != null &&
                                                    eq.master!.type.length >= 4)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    child:
                                                        EquipmentTypeIconImage(
                                                          iconId: eq
                                                              .master!
                                                              .type[3],
                                                          width: 16,
                                                          height: 16,
                                                          filterQuality:
                                                              FilterQuality
                                                                  .medium,
                                                        ),
                                                  ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            // Text-only mode reuses space instead of reserving an avatar column.
                            if (!show('portrait'))
                              _textIdentity(ship, master)
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (show('portrait')) ...[
                                    SizedBox(
                                      key: Key(
                                        'fleet-focus-portrait-${ship.id}',
                                      ),
                                      width: portraitWidth,
                                      height: portraitHeight,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child:
                                                  widget.repairStatus ==
                                                      ShipRepairStatus.retreat
                                                  ? ColorFiltered(
                                                      colorFilter:
                                                          shipRetreatGrayscale,
                                                      child: ShipPortrait(
                                                        ship: master,
                                                        isDamaged: isDamaged,
                                                        serverOrigin:
                                                            state.serverOrigin,
                                                        width: portraitWidth,
                                                        height: portraitHeight,
                                                      ),
                                                    )
                                                  : ShipPortrait(
                                                      ship: master,
                                                      isDamaged: isDamaged,
                                                      serverOrigin:
                                                          state.serverOrigin,
                                                      width: portraitWidth,
                                                      height: portraitHeight,
                                                    ),
                                            ),
                                          ),
                                          ShipHpFrame(
                                            key: Key(
                                              'fleet-summary-hp-outer-frame-${ship.id}',
                                            ),
                                            shipId: ship.id,
                                            currentHp:
                                                widget.repairStatus ==
                                                    ShipRepairStatus.retreat
                                                ? 0
                                                : ship.currentHp,
                                            maxHp: ship.maxHp,
                                            color: appColor(
                                              context,
                                              widget.repairStatus ==
                                                      ShipRepairStatus.retreat
                                                  ? yahagiStatusZeroHp
                                                  : shipHpBarColor(
                                                      hpRatio,
                                                      isZeroHp:
                                                          ship.currentHp <= 0,
                                                    ),
                                            ),
                                            filter: effectiveDamagePulseFilter,
                                            strokeWidth: 2.0,
                                          ),
                                          ShipMoraleMark(
                                            key: Key(
                                              'fleet-summary-morale-mark-${ship.id}',
                                            ),
                                            shipId: ship.id,
                                            value: ship.condition,
                                            sparklePulse: _sparklePulse,
                                            sparkleMode: effectiveSparkleMode,
                                            showTextBadge: false,
                                            repairLabel:
                                                widget.repairStatus?.label,
                                            layout: ShipMoraleMarkLayout.brief,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: sectionGap),
                                  ],
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            if (!show('portrait') &&
                                                (ship.condition < 30 ||
                                                    (ship.condition >= 50 &&
                                                        effectiveSparkleEnabled)))
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: ShipMoraleMark(
                                                  shipId: ship.id,
                                                  value: ship.condition,
                                                  sparklePulse: _sparklePulse,
                                                  sparkleMode:
                                                      effectiveSparkleMode,
                                                  showTextBadge: false,
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                (master == null
                                                        ? null
                                                        : gameNames(
                                                            context,
                                                          ).shipName(
                                                            master.name,
                                                            shipId: master.id,
                                                          )) ??
                                                    fleetText(context, '未知舰娘'),
                                                maxLines: 1,
                                                softWrap: false,
                                                style: appTextStyle(
                                                  context,
                                                  TextStyle(
                                                    fontSize: narrow
                                                        ? 11
                                                        : (compact ? 14 : 17),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (show('fuel')) ...[
                                              SizedBox(width: sectionGap),
                                              Expanded(
                                                child: CompactStatusMeter(
                                                  height: meterHeight,
                                                  showTrack: show('bars'),
                                                  icon: Image.asset(
                                                    'assets/images/material/01.png',
                                                    width: 10,
                                                    height: 10,
                                                  ),
                                                  value:
                                                      '${ship.currentFuel}/${master?.maxFuel ?? 0}',
                                                  ratio: fuelRatio,
                                                  valueColor:
                                                      shipSupplyValueColor(
                                                        fuelRatio,
                                                      ),
                                                  barColor: shipSupplyBarColor(
                                                    fuelRatio,
                                                  ),
                                                  valueKey: Key(
                                                    'fleet-focus-fuel-value-${ship.id}',
                                                  ),
                                                  trackKey: Key(
                                                    'fleet-focus-fuel-track-${ship.id}',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (show('hp') || show('ammo')) ...[
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              if (show('hp'))
                                                Expanded(
                                                  child: CompactStatusMeter(
                                                    alignRight: !show('bars'),
                                                    height: meterHeight,
                                                    showTrack: show('bars'),
                                                    icon: Icon(
                                                      Icons.favorite_rounded,
                                                      key: Key(
                                                        'fleet-focus-hp-icon-${ship.id}',
                                                      ),
                                                      color: appColor(
                                                        context,
                                                        Color(0xffef5a5a),
                                                      ),
                                                      size: 10,
                                                    ),
                                                    value:
                                                        '${ship.currentHp}/${ship.maxHp}',
                                                    ratio: hpRatio,
                                                    showHpThresholds: true,
                                                    valueColor:
                                                        shipHpValueColor(
                                                          hpRatio,
                                                          isZeroHp:
                                                              ship.currentHp <=
                                                              0,
                                                        ),
                                                    barColor: shipHpBarColor(
                                                      hpRatio,
                                                      isZeroHp:
                                                          ship.currentHp <= 0,
                                                    ),
                                                    valueKey: Key(
                                                      'fleet-focus-hp-value-${ship.id}',
                                                    ),
                                                    trackKey: Key(
                                                      'fleet-focus-hp-track-${ship.id}',
                                                    ),
                                                  ),
                                                )
                                              else
                                                const Expanded(
                                                  child: SizedBox.shrink(),
                                                ),
                                              SizedBox(width: sectionGap),
                                              if (show('ammo')) ...[
                                                Expanded(
                                                  child: CompactStatusMeter(
                                                    alignRight: !show('bars'),
                                                    height: meterHeight,
                                                    showTrack: show('bars'),
                                                    icon: Image.asset(
                                                      'assets/images/material/02.png',
                                                      width: 10,
                                                      height: 10,
                                                    ),
                                                    value:
                                                        '${ship.currentAmmo}/${master?.maxAmmo ?? 0}',
                                                    ratio: ammoRatio,
                                                    valueColor:
                                                        shipSupplyValueColor(
                                                          ammoRatio,
                                                        ),
                                                    barColor:
                                                        shipSupplyBarColor(
                                                          ammoRatio,
                                                        ),
                                                    valueKey: Key(
                                                      'fleet-focus-ammo-value-${ship.id}',
                                                    ),
                                                    trackKey: Key(
                                                      'fleet-focus-ammo-track-${ship.id}',
                                                    ),
                                                  ),
                                                ),
                                              ] else
                                                const Expanded(
                                                  child: SizedBox.shrink(),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (!show('portrait') && hpRatio <= .75)
              Positioned.fill(
                child: IgnorePointer(
                  child: ShipHpFrame(
                    shipId: ship.id,
                    currentHp: ship.currentHp,
                    maxHp: ship.maxHp,
                    color: appColor(
                      context,
                      shipHpBarColor(hpRatio, isZeroHp: ship.currentHp <= 0),
                    ),
                    filter: effectiveDamagePulseFilter,
                    strokeWidth: 1.2,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _textIdentity(OwnedShip ship, MasterShip? master) {
    final name = Row(
      key: Key('text-identity-${ship.id}'),
      children: [
        Flexible(
          child: Text(
            (master == null
                    ? null
                    : gameNames(
                        context,
                      ).shipName(master.name, shipId: master.id)) ??
                fleetText(context, '未知舰娘'),
            key: Key('text-name-${ship.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        if (ship.condition < 30 ||
            (ship.condition >= 50 && effectiveSparkleEnabled)) ...[
          const SizedBox(width: 4),
          SizedBox(
            key: Key('text-morale-${ship.id}'),
            // The face is 14px wide with a 4px inset in ShipMoraleMark.
            // Leave room on both sides so its Stack does not clip it.
            width: 22,
            height: 18,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ShipMoraleMark(
                shipId: ship.id,
                value: ship.condition,
                sparklePulse: _sparklePulse,
                sparkleMode: effectiveSparkleMode,
                showTextBadge: false,
              ),
            ),
          ),
        ],
        if (widget.repairStatus != null) ...[
          const SizedBox(width: 4),
          MiniBadge(
            key: Key('text-status-${ship.id}'),
            text: fleetText(context, widget.repairStatus!.label),
            color: appColor(context, Color(0xffffc861)),
          ),
        ],
      ],
    );
    Widget meter(String key, int current, int max) {
      final ratio = _ratio(current, max);
      final hp = key == 'hp';
      return CompactStatusMeter(
        height: 16,
        showTrack: show('bars'),
        alignRight: !show('bars') && key != 'fuel',
        icon: hp
            ? Icon(
                Icons.favorite_rounded,
                size: 10,
                color: appColor(context, Color(0xffef5a5a)),
              )
            : Image.asset(
                'assets/images/material/${key == 'fuel' ? '01' : '02'}.png',
                width: 10,
                height: 10,
              ),
        value: '$current/$max',
        ratio: ratio,
        showHpThresholds: hp,
        valueColor: hp
            ? shipHpValueColor(ratio, isZeroHp: current <= 0)
            : shipSupplyValueColor(ratio),
        barColor: hp
            ? shipHpBarColor(ratio, isZeroHp: current <= 0)
            : shipSupplyBarColor(ratio),
        valueKey: Key('fleet-focus-$key-value-${ship.id}'),
        trackKey: Key('fleet-focus-$key-track-${ship.id}'),
      );
    }

    final hp = show('hp') ? meter('hp', ship.currentHp, ship.maxHp) : null;
    final fuel = show('fuel')
        ? meter('fuel', ship.currentFuel, master?.maxFuel ?? 0)
        : null;
    final ammo = show('ammo')
        ? meter('ammo', ship.currentAmmo, master?.maxAmmo ?? 0)
        : null;
    if (hp == null && fuel == null && ammo == null) return name;

    // Keep the portrait layout's slots at every width: name/fuel, HP/ammo.
    // Empty lower cells must not move the remaining meter into another slot.
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: name),
            if (fuel != null) ...[
              const SizedBox(width: 8),
              Expanded(child: fuel),
            ],
          ],
        ),
        if (hp != null || ammo != null) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(child: hp ?? const SizedBox.shrink()),
              const SizedBox(width: 8),
              Expanded(child: ammo ?? const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }

  bool show(String key) => widget.visible.contains(key);
  List<Widget> _spaced(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const SizedBox(width: 4),
      items[i],
    ],
  ];
  List<Widget> _badges(
    String? type,
    MasterShip? master,
    List<EquipmentMechanismDisplay> mechanisms,
  ) {
    final ship = widget.ship;
    Widget badge(String key, String text, Color color) => MiniBadge(
      key: Key(
        key == 'shipSpeed'
            ? 'fleet-focus-speed-${ship.id}'
            : key.startsWith('mechanism')
            ? 'fleet-focus-mechanism-${ship.id}${key.substring(9)}'
            : '$key-${ship.id}',
      ),
      text: key.startsWith('mechanism')
          ? gameNames(context).entityText(fleetText(context, text))
          : fleetText(context, text),
      color: appColor(context, color),
    );
    return [
      if (show('level'))
        badge('level', 'Lv. ${ship.level}', const Color(0xffa9bac4)),
      if (show('type')) badge('type', type ?? '未知舰种', const Color(0xffa9bac4)),
      if (show('shipSpeed'))
        badge(
          'shipSpeed',
          ShipSpeedVisual.fromSpeed(ship.effectiveSpeed(master)).label,
          ShipSpeedVisual.fromSpeed(ship.effectiveSpeed(master)).foreground,
        ),
      if (show('morale'))
        badge(
          'morale',
          '疲劳 ${ship.condition}',
          shipFatigueColor(ship.condition),
        ),
      for (var i = 0; i < mechanisms.length; i++)
        if (show('mechanisms'))
          badge(
            i == 0 ? 'mechanism' : 'mechanism-$i',
            mechanisms[i].detailedShortLabel,
            mechanismToneColor(mechanisms[i].tone),
          ),
    ];
  }
}

class MiniBadge extends StatelessWidget {
  const MiniBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: appColor(context, color.withValues(alpha: 0.16)),
        border: Border.all(
          color: appColor(context, color.withValues(alpha: 0.42)),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: appTextStyle(
          context,
          TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class CompactStatusMeter extends StatelessWidget {
  const CompactStatusMeter({
    super.key,
    required this.height,
    required this.icon,
    required this.value,
    required this.ratio,
    required this.valueColor,
    required this.barColor,
    this.valueKey,
    this.trackKey,
    this.showTrack = true,
    this.alignRight = false,
    this.showHpThresholds = false,
  });

  final double height;
  final Widget icon;
  final String value;
  final double ratio;
  final Color valueColor;
  final Color barColor;
  final Key? valueKey;
  final Key? trackKey;
  final bool showTrack;
  final bool alignRight;
  final bool showHpThresholds;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Preserve the value when a narrow multi-column card cannot fit
          // both the fixed-size icon and the progress track.
          if (constraints.maxWidth < 40) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Text(
                value,
                key: valueKey,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            );
          }
          final valueWidth =
              ((constraints.maxWidth - 18) * (showTrack ? .65 : 1)).clamp(
                0.0,
                40.0,
              );
          return Row(
            mainAxisAlignment: alignRight
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              SizedBox(width: 12, child: Center(child: icon)),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: alignRight && !showTrack ? 0 : valueWidth,
                  maxWidth: valueWidth,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: alignRight
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    value,
                    key: valueKey,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: valueColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              if (showTrack) const SizedBox(width: 2),
              if (showTrack)
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: 0.45,
                    child: Container(
                      key: trackKey,
                      decoration: BoxDecoration(
                        color: appColor(context, Color(0xff294052)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: showHpThresholds
                          ? ProphetHpBar(
                              value: ratio,
                              color: appColor(context, barColor),
                              backgroundColor: appColor(
                                context,
                                Color(0xff294052),
                              ),
                              height: height * 0.45,
                            )
                          : FractionallySizedBox(
                              widthFactor: ratio,
                              heightFactor: 1.0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: appColor(context, barColor),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
