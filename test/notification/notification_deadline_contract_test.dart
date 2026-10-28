import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notification/game_notification_coordinator.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

import '../nosaki_sparkle_calculator_test.dart' show buildNosakiTestState;
import 'game_notification_coordinator_test.dart' show FakeNotificationPort;

class _MemorySettingsStore implements NotificationSettingsStore {
  @override
  Future<NotificationSettings> load() async => const NotificationSettings();

  @override
  Future<void> save(NotificationSettings settings) async {}
}

GameState _tasks(DateTime now, DateTime deadline) => GameState.empty.copyWith(
  updatedAt: now,
  masterShips: const {1: MasterShip(id: 1, name: 'Ship 60', shipTypeId: 2)},
  masterMissions: const {
    60: MasterMission(id: 60, name: 'Mission 60', duration: Duration(hours: 1)),
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
    const Fleet(id: 1, name: 'Fleet 60', shipIds: [1]),
    Fleet(
      id: 2,
      name: 'Fleet 30',
      mission: FleetMission(state: 1, missionId: 60, completionTime: deadline),
    ),
  ],
  repairDocks: [
    RepairDock(id: 1, state: 1, shipId: 1, completionTime: deadline),
  ],
  constructionDocks: [
    ConstructionDock(
      id: 1,
      state: 1,
      createdShipMasterId: 1,
      completionTime: deadline,
    ),
  ],
);

