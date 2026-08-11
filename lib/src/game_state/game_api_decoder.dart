import 'dart:convert';

import '../bridge/captured_api_event.dart';

class GameApiParseException implements Exception {
  const GameApiParseException(this.message);

  final String message;

  @override
  String toString() => 'GameApiParseException: $message';
}

abstract final class GameApiDecoder {
  static Map<String, Object?> decodeEnvelope(String responseBody) {
    final body = responseBody.startsWith('svdata=')
        ? responseBody.substring('svdata='.length)
        : responseBody;

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const GameApiParseException('响应不是有效 JSON');
    }
    if (decoded is! Map) {
      throw const GameApiParseException('响应外层不是对象');
    }
    return Map<String, Object?>.from(decoded);
  }

  static Object? decodeData(
    String responseBody, {
    bool allowMissingData = false,
  }) {
    return _decodeEnvelopeData(
      decodeEnvelope(responseBody),
      allowMissingData: allowMissingData,
    );
  }

  static Object? decodeEventData(
    CapturedApiEvent event, {
    bool allowMissingData = false,
  }) {
    return _decodeEnvelopeData(
      event.decodedEnvelope ?? decodeEnvelope(event.responseBody),
      allowMissingData: allowMissingData,
    );
  }

  static Object? _decodeEnvelopeData(
    Map<String, Object?> envelope, {
    required bool allowMissingData,
  }) {
    if (_asInt(envelope['api_result']) != 1) {
      throw const GameApiParseException('游戏接口返回失败');
    }
    if (!allowMissingData && !envelope.containsKey('api_data')) {
      throw const GameApiParseException('响应缺少 api_data');
    }
    return envelope['api_data'];
  }

  static int _asInt(Object? value) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };
  }
}
