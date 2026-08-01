import 'package:flutter/services.dart';

class ProxyResult {
  const ProxyResult({
    required this.success,
    required this.code,
    required this.message,
    required this.elapsedMs,
    this.details = const {},
  });

  final bool success;
  final String code;
  final String message;
  final int elapsedMs;
  final Map<String, dynamic> details;

  factory ProxyResult.fromJson(Map<String, dynamic> json) {
    return ProxyResult(
      success: json['success'] as bool? ?? false,
      code: json['code'] as String? ?? 'unknown_error',
      message: json['message'] as String? ?? 'Unknown error',
      elapsedMs: json['elapsedMs'] as int? ?? 0,
      details: Map<String, dynamic>.from(json['details'] as Map? ?? {}),
    );
  }
}

class NetworkStatus {
  const NetworkStatus({required this.hasVpn, required this.hasActiveNetwork});

  final bool hasVpn;
  final bool hasActiveNetwork;

  factory NetworkStatus.fromJson(Map<String, dynamic> json) {
    return NetworkStatus(
      hasVpn: json['hasVpn'] as bool? ?? false,
      hasActiveNetwork: json['hasActiveNetwork'] as bool? ?? false,
    );
  }
}

class NetworkProxyChannel {
  static const MethodChannel _channel = MethodChannel(
    'app.yahagi.kancollebrowser/network_proxy',
  );

  static Future<bool> isProxyOverrideSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isProxyOverrideSupported',
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<NetworkStatus> getNetworkStatus() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getNetworkStatus',
      );
      return NetworkStatus.fromJson(result ?? {});
    } catch (e) {
      return const NetworkStatus(hasVpn: false, hasActiveNetwork: false);
    }
  }

  static Future<ProxyResult> applyHttpProxy(String host, int port) async {
    return _invokeProxyMethod('applyHttpProxy', {'host': host, 'port': port});
  }

  static Future<ProxyResult> applySocksProxy(String host, int port) async {
    return _invokeProxyMethod('applySocksProxy', {'host': host, 'port': port});
  }

  static Future<ProxyResult> clearProxyOverride() async {
    return _invokeProxyMethod('clearProxyOverride');
  }

  static Future<ProxyResult> runNetworkDiagnostic(
    String mode,
    String host,
    int port,
  ) async {
    return _invokeProxyMethod('runNetworkDiagnostic', {
      'mode': mode,
      'host': host,
      'port': port,
    });
  }

  static Future<ProxyResult> _invokeProxyMethod(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final startTime = DateTime.now();
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (result != null) {
        return ProxyResult.fromJson(result);
      }
      return ProxyResult(
        success: false,
        code: 'null_result',
        message: 'No result returned from native platform',
        elapsedMs: DateTime.now().difference(startTime).inMilliseconds,
      );
    } on PlatformException catch (e) {
      return ProxyResult(
        success: false,
        code: e.code,
        message: e.message ?? 'Platform exception occurred',
        elapsedMs: DateTime.now().difference(startTime).inMilliseconds,
        details: {'stacktrace': e.stacktrace},
      );
    } catch (e) {
      return ProxyResult(
        success: false,
        code: 'unknown_error',
        message: e.toString(),
        elapsedMs: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }
}
