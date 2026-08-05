import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to disabled with the kcwiki endpoint', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesGadgetBypassStore();
    final settings = await store.load();
    expect(settings.enabled, isFalse);
    expect(settings.endpoint, kDefaultGadgetBypassEndpoint);
  });

  test('round-trips enabled state and a custom endpoint', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesGadgetBypassStore();
    await store.save(
      const GadgetBypassSettings(
        enabled: true,
        endpoint: 'https://example.com/cache/',
      ),
    );
    final settings = await store.load();
    expect(settings.enabled, isTrue);
    expect(settings.endpoint, 'https://example.com/cache/');
  });

  test('corrupt stored json falls back to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'gadget_bypass_settings_v1': '{broken json',
    });
    final store = SharedPreferencesGadgetBypassStore();
    final settings = await store.load();
    expect(settings.enabled, isFalse);
    expect(settings.endpoint, kDefaultGadgetBypassEndpoint);
  });

  test('normalizes public HTTPS mirror endpoints', () {
    expect(
      normalizeGadgetBypassEndpoint('https://EXAMPLE.com/cache'),
      'https://example.com/cache/',
    );
  });

  test('rejects unsafe mirror endpoints', () {
    const endpoints = <String>[
      'http://example.com/cache/',
      'https://user:pass@example.com/cache/',
      'https://localhost/cache/',
      'https://127.0.0.1/cache/',
      'https://10.0.0.1/cache/',
      'https://example.com/cache/?target=evil',
      'https://example.com/cache/#fragment',
      'https://example.com/cache/../private/',
      'https://example.com/cache/%2e%2e/private/',
      'https://w00g.kancolle-server.com/',
    ];
    for (final endpoint in endpoints) {
      expect(normalizeGadgetBypassEndpoint(endpoint), isNull, reason: endpoint);
    }
  });
}