void _expectPreemptContract(NotificationSnapshot snapshot, int seconds) {
  expect(snapshot.schemaVersion, 1);
  final preempts = snapshot.alarms.where(
    (alarm) => alarm.stage == NotificationAlarmStage.preempt,
  );
  if (seconds == 0) {
    expect(preempts, isEmpty);
    return;
  }
  expect(preempts, hasLength(4));
  for (final preempt in preempts) {
    final complete = snapshot.alarms.singleWhere(
      (alarm) =>
          alarm.taskId == preempt.taskId &&
          alarm.stage == NotificationAlarmStage.complete,
    );
    final map = preempt.toMap();
    expect(map['deadlineEpochMs'], complete.triggerTime.millisecondsSinceEpoch);
    expect(
      preempt.triggerTime,
      complete.triggerTime.subtract(Duration(seconds: seconds)),
    );
    final template = map['bodyTemplate'];
    expect(template, isA<String>());
    expect(template, contains('{seconds'));
    expect(
      (template! as String)
          .replaceAll('{secondsText}', '$seconds seconds')
          .replaceAll('{seconds}', '$seconds'),
      preempt.body,
    );
    expect(preempt.body, isNot(contains('{seconds')));
  }
  expect(
    preempts
        .singleWhere((alarm) => alarm.type == GameNotificationType.expedition)
        .toMap()['bodyTemplate'],
    contains('Mission 60'),
  );
  expect(
    preempts
        .singleWhere((alarm) => alarm.type == GameNotificationType.repair)
        .toMap()['bodyTemplate'],
    contains('Ship 60'),
  );
  expect(
    preempts
        .singleWhere((alarm) => alarm.type == GameNotificationType.morale)
        .toMap()['bodyTemplate'],
    contains('Fleet 60'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one snapshot uses one clock sample for Nosaki alarms and task deadlines',
    () async {
      final startedAt = DateTime.utc(2026, 10, 28, 12);
      var clock = startedAt;
      final controller = GameStateController(
        initialState: buildNosakiTestState(companionConds: [49, 54]),
      );
      final settings = NotificationSettingsController(
        store: _MemorySettingsStore(),
        initialSettings: const NotificationSettings(moralePreemptSeconds: 60),
      );
      final port = FakeNotificationPort();
      final coordinator = GameNotificationCoordinator(
        gameStateController: controller,
        settingsController: settings,
        notificationPort: port,
        nowProvider: () => clock = clock.add(const Duration(milliseconds: 1)),
        nosakiSparkleStartedAtProvider: () => startedAt,
      );
      addTearDown(coordinator.dispose);
      addTearDown(controller.dispose);
      addTearDown(settings.dispose);
      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      final snapshot = port.latestSnapshot!;
      final preempt = snapshot.alarms.singleWhere(
        (alarm) => alarm.key == 'morale_1_nosaki_preempt',
      );
      final complete = snapshot.alarms.singleWhere(
        (alarm) => alarm.key == 'morale_1_nosaki',
      );
      final task = snapshot.ongoingItems.singleWhere(
        (item) => item.id == 'morale:1',
      );
      expect(preempt.deadline, complete.triggerTime);
      expect(task.targetEpochMs, preempt.deadline!.millisecondsSinceEpoch);
    },
  );

  test(
    'hidden ongoing notifications retain task deadlines for preempt validation',
    () async {
      final now = DateTime.utc(2026, 10, 28, 12);
      final deadline = now.add(const Duration(minutes: 30));
      final controller = GameStateController(
        initialState: _tasks(now, deadline),
      );
      final settings = NotificationSettingsController(
        store: _MemorySettingsStore(),
        initialSettings: const NotificationSettings(
          ongoingLive: false,
          expeditionPreemptSeconds: 60,
          repairPreemptSeconds: 60,
          constructionPreemptSeconds: 60,
          moralePreemptSeconds: 60,
        ),
      );
      final port = FakeNotificationPort();
      final coordinator = GameNotificationCoordinator(
        gameStateController: controller,
        settingsController: settings,
        notificationPort: port,
        nowProvider: () => now,
      );
      addTearDown(coordinator.dispose);
      addTearDown(controller.dispose);
      addTearDown(settings.dispose);
      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      final snapshot = port.latestSnapshot!;
      expect(snapshot.presentation.ongoingLive, isFalse);
      _expectPreemptContract(snapshot, 60);
      expect(snapshot.ongoingItems, hasLength(4));
      for (final alarm in snapshot.alarms.where(
        (alarm) => alarm.stage == NotificationAlarmStage.preempt,
      )) {
        final task = snapshot.ongoingItems.singleWhere(
          (item) => item.id == alarm.taskId,
        );
        expect(task.state, OngoingTaskState.running);
        expect(task.targetEpochMs, alarm.deadline!.millisecondsSinceEpoch);
      }
      await settings.setMaster(false);
      await Future<void>.delayed(Duration.zero);
      expect(port.latestSnapshot!.presentation.enabled, isFalse);
      expect(port.latestSnapshot!.alarms, isEmpty);
      expect(port.latestSnapshot!.ongoingItems, isEmpty);
    },
  );

  test(
    'preempt templates preserve literal countdown tokens in task names',
    () async {
      final now = DateTime.utc(2026, 10, 28, 12);
      const name = 'Fleet {seconds}/{secondsText}/{{}} 60';
      const escapedName = 'Fleet {{seconds}}/{{secondsText}}/{{{{}}}} 60';
      final initial = _tasks(now, now.add(const Duration(minutes: 30)));
      final state = initial.copyWith(
        masterMissions: const {
          60: MasterMission(id: 60, name: name, duration: Duration(hours: 1)),
        },
        masterShips: const {1: MasterShip(id: 1, name: name, shipTypeId: 2)},
        fleets: [
          const Fleet(id: 1, name: name, shipIds: [1]),
          Fleet(id: 2, name: name, mission: initial.fleets.last.mission),
        ],
      );
      final controller = GameStateController(initialState: state);
      final settings = NotificationSettingsController(
        store: _MemorySettingsStore(),
        initialSettings: const NotificationSettings(
          expeditionPreemptSeconds: 60,
          repairPreemptSeconds: 60,
          constructionPreemptSeconds: 60,
          moralePreemptSeconds: 60,
        ),
      );
      final port = FakeNotificationPort();
      final coordinator = GameNotificationCoordinator(
        gameStateController: controller,
        settingsController: settings,
        notificationPort: port,
        nowProvider: () => now,
        localeCodeProvider: () => 'en',
      );
      addTearDown(coordinator.dispose);
      addTearDown(controller.dispose);
      addTearDown(settings.dispose);
      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      final expectedBodies = {
        'expedition_2_preempt': '$name returns to port in 60 seconds.',
        'repair_1_preempt': '$name finishes repairs in 60 seconds.',
        'construction_1_preempt': '$name finishes construction in 60 seconds.',
        'morale_1_normal_preempt':
            'All ships in $name recover to morale 49 in 60 seconds.',
      };
      for (final entry in expectedBodies.entries) {
        final alarm = port.scheduledAlarms[entry.key]!;
        expect(alarm.body, entry.value);
        expect(alarm.bodyTemplate, contains(escapedName));
      }
    },
  );

  test(
    'preempt schema keeps deadlines and templates across settings and locales',
    () async {
      final now = DateTime.utc(2026, 10, 28, 12);
      final deadline = now.add(const Duration(minutes: 30));
      final controller = GameStateController(
        initialState: _tasks(now, deadline),
      );
      final settings = NotificationSettingsController(
        store: _MemorySettingsStore(),
      );
      final locale = ValueNotifier('zh');
      final port = FakeNotificationPort();
      final coordinator = GameNotificationCoordinator(
        gameStateController: controller,
        settingsController: settings,
        notificationPort: port,
        nowProvider: () => now,
        localeCodeProvider: () => locale.value,
        localeListenable: locale,
      );
      addTearDown(coordinator.dispose);
      addTearDown(controller.dispose);
      addTearDown(settings.dispose);
      addTearDown(locale.dispose);
      coordinator.start();
      for (final seconds in [30, 60, 0, 60]) {
        await settings.setExpeditionPreemptSeconds(seconds);
        await settings.setRepairPreemptSeconds(seconds);
        await settings.setConstructionPreemptSeconds(seconds);
        await settings.setMoralePreemptSeconds(seconds);
        for (final code in ['zh', 'zh_Hant', 'ja', 'ko', 'en']) {
          locale.value = code;
          await Future<void>.delayed(Duration.zero);
          _expectPreemptContract(port.latestSnapshot!, seconds);
        }
      }
    },
  );

  test(
    'Nosaki preempt carries the same completion deadline and preserves morale 54',
    () async {
      final now = DateTime.utc(2026, 10, 28, 12);
      final initial = buildNosakiTestState(companionConds: [49, 54]);
      const name = 'Fleet {seconds}/{secondsText}/{{}} 60';
      final state = initial.copyWith(
        fleets: [
          Fleet(id: 1, name: name, shipIds: initial.fleets.single.shipIds),
        ],
      );
      final controller = GameStateController(initialState: state);
      final settings = NotificationSettingsController(
        store: _MemorySettingsStore(),
        initialSettings: const NotificationSettings(moralePreemptSeconds: 60),
      );
      final port = FakeNotificationPort();
      final coordinator = GameNotificationCoordinator(
        gameStateController: controller,
        settingsController: settings,
        notificationPort: port,
        nowProvider: () => now,
        nosakiSparkleStartedAtProvider: () => now,
        localeCodeProvider: () => 'en',
      );
      addTearDown(coordinator.dispose);
      addTearDown(controller.dispose);
      addTearDown(settings.dispose);
      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      final preempt = port.scheduledAlarms['morale_1_nosaki_preempt']!;
      final complete = port.scheduledAlarms['morale_1_nosaki']!;
      expect(
        preempt.toMap()['deadlineEpochMs'],
        complete.triggerTime.millisecondsSinceEpoch,
      );
      expect(
        preempt.toMap()['bodyTemplate'],
        contains('morale 54 in {secondsText}'),
      );
      expect(preempt.body, contains('morale 54 in 60 seconds'));
      expect(preempt.body, contains(name));
    },
  );
}
