import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_page.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/layout/ui_scale.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scale in [1.0, minimalUiScale]) {
    for (final occupied in [
      const EdgeInsets.only(left: 41),
      const EdgeInsets.only(right: 41),
      const EdgeInsets.only(bottom: 41),
    ]) {
      testWidgets(
        'logbook keeps workspace bounds $occupied without extra SafeArea gap at scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(915, 412);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final database = await LogbookDatabase.openForTesting();
          addTearDown(database.close);
          final controller = BattleController(gameState: () => GameState.empty);
          addTearDown(controller.dispose);

          // Exercise changing system insets without recreating the logbook state.
          for (final inset in [0.0, 36.0, 60.0, 0.0]) {
            await tester.pumpWidget(
              MaterialApp(
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      size: const Size(915, 412),
                      padding: EdgeInsets.all(inset),
                      viewPadding: EdgeInsets.all(inset),
                    ),
                    child: Padding(
                      padding: occupied,
                      child: UiScale(
                        scale: scale,
                        child: LogbookPage(
                          battleController: controller,
                          database: database,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final bounds = tester.getRect(find.byType(TabBarView));
            expect(bounds.left, closeTo(occupied.left, .001));
            expect(bounds.right, closeTo(915 - occupied.right, .001));
            expect(bounds.bottom, closeTo(412 - occupied.bottom, .001));
            final table = tester.getRect(
              find.byKey(const Key('logbook-table-sortie')),
            );
            expect(table.left, closeTo(bounds.left + 12 * scale, .001));
            expect(table.right, closeTo(bounds.right - 12 * scale, .001));
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final inset in [0.0, 36.0]) {
    for (final parentSafeArea in [false, true]) {
      testWidgets(
        'record and detail share safe bounds inset=$inset parent=$parentSafeArea',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(915, 412);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final database = await LogbookDatabase.openForTesting();
          addTearDown(database.close);
          final controller = BattleController(gameState: () => GameState.empty);
          addTearDown(controller.dispose);
          await database.insertBattleRecord(
            BattleRecord(
              battle: const LiveBattle(
                context: BattleContext(mapAreaId: 1, mapInfoNo: 1, node: 1),
                rank: BattleRank.s,
              ),
              completedAt: DateTime.utc(2026, 9, 5, 2),
              detail: const BattleDetailSnapshot(
                completedAtMillis: 0,
                mapLabel: '1-1',
                nodeLabel: 'A点',
                rank: 'S',
                enemyFleetName: '测试敌舰队',
              ),
            ),
            mapName: '安全区域海域',
          );
          final page = LogbookPage(
            battleController: controller,
            database: database,
          );
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(915, 412),
                    padding: EdgeInsets.fromLTRB(inset, 0, inset / 2, inset),
                    viewPadding: EdgeInsets.fromLTRB(
                      inset,
                      0,
                      inset / 2,
                      inset,
                    ),
                  ),
                  child: parentSafeArea
                      ? SafeArea(top: false, child: page)
                      : page,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final expectedInset = parentSafeArea ? inset : 0.0;
          final bounds = tester.getRect(find.byType(TabBarView));
          expect(bounds.left, expectedInset);
          expect(bounds.right, 915 - expectedInset / 2);
          expect(bounds.bottom, 412 - expectedInset);
          final tableLeft = tester
              .getRect(find.byKey(const Key('logbook-table-sortie')))
              .left;
          await tester.tap(find.text('安全区域海域 (1-1)'));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const Key('battle-detail-page'))),
            bounds,
          );
          expect(
            tester.getRect(find.byKey(const Key('battle-detail-back'))).left,
            greaterThanOrEqualTo(bounds.left),
          );
          await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(
                  find.byKey(const Key('battle-detail-filter-container')),
                )
                .left,
            tableLeft,
          );
          await tester.tap(find.byKey(const Key('battle-detail-back')));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const Key('logbook-table-sortie'))).left,
            tableLeft,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test('sortie status keeps official labels and marks legacy values', () {
    expect(sortieStatusLabel('普通战斗'), '普通战斗');
    expect(sortieStatusLabel(' 路线选择 '), '路线选择');
    expect(sortieStatusLabel(1), '旧版记录');
    expect(sortieStatusLabel(6), '旧版记录');
    expect(sortieStatusLabel('1'), '旧版记录');
    expect(sortieStatusLabel(null), '旧版记录');
    expect(sortieStatusLabel(''), '旧版记录');
  });

  testWidgets('top switcher places experience immediately after sortie', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => LogbookSegmented(
            selectedIndex: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );

    final labels = ['出击', '经验', '远征', '建造', '开发', '除籍', '资源'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    for (var index = 1; index < labels.length; index++) {
      expect(
        tester.getTopLeft(find.text(labels[index])).dx,
        greaterThan(tester.getTopLeft(find.text(labels[index - 1])).dx),
      );
    }
    await tester.tap(find.text('远征'));
    expect(selected, 1);
    await tester.tap(find.text('经验'));
    expect(selected, 6);
    expect(find.text('本次出击'), findsNothing);
    expect(find.text('历史战果'), findsNothing);
  });

  testWidgets('experience slides in the direction of the visible tab order', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    var selected = 6;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                LogbookSegmented(
                  selectedIndex: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
                Expanded(
                  child: LogbookPage(
                    battleController: controller,
                    database: database,
                    selectedTabIndex: selected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pages = find.descendant(
      of: find.byType(TabBarView),
      matching: find.byType(PageView),
    );
    Future<void> checkSlide(String tab, {required bool toRight}) async {
      await tester.tap(find.byKey(Key('logbook-tab-$tab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final pageController = tester.widget<PageView>(pages).controller!;
      final start = pageController.page!;
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        pageController.page!,
        toRight ? greaterThan(start) : lessThan(start),
        reason: 'Switching to $tab must follow its position in the header.',
      );
      await tester.pumpAndSettle();
    }

    for (final tab in [
      'sortie',
      'expedition',
      'construction',
      'development',
      'retirement',
      'resource',
    ]) {
      final toRight = tab != 'sortie';
      await checkSlide(tab, toRight: toRight);
      await checkSlide('experience', toRight: !toRight);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal table gestures cannot switch logbook categories', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(740, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(mapAreaId: 2, mapInfoNo: 3, node: 5),
          rank: BattleRank.s,
        ),
        completedAt: DateTime.utc(2026, 8, 11, 13, 15),
      ),
      mapName: '东部奥廖尔海',
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tabs = tester.widget<TabBarView>(find.byType(TabBarView));
    expect(tabs.physics, isA<NeverScrollableScrollPhysics>());

    final horizontal = find.byKey(
      const Key('logbook-sortie-horizontal-scroll'),
    );
    final scrollable = find.descendant(
      of: horizontal,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    final timeBefore = tester.getRect(find.text('08-11 22:15')).left;
    final mapBefore = tester.getRect(find.text('东部奥廖尔海 (2-3)')).left;
    final nodeBefore = tester.getRect(find.text('节点')).left;
    await tester.drag(horizontal, const Offset(-240, 0));
    await tester.pumpAndSettle();
    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, greaterThan(before));
    expect(tester.getRect(find.text('08-11 22:15')).left, lessThan(timeBefore));
    expect(tester.getRect(find.text('东部奥廖尔海 (2-3)')).left, mapBefore);
    expect(tester.getRect(find.text('节点')).left, lessThan(nodeBefore));
    expect(find.byKey(const Key('logbook-table-sortie')), findsOneWidget);
  });

  testWidgets('only a new battle row with captured detail opens the viewer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(mapAreaId: 1, mapInfoNo: 1, node: 1),
          rank: BattleRank.a,
        ),
        completedAt: DateTime.utc(2026, 9, 5, 1),
      ),
      mapName: '旧战斗海域',
    );
    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(mapAreaId: 6, mapInfoNo: 2, node: 5),
          rank: BattleRank.s,
        ),
        completedAt: DateTime.utc(2026, 9, 5, 2),
        detail: const BattleDetailSnapshot(
          completedAtMillis: 1788534000000,
          mapLabel: '6-2',
          nodeLabel: 'E点',
          rank: 'S',
          enemyFleetName: '新战斗敌舰队',
        ),
      ),
      mapName: '新战斗海域',
      nodeLabel: 'E',
    );
    await database.insertMapResourceRecord(
      MapResourceLogEntry(
        eventKey: 'detail-row-resource',
        timestamp: DateTime.utc(2026, 9, 5, 3),
        mapArea: 2,
        mapNo: 2,
        mapName: '资源海域',
        node: 2,
      ),
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旧战斗海域 (1-1)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle-detail-page')), findsNothing);

    await tester.tap(find.text('资源海域 (2-2)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle-detail-page')), findsNothing);

    await tester.tap(find.text('新战斗海域 (6-2)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle-detail-page')), findsOneWidget);
    expect(find.text('战斗详情 · 6-2 E点'), findsOneWidget);

    await tester.tap(find.byKey(const Key('battle-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logbook-table-sortie')), findsOneWidget);
    expect(find.text('共 3 条'), findsOneWidget);
    expect(find.text('新战斗海域 (6-2)'), findsOneWidget);
  });

  testWidgets('sortie table shows resource and item drop columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1500, 620);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(mapAreaId: 2, mapInfoNo: 2, node: 5),
          rank: BattleRank.s,
          dropShipMasterId: 101,
          dropShipMasterIds: <int>[101, 102],
          rewardItems: <BattleRewardItem>[
            BattleRewardItem(
              kind: BattleRewardKind.item,
              id: 68,
              count: 1,
              name: '秋刀鱼',
            ),
          ],
        ),
        completedAt: DateTime.utc(2026, 8, 24, 12),
      ),
      mapName: '巴士岛近海',
      nodeLabel: 'E',
    );
    await database.insertMapResourceRecord(
      MapResourceLogEntry(
        eventKey: 'sequence:9901',
        timestamp: DateTime.utc(2026, 8, 24, 12, 1),
        mapArea: 2,
        mapNo: 2,
        mapName: '巴士岛近海',
        node: 6,
        nodeLabel: 'F',
        fuelDelta: 80,
        ammoDelta: -30,
      ),
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('资源掉落'), findsOneWidget);
    expect(find.text('道具掉落'), findsOneWidget);
    expect(find.byKey(const Key('logbook-resource-icon-1')), findsOneWidget);
    expect(find.byKey(const Key('logbook-resource-icon-2')), findsOneWidget);
    expect(find.text('+80'), findsOneWidget);
    expect(find.text('-30'), findsOneWidget);
    expect(find.text('秋刀鱼 ×1'), findsOneWidget);
    expect(find.text('ID: 101、ID: 102'), findsOneWidget);
    expect(find.text('资源获得'), findsNothing);
    expect(find.text('资源损失'), findsNothing);
  });

  testWidgets('empty categories keep the Poi table headers visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(740, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('logbook-table-expedition')), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('远征'), findsOneWidget);
    expect(find.text('结果'), findsOneWidget);
    expect(find.text('暂无记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full logbook header fits the five approved mobile demo sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const sizes = <Size>[
      Size(1280, 680),
      Size(1024, 600),
      Size(800, 1100),
      Size(844, 390),
      Size(740, 360),
    ];

    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: size.width - 178,
                height: 54,
                child: WorkspaceContextHeader(
                  workspaceIndex: 6,
                  state: GameState.empty,
                  selectedFleetId: 1,
                  logbookTabIndex: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'size: $size');
      final switcher = tester.getRect(
        find.byKey(const Key('logbook-segmented')),
      );
      expect(switcher.left, greaterThanOrEqualTo(0), reason: 'size: $size');
      expect(
        switcher.right,
        lessThanOrEqualTo(size.width),
        reason: 'size: $size',
      );
    }
  });

  testWidgets('expedition table matches owned equipment density and styling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(740, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertExpeditionResult(
      expeditionId: 38,
      name: '东京急行（弐）',
      result: 2,
      materials: const [0, 0, 300, 420],
      item1Id: 1,
      item1Name: '高速修复材',
      item1Count: 1,
      item2Id: 10,
      item2Name: '家具箱（小）',
      item2Count: 1,
      rewardItems: const <Map<String, Object?>>[
        {'id': 1, 'name': '高速修复材', 'count': 1},
        {'id': 10, 'name': '家具箱（小）', 'count': 1},
        {'id': 2, 'name': '高速建造材', 'count': 2},
      ],
      timestamp: DateTime.utc(2026, 8, 11, 13, 5).millisecondsSinceEpoch,
    );
    await database.insertExpeditionResult(
      expeditionId: 120,
      name: '错误的远征名',
      result: 1,
      materials: const [45, 0, 45, 0],
      item1Id: 3,
      item1Name: '错误的道具名',
      item1Count: 2,
      timestamp: DateTime.utc(2026, 8, 11, 13, 6).millisecondsSinceEpoch,
    );
    await database.insertExpeditionResult(
      expeditionId: 0,
      name: '南西方面航空偵察作戦',
      result: 2,
      materials: const [0, 0, 36, 54],
      timestamp: DateTime.utc(2026, 8, 11, 13, 7).millisecondsSinceEpoch,
    );
    const state = GameState(
      masterMissions: {
        120: MasterMission(
          id: 120,
          name: '练习航海及警戒任务',
          duration: Duration(minutes: 30),
          displayNumber: 'C1',
        ),
        110: MasterMission(
          id: 110,
          name: '南西方面航空偵察作戦',
          duration: Duration(minutes: 35),
          displayNumber: 'B1',
        ),
      },
    );
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('38 · 东京急行（弐）'), findsOneWidget);
    expect(find.text('C1 · 练习航海及警戒任务'), findsOneWidget);
    expect(find.text('B1 · 南西方面航空偵察作戦'), findsOneWidget);
    expect(find.text('大成功'), findsNWidgets(2));
    expect(find.textContaining('高速修复材'), findsNothing);
    expect(find.textContaining('家具箱（小）'), findsNothing);
    expect(find.textContaining('高速建造材'), findsNothing);
    expect(find.textContaining('开发资材'), findsNothing);
    expect(find.textContaining('X1'), findsWidgets);
    expect(find.textContaining('X2'), findsWidgets);
    expect(
      find.byKey(const Key('logbook-expedition-reward-icon-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('logbook-expedition-reward-icon-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('logbook-expedition-reward-icon-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('logbook-expedition-reward-icon-3')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('logbook-resource-icon-fuel')), findsOneWidget);

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('logbook-table-expedition')),
    );
    expect(table.frozenColumnWidths, const <double>[205]);
    expect(table.scrollableColumnWidths.first, lessThanOrEqualTo(96));
    expect(table.scrollableColumnWidths.sublist(2, 6), const <double>[
      70,
      70,
      70,
      70,
    ]);
    expect(table.rowHeights, everyElement(FrozenDataTable.minimumRowHeight));
    expect(table.scrollableColumnWidths.last, greaterThanOrEqualTo(120));

    final horizontal = find.byKey(
      const Key('logbook-expedition-horizontal-scroll'),
    );
    final horizontalScrollable = find.descendant(
      of: horizontal,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    expect(
      tester
          .state<ScrollableState>(horizontalScrollable)
          .position
          .maxScrollExtent,
      greaterThan(0),
    );

    final expeditionBefore = tester.getRect(find.text('B1 · 南西方面航空偵察作戦')).left;
    final timeBefore = tester.getRect(find.text('08-11 22:07')).left;
    await tester.drag(
      find.byKey(const Key('logbook-expedition-horizontal-scroll')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('B1 · 南西方面航空偵察作戦')).left, expeditionBefore);
    expect(tester.getRect(find.text('08-11 22:07')).left, lessThan(timeBefore));
    final filter = find.byKey(const Key('logbook-filter-button'));
    expect(tester.getSize(filter), const Size.square(34));
    final resultText = tester.widget<Text>(find.text('大成功').first);
    expect(resultText.style?.fontSize, 12);
    expect(resultText.style?.color, const Color(0xffffc857));
  });

  testWidgets('construction development and retirement use approved columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertConstructionRecord(
      timestamp: 1,
      constructionType: '普通建造',
      shipId: 1,
      shipName: '雪风',
      shipType: '驱逐舰',
      fuel: 30,
      ammo: 30,
      steel: 30,
      bauxite: 30,
      developmentMaterial: 1,
      secretaryName: '矢矧改二乙 Lv.132',
    );
    await database.insertDevelopmentRecord(
      timestamp: 2,
      success: false,
      equipmentId: null,
      equipmentName: '—',
      equipmentType: '—',
      equipmentIconId: -1,
      fuel: 10,
      ammo: 20,
      steel: 30,
      bauxite: 40,
      secretaryName: '矢矧改二乙 Lv.132',
    );
    await database.insertRetirementRecord(
      timestamp: 3,
      type: '改修',
      shipType: '驱逐舰',
      shipName: '深雪',
      level: 1,
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    Future<void> pumpTab(int index) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LogbookPage(
              battleController: controller,
              database: database,
              selectedTabIndex: index,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpTab(2);
    final constructionTable = tester.widget<FrozenDataTable>(
      find.byKey(const Key('logbook-table-construction')),
    );
    expect(constructionTable.frozenColumnWidths, hasLength(1));
    final constructionShipBefore = tester.getRect(find.text('舰娘')).left;
    final constructionTimeBefore = tester.getRect(find.text('时间')).left;
    await tester.drag(
      find.byKey(const Key('logbook-construction-horizontal-scroll')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('舰娘')).left, constructionShipBefore);
    expect(
      tester.getRect(find.text('时间')).left,
      lessThan(constructionTimeBefore),
    );
    expect(find.text('开发资材'), findsOneWidget);
    expect(find.text('空闲槽'), findsNothing);
    expect(find.text('司令部等级'), findsNothing);
    expect(
      find.byKey(const Key('logbook-resource-icon-developmentMaterial')),
      findsOneWidget,
    );

    await pumpTab(3);
    final developmentTable = tester.widget<FrozenDataTable>(
      find.byKey(const Key('logbook-table-development')),
    );
    expect(developmentTable.frozenColumnWidths, hasLength(1));
    final equipmentBefore = tester.getRect(find.text('开发装备')).left;
    final typeBefore = tester.getRect(find.text('装备类型')).left;
    final developmentTimeBefore = tester.getRect(find.text('时间')).left;
    await tester.drag(
      find.byKey(const Key('logbook-development-horizontal-scroll')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('开发装备')).left, equipmentBefore);
    expect(tester.getRect(find.text('装备类型')).left, lessThan(typeBefore));
    expect(
      tester.getRect(find.text('时间')).left,
      lessThan(developmentTimeBefore),
    );
    expect(find.text('失败'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('失败')).style?.color,
      const Color(0xffff6464),
    );
    expect(find.text('司令部等级'), findsNothing);

    await pumpTab(4);
    expect(find.text('改修'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('改修')).style?.color,
      const Color(0xff67bce9),
    );
    final retirementTable = tester.widget<FrozenDataTable>(
      find.byKey(const Key('logbook-table-retirement')),
    );
    expect(retirementTable.frozenColumnWidths, isEmpty);
    expect(retirementTable.scrollableColumnWidths, hasLength(4));
    expect(
      retirementTable.frozenColumnWidths.fold<double>(0, (a, b) => a + b) +
          retirementTable.scrollableColumnWidths.fold<double>(
            0,
            (a, b) => a + b,
          ),
      greaterThanOrEqualTo(1000),
    );
  });

  testWidgets('sortie uses named map and capsule rank styling', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(mapAreaId: 2, mapInfoNo: 3, node: 5),
          rank: BattleRank.s,
          friendMain: [
            BattleShipSnapshot(
              masterId: 1,
              name: '矢矧改二乙',
              side: BattleSide.friend,
              fleetRole: BattleFleetRole.main,
              position: 0,
              initialHp: 54,
              maxHp: 54,
              currentHp: 54,
            ),
          ],
          friendEscort: [
            BattleShipSnapshot(
              masterId: 2,
              name: '能代改二',
              side: BattleSide.friend,
              fleetRole: BattleFleetRole.escort,
              position: 0,
              initialHp: 53,
              maxHp: 53,
              currentHp: 53,
            ),
          ],
          mvpPositions: [0, 6],
        ),
        completedAt: DateTime(2026, 8, 11, 22, 15),
      ),
    );
    const mapState = GameState(
      masterMapInfos: <int, MasterMapInfo>{
        203: MasterMapInfo(id: 23, mapAreaId: 2, mapNo: 3, name: '东部奥廖尔海'),
      },
    );
    final controller = BattleController(gameState: () => mapState);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('东部奥廖尔海 (2-3)'), findsOneWidget);
    final rank = find.byKey(const Key('logbook-rank-S'));
    expect(rank, findsOneWidget);
    expect(tester.getSize(rank), const Size(32, 22));
    final decoration = tester.widget<DecoratedBox>(rank).decoration;
    expect(decoration, isA<BoxDecoration>());
    expect((decoration as BoxDecoration).color, const Color(0xff2c2015));
    for (final header in ['旗舰', '二队旗舰', 'MVP', '二队 MVP']) {
      expect(find.text(header), findsOneWidget);
    }
    expect(find.text('矢矧改二乙'), findsNWidgets(2));
    expect(find.text('能代改二'), findsNWidgets(2));
    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('logbook-table-sortie')),
    );
    expect(table.frozenColumnWidths, hasLength(1));
    expect(table.scrollableColumnWidths, hasLength(16));
    expect(
      table.frozenColumnWidths.reduce((a, b) => a + b) +
          table.scrollableColumnWidths.reduce((a, b) => a + b),
      greaterThanOrEqualTo(1836),
    );
  });

  testWidgets(
    'sortie shows formation air state and separated heavy damage ships',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 600);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      await database.insertBattleRecord(
        BattleRecord(
          battle: const LiveBattle(
            context: BattleContext(mapAreaId: 2, mapInfoNo: 3, node: 5),
            friendFormation: 1,
            enemyFormation: 5,
            airSuperiority: '优势',
            friendMain: [
              BattleShipSnapshot(
                masterId: 1,
                name: '矢矧改二乙',
                side: BattleSide.friend,
                fleetRole: BattleFleetRole.main,
                position: 0,
                initialHp: 54,
                maxHp: 54,
                currentHp: 10,
              ),
              BattleShipSnapshot(
                masterId: 2,
                name: '雪风改二',
                side: BattleSide.friend,
                fleetRole: BattleFleetRole.main,
                position: 1,
                initialHp: 35,
                maxHp: 35,
                currentHp: 8,
              ),
            ],
            friendEscort: [
              BattleShipSnapshot(
                masterId: 3,
                name: '时雨改三特别作战型',
                side: BattleSide.friend,
                fleetRole: BattleFleetRole.escort,
                position: 0,
                initialHp: 36,
                maxHp: 36,
                currentHp: 9,
              ),
              BattleShipSnapshot(
                masterId: 4,
                name: '最上改二特航空巡洋舰',
                side: BattleSide.friend,
                fleetRole: BattleFleetRole.escort,
                position: 1,
                initialHp: 60,
                maxHp: 60,
                currentHp: 15,
              ),
            ],
          ),
          completedAt: DateTime.utc(2026, 8, 30, 12),
        ),
        mapName: '东部奥廖尔海',
      );
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DefaultTextStyle.merge(
              style: const TextStyle(height: 3),
              child: LogbookPage(
                battleController: controller,
                database: database,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final header in ['我方阵形', '敌方阵形', '制空状态', '大破舰娘']) {
        expect(find.text(header), findsOneWidget);
      }
      final summaryHeaders = [
        for (final header in ['状态', '我方阵形', '敌方阵形', '制空状态', '大破舰娘', '评价'])
          tester.getTopLeft(find.text(header)).dx,
      ];
      for (var index = 1; index < summaryHeaders.length; index++) {
        expect(summaryHeaders[index], greaterThan(summaryHeaders[index - 1]));
      }
      expect(find.text('单纵阵'), findsOneWidget);
      expect(find.text('单横阵'), findsOneWidget);
      expect(find.text('优势'), findsOneWidget);
      expect(find.text('矢矧改二乙、雪风改二、时雨改三特别作战型、最上改二特航空巡洋舰'), findsOneWidget);

      final friendFormation = tester.widget<DecoratedBox>(
        find.byKey(const Key('logbook-friend-formation-pill')),
      );
      final friendDecoration = friendFormation.decoration as BoxDecoration;
      expect(friendDecoration.color, const Color(0xff183e38));
      expect(friendDecoration.border!.top.color, const Color(0xff2f7469));
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('logbook-friend-formation-pill')),
                matching: find.text('单纵阵'),
              ),
            )
            .style
            ?.color,
        const Color(0xff83d5c8),
      );

      final enemyFormation = tester.widget<DecoratedBox>(
        find.byKey(const Key('logbook-enemy-formation-pill')),
      );
      final enemyDecoration = enemyFormation.decoration as BoxDecoration;
      expect(enemyDecoration.color, const Color(0xff46211e));
      expect(enemyDecoration.border!.top.color, const Color(0xffa0453a));
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('logbook-enemy-formation-pill')),
                matching: find.text('单横阵'),
              ),
            )
            .style
            ?.color,
        const Color(0xffff8c78),
      );

      final airState = tester.widget<DecoratedBox>(
        find.byKey(const Key('logbook-air-superiority-pill')),
      );
      final airDecoration = airState.decoration as BoxDecoration;
      expect(airDecoration.color, const Color(0xff183e38));
      expect(airDecoration.border!.top.color, const Color(0xff2f7469));
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('logbook-air-superiority-pill')),
                matching: find.text('优势'),
              ),
            )
            .style
            ?.color,
        const Color(0xff83d5c8),
      );

      final table = tester.widget<FrozenDataTable>(
        find.byKey(const Key('logbook-table-sortie')),
      );
      expect(table.scrollableColumnWidths, hasLength(16));
      expect(table.scrollableColumnWidths.sublist(3, 7), const <double>[
        96,
        96,
        102,
        166,
      ]);
      expect(table.rowHeights.first, greaterThan(120));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sortie localizes persisted air states without changing their pill colors',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      const persistedStates = <String>['未知', '均衡', '确保', '优势', '劣势', '丧失'];
      for (var index = 0; index < persistedStates.length; index++) {
        await database.insertBattleRecord(
          BattleRecord(
            battle: LiveBattle(
              context: const BattleContext(mapAreaId: 2, mapInfoNo: 3, node: 5),
              airSuperiority: persistedStates[index],
            ),
            completedAt: DateTime.utc(2026, 8, 30, 12, index),
          ),
        );
      }
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LogbookPage(battleController: controller, database: database),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in <String>[
        '不明',
        '航空均衡',
        '制空権確保',
        '航空優勢',
        '航空劣勢',
        '制空権喪失',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final persisted in persistedStates) {
        expect(find.text(persisted), findsNothing);
      }

      BoxDecoration decorationFor(String label) =>
          tester
                  .widget<DecoratedBox>(
                    find.ancestor(
                      of: find.text(label),
                      matching: find.byKey(
                        const Key('logbook-air-superiority-pill'),
                      ),
                    ),
                  )
                  .decoration
              as BoxDecoration;

      expect(decorationFor('制空権確保').color, const Color(0xff183e38));
      expect(decorationFor('航空劣勢').color, const Color(0xff46211e));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sortie malformed heavy damage JSON falls back to dash', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    for (var index = 0; index < 2; index++) {
      await database.insertBattleRecord(
        BattleRecord(
          battle: const LiveBattle(
            context: BattleContext(mapAreaId: 2, mapInfoNo: 3, node: 5),
          ),
          completedAt: DateTime.utc(2026, 8, 30, 12, index),
        ),
      );
    }
    final rawDatabase = await database.database;
    final inserted = await database.getBattleRecords();
    await rawDatabase.update(
      'battle_logs',
      {'heavy_damage_ship_names_json': '{not-json'},
      where: 'id = ?',
      whereArgs: [inserted[0]['id']],
    );
    await rawDatabase.update(
      'battle_logs',
      {'heavy_damage_ship_names_json': '["矢矧改二乙", 7]'},
      where: 'id = ?',
      whereArgs: [inserted[1]['id']],
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('logbook-table-sortie')),
    );
    expect(table.rowHeights, everyElement(FrozenDataTable.minimumRowHeight));
    for (var index = 0; index < 2; index++) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: table.scrollableCells(index)[6],
        ),
      );
      expect(find.text('-'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('logbook keeps only the filter icon button', (tester) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filter = find.byKey(const Key('logbook-filter-button'));
    expect(find.byKey(const Key('logbook-search-button')), findsNothing);
    expect(find.byKey(const Key('logbook-search-field')), findsNothing);
    expect(filter, findsOneWidget);
    expect(tester.getSize(filter), const Size.square(34));
    expect(
      find.descendant(
        of: filter,
        matching: find.byIcon(Icons.filter_alt_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sortie shows Poi map difficulty and route or boss node labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final rawDatabase = await database.database;
    for (final entry in const <(int, int)>[(3, 4), (4, 5)]) {
      await database.insertBattleRecord(
        BattleRecord(
          battle: LiveBattle(
            context: BattleContext(
              mapAreaId: 62,
              mapInfoNo: 2,
              node: entry.$1,
              eventId: entry.$2,
            ),
            rank: BattleRank.s,
          ),
          completedAt: DateTime(2026, 8, 11, 22, entry.$1),
        ),
      );
    }
    await rawDatabase.update('battle_logs', const <String, Object?>{
      'map_difficulty': 3,
    });
    const mapState = GameState(
      masterMapInfos: <int, MasterMapInfo>{
        6202: MasterMapInfo(
          id: 622,
          mapAreaId: 62,
          mapNo: 2,
          name: '南沙諸島沖/オルモック沖/サンベルナルジノ海峡沖',
        ),
      },
    );
    final controller = BattleController(gameState: () => mapState);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('南沙諸島沖/オルモッ… (62-2 乙)'), findsNWidgets(2));
    expect(find.text('C·道中'), findsOneWidget);
    expect(find.text('D·Boss'), findsOneWidget);
  });

  testWidgets('filter button opens the approved two-column filter panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('logbook-filter-panel')), findsOneWidget);
    expect(find.text('筛选出击记录'), findsOneWidget);
    for (final field in ['date', 'map', 'status', 'rank']) {
      expect(find.byKey(Key('logbook-filter-field-$field')), findsOneWidget);
    }
    expect(find.byKey(const Key('logbook-filter-reset')), findsOneWidget);
    expect(find.byKey(const Key('logbook-filter-apply')), findsOneWidget);
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sortie filter discovers and loads a map outside the first page',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      final raw = await database.database;
      final batch = raw.batch();

      void insertBattle({
        required int timestamp,
        required int mapArea,
        required int mapNo,
        required String mapName,
      }) {
        batch.insert('battle_logs', <String, Object?>{
          'timestamp': timestamp,
          'map_area': mapArea,
          'map_no': mapNo,
          'map_name': mapName,
          'node': 1,
          'node_type': '普通战斗',
          'rank': 's',
          'enemy_fleet_name': '-',
          'friend_fleet_state': '-',
          'enemy_fleet_state': '-',
        });
      }

      for (var index = 0; index < 55; index++) {
        insertBattle(
          timestamp: 1 + index,
          mapArea: 9,
          mapNo: 9,
          mapName: '历史海域',
        );
      }
      for (var index = 0; index < 50; index++) {
        insertBattle(
          timestamp: 100 + index,
          mapArea: 2,
          mapNo: 2,
          mapName: '巴士岛近海',
        );
      }
      await batch.commit(noResult: true);
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LogbookPage(battleController: controller, database: database),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logbook-filter-button')));
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const Key('logbook-filter-field-map')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(dropdown.items!.map((item) => item.value), contains('历史海域 (9-9)'));

      await tester.tap(find.byKey(const Key('logbook-filter-field-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('(9-9) 历史海域').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logbook-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.text('历史海域 (9-9)'), findsWidgets);
      expect(find.text('巴士岛近海 (2-2)'), findsNothing);
      expect(
        tester
            .widget<FrozenDataTable>(
              find.byKey(const Key('logbook-table-sortie')),
            )
            .rowHeights,
        hasLength(50),
      );

      await tester.drag(
        find.byKey(const Key('logbook-sortie-body-scroll')),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FrozenDataTable>(
              find.byKey(const Key('logbook-table-sortie')),
            )
            .rowHeights,
        hasLength(55),
      );

      await tester.tap(find.byKey(const Key('logbook-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logbook-filter-reset')));
      await tester.tap(find.byKey(const Key('logbook-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.text('巴士岛近海 (2-2)'), findsWidgets);
      expect(find.text('历史海域 (9-9)'), findsNothing);
    },
  );

  testWidgets('sortie filter catalog refreshes after a new map record', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await database.insertMapResourceRecord(
      MapResourceLogEntry(
        eventKey: 'new-filter-map',
        timestamp: DateTime(2026, 9, 2, 12),
        mapArea: 7,
        mapNo: 1,
        mapName: '新海域',
        node: 1,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('logbook-filter-field-map')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(dropdown.items!.map((item) => item.value), contains('新海域 (7-1)'));
  });

  testWidgets('clearing logs removes stale sortie rows', (tester) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertMapResourceRecord(
      MapResourceLogEntry(
        eventKey: 'row-to-clear',
        timestamp: DateTime(2026, 9, 2, 13),
        mapArea: 7,
        mapNo: 2,
        mapName: '待清空海域',
        node: 1,
      ),
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('待清空海域 (7-2)'), findsOneWidget);

    await database.clearAll();
    await tester.pumpAndSettle();

    expect(find.text('待清空海域 (7-2)'), findsNothing);
    expect(find.text('暂无记录'), findsOneWidget);
  });

  testWidgets('sortie filter options match recorded statuses and all ranks', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    for (final context in const <BattleContext>[
      BattleContext(mapAreaId: 2, mapInfoNo: 3, node: 3, eventId: 2),
      BattleContext(
        mapAreaId: 2,
        mapInfoNo: 3,
        node: 4,
        eventId: 6,
        eventKind: 2,
      ),
    ]) {
      await database.insertBattleRecord(
        BattleRecord(
          battle: LiveBattle(context: context, rank: BattleRank.ss),
          completedAt: DateTime(2026, 8, 11, 22, context.node),
        ),
      );
    }
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();

    List<String?> optionsFor(String field) {
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(Key('logbook-filter-field-$field')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      return dropdown.items!.map((item) => item.value).toList();
    }

    expect(
      optionsFor('status'),
      unorderedEquals(<String>['全部状态', '资源获得', '路线选择']),
    );
    expect(optionsFor('rank'), <String>[
      '全部评价',
      'SS',
      'S',
      'A',
      'B',
      'C',
      'D',
      'E',
    ]);
  });

  testWidgets('legacy numeric sortie status is never exposed as advance', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final db = await database.database;
    await db.insert('battle_logs', <String, Object?>{
      'timestamp': DateTime(2026, 8, 13, 12).millisecondsSinceEpoch,
      'map_area': 1,
      'map_no': 1,
      'node': 1,
      'node_type': 1,
      'rank': 's',
      'drop_ship_id': null,
      'enemy_fleet_name': '—',
      'friend_fleet_state': '6/6',
      'enemy_fleet_state': '0/6',
    });
    await db.insert('battle_logs', <String, Object?>{
      'timestamp': DateTime(2026, 8, 13, 13).millisecondsSinceEpoch,
      'map_area': 1,
      'map_no': 1,
      'node': 2,
      'node_type': ' 路线选择 ',
      'rank': 's',
      'drop_ship_id': null,
      'enemy_fleet_name': '—',
      'friend_fleet_state': '6/6',
      'enemy_fleet_state': '0/6',
    });
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('logbook-filter-field-status')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    final options = dropdown.items!.map((item) => item.value).toList();
    expect(options, contains('旧版记录'));
    expect(options, isNot(contains('进击')));

    await tester.tap(find.byKey(const Key('logbook-filter-field-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旧版记录').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logbook-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text('旧版记录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logbook-filter-field-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('路线选择').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logbook-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text('路线选择'), findsOneWidget);
    expect(find.text('旧版记录'), findsNothing);
  });

  testWidgets('retirement filter omits the ship-name field', (tester) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 4,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();

    for (final field in ['date', 'type', 'shipType']) {
      expect(find.byKey(Key('logbook-filter-field-$field')), findsOneWidget);
    }
    expect(find.byKey(const Key('logbook-filter-field-ship')), findsNothing);
  });

  testWidgets('sortie keeps historical map and resolved node labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    await database.insertBattleRecord(
      BattleRecord(
        battle: const LiveBattle(
          context: BattleContext(
            mapAreaId: 62,
            mapInfoNo: 2,
            node: 55,
            eventId: 4,
            nodeDisplayLabel: 'Y',
          ),
          rank: BattleRank.s,
        ),
        completedAt: DateTime(2026, 8, 11, 22, 5),
      ),
      mapDifficulty: 3,
      mapName: '南沙諸島沖/オルモック沖/サンベルナルジノ海峡沖',
      nodeLabel: 'Y',
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(battleController: controller, database: database),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('南沙諸島沖/オルモッ… (62-2 乙)'), findsOneWidget);
    expect(find.text('Y·道中'), findsOneWidget);
    expect(find.text('BC·道中'), findsNothing);
  });

  testWidgets(
    'practice sortie displays 演习, node -, enemy - and filters by 演习',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);

      // Insert practice battle record
      await database.insertBattleRecord(
        BattleRecord(
          battle: const LiveBattle(
            context: BattleContext(practice: true),
            rank: BattleRank.s,
            friendMain: [
              BattleShipSnapshot(
                masterId: 1,
                name: '矢矧改二乙',
                side: BattleSide.friend,
                fleetRole: BattleFleetRole.main,
                position: 0,
                initialHp: 54,
                maxHp: 54,
                currentHp: 54,
              ),
            ],
            enemyFleetName: '演习对手',
          ),
          completedAt: DateTime(2026, 8, 19, 22, 15),
        ),
      );

      // Insert regular sortie record
      await database.insertBattleRecord(
        BattleRecord(
          battle: const LiveBattle(
            context: BattleContext(
              mapAreaId: 1,
              mapInfoNo: 1,
              node: 1,
              eventId: 4,
              eventKind: 1,
            ),
            rank: BattleRank.s,
            friendMain: [
              BattleShipSnapshot(
                masterId: 1,
                name: '矢矧改二乙',
                side: BattleSide.friend,
                fleetRole: BattleFleetRole.main,
                position: 0,
                initialHp: 54,
                maxHp: 54,
                currentHp: 54,
              ),
            ],
            enemyFleetName: '敌侦察舰队',
          ),
          completedAt: DateTime(2026, 8, 19, 22, 10),
        ),
        mapName: '近海警备',
      );

      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LogbookPage(battleController: controller, database: database),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify practice row display
      expect(find.text('演习'), findsOneWidget);
      expect(find.text('-'), findsWidgets);
      expect(find.text('普通战斗'), findsNWidgets(2));
      expect(find.text('近海警备 (1-1)'), findsOneWidget);

      // Open filter panel
      await tester.tap(find.byKey(const Key('logbook-filter-button')));
      await tester.pumpAndSettle();

      // Select 演习 in map filter
      await tester.tap(find.byKey(const Key('logbook-filter-field-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('演习').last);
      await tester.pumpAndSettle();

      // Apply filter
      await tester.tap(find.byKey(const Key('logbook-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.text('演习'), findsOneWidget);
      expect(find.text('近海警备 (1-1)'), findsNothing);
    },
  );

  testWidgets('construction filter panel uses construction-specific fields', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('筛选建造记录'), findsOneWidget);
    for (final field in ['date', 'constructionType', 'shipType', 'secretary']) {
      expect(find.byKey(Key('logbook-filter-field-$field')), findsOneWidget);
    }
    expect(find.byKey(const Key('logbook-filter-field-status')), findsNothing);
  });

  testWidgets('filter choices stay pending until the user applies them', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in [('普通建造', '雪风'), ('大型建造', '大和')]) {
      await database.insertConstructionRecord(
        timestamp: now,
        constructionType: entry.$1,
        shipId: 1,
        shipName: entry.$2,
        shipType: '驱逐舰',
        fuel: 30,
        ammo: 30,
        steel: 30,
        bauxite: 30,
        developmentMaterial: 1,
        secretaryName: '矢矧改二乙',
      );
    }
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logbook-filter-button')));
    await tester.pumpAndSettle();
    final typeField = find.byKey(
      const Key('logbook-filter-field-constructionType'),
    );
    await tester.tap(
      find.descendant(
        of: typeField,
        matching: find.byType(DropdownButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('大型建造').last);
    await tester.pumpAndSettle();

    expect(find.text('雪风'), findsOneWidget);
    expect(find.text('大和'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logbook-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text('雪风'), findsNothing);
    expect(find.text('大和'), findsOneWidget);
  });

  testWidgets(
    'construction table refreshes immediately after database insert',
    (tester) async {
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LogbookPage(
              battleController: controller,
              database: database,
              selectedTabIndex: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('雪风'), findsNothing);

      await database.insertConstructionRecord(
        timestamp: 1,
        constructionType: '普通建造',
        shipId: 1,
        shipName: '雪风',
        shipType: '驱逐舰',
        fuel: 30,
        ammo: 30,
        steel: 30,
        bauxite: 30,
        developmentMaterial: 1,
        secretaryName: '矢矧改二乙',
      );
      await tester.pumpAndSettle();

      expect(find.text('雪风'), findsOneWidget);
    },
  );

  testWidgets('construction result replaces the visible pending row', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final constructionRecordId = await database.insertConstructionRecord(
      dockId: 2,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      constructionType: '普通建造',
      shipId: null,
      shipName: '建造中',
      shipType: '—',
      fuel: 30,
      ammo: 30,
      steel: 30,
      bauxite: 30,
      developmentMaterial: 1,
      secretaryName: '矢矧改二乙',
    );
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('建造中'), findsOneWidget);

    await database.updateConstructionResult(
      recordId: constructionRecordId,
      dockId: 2,
      shipId: 1,
      shipName: '雪风',
      shipType: '驱逐舰',
    );
    await tester.pumpAndSettle();

    expect(find.text('建造中'), findsNothing);
    expect(find.text('雪风'), findsOneWidget);
  });

  testWidgets('resource category keeps the existing resource trend page', (
    tester,
  ) async {
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 5,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ResourceTrendPage), findsOneWidget);
    expect(find.byKey(const Key('logbook-filter-button')), findsNothing);
  });

  testWidgets('loads the next database batch near the table bottom', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = await LogbookDatabase.openForTesting();
    addTearDown(database.close);
    for (var index = 0; index < 55; index++) {
      await database.insertDevelopmentRecord(
        timestamp: index,
        success: true,
        equipmentId: index,
        equipmentName: '装备$index',
        equipmentType: '主炮',
        equipmentIconId: 1,
        fuel: 10,
        ammo: 10,
        steel: 10,
        bauxite: 10,
        secretaryName: '矢矧改二乙',
      );
    }
    final controller = BattleController(gameState: () => GameState.empty);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LogbookPage(
            battleController: controller,
            database: database,
            selectedTabIndex: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FrozenDataTable>(
            find.byKey(const Key('logbook-table-development')),
          )
          .rowHeights,
      hasLength(50),
    );

    await tester.drag(
      find.byKey(const Key('logbook-development-body-scroll')),
      const Offset(0, -5000),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FrozenDataTable>(
            find.byKey(const Key('logbook-table-development')),
          )
          .rowHeights,
      hasLength(55),
    );
  });

  testWidgets(
    'all logbook tabs keep symmetric 12dp margins next to side menu under wide cutout insets',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(915, 412);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final database = await LogbookDatabase.openForTesting();
      addTearDown(database.close);
      final controller = BattleController(gameState: () => GameState.empty);
      addTearDown(controller.dispose);

      const categories = [
        (0, 'logbook-table-sortie'),
        (1, 'logbook-table-expedition'),
        (2, 'logbook-table-construction'),
        (3, 'logbook-table-development'),
        (4, 'logbook-table-retirement'),
      ];

      for (final scale in [1.0, minimalUiScale]) {
        for (final menuWidth in [41.0, 48.0]) {
          for (final (tabIndex, tableKey) in categories) {
            await tester.pumpWidget(
              MaterialApp(
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(915, 412),
                      padding: EdgeInsets.fromLTRB(63, 0, 28, 16),
                      viewPadding: EdgeInsets.fromLTRB(63, 0, 28, 16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(left: menuWidth),
                      child: UiScale(
                        scale: scale,
                        child: LogbookPage(
                          battleController: controller,
                          database: database,
                          selectedTabIndex: tabIndex,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final table = tester.getRect(find.byKey(Key(tableKey)));
            expect(table.left, closeTo(menuWidth + 12 * scale, .001));
            expect(table.right, closeTo(915 - 12 * scale, .001));
            expect(table.bottom, closeTo(412 - 10 * scale, .001));
          }
        }
      }
    },
  );
}
