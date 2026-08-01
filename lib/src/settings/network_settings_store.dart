import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum NetworkMode { system, httpProxy, socks5Proxy }

class NetworkSettings {
  const NetworkSettings({
    this.mode = NetworkMode.system,
    this.host = '',
    this.port = 8080,
  });

  final NetworkMode mode;
  final String host;
  final int port;

  NetworkSettings copyWith({NetworkMode? mode, String? host, int? port}) {
    return NetworkSettings(
      mode: mode ?? this.mode,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  Map<String, dynamic> toJson() {
    return {'mode': mode.name, 'host': host, 'port': port, 'schemaVersion': 1};
  }

  factory NetworkSettings.fromJson(Map<String, dynamic> json) {
    return NetworkSettings(
      mode: NetworkMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => NetworkMode.system,
      ),
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 8080,
    );
  }
}

abstract class NetworkSettingsStore {
  Future<NetworkSettings> loadSettings();
  Future<void> saveSettings(NetworkSettings settings);
}

class SharedPreferencesNetworkSettingsStore implements NetworkSettingsStore {
  static const _keySettings = 'network_settings_v1';

  @override
  Future<NetworkSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keySettings);
    if (jsonStr == null) {
      return const NetworkSettings();
    }
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NetworkSettings.fromJson(json);
    } catch (e) {
      return const NetworkSettings();
    }
  }

  @override
  Future<void> saveSettings(NetworkSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(settings.toJson());
    await prefs.setString(_keySettings, jsonStr);
  }
}
