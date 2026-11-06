import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';

import 'damage_control_briefing_sync_test.dart'
    show apiEvent, createSortieState, mapData;

void main() {
  for (final settle in [false, true]) {
    testWidgets(
      '${settle ? 'Settlement' : 'Immediate'} fleet sync keeps live forecast '
      'and both warning prompts current',
      (tester) async {
        final fixture = await _PipelineSmokeFixture.create(settle: settle);
        addTearDown(fixture.dispose);
        await fixture.settings.setAdvanceWarningTimings(
          AdvanceWarningTimingSettings.battleAndAdvance,
        );
        await fixture.pump(tester, showLiveBattle: true);
        await fixture.start(tester);

        await fixture.fight(tester, openingHp: 100, damage: 100);
        expect(find.textContaining('20 / 100'), findsOneWidget);
        expect(
          fixture.state.fleetDisplayState.ships[1002]!.currentHp,
          settle ? 100 : 20,
        );
        expect(
          fixture.state.fleetDisplayState.slotItems.containsKey(501),
          settle,
        );

        await fixture.publish(
          tester,
          '/kcsapi/api_req_battle_midnight/battle',
          {
            'api_hougeki': _battleData(
              openingHp: 20,
              damage: 5,
            )['api_hougeki1'],
          },
        );
        expect(find.textContaining('15 / 100'), findsOneWidget);
        expect(
          fixture.state.fleetDisplayState.ships[1002]!.currentHp,
          settle ? 100 : 15,
        );

        await fixture.publish(tester, '/kcsapi/api_req_sortie/battleresult', {
          'api_win_rank': 'B',
          'api_mvp': 1,
        });
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('携带：应急修理女神 ×1'), findsOneWidget);
        expect(fixture.state.fleetDisplayState.ships[1002]!.currentHp, 15);
        expect(
          fixture.state.fleetDisplayState.slotItems.containsKey(501),
          isFalse,
        );
        await _acknowledge(tester);

        await fixture.advance(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('携带：应急修理女神 ×1'), findsOneWidget);
        await _acknowledge(tester);
      },
    );
  }

  testWidgets(
    'production pipeline consumes both damage controls, repeats warnings, and resets sortie mute at port',
    (tester) async {
      final fixture = await _PipelineSmokeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);

      await fixture.start(tester);
      expect(fixture.battle.isDamageControlStateTrusted, isTrue);
      expect(find.byType(AlertDialog), findsNothing);

      await fixture.fight(tester, openingHp: 100, damage: 100);
      expect(fixture.wingman.currentHp, 20);
      expect(fixture.wingman.slotIds, <int>[-1]);
      expect(fixture.wingman.extraSlotId, 502);
      expect(fixture.state.state.slotItems.containsKey(501), isFalse);
      expect(fixture.state.state.slotItems[502]?.masterSlotItemId, 43);
      expect(fixture.battle.current!.friendMain[1].currentHp, 20);
      expect(fixture.writebacks.damageControls, greaterThan(0));

      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('吹雪'), findsOneWidget);
      expect(find.text('携带：应急修理女神 ×1'), findsOneWidget);
      expect(find.text('大破舰娘已携带损管，请确认剩余装备。'), findsOneWidget);

      await _acknowledge(tester);
      expect(fixture.battle.warningSession.isMuted, isFalse);
      final afterConfirmation = fixture.alerts.alerts.length;
      await fixture.advance(tester);
      expect(find.text('携带：应急修理女神 ×1'), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(afterConfirmation + 1));
      await _acknowledge(tester);

      await fixture.fight(tester, openingHp: 20, damage: 20);
      expect(fixture.wingman.currentHp, 100);
      expect(fixture.wingman.slotIds, <int>[-1]);
      expect(fixture.wingman.extraSlotId, -1);
      expect(fixture.state.state.slotItems, isEmpty);
      expect(fixture.battle.current!.friendMain[1].currentHp, 100);

      await fixture.advance(tester);
      expect(find.byType(AlertDialog), findsNothing);
      await fixture.fight(tester, openingHp: 100, damage: 80);
      expect(fixture.wingman.currentHp, 20);
      await fixture.advance(tester);
      expect(find.text('存在未携带损管的大破舰娘！'), findsOneWidget);
      expect(find.text('未携带损管'), findsOneWidget);
      expect(find.text('携带：应急修理女神 ×1'), findsNothing);
      expect(fixture.state.state.slotItems, isEmpty);
      expect(fixture.battle.isDamageControlStateTrusted, isTrue);

      await tester.tap(find.byKey(const Key('muteCurrentSortieWarning')));
      await tester.pumpAndSettle();
      expect(fixture.battle.warningSession.isMuted, isTrue);
      expect(fixture.alerts.cancellations, 1);
      expect(find.byType(AlertDialog), findsNothing);
      final mutedAlertCount = fixture.alerts.alerts.length;

      await fixture.advance(tester);
      await fixture.fight(tester, openingHp: 20, damage: 80, targetPosition: 0);
      expect(fixture.state.state.ships[1001]!.currentHp, 20);
      await fixture.advance(tester);
      expect(fixture.alerts.alerts, hasLength(mutedAlertCount));
      expect(find.byType(AlertDialog), findsNothing);

      await fixture.publish(tester, '/kcsapi/api_port/port', {
        'api_basic': <String, Object?>{'api_member_id': 1001},
        'api_ship': <Object?>[
          for (final ship in fixture.state.state.ships.values)
            <String, Object?>{
              'api_id': ship.id,
              'api_ship_id': ship.masterId,
              'api_lv': ship.level,
              'api_nowhp': ship.id == 1001 ? 100 : ship.currentHp,
              'api_maxhp': ship.maxHp,
              'api_slot': ship.slotIds,
              'api_slot_ex': ship.extraSlotId,
            },
        ],
      });
      expect(fixture.state.state.combatState.isActive, isFalse);
      expect(fixture.battle.warningSession.isActive, isFalse);
      expect(fixture.battle.warningSession.isMuted, isFalse);

      await fixture.start(tester);
      expect(fixture.battle.isDamageControlStateTrusted, isTrue);
      expect(find.text('未携带损管'), findsOneWidget);
      expect(fixture.alerts.alerts, hasLength(mutedAlertCount + 1));
      expect(fixture.state.lastError, isNull);
      expect(fixture.battle.lastError, isNull);
    },
  );

  testWidgets('practice packets never publish damage-control consumption', (
    tester,
  ) async {
    final fixture = await _PipelineSmokeFixture.create();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);

    await fixture.publish(
      tester,
      '/kcsapi/api_req_practice/battle',
      _battleData(openingHp: 100, damage: 100),
    );

    expect(fixture.battle.current!.context.practice, isTrue);
    expect(fixture.writebacks.damageControls, 0);
    expect(fixture.writebacks.hp, 0);
    expect(fixture.wingman.currentHp, 100);
    expect(fixture.wingman.slotIds, <int>[501]);
    expect(fixture.wingman.extraSlotId, 502);
    expect(
      fixture.state.state.slotItems.keys,
      unorderedEquals(<int>[501, 502]),
    );
    expect(fixture.alerts.alerts, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(fixture.battle.lastError, isNull);
  });

  testWidgets('attaching mid-sortie warns with unknown damage-control state', (
    tester,
  ) async {
    final fixture = await _PipelineSmokeFixture.create(
      wingmanHp: 20,
      active: true,
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);

    await fixture.advance(tester);

    expect(fixture.battle.isDamageControlStateTrusted, isFalse);
    expect(find.text('大破舰娘损管状态未知！'), findsOneWidget);
    expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
    expect(find.textContaining('携带：'), findsNothing);
    await _acknowledge(tester);
    await fixture.fight(tester, openingHp: 20, damage: 20);
    expect(fixture.writebacks.damageControls, 0);
    expect(fixture.writebacks.hp, 1);
    expect(fixture.wingman.currentHp, 1);
    expect(fixture.battle.isPredictionConfirmed, isFalse);
    expect(
      fixture.state.state.slotItems.keys,
      unorderedEquals(<int>[501, 502]),
    );
    await fixture.advance(tester);
    expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
  });

  testWidgets('a battle parse exception makes the next warning unknown', (
    tester,
  ) async {
    final fixture = await _PipelineSmokeFixture.create(wingmanHp: 20);
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await fixture.start(tester);
    expect(fixture.battle.isDamageControlStateTrusted, isTrue);
    expect(find.textContaining('携带：'), findsOneWidget);
    await _acknowledge(tester);

    await fixture.publish(
      tester,
      '/kcsapi/api_req_sortie/battle',
      const <Object?>[],
    );
    expect(fixture.battle.lastError, isNotNull);
    expect(fixture.battle.isDamageControlStateTrusted, isFalse);
    expect(fixture.writebacks.damageControls, 0);

    await fixture.advance(tester);
    expect(find.text('大破舰娘损管状态未知！'), findsOneWidget);
    expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
    expect(find.textContaining('携带：'), findsNothing);
    expect(fixture.wingman.currentHp, 20);
    expect(
      fixture.state.state.slotItems.keys,
      unorderedEquals(<int>[501, 502]),
    );
  });

  for (final gap in ['clear', 'invalidate', 'disable and re-enable']) {
    testWidgets('capture $gap requires unknown damage-control state', (
      tester,
    ) async {
      final fixture = await _PipelineSmokeFixture.create(wingmanHp: 20);
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      await fixture.start(tester);
      expect(fixture.battle.isDamageControlStateTrusted, isTrue);
      expect(find.textContaining('携带：'), findsOneWidget);
      await tester.tap(find.byKey(const Key('muteCurrentSortieWarning')));
      await tester.pumpAndSettle();
      expect(fixture.battle.warningSession.isMuted, isTrue);

      if (gap == 'clear') {
        fixture.capture.clearCapturedEvents();
      } else if (gap == 'invalidate') {
        await fixture.capture.invalidateSession();
      } else {
        await fixture.capture.configure(enabled: false);
        await fixture.fight(tester, openingHp: 20, damage: 20);
        expect(fixture.writebacks.damageControls, 0);
        await fixture.capture.configure(enabled: true);
      }
      expect(fixture.battle.warningSession.isMuted, isFalse);
      await fixture.advance(tester);

      expect(find.textContaining('携带：'), findsNothing);
      expect(fixture.battle.isDamageControlStateTrusted, isFalse);
      expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
      expect(fixture.account.current.memberId, 1001);
      await _acknowledge(tester);

      await fixture.fight(tester, openingHp: 20, damage: 20);
      expect(fixture.writebacks.damageControls, 0);
      expect(fixture.writebacks.hp, 1);
      expect(fixture.wingman.currentHp, 1);
      expect(fixture.battle.isPredictionConfirmed, isFalse);
      expect(fixture.wingman.slotIds, <int>[501]);
      expect(fixture.wingman.extraSlotId, 502);
      expect(
        fixture.state.state.slotItems.keys,
        unorderedEquals(<int>[501, 502]),
      );
      await fixture.advance(tester);
      expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
      await _acknowledge(tester);

      await fixture.start(tester);
      expect(fixture.battle.isDamageControlStateTrusted, isFalse);
      expect(fixture.battle.warningSession.isMuted, isFalse);
      expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
      expect(find.textContaining('携带：'), findsNothing);
      await _acknowledge(tester);

      await fixture.refreshPort(tester);
      await fixture.start(tester);
      expect(fixture.battle.isDamageControlStateTrusted, isTrue);
      expect(find.text('携带：应急修理女神 ×1'), findsOneWidget);
      expect(find.textContaining('应急修理要员'), findsNothing);
    });
  }

  testWidgets('capture interruption cancels a queued old sortie start', (
    tester,
  ) async {
    final decoding = Completer<void>();
    final releaseDecode = Completer<void>();
    final fixture = await _PipelineSmokeFixture.create(
      wingmanHp: 20,
      backgroundThresholdBytes: 1,
      decodeEnvelope: (body) async {
        if (!decoding.isCompleted) decoding.complete();
        await releaseDecode.future;
        return Map<String, Object?>.from(jsonDecode(body) as Map);
      },
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);

    final pendingStart = fixture.start(tester);
    await tester.pump();
    expect(decoding.isCompleted, isTrue);
    fixture.capture.clearCapturedEvents();
    releaseDecode.complete();
    await pendingStart;

    expect(fixture.state.state.combatState.isActive, isFalse);
    expect(fixture.battle.isDamageControlStateTrusted, isFalse);
    expect(fixture.battle.warningSession.isActive, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(fixture.alerts.alerts, isEmpty);

    await fixture.start(tester);
    expect(fixture.battle.isDamageControlStateTrusted, isFalse);
    expect(find.text('损管状态未知，请核对游戏内装备'), findsOneWidget);
    expect(find.textContaining('携带：'), findsNothing);
    await _acknowledge(tester);

    await fixture.refreshPort(tester);
    await fixture.start(tester);
    expect(fixture.battle.isDamageControlStateTrusted, isTrue);
    expect(find.text('携带：应急修理女神 ×1'), findsOneWidget);
  });
}

