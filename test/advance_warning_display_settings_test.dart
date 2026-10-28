import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/settings_organization_strings.dart';

void main() {
  test('Chinese warning master switch uses an enabled label', () {
    expect(
      lookupAppLocalizations(const Locale('zh')).battleWarningConfirm,
      '开启提醒',
    );
  });

  test(
    'unset display mode defaults to always confirm in both stores',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      for (final store in <SafetySettingsStore>[
        SharedPreferencesSafetySettingsStore(),
        MemorySafetySettingsStore(),
      ]) {
        final controller = await SafetySettingsController.load(store);
        addTearDown(controller.dispose);

        expect(
          controller.advanceWarningDisplayMode,
          AdvanceWarningDisplayMode.alwaysConfirm,
        );
        expect(controller.battleWarningMode, BattleWarningMode.confirm);
      }
    },
  );

  for (final invalidValue in <Object>['', 'unknown', 'off', 42, false]) {
    test(
      'invalid display mode $invalidValue defaults to always confirm',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'safety.advanceWarningDisplayMode': invalidValue,
          'safety.battleWarningMode': 'off',
        });
        final controller = await SafetySettingsController.load(
          SharedPreferencesSafetySettingsStore(),
        );
        addTearDown(controller.dispose);

        expect(
          controller.advanceWarningDisplayMode,
          AdvanceWarningDisplayMode.alwaysConfirm,
        );
        expect(controller.battleWarningMode, BattleWarningMode.off);
      },
    );
  }

  test(
    'display choice persists separately from the warning master switch',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = await SafetySettingsController.load(
        SharedPreferencesSafetySettingsStore(),
      );
      addTearDown(controller.dispose);
      await controller.setBattleWarningMode(BattleWarningMode.off);
      await controller.setAdvanceWarningDisplayMode(
        AdvanceWarningDisplayMode.smart,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('safety.advanceWarningDisplayMode'), 'smart');
      expect(prefs.getString('safety.battleWarningMode'), 'off');
      final restored = await SafetySettingsController.load(
        SharedPreferencesSafetySettingsStore(),
      );
      addTearDown(restored.dispose);
      expect(
        restored.advanceWarningDisplayMode,
        AdvanceWarningDisplayMode.smart,
      );
      expect(restored.battleWarningMode, BattleWarningMode.off);

      await restored.setAdvanceWarningDisplayMode(
        AdvanceWarningDisplayMode.alwaysConfirm,
      );
      final restoredAgain = await SafetySettingsController.load(
        SharedPreferencesSafetySettingsStore(),
      );
      addTearDown(restoredAgain.dispose);
      expect(
        restoredAgain.advanceWarningDisplayMode,
        AdvanceWarningDisplayMode.alwaysConfirm,
      );
      expect(restoredAgain.battleWarningMode, BattleWarningMode.off);
    },
  );

  test(
    'memory store restores display choice and notifies only on changes',
    () async {
      final store = MemorySafetySettingsStore();
      final controller = await SafetySettingsController.load(store);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setAdvanceWarningDisplayMode(
        AdvanceWarningDisplayMode.smart,
      );
      await controller.setAdvanceWarningDisplayMode(
        AdvanceWarningDisplayMode.smart,
      );
      expect(notifications, 1);
      final restored = await SafetySettingsController.load(store);
      addTearDown(restored.dispose);
      expect(
        restored.advanceWarningDisplayMode,
        AdvanceWarningDisplayMode.smart,
      );
      expect(restored.battleWarningMode, BattleWarningMode.confirm);
    },
  );

  testWidgets('display dropdown saves choices and updates their description', (
    tester,
  ) async {
    final store = MemorySafetySettingsStore();
    final controller = await SafetySettingsController.load(store);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BattleSettingsPage(safetySettingsController: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('zh'));
    final selector = find.byKey(const Key('advanceWarningDisplayModeSelector'));
    final dropdown = find.byKey(const Key('advanceWarningDisplayModeDropdown'));
    expect(selector, findsOneWidget);
    expect(
      tester.widget<DropdownButton<AdvanceWarningDisplayMode>>(dropdown).value,
      AdvanceWarningDisplayMode.alwaysConfirm,
    );
    expect(
      find.text(l10n.advanceWarningAlwaysConfirmDescription),
      findsOneWidget,
    );
    expect(find.text(l10n.advanceWarningSmartDescription), findsNothing);
    for (final (key, mode, label, description) in [
      (
        'advanceWarningDisplayOptionSmart',
        AdvanceWarningDisplayMode.smart,
        l10n.advanceWarningSmart,
        l10n.advanceWarningSmartDescription,
      ),
      (
        'advanceWarningDisplayOptionAlways',
        AdvanceWarningDisplayMode.alwaysConfirm,
        l10n.advanceWarningAlwaysConfirm,
        l10n.advanceWarningAlwaysConfirmDescription,
      ),
    ]) {
      await _tapVisible(tester, dropdown);
      expect(
        find.byKey(const Key('advanceWarningDisplayOptionAlways')).last,
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('advanceWarningDisplayOptionSmart')).last,
        findsOneWidget,
      );
      await _tapVisible(tester, find.byKey(Key(key)).last);
      expect(find.byKey(Key(key)), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<AdvanceWarningDisplayMode>>(dropdown)
            .value,
        mode,
      );
      expect(controller.advanceWarningDisplayMode, mode);
      expect(await store.loadAdvanceWarningDisplayMode(), mode);
      expect(
        find.descendant(of: selector, matching: find.text(label)),
        findsOneWidget,
      );
      expect(find.text(description), findsOneWidget);
    }

    await _tapVisible(
      tester,
      find.byKey(const Key('advanceWarningTimingDropdown')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('advanceWarningTimingOptionBattle')).last,
    );
    expect(selector, findsOneWidget);
    await _tapVisible(tester, dropdown);
    await _tapVisible(
      tester,
      find.byKey(const Key('advanceWarningDisplayOptionSmart')).last,
    );
    expect(
      controller.advanceWarningTimings,
      AdvanceWarningTimingSettings.battleOnly,
    );
    expect(
      controller.advanceWarningDisplayMode,
      AdvanceWarningDisplayMode.smart,
    );
    expect(find.text(l10n.advanceWarningSmartDescription), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('display choice remains readable and interactive in $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 780);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = MemorySafetySettingsStore();
      final controller = await SafetySettingsController.load(store);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: BattleSettingsPage(safetySettingsController: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(locale);
      final selector = find.byKey(
        const Key('advanceWarningDisplayModeSelector'),
      );
      final dropdown = find.byKey(
        const Key('advanceWarningDisplayModeDropdown'),
      );
      expect(find.text(l10n.advanceWarningDisplayModeTitle), findsOneWidget);
      final description = find.text(
        l10n.advanceWarningAlwaysConfirmDescription,
      );
      expect(description, findsOneWidget);
      expect(
        tester.getTopLeft(selector).dy,
        lessThan(
          tester
              .getTopLeft(
                find.text(
                  settingsOrganizationText(
                    tester.element(find.byType(BattleSettingsPage)),
                    'settingsGroupShipStatusFeedback',
                  ),
                ),
              )
              .dy,
        ),
      );
      await tester.ensureVisible(description);
      await tester.pumpAndSettle();
      _expectReadable(tester, description);
      for (final (optionKey, mode, label, currentDescription) in [
        (
          'advanceWarningDisplayOptionSmart',
          AdvanceWarningDisplayMode.smart,
          l10n.advanceWarningSmart,
          l10n.advanceWarningSmartDescription,
        ),
        (
          'advanceWarningDisplayOptionAlways',
          AdvanceWarningDisplayMode.alwaysConfirm,
          l10n.advanceWarningAlwaysConfirm,
          l10n.advanceWarningAlwaysConfirmDescription,
        ),
      ]) {
        final currentLabel = mode == AdvanceWarningDisplayMode.smart
            ? l10n.advanceWarningAlwaysConfirm
            : l10n.advanceWarningSmart;
        final current = find.descendant(
          of: selector,
          matching: find.text(currentLabel),
        );
        await tester.ensureVisible(current);
        await tester.pumpAndSettle();
        _expectReadable(tester, current);
        await _tapVisible(tester, dropdown);
        for (final (key, optionLabel) in [
          (
            'advanceWarningDisplayOptionAlways',
            l10n.advanceWarningAlwaysConfirm,
          ),
          ('advanceWarningDisplayOptionSmart', l10n.advanceWarningSmart),
        ]) {
          final option = find.byKey(Key(key)).last;
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          final text = find.descendant(
            of: option,
            matching: find.text(optionLabel),
          );
          expect(text, findsOneWidget);
          _expectReadable(tester, text);
        }
        await _tapVisible(tester, find.byKey(Key(optionKey)).last);
        expect(find.byKey(Key(optionKey)), findsOneWidget);
        expect(controller.advanceWarningDisplayMode, mode);
        expect(await store.loadAdvanceWarningDisplayMode(), mode);
        expect(controller.battleWarningMode, BattleWarningMode.confirm);
        final selected = find.descendant(
          of: selector,
          matching: find.text(label),
        );
        expect(selected, findsOneWidget);
        await tester.ensureVisible(selected);
        await tester.pumpAndSettle();
        _expectReadable(tester, selected);
        final updatedDescription = find.text(currentDescription);
        await tester.ensureVisible(updatedDescription);
        await tester.pumpAndSettle();
        _expectReadable(tester, updatedDescription);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectReadable(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.getMaxIntrinsicHeight(paragraph.size.width),
    lessThanOrEqualTo(paragraph.size.height + .1),
  );
  expect(tester.getRect(finder).left, greaterThanOrEqualTo(0));
  expect(tester.getRect(finder).right, lessThanOrEqualTo(320));
}
