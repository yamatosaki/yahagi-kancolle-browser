import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_port.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/localization/runtime_message_text.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_runtime_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/sound_settings_page.dart';

void main() {
  for (final runtimePage in [false, true]) {
    testWidgets(
      'audio error stays visible without reopening sound, runtime=$runtimePage',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final audio = await GameAudioController.load(_FailedSaveStore());
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        final port = _AudioPort();
        await audio.attachPort(port);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          audio.dispose();
          layout.dispose();
        });
        await tester.pumpWidget(
          _app(
            runtimePage
                ? GameRuntimeSettingsPage(
                    layoutSettingsController: layout,
                    audioController: audio,
                  )
                : SoundSettingsPage(audioController: audio),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Switch).first);
        await tester.pumpAndSettle();
        expect(audio.isMuted, isTrue);
        expect(port.muted, isTrue);
        expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
        expect(find.text(audio.errorMessage!), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'unavailable audio switch is visibly disabled, runtime=$runtimePage',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final audio = await GameAudioController.load(_FailedSaveStore());
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          audio.dispose();
          layout.dispose();
        });
        await tester.pumpWidget(
          _app(
            runtimePage
                ? GameRuntimeSettingsPage(
                    layoutSettingsController: layout,
                    audioController: audio,
                  )
                : SoundSettingsPage(audioController: audio),
          ),
        );
        await tester.pumpAndSettle();
        expect(audio.canToggle, isFalse);
        expect(
          tester.widget<Switch>(find.byType(Switch).first).onChanged,
          isNull,
        );
      },
    );
  }

  for (final locale in ['en', 'ja', 'ko', 'zh-Hant']) {
    test(
      'audio failure prefixes are translated in $locale and preserve details',
      () {
        final value = locale == 'zh-Hant'
            ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
            : Locale(locale);
        for (final prefix in [
          '游戏静音暂未生效，已保留静音设置：',
          '游戏声音设置保存失败，当前状态已保留：',
          '游戏声音切换失败：',
          '当前设备无法控制游戏声音：',
          '后台声音设置失败：',
        ]) {
          const detail = 'PlatformException(test_failure, 原始 detail)';
          final translated = runtimeMessageForLocale(value, '$prefix$detail');
          expect(translated, isNot('$prefix$detail'));
          expect(translated, endsWith(detail));
        }
      },
    );
  }
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

final class _FailedSaveStore implements GameAudioStore {
  @override
  Future<bool?> readMuted() async => false;
  @override
  Future<bool?> readBackgroundPlaybackEnabled() async => false;
  @override
  Future<void> writeMuted(bool value) async =>
      throw StateError('injected save failure');
  @override
  Future<void> writeBackgroundPlaybackEnabled(bool value) async {}
}

final class _AudioPort implements GameAudioPort {
  bool muted = false;
  @override
  Future<bool> isSupported() async => true;
  @override
  Future<void> setMuted(bool value) async => muted = value;
}
