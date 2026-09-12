import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_page.dart';
import 'package:yahagi_kancolle_browser/src/inventory/owned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/inventory/unowned_inventory_projection.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  setUp(() => GameStateController.disableTimerForTest = true);

  testWidgets(
    'account change closes an owned ship drawer even before matching instance IDs refresh',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      AccountSession.shared.selectMember(1001);
      final controller = await _equipmentCompatibilityController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );
      await tester.tap(find.byKey(const Key('owned-ship-name-row-9001')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ship-equipment-compatibility-drawer')),
        findsOneWidget,
      );
      AccountSession.shared.selectMember(2002);
      await tester.pump();
      expect(
        find.byKey(const Key('ship-equipment-compatibility-drawer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'unowned ship cards are flat and exclusions follow the active filter',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(
          kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
            'api_basic': <String, Object?>{'api_member_id': 1001},
            'api_ship': <Object?>[],
          }),
        );
      await controller.idle;
      final reminderController = NewShipReminderController(
        stateProvider: () => controller.state,
        store: NewShipReminderStore(await SharedPreferences.getInstance()),
        onPublish: (_) {},
      );
      addTearDown(reminderController.dispose);
      await reminderController.setFamilyExcluded(101, true);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(
            body: OwnedInventoryPage(
              controller: controller,
              reminderController: reminderController,
              showOwned: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('unowned-ship-summary')), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      final excludedCount = find.byKey(
        const Key('unowned-ship-excluded-count'),
      );
      expect(excludedCount, findsOneWidget);
      expect(tester.widget<Text>(excludedCount).data, '1');
      expect(
        tester.widget<Text>(excludedCount).style?.color,
        const Color(0xffffc85a),
      );
      final clearExclusions = find.byKey(
        const Key('unowned-ship-clear-exclusions'),
      );
      expect(clearExclusions, findsOneWidget);
      final clearIcon = find.descendant(
        of: clearExclusions,
        matching: find.byIcon(Icons.restore),
      );
      expect(clearIcon, findsOneWidget);
      expect(tester.widget<Icon>(clearIcon).size, 19);
      expect(tester.widget<Icon>(clearIcon).color, const Color(0xffffc85a));
      expect(tester.getSize(clearExclusions), const Size(34, 28));
      expect(
        tester
            .widget<Tooltip>(
              find.descendant(
                of: clearExclusions,
                matching: find.byType(Tooltip),
              ),
            )
            .message,
        '清除排除',
      );
      expect(find.text('清除排除'), findsNothing);
      expect(
        tester.getTopLeft(clearExclusions).dx,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const Key('unowned-ship-filter-result-count')),
              )
              .dx,
        ),
      );

      await tester.tap(find.byKey(const Key('unowned-ship-filter-cl')));
      await tester.pump();
      expect(tester.widget<Text>(excludedCount).data, '0');

      await tester.tap(find.byKey(const Key('unowned-ship-filter-dd')));
      await tester.pump();
      expect(tester.widget<Text>(excludedCount).data, '1');

      await tester.tap(clearExclusions);
      await tester.pump();
      expect(reminderController.excludedFamilyIds, isEmpty);
      expect(tester.widget<Text>(excludedCount).data, '0');
      expect(clearExclusions, findsOneWidget);
    },
  );

  testWidgets('explains unowned ship reminder exclusions below the filter', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(520, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(controller: controller, showOwned: false),
        ),
      ),
    );

    final hint = find.byKey(const Key('unowned-ship-reminder-hint'));
    expect(hint, findsOneWidget);
    final hintText = tester.widget<Text>(hint);
    expect(hintText.data, '获得未勾选的舰娘时，将正常提醒并震动；勾选的舰娘则不会提醒。');
    expect(hintText.style?.fontSize, 12);
    expect(hintText.style?.color, const Color(0xff8ba2af));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();
    expect(hint, findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    expect(hint, findsNothing);
  });

  testWidgets('unowned views reuse filters and remember each category', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(portEvent);
    await controller.idle;
    final projection = UnownedInventoryProjection(controller.state);
    final ddCount = projection
        .unownedShipFamiliesFor(category: ShipInventoryCategory.dd)
        .length;
    final unownedEquipmentRows = projection.unownedEquipment;
    final mainGunRows = projection.unownedEquipmentFor(
      category: EquipmentInventoryCategory.mainGun,
    );
    final mainGunCount = mainGunRows.length;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(controller: controller, showOwned: false),
        ),
      ),
    );

    expect(find.byKey(const Key('unowned-ship-filter-all')), findsOneWidget);
    expect(find.byKey(const Key('unowned-ship-filter-dd')), findsOneWidget);
    for (final key in <String>['bbBc', 'cv', 'cvl']) {
      expect(find.byKey(Key('unowned-ship-filter-$key')), findsOneWidget);
    }
    expect(find.byKey(const Key('unowned-ship-filter-cvCvl')), findsNothing);
    final unownedCapitalFilterX = <double>[
      tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-bbBc'))).dx,
      tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-cv'))).dx,
      tester.getTopLeft(find.byKey(const Key('unowned-ship-filter-cvl'))).dx,
    ];
    expect(unownedCapitalFilterX[0], lessThan(unownedCapitalFilterX[1]));
    expect(unownedCapitalFilterX[1], lessThan(unownedCapitalFilterX[2]));
    await tester.tap(find.byKey(const Key('unowned-ship-filter-dd')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('unowned-ship-filter-result-count')),
          )
          .data,
      '$ddCount',
    );

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();
    expect(
      find.byKey(const Key('unowned-equipment-filter-all')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unowned-equipment-summary')), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);
    final equipmentCardKeys = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              RegExp(
                r'^unowned-equipment-\d+$',
              ).hasMatch((widget.key! as ValueKey<String>).value),
        )
        .evaluate()
        .map((element) => (element.widget.key! as ValueKey<String>).value)
        .toList();
    expect(
      equipmentCardKeys,
      unownedEquipmentRows
          .map((row) => 'unowned-equipment-${row.master.id}')
          .toList(),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('unowned-equipment-filter-mainGun')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('unowned-equipment-filter-result-count')),
          )
          .data,
      '$mainGunCount',
    );
    final resetEquipmentFilter = find.byKey(
      const Key('unowned-equipment-filter-reset'),
    );
    expect(resetEquipmentFilter, findsOneWidget);
    final resetEquipmentIcon = find.descendant(
      of: resetEquipmentFilter,
      matching: find.byIcon(Icons.restore),
    );
    expect(resetEquipmentIcon, findsOneWidget);
    expect(tester.widget<Icon>(resetEquipmentIcon).size, 19);
    expect(
      tester.widget<Icon>(resetEquipmentIcon).color,
      const Color(0xffffc85a),
    );
    expect(tester.getSize(resetEquipmentFilter), const Size(34, 28));
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(
              of: resetEquipmentFilter,
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      '重置筛选',
    );
    expect(
      tester.getTopLeft(resetEquipmentFilter).dx,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(const Key('unowned-equipment-filter-result-count')),
            )
            .dx,
      ),
    );
    await tester.tap(resetEquipmentFilter);
    await tester.pump();
    final allLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('unowned-equipment-filter-all')),
        matching: find.text('全部'),
      ),
    );
    expect(allLabel.style?.color, const Color(0xffffcf62));
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('unowned-equipment-filter-result-count')),
          )
          .data,
      '${unownedEquipmentRows.length}',
    );

    await tester.tap(find.byKey(const Key('owned-inventory-tab-ships')));
    await tester.pump();
    final ddLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('unowned-ship-filter-dd')),
        matching: find.text('DD'),
      ),
    );
    expect(ddLabel.style?.color, const Color(0xffffcf62));
  });

  testWidgets('matches the confirmed compact ship and equipment controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    expect(find.byKey(const Key('owned-inventory-segmented')), findsOneWidget);
    expect(find.text('舰娘 0'), findsOneWidget);
    expect(find.text('装备 0'), findsOneWidget);
    expect(find.byKey(const Key('ship-filter-all')), findsOneWidget);
    for (final key in <String>['bbBc', 'cv', 'cvl']) {
      expect(find.byKey(Key('ship-filter-$key')), findsOneWidget);
    }
    expect(find.byKey(const Key('ship-filter-cvCvl')), findsNothing);
    final ownedCapitalFilterX = <double>[
      tester.getTopLeft(find.byKey(const Key('ship-filter-bbBc'))).dx,
      tester.getTopLeft(find.byKey(const Key('ship-filter-cv'))).dx,
      tester.getTopLeft(find.byKey(const Key('ship-filter-cvl'))).dx,
    ];
    expect(ownedCapitalFilterX[0], lessThan(ownedCapitalFilterX[1]));
    expect(ownedCapitalFilterX[1], lessThan(ownedCapitalFilterX[2]));
    expect(find.text('筛选结果 '), findsOneWidget);
    expect(find.byKey(const Key('ship-table-frozen-header')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('装备 0'));
    await tester.pump();

    expect(find.byKey(const Key('equipment-filter-all')), findsOneWidget);
    expect(find.byKey(const Key('equipment-filter-support')), findsOneWidget);
    expect(
      find.byKey(const Key('owned-inventory-equipment-sort-name')),
      findsOneWidget,
    );
    expect(find.text('总数（剩余）'), findsOneWidget);
    expect(find.text('改修／熟练度'), findsOneWidget);
    expect(find.text('着装情况'), findsOneWidget);
    expect(find.text('官方ID'), findsOneWidget);
    expect(find.text('实例ID'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section control uses the Poi equipment capacity count', (
    tester,
  ) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller.accept(start2Event);
    controller.accept(portEvent);
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
        <String, Object?>{'api_id': 1, 'api_slotitem_id': 201},
        <String, Object?>{'api_id': 2, 'api_slotitem_id': 42},
      ]),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    expect(find.text('装备 1'), findsOneWidget);
  });

  testWidgets('equipment remains grouped and ends with only official id', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
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
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-equipment')),
    );
    expect(
      table.scrollableHeaders.last.key,
      const Key('owned-inventory-equipment-sort-officialId'),
    );
    expect(table.rowHeights, hasLength(3));

    final masterId = tester.widget<SelectableText>(
      find.byKey(const Key('equipment-master-id-201')),
    );
    expect(masterId.data, '201');
    expect(find.byKey(const Key('equipment-instance-id-7001')), findsNothing);
    expect(find.textContaining('12.7cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('持有舰娘打开可装备装备抽屉', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = await _equipmentCompatibilityController(
      includeUnownedEquipment: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final row = find.byKey(const Key('owned-ship-name-row-9001'));
    expect(row, findsOneWidget);
    expect(tester.widget<Semantics>(row).properties.selected, isFalse);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(row).properties.selected, isTrue);

    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsOneWidget,
    );
    expect(find.text('夕張'), findsWidgets);
    expect(find.textContaining('Lv.98'), findsOneWidget);

    await tester.tap(find.byKey(const Key('owned-ship-name-row-9003')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lv.76'), findsOneWidget);
    expect(find.textContaining('Lv.98'), findsNothing);

    await tester.tap(
      find.byKey(const Key('ship-equipment-compatibility-close')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );
  });

  testWidgets('未持有舰娘卡片打开抽屉且复选框只切换排除', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _equipmentCompatibilityController();
    addTearDown(controller.dispose);
    final reminderController = NewShipReminderController(
      stateProvider: () => controller.state,
      store: NewShipReminderStore(await SharedPreferences.getInstance()),
      onPublish: (_) {},
    );
    addTearDown(reminderController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(
            controller: controller,
            reminderController: reminderController,
            showOwned: false,
          ),
        ),
      ),
    );

    final card = find.byKey(const Key('unowned-ship-103'));
    expect(card, findsOneWidget);
    final checkbox = find.descendant(of: card, matching: find.byType(Checkbox));
    await tester.tap(checkbox);
    await tester.pump();
    expect(reminderController.excludedFamilyIds, contains(103));
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(card);
    await tester.pumpAndSettle();
    final drawer = find.byKey(const Key('ship-equipment-compatibility-drawer'));
    expect(drawer, findsOneWidget);
    expect(
      find.descendant(of: drawer, matching: find.text('白雪')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: drawer, matching: find.textContaining('Lv.')),
      findsNothing,
    );
  });

  testWidgets('舰娘抽屉在切换范围及选中对象失效时关闭', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _equipmentCompatibilityController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-ship-name-row-9001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('owned-inventory-tab-unowned')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('unowned-ship-103')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('owned-inventory-tab-ships')));
    await tester.tap(find.byKey(const Key('owned-inventory-tab-owned')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('owned-ship-name-row-9001')));
    await tester.pumpAndSettle();
    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_port/port',
        _compatibilityPortData(
          ships: _compatibilityPortShips()
              .where((ship) => ship['api_id'] != 9001)
              .toList(),
        ),
      ),
    );
    await controller.idle;
    await tester.pump();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );
  });

  testWidgets('未持有舰娘变为持有时卡片与抽屉关闭', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _equipmentCompatibilityController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(controller: controller, showOwned: false),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('unowned-ship-103')));
    await tester.pumpAndSettle();
    final ships = _compatibilityPortShips()
      ..add(<String, Object?>{
        ..._compatibilityPortShips().first,
        'api_id': 9010,
        'api_ship_id': 103,
        'api_lv': 1,
      });
    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_port/port',
        _compatibilityPortData(ships: ships),
      ),
    );
    await controller.idle;
    await tester.pump();

    expect(find.byKey(const Key('unowned-ship-103')), findsNothing);
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );
  });

  testWidgets('舰娘抽屉在装备状态更新后保持打开并刷新', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _equipmentCompatibilityController(
      includeUnownedEquipment: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-ship-name-row-9001')));
    await tester.pumpAndSettle();
    final existingItems =
        jsonDecode(slotItemEvent.responseBody)['api_data']! as List<Object?>;
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
        ...existingItems,
        <String, Object?>{
          'api_id': 7999,
          'api_slotitem_id': 201,
          'api_level': 0,
          'api_alv': 0,
        },
      ]),
    );
    await controller.idle;
    await tester.pump();

    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsOneWidget,
    );
    final count = find.byKey(
      const Key('ship-equipment-compatibility-owned-count-201'),
    );
    expect(
      find.descendant(of: count, matching: find.text('持有 X3')),
      findsOneWidget,
    );
  });

  testWidgets('舰娘抽屉在仅装备类型名称更新时保持打开并刷新', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final sourceController = await _equipmentCompatibilityController(
      includeUnownedEquipment: true,
    );
    final reducer = _MutableInventoryReducer(sourceController.state);
    final controller = GameStateController(reducer: reducer);
    addTearDown(sourceController.dispose);
    addTearDown(controller.dispose);
    controller.accept(
      kcsapiEvent('/test/inventory-state', const <String, Object?>{}),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-ship-name-row-9001')));
    await tester.pumpAndSettle();
    expect(find.text('小口径主炮'), findsOneWidget);

    reducer.nextState = controller.state.copyWith(
      masterSlotItemTypes: <int, String>{
        ...controller.state.masterSlotItemTypes,
        1: '更新后主炮类型',
      },
    );
    controller.accept(
      kcsapiEvent('/test/inventory-state', const <String, Object?>{}),
    );
    await controller.idle;
    await tester.pump();

    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsOneWidget,
    );
    expect(find.text('更新后主炮类型'), findsOneWidget);
    expect(find.text('小口径主炮'), findsNothing);
  });

  testWidgets('受控范围更新与 controller 替换遵守舰娘选择有效性', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final firstController = await _equipmentCompatibilityController();
    final replacementController = GameStateController();
    addTearDown(firstController.dispose);
    addTearDown(replacementController.dispose);
    var activeController = firstController;
    var showOwned = true;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return OwnedInventoryPage(
                controller: activeController,
                showOwned: showOwned,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-ship-name-row-9001')));
    await tester.pumpAndSettle();
    rebuild(() => showOwned = false);
    await tester.pump();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('unowned-ship-103')));
    await tester.pumpAndSettle();
    rebuild(() => activeController = replacementController);
    await tester.pump();
    expect(
      find.byKey(const Key('ship-equipment-compatibility-drawer')),
      findsNothing,
    );
  });

  testWidgets(
    'equipment row opens, replaces, and closes compatibility drawer',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = await _equipmentCompatibilityController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );
      await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('equipment-name-row-201')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('equipment-compatibility-drawer')),
        findsOneWidget,
      );
      expect(find.text('12.7cm 连装炮'), findsWidgets);
      expect(find.text('装备 ID 201'), findsNothing);
      expect(find.textContaining('可装备：持有'), findsNothing);
      expect(find.text('分类：主炮'), findsNothing);
      expect(find.text('持有数 2'), findsNothing);
      expect(find.text('普通槽 3'), findsNothing);
      expect(find.text('增设栏 1'), findsNothing);
      expect(find.text('规则来源：游戏官方主数据'), findsNothing);
      expect(
        find.byKey(const Key('equipment-compatibility-search')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-type-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-search-button')),
        findsOneWidget,
      );
      expect(find.textContaining('舰级 #'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('equipment-compatibility-ship-101')),
          matching: find.text('軽巡洋艦 · Lv.98 / 76 / 45'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-tab-owned')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-tab-all')),
        findsOneWidget,
      );
      expect(find.text('普通槽＋增设栏'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('equipment-compatibility-ship-102')),
          matching: find.text('普通槽'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('★+4'), findsOneWidget);
      expect(find.textContaining('第 1、2 舰队'), findsOneWidget);

      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_hensei/change',
          null,
          includeApiData: false,
          requestParams: const <String, Object?>{
            'api_id': '1',
            'api_ship_idx': '1',
            'api_ship_id': '-1',
          },
        ),
      );
      await controller.idle;
      await tester.pump();
      expect(find.textContaining('第 2 舰队'), findsOneWidget);
      expect(find.textContaining('第 1、2 舰队'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('equipment-compatibility-drawer')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('equipment-name-row-201')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('equipment-name-row-202')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('equipment-compatibility-drawer')),
        findsOneWidget,
      );
      expect(find.text('零式水上侦察机'), findsWidgets);

      await tester.tap(find.byKey(const Key('equipment-compatibility-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('equipment-compatibility-drawer')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('equipment-name-row-201')));
      await tester.pumpAndSettle();
      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_req_kousyou/destroyitem2',
          const <String, Object?>{},
          requestParams: const <String, Object?>{
            'api_slotitem_ids': '7001,7003',
          },
        ),
      );
      await controller.idle;
      await tester.pump();
      expect(
        find.byKey(const Key('equipment-compatibility-drawer')),
        findsNothing,
      );
    },
  );

  testWidgets('未持有装备复用装备适配抽屉', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = await _equipmentCompatibilityController(
      includeUnownedEquipment: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-unowned')));
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('unowned-equipment-204')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('equipment-compatibility-drawer')),
      findsOneWidget,
    );
    expect(find.text('12.7cm 连装炮二型'), findsWidgets);
    expect(
      find.byKey(const Key('equipment-compatibility-tab-owned')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('equipment-compatibility-tab-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('equipment-compatibility-ship-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('equipment-compatibility-ship-103')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('equipment-compatibility-tab-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('equipment-compatibility-ship-103')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('unowned-equipment-205')));
    await tester.pumpAndSettle();
    expect(find.text('零式水上侦察机二型'), findsWidgets);

    await tester.tap(find.byKey(const Key('equipment-compatibility-close')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('unowned-equipment-204')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('owned-inventory-tab-owned')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('owned-inventory-tab-unowned')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('unowned-equipment-204')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('owned-inventory-tab-ships')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('equipment-compatibility-drawer')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('unowned-equipment-204')));
    await tester.pumpAndSettle();

    final existingItems =
        jsonDecode(slotItemEvent.responseBody)['api_data']! as List<Object?>;
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
        ...existingItems,
        <String, Object?>{
          'api_id': 7005,
          'api_slotitem_id': 204,
          'api_level': 0,
          'api_alv': 0,
        },
      ]),
    );
    await controller.idle;
    await tester.pump();

    expect(
      find.byKey(const Key('equipment-compatibility-drawer')),
      findsNothing,
    );
    expect(find.byKey(const Key('unowned-equipment-204')), findsNothing);
  });

  testWidgets(
    '装备适配抽屉 compatibility drawer uses compact tools and fixed ship categories',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = await _equipmentCompatibilityController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(
            body: OwnedInventoryPage(
              controller: controller,
              showShips: false,
              showSectionControl: false,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('equipment-name-row-201')));
      await tester.pumpAndSettle();

      final drawer = find.byKey(const Key('equipment-compatibility-drawer'));
      expect(drawer, findsOneWidget);
      expect(tester.getSize(drawer).width, lessThanOrEqualTo(340));
      expect(
        tester
            .getSize(
              find.byKey(const Key('equipment-compatibility-scope-tabs')),
            )
            .height,
        32,
      );
      expect(find.text('持有 2'), findsOneWidget);
      expect(find.text('全部 4'), findsOneWidget);
      expect(find.textContaining('持有舰娘'), findsNothing);
      expect(find.textContaining('全部舰娘'), findsNothing);
      Semantics explicitSemantics(Key key, String label) =>
          tester.widget<Semantics>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.label == label,
              ),
            ),
          );
      expect(
        explicitSemantics(
          const Key('equipment-compatibility-tab-owned'),
          '持有 2',
        ).properties,
        isA<SemanticsProperties>()
            .having((value) => value.button, 'button', isTrue)
            .having((value) => value.selected, 'selected', isTrue)
            .having((value) => value.label, 'label', '持有 2'),
      );
      IconButton toolButton(Key key) => tester.widget<IconButton>(
        find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
      );
      expect(find.byTooltip('舰种'), findsOneWidget);
      for (final key in const <Key>[
        Key('equipment-compatibility-ship-type-button'),
        Key('equipment-compatibility-search-button'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      for (final key in const <Key>[
        Key('equipment-compatibility-ship-type-button-visual'),
        Key('equipment-compatibility-search-button-visual'),
      ]) {
        expect(tester.getSize(find.byKey(key)), const Size(32, 32));
      }
      expect(
        toolButton(
          const Key('equipment-compatibility-ship-type-button'),
        ).isSelected,
        isFalse,
      );
      expect(
        toolButton(
          const Key('equipment-compatibility-search-button'),
        ).isSelected,
        isFalse,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-103')),
        findsNothing,
      );

      final allScopeNode = tester.getSemantics(
        find.byKey(const Key('equipment-compatibility-tab-all')),
      );
      expect(
        allScopeNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      allScopeNode.owner!.performAction(allScopeNode.id, SemanticsAction.tap);
      await tester.pump();
      expect(
        explicitSemantics(
          const Key('equipment-compatibility-tab-all'),
          '全部 4',
        ).properties.selected,
        isTrue,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-103')),
        findsOneWidget,
      );
      final unownedRow = find.byKey(
        const Key('equipment-compatibility-ship-103'),
      );
      expect(
        find.descendant(of: unownedRow, matching: find.text('駆逐艦')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: unownedRow, matching: find.textContaining('Lv.')),
        findsNothing,
      );
      final unownedUnknownTypeRow = find.byKey(
        const Key('equipment-compatibility-ship-104'),
      );
      expect(unownedUnknownTypeRow, findsOneWidget);
      expect(
        find.descendant(of: unownedUnknownTypeRow, matching: find.text('其他')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unownedUnknownTypeRow,
          matching: find.textContaining('Lv.'),
        ),
        findsNothing,
      );

      tester.view.physicalSize = const Size(900, 700);
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('equipment-compatibility-ship-type-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('equipment-compatibility-ship-type-dialog')),
        findsOneWidget,
      );
      final shipTypeDialog = find.byKey(
        const Key('equipment-compatibility-ship-type-dialog'),
      );
      expect(tester.getSize(shipTypeDialog).width, 480);
      expect(
        find.descendant(of: shipTypeDialog, matching: find.text('选择舰种')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shipTypeDialog, matching: find.byType(Wrap)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: shipTypeDialog, matching: find.byType(FilterChip)),
        findsNWidgets(10),
      );
      expect(
        find.descendant(of: shipTypeDialog, matching: find.byType(ListView)),
        findsOneWidget,
      );
      for (final label in const <String>[
        '全部',
        'BB/BC',
        'CV',
        'CVL',
        'CA',
        'CL',
        'DD',
        'DE',
        'SS',
        'AV/AO/AS…',
      ]) {
        expect(
          find.descendant(of: shipTypeDialog, matching: find.text(label)),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.byKey(const Key('equipment-compatibility-ship-category-dd')),
      );
      await tester.pumpAndSettle();
      expect(
        toolButton(
          const Key('equipment-compatibility-ship-type-button'),
        ).isSelected,
        isTrue,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-102')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-103')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('equipment-compatibility-ship-type-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('equipment-compatibility-ship-category-all')),
      );
      await tester.pumpAndSettle();
      expect(
        toolButton(
          const Key('equipment-compatibility-ship-type-button'),
        ).isSelected,
        isFalse,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-102')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-103')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('equipment-compatibility-search-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('equipment-compatibility-search-dialog')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('equipment-compatibility-search-dialog')),
          matching: find.text('搜索舰娘'),
        ),
        findsNWidgets(2),
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const Key('equipment-compatibility-search-dialog-field'),
              ),
            )
            .decoration
            ?.labelText,
        '搜索舰娘',
      );
      await tester.enterText(
        find.byKey(const Key('equipment-compatibility-search-dialog-field')),
        '不存在',
      );
      await tester.tap(
        find.byKey(const Key('equipment-compatibility-search-dialog-cancel')),
      );
      await tester.pumpAndSettle();
      expect(
        toolButton(
          const Key('equipment-compatibility-search-button'),
        ).isSelected,
        isFalse,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-103')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('equipment-compatibility-search-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('equipment-compatibility-search-dialog-field')),
        '  夕張  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('equipment-compatibility-search-dialog')),
        findsNothing,
      );
      expect(
        toolButton(
          const Key('equipment-compatibility-search-button'),
        ).isSelected,
        isTrue,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-102')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('equipment-compatibility-search-button')),
      );
      await tester.pumpAndSettle();
      final searchField = tester.widget<TextField>(
        find.byKey(const Key('equipment-compatibility-search-dialog-field')),
      );
      expect(searchField.controller!.text, '夕張');
      await tester.enterText(
        find.byKey(const Key('equipment-compatibility-search-dialog-field')),
        '',
      );
      await tester.tap(
        find.byKey(const Key('equipment-compatibility-search-dialog-confirm')),
      );
      await tester.pumpAndSettle();
      expect(
        toolButton(
          const Key('equipment-compatibility-search-button'),
        ).isSelected,
        isFalse,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-103')),
        findsOneWidget,
      );

      final expansionFilterNode = tester.getSemantics(
        find.byKey(const Key('equipment-compatibility-filter-expansion')),
      );
      expect(
        expansionFilterNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expansionFilterNode.owner!.performAction(
        expansionFilterNode.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(
        explicitSemantics(
          const Key('equipment-compatibility-filter-expansion'),
          '增设栏',
        ).properties,
        isA<SemanticsProperties>()
            .having((value) => value.button, 'button', isTrue)
            .having((value) => value.selected, 'selected', isTrue)
            .having((value) => value.label, 'label', '增设栏'),
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('equipment-compatibility-ship-102')),
        findsNothing,
      );
      semanticsHandle.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compatibility drawer keeps ship type and query across scope', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _equipmentCompatibilityController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(
            controller: controller,
            showShips: false,
            showSectionControl: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('equipment-name-row-201')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('equipment-compatibility-tab-all')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('equipment-compatibility-ship-type-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('equipment-compatibility-ship-category-dd')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('equipment-compatibility-search-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('equipment-compatibility-search-dialog-field')),
      '夕張',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('equipment-compatibility-tab-owned')),
    );
    await tester.pump();
    IconButton toolButton(Key key) => tester.widget<IconButton>(
      find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
    );
    expect(
      toolButton(
        const Key('equipment-compatibility-ship-type-button'),
      ).isSelected,
      isTrue,
    );
    expect(
      toolButton(const Key('equipment-compatibility-search-button')).isSelected,
      isTrue,
    );
    expect(
      find.byKey(const Key('equipment-compatibility-ship-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('equipment-compatibility-ship-102')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('equipment-compatibility-search-button')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(
              const Key('equipment-compatibility-search-dialog-field'),
            ),
          )
          .controller!
          .text,
      '夕張',
    );
  });

  testWidgets('compatibility drawer labels an owned unknown ship type', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _equipmentCompatibilityController(
      includeOwnedUnknownType: true,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(
            controller: controller,
            showShips: false,
            showSectionControl: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('equipment-name-row-201')));
    await tester.pumpAndSettle();

    final ownedUnknownTypeRow = find.byKey(
      const Key('equipment-compatibility-ship-104'),
    );
    expect(ownedUnknownTypeRow, findsOneWidget);
    expect(
      find.descendant(
        of: ownedUnknownTypeRow,
        matching: find.text('其他 · Lv.73'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compatibility drawer header scrolls with its single viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = await _equipmentCompatibilityController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(
            controller: controller,
            showShips: false,
            showSectionControl: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('equipment-name-row-201')));
    await tester.pumpAndSettle();

    final drawer = find.byKey(const Key('equipment-compatibility-drawer'));
    final scroll = find.descendant(
      of: drawer,
      matching: find.byKey(const Key('equipment-compatibility-scroll')),
    );
    expect(scroll, findsOneWidget);
    expect(tester.widget(scroll), isA<CustomScrollView>());
    expect(
      find.descendant(of: drawer, matching: find.byType(Scrollable)),
      findsOneWidget,
    );

    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: drawer, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    final title = find.descendant(
      of: scroll,
      matching: find.text('12.7cm 连装炮'),
    );
    expect(title, findsOneWidget);
    final initialTop = tester.getTopLeft(title).dy;

    await tester.drag(scroll, const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(
      title.evaluate().isEmpty || tester.getTopLeft(title).dy < initialTop,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compatibility drawer distinguishes unavailable rule data', (
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
        locale: const Locale('zh'),
        home: Scaffold(
          body: OwnedInventoryPage(
            controller: controller,
            showShips: false,
            showSectionControl: false,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('equipment-name-row-201')));
    await tester.pumpAndSettle();

    expect(find.text('装备规则数据等待更新'), findsOneWidget);
    expect(find.text('没有找到可装备的舰娘形态'), findsNothing);
  });

  testWidgets('equipment rows use the bundled POI fallback icon', (
    tester,
  ) async {
    final startEnvelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final startData =
        jsonDecode(jsonEncode(startEnvelope['api_data']))
            as Map<String, Object?>;
    final masterSlotItems = startData['api_mst_slotitem']! as List<Object?>;
    final target = masterSlotItems.cast<Map<String, Object?>>().firstWhere(
      (item) => item['api_id'] == 201,
    );
    target['api_type'] = <int>[1, 1, 1, 48, 0];

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('equipment-name-row-201'));
    final assetNames = tester
        .widgetList<Image>(
          find.descendant(of: row, matching: find.byType(Image)),
        )
        .map((image) => (image.image as AssetImage).assetName);
    expect(assetNames, contains('assets/images/slotitem/148.png'));
    expect(assetNames, isNot(contains('assets/images/slotitem/-1.png')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ship rows end with official and instance id columns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
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
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-ships')),
    );
    expect(
      table.scrollableHeaders
          .map((header) => header.key)
          .toList()
          .sublist(table.scrollableHeaders.length - 2),
      const <Key>[
        Key('owned-inventory-sort-officialId'),
        Key('owned-inventory-sort-instanceId'),
      ],
    );
    final horizontal = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('owned-inventory-horizontal-scroll')),
    );
    horizontal.controller!.jumpTo(
      horizontal.controller!.position.maxScrollExtent,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('owned-inventory-sort-officialId')));
    await tester.pump();
    expect(find.text('官方ID ▼'), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const Key('ship-master-id-9001')))
          .data,
      '101',
    );
    expect(
      tester
          .widget<SelectableText>(
            find.byKey(const Key('ship-instance-id-9001')),
          )
          .data,
      '9001',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('only name total and official id sort equipment groups', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
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
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-equipment')),
    );
    expect(
      table.frozenHeaders.single.key,
      const Key('owned-inventory-equipment-sort-name'),
    );
    expect(table.scrollableHeaders.map((header) => header.key), <Key?>[
      const Key('owned-inventory-equipment-sort-total'),
      null,
      null,
      const Key('owned-inventory-equipment-sort-officialId'),
    ]);

    await tester.tap(
      find.byKey(const Key('owned-inventory-equipment-sort-total')),
    );
    await tester.pump();
    expect(find.text('总数（剩余） ▼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses uniform 78 widths for ship stat columns', (tester) async {
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final table = tester.widget<FrozenDataTable>(
      find.byKey(const Key('owned-inventory-table-ships')),
    );

    expect(table.frozenColumnWidths, const <double>[240]);
    expect(table.scrollableColumnWidths, const <double>[
      96,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      78,
      210,
      52,
      92,
      110,
    ]);
  });

  testWidgets('keeps both filter rows equally compact on a square foldable', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final shipHeight = tester
        .getSize(find.byKey(const Key('ship-filter-all')))
        .height;
    final resetSort = find.byKey(const Key('owned-inventory-sort-reset'));
    expect(resetSort, findsOneWidget);
    await tester.ensureVisible(resetSort);
    expect(
      find.descendant(of: resetSort, matching: find.byIcon(Icons.restore)),
      findsOneWidget,
    );
    expect(find.text('还原默认排序'), findsNothing);
    expect(tester.getSize(resetSort), const Size(34, 28));
    final resetIcon = tester.widget<Icon>(
      find.descendant(of: resetSort, matching: find.byIcon(Icons.restore)),
    );
    expect(resetIcon.size, 19);
    expect(resetIcon.color, const Color(0xffffc85a));
    final resetTooltip = tester.widget<Tooltip>(
      find.descendant(of: resetSort, matching: find.byType(Tooltip)),
    );
    expect(resetTooltip.message, '还原默认排序');
    expect(tester.getSemantics(resetSort).label, contains('还原默认排序'));
    await tester.tap(resetSort);
    await tester.pump();
    expect(find.text('等级 ▼'), findsOneWidget);
    expect(find.text('等级 ▼①'), findsNothing);

    await tester.tap(find.text('装备 0'));
    await tester.pump();
    final equipmentHeight = tester
        .getSize(find.byKey(const Key('equipment-filter-all')))
        .height;

    expect(shipHeight, equipmentHeight);
    expect(shipHeight, lessThanOrEqualTo(30));
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
  });

  testWidgets('renders live ships and grouped equipment and toggles sorting', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller.accept(start2Event);
    controller.accept(portEvent);
    controller.accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    expect(find.text('舰娘 2'), findsOneWidget);
    expect(find.text('等级 ▼'), findsOneWidget);
    await tester.tap(find.text('等级 ▼'));
    await tester.pump();
    expect(find.text('等级 ▲'), findsOneWidget);

    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();
    expect(find.text('总数（剩余）'), findsOneWidget);
    expect(find.textContaining('12.7cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses one temporary sort and toggles its direction', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
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
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    await tester.tap(find.byKey(const Key('owned-inventory-sort-firepower')));
    await tester.pump();
    expect(find.text('等级'), findsOneWidget);
    expect(find.text('火力 ▼'), findsOneWidget);
    expect(find.text('火力 ▼①'), findsNothing);

    await tester.tap(find.byKey(const Key('owned-inventory-sort-firepower')));
    await tester.pump();
    expect(find.text('火力 ▲'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sort interactions reorder real frozen ship rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final startEnvelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final startData =
        jsonDecode(jsonEncode(startEnvelope['api_data']))
            as Map<String, Object?>;
    final masterShips = startData['api_mst_ship']! as List<Object?>;
    masterShips.add(<String, Object?>{
      ...Map<String, Object?>.from(masterShips[1]! as Map),
      'api_id': 103,
      'api_name': '睦月',
    });

    final portEnvelope =
        jsonDecode(portEvent.responseBody) as Map<String, Object?>;
    final portData = portEnvelope['api_data']! as Map<String, Object?>;
    final sourceShips = portData['api_ship']! as List<Object?>;
    final first = Map<String, Object?>.from(sourceShips[0]! as Map);
    final second = Map<String, Object?>.from(sourceShips[1]! as Map);
    final ships = <Object?>[
      <String, Object?>{
        ...first,
        'api_id': 9001,
        'api_ship_id': 101,
        'api_lv': 60,
        'api_karyoku': <int>[10, 10],
        'api_soukou': <int>[5, 5],
        'api_taisen': <int>[10, 10],
      },
      <String, Object?>{
        ...second,
        'api_id': 9002,
        'api_ship_id': 102,
        'api_lv': 50,
        'api_karyoku': <int>[30, 30],
        'api_soukou': <int>[10, 10],
        'api_taisen': <int>[5, 5],
      },
      <String, Object?>{
        ...second,
        'api_id': 9003,
        'api_ship_id': 103,
        'api_lv': 40,
        'api_karyoku': <int>[20, 20],
        'api_soukou': <int>[10, 10],
        'api_taisen': <int>[30, 30],
      },
    ];
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
      ..accept(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_ship': ships,
          'api_deck_port': const <Object?>[],
        }),
      );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    double rowTop(int shipId) =>
        tester.getTopLeft(find.byKey(Key('owned-ship-portrait-$shipId'))).dy;
    void expectOrder(List<int> shipIds) {
      for (var index = 1; index < shipIds.length; index++) {
        expect(rowTop(shipIds[index - 1]), lessThan(rowTop(shipIds[index])));
      }
    }

    expectOrder(const <int>[9001, 9002, 9003]);

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    await tester.tap(firepowerHeader);
    await tester.pump();
    expectOrder(const <int>[9002, 9003, 9001]);

    await tester.tap(firepowerHeader);
    await tester.pump();
    expectOrder(const <int>[9001, 9003, 9002]);

    final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));
    await tester.tap(armorHeader);
    await tester.pump();
    await tester.longPress(armorHeader);
    await tester.pump();
    await tester.tap(find.byKey(const Key('owned-inventory-sort-antiSub')));
    await tester.pump();
    expectOrder(const <int>[9003, 9002, 9001]);

    await tester.tap(find.byKey(const Key('owned-inventory-sort-reset')));
    await tester.pump();
    expectOrder(const <int>[9001, 9002, 9003]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locks a temporary sort and appends one temporary last level', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
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
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    final antiSubHeader = find.byKey(const Key('owned-inventory-sort-antiSub'));
    final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));

    await tester.tap(firepowerHeader);
    await tester.pump();
    await tester.longPress(firepowerHeader);
    await tester.pump();

    expect(find.text('火力 ▼①'), findsOneWidget);
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );

    await tester.tap(antiSubHeader);
    await tester.pump();
    expect(find.text('对潜 ▼②'), findsOneWidget);
    expect(
      find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );

    await tester.tap(armorHeader);
    await tester.pump();
    expect(find.text('火力 ▼①'), findsOneWidget);
    expect(find.text('对潜'), findsOneWidget);
    expect(find.text('装甲 ▼②'), findsOneWidget);
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsOneWidget,
    );

    await tester.tap(firepowerHeader);
    await tester.pump();
    expect(find.text('火力 ▲①'), findsOneWidget);

    final table = tester.widget(
      find.byKey(const Key('owned-inventory-table-ships')),
    );
    await tester.longPress(firepowerHeader);
    await tester.pump();
    expect(find.text('火力'), findsOneWidget);
    expect(find.text('装甲 ▼'), findsOneWidget);
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(
      tester.widget(find.byKey(const Key('owned-inventory-table-ships'))),
      isNot(same(table)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'directly locks an inactive field and clears the temporary sort',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 600);
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
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final antiSubHeader = find.byKey(
        const Key('owned-inventory-sort-antiSub'),
      );
      expect(find.text('等级 ▼'), findsOneWidget);

      await tester.longPress(antiSubHeader);
      await tester.pump();

      expect(find.text('等级'), findsOneWidget);
      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exposes sort state and supports Shift+Enter locking', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    final headerElement = tester.element(firepowerHeader);

    bool headerHasFocus() {
      final focusContext = tester.binding.focusManager.primaryFocus?.context;
      if (focusContext == null) return false;
      var isInsideHeader = identical(focusContext, headerElement);
      focusContext.visitAncestorElements((ancestor) {
        if (identical(ancestor, headerElement)) isInsideHeader = true;
        return !isInsideHeader;
      });
      return isInsideHeader;
    }

    for (var i = 0; i < 40 && !headerHasFocus(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(headerHasFocus(), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(find.text('火力 ▼①'), findsOneWidget);
    final semantics = tester.getSemantics(firepowerHeader);
    expect(semantics.label, contains('火力'));
    expect(semantics.label, contains('降序'));
    expect(semantics.label, contains('第1优先级'));
    expect(semantics.label, contains('已锁定'));
  });

  testWidgets('keeps accessible tap and named lock actions', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    var node = tester.getSemantics(firepowerHeader);
    var data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    expect(data.hasAction(SemanticsAction.customAction), isTrue);

    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(find.text('火力 ▼'), findsOneWidget);

    node = tester.getSemantics(firepowerHeader);
    data = node.getSemanticsData();
    final customActionId = data.customSemanticsActionIds!.single;
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      customActionId,
    );
    await tester.pump();

    expect(find.text('火力 ▼①'), findsOneWidget);
    node = tester.getSemantics(firepowerHeader);
    data = node.getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    expect(data.hasAction(SemanticsAction.customAction), isTrue);
    expect(data.hint, contains('长按或按 Shift+Enter 解除锁定'));

    final unlockActionId = data.customSemanticsActionIds!.single;
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      unlockActionId,
    );
    await tester.pump();

    expect(find.text('火力'), findsOneWidget);
    expect(find.text('等级 ▼'), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets(
    'keeps two locked levels while replacing the temporary last level',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 600);
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
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final antiSubHeader = find.byKey(
        const Key('owned-inventory-sort-antiSub'),
      );
      final firepowerHeader = find.byKey(
        const Key('owned-inventory-sort-firepower'),
      );
      final torpedoHeader = find.byKey(
        const Key('owned-inventory-sort-torpedo'),
      );
      final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));

      await tester.longPress(antiSubHeader);
      await tester.pump();
      await tester.longPress(firepowerHeader);
      await tester.pump();

      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(find.text('火力 ▼②'), findsOneWidget);
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );

      await tester.tap(torpedoHeader);
      await tester.pump();
      expect(find.text('雷装 ▼③'), findsOneWidget);
      expect(
        find.descendant(of: torpedoHeader, matching: find.byIcon(Icons.lock)),
        findsNothing,
      );

      await tester.tap(armorHeader);
      await tester.pump();
      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(find.text('火力 ▼②'), findsOneWidget);
      expect(find.text('雷装'), findsOneWidget);
      expect(find.text('装甲 ▼③'), findsOneWidget);
      expect(
        find.descendant(of: armorHeader, matching: find.byIcon(Icons.lock)),
        findsNothing,
      );
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long-pressing a locked header removes it and advances later priorities',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(2400, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = GameStateController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final antiSubHeader = find.byKey(
        const Key('owned-inventory-sort-antiSub'),
      );
      final firepowerHeader = find.byKey(
        const Key('owned-inventory-sort-firepower'),
      );
      final armorHeader = find.byKey(const Key('owned-inventory-sort-armor'));

      await tester.longPress(antiSubHeader);
      await tester.pump();
      await tester.longPress(firepowerHeader);
      await tester.pump();
      await tester.tap(armorHeader);
      await tester.pump();

      expect(find.text('对潜 ▼①'), findsOneWidget);
      expect(find.text('火力 ▼②'), findsOneWidget);
      expect(find.text('装甲 ▼③'), findsOneWidget);

      await tester.longPress(antiSubHeader);
      await tester.pump();

      expect(find.text('对潜'), findsOneWidget);
      expect(find.text('火力 ▼①'), findsOneWidget);
      expect(find.text('装甲 ▼②'), findsOneWidget);
      expect(
        find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
        findsNothing,
      );
      expect(
        find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
        findsOneWidget,
      );
    },
  );

  testWidgets('colors active headers and contains a locked header', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
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
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final levelHeader = find.byKey(const Key('owned-inventory-sort-level'));
    final temporaryText = tester.widget<Text>(
      find.descendant(of: levelHeader, matching: find.text('等级 ▼')),
    );
    expect(temporaryText.style?.color, const Color(0xffffc85a));

    await tester.longPress(levelHeader);
    await tester.pump();
    final lockedTextFinder = find.descendant(
      of: levelHeader,
      matching: find.text('等级 ▼①'),
    );
    final lockFinder = find.descendant(
      of: levelHeader,
      matching: find.byIcon(Icons.lock),
    );
    expect(
      tester.widget<Text>(lockedTextFinder).style?.color,
      const Color(0xff72bded),
    );
    expect(lockFinder, findsOneWidget);

    final headerRect = tester.getRect(levelHeader);
    final textRect = tester.getRect(lockedTextFinder);
    final lockRect = tester.getRect(lockFinder);
    expect(headerRect.width, 78);
    expect(textRect.left, greaterThanOrEqualTo(headerRect.left));
    expect(textRect.right, lessThanOrEqualTo(headerRect.right));
    expect(lockRect.left, greaterThanOrEqualTo(headerRect.left));
    expect(lockRect.right, lessThanOrEqualTo(headerRect.right));
    expect(textRect.top, greaterThanOrEqualTo(headerRect.top));
    expect(textRect.bottom, lessThanOrEqualTo(headerRect.bottom));
    expect(lockRect.top, greaterThanOrEqualTo(headerRect.top));
    expect(lockRect.bottom, lessThanOrEqualTo(headerRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rightmost sort headers stay tappable after horizontal scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
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
        locale: const Locale('zh'),
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final horizontal = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('owned-inventory-horizontal-scroll')),
    );
    horizontal.controller!.jumpTo(
      horizontal.controller!.position.maxScrollExtent - 202,
    );
    await tester.pump();

    for (final field in <String>[
      'luck',
      'evasion',
      'antiSub',
      'lineOfSight',
      'locked',
    ]) {
      final header = find.byKey(Key('owned-inventory-sort-$field'));
      expect(header.hitTestable(), findsOneWidget, reason: field);

      await tester.tap(header);
      await tester.pump();

      expect(
        find.descendant(
          of: header,
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data!.contains('▼'),
          ),
        ),
        findsOneWidget,
        reason: field,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores the default sort without clearing ship category', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2400, 600);
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
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    await tester.tap(find.byKey(const Key('ship-filter-dd')));
    await tester.pump();
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('吹雪'), findsNothing);

    final antiSubHeader = find.byKey(const Key('owned-inventory-sort-antiSub'));
    final firepowerHeader = find.byKey(
      const Key('owned-inventory-sort-firepower'),
    );
    final levelHeader = find.byKey(const Key('owned-inventory-sort-level'));

    await tester.longPress(antiSubHeader);
    await tester.pump();
    await tester.longPress(firepowerHeader);
    await tester.pump();
    expect(find.text('对潜 ▼①'), findsOneWidget);
    expect(find.text('火力 ▼②'), findsOneWidget);

    await tester.tap(find.byKey(const Key('owned-inventory-sort-reset')));
    await tester.pump();

    expect(find.text('等级 ▼'), findsOneWidget);
    expect(find.text('火力'), findsOneWidget);
    expect(find.text('对潜'), findsOneWidget);
    expect(
      find.descendant(of: antiSubHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(
      find.descendant(of: firepowerHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(
      find.descendant(of: levelHeader, matching: find.byIcon(Icons.lock)),
      findsNothing,
    );
    expect(find.text('夕張'), findsOneWidget);
    expect(find.text('吹雪'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses taller portraits and keeps modernization suffixes visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
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
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final portrait = find.byKey(const Key('owned-ship-portrait-9001'));
      expect(tester.getSize(portrait).height, greaterThanOrEqualTo(50));
      expect(tester.getSize(portrait).width, greaterThanOrEqualTo(76));
      expect(find.text('55/+10'), findsOneWidget);
      expect(find.text('42/+8'), findsOneWidget);
      expect(find.text('38/+12'), findsOneWidget);
      expect(find.text('46/+3'), findsOneWidget);
    },
  );

  testWidgets('equipment rows grow for many wearing ships without overlap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller.accept(start2Event);
    controller.accept(
      kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
        'api_ship': <Object?>[
          for (var index = 1; index <= 14; index++)
            <String, Object?>{
              'api_id': 9000 + index,
              'api_ship_id': 101,
              'api_lv': index,
              'api_slot': <int>[7000 + index],
            },
        ],
        'api_deck_port': const <Object?>[],
      }),
    );
    controller.accept(
      kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
        for (var index = 1; index <= 14; index++)
          <String, Object?>{
            'api_id': 7000 + index,
            'api_slotitem_id': 201,
            'api_level': index % 11,
          },
      ]),
    );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final row = find.byKey(const Key('equipment-name-row-201'));
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, greaterThan(44));

    final wearingCell = find.byKey(const Key('equipment-wearings-cell-201'));
    expect(wearingCell, findsOneWidget);
    final wearingCellRect = tester.getRect(wearingCell);
    final wearingItems = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          ((widget.key! as ValueKey<String>).value).startsWith(
            'equipment-wearing-item-201-',
          ),
    );
    expect(wearingItems, findsNWidgets(14));
    for (final element in wearingItems.evaluate()) {
      final itemRect = tester.getRect(
        find.byElementPredicate((candidate) {
          return identical(candidate, element);
        }),
      );
      expect(itemRect.left, greaterThanOrEqualTo(wearingCellRect.left + 8));
      expect(itemRect.right, lessThanOrEqualTo(wearingCellRect.right - 8));
      expect(itemRect.top, greaterThanOrEqualTo(wearingCellRect.top));
      expect(itemRect.bottom, lessThanOrEqualTo(wearingCellRect.bottom));
    }
    final firstItemRect = tester.getRect(wearingItems.first);
    expect(firstItemRect.left, closeTo(wearingCellRect.left + 8, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long equipment names wrap completely and grow their row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const longName = '试制十五厘米九联装对空喷进炮改二熟练型集中配备型性能强化改修型特殊装备';
    final startEnvelope =
        jsonDecode(start2Event.responseBody) as Map<String, Object?>;
    final startData =
        jsonDecode(jsonEncode(startEnvelope['api_data']))
            as Map<String, Object?>;
    final masterSlotItems = startData['api_mst_slotitem']! as List<Object?>;
    final target = masterSlotItems.cast<Map<String, Object?>>().firstWhere(
      (item) => item['api_id'] == 201,
    );
    target['api_name'] = longName;

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
      ..accept(portEvent)
      ..accept(slotItemEvent);
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final nameFinder = find.text(longName);
    final rowFinder = find.byKey(const Key('equipment-name-row-201'));
    expect(nameFinder, findsOneWidget);
    expect(tester.widget<Text>(nameFinder).maxLines, isNull);
    expect(tester.getSize(rowFinder).height, greaterThan(44));
    expect(
      tester.getRect(nameFinder).bottom,
      lessThanOrEqualTo(tester.getRect(rowFinder).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'equipment row contains the final wearing line with long names and scaled text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final startEnvelope =
          jsonDecode(start2Event.responseBody) as Map<String, Object?>;
      final startData =
          jsonDecode(jsonEncode(startEnvelope['api_data']))
              as Map<String, Object?>;
      final masters = startData['api_mst_ship']! as List<Object?>;
      final template = Map<String, Object?>.from(
        masters.first! as Map<String, Object?>,
      );
      for (var index = 1; index <= 30; index++) {
        masters.add(<String, Object?>{
          ...template,
          'api_id': 1000 + index,
          'api_name': index.isEven
              ? 'Samuel B.Roberts改二$index'
              : 'Ташкент改二$index',
        });
      }

      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
        ..accept(
          kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
            'api_ship': <Object?>[
              for (var index = 1; index <= 30; index++)
                <String, Object?>{
                  'api_id': 9000 + index,
                  'api_ship_id': 1000 + index,
                  'api_lv': 99 - index,
                  'api_slot': <int>[7000 + index],
                },
            ],
            'api_deck_port': const <Object?>[],
          }),
        )
        ..accept(
          kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
            for (var index = 1; index <= 30; index++)
              <String, Object?>{
                'api_id': 7000 + index,
                'api_slotitem_id': 201,
                'api_level': 0,
              },
          ]),
        );
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'HarmonyOS_Sans_SC'),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: Scaffold(body: OwnedInventoryPage(controller: controller)),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
      await tester.pump();

      final wearingCell = find.byKey(const Key('equipment-wearings-cell-201'));
      final finalItem = find.byKey(
        const ValueKey<String>('equipment-wearing-item-201-9030'),
      );
      expect(wearingCell, findsOneWidget);
      expect(finalItem, findsOneWidget);
      expect(
        tester.getRect(finalItem).bottom,
        lessThanOrEqualTo(tester.getRect(wearingCell).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lazily builds ship rows near the viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_ship': <Object?>[
            for (var index = 1; index <= 100; index++)
              <String, Object?>{
                'api_id': 9000 + index,
                'api_ship_id': 101,
                'api_lv': 1,
                'api_slot': const <int>[-1, -1, -1, -1],
              },
          ],
          'api_deck_port': const <Object?>[],
        }),
      );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final firstPortrait = find.byKey(const Key('owned-ship-portrait-9001'));
    final lastPortrait = find.byKey(const Key('owned-ship-portrait-9100'));
    expect(firstPortrait, findsOneWidget);
    expect(lastPortrait, findsNothing);
    final bodyList = find.byKey(const Key('owned-inventory-body-scroll'));
    expect(bodyList, findsOneWidget);
    final bodyListWidget = tester.widget<ListView>(bodyList);
    bodyListWidget.controller!.jumpTo(
      bodyListWidget.controller!.position.maxScrollExtent,
    );
    await tester.pump();

    expect(lastPortrait, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ignores unrelated game state updates and invalidates inventory changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
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
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final tableFinder = find.byKey(const Key('owned-inventory-table-ships'));
      expect(tableFinder, findsOneWidget);
      final initialTable = tester.widget(tableFinder);

      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/material', <Object?>[
          <String, Object?>{'api_id': 1, 'api_value': 999},
        ]),
      );
      await controller.idle;
      await tester.pump();

      expect(tester.widget(tableFinder), same(initialTable));

      controller.accept(slotItemEvent);
      await controller.idle;
      await tester.pump();

      expect(tester.widget(tableFinder), isNot(same(initialTable)));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('decodes owned ship portraits at thumbnail resolution', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1688, 780);
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
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );

    final image = tester.widget<Image>(
      find
          .descendant(
            of: find.byKey(const Key('owned-ship-portrait-9001')),
            matching: find.byType(Image),
          )
          .first,
    );
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).height, 106);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps lazy frozen rows and header synchronized while scrolling',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(844, 390);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller
        ..accept(start2Event)
        ..accept(
          kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
            'api_ship': <Object?>[
              for (var index = 1; index <= 100; index++)
                <String, Object?>{
                  'api_id': 9000 + index,
                  'api_ship_id': 101,
                  'api_lv': 1,
                  'api_slot': const <int>[-1, -1, -1, -1],
                },
            ],
            'api_deck_port': const <Object?>[],
          }),
        );
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OwnedInventoryPage(controller: controller)),
        ),
      );

      final bodyListFinder = find.byKey(
        const Key('owned-inventory-body-scroll'),
      );
      final bodyList = tester.widget<ListView>(bodyListFinder);
      bodyList.controller!.jumpTo(500);
      await tester.pump();

      final frozenList = tester.widget<ListView>(
        find.byKey(const Key('owned-inventory-frozen-scroll')),
      );
      expect(bodyList.controller!.offset, greaterThan(0));
      expect(
        frozenList.controller!.offset,
        closeTo(bodyList.controller!.offset, 0.1),
      );

      final horizontalFinder = find.byKey(
        const Key('owned-inventory-horizontal-scroll'),
      );
      expect(horizontalFinder, findsOneWidget);
      final horizontal = tester.widget<SingleChildScrollView>(horizontalFinder);
      horizontal.controller!.jumpTo(500);
      await tester.pump();

      final headerTranslation = find.descendant(
        of: find.byKey(const Key('owned-inventory-table-ships')),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! Transform) return false;
          final translation = widget.transform.getTranslation();
          return (translation.x + horizontal.controller!.offset).abs() <= 0.1 &&
              translation.y.abs() <= 0.1;
        }),
      );
      expect(horizontal.controller!.offset, greaterThan(0));
      expect(headerTranslation, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('provides known variable equipment extents to both lazy lists', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = GameStateController();
    addTearDown(controller.dispose);
    controller
      ..accept(start2Event)
      ..accept(
        kcsapiEvent('/kcsapi/api_port/port', <String, Object?>{
          'api_ship': <Object?>[
            for (var index = 1; index <= 14; index++)
              <String, Object?>{
                'api_id': 9000 + index,
                'api_ship_id': 101,
                'api_lv': index,
                'api_slot': <int>[7000 + index],
              },
          ],
          'api_deck_port': const <Object?>[],
        }),
      )
      ..accept(
        kcsapiEvent('/kcsapi/api_get_member/slot_item', <Object?>[
          for (var index = 1; index <= 14; index++)
            <String, Object?>{
              'api_id': 7000 + index,
              'api_slotitem_id': 201,
              'api_level': index % 11,
            },
          <String, Object?>{
            'api_id': 8000,
            'api_slotitem_id': 202,
            'api_level': 0,
          },
        ]),
      );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final frozenList = tester.widget<ListView>(
      find.byKey(const Key('owned-inventory-frozen-scroll')),
    );
    final bodyList = tester.widget<ListView>(
      find.byKey(const Key('owned-inventory-body-scroll')),
    );
    expect(frozenList.itemExtentBuilder, isNotNull);
    expect(bodyList.itemExtentBuilder, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('equipment table ignores fleet-only inventory changes', (
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
        home: Scaffold(body: OwnedInventoryPage(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('owned-inventory-tab-equipment')));
    await tester.pump();

    final tableFinder = find.byKey(
      const Key('owned-inventory-table-equipment'),
    );
    final initialTable = tester.widget(tableFinder);

    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_hensei/change',
        null,
        includeApiData: false,
        requestParams: const <String, Object?>{
          'api_id': '1',
          'api_ship_idx': '1',
          'api_ship_id': '-1',
        },
      ),
    );
    await controller.idle;
    await tester.pump();

    expect(tester.widget(tableFinder), same(initialTable));
    expect(tester.takeException(), isNull);
  });
}

