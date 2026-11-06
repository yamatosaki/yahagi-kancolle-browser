import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/capture/advance_warning_details.dart';
import 'package:yahagi_kancolle_browser/src/fleet/equipment_type_icon.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

import 'damage_control_briefing_sync_test.dart'
    show apiEvent, createSortieState, mapData;

const _targetId = 1002;
const _repairItem = 501;
const _battlePath = '/kcsapi/api_req_sortie/battle';
const _nightPath = '/kcsapi/api_req_battle_midnight/battle';
const _resultPath = '/kcsapi/api_req_sortie/battleresult';

void main() {
  for (final settle in [false, true]) {
    testWidgets(
      '${settle ? 'Settlement' : 'Default immediate'} sync across day, night, '
      'result, and the next node',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1180, 1060);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final harness = _FleetSyncHarness(
          _sortieState(expansionDamageControl: settle),
          settle: settle,
        );
        final state = harness.state;
        final battle = harness.battle;

        Future<void> publish(
          String path,
          Object? data, {
          Map<String, Object?> request = const {},
        }) async {
          await harness.publish(path, data, request: request);
          await tester.pump();
        }

        await tester.pumpWidget(_fleetPanels(state));
        await tester.tap(find.byKey(const Key('fleet-roster-ship-$_targetId')));
        await tester.pump();
        _expectFleetDisplay(tester, hp: 30, damageControl: true);
        await publish(
          '/kcsapi/api_req_map/start',
          mapData,
          request: const {'api_deck_id': '1'},
        );

        await publish(_battlePath, _dayBattle(30, openingHp: 30));
        _expectLiveBattle(state, battle, hp: 6, damageControl: false);
        _expectFleetDisplay(tester, hp: settle ? 30 : 6, damageControl: settle);

        await publish(_nightPath, {'api_hougeki': _hit(2)});
        _expectLiveBattle(state, battle, hp: 4, damageControl: false);
        _expectFleetDisplay(tester, hp: settle ? 30 : 4, damageControl: settle);

        await publish(_resultPath, const {'api_win_rank': '?'});
        _expectFleetDisplay(tester, hp: settle ? 30 : 4, damageControl: settle);

        await publish(_resultPath, const {'api_win_rank': 'B', 'api_mvp': 1});
        expect(battle.current?.displayStage, BattleDisplayStage.result);
        _expectFleetDisplay(tester, hp: 4, damageControl: false);

        await publish('/kcsapi/api_get_member/ship_deck', {
          'api_ship_data': [
            {
              'api_id': _targetId,
              'api_ship_id': 102,
              'api_nowhp': 5,
              'api_maxhp': 30,
              'api_slot': [100, -1],
            },
          ],
        });
        _expectFleetDisplay(tester, hp: 5, damageControl: false);

        // App rebuilds rebind the same updater. Keep the server correction.
        await tester.runAsync(() async {
          battle.bindFriendlyHpUpdater(state.applyFriendlyBattleHp);
          await state.idle;
        });
        await tester.pump();
        expect(state.state.ships[_targetId]!.currentHp, 5);
        _expectFleetDisplay(tester, hp: 5, damageControl: false);

        await publish('/kcsapi/api_req_map/next', {...mapData, 'api_no': 2});
        await publish(_battlePath, _dayBattle(1, openingHp: 5));
        _expectLiveBattle(state, battle, hp: 4, damageControl: false);
        _expectFleetDisplay(tester, hp: settle ? 5 : 4, damageControl: false);

        if (settle) {
          state.setDeferFleetBattleDisplay(false);
          await tester.pump();
          _expectFleetDisplay(tester, hp: 4, damageControl: false);

          state.setDeferFleetBattleDisplay(true);
          await publish(_nightPath, {'api_hougeki': _hit(1)});
          _expectFleetDisplay(tester, hp: 3, damageControl: false);
        }

        await publish(_resultPath, const {'api_win_rank': 'B', 'api_mvp': 1});
        _expectFleetDisplay(tester, hp: settle ? 3 : 4, damageControl: false);

        if (settle) {
          await publish('/kcsapi/api_req_map/next', {...mapData, 'api_no': 3});
          await publish(_battlePath, _dayBattle(1, openingHp: 3));
          _expectLiveBattle(state, battle, hp: 2, damageControl: false);
          _expectFleetDisplay(tester, hp: 3, damageControl: false);

          await publish('/kcsapi/api_req_map/next', {...mapData, 'api_no': 4});
          _expectFleetDisplay(tester, hp: 2, damageControl: false);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Combined settlement releases both fleet displays', (
    tester,
  ) async {
    final harness = _FleetSyncHarness(
      _sortieState(expansionDamageControl: true).copyWith(
        combinedFleetType: CombinedFleetType.surfaceTaskForce,
        fleets: const [
          Fleet(id: 1, name: 'Main', shipIds: [1001]),
          Fleet(id: 2, name: 'Escort', shipIds: [_targetId]),
        ],
      ),
      settle: true,
    );
    final state = harness.state;
    await harness.publish(
      '/kcsapi/api_req_map/start',
      mapData,
      request: const {'api_deck_id': '1'},
    );
    await harness.publish('/kcsapi/api_req_combined_battle/battle_water', {
      ..._dayBattle(0, openingHp: 30),
      'api_f_nowhps': [-1, 30],
      'api_f_maxhps': [-1, 30],
      'api_f_nowhps_combined': [-1, 30],
      'api_f_maxhps_combined': [-1, 30],
      'api_hougeki1': {
        'api_at_eflag': [1, 1],
        'api_at_list': [0, 0],
        'api_df_list': [
          [0],
          [6],
        ],
        'api_damage': [
          [5],
          [30],
        ],
      },
    });
    expect(state.state.ships[1001]!.currentHp, 25);
    expect(state.state.ships[_targetId]!.currentHp, 6);
    expect(state.state.slotItems[_repairItem], isNull);
    expect(state.fleetDisplayState.ships[1001]!.currentHp, 30);
    expect(state.fleetDisplayState.ships[_targetId]!.currentHp, 30);
    expect(state.fleetDisplayState.slotItems[_repairItem], isNotNull);

    await harness.publish('/kcsapi/api_req_combined_battle/battleresult', {
      'api_win_rank': 'B',
      'api_mvp': 1,
      'api_mvp_combined': 1,
    });
    expect(state.fleetDisplayState, same(state.state));
    await tester.pump();
  });
}

