import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../settings/game_frame_rate_settings.dart';
import 'game_frame_rate_runtime_controller.dart';
import 'game_frame_rate_script.dart';

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
  });

  final MethodChannel channel;

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
    const attempts = 12;
    for (var attempt = 0; attempt < attempts; attempt += 1) {
      try {
        await channel.invokeMethod<void>('configure', <String, Object?>{
          'mode': mode.wireName,
        });
        return;
      } on PlatformException catch (error) {
        if (error.code != 'webview_not_found' || attempt == attempts - 1) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
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

  @override
  Future<double?> measuredFps() async {
    final value = await channel.invokeMethod<num>('measuredFps');
    final fps = value?.toDouble();
    return fps != null && fps.isFinite && fps >= 0 ? fps : null;
  }
}

final class UnsupportedGameFrameRatePort implements GameFrameRatePort {
  const UnsupportedGameFrameRatePort();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> configure(GameFrameRateMode mode) async {}
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
