import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'ship_portrait_network.dart';

typedef ShipPortraitCacheDirectoryProvider = Future<Directory> Function();

class ShipPortraitCache {
  static int _temporaryFileSequence = 0;

  ShipPortraitCache({
    required this.directoryProvider,
    required this.client,
    this.network,
    this.requestTimeout = const Duration(seconds: 15),
    this.maximumResponseBytes = 8 * 1024 * 1024,
  });

  static final ShipPortraitCache shared = ShipPortraitCache(
    directoryProvider: () async {
      final support = await getApplicationSupportDirectory();
      return Directory(path.join(support.path, 'ship_portraits'));
    },
    client: http.Client(),
    network: Platform.isAndroid ? ShipPortraitNetwork() : null,
  );

  final ShipPortraitCacheDirectoryProvider directoryProvider;
  final http.Client client;
  final ShipPortraitNetwork? network;
  final Duration requestTimeout;
  final int maximumResponseBytes;
  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};
  final Map<String, Future<void>> _serialTails = <String, Future<void>>{};

  Listenable? routeChangesFor(Uri uri) =>
      ShipPortraitNetwork.appliesTo(uri) ? network : null;

  Future<File?> resolve({required String cacheKey, required Uri uri}) async {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    ShipPortraitRoute? route;
    final portraitNetwork = network;
    if (portraitNetwork != null && ShipPortraitNetwork.appliesTo(uri)) {
      try {
        route = await portraitNetwork.currentRoute();
      } catch (_) {
        return null;
      }
      if (route == null || !portraitNetwork.isCurrent(route)) return null;
    }
    final requestKey = '$cacheKey|$uri|${route?.token ?? ''}';
    final existing = _inFlight[requestKey];
    if (existing != null) return existing;

    final serialKey = route?.kanxyActive == true ? 'kanxy|$cacheKey' : cacheKey;
    final previous = _serialTails[serialKey] ?? Future<void>.value();
    final operation = previous.then(
      (_) => _resolve(cacheKey: cacheKey, uri: uri, route: route),
    );
    _inFlight[requestKey] = operation;
    final tail = operation.then<void>((_) {});
    _serialTails[serialKey] = tail;
    operation.whenComplete(() {
      if (identical(_inFlight[requestKey], operation)) {
        _inFlight.remove(requestKey);
      }
    });
    tail.whenComplete(() {
      if (identical(_serialTails[serialKey], tail)) {
        _serialTails.remove(serialKey);
      }
    });
    return operation;
  }

  Future<void> evict({
    required String cacheKey,
    required Uri uri,
    File? resolvedFile,
  }) async {
    try {
      final file =
          resolvedFile ??
          _cacheFile(
            directory: await directoryProvider(),
            cacheKey: cacheKey,
            uri: uri,
          );
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Decode failure eviction is best-effort; the placeholder remains usable.
    }
  }

  Future<File?> _resolve({
    required String cacheKey,
    required Uri uri,
    required ShipPortraitRoute? route,
  }) async {
    File? temporary;
    bool currentRoute() => route == null || network!.isCurrent(route);
    try {
      if (!currentRoute()) return null;
      final cacheDirectory = await directoryProvider();
      final kanxyActive = route?.kanxyActive == true;
      final directory = kanxyActive
          ? Directory(path.join(cacheDirectory.path, 'kanxy'))
          : cacheDirectory;
      await directory.create(recursive: true);
      final safeKey = _safeCacheKey(cacheKey);
      final ordinaryFile = _cacheFile(
        directory: directory,
        cacheKey: cacheKey,
        uri: uri,
      );
      if (!kanxyActive) {
        if (await _isValidPngFile(ordinaryFile)) {
          return currentRoute() ? ordinaryFile : null;
        }
        if (await ordinaryFile.exists()) await ordinaryFile.delete();
      }
      if (!currentRoute()) return null;
      final bytes = await _download(uri, route).timeout(requestTimeout);
      if (!currentRoute() ||
          bytes == null ||
          bytes.length > maximumResponseBytes ||
          !_hasPngSignature(bytes)) {
        return null;
      }

      // Kanxy can change a response without changing its URL or version.
      final file = kanxyActive
          ? _cacheFile(
              directory: directory,
              cacheKey: cacheKey,
              uri: uri,
              contentHash: sha256.convert(bytes).toString(),
            )
          : ordinaryFile;

      temporary = File('${file.path}.${pid}_${_temporaryFileSequence++}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      if (!currentRoute()) return null;
      if (await file.exists()) {
        if (await _isValidPngFile(file)) {
          await temporary.delete();
        } else {
          await file.delete();
        }
      }
      if (await temporary.exists()) {
        try {
          await temporary.rename(file.path);
        } on FileSystemException {
          if (await _isValidPngFile(file)) {
            await temporary.delete();
          } else {
            if (await file.exists()) await file.delete();
            await temporary.rename(file.path);
          }
        }
      }
      await _removeOlderVersions(
        directory: directory,
        safeKey: safeKey,
        keepPath: file.path,
      );
      return currentRoute() ? file : null;
    } catch (_) {
      return null;
    } finally {
      try {
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      } catch (_) {
        // A failed download must never make temporary files user-visible.
      }
    }
  }

  Future<Uint8List?> _download(Uri uri, ShipPortraitRoute? route) async {
    if (route != null) return network!.fetch(uri, route);
    final response = await client.get(uri);
    return response.statusCode == HttpStatus.ok ? response.bodyBytes : null;
  }

  File _cacheFile({
    required Directory directory,
    required String cacheKey,
    required Uri uri,
    String? contentHash,
  }) {
    final digest = sha256.convert(uri.toString().codeUnits).toString();
    final variant = contentHash == null ? digest : '$digest-$contentHash';
    return File(
      path.join(directory.path, '${_safeCacheKey(cacheKey)}-$variant.png'),
    );
  }

  String _safeCacheKey(String cacheKey) =>
      cacheKey.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<bool> _isValidPngFile(File file) async {
    if (!await file.exists() || await file.length() < _pngSignature.length) {
      return false;
    }
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      return _hasPngSignature(await handle.read(_pngSignature.length));
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }

  bool _hasPngSignature(List<int> bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var index = 0; index < _pngSignature.length; index++) {
      if (bytes[index] != _pngSignature[index]) return false;
    }
    return true;
  }

  static const List<int> _pngSignature = <int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ];

  Future<void> _removeOlderVersions({
    required Directory directory,
    required String safeKey,
    required String keepPath,
  }) async {
    await for (final entity in directory.list()) {
      if (entity is! File ||
          entity.path == keepPath ||
          !path.basename(entity.path).startsWith('$safeKey-') ||
          !entity.path.endsWith('.png')) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // A stale version may be in use by another image decode. It can be
        // cleaned the next time this portrait receives a newer version.
      }
    }
  }
}
