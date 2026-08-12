import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_sampler.dart';

Map<String, dynamic> _row(
  int index, {
  int fuel = 100,
  int ammo = 200,
  int steel = 300,
  int bauxite = 400,
  int bucket = 10,
  int devmat = 20,
  int blowtorch = 30,
  int screw = 40,
}) {
  return <String, dynamic>{
    'timestamp': 1000 + index,
    'fuel': fuel,
    'ammo': ammo,
    'steel': steel,
    'bauxite': bauxite,
    'bucket': bucket,
    'devmat': devmat,
    'blowtorch': blowtorch,
    'screw': screw,
  };
}

void main() {
  test('empty input stays empty', () {
    expect(downsampleResourceLogs(const <Map<String, dynamic>>[]), isEmpty);
  });

  test('small input is returned unchanged', () {
    final rows = <Map<String, dynamic>>[
      _row(0),
      _row(1, fuel: 101),
      _row(2, fuel: 99),
    ];
    final result = downsampleResourceLogs(rows, maxPoints: 500);
    expect(result, same(rows));
  });

  test('consecutive identical snapshots are removed', () {
    final rows = <Map<String, dynamic>>[
      _row(0),
      _row(1),
      _row(2),
      _row(3, fuel: 150),
      _row(4, fuel: 150),
    ];
    final result = downsampleResourceLogs(rows, maxPoints: 500);
    expect(result.length, 2);
    expect(result.first['timestamp'], 1000);
    expect(result.last['fuel'], 150);
  });

  test('large input is capped and preserves first and last rows', () {
    final rows = <Map<String, dynamic>>[
      for (var i = 0; i < 2000; i++) _row(i, fuel: 100 + i % 50),
    ];
    final result = downsampleResourceLogs(rows, maxPoints: 500);
    expect(result.length, lessThanOrEqualTo(500));
    expect(result.first['timestamp'], 1000);
    expect(result.last['timestamp'], 1000 + 1999);
  });

  test('mid-bucket spikes survive downsampling', () {
    final rows = <Map<String, dynamic>>[
      for (var i = 0; i < 120; i++) _row(i, fuel: 100),
    ];
    rows[5] = _row(5, fuel: 5000); // A sharp spike early in the first bucket.
    final result = downsampleResourceLogs(rows, maxPoints: 8);
    final fuels = result.map((r) => r['fuel'] as int).toList();
    expect(fuels, contains(5000));
    expect(fuels.first, 100);
    expect(fuels.last, 100);
  });

  test('result timestamps stay in ascending order', () {
    final rows = <Map<String, dynamic>>[
      for (var i = 0; i < 1000; i++)
        _row(i, fuel: (i * 37) % 1000, ammo: (i * 13) % 800),
    ];
    final result = downsampleResourceLogs(rows, maxPoints: 100);
    final timestamps = result.map((r) => r['timestamp'] as int).toList();
    for (var i = 1; i < timestamps.length; i++) {
      expect(timestamps[i], greaterThan(timestamps[i - 1]));
    }
  });

  test(
    'streaming sampler stays bounded and preserves endpoints and spikes',
    () {
      final sampler = ResourceTrendStreamSampler(
        expectedRows: 2000,
        maxPoints: 100,
      );
      for (var index = 0; index < 2000; index++) {
        sampler.add(_row(index, fuel: index == 505 ? 9000 : 100 + index % 20));
      }

      final result = sampler.finish();

      expect(result.length, lessThanOrEqualTo(100));
      expect(result.first['timestamp'], 1000);
      expect(result.last['timestamp'], 2999);
      expect(result.map((row) => row['fuel']), contains(9000));
    },
  );
}
