import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../settings/game_frame_rate_settings.dart';
import 'game_frame_rate_runtime_controller.dart';
import 'game_frame_rate_script.dart';

export '../settings/game_frame_rate_settings.dart'
    show GameFrameRateConfigurationCancelledException;

const MethodChannel _defaultGameFrameRateChannel = MethodChannel(
  'app.yahagi.kancollebrowser/game_frame_rate',
);

GameFrameRatePort createPlatformGameFrameRatePort() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return const MethodChannelGameFrameRatePort();
  }
  return const UnsupportedGameFrameRatePort();
}

GameFrameRateRuntimePort createGameFrameRateRuntimePort(
  WebViewController controller,
) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return const MethodChannelGameFrameRateRuntimePort();
  }
  return WebViewGameFrameRateRuntimePort(controller);
}

final class MethodChannelGameFrameRatePort implements GameFrameRatePort {
  const MethodChannelGameFrameRatePort({
    this.channel = _defaultGameFrameRateChannel,
    this.isActive,
    this.cancelled,
  });

  final MethodChannel channel;
  final bool Function()? isActive;
  final Future<void>? cancelled;

  @override
  Future<bool> isSupported() async {
    try {
      return await channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> configure(GameFrameRateMode mode) async {
    var cancellationRequested = false;
    final cancellation = cancelled?.then<void>((_) {
      cancellationRequested = true;
    });
    Future<void> waitForConfiguration(Future<void> operation) {
      return Future.any<void>(<Future<void>>[
        operation,
        if (cancellation != null)
          cancellation.then<void>((_) {
            throw const GameFrameRateConfigurationCancelledException();
          }),
      ]);
    }

    // Observe an already completed cancellation before sending native work.
    if (cancellation != null) await Future<void>.value();
    const attempts = 60;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      _ensureActive(cancellationRequested);
      try {
        await waitForConfiguration(
          channel.invokeMethod<void>('configure', <String, Object?>{
            'mode': mode.wireName,
          }),
        );
        _ensureActive(cancellationRequested);
        return;
      } catch (error) {
        _ensureActive(cancellationRequested);
        if (error is! PlatformException ||
            error.code != 'webview_not_found' ||
            attempt == attempts - 1) {
          rethrow;
        }
        await waitForConfiguration(
          Future<void>.delayed(const Duration(milliseconds: 16)),
        );
        _ensureActive(cancellationRequested);
      }
    }
  }

  void _ensureActive(bool cancellationRequested) {
    if (cancellationRequested || isActive?.call() == false) {
      throw const GameFrameRateConfigurationCancelledException();
    }
  }
}

final class MethodChannelGameFrameRateRuntimePort
    implements GameFrameRateRuntimePort {
  const MethodChannelGameFrameRateRuntimePort({
    this.channel = _defaultGameFrameRateChannel,
  });

  final MethodChannel channel;

  @override
  Future<void> apply(GameFrameRateTarget target) {
    return channel.invokeMethod<void>('applyTarget', <String, Object?>{
      'target': target.name,
    });
  }

  /// Cached game-loop and main-canvas render statistics, separate from Flutter.
  Future<Map<Object?, Object?>?> performanceSnapshot() {
    return channel.invokeMapMethod<Object?, Object?>('performanceSnapshot');
  }

  /// Temporary layer comparison; [GameWebViewLayerMode.restore] restores the
  /// original configuration. Neither option changes the canvas resolution.
  Future<Map<Object?, Object?>?> setLayerMode(GameWebViewLayerMode mode) {
    return channel.invokeMapMethod<Object?, Object?>(
      'setLayerMode',
      <String, Object?>{'mode': mode.name},
    );
  }

  @override
  Future<double?> measuredFps() async {
    final value = await channel.invokeMethod<num>('measuredFps');
    final fps = value?.toDouble();
    return fps != null && fps.isFinite && fps >= 0 ? fps : null;
  }
}

enum GameWebViewLayerMode { hardware, platformDefault, restore }

final class UnsupportedGameFrameRatePort implements GameFrameRatePort {
  const UnsupportedGameFrameRatePort();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> configure(GameFrameRateMode mode) async {
    throw PlatformException(code: 'frame_rate_unsupported');
  }
}

final class WebViewGameFrameRateRuntimePort
    implements GameFrameRateRuntimePort {
  const WebViewGameFrameRateRuntimePort(this.controller);

  final WebViewController controller;

  @override
  Future<void> apply(GameFrameRateTarget target) {
    return controller.runJavaScript(gameFrameRateApplyScript(target));
  }

  @override
  Future<double?> measuredFps() async {
    final value = await controller.runJavaScriptReturningResult(
      gameFrameRateMeasurementScript,
    );
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }
}
