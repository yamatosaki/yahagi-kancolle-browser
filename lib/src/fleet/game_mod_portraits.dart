import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as image;
import 'package:shared_preferences/shared_preferences.dart';

import '../game_state/game_state.dart';
import 'ship_portrait.dart' show ShipPortraitUriBuilder;

abstract interface class GameModPortraitStore {
  Future<bool?> readEnabled();
  Future<void> writeEnabled(bool enabled);
}

final class SharedPreferencesGameModPortraitStore
    implements GameModPortraitStore {
  static const key = 'game_mod_portrait_sync_enabled';

  @override
  Future<bool?> readEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(key);

  @override
  Future<void> writeEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final previous = preferences.getBool(key);
    try {
      if (!await preferences.setBool(key, enabled)) {
        throw StateError('portrait sync preference was not saved');
      }
    } catch (_) {
      // SharedPreferences changes its Dart cache before platform completion.
      try {
        if (previous == null) {
          await preferences.remove(key);
        } else {
          await preferences.setBool(key, previous);
        }
      } catch (_) {}
      rethrow;
    }
  }
}

abstract interface class GameModPortraitPort {
  Future<GameModPortraitSnapshot> snapshot();
  Future<Uint8List?> read({required String token, required String resourceId});
  void setChangedHandler(VoidCallback? handler);
}

final class MethodChannelGameModPortraitPort implements GameModPortraitPort {
  MethodChannelGameModPortraitPort([
    this.channel = const MethodChannel(
      'app.yahagi.kancollebrowser/mod_manager',
    ),
  ]);
  final MethodChannel channel;

  @override
  Future<GameModPortraitSnapshot> snapshot() async {
    final value = await channel.invokeMapMethod<Object?, Object?>(
      'portraitSnapshot',
    );
    return GameModPortraitSnapshot.fromMap(value ?? const {});
  }

  @override
  Future<Uint8List?> read({
    required String token,
    required String resourceId,
  }) => channel.invokeMethod<Uint8List>('readPortrait', {
    'token': token,
    'resourceId': resourceId,
  });

  @override
  void setChangedHandler(VoidCallback? handler) {
    channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'portraitsChanged') handler();
            },
    );
  }
}

enum GameModPortraitLayout { remodel, banner, characterFull, full }

final class GameModPortraitResource {
  const GameModPortraitResource({required this.id, required this.path});
  final String id;
  final String path;
  GameModPortraitLayout get layout {
    final layoutPath = path.replaceAll('_dmg/', '/');
    return layoutPath.contains('/remodel/')
        ? GameModPortraitLayout.remodel
        : layoutPath.contains('/banner/')
        ? GameModPortraitLayout.banner
        : layoutPath.contains('/character_full/')
        ? GameModPortraitLayout.characterFull
        : GameModPortraitLayout.full;
  }
}

final class GameModPortraitSnapshot {
  GameModPortraitSnapshot.fromMap(Map<Object?, Object?> map)
    : this._(
        map['token'] is String ? map['token'] as String : '',
        List.unmodifiable([
          for (final value
              in (map['resources'] is List
                  ? map['resources'] as List
                  : const []))
            if (value is Map &&
                value['id'] is String &&
                value['path'] is String)
              GameModPortraitResource(
                id: value['id'] as String,
                path: (value['path'] as String).replaceFirst(
                  RegExp(r'^/+'),
                  '',
                ),
              ),
        ]),
      );

  GameModPortraitSnapshot._(this.token, this.resources)
    : _resourcesByPath = _indexResources(resources);

  final String token;
  final List<GameModPortraitResource> resources;
  final Map<String, GameModPortraitResource> _resourcesByPath;

  static Map<String, GameModPortraitResource> _indexResources(
    List<GameModPortraitResource> resources,
  ) {
    final byPath = <String, GameModPortraitResource>{};
    for (final resource in resources) {
      // Preserve the first match even when normalized paths are duplicated.
      byPath.putIfAbsent(resource.path, () => resource);
    }
    return Map.unmodifiable(byPath);
  }
}

abstract final class GameModPortraitResolver {
  static GameModPortraitResource? select(
    MasterShip ship,
    GameModPortraitSnapshot snapshot, {
    bool isDamaged = false,
  }) {
    final id = ship.id.toString().padLeft(4, '0');
    for (final baseType in ['remodel', 'banner', 'character_full', 'full']) {
      final type = isDamaged ? '${baseType}_dmg' : baseType;
      final cipher = ShipPortraitUriBuilder.createCipher(ship.id, 'ship_$type');
      final filename = baseType == 'full' ? ship.portraitFileName : null;
      if (baseType == 'full' &&
          (filename == null || !RegExp(r'^[a-z0-9]+$').hasMatch(filename))) {
        continue;
      }
      final path =
          'kcs2/resources/ship/$type/${id}_$cipher${filename == null ? '' : '_$filename'}.png';
      final resource = snapshot._resourcesByPath[path];
      if (resource != null) return resource;
    }
    return null;
  }
}

final class GameModPortraitImage {
  const GameModPortraitImage({
    required this.bytes,
    required this.layout,
    required this.cacheKey,
  });
  final Uint8List bytes;
  final GameModPortraitLayout layout;
  final String cacheKey;
}

