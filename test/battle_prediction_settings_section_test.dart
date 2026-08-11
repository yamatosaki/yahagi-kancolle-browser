import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings_section.dart';

void main() {
  testWidgets('defaults to POI and persists a Yahagi selection', (
    tester,
  ) async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BattlePredictionSettingsSection(controller: controller),
        ),
      ),
    );

    final segmented = tester.widget<SegmentedButton<BattlePredictionMethod>>(
      find.byKey(const Key('battle-prediction-method')),
    );
    expect(segmented.selected, <BattlePredictionMethod>{
      BattlePredictionMethod.poi,
    });

    await tester.tap(find.text('轻量模式'));
    await tester.pump();

    expect(controller.method, BattlePredictionMethod.yahagi);
    expect(await store.load(), BattlePredictionMethod.yahagi);
  });
}
