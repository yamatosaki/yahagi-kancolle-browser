import 'dart:convert';
import 'dart:isolate';

import '../bridge/captured_api_event.dart';
import 'game_api_decoder.dart';

typedef GameApiEnvelopeDecoder =
    Future<Map<String, Object?>> Function(String responseBody);

abstract interface class GameApiEventConsumer {
  bool supportsPath(String path);

  void accept(CapturedApiEvent event);

  Future<void> get idle;
}

final class GameApiEventPipeline {
  GameApiEventPipeline({
    required List<GameApiEventConsumer> consumers,
    GameApiEnvelopeDecoder? decodeEnvelope,
    this.backgroundThresholdBytes = 64 * 1024,
  }) : assert(backgroundThresholdBytes > 0),
       _consumers = List<GameApiEventConsumer>.unmodifiable(consumers),
       _decodeEnvelope = decodeEnvelope ?? _decodeInBackground;

  final List<GameApiEventConsumer> _consumers;
  final GameApiEnvelopeDecoder _decodeEnvelope;
  final int backgroundThresholdBytes;
  Future<void> _queue = Future<void>.value();

  void add(CapturedApiEvent event) {
    _queue = _queue.then(
      (_) => _prepareAndDispatch(event),
      onError: (_) => _prepareAndDispatch(event),
    );
  }

  Future<void> get idle => _queue;

  Future<void> _prepareAndDispatch(CapturedApiEvent event) async {
    final consumers = <GameApiEventConsumer>[
      for (final consumer in _consumers)
        if (consumer.supportsPath(event.path)) consumer,
    ];
    if (consumers.isEmpty) return;

    var prepared = event;
    if (_shouldDecode(event)) {
      try {
        prepared = event.withDecodedEnvelope(
          await _decodeEnvelope(event.responseBody),
        );
      } catch (_) {
        // Preserve the established controller error path for invalid responses.
      }
    }

    for (final consumer in consumers) {
      consumer.accept(prepared);
    }
    await Future.wait<void>(<Future<void>>[
      for (final consumer in consumers) consumer.idle,
    ]);
  }

  bool _shouldDecode(CapturedApiEvent event) {
    return event.path == '/kcsapi/api_start2/getData' ||
        utf8.encode(event.responseBody).length >= backgroundThresholdBytes;
  }
}

Future<Map<String, Object?>> _decodeInBackground(String responseBody) {
  return Isolate.run(() => GameApiDecoder.decodeEnvelope(responseBody));
}
