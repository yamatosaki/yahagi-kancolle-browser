import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('selected fleet renders its ship status capsules', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    expect(find.text('第一舰队'), findsOneWidget);
    expect(find.byType(FleetShipStatusCapsule), findsNWidgets(2));
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('吹雪'), findsOneWidget);
  });

  testWidgets('fleet selector changes the list and ship tap opens that fleet', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);
    int? openedFleetId;

    await tester.pumpWidget(
      _card(
        controller: controller,
        onOpenFleet: (fleetId) => openedFleetId = fleetId,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FleetShipStatusCapsule).first);
    expect(openedFleetId, 1);

    await tester.tap(find.text('第二舰队'));
    await tester.pump();
    expect(find.byType(FleetShipStatusCapsule), findsOneWidget);
    expect(find.text('吹雪'), findsOneWidget);

    await tester.tap(find.byType(FleetShipStatusCapsule));
    expect(openedFleetId, 2);
  });

  testWidgets('selecting an empty fleet shows the empty state', (tester) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();
    await tester.tap(find.text('第三舰队'));
    await tester.pump();

    expect(find.text('无数据'), findsOneWidget);
    expect(find.byType(FleetShipStatusCapsule), findsNothing);
  });

  testWidgets('repeating ship animations do not block finite-frame tests', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.byType(FleetShipStatusCapsule), findsNWidgets(2));
  });
}

Future<GameStateController> _controllerWithPortData() async {
  final controller = GameStateController();
  controller
    ..accept(start2Event)
    ..accept(portEvent)
    ..accept(slotItemEvent);
  await controller.idle;
  return controller;
}

Widget _card({
  required GameStateController controller,
  ValueChanged<int>? onOpenFleet,
}) => MaterialApp(
  home: Scaffold(
    body: FleetSummaryCard(
      controller: controller,
      collapsed: false,
      onToggleCollapse: () {},
      onOpenFleet: onOpenFleet ?? (_) {},
    ),
  ),
);
