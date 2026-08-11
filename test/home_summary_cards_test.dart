import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/construction_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/anchorage_repair_view.dart';
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
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  testWidgets('维修简报提供独立的入渠与泊地模式切换', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await _pumpAt(
      tester,
      412,
      RepairSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenRepair: (_) {},
      ),
    );

    expect(find.text('维修简报'), findsOneWidget);
    expect(find.byKey(const Key('repair-summary-mode-dock')), findsOneWidget);
    expect(
      find.byKey(const Key('repair-summary-mode-anchorage')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('repair-summary-dock-grid')), findsOneWidget);
  });

  testWidgets('入渠胶囊维持2x2并跳转到入渠页面', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;
    RepairDestination? destination;

    await _pumpAt(
      tester,
      412,
      RepairSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenRepair: (value) => destination = value,
      ),
    );

    expect(find.byKey(const Key('repair-summary-dock-slot-1')), findsOneWidget);
    expect(find.byKey(const Key('repair-summary-dock-slot-4')), findsOneWidget);
    await tester.tap(find.byKey(const Key('repair-summary-dock-slot-1')));
    expect(destination?.mode, RepairCenterMode.dock);
    expect(destination?.fleetId, isNull);
  });

  testWidgets('泊地模式显示舰队行和固定2x3六个胶囊并传递所选舰队', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;
    RepairDestination? destination;

    await _pumpAt(
      tester,
      412,
      RepairSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenRepair: (value) => destination = value,
      ),
    );
    await tester.tap(find.byKey(const Key('repair-summary-mode-anchorage')));
    await tester.pump();

    expect(
      find.byKey(const Key('repair-summary-fleet-selector')),
      findsOneWidget,
    );
    expect(find.text('第一舰队'), findsOneWidget);
    expect(find.text('第四舰队'), findsOneWidget);
    expect(
      find.byKey(
        const Key('repair-summary-anchorage-slot'),
        skipOffstage: false,
      ),
      findsNWidgets(6),
    );

    final slots = tester
        .widgetList<Widget>(
          find.byKey(
            const Key('repair-summary-anchorage-slot'),
            skipOffstage: false,
          ),
        )
        .toList();
    expect(slots, hasLength(6));
    final rects = <Rect>[
      for (final element
          in find.byKey(const Key('repair-summary-anchorage-slot')).evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];
    expect(rects.map((rect) => rect.left.round()).toSet(), hasLength(2));
    expect(rects.map((rect) => rect.top.round()).toSet(), hasLength(3));

    await tester.tap(find.byKey(const Key('repair-summary-fleet-2')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('repair-summary-anchorage-slot')).last,
    );
    expect(destination?.mode, RepairCenterMode.anchorage);
    expect(destination?.fleetId, 2);
  });

  testWidgets('泊地简报实时响应游戏内换船且窄宽不溢出', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_get_member/deck', <Object?>[
          <String, Object?>{
            'api_id': 1,
            'api_name': '第一舰队完整名称',
            'api_ship': <int>[9001, -1, -1, -1, -1, -1],
            'api_mission': <int>[0, 0, 0, 0],
          },
          <String, Object?>{
            'api_id': 2,
            'api_name': '第二舰队完整名称',
            'api_ship': <int>[9002, -1, -1, -1, -1, -1],
            'api_mission': <int>[0, 0, 0, 0],
          },
        ]),
      );
    await controller.idle;

    await _pumpAt(
      tester,
      250,
      RepairSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenRepair: (_) {},
      ),
    );
    await tester.tap(find.byKey(const Key('repair-summary-mode-anchorage')));
    await tester.pump();
    expect(find.text('夕張'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_hensei/change',
        null,
        includeApiData: false,
        requestParams: const <String, Object?>{
          'api_id': '1',
          'api_ship_idx': '0',
          'api_ship_id': '9002',
        },
      ),
    );
    await controller.idle;
    await tester.pump();

    expect(find.text('吹雪'), findsOneWidget);
    expect(find.text('夕張'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('入渠舰娘名在窄宽胶囊中保持完整单行并自适应缩小', (tester) async {
    const longShipName = '超长舰娘名称测试改二甲';
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(id: 101, name: longShipName, shipTypeId: 2),
      },
      ships: const <int, OwnedShip>{
        9001: OwnedShip(id: 9001, masterId: 101, level: 50),
      },
      repairDocks: <RepairDock>[
        RepairDock(
          id: 1,
          state: 1,
          shipId: 9001,
          completionTime: DateTime.now().toUtc().add(const Duration(hours: 2)),
        ),
      ],
      hasPortData: true,
      hasMasterData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;

    await _pumpAt(
      tester,
      250,
      RepairSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenRepair: (_) {},
      ),
    );

    final name = find.text(longShipName);
    expect(name, findsOneWidget);
    expect(
      find.ancestor(of: name, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    final nameText = tester.widget<Text>(name);
    expect(nameText.maxLines, 1);
    expect(nameText.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });

  testWidgets('入渠剩余时间在窄宽胶囊中保持单行并自适应缩小', (tester) async {
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(id: 101, name: '测试舰娘', shipTypeId: 2),
      },
      ships: const <int, OwnedShip>{
        9001: OwnedShip(id: 9001, masterId: 101, level: 50),
      },
      repairDocks: <RepairDock>[
        RepairDock(
          id: 1,
          state: 1,
          shipId: 9001,
          completionTime: DateTime.now().toUtc().add(
            const Duration(hours: 12, minutes: 34, seconds: 56),
          ),
        ),
      ],
      hasPortData: true,
      hasMasterData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;

    await _pumpAt(
      tester,
      250,
      RepairSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenRepair: (_) {},
      ),
    );

    final countdown = find.descendant(
      of: find.byKey(const Key('repair-summary-dock-slot-1')),
      matching: find.byType(OperationCountdownText),
    );
    expect(countdown, findsOneWidget);
    expect(
      find.ancestor(of: countdown, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.widget<OperationCountdownText>(countdown).maxLines, 1);
    final renderedCountdown = tester.widgetList<Text>(
      find.descendant(of: countdown, matching: find.byType(Text)),
    );
    expect(renderedCountdown, hasLength(1));
    expect(
      renderedCountdown.single.data,
      matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('泊地正在修理胶囊只显示剩余时间', (tester) async {
    final state = GameState(
      masterShips: const <int, MasterShip>{
        182: MasterShip(id: 182, name: '明石改', shipTypeId: 19),
      },
      ships: const <int, OwnedShip>{
        9001: OwnedShip(
          id: 9001,
          masterId: 182,
          level: 80,
          currentHp: 40,
          maxHp: 45,
          repairDurationMilliseconds: 7230000,
        ),
      },
      fleets: const <Fleet>[
        Fleet(id: 1, name: '第1舰队', shipIds: <int>[9001]),
      ],
      hasPortData: true,
      hasMasterData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;

    await _pumpAt(
      tester,
      250,
      RepairSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenRepair: (_) {},
      ),
    );
    await tester.tap(find.byKey(const Key('repair-summary-mode-anchorage')));
    await tester.pump();

    expect(find.text('02:00:00'), findsOneWidget);
    expect(find.textContaining('正在修理'), findsNothing);
    final timeText = tester.widget<Text>(find.text('02:00:00'));
    expect(timeText.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

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
          onOpenRepair: (_) {},
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
            onOpenRepair: (_) {},
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

  testWidgets('入渠修理到期后圆点会随倒计时由黄色更新为绿色', (tester) async {
    final completionTime = DateTime.now().toUtc().add(
      const Duration(milliseconds: 500),
    );
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(id: 101, name: '夕张', shipTypeId: 2),
      },
      ships: const <int, OwnedShip>{
        9001: OwnedShip(id: 9001, masterId: 101, level: 50),
      },
      repairDocks: <RepairDock>[
        RepairDock(
          id: 1,
          state: 1,
          shipId: 9001,
          completionTime: completionTime,
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
            onOpenRepair: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    Color dockDotColor() {
      final slot = find.byKey(const Key('repair-summary-dock-slot-1'));
      final dots = tester.widgetList<Container>(
        find.descendant(
          of: slot,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          ),
        ),
      );
      return (dots.single.decoration! as BoxDecoration).color!;
    }

    expect(dockDotColor(), const Color(0xffffc940));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('已完成'), findsOneWidget);
    expect(dockDotColor(), const Color(0xff4caf50));
  });

  testWidgets('维修简报计时器只在展开期间存活', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    final periodicTimers = <Timer>[];

    Future<void> pumpCard(bool collapsed) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepairSummaryCard(
            key: const Key('timer-lifecycle-repair-summary'),
            controller: controller,
            collapsed: collapsed,
            onToggleCollapse: () {},
            onOpenRepair: (_) {},
          ),
        ),
      ),
    );

    await runZoned(
      () async {
        await pumpCard(true);
        expect(periodicTimers.where((timer) => timer.isActive), isEmpty);

        await pumpCard(false);
        expect(periodicTimers.where((timer) => timer.isActive), hasLength(1));

        await pumpCard(true);
        expect(periodicTimers.where((timer) => timer.isActive), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (self, parent, zone, duration, callback) {
          final timer = parent.createPeriodicTimer(zone, duration, callback);
          periodicTimers.add(timer);
          return timer;
        },
      ),
    );
  });

  testWidgets('维修简报折叠跨过完成时间后展开会立即校准状态', (tester) async {
    final completionTime = DateTime.now().toUtc().add(
      const Duration(milliseconds: 500),
    );
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(id: 101, name: '夕张', shipTypeId: 2),
      },
      ships: const <int, OwnedShip>{
        9001: OwnedShip(id: 9001, masterId: 101, level: 50),
      },
      repairDocks: <RepairDock>[
        RepairDock(
          id: 1,
          state: 1,
          shipId: 9001,
          completionTime: completionTime,
        ),
      ],
      hasPortData: true,
      hasMasterData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;

    Future<void> pumpCard(bool collapsed) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepairSummaryCard(
            key: const Key('collapsed-completion-repair-summary'),
            controller: controller,
            collapsed: collapsed,
            onToggleCollapse: () {},
            onOpenRepair: (_) {},
          ),
        ),
      ),
    );

    await pumpCard(true);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await pumpCard(false);

    final dockDots = tester.widgetList<Container>(
      find.descendant(
        of: find.byKey(const Key('repair-summary-dock-slot-1')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        ),
      ),
    );
    expect(find.text('已完成'), findsOneWidget);
    expect(
      (dockDots.single.decoration! as BoxDecoration).color,
      const Color(0xff4caf50),
    );
  });

  testWidgets('简报单元点击触发对应跳转', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    RepairDestination? openedRepair;
    var openedConstruction = false;
    var openedExpedition = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepairSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenRepair: (destination) => openedRepair = destination,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('吹雪').first);
    expect(openedRepair?.mode, RepairCenterMode.dock);
    expect(openedRepair?.fleetId, isNull);

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
            onOpenExpeditionCheck: (_) {},
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

  testWidgets('任务简报区分未同步、空任务且不显示容量计数', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedQuestsSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('需进入任务界面同步信息'), findsOneWidget);

    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/questlist', <String, Object?>{
        'api_exec_count': 0,
        'api_list': const <Object?>[],
      }),
    );
    await controller.idle;
    await tester.pump();
    expect(find.text('当前无进行中任务'), findsOneWidget);
    expect(find.text('0/5'), findsNothing);
  });

  testWidgets('known quest completion appears immediately on home', (
    tester,
  ) async {
    final controller = GameStateController(
      questStore: _StaticQuestStore(<int, GameQuest>{
        503: const GameQuest(
          id: 503,
          title: 'repair quest',
          detail: '',
          category: 5,
          type: 1,
          state: 2,
          progressFlag: 2,
          progressCurrent: 4,
          progressRequired: 5,
        ),
      }),
    );
    addTearDown(controller.dispose);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedQuestsSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenQuest: (_) {},
          ),
        ),
      ),
    );

    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_nyukyo/start',
        const <String, Object?>{},
        includeApiData: false,
        requestParams: const <String, Object?>{
          'api_ndock_id': '1',
          'api_ship_id': '999',
          'api_highspeed': '0',
        },
      ),
    );
    await controller.idle;
    await tester.pump();

    expect(find.text('repair quest'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
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
