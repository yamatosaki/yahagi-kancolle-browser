import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait_cache.dart';

class _FakeShipPortraitCache extends ShipPortraitCache {
  _FakeShipPortraitCache(this.file)
    : super(
        directoryProvider: () async => Directory.systemTemp,
        client: http.Client(),
      );

  final File file;
  int requests = 0;

  @override
  Future<File?> resolve({required String cacheKey, required Uri uri}) {
    requests++;
    return SynchronousFuture<File?>(file);
  }
}

class _ControlledPortraitCache extends ShipPortraitCache {
  _ControlledPortraitCache({
    required this.files,
    this.evictionCompleters = const <String, Completer<void>>{},
  }) : super(
         directoryProvider: () async => Directory.systemTemp,
         client: http.Client(),
       );

  final List<File?> files;
  final Map<String, Completer<void>> evictionCompleters;
  final List<Uri> resolvedUris = <Uri>[];
  final List<String> resolvedKeys = <String>[];
  final List<Uri> evictedUris = <Uri>[];

  @override
  Future<File?> resolve({required String cacheKey, required Uri uri}) {
    final index = resolvedUris.length.clamp(0, files.length - 1);
    resolvedUris.add(uri);
    resolvedKeys.add(cacheKey);
    return SynchronousFuture<File?>(files[index]);
  }

  @override
  Future<void> evict({required String cacheKey, required Uri uri}) {
    evictedUris.add(uri);
    return evictionCompleters[uri.toString()]?.future ??
        SynchronousFuture<void>(null);
  }
}

ShipPortraitFileImageProviderBuilder _memoryImageBuilder(
  Map<String, Uint8List> bytesByPath,
) =>
    (file, decodeHeight) => MemoryImage(bytesByPath[file.path]!);

