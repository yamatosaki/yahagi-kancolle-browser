import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings_section.dart';

void main() {
  testWidgets(
    'shows four modes and applies fixed frame-rate selections immediately',
    (tester) async {
      final store = MemoryGameFrameRateSettingsStore();
      final controller = await GameFrameRateSettingsController.load(store);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_testApp(controller, const Locale('zh')));

      expect(find.byType(SegmentedButton<GameFrameRateMode>), findsOneWidget);
      expect(find.text('自动'), findsOneWidget);
      expect(find.text('60 帧'), findsOneWidget);
      expect(find.text('30 帧'), findsOneWidget);
      expect(find.text('高刷'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<GameFrameRateMode>>(
              find.byType(SegmentedButton<GameFrameRateMode>),
            )
            .segments,
        hasLength(4),
      );

      await tester.tap(find.text('60 帧'));
      await tester.pumpAndSettle();
      expect(controller.mode, GameFrameRateMode.stable60);
      expect(await store.loadMode(), GameFrameRateMode.stable60);

      await tester.tap(find.text('30 帧'));
      await tester.pumpAndSettle();

      expect(controller.mode, GameFrameRateMode.stable30);
      expect(await store.loadMode(), GameFrameRateMode.stable30);
      expect(find.text('重新加载游戏页面后生效'), findsNothing);
    },
  );

  testWidgets('cancelling the high refresh warning keeps the current mode', (
    tester,
  ) async {
    final store = MemoryGameFrameRateSettingsStore();
    final controller = await GameFrameRateSettingsController.load(store);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller, const Locale('zh')));

    await tester.tap(find.text('高刷'));
    await tester.pumpAndSettle();
    expect(find.text('开启高刷模式？'), findsOneWidget);
    expect(find.textContaining('未知的账号风险'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.mode, GameFrameRateMode.automatic);
    expect(await store.loadMode(), GameFrameRateMode.automatic);
  });

  testWidgets('confirming the high refresh warning saves the mode', (
    tester,
  ) async {
    final store = MemoryGameFrameRateSettingsStore();
    final controller = await GameFrameRateSettingsController.load(store);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller, const Locale('zh')));

    await tester.tap(find.text('高刷'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('了解风险并开启'));
    await tester.pumpAndSettle();

    expect(controller.mode, GameFrameRateMode.highRefresh);
    expect(await store.loadMode(), GameFrameRateMode.highRefresh);
  });

  testWidgets('a saved high refresh mode does not show a startup warning', (
    tester,
  ) async {
    final controller = await GameFrameRateSettingsController.load(
      MemoryGameFrameRateSettingsStore(GameFrameRateMode.highRefresh),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller, const Locale('zh')));

    expect(find.text('开启高刷模式？'), findsNothing);
    expect(controller.mode, GameFrameRateMode.highRefresh);
  });

  for (final localeCase in <({Locale locale, List<String> texts})>[
    (
      locale: const Locale('zh'),
      texts: <String>['游戏帧率', '自动', '60 帧', '30 帧', '高刷'],
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      texts: <String>['遊戲幀率', '自動', '60 幀', '30 幀', '高更新率'],
    ),
    (
      locale: const Locale('ja'),
      texts: <String>['ゲームフレームレート', '自動', '60 FPS', '30 FPS', '高リフレッシュ'],
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
