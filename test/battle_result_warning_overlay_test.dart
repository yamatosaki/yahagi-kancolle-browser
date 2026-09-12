import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_damage_alert.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/capture/battle_result_warning_overlay.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
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

OwnedShip _ownedShip(int id, {int currentHp = 20, int maxHp = 20}) => OwnedShip(
  id: id,
  masterId: id,
  level: 99,
  currentHp: currentHp,
  maxHp: maxHp,
);

GameState _sortieState({
  required List<OwnedShip> main,
  List<OwnedShip> escort = const <OwnedShip>[],
  CombinedFleetType combinedFleetType = CombinedFleetType.none,
  Set<int> escapedShipIds = const <int>{},
  List<int> pendingEscapeShipIds = const <int>[],
  bool isActive = true,
}) {
  final ships = <int, OwnedShip>{
    for (final ship in <OwnedShip>[...main, ...escort]) ship.id: ship,
  };
  return GameState(
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
    expect(find.text('出击舰队中存在大破舰娘！'), findsOneWidget);
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
      final gameStateController = GameStateController();
      await gameStateController.initialize().timeout(queueTimeout);
      gameStateController
        ..accept(start2Event)
        ..accept(portEvent);
      await gameStateController.idle.timeout(queueTimeout);

      final battleController = BattleController(
        gameState: () => gameStateController.state,
        waitForGameState: () => gameStateController.idle,
        onFriendlyHpUpdated: gameStateController.applyFriendlyBattleHp,
        predictionExecutor: const _InlinePredictionExecutor(),
      );
      final unrelatedConsumer = _BlockingGameApiConsumer();
      final pipeline = GameApiEventPipeline(
        consumers: <GameApiEventConsumer>[
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
      });

      await tester.pumpWidget(
        MaterialApp(
          home: BattleResultWarningOverlay(
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
        }, sequence: 901),
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
        }, sequence: 902),
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
  });

  final GameCaptureController captureController;
  final _FakeGameCapturePort capturePort;
  final BattleController battleController;
  final SafetySettingsController settingsController;
  final _RecordingDamageAlertPort alerts;
  final GameStateReducer reducer = GameStateReducer();
  GameState state;
  final Future<GameState> Function() loadSafetyState;

  static Future<_WarningOverlayFixture> create({
    required BattleWarningMode mode,
    DamageVibrationFilter vibrationFilter = DamageVibrationFilter.all,
    GameState? initialState,
    Future<GameState> Function()? loadSafetyState,
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
    );
    return fixture;
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BattleResultWarningOverlay(
        gameCaptureController: captureController,
        loadSafetyState: loadSafetyState,
        safetySettingsController: settingsController,
        damageAlertPort: alerts,
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
          event.path == '/kcsapi/api_req_combined_battle/goback_port') {
        state = reducer.reduce(state, event);
      }
    }
    capturePort.add(event);
    await tester.pump();
    await tester.pump();
  }

  void dispose() {
    battleController.dispose();
    captureController.dispose();
    capturePort.dispose();
    settingsController.dispose();
  }
}

final class _RecordingDamageAlertPort implements BattleDamageAlertPort {
  final List<BattleDamageAlertSeverity> alerts = <BattleDamageAlertSeverity>[];

  @override
  Future<void> alert(BattleDamageAlertSeverity severity) async {
    alerts.add(severity);
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
