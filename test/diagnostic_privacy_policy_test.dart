import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/diagnostics/diagnostic_privacy_policy.dart';

void main() {
  group('DiagnosticPrivacyPolicy', () {
    final policy = DiagnosticPrivacyPolicy.v1();

    test('rejects credential field names regardless of case', () {
      for (final key in <String>[
        'account',
        'UserName',
        'password',
        'passwd',
        'api_token',
        'api_starttime',
        'Cookie',
        'Set-Cookie',
        'Authorization',
      ]) {
        expect(
          () => policy.validateField(key, 'TEST_ONLY_SECRET_DO_NOT_USE'),
          throwsA(isA<DiagnosticPrivacyViolation>()),
          reason: key,
        );
      }
    });

    test('rejects URLs query strings and credential-shaped values', () {
      for (final value in <String>[
        'https://example.invalid/login',
        '/kcsapi/api_port/port?api_token=secret',
        'api_token=TEST_ONLY_SECRET_DO_NOT_USE',
        'Bearer TEST_ONLY_SECRET_DO_NOT_USE',
        'session=TEST_ONLY_SECRET_DO_NOT_USE',
      ]) {
        expect(
          () => policy.validateField('message', value),
          throwsA(isA<DiagnosticPrivacyViolation>()),
          reason: value,
        );
      }
    });

    test('accepts a normalized kcsapi path without query data', () {
      expect(
        policy.safeApiPath('/kcsapi/api_port/port'),
        '/kcsapi/api_port/port',
      );
      expect(
        () => policy.safeApiPath('/kcsapi/api_port/port?api_token=secret'),
        throwsA(isA<DiagnosticPrivacyViolation>()),
      );
    });

    test('Kanxy exports allow only a known status and UTC timestamp', () {
      final record = <String, Object?>{
        'type': 'kanxy',
        'occurredAt': '2026-11-13T12:00:00.000Z',
        'fields': <String, Object?>{'status': 'WS_OPEN'},
      };
      void audit(Map<String, Object?> entry) {
        policy.validateExportDocument(<String, Object?>{
          'records': <Object?>[entry],
        });
      }

      expect(() => audit(record), returnsNormally);
      for (final invalid in <Map<String, Object?>>[
        {
          ...record,
          'fields': <String, Object?>{'status': 'WS_FUTURE_STATUS'},
        },
        {
          ...record,
          'fields': <String, Object?>{'status': 'WS_OPEN', 'port': 5412},
        },
        {...record, 'fields': <String, Object?>{}},
        {...record, 'extra': 1},
        {...record, 'occurredAt': 'unexpected'},
      ]) {
        expect(
          () => audit(invalid),
          throwsA(isA<DiagnosticPrivacyViolation>()),
        );
      }
    });

    test('safe stack keeps symbols but removes paths and arguments', () {
      final stack = StackTrace.fromString('''
#0      Login.submit (package:yahagi_kancolle_browser/src/login.dart:42:7)
#1      C:\\Users\\Player\\secret.dart:12:3
#2      _RootZone.run (dart:async/zone.dart:1400:13)
''');

      final safe = policy.safeStack(stack);

      expect(safe, contains('Login.submit'));
      expect(safe, contains('_RootZone.run'));
      expect(safe, isNot(contains('C:\\Users')));
      expect(safe, isNot(contains('src/login.dart')));
    });

    test('preserves Flutter frame locations for grey screen diagnosis', () {
      final safe = policy.safeStack(
        StackTrace.fromString('''
#0      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#1      _OverlayPortalState.build (package:flutter/src/widgets/overlay.dart:2100:8)
#2      PlatformDispatcher._drawFrame (dart:ui/platform_dispatcher.dart:444:5)
'''),
      );
      expect(safe, [
        'RenderBox.size (flutter/src/rendering/box.dart:2251:12)',
        '_OverlayPortalState.build (flutter/src/widgets/overlay.dart:2100:8)',
        'PlatformDispatcher._drawFrame',
      ]);
      expect(() => policy.validateField('stack', safe), returnsNormally);
    });

    test('stack filtering rejects disguised origins and unsafe symbols', () {
      final safe = policy.safeStack(
        StackTrace.fromString('''
#0      Widget.build (file:///C:/Users/Player/private.dart:1:2) package:flutter/src/widgets/framework.dart
#1      Widget.build (package:flutter/../../private.dart:1:2)
#2      api_token=secret (package:flutter/src/widgets/framework.dart:1:2)
#3      Widget.build (package:untrusted/src/private.dart:1:2)
#4      Widget.build (package:flutter/src/widgets/framework.dart:1:2)
'''),
      );
      expect(safe, ['Widget.build (flutter/src/widgets/framework.dart:1:2)']);
      expect(() => policy.validateField('stack', safe), returnsNormally);
    });
  });
}