class _FleetSyncHarness {
  _FleetSyncHarness(GameState initialState, {required bool settle})
    : state = GameStateController(initialState: initialState) {
    if (settle) state.setDeferFleetBattleDisplay(true);
    battle = BattleController(
      gameState: () => state.state,
      waitForGameState: () => state.idle,
      onFriendlyHpUpdated: state.applyFriendlyBattleHp,
      onDamageControlConsumed: state.applyDamageControlConsumption,
      onFleetBattleDisplayStarted: state.beginFleetBattleDisplay,
      onFleetBattleDisplaySettled: state.settleFleetBattleDisplay,
      predictionExecutor: const ImmediateBattlePredictionExecutor(),
    );
    _pipeline = GameApiEventPipeline(
      consumers: [state, battle],
      settleGameState: () async {
        await state.idle;
        await battle.idle;
        await state.idle;
      },
    );
    addTearDown(state.dispose);
    addTearDown(battle.dispose);
  }

  final GameStateController state;
  late final BattleController battle;
  late final GameApiEventPipeline _pipeline;
  int _sequence = 0;

  Future<void> publish(
    String path,
    Object? data, {
    Map<String, Object?> request = const {},
  }) {
    _pipeline.add(
      apiEvent(path, data, sequence: ++_sequence, requestParams: request),
    );
    return _pipeline.idle;
  }
}

Widget _fleetPanels(GameStateController controller) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Column(
      children: [
        SizedBox(
          height: 300,
          child: SingleChildScrollView(
            child: FleetSummaryCard(
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
              onOpenFleet: (_) {},
              damagePulseFilter: DamagePulseFilter.off,
              moraleSparkleMode: MoraleSparkleMode.off,
            ),
          ),
        ),
        Expanded(
          child: FleetInformationCenter(
            controller: controller,
            damagePulseMode: DamagePulseFilter.off,
            moraleSparkleMode: MoraleSparkleMode.off,
          ),
        ),
      ],
    ),
  ),
);

