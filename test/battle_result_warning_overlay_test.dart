import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/battle/sortie_damage_control_ledger.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/capture/sortie_warning_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

import 'fixtures/kcsapi_fixtures.dart';

BattleShipSnapshot _heavyDamageShip({
  BattleFleetRole fleetRole = BattleFleetRole.main,
  int position = 1,
  String name = 'test',
}) {
  return BattleShipSnapshot(
    masterId: 1,
    name: name,
    side: BattleSide.friend,
    fleetRole: fleetRole,
    position: position,
    initialHp: 20,
    maxHp: 20,
    currentHp: 5,
  );
}

OwnedShip _ownedShip(
  int id, {
  int currentHp = 20,
  int maxHp = 20,
  List<int> slotIds = const [],
  int extraSlotId = -1,
}) => OwnedShip(
  id: id,
  masterId: id,
  level: 99,
  currentHp: currentHp,
  maxHp: maxHp,
  slotIds: slotIds,
  extraSlotId: extraSlotId,
);

GameState _sortieState({
  required List<OwnedShip> main,
  List<OwnedShip> escort = const <OwnedShip>[],
  CombinedFleetType combinedFleetType = CombinedFleetType.none,
  Set<int> escapedShipIds = const <int>{},
  List<int> pendingEscapeShipIds = const <int>[],
  bool isActive = true,
  bool hasEquipmentInventory = true,
}) {
  final ships = <int, OwnedShip>{
    for (final ship in <OwnedShip>[...main, ...escort]) ship.id: ship,
  };
  return GameState(
    memberId: 1001,
    hasEquipmentInventory: hasEquipmentInventory,
    ships: ships,
    fleets: <Fleet>[
      Fleet(
        id: 1,
        name: '主力',
        shipIds: <int>[for (final ship in main) ship.id],
      ),
      if (escort.isNotEmpty)
        Fleet(
          id: 2,
          name: '随伴',
          shipIds: <int>[for (final ship in escort) ship.id],
        ),
    ],
    combinedFleetType: combinedFleetType,
    combatState: CombatState(
      sortieFleetId: 1,
      isActive: isActive,
      escapedShipIds: escapedShipIds,
      pendingEscapeShipIds: pendingEscapeShipIds,
    ),
  );
}

GameState _equipmentState({
  required List<OwnedShip> main,
  List<OwnedShip> escort = const [],
  Map<int, String> names = const {},
  Map<int, OwnedSlotItem> equipment = const {},
  bool hasEquipmentInventory = true,
}) =>
    _sortieState(
      main: main,
      escort: escort,
      combinedFleetType: escort.isEmpty
          ? CombinedFleetType.none
          : CombinedFleetType.surfaceTaskForce,
      hasEquipmentInventory: hasEquipmentInventory,
    ).copyWith(
      masterShips: {
        for (final ship in [...main, ...escort])
          ship.masterId: MasterShip(
            id: ship.masterId,
            name: names[ship.masterId] ?? '舰娘${ship.id}',
            shipTypeId: 2,
          ),
      },
      masterSlotItems: const {
        1: MasterSlotItem(id: 1, name: '小口径主炮'),
        42: MasterSlotItem(id: 42, name: '应急修理要员'),
        43: MasterSlotItem(id: 43, name: '应急修理女神'),
      },
      slotItems: equipment,
    );

Future<void> _advance(WidgetTester tester, _WarningOverlayFixture fixture) =>
    fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const {}),
    );

Future<void> _acknowledge(WidgetTester tester) async {
  await tester.tap(find.text('确认了解'));
  await tester.pumpAndSettle();
}

Future<void> _suppressSortie(WidgetTester tester) async {
  await tester.tap(find.text('此次出击不再提醒'));
  await tester.pumpAndSettle();
}

bool _trustedDamageControlState() => true;

