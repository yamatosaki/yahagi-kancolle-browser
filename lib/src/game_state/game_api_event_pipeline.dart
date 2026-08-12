import 'dart:isolate';

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

final class GameApiEventPipeline {
  GameApiEventPipeline({
    required List<GameApiEventConsumer> consumers,
    GameApiEnvelopeDecoder? decodeEnvelope,
    GameApiSyncEnvelopeDecoder? decodeSmallEnvelope,
    this.backgroundThresholdBytes = 64 * 1024,
  }) : assert(backgroundThresholdBytes > 0),
       _consumers = List<GameApiEventConsumer>.unmodifiable(consumers),
       _decodeEnvelope = decodeEnvelope ?? _decodeInBackground,
       _decodeSmallEnvelope =
           decodeSmallEnvelope ?? GameApiDecoder.decodeEnvelope;

  final List<GameApiEventConsumer> _consumers;
  final GameApiEnvelopeDecoder _decodeEnvelope;
  final GameApiSyncEnvelopeDecoder _decodeSmallEnvelope;
  final int backgroundThresholdBytes;
  Future<void> _queue = Future<void>.value();

  void add(CapturedApiEvent event) {
    _queue = _queue.then(
      (_) => _prepareAndDispatch(event),
      onError: (_) => _prepareAndDispatch(event),
    );
  }

  Future<void> get idle async {
    await _queue;
    await Future.wait<void>(<Future<void>>[
      for (final consumer in _consumers) consumer.idle,
    ]);
  }

  Future<void> _prepareAndDispatch(CapturedApiEvent event) async {
    final consumers = <GameApiEventConsumer>[
      for (final consumer in _consumers)
        if (consumer.supportsPath(event.path)) consumer,
    ];
    if (consumers.isEmpty) return;

    var prepared = event;
    if (!event.hasDecodedEnvelope) {
      try {
        prepared = event.withDecodedEnvelope(
          _shouldDecodeInBackground(event)
              ? await _decodeEnvelope(event.responseBody)
              : _decodeSmallEnvelope(event.responseBody),
        );
      } catch (_) {
        // Preserve the established controller error path for invalid responses.
      }
    }

    for (final consumer in consumers) {
      consumer.accept(prepared);
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
