import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  testWidgets('Battle groups and controls follow the approved order', (
    tester,
  ) async {
    final safety = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    final prediction = await BattlePredictionSettingsController.load(
      MemoryBattlePredictionSettingsStore(),
    );
    final notifications = NotificationSettingsController();
    addTearDown(safety.dispose);
    addTearDown(prediction.dispose);
    addTearDown(notifications.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BattleSettingsPage(
          safetySettingsController: safety,
          battlePredictionSettingsController: prediction,
          notificationSettingsController: notifications,
        ),
      ),
    );

    final groupTitles = ['游戏安全', '解谜与削甲', '未卜先知', '舰娘状态反馈'];
    for (var index = 1; index < groupTitles.length; index++) {
      expect(
        tester.getTopLeft(find.text(groupTitles[index - 1])).dy,
        lessThan(tester.getTopLeft(find.text(groupTitles[index])).dy),
      );
    }
    final controls = [
      'battleWarningMasterSwitch',
      'advanceWarningTimingDropdown',
      'advanceWarningDisplayModeDropdown',
      'debuff-reminder-style-menu',
      'battle-enemy-preview-portraits',
      'battle-last-formation-hint',
      'battle-section-order',
      'battleStatusEffectsMasterSwitch',
      'battleEffectScopeDropdown',
      'damagePulseFilterDropdown',
      'damageVibrationFilterDropdown',
      'moraleSparkleModeDropdown',
    ];
    for (var index = 1; index < controls.length; index++) {
      expect(
        tester.getTopLeft(find.byKey(Key(controls[index - 1]))).dy,
        lessThan(tester.getTopLeft(find.byKey(Key(controls[index]))).dy),
      );
    }
  });

  testWidgets('battle settings put severe damage alert first', (tester) async {
    final safety = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );

    await tester.pumpWidget(
      MaterialApp(home: BattleSettingsPage(safetySettingsController: safety)),
    );

    expect(find.byKey(const Key('diagnosticLoggingSwitch')), findsNothing);
    expect(find.text('大破提醒'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('大破提醒')).dy,
      lessThan(tester.getTopLeft(find.text('舰娘状态反馈')).dy),
    );
  });
}
