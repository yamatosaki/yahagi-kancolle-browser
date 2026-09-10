import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/land_base_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_visuals.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets(
    'damage frames only the portrait and never creates a fatigue face',
    (tester) async {
      await tester.pumpWidget(
        _row(base: _base(currentHp: 48, conditions: const <int>[1, 1, 1, 1])),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('land-base-portrait-hp-frame-62-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('land-base-row-hp-frame-62-1')),
        findsNothing,
      );
      expect(find.byKey(const Key('land-base-hp-meter-62-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('land-base-status-column-62-1')),
          matching: find.byType(DamagePulseBuilder),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('land-base-fatigue-face-62-1')),
        findsNothing,
      );
    },
  );

  for (final entry in <int, String>{2: 'yellow', 3: 'red'}.entries) {
    testWidgets('${entry.value} fatigue face sits at portrait top-right', (
      tester,
    ) async {
      await tester.pumpWidget(
        _row(
          base: _base(currentHp: 200, conditions: <int>[1, entry.key, 1, 1]),
        ),
      );

      final portrait = tester.getRect(
        find.byKey(const Key('land-base-portrait-62-1')),
      );
      final face = tester.getRect(
        find.byKey(const Key('land-base-fatigue-face-62-1')),
      );
      expect(face.top, closeTo(portrait.top, 0.1));
      expect(face.right, closeTo(portrait.right - 4, 0.1));
    });
  }

  testWidgets('renders four slots including missing planes and relocation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _row(
        base: _base(
          currentHp: 152,
          conditions: const <int>[1, 2, 3, 1],
          states: const <int>[1, 1, 2, 0],
          counts: const <int>[18, 12, 0, 0],
        ),
      ),
    );

    for (var id = 1; id <= 4; id++) {
      expect(find.byKey(Key('land-base-slot-62-1-$id')), findsOneWidget);
    }
    expect(find.text('18'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(
      find.byKey(const Key('land-base-slot-relocating-62-1-3')),
      findsOneWidget,
    );

    final slot = tester.getRect(find.byKey(const Key('land-base-slot-62-1-1')));
    final icon = tester.getRect(
      find.byKey(const Key('land-base-slot-icon-62-1-1')),
    );
    final count = tester.getRect(
      find.byKey(const Key('land-base-slot-count-62-1-1')),
    );
    expect(icon.width, greaterThan(16));
    expect(icon.height, greaterThan(16));
    expect(slot.right - count.right, inInclusiveRange(2, 4));
    expect(count.top - slot.top, inInclusiveRange(2, 4));
    expect(count.top, lessThan(icon.bottom));
  });

  testWidgets('ordinary phone window keeps slot count at eight pixels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _row(
        width: 390,
        base: _base(currentHp: 200, conditions: const <int>[1, 1, 1, 1]),
      ),
    );

    final count = find.descendant(
      of: find.byKey(const Key('land-base-slot-count-62-1-1')),
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(count).style?.fontSize, 8);
  });

  testWidgets('near-square large window enlarges only the slot count', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(673, 841);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _row(base: _base(currentHp: 200, conditions: const <int>[1, 1, 1, 1])),
    );

    final count = find.descendant(
      of: find.byKey(const Key('land-base-slot-count-62-1-1')),
      matching: find.byType(Text),
    );
    expect(tester.widget<Text>(count).style?.fontSize, 10);
  });

  testWidgets('action kind three is retreat and four is rest', (tester) async {
    await tester.pumpWidget(
      _row(
        base: _base(
          currentHp: 200,
          conditions: const <int>[1, 1, 1, 1],
          actionKind: 3,
        ),
      ),
    );

    var actionChip = find.byKey(const Key('land-base-action-chip-62-1'));
    var actionText = find.descendant(
      of: actionChip,
      matching: find.byType(Text),
    );
    expect(find.text('退避'), findsOneWidget);
    expect(find.text('休息'), findsNothing);
    expect(
      tester.widget<Text>(actionText).style?.color,
      const Color(0xff9ca8b2),
    );

    await tester.pumpWidget(
      _row(
        base: _base(
          currentHp: 200,
          conditions: const <int>[1, 1, 1, 1],
          actionKind: 4,
        ),
      ),
    );

    actionChip = find.byKey(const Key('land-base-action-chip-62-1'));
    actionText = find.descendant(of: actionChip, matching: find.byType(Text));
    expect(find.text('休息'), findsOneWidget);
    expect(find.text('退避'), findsNothing);
    expect(
      tester.widget<Text>(actionText).style?.color,
      const Color(0xff70c697),
    );
  });

  testWidgets('land base info chips match the home ship badge sizing', (
    tester,
  ) async {
    final base = _base(currentHp: 200, conditions: const <int>[1, 1, 1, 1]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const MiniBadge(
                key: Key('ship-badge-size-reference'),
                text: '参照',
                color: Color(0xffa9bac4),
              ),
              SizedBox(
                width: 640,
                child: LandBaseAirGroupRow(state: _state(base), base: base),
              ),
            ],
          ),
        ),
      ),
    );

    final reference = find.byKey(const Key('ship-badge-size-reference'));
    final referenceHeight = tester.getSize(reference).height;
    for (final key in const <Key>[
      Key('land-base-name-62-1'),
      Key('land-base-action-chip-62-1'),
      Key('land-base-air-power-chip-62-1'),
    ]) {
      final chip = find.byKey(key);
      final text = find.descendant(of: chip, matching: find.byType(Text));
      expect(tester.getSize(chip).height, closeTo(referenceHeight, 0.1));
      expect(tester.widget<Text>(text).style?.fontSize, 8);
    }
  });

  testWidgets(
    'ordinary landscape width uses a compact header without overflow',
    (tester) async {
      await tester.pumpWidget(
        _row(
          width: 470,
          base: _base(currentHp: 200, conditions: const <int>[1, 1, 1, 1]),
        ),
      );

      expect(tester.takeException(), isNull);

      final name = tester.getRect(find.byKey(const Key('land-base-name-62-1')));
      final airPower = tester.getRect(
        find.byKey(const Key('land-base-air-power-chip-62-1')),
      );
      final action = tester.getRect(
        find.byKey(const Key('land-base-action-chip-62-1')),
      );
      final range = tester.getRect(
        find.byKey(const Key('land-base-range-chip-62-1')),
      );
      final portrait = tester.getRect(
        find.byKey(const Key('land-base-portrait-62-1')),
      );

      expect(action.center.dy, closeTo(name.center.dy, 0.1));
      expect(airPower.center.dy, closeTo(name.center.dy, 0.1));
      expect(range.center.dy, closeTo(name.center.dy, 0.1));
      expect(portrait.top, greaterThan(name.bottom));
      expect(portrait.size, const Size(68, 32));

      final hpValue = tester.getRect(
        find.byKey(const Key('land-base-hp-value-62-1')),
      );
      final hpText = find.descendant(
        of: find.byKey(const Key('land-base-hp-value-62-1')),
        matching: find.byType(Text),
      );
      final hpMeter = tester.getRect(
        find.byKey(const Key('land-base-hp-meter-62-1')),
      );
      expect(tester.widget<Text>(hpText).style?.fontSize, 11);
      expect(hpMeter.top - hpValue.bottom, closeTo(3, 0.1));
      expect(hpMeter.left, closeTo(hpValue.left, 0.1));
      expect(hpMeter.height, closeTo(7.2, 0.1));

      final hpIcon = tester.widget<Icon>(
        find.byKey(const Key('land-base-hp-icon-62-1')),
      );
      expect(hpIcon.color, const Color(0xffef5a5a));
      expect(hpIcon.size, 10);

      expect(name.height, closeTo(action.height, 0.1));
      expect(name.top, closeTo(action.top, 0.1));
      expect(name.width, lessThan(100));
      expect(action.left - name.right, closeTo(4, 0.1));
      final nameContainer = find.descendant(
        of: find.byKey(const Key('land-base-name-62-1')),
        matching: find.byType(Container),
      );
      expect(
        tester.widget<Container>(nameContainer).decoration,
        isA<BoxDecoration>(),
      );

      final slots = <Rect>[
        for (var id = 1; id <= 4; id++)
          tester.getRect(find.byKey(Key('land-base-slot-62-1-$id'))),
      ];
      for (final slot in slots) {
        expect(slot.width, lessThanOrEqualTo(38));
      }
      for (var index = 1; index < slots.length; index++) {
        expect(slots[index].left - slots[index - 1].right, closeTo(2, 0.1));
      }
    },
  );

  testWidgets('very narrow dashboard column shrinks slots without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _row(
        // The row's horizontal padding leaves the 217.8 px content width
        // reported by the iPhone 17 Pro overflow.
        width: 229.8,
        base: _base(currentHp: 200, conditions: const <int>[1, 1, 1, 1]),
      ),
    );

    expect(tester.takeException(), isNull);

    final slots = <Rect>[
      for (var id = 1; id <= 4; id++)
        tester.getRect(find.byKey(Key('land-base-slot-62-1-$id'))),
    ];
    for (final slot in slots) {
      expect(slot.width, closeTo(18.45, 0.1));
    }
  });

  testWidgets('single-column spare width expands hp toward right slots', (
    tester,
  ) async {
    await tester.pumpWidget(
      _row(
        width: 640,
        base: _base(currentHp: 200, conditions: const <int>[1, 1, 1, 1]),
      ),
    );

    final row = tester.getRect(find.byKey(const Key('land-base-row-62-1')));
    final status = tester.getRect(
      find.byKey(const Key('land-base-status-column-62-1')),
    );
    final squadrons = tester.getRect(
      find.byKey(const Key('land-base-squadron-strip-62-1')),
    );

    expect(status.width, greaterThan(150));
    expect(squadrons.left - status.right, closeTo(7, 0.1));
    expect(row.right - squadrons.right, closeTo(7.2, 0.1));
  });

  testWidgets('card switches areas and collapses without a details panel', (
    tester,
  ) async {
    final controller = await _controllerWithLandBases();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller));
    await tester.pump();

    expect(find.text('[6] 中部海域'), findsOneWidget);
    expect(find.text('其他海域基地'), findsOneWidget);
    expect(find.text('第一基地航空队'), findsNothing);

    await tester.tap(find.byKey(const Key('land-base-area-selector-62')));
    await tester.pump();
    expect(find.text('[62] 反击！第三十一战队的战斗'), findsOneWidget);
    expect(find.text('第一基地航空队'), findsOneWidget);
    expect(find.text('其他海域基地'), findsNothing);

    await tester.tap(find.byKey(const Key('land-base-collapse-button')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LandBaseAirGroupRow), findsNothing);
    expect(find.text('点击航空队查看装备详情'), findsNothing);
  });

  testWidgets('area heading omits the land base count', (tester) async {
    final controller = await _controllerWithLandBases(selectedAreaBaseCount: 2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller));
    await tester.tap(find.byKey(const Key('land-base-area-selector-62')));
    await tester.pump();

    expect(find.text('2 支航空队'), findsNothing);
  });

  testWidgets('expanded foldable width arranges three bases in a 2x2 grid', (
    tester,
  ) async {
    final controller = await _controllerWithLandBases(selectedAreaBaseCount: 3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller, width: 760));
    await tester.tap(find.byKey(const Key('land-base-area-selector-62')));
    await tester.pump();

    final first = tester.getRect(find.byKey(const Key('land-base-row-62-1')));
    final second = tester.getRect(find.byKey(const Key('land-base-row-62-2')));
    final third = tester.getRect(find.byKey(const Key('land-base-row-62-3')));

    expect(first.top, closeTo(second.top, 0.1));
    expect(second.left, greaterThan(first.right));
    expect(third.left, closeTo(first.left, 0.1));
    expect(third.top, greaterThan(first.bottom));
    expect(third.width, closeTo(first.width, 0.1));
    expect(third.right, lessThan(second.right));
    expect(
      tester
          .getRect(find.byKey(const Key('land-base-status-column-62-1')))
          .width,
      closeTo(68, 0.1),
    );
  });

  testWidgets('ordinary width keeps land bases in one column', (tester) async {
    final controller = await _controllerWithLandBases(selectedAreaBaseCount: 3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_card(controller, width: 600));
    await tester.tap(find.byKey(const Key('land-base-area-selector-62')));
    await tester.pump();

    final first = tester.getRect(find.byKey(const Key('land-base-row-62-1')));
    final second = tester.getRect(find.byKey(const Key('land-base-row-62-2')));
    final third = tester.getRect(find.byKey(const Key('land-base-row-62-3')));

    expect(second.left, closeTo(first.left, 0.1));
    expect(second.top, greaterThan(first.bottom));
    expect(third.left, closeTo(first.left, 0.1));
    expect(third.top, greaterThan(second.bottom));
  });
}

