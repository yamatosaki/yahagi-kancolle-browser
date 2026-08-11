import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings_section.dart';

void main() {
  testWidgets('settings tabs render in Japanese', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Locale('ja'),
        SettingsSegmented(selectedIndex: 0, onChanged: (_) {}),
      ),
    );

    expect(find.text('画面'), findsOneWidget);
    expect(find.text('サウンド'), findsOneWidget);
    expect(find.text('戦闘'), findsOneWidget);
    expect(find.text('ネットワーク'), findsOneWidget);
    expect(find.text('情報・サポート'), findsOneWidget);
    expect(find.text('声音'), findsNothing);
  });

  testWidgets('settings tabs render in Traditional Chinese', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        SettingsSegmented(selectedIndex: 0, onChanged: (_) {}),
      ),
    );

    expect(find.text('畫面'), findsOneWidget);
    expect(find.text('聲音'), findsOneWidget);
    expect(find.text('戰鬥'), findsOneWidget);
    expect(find.text('網路'), findsOneWidget);
    expect(find.text('關於與支援'), findsOneWidget);
  });

  testWidgets('battle prediction settings render in Japanese', (tester) async {
    final controller = await BattlePredictionSettingsController.load(
      MemoryBattlePredictionSettingsStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _localizedApp(
        const Locale('ja'),
        BattlePredictionSettingsSection(controller: controller),
      ),
    );

    expect(find.text('戦闘予測エンジン'), findsOneWidget);
    expect(find.text('高精度モード'), findsOneWidget);
    expect(find.text('軽量モード'), findsOneWidget);
    expect(find.text('战斗预测引擎'), findsNothing);
  });
}

Widget _localizedApp(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
