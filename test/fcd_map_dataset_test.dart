import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';

String _datasetJson({
  String version = '2026/07/28/02',
  Map<String, Object?>? data,
}) => jsonEncode(<String, Object?>{
  'meta': <String, Object?>{'name': 'map', 'version': version},
  'data':
      data ??
      <String, Object?>{
        '5-6': <String, Object?>{
          'route': <String, Object?>{
            '42': <Object?>['X', 'Y'],
            '43': <Object?>['Y', 'A1'],
            '44': <Object?>['A1', 'AA'],
            '45': <Object?>['AA', 'ZZ'],
          },
        },
      },
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled POI snapshot parses and resolves a real route', () async {
    final raw = await rootBundle.loadString('assets/data/fcd/map.json');
    final dataset = FcdMapDataset.parse(raw);

    expect(dataset.version.toString(), '2026/07/28/02');
    expect(dataset.mapCount, greaterThan(50));
    expect(dataset.routeCount, greaterThan(1000));
    expect(
      dataset.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 42),
      'Y',
    );
  });

  test('compares validated FCD versions by numeric segments', () {
    final older = FcdMapVersion.parse('2026/07/28/02');
    final newerRevision = FcdMapVersion.parse('2026/07/28/10');
    final newerDay = FcdMapVersion.parse('2026/07/29/01');

    expect(older.toString(), '2026/07/28/02');
    expect(older.compareTo(newerRevision), lessThan(0));
    expect(newerRevision.compareTo(newerDay), lessThan(0));
    expect(() => FcdMapVersion.parse('2026/02/30/01'), throwsFormatException);
    expect(() => FcdMapVersion.parse('v2026/07/28/02'), throwsFormatException);
  });

  test('resolves route destinations instead of alphabetizing internal ids', () {
    final dataset = FcdMapDataset.parse(_datasetJson(), minimumMapCount: 1);

    expect(dataset.version.toString(), '2026/07/28/02');
    expect(
      dataset.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 42),
      'Y',
    );
    expect(
      dataset.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 43),
      'A1',
    );
    expect(
      dataset.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 44),
      'AA',
    );
    expect(
      dataset.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 45),
      'ZZ',
    );
    expect(
      dataset.resolve(mapAreaId: 5, mapInfoNo: 6, internalNodeId: 99),
      isNull,
    );
  });

  test('rejects malformed or unsafe FCD datasets', () {
    final cases = <String>[
      '{}',
      jsonEncode(<String, Object?>{
        'meta': <String, Object?>{
          'name': 'shiptag',
          'version': '2026/07/28/02',
        },
        'data': <String, Object?>{},
      }),
      _datasetJson(data: <String, Object?>{}),
      _datasetJson(
        data: <String, Object?>{
          'bad-map-key': <String, Object?>{
            'route': <String, Object?>{
              '1': <Object?>['A', 'B'],
            },
          },
        },
      ),
      _datasetJson(
        data: <String, Object?>{
          '5-6': <String, Object?>{
            'route': <String, Object?>{
              '42': <Object?>['X'],
            },
          },
        },
      ),
      _datasetJson(
        data: <String, Object?>{
          '5-6': <String, Object?>{
            'route': <String, Object?>{
              '42': <Object?>['X', ''],
            },
          },
        },
      ),
    ];

    for (final raw in cases) {
      expect(
        () => FcdMapDataset.parse(raw, minimumMapCount: 1),
        throwsFormatException,
        reason: raw,
      );
    }
  });

  test('rejects a response larger than the configured limit', () {
    final raw = _datasetJson();
    expect(
      () => FcdMapDataset.parse(
        raw,
        maxBytes: utf8.encode(raw).length - 1,
        minimumMapCount: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects severely incomplete or route-empty update datasets', () {
    expect(() => FcdMapDataset.parse(_datasetJson()), throwsFormatException);
    final emptyRoutes = <String, Object?>{
      for (var index = 1; index <= 50; index++)
        '1-$index': <String, Object?>{'route': <String, Object?>{}},
    };
    expect(
      () => FcdMapDataset.parse(_datasetJson(data: emptyRoutes)),
      throwsFormatException,
    );
  });
}
