import 'package:flutter/services.dart';

abstract interface class GameScreenshotPort {
  Future<String> captureWebView();
}

final class MethodChannelGameScreenshotPort implements GameScreenshotPort {
  const MethodChannelGameScreenshotPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/game_screenshot',
    ),
  ]);

  final MethodChannel channel;

  @override
  Future<String> captureWebView() async {
    final path = await channel.invokeMethod<String>('captureWebView');
    if (path == null || path.isEmpty) {
      throw StateError('Android did not return a screenshot path');
    }
    return path;
  }
}

final class GameScreenshotResult {
  const GameScreenshotResult({this.path, this.errorMessage});

  final String? path;
  final String? errorMessage;
}

final class GameScreenshotController {
  GameScreenshotController(this._port);

  final GameScreenshotPort _port;
  Future<GameScreenshotResult>? _inFlight;

  Future<GameScreenshotResult> capture() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    late final Future<GameScreenshotResult> pending;
    pending = _capture().whenComplete(() {
      if (identical(_inFlight, pending)) {
        _inFlight = null;
      }
    });
    _inFlight = pending;
    return pending;
  }

  Future<GameScreenshotResult> _capture() async {
    try {
      return GameScreenshotResult(path: await _port.captureWebView());
    } catch (error) {
      return GameScreenshotResult(errorMessage: error.toString());
    }
  }
}
