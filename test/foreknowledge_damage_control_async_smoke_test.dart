import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';

import 'damage_control_briefing_sync_test.dart'
    show apiEvent, createSortieState, lethalBattle, mapData;

void main() {
  late bool previousTimerSetting;
  setUp(() {
    previousTimerSetting = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
  });
  tearDown(() {
    GameStateController.disableTimerForTest = previousTimerSetting;
  });

  test(
    'late isolate damage-control use cannot revive a switched account or consume its same-id equipment',
    () async {
      final executor = _GatedIsolateExecutor()..delayNext = true;
      final harness = await _Harness.create(
        executor: executor,
        withAccountSession: true,
      );
      await harness.start();
      harness.battle.accept(
        apiEvent(_dayPath, lethalBattle(30, openingHp: 30), sequence: 2),
      );
      final delayed = await executor.started.future;
      expect(delayed.prediction.issues, isEmpty);
      expect(
        delayed.prediction.friendMain.single.damageControlUsedThisBattle,
        <int>[42],
      );
      expect(
        harness.battle.current!.displayStage,
        BattleDisplayStage.navigation,
      );
      harness.expectEquipment(intact: true);

      harness.account!.selectMember(2);
      expect(harness.battle.current, isNull);
      expect(harness.game.state.ships, isEmpty);
      // Give the new account an active sortie and the same instance IDs. A
      // leaked old callback would otherwise consume this account's equipment.
      harness.game.accept(
        apiEvent(
          '/kcsapi/api_get_member/require_info',
          _inventoryData(memberId: 2),
          sequence: 3,
        ),
      );
      harness.game.accept(harness.startEvent(sequence: 4));
      await harness.game.idle;
      expect(harness.game.state.memberId, 2);
      expect(harness.game.state.combatState.isActive, isTrue);
      harness.expectEquipment(intact: true);
      final newAccountState = harness.game.state;

      executor.release.complete();
      await harness.idle();

      expect(harness.battle.current, isNull);
      expect(harness.battle.session, isNull);
      expect(harness.game.state, same(newAccountState));
      harness.expectEquipment(intact: true);
      expect(harness.game.state.ships[1001]!.currentHp, 30);
      expect(harness.battle.lastError, isNull);
      expect(harness.game.lastError, isNull);
    },
  );

  test(
    'capture interruption discards late night use while retaining confirmed day use and inventory',
    () async {
      final executor = _GatedIsolateExecutor();
      final harness = await _Harness.create(executor: executor);
      await harness.start();
      await harness.dayBattle();
      final day = harness.battle.current!;
      expect(day.friendMain.single.damageControlUsedThisBattle, <int>[42]);
      harness.expectEquipment(intact: false);

      executor.delayNext = true;
      harness.battle.accept(apiEvent(_nightPath, _nightDamage(6), sequence: 3));
      final delayed = await executor.started.future;
      expect(delayed.prediction.issues, isEmpty);
      expect(
        delayed.prediction.friendMain.single.damageControlUsedThisBattle,
        <int>[42, 43],
      );
      final beforeInterruption = harness.game.state;
      harness.game.interruptCaptureContinuity();
      harness.battle.invalidateCaptureContinuity();
      expect(harness.battle.current, same(day));
      expect(harness.battle.isPredictionConfirmed, isFalse);

      executor.release.complete();
      await harness.idle();

      expect(harness.battle.current, same(day));
      expect(
        harness.battle.current!.friendMain.single.damageControlUsedThisBattle,
        <int>[42],
      );
      expect(harness.game.state, same(beforeInterruption));
      harness.expectEquipment(intact: false);
      expect(harness.game.state.ships[1001]!.currentHp, 6);
      expect(harness.battle.isPredictionConfirmed, isFalse);
      expect(harness.battle.lastError, isNull);
      expect(harness.game.lastError, isNull);
    },
  );

  test(
    'failed port preserves current use and successful port clears it after real isolate consumption',
    () async {
      final harness = await _Harness.create();
      await harness.start();
      await harness.dayBattle();
      final used = harness.battle.current!;
      expect(used.friendMain.single.damageControlUsedThisBattle, <int>[42]);
      harness.expectEquipment(intact: false);

      final failedPort = CapturedApiEvent(
        path: '/kcsapi/api_port/port',
        responseBody: jsonEncode(<String, Object?>{
          'api_result': 0,
          'api_data': _inventoryData(),
        }),
        source: CaptureSource.xhr,
        capturedAt: DateTime.utc(2026, 10, 26),
        sequence: 3,
      );
      harness.game.accept(failedPort);
      harness.battle.accept(failedPort);
      await harness.idle();
      expect(harness.battle.current, same(used));
      expect(
        harness.battle.current!.friendMain.single.damageControlUsedThisBattle,
        <int>[42],
      );
      harness.expectEquipment(intact: false);

      final port = apiEvent(
        '/kcsapi/api_port/port',
        _inventoryData(consumed: true),
        sequence: 4,
      );
      harness.game.accept(port);
      harness.battle.accept(port);
      await harness.idle();
      expect(harness.battle.current, isNull);
      expect(harness.battle.session, isNull);
      expect(harness.game.state.combatState.isActive, isFalse);
      harness.expectEquipment(intact: false);
      expect(harness.battle.lastError, isNull);
      expect(harness.game.lastError, isNull);
    },
  );
}

