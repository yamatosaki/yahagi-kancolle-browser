import 'dart:convert';

class GameApiParseException implements Exception {
  const GameApiParseException(this.message);

  final String message;

  @override
  String toString() => 'GameApiParseException: $message';
}

abstract final class GameApiDecoder {
  static Object? decodeData(
    String responseBody, {
    bool allowMissingData = false,
  }) {
    final body = responseBody.startsWith('svdata=')
        ? responseBody.substring('svdata='.length)
        : responseBody;

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const GameApiParseException('响应不是有效 JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const GameApiParseException('响应外层不是对象');
    }
    if (_asInt(decoded['api_result']) != 1) {
      throw const GameApiParseException('游戏接口返回失败');
    }
    if (!allowMissingData && !decoded.containsKey('api_data')) {
      throw const GameApiParseException('响应缺少 api_data');
    }
    return decoded['api_data'];
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
