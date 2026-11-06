import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

void main() {
  testWidgets('warning presents timing as one choice with advance by default', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      addTearDown(controller.dispose);
      await _pumpPage(tester, controller);

      final l10n = lookupAppLocalizations(const Locale('zh'));
      final master = find.byKey(const Key('battleWarningMasterSwitch'));
      final masterLabel = find.text(l10n.gameSafety);
      final selector = find.byKey(const Key('advanceWarningTimingSelector'));
      final dropdown = find.byKey(const Key('advanceWarningTimingDropdown'));
      final title = find.descendant(
        of: selector,
        matching: find.text(l10n.advanceWarningTimingModeTitle),
      );
      final selected = find.descendant(
        of: selector,
        matching: find.text(l10n.advanceWarningAfterAdvance),
      );
      expect(tester.widget<Switch>(master).value, isTrue);
      final masterRow = find.byKey(const Key('battleWarningMasterRow'));
      expect(masterRow, findsOneWidget);
      final masterSemantics = tester.getSemantics(masterRow);
      expect(
        masterSemantics,
        isSemantics(
          label: l10n.gameSafety,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSemantics(master).id, masterSemantics.id);
      expect(selector, findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<AdvanceWarningTimingSettings>>(dropdown)
            .value,
        AdvanceWarningTimingSettings.advanceOnly,
      );
      expect(selected, findsOneWidget);
      expect(
        tester.getRect(title).left,
        closeTo(tester.getRect(masterLabel).left, .1),
      );
      expect(
        tester.getRect(selected).left,
        greaterThan(tester.getRect(title).right),
      );
      expect(
        find.byKey(const Key('advanceWarningPostBattleSwitch')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('advanceWarningAfterAdvanceSwitch')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('advanceWarningTimingRequired')),
        findsNothing,
      );
      expect(find.text('POI'), findsNothing);
      expect(find.text('KCA'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('timing dropdown saves each complete legal choice and closes', (
    tester,
  ) async {
    final store = MemorySafetySettingsStore();
    final controller = await SafetySettingsController.load(store);
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller);
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final selector = find.byKey(const Key('advanceWarningTimingSelector'));
    final dropdown = find.byKey(const Key('advanceWarningTimingDropdown'));
    final battleOnlyWarning = find.byKey(
      const Key('advanceWarningPostBattleOnlyWarning'),
    );

    for (final (optionKey, timings, label) in [
      (
        'advanceWarningTimingOptionAdvance',
        AdvanceWarningTimingSettings.advanceOnly,
        l10n.advanceWarningAfterAdvance,
      ),
      (
        'advanceWarningTimingOptionBattle',
        AdvanceWarningTimingSettings.battleOnly,
        l10n.advanceWarningPostBattle,
      ),
      (
        'advanceWarningTimingOptionBoth',
        AdvanceWarningTimingSettings.battleAndAdvance,
        l10n.advanceWarningBothTimings,
      ),
      (
        'advanceWarningTimingOptionAdvance',
        AdvanceWarningTimingSettings.advanceOnly,
        l10n.advanceWarningAfterAdvance,
      ),
    ]) {
      await _tapVisible(tester, dropdown);
      for (final key in [
        'advanceWarningTimingOptionAdvance',
        'advanceWarningTimingOptionBattle',
        'advanceWarningTimingOptionBoth',
      ]) {
        expect(find.byKey(Key(key)).last, findsOneWidget);
      }
      await _tapVisible(tester, find.byKey(Key(optionKey)).last);

      expect(find.byKey(Key(optionKey)), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<AdvanceWarningTimingSettings>>(dropdown)
            .value,
        timings,
      );
      expect(controller.advanceWarningTimings, timings);
      expect(await store.loadAdvanceWarningTimings(), timings);
      expect(
        find.descendant(of: selector, matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('advanceWarningTimingRequired')),
        findsNothing,
      );
      expect(
        battleOnlyWarning,
        timings == AdvanceWarningTimingSettings.battleOnly
            ? findsOneWidget
            : findsNothing,
      );
      expect(
        find.byKey(const Key('advanceWarningDisplayModeSelector')),
        findsOneWidget,
      );
    }

    final timingsBeforeDismiss = controller.advanceWarningTimings;
    final savedBeforeDismiss = await store.loadAdvanceWarningTimings();
    final alternative = find.text(l10n.advanceWarningPostBattle);
    await _tapVisible(tester, dropdown);
    expect(alternative, findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(alternative, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(alternative, findsNothing);
    expect(controller.advanceWarningTimings, timingsBeforeDismiss);
    expect(await store.loadAdvanceWarningTimings(), savedBeforeDismiss);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'master row hides children and restores saved choices after reload',
    (tester) async {
      final store = MemorySafetySettingsStore();
      final controller = await SafetySettingsController.load(store);
      addTearDown(controller.dispose);
      await _pumpPage(tester, controller);
      await _tapVisible(
        tester,
        find.byKey(const Key('advanceWarningTimingDropdown')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('advanceWarningTimingOptionBattle')).last,
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('advanceWarningDisplayModeDropdown')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('advanceWarningDisplayOptionSmart')).last,
      );

      // Tap the label side, away from the Switch, to exercise the full row.
      await _tapMasterLabel(tester);
      expect(controller.battleWarningMode, BattleWarningMode.off);
      expect(
        find.byKey(const Key('advanceWarningTimingSelector')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('advanceWarningDisplayModeSelector')),
        findsNothing,
      );
      expect(
        controller.advanceWarningTimings,
        AdvanceWarningTimingSettings.battleOnly,
      );
      expect(
        controller.advanceWarningDisplayMode,
        AdvanceWarningDisplayMode.smart,
      );
      expect(
        await store.loadAdvanceWarningTimings(),
        AdvanceWarningTimingSettings.battleOnly,
      );
      expect(
        await store.loadAdvanceWarningDisplayMode(),
        AdvanceWarningDisplayMode.smart,
      );

      final restored = await SafetySettingsController.load(store);
      addTearDown(restored.dispose);
      await _pumpPage(tester, restored);
      final master = find.byKey(const Key('battleWarningMasterSwitch'));
      expect(tester.widget<Switch>(master).value, isFalse);
      expect(
        find.byKey(const Key('advanceWarningTimingSelector')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('advanceWarningDisplayModeSelector')),
        findsNothing,
      );
      await _tapMasterLabel(tester);

      final l10n = lookupAppLocalizations(const Locale('zh'));
      expect(restored.battleWarningMode, BattleWarningMode.confirm);
      expect(tester.widget<Switch>(master).value, isTrue);
      expect(
        find.descendant(
          of: find.byKey(const Key('advanceWarningTimingSelector')),
          matching: find.text(l10n.advanceWarningPostBattle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('advanceWarningDisplayModeSelector')),
          matching: find.text(l10n.advanceWarningSmart),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in <double>[320, 800]) {
      testWidgets(
        'timing choices remain readable at $width with large text in $locale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 780);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final store = MemorySafetySettingsStore();
          final controller = await SafetySettingsController.load(store);
          addTearDown(controller.dispose);
          await _pumpPage(tester, controller, locale: locale, largeText: true);

          final l10n = lookupAppLocalizations(locale);
          final selector = find.byKey(
            const Key('advanceWarningTimingSelector'),
          );
          final dropdown = find.byKey(
            const Key('advanceWarningTimingDropdown'),
          );
          for (final label in [
            l10n.advanceWarningTimingModeTitle,
            l10n.advanceWarningTimingModeDescription,
            l10n.advanceWarningAfterAdvance,
          ]) {
            final text = find.descendant(
              of: selector,
              matching: find.text(label),
            );
            expect(text, findsOneWidget);
            _expectReadable(tester, text, width);
          }
          await _tapVisible(tester, dropdown);
          for (final (key, label) in [
            (
              'advanceWarningTimingOptionAdvance',
              l10n.advanceWarningAfterAdvance,
            ),
            ('advanceWarningTimingOptionBattle', l10n.advanceWarningPostBattle),
            ('advanceWarningTimingOptionBoth', l10n.advanceWarningBothTimings),
          ]) {
            final option = find.byKey(Key(key)).last;
            await tester.ensureVisible(option);
            await tester.pumpAndSettle();
            final text = find.descendant(
              of: option,
              matching: find.text(label),
            );
            expect(text, findsOneWidget);
            _expectReadable(tester, text, width);
          }
          await _tapVisible(
            tester,
            find.byKey(const Key('advanceWarningTimingOptionBattle')).last,
          );
          expect(
            find.byKey(const Key('advanceWarningTimingOptionBattle')),
            findsOneWidget,
          );
          expect(
            controller.advanceWarningTimings,
            AdvanceWarningTimingSettings.battleOnly,
          );
          expect(
            await store.loadAdvanceWarningTimings(),
            AdvanceWarningTimingSettings.battleOnly,
          );
          final selected = find.descendant(
            of: selector,
            matching: find.text(l10n.advanceWarningPostBattle),
          );
          await tester.ensureVisible(selected);
          await tester.pumpAndSettle();
          _expectReadable(tester, selected, width);
          final warning = find.text(l10n.advanceWarningPostBattleOnlyWarning);
          await tester.ensureVisible(warning);
          await tester.pumpAndSettle();
          _expectReadable(tester, warning, width);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  SafetySettingsController controller, {
  Locale locale = const Locale('zh'),
  bool largeText = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(largeText ? 1.3 : 1)),
        child: child!,
      ),
      home: Scaffold(
        body: BattleSettingsPage(safetySettingsController: controller),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapMasterLabel(WidgetTester tester) async {
  final row = find.byKey(const Key('battleWarningMasterRow'));
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  final rect = tester.getRect(row);
  await tester.tapAt(Offset(rect.left + 24, rect.center.dy));
  await tester.pumpAndSettle();
}

void _expectReadable(WidgetTester tester, Finder finder, double width) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.getMaxIntrinsicHeight(paragraph.size.width),
    lessThanOrEqualTo(paragraph.size.height + .1),
  );
  expect(tester.getRect(finder).left, greaterThanOrEqualTo(0));
  expect(tester.getRect(finder).right, lessThanOrEqualTo(width));
}
