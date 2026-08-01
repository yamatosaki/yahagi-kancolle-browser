import 'package:flutter/services.dart';

typedef PreferredOrientationsSetter =
    Future<void> Function(List<DeviceOrientation> orientations);

class ScreenOrientationApplier {
  ScreenOrientationApplier({
    PreferredOrientationsSetter? setPreferredOrientations,
  }) : _setPreferredOrientations =
           setPreferredOrientations ?? SystemChrome.setPreferredOrientations;

  final PreferredOrientationsSetter _setPreferredOrientations;

  Future<void> apply({required bool autoLandscape}) {
    return _setPreferredOrientations(
      autoLandscape
          ? const <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const <DeviceOrientation>[],
    );
  }
}
