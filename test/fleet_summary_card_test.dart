import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/separated_wrap.dart';
import 'package:yahagi_kancolle_browser/src/fleet/morale_recovery_timer_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_dashboard_content.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
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

  testWidgets('ship type badges can use English abbreviations', (tester) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _card(
        controller: controller,
        shipTypeLabelMode: FleetShipTypeLabelMode.abbreviation,
      ),
    );
    await tester.pump();

    expect(find.text('DD'), findsOneWidget);
    expect(find.text('CL'), findsOneWidget);
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

  testWidgets('fleet selectors can use numeric abbreviations', (tester) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);
    setFleetSelectorLabelModeSetting(FleetSelectorLabelMode.number);
    addTearDown(
      () => setFleetSelectorLabelModeSetting(FleetSelectorLabelMode.customName),
    );

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    for (final label in ['1', '2', '3', '4']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('第一舰队'), findsNothing);
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

  testWidgets('flat 下空舰队的无数据是 11 号摘要灰且不居中', (tester) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_flatSummary(controller, 300));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fleet-summary-selector-3')));
    await tester.pump();

    final text = find.text('无数据');
    expect(text, findsOneWidget);
    final style = tester.widget<Text>(text).style;
    expect(style?.fontSize, 11);
    expect(style?.color, const Color(0xff8197a5));
    final padding =
        tester
                .widget<Padding>(
                  find.ancestor(of: text, matching: find.byType(Padding)).first,
                )
                .padding
            as EdgeInsets;
    expect(padding.horizontal / 2, lessThanOrEqualTo(6));
    expect(padding.vertical / 2, lessThanOrEqualTo(4));
    expect(
      find.ancestor(of: text, matching: find.byType(Center)),
      findsNothing,
    );
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

  testWidgets('flat summary separator never dangles at a wrapped line end', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 150,
              child: PanelStyleScope(
                style: PanelStyle.flat,
                child: FleetSummaryCard(
                  controller: controller,
                  collapsed: false,
                  onToggleCollapse: () {},
                  onOpenFleet: (_) {},
                  visible: defaultFields,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const ids = ['speed', 'total-level', 'air-power', 'line-of-sight'];
    final rows = {
      for (final id in ids)
        tester.getTopLeft(find.byKey(Key('fleet-summary-metric-$id'))).dy,
    };
    expect(rows.length, greaterThan(1), reason: 'metrics must wrap at 150dp');
    final wrap = tester.renderObject<RenderSeparatedWrap>(
      find.byType(SeparatedWrap),
    );
    final metrics = find.byKey(const Key('fleet-summary-metrics'));
    final left = tester.getTopLeft(metrics).dx;
    final right = tester.getTopRight(metrics).dx;
    final rects = [
      for (final id in ids)
        tester.getRect(find.byKey(Key('fleet-summary-metric-$id'))),
    ];
    for (final rect in rects) {
      expect(rect.right, lessThanOrEqualTo(right + 0.5));
    }
    final separators = wrap.debugSeparatorRects
        .map((r) => r.shift(tester.getTopLeft(metrics)))
        .toList();
    // Each separator sits between two metrics of its own line.
    for (final sep in separators) {
      final before = rects.where(
        (r) => (r.center.dy - sep.center.dy).abs() < 1 && r.right <= sep.left,
      );
      final after = rects.where(
        (r) => (r.center.dy - sep.center.dy).abs() < 1 && r.left >= sep.right,
      );
      expect(before, isNotEmpty, reason: 'separator at line start');
      expect(after, isNotEmpty, reason: 'separator at line end');
    }
    // One separator per adjacent pair on the same line.
    var sameLinePairs = 0;
    for (var i = 1; i < rects.length; i++) {
      if ((rects[i].center.dy - rects[i - 1].center.dy).abs() < 1) {
        sameLinePairs++;
      }
    }
    expect(separators.length, sameLinePairs);
    expect(sameLinePairs, lessThan(ids.length - 1));
    expect(rects.map((r) => r.left).reduce((a, b) => a < b ? a : b), left);
  });

  testWidgets('flat summary paints one separator between each metric', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_flatSummary(controller, 600));
    await tester.pump();

    final wrap = tester.renderObject<RenderSeparatedWrap>(
      find.byType(SeparatedWrap),
    );
    final count = tester
        .widgetList(
          find.descendant(
            of: find.byType(SeparatedWrap),
            matching: find.byType(InkWell),
          ),
        )
        .length;
    expect(count, greaterThan(1));
    expect(wrap.debugSeparatorRects.length, count - 1);
  });

  testWidgets('flat summary metrics stay tappable inside SeparatedWrap', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_flatSummary(controller, 300));
    await tester.pump();
    await tester.tap(find.byKey(const Key('fleet-summary-metric-air-power')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('制空详情'), findsOneWidget);
  });

  testWidgets('fleet selectors use names above metrics at matching width', (
    tester,
  ) async {
    final controller = await _controllerWithPortData();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller: controller));
    await tester.pump();

    final selector = find.byKey(const Key('fleet-summary-selector-1'));
    final switcher = find.byKey(const Key('fleet-summary-switcher'));
    final metrics = find.byKey(const Key('fleet-summary-metrics'));
    expect(selector, findsOneWidget);
    expect(find.text('第一舰队'), findsOneWidget);
    expect(find.text('第二舰队'), findsOneWidget);
    expect(find.text('第三舰队'), findsOneWidget);
    expect(find.text('第四舰队'), findsOneWidget);
    expect(
      tester.getSize(switcher).width,
      closeTo(tester.getSize(metrics).width, 1),
    );
    expect(
      tester.getBottomLeft(switcher).dy,
      lessThan(tester.getTopLeft(metrics).dy),
    );

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

  testWidgets(
    'opt-in transport metric shows paired values in port and on sortie',
    (tester) async {
      final fixture = await _controllerWithPortData();
      addTearDown(fixture.dispose);
      final controller = GameStateController(
        initialState: fixture.state.copyWith(
          combinedFleetType: CombinedFleetType.transportEscort,
          fleets: const [
            Fleet(id: 1, name: '主力', shipIds: [9001]),
            Fleet(id: 2, name: '护卫', shipIds: [9002]),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final transport = find.byKey(
        const Key('fleet-summary-metric-transport-points'),
      );
      final transportValue = find.byKey(
        const Key('fleet-summary-metric-transport-points-value'),
      );
      const totalText = 'S：7（A：4）';
      const tankTotalText = 'S：4（A：2）';

      await tester.pumpWidget(_card(controller: controller));
      expect(transport, findsNothing);

      await tester.pumpWidget(
        _card(
          controller: controller,
          visible: const {
            'line-of-sight',
            'transport-points',
            'recovery-countdown',
          },
        ),
      );
      expect(tester.widget<Text>(transportValue).data, '7（4）');
      expect(find.text('普通（战车）运输量'), findsOneWidget);
      expect(find.text(totalText), findsNothing);
      expect(find.text(tankTotalText), findsNothing);
      final transportX = tester.getCenter(transport).dx;
      expect(
        tester
            .getCenter(
              find.byKey(const Key('fleet-summary-metric-line-of-sight')),
            )
            .dx,
        lessThan(transportX),
      );
      expect(
        tester
            .getCenter(
              find.byKey(const Key('fleet-summary-metric-recovery-countdown')),
            )
            .dx,
        greaterThan(transportX),
      );

      await tester.tap(transport);
      await tester.pumpAndSettle();
      final popover = find.byKey(const Key('fleet-transport-details-popover'));
      for (final value in [
        totalText,
        tankTotalText,
        '5 TP',
        '2 TP',
        '3 TP',
        '1 TP',
      ]) {
        expect(
          find.descendant(of: popover, matching: find.text(value)),
          findsOneWidget,
        );
      }
      for (final label in ['第一舰队', '第二舰队']) {
        expect(
          find.descendant(of: popover, matching: find.text(label)),
          findsNWidgets(2),
        );
      }
      await tester.tap(find.byKey(const Key('fleet-transport-details-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fleet-summary-selector-2')));
      await tester.pump();
      expect(tester.widget<Text>(transportValue).data, '7（4）');
      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_map/start',
          {'api_maparea_id': 1, 'api_mapinfo_no': 1, 'api_no': 1},
          requestParams: {'api_deck_id': '1'},
        ),
      );
      await controller.idle;
      await tester.pump();
      expect(controller.state.combatState.isActive, isTrue);
      expect(tester.widget<Text>(transportValue).data, '7（4）');
      expect(find.text('普通（战车）运输量'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (label, width, columns, style, fields) in [
    (
      'ordinary phone',
      390.0,
      1,
      PanelStyle.card,
      {
        'speed',
        'air-power',
        'line-of-sight',
        'transport-points',
        'recovery-countdown',
      },
    ),
    (
      'compact phone',
      320.0,
      1,
      PanelStyle.flat,
      {
        'speed',
        'air-power',
        'line-of-sight',
        'transport-points',
        'recovery-countdown',
      },
    ),
    (
      'HD seven fields',
      760.0,
      2,
      PanelStyle.card,
      {
        'speed',
        'firepower',
        'anti-sub',
        'air-power',
        'line-of-sight',
        'transport-points',
        'recovery-countdown',
      },
    ),
  ]) {
    testWidgets('paired transport title stays readable in $label', (
      tester,
    ) async {
      final controller = await _controllerWithPortData();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: HdModuleColumns(
                  columns: columns,
                  child: PanelStyleScope(
                    style: style,
                    child: FleetSummaryCard(
                      controller: controller,
                      collapsed: false,
                      onToggleCollapse: () {},
                      onOpenFleet: (_) {},
                      visible: fields,
                      twoColumnVisible: fields,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final transport = find.byKey(
        const Key('fleet-summary-metric-transport-points'),
      );
      final title = find.descendant(
        of: transport,
        matching: find.text('普通（战车）运输量'),
      );
      final value = find.byKey(
        const Key('fleet-summary-metric-transport-points-value'),
      );
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(value).data, '7（5）');
      if (style == PanelStyle.card) {
        final titleBox = tester.renderObject<RenderBox>(title);
        final metricBox = tester.renderObject<RenderBox>(transport);
        final titleTransform = titleBox.getTransformTo(metricBox);
        expect(titleTransform.getMaxScaleOnAxis(), greaterThanOrEqualTo(.85));
      }
      await tester.tap(transport);
      await tester.pumpAndSettle();
      final popover = find.byKey(const Key('fleet-transport-details-popover'));
      expect(
        find.descendant(of: popover, matching: find.text('S：7（A：4）')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: popover, matching: find.text('S：5（A：3）')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('fleet-transport-details-close')));
      await tester.pumpAndSettle();
    });
  }

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
    expect(find.text('不含熟练度加成'), findsOneWidget);
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
  DateTime Function()? clock,
  FleetShipTypeLabelMode shipTypeLabelMode =
      FleetShipTypeLabelMode.localizedName,
  Set<String>? visible,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: FleetSummaryCard(
      controller: controller,
      collapsed: false,
      onToggleCollapse: () {},
      onOpenFleet: onOpenFleet ?? (_) {},
      moraleRecoveryTimerController: moraleRecoveryTimerController,
      visible:
          visible ??
          (moraleMetricMode == FleetMoraleMetricMode.recoveryCountdown
              ? ({...defaultFields}
                  ..remove('minimum-condition')
                  ..add('recovery-countdown'))
              : defaultFields),
      shipTypeLabelMode: shipTypeLabelMode,
      clock: clock,
    ),
  ),
);

Widget _flatSummary(GameStateController controller, double width) =>
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: PanelStyleScope(
              style: PanelStyle.flat,
              child: FleetSummaryCard(
                controller: controller,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenFleet: (_) {},
                visible: defaultFields,
              ),
            ),
          ),
        ),
      ),
    );
