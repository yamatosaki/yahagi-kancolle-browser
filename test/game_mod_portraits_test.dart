import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as image;
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/fleet/game_mod_portraits.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('sync defaults on and persists off across controller reload', () async {
    final first = GameModPortraitController(port: _Port());
    await first.initialize();
    expect(first.enabled, isTrue);
    await first.setEnabled(false);
    expect(first.enabled, isFalse);
    final second = GameModPortraitController(port: _Port());
    await second.initialize();
    expect(second.enabled, isFalse);
    first.dispose();
    second.dispose();
  });
  test(
    'resolver prefers matching remodel then banner and exact full filename',
    () {
      const ship = MasterShip(
        id: 607,
        name: '伊47',
        shipTypeId: 13,
        portraitFileName: 'tciiyagxjjpu',
      );
      final snapshot = GameModPortraitSnapshot.fromMap({
        'token': 't1',
        'resources': [
          {
            'id': 'wrong',
            'path': 'kcs2/resources/ship/full/0607_4674_other.png',
          },
          {
            'id': 'damage',
            'path': 'kcs2/resources/ship/full_dmg/0607_4228_tciiyagxjjpu.png',
          },
          {
            'id': 'full',
            'path': 'kcs2/resources/ship/full/0607_4674_tciiyagxjjpu.png',
          },
        ],
      });
      expect(GameModPortraitResolver.select(ship, snapshot)?.id, 'full');
      expect(
        GameModPortraitResolver.select(ship, snapshot, isDamaged: true)?.id,
        'damage',
      );
      expect(
        GameModPortraitResolver.select(
          ship.copyWith(portraitFileName: 'unknown'),
          snapshot,
        ),
        isNull,
      );
      expect(
        GameModPortraitResolver.select(
          ship.copyWith(portraitFileName: 'unknown'),
          snapshot,
          isDamaged: true,
        ),
        isNull,
      );
    },
  );
  test('later snapshot wins and token rollback remains valid', () async {
    final port = _Port();
    final c = GameModPortraitController(port: port);
    await c.initialize();
    final a = Completer<GameModPortraitSnapshot>();
    final b = Completer<GameModPortraitSnapshot>();
    port.pending.addAll([a, b]);
    final refreshA = c.refresh();
    final refreshB = c.refresh();
    b.complete(_snapshot('new'));
    await refreshB;
    a.complete(_snapshot('old'));
    await refreshA;
    expect(c.snapshotToken, 'new');
    port.current = _snapshot('old');
    await c.refresh();
    expect(c.snapshotToken, 'old');
    c.dispose();
  });
  test(
    'resolver uses exact normal paths in remodel, banner, character, full order',
    () {
      const ship = MasterShip(
        id: 426,
        name: 'Fubuki',
        shipTypeId: 2,
        portraitFileName: 'rtkekdbkqrkg',
      );
      final resources = [
        for (final type in ['full', 'character_full', 'banner', 'remodel'])
          {
            'id': type,
            'path':
                'kcs2/resources/ship/$type/0426_${ShipPortraitUriBuilder.createCipher(426, 'ship_$type')}${type == 'full' ? '_rtkekdbkqrkg' : ''}.png',
          },
      ];
      for (final expected in ['remodel', 'banner', 'character_full', 'full']) {
        expect(
          GameModPortraitResolver.select(
            ship,
            GameModPortraitSnapshot.fromMap({
              'token': 't',
              'resources': resources,
            }),
          )?.id,
          expected,
        );
        resources.removeWhere((r) => r['id'] == expected);
      }
      expect(
        GameModPortraitResolver.select(
          ship,
          GameModPortraitSnapshot.fromMap({
            'token': 't',
            'resources': resources,
          }),
        ),
        isNull,
      );
    },
  );
  test('damaged art resolves each matching layout in priority order', () {
    final resources = [
      {'id': 'normal', 'path': 'kcs2/resources/ship/banner/0426_4278.png'},
      {
        'id': 'character',
        'path': 'kcs2/resources/ship/character_full_dmg/0426_1142.png',
      },
      {'id': 'banner', 'path': 'kcs2/resources/ship/banner_dmg/0426_5095.png'},
      {
        'id': 'remodel',
        'path': 'kcs2/resources/ship/remodel_dmg/0426_3426.png',
      },
    ];
    for (final (id, layout) in [
      ('remodel', GameModPortraitLayout.remodel),
      ('banner', GameModPortraitLayout.banner),
      ('character', GameModPortraitLayout.characterFull),
    ]) {
      final snapshot = GameModPortraitSnapshot.fromMap({
        'token': 't',
        'resources': resources,
      });
      final resource = GameModPortraitResolver.select(
        _fubuki,
        snapshot,
        isDamaged: true,
      );
      expect(resource?.id, id);
      expect(resource?.layout, layout);
      resources.removeWhere((item) => item['id'] == id);
    }
    final normalOnly = GameModPortraitSnapshot.fromMap({
      'token': 't',
      'resources': resources,
    });
    expect(
      GameModPortraitResolver.select(_fubuki, normalOnly, isDamaged: true),
      isNull,
    );
  });
  test('normal and damaged Mod artwork are cached separately', () async {
    final port = _ReadPort()
      ..current = GameModPortraitSnapshot.fromMap({
        'token': 'both',
        'resources': [
          {'id': 'normal', 'path': 'kcs2/resources/ship/banner/0426_4278.png'},
          {
            'id': 'damaged',
            'path': 'kcs2/resources/ship/banner_dmg/0426_5095.png',
          },
        ],
      });
    final controller = GameModPortraitController(port: port);
    addTearDown(controller.dispose);
    await controller.initialize();

    final normal = await controller.resolve(_fubuki);
    final damaged = await controller.resolve(_fubuki, isDamaged: true);
    expect(normal?.cacheKey, contains('/normal/'));
    expect(damaged?.cacheKey, contains('/damaged/'));
    expect(await controller.resolve(_fubuki), same(normal));
    expect(await controller.resolve(_fubuki, isDamaged: true), same(damaged));
    expect(port.reads, 2);
  });
  test(
    'old image read cannot override a newly applied snapshot or off state',
    () async {
      final port = _ReadPort()..current = _artSnapshot('first');
      final c = GameModPortraitController(port: port);
      await c.initialize();
      final read = Completer<Uint8List?>();
      port.readGate = read;
      final old = c.resolve(_fubuki);
      port.current = _artSnapshot('second');
      await c.refresh();
      read.complete(_png);
      expect(await old, isNull);
      port.readGate = null;
      final current = await c.resolve(_fubuki);
      expect(current, isNotNull);
      expect(current!.cacheKey, startsWith('second/'));
      expect(current.cacheKey, endsWith('/fixed-v2'));
      await c.setEnabled(false);
      expect(await c.resolve(_fubuki), isNull);
      c.dispose();
    },
  );
  test(
    'three consumers share prepared PNG per token and same resource is reread after rollback',
    () async {
      final port = _ReadPort()..current = _artSnapshot('one');
      final c = GameModPortraitController(port: port);
      await c.initialize();
      final images = await Future.wait(
        List.generate(3, (_) => c.resolve(_fubuki)),
      );
      expect(images.every((p) => p != null), isTrue);
      expect(port.reads, 1);
      port.current = _artSnapshot('two');
      await c.refresh();
      await c.resolve(_fubuki);
      expect(port.reads, 2);
      port.current = _artSnapshot('one');
      await c.refresh();
      await c.resolve(_fubuki);
      expect(port.reads, 3);
      c.dispose();
    },
  );
  test(
    'snapshot failure removes stale mod and allows original token recovery',
    () async {
      final port = _ReadPort()..current = _artSnapshot('one');
      final c = GameModPortraitController(port: port);
      await c.initialize();
      expect(await c.resolve(_fubuki), isNotNull);
      port.failSnapshot = true;
      await c.refresh();
      expect(await c.resolve(_fubuki), isNull);
      expect(c.errorCode, isNull);
      port.failSnapshot = false;
      await c.refresh();
      expect(await c.resolve(_fubuki), isNotNull);
      c.dispose();
    },
  );
  test(
    'native apply event refreshes and controller disposal removes subscription',
    () async {
      final port = _Port();
      final c = GameModPortraitController(port: port);
      await c.initialize();
      port.current = _snapshot('changed');
      port.changed!();
      await Future<void>.delayed(Duration.zero);
      expect(c.snapshotToken, 'changed');
      c.dispose();
      expect(port.changed, isNull);
    },
  );
  test(
    'failed preference save rolls back enabled and exposes retryable error',
    () async {
      final store = _Store()..fail = true;
      final c = GameModPortraitController(port: _Port(), store: store);
      await c.initialize();
      await c.setEnabled(false);
      expect(c.enabled, isTrue);
      expect(c.saving, isFalse);
      expect(c.errorCode, 'portrait_sync_save_failed');
      store.fail = false;
      await c.setEnabled(false);
      expect(c.enabled, isFalse);
      expect(c.errorCode, isNull);
      c.dispose();
    },
  );
  test(
    'full images use the same fixed crop despite different alpha silhouettes',
    () async {
      final a = image.Image(width: 600, height: 1000, numChannels: 4);
      image.fillRect(
        a,
        x1: 0,
        y1: 0,
        x2: 299,
        y2: 299,
        color: image.ColorRgba8(10, 90, 170, 255),
      );
      image.fillRect(
        a,
        x1: 0,
        y1: 0,
        x2: 99,
        y2: 299,
        color: image.ColorRgba8(200, 30, 40, 255),
      );
      final b = a.clone();
      image.fillRect(
        a,
        x1: 400,
        y1: 80,
        x2: 500,
        y2: 250,
        color: image.ColorRgba8(220, 200, 150, 255),
      );
      image.fillRect(
        a,
        x1: 500,
        y1: 700,
        x2: 599,
        y2: 999,
        color: image.ColorRgba8(20, 20, 20, 255),
      );
      image.fillRect(
        b,
        x1: 0,
        y1: 700,
        x2: 99,
        y2: 999,
        color: image.ColorRgba8(20, 20, 20, 255),
      );
      final expected = image.encodePng(
        image.copyResize(
          image.copyCrop(a, x: 0, y: 0, width: 300, height: 300),
          width: 256,
          height: 256,
        ),
      );
      final preparedA = await _prepareFull(a, 'full');
      final preparedB = await _prepareFull(b, 'full');
      expect(preparedA.bytes, orderedEquals(expected));
      expect(preparedB.bytes, orderedEquals(expected));
    },
  );
  test(
    'fixed full crop is top-left, rounds thirty percent of height and clamps to width',
    () async {
      for (final dimensions in [
        (50, 1000, 50),
        (200, 333, 100),
        (100, 100, 30),
      ]) {
        final (width, height, side) = dimensions;
        final source = image.Image(
          width: width,
          height: height,
          numChannels: 4,
        );
        image.fillRect(
          source,
          x1: 0,
          y1: 0,
          x2: side - 1,
          y2: side - 1,
          color: image.ColorRgba8(10, 180, 30, 255),
        );
        image.fillRect(
          source,
          x1: 0,
          y1: 0,
          x2: side ~/ 3,
          y2: side - 1,
          color: image.ColorRgba8(200, 10, 90, 255),
        );
        image.fillRect(
          source,
          x1: width - 1,
          y1: height - 1,
          x2: width - 1,
          y2: height - 1,
          color: image.ColorRgba8(0, 0, 255, 255),
        );
        final expected = image.encodePng(
          image.copyResize(
            image.copyCrop(source, x: 0, y: 0, width: side, height: side),
            width: 256,
            height: 256,
          ),
        );
        expect(
          (await _prepareFull(source, 'full')).bytes,
          orderedEquals(expected),
        );
      }
    },
  );
  test(
    'standard character canvas keeps the centered head rather than left-side equipment',
    () async {
      // The real 0147/0467 character_full files are 431 x 645. Their heads
      // are centered, unlike package full images such as I-47.
      final source = image.Image(width: 431, height: 645, numChannels: 4);
      image.fill(source, color: image.ColorRgba8(10, 20, 200, 255));
      image.fillRect(
        source,
        x1: 119,
        y1: 0,
        x2: 312,
        y2: 193,
        color: image.ColorRgba8(200, 30, 40, 255),
      );
      final portrait = await _prepareFull(source, 'character_full');
      final decoded = image.decodePng(portrait.bytes)!;
      for (final point in [(0, 0), (128, 128), (255, 255)]) {
        final pixel = decoded.getPixel(point.$1, point.$2);
        expect(pixel.r, 200, reason: 'centered head must fill the portrait');
        expect(pixel.b, 40);
      }
    },
  );
}

