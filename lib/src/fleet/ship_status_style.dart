import 'package:flutter/material.dart';

const yahagiStatusRed = Color(0xffd33d17);
const yahagiStatusOrange = Color(0xfff57c00);
const yahagiStatusYellow = Color(0xffffc940);
const yahagiStatusGreen = Color(0xff29a634);
const yahagiStatusZeroHp = Color(0xff71818b);

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
