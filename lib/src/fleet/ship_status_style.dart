import 'package:flutter/material.dart';

const yahagiStatusRed = Color(0xffd33d17);
const yahagiStatusOrange = Color(0xfff57c00);
const yahagiStatusYellow = Color(0xffffc940);
const yahagiStatusGreen = Color(0xff29a634);

Color shipHpColor(double ratio) {
  if (ratio <= 0.25) {
    return yahagiStatusRed;
  }
  if (ratio <= 0.50) {
    return yahagiStatusOrange;
  }
  if (ratio <= 0.75) {
    return yahagiStatusYellow;
  }
  return yahagiStatusGreen;
}

Color shipSupplyColor(double ratio) {
  if (ratio <= 0.50) {
    return yahagiStatusRed;
  }
  if (ratio <= 0.75) {
    return yahagiStatusOrange;
  }
  if (ratio < 1) {
    return yahagiStatusYellow;
  }
  return yahagiStatusGreen;
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
