import 'package:flutter/material.dart';
import 'fleet_ui_strings.dart';

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
    this.moraleSparkleEnabled = true,
    this.repairStatus,
    this.specialAttack,
    this.onTap,
  });

  final GameState state;
  final OwnedShip ship;
  final DamagePulseFilter damagePulseFilter;
  final bool moraleSparkleEnabled;
  final ShipRepairStatus? repairStatus;
  final EquipmentMechanismDisplay? specialAttack;
  final VoidCallback? onTap;

  @override
  State<FleetShipStatusCapsule> createState() => _FleetShipStatusCapsuleState();
}

class _FleetShipStatusCapsuleState extends State<FleetShipStatusCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparklePulse;

  @override
  void initState() {
    super.initState();
    _sparklePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
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
    final type = state.masterShipTypes[master?.shipTypeId];
    final hpRatio = _ratio(ship.currentHp, ship.maxHp);
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

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xff1c3547), // Brighter background
            border: Border.all(
              color: const Color(0xff4c6b84),
              width: 1.2,
            ), // Brighter & slightly thicker border
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45, // Stronger shadow
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
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
                    final portraitWidth = (identityConstraints.maxWidth * 0.35)
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
                        // Top Badges Row and Equipment Icons
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MiniBadge(
                                      text: 'Lv. ${ship.level}',
                                      color: const Color(0xffa9bac4),
                                    ),
                                    const SizedBox(width: 4),
                                    MiniBadge(
                                      text:
                                          type?.name ??
                                          fleetText(context, '未知舰种'),
                                      color: const Color(0xffa9bac4),
                                    ),
                                    const SizedBox(width: 4),
                                    MiniBadge(
                                      key: Key('fleet-focus-speed-${ship.id}'),
                                      text: fleetText(
                                        context,
                                        ShipSpeedVisual.fromSpeed(
                                          ship.effectiveSpeed(master),
                                        ).label,
                                      ),
                                      color: ShipSpeedVisual.fromSpeed(
                                        ship.effectiveSpeed(master),
                                      ).foreground,
                                    ),
                                    const SizedBox(width: 4),
                                    MiniBadge(
                                      text: fleetText(
                                        context,
                                        '疲劳 ${ship.condition}',
                                      ),
                                      color: shipFatigueColor(ship.condition),
                                    ),
                                    for (
                                      var i = 0;
                                      i < allMechanisms.length;
                                      i++
                                    ) ...<Widget>[
                                      const SizedBox(width: 4),
                                      MiniBadge(
                                        key: Key(
                                          i == 0
                                              ? 'fleet-focus-mechanism-${ship.id}'
                                              : 'fleet-focus-mechanism-${ship.id}-$i',
                                        ),
                                        text: allMechanisms[i]
                                            .effectiveShortLabel,
                                        color: _mechanismColor(
                                          allMechanisms[i].tone,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (equipment.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final eq in equipment)
                                    if (eq.master != null &&
                                        eq.master!.type.length >= 4)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: EquipmentTypeIconImage(
                                          iconId: eq.master!.type[3],
                                          width: 16,
                                          height: 16,
                                          filterQuality: FilterQuality.medium,
                                        ),
                                      ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Avatar and Status Info Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              key: Key('fleet-focus-portrait-${ship.id}'),
                              width: portraitWidth,
                              height: portraitHeight,
                              child: Stack(
                                fit: StackFit.expand,
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child:
                                          widget.repairStatus ==
                                              ShipRepairStatus.retreat
                                          ? ColorFiltered(
                                              colorFilter:
                                                  const ColorFilter.matrix(
                                                    <double>[
                                                      0.2126,
                                                      0.7152,
                                                      0.0722,
                                                      0,
                                                      0,
                                                      0.2126,
                                                      0.7152,
                                                      0.0722,
                                                      0,
                                                      0,
                                                      0.2126,
                                                      0.7152,
                                                      0.0722,
                                                      0,
                                                      0,
                                                      0,
                                                      0,
                                                      0,
                                                      1,
                                                      0,
                                                    ],
                                                  ),
                                              child: ShipPortrait(
                                                ship: master,
                                                serverOrigin:
                                                    state.serverOrigin,
                                                width: portraitWidth,
                                                height: portraitHeight,
                                              ),
                                            )
                                          : ShipPortrait(
                                              ship: master,
                                              serverOrigin: state.serverOrigin,
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
                                    color:
                                        widget.repairStatus ==
                                            ShipRepairStatus.retreat
                                        ? yahagiStatusZeroHp
                                        : shipHpBarColor(
                                            hpRatio,
                                            isZeroHp: ship.currentHp <= 0,
                                          ),
                                    filter: widget.damagePulseFilter,
                                    strokeWidth: 2.0,
                                  ),
                                  ShipMoraleMark(
                                    key: Key(
                                      'fleet-summary-morale-mark-${ship.id}',
                                    ),
                                    shipId: ship.id,
                                    value: ship.condition,
                                    sparklePulse: _sparklePulse,
                                    sparkleEnabled: widget.moraleSparkleEnabled,
                                    showTextBadge: false,
                                    repairLabel: widget.repairStatus?.label,
                                    layout: ShipMoraleMarkLayout.brief,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: sectionGap),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          master?.name ??
                                              fleetText(context, '未知舰娘'),
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            fontSize: narrow
                                                ? 11
                                                : (compact ? 14 : 17),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: sectionGap),
                                      Expanded(
                                        child: CompactStatusMeter(
                                          height: meterHeight,
                                          icon: Image.asset(
                                            'assets/images/material/01.png',
                                            width: 10,
                                            height: 10,
                                          ),
                                          value:
                                              '${ship.currentFuel}/${master?.maxFuel ?? 0}',
                                          ratio: fuelRatio,
                                          valueColor: shipSupplyValueColor(
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
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CompactStatusMeter(
                                          height: meterHeight,
                                          icon: Icon(
                                            Icons.favorite_rounded,
                                            key: Key(
                                              'fleet-focus-hp-icon-${ship.id}',
                                            ),
                                            color: const Color(0xffef5a5a),
                                            size: 10,
                                          ),
                                          value:
                                              '${ship.currentHp}/${ship.maxHp}',
                                          ratio: hpRatio,
                                          valueColor: shipHpValueColor(
                                            hpRatio,
                                            isZeroHp: ship.currentHp <= 0,
                                          ),
                                          barColor: shipHpBarColor(
                                            hpRatio,
                                            isZeroHp: ship.currentHp <= 0,
                                          ),
                                          valueKey: Key(
                                            'fleet-focus-hp-value-${ship.id}',
                                          ),
                                          trackKey: Key(
                                            'fleet-focus-hp-track-${ship.id}',
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: sectionGap),
                                      Expanded(
                                        child: CompactStatusMeter(
                                          height: meterHeight,
                                          icon: Image.asset(
                                            'assets/images/material/02.png',
                                            width: 10,
                                            height: 10,
                                          ),
                                          value:
                                              '${ship.currentAmmo}/${master?.maxAmmo ?? 0}',
                                          ratio: ammoRatio,
                                          valueColor: shipSupplyValueColor(
                                            ammoRatio,
                                          ),
                                          barColor: shipSupplyBarColor(
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
                                    ],
                                  ),
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
        );
      },
    );
  }
}

Color _mechanismColor(MechanismTone tone) => switch (tone) {
  MechanismTone.antiAir => const Color(0xffffc861),
  MechanismTone.specialAttack => const Color(0xffff8b88),
  MechanismTone.nightAttack => const Color(0xffbfa4ff),
  MechanismTone.neutral ||
  MechanismTone.antiSubmarine => const Color(0xff8ec6e8),
};

class MiniBadge extends StatelessWidget {
  const MiniBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
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
  });

  final double height;
  final Widget icon;
  final String value;
  final double ratio;
  final Color valueColor;
  final Color barColor;
  final Key? valueKey;
  final Key? trackKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(width: 12, child: Center(child: icon)),
          const SizedBox(width: 4),
          SizedBox(
            width: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: valueKey,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: FractionallySizedBox(
              heightFactor: 0.45,
              child: Container(
                key: trackKey,
                decoration: BoxDecoration(
                  color: const Color(0xff294052),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio,
                  heightFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
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
}
