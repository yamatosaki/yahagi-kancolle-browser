import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notification/game_notification_coordinator.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_timer_anchor_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

class FakeNotificationPort implements NotificationPort {
  final Map<String, ScheduledNotificationItem> scheduledAlarms = {};
  final List<ImmediateNotificationItem> deliveredImmediateAlerts = [];
  NotificationSnapshot? latestSnapshot;
  bool failApply = false;
  int failuresRemaining = 0;
  int applyCount = 0;
  int activeApplies = 0;
  int maxActiveApplies = 0;
  Completer<void>? applyGate;
  final List<NotificationSnapshot> appliedSnapshots = [];

  @override
  Future<NotificationApplyResult> applySnapshot(
    NotificationSnapshot snapshot,
  ) async {
    applyCount++;
    activeApplies++;
    if (activeApplies > maxActiveApplies) maxActiveApplies = activeApplies;
    appliedSnapshots.add(snapshot);
    final gate = applyGate;
    if (gate != null) await gate.future;
    activeApplies--;
    if (failApply || failuresRemaining-- > 0) {
      throw StateError('native apply failed');
    }
    latestSnapshot = snapshot;
    deliveredImmediateAlerts.addAll(snapshot.immediateAlerts);
    scheduledAlarms
      ..clear()
      ..addEntries(snapshot.alarms.map((alarm) => MapEntry(alarm.key, alarm)));
    return const NotificationApplyResult(
      scheduledExact: 0,
      scheduledInexact: 0,
      canceled: 0,
      failures: [],
    );
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async {
    return const NotificationPlatformCapabilities(
      notificationsGranted: true,
      exactAlarmsGranted: true,
      channelsEnabled: true,
    );
  }

  @override
  Future<void> openSystemNotificationSettings() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<bool> requestNotificationPermission() async => true;
}

GameState _anchorageState({bool akashiFlagship = true}) {
  const akashiMaster = MasterShip(id: 182, name: '明石', shipTypeId: 19);
  const escortMaster = MasterShip(id: 1, name: '护卫舰', shipTypeId: 2);
  const akashi = OwnedShip(
    id: 1,
    masterId: 182,
    level: 35,
    currentHp: 39,
    maxHp: 39,
    condition: 49,
    currentFuel: 50,
    currentAmmo: 10,
    slotIds: [],
  );
  const escort = OwnedShip(
    id: 2,
    masterId: 1,
    level: 50,
    currentHp: 20,
    maxHp: 30,
    condition: 49,
    currentFuel: 15,
    currentAmmo: 20,
    slotIds: [],
    repairDurationMilliseconds: 3_600_000,
  );
  return GameState.empty.copyWith(
    masterShips: const {182: akashiMaster, 1: escortMaster},
    ships: const {1: akashi, 2: escort},
    fleets: [
      Fleet(
        id: 1,
        name: '第1舰队',
        shipIds: akashiFlagship ? const [1, 2] : const [2, 1],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameNotificationCoordinator', () {
    late GameStateController gameStateController;
    late NotificationSettingsController settingsController;
    late FakeNotificationPort fakePort;
    late DateTime testNow;
    late GameState testState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gameStateController = GameStateController();
      settingsController = NotificationSettingsController(
        store: const SharedPreferencesNotificationSettingsStore(),
      );
      await settingsController.initialize();
      fakePort = FakeNotificationPort();
      testNow = DateTime(2026, 8, 22, 12, 0, 0);
      testState = GameState.empty;
    });

    test(
      'locale changes update alarms without changing identity or names',
      () async {
        final locale = ValueNotifier('zh');
        testState = testState.copyWith(
          masterMissions: const {
            37: MasterMission(
              id: 37,
              name: '东京急行',
              duration: Duration(minutes: 30),
            ),
          },
          fleets: [
            Fleet(
              id: 2,
              name: '我的舰队',
              shipIds: const [2],
              mission: FleetMission(
                state: 1,
                missionId: 37,
                completionTime: testNow.add(const Duration(minutes: 30)),
              ),
            ),
            Fleet(
              id: 3,
              name: '',
              shipIds: const [3],
              mission: FleetMission(
                state: 1,
                missionId: 99,
                completionTime: testNow.add(const Duration(minutes: 30)),
              ),
            ),
          ],
        );
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          localeCodeProvider: () => locale.value,
          localeListenable: locale,
        );
        coordinator.start();
        await Future<void>.delayed(Duration.zero);
        final original = Map.of(fakePort.scheduledAlarms);
        for (final code in ['zh_Hant', 'ja', 'zh']) {
          locale.value = code;
          await Future<void>.delayed(Duration.zero);
          expect(
            fakePort.latestSnapshot!.presentation.toMap()['localeCode'],
            code,
          );
          expect(fakePort.scheduledAlarms.keys, original.keys);
          for (final entry in original.entries) {
            final updated = fakePort.scheduledAlarms[entry.key]!;
            expect(updated.taskId, entry.value.taskId);
            expect(updated.triggerTime, entry.value.triggerTime);
          }
          final alarm = fakePort.scheduledAlarms['expedition_2_complete']!;
          expect(alarm.title, contains('我的舰队'));
          expect(alarm.body, contains('东京急行'));
          if (code == 'ja') {
            expect(alarm.title, '遠征完了 · 我的舰队');
            expect(
              fakePort.scheduledAlarms['expedition_3_complete']!.title,
              '遠征完了 · 第3艦隊',
            );
            expect(
              fakePort.scheduledAlarms['expedition_3_complete']!.body,
              '遠征 99 が無事に母港へ帰投しました！',
            );
          }
          if (code == 'zh_Hant') expect(alarm.title, '遠征完成 · 我的舰队');
        }
        expect(fakePort.deliveredImmediateAlerts, isEmpty);
        final applyCount = fakePort.applyCount;
        coordinator.dispose();
        locale.value = 'ja';
        await Future<void>.delayed(Duration.zero);
        expect(fakePort.applyCount, applyCount);
        locale.dispose();
      },
    );

    test(
      'missing master fallback follows locale for manual completion and tombstones',
      () async {
        final locale = ValueNotifier('zh');
        final deadline = testNow.add(const Duration(hours: 1));
        testState = testState.copyWith(
          constructionDocks: [
            ConstructionDock(
              id: 1,
              state: 2,
              createdShipMasterId: 9999,
              completionTime: deadline,
            ),
          ],
          repairDocks: [
            RepairDock(id: 1, state: 1, shipId: 9999, completionTime: deadline),
          ],
        );
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          localeCodeProvider: () => locale.value,
          localeListenable: locale,
        );
        coordinator.start();
        await Future<void>.delayed(Duration.zero);
        locale.value = 'ja';
        await Future<void>.delayed(Duration.zero);
        testState = testState.copyWith(
          constructionDocks: [
            ConstructionDock(
              id: 1,
              state: 3,
              createdShipMasterId: 9999,
              completionTime: deadline,
            ),
          ],
          repairDocks: const [RepairDock(id: 1)],
        );
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        expect(fakePort.deliveredImmediateAlerts, hasLength(2));
        expect(
          fakePort.deliveredImmediateAlerts.every(
            (alert) => alert.body.startsWith('艦娘 '),
          ),
          isTrue,
        );
        final repair = fakePort.latestSnapshot!.ongoingItems.firstWhere(
          (item) => item.id == 'repair:1',
        );
        expect(repair.title, contains('艦娘 修理完了'));
        locale.value = 'zh_Hant';
        await Future<void>.delayed(Duration.zero);
        final translatedRepair = fakePort.latestSnapshot!.ongoingItems
            .firstWhere((item) => item.id == 'repair:1');
        expect(translatedRepair.title, contains('艦船 修復完成'));
        expect(translatedRepair.targetEpochMs, repair.targetEpochMs);
        expect(fakePort.deliveredImmediateAlerts, hasLength(2));
        coordinator.dispose();
        locale.dispose();
      },
    );

