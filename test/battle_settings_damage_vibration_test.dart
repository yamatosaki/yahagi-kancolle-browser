import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  for (final (locale, labels) in <(Locale, List<String>)>[
    (const Locale('zh'), ['闪烁', '常亮', '关闭']),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ['閃爍', '恆亮', '關閉'],
    ),
    (const Locale('ja'), ['点滅', '常時点灯', 'オフ']),
  ]) {
    testWidgets('morale mode choices are localized for $locale', (
      tester,
    ) async {
      final controller = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BattleSettingsPage(safetySettingsController: controller),
        ),
      );
      final dropdown = tester.widget<DropdownButton<MoraleSparkleMode>>(
        find.byKey(const Key('moraleSparkleModeDropdown')),
      );
      expect(dropdown.value, MoraleSparkleMode.blinking);
      expect(dropdown.items!.map((item) => (item.child as Text).data), labels);
    });
  }

  testWidgets('battle settings show the approved status effect controls', (
    tester,
  ) async {
    final controller = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BattleSettingsPage(safetySettingsController: controller),
      ),
    );

    expect(find.text('大破提醒'), findsOneWidget);
    expect(find.text('游戏安全'), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('battleWarningMasterSwitch'))),
      isA<Switch>(),
    );
    expect(find.byKey(const Key('battleWarningMasterRow')), findsOneWidget);
    expect(
      find.byKey(const Key('advanceWarningTimingSelector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('advanceWarningDisplayModeSelector')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DropdownButton<AdvanceWarningTimingSettings>>(
            find.byKey(const Key('advanceWarningTimingDropdown')),
          )
          .value,
      AdvanceWarningTimingSettings.advanceOnly,
    );
    expect(
      tester
          .widget<DropdownButton<AdvanceWarningDisplayMode>>(
            find.byKey(const Key('advanceWarningDisplayModeDropdown')),
          )
          .value,
      AdvanceWarningDisplayMode.alwaysConfirm,
    );
    expect(find.text('结算后提醒'), findsNothing);
    expect(find.text('进击后提醒'), findsOneWidget);
    expect(find.text('POI'), findsNothing);
    expect(find.text('KCA'), findsNothing);
    expect(find.text('舰娘状态反馈'), findsOneWidget);
    expect(find.text('启用状态效果'), findsOneWidget);
    expect(find.text('画面显示范围'), findsOneWidget);
    expect(find.text('受损闪烁'), findsOneWidget);
    expect(find.text('受损震动'), findsOneWidget);
    expect(find.text('士气闪光效果'), findsOneWidget);
    expect(find.text('战斗受损震动提醒'), findsNothing);

    expect(
      find.byKey(const Key('battleStatusEffectsMasterSwitch')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('damagePulseFilterDropdown')), findsOneWidget);
    expect(find.byKey(const Key('battleEffectScopeDropdown')), findsOneWidget);
    expect(
      find.byKey(const Key('damageVibrationFilterDropdown')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('moraleSparkleModeDropdown')), findsOneWidget);

    final scopeDropdownWidget = tester
        .widget<DropdownButton<BattleEffectDisplayScope>>(
          find.byKey(const Key('battleEffectScopeDropdown')),
        );
    final pulseDropdownWidget = tester
        .widget<DropdownButton<DamagePulseFilter>>(
          find.byKey(const Key('damagePulseFilterDropdown')),
        );
    final vibrationDropdownWidget = tester
        .widget<DropdownButton<DamageVibrationFilter>>(
          find.byKey(const Key('damageVibrationFilterDropdown')),
        );

    expect(scopeDropdownWidget.alignment, AlignmentDirectional.centerEnd);
    expect(pulseDropdownWidget.alignment, AlignmentDirectional.centerEnd);
    expect(vibrationDropdownWidget.alignment, AlignmentDirectional.centerEnd);

    final scopeText = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('battleEffectScopeDropdown')),
        matching: find.text('全部'),
      ),
    );
    final scopeIcon = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('battleEffectScopeDropdown')),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
    );
    expect(scopeText.right, closeTo(scopeIcon.left, 0.5));
  });

  testWidgets('master switch disables children without changing their values', (
    tester,
  ) async {
    final controller = await SafetySettingsController.load(
      MemorySafetySettingsStore(
        battleStatusEffects: const BattleStatusEffectSettings(
          displayScope: BattleEffectDisplayScope.fleetOnly,
          damagePulseFilter: DamagePulseFilter.minorOnly,
          damageVibrationFilter: DamageVibrationFilter.heavyOnly,
          moraleSparkleMode: MoraleSparkleMode.off,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BattleSettingsPage(safetySettingsController: controller),
      ),
    );

    await tester.tap(find.byKey(const Key('battleStatusEffectsMasterSwitch')));
    await tester.pump();

    expect(controller.battleStatusEffects.enabled, isFalse);
    expect(
      controller.battleStatusEffects.displayScope,
      BattleEffectDisplayScope.fleetOnly,
    );
    expect(
      controller.battleStatusEffects.damagePulseFilter,
      DamagePulseFilter.minorOnly,
    );
    expect(
      controller.battleStatusEffects.damageVibrationFilter,
      DamageVibrationFilter.heavyOnly,
    );
    expect(
      controller.battleStatusEffects.moraleSparkleMode,
      MoraleSparkleMode.off,
    );

    final pulseDropdown = tester.widget<DropdownButton<DamagePulseFilter>>(
      find.byKey(const Key('damagePulseFilterDropdown')),
    );
    final vibrationDropdown = tester
        .widget<DropdownButton<DamageVibrationFilter>>(
          find.byKey(const Key('damageVibrationFilterDropdown')),
        );
    final moraleDropdown = tester.widget<DropdownButton<MoraleSparkleMode>>(
      find.byKey(const Key('moraleSparkleModeDropdown')),
    );
    expect(pulseDropdown.onChanged, isNull);
    expect(vibrationDropdown.onChanged, isNull);
    expect(moraleDropdown.onChanged, isNull);
  });

  testWidgets('scope and filter controls update independent fields', (
    tester,
  ) async {
    final controller = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BattleSettingsPage(safetySettingsController: controller),
      ),
    );

    final scopeDropdown = tester
        .widget<DropdownButton<BattleEffectDisplayScope>>(
          find.byKey(const Key('battleEffectScopeDropdown')),
        );
    scopeDropdown.onChanged!(BattleEffectDisplayScope.predictionOnly);
    await tester.pump();
    expect(
      controller.battleStatusEffects.displayScope,
      BattleEffectDisplayScope.predictionOnly,
    );

    final pulseDropdown = tester.widget<DropdownButton<DamagePulseFilter>>(
      find.byKey(const Key('damagePulseFilterDropdown')),
    );
    pulseDropdown.onChanged!(DamagePulseFilter.moderateOnly);
    await tester.pump();
    final vibrationDropdown = tester
        .widget<DropdownButton<DamageVibrationFilter>>(
          find.byKey(const Key('damageVibrationFilterDropdown')),
        );
    vibrationDropdown.onChanged!(DamageVibrationFilter.heavyOnly);
    await tester.pump();

    expect(
      controller.battleStatusEffects.damagePulseFilter,
      DamagePulseFilter.moderateOnly,
    );
    expect(
      controller.battleStatusEffects.damageVibrationFilter,
      DamageVibrationFilter.heavyOnly,
    );
    final moraleDropdown = tester.widget<DropdownButton<MoraleSparkleMode>>(
      find.byKey(const Key('moraleSparkleModeDropdown')),
    );
    expect(
      moraleDropdown.items!.map((item) => item.value),
      MoraleSparkleMode.values,
    );
    expect(moraleDropdown.alignment, AlignmentDirectional.centerEnd);
    for (final mode in MoraleSparkleMode.values) {
      moraleDropdown.onChanged!(mode);
      await tester.pump();
      expect(controller.battleStatusEffects.moraleSparkleMode, mode);
    }
  });
}
