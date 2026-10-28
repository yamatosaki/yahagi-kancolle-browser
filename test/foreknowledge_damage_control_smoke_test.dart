import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

import 'damage_control_briefing_sync_test.dart'
    show apiEvent, createSortieState, lethalBattle, mapData;

const _day = '/kcsapi/api_req_sortie/battle';
const _night = '/kcsapi/api_req_battle_midnight/battle';
const _result = '/kcsapi/api_req_sortie/battleresult';
const _next = '/kcsapi/api_req_map/next';
const _resultData = <String, Object?>{'api_win_rank': 'B', 'api_mvp': 1};

OwnedShip _owned(int id, {List<int> slots = const [], int extra = -1}) =>
    OwnedShip(
      id: id,
      masterId: 101,
      level: 50,
      currentHp: 30,
      maxHp: 30,
      slotIds: slots,
      extraSlotId: extra,
    );

GameState _twoItems() => createSortieState(
  ships: [
    _owned(1001, slots: [501], extra: 502),
  ],
  slotItems: const [
    OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
    OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
  ],
);

// Deliberately omit predictionExecutor: these smoke tests exercise the actual
// default IsolateBattlePredictionExecutor and the returned mutated POI engine.
BattleController _controller(GameStateController game) {
  final battle = BattleController(
    gameState: () => game.state,
    waitForGameState: () => game.idle,
    onFriendlyHpUpdated: game.applyFriendlyBattleHp,
    onDamageControlConsumed: game.applyDamageControlConsumption,
  );
  addTearDown(battle.dispose);
  addTearDown(game.dispose);
  return battle;
}

Future<void> _accept(
  WidgetTester tester,
  GameStateController game,
  BattleController battle,
  CapturedApiEvent event,
) async {
  // Widget fake time cannot drive an Isolate.run response. Bound the real wait
  // so a broken isolate round trip fails here instead of hanging the test.
  await tester.runAsync(() async {
    if (event.path.startsWith('/kcsapi/api_req_map/')) game.accept(event);
    battle.accept(event);
    await battle.idle.timeout(const Duration(seconds: 15));
    await game.idle.timeout(const Duration(seconds: 15));
  });
  await tester.pump();
  expect(battle.lastError, isNull);
}

Future<void> _start(
  WidgetTester tester,
  GameStateController game,
  BattleController battle,
) async {
  await tester.pumpWidget(_SmokeView(game: game, battle: battle));
  await _accept(
    tester,
    game,
    battle,
    apiEvent(
      '/kcsapi/api_req_map/start',
      mapData,
      sequence: 2,
      requestParams: const {'api_deck_id': '1'},
    ),
  );
}

Finder _hammers(Finder parent) => find.descendant(
  of: parent,
  matching: find.byWidgetPredicate(
    (widget) => widget is EquipmentTypeIconImage && widget.iconId == 14,
  ),
);

int _battleHammers([int position = 0]) =>
    _hammers(find.byKey(Key('battle-ship-friend-$position'))).evaluate().length;

int _equipmentHammers([int shipId = 1001]) =>
    _hammers(find.byKey(Key('equipment-$shipId'))).evaluate().length;

(int, int) _counts() => (_battleHammers(), _equipmentHammers());

