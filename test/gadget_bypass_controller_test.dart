import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';

class _MemoryBypassStore implements GadgetBypassStore {
  _MemoryBypassStore([this.settings = const GadgetBypassSettings()]);

  GadgetBypassSettings settings;

  @override
  Future<GadgetBypassSettings> load() async => settings;

  @override
  Future<void> save(GadgetBypassSettings settings) async {
    this.settings = settings;
  }
}

class _RecordingBypassPort implements GadgetBypassPort {
  final List<({bool enabled, String endpoint})> configureCalls = [];
  bool configured = false;

  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async {
    configureCalls.add((enabled: enabled, endpoint: endpoint));
    configured = true;
    return true;
  }

  @override
  Future<GadgetBypassStatus> status() async =>
      const GadgetBypassStatus(enabled: false, endpoint: '', supported: true);

  @override
  Future<bool> clearCache() async => true;

  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async {
    return const GadgetBypassDiagnoseResult(
      w00g: GadgetBypassProbe(reachable: true, statusCode: 200, elapsedMs: 12),
      endpoint: GadgetBypassProbe(
        reachable: true,
        statusCode: 200,
        elapsedMs: 34,
      ),
      kcsapi: GadgetBypassProbe(
        reachable: false,
        elapsedMs: 5000,
        error: 'timeout',
      ),
    );
  }
}

void main() {
  test('load applies persisted settings to the native side', () async {
    final store = _MemoryBypassStore(
      const GadgetBypassSettings(enabled: true, endpoint: 'https://a.example/'),
    );
    final port = _RecordingBypassPort();
    final controller = await GadgetBypassController.load(store, port: port);

    expect(controller.enabled, isTrue);
    expect(controller.endpoint, 'https://a.example/');
    expect(port.configureCalls, hasLength(1));
    expect(port.configureCalls.single.enabled, isTrue);
    expect(port.configureCalls.single.endpoint, 'https://a.example/');
  });

  test('setEnabled persists and pushes the new state', () async {
    final store = _MemoryBypassStore();
    final port = _RecordingBypassPort();
    final controller = await GadgetBypassController.load(store, port: port);

    final applied = await controller.setEnabled(true);

    expect(applied, isTrue);
    expect(controller.enabled, isTrue);
    expect(store.settings.enabled, isTrue);
    expect(port.configureCalls.last.enabled, isTrue);
  });

  test('setEndpoint persists and pushes the new endpoint', () async {
    final store = _MemoryBypassStore();
    final port = _RecordingBypassPort();
    final controller = await GadgetBypassController.load(store, port: port);

    await controller.setEndpoint('https://luckyjervis.com');

    expect(controller.endpoint, 'https://luckyjervis.com/');
    expect(store.settings.endpoint, 'https://luckyjervis.com/');
    expect(port.configureCalls.last.endpoint, 'https://luckyjervis.com/');
  });

  test('native configure failure rolls back the enabled setting', () async {
    final store = _MemoryBypassStore();
    final port = _FailingBypassPort();
    final controller = await GadgetBypassController.load(store, port: port);

    await controller.setEnabled(true);

    expect(controller.enabled, isFalse);
    expect(controller.lastError, isNotNull);
    expect(store.settings.enabled, isFalse);
  });

  test('unsafe custom endpoint is rejected before native configure', () async {
    final store = _MemoryBypassStore();
    final port = _RecordingBypassPort();
    final controller = await GadgetBypassController.load(store, port: port);
    final callsBefore = port.configureCalls.length;

    final applied = await controller.setEndpoint('http://127.0.0.1/cache/');

    expect(applied, isFalse);
    expect(controller.endpoint, kDefaultGadgetBypassEndpoint);
    expect(store.settings.endpoint, kDefaultGadgetBypassEndpoint);
    expect(port.configureCalls, hasLength(callsBefore));
    expect(controller.lastError, 'invalid_endpoint');
  });

  test('diagnose stores probe results and clears busy state', () async {
    final store = _MemoryBypassStore();
    final port = _RecordingBypassPort();
    final controller = await GadgetBypassController.load(store, port: port);

    await controller.diagnose();

    expect(controller.isDiagnosing, isFalse);
    expect(controller.lastDiagnose, isNotNull);
    expect(controller.lastDiagnose!.w00g.reachable, isTrue);
    expect(controller.lastDiagnose!.kcsapi.reachable, isFalse);
  });
}

class _FailingBypassPort implements GadgetBypassPort {
  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async {
    return false;
  }

  @override
  Future<GadgetBypassStatus> status() async =>
      const GadgetBypassStatus(enabled: false, endpoint: '', supported: true);

  @override
  Future<bool> clearCache() async => true;

  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async {
    return const GadgetBypassDiagnoseResult(
      w00g: GadgetBypassProbe(reachable: false, elapsedMs: 100),
      endpoint: GadgetBypassProbe(reachable: false, elapsedMs: 100),
      kcsapi: GadgetBypassProbe(reachable: false, elapsedMs: 100),
    );
  }
}
