import 'package:flutter/foundation.dart';
import '../browser/network_proxy_channel.dart';
import 'network_settings_store.dart';

class NetworkSettingsController extends ChangeNotifier {
  NetworkSettingsController({required this.store});

  final NetworkSettingsStore store;

  NetworkSettings _settings = const NetworkSettings();
  NetworkSettings get settings => _settings;

  bool _isProxyOverrideSupported = false;
  bool get isProxyOverrideSupported => _isProxyOverrideSupported;

  NetworkStatus _networkStatus = const NetworkStatus(
    hasVpn: false,
    hasActiveNetwork: false,
  );
  NetworkStatus get networkStatus => _networkStatus;

  ProxyResult? _lastTestResult;
  ProxyResult? get lastTestResult => _lastTestResult;

  bool _isTesting = false;
  bool get isTesting => _isTesting;

  bool _isApplying = false;
  bool get isApplying => _isApplying;

  Future<void> initialize() async {
    _settings = await store.loadSettings();
    _isProxyOverrideSupported =
        await NetworkProxyChannel.isProxyOverrideSupported();
    _networkStatus = await NetworkProxyChannel.getNetworkStatus();
    notifyListeners();
  }

  Future<void> refreshNetworkStatus() async {
    _networkStatus = await NetworkProxyChannel.getNetworkStatus();
    notifyListeners();
  }

  void clearTestResult() {
    _lastTestResult = null;
    notifyListeners();
  }

  Future<void> testConnection(NetworkMode mode, String host, int port) async {
    if (_isTesting) return;
    _isTesting = true;
    _lastTestResult = null;
    notifyListeners();

    ProxyResult result = const ProxyResult(
      success: false,
      code: 'init',
      message: 'init',
      elapsedMs: 0,
    );
    try {
      result = await NetworkProxyChannel.runNetworkDiagnostic(
        mode.name,
        host,
        port,
      );
    } catch (e) {
      result = ProxyResult(
        success: false,
        code: 'exception',
        message: e.toString(),
        elapsedMs: 0,
      );
    } finally {
      _lastTestResult = result;
      _isTesting = false;
      notifyListeners();
    }
  }

  Future<ProxyResult> applySettings(
    NetworkMode mode,
    String host,
    int port,
  ) async {
    if (_isApplying) {
      return const ProxyResult(
        success: false,
        code: 'proxy_operation_busy',
        message: 'proxy_operation_busy',
        elapsedMs: 0,
      );
    }

    _isApplying = true;
    notifyListeners();

    ProxyResult result = const ProxyResult(
      success: false,
      code: 'init',
      message: 'init',
      elapsedMs: 0,
    );
    try {
      if (mode == NetworkMode.system) {
        result = await NetworkProxyChannel.clearProxyOverride();
      } else if (mode == NetworkMode.httpProxy) {
        result = await NetworkProxyChannel.applyHttpProxy(host, port);
      } else if (mode == NetworkMode.socks5Proxy) {
        result = await NetworkProxyChannel.applySocksProxy(host, port);
      } else {
        result = const ProxyResult(
          success: false,
          code: 'unknown_mode',
          message: 'unknown_mode',
          elapsedMs: 0,
        );
      }

      if (result.success) {
        _settings = _settings.copyWith(mode: mode, host: host, port: port);
        await store.saveSettings(_settings);
      }
    } finally {
      _isApplying = false;
      notifyListeners();
    }

    return result;
  }
}
