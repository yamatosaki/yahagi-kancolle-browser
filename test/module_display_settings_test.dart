import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/module_display_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/fleet/repair_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/construction_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/fleet/expedition_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'fixtures/fleet_display_sample.dart';
import 'fixtures/kcsapi_fixtures.dart';
import 'package:yahagi_kancolle_browser/src/quest/pinned_quests_summary.dart';

class _Store extends GameStateStore {
  _Store(this.value);
  final GameState value;
  @override
  Future<GameState> load() async => value;
}

void main() {
  test('quest fields default to all and persist individual choices', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesLayoutSettingsStore();
    final settings = await LayoutSettingsController.load(store);
    addTearDown(settings.dispose);
    expect(settings.moduleDisplayFields('quests'), {
      'type',
      'number',
      'name',
      'progress',
    });
    await settings.setModuleDisplayFields('quests', {'number', 'progress'});
    final restored = await LayoutSettingsController.load(store);
    addTearDown(restored.dispose);
    expect(restored.moduleDisplayFields('quests'), {'number', 'progress'});
    await restored.setModuleDisplayFields('quests', {});
    expect(restored.moduleDisplayFields('quests'), isEmpty);
  });

  testWidgets('quest field combinations preserve navigation at narrow widths', (
    tester,
  ) async {
    final game = GameStateController();
    addTearDown(game.dispose);
    await game.initialize();
    game.accept(
      kcsapiEvent('/kcsapi/api_get_member/questlist', {
        'api_count': 1,
        'api_exec_count': 1,
        'api_list': [
          {
            'api_no': 101,
            'api_title': '测试任务名字',
            'api_detail': '',
            'api_category': 2,
            'api_type': 1,
            'api_state': 2,
            'api_progress_flag': 1,
          },
        ],
      }),
    );
    await game.idle;
    for (var mask = 0; mask < 16; mask++) {
      final keys = ['type', 'number', 'name', 'progress'];
      final fields = {
        for (var i = 0; i < 4; i++)
          if ((mask & (1 << i)) != 0) keys[i],
      };
      int? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: PinnedQuestsSummary(
                controller: game,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenQuest: (id) => opened = id,
                visible: fields,
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('#101'),
        fields.contains('number') ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('测试任务名字'),
        fields.contains('name') ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('50%'),
        fields.contains('progress') ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('出击'),
        fields.contains('type') ? findsOneWidget : findsNothing,
      );
      if (fields.isNotEmpty) {
        await tester.tap(find.byKey(const Key('quest-summary-item-101')));
        expect(opened, 101);
      }
      expect(tester.takeException(), isNull);
    }
  });

  test('维修简报舰队名称模式默认自定义名称并持久化', () async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(
      () => setRepairFleetSelectorLabelModeSetting(
        FleetSelectorLabelMode.customName,
      ),
    );
    final store = SharedPreferencesLayoutSettingsStore();
    final settings = await LayoutSettingsController.load(store);
    addTearDown(settings.dispose);
    expect(
      settings.repairFleetSelectorLabelMode,
      FleetSelectorLabelMode.customName,
    );

    await settings.setRepairFleetSelectorLabelMode(
      FleetSelectorLabelMode.number,
    );
    final reloaded = await LayoutSettingsController.load(store);
    addTearDown(reloaded.dispose);
    expect(
      reloaded.repairFleetSelectorLabelMode,
      FleetSelectorLabelMode.number,
    );
  });

  test(
    'existing expedition preferences retain time and explicit hiding persists',
    () async {
      SharedPreferences.setMockInitialValues({
        'module_display_expedition': <String>['number'],
      });
      final store = SharedPreferencesLayoutSettingsStore();
      final settings = await LayoutSettingsController.load(store);
      addTearDown(settings.dispose);
      expect(settings.moduleDisplayFields('expedition'), {'number', 'time'});
      await settings.setModuleDisplayFields('expedition', {'number'});
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.moduleDisplayFields('expedition'), {'number'});
    },
  );

  testWidgets(
    'expedition badges precede name and all four display options toggle independently',
    (tester) async {
      final game = GameStateController(
        gameStateStore: _Store(
          GameState.empty.copyWith(
            hasPortData: true,
            fleets: [
              Fleet(
                id: 2,
                name: '第二舰队很长的自定义名字',
                mission: FleetMission(
                  state: 1,
                  missionId: 100,
                  completionTime: DateTime.now().add(const Duration(hours: 2)),
                ),
              ),
            ],
            masterMissions: {
              100: const MasterMission(
                id: 100,
                name: '远征名称测试',
                duration: Duration(hours: 2),
                displayNumber: 'A1',
              ),
            },
          ),
        ),
      );
      addTearDown(game.dispose);
      await game.initialize();
      for (final width in [280.0, 360.0, 560.0]) {
        for (var mask = 0; mask < 16; mask++) {
          final keys = ['fleet', 'number', 'name', 'time'];
          final fields = {
            for (var i = 0; i < 4; i++)
              if ((mask & (1 << i)) != 0) keys[i],
          };
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: ExpeditionSummaryCard(
                      controller: game,
                      visible: fields,
                      collapsed: false,
                      onToggleCollapse: () {},
                      onOpenExpedition: () {},
                      onOpenExpeditionCheck: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final key in keys) {
            expect(
              find.byKey(Key('expedition-summary-$key-2')),
              fields.contains(key) ? findsOneWidget : findsNothing,
            );
          }
          if (fields.contains('number')) {
            expect(find.text('A1'), findsOneWidget);
          }
          if (mask == 7) {
            final fleet = tester.getRect(
              find.byKey(const Key('expedition-summary-fleet-2')),
            );
            final number = tester.getRect(
              find.byKey(const Key('expedition-summary-number-2')),
            );
            final name = tester.getRect(
              find.byKey(const Key('expedition-summary-name-2')),
            );
            expect(number.left, greaterThan(fleet.right));
            expect(name.left, greaterThan(number.right));
          }
          expect(tester.takeException(), isNull, reason: '$width $mask');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('English narrow expedition puts the name below its badges', (
    tester,
  ) async {
    final game = GameStateController(
      gameStateStore: _Store(
        GameState.empty.copyWith(
          hasPortData: true,
          fleets: [
            Fleet(
              id: 2,
              name: 'Second fleet',
              mission: FleetMission(
                state: 1,
                missionId: 100,
                completionTime: DateTime.now().add(const Duration(hours: 2)),
              ),
            ),
          ],
          masterMissions: {
            100: const MasterMission(
              id: 100,
              name: 'A long expedition name for a narrow display',
              duration: Duration(hours: 2),
              displayNumber: 'A1',
            ),
          },
        ),
      ),
    );
    addTearDown(game.dispose);
    await game.initialize();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 280,
              child: ExpeditionSummaryCard(
                controller: game,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenExpedition: () {},
                onOpenExpeditionCheck: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    final row = tester.getRect(
      find.byKey(const Key('expedition-summary-row-2')),
    );
    final fleet = tester.getRect(
      find.byKey(const Key('expedition-summary-fleet-2')),
    );
    final number = tester.getRect(
      find.byKey(const Key('expedition-summary-number-2')),
    );
    final name = tester.getRect(
      find.byKey(const Key('expedition-summary-name-2')),
    );
    final time = tester.getRect(
      find.byKey(const Key('expedition-summary-time-2')),
    );
    expect(find.text('A1'), findsOneWidget);
    expect(
      find.text('A long expedition name for a narrow display'),
      findsOneWidget,
    );
    expect(number.left, greaterThan(fleet.right));
    expect(number.top, fleet.top);
    expect(name.top, greaterThan(fleet.bottom));
    expect(name.top, greaterThan(number.bottom));
    expect(name.left, row.left);
    for (final rect in [fleet, number, name, time]) {
      expect(rect.left, greaterThanOrEqualTo(row.left));
      expect(rect.right, lessThanOrEqualTo(row.right));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'module choices persist independently and restore empty selections',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesLayoutSettingsStore();
      final settings = await LayoutSettingsController.load(store);
      addTearDown(settings.dispose);
      await settings.setModuleDisplayFields('land_base', {'range'});
      await settings.setModuleDisplayFields('repair', {});
      final restored = await LayoutSettingsController.load(store);
      addTearDown(restored.dispose);
      expect(restored.moduleDisplayFields('land_base'), {'range'});
      expect(restored.moduleDisplayFields('repair'), isEmpty);
      expect(restored.moduleDisplayFields('construction'), {
        'portrait',
        'empty',
      });
    },
  );
  testWidgets('compact dialogs have the approved options and a working reset', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    addTearDown(settings.dispose);
    for (final module in moduleDisplayOptions.keys) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showModuleDisplaySettings(context, settings, module),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('$module-capsule-logo')), findsOneWidget);
      expect(find.byKey(Key('$module-capsule-name')), findsOneWidget);
      expect(
        find.byType(FilterChip),
        findsNWidgets(moduleDisplayOptions[module]!.length + 2),
      );
      // Toggle capsule logo
      await tester.tap(find.byKey(Key('$module-capsule-logo')));
      await tester.pump();
      expect(settings.moduleShowLogo(module), isFalse);

      if (moduleDisplayOptions[module]!.isNotEmpty) {
        final option = moduleDisplayOptions[module]!.keys.first;
        await tester.tap(find.byKey(Key('$module-display-$option')));
        await tester.pump();
        expect(settings.moduleDisplayFields(module), isNot(contains(option)));
      }

      if (module == 'repair') {
        expect(
          find.byKey(const Key('repair-selector-label-custom-name')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('repair-selector-label-number')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('repair-selector-label-number')));
        await tester.pump();
        expect(
          settings.repairFleetSelectorLabelMode,
          FleetSelectorLabelMode.number,
        );
      }

      await tester.tap(find.byKey(Key('$module-display-reset')));
      await tester.pump();
      expect(settings.moduleShowLogo(module), isTrue);
      expect(settings.moduleShowName(module), isTrue);
      if (module == 'repair') {
        expect(
          settings.repairFleetSelectorLabelMode,
          FleetSelectorLabelMode.customName,
        );
      }

      if (moduleDisplayOptions[module]!.isNotEmpty) {
        final option = moduleDisplayOptions[module]!.keys.first;
        expect(settings.moduleDisplayFields(module), contains(option));
      }

      await tester.tap(find.byKey(Key('$module-display-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'dock cards filter slots, keep numbering and fit image/text modes',
    (tester) async {
      final game = GameStateController(
        gameStateStore: _Store(
          demoState().copyWith(
            repairDocks: [
              const RepairDock(id: 1),
              RepairDock(
                id: 2,
                state: 1,
                shipId: 3,
                completionTime: DateTime.now().add(const Duration(hours: 1)),
              ),
            ],
            constructionDocks: [
              const ConstructionDock(id: 1),
              const ConstructionDock(id: 2, state: 3, createdShipMasterId: 3),
            ],
          ),
        ),
      );
      addTearDown(game.dispose);
      await game.initialize();
      for (final module in ['repair', 'construction']) {
        for (final width in [280.0, 360.0, 560.0]) {
          for (final fields in [
            <String>{'portrait', 'empty'},
            <String>{'portrait'},
            <String>{'empty'},
            <String>{},
          ]) {
            final child = module == 'repair'
                ? RepairSummaryCard(
                    key: UniqueKey(),
                    controller: game,
                    visible: fields,
                    collapsed: false,
                    onToggleCollapse: () {},
                    onOpenRepair: (_) {},
                  )
                : ConstructionSummaryCard(
                    controller: game,
                    visible: fields,
                    collapsed: false,
                    onToggleCollapse: () {},
                    onOpenConstruction: () {},
                  );
            await tester.pumpWidget(
              MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: width, child: child),
                  ),
                ),
              ),
            );
            if (!fields.contains('portrait')) {
              expect(find.byType(ShipPortrait), findsNothing);
            }
            if (!fields.contains('empty')) {
              expect(find.text('2 · 文月改二'), findsOneWidget);
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$module $width $fields',
            );
          }
        }
      }
      // The same portrait/empty preference also applies to anchorage and Nosaki.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: RepairSummaryCard(
                key: UniqueKey(),
                controller: game,
                visible: const {},
                collapsed: false,
                onToggleCollapse: () {},
                onOpenRepair: (_) {},
              ),
            ),
          ),
        ),
      );
      for (final mode in ['anchorage', 'nosaki']) {
        await tester.tap(find.byKey(Key('repair-summary-mode-$mode')));
        await tester.pump();
        expect(find.byType(ShipPortrait), findsNothing);
        expect(find.text('1 · 日進甲'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'resetDashboardCardOrder restores hidden logo and name across all modules',
    () async {
      SharedPreferences.setMockInitialValues({
        'module_capsule_logo_fleet': false,
        'module_capsule_name_fleet': false,
        'module_capsule_logo_battle': false,
        'module_capsule_name_battle': false,
        'module_capsule_logo_repair': false,
        'module_capsule_name_repair': false,
      });
      final store = SharedPreferencesLayoutSettingsStore();
      final settings = await LayoutSettingsController.load(store);
      addTearDown(settings.dispose);

      expect(settings.moduleShowLogo('fleet'), isFalse);
      expect(settings.moduleShowName('fleet'), isFalse);
      expect(settings.moduleShowLogo('battle'), isFalse);
      expect(settings.moduleShowName('battle'), isFalse);
      expect(settings.moduleShowLogo('repair'), isFalse);
      expect(settings.moduleShowName('repair'), isFalse);

      await settings.resetDashboardCardOrder();

      expect(settings.moduleShowLogo('fleet'), isTrue);
      expect(settings.moduleShowName('fleet'), isTrue);
      expect(settings.moduleShowLogo('battle'), isTrue);
      expect(settings.moduleShowName('battle'), isTrue);
      expect(settings.moduleShowLogo('repair'), isTrue);
      expect(settings.moduleShowName('repair'), isTrue);

      final reloaded = await LayoutSettingsController.load(store);
      addTearDown(reloaded.dispose);
      expect(reloaded.moduleShowLogo('fleet'), isTrue);
      expect(reloaded.moduleShowName('fleet'), isTrue);
      expect(reloaded.moduleShowLogo('battle'), isTrue);
      expect(reloaded.moduleShowName('battle'), isTrue);
      expect(reloaded.moduleShowLogo('repair'), isTrue);
      expect(reloaded.moduleShowName('repair'), isTrue);
    },
  );

  test(
    'resetHdLayout and resetHdPortraitLayout restore hidden capsule logo and name',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesLayoutSettingsStore();
      final settings = await LayoutSettingsController.load(store);
      addTearDown(settings.dispose);

      await settings.setModuleShowLogo('fleet', false);
      await settings.setModuleShowName('expedition', false);
      expect(settings.moduleShowLogo('fleet'), isFalse);
      expect(settings.moduleShowName('expedition'), isFalse);

      await settings.resetHdLayout();
      expect(settings.moduleShowLogo('fleet'), isTrue);
      expect(settings.moduleShowName('expedition'), isTrue);

      await settings.setModuleShowLogo('quests', false);
      await settings.setModuleShowName('quests', false);
      expect(settings.moduleShowLogo('quests'), isFalse);
      expect(settings.moduleShowName('quests'), isFalse);

      await settings.resetHdPortraitLayout();
      expect(settings.moduleShowLogo('quests'), isTrue);
      expect(settings.moduleShowName('quests'), isTrue);
    },
  );
}
