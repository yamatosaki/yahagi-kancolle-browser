import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/morale_recovery_timer_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notification/notification_timer_anchor_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('selected fleet renders its ship status capsules', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    expect(find.byKey(const Key('fleet-summary-selector-1')), findsOneWidget);
    expect(find.byType(FleetShipStatusCapsule), findsNWidgets(2));
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('吹雪'), findsOneWidget);
  });

  testWidgets('home ship capsule shows a same-size combat mechanism badge', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    final level = tester.widget<Text>(find.text('Lv. 50'));
    final mechanism = tester.widget<Text>(find.text('先反'));
    expect(mechanism.style?.fontSize, level.style?.fontSize);
    expect(mechanism.style?.fontWeight, level.style?.fontWeight);
    expect(find.byKey(const Key('fleet-focus-mechanism-9001')), findsOneWidget);
  });

  testWidgets('home ship top status badge uses its own color outline', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    final badge = find.byKey(const Key('fleet-focus-speed-9001'));
    final container = find.descendant(
      of: badge,
      matching: find.byType(Container),
    );
    final decoration = tester.widget<Container>(container).decoration;

    expect(decoration, isA<BoxDecoration>());
    expect(
      (decoration! as BoxDecoration).border,
      Border.all(color: const Color(0xff7ed8cf).withValues(alpha: 0.42)),
    );
  });

  testWidgets('fleet selector changes the list and ship tap opens that fleet', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);
    int? openedFleetId;

    await tester.pumpWidget(
      _card(
        controller: controller,
        onOpenFleet: (fleetId) => openedFleetId = fleetId,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FleetShipStatusCapsule).first);
    expect(openedFleetId, 1);

    await tester.tap(find.byKey(const Key('fleet-summary-selector-2')));
    await tester.pump();
    expect(find.byType(FleetShipStatusCapsule), findsOneWidget);
    expect(find.text('吹雪'), findsOneWidget);

    await tester.tap(find.byType(FleetShipStatusCapsule));
    expect(openedFleetId, 2);
  });

  testWidgets('selecting an empty fleet shows the empty state', (tester) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fleet-summary-selector-3')));
    await tester.pump();

    expect(find.text('无数据'), findsOneWidget);
    expect(find.byType(FleetShipStatusCapsule), findsNothing);
  });

  testWidgets('repeating ship animations do not block finite-frame tests', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.byType(FleetShipStatusCapsule), findsNWidgets(2));
  });

  testWidgets('fleet selectors share the title row and metrics fill old row', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    final title = find.text('编队简报');
    final selector = find.byKey(const Key('fleet-summary-selector-1'));
    final switcher = find.byKey(const Key('fleet-summary-switcher'));
    expect(title, findsOneWidget);
    expect(selector, findsOneWidget);
    expect(tester.getSize(switcher).width, 108);
    expect(tester.getSize(selector).width, closeTo(26, 1));
    expect(
      tester.getCenter(title).dy,
      closeTo(tester.getCenter(selector).dy, 1),
    );
    expect(
      tester.getTopLeft(selector).dx - tester.getTopRight(title).dx,
      greaterThan(100),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    const metricIds = <String>[
      'speed',
      'total-level',
      'air-power',
      'line-of-sight',
      'minimum-condition',
    ];
    for (final id in metricIds) {
      expect(find.byKey(Key('fleet-summary-metric-$id')), findsOneWidget);
    }

    final levelText = tester.widget<Text>(find.text('Lv. 50'));
    final metricText = tester.widget<Text>(
      find.byKey(const Key('fleet-summary-metric-speed-value')),
    );
    expect(metricText.style?.fontSize, levelText.style?.fontSize);
  });

  testWidgets('line-of-sight metric opens the shared formula 33 details', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('fleet-summary-metric-line-of-sight')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('索敌详情'), findsOneWidget);
    expect(find.text('总索敌'), findsOneWidget);
    expect(find.text('33式'), findsOneWidget);
    expect(find.text('× 1'), findsOneWidget);
    expect(find.text('× 4'), findsOneWidget);
  });

  testWidgets('air power metric opens the shared air power details', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    await tester.tap(find.byKey(const Key('fleet-summary-metric-air-power')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('制空详情'), findsOneWidget);
    expect(find.text('最小'), findsOneWidget);
    expect(find.text('最大'), findsOneWidget);
    expect(find.text('无加成'), findsOneWidget);
  });

  testWidgets('selected recovery countdown shows the live timer', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);
    final now = DateTime.utc(2026, 8, 23, 12);
    final fleet = controller.state.fleets.first;
    final timerController = MoraleRecoveryTimerController(
      initialAnchors: {
        fleet.id: MoraleNotificationTimerAnchor(
          fleetSignature: NotificationTimerSignature.morale(fleet),
          observedAt: now,
          observedCondition: 32,
          targetAt: now.add(const Duration(minutes: 8, seconds: 42)),
        ),
      },
    );
    addTearDown(timerController.dispose);

    await tester.pumpWidget(
      _card(
        controller: controller,
        moraleRecoveryTimerController: timerController,
        moraleMetricMode: FleetMoraleMetricMode.recoveryCountdown,
        clock: () => now,
      ),
    );
    await tester.pump();

    expect(find.text('恢复倒计时'), findsOneWidget);
    expect(find.text('08:42'), findsOneWidget);
    expect(
      find.byKey(const Key('fleet-summary-metric-recovery-countdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('fleet-summary-metric-minimum-condition')),
      findsNothing,
    );
  });

  testWidgets('home portraits show repair badges without fatigue text badges', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    expect(find.byKey(const Key('fleet-repair-badge-9001')), findsOneWidget);
    expect(find.byKey(const Key('fleet-repair-badge-9002')), findsOneWidget);
    expect(find.text('入渠'), findsNWidgets(2));
    expect(find.byKey(const Key('fleet-fatigue-badge-9001')), findsNothing);
    expect(find.byKey(const Key('fleet-fatigue-badge-9002')), findsNothing);
  });
}

Future<GameStateController> _controllerWithPortData() async {
  final controller = GameStateController();
  controller
    ..accept(start2Event)
    ..accept(portEvent)
    ..accept(slotItemEvent);
  await controller.idle;
  return controller;
}

Widget _card({
  required GameStateController controller,
  ValueChanged<int>? onOpenFleet,
  MoraleRecoveryTimerController? moraleRecoveryTimerController,
  FleetMoraleMetricMode moraleMetricMode =
      FleetMoraleMetricMode.minimumCondition,
  VoidCallback? onToggleMoraleMetricMode,
  DateTime Function()? clock,
}) => MaterialApp(
  home: Scaffold(
    body: FleetSummaryCard(
      controller: controller,
      collapsed: false,
      onToggleCollapse: () {},
      onOpenFleet: onOpenFleet ?? (_) {},
      moraleRecoveryTimerController: moraleRecoveryTimerController,
      visible: moraleMetricMode == FleetMoraleMetricMode.recoveryCountdown
          ? ({...defaultFields}
              ..remove('minimum-condition')
              ..add('recovery-countdown'))
          : defaultFields,
      clock: clock,
    ),
  ),
);
