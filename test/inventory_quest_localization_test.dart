import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';

void main() {
  testWidgets('inventory tabs render in Japanese', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Locale('ja'),
        OwnedInventorySegmented(
          showShips: true,
          shipCount: 0,
          equipmentCount: 0,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('艦娘 0'), findsOneWidget);
    expect(find.text('装備 0'), findsOneWidget);
    expect(find.text('舰娘'), findsNothing);
  });

  testWidgets('quest mode tabs render in Traditional Chinese', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        QuestModeTabs(mode: QuestCenterMode.active, onChanged: (_) {}),
      ),
    );

    expect(find.text('進行中'), findsOneWidget);
    expect(find.text('全部任務'), findsOneWidget);
    expect(find.text('全任务'), findsNothing);
  });
}

Widget _localizedApp(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
