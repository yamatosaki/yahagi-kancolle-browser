import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_speed_visual.dart';

void main() {
  test('maps all implemented ship speed tiers and their capsule colors', () {
    expect(ShipSpeedVisual.fromSpeed(5).label, '低速');
    expect(ShipSpeedVisual.fromSpeed(10).label, '高速');
    expect(ShipSpeedVisual.fromSpeed(15).label, '高速+');
    expect(ShipSpeedVisual.fromSpeed(20).label, '最速');

    expect(ShipSpeedVisual.fromSpeed(5).foreground, const Color(0xffffcf67));
    for (final speed in <int>[10, 15, 20]) {
      expect(
        ShipSpeedVisual.fromSpeed(speed).foreground,
        const Color(0xff7ed8cf),
      );
    }
  });
}
