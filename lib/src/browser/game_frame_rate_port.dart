import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings/game_frame_rate_settings.dart';

const MethodChannel _defaultGameFrameRateChannel = MethodChannel(
  'app.yahagi.kancollebrowser/game_frame_rate',
);

GameFrameRatePort createPlatformGameFrameRatePort() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return const MethodChannelGameFrameRatePort();
  }
  return const UnsupportedGameFrameRatePort();
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
  Future<void> configure(GameFrameRateMode mode) {
    return channel.invokeMethod<void>('configure', <String, Object?>{
      'mode': mode.wireName,
    });
  }
}

final class UnsupportedGameFrameRatePort implements GameFrameRatePort {
  const UnsupportedGameFrameRatePort();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> configure(GameFrameRateMode mode) async {}
}
