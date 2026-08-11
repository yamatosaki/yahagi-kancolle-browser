import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_style.dart';

void main() {
  test('normal damage pulse preserves the original shared visual settings', () {
    for (final ratio in <double>[0.65, 0.42, 0.18]) {
      final spec = damagePulseVisualSpec(
        hpRatio: ratio,
        mode: DamagePulseMode.normal,
        normalColor: shipHpBarColor(ratio),
      );

      expect(spec.pulses, isTrue);
      expect(spec.duration, const Duration(milliseconds: 2400));
      expect(spec.minFrameOpacity, 0.35);
      expect(spec.maxGlowRadius, 11);
      expect(spec.maxTintOpacity, 0);
      expect(spec.color, shipHpBarColor(ratio));
    }
  });

  test('enhanced damage pulse separates minor moderate and heavy damage', () {
    final minor = damagePulseVisualSpec(
      hpRatio: 0.65,
      mode: DamagePulseMode.enhanced,
      normalColor: shipHpBarColor(0.65),
    );
    final moderate = damagePulseVisualSpec(
      hpRatio: 0.42,
      mode: DamagePulseMode.enhanced,
      normalColor: shipHpBarColor(0.42),
    );
    final heavy = damagePulseVisualSpec(
      hpRatio: 0.18,
      mode: DamagePulseMode.enhanced,
      normalColor: shipHpBarColor(0.18),
    );

    expect(minor.color, const Color(0xffffd34f));
    expect(moderate.color, const Color(0xffff8418));
    expect(heavy.color, const Color(0xffff2933));
    expect(minor.duration, const Duration(milliseconds: 2200));
    expect(moderate.duration, const Duration(milliseconds: 1450));
    expect(heavy.duration, const Duration(milliseconds: 760));
    expect(minor.maxTintOpacity, lessThan(moderate.maxTintOpacity));
    expect(moderate.maxTintOpacity, lessThan(heavy.maxTintOpacity));
    expect(heavy.strokeWidth, 4);
  });

  test('healthy and zero HP ships do not pulse', () {
    expect(
      damagePulseVisualSpec(
        hpRatio: 0.76,
        mode: DamagePulseMode.enhanced,
        normalColor: yahagiStatusGreen,
      ).pulses,
      isFalse,
    );
    expect(
      damagePulseVisualSpec(
        hpRatio: 0,
        mode: DamagePulseMode.enhanced,
        normalColor: yahagiStatusZeroHp,
      ).pulses,
      isFalse,
    );
  });

  test('uses damage colors for HP bars and white healthy values', () {
    expect(shipHpBarColor(0, isZeroHp: true), const Color(0xff71818b));
    expect(shipHpValueColor(0, isZeroHp: true), const Color(0xff71818b));
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
