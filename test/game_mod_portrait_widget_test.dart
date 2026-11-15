import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/fleet/game_mod_portraits.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait_cache.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

const _ship = MasterShip(
  id: 426,
  name: '吹雪改二',
  shipTypeId: 2,
  portraitVersion: '1',
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'mod portrait, platform codec failure and disabling preserve original cache',
    (tester) async {
      final bytes = File('assets/images/material/01.png').readAsBytesSync();
      final port = _Port(bytes);
      final c = GameModPortraitController(port: port);
      await c.initialize();
      final cache = _Official();
      expect(
        GameModPortraitResolver.select(_ship, await port.snapshot()),
        isNotNull,
      );
      await tester.runAsync(() async {
        expect(await c.resolve(_ship), isNotNull);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: GameModPortraitScope(
            controller: c,
            child: ShipPortrait(
              ship: _ship,
              serverOrigin: 'https://example.test',
              cache: cache,
              fileImageProviderBuilder: (_, _) => MemoryImage(bytes),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-mod-portrait')), findsOneWidget);
      final rendered = tester.widget<Image>(find.byType(Image));
      rendered.errorBuilder!(
        tester.element(find.byType(Image)),
        StateError('platform codec'),
        StackTrace.empty,
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-mod-portrait')), findsNothing);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      await c.setEnabled(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-mod-portrait')), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(cache.evictions, 0);
      expect(cache.requests, 2);
      c.dispose();
    },
  );
  testWidgets(
    'invalid mod PNG falls back to official image without changing its cache',
    (tester) async {
      final bytes = File('assets/images/material/01.png').readAsBytesSync();
      final port = _Port(Uint8List.fromList([1, 2, 3]));
      final c = GameModPortraitController(port: port);
      await c.initialize();
      final cache = _Official();
      await tester.runAsync(() async {
        await c.resolve(_ship);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: GameModPortraitScope(
            controller: c,
            child: ShipPortrait(
              ship: _ship,
              serverOrigin: 'https://example.test',
              cache: cache,
              fileImageProviderBuilder: (_, _) => MemoryImage(bytes),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('game-mod-portrait')), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(cache.evictions, 0);
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
}

class _Port implements GameModPortraitPort {
  _Port(this.bytes);
  final Uint8List bytes;
  @override
  Future<GameModPortraitSnapshot> snapshot() async =>
      GameModPortraitSnapshot.fromMap({
        'token': 'one',
        'resources': [
          {'id': 'fubuki', 'path': 'kcs2/resources/ship/banner/0426_4278.png'},
        ],
      });
  @override
  Future<Uint8List?> read({
    required String token,
    required String resourceId,
  }) async => bytes;
  @override
  void setChangedHandler(VoidCallback? handler) {}
}

class _Official extends ShipPortraitCache {
  _Official()
    : super(
        directoryProvider: () async => Directory.systemTemp,
        client: http.Client(),
      );
  int requests = 0, evictions = 0;
  @override
  Future<File?> resolve({required String cacheKey, required Uri uri}) async {
    requests++;
    return File('official.png');
  }

  @override
  Future<void> evict({
    required String cacheKey,
    required Uri uri,
    File? resolvedFile,
  }) async {
    evictions++;
  }
}