Future<void> _acknowledge(WidgetTester tester) async {
  await tester.tap(find.text('确认了解'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
}

Map<String, Object?> _battleData({
  required int openingHp,
  required num damage,
  int targetPosition = 1,
}) => <String, Object?>{
  'api_deck_id': 1,
  'api_f_nowhps': <int>[-1, 100, openingHp],
  'api_f_maxhps': const <int>[-1, 100, 100],
  'api_e_nowhps': const <int>[-1, 20],
  'api_e_maxhps': const <int>[-1, 20],
  'api_ship_ke': const <int>[-1, 501],
  'api_hougeki1': <String, Object?>{
    'api_at_eflag': const <int>[1],
    'api_at_list': const <int>[0],
    'api_df_list': <Object?>[
      <int>[targetPosition],
    ],
    'api_damage': <Object?>[
      <num>[damage],
    ],
  },
};

final class _PipelineSmokeFixture {
  _PipelineSmokeFixture({
    required this.account,
    required this.state,
    required this.battle,
    required this.pipeline,
    required this.capture,
    required this.capturePort,
    required this.settings,
    required this.alerts,
    required this.writebacks,
  });

  final AccountSession account;
  final GameStateController state;
  final BattleController battle;
  final GameApiEventPipeline pipeline;
  final GameCaptureController capture;
  final _CapturePort capturePort;
  final SafetySettingsController settings;
  final _RecordingDamageAlertPort alerts;
  final _WritebackProbe writebacks;
  int _sequence = 0;
  int _node = 0;

  OwnedShip get wingman => state.state.ships[1002]!;

  static Future<_PipelineSmokeFixture> create({
    int wingmanHp = 100,
    bool active = false,
    bool settle = false,
    GameApiEnvelopeDecoder? decodeEnvelope,
    int backgroundThresholdBytes = 64 * 1024,
  }) async {
    final account = AccountSession(initialMemberId: 1001);
    final initialState =
        createSortieState(
          ships: <OwnedShip>[
            OwnedShip(
              id: 1001,
              masterId: 101,
              level: 50,
              currentHp: 100,
              maxHp: 100,
            ),
            OwnedShip(
              id: 1002,
              masterId: 102,
              level: 50,
              currentHp: wingmanHp,
              maxHp: 100,
              slotIds: const <int>[501],
              extraSlotId: 502,
            ),
          ],
          slotItems: const <OwnedSlotItem>[
            OwnedSlotItem(instanceId: 501, masterSlotItemId: 42),
            OwnedSlotItem(instanceId: 502, masterSlotItemId: 43),
          ],
        ).copyWith(
          memberId: 1001,
          hasEquipmentInventory: true,
          combatState: CombatState(
            isActive: active,
            sortieFleetId: 1,
            mapArea: 1,
            mapInfo: 1,
            currentNode: active ? 1 : 0,
          ),
        );
    final state = GameStateController(
      initialState: initialState,
      accountSession: account,
    );
    if (settle) state.setDeferFleetBattleDisplay(true);
    await state.initialize();
    final settings = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    final alerts = _RecordingDamageAlertPort();
    final writebacks = _WritebackProbe();
    final battle = BattleController(
      accountSession: account,
      gameState: () => state.state,
      waitForGameState: () => state.idle,
      onFriendlyHpUpdated: (hp, capturedAt) {
        writebacks.hp += 1;
        state.applyFriendlyBattleHp(hp, capturedAt);
      },
      onDamageControlConsumed: (consumed, capturedAt) {
        writebacks.damageControls += 1;
        state.applyDamageControlConsumption(consumed, capturedAt);
      },
      onFleetBattleDisplayStarted: state.beginFleetBattleDisplay,
      onFleetBattleDisplaySettled: state.settleFleetBattleDisplay,
      damageAlertPort: alerts,
      battleStatusEffectSettings: () => settings.battleStatusEffects,
      predictionExecutor: const ImmediateBattlePredictionExecutor(),
    );
    final pipeline = GameApiEventPipeline(
      consumers: <GameApiEventConsumer>[account, state, battle],
      decodeEnvelope: decodeEnvelope,
      backgroundThresholdBytes: backgroundThresholdBytes,
      settleGameState: () async {
        await state.idle;
        await battle.idle;
        await state.idle;
      },
    );
    final capture = GameCaptureController(
      onAcceptedEvent: pipeline.add,
      onCaptureInterrupted: () {
        pipeline.invalidateQueuedEvents();
        battle.invalidateCaptureContinuity();
      },
    );
    final capturePort = _CapturePort();
    await capture.attach(capturePort, enabled: true);
    return _PipelineSmokeFixture(
      account: account,
      state: state,
      battle: battle,
      pipeline: pipeline,
      capture: capture,
      capturePort: capturePort,
      settings: settings,
      alerts: alerts,
      writebacks: writebacks,
    );
  }

  Future<void> pump(WidgetTester tester, {bool showLiveBattle = false}) =>
      tester.pumpWidget(
        MaterialApp(
          locale: showLiveBattle ? const Locale('zh') : null,
          localizationsDelegates: showLiveBattle
              ? AppLocalizations.localizationsDelegates
              : null,
          supportedLocales: showLiveBattle
              ? AppLocalizations.supportedLocales
              : const [Locale('en')],
          home: BattleResultWarningOverlay(
            accountSession: account,
            gameCaptureController: capture,
            loadSafetyState: () async {
              await pipeline.dispatchIdle;
              await battle.idle;
              await state.idle;
              return state.state;
            },
            safetySettingsController: settings,
            damageAlertPort: alerts,
            warningSession: battle.warningSession,
            damageControlStateTrusted: () => battle.isDamageControlStateTrusted,
            child: showLiveBattle
                ? Scaffold(
                    body: SingleChildScrollView(
                      child: LiveBattleCard(
                        controller: battle,
                        collapsed: false,
                        onToggleCollapse: () {},
                        damagePulseMode: DamagePulseFilter.off,
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      );

  Future<void> start(WidgetTester tester) {
    _node = 1;
    return publish(
      tester,
      '/kcsapi/api_req_map/start',
      <String, Object?>{...mapData, 'api_no': _node},
      requestParams: const <String, Object?>{'api_deck_id': '1'},
    );
  }

  Future<void> advance(WidgetTester tester) => publish(
    tester,
    '/kcsapi/api_req_map/next',
    <String, Object?>{...mapData, 'api_no': ++_node},
  );

  Future<void> refreshPort(WidgetTester tester) =>
      publish(tester, '/kcsapi/api_port/port', <String, Object?>{
        'api_basic': <String, Object?>{'api_member_id': 1001},
        'api_ship': <Object?>[
          for (final ship in state.state.ships.values)
            <String, Object?>{
              'api_id': ship.id,
              'api_ship_id': ship.masterId,
              'api_lv': ship.level,
              'api_nowhp': ship.currentHp,
              'api_maxhp': ship.maxHp,
              'api_slot': ship.id == 1002 ? <int>[-1] : ship.slotIds,
              'api_slot_ex': ship.extraSlotId,
            },
        ],
      });

  Future<void> fight(
    WidgetTester tester, {
    required int openingHp,
    required num damage,
    int targetPosition = 1,
  }) => publish(
    tester,
    '/kcsapi/api_req_sortie/battle',
    _battleData(
      openingHp: openingHp,
      damage: damage,
      targetPosition: targetPosition,
    ),
  );

  Future<void> publish(
    WidgetTester tester,
    String path,
    Object? data, {
    Map<String, Object?> requestParams = const <String, Object?>{},
  }) async {
    capturePort.add(
      apiEvent(path, data, sequence: ++_sequence, requestParams: requestParams),
    );
    await pipeline.idle;
    await tester.pumpAndSettle();
  }

  void dispose() {
    capture.dispose();
    capturePort.dispose();
    battle.dispose();
    state.dispose();
    settings.dispose();
    account.dispose();
  }
}

final class _WritebackProbe {
  int hp = 0;
  int damageControls = 0;
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

final class _CapturePort implements GameCapturePort {
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
