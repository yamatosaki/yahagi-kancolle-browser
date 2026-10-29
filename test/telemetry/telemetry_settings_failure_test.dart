import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the actual preference store's rejected platform write.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:yahagi_kancolle_browser/src/telemetry/telemetry_controller.dart';
import 'package:yahagi_kancolle_browser/src/telemetry/telemetry_service.dart';
import 'package:yahagi_kancolle_browser/src/telemetry/telemetry_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  test('a rejected opt-out write is reported to its caller', () async {
    SharedPreferencesStorePlatform.instance = _RejectingPreferences();
    const store = SharedPreferencesTelemetrySettingsStore();
    await expectLater(store.saveEnabled(false), throwsStateError);
  });

  test('an unreadable preference does not enable telemetry', () async {
    SharedPreferences.setMockInitialValues({
      'telemetry.anonymous_stats_enabled': 'corrupt',
    });
    expect(
      await const SharedPreferencesTelemetrySettingsStore().loadEnabled(),
      isFalse,
    );
  });

  test(
    'failed opt-out remains stopped and can retry the same choice',
    () async {
      final store = _FailingStore();
      final service = _Service();
      final controller = TelemetryController(store: store, service: service);
      addTearDown(controller.dispose);
      await controller.setEnabled(false);
      await controller.startIfEnabled();
      expect(controller.enabled, isFalse);
      expect(controller.saveFailed, isTrue);
      expect(controller.saving, isFalse);
      expect(service.stops, 1);
      expect(service.starts, 0);
      store.fail = false;
      await controller.setEnabled(false);
      expect(store.value, isFalse);
      expect(controller.saveFailed, isFalse);
    },
  );

  test('failed opt-in never starts the service', () async {
    final store = _FailingStore()..value = false;
    final service = _Service();
    final controller = TelemetryController(
      store: store,
      service: service,
      initialEnabled: false,
    );
    addTearDown(controller.dispose);
    await controller.setEnabled(true);
    await controller.startIfEnabled();
    expect(service.starts, 0);
  });

  test('pending opt-in cannot start through a lifecycle callback', () async {
    final store = _FailingStore()
      ..fail = false
      ..gate = Completer<void>();
    final service = _Service();
    final controller = TelemetryController(
      store: store,
      service: service,
      initialEnabled: false,
    );
    addTearDown(controller.dispose);
    final saving = controller.setEnabled(true);
    expect(controller.saving, isTrue);
    await controller.startIfEnabled();
    expect(service.starts, 0);
    store.gate!.complete();
    await saving;
    expect(service.starts, 1);
    expect(controller.saving, isFalse);
  });
}

class _RejectingPreferences extends InMemorySharedPreferencesStore {
  _RejectingPreferences() : super.withData({});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class _FailingStore implements TelemetrySettingsStore {
  bool value = true;
  bool fail = true;
  Completer<void>? gate;
  @override
  Future<bool> loadEnabled() async => value;
  @override
  Future<void> saveEnabled(bool enabled) async {
    if (gate != null) await gate!.future;
    if (fail) throw StateError('Storage unavailable');
    value = enabled;
  }
}

class _Service implements TelemetryService {
  int starts = 0;
  int stops = 0;
  @override
  Future<void> start() async => starts++;
  @override
  void stop() => stops++;
  @override
  void dispose() {}
  @override
  void onLifecycleChanged(AppLifecycleState state) {}
}
