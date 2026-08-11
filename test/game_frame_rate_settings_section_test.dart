import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings_section.dart';

void main() {
  testWidgets(
    'shows three modes and applies a selection without reload notice',
    (tester) async {
      final store = MemoryGameFrameRateSettingsStore();
      final controller = await GameFrameRateSettingsController.load(store);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_testApp(controller, const Locale('zh')));

      expect(find.byType(SegmentedButton<GameFrameRateMode>), findsOneWidget);
      expect(find.text('自动'), findsOneWidget);
      expect(find.text('稳定 30 FPS'), findsOneWidget);
      expect(find.text('优先 60 FPS'), findsOneWidget);

      await tester.tap(find.text('稳定 30 FPS'));
      await tester.pumpAndSettle();

      expect(controller.mode, GameFrameRateMode.stable30);
      expect(await store.loadMode(), GameFrameRateMode.stable30);
      expect(find.text('重新加载游戏页面后生效'), findsNothing);
    },
  );

  for (final localeCase in <({Locale locale, List<String> texts})>[
    (
      locale: const Locale('zh'),
      texts: <String>['游戏帧率', '自动', '稳定 30 FPS', '优先 60 FPS'],
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      texts: <String>['遊戲幀率', '自動', '穩定 30 FPS', '優先 60 FPS'],
    ),
    (
      locale: const Locale('ja'),
      texts: <String>['ゲームフレームレート', '自動', '安定 30 FPS', '60 FPS 優先'],
    ),
  ]) {
    testWidgets('localizes all modes for ${localeCase.locale}', (tester) async {
      final controller = await GameFrameRateSettingsController.load(
        MemoryGameFrameRateSettingsStore(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_testApp(controller, localeCase.locale));

      for (final text in localeCase.texts) {
        expect(find.text(text), findsOneWidget);
      }
    });
  }
}

Widget _testApp(GameFrameRateSettingsController controller, Locale locale) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: GameFrameRateSettingsSection(controller: controller),
      ),
    );