const _dayPath = '/kcsapi/api_req_sortie/battle';
const _nightPath = '/kcsapi/api_req_battle_midnight/battle';

Map<String, Object?> _nightDamage(int damage) => <String, Object?>{
  'api_hougeki': <String, Object?>{
    'api_at_eflag': <int>[1],
    'api_at_list': <int>[0],
    'api_df_list': <Object?>[
      <int>[0],
    ],
    'api_damage': <Object?>[
      <int>[damage],
    ],
  },
};

Map<String, Object?> _inventoryData({
  int memberId = 0,
  bool consumed = false,
}) => <String, Object?>{
  if (memberId > 0) 'api_basic': <String, Object?>{'api_member_id': memberId},
  'api_ship': <Object?>[
    <String, Object?>{
      'api_id': 1001,
      'api_ship_id': 101,
      'api_lv': 50,
      'api_nowhp': consumed ? 6 : 30,
      'api_maxhp': 30,
      'api_slot': <int>[consumed ? -1 : 501],
      'api_slot_ex': 502,
    },
  ],
  'api_slot_item': <Object?>[
    if (!consumed) <String, Object?>{'api_id': 501, 'api_slotitem_id': 42},
    <String, Object?>{'api_id': 502, 'api_slotitem_id': 43},
  ],
  'api_deck': <Object?>[
    <String, Object?>{
      'api_id': 1,
      'api_name': '第一舰队',
      'api_ship': <int>[1001],
    },
  ],
};

final class _Harness {
  _Harness(this.game, this.battle, this.account);

  final GameStateController game;
  final BattleController battle;
  final AccountSession? account;

  static Future<_Harness> create({
    BattlePredictionExecutor executor = const IsolateBattlePredictionExecutor(),
    bool withAccountSession = false,
  }) async {
    final account = withAccountSession
        ? AccountSession(initialMemberId: 1)
        : null;
    final game = GameStateController(
      initialState: createSortieState(
        ships: const <OwnedShip>[
          OwnedShip(
            id: 1001,
            masterId: 101,
            level: 50,
            currentHp: 30,
            maxHp: 30,
            slotIds: <int>[501],
            extraSlotId: 502,
          ),
        ],
        slotItems: const <OwnedSlotItem>[
          OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
          OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
        ],
      ).copyWith(memberId: account?.current.memberId ?? 0),
      accountSession: account,
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduleMicrotask,
      ),
    );
    await game.initialize();
    final battle = BattleController(
      gameState: () => game.state,
      waitForGameState: () => game.idle,
      onFriendlyHpUpdated: game.applyFriendlyBattleHp,
      onDamageControlConsumed: game.applyDamageControlConsumption,
      predictionExecutor: executor,
      accountSession: account,
      captureNotifications: FrameNotificationCoalescer(
        scheduleFrame: scheduleMicrotask,
      ),
    );
    final harness = _Harness(game, battle, account);
    addTearDown(() async {
      if (executor is _GatedIsolateExecutor && !executor.release.isCompleted) {
        executor.release.complete();
      }
      await harness.idle();
      battle.dispose();
      game.dispose();
      account?.dispose();
    });
    return harness;
  }

  CapturedApiEvent startEvent({int sequence = 1}) => apiEvent(
    '/kcsapi/api_req_map/start',
    mapData,
    sequence: sequence,
    requestParams: const <String, Object?>{'api_deck_id': '1'},
  );

  Future<void> start() async {
    final event = startEvent();
    game.accept(event);
    battle.accept(event);
    await idle();
    expect(battle.isDamageControlStateTrusted, isTrue);
  }

  Future<void> dayBattle() async {
    battle.accept(
      apiEvent(_dayPath, lethalBattle(30, openingHp: 30), sequence: 2),
    );
    await idle();
    expect(battle.isPredictionConfirmed, isTrue);
  }

  Future<void> idle() async {
    await battle.idle;
    await game.idle;
  }

  void expectEquipment({required bool intact}) {
    expect(game.state.ships[1001]!.slotIds, <int>[intact ? 501 : -1]);
    expect(game.state.slotItems.containsKey(501), intact);
    expect(game.state.ships[1001]!.extraSlotId, 502);
    expect(game.state.slotItems[502]!.masterSlotItemId, 43);
  }
}

final class _GatedIsolateExecutor implements BattlePredictionExecutor {
  bool delayNext = false;
  final started = Completer<BattlePredictionAppendResult>();
  final release = Completer<void>();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async {
    final shouldDelay = delayNext;
    delayNext = false;
    final result = await const IsolateBattlePredictionExecutor().append(
      engine: engine,
      path: path,
      data: data,
    );
    if (shouldDelay) {
      started.complete(result);
      await release.future;
    }
    return result;
  }
}
