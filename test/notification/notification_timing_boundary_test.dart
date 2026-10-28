import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_progress.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notification/game_notification_coordinator.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_port.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';

// Only the platform boundary is replaced. This fake stores snapshots and can
// delay their acknowledgement/application; it does not simulate AlarmManager,
// Android notification delivery, PendingIntent identity, or battery restrictions.
class RecordingNotificationPort implements NotificationPort {
  NotificationSnapshot? applied;
  final requested = <NotificationSnapshot>[];
  Completer<void>? applyGate;

  ScheduledNotificationItem? alarm(String key) {
    for (final alarm in applied?.alarms ?? <ScheduledNotificationItem>[]) {
      if (alarm.key == key) return alarm;
    }
    return null;
  }

  @override
  Future<NotificationApplyResult> applySnapshot(
    NotificationSnapshot snapshot,
  ) async {
    requested.add(snapshot);
    final gate = applyGate;
    if (gate != null) await gate.future;
    applied = snapshot;
    return const NotificationApplyResult(
      scheduledExact: 0,
      scheduledInexact: 0,
      canceled: 0,
      failures: [],
    );
  }

  @override
  Future<NotificationPlatformCapabilities> getCapabilities() async =>
      const NotificationPlatformCapabilities(
        notificationsGranted: true,
        exactAlarmsGranted: true,
        channelsEnabled: true,
      );

  @override
  Future<void> openSystemNotificationSettings() async {}
  @override
  Future<void> requestExactAlarmPermission() async {}
  @override
  Future<bool> requestNotificationPermission() async => true;
}

class MemorySettingsStore implements NotificationSettingsStore {
  NotificationSettings value = const NotificationSettings(
    repair: false,
    construction: false,
    anchorage: false,
    morale: false,
  );
  @override
  Future<NotificationSettings> load() async => value;
  @override
  Future<void> save(NotificationSettings settings) async => value = settings;
}

DateTime sampleTime(int hour, int minute, [int second = 0]) => DateTime.parse(
  '2026-10-28T${hour.toString().padLeft(2, '0')}:'
  '${minute.toString().padLeft(2, '0')}:'
  '${second.toString().padLeft(2, '0')}+09:00',
).toUtc();

GameState expeditionState(DateTime deadline) => GameState(
  masterMissions: const {
    100: MasterMission(
      id: 100,
      name: '海峡警備行動',
      duration: Duration(minutes: 55),
    ),
  },
  fleets: [
    Fleet(
      id: 2,
      name: '第二舰队',
      mission: FleetMission(state: 1, missionId: 100, completionTime: deadline),
    ),
  ],
);

CapturedApiEvent fleetRefresh(DateTime? deadline, DateTime capturedAt) =>
    CapturedApiEvent(
      path: '/kcsapi/api_get_member/deck',
      responseBody: jsonEncode({
        'api_result': 1,
        'api_data': [
          {
            'api_id': 2,
            'api_name': '第二舰队',
            'api_ship': <int>[],
            'api_mission': [
              if (deadline == null) ...[
                0,
                0,
                0,
              ] else ...[
                1,
                100,
                deadline.millisecondsSinceEpoch,
              ],
            ],
          },
        ],
      }),
      source: CaptureSource.xhr,
      capturedAt: capturedAt,
    );

class AuditHarness {
  AuditHarness(DateTime initialNow, DateTime deadline) : now = initialNow {
    controller = GameStateController(initialState: expeditionState(deadline));
    final store = MemorySettingsStore();
    settings = NotificationSettingsController(
      store: store,
      initialSettings: store.value,
    );
    coordinator = GameNotificationCoordinator(
      gameStateController: controller,
      settingsController: settings,
      notificationPort: port,
      nowProvider: () => now,
    )..start();
  }

  DateTime now;
  final port = RecordingNotificationPort();
  late final GameStateController controller;
  late final NotificationSettingsController settings;
  late final GameNotificationCoordinator coordinator;

  DateTime get stateDeadline =>
      controller.state.fleets.single.mission.completionTime!;

