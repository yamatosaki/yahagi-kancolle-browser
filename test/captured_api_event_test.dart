import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';

void main() {
  group('ApiBridgeDecoder', () {
    test('decodes a kcsapi response and removes the svdata prefix', () {
      final event = ApiBridgeDecoder.decode(
        '{"kind":"kcsapi-response",'
        '"path":"/kcsapi/api_port/port",'
        '"body":"svdata={\\"api_result\\":1}",'
        '"source":"fetch",'
        '"capturedAt":"2026-07-29T10:00:00.000Z"}',
      );

      expect(event.path, '/kcsapi/api_port/port');
      expect(event.responseBody, '{"api_result":1}');
      expect(event.source, CaptureSource.fetch);
      expect(event.capturedAt, DateTime.utc(2026, 7, 29, 10));
      expect(event.apiResult, 1);
    });

    test('rejects malformed messages and non-kcsapi paths', () {
      expect(
        () => ApiBridgeDecoder.decode('not-json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ApiBridgeDecoder.decode(
          '{"kind":"kcsapi-response","path":"/analytics",'
          '"body":"{}","source":"xhr"}',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
