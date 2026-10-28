import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Verify both failed platform writes and the SharedPreferences cache.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_font_size.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('default preserves the original nonlinear system scaler', () {
    const systemScaler = _NonlinearTextScaler();
    expect(
      UiFontSize.system.resolveTextScaler(systemScaler),
      same(systemScaler),
    );
    expect(systemScaler.scale(12), 24);
    expect(systemScaler.scale(24), 36);
  });

  for (final (mode, factor) in [
    (UiFontSize.small, 0.8),
    (UiFontSize.medium, 1.0),
    (UiFontSize.large, 1.25),
  ]) {
    test('$mode is fixed independently of system scaling', () {
      for (final systemScaler in <TextScaler>[
        TextScaler.noScaling,
        const TextScaler.linear(2),
        const _NonlinearTextScaler(),
      ]) {
        final scaler = mode.resolveTextScaler(systemScaler);
        expect(scaler.scale(12), closeTo(12 * factor, 0.0001));
        expect(scaler.scale(24), closeTo(24 * factor, 0.0001));
      }
    });
  }

  for (final saved in <Object?>[null, 'unknown', 123]) {
    test('missing or invalid stored font size $saved follows system', () async {
      SharedPreferences.setMockInitialValues({'layout_ui_font_size': ?saved});
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      expect(controller.uiFontSize, UiFontSize.system);
    });
  }

  test(
    'all selections notify immediately and survive controller reload',
    () async {
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);
      for (final mode in [
        UiFontSize.small,
        UiFontSize.medium,
        UiFontSize.large,
        UiFontSize.system,
      ]) {
        final before = notifications;
        final save = controller.setUiFontSize(mode);
        expect(controller.uiFontSize, mode);
        expect(notifications, before + 1);
        await save;
        expect(
          (await SharedPreferences.getInstance()).getString(
            'layout_ui_font_size',
          ),
          mode.name,
        );
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.uiFontSize, mode);
        restored.dispose();
        await controller.setUiFontSize(mode);
        expect(notifications, before + 1);
      }
    },
  );

  test('rapid selections commit in order and keep the final choice', () async {
    final store = _DelayedFontSizeStore();
    final controller = await LayoutSettingsController.load(store);
    addTearDown(controller.dispose);
    final first = controller.setUiFontSize(UiFontSize.small);
    final second = controller.setUiFontSize(UiFontSize.large);
    expect(controller.uiFontSize, UiFontSize.large);
    await Future.wait([first, second]);
    expect(store.saved, UiFontSize.large);
    expect(store.maximumConcurrentWrites, 1);
  });

  for (final throwsOnWrite in [false, true]) {
    test(
      'failed save restores the confirmed setting and cache ($throwsOnWrite)',
      () async {
        final platform = _FailingFontSizePreferences({
          'flutter.layout_ui_font_size': 'medium',
        })..throwsOnWrite = throwsOnWrite;
        SharedPreferencesStorePlatform.instance = platform;
        final controller = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(controller.dispose);
        platform.fail = true;
        await controller.setUiFontSize(UiFontSize.large);
        expect(controller.uiFontSize, UiFontSize.medium);
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.uiFontSize, UiFontSize.medium);
        restored.dispose();
      },
    );
  }
}

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 14 ? fontSize * 2 : fontSize * 1.5;

  @override
  double get textScaleFactor => 2;
}

class _DelayedFontSizeStore extends SharedPreferencesLayoutSettingsStore {
  UiFontSize saved = UiFontSize.system;
  int activeWrites = 0;
  int maximumConcurrentWrites = 0;

  @override
  Future<UiFontSize> loadUiFontSize() async => saved;

  @override
  Future<void> saveUiFontSize(UiFontSize size) async {
    activeWrites++;
    if (activeWrites > maximumConcurrentWrites) {
      maximumConcurrentWrites = activeWrites;
    }
    await Future<void>.delayed(
      Duration(milliseconds: size == UiFontSize.small ? 20 : 1),
    );
    saved = size;
    activeWrites--;
  }
}

class _FailingFontSizePreferences extends InMemorySharedPreferencesStore {
  _FailingFontSizePreferences(super.data) : super.withData();
  bool fail = false;
  bool throwsOnWrite = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (fail && key == 'flutter.layout_ui_font_size') {
      if (throwsOnWrite) {
        throw StateError('Simulated font size platform failure');
      }
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
