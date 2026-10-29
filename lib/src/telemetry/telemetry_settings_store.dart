import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TelemetrySettingsStore {
  Future<bool> loadEnabled();

  Future<void> saveEnabled(bool value);
}

final class SharedPreferencesTelemetrySettingsStore
    implements TelemetrySettingsStore {
  const SharedPreferencesTelemetrySettingsStore();

  static const String _enabledKey = 'telemetry.anonymous_stats_enabled';

  @override
  Future<bool> loadEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load telemetry settings, falling back to disabled: $error\n$stackTrace',
      );
      return false;
    }
  }

  @override
  Future<void> saveEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_enabledKey, value)) {
      throw StateError('Telemetry preference was not saved');
    }
  }
}

final class MemoryTelemetrySettingsStore implements TelemetrySettingsStore {
  MemoryTelemetrySettingsStore([this.value = true]);

  bool value;

  @override
  Future<bool> loadEnabled() async => value;

  @override
  Future<void> saveEnabled(bool value) async => this.value = value;
}