Future<void> _mode(WidgetTester tester, String mode) async {
  final toggle = find.byKey(Key('battle-mode-$mode'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pump();
}

Future<void> _collapse(WidgetTester tester, {required bool collapsed}) async {
  final toggle = find.descendant(
    of: find.byKey(const Key('live-battle-card')),
    matching: find.byIcon(
      collapsed
          ? Icons.keyboard_arrow_up_rounded
          : Icons.keyboard_arrow_down_rounded,
    ),
  );
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pump();
}

void main() {
  setUpAll(() => GameStateController.disableTimerForTest = true);
  tearDownAll(() => GameStateController.disableTimerForTest = false);

  testWidgets(
    'default isolate carries battle uses across phases and resets at next node',
    (tester) async {
      final game = GameStateController(initialState: _twoItems());
      final battle = _controller(game);
      await _start(tester, game, battle);
      final counts = <(int, int)>[_counts()];

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_day, lethalBattle(30, openingHp: 30), sequence: 3),
      );
      counts.add(_counts());
      expect(game.state.ships[1001]!.slotIds, [-1]);
      expect(game.state.ships[1001]!.extraSlotId, 502);
      expect(game.state.slotItems.keys, [502]);
      expect(game.state.ships[1001]!.currentHp, 6);

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_night, const <String, Object?>{}, sequence: 4),
      );
      counts.add(_counts());
      expect(battle.current!.friendMain.single.damageControlUsedThisBattle, [
        42,
      ]);
      expect(battle.current!.friendMain.single.usedDamageControlItemIds, [42]);

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_result, _resultData, sequence: 5),
      );
      counts.add(_counts());
      expect(battle.current!.displayStage, BattleDisplayStage.result);

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_next, {...mapData, 'api_no': 2}, sequence: 6),
      );
      counts.add(_counts());
      expect(
        battle.current!.friendMain.single.damageControlUsedThisBattle,
        isEmpty,
      );

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_day, lethalBattle(6, openingHp: 6), sequence: 7),
      );
      counts.add(_counts());
      expect(battle.current!.friendMain.single.damageControlUsedThisBattle, [
        43,
      ]);
      expect(battle.current!.friendMain.single.usedDamageControlItemIds, [
        42,
        43,
      ]);
      expect(game.state.slotItems, isEmpty);
      expect(game.state.ships[1001]!.extraSlotId, -1);
      expect(game.state.ships[1001]!.currentHp, 30);
      expect(battle.isDamageControlStateTrusted, isTrue);

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_result, _resultData, sequence: 8),
      );
      counts.add(_counts());
      expect(counts, const [
        (0, 2),
        (1, 1),
        (1, 1),
        (1, 1),
        (0, 1),
        (1, 0),
        (1, 0),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed next response retains current battle hammer until successful navigation',
    (tester) async {
      final game = GameStateController(initialState: _twoItems());
      final battle = _controller(game);
      await _start(tester, game, battle);
      await _accept(
        tester,
        game,
        battle,
        apiEvent(_day, lethalBattle(30, openingHp: 30), sequence: 3),
      );
      await _accept(
        tester,
        game,
        battle,
        apiEvent(_result, _resultData, sequence: 4),
      );
      expect(_counts(), (1, 1));

      await _accept(
        tester,
        game,
        battle,
        CapturedApiEvent(
          path: _next,
          responseBody: jsonEncode({
            'api_result': 0,
            'api_data': {...mapData, 'api_no': 2},
          }),
          source: CaptureSource.xhr,
          capturedAt: DateTime.utc(2026, 9, 16),
          sequence: 5,
        ),
      );
      expect(battle.current!.context.node, 1);
      expect(battle.current!.displayStage, BattleDisplayStage.result);
      expect(battle.current!.friendMain.single.damageControlUsedThisBattle, [
        42,
      ]);
      expect(_counts(), (1, 1));

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_next, {...mapData, 'api_no': 2}, sequence: 6),
      );
      expect(battle.current!.context.node, 2);
      expect(battle.current!.displayStage, BattleDisplayStage.navigation);
      expect(
        battle.current!.friendMain.single.damageControlUsedThisBattle,
        isEmpty,
      );
      expect(_counts(), (0, 1));
      expect(game.state.ships[1001]!.extraSlotId, 502);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mode changes collapse and repeated results never revive previous node use',
    (tester) async {
      final game = GameStateController(initialState: _twoItems());
      final battle = _controller(game);
      await _start(tester, game, battle);
      await _accept(
        tester,
        game,
        battle,
        apiEvent(_day, lethalBattle(30, openingHp: 30), sequence: 3),
      );
      final firstResult = apiEvent(_result, _resultData, sequence: 4);
      await _accept(tester, game, battle, firstResult);
      await _accept(tester, game, battle, firstResult);
      await _accept(
        tester,
        game,
        battle,
        apiEvent(_result, _resultData, sequence: 5),
      );
      expect(_counts(), (1, 1));

      await _mode(tester, 'compact');
      expect(find.byKey(const Key('compact-fleet-grid')), findsOneWidget);
      await _collapse(tester, collapsed: true);
      expect(find.byKey(const Key('live-battle-expanded')), findsNothing);
      await _collapse(tester, collapsed: false);
      await _mode(tester, 'detailed');
      expect(_counts(), (1, 1));

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_next, {...mapData, 'api_no': 2}, sequence: 6),
      );
      await _accept(
        tester,
        game,
        battle,
        apiEvent(_day, lethalBattle(0, openingHp: 6), sequence: 7),
      );
      final secondResult = apiEvent(_result, _resultData, sequence: 8);
      await _accept(tester, game, battle, secondResult);
      await _accept(tester, game, battle, secondResult);
      await _accept(
        tester,
        game,
        battle,
        apiEvent(_result, _resultData, sequence: 9),
      );
      expect(_counts(), (0, 1));
      expect(battle.current!.friendMain.single.usedDamageControlItemIds, [42]);
      expect(
        battle.current!.friendMain.single.damageControlUsedThisBattle,
        isEmpty,
      );

      await _mode(tester, 'compact');
      await _collapse(tester, collapsed: true);
      await _collapse(tester, collapsed: false);
      await _mode(tester, 'detailed');
      expect(_counts(), (0, 1));
      expect(game.state.slotItems.keys, [502]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real seventh-ship consumption marks only its row and updates its inventory',
    (tester) async {
      final game = GameStateController(
        initialState: createSortieState(
          ships: [
            _owned(1001, slots: [501]),
            for (var id = 1002; id <= 1006; id++) _owned(id),
            _owned(1007, extra: 507),
          ],
          slotItems: const [
            OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
            OwnedSlotItem(instanceId: 507, masterSlotItemId: 43),
          ],
        ),
      );
      final battle = _controller(game);
      await _start(tester, game, battle);
      expect(_equipmentHammers(1001), 1);
      expect(_equipmentHammers(1007), 1);
      expect(_battleHammers(6), 0);
      await _accept(
        tester,
        game,
        battle,
        apiEvent(_day, {
          ...lethalBattle(30, openingHp: 30),
          'api_f_nowhps': [-1, for (var index = 0; index < 7; index++) 30],
          'api_f_maxhps': [-1, for (var index = 0; index < 7; index++) 30],
          'api_hougeki1': {
            'api_at_eflag': [1],
            'api_at_list': [0],
            'api_df_list': [
              [6],
            ],
            'api_damage': [
              [30],
            ],
          },
        }, sequence: 3),
      );
      expect(battle.current!.friendMain, hasLength(7));
      expect(battle.current!.friendEscort, isEmpty);
      expect(battle.current!.friendMain[6].damageControlUsedThisBattle, [43]);
      expect(battle.current!.friendMain[6].ownedShipId, 1007);
      expect(
        battle.current!.friendMain
            .take(6)
            .every((ship) => ship.damageControlUsedThisBattle.isEmpty),
        isTrue,
      );
      expect(_battleHammers(0), 0);
      expect(_battleHammers(6), 1);
      expect(_equipmentHammers(1001), 1);
      expect(_equipmentHammers(1007), 0);
      expect(game.state.ships[1001]!.slotIds, [501]);
      expect(game.state.ships[1007]!.extraSlotId, -1);
      expect(game.state.slotItems.keys, [501]);
      expect(game.state.ships[1007]!.currentHp, 30);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real combined escort consumption keeps main equipment and resets only battle markers at next',
    (tester) async {
      final game = GameStateController(
        initialState:
            createSortieState(
              ships: [
                _owned(1001, slots: [501]),
                _owned(2001, extra: 601),
              ],
              slotItems: const [
                OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
                OwnedSlotItem(instanceId: 601, masterSlotItemId: 43),
              ],
            ).copyWith(
              combinedFleetType: CombinedFleetType.surfaceTaskForce,
              fleets: const [
                Fleet(id: 1, name: '第一舰队', shipIds: [1001]),
                Fleet(id: 2, name: '第二舰队', shipIds: [2001]),
              ],
            ),
      );
      final battle = _controller(game);
      await _start(tester, game, battle);

      Future<void> selectFleet(int id) async {
        final selector = find.byKey(Key('fleet-summary-selector-$id'));
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pump();
      }

      expect(_equipmentHammers(1001), 1);
      await selectFleet(2);
      expect(_equipmentHammers(2001), 1);
      expect(_battleHammers(0), 0);
      expect(_battleHammers(6), 0);

      await _accept(
        tester,
        game,
        battle,
        apiEvent('/kcsapi/api_req_combined_battle/each_battle', {
          ...lethalBattle(30, openingHp: 30),
          'api_f_nowhps_combined': [-1, 30],
          'api_f_maxhps_combined': [-1, 30],
          'api_hougeki1': {
            'api_at_eflag': [1],
            'api_at_list': [0],
            'api_df_list': [
              [6],
            ],
            'api_damage': [
              [30],
            ],
          },
        }, sequence: 3),
      );
      expect(battle.current!.friendMain.single.ownedShipId, 1001);
      expect(battle.current!.friendEscort.single.ownedShipId, 2001);
      expect(
        battle.current!.friendMain.single.damageControlUsedThisBattle,
        isEmpty,
      );
      expect(battle.current!.friendEscort.single.damageControlUsedThisBattle, [
        43,
      ]);
      expect(_battleHammers(0), 0);
      expect(_battleHammers(6), 1);
      expect(_equipmentHammers(2001), 0);
      expect(game.state.ships[2001]!.extraSlotId, -1);
      expect(game.state.ships[2001]!.currentHp, 30);
      expect(game.state.ships[1001]!.slotIds, [501]);
      expect(game.state.slotItems.keys, [501]);
      await selectFleet(1);
      expect(_equipmentHammers(1001), 1);

      await _accept(
        tester,
        game,
        battle,
        apiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          _resultData,
          sequence: 4,
        ),
      );
      expect(battle.current!.displayStage, BattleDisplayStage.result);
      expect(_battleHammers(0), 0);
      expect(_battleHammers(6), 1);
      expect(battle.current!.friendEscort.single.usedDamageControlItemIds, [
        43,
      ]);

      await _accept(
        tester,
        game,
        battle,
        apiEvent(_next, {...mapData, 'api_no': 2}, sequence: 5),
      );
      expect(battle.current!.context.node, 2);
      expect(
        battle.current!.friendEscort.single.damageControlUsedThisBattle,
        isEmpty,
      );
      expect(_battleHammers(0), 0);
      expect(_battleHammers(6), 0);
      expect(_equipmentHammers(1001), 1);
      await selectFleet(2);
      expect(_equipmentHammers(2001), 0);
      expect(game.state.slotItems.keys, [501]);
      expect(battle.isDamageControlStateTrusted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SmokeView extends StatefulWidget {
  const _SmokeView({required this.game, required this.battle});

  final GameStateController game;
  final BattleController battle;

  @override
  State<_SmokeView> createState() => _SmokeViewState();
}

class _SmokeViewState extends State<_SmokeView> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 389,
          child: Column(
            children: [
              FleetSummaryCard(
                controller: widget.game,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenFleet: (_) {},
              ),
              LiveBattleCard(
                controller: widget.battle,
                collapsed: _collapsed,
                onToggleCollapse: () =>
                    setState(() => _collapsed = !_collapsed),
                damagePulseMode: DamagePulseFilter.off,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
