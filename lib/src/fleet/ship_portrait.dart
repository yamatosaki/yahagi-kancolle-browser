import '../theme/app_palette.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import 'ship_damage_level.dart';
import 'ship_portrait_cache.dart';
import 'game_mod_portraits.dart';

const shipCardPortraitHeight = 54.0;
const shipCardCapsuleMinHeight = 76.0;

double shipCardPortraitWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width * 0.16).clamp(100.0, 180.0);
}

bool shipUsesDamagedPortrait(OwnedShip ship) {
  final level = shipDamageLevel(currentHp: ship.currentHp, maxHp: ship.maxHp);
  return level == ShipDamageLevel.moderate || level == ShipDamageLevel.heavy;
}

enum ShipPortraitResourceType {
  remodel,
  banner;

  String _nameFor(bool isDamaged) => isDamaged ? '${name}_dmg' : name;
}

typedef ShipPortraitFileImageProviderBuilder =
    ImageProvider<Object> Function(File file, int? decodeHeight);

abstract final class ShipPortraitUriBuilder {
  static const List<int> _resource = <int>[
    6657,
    5699,
    3371,
    8909,
    7719,
    6229,
    5449,
    8561,
    2987,
    5501,
    3127,
    9319,
    4365,
    9811,
    9927,
    2423,
    3439,
    1865,
    5925,
    4409,
    5509,
    1517,
    9695,
    9255,
    5325,
    3691,
    5519,
    6949,
    5607,
    9539,
    4133,
    7795,
    5465,
    2659,
    6381,
    6875,
    4019,
    9195,
    5645,
    2887,
    1213,
    1815,
    8671,
    3015,
    3147,
    2991,
    7977,
    7045,
    1619,
    7909,
    4451,
    6573,
    4545,
    8251,
    5983,
    2849,
    7249,
    7449,
    9477,
    5963,
    2711,
    9019,
    7375,
    2201,
    5631,
    4893,
    7653,
    3719,
    8819,
    5839,
    1853,
    9843,
    9119,
    7023,
    5681,
    2345,
    9873,
    6349,
    9315,
    3795,
    9737,
    4633,
    4173,
    7549,
    7171,
    6147,
    4723,
    5039,
    2723,
    7815,
    6201,
    5999,
    5339,
    4431,
    2911,
    4435,
    3611,
    4423,
    9517,
    3243,
  ];

  static Uri? build({
    required MasterShip ship,
    required String serverOrigin,
    ShipPortraitResourceType resourceType = ShipPortraitResourceType.remodel,
    bool isDamaged = false,
  }) {
    if (ship.portraitVersion == null) {
      return null;
    }
    final origin = Uri.tryParse(serverOrigin);
    if (origin == null ||
        (origin.scheme != 'http' && origin.scheme != 'https') ||
        origin.host.isEmpty) {
      return null;
    }
    final server = Uri(
      scheme: origin.scheme,
      host: origin.host,
      port: origin.hasPort ? origin.port : null,
    );
    final paddedId = ship.id.toString().padLeft(4, '0');
    final resourceName = resourceType._nameFor(isDamaged);
    final cipher = createCipher(ship.id, 'ship_$resourceName');
    final version = int.tryParse(ship.portraitVersion!);
    return server.replace(
      path: '/kcs2/resources/ship/$resourceName/${paddedId}_$cipher.png',
      queryParameters: version != null && version > 1
          ? <String, String>{'version': ship.portraitVersion!}
          : null,
    );
  }

  static String createCipher(int id, String seed) {
    var key = 0;
    for (final codeUnit in seed.codeUnits) {
      key += codeUnit;
    }
    final index = (key + id * seed.length) % _resource.length;
    return (((17 * (id + 7) * _resource[index]) % 8973) + 1000).toString();
  }
}

class ShipPortrait extends StatelessWidget {
  const ShipPortrait({
    super.key,
    required this.ship,
    required this.serverOrigin,
    this.width = 96,
    this.height = 56,
    this.decodeHeight,
    this.resourceType = ShipPortraitResourceType.remodel,
    this.isDamaged = false,
    this.cache,
    this.fileImageProviderBuilder,
  });

