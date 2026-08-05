import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_check_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/dashboard_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('远征检查默认状态不绘制独有边框', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckCard(
          controller: controller,
          collapsed: false,
          onToggleCollapse: () {},
          onOpenDetails: () {},
        ),
      ),
    );

    expect(
      tester.widget<DashboardCard>(find.byType(DashboardCard)).borderColor,
      isNull,
    );
  });

  testWidgets('首页卡片具有折叠箭头、模式切换和独立详情页按钮', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    var collapsed = false;
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SizedBox(
              width: 420,
              child: ExpeditionCheckCard(
                controller: controller,
                collapsed: collapsed,
                onToggleCollapse: () => setState(() => collapsed = !collapsed),
                onOpenDetails: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('远征检查'), findsOneWidget);
    expect(find.text('简洁'), findsOneWidget);
    expect(find.text('详细'), findsOneWidget);
    expect(find.text('成功'), findsOneWidget);
    expect(find.text('大成功'), findsOneWidget);
    expect(find.text('详情页'), findsOneWidget);

    for (final label in <String>['简洁', '详细', '成功', '大成功', '详情页']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.fontSize, 10);
      expect(text.style?.fontWeight, FontWeight.w700);
    }
    for (final key in <String>[
      'expedition-mode-segments',
      'expedition-success-segments',
      'expedition-details-segment',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }

    await tester.tap(find.text('详情页'));
    expect(opened, isTrue);

    await tester.tap(find.byKey(const Key('expedition-check-collapse')));
    await tester.pumpAndSettle();
    expect(find.text('详情页'), findsNothing);
  });

  testWidgets('真实母港规模不会让远征卡片无限分配内存', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _largePortState();
    final controller = GameStateController(
      gameStateStore: _StaticGameStateStore(state),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: ExpeditionCheckCard(
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
              onOpenDetails: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('远征检查'), findsOneWidget);
    expect(find.textContaining('常规检查'), findsOneWidget);

    await tester.tap(find.text('详细'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('预计收入'), findsOneWidget);
    expect(find.text('远征条件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('远征检查卡片在标准手机宽度下切换大成功无溢出', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 412,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ExpeditionCheckCard(
                controller: controller,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenDetails: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fleetGroup = find.byKey(const Key('expedition-fleet-segments'));
    expect(fleetGroup, findsOneWidget);
    final fleetLabels = find.descendant(
      of: fleetGroup,
      matching: find.byType(Text),
    );
    expect(fleetLabels, findsWidgets);
    for (final text in tester.widgetList<Text>(fleetLabels)) {
      expect(text.style?.fontSize, 10);
      expect(text.style?.fontWeight, FontWeight.w700);
    }
    final missionTexts = tester.widgetList<Text>(
      find.byKey(const Key('expedition-mission-name')),
    );
    expect(missionTexts, isNotEmpty);
    expect(missionTexts.every((text) => text.style?.fontSize == 12), isTrue);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('expedition-status-text')))
          .style
          ?.fontSize,
      12,
    );
    await tester.tap(find.text('大成功'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('详细'));
    await tester.pumpAndSettle();
    expect(find.text('详情页'), findsOneWidget);
    final titleCenter = tester.getCenter(find.text('远征检查'));
    final detailsCenter = tester.getCenter(find.text('详情页'));
    expect((titleCenter.dy - detailsCenter.dy).abs(), lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('长舰队名在手机宽度下自动缩小为单行', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer.reduce(state, portEvent);
    state = reducer.reduce(state, slotItemEvent);
    final secondFleet = state.fleets.firstWhere((fleet) => fleet.id == 2);
    state = state.copyWith(
      fleets: <Fleet>[
        Fleet(id: 2, name: '第十一驱逐舰队', shipIds: secondFleet.shipIds),
        for (final fleet in state.fleets)
          if (fleet.id != 2) fleet,
      ],
    );
    final controller = GameStateController(
      gameStateStore: _StaticGameStateStore(state),
    );
    addTearDown(controller.dispose);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 412,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ExpeditionCheckCard(
                controller: controller,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenDetails: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nameText = tester.widget<Text>(find.text('第十一驱逐舰队'));
    expect(nameText.maxLines, 1);
    expect(nameText.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄卡片的远征名称与常规检查统一使用紧凑自适应字号', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ExpeditionCheckCard(
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
              onOpenDetails: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final missionTexts = tester.widgetList<Text>(
      find.byKey(const Key('expedition-mission-name')),
    );
    expect(missionTexts, isNotEmpty);
    expect(missionTexts.every((text) => text.style?.fontSize == 11), isTrue);
    expect(missionTexts.every((text) => text.maxLines == 1), isTrue);

    final status = tester.widget<Text>(
      find.byKey(const Key('expedition-status-text')),
    );
    expect(status.style?.fontSize, 11);
    expect(status.maxLines, 1);
    expect(tester.takeException(), isNull);
  });
}

class _StaticGameStateStore extends GameStateStore {
  _StaticGameStateStore(this.value);
  final GameState value;
  @override
  Future<GameState> load() async => value;
}

GameState _largePortState() {
  final masters = <int, MasterShip>{};
  final ships = <int, OwnedShip>{};
  final slots = <int, OwnedSlotItem>{};
  var slotId = 1;
  for (var index = 1; index <= 279; index++) {
    final masterId = 1000 + index;
    masters[masterId] = MasterShip(
      id: masterId,
      name: '舰船$index',
      shipTypeId: index == 1 ? 3 : 2,
      maxFuel: 20,
      maxAmmo: 20,
      slotCount: 8,
    );
    final shipSlots = <int>[];
    for (var slot = 0; slot < 8; slot++) {
      slots[slotId] = OwnedSlotItem(id: slotId, masterId: 1);
      shipSlots.add(slotId++);
    }
    ships[index] = OwnedShip(
      id: index,
      masterId: masterId,
      level: 80,
      currentFuel: 20,
      currentAmmo: 20,
      slotIds: shipSlots,
    );
  }
  return GameState(
    masterShips: masters,
    ships: ships,
    slotItems: slots,
    fleets: const <Fleet>[
      Fleet(id: 2, name: '第2舰队', shipIds: <int>[1, 2, 3, 4, 5, 6]),
    ],
    hasPortData: true,
    hasMasterData: true,
  );
}