  Widget page() => MaterialApp(
    home: SecondTickScope(
      now: () => now,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => OperationCountdownText(
            completionTime:
                controller.state.fleets.single.mission.completionTime,
            completedText: 'completed',
          ),
        ),
      ),
    ),
  );

  Future<void> refresh(DateTime? deadline) async {
    controller.accept(fleetRefresh(deadline, now));
    await controller.idle;
  }

  Future<void> dispose(WidgetTester tester) async {
    port.applyGate?.complete();
    port.applyGate = null;
    coordinator.dispose();
    controller.dispose();
    settings.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.resetInternalState();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GameStateController.disableTimerForTest = true;
    binding.resetInternalState();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  tearDown(() => GameStateController.disableTimerForTest = false);

  testWidgets(
    'paused lifecycle synchronizes a committed deadline without a render frame',
    (tester) async {
      final oldDeadline = sampleTime(16, 10, 19);
      final newDeadline = sampleTime(16, 13);
      final harness = AuditHarness(sampleTime(16, 8, 19), oldDeadline);
      try {
        await tester.pumpWidget(harness.page());
        // Drain the MaterialApp's already requested follow-up frame before
        // pausing. WidgetTester.pump can force a previously requested frame
        // even when the real engine would no longer produce frames.
        await tester.pump();
        expect(binding.hasScheduledFrame, isFalse);
        expect(find.text('00:02:00'), findsOneWidget);
        final originalApplyCount = harness.port.requested.length;

        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(binding.framesEnabled, isFalse);
        harness.now = sampleTime(16, 9, 19);
        await harness.refresh(newDeadline);
        expect(binding.hasScheduledFrame, isFalse);
        await tester.pump(const Duration(seconds: 1));

        expect(binding.framesEnabled, isFalse);
        expect(harness.stateDeadline, newDeadline);
        expect(harness.port.requested.length, originalApplyCount + 1);
        expect(
          harness.port.alarm('expedition_2_preempt')!.triggerTime,
          sampleTime(16, 12),
        );
        expect(
          formatOperationDuration(newDeadline.difference(harness.now)),
          '00:03:41',
        );
        // The visible widget has also not received the deferred state broadcast.
        expect(find.text('00:02:00'), findsOneWidget);
        expect(find.text('00:03:41'), findsNothing);

        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        expect(binding.framesEnabled, isTrue);
        await tester.pump();
        expect(find.text('00:03:41'), findsOneWidget);
        expect(
          harness.port.alarm('expedition_2_preempt')!.triggerTime,
          sampleTime(16, 12),
        );
        expect(harness.port.requested.length, originalApplyCount + 1);
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets(
    '221 second rendered countdown and due old 60 second alert coexist only with delayed fake native apply',
    (tester) async {
      final harness = AuditHarness(
        sampleTime(16, 8, 19),
        sampleTime(16, 10, 19),
      );
      try {
        await tester.pumpWidget(harness.page());
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        harness.now = sampleTime(16, 9, 19);
        harness.port.applyGate = Completer<void>();
        await harness.refresh(sampleTime(16, 13));

        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(find.text('00:03:41'), findsOneWidget);
        final retained = harness.port.alarm('expedition_2_preempt')!;
        expect(retained.triggerTime, harness.now);
        expect(retained.body, contains('还有 60 秒'));
        expect(
          harness.port.requested.last.alarms
              .singleWhere((alarm) => alarm.key == 'expedition_2_preempt')
              .triggerTime,
          sampleTime(16, 12),
        );
        expect(retained.deadline, sampleTime(16, 10, 19));
        expect(retained.bodyTemplate, contains('{seconds}'));

        harness.port.applyGate!.complete();
        harness.port.applyGate = null;
        await tester.pump();
        expect(
          harness.port.alarm('expedition_2_preempt')!.triggerTime,
          sampleTime(16, 12),
        );
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets('same fleet deadline change replaces both desired alarms', (
    tester,
  ) async {
    final harness = AuditHarness(sampleTime(16, 9, 19), sampleTime(16, 13));
    try {
      await tester.pumpWidget(harness.page());
      await harness.refresh(sampleTime(16, 15, 40));
      await tester.pump();
      expect(harness.port.applied!.alarms.map((alarm) => alarm.key).toSet(), {
        'expedition_2_preempt',
        'expedition_2_complete',
      });
      expect(
        harness.port.alarm('expedition_2_preempt')!.triggerTime,
        sampleTime(16, 14, 40),
      );
      expect(
        harness.port.alarm('expedition_2_complete')!.triggerTime,
        sampleTime(16, 15, 40),
      );
      expect(
        harness.port.alarm('expedition_2_preempt')!.deadline,
        sampleTime(16, 15, 40),
      );
      expect(
        harness.port.applied!.ongoingItems.single.targetEpochMs,
        sampleTime(16, 15, 40).millisecondsSinceEpoch,
      );
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets(
    'clearing the fleet mission removes desired alarms and ongoing task',
    (tester) async {
      final harness = AuditHarness(sampleTime(16, 9, 19), sampleTime(16, 13));
      try {
        await tester.pumpWidget(harness.page());
        await harness.refresh(null);
        await tester.pump();
        expect(
          harness.controller.state.fleets.single.mission.isActive,
          isFalse,
        );
        expect(harness.port.applied!.alarms, isEmpty);
        expect(harness.port.applied!.ongoingItems, isEmpty);
        // This checks desired snapshot state, not Android's already posted cards.
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets('60 then 30 then zero then 60 updates preempt settings live', (
    tester,
  ) async {
    final deadline = sampleTime(16, 13);
    final harness = AuditHarness(sampleTime(16, 9, 19), deadline);
    try {
      await tester.pumpWidget(harness.page());
      for (final seconds in [60, 30, 0, 60]) {
        await harness.settings.setExpeditionPreemptSeconds(seconds);
        await tester.pump();
        final preempt = harness.port.alarm('expedition_2_preempt');
        if (seconds == 0) {
          expect(preempt, isNull);
        } else {
          expect(
            preempt!.triggerTime,
            deadline.subtract(Duration(seconds: seconds)),
          );
          expect(preempt.body, contains('还有 $seconds 秒'));
          expect(preempt.deadline, deadline);
          expect(preempt.bodyTemplate, contains('还有 {seconds} 秒'));
        }
        expect(
          harness.port.alarm('expedition_2_complete')!.triggerTime,
          deadline,
        );
      }
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets(
    'shared UI clock catches up from 221 to 60 seconds after background',
    (tester) async {
      final harness = AuditHarness(sampleTime(16, 9, 19), sampleTime(16, 13));
      try {
        await tester.pumpWidget(harness.page());
        expect(find.text('00:03:41'), findsOneWidget);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        harness.now = sampleTime(16, 12);
        await tester.pump(const Duration(seconds: 161));
        expect(find.text('00:03:41'), findsOneWidget);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        expect(find.text('00:01:00'), findsOneWidget);
        expect(
          harness.port.alarm('expedition_2_preempt')!.triggerTime,
          harness.now,
        );
      } finally {
        await harness.dispose(tester);
      }
    },
  );
}
