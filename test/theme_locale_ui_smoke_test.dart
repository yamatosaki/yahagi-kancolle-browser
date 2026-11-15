import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_check_page.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/background_game_retention_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/screen_settings_page.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_theme.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/toolbox_page.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _scenarios = [
  (size: Size(320, 780), scale: 1.4),
  (size: Size(390, 844), scale: 1.0),
  (size: Size(844, 390), scale: 1.0),
  (size: Size(1280, 800), scale: 1.0),
];

void main() {
  for (final page in [
    'settings',
    'fleet',
    'expedition',
    'quest',
    for (final mode in ToolboxMode.values) 'tools-${mode.name}',
    'logbook',
  ]) {
    testWidgets(
      '$page renders across three themes, five locales and screen sizes',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final previousTimer = GameStateController.disableTimerForTest;
        GameStateController.disableTimerForTest = true;
        addTearDown(
          () => GameStateController.disableTimerForTest = previousTimer,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = GameStateController()
          ..accept(start2Event)
          ..accept(portEvent)
          ..accept(slotItemEvent);
        await controller.idle;
        addTearDown(controller.dispose);
        final layout = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        final display = await DisplayModeController.load(
          MemoryDisplayModeStore(),
        );
        final audio = await GameAudioController.load(
          SharedPreferencesGameAudioStore(),
        );
        final retention = await BackgroundGameRetentionController.load(
          SharedPreferencesBackgroundGameRetentionStore(),
        );
        retention.reportSyncError('后台保活启动失败：native_test_error');
        addTearDown(layout.dispose);
        addTearDown(display.dispose);
        addTearDown(audio.dispose);
        addTearDown(retention.dispose);
        final database = page == 'logbook'
            ? await LogbookDatabase.openForTesting()
            : null;
        if (database != null) {
          addTearDown(database.close);
          await _populateLogbook(database);
          await database.insertResourceSnapshot(controller.state);
        }
        final battle = BattleController(gameState: () => controller.state);
        addTearDown(battle.dispose);
        final failures = <String>[];
        var currentLabel = page;
        final originalErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) =>
            failures.add('$currentLabel: ${details.toString()}');
        addTearDown(() => FlutterError.onError = originalErrorHandler);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        });

        try {
          for (final mode in AppThemeMode.values) {
            await layout.setAppThemeMode(mode);
            for (final locale in AppLocalizations.supportedLocales) {
              for (final scenario in _scenarios) {
                final label =
                    '$page/$mode/$locale/${scenario.size}/${scenario.scale}';
                currentLabel = label;
                tester.view.physicalSize = scenario.size;
                final child = page.startsWith('tools-')
                    ? ToolboxPage(
                        state: controller.state,
                        mode: ToolboxMode.values.byName(page.substring(6)),
                        compositionInitiallyShowSaved: false,
                      )
                    : switch (page) {
                        'settings' => ScreenSettingsPage(
                          layoutSettingsController: layout,
                          displayModeController: display,
                          audioController: audio,
                          backgroundGameRetentionController: retention,
                        ),
                        'fleet' => FleetInformationCenter(
                          controller: controller,
                        ),
                        'expedition' => ExpeditionCheckPage(
                          controller: controller,
                          onBack: () {},
                        ),
                        'quest' => QuestCenterPage(
                          controller: controller,
                          catalog: _longQuestCatalog,
                          mode: QuestCenterMode.all,
                          initialQuestId: 90001,
                        ),
                        _ => LogbookPage(
                          battleController: battle,
                          database: database,
                        ),
                      };
                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey(label),
                    locale: locale,
                    theme: createAppTheme(mode: mode),
                    themeAnimationDuration: Duration.zero,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                      child: child!,
                    ),
                    home: Scaffold(body: child),
                  ),
                );
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 300));
                _collectException(tester, failures, label);

                if (page == 'settings' && locale.languageCode != 'zh') {
                  expect(find.text('后台保活启动失败：native_test_error'), findsNothing);
                }
                if (page == 'settings') {
                  final dropdown = find.byKey(
                    const Key('settings-app-theme-dropdown'),
                  );
                  await tester.ensureVisible(dropdown);
                  await tester.pump();
                  final l10n = lookupAppLocalizations(locale);
                  final selectedLabel = switch (mode) {
                    AppThemeMode.dark => l10n.themeClassicDark,
                    AppThemeMode.seaSalt => l10n.themeSeaSaltTeal,
                    AppThemeMode.skyBlue => l10n.themeClearSkyBlue,
                  };
                  _expectReadableText(
                    tester,
                    find.descendant(
                      of: dropdown,
                      matching: find.text(selectedLabel),
                    ),
                    reason: '$label/selected-theme',
                  );
                  await tester.tap(dropdown);
                  await tester.pumpAndSettle();
                  for (final name in [
                    l10n.themeClassicDark,
                    l10n.themeSeaSaltTeal,
                    l10n.themeClearSkyBlue,
                  ]) {
                    _expectReadableText(
                      tester,
                      find.text(name).last,
                      reason: '$label/theme-menu/$name',
                    );
                  }
                  tester.state<NavigatorState>(find.byType(Navigator)).pop();
                  await tester.pumpAndSettle();
                  _collectException(tester, failures, '$label/theme-menu');
                }

                if (page == 'fleet') {
                  final equipment = find.byKey(
                    const Key('fleet-equipment-row-9001-0'),
                  );
                  if (equipment.evaluate().isNotEmpty) {
                    await tester.ensureVisible(equipment);
                    await tester.pump();
                    await tester.tap(equipment);
                    await tester.pump(const Duration(milliseconds: 300));
                    expect(
                      find.byKey(
                        const Key('fleet-detail-equipment-name-9001-0'),
                      ),
                      findsOneWidget,
                    );
                    _collectException(
                      tester,
                      failures,
                      '$label/equipment-details',
                    );
                  }
                  final los = find.byKey(const Key('fleet-los-metric'));
                  if (los.evaluate().isNotEmpty) {
                    await tester.ensureVisible(los);
                    await tester.pump();
                    await tester.tap(los);
                    await tester.pump();
                    await tester.pump(const Duration(milliseconds: 300));
                    final details = find.byKey(
                      const Key('fleet-los-details-popover'),
                    );
                    expect(details, findsOneWidget);
                    expect(
                      find.descendant(
                        of: details,
                        matching: find.text(
                          lookupAppLocalizations(locale).losDetails,
                        ),
                      ),
                      findsOneWidget,
                    );
                    _collectException(tester, failures, '$label/los-popover');
                    await tester.tap(
                      find.byKey(const Key('fleet-los-details-close')),
                    );
                    await tester.pump();
                    await tester.pump(const Duration(milliseconds: 300));
                    expect(details, findsNothing);
                  }
                }

                if (page == 'expedition') {
                  await tester.tap(
                    find.byKey(const Key('expedition-mission-picker')),
                  );
                  await tester.pumpAndSettle();
                  expect(
                    find.byKey(const Key('expedition-mission-picker-dialog')),
                    findsOneWidget,
                  );
                  _collectException(tester, failures, '$label/mission-dialog');
                  await tester.tap(
                    find.byKey(const Key('expedition-mission-option-5')),
                  );
                  await tester.pumpAndSettle();
                  _collectException(
                    tester,
                    failures,
                    '$label/mission-selected',
                  );
                }

                if (page == 'quest') {
                  for (final tab in ['conditions', 'rewards', 'relations']) {
                    final tabButton = find.byKey(Key('quest-detail-tab-$tab'));
                    if (tabButton.evaluate().isNotEmpty) {
                      await tester.ensureVisible(tabButton);
                      await tester.pump();
                      await tester.tap(tabButton);
                      await tester.pump();
                      _collectException(tester, failures, '$label/$tab');
                    }
                  }
                }

                // Build lazily rendered content at the opposite end of each page.
                final scrollables = tester
                    .stateList<ScrollableState>(find.byType(Scrollable))
                    .toList();
                for (final scrollable in scrollables) {
                  final position = scrollable.position;
                  if (position.hasContentDimensions &&
                      axisDirectionToAxis(position.axisDirection) ==
                          Axis.vertical &&
                      position.maxScrollExtent > 0) {
                    position.jumpTo(position.maxScrollExtent);
                  }
                }
                await tester.pump();
                _collectException(tester, failures, '$label/scrolled');
                if (page == 'logbook') {
                  final filter = find.byKey(const Key('logbook-filter-button'));
                  await tester.tap(filter);
                  await tester.pumpAndSettle();
                  expect(
                    find.byKey(const Key('logbook-filter-panel')),
                    findsOneWidget,
                  );
                  _collectException(tester, failures, '$label/filter-panel');
                  tester.state<NavigatorState>(find.byType(Navigator)).pop();
                  await tester.pumpAndSettle();
                  final tabs = tester.widget<TabBarView>(
                    find.byType(TabBarView),
                  );
                  for (var index = 1; index < 6; index++) {
                    tabs.controller!.index = index;
                    await tester.pumpAndSettle();
                    _collectException(tester, failures, '$label/tab-$index');
                  }
                }
                await tester.pumpWidget(const SizedBox());
                await tester.pump();
              }
            }
          }
        } finally {
          try {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            // Drain resource snapshot futures while their fake-async zone is
            // still being pumped, before the test runner starts tearDown.
            await database?.close();
          } finally {
            FlutterError.onError = originalErrorHandler;
          }
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      },
    );
  }
}