class GameModPortraitController extends ChangeNotifier
    with WidgetsBindingObserver {
  GameModPortraitController({
    GameModPortraitPort? port,
    GameModPortraitStore? store,
  }) : _port = port ?? MethodChannelGameModPortraitPort(),
       _store = store ?? SharedPreferencesGameModPortraitStore();
  final GameModPortraitPort _port;
  final GameModPortraitStore _store;
  final _images = <String, Future<GameModPortraitImage?>>{};
  GameModPortraitSnapshot? _snapshot;
  bool _enabled = true;
  bool _saving = false;
  bool _disposed = false;
  bool _observing = false;
  int _refreshGeneration = 0;
  int _imageGeneration = 0;
  String? _errorCode;
  Future<void>? _initialization;

  bool get enabled => _enabled;
  bool get saving => _saving;
  String? get errorCode => _errorCode;
  String? get snapshotToken => _snapshot?.token;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final enabled = await _store.readEnabled() ?? true;
      if (_disposed) return;
      _enabled = enabled;
    } catch (_) {
      if (_disposed) return;
      _errorCode = 'portrait_sync_load_failed';
    }
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
    _port.setChangedHandler(() => unawaited(refresh()));
    notifyListeners();
    await refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_refreshGeneration;
    GameModPortraitSnapshot? snapshot;
    try {
      snapshot = await _port.snapshot();
    } catch (_) {
      // Unavailable native support or a failed read must preserve official art.
    }
    if (_disposed || generation != _refreshGeneration) return;
    if (_snapshot?.token == snapshot?.token) return;
    _snapshot = snapshot;
    _imageGeneration++;
    _images.clear();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed || _saving || value == _enabled) return;
    final previous = _enabled;
    _enabled = value;
    _saving = true;
    _errorCode = null;
    _imageGeneration++;
    _images.clear();
    notifyListeners();
    try {
      await _store.writeEnabled(value);
    } catch (_) {
      if (_disposed) return;
      _enabled = previous;
      _errorCode = 'portrait_sync_save_failed';
      _imageGeneration++;
      _images.clear();
    }
    if (_disposed) return;
    _saving = false;
    notifyListeners();
  }

  Future<GameModPortraitImage?> resolve(
    MasterShip ship, {
    bool isDamaged = false,
  }) {
    final snapshot = _snapshot;
    if (_disposed || !_enabled || snapshot == null || snapshot.token.isEmpty) {
      return SynchronousFuture(null);
    }
    final resource = GameModPortraitResolver.select(
      ship,
      snapshot,
      isDamaged: isDamaged,
    );
    if (resource == null) return SynchronousFuture(null);
    final key = '${snapshot.token}/${resource.id}/fixed-v2';
    final existing = _images.remove(key);
    if (existing != null) {
      _images[key] = existing;
      return existing;
    }
    final generation = _imageGeneration;
    late final Future<GameModPortraitImage?> operation;
    operation = _readImage(snapshot.token, resource, key).then((result) {
      final current = !_disposed && _enabled && generation == _imageGeneration
          ? result
          : null;
      if (identical(_images[key], operation)) {
        _images[key] = SynchronousFuture(current);
      }
      return current;
    });
    _images[key] = operation;
    // PNG thumbnails are separate from the official file cache and bounded.
    while (_images.length > 48) {
      _images.remove(_images.keys.first);
    }
    return operation;
  }

  Future<GameModPortraitImage?> _readImage(
    String token,
    GameModPortraitResource resource,
    String key,
  ) async {
    try {
      final bytes = await _port.read(token: token, resourceId: resource.id);
      if (bytes == null || bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
        return null;
      }
      final prepared = await compute(_preparePortrait, (
        bytes,
        resource.layout,
      ));
      if (prepared == null) return null;
      return GameModPortraitImage(
        bytes: prepared,
        layout: resource.layout,
        cacheKey: key,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _refreshGeneration++;
    _imageGeneration++;
    _images.clear();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _port.setChangedHandler(null);
    }
    super.dispose();
  }
}

Uint8List? _preparePortrait((Uint8List, GameModPortraitLayout) request) {
  final (bytes, layout) = request;
  // Check dimensions before decoding large inputs. Never feed arbitrary bytes
  // directly to a platform image codec and never overwrite official resources.
  if (bytes.length < 24 ||
      bytes[0] != 137 ||
      bytes[1] != 80 ||
      bytes[2] != 78 ||
      bytes[3] != 71) {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  final width = data.getUint32(16), height = data.getUint32(20);
  if (width == 0 ||
      height == 0 ||
      width > 8192 ||
      height > 8192 ||
      width * height > 16 * 1024 * 1024) {
    return null;
  }
  try {
    final decoded = image.decodePng(bytes);
    if (decoded == null) return null;
    if (layout == GameModPortraitLayout.remodel) return bytes;
    if (layout == GameModPortraitLayout.banner) {
      // One fixed banner template for every package, using only canvas size.
      final cropWidth = (decoded.height * 1.7).round().clamp(1, decoded.width);
      final x = (decoded.width * .65 - cropWidth / 2).round().clamp(
        0,
        decoded.width - cropWidth,
      );
      return Uint8List.fromList(
        image.encodePng(
          image.copyCrop(
            decoded,
            x: x,
            y: 0,
            width: cropWidth,
            height: decoded.height,
          ),
        ),
      );
    }
    // character_full uses the game's centered character canvas; package full
    // images use a separate top-left template. Both depend only on dimensions.
    final side = (decoded.height * .30).round().clamp(1, decoded.width);
    final x = layout == GameModPortraitLayout.characterFull
        ? ((decoded.width - side) / 2).round()
        : 0;
    final thumbnail = image.copyResize(
      image.copyCrop(decoded, x: x, y: 0, width: side, height: side),
      width: 256,
      height: 256,
    );
    return Uint8List.fromList(image.encodePng(thumbnail));
  } catch (_) {
    return null;
  }
}

class GameModPortraitScope
    extends InheritedNotifier<GameModPortraitController> {
  const GameModPortraitScope({
    super.key,
    required GameModPortraitController controller,
    required super.child,
  }) : super(notifier: controller);
  static GameModPortraitController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GameModPortraitScope>()
      ?.notifier;
}
