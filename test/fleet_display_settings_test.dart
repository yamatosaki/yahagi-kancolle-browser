import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/fleet/dashboard_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  test(
    'mechanism preferences keep the original field when saved again',
    () async {
      SharedPreferences.setMockInitialValues({
        'fleet_brief_display_fields_v2': ['hp', 'mechanisms'],
      });
      final store = SharedPreferencesLayoutSettingsStore();
      final controller = await LayoutSettingsController.load(store);
      addTearDown(controller.dispose);
      expect(controller.fleetDisplayFields, {'hp', 'mechanisms'});
      expect(controller.hdFleetDisplayFields, contains('mechanisms'));

      await controller.setFleetDisplayFields(controller.fleetDisplayFields);
      expect((await store.loadFleetDisplayFields())!.toSet(), {
        'hp',
        'mechanisms',
      });
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.fleetDisplayFields, {'hp', 'mechanisms'});
    },
  );

  test(
    'ordinary and HD settings share the combined mechanism switch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesLayoutSettingsStore();
      final controller = await LayoutSettingsController.load(store);
      addTearDown(controller.dispose);
      expect(controller.fleetDisplayFields, contains('mechanisms'));
      expect(controller.hdFleetDisplayFields, contains('mechanisms'));

      await controller.setHdFleetDisplayFields(
        controller.hdFleetDisplayFields.difference({'mechanisms'}),
      );
      expect(controller.fleetDisplayFields, isNot(contains('mechanisms')));
      await controller.setFleetDisplayFields({
        ...controller.fleetDisplayFields,
        'mechanisms',
      });
      expect(controller.hdFleetDisplayFields, contains('mechanisms'));
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.fleetDisplayFields, contains('mechanisms'));
      expect(restored.hdFleetDisplayFields, contains('mechanisms'));
    },
  );

  testWidgets('two-column editor allows seven persisted summary choices', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesLayoutSettingsStore();
    final controller = await LayoutSettingsController.load(store);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FleetDisplaySettingsSection(
              controller: controller,
              twoColumns: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('舰队汇总 · 7 / 7'), findsOneWidget);
    expect(find.text('最多同时显示 7 项；先取消一项即可选择其他指标。'), findsOneWidget);
    final firepower = find.byKey(const Key('fleet-display-firepower'));
    final antiAir = find.byKey(const Key('fleet-display-anti-air'));
    final transport = find.byKey(const Key('fleet-display-transport-points'));
    expect(tester.widget<FilterChip>(antiAir).onSelected, isNull);
    expect(tester.widget<FilterChip>(transport).selected, isFalse);
    expect(tester.widget<FilterChip>(transport).onSelected, isNull);
    await tester.ensureVisible(firepower);
    await tester.tap(firepower);
    await tester.pumpAndSettle();
    await tester.ensureVisible(antiAir);
    await tester.tap(antiAir);
    await tester.pumpAndSettle();
    expect(
      controller.hdFleetDisplayFields.intersection(summaryFields).length,
      7,
    );
    expect(controller.hdFleetDisplayFields, contains('anti-air'));
    expect(controller.hdFleetDisplayFields, isNot(contains('firepower')));
    expect(controller.fleetDisplayFields.intersection(summaryFields).length, 5);
    await tester.tap(antiAir);
    await tester.pumpAndSettle();
    await tester.ensureVisible(transport);
    await tester.tap(transport);
    await tester.pumpAndSettle();
    expect(controller.hdFleetDisplayFields, contains('transport-points'));
    expect(controller.fleetDisplayFields, isNot(contains('transport-points')));
    final restored = await LayoutSettingsController.load(store);
    addTearDown(restored.dispose);
    expect(restored.hdFleetDisplayFields, controller.hdFleetDisplayFields);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'collapsed fleet gear opens a compact responsive dialog and saves selections',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      final game = GameStateController();
      addTearDown(settings.dispose);
      addTearDown(game.dispose);
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(900, 480), const Size(360, 740)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => FleetSummaryCard(
                  controller: game,
                  collapsed: true,
                  onToggleCollapse: () {},
                  onOpenFleet: (_) {},
                  onOpenDisplaySettings: () =>
                      showFleetDisplaySettings(context, settings),
                ),
              ),
            ),
          ),
        );
        await tester.tap(
          find.byKey(const Key('fleet-display-settings-button')),
        );
        await tester.pumpAndSettle();
        final portrait = find.byKey(const Key('fleet-display-portrait'));
        final equipment = find.byKey(const Key('fleet-display-equipment'));
        expect(tester.getTopLeft(portrait).dy, tester.getTopLeft(equipment).dy);
        await tester.tap(portrait);
        await tester.pump();
        expect(
          tester.widget<FilterChip>(portrait).selected,
          settings.fleetDisplayFields.contains('portrait'),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('fleet-display-close')));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'selection persists, caps restored metrics, and preserves empty choices',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesLayoutSettingsStore();
      final controller = await LayoutSettingsController.load(store);
      addTearDown(controller.dispose);
      await controller.setFleetDisplayFields(allFields);
      expect(
        controller.fleetDisplayFields.intersection(summaryFields).length,
        5,
      );
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.fleetDisplayFields, controller.fleetDisplayFields);
      await controller.setFleetDisplayFields({});
      final empty = await LayoutSettingsController.load(store);
      addTearDown(empty.dispose);
      expect(empty.fleetDisplayFields, isEmpty);
    },
  );
  test('fleet label modes and cleared-map visibility persist', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesLayoutSettingsStore();
    var controller = await LayoutSettingsController.load(store);
    expect(
      controller.fleetShipTypeLabelMode,
      FleetShipTypeLabelMode.localizedName,
    );
    expect(
      controller.fleetSelectorLabelMode,
      FleetSelectorLabelMode.customName,
    );
    expect(controller.showClearedMaps, isFalse);

    await controller.setFleetShipTypeLabelMode(
      FleetShipTypeLabelMode.abbreviation,
    );
    await controller.setFleetSelectorLabelMode(FleetSelectorLabelMode.number);
    await controller.setShowClearedMaps(true);
    controller.dispose();

    controller = await LayoutSettingsController.load(store);
    expect(
      controller.fleetShipTypeLabelMode,
      FleetShipTypeLabelMode.abbreviation,
    );
    expect(controller.fleetSelectorLabelMode, FleetSelectorLabelMode.number);
    expect(controller.showClearedMaps, isTrue);

    await controller.setShowClearedMaps(false);
    controller.dispose();
    controller = await LayoutSettingsController.load(store);
    addTearDown(controller.dispose);
    expect(controller.showClearedMaps, isFalse);
  });
  test(
    'existing countdown preference migrates once into selected metrics',
    () async {
      SharedPreferences.setMockInitialValues({
        'layout_fleet_morale_metric_mode': 'recoveryCountdown',
      });
      final store = SharedPreferencesLayoutSettingsStore();
      final controller = await LayoutSettingsController.load(store);
      addTearDown(controller.dispose);
      expect(controller.fleetDisplayFields, contains('recovery-countdown'));
      expect(
        controller.fleetDisplayFields,
        isNot(contains('minimum-condition')),
      );
      await controller.setFleetDisplayFields(defaultFields);
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.fleetDisplayFields, defaultFields);
    },
  );
  testWidgets(
    'settings allow replacement at five and a single mechanism switch',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesLayoutSettingsStore();
      final controller = await LayoutSettingsController.load(store);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FleetDisplaySettingsSection(controller: controller),
            ),
          ),
        ),
      );
      FilterChip checkbox(String id) =>
          tester.widget(find.byKey(Key('fleet-display-$id')));
      expect(checkbox('firepower').onSelected, isNull);
      expect(checkbox('transport-points').selected, isFalse);
      expect(checkbox('transport-points').onSelected, isNull);
      checkbox('total-level').onSelected!(false);
      await tester.pump();
      expect(checkbox('firepower').onSelected, isNotNull);
      checkbox('firepower').onSelected!(true);
      await tester.pump();
      expect(
        controller.fleetDisplayFields.intersection(summaryFields).length,
        5,
      );
      expect(checkbox('torpedo').onSelected, isNull);
      checkbox('firepower').onSelected!(false);
      await tester.pump();
      checkbox('transport-points').onSelected!(true);
      await tester.pumpAndSettle();
      expect(checkbox('transport-points').selected, isTrue);
      expect(find.text('普通（战车）运输量'), findsOneWidget);
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.fleetDisplayFields, contains('transport-points'));
      final mechanisms = tester.widget<FilterChip>(
        find.byKey(const Key('fleet-display-mechanisms')),
      );
      expect(
        mechanisms.label,
        isA<Text>().having((text) => text.data, 'text', '特殊机制'),
      );
      expect(mechanisms.tooltip, '先制对潜、对空 CI、喷进弹幕、空母夜袭与旗舰特殊攻击');
      for (final field in ['asw', 'aaci', 'rocket', 'night', 'special']) {
        expect(find.byKey(Key('fleet-display-$field')), findsNothing);
      }
      mechanisms.onSelected!(false);
      await tester.pump();
      expect(controller.fleetDisplayFields, isNot(contains('mechanisms')));
      expect(tester.takeException(), isNull);

      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('fleet-ship-type-label-abbreviation')),
            )
            .selected,
        isFalse,
      );
      await tester.tap(
        find.byKey(const Key('fleet-ship-type-label-abbreviation')),
      );
      await tester.pump();
      expect(
        controller.fleetShipTypeLabelMode,
        FleetShipTypeLabelMode.abbreviation,
      );

      final customName = find.byKey(
        const Key('fleet-selector-label-custom-name'),
      );
      final number = find.byKey(const Key('fleet-selector-label-number'));
      expect(tester.widget<ChoiceChip>(customName).selected, isTrue);
      expect(tester.widget<ChoiceChip>(number).selected, isFalse);
      await tester.tap(number);
      await tester.pump();
      expect(controller.fleetSelectorLabelMode, FleetSelectorLabelMode.number);
    },
  );

  testWidgets(
    'fleet capsule logo and name toggle independently and reset restores both',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesLayoutSettingsStore();
      final controller = await LayoutSettingsController.load(store);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FleetDisplaySettingsSection(controller: controller),
            ),
          ),
        ),
      );

      expect(find.text('胶囊外观'), findsOneWidget);
      final logoChip = find.byKey(const Key('fleet-capsule-logo'));
      final nameChip = find.byKey(const Key('fleet-capsule-name'));
      expect(logoChip, findsOneWidget);
      expect(nameChip, findsOneWidget);
      expect(tester.widget<FilterChip>(logoChip).selected, isTrue);
      expect(tester.widget<FilterChip>(nameChip).selected, isTrue);

      await tester.tap(logoChip);
      await tester.pump();
      expect(controller.moduleShowLogo('fleet'), isFalse);

      await tester.tap(nameChip);
      await tester.pump();
      expect(controller.moduleShowName('fleet'), isFalse);

      await controller.setFleetSelectorLabelMode(FleetSelectorLabelMode.number);

      await tester.tap(find.byKey(const Key('fleet-display-default')));
      await tester.pump();
      expect(controller.moduleShowLogo('fleet'), isTrue);
      expect(controller.moduleShowName('fleet'), isTrue);
      expect(
        controller.fleetSelectorLabelMode,
        FleetSelectorLabelMode.customName,
      );
    },
  );

  testWidgets('DashboardCard respects showLogo and showTitle visibility', (
    tester,
  ) async {
    for (final showLogo in [true, false]) {
      for (final showTitle in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DashboardCard(
                title: '测试标题',
                icon: const Icon(Icons.explore, key: Key('test-icon')),
                collapsed: false,
                showLogo: showLogo,
                showTitle: showTitle,
                onToggleCollapse: () {},
                child: const Text('内容'),
              ),
            ),
          ),
        );

        if (showLogo) {
          expect(find.byKey(const Key('test-icon')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('test-icon')), findsNothing);
        }

        if (showTitle) {
          expect(find.text('测试标题'), findsOneWidget);
        } else {
          expect(find.text('测试标题'), findsNothing);
        }
      }
    }
  });
}
