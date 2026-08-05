import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_dataset.dart';
import 'package:yahagi_kancolle_browser/src/battle/fcd_map_update_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/fcd_map_update_section.dart';

String _map(String version) =>
    '{"meta":{"name":"map","version":"$version"},"data":{"5-6":{"route":{"42":["X","Y"]}}}}';

void main() {
  testWidgets('shows a stored UTC check time in the device local timezone', (
    tester,
  ) async {
    final checkedAtUtc = DateTime.utc(2026, 8, 5, 16, 0, 45);
    final local = checkedAtUtc.toLocal();
    final expected =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
    final controller = FcdMapController(
      dataset: FcdMapDataset.parse(_map('2026/07/01/01'), minimumMapCount: 1),
      updater: _Updater((current) async => FcdMapUpToDate(current.version)),
      lastCheckedAt: checkedAtUtc,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));

    expect(find.textContaining('上次检查：$expected'), findsOneWidget);
  });

  testWidgets('keeps version and last-check metadata on one styled row', (
    tester,
  ) async {
    final controller = FcdMapController(
      dataset: FcdMapDataset.parse(_map('2026/07/01/01'), minimumMapCount: 1),
      updater: _Updater((current) async => FcdMapUpToDate(current.version)),
      lastCheckedAt: DateTime(2026, 8, 5, 14, 30),
      sourceHost: 'raw.githubusercontent.com',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));

    final versionFinder = find.textContaining('数据版本：2026/07/01/01');
    final checkedFinder = find.textContaining('上次检查：2026-08-05 14:30');
    expect(versionFinder, findsOneWidget);
    expect(checkedFinder, findsOneWidget);
    expect(
      tester.widget<Text>(versionFinder).style,
      tester.widget<Text>(checkedFinder).style,
    );
    expect(
      tester.getTopLeft(versionFinder).dy,
      tester.getTopLeft(checkedFinder).dy,
    );
    expect(find.textContaining('raw.githubusercontent.com'), findsNothing);
    expect(find.textContaining('数据来源'), findsNothing);
    expect(find.textContaining('poi FCD'), findsNothing);
  });

  testWidgets('wraps metadata without overflow on a narrow screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = FcdMapController(
      dataset: FcdMapDataset.parse(_map('2026/07/01/01'), minimumMapCount: 1),
      updater: _Updater((current) async => FcdMapUpToDate(current.version)),
      lastCheckedAt: DateTime(2026, 8, 5, 14, 30),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));

    expect(find.textContaining('数据版本：2026/07/01/01'), findsOneWidget);
    expect(find.textContaining('上次检查：2026-08-05 14:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows version and disables duplicate manual checks', (
    tester,
  ) async {
    final completer = Completer<FcdMapUpdateResult>();
    final controller = FcdMapController(
      dataset: FcdMapDataset.parse(_map('2026/07/01/01'), minimumMapCount: 1),
      updater: _Updater((_) => completer.future),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    expect(find.textContaining('2026/07/01/01'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fcd-map-check-button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('fcd-map-check-button')))
          .onPressed,
      isNull,
    );
    completer.complete(FcdMapUpToDate(controller.version));
    await tester.pumpAndSettle();
    expect(find.textContaining('未卜先知数据已经是最新版本。'), findsOneWidget);
  });

  testWidgets('reports a hot-applied data update', (tester) async {
    final updated = FcdMapDataset.parse(
      _map('2026/07/28/02'),
      minimumMapCount: 1,
    );
    final controller = FcdMapController(
      dataset: FcdMapDataset.parse(_map('2026/07/01/01'), minimumMapCount: 1),
      updater: _Updater((_) async => FcdMapUpdated(updated)),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('fcd-map-check-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2026/07/28/02'), findsWidgets);
    expect(find.textContaining('已立即生效'), findsOneWidget);
  });
}

Widget _app(FcdMapController controller) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: FcdMapUpdateSection(controller: controller)),
);

final class _Updater implements FcdMapUpdateClient {
  _Updater(this.callback);

  final Future<FcdMapUpdateResult> Function(FcdMapDataset current) callback;

  @override
  Future<FcdMapUpdateResult> checkAndUpdate({required FcdMapDataset current}) =>
      callback(current);
}