LandBaseState _base({
  required int currentHp,
  required List<int> conditions,
  int actionKind = 1,
  List<int> states = const <int>[1, 1, 1, 1],
  List<int> counts = const <int>[18, 18, 18, 18],
}) => LandBaseState(
  areaId: 62,
  baseId: 1,
  name: '第一基地航空队',
  actionKind: actionKind,
  distanceBase: 7,
  maxHp: 200,
  currentHp: currentHp,
  squadrons: <LandBaseSquadronState>[
    for (var index = 0; index < 4; index++)
      LandBaseSquadronState(
        squadronId: index + 1,
        state: states[index],
        slotItemId: 1001 + index,
        currentCount: counts[index],
        maxCount: 18,
        condition: conditions[index],
      ),
  ],
);

Widget _row({required LandBaseState base, double width = 640}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: LandBaseAirGroupRow(state: _state(base), base: base),
    ),
  ),
);

GameState _state(LandBaseState base) => GameState(
  serverOrigin: 'https://example.test',
  landBases: <LandBaseState>[base],
  masterSlotItems: <int, MasterSlotItem>{
    for (var index = 0; index < 4; index++)
      201 + index: MasterSlotItem(
        id: 201 + index,
        name: '陆航装备${index + 1}',
        antiAir: 10,
        type: const <int>[0, 0, 6, 6],
      ),
  },
  slotItems: <int, OwnedSlotItem>{
    for (var index = 0; index < 4; index++)
      1001 + index: OwnedSlotItem(id: 1001 + index, masterId: 201 + index),
  },
);

