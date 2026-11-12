import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/top_notice_settings_section.dart';

const _titles = {
  'sortieHeavyDamage': '出击大破提醒',
  'sortieSupply': '出击补给提醒',
  'expeditionHeavyDamage': '远征大破提醒',
  'expeditionSupply': '远征补给提醒',
  'expeditionSuccess': '远征成功提醒',
  'sortieCapacity': '出击容量提醒',
  'equipmentDevelopment': '装备开发',
  'equipmentImprovement': '装备改修',
  'modernization': '近代化改修',
  'marriage': '誓约',
  'practiceExperience': '演习经验',
  'questCompletion': '任务达成',
};

Finder _kindSwitch(String kind) =>
    find.byKey(Key('settings-top-notice-kind-$kind'));

Future<void> _pumpSection(
  WidgetTester tester,
  LayoutSettingsController controller, {
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TopNoticeSettingsSection(controller: controller),
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('notice switches follow the approved order and defaults', (
    tester,
  ) async {
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(controller.dispose);
    await _pumpSection(tester, controller);

    expect(controller.topNoticeEnabled, isTrue);
    var previousY = 0.0;
    for (final entry in _titles.entries) {
      final control = _kindSwitch(entry.key);
      expect(find.text(entry.value), findsOneWidget);
      final y = tester.getTopLeft(control).dy;
      expect(y, greaterThan(previousY));
      previousY = y;
      expect(tester.widget<Switch>(control).value, isTrue);
    }
    final expeditionSuccessRow = find
        .ancestor(
          of: _kindSwitch('expeditionSuccess'),
          matching: find.byType(MergeSemantics),
        )
        .first;
    expect(
      find.descendant(of: expeditionSuccessRow, matching: find.byType(Text)),
      findsOneWidget,
    );
    expect(find.text('进入出击页时提示有大破舰的编队'), findsNothing);
    expect(find.text('削甲顶部提醒'), findsNothing);
    expect(find.text('智能进击损管提示'), findsNothing);
  });

  testWidgets('turning off the master keeps and disables each preference', (
    tester,
  ) async {
    final controller = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(controller.dispose);
    await _pumpSection(tester, controller);
    final sortieHeavy = _kindSwitch('sortieHeavyDamage');
    final expeditionSupply = _kindSwitch('expeditionSupply');
    final expeditionSuccess = _kindSwitch('expeditionSuccess');
    final sortieHeavyLabel = find.text('出击大破提醒');
    final enabledLabelColor = tester
        .widget<Text>(sortieHeavyLabel)
        .style
        ?.color;
    await tester.tap(sortieHeavy);
    await tester.tap(expeditionSupply);
    await tester.tap(expeditionSuccess);
    await tester.pumpAndSettle();

    await controller.setTopNoticeDurationSeconds(15);
    await controller.setTopNoticeEnabled(false);
    await tester.pumpAndSettle();
    final duration = find.byKey(
      const Key('settings-top-notice-duration-dropdown'),
    );
    expect(tester.widget<DropdownButton<int>>(duration).onChanged, isNull);
    for (final kind in _titles.keys) {
      expect(tester.widget<Switch>(_kindSwitch(kind)).onChanged, isNull);
    }
    expect(
      tester.widget<Text>(sortieHeavyLabel).style?.color,
      isNot(enabledLabelColor),
    );
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        tester.getSemantics(sortieHeavy),
        isSemantics(
          label: '出击大破提醒',
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
          hasToggledState: true,
          isToggled: false,
        ),
      );
    } finally {
      semantics.dispose();
    }
    expect(tester.widget<Switch>(sortieHeavy).value, isFalse);
    expect(tester.widget<Switch>(expeditionSupply).value, isFalse);
    expect(tester.widget<Switch>(expeditionSuccess).value, isFalse);

    final restored = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(restored.dispose);
    expect(restored.topNoticeEnabled, isFalse);
    await restored.setTopNoticeEnabled(true);
    await _pumpSection(tester, restored);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<int>>(duration).value, 15);
    expect(tester.widget<Switch>(sortieHeavy).value, isFalse);
    expect(tester.widget<Switch>(expeditionSupply).value, isFalse);
    expect(tester.widget<Switch>(expeditionSuccess).value, isFalse);
    for (final kind in _titles.keys) {
      expect(tester.widget<Switch>(_kindSwitch(kind)).onChanged, isNotNull);
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('notice settings fit a narrow screen in $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(controller.dispose);
      await _pumpSection(
        tester,
        controller,
        locale: locale,
        textScaler: const TextScaler.linear(1.3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final lastSwitch = _kindSwitch('questCompletion');
      await tester.ensureVisible(lastSwitch);
      await tester.pumpAndSettle();
      expect(lastSwitch.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
