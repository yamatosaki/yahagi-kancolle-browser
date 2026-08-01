import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bridge/captured_api_event.dart';

enum WebViewLoadState { idle, loading, ready, failed }

class PrototypeStatusController extends ChangeNotifier {
  PrototypeStatusController({
    bool Function()? captureEnabled,
    this.maxEvents = 32,
    this.maxMessageBytes = 256 * 1024,
  }) : assert(maxEvents > 0),
       assert(maxMessageBytes > 0),
       _captureEnabled = captureEnabled ?? _captureEnabledByDefault;

  final bool Function() _captureEnabled;
  final int maxEvents;
  final int maxMessageBytes;
  WebViewLoadState _loadState = WebViewLoadState.idle;
  String? _errorMessage;
  String? _lastBridgeError;
  final List<CapturedApiEvent> _capturedEvents = [];

  WebViewLoadState get loadState => _loadState;
  String? get errorMessage => _errorMessage;
  String? get lastBridgeError => _lastBridgeError;
  List<CapturedApiEvent> get capturedEvents =>
      List.unmodifiable(_capturedEvents);
  CapturedApiEvent? get lastEvent =>
      _capturedEvents.isEmpty ? null : _capturedEvents.last;

  String get statusLabel => switch (_loadState) {
    WebViewLoadState.idle => '等待 WebView',
    WebViewLoadState.loading => '页面加载中',
    WebViewLoadState.ready => 'WebView 已就绪',
    WebViewLoadState.failed => 'WebView 加载失败',
  };

  void onPageStarted(String _) {
    _loadState = WebViewLoadState.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void onPageFinished(String _) {
    _loadState = WebViewLoadState.ready;
    _errorMessage = null;
    notifyListeners();
  }

  void onWebResourceError(String description) {
    _loadState = WebViewLoadState.failed;
    _errorMessage = description;
    notifyListeners();
  }

  void onJavaScriptMessage(String message) {
    if (!_captureEnabled()) {
      return;
    }
    if (utf8.encode(message).length > maxMessageBytes) {
      _lastBridgeError = 'Bridge message exceeds size limit';
      notifyListeners();
      return;
    }
    try {
      final event = ApiBridgeDecoder.decode(message);
      _capturedEvents.add(event);
      while (_capturedEvents.length > maxEvents) {
        _capturedEvents.removeAt(0);
      }
      _lastBridgeError = null;
    } on FormatException catch (error) {
      _lastBridgeError = error.message;
    }
    notifyListeners();
  }

  static bool _captureEnabledByDefault() => true;
}
