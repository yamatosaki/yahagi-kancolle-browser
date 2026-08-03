import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_records_page.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

BattleController createController() {
  final reducer = GameStateReducer();
  var state = reducer.reduce(GameState.empty, start2Event);
  state = reducer.reduce(state, portEvent);
  return BattleController(gameState: () => state);
}

class _TestBattleCard extends StatefulWidget {
  const _TestBattleCard({required this.controller});
  final BattleController controller;
  @override
  State<_TestBattleCard> createState() => _TestBattleCardState();
}

class _TestBattleCardState extends State<_TestBattleCard> {
  bool collapsed = false;
  @override
  Widget build(BuildContext context) {
    return LiveBattleCard(
      controller: widget.controller,
      collapsed: collapsed,
      onToggleCollapse: () => setState(() => collapsed = !collapsed),
    );
  }
}

void main() {
  testWidgets('live card stays visible and changes from idle to forecast', (
    tester,
  ) async {
    final controller = createController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBattleCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
          ),
        ),
      ),
    );
    expect(find.text('未卜先知'), findsOneWidget);
    expect(find.text('待机'), findsOneWidget);
    expect(find.text('等待出击数据'), findsOneWidget);

    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;
    await tester.pump();

    expect(find.text('未卜先知'), findsOneWidget);
    expect(find.text('预判'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.byKey(const Key('detailed-battle-panel')), findsOneWidget);
    expect(find.text('我方主力（单纵阵）'), findsOneWidget);
    expect(find.text('敌方主力（单纵阵）'), findsOneWidget);
    expect(find.text('18 / 30 (-12)'), findsOneWidget);
    expect(find.text('18 / 30 (-12)'), findsOneWidget);
    expect(find.byKey(const Key('battle-mvp-friend-0')), findsOneWidget);

    final friendTitle = tester.getTopLeft(find.text('我方主力（单纵阵）'));
    final enemyTitle = tester.getTopLeft(find.text('敌方主力（单纵阵）'));
    expect(friendTitle.dx, lessThan(enemyTitle.dx));
    expect((friendTitle.dy - enemyTitle.dy).abs(), lessThan(2));
  });

  testWidgets('full panel shows navigation before enemy data arrives', (
    tester,
  ) async {
    final controller = createController();
    addTearDown(controller.dispose);
    controller.accept(mapStartEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBattleCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
          ),
        ),
      ),
    );

    expect(find.text('航向'), findsWidgets);
    expect(find.text('A点'), findsOneWidget);
    expect(find.text('普通战斗'), findsOneWidget);
    expect(find.text('我方舰队'), findsOneWidget);
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('敌方主力'), findsNothing);
  });

  testWidgets('combined navigation names and shows both friendly fleets', (
    tester,
  ) async {
    final reducer = GameStateReducer();
    var state = reducer.reduce(GameState.empty, start2Event);
    state = reducer
        .reduce(state, portEvent)
        .copyWith(combinedFleetType: CombinedFleetType.carrierTaskForce);
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);
    controller.accept(mapStartEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBattleCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
          ),
        ),
      ),
    );

    expect(find.text('空母机动部队'), findsOneWidget);
    expect(find.text('我方主力'), findsOneWidget);
    expect(find.text('我方随伴'), findsOneWidget);
    final mainTitle = tester.getTopLeft(find.text('我方主力'));
    final escortTitle = tester.getTopLeft(find.text('我方随伴'));
    expect(mainTitle.dx, lessThan(escortTitle.dx));
    expect((mainTitle.dy - escortTitle.dy).abs(), lessThan(2));
  });

  testWidgets(
    'side-by-side fleets remain usable in a narrow information pane',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = createController();
      addTearDown(controller.dispose);
      controller
        ..accept(mapStartEvent)
        ..accept(dayBattleEvent);
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveBattleCard(
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('battle-side-by-side-fleets')),
        findsOneWidget,
      );
      final friendTitle = tester.getTopLeft(find.text('我方主力（单纵阵）'));
      final enemyTitle = tester.getTopLeft(find.text('敌方主力（单纵阵）'));
      expect(friendTitle.dx, lessThan(enemyTitle.dx));
      expect((friendTitle.dy - enemyTitle.dy).abs(), lessThan(2));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('battle-mvp-friend-0')), findsOneWidget);
    },
  );

  testWidgets('defaults to full mode and can switch to compact summary', (
    tester,
  ) async {
    final controller = createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBattleCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('detailed-battle-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('battle-mode-compact')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compact-battle-panel')), findsOneWidget);
    expect(find.byKey(const Key('compact-fleet-grid')), findsOneWidget);
    expect(find.text('我方 2/2'), findsNothing);
    expect(find.text('敌方 1/2'), findsNothing);

    await tester.tap(find.byKey(const Key('battle-mode-detailed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detailed-battle-panel')), findsOneWidget);
  });

  testWidgets('live card collapses to one title row and expands again', (
    tester,
  ) async {
    final controller = createController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _TestBattleCard(controller: controller)),
      ),
    );

    await tester.tap(find.byTooltip('折叠未卜先知'));
    await tester.pumpAndSettle();

    expect(find.text('未卜先知'), findsOneWidget);
    expect(find.text('待机'), findsNothing);
    expect(find.text('等待出击数据'), findsNothing);

    await tester.tap(find.byTooltip('展开未卜先知'));
    await tester.pumpAndSettle();

    expect(find.text('待机'), findsOneWidget);
    expect(find.text('等待出击数据'), findsOneWidget);
  });

  testWidgets('confirmed full panel shows official result and drops', (
    tester,
  ) async {
    final controller = createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(battleResultEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveBattleCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
          ),
        ),
      ),
    );

    expect(find.text('已确认'), findsOneWidget);
    expect(find.text('Test Enemy Fleet'), findsOneWidget);
    expect(find.text('掉落：吹雪'), findsOneWidget);
    expect(find.text('掉落：家具コイン'), findsOneWidget);
    expect(find.textContaining('44'), findsNothing);
    expect(find.byKey(const Key('battle-mvp-friend-0')), findsOneWidget);
  });

  testWidgets('records page shows and expands an authoritative result', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(battleResultEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BattleRecordsPage(controller: controller)),
      ),
    );

    expect(find.text('战斗记录'), findsOneWidget);
    expect(find.text('Test Enemy Fleet'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    final dropName = controller.gameStateSnapshot.masterShips[102]!.name;
    expect(find.text('掉落：$dropName'), findsOneWidget);

    await tester.tap(find.byKey(const Key('battle-record-0')));
    await tester.pumpAndSettle();

    final friendName = controller.gameStateSnapshot.masterShips[101]!.name;
    expect(find.text(friendName), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('18/30')).style?.color,
      const Color(0xffffc940),
    );
    final hpBarColors = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((bar) => bar.color)
        .toSet();
    expect(hpBarColors, contains(const Color(0xffffc940)));
    expect(hpBarColors, contains(const Color(0xff29a634)));
    expect(hpBarColors, contains(const Color(0xff71818b)));
    expect(find.text('敌舰 501'), findsOneWidget);
  });
}
