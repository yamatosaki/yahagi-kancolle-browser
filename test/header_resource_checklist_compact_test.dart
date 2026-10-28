import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  testWidgets('fallback checklist uses compact rows and a bounded window', (
    tester,
  ) async {
    await _open(tester);
    final list = find.byKey(const Key('header-resource-filter-list'));
    final content = find
        .ancestor(of: list, matching: find.byType(Column))
        .first;
    expect(tester.getSize(content).width, lessThanOrEqualTo(360));
    expect(tester.getSize(content).height, lessThanOrEqualTo(440));
    final row = find.byKey(const Key('header-resource-filter-row-senka'));
    expect(tester.getSize(row).height, inInclusiveRange(36, 38));
    final icon = tester.widget<Icon>(
      find.descendant(of: row, matching: find.byType(Icon)),
    );
    expect(icon.size, 20);
    final checkbox = find.byKey(const Key('header-resource-visible-senka'));
    expect(tester.getRect(checkbox).width, lessThanOrEqualTo(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact checkbox and row toggle once and persist immediately', (
    tester,
  ) async {
    final settings = await _open(tester);
    final row = find.byKey(const Key('header-resource-filter-row-senka'));
    final checkbox = find.byKey(const Key('header-resource-visible-senka'));
    await tester.tapAt(tester.getRect(row).centerRight - const Offset(16, 0));
    await tester.pump();
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    expect(settings.visibleHeaderResourceIds, isNot(contains(headerSenkaId)));
    var reloaded = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(reloaded.visibleHeaderResourceIds, isNot(contains(headerSenkaId)));
    reloaded.dispose();
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    reloaded = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    expect(reloaded.visibleHeaderResourceIds, contains(headerSenkaId));
    reloaded.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('short-screen large text remains readable in $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester, locale: locale, textScale: 1.6);
      final list = find.byKey(const Key('header-resource-filter-list'));
      final content = find
          .ancestor(of: list, matching: find.byType(Column))
          .first;
      expect(tester.getRect(content).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(content).bottom, lessThanOrEqualTo(360));
      final row = find.byKey(const Key('header-resource-filter-row-senka'));
      final label = tester
          .widgetList<Text>(
            find.descendant(of: row, matching: find.byType(Text)),
          )
          .first;
      expect(label.overflow, isNot(TextOverflow.ellipsis));
      final lastRow = find.byKey(
        const Key('header-resource-filter-row-useitem-100'),
      );
      await tester.scrollUntilVisible(
        lastRow,
        150,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      expect(lastRow, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('header-resource-filter-done')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  }
}

Future<LayoutSettingsController> _open(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await LayoutSettingsController.load(
    SharedPreferencesLayoutSettingsStore(),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHeaderResourceChecklist(
              context: context,
              controller: settings,
              stateProvider: () => const GameState(
                hasPortData: true,
                maxShipCount: 9999,
                maxEquipmentCount: 99999,
              ),
              senka: 999999.99,
              rank: 99999,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return settings;
}
