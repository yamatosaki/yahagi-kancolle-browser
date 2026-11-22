import 'package:flutter/services.dart';

import 'game_resource_cache_store.dart';

enum GameResourceCacheState {
  idle,
  downloading,
  paused,
  complete,
  checking,
  capacityBlocked,
  error,
}

final class GameResourceManifest {
  const GameResourceManifest({
    required this.profile,
    required this.urls,
    required this.targetBytes,
    this.expectedLengths,
  }) : assert(
         expectedLengths == null || expectedLengths.length == urls.length,
         'Expected lengths must align with manifest URLs',
       );

  final String profile;
  final List<String> urls;
  final int targetBytes;
  final List<int>? expectedLengths;
}

final class GameResourceCacheStatus {
  const GameResourceCacheStatus({
    required this.mode,
    required this.state,
    required this.cachedBytes,
    required this.maxBytes,
    required this.targetBytes,
    required this.downloadedBytes,
    required this.bytesPerSecond,
    required this.remainingSeconds,
    required this.missingCount,
    required this.damagedCount,
    this.outdatedCount = 0,
    required this.fileCount,
    required this.capacityBlocked,
    this.isMetered = false,
    this.waitingForWifi = false,
    this.manifestReady = true,
    this.preloadBlockedByProxy = false,
    this.supported = true,
    this.policyError = false,
  });

  static const empty = GameResourceCacheStatus(
    mode: GameResourceCacheMode.temporary,
    state: GameResourceCacheState.idle,
    cachedBytes: 0,
    maxBytes: 1000000000,
    targetBytes: 0,
    downloadedBytes: 0,
    bytesPerSecond: 0,
    remainingSeconds: null,
    missingCount: 0,
    damagedCount: 0,
    outdatedCount: 0,
    fileCount: 0,
    capacityBlocked: false,
    isMetered: false,
    waitingForWifi: false,
    manifestReady: false,
  );

  final GameResourceCacheMode mode;
  final GameResourceCacheState state;
  final int cachedBytes;
  final int maxBytes;
  final int targetBytes;
  final int downloadedBytes;
  final int bytesPerSecond;
  final int? remainingSeconds;
  final int missingCount;
  final int damagedCount;
  final int outdatedCount;
  final int fileCount;
  final bool capacityBlocked;
  final bool isMetered;
  final bool waitingForWifi;
  final bool manifestReady;
  final bool preloadBlockedByProxy;
  final bool supported;
  final bool policyError;

  bool get isRunning =>
      state == GameResourceCacheState.downloading ||
      state == GameResourceCacheState.checking;

  factory GameResourceCacheStatus.fromMap(Map<Object?, Object?> map) {
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;
    final stateName = map['state'] as String?;
    return GameResourceCacheStatus(
      mode: GameResourceCacheModeWire.fromWireName(map['mode'] as String?),
      state: GameResourceCacheState.values.firstWhere(
        (state) => state.name == stateName,
        orElse: () => GameResourceCacheState.idle,
      ),
      cachedBytes: number('cachedBytes'),
      maxBytes: number('maxBytes'),
      targetBytes: number('targetBytes'),
      downloadedBytes: number('downloadedBytes'),
      bytesPerSecond: number('bytesPerSecond'),
      remainingSeconds: map['remainingSeconds'] == null
          ? null
          : number('remainingSeconds'),
      missingCount: number('missingCount'),
      damagedCount: number('damagedCount'),
      outdatedCount: number('outdatedCount'),
      fileCount: number('fileCount'),
      capacityBlocked: map['capacityBlocked'] as bool? ?? false,
      isMetered: map['isMetered'] as bool? ?? false,
      waitingForWifi: map['waitingForWifi'] as bool? ?? false,
      manifestReady: map['manifestReady'] as bool? ?? false,
      preloadBlockedByProxy: map['preloadBlockedByProxy'] as bool? ?? false,
      supported: map['supported'] as bool? ?? true,
      policyError: map['policyError'] as bool? ?? false,
    );
  }
}

