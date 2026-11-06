import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../battle/prophet_hp_bar.dart';
import '../game_state/game_state.dart';
import '../layout/flat_portrait_backdrop.dart';
import '../layout/flat_style.dart';
import '../layout/game_edge_tap_guard.dart';
import '../localization/game_name_localizations.dart';
import '../settings/battle_status_effect_settings.dart';
import '../settings/fleet_display_options.dart';
import '../theme/app_palette.dart';
import 'combat_mechanism.dart';
import 'equipment_display.dart';
import 'equipment_type_icon.dart';
import 'fleet_ship_type_label.dart';
import 'fleet_ui_strings.dart';
import 'minimal_status_glow.dart';
import 'ship_portrait.dart';
import 'ship_repair_status.dart';
import 'ship_speed_visual.dart';
import 'ship_status_style.dart';

enum MoraleBand { sparkle, normal, mild, tired, exhausted }

MoraleBand moraleBandOf(int value) => switch (value) {
  >= 50 => MoraleBand.sparkle,
  >= 40 => MoraleBand.normal,
  >= 30 => MoraleBand.mild,
  >= 20 => MoraleBand.tired,
  _ => MoraleBand.exhausted,
};

typedef _MoraleStyle = ({IconData icon, Color background, Color foreground});

_MoraleStyle _moraleStyle(MoraleBand band) => switch (band) {
  MoraleBand.sparkle => (
    icon: Icons.auto_awesome,
    background: const Color(0xff4a4214),
    foreground: const Color(0xfffff27a),
  ),
  MoraleBand.normal => (
    icon: Icons.sentiment_satisfied,
    background: const Color(0xff1f3443),
    foreground: const Color(0xffcbd5e1),
  ),
  MoraleBand.mild => (
    icon: Icons.sentiment_neutral,
    background: const Color(0xff2c3236),
    foreground: const Color(0xffe8c9a0),
  ),
  MoraleBand.tired => (
    icon: Icons.sentiment_dissatisfied,
    background: const Color(0xff4a2a12),
    foreground: shipFatigueColor(25),
  ),
  MoraleBand.exhausted => (
    icon: Icons.sentiment_very_dissatisfied,
    background: const Color(0xff4a1c1a),
    foreground: shipFatigueColor(10),
  ),
};

class MoraleChip extends StatefulWidget {
  const MoraleChip({super.key, required this.value, required this.sparkleMode});

  final int value;
  final MoraleSparkleMode sparkleMode;

  @override
  State<MoraleChip> createState() => _MoraleChipState();
}

