import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/construction_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/expedition_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_progress.dart';
import 'package:yahagi_kancolle_browser/src/fleet/repair_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_store.dart';
import 'package:yahagi_kancolle_browser/src/quest/pinned_quests_summary.dart';

import 'fixtures/kcsapi_fixtures.dart';

Future<void> _pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('建造与入渠简报在窄手机面板下不溢出', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    for (final width in <double>[412, 300, 250]) {
      await _pumpAt(
        tester,
        width,
        ConstructionSummaryCard(
          controller: controller,
          collapsed: false,
          onToggleCollapse: () {},
          onOpenConstruction: () {},
        ),
      );
      expect(tester.takeException(), isNull);

      await _pumpAt(
        tester,
        width,
        RepairSummaryCard(
          controller: controller,
          collapsed: false,
          onToggleCollapse: () {},
          onOpenRepair: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('建造简报圆点：完成绿色、建造中黄色', (tester) async {
    final now = DateTime.now().toUtc();
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(id: 101, name: '夕张', shipTypeId: 2),
      },
      constructionDocks: <ConstructionDock>[
        ConstructionDock(
          id: 1,
          state: 3,
          createdShipMasterId: 101,
          completionTime: now.subtract(const Duration(minutes: 1)),
        ),
        ConstructionDock(
          id: 2,
          state: 2,
          createdShipMasterId: 101,
          completionTime: now.add(const Duration(hours: 1)),
        ),
      ],
      hasPortData: true,
      hasMasterData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConstructionSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenConstruction: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final colors = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          ),
        )
        .map((dot) => (dot.decoration! as BoxDecoration).color)
        .toSet();
    expect(colors, contains(const Color(0xff4caf50)));
    expect(colors, contains(const Color(0xffffc940)));
  });

  testWidgets('入渠简报圆点：完成绿色、修理中黄色', (tester) async {
    final now = DateTime.now().toUtc();
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(id: 101, name: '夕张', shipTypeId: 2),
      },
      ships: <int, OwnedShip>{
        9001: OwnedShip(id: 9001, masterId: 101, level: 50),
      },
      repairDocks: <RepairDock>[
        RepairDock(
          id: 1,
          state: 1,
          shipId: 9001,
          completionTime: now.subtract(const Duration(minutes: 1)),
        ),
        RepairDock(
          id: 2,
          state: 1,
          shipId: 9001,
          completionTime: now.add(const Duration(hours: 1)),
        ),
      ],
      hasPortData: true,
      hasMasterData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepairSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenRepair: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final colors = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          ),
        )
        .map((dot) => (dot.decoration! as BoxDecoration).color)
        .toSet();
    expect(colors, contains(const Color(0xff4caf50)));
    expect(colors, contains(const Color(0xffffc940)));
  });

  testWidgets('简报单元点击触发对应跳转', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    var openedRepair = false;
    var openedConstruction = false;
    var openedExpedition = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepairSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenRepair: () => openedRepair = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('吹雪').first);
    expect(openedRepair, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConstructionSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenConstruction: () => openedConstruction = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('夕張').first);
    expect(openedConstruction, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpeditionSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenExpedition: () => openedExpedition = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expeditionItem = find
        .ancestor(
          of: find.byType(OperationCountdownText),
          matching: find.byType(InkWell),
        )
        .first;
    final expeditionTexts = tester.widgetList<Text>(
      find.descendant(of: expeditionItem, matching: find.byType(Text)),
    );
    expect(expeditionTexts, isNotEmpty);
    for (final text in expeditionTexts) {
      expect(text.style?.fontSize, 10);
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.fontFamily, isNot('monospace'));
    }
    await tester.tap(find.text('海上護衛任務'));
    expect(openedExpedition, isTrue);
  });

  testWidgets('任务简报点击任务触发对应任务跳转', (tester) async {
    final controller = GameStateController(
      questStore: _StaticQuestStore(<int, GameQuest>{
        101: const GameQuest(
          id: 101,
          title: '测试任务',
          detail: '详情',
          category: 1,
          type: 1,
          state: 2,
          progressFlag: 1,
        ),
      }),
    );
    addTearDown(controller.dispose);
    await controller.idle;

    int? openedQuestId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedQuestsSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenQuest: (id) => openedQuestId = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('测试任务'));
    expect(openedQuestId, 101);
  });
}

class _StaticStore extends GameStateStore {
  _StaticStore(this.value);
  final GameState value;
  @override
  Future<GameState> load() async => value;
}

class _StaticQuestStore extends QuestStore {
  _StaticQuestStore(this.value);
  final Map<int, GameQuest> value;
  @override
  Future<Map<int, GameQuest>> loadQuests() async => value;
  @override
  Future<void> saveQuests(Map<int, GameQuest> quests) async {}
  @override
  Future<void> clearQuests() async {}
}