    test(
      'delivers a new-ship immediate alert with vibration settings',
      () async {
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
        );
        coordinator.start();

        coordinator.enqueueImmediateAlert(
          ImmediateNotificationItem(
            key: 'new-ship:42',
            type: GameNotificationType.newShip,
            occurredAt: testNow,
            title: '发现未持有舰娘',
            body: '四号',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          fakePort.deliveredImmediateAlerts.last.type,
          GameNotificationType.newShip,
        );
        expect(fakePort.latestSnapshot?.presentation.vibration, isTrue);
        coordinator.dispose();
      },
    );

    test('schedules expedition complete and preempt alarms correctly', () {
      final returnTime = testNow.add(const Duration(minutes: 30));

      testState = testState.copyWith(
        masterMissions: {
          37: const MasterMission(
            id: 37,
            name: '东京急行',
            duration: Duration(minutes: 30),
          ),
        },
        fleets: [
          const Fleet(id: 1, name: '第1舰队', shipIds: [1]),
          Fleet(
            id: 2,
            name: '第2舰队',
            shipIds: const [2],
            mission: FleetMission(
              state: 1,
              missionId: 37,
              completionTime: returnTime,
            ),
          ),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      // Verify expedition alarms
      expect(
        fakePort.scheduledAlarms.containsKey('expedition_2_complete'),
        isTrue,
      );
      expect(
        fakePort.scheduledAlarms.containsKey('expedition_2_preempt'),
        isTrue,
      );

      final completeAlarm = fakePort.scheduledAlarms['expedition_2_complete']!;
      expect(completeAlarm.triggerTime, returnTime);
      expect(completeAlarm.body, '东京急行 已顺利返抵母港！');

      final preemptAlarm = fakePort.scheduledAlarms['expedition_2_preempt']!;
      expect(
        preemptAlarm.triggerTime,
        returnTime.subtract(const Duration(seconds: 60)),
      );

      coordinator.dispose();
    });

    test('uses the game expedition display number in ongoing titles', () async {
      final returnTime = testNow.add(const Duration(minutes: 30));
      testState = testState.copyWith(
        masterMissions: const {
          110: MasterMission(
            id: 110,
            name: '南西方面航空侦察作战',
            duration: Duration(minutes: 35),
          ),
        },
        fleets: [
          Fleet(
            id: 4,
            name: '第4舰队',
            shipIds: const [1],
            mission: FleetMission(
              state: 1,
              missionId: 110,
              completionTime: returnTime,
            ),
          ),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );

      coordinator.start();

      expect(
        fakePort.latestSnapshot!.ongoingItems.single.title,
        '⚓ 远征 第4舰队 B1 · 南西方面航空侦察作战',
      );

      testState = testState.copyWith(
        masterMissions: const {
          110: MasterMission(
            id: 110,
            name: '南西方面航空侦察作战',
            duration: Duration(minutes: 35),
            displayNumber: 'B-自定义',
          ),
        },
      );
      gameStateController.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(
        fakePort.latestSnapshot!.ongoingItems.single.title,
        '⚓ 远征 第4舰队 B-自定义 · 南西方面航空侦察作战',
      );
      coordinator.dispose();
    });

    test('schedules repair dock alarm and cancels when repaired', () async {
      final completeTime = testNow.add(const Duration(hours: 1));
      testState = testState.copyWith(
        masterShips: {
          131: const MasterShip(id: 131, name: '大和', shipTypeId: 9),
        },
        ships: {
          10: const OwnedShip(
            id: 10,
            masterId: 131,
            level: 99,
            currentHp: 20,
            maxHp: 96,
            condition: 49,
            currentFuel: 100,
            currentAmmo: 100,
            slotIds: [],
          ),
        },
        repairDocks: [
          RepairDock(id: 1, state: 1, shipId: 10, completionTime: completeTime),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(fakePort.scheduledAlarms.containsKey('repair_1_complete'), isTrue);
      final alarm = fakePort.scheduledAlarms['repair_1_complete']!;
      expect(alarm.body, '大和 已经在船坞修理完毕，HP 已完全修满！');

      // Now clear the dock (e.g. instant bucket used)
      testState = testState.copyWith(
        repairDocks: [
          const RepairDock(id: 1, state: 0, shipId: 0, completionTime: null),
        ],
      );
      // Trigger setting change or notification sync
      settingsController.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(
        fakePort.scheduledAlarms.containsKey('repair_1_complete'),
        isFalse,
      );
      expect(
        fakePort.latestSnapshot?.alarms.map((item) => item.key),
        isNot(contains('repair_1_complete')),
      );

      coordinator.dispose();
    });

    test('schedules construction dock with parsed master ship name', () {
      final completeTime = testNow.add(const Duration(hours: 4));
      testState = testState.copyWith(
        masterShips: {
          153: const MasterShip(id: 153, name: '大凤', shipTypeId: 11),
        },
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 2,
            createdShipMasterId: 153,
            completionTime: completeTime,
          ),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(
        fakePort.scheduledAlarms.containsKey('construction_1_complete'),
        isTrue,
      );
      final alarm = fakePort.scheduledAlarms['construction_1_complete']!;
      expect(alarm.body, '大凤 已在船坞建造完成！');

      coordinator.dispose();
    });

    test('keeps overdue authoritative tasks as completed ongoing items', () {
      final overdue = testNow.subtract(const Duration(minutes: 1));
      testState = GameState.empty.copyWith(
        updatedAt: testNow.subtract(const Duration(minutes: 30)),
        masterMissions: const {
          37: MasterMission(
            id: 37,
            name: '东京急行',
            duration: Duration(minutes: 30),
          ),
        },
        masterShips: const {
          1: MasterShip(id: 1, name: '吹雪', shipTypeId: 2),
          153: MasterShip(id: 153, name: '大凤', shipTypeId: 11),
        },
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
          10: OwnedShip(
            id: 10,
            masterId: 1,
            level: 1,
            currentHp: 5,
            maxHp: 10,
            condition: 49,
            currentFuel: 10,
            currentAmmo: 10,
            slotIds: [],
            repairDurationMilliseconds: 600000,
          ),
        },
        fleets: [
          const Fleet(id: 1, name: '第1舰队', shipIds: [1]),
          Fleet(
            id: 2,
            name: '第2舰队',
            shipIds: const [10],
            mission: FleetMission(
              state: 1,
              missionId: 37,
              completionTime: overdue,
            ),
          ),
        ],
        repairDocks: [
          RepairDock(id: 1, state: 1, shipId: 10, completionTime: overdue),
        ],
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 1,
            createdShipMasterId: 153,
            completionTime: overdue,
          ),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      final completedById = {
        for (final item in fakePort.latestSnapshot!.ongoingItems) item.id: item,
      };
      for (final id in const [
        'expedition:2',
        'repair:1',
        'construction:1',
        'morale:1',
      ]) {
        expect(
          completedById[id]?.state,
          OngoingTaskState.completed,
          reason: id,
        );
        expect(completedById[id]?.progress, 1, reason: id);
        expect(completedById[id]?.remainingSeconds, 0, reason: id);
      }
      expect(fakePort.latestSnapshot!.alarms, isEmpty);

      coordinator.dispose();
    });

    test('schedules anchorage repair 20m alarm when timer is active', () {
      final ancStarted = testNow.subtract(const Duration(minutes: 5));
      testState = _anchorageState();
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
        anchorageRepairStartedAtProvider: () => ancStarted,
      );
      coordinator.start();

      expect(fakePort.scheduledAlarms.containsKey('anchorage_1_20m'), isTrue);
      final alarm = fakePort.scheduledAlarms['anchorage_1_20m']!;
      expect(alarm.triggerTime, ancStarted.add(const Duration(minutes: 20)));
      expect(alarm.body, contains('20 分钟'));
      final item = fakePort.latestSnapshot!.ongoingItems.singleWhere(
        (item) => item.id == 'anchorage:1',
      );
      expect(item.clockMode, OngoingClockMode.elapsed);
      expect(item.anchorEpochMs, ancStarted.millisecondsSinceEpoch);
      expect(item.state, OngoingTaskState.running);

      coordinator.dispose();
    });

    test('anchorage keeps counting up after the 20 minute milestone', () {
      final ancStarted = testNow.subtract(const Duration(minutes: 21));
      testState = _anchorageState();
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
        anchorageRepairStartedAtProvider: () => ancStarted,
      );
      coordinator.start();

      final item = fakePort.latestSnapshot!.ongoingItems.singleWhere(
        (item) => item.id == 'anchorage:1',
      );
      expect(item.clockMode, OngoingClockMode.elapsed);
      expect(item.anchorEpochMs, ancStarted.millisecondsSinceEpoch);
      expect(item.state, OngoingTaskState.settlementReady);

      coordinator.dispose();
    });

    test(
      'anchorage all-repaired estimate waits for port confirmation',
      () async {
        await settingsController.setAnchorageMode(
          AnchorageNotificationMode.allRepaired,
        );
        final ancStarted = testNow.subtract(const Duration(hours: 2));
        testState = _anchorageState();
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          anchorageRepairStartedAtProvider: () => ancStarted,
        );
        coordinator.start();

        final item = fakePort.latestSnapshot!.ongoingItems.singleWhere(
          (item) => item.id == 'anchorage:1',
        );
        expect(item.clockMode, OngoingClockMode.elapsed);
        expect(item.anchorEpochMs, ancStarted.millisecondsSinceEpoch);
        expect(item.state, OngoingTaskState.completed);
        expect(item.progress, 1);

        coordinator.dispose();
      },
    );

    test(
      'restores anchorage estimate from cached state after process restart',
      () {
        final cachedAt = testNow.subtract(const Duration(minutes: 5));
        testState = _anchorageState().copyWith(updatedAt: cachedAt);
        final anchors = NotificationTimerAnchors(
          akashi: GlobalNotificationTimerAnchor(
            anchorAt: cachedAt,
            signature: NotificationTimerSignature.anchorage(testState)!,
          ),
        );
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          anchorageRepairStartedAtProvider: () => null,
          initialTimerAnchors: anchors,
        );
        coordinator.start();

        final alarm = fakePort.scheduledAlarms['anchorage_1_20m'];
        expect(alarm?.triggerTime, cachedAt.add(const Duration(minutes: 20)));
        expect(
          fakePort.latestSnapshot?.ongoingItems.map((item) => item.id),
          contains('anchorage:1'),
        );

        coordinator.dispose();
      },
    );

