import 'dart:collection';
import 'dart:convert';

import '../browser/game_load_event.dart';
import 'diagnostic_privacy_policy.dart';

enum DiagnosticOutcome { success, failure, skipped }

enum DiagnosticLifecycleState {
  started,
  resumed,
  inactive,
  hidden,
  paused,
  stopped,
  lowMemory,
}

enum DiagnosticComponent { application, capture, database, platform, webView }

enum DiagnosticErrorCode {
  operationFailed,
  decodeFailed,
  platformUnavailable,
  webViewLoadFailed,
  renderProcessGone,
}

enum DiagnosticWebViewHost { flutterPlatformView, activityDirect, absent }

enum DiagnosticGameRenderer { webgl, canvas, unknown }

final class DiagnosticEvent {
  DiagnosticEvent._({
    required this.occurredAt,
    required this.type,
    required Map<String, Object?> fields,
  }) : fields = UnmodifiableMapView<String, Object?>(fields) {
    _policy.validateField('type', type);
    _policy.validateRecord(fields);
  }

  static final DiagnosticPrivacyPolicy _policy = DiagnosticPrivacyPolicy.v1();

  final DateTime occurredAt;
  final String type;
  final Map<String, Object?> fields;

  factory DiagnosticEvent.kanxy({
    required DateTime occurredAt,
    required DiagnosticKanxyStatus status,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'kanxy',
    fields: <String, Object?>{'status': status.wireName},
  );

  factory DiagnosticEvent.gameLoad({
    required DateTime occurredAt,
    required GameLoadEvent event,
    required DiagnosticWebViewHost webViewHost,
    required String renderingMode,
    int? generationId,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'gameLoad',
    fields: <String, Object?>{
      ...event.toMap(),
      'webViewHost': webViewHost.name,
      'renderingMode': renderingMode,
      'generationId': ?generationId,
    },
  );

  factory DiagnosticEvent.lifecycle({
    required DateTime occurredAt,
    required DiagnosticLifecycleState state,
    required int uptimeMs,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'lifecycle',
    fields: <String, Object?>{'state': state.name, 'uptimeMs': uptimeMs},
  );

  factory DiagnosticEvent.slowApi({
    required DateTime occurredAt,
    required String path,
    required int responseBytes,
    required int queueWaitMicros,
    required int decodeMicros,
    required int dispatchMicros,
    required DiagnosticOutcome outcome,
    required bool usedSynchronousFallback,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'apiSlow',
    fields: <String, Object?>{
      'path': _policy.safeApiPath(path),
      'responseBytes': responseBytes,
      'queueWaitMicros': queueWaitMicros,
      'decodeMicros': decodeMicros,
      'dispatchMicros': dispatchMicros,
      'outcome': outcome.name,
      'usedSynchronousFallback': usedSynchronousFallback,
    },
  );

  factory DiagnosticEvent.fixedError({
    required DateTime occurredAt,
    required DiagnosticComponent component,
    required String errorType,
    required DiagnosticErrorCode code,
    StackTrace? stack,
    String? renderingMode,
    DiagnosticWebViewHost? webViewHost,
    DiagnosticGameRenderer? renderer,
    int? generationId,
    DiagnosticLifecycleState? lifecycle,
    int? pssKb,
    int? graphicsKb,
    int? privateOtherKb,
    int? systemAvailableKb,
    bool? lowMemory,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'fixedError',
    fields: <String, Object?>{
      'component': component.name,
      'errorType': errorType,
      'code': code.name,
      'stack': _policy.safeStack(stack),
      'renderingMode': ?renderingMode,
      'webViewHost': ?webViewHost?.name,
      'renderer': ?renderer?.name,
      'generationId': ?generationId,
      'lifecycle': ?lifecycle?.name,
      'pssKb': ?pssKb,
      'graphicsKb': ?graphicsKb,
      'privateOtherKb': ?privateOtherKb,
      'systemAvailableKb': ?systemAvailableKb,
      'lowMemory': ?lowMemory,
    },
  );

  factory DiagnosticEvent.startupSnapshot({
    required DateTime occurredAt,
    required int uptimeMs,
    required String previousExitReason,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'startupSnapshot',
    fields: <String, Object?>{
      'uptimeMs': uptimeMs,
      'previousExitReason': previousExitReason,
    },
  );

  factory DiagnosticEvent.performanceSample({
    required DateTime occurredAt,
    required int uptimeMs,
    required int pssKb,
    required int javaHeapKb,
    required int nativeHeapKb,
    required int graphicsKb,
    required int privateOtherKb,
    required int systemAvailableKb,
    required DiagnosticWebViewHost webViewHost,
    required DiagnosticGameRenderer renderer,
    required int generationId,
    required int totalFrames,
    required int over16Ms,
    required int over33Ms,
    required int over100Ms,
    required int maxFrameMicros,
    required int pendingApiEvents,
    required String? activeApiPath,
    required int backgroundDecodeFallbacks,
    required int databaseBytes,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'performanceSample',
    fields: <String, Object?>{
      'uptimeMs': uptimeMs,
      'pssKb': pssKb,
      'javaHeapKb': javaHeapKb,
      'nativeHeapKb': nativeHeapKb,
      'graphicsKb': graphicsKb,
      'privateOtherKb': privateOtherKb,
      'systemAvailableKb': systemAvailableKb,
      'webViewHost': webViewHost.name,
      'renderer': renderer.name,
      'generationId': generationId,
      'totalFrames': totalFrames,
      'over16Ms': over16Ms,
      'over33Ms': over33Ms,
      'over100Ms': over100Ms,
      'maxFrameMicros': maxFrameMicros,
      'pendingApiEvents': pendingApiEvents,
      'activeApiPath': activeApiPath == null
          ? null
          : _policy.safeApiPath(activeApiPath),
      'backgroundDecodeFallbacks': backgroundDecodeFallbacks,
      'databaseBytes': databaseBytes,
    },
  );

  factory DiagnosticEvent.webViewState({
    required DateTime occurredAt,
    required String state,
    required int durationMs,
    int? errorCode,
  }) => DiagnosticEvent._(
    occurredAt: occurredAt.toUtc(),
    type: 'webViewState',
    fields: <String, Object?>{
      'state': state,
      'durationMs': durationMs,
      'errorCode': ?errorCode,
    },
  );

  factory DiagnosticEvent.gameLoopSample({
    required DateTime occurredAt,
    required Map<Object?, Object?> snapshot,
  }) {
    final fresh = snapshot['fresh'] == true;
    final raw = snapshot['sample'];
    final sample = fresh && raw is Map ? raw : const <Object?, Object?>{};
    num? number(Object? value) =>
        value is num && value.isFinite && value >= 0 ? value : null;
    final target = sample['target'];
    return DiagnosticEvent._(
      occurredAt: occurredAt.toUtc(),
      type: 'gameLoopSample',
      fields: <String, Object?>{
        'fresh': fresh,
        'sampleAgeMs': number(snapshot['sampleAgeMs']),
        'target': const ['fps30', 'fps60', 'highRefresh'].contains(target)
            ? target
            : null,
        'visible': sample['visible'] is bool ? sample['visible'] : null,
        'gameFps': number(sample['fps']),
        'gameRenderFps': number(sample['renderFps']),
        'rafFps': number(sample['rafFps']),
        'configuredFps': number(sample['configuredFps']),
      },
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'occurredAt': occurredAt.toIso8601String(),
    'type': type,
    'fields': fields,
  };

  int get estimatedEncodedBytes => utf8.encode(jsonEncode(toJson())).length + 1;
}
