import 'package:flutter/material.dart';
import 'fleet_ui_strings.dart';

import '../settings/battle_status_effect_settings.dart';
import 'ship_damage_level.dart';
import 'ship_status_style.dart';

typedef DamagePulseWidgetBuilder =
    Widget Function(
      BuildContext context,
      DamagePulseVisualSpec spec,
      double phase,
    );

class DamagePulseBuilder extends StatefulWidget {
  const DamagePulseBuilder({
    super.key,
    required this.currentHp,
    required this.maxHp,
    required this.filter,
    required this.normalColor,
    required this.builder,
  });

  final int currentHp;
  final int maxHp;
  final DamagePulseFilter filter;
  final Color normalColor;
  final DamagePulseWidgetBuilder builder;

  @override
  State<DamagePulseBuilder> createState() => _DamagePulseBuilderState();
}

class _DamagePulseBuilderState extends State<DamagePulseBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  DamagePulseVisualSpec get _spec => damagePulseVisualSpec(
    damageLevel: shipDamageLevel(
      currentHp: widget.currentHp,
      maxHp: widget.maxHp,
    ),
    filter: widget.filter,
    normalColor: widget.normalColor,
  );

  @override
  void initState() {
    super.initState();
    final spec = _spec;
    _animation = AnimationController(vsync: this, duration: spec.duration);
    if (spec.pulses) {
      _animation.repeat();
    }
  }

  @override
  void didUpdateWidget(DamagePulseBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final spec = _spec;
    if (_animation.duration != spec.duration) {
      _animation.duration = spec.duration;
    }
    if (spec.pulses) {
      if (!_animation.isAnimating) {
        _animation.repeat();
      }
    } else {
      _animation
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    if (!spec.pulses) {
      return widget.builder(context, spec, 1);
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final trianglePhase = _animation.value <= 0.5
            ? _animation.value * 2
            : (1 - _animation.value) * 2;
        final phase = Curves.easeInOut.transform(trianglePhase);
        return widget.builder(context, spec, phase);
      },
    );
  }
}

class ShipHpFrame extends StatefulWidget {
  const ShipHpFrame({
    super.key,
    required this.shipId,
    required this.currentHp,
    required this.maxHp,
    required this.color,
    this.filter = DamagePulseFilter.all,
    this.strokeWidth = 4.0,
  });

  final int shipId;
  final int currentHp;
  final int maxHp;
  final Color color;
  final DamagePulseFilter filter;
  final double strokeWidth;

  double get ratio => maxHp <= 0 ? 0 : (currentHp / maxHp).clamp(0, 1);

  @override
  State<ShipHpFrame> createState() => _ShipHpFrameState();
}

class _ShipHpFrameState extends State<ShipHpFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  DamagePulseVisualSpec get _spec => damagePulseVisualSpec(
    damageLevel: shipDamageLevel(
      currentHp: widget.currentHp,
      maxHp: widget.maxHp,
    ),
    filter: widget.filter,
    normalColor: widget.color,
  );

  @override
  void initState() {
    super.initState();
    final spec = _spec;
    _animation = AnimationController(vsync: this, duration: spec.duration);
    if (spec.pulses) {
      _animation.repeat();
    }
  }

  @override
  void didUpdateWidget(ShipHpFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final spec = _spec;
    if (_animation.duration != spec.duration) {
      _animation.duration = spec.duration;
    }
    if (spec.pulses) {
      if (!_animation.isAnimating) {
        _animation.repeat();
      }
    } else {
      _animation.stop();
      _animation.value = 0;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    final effectiveStrokeWidth = spec.pulses
        ? widget.strokeWidth.clamp(spec.strokeWidth, double.infinity).toDouble()
        : widget.strokeWidth;
    Widget coloredFrame({double glowRadius = 1}) => CustomPaint(
      painter: _ShipHpFramePainter(
        ratio: widget.ratio,
        color: spec.color,
        glowRadius: glowRadius,
        strokeWidth: effectiveStrokeWidth,
      ),
    );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _ShipHpFramePainter(
              ratio: 1,
              color: const Color(0xff59666e),
              strokeWidth: widget.strokeWidth,
            ),
          ),
          if (spec.pulses)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final trianglePhase = _animation.value <= 0.5
                    ? _animation.value * 2
                    : (1 - _animation.value) * 2;
                final phase = Curves.easeInOut.transform(trianglePhase);
                final frameOpacity =
                    spec.minFrameOpacity + phase * (1 - spec.minFrameOpacity);
                final tintOpacity =
                    spec.minTintOpacity +
                    phase * (spec.maxTintOpacity - spec.minTintOpacity);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (spec.maxTintOpacity > 0)
                      Opacity(
                        key: Key('fleet-damage-tint-${widget.shipId}'),
                        opacity: tintOpacity,
                        child: ColoredBox(color: spec.color),
                      ),
                    Opacity(
                      key: Key('fleet-damage-pulse-${widget.shipId}'),
                      opacity: frameOpacity,
                      child: coloredFrame(
                        glowRadius: 0.5 + phase * (spec.maxGlowRadius - 0.5),
                      ),
                    ),
                  ],
                );
              },
            )
          else if (widget.ratio > 0)
            coloredFrame(),
        ],
      ),
    );
  }
}

