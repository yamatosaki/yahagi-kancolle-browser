import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_check_page.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('远征检查详情默认选择远征 1', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>).first,
          )
          .initialValue,
      1,
    );
  });

  testWidgets('详情页在窄屏显示耗时、消耗、收入与条件', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(controller: controller, onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('远征检查'), findsOneWidget);
    expect(find.text('远征时间与消耗'), findsOneWidget);
    expect(find.text('预计收入'), findsOneWidget);
    expect(find.text('远征条件'), findsOneWidget);

    await tester.tap(find.text('大成功'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大成功模式在宽屏完整单行显示且不使用横向滚动', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          showHeader: false,
        ),
      ),
    );
    await tester.tap(find.text('大成功'));
    await tester.pumpAndSettle();

    final controls = find.byKey(const Key('expedition-header-controls'));
    final results = find.byKey(const Key('expedition-header-results'));
    expect(controls, findsOneWidget);
    expect(results, findsOneWidget);
    expect(
      (tester.getCenter(controls).dy - tester.getCenter(results).dy).abs(),
      lessThan(2),
    );
    expect(
      tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((scroll) => scroll.scrollDirection == Axis.horizontal),
      isEmpty,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('expedition-mission-label')))
          .overflow,
      isNot(TextOverflow.ellipsis),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('大成功模式在窄屏仅将两个检查结果换到第二行', (tester) async {
    tester.view.physicalSize = const Size(700, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpeditionCheckPage(
          controller: controller,
          onBack: () {},
          showHeader: false,
        ),
      ),
    );
    await tester.tap(find.text('大成功'));
    await tester.pumpAndSettle();

    final controls = find.byKey(const Key('expedition-header-controls'));
    final results = find.byKey(const Key('expedition-header-results'));
    expect(controls, findsOneWidget);
    expect(results, findsOneWidget);
    expect(
      tester.getTopLeft(results).dy,
      greaterThan(tester.getBottomLeft(controls).dy),
    );
    expect(
      find.descendant(of: results, matching: find.byType(Text)),
      findsNWidgets(2),
    );
    expect(
      tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((scroll) => scroll.scrollDirection == Axis.horizontal),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
