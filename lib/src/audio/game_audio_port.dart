import 'package:flutter/services.dart';

abstract interface class GameAudioPort {
  Future<bool> isSupported();

  Future<void> setMuted(bool muted);
}

final class MethodChannelGameAudioPort implements GameAudioPort {
  MethodChannelGameAudioPort([
    this._channel = const MethodChannel(
      'app.yahagi.kancollebrowser/game_audio',
    ),
  ]);

  final MethodChannel _channel;

  @override
  Future<bool> isSupported() async {
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<void> setMuted(bool muted) {
    return _channel.invokeMethod<void>('setMuted', <String, Object>{
      'muted': muted,
    });
  }
}