Future<GameStateController> _controllerWithLandBases({
  int selectedAreaBaseCount = 1,
}) async {
  final controller = GameStateController();
  controller
    ..accept(
      kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
        'api_mst_stype': const <Object?>[],
        'api_mst_ship': const <Object?>[],
        'api_mst_maparea': <Object?>[
          <String, Object?>{'api_id': 6, 'api_name': '中部海域'},
          <String, Object?>{'api_id': 62, 'api_name': '反击！第三十一战队的战斗'},
        ],
      }),
    )
    ..accept(
      kcsapiEvent('/kcsapi/api_get_member/mapinfo', <String, Object?>{
        'api_map_info': const <Object?>[],
        'api_air_base': <Object?>[
          <String, Object?>{
            'api_area_id': 6,
            'api_rid': 1,
            'api_name': '其他海域基地',
          },
          <String, Object?>{
            'api_area_id': 62,
            'api_rid': 1,
            'api_name': '第一基地航空队',
          },
          for (var baseId = 2; baseId <= selectedAreaBaseCount; baseId++)
            <String, Object?>{
              'api_area_id': 62,
              'api_rid': baseId,
              'api_name': baseId == 2 ? '第二基地航空队' : '第三基地航空队',
            },
        ],
      }),
    );
  await controller.idle;
  return controller;
}

Widget _card(GameStateController controller, {double? width}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: width,
      child: _CardHarness(controller: controller),
    ),
  ),
);

class _CardHarness extends StatefulWidget {
  const _CardHarness({required this.controller});

  final GameStateController controller;

  @override
  State<_CardHarness> createState() => _CardHarnessState();
}

class _CardHarnessState extends State<_CardHarness> {
  var _collapsed = false;

  @override
  Widget build(BuildContext context) => LandBaseSummaryCard(
    controller: widget.controller,
    collapsed: _collapsed,
    onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
  );
}
