import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notification/game_notification_coordinator.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_timer_anchor_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';
import 'game_notification_coordinator_test.dart' show FakeNotificationPort;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('startup notification state', () {
    late AccountSession session;
    late GameStateController game;
    late NotificationSettingsController settings;
    late FakeNotificationPort port;
    late GameNotificationCoordinator coordinator;
    late GameState state;
    final now = DateTime.utc(2026, 11, 26);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      session = AccountSession();
      game = GameStateController(accountSession: session);
      settings = NotificationSettingsController(
        store: const SharedPreferencesNotificationSettingsStore(),
      );
      await settings.initialize();
      port = FakeNotificationPort();
      state = const GameState();
      coordinator = GameNotificationCoordinator(
        gameStateController: game,
        settingsController: settings,
        notificationPort: port,
        accountSession: session,
        gameStateProvider: () => state,
        nowProvider: () => now,
      );
    });

    tearDown(() {
      coordinator.dispose();
      settings.dispose();
      game.dispose();
      session.dispose();
    });

    Future<void> settle() async {
      await coordinator.accountReady;
      await Future<void>.delayed(Duration.zero);
    }

    test('cold launch waits for authoritative game state', () async {
      coordinator.start();
      await settle();
      expect(port.latestSnapshot!.toMap()['awaitingInitialGameState'], isTrue);
      expect(port.latestSnapshot!.memberId, 0);

      session.accept(
        CapturedApiEvent(
          path: '/kcsapi/api_start2/getData',
          responseBody: '{"api_result":1,"api_data":{}}',
          source: CaptureSource.manual,
          capturedAt: now,
        ),
      );
      await settle();
      expect(port.latestSnapshot!.toMap()['awaitingInitialGameState'], isTrue);

      session.selectMember(1001);
      await settle();
      expect(port.latestSnapshot!.toMap()['awaitingInitialGameState'], isTrue);
      expect(port.latestSnapshot!.memberId, 1001);

      final deadline = now.add(const Duration(hours: 1));
      state = GameState(
        memberId: 1001,
        hasPortData: true,
        fleets: [
          Fleet(
            id: 2,
            name: 'A',
            shipIds: const [1],
            mission: FleetMission(
              state: 1,
              missionId: 1,
              completionTime: deadline,
            ),
          ),
        ],
      );
      game.notifyListeners();
      await settle();
      expect(port.latestSnapshot!.toMap()['awaitingInitialGameState'], isNull);
      expect(
        port.scheduledAlarms['expedition_2_complete']!.triggerTime,
        deadline,
      );
    });

    test('explicit session reset clears saved alarms even offline', () async {
      coordinator.start();
      await settle();
      session.reset();
      await settle();
      expect(port.latestSnapshot!.toMap()['awaitingInitialGameState'], isNull);
      expect(port.latestSnapshot!.presentation.enabled, isFalse);
    });

    test('turning off notifications clears saved alarms offline', () async {
      coordinator.start();
      await settle();
      await settings.setMaster(false);
      await settle();
      expect(port.latestSnapshot!.toMap()['awaitingInitialGameState'], isNull);
      expect(port.latestSnapshot!.presentation.enabled, isFalse);
    });
  });

  test(
    'switching accounts does not complete the previous account repair',
    () async {
      SharedPreferences.setMockInitialValues({});
      final game = GameStateController();
      final settings = NotificationSettingsController(
        store: const SharedPreferencesNotificationSettingsStore(),
      );
      await settings.initialize();
      final port = FakeNotificationPort();
      final now = DateTime.utc(2026, 9, 12);
      var state = GameState(
        memberId: 1001,
        repairDocks: [
          RepairDock(
            id: 1,
            state: 1,
            shipId: 9,
            completionTime: now.add(const Duration(hours: 1)),
          ),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: game,
        settingsController: settings,
        notificationPort: port,
        gameStateProvider: () => state,
        nowProvider: () => now,
      );
      addTearDown(() {
        coordinator.dispose();
        game.dispose();
        settings.dispose();
      });
      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      state = const GameState(memberId: 2002, repairDocks: [RepairDock(id: 1)]);
      game.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(port.deliveredImmediateAlerts, isEmpty);
    },
  );

  test(
    'failed old-account alerts are discarded when another account arrives',
    () async {
      SharedPreferences.setMockInitialValues({});
      final game = GameStateController();
      final settings = NotificationSettingsController(
        store: const SharedPreferencesNotificationSettingsStore(),
      );
      await settings.initialize();
      final port = FakeNotificationPort();
      final retry = Completer<void>();
      var state = const GameState(memberId: 1001);
      final coordinator = GameNotificationCoordinator(
        gameStateController: game,
        settingsController: settings,
        notificationPort: port,
        gameStateProvider: () => state,
        retryDelay: (_) => retry.future,
      );
      addTearDown(() {
        coordinator.dispose();
        game.dispose();
        settings.dispose();
      });
      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      port.failApply = true;
      coordinator.enqueueImmediateAlert(
        ImmediateNotificationItem(
          key: 'old-ship',
          type: GameNotificationType.newShip,
          occurredAt: DateTime.now(),
          title: 'A ship',
          body: 'A ship',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      port.failApply = false;
      state = const GameState(memberId: 2002);
      game.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(port.deliveredImmediateAlerts, isEmpty);
    },
  );

  test(
    'account boundary disables native state before new port and restores own anchors',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = AccountSession(initialMemberId: 1001);
      final game = GameStateController(accountSession: session);
      final settings = NotificationSettingsController(
        store: const SharedPreferencesNotificationSettingsStore(),
      );
      await settings.initialize();
      final port = FakeNotificationPort();
      final at = DateTime.utc(2026, 9, 12, 1);
      var state = GameState(
        memberId: 1001,
        hasPortData: true,
        updatedAt: at,
        ships: const {
          1: OwnedShip(
            id: 1,
            masterId: 1,
            level: 1,
            currentHp: 10,
            maxHp: 10,
            condition: 40,
            currentFuel: 10,
            currentAmmo: 10,
            slotIds: [],
          ),
        },
        fleets: const [
          Fleet(id: 1, name: 'A', shipIds: [1]),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: game,
        settingsController: settings,
        notificationPort: port,
        accountSession: session,
        gameStateProvider: () => state,
        timerAnchorStore: const SharedPreferencesNotificationTimerAnchorStore(),
      );
      addTearDown(() {
        coordinator.dispose();
        game.dispose();
        settings.dispose();
        session.dispose();
      });
      coordinator.start();
      await coordinator.accountReady;
      await Future<void>.delayed(Duration.zero);
      final oldTarget = coordinator.moraleRecoveryTimerController
          .targetForFleet(1);
      final oldSessionId = port.latestSnapshot!.sessionId;
      expect(port.latestSnapshot!.memberId, 1001);
      expect(oldTarget, isNotNull);
      final beforeMetadata = port.applyCount;
      session.accept(
        CapturedApiEvent(
          path: '/kcsapi/api_get_member/basic',
          responseBody:
              '{"api_result":1,"api_data":{"api_member_id":1001,"api_nickname":"updated"}}',
          source: CaptureSource.manual,
          capturedAt: at,
        ),
      );
      await coordinator.accountReady;
      await Future<void>.delayed(Duration.zero);
      expect(
        port.applyCount,
        beforeMetadata,
        reason: 'metadata is not a notification session boundary',
      );
      expect(port.latestSnapshot!.sessionId, oldSessionId);
      expect(
        coordinator.moraleRecoveryTimerController.targetForFleet(1),
        oldTarget,
      );
      session.selectMember(2002);
      await Future<void>.delayed(Duration.zero);
      expect(port.latestSnapshot!.presentation.enabled, isFalse);
      expect(port.latestSnapshot!.memberId, 2002);
      expect(port.latestSnapshot!.alarms, isEmpty);
      expect(
        coordinator.moraleRecoveryTimerController.targetForFleet(1),
        isNull,
      );
      state = state.copyWith(
        memberId: 2002,
        hasPortData: false,
        updatedAt: at.add(const Duration(minutes: 5)),
      );
      await coordinator.accountReady;
      game.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(port.latestSnapshot!.presentation.enabled, isFalse);
      state = state.copyWith(hasPortData: true);
      game.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(
        coordinator.moraleRecoveryTimerController.targetForFleet(1),
        oldTarget!.add(const Duration(minutes: 5)),
      );
      expect(port.latestSnapshot!.presentation.enabled, isTrue);
      session.selectMember(1001);
      state = state.copyWith(memberId: 1001);
      await coordinator.accountReady;
      await Future<void>.delayed(Duration.zero);
      expect(
        coordinator.moraleRecoveryTimerController.targetForFleet(1),
        oldTarget,
      );
      expect(port.latestSnapshot!.sessionId, isNot(oldSessionId));
      coordinator.enqueueImmediateAlert(
        ImmediateNotificationItem(
          key: 'new-account-ship',
          type: GameNotificationType.newShip,
          occurredAt: at,
          title: 'A',
          body: 'A',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(port.deliveredImmediateAlerts.single.key, 'new-account-ship');
      final beforeRelogin = port.latestSnapshot!.sessionId;
      session.reset();
      session.selectMember(1001);
      await coordinator.accountReady;
      await Future<void>.delayed(Duration.zero);
      expect(port.latestSnapshot!.sessionId, isNot(beforeRelogin));
    },
  );
}
