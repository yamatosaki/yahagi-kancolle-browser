import 'dart:async';
import 'dart:isolate';
import 'dart:convert';

import '../bridge/captured_api_event.dart';
import 'game_api_decoder.dart';

typedef GameApiEnvelopeDecoder =
    Future<Map<String, Object?>> Function(String responseBody);
typedef GameApiSyncEnvelopeDecoder =
    Map<String, Object?> Function(String responseBody);

abstract interface class GameApiEventConsumer {
  bool supportsPath(String path);

  void accept(CapturedApiEvent event);

  Future<void> get idle;
}

final class GameApiTiming {
  const GameApiTiming({
    required this.path,
    required this.responseBytes,
    required this.queueDepth,
    required this.queueWaitMicros,
    required this.decodeMicros,
    required this.dispatchMicros,
    required this.success,
    required this.usedSynchronousFallback,
  });

  final String path;
  final int responseBytes;
  final int queueDepth;
  final int queueWaitMicros;
  final int decodeMicros;
  final int dispatchMicros;
  final bool success;
  final bool usedSynchronousFallback;
}

abstract interface class GameApiPipelineObserver {
  void onCompleted(GameApiTiming timing);
}

final class GameApiEventPipeline {
  GameApiEventPipeline({
    required List<GameApiEventConsumer> consumers,
    GameApiEnvelopeDecoder? decodeEnvelope,
    GameApiSyncEnvelopeDecoder? decodeSmallEnvelope,
    this.observer,
    this.backgroundThresholdBytes = 64 * 1024,
    this.backgroundDecodeTimeout = const Duration(seconds: 5),
    this.onBackgroundDecodeFallback,
    this.settleGameState,
  }) : assert(backgroundThresholdBytes > 0),
       assert(backgroundDecodeTimeout > Duration.zero),
       _consumers = List<GameApiEventConsumer>.unmodifiable(consumers),
       _decodeEnvelope = decodeEnvelope ?? _decodeInBackground,
       _decodeSmallEnvelope =
           decodeSmallEnvelope ?? GameApiDecoder.decodeEnvelope;

  final List<GameApiEventConsumer> _consumers;
  final GameApiEnvelopeDecoder _decodeEnvelope;
  final GameApiSyncEnvelopeDecoder _decodeSmallEnvelope;
  final int backgroundThresholdBytes;
  final Duration backgroundDecodeTimeout;
  final void Function(String path)? onBackgroundDecodeFallback;

  /// Completes the core reducer -> prediction -> HP writeback transaction.
  /// Deliberately excludes independent database/download/report queues.
  final Future<void> Function()? settleGameState;
  GameApiPipelineObserver? observer;
  Future<void> _queue = Future<void>.value();
  int _pendingEventCount = 0;
  String? _activePath;
  int _backgroundFallbackCount = 0;
  int _sessionGeneration = 0;
  bool _awaitingLoginStart = false;
  String? _activeDocumentId;
  double? _activeDocumentStartedAt;
  final Set<String> _retiredDocumentIds = {};

  /// Called before leaving a login session, including while decoding an event.
  void invalidatePendingEvents({bool waitForLoginStart = false}) {
    _sessionGeneration++;
    _awaitingLoginStart = waitForLoginStart;
    _activeDocumentId = null;
    _activeDocumentStartedAt = null;
    _retiredDocumentIds.clear();
  }

  bool _acceptDocument(CapturedApiEvent event) {
    final documentId = event.captureDocumentId;
    final startedAt = event.captureDocumentStartedAtEpochMs;
    if (documentId == _activeDocumentId) return true;
    if (documentId == null || startedAt == null) {
      return _activeDocumentId == null;
    }
    if (event.path != '/kcsapi/api_start2/getData' || event.apiResult != 1) {
      return _activeDocumentId == null;
    }
    // A late response from an older game document must not restart that login.
    if (_retiredDocumentIds.contains(documentId) ||
        (_activeDocumentStartedAt != null &&
            startedAt <= _activeDocumentStartedAt!)) {
      return false;
    }
    if (_activeDocumentId case final previous?) {
      _retiredDocumentIds.add(previous);
      if (_retiredDocumentIds.length > 64) {
        _retiredDocumentIds.remove(_retiredDocumentIds.first);
      }
    }
    _activeDocumentId = documentId;
    _activeDocumentStartedAt = startedAt;
    return true;
  }

  int get pendingEventCount => _pendingEventCount;
  String? get activePath => _activePath;
  int get backgroundFallbackCount => _backgroundFallbackCount;

  /// For side effects that run after awaiting this pipeline's dispatch queue.
  bool isCurrentDocument(CapturedApiEvent event) =>
      !_awaitingLoginStart &&
      (_activeDocumentId == null ||
          event.captureDocumentId == _activeDocumentId);

