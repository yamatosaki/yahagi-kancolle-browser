import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_check_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';

void main() {
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

    await tester.tap(find.text('详情页'));
    expect(opened, isTrue);

    await tester.tap(find.byKey(const Key('expedition-check-collapse')));
    await tester.pumpAndSettle();
    expect(find.text('详情页'), findsNothing);
  });

  testWidgets('真实母港规模不会让远征卡片无限分配内存', (tester) async {
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
