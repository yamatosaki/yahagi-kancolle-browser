import 'dart:convert';

enum CaptureSource {
  fetch('fetch'),
  xhr('xhr'),
  manual('manual');

  const CaptureSource(this.wireName);

  final String wireName;

  String get label => switch (this) {
    CaptureSource.fetch => 'Fetch',
    CaptureSource.xhr => 'XHR',
    CaptureSource.manual => '模拟数据',
  };

  static CaptureSource parse(Object? value) {
    return values.firstWhere(
      (source) => source.wireName == value,
      orElse: () => CaptureSource.manual,
    );
  }
}

class CapturedApiEvent {
  const CapturedApiEvent({
    this.method = 'POST',
    required this.path,
    this.requestParams = const <String, Object?>{},
    required this.responseBody,
    this.statusCode = 0,
    required this.source,
    this.sourceOrigin = '',
    required this.capturedAt,
    this.sequence = 0,
  });

  final String method;
  final String path;
  final Map<String, Object?> requestParams;
  final String responseBody;
  final int statusCode;
  final CaptureSource source;
  final String sourceOrigin;
  final DateTime capturedAt;
  final int sequence;

  int? get apiResult {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic> && decoded['api_result'] is int) {
        return decoded['api_result'] as int;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

abstract final class ApiBridgeDecoder {
  static const int _maxMessageLength = 2 * 1024 * 1024;

  static CapturedApiEvent decode(String message) {
    if (message.length > _maxMessageLength) {
      throw const FormatException('Bridge message is too large');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      throw const FormatException('Bridge message is not valid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Bridge message must be an object');
    }
    if (decoded['kind'] != 'kcsapi-response') {
      throw const FormatException('Unsupported bridge message kind');
    }

    final path = decoded['path'];
    final body = decoded['body'];
    if (path is! String || !path.startsWith('/kcsapi/')) {
      throw const FormatException('Only /kcsapi/ responses are accepted');
    }
    if (body is! String) {
      throw const FormatException('Response body must be a string');
    }

    final capturedAtValue = decoded['capturedAt'];
    final capturedAt = capturedAtValue is String
        ? DateTime.tryParse(capturedAtValue)?.toUtc()
        : null;

    return CapturedApiEvent(
      path: path,
      responseBody: body.startsWith('svdata=')
          ? body.substring('svdata='.length)
          : body,
      source: CaptureSource.parse(decoded['source']),
      capturedAt: capturedAt ?? DateTime.now().toUtc(),
    );
  }
}
