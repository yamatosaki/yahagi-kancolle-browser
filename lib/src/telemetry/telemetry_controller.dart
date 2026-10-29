import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';
import 'telemetry_settings_store.dart';

final class TelemetryController extends ChangeNotifier {
  TelemetryController({
    required this.store,
    required this.service,
    bool initialEnabled = true,
  }) : _enabled = initialEnabled;

  final TelemetrySettingsStore store;
  final TelemetryService service;
  bool _enabled;
  bool _saving = false;
  bool _saveFailed = false;
  bool _disposed = false;
  int _operationVersion = 0;
  Future<void> _pendingSave = Future<void>.value();

  bool get enabled => _enabled;
  bool get saving => _saving;
  bool get saveFailed => _saveFailed;
  bool get isDisposed => _disposed;

  /// Starts the telemetry service if the user has enabled telemetry and the controller is not disposed.
  Future<void> startIfEnabled() async {
    if (_disposed || !_enabled || _saving || _saveFailed) return;
    await service.start();
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed || (_enabled == value && !_saveFailed)) return;
    _enabled = value;
    _saving = true;
    _saveFailed = false;
    final opVersion = ++_operationVersion;
    if (!value) service.stop();
    // Keep durable preferences in the same order as the user's toggles.
    var saved = false;
    final saving = _pendingSave = _pendingSave.then((_) async {
      try {
        await store.saveEnabled(value);
        saved = true;
      } catch (_) {
        // Keep reporting stopped after an opt-out, while allowing a retry or
        // a later choice to be persisted even when this write failed.
      }
    });
    notifyListeners();
    await saving;

    if (_disposed || opVersion != _operationVersion) {
      return;
    }
    _saving = false;
    _saveFailed = !saved;
    notifyListeners();
    if (_enabled && saved) {
      await service.start();
    }
  }

  static Future<TelemetryController> create({
    required TelemetrySettingsStore store,
    required TelemetryService service,
  }) async {
    final enabled = await store.loadEnabled();
    return TelemetryController(
      store: store,
      service: service,
      initialEnabled: enabled,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    service.dispose();
    super.dispose();
  }
}