List<Map<String, Object?>> _compatibilityPortShips() {
  final envelope = jsonDecode(portEvent.responseBody) as Map<String, Object?>;
  final data =
      jsonDecode(jsonEncode(envelope['api_data'])) as Map<String, Object?>;
  final ships = (data['api_ship']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final first = ships.first..['api_lv'] = 98;
  for (final (instanceId, level) in <(int, int)>[(9003, 76), (9004, 45)]) {
    ships.add(<String, Object?>{
      ...first,
      'api_id': instanceId,
      'api_lv': level,
      'api_slot': const <int>[-1, -1, -1, -1],
      'api_onslot': const <int>[0, 0, 0, 0],
    });
  }
  return ships;
}

Map<String, Object?> _compatibilityPortData({
  required List<Map<String, Object?>> ships,
}) {
  final envelope = jsonDecode(portEvent.responseBody) as Map<String, Object?>;
  final data =
      jsonDecode(jsonEncode(envelope['api_data'])) as Map<String, Object?>;
  (data['api_basic']! as Map<String, Object?>)['api_member_id'] = 1001;
  data['api_ship'] = ships;
  return data;
}

class _MutableInventoryReducer extends GameStateReducer {
  _MutableInventoryReducer(this.nextState);

  GameState nextState;

  @override
  GameState reduce(GameState state, CapturedApiEvent event) => nextState;
}

Future<GameStateController> _equipmentCompatibilityController({
  bool includeOwnedUnknownType = false,
  bool includeUnownedEquipment = false,
}) async {
  final startEnvelope =
      jsonDecode(start2Event.responseBody) as Map<String, Object?>;
  final startData =
      jsonDecode(jsonEncode(startEnvelope['api_data'])) as Map<String, Object?>;
  final shipTypes = startData['api_mst_stype']! as List<Object?>;
  for (final entry in shipTypes) {
    (entry! as Map<String, Object?>)['api_equip_type'] = <String, Object?>{
      '1': 1,
      '10': 1,
      '14': 1,
    };
  }
  shipTypes.add(<String, Object?>{
    'api_id': 99,
    'api_name': '',
    'api_equip_type': <String, Object?>{'1': 1, '10': 1, '14': 1},
  });
  final ships = startData['api_mst_ship']! as List<Object?>;
  final unownedShip = jsonDecode(jsonEncode(ships[1])) as Map<String, Object?>
    ..['api_id'] = 103
    ..['api_sortno'] = 52
    ..['api_name'] = '白雪';
  ships.add(unownedShip);
  final unknownTypeShip =
      jsonDecode(jsonEncode(ships[1])) as Map<String, Object?>
        ..['api_id'] = 104
        ..['api_sortno'] = 53
        ..['api_name'] = '未知舰种'
        ..['api_stype'] = 99;
  ships.add(unknownTypeShip);
  if (includeUnownedEquipment) {
    final equipment = startData['api_mst_slotitem']! as List<Object?>;
    startData['api_mst_slotitem_equiptype'] = <Object?>[
      <String, Object?>{'api_id': 1, 'api_name': '小口径主炮'},
      <String, Object?>{'api_id': 10, 'api_name': '水上侦察机'},
      <String, Object?>{'api_id': 14, 'api_name': '声呐'},
    ];
    equipment.add(<String, Object?>{
      ...equipment.first! as Map<String, Object?>,
      'api_id': 204,
      'api_sortno': 18,
      'api_name': '12.7cm 连装炮二型',
    });
    equipment.add(<String, Object?>{
      ...equipment[1]! as Map<String, Object?>,
      'api_id': 205,
      'api_sortno': 19,
      'api_name': '零式水上侦察机二型',
    });
  }
  startData['api_mst_equip_ship'] = <String, Object?>{
    '104': <String, Object?>{
      'api_equip_type': <String, Object?>{'1': 1, '10': 1, '14': 1},
    },
  };
  startData['api_mst_equip_exslot'] = <Object?>[];
  startData['api_mst_equip_exslot_ship'] = <String, Object?>{
    '201': <String, Object?>{
      'api_ship_ids': <String, Object?>{'101': 1},
      'api_req_level': 4,
    },
  };
  startData['api_mst_equip_limit_exslot'] = <String, Object?>{};

  final portEnvelope =
      jsonDecode(portEvent.responseBody) as Map<String, Object?>;
  final portData =
      jsonDecode(jsonEncode(portEnvelope['api_data'])) as Map<String, Object?>;
  (portData['api_basic']! as Map<String, Object?>)['api_member_id'] = 1001;
  final ownedShips = portData['api_ship']! as List<Object?>;
  final firstOwnedShip = ownedShips.first! as Map<String, Object?>;
  firstOwnedShip['api_lv'] = 98;
  for (final (instanceId, level) in <(int, int)>[(9003, 76), (9004, 45)]) {
    ownedShips.add(<String, Object?>{
      ...firstOwnedShip,
      'api_id': instanceId,
      'api_lv': level,
      'api_slot': const <int>[-1, -1, -1, -1],
      'api_onslot': const <int>[0, 0, 0, 0],
    });
  }
  if (includeOwnedUnknownType) {
    ownedShips.add(<String, Object?>{
      ...firstOwnedShip,
      'api_id': 9005,
      'api_ship_id': 104,
      'api_lv': 73,
      'api_slot': const <int>[-1, -1, -1, -1],
      'api_onslot': const <int>[0, 0, 0, 0],
    });
  }

  final controller = GameStateController();
  controller
    ..accept(kcsapiEvent('/kcsapi/api_start2/getData', startData))
    ..accept(kcsapiEvent('/kcsapi/api_port/port', portData))
    ..accept(slotItemEvent);
  await controller.idle;
  return controller;
}
