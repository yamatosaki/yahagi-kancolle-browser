enum GameNotificationType {
  expedition,
  repair,
  anchorage,
  construction,
  morale,
  newShip;

  String get channelId => 'channel_$name';
}

enum NotificationAlarmStage { preempt, milestone, complete }

enum OngoingTaskState { running, settlementReady, completed }

enum OngoingClockMode { countdown, elapsed }

class ImmediateNotificationItem {
  const ImmediateNotificationItem({
    required this.key,
    this.taskId = '',
    required this.type,
    required this.occurredAt,
    DateTime? deadline,
    required this.title,
    required this.body,
  }) : deadline = deadline ?? occurredAt;

  final String key;
  final String taskId;
  final GameNotificationType type;
  final DateTime occurredAt;
  final DateTime deadline;
  final String title;
  final String body;

  Map<String, Object?> toMap() => {
    'key': key,
    'taskId': taskId,
    'type': type.name,
    'occurredAtEpochMs': occurredAt.millisecondsSinceEpoch,
    'deadlineEpochMs': deadline.millisecondsSinceEpoch,
    'title': title,
    'body': body,
  };
}

class ScheduledNotificationItem {
  const ScheduledNotificationItem({
    required this.key,
    this.taskId = '',
    required this.type,
    this.stage = NotificationAlarmStage.complete,
    this.removeTaskOnFire = false,
    required this.triggerTime,
    required this.title,
    required this.body,
  });

  final String key;
  final String taskId;
  final GameNotificationType type;
  final NotificationAlarmStage stage;
  final bool removeTaskOnFire;
  final DateTime triggerTime;
  final String title;
  final String body;

  Map<String, Object?> toMap() => {
    'key': key,
    'taskId': taskId,
    'type': type.name,
    'stage': stage.name,
    'removeTaskOnFire': removeTaskOnFire,
    'triggerTimeEpochMs': triggerTime.millisecondsSinceEpoch,
    'title': title,
    'body': body,
  };
}

class OngoingTaskItem {
  const OngoingTaskItem({
    required this.id,
    required this.type,
    required this.title,
    this.state = OngoingTaskState.running,
    this.clockMode = OngoingClockMode.countdown,
    this.anchorEpochMs,
    required this.progress,
    required this.remainingSeconds,
    this.targetEpochMs,
    this.totalDurationSec,
  });

  final String id;
  final GameNotificationType type;
  final String title;
  final OngoingTaskState state;
  final OngoingClockMode clockMode;
  final int? anchorEpochMs;
  final double progress; // 0.0 to 1.0
  final int remainingSeconds;
  final int? targetEpochMs;
  final int? totalDurationSec;

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'state': state.name,
    'clockMode': clockMode.name,
    'anchorEpochMs': anchorEpochMs,
    'progress': progress,
    'remainingSeconds': remainingSeconds,
    'targetEpochMs': targetEpochMs,
    'totalDurationSec': totalDurationSec,
  };
}

class NotificationPresentation {
  const NotificationPresentation({
    this.localeCode = 'zh',
    required this.enabled,
    required this.sound,
    required this.vibration,
    required this.showProgress,
    required this.showPercent,
    required this.showCountdown,
    required this.ongoingLive,
  });

  final String localeCode;
  final bool enabled;
  final bool sound;
  final bool vibration;
  final bool showProgress;
  final bool showPercent;
  final bool showCountdown;
  final bool ongoingLive;

  Map<String, Object?> toMap() => {
    'localeCode': localeCode,
    'enabled': enabled,
    'sound': sound,
    'vibration': vibration,
    'showProgress': showProgress,
    'showPercent': showPercent,
    'showCountdown': showCountdown,
    'ongoingLive': ongoingLive,
  };
}

class NotificationSnapshot {
  const NotificationSnapshot({
    this.schemaVersion = 1,
    this.memberId,
    this.sessionId,
    required this.updatedAt,
    this.immediateAlerts = const [],
    required this.alarms,
    required this.ongoingItems,
    required this.presentation,
  });

  final int schemaVersion;
  final int? memberId;
  final String? sessionId;
  final DateTime updatedAt;
  final List<ImmediateNotificationItem> immediateAlerts;
  final List<ScheduledNotificationItem> alarms;
  final List<OngoingTaskItem> ongoingItems;
  final NotificationPresentation presentation;

  Map<String, Object?> toMap() => {
    'schemaVersion': schemaVersion,
    if (memberId != null) 'memberId': memberId,
    if (sessionId != null) 'sessionId': sessionId,
    'updatedAtEpochMs': updatedAt.millisecondsSinceEpoch,
    'immediateAlerts': immediateAlerts.map((item) => item.toMap()).toList(),
    'alarms': alarms.map((item) => item.toMap()).toList(),
    'ongoingItems': ongoingItems.map((item) => item.toMap()).toList(),
    'presentation': presentation.toMap(),
  };
}

class NotificationApplyResult {
  const NotificationApplyResult({
    required this.scheduledExact,
    required this.scheduledInexact,
    required this.canceled,
    required this.failures,
  });

  factory NotificationApplyResult.fromMap(Map<Object?, Object?> map) {
    final rawFailures = map['failures'];
    return NotificationApplyResult(
      scheduledExact: _intValue(map['scheduledExact']),
      scheduledInexact: _intValue(map['scheduledInexact']),
      canceled: _intValue(map['canceled']),
      failures: rawFailures is List
          ? rawFailures.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  final int scheduledExact;
  final int scheduledInexact;
  final int canceled;
  final List<String> failures;

  @override
  bool operator ==(Object other) =>
      other is NotificationApplyResult &&
      scheduledExact == other.scheduledExact &&
      scheduledInexact == other.scheduledInexact &&
      canceled == other.canceled &&
      _stringListsEqual(failures, other.failures);

  @override
  int get hashCode => Object.hash(
    scheduledExact,
    scheduledInexact,
    canceled,
    Object.hashAll(failures),
  );
}

class NotificationPlatformCapabilities {
  const NotificationPlatformCapabilities({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.channelsEnabled,
  });

  factory NotificationPlatformCapabilities.fromMap(Map<Object?, Object?> map) {
    return NotificationPlatformCapabilities(
      notificationsGranted: map['notificationsGranted'] == true,
      exactAlarmsGranted: map['exactAlarmsGranted'] == true,
      channelsEnabled: map['channelsEnabled'] == true,
    );
  }

  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool channelsEnabled;

  @override
  bool operator ==(Object other) =>
      other is NotificationPlatformCapabilities &&
      notificationsGranted == other.notificationsGranted &&
      exactAlarmsGranted == other.exactAlarmsGranted &&
      channelsEnabled == other.channelsEnabled;

  @override
  int get hashCode =>
      Object.hash(notificationsGranted, exactAlarmsGranted, channelsEnabled);
}

int _intValue(Object? value) => value is num ? value.toInt() : 0;

bool _stringListsEqual(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
