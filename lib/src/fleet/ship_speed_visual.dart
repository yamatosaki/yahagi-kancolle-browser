import 'package:flutter/material.dart';

class ShipSpeedVisual {
  const ShipSpeedVisual({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  factory ShipSpeedVisual.fromSpeed(int speed) {
    final label = switch (speed) {
      >= 20 => '最速',
      >= 15 => '高速+',
      >= 10 => '高速',
      _ => '低速',
    };
    final fast = speed >= 10;
    return ShipSpeedVisual(
      label: label,
      foreground: fast ? const Color(0xff7ed8cf) : const Color(0xffffcf67),
      background: fast ? const Color(0xff164c48) : const Color(0xff5b4829),
    );
  }
}
