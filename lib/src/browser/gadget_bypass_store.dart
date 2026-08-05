import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultGadgetBypassEndpoint = 'https://kcwiki.github.io/cache/';
const String kLuckyjervisGadgetBypassEndpoint = 'https://luckyjervis.com/';

String? normalizeGadgetBypassEndpoint(String value) {
  final candidate = value.trim();
  if (_hasUnsafeRawPath(candidate)) return null;
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.scheme.toLowerCase() != 'https' || !uri.hasAuthority) {
    return null;
  }
  if (uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (!_isPublicMirrorHostname(host) || host == 'w00g.kancolle-server.com') {
    return null;
  }
  if (uri.pathSegments.any((segment) => segment == '.' || segment == '..')) {
    return null;
  }
  final path = uri.path.isEmpty
      ? '/'
      : uri.path.endsWith('/')
      ? uri.path
      : '${uri.path}/';
  return Uri(scheme: 'https', host: host, path: path).toString();
}

bool _isPublicMirrorHostname(String host) {
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.contains(':')) {
    return false;
  }
  final ipv4 = host.split('.');
  if (ipv4.length == 4 &&
      ipv4.every((part) {
        final value = int.tryParse(part);
        return value != null && value >= 0 && value <= 255;
      })) {
    return false;
  }
  return host.contains('.') && !host.contains(RegExp(r'\s'));
}

bool _hasUnsafeRawPath(String value) {
  final authorityStart = value.indexOf('://');
  if (authorityStart < 0) return false;
  final pathStart = value.indexOf('/', authorityStart + 3);
  if (pathStart < 0) return false;
  final rawPath = value.substring(pathStart).split('?').first.split('#').first;
  for (final rawSegment in rawPath.split('/')) {
    var decoded = rawSegment;
    try {
      decoded = Uri.decodeComponent(decoded);
      decoded = Uri.decodeComponent(decoded);
    } on FormatException {
      return true;
    }
    if (decoded == '.' ||
        decoded == '..' ||
        decoded.contains('/') ||
        decoded.contains(r'\')) {
      return true;
    }
  }
  return false;
}

class GadgetBypassSettings {
  const GadgetBypassSettings({
    this.enabled = false,
    this.endpoint = kDefaultGadgetBypassEndpoint,
  });

  final bool enabled;
  final String endpoint;

  GadgetBypassSettings copyWith({bool? enabled, String? endpoint}) {
    return GadgetBypassSettings(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
    );
  }

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'endpoint': endpoint, 'schemaVersion': 1};
  }

  factory GadgetBypassSettings.fromJson(Map<String, dynamic> json) {
    return GadgetBypassSettings(
      enabled: json['enabled'] as bool? ?? false,
      endpoint: json['endpoint'] as String? ?? kDefaultGadgetBypassEndpoint,
    );
  }
}

abstract class GadgetBypassStore {
  Future<GadgetBypassSettings> load();
  Future<void> save(GadgetBypassSettings settings);
}

class SharedPreferencesGadgetBypassStore implements GadgetBypassStore {
  static const String _key = 'gadget_bypass_settings_v1';

  @override
  Future<GadgetBypassSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return const GadgetBypassSettings();
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return GadgetBypassSettings.fromJson(json);
    } catch (e) {
      return const GadgetBypassSettings();
    }
  }

  @override
  Future<void> save(GadgetBypassSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
