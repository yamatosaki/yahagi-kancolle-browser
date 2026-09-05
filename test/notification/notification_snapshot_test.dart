import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_models.dart';

void main() {
  test('notification snapshot serializes the complete native state', () {
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
    final target = DateTime.fromMillisecondsSinceEpoch(1_700_000_600_000);
    final snapshot = NotificationSnapshot(
      updatedAt: updatedAt,
      immediateAlerts: [
        ImmediateNotificationItem(
          key: 'construction:1:manual:1700000000000',
          taskId: 'construction:1',
          type: GameNotificationType.construction,
          occurredAt: updatedAt,
          deadline: target,
          title: 'Construction complete',
          body: 'Dock 1 is ready',
        ),
      ],
      alarms: [
        ScheduledNotificationItem(
          key: 'expedition:2:complete',
          taskId: 'expedition:2',
          type: GameNotificationType.expedition,
          stage: NotificationAlarmStage.complete,
          removeTaskOnFire: true,
          triggerTime: target,
          title: 'Expedition complete',
          body: 'Fleet 2 has returned',
        ),
      ],
      ongoingItems: [
        OngoingTaskItem(
          id: 'expedition:2',
          type: GameNotificationType.expedition,
          title: 'Fleet 2 · Mission 5',
          state: OngoingTaskState.completed,
          clockMode: OngoingClockMode.countdown,
          progress: 0.5,
          remainingSeconds: 600,
          targetEpochMs: target.millisecondsSinceEpoch,
          totalDurationSec: 1200,
        ),
      ],
      presentation: const NotificationPresentation(
        enabled: true,
        sound: false,
        vibration: true,
        showProgress: true,
        showPercent: false,
        showCountdown: true,
        ongoingLive: true,
      ),
    );

    expect(snapshot.toMap(), {
      'schemaVersion': 1,
      'updatedAtEpochMs': updatedAt.millisecondsSinceEpoch,
      'immediateAlerts': [
        {
          'key': 'construction:1:manual:1700000000000',
          'taskId': 'construction:1',
          'type': 'construction',
          'occurredAtEpochMs': updatedAt.millisecondsSinceEpoch,
          'deadlineEpochMs': target.millisecondsSinceEpoch,
          'title': 'Construction complete',
          'body': 'Dock 1 is ready',
        },
      ],
      'alarms': [
        {
          'key': 'expedition:2:complete',
          'taskId': 'expedition:2',
          'type': 'expedition',
          'stage': 'complete',
          'removeTaskOnFire': true,
          'triggerTimeEpochMs': target.millisecondsSinceEpoch,
          'title': 'Expedition complete',
          'body': 'Fleet 2 has returned',
        },
      ],
      'ongoingItems': [
        {
          'id': 'expedition:2',
          'type': 'expedition',
          'title': 'Fleet 2 · Mission 5',
          'state': 'completed',
          'clockMode': 'countdown',
          'anchorEpochMs': null,
          'progress': 0.5,
          'remainingSeconds': 600,
          'targetEpochMs': target.millisecondsSinceEpoch,
          'totalDurationSec': 1200,
        },
      ],
      'presentation': {
        'localeCode': 'zh',
        'enabled': true,
        'sound': false,
        'vibration': true,
        'showProgress': true,
        'showPercent': false,
        'showCountdown': true,
        'ongoingLive': true,
      },
    });
  });

  test('platform result and capabilities decode defensive native maps', () {
    expect(
      NotificationApplyResult.fromMap({
        'scheduledExact': 2,
        'scheduledInexact': 1,
        'canceled': 3,
        'failures': ['bad-key'],
      }),
      const NotificationApplyResult(
        scheduledExact: 2,
        scheduledInexact: 1,
        canceled: 3,
        failures: ['bad-key'],
      ),
    );

    expect(
      NotificationPlatformCapabilities.fromMap({
        'notificationsGranted': true,
        'exactAlarmsGranted': false,
        'channelsEnabled': true,
      }),
      const NotificationPlatformCapabilities(
        notificationsGranted: true,
        exactAlarmsGranted: false,
        channelsEnabled: true,
      ),
    );
  });
}
