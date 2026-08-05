import 'package:flutter/foundation.dart';

import 'game_launch_config.dart';
import 'safe_page_address.dart';

enum GameBrowserMode { localPrototype, realWeb }

enum GamePageLoadState { idle, loading, ready, failed }

abstract interface class GameBrowserPort {
  Future<void> loadUri(Uri uri);

  Future<void> showLocalHome();

  Future<void> reload();

  Future<bool> canGoBack();

  Future<void> goBack();

  Future<void> runJavaScript(String javascript);

  Future<void> clearCache();
}

final class GameBrowserController extends ChangeNotifier {
  factory GameBrowserController({GameBrowserPort? port}) {
    return GameBrowserController._(port);
  }

  GameBrowserController._(this._port);

  GameBrowserPort? _port;

  GameBrowserMode _mode = GameBrowserMode.realWeb;
  GamePageLoadState _loadState = GamePageLoadState.idle;
  String _displayAddress = GameLaunchConfig.dmmGameEntry.toString();
  String? _errorMessage;
  Future<void>? _reloadInFlight;

  GameBrowserMode get mode => _mode;
  GamePageLoadState get loadState => _loadState;
  String get displayAddress => _displayAddress;
  String? get errorMessage => _errorMessage;

  void attachPort(GameBrowserPort port) {
    _port = port;
  }

  Future<void> enterDmmLoginTest() async {
    final port = _readyPort();
    if (port == null) {
      return;
    }
    _mode = GameBrowserMode.realWeb;
    _errorMessage = null;
    notifyListeners();
    await port.loadUri(GameLaunchConfig.dmmGameEntry);
  }

  Future<void> goHome() async {
    return enterDmmLoginTest();
  }

  Future<void> reload() async {
    final inFlight = _reloadInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final port = _readyPort();
    if (port != null) {
      final pending = port.reload();
      _reloadInFlight = pending;
      try {
        await pending;
      } finally {
        if (identical(_reloadInFlight, pending)) {
          _reloadInFlight = null;
        }
      }
    }
  }

  Future<void> goBack() async {
    final port = _readyPort();
    if (port == null) {
      return;
    }
    if (_mode == GameBrowserMode.realWeb && await port.canGoBack()) {
      await port.goBack();
      return;
    }
    await goHome();
  }

  Future<void> runJavaScript(String javascript) async {
    final port = _port;
    if (port != null) {
      await port.runJavaScript(javascript);
    }
  }

  Future<void> clearCache() async {
    final port = _port;
    if (port != null) {
      await port.clearCache();
    }
  }

  void onPageStarted(String url) {
    _loadState = GamePageLoadState.loading;
    _errorMessage = null;
    _updateDisplayAddress(url);
    notifyListeners();
  }

  void onPageFinished(String url) {
    _loadState = GamePageLoadState.ready;
    _errorMessage = null;
    _updateDisplayAddress(url);
    notifyListeners();
  }

  void onWebResourceError({
    required String description,
    required bool isForMainFrame,
  }) {
    if (!isForMainFrame) {
      return;
    }
    _loadState = GamePageLoadState.failed;
    _errorMessage = description;
    notifyListeners();
  }

  void onBlockedNavigation(Uri uri) {
    final scheme = uri.scheme.isEmpty ? '未知协议' : uri.scheme;
    _errorMessage = '暂不支持的外部跳转：$scheme';
    notifyListeners();
  }

  void _updateDisplayAddress(String url) {
    final uri = Uri.tryParse(url);
    if (_mode == GameBrowserMode.localPrototype &&
        (uri == null || !SafePageAddress.canNavigate(uri))) {
      _displayAddress = '本地模拟页';
      return;
    }
    _displayAddress = SafePageAddress.fromRaw(url).displayText;
  }

  GameBrowserPort? _readyPort() {
    final port = _port;
    if (port != null) {
      return port;
    }
    _errorMessage = 'WebView 尚未就绪';
    notifyListeners();
    return null;
  }
}