void main() {
  test('boss result has no retreat risk even with a heavily damaged ship', () {
    final battle = LiveBattle(
      context: const BattleContext(node: 5, bossNode: 5),
      friendMain: <BattleShipSnapshot>[_heavyDamageShip()],
      displayStage: BattleDisplayStage.result,
    );

    expect(shouldShowPostBattleWarning(battle), isFalse);
  });

  test('non-boss result keeps the heavily damaged retreat warning', () {
    final battle = LiveBattle(
      context: const BattleContext(node: 4, bossNode: 5),
      friendMain: <BattleShipSnapshot>[_heavyDamageShip()],
      displayStage: BattleDisplayStage.result,
    );

    expect(shouldShowPostBattleWarning(battle), isTrue);
  });

  group('combined escort flagship warning exception', () {
    const combinedContext = BattleContext(
      node: 4,
      bossNode: 5,
      combinedFleetType: CombinedFleetType.surfaceTaskForce,
    );

    LiveBattle resultBattle({
      BattleContext? context,
      List<BattleShipSnapshot> main = const <BattleShipSnapshot>[],
      List<BattleShipSnapshot> escort = const <BattleShipSnapshot>[],
    }) => LiveBattle(
      context: context ?? combinedContext,
      friendMain: main,
      friendEscort: escort,
      displayStage: BattleDisplayStage.result,
    );

    test('does not warn when only the combined escort flagship is heavy', () {
      final battle = resultBattle(
        escort: <BattleShipSnapshot>[
          _heavyDamageShip(
            fleetRole: BattleFleetRole.escort,
            position: 0,
            name: '二队旗舰',
          ),
        ],
      );

      expect(shouldShowPostBattleWarning(battle), isFalse);
    });

    test('still warns for a combined escort non-flagship', () {
      final battle = resultBattle(
        escort: <BattleShipSnapshot>[
          _heavyDamageShip(
            fleetRole: BattleFleetRole.escort,
            position: 1,
            name: '二队僚舰',
          ),
        ],
      );

      expect(shouldShowPostBattleWarning(battle), isTrue);
    });

    test('does not warn for only a combined main-fleet flagship', () {
      final battle = resultBattle(
        main: <BattleShipSnapshot>[_heavyDamageShip(position: 0, name: '一队旗舰')],
      );

      expect(shouldShowPostBattleWarning(battle), isFalse);
    });

    test('does not warn for only a normal fleet flagship', () {
      expect(
        shouldShowPostBattleWarning(
          resultBattle(
            context: const BattleContext(node: 4, bossNode: 5),
            main: [_heavyDamageShip(position: 0)],
          ),
        ),
        isFalse,
      );
    });

    test('still warns when another ship is heavy with the escort flagship', () {
      final battle = resultBattle(
        escort: <BattleShipSnapshot>[
          _heavyDamageShip(
            fleetRole: BattleFleetRole.escort,
            position: 0,
            name: '二队旗舰',
          ),
          _heavyDamageShip(
            fleetRole: BattleFleetRole.escort,
            position: 2,
            name: '二队僚舰',
          ),
        ],
      );

      expect(shouldShowPostBattleWarning(battle), isTrue);
    });

    test(
      'does not treat an escort-like snapshot as safe outside combined fleet',
      () {
        final battle = resultBattle(
          context: const BattleContext(node: 4, bossNode: 5),
          escort: <BattleShipSnapshot>[
            _heavyDamageShip(
              fleetRole: BattleFleetRole.escort,
              position: 0,
              name: '普通舰队舰娘',
            ),
          ],
        );

        expect(shouldShowPostBattleWarning(battle), isTrue);
      },
    );
  });

  group('advance warning uses the settled sortie state', () {
    test(
      'ignores a confirmed escaped ship but warns for another heavy ship',
      () {
        final state = _sortieState(
          main: <OwnedShip>[_ownedShip(101)],
          escort: <OwnedShip>[
            _ownedShip(201),
            _ownedShip(202, currentHp: 2),
            _ownedShip(203, currentHp: 3),
          ],
          combinedFleetType: CombinedFleetType.carrierTaskForce,
          escapedShipIds: const <int>{202},
        );

        expect(shouldShowAdvanceWarning(state), isTrue);
      },
    );

    test('does not warn when every heavy ship has confirmed escape', () {
      final state = _sortieState(
        main: <OwnedShip>[_ownedShip(101)],
        escort: <OwnedShip>[
          _ownedShip(201),
          _ownedShip(202, currentHp: 2),
          _ownedShip(203),
        ],
        combinedFleetType: CombinedFleetType.carrierTaskForce,
        escapedShipIds: const <int>{202},
      );

      expect(shouldShowAdvanceWarning(state), isFalse);
    });

    test('keeps the combined escort flagship exception', () {
      final state = _sortieState(
        main: <OwnedShip>[_ownedShip(101)],
        escort: <OwnedShip>[_ownedShip(201, currentHp: 2), _ownedShip(202)],
        combinedFleetType: CombinedFleetType.carrierTaskForce,
      );

      expect(shouldShowAdvanceWarning(state), isFalse);
    });

    test('does not warn for only the combined main-fleet flagship', () {
      final state = _sortieState(
        main: <OwnedShip>[_ownedShip(101, currentHp: 2), _ownedShip(102)],
        escort: <OwnedShip>[_ownedShip(201), _ownedShip(202)],
        combinedFleetType: CombinedFleetType.surfaceTaskForce,
      );

      expect(shouldShowAdvanceWarning(state), isFalse);
    });

    test('ignores main flagship but keeps warnings for accompanying ships', () {
      for (final type in CombinedFleetType.values) {
        final state = _sortieState(
          main: [_ownedShip(101, currentHp: 2), _ownedShip(102)],
          combinedFleetType: type,
        );
        expect(shouldShowAdvanceWarning(state), isFalse, reason: type.name);
        expect(
          shouldShowAdvanceWarning(
            state.copyWith(
              ships: {...state.ships, 102: _ownedShip(102, currentHp: 2)},
            ),
          ),
          isTrue,
          reason: type.name,
        );
      }
    });

    test('missing flagship data must not reclassify a damaged second ship', () {
      final state = _sortieState(
        main: [_ownedShip(101), _ownedShip(102, currentHp: 2)],
      );
      expect(
        shouldShowAdvanceWarning(
          state.copyWith(ships: {102: state.ships[102]!}),
        ),
        isTrue,
      );
    });

    test('pending escape is not treated as confirmed escape', () {
      final state = _sortieState(
        main: <OwnedShip>[_ownedShip(101), _ownedShip(102, currentHp: 2)],
        pendingEscapeShipIds: const <int>[102],
      );

      expect(shouldShowAdvanceWarning(state), isTrue);
    });

    test('does not warn after the sortie has returned to port', () {
      final state = _sortieState(
        main: <OwnedShip>[_ownedShip(101), _ownedShip(102, currentHp: 2)],
        isActive: false,
      );

      expect(shouldShowAdvanceWarning(state), isFalse);
    });
  });

  testWidgets('battle result alone does not show a dialog or vibration', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishRiskResult(tester);

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('advance warning offers suppression for the current sortie', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const {}),
    );

    expect(find.text('此次出击不再提醒'), findsOneWidget);
  });

  group('advance warning damage-control details', () {
    for (final scenario in [
      (
        name: 'personnel in a normal slot',
        slotIds: <int>[7001],
        extraSlotId: -1,
        equipment: <int, OwnedSlotItem>{
          7001: const OwnedSlotItem(id: 7001, masterId: 42),
        },
        headline: '大破舰娘已携带损管，请确认剩余装备。',
        status: '携带：应急修理要员 ×1',
      ),
      (
        name: 'goddess in the expansion slot',
        slotIds: <int>[-1, -1],
        extraSlotId: 7002,
        equipment: <int, OwnedSlotItem>{
          7002: const OwnedSlotItem(id: 7002, masterId: 43),
        },
        headline: '大破舰娘已携带损管，请确认剩余装备。',
        status: '携带：应急修理女神 ×1',
      ),
      (
        name: 'empty normal and expansion slots',
        slotIds: <int>[-1, 0],
        extraSlotId: -1,
        equipment: <int, OwnedSlotItem>{},
        headline: '存在未携带损管的大破舰娘！',
        status: '未携带损管',
      ),
      (
        name: 'both damage-control types',
        slotIds: <int>[7001],
        extraSlotId: 7002,
        equipment: <int, OwnedSlotItem>{
          7001: const OwnedSlotItem(id: 7001, masterId: 42),
          7002: const OwnedSlotItem(id: 7002, masterId: 43),
        },
        headline: '大破舰娘已携带损管，请确认剩余装备。',
        status: '携带：应急修理要员 ×1、应急修理女神 ×1',
      ),
    ]) {
      testWidgets('shows the current ${scenario.name}', (tester) async {
        final fixture = await _WarningOverlayFixture.create(
          mode: BattleWarningMode.confirm,
          initialState: _equipmentState(
            main: [
              _ownedShip(101),
              _ownedShip(
                102,
                currentHp: 2,
                slotIds: scenario.slotIds,
                extraSlotId: scenario.extraSlotId,
              ),
            ],
            names: const {102: '矢矧改二'},
            equipment: scenario.equipment,
          ),
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await _advance(tester, fixture);

        expect(find.text(scenario.headline), findsOneWidget);
        expect(find.textContaining('矢矧改二'), findsOneWidget);
        expect(find.text(scenario.status), findsOneWidget);
        if (scenario.equipment.isNotEmpty) {
          expect(find.text('已在大破状态下选择进击，请确认舰船及剩余损管。'), findsOneWidget);
          expect(find.text('已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。'), findsNothing);
        }
      });
    }

    testWidgets('sorts missing before unknown before equipped ships', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        initialState: _equipmentState(
          main: [
            _ownedShip(101),
            _ownedShip(102, currentHp: 2, slotIds: [7001]),
            _ownedShip(103, currentHp: 2, slotIds: [7999]),
            _ownedShip(104, currentHp: 2),
            _ownedShip(105, currentHp: 2),
          ],
          names: const {102: '有损管舰', 103: '未知舰', 104: '无损管甲', 105: '无损管乙'},
          equipment: const {7001: OwnedSlotItem(id: 7001, masterId: 42)},
        ),
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);

      expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
      final orderedNames = ['无损管甲', '无损管乙', '未知舰', '有损管舰'];
      for (var index = 1; index < orderedNames.length; index += 1) {
        expect(
          tester.getTopLeft(find.textContaining(orderedNames[index - 1])).dy,
          lessThan(
            tester.getTopLeft(find.textContaining(orderedNames[index])).dy,
          ),
        );
      }
      expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(1));
    });

    testWidgets('adds fleet and position only to duplicate ship names', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        initialState: _equipmentState(
          main: [
            _ownedShip(101),
            _ownedShip(102, currentHp: 2),
            _ownedShip(103, currentHp: 3),
          ],
          escort: [_ownedShip(201), _ownedShip(202, currentHp: 1)],
          names: const {102: '同名舰', 103: '独有舰', 202: '同名舰'},
        ),
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);

      expect(find.textContaining('同名舰'), findsNWidgets(2));
      expect(find.textContaining('第1舰队·2号舰'), findsOneWidget);
      expect(find.textContaining('第2舰队·2号舰'), findsOneWidget);
      expect(find.text('独有舰'), findsOneWidget);
      expect(find.textContaining('3号舰'), findsNothing);
      final dialogTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          )
          .map((widget) => widget.data ?? '')
          .join('\n');
      expect(dialogTexts, isNot(contains('HP')));
      expect(dialogTexts, isNot(matches(RegExp(r'\d+\s*/\s*\d+'))));
    });

    for (final keepGoddess in [false, true]) {
      testWidgets(
        'rechecks consumed damage control with remaining goddess $keepGoddess',
        (tester) async {
          final fixture = await _WarningOverlayFixture.create(
            mode: BattleWarningMode.confirm,
            initialState: _equipmentState(
              main: [
                _ownedShip(101),
                _ownedShip(
                  102,
                  currentHp: 2,
                  slotIds: [7001],
                  extraSlotId: keepGoddess ? 7002 : -1,
                ),
              ],
              equipment: {
                7001: const OwnedSlotItem(id: 7001, masterId: 42),
                if (keepGoddess)
                  7002: const OwnedSlotItem(id: 7002, masterId: 43),
              },
            ),
          );
          addTearDown(fixture.dispose);
          await fixture.pump(tester);
          await _advance(tester, fixture);
          await _acknowledge(tester);
          fixture.state = fixture.reducer.applyDamageControlConsumption(
            fixture.state,
            const {
              102: [DamageControlEquipmentRef(instanceId: 7001, masterId: 42)],
            },
            DateTime.utc(2026, 10, 22),
          );
          await _advance(tester, fixture);

          expect(find.textContaining('应急修理要员'), findsNothing);
          expect(
            find.text(keepGoddess ? '携带：应急修理女神 ×1' : '未携带损管'),
            findsOneWidget,
          );
          expect(fixture.alerts.alerts, hasLength(2));
        },
      );
    }

    testWidgets('open warning refreshes when the last goddess is consumed', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        initialState: _equipmentState(
          main: [
            _ownedShip(101),
            _ownedShip(102, currentHp: 2, extraSlotId: 7001),
          ],
          equipment: const {7001: OwnedSlotItem(id: 7001, masterId: 43)},
        ),
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      expect(find.text('携带：应急修理女神 ×1'), findsOneWidget);
      final originalRoute = ModalRoute.of(
        tester.element(find.byType(AlertDialog)),
      );
      fixture.state = fixture.reducer.applyDamageControlConsumption(
        fixture.state,
        const {
          102: [DamageControlEquipmentRef(instanceId: 7001, masterId: 43)],
        },
        DateTime.utc(2026, 10, 22),
      );
      await _advance(tester, fixture);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(AlertDialog))),
        same(originalRoute),
      );
      expect(find.textContaining('应急修理女神'), findsNothing);
      expect(find.text('未携带损管'), findsOneWidget);
      expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
      expect(find.text('已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。'), findsOneWidget);
      expect(find.text('已在大破状态下选择进击，请确认舰船及剩余损管。'), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));
    });

    testWidgets('open warning refreshes newly heavy and escaped ships', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        initialState: _equipmentState(
          main: [
            _ownedShip(101),
            _ownedShip(102, currentHp: 2, extraSlotId: 7001),
            _ownedShip(103),
          ],
          names: const {102: '矢矧改二', 103: '雪风改二'},
          equipment: const {7001: OwnedSlotItem(id: 7001, masterId: 43)},
        ),
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      expect(find.text('矢矧改二'), findsOneWidget);
      expect(find.text('雪风改二'), findsNothing);
      final originalRoute = ModalRoute.of(
        tester.element(find.byType(AlertDialog)),
      );
      fixture.state = fixture.state.copyWith(
        ships: {...fixture.state.ships, 103: _ownedShip(103, currentHp: 1)},
        combatState: fixture.state.combatState.copyWith(
          escapedShipIds: const {102},
        ),
      );
      await _advance(tester, fixture);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.byType(AlertDialog))),
        same(originalRoute),
      );
      expect(find.text('矢矧改二'), findsNothing);
      expect(find.text('雪风改二'), findsOneWidget);
      expect(find.text('未携带损管'), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(1));
    });

    for (final trusted in <bool?>[null, false, true]) {
      testWidgets('uses the complete unknown message when trust is $trusted', (
        tester,
      ) async {
        final fixture = await _WarningOverlayFixture.create(
          mode: BattleWarningMode.confirm,
          damageControlStateTrusted: trusted == null ? null : () => trusted,
          initialState: _equipmentState(
            main: [_ownedShip(101), _ownedShip(102, currentHp: 2)],
            hasEquipmentInventory: false,
          ),
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await _advance(tester, fixture);

        expect(find.text('大破舰娘损管状态未知！'), findsOneWidget);
        expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
        expect(find.text('未携带损管'), findsNothing);
        expect(find.text('已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。'), findsOneWidget);
      });
    }

    for (final trusted in <bool?>[null, false]) {
      testWidgets(
        'does not certify equipment when consumption trust is $trusted',
        (tester) async {
          final fixture = await _WarningOverlayFixture.create(
            mode: BattleWarningMode.confirm,
            damageControlStateTrusted: trusted == null ? null : () => trusted,
            initialState: _equipmentState(
              main: [
                _ownedShip(101),
                _ownedShip(102, currentHp: 2, slotIds: [7001]),
              ],
              equipment: const {7001: OwnedSlotItem(id: 7001, masterId: 43)},
            ),
          );
          addTearDown(fixture.dispose);
          await fixture.pump(tester);
          await _advance(tester, fixture);

          expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
          expect(find.textContaining('携带：'), findsNothing);
        },
      );
    }
  });

  group('current sortie warning suppression', () {
    testWidgets('suppresses later dialogs and vibrations after choosing mute', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      await _suppressSortie(tester);
      await _advance(tester, fixture);
      await _advance(tester, fixture);

      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));
      expect(fixture.alerts.cancellations, 1);
      expect(
        fixture.settingsController.battleWarningMode,
        BattleWarningMode.confirm,
      );
    });

    testWidgets(
      'new damage and equipment consumption do not restore reminders',
      (tester) async {
        final fixture = await _WarningOverlayFixture.create(
          mode: BattleWarningMode.confirm,
          initialState: _equipmentState(
            main: [
              _ownedShip(101),
              _ownedShip(102, currentHp: 2, slotIds: [7001]),
              _ownedShip(103),
            ],
            equipment: const {7001: OwnedSlotItem(id: 7001, masterId: 43)},
          ),
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await _advance(tester, fixture);
        await _suppressSortie(tester);
        fixture.state = fixture.reducer.applyDamageControlConsumption(
          fixture.state,
          const {
            102: [DamageControlEquipmentRef(instanceId: 7001, masterId: 43)],
          },
          DateTime.utc(2026, 10, 22),
        );
        fixture.state = fixture.state.copyWith(
          ships: {...fixture.state.ships, 103: _ownedShip(103, currentHp: 1)},
        );
        await _advance(tester, fixture);

        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, hasLength(1));
      },
    );

    testWidgets('successful new map start restores reminders', (tester) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      await _suppressSortie(tester);
      await fixture.publishEvent(
        tester,
        kcsapiEvent(
          '/kcsapi/api_req_map/start',
          const {},
          requestParams: const {'api_deck_id': 1},
        ),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(2));
    });

    testWidgets('duplicate start delivery does not clear suppression', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await fixture.publishEvent(
        tester,
        kcsapiEvent(
          '/kcsapi/api_req_map/start',
          const {},
          requestParams: const {'api_deck_id': 1},
        ),
      );
      final startEvent = fixture.captureController.latestEvent!;
      await _suppressSortie(tester);
      fixture.capturePort.add(startEvent);
      await tester.pump();
      await tester.pump();
      await _advance(tester, fixture);

      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));
    });

    testWidgets('changing warning settings does not clear sortie suppression', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      await _suppressSortie(tester);
      await fixture.settingsController.setBattleWarningMode(
        BattleWarningMode.off,
      );
      await fixture.settingsController.setBattleWarningMode(
        BattleWarningMode.confirm,
      );
      await _advance(tester, fixture);

      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));
    });

    testWidgets('returning to port clears suppression for the next sortie', (
      tester,
    ) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      await _suppressSortie(tester);
      await fixture.publishEvent(
        tester,
        kcsapiEvent('/kcsapi/api_port/port', const {}),
      );

      await _advance(tester, fixture);
      expect(find.byType(AlertDialog), findsNothing);
      await fixture.publishEvent(
        tester,
        kcsapiEvent(
          '/kcsapi/api_req_map/start',
          const {},
          requestParams: const {'api_deck_id': 1},
        ),
      );

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(2));
    });

    for (final path in ['/kcsapi/api_req_map/start', '/kcsapi/api_port/port']) {
      testWidgets('failed $path keeps current sortie suppression', (
        tester,
      ) async {
        final session = SortieWarningSession();
        final fixture = await _WarningOverlayFixture.create(
          mode: BattleWarningMode.confirm,
          warningSession: session,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await _advance(tester, fixture);
        await _suppressSortie(tester);
        final generation = session.generation;
        await fixture.publishEvent(
          tester,
          kcsapiEvent(path, const {}, apiResult: 0),
        );
        await _advance(tester, fixture);

        expect(session.generation, generation);
        expect(session.isMuted, isTrue);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, hasLength(1));
      });
    }

    for (final unknownAccount in [false, true]) {
      testWidgets(
        'account transition clears suppression through unknown $unknownAccount',
        (tester) async {
          final session = SortieWarningSession();
          final fixture = await _WarningOverlayFixture.create(
            mode: BattleWarningMode.confirm,
            warningSession: session,
          );
          addTearDown(fixture.dispose);
          await fixture.pump(tester);
          await _advance(tester, fixture);
          await _suppressSortie(tester);
          if (unknownAccount) {
            fixture.accountSession.reset();
            await tester.pump();
            expect(session.isMuted, isFalse);
            fixture.accountSession.selectMember(1001);
          } else {
            fixture.accountSession.selectMember(2002);
            fixture.state = fixture.state.copyWith(memberId: 2002);
          }
          await _advance(tester, fixture);

          expect(session.isMuted, isFalse);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(fixture.alerts.alerts, hasLength(2));
        },
      );
    }

    testWidgets('capture reset clears current sortie suppression', (
      tester,
    ) async {
      final session = SortieWarningSession();
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        warningSession: session,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      await _suppressSortie(tester);
      await fixture.captureController.invalidateSession();
      await tester.pumpAndSettle();

      expect(session.isMuted, isFalse);
      await _advance(tester, fixture);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(2));
    });

    testWidgets(
      'shared suppression survives removing and restoring the overlay',
      (tester) async {
        final session = SortieWarningSession();
        final fixture = await _WarningOverlayFixture.create(
          mode: BattleWarningMode.confirm,
          warningSession: session,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await _advance(tester, fixture);
        await _suppressSortie(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await fixture.pump(tester);
        await _advance(tester, fixture);

        expect(session.isMuted, isTrue);
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, hasLength(1));
      },
    );

    testWidgets('late safety result cannot revive a suppressed warning', (
      tester,
    ) async {
      final delayedState = Completer<GameState>();
      var checks = 0;
      late final _WarningOverlayFixture fixture;
      fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        loadSafetyState: () async {
          checks += 1;
          return checks == 1 ? fixture.state : delayedState.future;
        },
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);
      await _advance(tester, fixture);
      expect(find.byType(AlertDialog), findsOneWidget);
      await _suppressSortie(tester);
      delayedState.complete(fixture.state);
      await tester.pumpAndSettle();
      await _advance(tester, fixture);

      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));
    });

    testWidgets('port cancels a delayed safety result', (tester) async {
      final delayedState = Completer<GameState>();
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        loadSafetyState: () => delayedState.future,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final oldState = fixture.state;
      await _advance(tester, fixture);
      await fixture.publishEvent(
        tester,
        kcsapiEvent('/kcsapi/api_port/port', const {}),
      );
      delayedState.complete(oldState);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, isEmpty);
    });

    testWidgets(
      'new sortie cannot use a delayed result from the previous sortie',
      (tester) async {
        final delayedState = Completer<GameState>();
        var checks = 0;
        late final _WarningOverlayFixture fixture;
        fixture = await _WarningOverlayFixture.create(
          mode: BattleWarningMode.confirm,
          loadSafetyState: () async {
            checks += 1;
            return checks == 1
                ? delayedState.future
                : _sortieState(main: [_ownedShip(101), _ownedShip(102)]);
          },
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        final previousState = fixture.state;
        await _advance(tester, fixture);
        await fixture.publishEvent(
          tester,
          kcsapiEvent(
            '/kcsapi/api_req_map/start',
            const {},
            requestParams: const {'api_deck_id': 1},
          ),
        );
        delayedState.complete(previousState);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, isEmpty);
      },
    );
  });

  for (final width in [320.0, 375.0]) {
    testWidgets('long warnings fit a ${width.toInt()} pixel viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
        initialState: _equipmentState(
          main: [
            _ownedShip(101),
            for (var shipId = 102; shipId < 108; shipId += 1)
              _ownedShip(shipId, currentHp: 2, slotIds: [7999]),
          ],
          escort: [
            _ownedShip(201),
            for (var shipId = 202; shipId < 208; shipId += 1)
              _ownedShip(shipId, currentHp: 2, slotIds: [7999]),
          ],
          names: {
            for (final shipId in [
              102,
              103,
              104,
              105,
              106,
              107,
              202,
              203,
              204,
              205,
              206,
              207,
            ])
              shipId: '非常长的舰娘名称改二甲乙丙$shipId',
          },
        ),
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await _advance(tester, fixture);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.textContaining('非常长的舰娘名称改二甲乙丙207'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('确认了解').hitTestable(), findsOneWidget);
      expect(find.text('此次出击不再提醒').hitTestable(), findsOneWidget);
      await _suppressSortie(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final type in [
    CombinedFleetType.none,
    CombinedFleetType.surfaceTaskForce,
  ]) {
    testWidgets(
      'flagship alone does not show an advance dialog or vibration ${type.name}',
      (tester) async {
        final fixture = await _WarningOverlayFixture.create(
          mode: BattleWarningMode.confirm,
          initialState: _sortieState(
            main: [_ownedShip(101, currentHp: 2), _ownedShip(102)],
            combinedFleetType: type,
          ),
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        await fixture.publishEvent(
          tester,
          kcsapiEvent('/kcsapi/api_req_map/next', const {}),
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.alerts.alerts, isEmpty);
      },
    );
  }

  testWidgets('every successful advance recomputes and shows the warning', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishRiskResult(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.heavy,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('大破安全警告'), findsOneWidget);
    expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
    expect(find.text('已在大破状态下选择进击！请立即停止后续操作，避免进入下一场战斗。'), findsOneWidget);
    expect(find.text('确认了解'), findsOneWidget);
    await tester.tap(find.text('确认了解'));
    await tester.pumpAndSettle();

    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.heavy,
      BattleDamageAlertSeverity.heavy,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('confirmed retreat does not hide another heavy ship', (
    tester,
  ) async {
    final retreatState = _sortieState(
      main: <OwnedShip>[_ownedShip(101)],
      escort: <OwnedShip>[
        _ownedShip(201),
        _ownedShip(202, currentHp: 2),
        _ownedShip(203, currentHp: 3),
      ],
      combinedFleetType: CombinedFleetType.carrierTaskForce,
      pendingEscapeShipIds: const <int>[202],
    );
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
      initialState: retreatState,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent(
        '/kcsapi/api_req_sortie/goback_port',
        const <String, Object?>{},
      ),
    );
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.state.combatState.escapedShipIds, const <int>{202});
    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.heavy,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('returned port state suppresses a later stray advance event', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishRiskResult(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_port/port', const <String, Object?>{}),
    );
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('failed advance is ignored and a successful retry recomputes', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishRiskResult(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent(
        '/kcsapi/api_req_map/next',
        const <String, Object?>{},
        apiResult: 0,
      ),
    );

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);

    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.heavy,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('enabling warning applies to the next advance without a cache', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.off,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishRiskResult(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);

    await fixture.settingsController.setBattleWarningMode(
      BattleWarningMode.confirm,
    );
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.heavy,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('map start performs the same current-state safety check', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent(
        '/kcsapi/api_req_map/start',
        const <String, Object?>{},
        requestParams: const <String, Object?>{'api_deck_id': 1},
      ),
    );

    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.heavy,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('advance waits for the settled safety state before deciding', (
    tester,
  ) async {
    final settledState = Completer<GameState>();
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
      loadSafetyState: () => settledState.future,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);

    settledState.complete(fixture.state);
    await tester.pump();
    await tester.pump();

    expect(fixture.alerts.alerts, <BattleDamageAlertSeverity>[
      BattleDamageAlertSeverity.heavy,
    ]);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('account round trip cancels a delayed advance safety result', (
    tester,
  ) async {
    final settledState = Completer<GameState>();
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
      loadSafetyState: () => settledState.future,
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const {}),
    );

    fixture.accountSession.selectMember(2002);
    fixture.accountSession.selectMember(1001);
    settledState.complete(fixture.state);
    await tester.pumpAndSettle();

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('capture reset cancels a delayed advance safety result', (
    tester,
  ) async {
    final settledState = Completer<GameState>();
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
      loadSafetyState: () => settledState.future,
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const {}),
    );

    await fixture.captureController.invalidateSession();
    settledState.complete(fixture.state);
    await tester.pumpAndSettle();

    expect(fixture.captureController.latestEvent, isNull);
    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'account switch closes old warnings and permits current warnings',
    (tester) async {
      final fixture = await _WarningOverlayFixture.create(
        mode: BattleWarningMode.confirm,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await fixture.publishEvent(
        tester,
        kcsapiEvent('/kcsapi/api_req_map/next', const {}),
      );
      expect(find.byType(AlertDialog), findsOneWidget);

      fixture.accountSession.selectMember(2002);
      fixture.state = fixture.state.copyWith(memberId: 2002);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.alerts.alerts, hasLength(1));

      await fixture.publishEvent(
        tester,
        kcsapiEvent('/kcsapi/api_req_map/next', const {}),
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(2));
      fixture.accountSession.reset();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('unknown account and mismatched safety state do not warn', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    fixture.accountSession.reset();
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const {}),
    );
    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);

    fixture.accountSession.selectMember(2002);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const {}),
    );
    expect(fixture.state.memberId, 1001);
    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('warning uses heavy filter while keeping dialog independent', (
    tester,
  ) async {
    final fixture = await _WarningOverlayFixture.create(
      mode: BattleWarningMode.confirm,
      vibrationFilter: DamageVibrationFilter.moderateOnly,
    );
    addTearDown(fixture.dispose);

    await fixture.pump(tester);
    await fixture.publishRiskResult(tester);
    await fixture.publishEvent(
      tester,
      kcsapiEvent('/kcsapi/api_req_map/next', const <String, Object?>{}),
    );

    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'production queue order warns without waiting for an unrelated consumer',
    (tester) async {
      const queueTimeout = Duration(seconds: 1);
      final accountSession = AccountSession();
      final expirationTimerDisabled = GameStateController.disableTimerForTest;
      late final GameStateController gameStateController;
      try {
        GameStateController.disableTimerForTest = true;
        gameStateController = GameStateController(
          accountSession: accountSession,
        );
      } finally {
        GameStateController.disableTimerForTest = expirationTimerDisabled;
      }
      await gameStateController.initialize().timeout(queueTimeout);
      final battleController = BattleController(
        accountSession: accountSession,
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        predictionExecutor: const _InlinePredictionExecutor(),
      );
      final unrelatedConsumer = _BlockingGameApiConsumer();
      final pipeline = GameApiEventPipeline(
        decodeEnvelope: (body) async =>
            Map<String, Object?>.from(jsonDecode(body) as Map),
        consumers: <GameApiEventConsumer>[
          accountSession,
          gameStateController,
          battleController,
          unrelatedConsumer,
        ],
      );
      final captureController = GameCaptureController(
        onAcceptedEvent: pipeline.add,
      );
      final capturePort = _FakeGameCapturePort();
      await captureController.attach(capturePort, enabled: true);
      final settingsController = await SafetySettingsController.load(
        MemorySafetySettingsStore(),
      );
      await settingsController.setBattleWarningMode(BattleWarningMode.confirm);
      final alerts = _RecordingDamageAlertPort();
      addTearDown(() {
        unrelatedConsumer.release();
        captureController.dispose();
        battleController.dispose();
        gameStateController.dispose();
        capturePort.dispose();
        settingsController.dispose();
        accountSession.dispose();
      });

      capturePort.add(start2Event);
      await pipeline.dispatchIdle.timeout(queueTimeout);
      await gameStateController.idle.timeout(queueTimeout);
      final portData =
          (jsonDecode(portEvent.responseBody) as Map)['api_data'] as Map;
      capturePort.add(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          ...Map<String, Object?>.from(portData),
          'api_basic': <String, Object?>{
            ...Map<String, Object?>.from(portData['api_basic'] as Map),
            'api_member_id': 1001,
          },
        }, sequence: 2),
      );
      await pipeline.dispatchIdle.timeout(queueTimeout);
      await gameStateController.idle.timeout(queueTimeout);
      await battleController.idle.timeout(queueTimeout);
      expect(accountSession.current.memberId, 1001);
      expect(gameStateController.state.memberId, 1001);

      await tester.pumpWidget(
        MaterialApp(
          home: BattleResultWarningOverlay(
            accountSession: accountSession,
            gameCaptureController: captureController,
            loadSafetyState: () async {
              await pipeline.dispatchIdle;
              await battleController.idle;
              await gameStateController.idle;
              return gameStateController.state;
            },
            safetySettingsController: settingsController,
            damageAlertPort: alerts,
            child: const SizedBox.expand(),
          ),
        ),
      );

      capturePort.add(mapStartEvent);
      await pipeline.dispatchIdle.timeout(queueTimeout);
      await battleController.idle.timeout(queueTimeout);
      await gameStateController.idle.timeout(queueTimeout);

      capturePort.add(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[28, 8],
          'api_f_maxhps': <int>[30, 15],
          'api_e_nowhps': <int>[20],
          'api_e_maxhps': <int>[20],
          'api_ship_ke': <int>[501],
          'api_hougeki1': <String, Object?>{
            'api_at_eflag': <int>[1],
            'api_at_list': <int>[0],
            'api_df_list': <Object?>[
              <int>[1],
            ],
            'api_damage': <Object?>[
              <num>[6],
            ],
          },
        }, sequence: 21),
      );
      await pipeline.dispatchIdle.timeout(queueTimeout);
      await battleController.idle.timeout(queueTimeout);
      await gameStateController.idle.timeout(queueTimeout);
      expect(gameStateController.state.ships[9002]!.currentHp, 2);

      capturePort.add(battleResultEvent);
      capturePort.add(
        kcsapiEvent('/kcsapi/api_req_map/next', <String, Object?>{
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 2,
        }, sequence: 23),
      );
      await pipeline.dispatchIdle.timeout(queueTimeout);
      await battleController.idle.timeout(queueTimeout);
      await gameStateController.idle.timeout(queueTimeout);
      await tester.pump();
      await tester.pump();

      expect(unrelatedConsumer.released, isFalse);
      expect(alerts.alerts, <BattleDamageAlertSeverity>[
        BattleDamageAlertSeverity.heavy,
      ]);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );
}

final class _WarningOverlayFixture {
  _WarningOverlayFixture({
    required this.captureController,
    required this.capturePort,
    required this.battleController,
    required this.settingsController,
    required this.alerts,
    required this.state,
    required this.loadSafetyState,
    required this.accountSession,
    required this.damageControlStateTrusted,
    this.warningSession,
  });

  final GameCaptureController captureController;
  final _FakeGameCapturePort capturePort;
  final BattleController battleController;
  final SafetySettingsController settingsController;
  final _RecordingDamageAlertPort alerts;
  final GameStateReducer reducer = GameStateReducer();
  GameState state;
  final Future<GameState> Function() loadSafetyState;
  final AccountSession accountSession;
  final bool Function()? damageControlStateTrusted;
  final SortieWarningSession? warningSession;
  int _eventSequence = 1000;

  static Future<_WarningOverlayFixture> create({
    required BattleWarningMode mode,
    DamageVibrationFilter vibrationFilter = DamageVibrationFilter.all,
    GameState? initialState,
    Future<GameState> Function()? loadSafetyState,
    bool Function()? damageControlStateTrusted = _trustedDamageControlState,
    SortieWarningSession? warningSession,
  }) async {
    var state =
        initialState ??
        _sortieState(
          main: <OwnedShip>[_ownedShip(101), _ownedShip(102, currentHp: 2)],
        );
    final battleController = BattleController(
      gameState: () => state,
      predictionExecutor: const _InlinePredictionExecutor(),
    );
    final captureController = GameCaptureController();
    final capturePort = _FakeGameCapturePort();
    await captureController.attach(capturePort, enabled: true);
    final settingsController = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    await settingsController.setBattleWarningMode(mode);
    await settingsController.setDamageVibrationFilter(vibrationFilter);
    late final _WarningOverlayFixture fixture;
    fixture = _WarningOverlayFixture(
      captureController: captureController,
      capturePort: capturePort,
      battleController: battleController,
      settingsController: settingsController,
      alerts: _RecordingDamageAlertPort(),
      state: state,
      loadSafetyState: loadSafetyState ?? () async => fixture.state,
      accountSession: AccountSession(initialMemberId: state.memberId),
      damageControlStateTrusted: damageControlStateTrusted,
      warningSession: warningSession,
    );
    return fixture;
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BattleResultWarningOverlay(
        accountSession: accountSession,
        gameCaptureController: captureController,
        loadSafetyState: loadSafetyState,
        safetySettingsController: settingsController,
        damageAlertPort: alerts,
        damageControlStateTrusted: damageControlStateTrusted,
        warningSession: warningSession,
        child: const SizedBox.expand(),
      ),
    ),
  );

  Future<void> publishRiskResult(WidgetTester tester) async {
    battleController
      ..accept(mapStartEvent)
      ..accept(
        kcsapiEvent('/kcsapi/api_req_sortie/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[30, 15],
          'api_f_maxhps': <int>[30, 15],
          'api_e_nowhps': <int>[20],
          'api_e_maxhps': <int>[20],
          'api_ship_ke': <int>[501],
          'api_hougeki1': <String, Object?>{
            'api_at_eflag': <int>[1],
            'api_at_list': <int>[0],
            'api_df_list': <Object?>[
              <int>[0],
            ],
            'api_damage': <Object?>[
              <num>[25],
            ],
          },
        }, sequence: 801),
      )
      ..accept(battleResultEvent);
    await battleController.idle;

    capturePort.add(battleResultEvent);
    await tester.pump();
    await tester.pump();
  }

  Future<void> publishEvent(WidgetTester tester, CapturedApiEvent event) async {
    if (event.apiResult == 1) {
      if (event.path == '/kcsapi/api_port/port') {
        state = state.copyWith(combatState: CombatState.empty);
      } else if (event.path == '/kcsapi/api_req_sortie/goback_port' ||
          event.path == '/kcsapi/api_req_combined_battle/goback_port' ||
          event.path == '/kcsapi/api_req_map/start') {
        state = reducer.reduce(state, event);
      }
    }
    capturePort.add(
      CapturedApiEvent(
        method: event.method,
        path: event.path,
        requestParams: event.requestParams,
        responseBody: event.responseBody,
        statusCode: event.statusCode,
        source: event.source,
        sourceOrigin: event.sourceOrigin,
        capturedAt: event.capturedAt,
        sequence: ++_eventSequence,
        responseByteLength: event.responseByteLength,
        decodedEnvelope: event.decodedEnvelope,
        captureSessionId: event.captureSessionId,
        captureDocumentId: event.captureDocumentId,
        captureDocumentStartedAtEpochMs: event.captureDocumentStartedAtEpochMs,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void dispose() {
    battleController.dispose();
    captureController.dispose();
    capturePort.dispose();
    settingsController.dispose();
    accountSession.dispose();
  }
}

final class _RecordingDamageAlertPort
    implements BattleDamageAlertPort, CancellableBattleDamageAlertPort {
  final List<BattleDamageAlertSeverity> alerts = <BattleDamageAlertSeverity>[];
  int cancellations = 0;

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {
    alerts.add(severity);
  }

  @override
  Future<void> cancel() async {
    cancellations += 1;
  }
}

final class _InlinePredictionExecutor implements BattlePredictionExecutor {
  const _InlinePredictionExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async =>
      (engine: engine, prediction: engine.append(path: path, data: data));
}

final class _BlockingGameApiConsumer implements GameApiEventConsumer {
  final Completer<void> _idle = Completer<void>();

  bool get released => _idle.isCompleted;

  @override
  void accept(CapturedApiEvent event) {}

  @override
  Future<void> get idle => _idle.future;

  @override
  bool supportsPath(String path) => true;

  void release() {
    if (!_idle.isCompleted) _idle.complete();
  }
}

final class _FakeGameCapturePort implements GameCapturePort {
  final StreamController<CapturedApiEvent> _events =
      StreamController<CapturedApiEvent>.broadcast(sync: true);

  @override
  Stream<CapturedApiEvent> get events => _events.stream;

  void add(CapturedApiEvent event) => _events.add(event);

  @override
  Future<void> configure({
    required bool enabled,
    required String script,
  }) async {}

  @override
  Future<bool> isSupported() async => true;

  @override
  void dispose() => unawaited(_events.close());
}