Future<void> _populateLogbook(LogbookDatabase database) async {
  final timestamp = DateTime.utc(2026, 10, 20, 12).millisecondsSinceEpoch;
  await database.insertBattleRecord(
    BattleRecord(
      battle: const LiveBattle(
        context: BattleContext(mapAreaId: 7, mapInfoNo: 5, node: 12),
        rank: BattleRank.s,
        enemyFleetName: '深海連合艦隊・長距離海上護衛部隊・重巡洋艦を含む敵増援部隊',
        friendMain: [
          BattleShipSnapshot(
            masterId: 1,
            name: '矢矧改二乙・長距離護衛部隊旗艦',
            side: BattleSide.friend,
            fleetRole: BattleFleetRole.main,
            position: 0,
            initialHp: 80,
            maxHp: 80,
            currentHp: 10,
          ),
        ],
      ),
      completedAt: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
    ),
    mapName: '長距離航海海域・敵増援部隊との決戦海域',
    nodeLabel: '長距離航海終点',
  );
  await database.insertExpeditionResult(
    expeditionId: 5,
    name: '海上護衛任務・長距離航海と資源輸送を兼ねた海上護衛作戦',
    result: 2,
    materials: [999999, 888888, 777777, 666666],
    item1Name: '開発資材',
    item1Count: 999,
    timestamp: timestamp,
  );
  await database.insertConstructionRecord(
    timestamp: timestamp,
    constructionType: '大型建造',
    shipId: 1,
    shipName: '矢矧改二乙',
    shipType: '軽巡洋艦',
    fuel: 9999,
    ammo: 9999,
    steel: 9999,
    bauxite: 9999,
    developmentMaterial: 100,
    secretaryName: '矢矧改二乙 Lv.175',
  );
  await database.insertDevelopmentRecord(
    timestamp: timestamp,
    success: true,
    equipmentId: 1,
    equipmentName: '12.7cm連装高角砲改二・長距離護衛部隊特別装備',
    equipmentType: '小口径主砲',
    equipmentIconId: 1,
    fuel: 999,
    ammo: 999,
    steel: 999,
    bauxite: 999,
    secretaryName: '矢矧改二乙 Lv.175',
  );
  await database.insertRetirementRecord(
    timestamp: timestamp,
    type: '解体',
    shipType: '軽巡洋艦',
    shipName: '矢矧改二乙・長距離護衛部隊旗艦',
    level: 175,
  );
}

void _collectException(
  WidgetTester tester,
  List<String> failures,
  String label,
) {
  final exception = tester.takeException();
  if (exception != null) failures.add('$label: $exception');
}

void _expectReadableText(
  WidgetTester tester,
  Finder text, {
  required String reason,
}) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
  expect(
    paragraph.getMaxIntrinsicHeight(paragraph.size.width),
    lessThanOrEqualTo(paragraph.size.height + .1),
    reason: reason,
  );
}

final _longQuestCatalog = QuestCatalog([
  QuestCatalogEntry(
    gameId: 90001,
    code: 'B999',
    name: '「改装特務艦隊」長距離航海における海上護衛任務と艦隊運用の総合演習',
    description:
        '第一艦隊に旗艦「矢矧改二乙」を配備し、長距離航海における海上護衛任務を実施せよ。'
        '多言語表示でも詳細条件と報酬内容を最後まで確認できること。',
    rewards:
        '二回選択報酬：[装備運用枠+8、二式爆雷★4、開発資材×40]'
        '[61cm五連装(酸素)魚雷★4×2、12.7cm連装高角砲改二★4、新型兵装資材×3]',
    materials: [999999, 12000, 888888, 99999],
  ),
]);
