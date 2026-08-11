import 'package:flutter/material.dart';

const yahagiStatusRed = Color(0xffd33d17);
const yahagiStatusOrange = Color(0xfff57c00);
const yahagiStatusYellow = Color(0xffffc940);
const yahagiStatusGreen = Color(0xff29a634);
const yahagiStatusZeroHp = Color(0xff71818b);

enum DamagePulseMode { normal, enhanced }

@immutable
class DamagePulseVisualSpec {
  const DamagePulseVisualSpec({
    required this.pulses,
    required this.color,
    required this.duration,
    required this.minFrameOpacity,
    required this.maxGlowRadius,
    required this.minTintOpacity,
    required this.maxTintOpacity,
    required this.strokeWidth,
  });

  final bool pulses;
  final Color color;
  final Duration duration;
  final double minFrameOpacity;
  final double maxGlowRadius;
  final double minTintOpacity;
  final double maxTintOpacity;
  final double strokeWidth;
}

DamagePulseVisualSpec damagePulseVisualSpec({
  required double hpRatio,
  required DamagePulseMode mode,
  required Color normalColor,
}) {
  final pulses = hpRatio > 0 && hpRatio <= 0.75;
  if (mode == DamagePulseMode.normal || !pulses) {
    return DamagePulseVisualSpec(
      pulses: pulses,
      color: normalColor,
      duration: const Duration(milliseconds: 2400),
      minFrameOpacity: 0.35,
      maxGlowRadius: 11,
      minTintOpacity: 0,
      maxTintOpacity: 0,
      strokeWidth: 4,
    );
  }
  if (hpRatio <= 0.25) {
    return const DamagePulseVisualSpec(
      pulses: true,
      color: Color(0xffff2933),
      duration: Duration(milliseconds: 760),
      minFrameOpacity: 0.58,
      maxGlowRadius: 21,
      minTintOpacity: 0.075,
      maxTintOpacity: 0.24,
      strokeWidth: 4,
    );
  }
  if (hpRatio <= 0.50) {
    return const DamagePulseVisualSpec(
      pulses: true,
      color: Color(0xffff8418),
      duration: Duration(milliseconds: 1450),
      minFrameOpacity: 0.46,
      maxGlowRadius: 14,
      minTintOpacity: 0.045,
      maxTintOpacity: 0.16,
      strokeWidth: 3,
    );
  }
  return const DamagePulseVisualSpec(
    pulses: true,
    color: Color(0xffffd34f),
    duration: Duration(milliseconds: 2200),
    minFrameOpacity: 0.38,
    maxGlowRadius: 9,
    minTintOpacity: 0.025,
    maxTintOpacity: 0.10,
    strokeWidth: 3,
  );
}

Color _fourBandColor(double ratio, Color healthyColor) {
  if (ratio <= 0.25) {
    return yahagiStatusRed;
  }
  if (ratio <= 0.50) {
    return yahagiStatusOrange;
  }
  if (ratio <= 0.75) {
    return yahagiStatusYellow;
  }
  return healthyColor;
}

Color shipHpBarColor(double ratio, {bool isZeroHp = false}) =>
    isZeroHp ? yahagiStatusZeroHp : _fourBandColor(ratio, yahagiStatusGreen);

Color shipHpValueColor(double ratio, {bool isZeroHp = false}) =>
    isZeroHp ? yahagiStatusZeroHp : _fourBandColor(ratio, Colors.white);

Color shipSupplyBarColor(double ratio) =>
    _fourBandColor(ratio, yahagiStatusGreen);

Color shipSupplyValueColor(double ratio) => _fourBandColor(ratio, Colors.white);

bool isShipHeavilyDamaged({required int currentHp, required int maxHp}) {
  return currentHp > 0 && maxHp > 0 && currentHp * 4 <= maxHp;
}

Color shipFatigueColor(int fatigue) {
  if (fatigue < 20) {
    return const Color(0xffdd514c);
  }
  if (fatigue < 30) {
    return const Color(0xfff37b1d);
  }
  if (fatigue < 40) {
    return const Color(0xffffc880);
  }
  if (fatigue < 50) {
    return Colors.white;
  }
  if (fatigue < 53) {
    return const Color(0xffffee00);
  }
  return const Color(0xffffff40);
}