abstract interface class GameResourceCachePort {
  Future<bool> configure(GameResourceCacheMode mode);
  Future<GameResourceCacheStatus> status();
  Future<bool> setManifest(
    GameResourceManifest manifest, {
    bool Function()? shouldContinue,
  });
  Future<bool> startDownload({bool allowMetered = false});
  Future<bool> pauseDownload();
  Future<GameResourceCacheStatus> checkIntegrity();
  Future<bool> repair({bool allowMetered = false});
  Future<bool> clear();
}

final class MethodChannelGameResourceCachePort
    implements GameResourceCachePort {
  const MethodChannelGameResourceCachePort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/game_resource_cache',
    ),
  ]);

  final MethodChannel channel;
  static const int _manifestBatchSize = 500;
  static int _nextManifestTransaction = 0;

  @override
  Future<bool> configure(GameResourceCacheMode mode) async =>
      await channel.invokeMethod<bool>('configure', <String, Object?>{
        'mode': mode.wireName,
      }) ??
      false;

  @override
  Future<GameResourceCacheStatus> status() async =>
      _statusFrom(await channel.invokeMethod<Map<Object?, Object?>>('status'));

  @override
  Future<bool> setManifest(
    GameResourceManifest manifest, {
    bool Function()? shouldContinue,
  }) async {
    final transactionId =
        '${DateTime.now().microsecondsSinceEpoch}-${_nextManifestTransaction++}';
    var begun = false;
    var committed = false;
    try {
      if (shouldContinue?.call() == false) return false;
      begun =
          await channel.invokeMethod<bool>('beginManifest', <String, Object?>{
            'transactionId': transactionId,
            'profile': manifest.profile,
            'targetBytes': manifest.targetBytes,
          }) ??
          false;
      if (!begun) return false;
      for (
        var offset = 0;
        offset < manifest.urls.length;
        offset += _manifestBatchSize
      ) {
        if (shouldContinue?.call() == false) return false;
        final end = (offset + _manifestBatchSize).clamp(
          0,
          manifest.urls.length,
        );
        final appended =
            await channel
                .invokeMethod<bool>('appendManifest', <String, Object?>{
                  'transactionId': transactionId,
                  'urls': manifest.urls.sublist(offset, end),
                  if (manifest.expectedLengths case final lengths?)
                    'expectedLengths': lengths.sublist(offset, end),
                }) ??
            false;
        if (!appended) return false;
      }
      if (shouldContinue?.call() == false) return false;
      committed =
          await channel.invokeMethod<bool>('commitManifest', <String, Object?>{
            'transactionId': transactionId,
          }) ??
          false;
      return committed;
    } finally {
      if (begun && !committed) {
        try {
          await channel.invokeMethod<bool>('abortManifest', <String, Object?>{
            'transactionId': transactionId,
          });
        } on PlatformException {
          // The channel is already unavailable; native process cleanup owns it.
        }
      }
    }
  }

  @override
  Future<bool> startDownload({bool allowMetered = false}) async =>
      await channel.invokeMethod<bool>('startDownload', <String, Object?>{
        'allowMetered': allowMetered,
      }) ??
      false;

  @override
  Future<bool> pauseDownload() async =>
      await channel.invokeMethod<bool>('pauseDownload') ?? false;

  @override
  Future<GameResourceCacheStatus> checkIntegrity() async => _statusFrom(
    await channel.invokeMethod<Map<Object?, Object?>>('checkIntegrity'),
  );

  @override
  Future<bool> repair({bool allowMetered = false}) async =>
      await channel.invokeMethod<bool>('repair', <String, Object?>{
        'allowMetered': allowMetered,
      }) ??
      false;

  @override
  Future<bool> clear() async =>
      await channel.invokeMethod<bool>('clear') ?? false;

  GameResourceCacheStatus _statusFrom(Map<Object?, Object?>? value) =>
      value == null
      ? GameResourceCacheStatus.empty
      : GameResourceCacheStatus.fromMap(value);
}