  final MasterShip? ship;
  final String serverOrigin;
  final double width;
  final double height;
  final int? decodeHeight;
  final ShipPortraitResourceType resourceType;
  final bool isDamaged;
  final ShipPortraitCache? cache;
  final ShipPortraitFileImageProviderBuilder? fileImageProviderBuilder;

  @override
  Widget build(BuildContext context) {
    final official = _buildOfficial(context);
    final portraits = GameModPortraitScope.maybeOf(context);
    if (portraits == null || ship == null || !portraits.enabled) {
      return official;
    }
    return FutureBuilder<GameModPortraitImage?>(
      future: portraits.resolve(ship!, isDamaged: isDamaged),
      builder: (context, snapshot) {
        final mod = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        if (mod == null) return official;
        return _ModPortraitImage(
          portrait: mod,
          width: width,
          height: height,
          official: official,
        );
      },
    );
  }

  Widget _buildOfficial(BuildContext context) {
    final uri = ship == null
        ? null
        : ShipPortraitUriBuilder.build(
            ship: ship!,
            serverOrigin: serverOrigin,
            resourceType: resourceType,
          );
    final placeholder = ColoredBox(
      color: appColor(context, Color(0xff1b3240)),
      child: SizedBox(
        width: width,
        height: height,
        child: Icon(
          Icons.directions_boat_outlined,
          color: appColor(context, Color(0xff8197a5)),
        ),
      ),
    );
    if (uri == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }
    final enemyBanner = resourceType == ShipPortraitResourceType.banner;
    final imageHeight = (height / 176) * 182;
    final horizontalOffset = height * (enemyBanner ? 1.6 : 0.555);
    final verticalOffset = (height / 176) * 3;
    Widget cachedImage(Uri imageUri, bool damaged, Widget fallback) =>
        _PersistentPortraitImage(
          uri: imageUri,
          cacheKey: '${ship!.id}_${resourceType._nameFor(damaged)}',
          cache: cache ?? ShipPortraitCache.shared,
          imageProviderBuilder: fileImageProviderBuilder,
          height: imageHeight,
          decodeHeight: decodeHeight,
          fit: BoxFit.fitHeight,
          placeholder: fallback,
        );

    final normal = cachedImage(uri, false, placeholder);
    final damagedUri = isDamaged
        ? ShipPortraitUriBuilder.build(
            ship: ship!,
            serverOrigin: serverOrigin,
            resourceType: resourceType,
            isDamaged: true,
          )
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: <Color>[Colors.black, Colors.black, Colors.transparent],
          stops: <double>[0, 0.76, 1],
        ).createShader(bounds),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: appColors(context, <Color>[
                  Color(0xff385064),
                  Color(0xff1b3240),
                ]),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: -horizontalOffset,
                  top: -verticalOffset,
                  child: damagedUri == null
                      ? normal
                      : cachedImage(damagedUri, true, normal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModPortraitImage extends StatefulWidget {
  const _ModPortraitImage({
    required this.portrait,
    required this.width,
    required this.height,
    required this.official,
  });
  final GameModPortraitImage portrait;
  final double width;
  final double height;
  final Widget official;

  @override
  State<_ModPortraitImage> createState() => _ModPortraitImageState();
}

class _ModPortraitImageState extends State<_ModPortraitImage> {
  bool _failed = false;
  bool _failureScheduled = false;

  @override
  void didUpdateWidget(covariant _ModPortraitImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portrait.cacheKey != widget.portrait.cacheKey) {
      _failed = false;
      _failureScheduled = false;
    }
  }

  void _decodeFailed() {
    if (_failed || _failureScheduled) return;
    _failureScheduled = true;
    final failedKey = widget.portrait.cacheKey;
    scheduleMicrotask(() {
      if (!mounted || widget.portrait.cacheKey != failedKey) return;
      setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.official;
    final portrait = widget.portrait;
    final width = widget.width;
    final height = widget.height;
    final full =
        portrait.layout == GameModPortraitLayout.full ||
        portrait.layout == GameModPortraitLayout.characterFull;
    final banner = portrait.layout == GameModPortraitLayout.banner;
    final imageHeight = full || banner ? height : (height / 176) * 182;
    return ClipRRect(
      key: const ValueKey('game-mod-portrait'),
      borderRadius: BorderRadius.circular(8),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.76, 1],
        ).createShader(bounds),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: appColors(context, [
                  Color(0xff385064),
                  Color(0xff1b3240),
                ]),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: full || banner ? 0 : -height * 0.555,
                  top: full || banner ? 0 : -(height / 176) * 3,
                  child: Image.memory(
                    portrait.bytes,
                    key: ValueKey(portrait.cacheKey),
                    height: imageHeight,
                    width: banner ? width : null,
                    fit: banner ? BoxFit.cover : BoxFit.fitHeight,
                    gaplessPlayback: false,
                    errorBuilder: (_, error, stack) {
                      _decodeFailed();
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersistentPortraitImage extends StatefulWidget {
  const _PersistentPortraitImage({
    required this.uri,
    required this.cacheKey,
    required this.cache,
    required this.height,
    required this.decodeHeight,
    required this.fit,
    required this.placeholder,
    required this.imageProviderBuilder,
  });

  final Uri uri;
  final String cacheKey;
  final ShipPortraitCache cache;
  final double height;
  final int? decodeHeight;
  final BoxFit fit;
  final Widget placeholder;
  final ShipPortraitFileImageProviderBuilder? imageProviderBuilder;

  @override
  State<_PersistentPortraitImage> createState() =>
      _PersistentPortraitImageState();
}

class _PersistentPortraitImageState extends State<_PersistentPortraitImage> {
  late Future<File?> _file;
  int _decodeAttempt = 0;
  int? _handledDecodeErrorAttempt;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _PersistentPortraitImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri ||
        oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.cache != widget.cache) {
      _generation++;
      _decodeAttempt = 0;
      _handledDecodeErrorAttempt = null;
      _resolve();
    }
  }

  void _resolve() {
    _file = widget.cache.resolve(cacheKey: widget.cacheKey, uri: widget.uri);
  }

  void _handleDecodeError(int failedAttempt) {
    if (failedAttempt != _decodeAttempt) return;
    if (_handledDecodeErrorAttempt == _decodeAttempt) return;
    _handledDecodeErrorAttempt = _decodeAttempt;
    final failedGeneration = _generation;
    final failedUri = widget.uri;
    final failedCacheKey = widget.cacheKey;
    final failedCache = widget.cache;
    final retry = failedAttempt == 0;
    unawaited(
      failedCache.evict(cacheKey: failedCacheKey, uri: failedUri).then((_) {
        scheduleMicrotask(() {
          if (!mounted ||
              !retry ||
              _generation != failedGeneration ||
              _decodeAttempt != failedAttempt ||
              widget.uri != failedUri ||
              widget.cacheKey != failedCacheKey ||
              widget.cache != failedCache) {
            return;
          }
          setState(() {
            _decodeAttempt++;
            _resolve();
          });
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    future: _file,
    builder: (context, snapshot) {
      final file = snapshot.data;
      if (snapshot.connectionState != ConnectionState.done || file == null) {
        return widget.placeholder;
      }
      final renderedAttempt = _decodeAttempt;
      final imageProvider =
          widget.imageProviderBuilder?.call(file, widget.decodeHeight) ??
          ResizeImage.resizeIfNeeded(
            null,
            widget.decodeHeight,
            FileImage(file),
          );
      return Image(
        key: ValueKey<String>(
          'ship-portrait-$_generation-$renderedAttempt-${file.path}',
        ),
        image: imageProvider,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          _handleDecodeError(renderedAttempt);
          return widget.placeholder;
        },
      );
    },
  );
}
