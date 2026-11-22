import 'package:flutter/services.dart';

final class GameStartupActivitySnapshot {
  const GameStartupActivitySnapshot({
    required this.navigationId,
    required this.requestCount,
    required this.gameResources,
    required this.gameApi,
  });

  final int navigationId;
  final int requestCount;
  final bool gameResources;
  final bool gameApi;
}

abstract interface class GameStartupActivityPort {
  Future<GameStartupActivitySnapshot?> snapshot({required bool nativeActivity});
}

final class MethodChannelGameStartupActivityPort
    implements GameStartupActivityPort {
  const MethodChannelGameStartupActivityPort();

  static const _channel = MethodChannel(
    'app.yahagi.kancollebrowser/game_startup_activity',
  );

  @override
  Future<GameStartupActivitySnapshot?> snapshot({
    required bool nativeActivity,
  }) async {
    final Object? payload;
    try {
      payload = await _channel.invokeMethod<Object?>('snapshot', {
        'nativeActivity': nativeActivity,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    if (payload is! Map<Object?, Object?> || payload.length != 4) return null;
    final navigationId = payload['navigationId'];
    final requestCount = payload['requestCount'];
    final gameResources = payload['gameResources'];
    final gameApi = payload['gameApi'];
    if (navigationId is! int ||
        navigationId <= 0 ||
        requestCount is! int ||
        requestCount < 0 ||
        gameResources is! bool ||
        gameApi is! bool ||
        (requestCount == 0 && (gameResources || gameApi))) {
      return null;
    }
    return GameStartupActivitySnapshot(
      navigationId: navigationId,
      requestCount: requestCount,
      gameResources: gameResources,
      gameApi: gameApi,
    );
  }
}
