import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_check_summary.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';

void main() {
  testWidgets('five warning pills use agreed copy colors and fleet links', (
    tester,
  ) async {
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(
          id: 101,
          name: '瑞鹤改二甲',
          shipTypeId: 18,
          maxFuel: 100,
          maxAmmo: 100,
          slotCount: 2,
        ),
        102: MasterShip(
          id: 102,
          name: '雪风改',
          shipTypeId: 2,
          maxFuel: 20,
          maxAmmo: 20,
          slotCount: 3,
        ),
      },
      ships: const <int, OwnedShip>{
        1001: OwnedShip(
          id: 1001,
          masterId: 101,
          level: 99,
          currentHp: 2,
          maxHp: 10,
          currentFuel: 50,
          currentAmmo: 50,
          condition: 18,
          slotIds: <int>[7001],
          extraSlotId: 0,
        ),
        1002: OwnedShip(
          id: 1002,
          masterId: 102,
          level: 80,
          currentHp: 30,
          maxHp: 30,
          currentFuel: 20,
          currentAmmo: 20,
          condition: 49,
          slotIds: <int>[7002, 7003],
          extraSlotId: -1,
        ),
      },
      fleets: const <Fleet>[
        Fleet(id: 1, name: '第1舰队', shipIds: <int>[1001, 1002]),
      ],
      hasMasterData: true,
      hasPortData: true,
    );
    final controller = GameStateController(gameStateStore: _StaticStore(state));
    addTearDown(controller.dispose);
    await controller.idle;
    final openedFleetIds = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PreSortieCheckSummary(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
            onOpenFleet: openedFleetIds.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第1舰队 存在大破舰，停止出击！'), findsOneWidget);
    expect(find.text('第1舰队 舰娘未补给'), findsOneWidget);
    expect(find.text('第1舰队 舰娘疲劳未恢复'), findsOneWidget);
    expect(find.text('第1舰队 装备缺失（主装备槽）：瑞鹤改二甲、雪风改'), findsOneWidget);
    expect(find.text('第1舰队 装备缺失（增设槽）：瑞鹤改二甲'), findsOneWidget);

    const kinds = <String>[
      'critical',
      'supply',
      'fatigue',
      'main-equipment',
      'extra-equipment',
    ];
    for (final kind in kinds) {
      final warning = find.byKey(Key('pre-sortie-warning-1-$kind'));
      final surface = tester.widget<Material>(
        find.byKey(Key('pre-sortie-warning-surface-1-$kind')),
      );
      final expected = kind == 'critical'
          ? const Color(0xfff44336)
          : const Color(0xffff9800);
      expect(surface.color, expected.withValues(alpha: 0.2));
      final shape = surface.shape! as RoundedRectangleBorder;
      expect(shape.side.color, expected);
      await tester.tap(warning);
    }
    expect(openedFleetIds, <int>[1, 1, 1, 1, 1]);
  });
}

class _StaticStore extends GameStateStore {
  _StaticStore(this.value);

  final GameState value;

  @override
  Future<GameState> load() async => value;
}
