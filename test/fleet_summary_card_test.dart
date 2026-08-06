import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('standby fleet uses the shared green status color', (
    tester,
  ) async {
    final controller = GameStateController(
      gameStateStore: _StaticGameStateStore(
        const GameState(
          fleets: <Fleet>[
            Fleet(id: 1, name: '第1舰队', shipIds: <int>[9001]),
          ],
          hasPortData: true,
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('母港待命'), findsOneWidget);
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const Key('fleet-status-dot-1')),
                  )
                  .decoration
              as BoxDecoration?)
          ?.color,
      const Color(0xff29a634),
    );
  });

  testWidgets('tapping a fleet capsule opens that fleet', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    int? openedFleetId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: (id) => openedFleetId = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('第一舰队'));
    expect(openedFleetId, 1);

    await tester.tap(find.text('第二舰队'));
    expect(openedFleetId, 2);
  });

  testWidgets('sortie fleet stays active until the next port snapshot', (
    tester,
  ) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(mapStartEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.state.combatState.sortieFleetId, 1);
    expect(find.text('出击中'), findsOneWidget);

    controller.accept(portEvent);
    await controller.idle;
    await tester.pump();

    expect(controller.state.combatState.isActive, isFalse);
    expect(controller.state.combatState.sortieFleetId, 0);
    expect(find.text('出击中'), findsNothing);
    expect(find.text('母港待命'), findsWidgets);
  });

  testWidgets('expedition changes to returned when countdown completes', (
    tester,
  ) async {
    var now = DateTime.now().toUtc();
    final controller = GameStateController(
      gameStateStore: _StaticGameStateStore(
        GameState(
          fleets: <Fleet>[
            Fleet(
              id: 1,
              name: '2',
              shipIds: const <int>[9001],
              mission: FleetMission(
                state: 1,
                missionId: 5,
                completionTime: now.add(const Duration(seconds: 1)),
              ),
            ),
          ],
          hasPortData: true,
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetSummaryCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: (_) {},
            clock: () => now,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('远征中'), findsOneWidget);
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const Key('fleet-status-dot-1')),
                  )
                  .decoration
              as BoxDecoration?)
          ?.color,
      const Color(0xffffc940),
    );
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('已返母港'), findsOneWidget);
    expect(find.text('远征中'), findsNothing);
    expect(
      (tester
                  .widget<Container>(
                    find.byKey(const Key('fleet-status-dot-1')),
                  )
                  .decoration
              as BoxDecoration?)
          ?.color,
      const Color(0xff03a9f4),
    );
  });
}

class _StaticGameStateStore extends GameStateStore {
  _StaticGameStateStore(this.value);

  final GameState value;

  @override
  Future<GameState> load() async => value;
}
