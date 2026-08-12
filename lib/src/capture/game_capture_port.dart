import 'dart:convert';
import 'dart:typed_data';

import '../bridge/captured_api_event.dart';

enum GameCaptureState {
  disabled,
  checking,
  ready,
  capturing,
  unsupported,
  error,
}

abstract interface class GameCapturePort {
  Stream<CapturedApiEvent> get events;

  Future<bool> isSupported();

  Future<void> configure({required bool enabled, required String script});

  void dispose();
}

abstract final class AndroidCaptureEvent {
  static Object? decode(Object? value) {
    if (value is! Map) {
      throw const FormatException('Native capture event must be an object');
    }

    final map = Map<Object?, Object?>.from(value);
    if (map['version'] != 1) {
      throw const FormatException('Unsupported native capture protocol');
    }

    if (map['kind'] != 'kcsapi_response') {
      throw const FormatException('Unsupported native capture protocol kind');
    }

    final method = map['method'];
    final path = map['path'];
    final responsePayload = _decodeResponseBody(map);
    final responseBody = responsePayload.text;
    final statusCode = map['statusCode'];
    final transport = map['transport'];
    final sourceOrigin = map['sourceOrigin'];
    final capturedAtValue = map['capturedAt'];
    final sequence = map['sequence'];
    final rawParams = map['requestParams'];

    if (method is! String || (method != 'GET' && method != 'POST')) {
      throw const FormatException('Unsupported request method');
    }
    if (path is! String || !path.startsWith('/kcsapi/')) {
      throw const FormatException('Only /kcsapi/ responses are accepted');
    }
    if (statusCode is! int ||
        sourceOrigin is! String ||
        sourceOrigin.isEmpty ||
        sequence is! int ||
        sequence < 1 ||
        rawParams is! Map) {
      throw const FormatException('Native capture event has invalid fields');
    }
    final capturedAt = capturedAtValue is String
        ? DateTime.tryParse(capturedAtValue)?.toUtc()
        : null;
    if (capturedAt == null) {
      throw const FormatException('Native capture time is invalid');
    }

    final source = switch (transport) {
      'xhr' => CaptureSource.xhr,
      'fetch' => CaptureSource.fetch,
      _ => throw const FormatException('Unsupported capture transport'),
    };

    return CapturedApiEvent(
      method: method,
      path: path,
      requestParams: _sanitizeMap(rawParams),
      responseBody: responseBody.startsWith('svdata=')
          ? responseBody.substring('svdata='.length)
          : responseBody,
      statusCode: statusCode,
      source: source,
      sourceOrigin: sourceOrigin,
      capturedAt: capturedAt,
      sequence: sequence,
      responseByteLength: responsePayload.byteLength,
    );
  }

  static ({String text, int? byteLength}) _decodeResponseBody(
    Map<Object?, Object?> map,
  ) {
    final stringBody = map['responseBody'];
    if (stringBody is String) return (text: stringBody, byteLength: null);

    final binaryBody = map['responseBodyBytes'];
    if (binaryBody is Uint8List) {
      try {
        return (
          text: utf8.decode(binaryBody, allowMalformed: false),
          byteLength: binaryBody.length,
        );
      } on FormatException {
        throw const FormatException('Native response body is not valid UTF-8');
      }
    }
    throw const FormatException('Native capture event has no response body');
  }

  static Map<String, Object?> _sanitizeMap(Map<Object?, Object?> input) {
    final output = <String, Object?>{};
    for (final entry in input.entries) {
      final key = entry.key;
      if (key is! String || key == 'api_token' || key == 'api_starttime') {
        continue;
      }
      output[key] = _sanitizeValue(entry.value);
    }
    return Map.unmodifiable(output);
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is Map) {
      return _sanitizeMap(Map<Object?, Object?>.from(value));
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_sanitizeValue));
    }
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }
}
