import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_validator.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';

void main() {
  group('NetworkSettingsValidator Tests', () {
    test('Valid IPv4', () {
      expect(NetworkSettingsValidator.validateHost('192.168.1.10'), isNull);
    });

    test('Valid IPv6', () {
      expect(
        NetworkSettingsValidator.validateHost('fe80::1ff:fe23:4567:890a'),
        isNull,
      );
      expect(
        NetworkSettingsValidator.validateHost('[fe80::1ff:fe23:4567:890a]'),
        isNull,
      );
    });

    test('Valid Domain', () {
      expect(NetworkSettingsValidator.validateHost('example.com'), isNull);
      expect(NetworkSettingsValidator.validateHost('localhost'), isNull);
    });

    test('Empty Host', () {
      expect(
        NetworkSettingsValidator.validateHost(''),
        NetworkValidationError.hostEmpty,
      );
      expect(
        NetworkSettingsValidator.validateHost('   '),
        NetworkValidationError.hostEmpty,
      );
    });

    test('Host with http://', () {
      expect(
        NetworkSettingsValidator.validateHost('http://192.168.1.10'),
        NetworkValidationError.httpScheme,
      );
      expect(
        NetworkSettingsValidator.validateHost('socks5://127.0.0.1'),
        NetworkValidationError.socksScheme,
      );
      expect(
        NetworkSettingsValidator.validateHost('ftp://127.0.0.1'),
        NetworkValidationError.scheme,
      );
    });

    test('Host with path', () {
      expect(
        NetworkSettingsValidator.validateHost('192.168.1.10/proxy'),
        NetworkValidationError.path,
      );
    });

    test('Host with auth', () {
      expect(
        NetworkSettingsValidator.validateHost('user:pass@192.168.1.10'),
        NetworkValidationError.credentials,
      );
    });

    test('Valid port', () {
      expect(NetworkSettingsValidator.validatePort('8080'), isNull);
      expect(NetworkSettingsValidator.validatePort('1'), isNull);
      expect(NetworkSettingsValidator.validatePort('65535'), isNull);
    });

    test('Invalid port (0)', () {
      expect(
        NetworkSettingsValidator.validatePort('0'),
        NetworkValidationError.portZero,
      );
    });

    test('Invalid port (65536)', () {
      expect(
        NetworkSettingsValidator.validatePort('65536'),
        NetworkValidationError.portRange,
      );
    });

    test('Invalid port (non-number)', () {
      expect(
        NetworkSettingsValidator.validatePort('abc'),
        NetworkValidationError.portInteger,
      );
    });

    test('Invalid port (decimal)', () {
      expect(
        NetworkSettingsValidator.validatePort('80.80'),
        NetworkValidationError.portDecimal,
      );
    });

    test('Invalid port (negative)', () {
      expect(
        NetworkSettingsValidator.validatePort('-8080'),
        NetworkValidationError.portNegative,
      );
    });

    test('Format Proxy Host', () {
      expect(NetworkSettingsValidator.formatProxyHost('fe80::1'), '[fe80::1]');
      expect(
        NetworkSettingsValidator.formatProxyHost('[fe80::1]'),
        '[fe80::1]',
      );
      expect(
        NetworkSettingsValidator.formatProxyHost('192.168.1.1'),
        '192.168.1.1',
      );
    });

    test('Build Proxy Rules', () {
      expect(
        NetworkSettingsValidator.buildHttpProxyRule('127.0.0.1', 8080),
        'http://127.0.0.1:8080',
      );
      expect(
        NetworkSettingsValidator.buildSocksProxyRule('127.0.0.1', 1080),
        'socks://127.0.0.1:1080',
      );
      expect(
        NetworkSettingsValidator.buildHttpProxyRule('fe80::1', 8080),
        'http://[fe80::1]:8080',
      );
    });
  });

  group('NetworkSettings Serialization', () {
    test('Json serialize and deserialize', () {
      const original = NetworkSettings(
        mode: NetworkMode.httpProxy,
        host: '192.168.1.10',
        port: 8080,
      );
      final json = original.toJson();
      final restored = NetworkSettings.fromJson(json);
      expect(restored.mode, NetworkMode.httpProxy);
      expect(restored.host, '192.168.1.10');
      expect(restored.port, 8080);
    });

    test('Deserialize unknown mode fallbacks to system', () {
      final json = {
        'mode': 'daofengPc',
        'host': '192.168.1.10',
        'port': 8099,
        'schemaVersion': 1,
      };
      final restored = NetworkSettings.fromJson(json);
      expect(restored.mode, NetworkMode.system);
    });
  });
}