void main() {
  group('ShipPortraitUriBuilder', () {
    test('matches the game remodel-art cipher used by Yahagi avatars', () {
      const ship = MasterShip(
        id: 163,
        name: 'まるゆ',
        shipTypeId: 22,
        portraitVersion: '7',
      );

      final uri = ShipPortraitUriBuilder.build(
        ship: ship,
        serverOrigin: 'https://203.104.209.71',
      );

      expect(
        uri.toString(),
        'https://203.104.209.71/kcs2/resources/ship/remodel/0163_6320.png?version=7',
      );
    });

    test('enemy portrait uses POI banner resources', () {
      const enemy = MasterShip(
        id: 1501,
        name: '敌舰',
        shipTypeId: 13,
        portraitVersion: '7',
      );

      final uri = ShipPortraitUriBuilder.build(
        ship: enemy,
        serverOrigin: 'https://w01y.kancolle-server.com',
        resourceType: ShipPortraitResourceType.banner,
      );

      expect(
        uri.toString(),
        'https://w01y.kancolle-server.com/kcs2/resources/ship/banner/1501_2115.png?version=7',
      );
    });

    test('damaged portrait uses the remodel_dmg cipher and ship version', () {
      const ship = MasterShip(
        id: 163,
        name: 'まるゆ',
        shipTypeId: 22,
        portraitVersion: '7',
      );

      final uri = ShipPortraitUriBuilder.build(
        ship: ship,
        serverOrigin: 'https://example.test',
        isDamaged: true,
      );

      expect(
        uri.toString(),
        'https://example.test/kcs2/resources/ship/remodel_dmg/0163_2809.png?version=7',
      );
    });

    test('rejects non-http origins and missing versions', () {
      const ship = MasterShip(id: 101, name: '测试舰', shipTypeId: 2);

      expect(
        ShipPortraitUriBuilder.build(
          ship: ship,
          serverOrigin: 'file:///data/game',
        ),
        isNull,
      );
      expect(
        ShipPortraitUriBuilder.build(
          ship: ship,
          serverOrigin: 'https://example.com',
        ),
        isNull,
      );
    });
  });

  testWidgets('ShipPortrait renders the persistent cached file', (
    tester,
  ) async {
    final cache = _FakeShipPortraitCache(File('assets/app_icon.png'));
    const enemy = MasterShip(
      id: 1501,
      name: '駆逐イ級',
      shipTypeId: 2,
      portraitVersion: '1',
    );
    expect(
      ShipPortraitUriBuilder.build(
        ship: enemy,
        serverOrigin: 'https://example.test',
        resourceType: ShipPortraitResourceType.banner,
      ),
      isNotNull,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShipPortrait(
          ship: enemy,
          serverOrigin: 'https://example.test',
          resourceType: ShipPortraitResourceType.banner,
          cache: cache,
        ),
      ),
    );
    expect(find.byType(FutureBuilder<File?>), findsOneWidget);
    await tester.pumpAndSettle();

    expect(cache.requests, 1);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
  });

  testWidgets('ShipPortrait limits cached thumbnail decode height', (
    tester,
  ) async {
    final cache = _FakeShipPortraitCache(File('assets/app_icon.png'));
    await tester.pumpWidget(
      MaterialApp(
        home: ShipPortrait(
          ship: const MasterShip(
            id: 101,
            name: '测试舰',
            shipTypeId: 2,
            portraitVersion: '1',
          ),
          serverOrigin: 'https://example.test',
          decodeHeight: 106,
          cache: cache,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).height, 106);
  });

  testWidgets('missing damaged art uses the separately cached normal art', (
    tester,
  ) async {
    final normal = File('assets/app_icon.png');
    final cache = _ControlledPortraitCache(files: [null, normal]);

    await tester.pumpWidget(
      MaterialApp(
        home: ShipPortrait(
          ship: const MasterShip(
            id: 163,
            name: 'まるゆ',
            shipTypeId: 22,
            portraitVersion: '7',
          ),
          serverOrigin: 'https://example.test',
          isDamaged: true,
          cache: cache,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cache.resolvedKeys, ['163_remodel_dmg', '163_remodel']);
    expect(cache.resolvedUris.map((uri) => uri.pathSegments[3]), [
      'remodel_dmg',
      'remodel',
    ]);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, FileImage(normal));
    expect(tester.takeException(), isNull);
  });

  testWidgets('decode failure is evicted and retried exactly once', (
    tester,
  ) async {
    final invalid = File('invalid-a.png');
    final valid = File('valid.png');
    final cache = _ControlledPortraitCache(files: <File>[invalid, valid]);
    final bytes = <String, Uint8List>{
      invalid.path: Uint8List.fromList(<int>[1, 2, 3]),
      valid.path: File('assets/images/material/01.png').readAsBytesSync(),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: ShipPortrait(
          ship: const MasterShip(
            id: 1501,
            name: '駆逐イ級',
            shipTypeId: 2,
            portraitVersion: '1',
          ),
          serverOrigin: 'https://example.test',
          cache: cache,
          fileImageProviderBuilder: _memoryImageBuilder(bytes),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cache.resolvedUris, hasLength(2));
    expect(cache.evictedUris, hasLength(1));
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('two decode failures stop after one retry', (tester) async {
    final invalidA = File('invalid-a.png');
    final invalidB = File('invalid-b.png');
    final cache = _ControlledPortraitCache(files: <File>[invalidA, invalidB]);
    final bytes = <String, Uint8List>{
      invalidA.path: Uint8List.fromList(<int>[1]),
      invalidB.path: Uint8List.fromList(<int>[2]),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: ShipPortrait(
          ship: const MasterShip(
            id: 1501,
            name: '駆逐イ級',
            shipTypeId: 2,
            portraitVersion: '1',
          ),
          serverOrigin: 'https://example.test',
          cache: cache,
          fileImageProviderBuilder: _memoryImageBuilder(bytes),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(cache.resolvedUris, hasLength(2));
    expect(cache.evictedUris, hasLength(2));
    expect(find.byIcon(Icons.directions_boat_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale eviction cannot consume the next URI retry', (
    tester,
  ) async {
    const origin = 'https://example.test';
    const shipA = MasterShip(
      id: 1501,
      name: '駆逐イ級',
      shipTypeId: 2,
      portraitVersion: '1',
    );
    const shipB = MasterShip(
      id: 1502,
      name: '駆逐ロ級',
      shipTypeId: 2,
      portraitVersion: '1',
    );
    final uriA = ShipPortraitUriBuilder.build(
      ship: shipA,
      serverOrigin: origin,
    )!;
    final uriB = ShipPortraitUriBuilder.build(
      ship: shipB,
      serverOrigin: origin,
    )!;
    final evictionA = Completer<void>();
    final evictionB = Completer<void>();
    final invalidA = File('stale-invalid-a.png');
    final invalidB = File('current-invalid-b.png');
    final validB = File('current-valid-b.png');
    final cache = _ControlledPortraitCache(
      files: <File>[invalidA, invalidB, validB],
      evictionCompleters: <String, Completer<void>>{
        uriA.toString(): evictionA,
        uriB.toString(): evictionB,
      },
    );
    final bytes = <String, Uint8List>{
      invalidA.path: Uint8List.fromList(<int>[1]),
      invalidB.path: Uint8List.fromList(<int>[2]),
      validB.path: File('assets/images/material/01.png').readAsBytesSync(),
    };
    Widget app(MasterShip ship) => MaterialApp(
      home: ShipPortrait(
        ship: ship,
        serverOrigin: origin,
        cache: cache,
        fileImageProviderBuilder: _memoryImageBuilder(bytes),
      ),
    );

    await tester.pumpWidget(app(shipA));
    await tester.pumpAndSettle();
    expect(cache.evictedUris, <Uri>[uriA]);

    await tester.pumpWidget(app(shipB));
    await tester.pumpAndSettle();
    expect(cache.evictedUris, <Uri>[uriA, uriB]);

    evictionA.complete();
    await tester.pump();
    expect(cache.resolvedUris.where((uri) => uri == uriB), hasLength(1));

    evictionB.complete();
    await tester.pumpAndSettle();
    expect(cache.resolvedUris.where((uri) => uri == uriB), hasLength(2));
    expect(cache.resolvedUris, hasLength(3));
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(tester.takeException(), isNull);
  });
}
