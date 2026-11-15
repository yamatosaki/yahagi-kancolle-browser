import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait_cache.dart';
import 'package:yahagi_kancolle_browser/src/fleet/slot_item_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

class _AndroidAssetCache extends ShipPortraitCache {
  _AndroidAssetCache()
    : super(
        directoryProvider: () async => Directory.systemTemp,
        client: http.Client(),
      );

  final route = ValueNotifier(false);
  final resolved = <(String, Uri)>[];

  @override
  Listenable? routeChangesFor(Uri uri) => route;

  @override
  Future<File?> resolve({required String cacheKey, required Uri uri}) {
    resolved.add((cacheKey, uri));
    return SynchronousFuture(File('assets/app_icon.png'));
  }
}

void main() {
  test('builds the official item_up resource URI with version', () {
    final uri = SlotItemPortraitUriBuilder.build(
      item: const MasterSlotItem(id: 168, name: '九六式陸攻', resourceVersion: '2'),
      serverOrigin: 'https://example.test/game/',
    );

    expect(uri, isNotNull);
    expect(
      uri.toString(),
      startsWith('https://example.test/kcs2/resources/slot/item_up/0168_'),
    );
    expect(uri?.queryParameters['version'], '2');
  });

  test('rejects an invalid resource origin', () {
    expect(
      SlotItemPortraitUriBuilder.build(
        item: const MasterSlotItem(id: 168, name: '九六式陸攻'),
        serverOrigin: 'not a server',
      ),
      isNull,
    );
  });

  testWidgets(
    'official Android equipment art uses the persistent native route',
    (tester) async {
      final cache = _AndroidAssetCache();
      addTearDown(cache.client.close);
      addTearDown(cache.route.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SlotItemPortrait(
            item: const MasterSlotItem(
              id: 168,
              name: '九六式陸攻',
              resourceVersion: '2',
            ),
            serverOrigin: 'https://w00g.kancolle-server.com',
            cache: cache,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(cache.resolved.single.$1, 'slot_168_item_up');
      expect(
        cache.resolved.single.$2.path,
        startsWith('/kcs2/resources/slot/item_up/0168_'),
      );
      expect(tester.widget<Image>(find.byType(Image)).image, isA<FileImage>());

      cache.route.value = true;
      await tester.pumpAndSettle();
      expect(cache.resolved, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