class _ShipHpFramePainter extends CustomPainter {
  const _ShipHpFramePainter({
    required this.ratio,
    required this.color,
    this.glowRadius = 0,
    this.strokeWidth = 4.0,
  });

  final double ratio;
  final Color color;
  final double glowRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || ratio <= 0) return;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(-2, -2, size.width + 4, size.height + 4),
      const Radius.circular(12),
    );
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        -16,
        -16,
        ratio >= 1 ? size.width + 16 : size.width * ratio,
        size.height + 16,
      ),
    );
    if (glowRadius > 0) {
      canvas.drawRRect(
        frame,
        Paint()
          ..color = color.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius),
      );
    }
    canvas.drawRRect(
      frame,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShipHpFramePainter oldDelegate) =>
      ratio != oldDelegate.ratio ||
      color != oldDelegate.color ||
      glowRadius != oldDelegate.glowRadius ||
      strokeWidth != oldDelegate.strokeWidth;
}

enum ShipMoraleMarkLayout { detail, brief }

enum FatigueFaceLevel { yellow, red }

class FatigueFace extends StatelessWidget {
  const FatigueFace({
    super.key,
    required this.level,
    required this.size,
    this.faceKey,
  });

  final FatigueFaceLevel level;
  final double size;
  final Key? faceKey;

  @override
  Widget build(BuildContext context) {
    final danger = level == FatigueFaceLevel.red;
    final color = danger ? const Color(0xffef5a5a) : const Color(0xffe7ad45);
    return Container(
      key: faceKey,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xfff6ead1), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 5),
        ],
      ),
      child: Icon(
        danger
            ? Icons.sentiment_very_dissatisfied_rounded
            : Icons.sentiment_dissatisfied_rounded,
        color: const Color(0xff3a2a20),
        size: size * 0.79,
      ),
    );
  }
}

class ShipMoraleMark extends StatelessWidget {
  const ShipMoraleMark({
    super.key,
    required this.shipId,
    required this.value,
    required this.sparklePulse,
    this.sparkleEnabled = true,
    this.showTextBadge = true,
    this.repairLabel,
    this.layout = ShipMoraleMarkLayout.brief,
  });