    test('drops anchorage task when Akashi is moved out of flagship', () async {
      final ancStarted = testNow.subtract(const Duration(minutes: 5));
      testState = _anchorageState();
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
        anchorageRepairStartedAtProvider: () => ancStarted,
      );
      coordinator.start();

      expect(
        fakePort.latestSnapshot?.ongoingItems.map((item) => item.id),
        contains('anchorage:1'),
      );

      testState = _anchorageState(akashiFlagship: false);
      gameStateController.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(
        fakePort.latestSnapshot?.ongoingItems.map((item) => item.id),
        isNot(contains('anchorage:1')),
      );
      expect(
        fakePort.latestSnapshot?.alarms.map((alarm) => alarm.taskId),
        isNot(contains('anchorage:1')),
      );

      coordinator.dispose();
    });

    test(
      'all-repaired mode schedules the projected final repair deadline',
      () async {
        await settingsController.setAnchorageMode(
          AnchorageNotificationMode.allRepaired,
        );
        final ancStarted = testNow.subtract(const Duration(minutes: 5));
        testState = _anchorageState();
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          anchorageRepairStartedAtProvider: () => ancStarted,
        );
        coordinator.start();

        final alarm = fakePort.latestSnapshot?.alarms.singleWhere(
          (item) => item.key == 'anchorage_1_all_repaired',
        );
        expect(alarm?.taskId, 'anchorage:1');
        expect(alarm?.removeTaskOnFire, isTrue);
        expect(alarm?.triggerTime.isAfter(testNow), isTrue);
        expect(alarm?.title, '泊地修理完成 · 第1舰队');
        expect(alarm?.body, '第1舰队 中符合条件的舰船预计已全部修复。');

        coordinator.dispose();
      },
    );

    test(
      'fast build alerts immediately and keeps completed ongoing progress',
      () async {
        final completeTime = testNow.add(const Duration(hours: 1));
        testState = testState.copyWith(
          masterShips: {
            153: const MasterShip(id: 153, name: '大凤', shipTypeId: 11),
          },
          constructionDocks: [
            ConstructionDock(
              id: 1,
              state: 1,
              createdShipMasterId: 153,
              completionTime: completeTime,
            ),
          ],
        );

        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
        );
        coordinator.start();

        expect(
          fakePort.scheduledAlarms.containsKey('construction_1_complete'),
          isTrue,
        );
        expect(fakePort.latestSnapshot?.ongoingItems.length, 1);

        // Fast build (speedchange) sets state to 3 and completionTime to now
        testState = testState.copyWith(
          constructionDocks: [
            ConstructionDock(
              id: 1,
              state: 3,
              createdShipMasterId: 153,
              completionTime: testNow,
            ),
          ],
        );
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);

        expect(
          fakePort.scheduledAlarms.containsKey('construction_1_complete'),
          isFalse,
        );
        expect(fakePort.latestSnapshot?.alarms, isEmpty);
        final completed = fakePort.latestSnapshot!.ongoingItems.single;
        expect(completed.id, 'construction:1');
        expect(completed.state, OngoingTaskState.completed);
        expect(completed.progress, 1);
        expect(completed.remainingSeconds, 0);
        expect(fakePort.deliveredImmediateAlerts, hasLength(1));
        expect(fakePort.deliveredImmediateAlerts.single.title, '建造完成 · 船坞 #1');
        expect(fakePort.deliveredImmediateAlerts.single.body, contains('大凤'));

        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        expect(fakePort.deliveredImmediateAlerts, hasLength(1));

        testState = testState.copyWith(
          constructionDocks: const [ConstructionDock(id: 1)],
        );
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        expect(fakePort.latestSnapshot?.ongoingItems, isEmpty);
        expect(fakePort.deliveredImmediateAlerts, hasLength(1));

        coordinator.dispose();
      },
    );

    test(
      'fast repair alerts immediately and retains completion until authoritative refresh',
      () async {
        final completeTime = testNow.add(const Duration(hours: 1));
        String? lastUpdatedPath;
        testState = testState.copyWith(
          masterShips: const {
            131: MasterShip(id: 131, name: '大和', shipTypeId: 9),
          },
          ships: const {
            10: OwnedShip(
              id: 10,
              masterId: 131,
              level: 99,
              currentHp: 20,
              maxHp: 96,
              condition: 49,
              currentFuel: 100,
              currentAmmo: 100,
              slotIds: [],
            ),
          },
          repairDocks: [
            RepairDock(
              id: 1,
              state: 1,
              shipId: 10,
              completionTime: completeTime,
            ),
          ],
        );
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          lastUpdatedPathProvider: () => lastUpdatedPath,
        );
        coordinator.start();

        lastUpdatedPath = '/kcsapi/api_req_nyukyo/speedchange';
        testState = testState.copyWith(repairDocks: const [RepairDock(id: 1)]);
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);

        final completed = fakePort.latestSnapshot!.ongoingItems.single;
        expect(completed.id, 'repair:1');
        expect(completed.state, OngoingTaskState.completed);
        expect(completed.progress, 1);
        expect(completed.remainingSeconds, 0);
        expect(fakePort.deliveredImmediateAlerts, hasLength(1));
        expect(
          fakePort.deliveredImmediateAlerts.single.title,
          '舰船修复完成 · 船坞 #1',
        );
        expect(fakePort.deliveredImmediateAlerts.single.body, contains('大和'));

        lastUpdatedPath = '/kcsapi/api_get_member/material';
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        expect(fakePort.latestSnapshot?.ongoingItems.single.id, 'repair:1');
        expect(fakePort.deliveredImmediateAlerts, hasLength(1));

        lastUpdatedPath = '/kcsapi/api_get_member/ndock';
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        expect(fakePort.latestSnapshot?.ongoingItems, isEmpty);
        expect(fakePort.deliveredImmediateAlerts, hasLength(1));

        coordinator.dispose();
      },
    );

    test('does not alert for an already completed dock on startup', () {
      testState = testState.copyWith(
        masterShips: const {
          153: MasterShip(id: 153, name: '大凤', shipTypeId: 11),
        },
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 3,
            createdShipMasterId: 153,
            completionTime: testNow,
          ),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );

      coordinator.start();

      expect(fakePort.deliveredImmediateAlerts, isEmpty);
      expect(
        fakePort.latestSnapshot?.ongoingItems.single.state,
        OngoingTaskState.completed,
      );
      coordinator.dispose();
    });

    test('reports native snapshot application failures', () async {
      fakePort.failApply = true;
      final errors = <Object>[];
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
        retryDelay: (_) async {},
        onError: (error, _) => errors.add(error),
      );

      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<StateError>());
      expect(fakePort.applyCount, 4);
      coordinator.dispose();
    });

    test(
      'serializes native snapshot calls and applies the newest state last',
      () async {
        final firstGate = Completer<void>();
        fakePort.applyGate = firstGate;
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
        );
        coordinator.start();

        final completeTime = testNow.add(const Duration(minutes: 30));
        testState = testState.copyWith(
          constructionDocks: [
            ConstructionDock(
              id: 1,
              state: 1,
              createdShipMasterId: 1,
              completionTime: completeTime,
            ),
          ],
        );
        gameStateController.notifyListeners();
        testState = testState.copyWith(
          constructionDocks: const [ConstructionDock(id: 1)],
        );
        gameStateController.notifyListeners();

        fakePort.applyGate = null;
        firstGate.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fakePort.maxActiveApplies, 1);
        expect(fakePort.latestSnapshot?.ongoingItems, isEmpty);
        expect(fakePort.applyCount, 2);
        coordinator.dispose();
      },
    );

    test(
      'retries failed snapshots with bounded backoff and keeps immediate alerts',
      () async {
        fakePort.failuresRemaining = 2;
        final delays = <Duration>[];
        final completeTime = testNow.add(const Duration(hours: 1));
        testState = testState.copyWith(
          masterShips: const {
            153: MasterShip(id: 153, name: '大凤', shipTypeId: 11),
          },
          constructionDocks: [
            ConstructionDock(
              id: 1,
              state: 1,
              createdShipMasterId: 153,
              completionTime: completeTime,
            ),
          ],
        );
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          retryDelay: (delay) async => delays.add(delay),
        );
        coordinator.start();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(delays, const [Duration(seconds: 1), Duration(seconds: 3)]);
        expect(fakePort.applyCount, 3);

        testState = testState.copyWith(
          constructionDocks: [
            ConstructionDock(
              id: 1,
              state: 3,
              createdShipMasterId: 153,
              completionTime: testNow,
            ),
          ],
        );
        fakePort.failuresRemaining = 1;
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fakePort.deliveredImmediateAlerts, hasLength(1));
        expect(
          fakePort.deliveredImmediateAlerts.single.taskId,
          'construction:1',
        );
        coordinator.dispose();
      },
    );

    test('natural morale deadline stays anchored to the game snapshot', () {
      testState = GameState.empty.copyWith(
        updatedAt: testNow,
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
          Fleet(id: 1, name: 'Fleet 1', shipIds: [1]),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();
      final firstDeadline = fakePort.latestSnapshot!.alarms
          .singleWhere((alarm) => alarm.key == 'morale_1_normal')
          .triggerTime;

      testNow = testNow.add(const Duration(minutes: 1));
      testState = testState.copyWith(updatedAt: testNow);
      gameStateController.notifyListeners();
      final secondDeadline = fakePort.latestSnapshot!.alarms
          .singleWhere((alarm) => alarm.key == 'morale_1_normal')
          .triggerTime;

      expect(secondDeadline, firstDeadline);
      coordinator.dispose();
    });

    test('disabling notifications keeps the shared morale target', () async {
      testState = GameState.empty.copyWith(
        updatedAt: testNow,
        ships: const {
          1: OwnedShip(id: 1, masterId: 1, level: 1, condition: 40),
        },
        fleets: const [
          Fleet(id: 1, name: 'Fleet 1', shipIds: [1]),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();
      final target = coordinator.moraleRecoveryTimerController.targetForFleet(
        1,
      );

      await settingsController.setMaster(false);

      expect(
        coordinator.moraleRecoveryTimerController.targetForFleet(1),
        target,
      );
      expect(fakePort.latestSnapshot?.alarms, isEmpty);
      coordinator.dispose();
    });

    test(
      'recovered morale clears its anchor before the same fleet becomes tired again',
      () async {
        const fleet = Fleet(id: 1, name: '第1舰队', shipIds: [1]);
        OwnedShip shipWithCondition(int condition) => OwnedShip(
          id: 1,
          masterId: 1,
          level: 1,
          currentHp: 10,
          maxHp: 10,
          condition: condition,
          currentFuel: 10,
          currentAmmo: 10,
          slotIds: const [],
        );

        final expiredTarget = testNow.add(const Duration(minutes: 9));
        testState = GameState.empty.copyWith(
          updatedAt: testNow,
          ships: {1: shipWithCondition(49)},
          fleets: const [fleet],
        );
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
          initialTimerAnchors: NotificationTimerAnchors(
            moraleByFleet: {
              1: MoraleNotificationTimerAnchor(
                fleetSignature: NotificationTimerSignature.morale(fleet),
                observedAt: testNow,
                observedCondition: 40,
                targetAt: expiredTarget,
              ),
            },
          ),
        );
        coordinator.start();
        await Future<void>.delayed(Duration.zero);

        testNow = testNow.add(const Duration(hours: 1));
        testState = testState.copyWith(
          updatedAt: testNow,
          ships: {1: shipWithCondition(40)},
        );
        gameStateController.notifyListeners();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final alarm = fakePort.scheduledAlarms['morale_1_normal'];
        expect(alarm, isNotNull);
        expect(
          alarm!.triggerTime.toUtc(),
          testNow.add(const Duration(minutes: 9)).toUtc(),
        );
        expect(
          fakePort.latestSnapshot!.ongoingItems
              .singleWhere((item) => item.id == 'morale:1')
              .state,
          OngoingTaskState.running,
        );
        coordinator.dispose();
      },
    );

    test('schedules construction dock preempt alarm when configured', () async {
      await settingsController.setConstructionPreemptSeconds(30);
      final completeTime = testNow.add(const Duration(hours: 4));
      testState = testState.copyWith(
        masterShips: {
          153: const MasterShip(id: 153, name: '大凤', shipTypeId: 11),
        },
        constructionDocks: [
          ConstructionDock(
            id: 1,
            state: 2,
            createdShipMasterId: 153,
            completionTime: completeTime,
          ),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(
        fakePort.scheduledAlarms.containsKey('construction_1_complete'),
        isTrue,
      );
      expect(
        fakePort.scheduledAlarms.containsKey('construction_1_preempt'),
        isTrue,
      );
      final preemptAlarm = fakePort.scheduledAlarms['construction_1_preempt']!;
      expect(
        preemptAlarm.triggerTime,
        completeTime.subtract(const Duration(seconds: 30)),
      );
      expect(preemptAlarm.body, '大凤 还有 30 秒建造完成。');

      coordinator.dispose();
    });

    test('schedules repair dock preempt alarm when set to 30s', () async {
      await settingsController.setRepairPreemptSeconds(30);
      final completeTime = testNow.add(const Duration(hours: 1));
      testState = testState.copyWith(
        masterShips: {
          131: const MasterShip(id: 131, name: '大和', shipTypeId: 9),
        },
        ships: {
          10: const OwnedShip(
            id: 10,
            masterId: 131,
            level: 99,
            currentHp: 20,
            maxHp: 96,
            condition: 49,
            currentFuel: 100,
            currentAmmo: 100,
            slotIds: [],
          ),
        },
        repairDocks: [
          RepairDock(id: 1, state: 1, shipId: 10, completionTime: completeTime),
        ],
      );

      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(fakePort.scheduledAlarms.containsKey('repair_1_preempt'), isTrue);
      final preempt = fakePort.scheduledAlarms['repair_1_preempt']!;
      expect(
        preempt.triggerTime,
        completeTime.subtract(const Duration(seconds: 30)),
      );
      expect(preempt.body, '大和 还有 30 秒修理完毕。');

      coordinator.dispose();
    });

    test('schedules natural morale preempt alarm when configured', () async {
      await settingsController.setMoralePreemptSeconds(60);
      testState = GameState.empty.copyWith(
        updatedAt: testNow,
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
          Fleet(id: 1, name: '第1舰队', shipIds: [1]),
        ],
      );
      final coordinator = GameNotificationCoordinator(
        gameStateController: gameStateController,
        settingsController: settingsController,
        notificationPort: fakePort,
        gameStateProvider: () => testState,
        nowProvider: () => testNow,
      );
      coordinator.start();

      expect(
        fakePort.scheduledAlarms.containsKey('morale_1_normal_preempt'),
        isTrue,
      );
      final preempt = fakePort.scheduledAlarms['morale_1_normal_preempt']!;
      final complete = fakePort.scheduledAlarms['morale_1_normal']!;
      expect(
        preempt.triggerTime,
        complete.triggerTime.subtract(const Duration(seconds: 60)),
      );
      expect(preempt.body, '第1舰队 全队舰船士气还有 60 秒恢复至 49。');

      coordinator.dispose();
    });

    test(
      'uses user-defined custom fleet names in ongoing and alarm notifications',
      () {
        final returnTime = testNow.add(const Duration(minutes: 30));
        testState = testState.copyWith(
          masterMissions: const {
            1: MasterMission(
              id: 1,
              name: '練習航海',
              displayNumber: '01',
              duration: Duration(minutes: 15),
            ),
          },
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
          fleets: [
            Fleet(
              id: 2,
              name: '北方遠征隊',
              shipIds: const [1],
              mission: FleetMission(
                state: 1,
                missionId: 1,
                completionTime: returnTime,
              ),
            ),
          ],
        );
        final coordinator = GameNotificationCoordinator(
          gameStateController: gameStateController,
          settingsController: settingsController,
          notificationPort: fakePort,
          gameStateProvider: () => testState,
          nowProvider: () => testNow,
        );
        coordinator.start();

        expect(
          fakePort.latestSnapshot!.ongoingItems
              .firstWhere((i) => i.id == 'expedition:2')
              .title,
          '⚓ 远征 北方遠征隊 01 · 練習航海',
        );

        expect(
          fakePort.latestSnapshot!.ongoingItems
              .firstWhere((i) => i.id == 'morale:2')
              .title,
          '✨ 疲劳 北方遠征隊 (Cond 40/49)',
        );

        final preemptAlarm = fakePort.scheduledAlarms['expedition_2_preempt']!;
        expect(preemptAlarm.title, '远征即将归还 · 北方遠征隊');

        final completeAlarm =
            fakePort.scheduledAlarms['expedition_2_complete']!;
        expect(completeAlarm.title, '远征完成 · 北方遠征隊');

        coordinator.dispose();
      },
    );
  });
}
