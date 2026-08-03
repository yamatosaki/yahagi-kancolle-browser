import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_page.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';

Map<String, dynamic> _row(
  DateTime time, {
  int fuel = 1000,
  int ammo = 2000,
  int steel = 3000,
  int bauxite = 4000,
  int bucket = 100,
  int devmat = 20,
  int blowtorch = 30,
  int screw = 40,
}) {
  return <String, dynamic>{
    'timestamp': time.millisecondsSinceEpoch,
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

Future<void> _seed(List<Map<String, dynamic>> rows) async {
  final db = await LogbookDatabase.instance.database;
  await db.delete('resource_logs');
  for (final row in rows) {
    await db.insert('resource_logs', row);
  }
}

Widget _wrap() => const MaterialApp(home: Scaffold(body: ResourceTrendPage()));

void main() {
  testWidgets('flat resource data renders two charts without errors', (
    tester,
  ) async {
    final now = DateTime.now();
    await _seed(<Map<String, dynamic>>[
      for (var i = 20; i >= 0; i--)
        _row(now.subtract(Duration(minutes: i * 30))),
    ]);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsNWidgets(2));
    expect(find.text('1,000'), findsWidgets);
  });

  testWidgets('single record renders without errors', (tester) async {
    await _seed(<Map<String, dynamic>>[_row(DateTime.now())]);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsNWidgets(2));
  });

  testWidgets('empty data shows the empty state', (tester) async {
    await _seed(<Map<String, dynamic>>[]);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('暂无资源记录'), findsOneWidget);
  });

  testWidgets('tapping a stat card hides its line series', (tester) async {
    final now = DateTime.now();
    await _seed(<Map<String, dynamic>>[
      for (var i = 12; i >= 0; i--)
        _row(now.subtract(Duration(hours: i * 2)), fuel: 1000 + i * 10),
    ]);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    LineChart mainChart() =>
        tester.widget<LineChart>(find.byType(LineChart).first);
    expect(mainChart().data.lineBarsData.length, 4);

    await tester.tap(find.byKey(const Key('resource-trend-card-fuel')));
    await tester.pumpAndSettle();

    expect(mainChart().data.lineBarsData.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter buttons switch ranges without errors', (tester) async {
    final now = DateTime.now();
    await _seed(<Map<String, dynamic>>[
      _row(now.subtract(const Duration(days: 40)), fuel: 500),
      _row(now.subtract(const Duration(days: 10)), fuel: 900),
      _row(now, fuel: 1200),
    ]);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    for (final label in <String>['7天', '30天', '全部记录', '24小时']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsNWidgets(2));
    }
  });
}
