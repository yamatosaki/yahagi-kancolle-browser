import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_port.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';

void main() {
  group('AndroidCaptureEvent', () {
    test('decodes a validated native capture event', () {
      final event =
          AndroidCaptureEvent.decode(<Object?, Object?>{
                'version': 1,
                'kind': 'kcsapi_response',
                'method': 'POST',
                'path': '/kcsapi/api_port/port',
                'requestParams': <String, Object?>{
                  'api_verno': '1',
                  'api_token': 'must-not-cross-the-bridge',
                  'nested': <String, Object?>{'api_starttime': 'secret'},
                },
                'responseBody': 'svdata={"api_result":1}',
                'statusCode': 200,
                'transport': 'xhr',
                'sourceOrigin': 'https://w01y.kancolle-server.com',
                'capturedAt': '2026-07-30T10:00:00.000Z',
                'sequence': 1,
              })
              as CapturedApiEvent;

      expect(event.path, '/kcsapi/api_port/port');
      expect(event.responseBody, '{"api_result":1}');
      expect(event.method, 'POST');
      expect(event.statusCode, 200);
      expect(event.sourceOrigin, 'https://w01y.kancolle-server.com');
      expect(event.sequence, 1);
      expect(event.requestParams, isNot(contains('api_token')));
      expect(event.requestParams['nested'], isNot(contains('api_starttime')));
    });

    test('decodes valid response payload', () {
      final event =
          AndroidCaptureEvent.decode(<String, Object?>{
                'version': 1,
                'kind': 'kcsapi_response',
                'method': 'POST',
                'path': '/kcsapi/api_req_map/start',
                'requestParams': <String, Object?>{'api_verno': '1'},
                'responseBody': 'svdata={"api_result": 1}',
                'statusCode': 200,
                'transport': 'xhr',
                'sourceOrigin': 'http://127.0.0.1',
                'capturedAt': '2023-11-20T12:34:56Z',
                'sequence': 42,
              })
              as CapturedApiEvent;

      expect(event.path, '/kcsapi/api_req_map/start');
    });

    test('decodes binary response bytes from the native channel', () {
      final event =
          AndroidCaptureEvent.decode(<String, Object?>{
                'version': 1,
                'kind': 'kcsapi_response',
                'method': 'POST',
                'path': '/kcsapi/api_port/port',
                'requestParams': <String, Object?>{},
                'responseBodyBytes': Uint8List.fromList(
                  utf8.encode('svdata={"api_result":1,"api_data":"艦"}'),
                ),
                'statusCode': 200,
                'transport': 'fetch',
                'sourceOrigin': 'https://w01y.kancolle-server.com',
                'capturedAt': '2026-07-30T10:00:00.000Z',
                'sequence': 2,
              })
              as CapturedApiEvent;

      expect(event.responseBody, '{"api_result":1,"api_data":"艦"}');
      expect(
        event.responseByteLength,
        utf8.encode('svdata={"api_result":1,"api_data":"艦"}').length,
      );
      expect(event.sequence, 2);
    });

    test('rejects unknown versions and non-kcsapi paths', () {
      final valid = <Object?, Object?>{
        'version': 1,
        'kind': 'kcsapi_response',
        'method': 'POST',
        'path': '/kcsapi/api_port/port',
        'requestParams': <String, Object?>{},
        'responseBody': 'svdata={"api_result":1}',
        'statusCode': 200,
        'transport': 'fetch',
        'sourceOrigin': 'https://w01y.kancolle-server.com',
        'capturedAt': '2026-07-30T10:00:00.000Z',
        'sequence': 1,
      };

      expect(
        () => AndroidCaptureEvent.decode(<Object?, Object?>{
          ...valid,
          'version': 2,
        }),
        throwsFormatException,
      );
      expect(
        () => AndroidCaptureEvent.decode(<Object?, Object?>{
          ...valid,
          'path': '/analytics',
        }),
        throwsFormatException,
      );
    });

    test('rejects incorrect required field types', () {
      expect(
        () => AndroidCaptureEvent.decode(<Object?, Object?>{
          'version': 1,
          'kind': 'kcsapi_response',
          'method': 'POST',
          'path': '/kcsapi/api_port/port',
          'requestParams': <String, Object?>{},
          'responseBody': 42,
          'statusCode': 200,
          'transport': 'xhr',
          'sourceOrigin': 'https://w01y.kancolle-server.com',
          'capturedAt': '2026-07-30T10:00:00.000Z',
          'sequence': 1,
        }),
        throwsFormatException,
      );
    });
  });
}
