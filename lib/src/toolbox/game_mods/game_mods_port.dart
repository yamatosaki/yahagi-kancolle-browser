import 'package:flutter/services.dart';

import 'game_mods_models.dart';
import 'game_mods_library.dart';

abstract interface class GameModsPort {
  Future<GameModsCapabilities> capabilities();
  Future<GameModsStatus> status();
  Future<GameModsPreflight?> pickAndPreflightArchive();
  Future<void> commitImport(String token);
  Future<void> discardImport(String token);
  Future<void> saveDraft(GameModsConfig config);
  Future<void> cancelChanges();
  Future<GameModsApplyResult> applyAndReload();
  Future<void> removePackage(String id);
  Future<void> resetAll();
}

abstract interface class GameModsArchiveUpdatePort {
  Future<GameModsPreflight?> pickAndPreflightUpdate(String packageId);
}

/// Optional extension so other platforms can keep their existing mod manager.
abstract interface class GameModsLibraryPort {
  Future<bool> chooseLibraryDirectory();
  Future<void> openLibraryDirectory();
  Future<GameModLibraryScan> scanLibrary();
  Future<void> commitLibraryScan(String token);
  Future<void> discardLibraryScan(String token);
}

/// Optional polling API; it does not replace the channel's portrait callbacks.
abstract interface class GameModsProgressPort {
  Future<GameModsOperationProgress?> operationProgress();
}

final class MethodChannelGameModsPort
    implements
        GameModsPort,
        GameModsArchiveUpdatePort,
        GameModsLibraryPort,
        GameModsProgressPort {
  const MethodChannelGameModsPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/mod_manager',
    ),
  ]);
  final MethodChannel channel;
  @override
  Future<GameModsOperationProgress?> operationProgress() async {
    final value = await channel.invokeMethod<Object?>('operationProgress');
    return value == null
        ? null
        : GameModsOperationProgress.fromMap(gameModsMap(value));
  }

  @override
  Future<GameModsCapabilities> capabilities() async =>
      GameModsCapabilities.fromMap(
        gameModsMap(await channel.invokeMethod<Object?>('capabilities')),
      );
  @override
  Future<GameModsStatus> status() async => GameModsStatus.fromMap(
    gameModsMap(await channel.invokeMethod<Object?>('status')),
  );
  @override
  Future<GameModsPreflight?> pickAndPreflightArchive() async {
    final value = await channel.invokeMethod<Object?>(
      'pickAndPreflightArchive',
    );
    return value == null ? null : GameModsPreflight.fromMap(gameModsMap(value));
  }

  @override
  Future<GameModsPreflight?> pickAndPreflightUpdate(String packageId) async {
    final value = await channel.invokeMethod<Object?>(
      'pickAndPreflightUpdate',
      {'id': packageId},
    );
    return value == null ? null : GameModsPreflight.fromMap(gameModsMap(value));
  }

  @override
  Future<void> commitImport(String token) =>
      channel.invokeMethod<void>('commitImport', {'token': token});
  @override
  Future<void> discardImport(String token) =>
      channel.invokeMethod<void>('discardImport', {'token': token});
  @override
  Future<void> saveDraft(GameModsConfig config) =>
      channel.invokeMethod<void>('saveDraft', {'config': config.toMap()});
  @override
  Future<void> cancelChanges() => channel.invokeMethod<void>('cancelChanges');
  @override
  Future<GameModsApplyResult> applyAndReload() async {
    final map = gameModsMap(
      await channel.invokeMethod<Object?>('applyAndReload'),
    );
    return GameModsApplyResult.values.firstWhere(
      (r) => r.name == map['result'],
      orElse: () => GameModsApplyResult.failed,
    );
  }

  @override
  Future<void> removePackage(String id) =>
      channel.invokeMethod<void>('removePackage', {'id': id});
  @override
  Future<void> resetAll() => channel.invokeMethod<void>('resetAll');

  @override
  Future<bool> chooseLibraryDirectory() async =>
      await channel.invokeMethod<bool>('chooseLibraryDirectory') ?? false;
  @override
  Future<void> openLibraryDirectory() =>
      channel.invokeMethod<void>('openLibraryDirectory');
  @override
  Future<GameModLibraryScan> scanLibrary() async => GameModLibraryScan.fromMap(
    gameModsMap(await channel.invokeMethod<Object?>('scanLibrary')),
  );
  @override
  Future<void> commitLibraryScan(String token) =>
      channel.invokeMethod<void>('commitLibraryScan', {'token': token});
  @override
  Future<void> discardLibraryScan(String token) =>
      channel.invokeMethod<void>('discardLibraryScan', {'token': token});
}
