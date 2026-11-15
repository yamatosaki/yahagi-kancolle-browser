import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait_cache.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait_network.dart';

List<int> _pngBytes([List<int> payload = const <int>[]]) => <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  ...payload,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ship_portrait_cache_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('downloads once and reuses the persisted portrait', () async {
    var requests = 0;
    final cache = ShipPortraitCache(
      directoryProvider: () async => root,
      client: MockClient((request) async {
        requests++;
        return http.Response.bytes(_pngBytes(<int>[1, 2, 3]), 200);
      }),
    );
    final uri = Uri.parse('https://example.test/1501.png?version=1');

    final first = await cache.resolve(cacheKey: '1501_banner', uri: uri);
    final second = await cache.resolve(cacheKey: '1501_banner', uri: uri);

    expect(first, isNotNull);
    expect(await first!.readAsBytes(), _pngBytes(<int>[1, 2, 3]));
    expect(second!.path, first.path);
    expect(requests, 1);
  });

  test(
    'new portrait URI replaces the previous version for the same ship',
    () async {
      var requests = 0;
      final cache = ShipPortraitCache(
        directoryProvider: () async => root,
        client: MockClient((request) async {
          requests++;
          return http.Response.bytes(
            _pngBytes(
              request.url.queryParameters['version'] == '2'
                  ? <int>[2]
                  : <int>[1],
            ),
            200,
          );
        }),
      );

      final oldFile = await cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=1'),
      );
      final newFile = await cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=2'),
      );

      expect(requests, 2);
      expect(await newFile!.readAsBytes(), _pngBytes(<int>[2]));
      expect(newFile.path, isNot(oldFile!.path));
      expect(oldFile.existsSync(), isFalse);
      final files = root.listSync(recursive: true).whereType<File>().toList();
      expect(files, hasLength(1));
    },
  );

  test(
    'concurrent requests for one portrait share a single download',
    () async {
      var requests = 0;
      final cache = ShipPortraitCache(
        directoryProvider: () async => root,
        client: MockClient((request) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response.bytes(_pngBytes(<int>[7]), 200);
        }),
      );
      final uri = Uri.parse('https://example.test/1501.png');

      final files = await Future.wait([
        cache.resolve(cacheKey: '1501_banner', uri: uri),
        cache.resolve(cacheKey: '1501_banner', uri: uri),
      ]);

      expect(requests, 1);
      expect(files[0]!.path, files[1]!.path);
    },
  );

  test('failed downloads leave no cache file', () async {
    final cache = ShipPortraitCache(
      directoryProvider: () async => root,
      client: MockClient((request) async => http.Response('missing', 404)),
    );

    final file = await cache.resolve(
      cacheKey: '1501_banner',
      uri: Uri.parse('https://example.test/missing.png'),
    );

    expect(file, isNull);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test(
    'Android official portraits separate Kanxy downloads from stock cache',
    () async {
      const channel = MethodChannel('test/ship_portrait_network');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final network = ShipPortraitNetwork(channel);
      addTearDown(network.dispose);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final routes = <String>[];
      final staleRequestStarted = Completer<void>();
      final releaseStaleRequest = Completer<void>();
      var kanxyBody = 2;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getRoute') {
          return {'token': 'stock-first', 'kanxyActive': false};
        }
        final arguments = call.arguments as Map;
        final token = arguments['token'] as String;
        routes.add(token);
        if ((arguments['uri'] as String).endsWith('?version=2')) {
          staleRequestStarted.complete();
          await releaseStaleRequest.future;
        }
        return Uint8List.fromList(_pngBytes([token == 'vpn' ? kanxyBody : 1]));
      });
      Future<void> setRoute(String token, {required bool kanxyActive}) =>
          messenger.handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              MethodCall('routeChanged', {
                'token': token,
                'kanxyActive': kanxyActive,
              }),
            ),
            (_) {},
          );
      final cache = ShipPortraitCache(
        directoryProvider: () async => root,
        client: MockClient(
          (_) async => throw StateError(
            'Dart must not fetch official Android portraits',
          ),
        ),
        network: network,
      );
      final uri = Uri.parse(
        'https://w00g.kancolle-server.com/kcs2/resources/ship/remodel/0748_1234.png',
      );
      Future<File?> resolve() =>
          cache.resolve(cacheKey: '748_remodel', uri: uri);

      final stock = (await resolve())!;
      expect((await resolve())?.path, stock.path);
      final stale = cache.resolve(
        cacheKey: '748_remodel',
        uri: uri.replace(query: 'version=2'),
      );
      await staleRequestStarted.future;
      await setRoute('vpn', kanxyActive: true);
      final modified = await Future.wait([resolve(), resolve()]);
      expect(modified[0]?.path, modified[1]?.path);
      expect(modified.first?.path, isNot(stock.path));
      expect(await modified.first?.readAsBytes(), _pngBytes([2]));
      releaseStaleRequest.complete();
      expect(await stale, isNull);
      kanxyBody = 3;
      final refreshed = (await resolve())!;
      expect(refreshed.path, isNot(modified.first?.path));
      expect(await refreshed.readAsBytes(), _pngBytes([3]));

      await setRoute('stock-second', kanxyActive: false);
      expect((await resolve())?.path, stock.path);
      expect(await stock.readAsBytes(), _pngBytes([1]));
      expect(routes, ['stock-first', 'stock-first', 'vpn', 'vpn']);
    },
  );

  test(
    'different versions for one portrait commit in invocation order',
    () async {
      final oldRequestStarted = Completer<void>();
      final releaseOldRequest = Completer<void>();
      final requests = <String>[];
      final cache = ShipPortraitCache(
        directoryProvider: () async => root,
        client: MockClient((request) async {
          final version = request.url.queryParameters['version']!;
          requests.add(version);
          if (version == '1') {
            oldRequestStarted.complete();
            await releaseOldRequest.future;
          }
          return http.Response.bytes(_pngBytes(<int>[int.parse(version)]), 200);
        }),
      );
      final oldFuture = cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=1'),
      );
      await oldRequestStarted.future;
      final newFuture = cache.resolve(
        cacheKey: '1501_banner',
        uri: Uri.parse('https://example.test/1501.png?version=2'),
      );
      releaseOldRequest.complete();

      final results = await Future.wait(<Future<File?>>[oldFuture, newFuture]);

      expect(requests, <String>['1', '2']);
      expect(results[1], isNotNull);
      expect(await results[1]!.readAsBytes(), _pngBytes(<int>[2]));
      expect(results[1]!.existsSync(), isTrue);
      expect(results[0]!.existsSync(), isFalse);
      expect(root.listSync().whereType<File>(), hasLength(1));
    },
  );

  test('HTTP 200 non-PNG response never poisons the cache', () async {
    final cache = ShipPortraitCache(
      directoryProvider: () async => root,
      client: MockClient(
        (request) async =>
            http.Response('<html>temporary proxy page</html>', 200),
      ),
    );

    final file = await cache.resolve(
      cacheKey: '1501_banner',
      uri: Uri.parse('https://example.test/1501.png'),
    );

    expect(file, isNull);
    expect(root.listSync().whereType<File>(), isEmpty);
  });

  for (final corruptBytes in <List<int>>[
    <int>[],
    <int>[1, 2, 3],
  ]) {
    test(
      'repairs an existing ${corruptBytes.isEmpty ? 'zero-byte' : 'invalid'} file',
      () async {
        var requests = 0;
        final uri = Uri.parse('https://example.test/1501.png');
        final primingCache = ShipPortraitCache(
          directoryProvider: () async => root,
          client: MockClient(
            (request) async => http.Response.bytes(_pngBytes(<int>[1]), 200),
          ),
        );
        final poisoned = await primingCache.resolve(
          cacheKey: '1501_banner',
          uri: uri,
        );
        poisoned!.writeAsBytesSync(corruptBytes, flush: true);
        final repairingCache = ShipPortraitCache(
          directoryProvider: () async => root,
          client: MockClient((request) async {
            requests++;
            return http.Response.bytes(_pngBytes(<int>[2]), 200);
          }),
        );

        final repaired = await repairingCache.resolve(
          cacheKey: '1501_banner',
          uri: uri,
        );

        expect(requests, 1);
        expect(await repaired!.readAsBytes(), _pngBytes(<int>[2]));
      },
    );
  }
}
