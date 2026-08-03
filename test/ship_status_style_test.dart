import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_style.dart';

void main() {
  test('uses damage colors for HP bars and white healthy values', () {
    expect(shipHpBarColor(0.25), const Color(0xffd33d17));
    expect(shipHpValueColor(0.25), const Color(0xffd33d17));
    expect(shipHpBarColor(0.2501), const Color(0xfff57c00));
    expect(shipHpValueColor(0.50), const Color(0xfff57c00));
    expect(shipHpBarColor(0.5001), const Color(0xffffc940));
    expect(shipHpValueColor(0.75), const Color(0xffffc940));
    expect(shipHpBarColor(0.7501), yahagiStatusGreen);
    expect(shipHpValueColor(0.7501), Colors.white);
  });

  test('uses damage colors for supply bars and white healthy values', () {
    expect(shipSupplyBarColor(0.25), const Color(0xffd33d17));
    expect(shipSupplyValueColor(0.25), const Color(0xffd33d17));
    expect(shipSupplyBarColor(0.2501), const Color(0xfff57c00));
    expect(shipSupplyValueColor(0.50), const Color(0xfff57c00));
    expect(shipSupplyBarColor(0.5001), const Color(0xffffc940));
    expect(shipSupplyValueColor(0.75), const Color(0xffffc940));
    expect(shipSupplyBarColor(0.7501), yahagiStatusGreen);
    expect(shipSupplyValueColor(0.7501), Colors.white);
    expect(shipSupplyBarColor(1), yahagiStatusGreen);
    expect(shipSupplyValueColor(1), Colors.white);
  });

  test('heavy damage uses the exact game quarter-HP boundary', () {
    expect(isShipHeavilyDamaged(currentHp: 25, maxHp: 100), isTrue);
    expect(isShipHeavilyDamaged(currentHp: 26, maxHp: 100), isFalse);
    expect(isShipHeavilyDamaged(currentHp: 8, maxHp: 33), isTrue);
    expect(isShipHeavilyDamaged(currentHp: 9, maxHp: 33), isFalse);
    expect(isShipHeavilyDamaged(currentHp: 0, maxHp: 33), isFalse);
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
