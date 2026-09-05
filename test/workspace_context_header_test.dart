import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/improvement/improvement_planner_controller.dart'
    show ConstructionCenterMode;
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';

Widget _localizedApp({required Widget home, Locale? locale}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  const state = GameState(
    resources: <GameResourceType, int>{GameResourceType.fuel: 123456},
    fleets: <Fleet>[
      Fleet(id: 1, name: '第1艦隊', shipIds: <int>[1]),
      Fleet(id: 2, name: '2'),
      Fleet(id: 3, name: 'A2'),
      Fleet(id: 4, name: '6'),
    ],
    ships: <int, OwnedShip>{
      1: OwnedShip(id: 1, masterId: 187, level: 80, currentHp: 45, maxHp: 45),
    },
    masterShips: <int, MasterShip>{
      187: MasterShip(id: 187, name: '明石改', shipTypeId: 19),
    },
  );

  testWidgets('game workspace alone shows resources', (tester) async {
    var anchorageTapCount = 0;
    final senkaState = SenkaState.forMonth('2026-08').copyWith(
      rankingHistory: {
        'player': [
          SenkaRankingSnapshot(
            rank: 370,
            senka: 1120,
            capturedAt: DateTime.utc(2026, 8, 11),
            localSenkaAtCapture: 0,
          ),
        ],
      },
    );
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 0,
            state: state,
            senkaState: senkaState,
            anchorageRepairStartedAt: DateTime.utc(2026, 8, 11, 1),
            onAnchorageTimerTap: () => anchorageTapCount++,
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('header-resource-material-1')), findsOneWidget);
    expect(find.text('战果：1120（#370）'), findsOneWidget);
    expect(find.textContaining('泊地：'), findsOneWidget);
    expect(find.text('泊地：--:--:--'), findsNothing);
    expect(find.byKey(const Key('workspace-title-fleet')), findsNothing);

    await tester.tap(find.byKey(const Key('header-resource-anchorage-timer')));
    await tester.pump();
    expect(anchorageTapCount, 1);
  });

  testWidgets(
    'game workspace shows separate ship and equipment capacity pills',
    (tester) async {
      const capacityState = GameState(
        maxShipCount: 310,
        maxEquipmentCount: 1499,
        hasPortData: true,
        ships: <int, OwnedShip>{
          1: OwnedShip(id: 1, masterId: 101, level: 1),
          2: OwnedShip(id: 2, masterId: 102, level: 1),
        },
        masterSlotItems: <int, MasterSlotItem>{
          201: MasterSlotItem(id: 201, name: '主炮', type: <int>[1, 1, 1]),
          202: MasterSlotItem(id: 202, name: '副炮', type: <int>[1, 1, 4]),
          203: MasterSlotItem(id: 203, name: '鱼雷', type: <int>[1, 1, 5]),
          42: MasterSlotItem(id: 42, name: '损管', type: <int>[1, 1, 23]),
          145: MasterSlotItem(id: 145, name: '战斗粮食', type: <int>[1, 1, 43]),
          146: MasterSlotItem(id: 146, name: '洋上补给', type: <int>[1, 1, 44]),
        },
        slotItems: <int, OwnedSlotItem>{
          1: OwnedSlotItem(id: 1, masterId: 201),
          2: OwnedSlotItem(id: 2, masterId: 202),
          3: OwnedSlotItem(id: 3, masterId: 203),
          4: OwnedSlotItem(id: 4, masterId: 42),
          5: OwnedSlotItem(id: 5, masterId: 145),
          6: OwnedSlotItem(id: 6, masterId: 146),
        },
      );

      await tester.pumpWidget(
        _localizedApp(
          locale: const Locale('zh'),
          home: const Scaffold(
            body: WorkspaceContextHeader(
              workspaceIndex: 0,
              state: capacityState,
              selectedFleetId: 1,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('header-ship-capacity')), findsOneWidget);
      expect(
        find.byKey(const Key('header-equipment-capacity')),
        findsOneWidget,
      );
      expect(find.text('舰娘: 2 / 310'), findsOneWidget);
      expect(find.text('装备: 3 / 1499'), findsOneWidget);
    },
  );

  testWidgets('fleet workspace replaces resources with fleet switches', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 1,
            state: state,
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('resource-item-1')), findsNothing);
    expect(find.byKey(const Key('workspace-title-fleet')), findsOneWidget);
    for (var id = 1; id <= 4; id++) {
      expect(find.byKey(Key('fleet-button-$id')), findsOneWidget);
    }
  });

  testWidgets('fleet workspace marks the active sortie fleet', (tester) async {
    const sortieState = GameState(
      fleets: <Fleet>[
        Fleet(id: 1, name: '第一舰队', shipIds: <int>[9001]),
        Fleet(id: 2, name: '第二舰队', shipIds: <int>[9002]),
      ],
      combatState: CombatState(sortieFleetId: 1, isActive: true),
    );
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 1,
            state: sortieState,
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.text('出击中'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('fleet-status-cell-2')),
        matching: find.text('母港待命'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('other workspaces replace resources with their page title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 4,
            state: state,
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('resource-item-1')), findsNothing);
    expect(
      find.byKey(const Key('workspace-title-construction')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('workspace-title-construction')))
          .data,
      '建造',
    );
    expect(find.text('建造'), findsWidgets);
    expect(find.text('开发'), findsOneWidget);
    expect(find.text('改修'), findsOneWidget);
  });

  testWidgets(
    'construction workspace only shows development calculator and formula tabs when in development mode',
    (tester) async {
      var constructionMode = ConstructionCenterMode.construction;
      var developmentMode = DevelopmentWorkbenchMode.calculator;

      await tester.pumpWidget(
        _localizedApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: WorkspaceContextHeader(
                workspaceIndex: 4,
                state: state,
                selectedFleetId: 1,
                constructionMode: constructionMode,
                onConstructionModeChanged: (mode) {
                  setState(() => constructionMode = mode);
                },
                developmentMode: developmentMode,
                onDevelopmentModeChanged: (mode) {
                  setState(() => developmentMode = mode);
                },
              ),
            ),
          ),
        ),
      );

      // In construction mode, development sub-tabs should not appear
      expect(
        find.byKey(const Key('development-workbench-mode-tabs')),
        findsNothing,
      );

      // Tap development mode
      await tester.tap(find.byKey(const Key('construction-mode-development')));
      await tester.pump();

      expect(constructionMode, ConstructionCenterMode.development);
      expect(
        find.byKey(const Key('development-workbench-mode-tabs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('development-mode-calculator')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('development-mode-formula')), findsOneWidget);

      // Ensure no icons are inside the development sub-tabs
      expect(
        find.descendant(
          of: find.byKey(const Key('development-workbench-mode-tabs')),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );

      // Switch to formula
      await tester.tap(find.byKey(const Key('development-mode-formula')));
      await tester.pump();
      expect(developmentMode, DevelopmentWorkbenchMode.formula);

      // Tapping development tab resets/defaults to calculator
      await tester.tap(find.byKey(const Key('construction-mode-development')));
      await tester.pump();
      expect(developmentMode, DevelopmentWorkbenchMode.calculator);
    },
  );

  testWidgets('senka workspace shows the formal page title and tabs', (
    tester,
  ) async {
    SenkaCenterMode? changedMode;
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 9,
            state: state,
            selectedFleetId: 1,
            senkaMode: SenkaCenterMode.info,
            onSenkaModeChanged: (mode) => changedMode = mode,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('workspace-title-senka')), findsOneWidget);
    expect(find.text('战果'), findsOneWidget);
    expect(find.byKey(const Key('senka-mode-tabs')), findsOneWidget);
    expect(find.byKey(const Key('senka-tab-info')), findsOneWidget);
    expect(find.byKey(const Key('senka-tab-calendar')), findsOneWidget);
    expect(find.byKey(const Key('senka-tab-calculator')), findsOneWidget);

    final title = tester.getRect(
      find.byKey(const Key('workspace-title-senka')),
    );
    final switcher = tester.getRect(find.byKey(const Key('senka-mode-tabs')));
    expect(switcher.left, greaterThan(title.right));
    expect(switcher.height, 38);

    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    expect(changedMode, SenkaCenterMode.calendar);
  });

  testWidgets('quest workspace switches between active and all quests', (
    tester,
  ) async {
    const questState = GameState(
      quests: <int, GameQuest>{
        201: GameQuest(
          id: 201,
          title: 'Quest 1',
          detail: '',
          category: 2,
          type: 1,
          state: 2,
          progressFlag: 0,
        ),
        402: GameQuest(
          id: 402,
          title: 'Quest 2',
          detail: '',
          category: 4,
          type: 2,
          state: 3,
          progressFlag: 2,
        ),
      },
    );
    QuestCenterMode? changedMode;
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 5,
            state: questState,
            selectedFleetId: 1,
            questMode: QuestCenterMode.active,
            onQuestModeChanged: (mode) => changedMode = mode,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('workspace-title-quest')), findsOneWidget);
    expect(find.byKey(const Key('quest-mode-tabs')), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('全任务'), findsOneWidget);
    expect(find.textContaining('更新于'), findsNothing);
    await tester.tap(find.text('全任务'));
    expect(changedMode, QuestCenterMode.all);
  });

  testWidgets('all quest workspace adds search and filter actions', (
    tester,
  ) async {
    final filters = QuestFilterController();
    addTearDown(filters.dispose);
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 5,
            state: const GameState(),
            selectedFleetId: 1,
            questMode: QuestCenterMode.all,
            questFilters: filters,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('quest-search-button')), findsOneWidget);
    expect(find.byKey(const Key('quest-filter-button')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('quest-mode-tabs'))),
      const Size(260, 38),
    );
  });

  testWidgets('quest workspace exposes translation before mode tabs', (
    tester,
  ) async {
    final filters = QuestFilterController();
    addTearDown(filters.dispose);
    bool? translationEnabled;
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 5,
            state: const GameState(),
            selectedFleetId: 1,
            questFilters: filters,
            questTranslationEnabled: false,
            onQuestTranslationChanged: (value) => translationEnabled = value,
          ),
        ),
      ),
    );

    final toggle = find.byKey(const Key('quest-translation-toggle'));
    final tabs = find.byKey(const Key('quest-mode-tabs'));
    expect(toggle, findsOneWidget);
    expect(tester.getRect(toggle).right, lessThan(tester.getRect(tabs).left));
    await tester.tap(toggle);
    expect(translationEnabled, isTrue);
  });

  testWidgets('owned inventory puts its section switch in the top right', (
    tester,
  ) async {
    bool? selectedShips;
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 7,
            state: const GameState(
              ships: <int, OwnedShip>{
                1: OwnedShip(id: 1, masterId: 1, level: 1),
              },
              slotItems: <int, OwnedSlotItem>{
                1: OwnedSlotItem(id: 1, masterId: 1),
                2: OwnedSlotItem(id: 2, masterId: 42),
              },
            ),
            selectedFleetId: 1,
            inventoryShowShips: true,
            onInventorySectionChanged: (value) => selectedShips = value,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('workspace-title-owned-inventory')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('owned-inventory-segmented')), findsOneWidget);
    expect(find.text('装备 1'), findsOneWidget);
    final title = tester.getRect(
      find.byKey(const Key('workspace-title-owned-inventory')),
    );
    final switcher = tester.getRect(
      find.byKey(const Key('owned-inventory-segmented')),
    );
    expect(switcher.left, greaterThan(title.right));

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    expect(selectedShips, isFalse);
  });

  testWidgets('logbook puts its six-section capsule in the top right', (
    tester,
  ) async {
    var selectedTab = 0;
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 6,
            state: state,
            selectedFleetId: 1,
            logbookTabIndex: selectedTab,
            onLogbookTabChanged: (value) => selectedTab = value,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('workspace-title-logbook')), findsOneWidget);
    expect(find.text('航海日志'), findsOneWidget);
    expect(find.text('Poi 航海日志'), findsNothing);
    expect(find.byKey(const Key('logbook-segmented')), findsOneWidget);
    for (final label in ['出击', '远征', '建造', '开发', '除籍', '资源']) {
      expect(find.text(label), findsOneWidget);
    }

    final title = tester.getRect(
      find.byKey(const Key('workspace-title-logbook')),
    );
    final switcher = tester.getRect(find.byKey(const Key('logbook-segmented')));
    expect(switcher.left, greaterThan(title.right));
    expect(switcher.height, 38);

    await tester.tap(find.byKey(const Key('logbook-tab-expedition')));
    expect(selectedTab, 1);
  });

  testWidgets('toolbox header no longer exposes development mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 10,
            state: const GameState(),
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('workspace-title-tools')), findsOneWidget);
    expect(find.text('工具箱'), findsOneWidget);
    expect(find.byKey(const Key('toolbox-mode-tabs')), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('装备开发'), findsNothing);
  });

  testWidgets('Japanese toolbox header fits a narrow workspace', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(300, 80);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('ja'),
        home: const Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 10,
            state: GameState(),
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('workspace-title-tools')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
