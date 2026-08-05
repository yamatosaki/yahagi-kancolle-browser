import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/about_dialog.dart';

void main() {
  testWidgets('about dialog fits a compact landscape viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(820, 560);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AboutDialogWidget())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('about-disclaimer-scroll')), findsOneWidget);
    expect(find.textContaining('1.0.2'), findsOneWidget);
  });

  testWidgets('compact landscape keeps the full about content reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AboutDialogWidget())),
    );
    await tester.pumpAndSettle();

    final scroll = find.byKey(const Key('about-content-scroll'));
    expect(scroll, findsOneWidget);
    expect(tester.getSize(scroll).height, greaterThanOrEqualTo(140));
    await tester.scrollUntilVisible(
      find.byKey(const Key('about-disclaimer-end')),
      120,
      scrollable: find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('about-disclaimer-end')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
