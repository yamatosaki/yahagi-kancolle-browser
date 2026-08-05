import 'package:flutter/services.dart';

class GadgetBypassStatus {
  const GadgetBypassStatus({
    required this.enabled,
    required this.endpoint,
    required this.supported,
    this.cacheBytes = 0,
  });

  final bool enabled;
  final String endpoint;
  final bool supported;
  final int cacheBytes;

  factory GadgetBypassStatus.fromJson(Map<String, dynamic> json) {
    return GadgetBypassStatus(
      enabled: json['enabled'] as bool? ?? false,
      endpoint: json['endpoint'] as String? ?? '',
      supported: json['supported'] as bool? ?? false,
      cacheBytes: json['cacheBytes'] as int? ?? 0,
    );
  }
}

class GadgetBypassProbe {
  const GadgetBypassProbe({
    required this.reachable,
    this.statusCode,
    required this.elapsedMs,
    this.error,
  });

  final bool reachable;
  final int? statusCode;
  final int elapsedMs;
  final String? error;

  factory GadgetBypassProbe.fromJson(Map<String, dynamic> json) {
    return GadgetBypassProbe(
      reachable: json['reachable'] as bool? ?? false,
      statusCode: json['statusCode'] as int?,
      elapsedMs: json['elapsedMs'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

class GadgetBypassDiagnoseResult {
  const GadgetBypassDiagnoseResult({
    required this.w00g,
    required this.endpoint,
    required this.kcsapi,
  });

  final GadgetBypassProbe w00g;
  final GadgetBypassProbe endpoint;
  final GadgetBypassProbe kcsapi;

  factory GadgetBypassDiagnoseResult.fromJson(Map<String, dynamic> json) {
    return GadgetBypassDiagnoseResult(
      w00g: GadgetBypassProbe.fromJson(
        Map<String, dynamic>.from(json['w00g'] as Map? ?? const {}),
      ),
      endpoint: GadgetBypassProbe.fromJson(
        Map<String, dynamic>.from(json['endpoint'] as Map? ?? const {}),
      ),
      kcsapi: GadgetBypassProbe.fromJson(
        Map<String, dynamic>.from(json['kcsapi'] as Map? ?? const {}),
      ),
    );
  }
}

abstract interface class GadgetBypassPort {
  Future<bool> configure({required bool enabled, required String endpoint});
  Future<GadgetBypassStatus> status();
  Future<bool> clearCache();
  Future<GadgetBypassDiagnoseResult> diagnose();
}

class MethodChannelGadgetBypassPort implements GadgetBypassPort {
  MethodChannelGadgetBypassPort([
    this._channel = const MethodChannel(
      'app.yahagi.kancollebrowser/gadget_bypass',
    ),
  ]);

  final MethodChannel _channel;

  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'configure',
        <String, dynamic>{'enabled': enabled, 'endpoint': endpoint},
      );
      return result?['success'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<GadgetBypassStatus> status() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('status');
      return GadgetBypassStatus.fromJson(result ?? <String, dynamic>{});
    } catch (e) {
      return const GadgetBypassStatus(
        enabled: false,
        endpoint: '',
        supported: false,
      );
    }
  }

  @override
  Future<bool> clearCache() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'clearCache',
      );
      return result?['success'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'diagnose',
      );
      return GadgetBypassDiagnoseResult.fromJson(result ?? <String, dynamic>{});
    } catch (e) {
      return const GadgetBypassDiagnoseResult(
        w00g: GadgetBypassProbe(reachable: false, elapsedMs: 0),
        endpoint: GadgetBypassProbe(reachable: false, elapsedMs: 0),
        kcsapi: GadgetBypassProbe(reachable: false, elapsedMs: 0),
      );
    }
  }
}
