import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_orientation.dart';

void main() {
  test('自动横屏允许左右两个横屏方向', () async {
    List<DeviceOrientation>? applied;
    final applier = ScreenOrientationApplier(
      setPreferredOrientations: (orientations) async {
        applied = orientations;
      },
    );

    await applier.apply(autoLandscape: true);

    expect(applied, <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  });

  test('关闭自动横屏时清空限制并跟随系统', () async {
    List<DeviceOrientation>? applied;
    final applier = ScreenOrientationApplier(
      setPreferredOrientations: (orientations) async {
        applied = orientations;
      },
    );

    await applier.apply(autoLandscape: false);

    expect(applied, isEmpty);
  });

  test('布局设置首次加载时默认开启并应用自动横屏', () async {
    final store = _MemoryLayoutSettingsStore();
    final calls = <List<DeviceOrientation>>[];

    final controller = await LayoutSettingsController.load(
      store,
      orientationApplier: ScreenOrientationApplier(
        setPreferredOrientations: (orientations) async {
          calls.add(orientations);
        },
      ),
    );

    expect(controller.autoLandscape, isTrue);
    expect(calls, <List<DeviceOrientation>>[
      <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ]);
  });

  test('切换为跟随系统时立即应用并保存', () async {
    final store = _MemoryLayoutSettingsStore();
    final calls = <List<DeviceOrientation>>[];
    final controller = await LayoutSettingsController.load(
      store,
      orientationApplier: ScreenOrientationApplier(
        setPreferredOrientations: (orientations) async {
          calls.add(orientations);
        },
      ),
    );

    await controller.setAutoLandscape(false);

    expect(controller.autoLandscape, isFalse);
    expect(store.autoLandscape, isFalse);
    expect(calls.last, isEmpty);
  });
}

class _MemoryLayoutSettingsStore implements LayoutSettingsStore {
  bool autoLandscape = true;

  @override
  Future<bool> loadAutoLandscape() async => autoLandscape;

  @override
  Future<void> saveAutoLandscape(bool value) async => autoLandscape = value;

  @override
  Future<bool> loadAutoZoom() async => true;

  @override
  Future<List<String>> loadDashboardCardCollapsed() async => <String>[];

  @override
  Future<List<String>> loadDashboardCardOrder() async => <String>[];

  @override
  Future<String?> loadFontFamily() async => null;

  @override
  Future<double> loadGameAreaRatio() async => 0.65;

  @override
  Future<double> loadInformationPanelWidth() async => 390;

  @override
  Future<String?> loadLocaleCode() async => null;

  @override
  Future<void> saveAutoZoom(bool autoZoom) async {}

  @override
  Future<void> saveDashboardCardCollapsed(List<String> collapsedIds) async {}

  @override
  Future<void> saveDashboardCardOrder(List<String> order) async {}

  @override
  Future<void> saveFontFamily(String? fontFamily) async {}

  @override
  Future<void> saveGameAreaRatio(double ratio) async {}

  @override
  Future<void> saveInformationPanelWidth(double width) async {}

  @override
  Future<void> saveLocaleCode(String? localeCode) async {}
}
