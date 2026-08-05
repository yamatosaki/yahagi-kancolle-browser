import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/orientation_policy.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';

void main() {
  test('自动：手机与折叠屏外屏强制横屏', () {
    expect(
      preferredOrientationsFor(const Size(412, 915), DisplayMode.auto),
      <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    expect(
      preferredOrientationsFor(const Size(914, 411), DisplayMode.auto),
      <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
  });

  test('自动：近似正方形折叠屏保持竖向布局并跟随四向旋转', () {
    expect(
      preferredOrientationsFor(const Size(673, 841), DisplayMode.auto),
      <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeRight,
      ],
    );
  });

  test('自动：宽矩形折叠屏与平板跟随四向旋转', () {
    expect(
      preferredOrientationsFor(const Size(1280, 800), DisplayMode.auto),
      <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeRight,
      ],
    );
    expect(
      preferredOrientationsFor(const Size(800, 1280), DisplayMode.auto),
      <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeRight,
      ],
    );
  });

  test('强制横屏与强制竖屏覆盖自动判断', () {
    expect(
      preferredOrientationsFor(const Size(673, 841), DisplayMode.landscape),
      <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    expect(
      preferredOrientationsFor(const Size(412, 915), DisplayMode.portrait),
      <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
  });
}
