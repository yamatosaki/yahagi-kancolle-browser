import 'package:flutter/widgets.dart';

enum UiFontSize {
  system,
  small,
  medium,
  large;

  /// Manual presets replace system scaling; default keeps the original scaler.
  TextScaler resolveTextScaler(TextScaler systemScaler) => switch (this) {
    system => systemScaler,
    small => const TextScaler.linear(0.8),
    medium => TextScaler.noScaling,
    large => const TextScaler.linear(1.25),
  };
}