  final int shipId;
  final int value;
  final Animation<double> sparklePulse;
  final bool sparkleEnabled;
  final bool showTextBadge;
  final String? repairLabel;
  final ShipMoraleMarkLayout layout;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final badgeHeight = (constraints.maxHeight * 0.3)
            .clamp(14.0, 18.0)
            .toDouble();
        final badgeFont = (constraints.maxHeight * 0.16)
            .clamp(7.0, 10.0)
            .toDouble();
        final badgeWidth = badgeHeight * 3.68;
        final repairBadgeHeight = (constraints.maxHeight * 0.23)
            .clamp(12.0, 15.0)
            .toDouble();
        final repairBadgeWidth = repairBadgeHeight * 2.8;
        final isDetail = layout == ShipMoraleMarkLayout.detail;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (sparkleEnabled && value >= 50)
              _ShipSparkleLayer(shipId: shipId, animation: sparklePulse),
            if (value < 30)
              _fatigueFace(constraints.maxHeight, placeOnLeft: isDetail),
            if (repairLabel != null)
              Positioned(
                right: isDetail ? 5 : 0,
                top: isDetail ? 4 : null,
                bottom: isDetail ? null : 0,
                child: Container(
                  key: Key('fleet-repair-badge-$shipId'),
                  height: isDetail ? badgeHeight : repairBadgeHeight,
                  width: isDetail ? badgeWidth : repairBadgeWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        (isDetail ? badgeHeight : repairBadgeHeight) * 0.34,
                  ),
                  decoration: BoxDecoration(
                    color: repairLabel == '退避'
                        ? const Color(0xdd1e293b)
                        : (repairLabel == '刷闪'
                              ? const Color(0xdd0b2a1a)
                              : const Color(0xdd0b2738)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: repairLabel == '退避'
                          ? const Color(0xff64748b)
                          : (repairLabel == '刷闪'
                                ? const Color(0xc965d493)
                                : const Color(0xc963c7ee)),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99000000), blurRadius: 4),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      fleetText(context, repairLabel!),
                      maxLines: 1,
                      style: TextStyle(
                        color: repairLabel == '退避'
                            ? const Color(0xffcbd5e1)
                            : (repairLabel == '刷闪'
                                  ? const Color(0xff65d493)
                                  : const Color(0xff8edcff)),
                        fontSize: badgeFont,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            if (showTextBadge)
              Positioned(
                right: 5,
                bottom: 4,
                child: Container(
                  key: Key('fleet-fatigue-badge-$shipId'),
                  height: badgeHeight,
                  width: badgeWidth,
                  padding: EdgeInsets.symmetric(horizontal: badgeHeight * 0.34),
                  decoration: BoxDecoration(
                    color: const Color(0xdd07131d),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: shipFatigueColor(value).withValues(alpha: 0.78),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99000000), blurRadius: 4),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: fleetText(context, '疲劳 '),
                            style: TextStyle(
                              color: shipFatigueColor(value),
                              fontSize: badgeFont,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: '$value',
                            style: TextStyle(
                              color: shipFatigueColor(value),
                              fontSize: badgeFont + 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _fatigueFace(double height, {required bool placeOnLeft}) {
    final danger = value <= 19;
    final size = placeOnLeft
        ? (height * 0.42).clamp(18.0, 24.0).toDouble()
        : (height * 0.34).clamp(14.0, 20.0).toDouble();
    return Positioned(
      left: placeOnLeft ? 4 : null,
      right: placeOnLeft ? null : 4,
      top: placeOnLeft ? 4 : 0,
      child: FatigueFace(
        level: danger ? FatigueFaceLevel.red : FatigueFaceLevel.yellow,
        size: size,
        faceKey: Key('fleet-fatigue-face-$value'),
      ),
    );
  }
}

class _ShipSparkleLayer extends StatelessWidget {
  const _ShipSparkleLayer({required this.shipId, required this.animation});

  static const points = <({double x, double y, double size})>[
    (x: 0.07, y: 0.18, size: 10),
    (x: 0.21, y: 0.58, size: 6),
    (x: 0.31, y: 0.29, size: 8),
    (x: 0.69, y: 0.68, size: 7),
    (x: 0.80, y: 0.22, size: 11),
    (x: 0.91, y: 0.48, size: 6),
  ];

  final int shipId;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final phase = animation.value;
      final opacity = switch (phase) {
        < 0.16 => 0.0,
        < 0.24 => (phase - 0.16) / 0.08,
        < 0.31 => 1.0,
        < 0.38 => 1 - (phase - 0.31) / 0.07,
        _ => 0.0,
      };
      final scale = 0.55 + opacity * 0.7;
      return LayoutBuilder(
        builder: (context, constraints) => Stack(
          key: Key('fleet-morale-stars-$shipId'),
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < points.length; index++)
              Positioned(
                left:
                    constraints.maxWidth * points[index].x -
                    points[index].size / 2,
                top:
                    constraints.maxHeight * points[index].y -
                    points[index].size / 2,
                child: Transform.scale(
                  key: Key('fleet-sparkle-$shipId-$index'),
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Icon(
                      index.isEven
                          ? Icons.auto_awesome_rounded
                          : Icons.star_rounded,
                      size: points[index].size,
                      color: const Color(0xfffff7a4),
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 3),
                        Shadow(color: Color(0xffffcf3f), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
