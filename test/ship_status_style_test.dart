import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_style.dart';

void main() {
  test('uses Yahagi health thresholds at every boundary', () {
    expect(shipHpColor(0.25), const Color(0xffd33d17));
    expect(shipHpColor(0.2501), const Color(0xfff57c00));
    expect(shipHpColor(0.50), const Color(0xfff57c00));
    expect(shipHpColor(0.5001), const Color(0xffffc940));
    expect(shipHpColor(0.75), const Color(0xffffc940));
    expect(shipHpColor(0.7501), const Color(0xff29a634));
  });

  test('uses Yahagi supply thresholds at every boundary', () {
    expect(shipSupplyColor(0.50), const Color(0xffd33d17));
    expect(shipSupplyColor(0.5001), const Color(0xfff57c00));
    expect(shipSupplyColor(0.75), const Color(0xfff57c00));
    expect(shipSupplyColor(0.7501), const Color(0xffffc940));
    expect(shipSupplyColor(0.9999), const Color(0xffffc940));
    expect(shipSupplyColor(1), const Color(0xff29a634));
  });

  test('uses Yahagi fatigue bands', () {
    expect(shipFatigueColor(19), const Color(0xffdd514c));
    expect(shipFatigueColor(20), const Color(0xfff37b1d));
    expect(shipFatigueColor(30), const Color(0xffffc880));
    expect(shipFatigueColor(40), Colors.white);
    expect(shipFatigueColor(50), const Color(0xffffee00));
    expect(shipFatigueColor(53), const Color(0xffffff40));
  });
}
