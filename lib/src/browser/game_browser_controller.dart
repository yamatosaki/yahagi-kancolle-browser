import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_launch_config.dart';
import 'origin_cookie_manager_port.dart';
import 'safe_page_address.dart';

enum GameBrowserMode { localPrototype, realWeb }

enum GamePageLoadState { idle, loading, ready, failed }

enum GameFrameReloadResult {
  reloaded,
  gameFrameNotFound,
  htmlWrapNotFound,
  blocked,
  unsupported,
}

abstract interface class GameBrowserPort {
  Future<void> loadUri(Uri uri);

  Future<void> showLocalHome();

  Future<void> reload();

  Future<GameFrameReloadResult> reloadGameFrame();

  Future<bool> canGoBack();

  Future<void> goBack();

  Future<void> runJavaScript(String javascript);

  Future<void> fitGameScreen();

  Future<void> clearCache();

  Future<void> clearSession();
}

final class GameBrowserController extends ChangeNotifier {
  factory GameBrowserController({
    GameBrowserPort? port,
    Uri? homeUri,
    OriginCookieManagerPort? originCookieManagerPort,
    FutureOr<void> Function()? onSessionReset,
  }) {
    return GameBrowserController._(
      port,
      homeUri ?? GameLaunchConfig.dmmGameEntry,
      originCookieManagerPort ?? const MethodChannelOriginCookieManagerPort(),
      onSessionReset,
    );
  }

  GameBrowserController._(
    this._port,
    this._homeUri,
    this._originCookieManagerPort,
    this.onSessionReset,
  ) : _displayAddress = _homeUri.toString();

  GameBrowserPort? _port;
  Uri _homeUri;
  final OriginCookieManagerPort _originCookieManagerPort;
  final FutureOr<void> Function()? onSessionReset;
  int _sessionResetGeneration = 0;
  bool _initialHomePrepared = false;
  Future<void>? _initialHomePreparation;

  GameBrowserMode _mode = GameBrowserMode.realWeb;
  GamePageLoadState _loadState = GamePageLoadState.idle;
  String _displayAddress;
  String? _errorMessage;
  Future<void>? _reloadInFlight;
  Future<GameFrameReloadResult>? _gameFrameReloadInFlight;

  GameBrowserMode get mode => _mode;
  GamePageLoadState get loadState => _loadState;
  Uri get homeUri => _homeUri;
  String get displayAddress => _displayAddress;
  String? get errorMessage => _errorMessage;
  bool get isOfficialGamePage {
    final uri = Uri.tryParse(_displayAddress);
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'kancolle-server.com' ||
        host.endsWith('.kancolle-server.com');
  }

  void attachPort(GameBrowserPort port) {
    if (identical(_port, port)) {
      return;
    }
    _port = port;
    _reloadInFlight = null;
    _gameFrameReloadInFlight = null;
  }

  void detachPort(GameBrowserPort port) {
    if (identical(_port, port)) {
      _port = null;
      _reloadInFlight = null;
      _gameFrameReloadInFlight = null;
    }
  }

  Future<void> enterDmmLoginTest() async {
    return switchHome(GameLaunchConfig.dmmGameEntry);
  }

  Future<void> switchHome(Uri target) async {
    final generation = ++_sessionResetGeneration;
    await onSessionReset?.call();
    if (generation != _sessionResetGeneration) return;
    _homeUri = target;
    final port = _readyPort();
    if (port == null) {
      return;
    }
    _mode = GameBrowserMode.realWeb;
    _errorMessage = null;
    notifyListeners();
    await _clearEphemeralSessionFor(target);
    if (generation != _sessionResetGeneration) return;
    _initialHomePrepared = true;
    await port.loadUri(target);
  }

  Future<void> prepareInitialHome() {
    if (_initialHomePrepared) return Future<void>.value();
    final existing = _initialHomePreparation;
    if (existing != null) return existing;

    late final Future<void> pending;
    pending = _prepareInitialHome().whenComplete(() {
      if (identical(_initialHomePreparation, pending)) {
        _initialHomePreparation = null;
      }
    });
    _initialHomePreparation = pending;
    return pending;
  }

  Future<void> _prepareInitialHome() async {
    await _clearEphemeralSessionFor(_homeUri);
    _initialHomePrepared = true;
  }

  Future<void> _clearEphemeralSessionFor(Uri entryUri) async {
    if (entryUri == GameLaunchConfig.ooiEntry) {
      await _originCookieManagerPort.clearCookiesForOrigin(
        GameLaunchConfig.ooiOrigin,
      );
    }
  }

  Future<void> goHome() async {
    final port = _readyPort();
    if (port == null) return;
    _mode = GameBrowserMode.realWeb;
    _errorMessage = null;
    notifyListeners();
    await port.loadUri(_homeUri);
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

  Future<GameFrameReloadResult> reloadGameFrame() async {
    final inFlight = _gameFrameReloadInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final port = _readyPort();
    if (port == null) {
      return GameFrameReloadResult.blocked;
    }
    final pending = port.reloadGameFrame();
    _gameFrameReloadInFlight = pending;
    try {
      return await pending;
    } finally {
      if (identical(_gameFrameReloadInFlight, pending)) {
        _gameFrameReloadInFlight = null;
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

  Future<void> fitGameScreen() async {
    final port = _port;
    if (port != null) {
      await port.fitGameScreen();
    }
  }

  Future<void> clearCache() async {
    final port = _port;
    if (port != null) {
      await port.clearCache();
    }
  }

  Future<void> logoutAndClearSession() async {
    final generation = ++_sessionResetGeneration;
    await onSessionReset?.call();
    if (generation != _sessionResetGeneration) return;
    final port = _readyPort();
    if (port == null) {
      return;
    }
    await port.clearSession();
    if (generation != _sessionResetGeneration) return;
    _mode = GameBrowserMode.realWeb;
    _errorMessage = null;
    notifyListeners();
    await port.loadUri(_homeUri);
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