  void add(CapturedApiEvent event) {
    final generation = _sessionGeneration;
    _pendingEventCount += 1;
    final queueDepth = _pendingEventCount;
    final queued = Stopwatch()..start();
    final currentObserver = observer;
    _queue = _queue.then(
      (_) => _prepareDispatchAndObserve(
        event,
        currentObserver,
        queued,
        queueDepth,
        generation,
      ),
      onError: (_) => _prepareDispatchAndObserve(
        event,
        currentObserver,
        queued,
        queueDepth,
        generation,
      ),
    );
  }

  Future<void> _prepareDispatchAndObserve(
    CapturedApiEvent event,
    GameApiPipelineObserver? target,
    Stopwatch queued,
    int queueDepth,
    int generation,
  ) async {
    queued.stop();
    final queueWaitMicros = queued.elapsedMicroseconds;
    var result = (
      decodeMicros: 0,
      dispatchMicros: 0,
      success: false,
      usedSynchronousFallback: false,
    );
    try {
      if (generation == _sessionGeneration) {
        result = await _prepareAndDispatch(event, generation);
      }
    } finally {
      _pendingEventCount -= 1;
      target?.onCompleted(
        GameApiTiming(
          path: event.path,
          responseBytes:
              event.responseByteLength ??
              utf8.encode(event.responseBody).length,
          queueDepth: queueDepth,
          queueWaitMicros: queueWaitMicros,
          decodeMicros: result.decodeMicros,
          dispatchMicros: result.dispatchMicros,
          success: result.success,
          usedSynchronousFallback: result.usedSynchronousFallback,
        ),
      );
    }
  }

  Future<void> get idle async {
    await _queue;
    await Future.wait<void>(<Future<void>>[
      for (final consumer in _consumers) consumer.idle,
    ]);
  }

  /// Waits until every currently queued event has been decoded and dispatched,
  /// without waiting for unrelated asynchronous work owned by consumers.
  Future<void> get dispatchIdle => _queue;

  Future<
    ({
      int decodeMicros,
      int dispatchMicros,
      bool success,
      bool usedSynchronousFallback,
    })
  >
  _prepareAndDispatch(CapturedApiEvent event, int generation) async {
    final consumers = <GameApiEventConsumer>[
      for (final consumer in _consumers)
        if (consumer.supportsPath(event.path)) consumer,
    ];
    if (consumers.isEmpty) {
      return (
        decodeMicros: 0,
        dispatchMicros: 0,
        success: true,
        usedSynchronousFallback: false,
      );
    }

    var prepared = event;
    var success = true;
    var usedSynchronousFallback = false;
    final decodeWatch = Stopwatch()..start();
    _activePath = event.path;
    try {
      if (!event.hasDecodedEnvelope) {
        try {
          Map<String, Object?> envelope;
          if (_shouldDecodeInBackground(event)) {
            try {
              envelope = await _decodeEnvelope(
                event.responseBody,
              ).timeout(backgroundDecodeTimeout);
            } on TimeoutException {
              usedSynchronousFallback = true;
              _backgroundFallbackCount += 1;
              try {
                onBackgroundDecodeFallback?.call(event.path);
              } catch (_) {
                // Observability must never interrupt the game data pipeline.
              }
              envelope = _decodeSmallEnvelope(event.responseBody);
            }
          } else {
            envelope = _decodeSmallEnvelope(event.responseBody);
          }
          prepared = event.withDecodedEnvelope(envelope);
        } catch (_) {
          success = false;
          // Preserve the established controller error path for invalid responses.
        }
      }
      decodeWatch.stop();

      final dispatchWatch = Stopwatch()..start();
      if (generation != _sessionGeneration ||
          (_awaitingLoginStart &&
              (prepared.path != '/kcsapi/api_start2/getData' ||
                  prepared.apiResult != 1)) ||
          (prepared.hasDecodedEnvelope &&
              prepared.decodedEnvelope!['api_result'].toString() != '1') ||
          !_acceptDocument(prepared)) {
        success = false;
      } else {
        _awaitingLoginStart = false;
        for (final consumer in consumers) {
          consumer.accept(prepared);
        }
        await settleGameState?.call();
      }
      dispatchWatch.stop();
      return (
        decodeMicros: decodeWatch.elapsedMicroseconds,
        dispatchMicros: dispatchWatch.elapsedMicroseconds,
        success: success,
        usedSynchronousFallback: usedSynchronousFallback,
      );
    } finally {
      if (decodeWatch.isRunning) decodeWatch.stop();
      _activePath = null;
    }
  }

  bool _shouldDecodeInBackground(CapturedApiEvent event) {
    return event.path == '/kcsapi/api_start2/getData' ||
        event.responseBody.length >= backgroundThresholdBytes;
  }
}

Future<Map<String, Object?>> _decodeInBackground(String responseBody) {
  return Isolate.run(() => GameApiDecoder.decodeEnvelope(responseBody));
}
