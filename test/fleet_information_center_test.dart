import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_status_views.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('renders the approved compact three-column fleet workspace', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1180,
            height: 720,
            child: FleetInformationCenter(controller: controller),
          ),
        ),
      ),
    );

    final roster = find.byKey(const Key('fleet-roster-panel'));
    final focus = find.byKey(const Key('fleet-focus-panel'));
    final detail = find.byKey(const Key('fleet-detail-panel'));
    expect(roster, findsOneWidget);
    expect(focus, findsOneWidget);
    expect(detail, findsOneWidget);
    expect(tester.getTopLeft(roster).dx, lessThan(tester.getTopLeft(focus).dx));
    expect(tester.getTopLeft(focus).dx, lessThan(tester.getTopLeft(detail).dx));

    final rosterShip = find.byKey(const Key('fleet-roster-ship-9001'));
    expect(rosterShip, findsOneWidget);
    final rosterDecoration = tester.widget<Container>(rosterShip).decoration;
    expect(rosterDecoration, isA<BoxDecoration>());
    expect(
      ((rosterDecoration! as BoxDecoration).border! as Border).top.width,
      4,
    );

    final focusShip = find.byKey(const Key('fleet-focus-ship-9001'));
    expect(focusShip, findsOneWidget);
    expect(tester.getSize(focusShip).height, lessThanOrEqualTo(72));
    final statusWidths = <double>[
      tester.getSize(find.byKey(const Key('fleet-focus-hp-track-9001'))).width,
      tester
          .getSize(find.byKey(const Key('fleet-focus-fuel-track-9001')))
          .width,
      tester
          .getSize(find.byKey(const Key('fleet-focus-ammo-track-9001')))
          .width,
    ];
    expect(statusWidths.toSet(), hasLength(1));

    expect(find.byKey(const Key('fleet-equipment-list')), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.textContaining('更新于'), findsNothing);
  });

  testWidgets('keeps all three fleet panels inside the compact viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(740, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 740,
            height: 360,
            child: FleetInformationCenter(controller: controller),
          ),
        ),
      ),
    );

    final rosterRect = tester.getRect(
      find.byKey(const Key('fleet-roster-panel')),
    );
    final focusRect = tester.getRect(
      find.byKey(const Key('fleet-focus-panel')),
    );
    final detailRect = tester.getRect(
      find.byKey(const Key('fleet-detail-panel')),
    );

    expect(rosterRect.left, greaterThanOrEqualTo(0));
    expect(rosterRect.right, lessThan(focusRect.left));
    expect(focusRect.right, lessThan(detailRect.left));
    expect(detailRect.right, lessThanOrEqualTo(740));
    expect(find.byType(Scrollable), findsWidgets);
    expect(
      tester
          .widgetList<Scrollable>(find.byType(Scrollable))
          .any((scrollable) => scrollable.axisDirection == AxisDirection.right),
      isFalse,
    );
  });

  testWidgets('aligns fleet title and fleet switches in one header row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    final titleRect = tester.getRect(find.text('舰队').first);
    final firstFleetRect = tester.getRect(
      find.byKey(const Key('fleet-button-1')),
    );
    expect(
      (titleRect.center.dy - firstFleetRect.center.dy).abs(),
      lessThanOrEqualTo(2),
    );
    expect(titleRect.left, lessThan(firstFleetRect.left));
  });

  testWidgets('uses the demo compact heights for fleet header and metrics', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('fleet-button-1'))).height, 32);
    expect(
      tester.getSize(find.byKey(const Key('fleet-los-metric'))).height,
      lessThanOrEqualTo(48),
    );
  });

  testWidgets('uses long 3 to 1 portrait capsules in the fleet roster', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(740, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    final capsule = tester.getSize(
      find.byKey(const Key('fleet-roster-ship-9001')),
    );
    expect(capsule.width / capsule.height, closeTo(3, 0.2));
    expect(find.text('全舰总览'), findsNothing);
    expect(find.text('2 艘'), findsNothing);
  });

  testWidgets('uses 30 dp fleet selectors on phone layouts', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('fleet-button-1'))).height, 30);
  });

  testWidgets('keeps healthy status values white while bars stay green', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    for (final type in <String>['hp', 'fuel', 'ammo']) {
      final value = tester.widget<Text>(
        find.byKey(Key('fleet-focus-$type-value-9001')),
      );
      expect(value.style?.color, Colors.white);
      final progress = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(Key('fleet-focus-$type-track-9001')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(progress.color, const Color(0xff29a634));
    }
  });

  testWidgets('shows three digit fuel and ammo values without truncation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final startEnvelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final startData =
        jsonDecode(jsonEncode(startEnvelope['api_data']))
            as Map<String, Object?>;
    final masterShips = startData['api_mst_ship']! as List<Object?>;
    (masterShips.first! as Map<String, Object?>)
      ..['api_fuel_max'] = 180
      ..['api_bull_max'] = 225;

    final portEnvelope =
        jsonDecode(portEvent.responseBody) as Map<String, Object?>;
    final portData =
        jsonDecode(jsonEncode(portEnvelope['api_data']))
            as Map<String, Object?>;
    final ownedShips = portData['api_ship']! as List<Object?>;
    (ownedShips.first! as Map<String, Object?>)
      ..['api_fuel'] = 58
      ..['api_bull'] = 67;

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
      ..accept(kcsapiEvent('/kcsapi/api_port/port', portData))
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    for (final type in <String>['fuel', 'ammo']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(Key('fleet-focus-$type-value-9001')),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(find.text('58/180'), findsOneWidget);
    expect(find.text('67/225'), findsOneWidget);
  });

  testWidgets('keeps a five dp gap between status icons and values', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    final icon = tester.getRect(
      find.byKey(const Key('fleet-focus-hp-icon-9001')),
    );
    final value = tester.getRect(
      find.byKey(const Key('fleet-focus-hp-value-9001')),
    );
    expect(value.left - icon.right, closeTo(5, 0.1));
  });

  testWidgets('uses the approved 2 by 3 fleet focus layout', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final envelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final data =
        jsonDecode(jsonEncode(envelope['api_data'])) as Map<String, Object?>;
    final ships = data['api_mst_ship']! as List<Object?>;
    (ships.first! as Map<String, Object?>)['api_name'] = '航空戦艦陸奥改二';
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', data))
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    final name = tester.widget<Text>(find.text('航空戦艦陸奥改二'));
    expect(name.style?.fontSize, 17);
    expect(name.overflow, isNot(TextOverflow.ellipsis));
    expect(
      tester.getSize(find.byKey(const Key('fleet-focus-portrait-9001'))),
      const Size(96, 42),
    );

    final hp = tester.getRect(
      find.byKey(const Key('fleet-focus-hp-track-9001')),
    );
    final fuel = tester.getRect(
      find.byKey(const Key('fleet-focus-fuel-track-9001')),
    );
    final ammo = tester.getRect(
      find.byKey(const Key('fleet-focus-ammo-track-9001')),
    );
    expect(fuel.left, lessThan(hp.left));
    expect(ammo.left, closeTo(hp.left, 1));
    expect(fuel.top, greaterThan(hp.top));
    expect(ammo.top, greaterThan(hp.top));
    expect(<double>{hp.width, fuel.width, ammo.width}, hasLength(1));
    expect(
      tester
          .getTopLeft(find.byKey(const Key('fleet-focus-meta-content-9001')))
          .dx,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('fleet-focus-hp-icon-9001'))).dx,
        1,
      ),
    );
  });

  testWidgets('fleet focus header has vertical slack on a real device scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1600, 760),
            textScaler: TextScaler.linear(1.1),
          ),
          child: Scaffold(body: FleetInformationCenter(controller: controller)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('removes redundant equipment section headings', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    expect(find.text('舰娘详情'), findsNothing);
    expect(find.text('全部装备'), findsNothing);
    await tester.tap(find.byKey(const Key('fleet-equipment-row-9001-0')));
    await tester.pumpAndSettle();
    expect(find.text('装备详情'), findsNothing);
    expect(
      find.byKey(const Key('fleet-detail-equipment-icon-9001-0')),
      findsOneWidget,
    );
  });

  testWidgets('switches the right panel between ship and equipment details', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    expect(find.text('舰娘详情'), findsNothing);
    expect(
      find.byKey(const Key('fleet-detail-equipment-icon-9001-0')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('fleet-equipment-row-9001-0')));
    await tester.pumpAndSettle();
    expect(find.text('装备详情'), findsNothing);
    expect(
      find.byKey(const Key('fleet-detail-equipment-icon-9001-0')),
      findsOneWidget,
    );

    await tester.tap(
      find
          .ancestor(
            of: find.byKey(const Key('fleet-focus-ship-9001')),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('舰娘详情'), findsNothing);

    await tester.tap(find.byKey(const Key('fleet-roster-ship-9002')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fleet-focus-ship-9002')), findsOneWidget);
  });

  testWidgets('ship detail panel keeps only the parameter grid', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    final detail = find.byKey(const Key('fleet-detail-panel'));
    expect(
      find.descendant(of: detail, matching: find.byType(ShipPortrait)),
      findsNothing,
    );
    expect(
      find.descendant(of: detail, matching: find.textContaining('Lv.')),
      findsNothing,
    );
    expect(
      find.descendant(of: detail, matching: find.text('耐久')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.text('运')),
      findsOneWidget,
    );
  });

  testWidgets('equipment detail hides provisional visible bonuses', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final envelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final data =
        jsonDecode(jsonEncode(envelope['api_data'])) as Map<String, Object?>;
    final ships = data['api_mst_ship']! as List<Object?>;
    (ships.first! as Map<String, Object?>)['api_name'] = '雪風改';
    final slotItems = data['api_mst_slotitem']! as List<Object?>;
    (slotItems.first! as Map<String, Object?>)
      ..['api_name'] = '12.7cm連装砲C型改二'
      ..['api_id'] = 266;
    final ownedEnvelope =
        jsonDecode(slotItemEvent.responseBody) as Map<String, Object?>;
    final ownedItems =
        jsonDecode(jsonEncode(ownedEnvelope['api_data'])) as List<Object?>;
    (ownedItems.first! as Map<String, Object?>)['api_slotitem_id'] = 266;
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', data))
      ..accept(portEvent)
      ..accept(kcsapiEvent('/kcsapi/api_get_member/slot_item', ownedItems));
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('fleet-equipment-row-9001-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fleet-equipment-bonus-0')), findsNothing);
  });

  testWidgets('renders static sparkle and redesigned fatigue face markers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final envelope = jsonDecode(portEvent.responseBody) as Map<String, Object?>;
    final data =
        jsonDecode(jsonEncode(envelope['api_data'])) as Map<String, Object?>;
    final ships = data['api_ship']! as List<Object?>;
    (ships[0]! as Map<String, Object?>)['api_cond'] = 60;
    (ships[1]! as Map<String, Object?>)
      ..['api_cond'] = 18
      ..['api_nowhp'] = 2;
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(kcsapiEvent('/kcsapi/api_port/port', data))
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    expect(find.byKey(const Key('fleet-morale-stars-60')), findsOneWidget);
    expect(find.byKey(const Key('fleet-fatigue-face-18')), findsOneWidget);
    final dangerCapsule = tester.widget<Container>(
      find.byKey(const Key('fleet-roster-ship-9002')),
    );
    final border =
        (dangerCapsule.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 4);
    expect(border.top.color, const Color(0xffd33d17));
  });

  testWidgets('fixed status pages do not render the old secondary tabs', (
    tester,
  ) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1180,
            height: 720,
            child: FleetInformationCenter(
              controller: controller,
              page: FleetInformationPage.expedition,
            ),
          ),
        ),
      ),
    );

    expect(find.text('远征'), findsOneWidget);
    expect(find.byKey(const Key('fleet-center-fleet-tab')), findsNothing);
    expect(find.byKey(const Key('fleet-center-expedition-tab')), findsNothing);
    expect(find.byKey(const Key('fleet-center-repair-tab')), findsNothing);
    expect(
      find.byKey(const Key('fleet-center-construction-tab')),
      findsNothing,
    );
  });

  testWidgets(
    'completed construction shows full progress and completion text',
    (tester) async {
      final state = GameState(
        masterShips: const <int, MasterShip>{
          101: MasterShip(id: 101, name: '多摩', shipTypeId: 2),
        },
        constructionDocks: <ConstructionDock>[
          ConstructionDock(
            id: 1,
            state: 3,
            createdShipMasterId: 101,
            fuel: 30,
            ammunition: 30,
            steel: 30,
            bauxite: 30,
            developmentMaterial: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1180,
              height: 720,
              child: ConstructionDockStatusView(state: state),
            ),
          ),
        ),
      );

      final progress = find.byKey(const Key('construction-progress-1'));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.descendant(
                of: progress,
                matching: find.byType(LinearProgressIndicator),
              ),
            )
            .value,
        1,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('建造完成'), findsOneWidget);
      expect(find.text('进度未知'), findsNothing);
    },
  );

  testWidgets('shows a real fleet and expands equipment details', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1180,
            height: 720,
            child: FleetInformationCenter(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('舰队'), findsOneWidget);
    expect(find.text('第一舰队'), findsOneWidget);
    expect(find.text('第二舰队'), findsOneWidget);
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('Lv. 50'), findsOneWidget);
    expect(find.text('12.7cm 连装炮'), findsNothing);
    expect(find.text('血量'), findsNothing);
    expect(find.text('燃料'), findsNothing);
    expect(find.text('弹药'), findsNothing);
    expect(find.text('活力 49'), findsNothing);
    expect(find.text('士气 49'), findsNothing);
    expect(find.text('疲劳 49'), findsOneWidget);
    expect(find.text('-25.63'), findsOneWidget);
    expect(find.text('40'), findsNothing);
    expect(find.byKey(const Key('ship-status-hp-icon-9001')), findsOneWidget);
    final hpIcon = tester.widget<Icon>(
      find.byKey(const Key('ship-status-hp-icon-9001')),
    );
    expect(hpIcon.icon, Icons.favorite_rounded);
    for (final type in <String>['fuel', 'ammo']) {
      final image = tester.widget<Image>(
        find.byKey(Key('ship-status-$type-icon-9001')),
      );
      final asset = image.image as AssetImage;
      expect(
        asset.assetName,
        type == 'fuel'
            ? 'assets/images/material/01.png'
            : 'assets/images/material/02.png',
      );
    }
    final portraitSize = tester.getSize(
      find.byKey(const Key('ship-portrait-9001')),
    );
    expect(portraitSize.width, inInclusiveRange(100, 180));
    expect(portraitSize.height, 54);
    expect(
      tester.getSize(find.byKey(const Key('ship-row-9001'))).height,
      lessThanOrEqualTo(76),
    );
    final hpPosition = tester.getTopLeft(
      find.byKey(const Key('ship-status-hp-9001')),
    );
    final fuelPosition = tester.getTopLeft(
      find.byKey(const Key('ship-status-fuel-9001')),
    );
    final ammoPosition = tester.getTopLeft(
      find.byKey(const Key('ship-status-ammo-9001')),
    );
    final identityTopCenter = tester.getCenter(
      find.byKey(const Key('ship-identity-top-9001')),
    );
    final fatigueCenter = tester.getCenter(
      find.byKey(const Key('ship-fatigue-9001')),
    );
    final supplyWarningCenter = tester.getCenter(
      find.byKey(const Key('ship-supply-warning-9001')),
    );
    final fuelCenter = tester.getCenter(
      find.byKey(const Key('ship-status-fuel-9001')),
    );
    final hpCenter = tester.getCenter(
      find.byKey(const Key('ship-status-hp-9001')),
    );
    final ammoCenter = tester.getCenter(
      find.byKey(const Key('ship-status-ammo-9001')),
    );
    expect(hpPosition.dx, lessThan(fuelPosition.dx));
    expect(fuelPosition.dx, ammoPosition.dx);
    expect(fuelPosition.dy, lessThan(ammoPosition.dy));
    expect((identityTopCenter.dy - fuelCenter.dy).abs(), lessThanOrEqualTo(2));
    expect((fatigueCenter.dy - fuelCenter.dy).abs(), lessThanOrEqualTo(2));
    expect(
      (supplyWarningCenter.dy - fuelCenter.dy).abs(),
      lessThanOrEqualTo(2),
    );
    expect((hpCenter.dy - ammoCenter.dy).abs(), lessThanOrEqualTo(2));
    final hpSize = tester.getSize(find.byKey(const Key('ship-status-hp-9001')));
    final statusColumnGap = ammoPosition.dx - (hpPosition.dx + hpSize.width);
    expect(statusColumnGap, inInclusiveRange(30, 40));

    await tester.tap(find.byKey(const Key('fleet-los-metric')));
    await tester.pumpAndSettle();
    expect(find.text('总索敌'), findsOneWidget);
    expect(find.text('33式'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('× 1'), findsOneWidget);
    expect(find.text('-25.63'), findsNWidgets(2));
    expect(find.text('× 2'), findsOneWidget);
    expect(find.text('-19.63'), findsOneWidget);
    expect(find.text('× 3'), findsOneWidget);
    expect(find.text('-13.63'), findsOneWidget);
    expect(find.text('× 4'), findsOneWidget);
    expect(find.text('-7.63'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    final shipName = tester.widget<Text>(find.text('夕張'));
    final shipLevel = tester.widget<Text>(find.text('Lv. 50'));
    final shipType = tester.widget<Text>(find.text('軽巡洋艦'));
    final identityTop = find.byKey(const Key('ship-identity-top-9001'));
    final shipSpeed = tester.widget<Text>(
      find.descendant(of: identityTop, matching: find.text('高速')),
    );
    final openingAsw = tester.widget<Text>(find.text('先制对潜'));
    final fatigue = tester.widget<Text>(find.text('疲劳 49'));
    expect(
      tester.getSize(find.byKey(const Key('ship-identity-9001'))).width,
      inInclusiveRange(108, 130),
    );
    expect(shipName.style?.fontSize, greaterThanOrEqualTo(18));
    for (final text in <Text>[shipLevel, shipType, shipSpeed, openingAsw]) {
      expect(text.style?.fontSize, 13);
      expect(
        text.style?.fontWeight?.value,
        greaterThanOrEqualTo(FontWeight.w600.value),
      );
    }
    expect(fatigue.style?.fontSize, 13);
    expect(
      fatigue.style?.fontWeight?.value,
      greaterThanOrEqualTo(FontWeight.w700.value),
    );
    final hpValue = tester.widget<Text>(
      find.byKey(const Key('ship-status-hp-value-9001')),
    );
    expect(hpValue.style?.fontSize, 14);
    expect(
      hpValue.style?.fontWeight?.value,
      greaterThanOrEqualTo(FontWeight.w700.value),
    );
    for (final text in <Text>[shipName, shipLevel, shipType]) {
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    final identityName = find.byKey(const Key('ship-identity-name-9001'));
    final identityNext = find.byKey(const Key('ship-identity-next-9001'));
    expect(
      find.descendant(of: identityTop, matching: find.text('高速')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: identityTop, matching: find.text('先制对潜')),
      findsOneWidget,
    );
    final levelPosition = tester.getTopLeft(
      find.descendant(of: identityTop, matching: find.text('Lv. 50')),
    );
    final typePosition = tester.getTopLeft(
      find.descendant(of: identityTop, matching: find.text('軽巡洋艦')),
    );
    final speedPosition = tester.getTopLeft(
      find.descendant(of: identityTop, matching: find.text('高速')),
    );
    final openingAswPosition = tester.getTopLeft(
      find.descendant(of: identityTop, matching: find.text('先制对潜')),
    );
    expect(levelPosition.dx, lessThan(typePosition.dx));
    expect(typePosition.dx, lessThan(speedPosition.dx));
    expect(speedPosition.dx, lessThan(openingAswPosition.dx));
    expect(
      tester.getTopLeft(identityTop).dy,
      lessThan(tester.getTopLeft(identityName).dy),
    );
    expect(
      tester.getTopLeft(identityName).dy,
      lessThan(tester.getTopLeft(identityNext).dy),
    );
    final healthArea = find.byKey(const Key('ship-health-area-9001'));
    final topStatusLine = find.byKey(const Key('ship-status-top-line-9001'));
    final bottomStatusLine = find.byKey(
      const Key('ship-status-bottom-line-9001'),
    );
    expect(
      find.descendant(of: topStatusLine, matching: find.text('疲劳 49')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: identityTop, matching: find.text('疲劳 49')),
      findsNothing,
    );
    final supplyWarning = find.byKey(const Key('ship-supply-warning-9001'));
    expect(
      find.descendant(of: topStatusLine, matching: supplyWarning),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(supplyWarning).dx,
      lessThan(tester.getTopLeft(find.text('疲劳 49')).dx),
    );
    expect(
      tester.getTopLeft(find.text('疲劳 49')).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('ship-status-hp-9001'))).dy,
      ),
    );
    expect(
      find.descendant(
        of: bottomStatusLine,
        matching: find.byKey(const Key('ship-status-hp-9001')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: topStatusLine,
        matching: find.byKey(const Key('ship-status-fuel-9001')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomStatusLine,
        matching: find.byKey(const Key('ship-status-ammo-9001')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: healthArea,
        matching: find.byKey(const Key('ship-status-hp-9001')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('夕張'));
    await tester.pumpAndSettle();

    expect(find.text('12.7cm 连装炮'), findsOneWidget);
    expect(find.byKey(const Key('equipment-card-9001-0')), findsOneWidget);
    expect(find.byKey(const Key('equipment-card-9001-1')), findsOneWidget);
    expect(find.byKey(const Key('equipment-card-9001-2')), findsOneWidget);
    expect(find.text('火力 +3'), findsOneWidget);
    expect(find.text('对空 +2'), findsOneWidget);
    expect(find.text('命中 +1'), findsOneWidget);
    expect(find.text('射程 短'), findsOneWidget);
    expect(find.text('改修 +4'), findsNothing);
    final improvement = find.byKey(const Key('equipment-improvement-9001-0'));
    expect(improvement, findsOneWidget);
    expect(
      find.descendant(
        of: improvement,
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: improvement, matching: find.text('4')),
      findsOneWidget,
    );
    final gunName = find.text('12.7cm 连装炮');
    expect(tester.getSize(gunName).width, lessThan(180));
    expect(
      tester.getTopLeft(improvement).dx - tester.getTopRight(gunName).dx,
      lessThanOrEqualTo(6),
    );
    expect(find.text('搭载 0'), findsNothing);
    expect(find.text('搭载'), findsNothing);

    final gunIcon = tester.widget<Image>(
      find.byKey(const Key('equipment-icon-9001-0')),
    );
    expect(
      (gunIcon.image as AssetImage).assetName,
      'assets/images/slotitem/1.png',
    );

    final aircraftIcon = tester.widget<Image>(
      find.byKey(const Key('equipment-icon-9001-1')),
    );
    expect(
      (aircraftIcon.image as AssetImage).assetName,
      'assets/images/slotitem/10.png',
    );
    final proficiency = find.byKey(const Key('equipment-proficiency-9001-1'));
    expect(proficiency, findsOneWidget);
    expect(
      (tester.widget<Image>(proficiency).image as AssetImage).assetName,
      'assets/images/airplane/alv6.png',
    );

    final aircraftOnSlot = find.byKey(const Key('equipment-onslot-9001-1'));
    expect(tester.getSize(aircraftOnSlot), const Size(30, 30));
    expect(
      find.descendant(of: aircraftOnSlot, matching: find.text('2')),
      findsOneWidget,
    );
    final aircraftSlotPosition = tester.getTopLeft(
      find.descendant(of: aircraftOnSlot, matching: find.text('2')),
    );
    final aircraftIconPosition = tester.getTopLeft(
      find.byKey(const Key('equipment-icon-9001-1')),
    );
    expect(aircraftSlotPosition.dx, lessThan(aircraftIconPosition.dx + 10));
    expect(aircraftSlotPosition.dy, lessThan(aircraftIconPosition.dy + 10));
    expect(find.byKey(const Key('equipment-onslot-9001-0')), findsNothing);
    final equipmentName = tester.widget<Text>(find.text('12.7cm 连装炮'));
    expect(equipmentName.maxLines, 1);
    expect(equipmentName.softWrap, isFalse);
    expect(equipmentName.overflow, TextOverflow.ellipsis);

    final firstCard = find.byKey(const Key('equipment-card-9001-0'));
    final secondCard = find.byKey(const Key('equipment-card-9001-1'));
    expect(tester.getTopLeft(firstCard).dy, tester.getTopLeft(secondCard).dy);
    expect(
      tester.getTopLeft(firstCard).dx,
      lessThan(tester.getTopLeft(secondCard).dx),
    );

    expect(find.byKey(const Key('equipment-mechanisms-9001')), findsNothing);
    expect(find.textContaining('可发动'), findsNothing);

    await tester.tap(
      find.descendant(of: identityTop, matching: find.text('先制对潜')),
    );
    await tester.pumpAndSettle();
    expect(find.text('先制对潜'), findsNWidgets(2));
    expect(find.textContaining('开幕雷击前'), findsOneWidget);
  }, skip: true);

  testWidgets('uses one equipment-card column on a narrow layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(340, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 820,
            height: 720,
            child: FleetInformationCenter(controller: controller),
          ),
        ),
      ),
    );

    await tester.tap(find.text('夕張'));
    await tester.pumpAndSettle();

    final firstCard = find.byKey(const Key('equipment-card-9001-0'));
    final secondCard = find.byKey(const Key('equipment-card-9001-1'));
    expect(tester.getTopLeft(firstCard).dx, tester.getTopLeft(secondCard).dx);
    expect(
      tester.getTopLeft(firstCard).dy,
      lessThan(tester.getTopLeft(secondCard).dy),
    );
  }, skip: true);

  testWidgets(
    'shows expedition repair and construction pages from real state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1180, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final readyController = GameStateController();
      final emptyController = GameStateController();
      addTearDown(readyController.dispose);
      addTearDown(emptyController.dispose);
      readyController
        ..accept(start2Event)
        ..accept(portEvent);
      await readyController.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1180,
              height: 720,
              child: FleetInformationCenter(controller: readyController),
            ),
          ),
        ),
      );

      const fleetPortraitSize = Size(180, 54);
      const fleetCapsuleHeight = 76.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1180,
              height: 720,
              child: FleetInformationCenter(
                controller: readyController,
                page: FleetInformationPage.expedition,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('expedition-row-2')), findsOneWidget);
      expect(find.byKey(const Key('expedition-portrait-2')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('expedition-portrait-2'))),
        fleetPortraitSize,
      );
      expect(
        tester.getSize(find.byKey(const Key('expedition-row-2'))).height,
        fleetCapsuleHeight,
      );
      expect(find.text('海上護衛任務'), findsOneWidget);
      expect(find.textContaining('%'), findsWidgets);
      expect(find.text('预计'), findsNothing);
      expect(find.textContaining('资料待更新'), findsNothing);
      expect(find.text('6 艘'), findsNothing);
      expect(find.textContaining('旗舰：'), findsNothing);
      for (final type in <String>['fuel', 'ammo', 'steel', 'bauxite']) {
        expect(find.byKey(Key('expedition-resource-2-$type')), findsNothing);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1180,
              height: 720,
              child: FleetInformationCenter(
                controller: readyController,
                page: FleetInformationPage.repair,
              ),
            ),
          ),
        ),
      );

      for (var id = 1; id <= 4; id++) {
        expect(find.byKey(Key('repair-dock-row-$id')), findsOneWidget);
      }
      expect(find.text('未入渠'), findsOneWidget);
      expect(find.text('未解锁'), findsOneWidget);
      expect(find.text('吹雪'), findsOneWidget);
      expect(find.textContaining('修理进度'), findsWidgets);
      expect(find.byKey(const Key('repair-progress-1')), findsOneWidget);
      expect(find.byKey(const Key('repair-hp-1')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('repair-portrait-1'))),
        fleetPortraitSize,
      );
      expect(
        tester.getSize(find.byKey(const Key('repair-dock-row-1'))).height,
        fleetCapsuleHeight,
      );
      final repairHp = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('repair-hp-1')),
          matching: find.byType(Text),
        ),
      );
      expect(repairHp.style?.fontSize, greaterThanOrEqualTo(16));
      final fuelCost = tester.widget<Image>(
        find.byKey(const Key('repair-resource-1-fuel')),
      );
      final steelCost = tester.widget<Image>(
        find.byKey(const Key('repair-resource-1-steel')),
      );
      expect(
        (fuelCost.image as AssetImage).assetName,
        'assets/images/material/01.png',
      );
      expect(
        (steelCost.image as AssetImage).assetName,
        'assets/images/material/03.png',
      );
      final hpRight = tester.getTopRight(find.byKey(const Key('repair-hp-1')));
      final progressLeft = tester.getTopLeft(
        find.byKey(const Key('repair-progress-1')),
      );
      expect(progressLeft.dx - hpRight.dx, greaterThanOrEqualTo(16));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1180,
              height: 720,
              child: FleetInformationCenter(
                controller: readyController,
                page: FleetInformationPage.construction,
              ),
            ),
          ),
        ),
      );

      for (var id = 1; id <= 4; id++) {
        expect(find.byKey(Key('construction-dock-row-$id')), findsOneWidget);
      }
      expect(find.text('未建造'), findsOneWidget);
      expect(find.text('未解锁'), findsOneWidget);
      expect(find.text('夕張'), findsOneWidget);
      expect(find.text('常规建造'), findsOneWidget);
      expect(find.text('大型建造'), findsOneWidget);
      expect(find.text('结果已知'), findsNothing);
      expect(find.text('高速建造可完成'), findsNothing);
      expect(find.textContaining('第1建造'), findsNothing);
      final constructionProgress = find.byKey(
        const Key('construction-progress-1'),
      );
      expect(constructionProgress, findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.descendant(
                of: constructionProgress,
                matching: find.byType(LinearProgressIndicator),
              ),
            )
            .value,
        isNotNull,
      );
      expect(
        find.descendant(
          of: constructionProgress,
          matching: find.textContaining('%'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('construction-portrait-1'))),
        fleetPortraitSize,
      );
      expect(
        tester.getSize(find.byKey(const Key('construction-dock-row-1'))).height,
        fleetCapsuleHeight,
      );
      for (final type in <String>[
        'fuel',
        'ammo',
        'steel',
        'bauxite',
        'development',
      ]) {
        final image = tester.widget<Image>(
          find.byKey(Key('construction-resource-1-$type')),
        );
        expect(image.image, isA<AssetImage>());
      }

      await tester.pumpWidget(
        MaterialApp(home: FleetInformationCenter(controller: emptyController)),
      );

      expect(find.text('等待母港数据'), findsOneWidget);
    },
  );

  testWidgets('keeps operation cards usable on a narrow landscape layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );

    for (final page in <FleetInformationPage>[
      FleetInformationPage.expedition,
      FleetInformationPage.repair,
      FleetInformationPage.construction,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetInformationCenter(controller: controller, page: page),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('横屏左右摄像头位置不会改变舰娘头像的卡片内起点', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    Future<double> portraitInset(EdgeInsets padding) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(900, 400),
              padding: padding,
              viewPadding: padding,
            ),
            child: Scaffold(
              body: FleetInformationCenter(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rowLeft = tester
          .getTopLeft(find.byKey(const Key('ship-row-9001')))
          .dx;
      final portraitLeft = tester
          .getTopLeft(find.byKey(const Key('ship-portrait-9001')))
          .dx;
      return portraitLeft - rowLeft;
    }

    final leftCameraInset = await portraitInset(
      const EdgeInsets.only(left: 48),
    );
    final rightCameraInset = await portraitInset(
      const EdgeInsets.only(right: 48),
    );

    expect(leftCameraInset, closeTo(rightCameraInset, 0.01));
    expect(
      tester.getSize(find.byKey(const Key('ship-portrait-9001'))).width,
      144,
    );
  }, skip: true);

  testWidgets('正方形折叠屏复用手机舰娘卡且忽略列表顶部安全区', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 1024);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1024, 1024),
            padding: EdgeInsets.only(top: 48),
            viewPadding: EdgeInsets.only(top: 48),
          ),
          child: Scaffold(body: FleetInformationCenter(controller: controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ship-identity-top-9001')), findsOneWidget);
    final metricsBottom = tester
        .getBottomRight(find.byKey(const Key('fleet-los-metric')))
        .dy;
    final firstShipTop = tester
        .getTopLeft(find.byKey(const Key('ship-row-9001')))
        .dy;
    expect(firstShipTop - metricsBottom, closeTo(10, 1));
    expect(find.text('平均疲劳'), findsOneWidget);

    final firstFleet = find.byKey(const Key('fleet-button-1'));
    final firstNameCell = find.descendant(
      of: firstFleet,
      matching: find.byKey(const Key('fleet-name-cell-1')),
    );
    final firstStatusCell = find.descendant(
      of: firstFleet,
      matching: find.byKey(const Key('fleet-status-cell-1')),
    );
    expect(
      tester.getSize(firstNameCell).width,
      closeTo(tester.getSize(firstStatusCell).width, 1),
    );
    expect(
      tester
          .getCenter(
            find.descendant(of: firstNameCell, matching: find.byType(Text)),
          )
          .dx,
      closeTo(tester.getCenter(firstNameCell).dx, 1),
    );
    final standby = tester.widget<Text>(
      find.descendant(of: firstStatusCell, matching: find.text('母港待命')),
    );
    final returned = tester.widget<Text>(find.text('已返母港'));
    expect(standby.style?.color, Colors.white);
    expect(returned.style?.color, Colors.white);
    final standbyDot = find.byKey(const Key('fleet-selector-status-dot-1'));
    expect(tester.getSize(standbyDot), const Size.square(7));
    expect(
      (tester.widget<Container>(standbyDot).decoration as BoxDecoration?)
          ?.color,
      const Color(0xff29a634),
    );
    expect(find.textContaining('·'), findsNothing);
    expect(find.textContaining('艘'), findsNothing);
  }, skip: true);

  testWidgets('平板竖屏复用方形折叠屏舰娘卡并以两列显示装备', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1280);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FleetInformationCenter(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ship-identity-9001')), findsNothing);
    final shipRow = tester.getRect(find.byKey(const Key('ship-row-9001')));
    for (final type in <String>['fuel', 'ammo']) {
      final bar = tester.getRect(find.byKey(Key('ship-status-$type-9001')));
      expect(bar.right, lessThanOrEqualTo(shipRow.right));
      expect(bar.width, greaterThan(8));
    }

    await tester.tap(find.text('夕張'));
    await tester.pumpAndSettle();

    final firstCard = find.byKey(const Key('equipment-card-9001-0'));
    final secondCard = find.byKey(const Key('equipment-card-9001-1'));
    expect(tester.getTopLeft(firstCard).dy, tester.getTopLeft(secondCard).dy);
    expect(
      tester.getTopLeft(firstCard).dx,
      lessThan(tester.getTopLeft(secondCard).dx),
    );
    expect(tester.takeException(), isNull);
  }, skip: true);

  testWidgets('opens fleet center with the requested fleet selected', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1180,
            height: 720,
            child: FleetInformationCenter(
              controller: controller,
              initialFleetId: 2,
            ),
          ),
        ),
      ),
    );

    Material selectedMaterial(Key key) => tester.widget<Material>(
      find
          .descendant(of: find.byKey(key), matching: find.byType(Material))
          .first,
    );
    expect(
      selectedMaterial(const Key('fleet-button-2')).color,
      const Color(0xff3a3020),
    );
    expect(
      selectedMaterial(const Key('fleet-button-1')).color,
      const Color(0xff102331),
    );
  });

  testWidgets('手机竖屏下舰队、入渠、建造页面无溢出', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    for (final page in <FleetInformationPage>[
      FleetInformationPage.fleet,
      FleetInformationPage.repair,
      FleetInformationPage.construction,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 412,
              height: 915,
              child: FleetInformationCenter(controller: controller, page: page),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('手机竖屏舰娘卡 HP、燃料、弹药三条完整可见', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 412,
            height: 915,
            child: FleetInformationCenter(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final keyName in <String>['hp', 'fuel', 'ammo']) {
      final bar = find.byKey(Key('ship-status-$keyName-9001'));
      expect(bar, findsOneWidget);
      final rect = tester.getRect(bar);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(412));
      expect(rect.width, greaterThan(8));
    }
    final hpWidth = tester
        .getSize(find.byKey(const Key('ship-status-hp-9001')))
        .width;
    final fuelWidth = tester
        .getSize(find.byKey(const Key('ship-status-fuel-9001')))
        .width;
    expect(hpWidth / fuelWidth, closeTo(1.3, 0.08));
    final nameRight = tester
        .getTopRight(find.byKey(const Key('ship-identity-name-9001')))
        .dx;
    final lvLeft = tester.getTopLeft(find.text('Lv. 50')).dx;
    expect(lvLeft - nameRight, greaterThanOrEqualTo(30));

    final statusValues = <Finder>[
      find.text('Lv. 50'),
      find.byKey(const Key('ship-status-hp-value-9001')),
      find.byKey(const Key('ship-status-fuel-value-9001')),
      find.byKey(const Key('ship-status-ammo-value-9001')),
    ];
    for (final value in statusValues) {
      final text = tester.widget<Text>(value);
      expect(text.style?.fontSize, 10);
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(
        find.ancestor(of: value, matching: find.byType(FittedBox)),
        findsNothing,
      );
    }
    final hpText = tester.widget<Text>(
      find.byKey(const Key('ship-status-hp-value-9001')),
    );
    expect(hpText.style?.color, Colors.white);
    final hpBar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('ship-status-hp-9001')),
    );
    expect(hpBar.color, const Color(0xff29a634));
    expect(tester.takeException(), isNull);
  }, skip: true);
}
