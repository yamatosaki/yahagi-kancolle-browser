import 'package:flutter/material.dart';

import '../game_state/game_state.dart';

const shipCardPortraitHeight = 54.0;
const shipCardCapsuleMinHeight = 76.0;

double shipCardPortraitWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width * 0.16).clamp(100.0, 180.0);
}

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

  static Uri? build({required MasterShip ship, required String serverOrigin}) {
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
    final cipher = _createCipher(ship.id, 'ship_remodel');
    final version = int.tryParse(ship.portraitVersion!);
    return server.replace(
      path: '/kcs2/resources/ship/remodel/${paddedId}_$cipher.png',
      queryParameters: version != null && version > 1
          ? <String, String>{'version': ship.portraitVersion!}
          : null,
    );
  }

  static String _createCipher(int id, String seed) {
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
  });

  final MasterShip? ship;
  final String serverOrigin;
  final double width;
  final double height;
  final int? decodeHeight;

  @override
  Widget build(BuildContext context) {
    final uri = ship == null
        ? null
        : ShipPortraitUriBuilder.build(ship: ship!, serverOrigin: serverOrigin);
    final placeholder = ColoredBox(
      color: const Color(0xff1b3240),
      child: SizedBox(
        width: width,
        height: height,
        child: const Icon(
          Icons.directions_boat_outlined,
          color: Color(0xff8197a5),
        ),
      ),
    );
    if (uri == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: placeholder,
      );
    }
    final imageHeight = (height / 176) * 182;
    final horizontalOffset = height * 0.555;
    final verticalOffset = (height / 176) * 3;
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xff385064), Color(0xff1b3240)],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: -horizontalOffset,
                  top: -verticalOffset,
                  child: Image.network(
                    uri.toString(),
                    height: imageHeight,
                    cacheHeight: decodeHeight,
                    fit: BoxFit.fitHeight,
                    errorBuilder: (context, error, stackTrace) => placeholder,
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