void _expectFleetDisplay(
  WidgetTester tester, {
  required int hp,
  required bool damageControl,
}) {
  final summaryShip = tester
      .widgetList<FleetShipStatusCapsule>(find.byType(FleetShipStatusCapsule))
      .singleWhere((capsule) => capsule.ship.id == _targetId);
  expect(summaryShip.ship.currentHp, hp, reason: 'briefing HP');
  expect(
    tester
        .widgetList<EquipmentTypeIconImage>(
          find.descendant(
            of: find.byKey(const Key('equipment-$_targetId')),
            matching: find.byType(EquipmentTypeIconImage),
          ),
        )
        .map((icon) => icon.iconId),
    [1, if (damageControl) 14],
    reason: 'briefing equipment',
  );
  final detail = find.byType(FleetInformationCenter);
  expect(
    tester
        .widget<Text>(
          find.descendant(
            of: detail,
            matching: find.byKey(const Key('fleet-focus-hp-value-$_targetId')),
          ),
        )
        .data,
    '$hp/30',
    reason: 'details HP',
  );
  expect(
    find.byKey(const Key('fleet-equipment-row-$_targetId-0')),
    findsOneWidget,
  );
  expect(
    find.byKey(const Key('fleet-equipment-row-$_targetId-1')),
    damageControl ? findsOneWidget : findsNothing,
    reason: 'details damage control',
  );
}

void _expectLiveBattle(
  GameStateController state,
  BattleController battle, {
  required int hp,
  required bool damageControl,
}) {
  expect(state.state.ships[_targetId]!.currentHp, hp);
  expect(state.state.slotItems.containsKey(_repairItem), damageControl);
  final forecastShip = battle.current!.friendShips.singleWhere(
    (ship) => ship.ownedShipId == _targetId,
  );
  expect(forecastShip.currentHp, hp);
  final warning = collectAdvanceWarningShips(
    state.state,
    damageControlStateTrusted: battle.isDamageControlStateTrusted,
  ).single;
  expect(warning.ship.currentHp, hp, reason: 'advance warning HP');
  expect(
    warning.damageControlStatus,
    damageControl
        ? AdvanceDamageControlStatus.equipped
        : AdvanceDamageControlStatus.missing,
    reason: 'advance warning damage control inventory',
  );
}

GameState _sortieState({required bool expansionDamageControl}) =>
    createSortieState(
      ships: [
        const OwnedShip(
          id: 1001,
          masterId: 101,
          level: 50,
          currentHp: 30,
          maxHp: 30,
        ),
        OwnedShip(
          id: _targetId,
          masterId: 102,
          level: 50,
          currentHp: 30,
          maxHp: 30,
          slotIds: [100, expansionDamageControl ? -1 : _repairItem],
          extraSlotId: expansionDamageControl ? _repairItem : -1,
        ),
      ],
      slotItems: const [
        OwnedSlotItem(instanceId: 100, masterSlotItemId: 1),
        OwnedSlotItem(instanceId: _repairItem, masterSlotItemId: 42),
      ],
    ).copyWith(hasEquipmentInventory: true);

Map<String, Object?> _dayBattle(int damage, {required int openingHp}) => {
  'api_deck_id': 1,
  'api_formation': [1, 1, 1],
  'api_f_nowhps': [-1, 30, openingHp],
  'api_f_maxhps': [-1, 30, 30],
  'api_e_nowhps': [-1, 20],
  'api_e_maxhps': [-1, 20],
  'api_ship_ke': [-1, 501],
  'api_hougeki1': _hit(damage),
};

Map<String, Object?> _hit(int damage) => {
  'api_at_eflag': [1],
  'api_at_list': [0],
  'api_df_list': [
    [1],
  ],
  'api_damage': [
    [damage],
  ],
};
