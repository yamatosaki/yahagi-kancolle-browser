import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_center_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';

void main() {
  const state = GameState(
    resources: <GameResourceType, int>{GameResourceType.fuel: 123456},
    fleets: <Fleet>[
      Fleet(id: 1, name: '第1艦隊'),
      Fleet(id: 2, name: '2'),
      Fleet(id: 3, name: 'A2'),
      Fleet(id: 4, name: '6'),
    ],
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
      MaterialApp(
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

  testWidgets('fleet workspace replaces resources with fleet switches', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
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
      const MaterialApp(
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
      const MaterialApp(
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
  });

  testWidgets('senka workspace shows the formal page title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 9,
            state: state,
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('workspace-title-senka')), findsOneWidget);
    expect(find.text('战果'), findsOneWidget);
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
      MaterialApp(
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
      MaterialApp(
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

  testWidgets('owned inventory puts its section switch in the top right', (
    tester,
  ) async {
    bool? selectedShips;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 7,
            state: const GameState(
              ships: <int, OwnedShip>{
                1: OwnedShip(id: 1, masterId: 1, level: 1),
              },
              slotItems: <int, OwnedSlotItem>{
                1: OwnedSlotItem(id: 1, masterId: 1),
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
      MaterialApp(
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
}
