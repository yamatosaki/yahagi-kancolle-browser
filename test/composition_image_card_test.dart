import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/fleet/slot_item_portrait.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/composition_image_card.dart';

import 'fixtures/composition_image_fixture.dart';

void main() {
  testWidgets('paired transport fits the record and image metric cells', (
    tester,
  ) async {
    const equipment = [501, 502, 503, 504, 505];
    final state = GameState(
      ships: {
        for (var id = 1; id <= 12; id++)
          id: OwnedShip(
            id: id,
            masterId: 100,
            level: 99,
            slotIds: equipment,
            extraSlotId: 506,
          ),
      },
      masterShips: const {
        100: MasterShip(id: 100, name: '輸送艦', shipTypeId: 22, slotCount: 5),
      },
      slotItems: {
        for (var id = 501; id <= 506; id++)
          id: OwnedSlotItem(instanceId: id, masterSlotItemId: 576),
      },
      masterSlotItems: const {
        576: MasterSlotItem(id: 576, name: '大発動艇(R35＆フランス兵)', type: [0, 0, 24]),
      },
      fleets: const [
        Fleet(id: 1, name: '主力', shipIds: [1, 2, 3, 4, 5, 6]),
        Fleet(id: 2, name: '护卫', shipIds: [7, 8, 9, 10, 11, 12]),
      ],
    );
    for (final recordMode in [true, false]) {
      await _pump(
        tester,
        state: state,
        fleetIds: {1, 2},
        recordMode: recordMode,
        isCombinedFleet: true,
      );
      final metric = find.byKey(
        const Key('composition-metric-1-transport-points'),
      );
      final value = find.descendant(
        of: metric,
        matching: find.text('756（1862）'),
      );
      expect(value, findsOneWidget);
      final cellRect = tester.getRect(metric);
      final valueRect = tester.getRect(value);
      for (final field in ['speed', 'line-of-sight']) {
        final other = tester.getRect(
          find.byKey(Key('composition-metric-1-$field')),
        );
        expect(other.top, cellRect.top);
        expect(other.height, cellRect.height);
      }
      expect(valueRect.left, greaterThanOrEqualTo(cellRect.left));
      expect(valueRect.right, lessThanOrEqualTo(cellRect.right));
      expect(valueRect.bottom, lessThanOrEqualTo(cellRect.bottom));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('record mode uses contiguous table cells and keeps equipment', (
    tester,
  ) async {
    await _pump(
      tester,
      state: compositionImageFixture(),
      fleetIds: {1},
      recordMode: true,
    );
    final first = find.byKey(const Key('composition-slot-1-1-1'));
    final second = find.byKey(const Key('composition-slot-1-1-2'));
    expect(tester.getTopRight(first).dx, tester.getTopLeft(second).dx);
    final equipmentDecoration =
        tester.widget<Container>(first).decoration as BoxDecoration;
    expect(equipmentDecoration.borderRadius, isNull);
    expect(
      (equipmentDecoration.border! as Border).left.color,
      const Color(0xff527286),
    );
    expect((equipmentDecoration.border! as Border).left.width, 1.2);
    final metricDecoration =
        tester
                .widget<Container>(
                  find.byKey(const Key('composition-metric-1-speed')),
                )
                .decoration
            as BoxDecoration;
    expect(
      (metricDecoration.border! as Border).bottom.color,
      const Color(0xff5c7d90),
    );
    expect(find.byKey(const Key('composition-image-header')), findsNothing);
    expect(find.byKey(const Key('composition-generated-at')), findsNothing);
    expect(
      find.byKey(const Key('composition-equipment-name-1-1-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('record ship rows align with the metrics grid', (tester) async {
    final fixture = compositionImageFixture();
    final state = fixture.copyWith(
      masterShips: {
        ...fixture.masterShips,
        for (final (shipId, slots) in [(1, 3), (2, 4), (3, 4), (4, 5)])
          shipId + 99: MasterShip(
            id: shipId + 99,
            name: '测试舰$shipId',
            shipTypeId: 3,
            slotCount: slots,
          ),
      },
      ships: {
        ...fixture.ships,
        for (final (shipId, slots, expansion) in [
          (1, 3, 0),
          (2, 4, 0),
          (3, 4, 505),
          (4, 5, 505),
        ])
          shipId: OwnedShip(
            id: shipId,
            masterId: shipId + 99,
            level: 99,
            slotIds: List.filled(slots, 501),
            extraSlotId: expansion,
          ),
      },
    );
    await _pump(tester, state: state, fleetIds: {1}, recordMode: true);
    final metric = tester.getRect(
      find.byKey(const Key('composition-metric-1-speed')),
    );
    final firstSlotLeft = metric.left + metric.width * 2;
    final equipmentWidth = metric.width * 6;
    for (final (shipId, count) in [(1, 3), (2, 4), (3, 5), (4, 6)]) {
      final slots = [
        for (
          var index = 1;
          index <=
              (shipId == 4
                  ? 5
                  : shipId == 1
                  ? 3
                  : 4);
          index++
        )
          find.byKey(Key('composition-slot-1-$shipId-$index')),
        if (shipId >= 3) find.byKey(Key('composition-slot-1-$shipId-extra')),
      ];
      expect(slots, hasLength(count));
      expect(tester.getRect(slots.first).left, closeTo(firstSlotLeft, 2));
      for (final slot in slots) {
        expect(tester.getRect(slot).width, closeTo(equipmentWidth / count, 2));
      }
      expect(
        tester.getRect(slots.last).right,
        closeTo(metric.left + metric.width * 8, 2),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('equipment tiles run horizontally with details below the name', (
    tester,
  ) async {
    await _pump(tester, state: compositionImageFixture(), fleetIds: {1});
    final first = find.byKey(const Key('composition-slot-1-1-1'));
    final second = find.byKey(const Key('composition-slot-1-1-2'));
    final name = find.byKey(const Key('composition-equipment-name-1-1-1'));
    final proficiency = find.byKey(const Key('composition-proficiency-1-1-1'));
    final improvement = find.text('★6').first;
    final count = find.byKey(const Key('composition-plane-count-1-1-1'));
    expect(
      tester.getTopLeft(second).dx,
      greaterThan(tester.getTopRight(first).dx),
    );
    expect(tester.getTopLeft(second).dy, tester.getTopLeft(first).dy);
    for (final detail in [proficiency, improvement, count]) {
      expect(
        tester.getTopLeft(detail).dy,
        greaterThan(tester.getTopLeft(name).dy),
      );
    }
    expect(
      tester.widget<Text>(improvement).style?.color,
      const Color(0xff81d8cc),
    );
    expect(tester.widget<Text>(count).style?.color, const Color(0xff81d8cc));
    final portrait = tester.widget<ShipPortrait>(
      find.descendant(
        of: find.byKey(const Key('composition-ship-1-1')),
        matching: find.byType(ShipPortrait),
      ),
    );
    expect(portrait.width, 112);
    expect(find.text('装备 1'), findsNothing);
    expect(find.text('熟練'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('five regular slots and expansion fit on one ship row', (
    tester,
  ) async {
    final fixture = compositionImageFixture();
    final state = fixture.copyWith(
      masterShips: {
        ...fixture.masterShips,
        100: const MasterShip(
          id: 100,
          name: '大和改二',
          shipTypeId: 11,
          slotCount: 5,
        ),
      },
      ships: {
        ...fixture.ships,
        1: const OwnedShip(
          id: 1,
          masterId: 100,
          level: 99,
          luck: 20,
          slotIds: [501, -1, 503, 504, -1],
          extraSlotId: 505,
        ),
      },
    );
    await _pump(tester, state: state, fleetIds: {1});
    final fourth = find.byKey(const Key('composition-slot-1-1-4'));
    final fifth = find.byKey(const Key('composition-slot-1-1-5'));
    final extra = find.byKey(const Key('composition-slot-1-1-extra'));
    expect(fifth, findsOneWidget);
    expect(
      tester.getTopLeft(fifth).dx,
      greaterThan(tester.getTopRight(fourth).dx),
    );
    expect(
      tester.getTopLeft(extra).dx,
      greaterThan(tester.getTopRight(fifth).dx),
    );
    expect(tester.getTopLeft(extra).dy, tester.getTopLeft(fifth).dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('land base has a representative equipment icon', (tester) async {
    await _pump(
      tester,
      state: compositionImageFixture(),
      fleetIds: {1},
      areaId: 47,
      baseIds: {1},
    );
    expect(
      find.byKey(const Key('composition-base-portrait-47-1')),
      findsOneWidget,
    );
    final portrait = tester.widget<SlotItemPortrait>(
      find.descendant(
        of: find.byKey(const Key('composition-base-portrait-47-1')),
        matching: find.byType(SlotItemPortrait),
      ),
    );
    expect(portrait.width, 112);
    expect(portrait.fit, BoxFit.cover);
    expect(
      tester.widget<Text>(find.text('出撃')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(
      tester.widget<Text>(find.text('行動半径 8')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(find.text('第 1 航空隊'), findsNothing);
    expect(find.text('第 1 中隊'), findsNothing);
    expect(
      tester
          .getTopLeft(find.byKey(const Key('composition-slot-base-47-1-1')))
          .dx,
      tester.getTopLeft(find.byKey(const Key('composition-slot-1-1-1'))).dx,
    );
    for (var index = 1; index <= 4; index++) {
      expect(
        find.byKey(Key('composition-slot-base-47-1-$index')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final scenario in const <(String, int, String?)>[
    ('unopened', 0, null),
    ('opened and empty', -1, '未装備'),
    ('equipped', 505, '熟練見張員'),
  ]) {
    testWidgets('expansion slot state: ${scenario.$1}', (tester) async {
      final state = compositionImageFixture().copyWith(
        fleets: const [
          Fleet(id: 1, name: '増設確認', shipIds: [1]),
        ],
        ships: {
          1: OwnedShip(
            id: 1,
            masterId: 100,
            level: 99,
            extraSlotId: scenario.$2,
          ),
        },
      );
      await _pump(tester, state: state, fleetIds: {1});
      final extra = find.byKey(const Key('composition-slot-1-1-extra'));
      if (scenario.$3 == null) {
        expect(extra, findsNothing);
      } else {
        expect(extra, findsOneWidget);
        expect(
          find.descendant(of: extra, matching: find.text(scenario.$3!)),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('inherits the application font for exported CJK names', (
    tester,
  ) async {
    await _pump(tester, state: compositionImageFixture(), fleetIds: {1});
    final name = find.byKey(const Key('composition-equipment-name-1-1-1'));
    expect(
      DefaultTextStyle.of(tester.element(name)).style.fontFamily,
      'CompositionTestFont',
    );
  });

  testWidgets(
    'renders no regular slots when master explicitly declares zero slots',
    (tester) async {
      const state = GameState(
        fleets: [
          Fleet(id: 1, name: '零装備艦', shipIds: [1]),
        ],
        ships: {
          1: OwnedShip(
            id: 1,
            masterId: 1,
            level: 1,
            slotIds: [-1, -1, -1, -1, -1],
            extraSlotId: 0,
          ),
        },
        masterShips: {
          1: MasterShip(id: 1, name: '零装備艦', shipTypeId: 13, slotCount: 0),
        },
      );
      await _pump(tester, state: state, fleetIds: {1});
      expect(find.byKey(const Key('composition-ship-1-1')), findsOneWidget);
      for (var slot = 1; slot <= 5; slot++) {
        expect(find.byKey(Key('composition-slot-1-1-$slot')), findsNothing);
      }
      expect(find.byKey(const Key('composition-slot-1-1-extra')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'omits unavailable padded slots while retaining available empty slots',
    (tester) async {
      const state = GameState(
        fleets: [
          Fleet(id: 1, name: 'Three slots', shipIds: [1]),
        ],
        ships: {
          1: OwnedShip(
            id: 1,
            masterId: 1,
            level: 1,
            slotIds: [-1, -1, -1, -1, -1],
          ),
        },
        masterShips: {
          1: MasterShip(id: 1, name: '三装備艦', shipTypeId: 3, slotCount: 3),
        },
      );
      await _pump(tester, state: state, fleetIds: {1});
      expect(find.byKey(const Key('composition-slot-1-1-3')), findsOneWidget);
      expect(find.byKey(const Key('composition-slot-1-1-4')), findsNothing);
      expect(find.byKey(const Key('composition-slot-1-1-5')), findsNothing);
    },
  );

  testWidgets('preserves empty regular slots and renders expansion equipment', (
    tester,
  ) async {
    await _pump(tester, state: compositionImageFixture(), fleetIds: {1});
    final first = find.byKey(const Key('composition-ship-1-1'));
    final empty = find.byKey(const Key('composition-slot-1-1-2'));
    final third = find.byKey(const Key('composition-slot-1-1-3'));
    final extra = find.byKey(const Key('composition-slot-1-1-extra'));
    expect(first, findsOneWidget);
    expect(empty, findsOneWidget);
    expect(tester.getTopLeft(empty).dx, lessThan(tester.getTopLeft(third).dx));
    expect(tester.getTopLeft(empty).dy, tester.getTopLeft(third).dy);
    expect(
      find.descendant(of: extra, matching: find.text('熟練見張員')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.text('★6')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('composition-proficiency-1-1-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses a single fleet title and keeps levels beside short and long ship names',
    (tester) async {
      final state = compositionImageFixture().copyWith(
        fleets: const [
          Fleet(id: 1, name: '夜間遊撃部隊', shipIds: [1, 2]),
        ],
        ships: const {
          1: OwnedShip(id: 1, masterId: 100, level: 99, slotIds: [-1]),
          2: OwnedShip(id: 2, masterId: 101, level: 175, slotIds: [-1]),
        },
        masterShips: const {
          100: MasterShip(id: 100, name: '伊26', shipTypeId: 13, slotCount: 1),
          101: MasterShip(
            id: 101,
            name: 'Commandant Teste改',
            shipTypeId: 16,
            slotCount: 1,
          ),
        },
      );
      await _pump(tester, state: state, fleetIds: {1});
      expect(find.text('夜間遊撃部隊'), findsOneWidget);
      expect(find.text('第 1 艦隊'), findsNothing);
      expect(find.text('01'), findsNothing);
      expect(find.text('2 隻'), findsNothing);
      for (final (shipId, shipName, level) in [
        (1, '伊26', 99),
        (2, 'Commandant Teste改', 175),
      ]) {
        final ship = find.byKey(Key('composition-ship-1-$shipId'));
        final name = find.descendant(of: ship, matching: find.text(shipName));
        final badge = find.descendant(
          of: ship,
          matching: find.text('Lv. $level'),
        );
        expect(
          tester.getCenter(badge).dy,
          greaterThan(tester.getCenter(name).dy),
        );
        expect(
          find.descendant(of: ship, matching: find.byType(ShipPortrait)),
          findsOneWidget,
        );
        expect(tester.widget<Text>(name).maxLines, 2);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact header shows local generation time without summary or expansion labels',
    (tester) async {
      await _pump(
        tester,
        state: compositionImageFixture(),
        fleetIds: {1},
        generatedAt: DateTime(2026, 9, 12, 21, 6, 7).toUtc(),
      );
      final header = find.byKey(const Key('composition-image-header'));
      final timestamp = find.byKey(const Key('composition-generated-at'));
      expect(tester.widget<Text>(timestamp).data, '2026-09-12 21:06:07');
      expect(tester.getSize(header).height, lessThanOrEqualTo(44));
      expect(find.text('7 隻'), findsNothing);
      expect(find.text('1 艦隊'), findsNothing);
      expect(find.text('搭載数 · 現在'), findsNothing);
      expect(find.text('補強'), findsNothing);
      expect(
        tester
            .getTopLeft(
              find.byKey(const Key('composition-equipment-name-1-1-extra')),
            )
            .dx,
        greaterThan(
          tester
              .getTopRight(
                find.byKey(const Key('composition-equipment-name-1-1-1')),
              )
              .dx,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows each fleet totals, current air power range and formula 33 score',
    (tester) async {
      const state = GameState(
        admiralLevel: 20,
        fleets: [
          Fleet(id: 1, name: '第一隊', shipIds: [1, 2]),
          Fleet(id: 2, name: '第二隊', shipIds: [3]),
        ],
        masterShips: {
          101: MasterShip(
            id: 101,
            name: '甲',
            shipTypeId: 11,
            speed: 15,
            slotCount: 1,
            slotCapacities: [18],
          ),
          102: MasterShip(id: 102, name: '乙', shipTypeId: 3, speed: 5),
        },
        ships: {
          1: OwnedShip(
            id: 1,
            masterId: 101,
            level: 80,
            firepower: 58,
            torpedo: 40,
            antiAir: 44,
            antiSub: 30,
            lineOfSight: 25,
            slotIds: [7001],
            onSlot: [4],
            extraSlotId: 0,
          ),
          2: OwnedShip(
            id: 2,
            masterId: 102,
            level: 64,
            firepower: 40,
            torpedo: 60,
            antiAir: 30,
            antiSub: 45,
            lineOfSight: 16,
            extraSlotId: 0,
          ),
          3: OwnedShip(
            id: 3,
            masterId: 102,
            level: 7,
            lineOfSight: 36,
            extraSlotId: 0,
          ),
        },
        masterSlotItems: {
          201: MasterSlotItem(
            id: 201,
            name: '烈風',
            antiAir: 10,
            type: [0, 0, 6, 6, 0],
          ),
        },
        slotItems: {
          7001: OwnedSlotItem(
            id: 7001,
            masterId: 201,
            level: 10,
            proficiency: 6,
          ),
        },
      );
      // Displaying maximum plane counts must not change the current fleet totals.
      await _pump(
        tester,
        state: state,
        fleetIds: {1, 2},
        mode: CompositionPlaneCountMode.maximum,
      );
      for (final (field, expected) in [
        ('speed', '低速'),
        ('total-level', '144'),
        ('firepower', '98'),
        ('torpedo', '100'),
        ('anti-air', '74'),
        ('anti-sub', '75'),
        ('air-power', '40+'),
        ('line-of-sight', '9.00'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key('composition-metric-1-$field')),
            matching: find.text(expected),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('composition-metric-2-total-level')),
          matching: find.text('7'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('composition-metric-2-line-of-sight')),
          matching: find.text('8.00'),
        ),
        findsOneWidget,
      );

      for (final missing in [
        state.copyWith(admiralLevel: 0),
        state.copyWith(slotItems: {}),
      ]) {
        await _pump(tester, state: missing, fleetIds: {1});
        final missingLabel = lookupAppLocalizations(const Locale('ja')).noValue;
        expect(
          find.descendant(
            of: find.byKey(const Key('composition-metric-1-line-of-sight')),
            matching: find.text(missingLabel),
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps aircraft details beside equipment names and shows ship luck above level',
    (tester) async {
      await _pump(
        tester,
        state: compositionImageFixture(),
        fleetIds: {1},
        areaId: 47,
        baseIds: {1},
      );
      expect(find.text('運 18'), findsOneWidget);
      for (final suffix in ['1-1-1', '1-1-3', 'base-47-1-1']) {
        final name = find.byKey(Key('composition-equipment-name-$suffix'));
        final proficiency = find.byKey(Key('composition-proficiency-$suffix'));
        final improvement = find.descendant(
          of: find.byKey(Key('composition-slot-$suffix')),
          matching: find.text(
            suffix == '1-1-1'
                ? '★6'
                : suffix == '1-1-3'
                ? '★10'
                : '★4',
          ),
        );
        final count = find.byKey(Key('composition-plane-count-$suffix'));
        for (final detail in [proficiency, improvement, count]) {
          expect(
            tester.getTopLeft(detail).dy,
            greaterThan(tester.getTopLeft(name).dy),
          );
        }
      }
      for (final prefix in ['1-1', 'base-47-1']) {
        for (var slot = 1; slot <= 4; slot++) {
          expect(
            find.descendant(
              of: find.byKey(Key('composition-slot-$prefix-$slot')),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    widget.data == '$slot' &&
                    widget.key != Key('composition-plane-count-$prefix-$slot'),
              ),
            ),
            findsNothing,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shows zero surviving aircraft and individual maximum before master fallback',
    (tester) async {
      final state = compositionImageFixture();
      await _pump(tester, state: state, fleetIds: {1});
      final firstCount = find.byKey(const Key('composition-plane-count-1-1-1'));
      final thirdCount = find.byKey(const Key('composition-plane-count-1-1-3'));
      expect(tester.widget<Text>(firstCount).data, '0');
      expect(tester.widget<Text>(thirdCount).data, '11');

      await _pump(
        tester,
        state: state,
        fleetIds: {1},
        mode: CompositionPlaneCountMode.maximum,
      );
      expect(tester.widget<Text>(firstCount).data, '6');
      expect(tester.widget<Text>(thirdCount).data, '24');

      await _pump(
        tester,
        state: state,
        fleetIds: {1},
        mode: CompositionPlaneCountMode.hidden,
      );
      expect(firstCount, findsNothing);
      expect(thirdCount, findsNothing);
      expect(
        find.byKey(const Key('composition-proficiency-1-1-1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selects land bases by both area and base ID and preserves squadron gaps',
    (tester) async {
      await _pump(
        tester,
        state: compositionImageFixture(),
        areaId: 47,
        baseIds: {1, 3},
      );
      expect(find.text('第一航空隊'), findsOneWidget);
      expect(find.text('本土防空隊'), findsOneWidget);
      expect(find.text('第二航空隊'), findsNothing);
      expect(find.text('別海域の航空隊'), findsNothing);
      expect(
        find.byKey(const Key('composition-slot-base-47-1-2')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('composition-plane-count-base-47-1-1')),
            )
            .data,
        '0',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'builds all four fleets including seventh ship and three bases beyond viewport',
    (tester) async {
      await _pump(
        tester,
        state: compositionImageFixture(),
        fleetIds: {1, 2, 3, 4},
        areaId: 47,
        baseIds: {1, 2, 3},
      );
      final image = find.byKey(const Key('composition-image-card'));
      expect(tester.getSize(image).width, 1200);
      expect(tester.getSize(image).height, greaterThan(2200));
      expect(find.byKey(const Key('composition-ship-1-7')), findsOneWidget);
      expect(find.byKey(const Key('composition-ship-4-25')), findsOneWidget);
      expect(find.byKey(const Key('composition-base-47-3')), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(GridView), findsNothing);
      final longName = tester.widget<Text>(
        find.byKey(const Key('composition-equipment-name-1-1-3')),
      );
      expect(longName.maxLines, 1);
      expect(longName.softWrap, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders missing records and empty selection without throwing', (
    tester,
  ) async {
    const state = GameState(
      fleets: [
        Fleet(id: 1, name: '自定义名称', shipIds: [999, 1]),
      ],
      ships: {
        1: OwnedShip(id: 1, masterId: 999, level: 1, slotIds: [999]),
      },
    );
    await _pump(tester, state: state, fleetIds: {1});
    expect(find.text('自定义名称'), findsOneWidget);
    expect(find.byKey(const Key('composition-ship-1-999')), findsOneWidget);
    expect(find.byKey(const Key('composition-slot-1-1-1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('composition-fleet-metrics-1')),
        matching: find.text(lookupAppLocalizations(const Locale('ja')).noValue),
      ),
      findsNWidgets(9),
    );
    expect(tester.takeException(), isNull);
    await _pump(tester, state: GameState.empty);
    expect(find.byKey(const Key('composition-image-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required GameState state,
  Set<int> fleetIds = const {},
  int? areaId,
  Set<int> baseIds = const {},
  CompositionPlaneCountMode mode = CompositionPlaneCountMode.current,
  DateTime? generatedAt,
  bool recordMode = false,
  bool isCombinedFleet = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1300, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'CompositionTestFont'),
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: CompositionImageCard(
              state: state,
              fleetIds: fleetIds,
              landBaseAreaId: areaId,
              landBaseIds: baseIds,
              planeCountMode: mode,
              generatedAt: generatedAt ?? DateTime(2026, 9, 12, 21, 6, 7),
              recordMode: recordMode,
              isCombinedFleet: isCombinedFleet,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
