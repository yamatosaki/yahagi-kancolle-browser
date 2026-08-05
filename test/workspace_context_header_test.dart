import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';

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
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 0,
            state: state,
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('resource-item-1')), findsOneWidget);
    expect(find.byKey(const Key('workspace-title-fleet')), findsNothing);
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
    expect(find.text('建造'), findsOneWidget);
  });

  testWidgets('quest workspace puts connected counts beside its title', (
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
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspaceContextHeader(
            workspaceIndex: 5,
            state: questState,
            selectedFleetId: 1,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('workspace-title-quest')), findsOneWidget);
    expect(find.byKey(const Key('quest-count-segmented')), findsOneWidget);
    expect(find.text('已接受 2'), findsOneWidget);
    expect(find.text('已完成 1'), findsOneWidget);
    expect(find.textContaining('更新于'), findsNothing);
  });
}
