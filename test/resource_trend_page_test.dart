import 'dart:async';
import 'dart:ui' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_page.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_chart.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_sampler.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

Map<String, dynamic> row(DateTime at, int amount) => {
  'timestamp': at.millisecondsSinceEpoch,
  for (final key in resourceTrendKeys) key: amount,
};
Widget wrap(
  ResourceTrendLoader loader, {
  DateTime Function()? now,
  Locale locale = const Locale('zh'),
  double textScale = 1,
  bool visible = true,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: ResourceTrendPage(loadLogs: loader, now: now, visible: visible),
  ),
);
void main() {
  testWidgets('hidden resource chart defers refresh and retains the view', (
    tester,
  ) async {
    var clock = DateTime.parse('2026-09-05T23:59:00.000+09:00');
    DateTime now() => clock;
    final requests = <int>[];
    Future<List<Map<String, dynamic>>> load(int days) async {
      requests.add(days);
      return [row(clock, 1200)];
    }

    await tester.pumpWidget(wrap(load, now: now));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resource-range-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resource-card-ammo')));
    await tester.pumpAndSettle();
    ResourceTrendChart chart() =>
        tester.widget<ResourceTrendChart>(find.byType(ResourceTrendChart));
    expect(chart().resourceKey, 'ammo');
    expect(requests, [1, 7]);

    await tester.pumpWidget(wrap(load, now: now, visible: false));
    clock = clock.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, [1, 7]);

    await tester.pumpWidget(wrap(load, now: now));
    await tester.pumpAndSettle();
    expect(requests, [1, 7, 7]);
    expect(chart().resourceKey, 'ammo');
    expect(chart().data.window.days, 7);
  });

  testWidgets('JST midnight rolls the range and resume reloads observations', (
    tester,
  ) async {
    var clock = DateTime.parse('2026-09-05T23:59:59.000+09:00');
    var calls = 0;
    await tester.pumpWidget(
      wrap((_) async {
        calls++;
        return [row(clock, 1200)];
      }, now: () => clock),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    clock = clock.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(calls, 2);
    final chart = tester.widget<ResourceTrendChart>(
      find.byType(ResourceTrendChart),
    );
    expect(chart.data.window.start, DateTime.utc(2026, 9, 5, 15));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(days: 2));
    expect(calls, 3);
  });
  testWidgets(
    'chart touch and slider inspect real chronological observations',
    (tester) async {
      final now = DateTime.parse('2026-09-05T18:00:00+09:00');
      final start = DateTime.parse('2026-09-05T00:00:00+09:00');
      await tester.pumpWidget(
        wrap(
          (_) async => [
            row(start, 1000),
            row(start.add(const Duration(minutes: 1)), 1050),
            row(now, 1300),
          ],
          now: () => now,
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('resource-trend-canvas'));
      ResourceTrendPainter painter() =>
          tester.widget<CustomPaint>(finder).painter! as ResourceTrendPainter;
      final bounds = painter().plotRect(tester.getSize(finder));
      await tester.tapAt(
        tester.getTopLeft(finder) +
            Offset(bounds.left + bounds.width * .01, bounds.center.dy),
      );
      await tester.pump();
      expect(painter().selected, 1);
      tester
          .widget<Slider>(find.byKey(const ValueKey('resource-trend-scrubber')))
          .onChanged!(1);
      await tester.pump();
      expect(painter().selected, 2);
      expect(painter().points.last.value, 1300);
    },
  );
  testWidgets('large text in Japanese remains usable on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrap(
        (_) async => [
          row(DateTime.now().subtract(const Duration(days: 1)), 100),
          row(DateTime.now().subtract(const Duration(seconds: 1)), 9999999),
        ],
        locale: const Locale('ja'),
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('resource-trend-expand')),
    );
    await tester.tap(find.byKey(const ValueKey('resource-trend-expand')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('resource database notifications refresh visible inventory', (
    tester,
  ) async {
    final db = (await tester.runAsync(LogbookDatabase.openForTesting))!;
    addTearDown(db.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceTrendPage(
            database: db,
            now: () => DateTime.now().add(const Duration(seconds: 2)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await db.insertResourceSnapshot(
        GameState(
          resources: {for (final type in GameResourceType.values) type: 2345},
        ),
      );
      // The notifier debounce is created in the real async zone alongside
      // native SQLite I/O, so allow that clock (not the fake pump clock) to run.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('2,345'), findsNWidgets(9));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('empty persisted selections fall back to all eight resources', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      resourceTrendVisibleResourcesKey: ['unknown'],
    });
    await tester.pumpWidget(wrap((_) async => []));
    await tester.pumpAndSettle();
    for (final key in resourceTrendKeys) {
      expect(find.byKey(ValueKey('resource-card-$key')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('resource-trend-filter')));
    await tester.pumpAndSettle();
    for (final key in resourceTrendKeys) {
      await tester.ensureVisible(find.byKey(ValueKey('resource-filter-$key')));
      await tester.tap(find.byKey(ValueKey('resource-filter-$key')));
      await tester.pump();
    }
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '确定'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('capsules expose a working accessibility tap action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap((_) async => []));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find.byKey(const ValueKey('resource-card-bucket')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        viewId: tester.view.viewId,
        nodeId: node.id,
        type: SemanticsAction.tap,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ResourceTrendChart>(find.byType(ResourceTrendChart))
          .resourceKey,
      'bucket',
    );
    semantics.dispose();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  List<Map<String, dynamic>> rows(int days) {
    final now = DateTime.now();
    return [
      row(now.subtract(Duration(days: days)), 1000),
      row(now.subtract(const Duration(seconds: 1)), 1200 + days),
    ];
  }

  testWidgets(
    'one global range controls eight compact capsules and a single chart',
    (tester) async {
      await tester.pumpWidget(wrap((days) async => rows(days)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resource-trend-chart')),
        findsOneWidget,
      );
      for (final key in resourceTrendKeys) {
        expect(find.byKey(ValueKey('resource-card-$key')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(ValueKey('resource-card-$key'))).height,
          40,
        );
      }
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('7天'), findsOneWidget);
      expect(find.text('90天'), findsOneWidget);
      expect(find.text('▲+201'), findsNWidgets(8));
      await tester.tap(find.text('7天'));
      await tester.pumpAndSettle();
      expect(find.text('▲+207'), findsNWidgets(8));
      await tester.tap(find.byKey(const ValueKey('resource-card-bucket')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resource-trend-chart')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(412, 915),
    const Size(720, 840),
    const Size(840, 720),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    testWidgets('responsive layout has no overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrap(
          (_) async => [
            row(DateTime.now().subtract(const Duration(days: 100)), 9999999),
            row(DateTime.now().subtract(const Duration(seconds: 1)), 1),
          ],
        ),
      );
      await tester.pumpAndSettle();
      if (size.width > size.height && size.width >= 600) {
        final fuel = tester.getTopLeft(
          find.byKey(const ValueKey('resource-card-fuel')),
        );
        final bauxite = tester.getTopLeft(
          find.byKey(const ValueKey('resource-card-bauxite')),
        );
        final bucket = tester.getTopLeft(
          find.byKey(const ValueKey('resource-card-bucket')),
        );
        expect(fuel.dy, bauxite.dy);
        expect(bucket.dy, fuel.dy + 48);
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('resource-trend-expand')),
      );
      await tester.tap(find.byKey(const ValueKey('resource-trend-expand')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resource-trend-fullscreen')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    });
  }
  testWidgets('late responses cannot overwrite the selected range', (
    tester,
  ) async {
    final old = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      wrap((days) => days == 1 ? old.future : Future.value(rows(days))),
    );
    await tester.pump();
    await tester.tap(find.text('30天'));
    await tester.pumpAndSettle();
    old.complete(rows(1));
    await tester.pumpAndSettle();
    expect(find.text('▲+230'), findsNWidgets(8));
    expect(find.text('▲+201'), findsNothing);
  });
  testWidgets('failed query shows retry instead of empty data', (tester) async {
    var fails = true;
    await tester.pumpWidget(
      wrap((days) async {
        if (fails) throw StateError('offline');
        return rows(days);
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resource-trend-retry')), findsOneWidget);
    fails = false;
    await tester.tap(find.byKey(const ValueKey('resource-trend-retry')));
    await tester.pumpAndSettle();
    expect(find.text('▲+201'), findsNWidgets(8));
  });
  testWidgets(
    'resource filter preserves a nonempty selection and persists it',
    (tester) async {
      await tester.pumpWidget(wrap((days) async => rows(days)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resource-trend-filter')));
      await tester.pumpAndSettle();
      for (final key in resourceTrendKeys.where((key) => key != 'fuel')) {
        await tester.ensureVisible(
          find.byKey(ValueKey('resource-filter-$key')),
        );
        await tester.tap(find.byKey(ValueKey('resource-filter-$key')));
        await tester.pump();
      }
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resource-card-fuel')), findsOneWidget);
      expect(find.byKey(const ValueKey('resource-card-bucket')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(wrap((days) async => rows(days)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resource-card-bucket')), findsNothing);
    },
  );
}