GameModPortraitSnapshot _snapshot(String token) =>
    GameModPortraitSnapshot.fromMap({'token': token, 'resources': <Object>[]});

class _Port implements GameModPortraitPort {
  GameModPortraitSnapshot current = _snapshot('initial');
  final pending = <Completer<GameModPortraitSnapshot>>[];
  void Function()? changed;
  bool failSnapshot = false;
  @override
  Future<GameModPortraitSnapshot> snapshot() => failSnapshot
      ? Future.error(StateError('native unavailable'))
      : pending.isEmpty
      ? Future.value(current)
      : pending.removeAt(0).future;
  @override
  Future<Uint8List?> read({
    required String token,
    required String resourceId,
  }) async => null;
  @override
  void setChangedHandler(void Function()? handler) {
    changed = handler;
  }
}

const _fubuki = MasterShip(id: 426, name: 'Fubuki', shipTypeId: 2);
Uint8List get _png => File('assets/images/material/01.png').readAsBytesSync();
GameModPortraitSnapshot _artSnapshot(String token) =>
    GameModPortraitSnapshot.fromMap({
      'token': token,
      'resources': [
        {'id': 'normal', 'path': 'kcs2/resources/ship/banner/0426_4278.png'},
      ],
    });

class _ReadPort extends _Port {
  int reads = 0;
  Uint8List? bytes;
  Completer<Uint8List?>? readGate;
  @override
  Future<Uint8List?> read({required String token, required String resourceId}) {
    reads++;
    return readGate?.future ?? Future.value(bytes ?? _png);
  }
}

class _Store implements GameModPortraitStore {
  bool fail = false;
  @override
  Future<bool?> readEnabled() async => null;
  @override
  Future<void> writeEnabled(bool value) async {
    if (fail) throw StateError('disk');
  }
}

Future<GameModPortraitImage> _prepareFull(
  image.Image source,
  String type,
) async {
  const ship = MasterShip(
    id: 607,
    name: 'I-47',
    shipTypeId: 13,
    portraitFileName: 'tciiyagxjjpu',
  );
  final suffix = type == 'full' ? '_tciiyagxjjpu' : '';
  final cipher = ShipPortraitUriBuilder.createCipher(ship.id, 'ship_$type');
  final port = _ReadPort()
    ..current = GameModPortraitSnapshot.fromMap({
      'token': 'fixed',
      'resources': [
        {
          'id': 'fixed',
          'path': 'kcs2/resources/ship/$type/0607_$cipher$suffix.png',
        },
      ],
    })
    ..bytes = Uint8List.fromList(image.encodePng(source));
  final controller = GameModPortraitController(port: port);
  await controller.initialize();
  try {
    return (await controller.resolve(ship))!;
  } finally {
    controller.dispose();
  }
}
