import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/ui_font_size.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';

const _dropdownKey = Key('settings-ui-font-size-dropdown');
const _rowKey = Key('settings-ui-font-size-row');

Future<void> _pumpSettings(
  WidgetTester tester,
  LayoutSettingsController controller,
  DisplayModeController display, {
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    theme: createAppTheme(mode: controller.appThemeMode),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: ScreenSettingsPage(
        layoutSettingsController: controller,
        displayModeController: display,
      ),
    ),
  ),
);

void _expectTextFits(WidgetTester tester, Finder finder, Rect bounds) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.getMaxIntrinsicHeight(paragraph.size.width),
    lessThanOrEqualTo(paragraph.size.height + .1),
  );
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(bounds.left - .1));
  expect(rect.right, lessThanOrEqualTo(bounds.right + .1));
  expect(rect.top, greaterThanOrEqualTo(bounds.top - .1));
  expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'screen font size choices update immediately and survive reload',
    (tester) async {
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final display = await DisplayModeController.load(
        MemoryDisplayModeStore(),
      );
      addTearDown(controller.dispose);
      addTearDown(display.dispose);

      await _pumpSettings(tester, controller, display);

      final dropdown = find.byKey(_dropdownKey);
      expect(dropdown, findsOneWidget);
      expect(controller.uiFontSize, UiFontSize.system);
      expect(find.text('界面字号'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(_rowKey)).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('settings-ui-display-size-row')))
              .dy,
        ),
      );

      for (final (size, label) in [
        (UiFontSize.small, '小'),
        (UiFontSize.medium, '中'),
        (UiFontSize.large, '大'),
        (UiFontSize.system, '默认（跟随系统）'),
      ]) {
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();

        expect(controller.uiFontSize, size);
        expect(tester.widget<DropdownButton<UiFontSize>>(dropdown).value, size);
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.uiFontSize, size);
        restored.dispose();
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    for (final scenario in [
      (width: 320.0, textScale: 1.3),
      (width: 390.0, textScale: 1.0),
      (width: 480.0, textScale: 1.0),
    ]) {
      testWidgets(
        'font size row and menu fit ${scenario.width}px at ${scenario.textScale}x in $locale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(scenario.width, 780);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final controller = await LayoutSettingsController.load(
            SharedPreferencesLayoutSettingsStore(),
          );
          final display = await DisplayModeController.load(
            MemoryDisplayModeStore(),
          );
          addTearDown(controller.dispose);
          addTearDown(display.dispose);
          await _pumpSettings(
            tester,
            controller,
            display,
            locale: locale,
            textScale: scenario.textScale,
          );
          await tester.pumpAndSettle();

          final l10n = lookupAppLocalizations(locale);
          final row = find.byKey(_rowKey);
          final dropdown = find.byKey(_dropdownKey);
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          expect(
            tester.widget<DropdownButton<UiFontSize>>(dropdown).isExpanded,
            isTrue,
          );
          expect(
            tester.widget<DropdownButton<UiFontSize>>(dropdown).itemHeight,
            isNull,
          );
          _expectTextFits(
            tester,
            find.text(l10n.uiFontSizeTitle),
            tester.getRect(row),
          );
          _expectTextFits(
            tester,
            find.text(l10n.uiFontSizeDescription),
            tester.getRect(row),
          );
          final selectedLabel = find.descendant(
            of: dropdown,
            matching: find.text(l10n.uiFontSizeSystem),
          );
          _expectTextFits(tester, selectedLabel, tester.getRect(dropdown));
          expect(
            tester.getTopLeft(dropdown).dy,
            greaterThan(
              tester.getBottomLeft(find.text(l10n.uiFontSizeDescription)).dy,
            ),
          );

          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          for (final label in [
            l10n.uiFontSizeSystem,
            l10n.uiFontSizeSmall,
            l10n.uiFontSizeMedium,
            l10n.uiFontSizeLarge,
          ]) {
            final option = find.text(label).last;
            await tester.ensureVisible(option);
            await tester.pumpAndSettle();
            _expectTextFits(
              tester,
              option,
              Rect.fromLTWH(0, 0, scenario.width, 780),
            );
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(l10n.uiFontSizeLarge).last);
          await tester.pumpAndSettle();
          expect(controller.uiFontSize, UiFontSize.large);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
