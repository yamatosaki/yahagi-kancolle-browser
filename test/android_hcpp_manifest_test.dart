import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not enable HCPP globally for the standard rendering mode', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      isNot(contains('io.flutter.embedding.android.EnableHcpp')),
    );
  });

  test('selects HCPP before engine startup from the saved rendering mode', () {
    final activity = File(
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/MainActivity.kt',
    ).readAsStringSync();
    final policy = File(
      'android/app/src/main/kotlin/app/yahagi/kancollebrowser/GameRenderingModeHcppPolicy.kt',
    ).readAsStringSync();

    expect(activity, contains('override fun getFlutterShellArgs()'));
    expect(policy, contains('flutter.game.renderingMode'));
    expect(activity, contains('ARG_ENABLE_HCPP_AND_SURFACE_CONTROL'));
    expect(activity, contains('ARG_DISABLE_HCPP_AND_SURFACE_CONTROL'));
  });
}
