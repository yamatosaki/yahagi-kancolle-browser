import 'package:flutter/foundation.dart';

import 'gadget_bypass_channel.dart';
import 'gadget_bypass_store.dart';

class GadgetBypassController extends ChangeNotifier {
  GadgetBypassController({required this.store, required this.port});

  final GadgetBypassStore store;
  final GadgetBypassPort port;

  GadgetBypassSettings _settings = const GadgetBypassSettings();
  GadgetBypassSettings get settings => _settings;

  bool get enabled => _settings.enabled;
  String get endpoint => _settings.endpoint;

  bool _supported = true;
  bool get supported => _supported;

  bool _isApplying = false;
  bool get isApplying => _isApplying;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isDiagnosing = false;
  bool get isDiagnosing => _isDiagnosing;

  GadgetBypassDiagnoseResult? _lastDiagnose;
  GadgetBypassDiagnoseResult? get lastDiagnose => _lastDiagnose;

  static Future<GadgetBypassController> load(
    GadgetBypassStore store, {
    GadgetBypassPort? port,
  }) async {
    final controller = GadgetBypassController(
      store: store,
      port: port ?? MethodChannelGadgetBypassPort(),
    );
    await controller.initialize();
    return controller;
  }

  Future<void> initialize() async {
    final loaded = await store.load();
    final normalized = normalizeGadgetBypassEndpoint(loaded.endpoint);
    _settings = normalized == null
        ? const GadgetBypassSettings()
        : loaded.copyWith(endpoint: normalized);
    final applied = await applyToNative();
    if (!applied && _settings.enabled) {
      _settings = _settings.copyWith(enabled: false);
      await store.save(_settings);
    }
    await refreshStatus();
  }

  Future<bool> setEnabled(bool value) async {
    if (_settings.enabled == value) return true;
    final previous = _settings;
    final candidate = _settings.copyWith(enabled: value);
    _settings = candidate;
    final applied = await applyToNative();
    if (!applied) {
      _settings = previous;
      notifyListeners();
      return false;
    }
    await store.save(candidate);
    notifyListeners();
    return true;
  }

  Future<bool> setEndpoint(String endpoint) async {
    final normalized = normalizeGadgetBypassEndpoint(endpoint);
    if (normalized == null) {
      _lastError = 'invalid_endpoint';
      notifyListeners();
      return false;
    }
    if (_settings.endpoint == normalized) return true;
    final previous = _settings;
    final candidate = _settings.copyWith(endpoint: normalized);
    _settings = candidate;
    final applied = await applyToNative();
    if (!applied) {
      _settings = previous;
      notifyListeners();
      return false;
    }
    await store.save(candidate);
    notifyListeners();
    return true;
  }

  Future<bool> applyToNative() async {
    _isApplying = true;
    notifyListeners();
    var applied = false;
    try {
      applied = await port.configure(
        enabled: _settings.enabled,
        endpoint: _settings.endpoint,
      );
      _lastError = applied ? null : 'native_configure_failed';
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isApplying = false;
      notifyListeners();
    }
    return applied;
  }

  Future<void> refreshStatus() async {
    try {
      final status = await port.status();
      _supported = status.supported;
      notifyListeners();
    } catch (e) {
      // Keep the previous value on failure.
    }
  }

  Future<bool> clearCache() async {
    final ok = await port.clearCache();
    if (!ok) _lastError = 'cache_clear_failed';
    notifyListeners();
    return ok;
  }

  Future<void> diagnose() async {
    if (_isDiagnosing) return;
    _isDiagnosing = true;
    _lastDiagnose = null;
    notifyListeners();
    try {
      _lastDiagnose = await port.diagnose();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isDiagnosing = false;
      notifyListeners();
    }
  }
}