class _MoraleChipState extends State<MoraleChip>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  bool get _sparkles =>
      widget.sparkleMode != MoraleSparkleMode.off &&
      moraleBandOf(widget.value) == MoraleBand.sparkle;

  bool get _blinks =>
      _sparkles && widget.sparkleMode == MoraleSparkleMode.blinking;

  void _syncPulse() {
    if (_blinks) {
      final pulse = _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      );
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else {
      _pulse?.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MoraleChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  BoxDecoration _decoration(
    _MoraleStyle style,
    double glow,
    AppPalette palette,
  ) => BoxDecoration(
    color: palette.color(style.background),
    borderRadius: BorderRadius.circular(3),
    boxShadow: glow > 0
        ? [
            BoxShadow(
              color: palette.color(
                const Color(0xfffff27a).withValues(alpha: 0.6 * glow),
              ),
              blurRadius: 5,
            ),
          ]
        : null,
  );

  Widget _chip(
    _MoraleStyle style,
    double glow,
    Widget child, {
    Animation<double>? animation,
  }) {
    final palette = AppPalette.of(context);
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: child,
    );
    return Container(
      height: math.max(12, MediaQuery.textScalerOf(context).scale(9)),
      constraints: const BoxConstraints(minWidth: 28),
      child: animation == null
          ? DecoratedBox(
              decoration: _decoration(style, glow, palette),
              child: padded,
            )
          : MinimalAnimatedDecoration(
              animation: animation,
              decorationBuilder: (value) =>
                  _decoration(style, 0.3 + 0.7 * value, palette),
              child: padded,
            ),
    );
  }

  Widget _content(_MoraleStyle style) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(style.icon, size: 9, color: appColor(context, style.foreground)),
      const SizedBox(width: 1),
      Text(
        '${widget.value}',
        maxLines: 1,
        style: TextStyle(
          color: appColor(context, style.foreground),
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final style = _moraleStyle(moraleBandOf(widget.value));
    final pulse = _pulse;
    final content = _content(style);
    if (!_sparkles) return _chip(style, 0, content);
    if (!_blinks || pulse == null) return _chip(style, 1, content);
    return RepaintBoundary(child: _chip(style, 0, content, animation: pulse));
  }
}

class FleetShipMinimalRow extends StatelessWidget {
  const FleetShipMinimalRow({
    super.key,
    required this.state,
    required this.ship,
    required this.visible,
    required this.shipTypeLabelMode,
    required this.damagePulseFilter,
    required this.moraleSparkleMode,
    this.repairStatus,
    this.specialAttack,
    this.onTap,
  });

  final GameState state;
  final OwnedShip ship;
  final Set<String> visible;
  final FleetShipTypeLabelMode shipTypeLabelMode;
  final DamagePulseFilter damagePulseFilter;
  final MoraleSparkleMode moraleSparkleMode;
  final ShipRepairStatus? repairStatus;
  final EquipmentMechanismDisplay? specialAttack;
  final VoidCallback? onTap;

  static const _textColor = Color(0xffdce6eb);

  bool _show(String key) => visible.contains(key);

  // 与普通档无头像时一致：疲劳值关闭后，疲劳不足与闪光仍要能看到。
  bool get _moraleWarns =>
      ship.condition < 30 ||
      (ship.condition >= 50 && moraleSparkleMode != MoraleSparkleMode.off);

  Widget _moraleChip() => MoraleChip(
    key: Key('minimal-morale-${ship.id}'),
    value: ship.condition,
    sparkleMode: moraleSparkleMode,
  );

  static double _ratio(int current, int max) =>
      max <= 0 ? 0 : (current / max).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final master = state.masterForShip(ship);
    final portrait = _show('portrait');
    final shadows = portrait ? flatOnImageShadows(context) : null;
    final statusInfo = _statusInfo(context, master);
    final hasStatus =
        statusInfo.isNotEmpty || ['hp', 'fuel', 'ammo'].any(_show);
    final lines = Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: math.max(
              16,
              MediaQuery.textScalerOf(context).scale(11) * 16 / 11,
            ),
            child: _identityLine(context, master, shadows),
          ),
          if (hasStatus) ...[
            const SizedBox(height: 1),
            _statusGrid(context, master, shadows, statusInfo),
          ],
        ],
      ),
    );
    return GameEdgeTapGuard(
      child: Material(
        key: Key('minimal-ship-row-${ship.id}'),
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: portrait
              ? FlatPortraitBackdrop(
                  image: (width, height) => _portrait(master, width, height),
                  child: lines,
                )
              : lines,
        ),
      ),
    );
  }

  Widget _portrait(MasterShip? master, double width, double height) {
    final image = ShipPortrait(
      ship: master,
      serverOrigin: state.serverOrigin,
      isDamaged: shipUsesDamagedPortrait(ship),
      width: width,
      height: height,
    );
    return repairStatus == ShipRepairStatus.retreat
        ? ColorFiltered(colorFilter: shipRetreatGrayscale, child: image)
        : image;
  }

  List<Widget> _statusInfo(BuildContext context, MasterShip? master) {
    final mechanisms = [
      ...detectShipCombatMechanisms(state, ship),
      ?specialAttack,
    ].where((_) => _show('mechanisms'));
    final speed = ShipSpeedVisual.fromSpeed(ship.effectiveSpeed(master));
    return [
      if (_show('morale') || _moraleWarns) _moraleChip(),
      if (_show('shipSpeed'))
        _Tag(
          text: fleetText(context, speed.label),
          color: speed.foreground,
          background: speed.background,
        ),
      for (final mechanism in mechanisms)
        _Tag(
          key: Key('minimal-mechanism-${ship.id}-${mechanism.kind?.name}'),
          text: fleetText(context, mechanism.effectiveShortLabel),
          color: mechanismToneColor(mechanism.tone),
        ),
      if (repairStatus != null)
        _Tag(
          key: Key('minimal-repair-${ship.id}'),
          text: fleetText(context, repairStatus!.label),
          color: switch (repairStatus!) {
            ShipRepairStatus.dock ||
            ShipRepairStatus.anchorage => const Color(0xff8edcff),
            ShipRepairStatus.retreat => const Color(0xffcbd5e1),
            ShipRepairStatus.nosakiSparkle => const Color(0xff65d493),
          },
          background: switch (repairStatus!) {
            ShipRepairStatus.dock ||
            ShipRepairStatus.anchorage => const Color(0xdd0b2738),
            ShipRepairStatus.retreat => const Color(0xdd1e293b),
            ShipRepairStatus.nosakiSparkle => const Color(0xdd0b2a1a),
          },
        ),
    ];
  }

  Widget _identityLine(
    BuildContext context,
    MasterShip? master,
    List<Shadow>? shadows,
  ) {
    final typeLabel = _show('type')
        ? fleetShipTypeShortLabel(context, state, master, shipTypeLabelMode) ??
              fleetText(context, FleetUiKeys.unknownShipType)
        : null;
    final name =
        (master == null
            ? null
            : gameNames(context).shipName(master.name, shipId: master.id)) ??
        fleetText(context, FleetUiKeys.unknownShip);
    final meta = <Widget>[
      if (_show('level'))
        Text(
          'Lv${ship.level}',
          style: TextStyle(
            color: appColor(context, flatMutedColor),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            shadows: shadows,
          ),
        ),
    ];
    final icons = _show('equipment')
        ? [
            for (final eq in state.equipmentForShip(ship))
              if (eq.master != null && eq.master!.type.length >= 4)
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: EquipmentTypeIconImage(
                    iconId: eq.master!.type[3],
                    width: 16,
                    height: 16,
                  ),
                ),
          ]
        : const <Widget>[];
    // 除舰名外每段都有宽度上限并可缩放，窄面板里只截断舰名而不会溢出。
    return LayoutBuilder(
      builder: (context, box) => Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (typeLabel != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 30),
                    child: Text(
                      typeLabel,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appColor(context, const Color(0xffa9bac4)),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        shadows: shadows,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    name,
                    key: Key('minimal-name-${ship.id}'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: appColor(context, _textColor),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      shadows: shadows,
                    ),
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * .36),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < meta.length; i++) ...[
                            if (i > 0) const SizedBox(width: 3),
                            meta[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (icons.isNotEmpty) ...[
            const SizedBox(width: 3),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * .32),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: icons),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusGrid(
    BuildContext context,
    MasterShip? master,
    List<Shadow>? shadows,
    List<Widget> statusInfo,
  ) {
    final currentHp = repairStatus == ShipRepairStatus.retreat
        ? 0
        : ship.currentHp;
    final hpRatio = _ratio(currentHp, ship.maxHp);
    final barColor = shipHpBarColor(hpRatio, isZeroHp: currentHp <= 0);
    final showBars = _show('bars');
    final hpBar = ProphetHpBar(
      key: Key('minimal-hp-track-${ship.id}'),
      value: hpRatio,
      color: appColor(context, barColor),
      backgroundColor: appColor(context, const Color(0xff294052)),
      height: 4,
    );
    Size measure(
      String text,
      TextStyle style, {
      double maxWidth = double.infinity,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: maxWidth.isFinite ? null : 1,
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    _StatusMetric metric({
      required String field,
      required Widget icon,
      required String value,
      required Color color,
      required Widget? track,
      required double minimumBarWidth,
    }) {
      final style = TextStyle(
        color: appColor(context, color),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: shadows,
      );
      final size = measure(value, style);
      Widget text = Text(
        value,
        key: Key(
          field == 'hp'
              ? 'minimal-hp-value-${ship.id}'
              : 'minimal-supply-$field-value-${ship.id}',
        ),
        style: style,
      );
      if (field == 'hp' &&
          !showBars &&
          repairStatus != ShipRepairStatus.retreat) {
        text = MinimalDamagePulseGlow(
          currentHp: currentHp,
          maxHp: ship.maxHp,
          filter: damagePulseFilter,
          normalColor: appColor(context, barColor),
          child: text,
        );
      }
      return _StatusMetric(
        icon: icon,
        value: text,
        labelWidth: 12 + size.width.ceilToDouble(),
        labelHeight: math.max(10, size.height),
        valueHeightAtWidth: (width) =>
            measure(value, style, maxWidth: width).height,
        track: track,
        minimumBarWidth: minimumBarWidth,
      );
    }

    final hp = _show('hp')
        ? metric(
            field: 'hp',
            icon: Icon(
              Icons.favorite_rounded,
              key: Key('minimal-hp-icon-${ship.id}'),
              color: appColor(context, const Color(0xffef5a5a)),
              size: 10,
              shadows: shadows,
            ),
            value: '$currentHp/${ship.maxHp}',
            color: shipHpValueColor(hpRatio, isZeroHp: currentHp <= 0),
            track: !showBars
                ? null
                : repairStatus == ShipRepairStatus.retreat
                ? hpBar
                : MinimalDamagePulseGlow(
                    currentHp: currentHp,
                    maxHp: ship.maxHp,
                    filter: damagePulseFilter,
                    normalColor: appColor(context, barColor),
                    borderRadius: BorderRadius.circular(2),
                    child: hpBar,
                  ),
            minimumBarWidth: 24,
          )
        : null;
    _StatusMetric supply(String field, int current, int max, String asset) {
      final ratio = _ratio(current, max);
      return metric(
        field: field,
        icon: Image.asset(
          asset,
          key: Key('minimal-supply-$field-icon-${ship.id}'),
          width: 10,
          height: 10,
        ),
        value: '$current/$max',
        color: shipSupplyValueColor(ratio),
        track: showBars
            ? _SupplyBar(
                key: Key('minimal-supply-$field-${ship.id}'),
                ratio: ratio,
              )
            : null,
        minimumBarWidth: 18,
      );
    }

    var fuel = _show('fuel')
        ? supply(
            'fuel',
            ship.currentFuel,
            master?.maxFuel ?? 0,
            'assets/images/material/01.png',
          )
        : null;
    var ammo = _show('ammo')
        ? supply(
            'ammo',
            ship.currentAmmo,
            master?.maxAmmo ?? 0,
            'assets/images/material/02.png',
          )
        : null;
    if (fuel != null && ammo != null) {
      final labelWidth = math.max(fuel.labelWidth, ammo.labelWidth);
      fuel = fuel.withLabelWidth(labelWidth);
      ammo = ammo.withLabelWidth(labelWidth);
    }
    final infoHeight = statusInfo.fold<double>(
      math.max(12.0, MediaQuery.textScalerOf(context).scale(9)),
      (height, item) => item is _Tag
          ? math.max(
              height,
              measure(
                    item.text,
                    const TextStyle(
                      fontSize: 8,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ).height +
                  2,
            )
          : height,
    );

    return LayoutBuilder(
      builder: (context, box) {
        final hasLeft = statusInfo.isNotEmpty || hp != null;
        final hasRight = fuel != null || ammo != null;
        final gap = hasLeft && hasRight ? 6.0 : 0.0;
        final available = box.maxWidth - gap;
        final leftWidth = hasLeft ? available * (hasRight ? .56 : 1) : 0.0;
        final rightWidth = hasRight ? available - leftWidth : 0.0;
        Widget cell(String field, _StatusMetric? metric, double width) =>
            metric == null
            ? const SizedBox.shrink()
            : SizedBox(
                key: Key('minimal-status-$field-${ship.id}'),
                width: width,
                height: metric.heightAt(width),
                child: metric.build(width),
              );
        final info = statusInfo.isEmpty
            ? const SizedBox.shrink()
            : SizedBox(
                key: Key('minimal-status-info-${ship.id}'),
                height: infoHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < statusInfo.length; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        statusInfo[i],
                      ],
                    ],
                  ),
                ),
              );
        final topRow = statusInfo.isNotEmpty || fuel != null;
        final bottomRow = hp != null || ammo != null;
        // Fixed widths keep Table from requesting intrinsic sizes of its
        // responsive children. Each row uses the taller of its two cells.
        return Table(
          columnWidths: {
            0: FixedColumnWidth(leftWidth),
            1: FixedColumnWidth(gap),
            2: FixedColumnWidth(rightWidth),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            if (topRow)
              TableRow(
                children: [
                  info,
                  const SizedBox.shrink(),
                  cell('fuel', fuel, rightWidth),
                ],
              ),
            if (topRow && bottomRow)
              const TableRow(
                children: [
                  SizedBox(height: 1),
                  SizedBox(height: 1),
                  SizedBox(height: 1),
                ],
              ),
            if (bottomRow)
              TableRow(
                children: [
                  cell('hp', hp, leftWidth),
                  const SizedBox.shrink(),
                  cell('ammo', ammo, rightWidth),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _StatusMetric {
  const _StatusMetric({
    required this.icon,
    required this.value,
    required this.labelWidth,
    required this.labelHeight,
    required this.valueHeightAtWidth,
    required this.track,
    required this.minimumBarWidth,
  });

  final Widget icon;
  final Widget value;
  final double labelWidth;
  final double labelHeight;
  final double Function(double) valueHeightAtWidth;
  final Widget? track;
  final double minimumBarWidth;

  _StatusMetric withLabelWidth(double width) => _StatusMetric(
    icon: icon,
    value: value,
    labelWidth: width,
    labelHeight: labelHeight,
    valueHeightAtWidth: valueHeightAtWidth,
    track: track,
    minimumBarWidth: minimumBarWidth,
  );

  double get minimumWidth =>
      labelWidth + (track == null ? 0 : 4 + minimumBarWidth);

  double heightAt(double width) {
    final height = math.max(
      labelHeight,
      valueHeightAtWidth(math.max(1, width - 12)),
    );
    if (track == null) return math.max(12, height);
    return width < minimumWidth ? height + 6 : math.max(12, labelHeight);
  }

  Widget _label(double width) => SizedBox(
    width: math.min(width, labelWidth),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 2),
        // 只有数字本身也放不下时才自然换行，不缩小或截断 current/max。
        Flexible(child: value),
      ],
    ),
  );

  Widget build(double width) {
    final bar = track;
    if (bar == null) return _label(width);
    if (width < minimumWidth) {
      // 数字保留原字号；大字或窄面板里让条另起一行。
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(width),
          const SizedBox(height: 2),
          SizedBox(width: width, child: bar),
        ],
      );
    }
    return Row(
      children: [
        _label(labelWidth),
        const SizedBox(width: 4),
        Expanded(child: bar),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    super.key,
    required this.text,
    required this.color,
    this.background,
  });

  final String text;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: appColor(context, background ?? color.withValues(alpha: 0.18)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      text,
      maxLines: 1,
      style: TextStyle(
        color: appColor(context, color),
        fontSize: 8,
        height: 1.1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SupplyBar extends StatelessWidget {
  const _SupplyBar({super.key, required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) => Container(
    height: 3,
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: appColor(context, const Color(0xff294052)),
      borderRadius: BorderRadius.circular(1.5),
    ),
    child: FractionallySizedBox(
      widthFactor: ratio,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appColor(context, shipSupplyBarColor(ratio)),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    ),
  );
}
