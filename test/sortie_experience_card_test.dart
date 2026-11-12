import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_resource_checklist.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/flat_underline_tabs.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_dashboard_content.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_card.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_controller.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_row.dart';
import 'package:yahagi_kancolle_browser/src/theme/app_palette.dart';
import 'package:yahagi_kancolle_browser/src/widgets/app_segmented_style.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _clearButton = Key('sortie-exp-clear-total');
const _clearDialog = Key('sortie-exp-clear-dialog');
const _clearCancel = Key('sortie-exp-clear-cancel');
const _clearConfirm = Key('sortie-exp-clear-confirm');
const _filterButton = Key('sortie-exp-filter-total');
const _filterDialog = Key('sortie-exp-filter-dialog');
const _filterDone = Key('sortie-exp-filter-done');
const _filterReset = Key('sortie-exp-filter-reset');
const _nativeDialog = MethodChannel(
  'app.yahagi.kancollebrowser/native_warning',
);

void main() {
  testWidgets('a tracking action from the previous account is ignored', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester);
    await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
    await tester.pumpAndSettle();
    final tracking = find.byKey(const Key('sortie-exp-tracking-switch'));
    final oldAction = tester.widget<Switch>(tracking).onChanged!;
    final press = await tester.startGesture(tester.getCenter(tracking));

    fixture.accountSession.selectMember(100);
    await fixture.controller.idle;
    await fixture.controller.setTrackingEnabled(true);
    await tester.pumpAndSettle();
    await press.up();
    await fixture.controller.idle;
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(tracking).value, isTrue);

    oldAction(false);
    await fixture.controller.idle;
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(tracking).value, isTrue);
  });

  setUp(() => GameStateController.disableTimerForTest = true);
  tearDown(() => GameStateController.disableTimerForTest = false);

  testWidgets('warehouse spending shares total roster and opens ship details', (
    tester,
  ) async {
    const leaders = {
      'fuel': 111,
      'ammo': 110,
      'steel': 109,
      'bauxite': 108,
      'buckets': 107,
    };
    const zero = {'fuel': 0, 'ammo': 0, 'steel': 0, 'bauxite': 0, 'buckets': 0};
    await _Fixture.mount(
      tester,
      width: 180,
      textScale: 1.4,
      initialPreferences: _totalPreferences(
        11,
        resourceLedger: {
          'version': 1,
          'incomplete': false,
          'unallocated': zero,
          'ships': [
            for (final MapEntry(key: resource, value: id) in leaders.entries)
              {
                'id': id,
                'supply': {
                  ...zero,
                  if (const ['fuel', 'ammo', 'bauxite'].contains(resource))
                    resource: 25,
                },
                'repair': {
                  ...zero,
                  if (resource == 'steel' || resource == 'buckets') resource: 3,
                },
                'pending': zero,
                'incomplete': false,
              },
          ],
        },
      ),
    );

    Future<void> tap(Key key) async {
      final target = find.byKey(key);
      expect(target, findsOneWidget);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap(const Key('sortie-exp-tab-total'));
    expect(find.byKey(const Key('sortie-exp-value-101')), findsOneWidget);
    await tap(const Key('sortie-exp-total-tab-consumption'));
    expect(find.text('本轮仓库支出'), findsOneWidget);
    final summary = find.byKey(const Key('sortie-exp-resource-summary'));
    expect(
      find.descendant(of: summary, matching: find.text('桶')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.text('高速修复材')),
      findsNothing,
    );
    expect(find.text('MVP'), findsNothing);
    expect(find.text('统计已确认归属的补给、入渠和用桶。'), findsNothing);
    expect(find.byKey(const Key('sortie-exp-value-101')), findsNothing);
    expect(find.byType(SortieExperienceShipName), findsNWidgets(10));
    expect(find.byType(SortieExperienceProgress), findsNWidgets(10));
    expect(find.text('未统计'), findsWidgets);
    await tap(const Key('sortie-exp-total-next'));
    expect(find.byType(SortieExperienceShipName), findsOneWidget);
    await tap(const Key('sortie-exp-resource-open-111'));
    expect(find.byKey(const Key('sortie-exp-resource-dialog')), findsOneWidget);
    expect(find.text('出击补给支出'), findsOneWidget);
    expect(find.text('入渠与加速'), findsOneWidget);
    expect(find.text('本轮待补给'), findsOneWidget);
    expect(find.text('舰上消耗'), findsNothing);
    await tap(const Key('sortie-exp-resource-close'));
    await tap(const Key('sortie-exp-total-tab-experience'));
    expect(find.byKey(const Key('sortie-exp-value-111')), findsOneWidget);
    expect(find.byKey(const Key('sortie-exp-resource-sort')), findsNothing);

    await tap(const Key('sortie-exp-total-tab-consumption'));
    for (final MapEntry(key: resource, value: id) in leaders.entries) {
      await tap(const Key('sortie-exp-resource-sort'));
      expect(find.byType(MenuItemButton), findsNWidgets(5));
      expect(find.byType(AlertDialog), findsNothing);
      await tap(Key('sortie-exp-resource-sort-$resource'));
      expect(find.text('1 / 2'), findsOneWidget);
      final firstShip = find.byKey(Key('sortie-exp-ship-$id'));
      expect(firstShip, findsOneWidget);
      expect(
        tester.getTopLeft(firstShip).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('sortie-exp-ship-101'))).dy,
        ),
      );
      if (resource == 'buckets') {
        Text amount(String value) => tester.widget<Text>(
          find.descendant(of: firstShip, matching: find.text(value)).first,
        );
        expect(amount('3').style?.color, amount('0').style?.color);
      }
    }
    await tap(const Key('sortie-exp-total-tab-experience'));
    expect(find.byKey(const Key('sortie-exp-value-101')), findsOneWidget);
    expect(find.byKey(const Key('sortie-exp-value-111')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('warehouse spending resource layout', () {
    const font = 'HarmonyOS_Sans_SC';
    const resources = ['fuel', 'ammo', 'steel', 'bauxite', 'buckets'];
    const labels = ['燃料', '弹药', '钢材', '铝土', '桶'];
    const sixDigits = [123456, 234567, 356789, 148912, 219];
    const formattedSixDigits = [
      '123,456',
      '234,567',
      '356,789',
      '148,912',
      '219',
    ];
    const sevenDigits = [1234567, 2345678, 3567891, 1489123, 219];
    const formattedSevenDigits = [
      '1,234,567',
      '2,345,678',
      '3,567,891',
      '1,489,123',
      '219',
    ];

    setUpAll(() async {
      await (FontLoader(
        font,
      )..addFont(rootBundle.load('assets/fonts/HarmonyOS_Sans_SC.ttf'))).load();
      await (FontLoader('HarmonyOS_Sans_Condensed')..addFont(
            rootBundle.load('assets/fonts/HarmonyOS_Sans_Condensed_Bold.ttf'),
          ))
          .load();
    });

    for (final (width, textScale, columns, values, formatted) in [
      (280.0, 1.0, 5, sixDigits, formattedSixDigits),
      (145.0, 1.0, 3, sixDigits, formattedSixDigits),
      (145.0, 1.0, 2, sevenDigits, formattedSevenDigits),
      (145.0, 1.4, 2, sixDigits, formattedSixDigits),
    ]) {
      testWidgets(
        'shows $columns columns at width $width, text scale $textScale, '
        'starting at ${formatted.first}',
        (tester) async {
          const zero = {
            'fuel': 0,
            'ammo': 0,
            'steel': 0,
            'bauxite': 0,
            'buckets': 0,
          };
          await _Fixture.mount(
            tester,
            width: width + 12, // The flat dashboard card adds 6 dp per side.
            textScale: textScale,
            style: PanelStyle.flat,
            fontFamily: font,
            initialPreferences: _totalPreferences(
              1,
              resourceLedger: {
                'version': 1,
                'incomplete': false,
                'unallocated': zero,
                'ships': [
                  {
                    'id': 101,
                    'supply': {
                      ...zero,
                      'fuel': values[0],
                      'ammo': values[1],
                      'bauxite': values[3],
                    },
                    'repair': {
                      ...zero,
                      'steel': values[2],
                      'buckets': values[4],
                    },
                    'pending': zero,
                    'incomplete': false,
                  },
                ],
              },
            ),
          );
          for (final tab in ['tab-total', 'total-tab-consumption']) {
            await tester.tap(find.byKey(Key('sortie-exp-$tab')));
            await tester.pumpAndSettle();
          }
          final summary = find.byKey(const Key('sortie-exp-resource-summary'));
          final bounds = tester.getRect(summary);
          expect(bounds.width, closeTo(width, .01));

          final numbers = [
            for (final value in formatted)
              find.descendant(of: summary, matching: find.text(value)),
          ];
          final rectangles = numbers.map(tester.getRect).toList();
          for (var index = 1; index < rectangles.length; index++) {
            final previous = rectangles[index - 1];
            final current = rectangles[index];
            if (index % columns == 0) {
              expect(current.top, greaterThan(previous.bottom));
              expect(current.left, closeTo(rectangles.first.left, .1));
            } else {
              expect(current.top, closeTo(previous.top, .1));
              expect(current.left, greaterThanOrEqualTo(previous.right - .1));
            }
          }

          for (var index = 0; index < resources.length; index++) {
            final group = find.descendant(
              of: summary,
              matching: find.byKey(
                Key('sortie-exp-resource-group-${resources[index]}'),
              ),
            );
            expect(
              find.descendant(of: group, matching: find.byType(Image)),
              findsOneWidget,
            );
            expect(
              find.descendant(of: group, matching: find.text(labels[index])),
              findsOneWidget,
            );
            expect(
              find.descendant(of: group, matching: numbers[index]),
              findsOneWidget,
            );
            final number = tester.renderObject<RenderParagraph>(numbers[index]);
            final painted = rectangles[index];
            expect(tester.widget<Text>(numbers[index]).style?.fontSize, 12);
            expect(number.textScaler.scale(12), closeTo(12 * textScale, .01));
            expect(painted.height, closeTo(number.size.height, .01));
            expect(painted.width, closeTo(number.size.width, .01));
            expect(number.didExceedMaxLines, isFalse);
            final text = TextPainter(
              text: number.text,
              textDirection: number.textDirection,
              textScaler: number.textScaler,
            )..layout();
            expect(painted.width, greaterThanOrEqualTo(text.width - .01));
            expect(painted.height, closeTo(text.height, .01));
            text.dispose();
            expect(bounds.inflate(.01).contains(painted.bottomRight), isTrue);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  testWidgets('warehouse sorting stays anchored in native game mode', (
    tester,
  ) async {
    final requests = <Map<Object?, Object?>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_nativeDialog, (call) async {
      if (call.method != 'show') return null;
      requests.add(Map<Object?, Object?>.from(call.arguments as Map));
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_nativeDialog, null));
    await _Fixture.mount(
      tester,
      nativeActivity: true,
      initialPreferences: _totalPreferences(2),
    );

    Future<void> tap(String suffix) async {
      final target = find.byKey(Key('sortie-exp-$suffix'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap('tab-total');
    await tap('total-tab-consumption');
    await tap('resource-sort');
    expect(requests, isEmpty);
    expect(find.byType(MenuItemButton), findsNWidgets(5));
    expect(find.byType(AlertDialog), findsNothing);
    final trigger = find.byKey(const Key('sortie-exp-resource-sort'));
    final fuel = find.byKey(const Key('sortie-exp-resource-sort-fuel'));
    final triggerBounds = tester.getRect(trigger);
    final optionBounds = tester.getRect(fuel);
    expect(optionBounds.left, closeTo(triggerBounds.left, 1));
    expect(optionBounds.width, closeTo(triggerBounds.width, 1));
    expect(optionBounds.top, greaterThanOrEqualTo(triggerBounds.bottom));

    await tap('resource-sort-buckets');
    expect(
      find.descendant(of: trigger, matching: find.text('桶')),
      findsOneWidget,
    );
    await tap('resource-sort');
    await tap('total-tab-experience');
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.byKey(const Key('sortie-exp-value-101')), findsOneWidget);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last sortie summary stays two by two at narrow width', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(
      tester,
      width: 145,
      textScale: 1.4,
      style: PanelStyle.flat,
    );
    await fixture.start();
    await fixture.settle([-1, 750, 1500], mainMvp: 1);
    await fixture.returnToPort();
    expect(find.text('上次出击'), findsOneWidget);

    Rect label(String text) => tester.getRect(find.text(text));
    final area = label('海域');
    final fleet = label('出击舰队');
    final settled = label('已结算');
    final total = label('上次舰队合计');
    expect(area.left, closeTo(settled.left, .1));
    expect(fleet.left, closeTo(total.left, .1));
    expect(area.right, lessThan(fleet.left));
    expect(settled.right, lessThan(total.left));
    expect(area.center.dy, closeTo(fleet.center.dy, .1));
    expect(settled.center.dy, closeTo(total.center.dy, .1));
    expect(settled.top, greaterThan(area.bottom));
    expect(find.text('+2,250 EXP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (width, style, textScale) in [
    (320.0, PanelStyle.card, 1.0),
    (180.0, PanelStyle.flat, 1.4),
  ]) {
    testWidgets('total ships paginate after filtering at width $width', (
      tester,
    ) async {
      final fixture = await _Fixture.mount(
        tester,
        width: width,
        style: style,
        textScale: textScale,
        initialPreferences: {
          ..._totalPreferences(21),
          ..._totalPreferences(11, memberId: 100),
        },
      );
      final previous = find.byKey(const Key('sortie-exp-total-previous'));
      final next = find.byKey(const Key('sortie-exp-total-next'));
      final indicator = find.byKey(const Key('sortie-exp-total-page'));

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      void expectPage(int first, int last, String label) {
        expect(
          find.byType(SortieExperienceShipName),
          findsNWidgets(last - first + 1),
        );
        for (var id = 101; id <= 121; id++) {
          expect(
            find.byKey(Key('sortie-exp-ship-$id')),
            id >= first && id <= last ? findsOneWidget : findsNothing,
          );
        }
        expect(tester.widget<Text>(indicator).data, label);
      }

      await tap(find.byKey(const Key('sortie-exp-tab-total')));
      expectPage(101, 110, '1 / 3');
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      await tap(next);
      expectPage(111, 120, '2 / 3');
      await fixture.controller.setTrackingEnabled(false);
      await tester.pumpAndSettle();
      expectPage(111, 120, '2 / 3');
      await tap(next);
      expectPage(121, 121, '3 / 3');
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tap(previous);
      expectPage(111, 120, '2 / 3');

      final archive = fixture.controller.totals;
      await tap(find.byKey(_filterButton));
      final choice = find.byKey(const Key('sortie-exp-filter-ship-101'));
      await tap(choice);
      expectPage(111, 120, '2 / 3');
      await tap(find.byKey(_filterDone));
      expectPage(102, 111, '1 / 2');
      expect(fixture.controller.totals, archive);
      await tap(next);
      expectPage(112, 121, '2 / 2');

      final oldPageAction = tester.widget<IconButton>(previous).onPressed!;
      fixture.accountSession.selectMember(100);
      await fixture.controller.initialize();
      await tester.pumpAndSettle();
      oldPageAction();
      await tester.pumpAndSettle();
      expectPage(101, 110, '1 / 2');
      expect(fixture.controller.totalSorties, 3);
      await fixture.controller.clearTotal();
      await fixture.controller.idle;
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);
      expect(find.byType(SortieExperienceShipName), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ten total ships fit without pagination controls', (
    tester,
  ) async {
    await _Fixture.mount(tester, initialPreferences: _totalPreferences(10));
    await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
    await tester.pumpAndSettle();
    expect(find.byType(SortieExperienceShipName), findsNWidgets(10));
    expect(find.byKey(const Key('sortie-exp-total-page')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'total percentages include hidden ships and follow confirmed loss',
    (tester) async {
      final fixture = await _Fixture.mount(tester, width: 180, textScale: 1.4);
      await fixture.recordTotal();
      await fixture.controller.setHiddenTotalShipIds({
        102,
      }, expectedAccount: fixture.accountSession.current);
      await tester.pumpAndSettle();
      expect(find.text('合计 960 EXP'), findsOneWidget);
      expect(fixture.percentage(101), '25%');
      expect(fixture.mvp(101), '0');
      expect(find.byKey(const Key('sortie-exp-ship-102')), findsNothing);

      await fixture.destroyShips('102');
      expect(find.text('合计 240 EXP'), findsOneWidget);
      expect(fixture.percentage(101), '100%');
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero cumulative EXP displays zero percentages', (tester) async {
    final fixture = await _Fixture.mount(
      tester,
      initialPreferences: _totalPreferences(2, fixedExperience: 0),
    );
    await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
    await tester.pumpAndSettle();
    expect(find.text('合计 0 EXP'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(2));
    expect(fixture.mvp(101), '—');
    expect(fixture.mvp(102), '—');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lost ships clamp the last page without treating cleanup as a filter edit',
    (tester) async {
      final fixture = await _Fixture.mount(
        tester,
        initialPreferences: _totalPreferences(22),
      );
      await fixture.controller.setHiddenTotalShipIds({
        101,
      }, expectedAccount: fixture.accountSession.current);
      await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
      await tester.pumpAndSettle();
      final next = find.byKey(const Key('sortie-exp-total-next'));
      final page = find.byKey(const Key('sortie-exp-total-page'));
      for (var index = 0; index < 2; index++) {
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<Text>(page).data, '3 / 3');
      expect(find.byKey(const Key('sortie-exp-ship-122')), findsOneWidget);

      await fixture.destroyShips('101,122');
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      expect(tester.widget<Text>(page).data, '2 / 2');
      expect(find.byType(SortieExperienceShipName), findsNWidgets(10));
      expect(find.byKey(const Key('sortie-exp-ship-112')), findsOneWidget);

      await fixture.destroyShips(
        [for (var id = 102; id <= 121; id++) id].join(','),
      );
      expect(page, findsNothing);
      expect(find.byType(SortieExperienceShipName), findsNothing);
      expect(find.text('合计 0 EXP'), findsOneWidget);
      expect(fixture.controller.totalSorties, 3);
      expect(tester.takeException(), isNull);
    },
  );

  for (final native in [false, true]) {
    testWidgets('open ship filter drops lost draft rows, native=$native', (
      tester,
    ) async {
      final port = _ShipChecklistPort();
      addTearDown(port.source.close);
      final fixture = await _Fixture.mount(
        tester,
        nativeActivity: native,
        nativeChecklistPort: port,
      );
      await fixture.recordTotal();
      await tester.tap(find.byKey(_filterButton));
      await tester.pumpAndSettle();
      final lostChoice = find.byKey(const Key('sortie-exp-filter-ship-101'));
      if (native) {
        port.emit('101', 1, checked: false);
      } else {
        await tester.tap(lostChoice);
      }
      await tester.pumpAndSettle();

      await fixture.destroyShips('101');
      if (native) {
        expect((port.updated.last['items'] as List).map((row) => row['id']), [
          '102',
        ]);
        port.emit('101', 2, checked: false);
        port.result.complete(NativeGameWarningAction.acknowledge);
      } else {
        expect(lostChoice, findsNothing);
        expect(
          find.byKey(const Key('sortie-exp-filter-ship-102')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(_filterDone));
      }
      await tester.pumpAndSettle();
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      expect(fixture.controller.totals.map((ship) => ship.ownedShipId), [102]);
      expect(fixture.controller.totalSorties, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'total ship picker applies drafts on Done with matching capsules',
    (tester) async {
      final fixture = await _Fixture.mount(tester);
      await fixture.recordTotal();
      final filter = find.byKey(_filterButton);
      final clear = find.byKey(_clearButton);
      final dialog = find.byKey(_filterDialog);
      expect(tester.getSize(filter), tester.getSize(clear));
      expect(
        find.descendant(of: filter, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: filter,
          matching: find.byIcon(Icons.filter_alt_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(filter).style!.backgroundColor!.resolve({}),
        const Color(0xfff0c06f),
      );

      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(tester.element(dialog)),
        isA<GameSafetyDialogRoute>(),
      );
      expect(find.text('选择显示舰娘'), findsOneWidget);
      final ship101 = find.byKey(const Key('sortie-exp-filter-ship-101'));
      final ship102 = find.byKey(const Key('sortie-exp-filter-ship-102'));
      await tester.tap(ship101);
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(ship101).value, isFalse);
      expect(find.byKey(const Key('sortie-exp-ship-101')), findsOneWidget);
      expect(find.byKey(const Key('sortie-exp-ship-102')), findsOneWidget);
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.controller.totals.map((ship) => ship.experience), [
        720,
        240,
      ]);
      await tester.tap(ship102);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(ship102).value, isFalse);
      expect(find.byKey(const Key('sortie-exp-ship-102')), findsOneWidget);
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(ship101).value, isTrue);
      expect(tester.widget<CheckboxListTile>(ship102).value, isTrue);
      await tester.tap(ship101);
      await tester.tap(ship102);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_filterDone));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.text('当前未选择显示舰娘'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sortie-exp-tab-sortie')));
      await tester.pumpAndSettle();
      expect(fixture.exp(101).data, '+240');
      await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
      await tester.pumpAndSettle();
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(ship101).value, isFalse);
      await tester.tap(find.byKey(_filterReset));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(ship101).value, isTrue);
      expect(find.text('当前未选择显示舰娘'), findsOneWidget);
      await tester.tap(find.byKey(_filterDone));
      await tester.pumpAndSettle();
      expect(fixture.exp(101).data, '+240');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'total ship picker uses the native checklist and rejects stale accounts',
    (tester) async {
      final port = _ShipChecklistPort();
      addTearDown(port.source.close);
      final fixture = await _Fixture.mount(
        tester,
        nativeActivity: true,
        nativeChecklistPort: port,
      );
      await fixture.recordTotal();
      await tester.tap(find.byKey(_filterButton));
      await tester.pumpAndSettle();
      final request = port.shown.single;
      expect(request['kind'], 'moduleDisplay');
      expect(request['title'], '选择显示舰娘');
      expect(request['labels'], {'acknowledge': '完成编辑'});
      expect(find.byKey(_filterDialog), findsNothing);
      expect((request['items']! as List).map((row) => row['id']), [
        '102',
        '101',
      ]);
      port.emit('101', 1, checked: false);
      await tester.pump();
      expect(find.byKey(const Key('sortie-exp-ship-101')), findsOneWidget);
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
      expect(port.updated.last['appliedChangeId'], 1);
      expect((port.updated.last['items'] as List).last['checked'], isFalse);
      expect(fixture.controller.totalSorties, 1);

      fixture.accountSession.selectMember(100);
      port.emit('102', 2, checked: false);
      await fixture.controller.idle;
      await tester.pumpAndSettle();
      expect(port.dismissed, [request['id']]);
      fixture.accountSession.selectMember(99);
      await fixture.controller.initialize();
      await tester.pumpAndSettle();
      expect(fixture.exp(101).data, '+240');
      expect(fixture.controller.hiddenTotalShipIds, isEmpty);
    },
  );

  testWidgets('native ship picker commits only when Done is returned', (
    tester,
  ) async {
    final port = _ShipChecklistPort();
    addTearDown(port.source.close);
    final fixture = await _Fixture.mount(
      tester,
      nativeActivity: true,
      nativeChecklistPort: port,
    );
    await fixture.recordTotal();
    await tester.tap(find.byKey(_filterButton));
    await tester.pumpAndSettle();
    expect(port.shown.single['backCancels'], isTrue);
    expect(port.shown.single['protectInputOnDismiss'], isFalse);

    port.emit('101', 1, checked: false);
    await tester.pump();
    expect(fixture.controller.hiddenTotalShipIds, isEmpty);
    port.result.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(fixture.controller.hiddenTotalShipIds, {101});
    expect(find.byKey(const Key('sortie-exp-ship-101')), findsNothing);
    expect(find.byKey(const Key('sortie-exp-ship-102')), findsOneWidget);
  });

  testWidgets('total ship picker keeps a 65-ship list and controls reachable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final port = _ShipChecklistPort();
    addTearDown(port.source.close);
    final fixture = await _Fixture.mount(
      tester,
      locale: const Locale('en'),
      textScale: 1.4,
      nativeActivity: true,
      nativeChecklistPort: port,
      initialPreferences: {
        'account.99.sortieExperience.v1': jsonEncode({
          'version': 1,
          'memberId': 99,
          'tracking': true,
          'totalSorties': 11,
          'totals': [
            for (var id = 101; id < 166; id++)
              {
                'ownedShipId': id,
                'masterShipId': id,
                'name': 'Tracked ship $id',
                'fleetId': 1,
                'position': 0,
                'experience': 9000000 + id,
                'retreated': false,
              },
          ],
        }),
      },
    );
    await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_filterButton));
    await tester.pumpAndSettle();
    final dialog = find.byKey(_filterDialog);
    expect(ModalRoute.of(tester.element(dialog)), isA<GameSafetyDialogRoute>());
    expect(port.shown, isEmpty);
    final lastShip = find.byKey(const Key('sortie-exp-filter-ship-101'));
    final scrollable = find.descendant(
      of: find.byKey(const Key('sortie-exp-filter-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(lastShip, 150, scrollable: scrollable);
    await tester.tap(lastShip);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(lastShip).value, isFalse);
    expect(fixture.controller.hiddenTotalShipIds, isEmpty);
    expect(fixture.controller.totalSorties, 11);
    expect(fixture.controller.totals, hasLength(65));
    expect(find.byKey(_filterDone).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(_filterDone));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(fixture.controller.hiddenTotalShipIds, {101});
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows zero and earned EXP in yellow, then keeps unnumbered '
      'green rows in fleet order after returning', (tester) async {
    final fixture = await _Fixture.mount(tester);
    expect(find.text('出击经验'), findsOneWidget);
    expect(find.text('暂无出击记录'), findsOneWidget);

    await fixture.start();
    expect(find.text('本次出击'), findsOneWidget);
    expect(find.text('已结算'), findsOneWidget);
    expect(find.text('0 场战斗'), findsOneWidget);
    expect(find.text('海域'), findsOneWidget);
    expect(find.text('5-3'), findsOneWidget);
    expect(find.text('出击舰队'), findsOneWidget);
    expect(find.text('第 1 舰队'), findsOneWidget);
    final amount = find.byKey(const Key('sortie-exp-sortie-experience'));
    expect(find.text('本次舰队合计'), findsOneWidget);
    expect(tester.widget<Text>(amount).data, '+0 EXP');
    expect(tester.widget<Text>(amount).style?.color, const Color(0xfff7cf75));
    final mapStyle = tester.widget<Text>(find.text('5-3')).style;
    final amountStyle = tester.widget<Text>(amount).style;
    expect(amountStyle?.fontSize, mapStyle?.fontSize);
    expect(amountStyle?.fontWeight, mapStyle?.fontWeight);
    expect(find.byKey(const Key('sortie-exp-position-101')), findsNothing);
    expect(fixture.exp(101).data, '0');
    expect(fixture.percentage(101), '0%');
    expect(fixture.mvp(101), '0');
    expect(fixture.level(101), 'Lv.2');
    expect(fixture.next(101), 'Next. 140');
    expect(fixture.exp(101).style?.color, const Color(0xfff7cf75));

    await fixture.settle([-1, 240, 720], mainMvp: 2);
    expect(fixture.level(101), 'Lv.3');
    expect(fixture.next(101), 'Next. 200');
    await fixture.moveToNextNode();
    await fixture.settle([-1, 240, 720], mainMvp: 2);
    expect(find.text('2 场战斗'), findsOneWidget);
    expect(tester.widget<Text>(amount).data, '+1,920 EXP');
    expect(fixture.exp(101).data, '+480');
    expect(fixture.exp(102).data, '+1,440');
    expect(fixture.percentage(101), '25%');
    expect(fixture.percentage(102), '75%');
    expect(fixture.mvp(101), '0');
    expect(fixture.mvp(102), '2');
    expect(fixture.level(101), 'Lv.4');
    expect(fixture.next(101), 'Next. 360');
    expect(fixture.exp(101).style?.color, const Color(0xfff7cf75));

    await fixture.returnToPort();
    expect(find.text('上次出击'), findsOneWidget);
    expect(find.text('上次舰队合计'), findsOneWidget);
    expect(tester.widget<Text>(amount).data, '+1,920 EXP');
    expect(tester.widget<Text>(amount).style?.color, const Color(0xff8adac7));
    expect(find.byKey(const Key('sortie-exp-position-101')), findsNothing);
    expect(find.byKey(const Key('sortie-exp-position-102')), findsNothing);
    expect(fixture.exp(101).style?.color, const Color(0xff8adac7));
    expect(fixture.exp(101).data, '+480');
    expect(fixture.mvp(102), '2');
    expect(fixture.next(101), 'Next. 360');
    expect(
      tester.getTopLeft(find.byKey(const Key('sortie-exp-ship-101'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('sortie-exp-ship-102'))).dy,
      ),
    );

    await fixture.start();
    expect(find.byKey(const Key('sortie-exp-position-101')), findsNothing);
    expect(fixture.exp(101).data, '0');
    expect(fixture.mvp(102), '0');
  });

  testWidgets('total capsule matches the fleet style and receives only '
      'tracked results after returning', (tester) async {
    final fixture = await _Fixture.mount(tester);
    await fixture.start();
    await fixture.settle([-1, 240, 720]);

    final total = find.byKey(const Key('sortie-exp-tab-total'));
    await tester.tap(total);
    await tester.pumpAndSettle();
    final segment = tester.widget<Material>(total);
    final context = tester.element(total);
    expect(segment.color, AppSegmentedStyle.selection(context, true));
    expect(segment.borderRadius, AppSegmentedStyle.itemRadius(compact: true));
    expect(find.text('海域'), findsNothing);
    expect(find.text('累计记录'), findsOneWidget);
    expect(find.text('全部舰船合计'), findsOneWidget);
    expect(find.text('总累计 0 场'), findsOneWidget);
    expect(find.text('出击'), findsOneWidget);
    final tracking = find.byKey(const Key('sortie-exp-tracking-switch'));
    final clear = find.byKey(const Key('sortie-exp-clear-total'));
    expect(
      tester.getRect(tracking).height,
      closeTo(tester.getSize(total).height, 0.01),
    );
    expect(tester.getSize(clear).height, tester.getSize(total).height);

    await tester.tap(tracking);
    await tester.pumpAndSettle();
    await fixture.moveToNextNode();
    await fixture.settle([-1, 500, 900]);
    expect(find.text('总累计 0 场'), findsOneWidget);
    expect(find.byKey(const Key('sortie-exp-ship-101')), findsNothing);

    await fixture.returnToPort();
    expect(find.text('总累计 1 场'), findsOneWidget);
    final amount = tester.widget<Text>(
      find.byKey(const Key('sortie-exp-total-experience')),
    );
    expect(amount.data, '合计 1,400 EXP');
    expect(amount.style?.color, const Color(0xff8adac7));
    final countStyle = tester.widget<Text>(find.text('总累计 1 场')).style;
    expect(amount.style?.fontSize, countStyle?.fontSize);
    expect(amount.style?.fontWeight, countStyle?.fontWeight);
    expect(fixture.exp(101).data, '+500');
    expect(fixture.exp(102).data, '+900');
    expect(fixture.level(101), 'Lv.4');
    expect(fixture.next(101), 'Next. 100');
    expect(fixture.exp(101).style?.color, const Color(0xff8adac7));
    expect(find.byKey(const Key('sortie-exp-position-101')), findsNothing);

    await fixture.start();
    await fixture.settle([-1, 180, 80]);
    expect(find.text('总累计 1 场'), findsOneWidget);
    expect(fixture.exp(101).data, '+500');
    expect(fixture.level(101), 'Lv.5');
    expect(fixture.next(101), 'Next. 420');

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(fixture.controller.totalSorties, 1);
    expect(find.text('清理累计记录？'), findsOneWidget);
    final dialog = find.byKey(_clearDialog);
    expect(ModalRoute.of(tester.element(dialog)), isA<GameSafetyDialogRoute>());
    await tester.tap(find.byKey(_clearCancel));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.text('总累计 1 场'), findsOneWidget);

    final clearStyle = tester.widget<FilledButton>(clear).style!;
    expect(
      clearStyle.backgroundColor!.resolve({}),
      AppPalette.of(context).error,
    );
    expect(clearStyle.foregroundColor!.resolve({}), Colors.white);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_clearConfirm));
    expect(fixture.controller.totalSorties, 1);
    await tester.pumpAndSettle();
    expect(find.text('总累计 0 场'), findsOneWidget);
    expect(tester.widget<FilledButton>(clear).onPressed, isNull);
    await tester.tap(find.byKey(const Key('sortie-exp-tab-sortie')));
    await tester.pumpAndSettle();
    expect(fixture.exp(101).data, '+180');
  });

  testWidgets('clear confirmation handles Back and leaves the total intact', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester);
    await fixture.recordTotal();
    await tester.tap(find.byKey(_clearButton));
    await tester.pumpAndSettle();
    expect(find.byKey(_clearDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_clearDialog), findsNothing);
    expect(fixture.controller.totalSorties, 1);
  });

  testWidgets('clear confirmation is revoked when the account changes', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester);
    await fixture.recordTotal();
    final clear = find.byKey(_clearButton);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    final staleConfirm = tester
        .widget<FilledButton>(find.byKey(_clearConfirm))
        .onPressed!;

    fixture.accountSession.selectMember(100);
    await fixture.controller.idle;
    await tester.pump();
    fixture.accountSession.selectMember(99);
    await fixture.controller.idle;
    await tester.pump();
    staleConfirm();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(_clearDialog), findsNothing);
    expect(find.text('总累计 1 场'), findsOneWidget);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.byKey(_clearDialog), findsOneWidget);
    await tester.tap(find.byKey(_clearCancel));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'clear confirmation uses one native request and respects its result',
    (tester) async {
      final requests = <Map<Object?, Object?>>[];
      final replies = <Completer<Map<String, Object?>>>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_nativeDialog, (call) async {
        if (call.method != 'show') return null;
        requests.add(Map<Object?, Object?>.from(call.arguments as Map));
        final reply = Completer<Map<String, Object?>>();
        replies.add(reply);
        return reply.future;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(_nativeDialog, null),
      );
      final fixture = await _Fixture.mount(tester, nativeActivity: true);
      await fixture.recordTotal();

      final clear = find.byKey(_clearButton);
      await tester.tap(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(fixture.controller.totalSorties, 1);
      expect(find.byKey(_clearDialog), findsNothing);
      expect(requests.single['kind'], 'surfaceDialog');
      expect(requests.single.containsKey('protectInputOnDismiss'), isFalse);
      expect(requests.single['title'], '清理累计记录？');
      expect(requests.single['actions'], ['cancel', 'confirm']);
      expect(requests.single['dismissible'], isFalse);
      replies.single.complete({'action': 'cancel', 'checked': false});
      await tester.pumpAndSettle();
      expect(fixture.controller.totalSorties, 1);

      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      replies.last.complete({'action': 'confirm', 'checked': false});
      await tester.pumpAndSettle();
      expect(fixture.controller.totalSorties, 0);
    },
  );

  testWidgets('combined sortie displays main and escort fleets separately', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester, combined: true);
    await fixture.start();
    expect(find.text('主力舰队'), findsOneWidget);
    expect(find.text('护卫舰队'), findsOneWidget);
    expect(fixture.exp(201).data, '0');
    expect(find.text('矢矧改二乙'), findsNWidgets(2));

    await fixture.settle([-1, 240, 720], escort: [-1, 300, 450]);
    expect(fixture.exp(101).data, '+240');
    expect(fixture.exp(201).data, '+300');
    expect(fixture.exp(202).data, '+450');
    expect(fixture.next(101), 'Next. 200');
    expect(fixture.next(201), 'Next. 160');
    await fixture.returnToPort();
    expect(find.byKey(const Key('sortie-exp-position-201')), findsNothing);
    expect(find.text('护卫舰队'), findsOneWidget);
    expect(fixture.exp(201).data, '+300');
  });

  testWidgets('partial rewards distinguish confirmed zero from missing EXP', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester, combined: true);
    await fixture.start();
    expect(fixture.exp(201).data, '0');

    await fixture.settle([-1, 0, 720], escort: [-1, 300]);
    expect(fixture.exp(101).data, '0');
    expect(fixture.exp(102).data, '+720');
    expect(fixture.exp(201).data, '未捕获');
    expect(fixture.exp(202).data, '未捕获');

    await fixture.returnToPort();
    expect(fixture.exp(101).data, '0');
    expect(fixture.exp(201).data, '未捕获');
    expect(
      tester
          .widget<Text>(find.byKey(const Key('sortie-exp-sortie-experience')))
          .data,
      '+720 EXP',
    );
  });

  for (final (span, width, textScale, sideBySide) in [
    (2, 580.0, 1.0, true),
    (3, 740.0, 1.0, true),
    (1, 740.0, 1.0, false),
    (2, 400.0, 1.0, false),
    (2, 580.0, 1.4, false),
  ]) {
    testWidgets('combined sortie at HD 1×$span, width $width and '
        'text scale $textScale is ${sideBySide ? 'side by side' : 'stacked'}', (
      tester,
    ) async {
      final fixture = await _Fixture.mount(
        tester,
        combined: true,
        hdColumns: span,
        width: width,
        textScale: textScale,
      );
      await fixture.start();
      await fixture.settle([-1, 240, 720], escort: [-1, 300, 450]);
      final main = tester.getRect(find.byKey(const Key('sortie-exp-ship-101')));
      final escort = tester.getRect(
        find.byKey(const Key('sortie-exp-ship-201')),
      );
      if (sideBySide) {
        expect(escort.left, greaterThan(main.right));
        expect(escort.top, main.top);
      } else {
        expect(escort.left, main.left);
        expect(escort.top, greaterThan(main.bottom));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('narrow flat dashboard uses fleet underline tabs and exposes '
      'the same controls with larger English text', (tester) async {
    final fixture = await _Fixture.mount(
      tester,
      style: PanelStyle.flat,
      locale: const Locale('en'),
      textScale: 1.4,
      width: 180,
      combined: true,
      firstShipName: 'A very long ship name that must wrap and then truncate',
    );
    await fixture.start();
    await fixture.settle([-1, 1234567, 720], escort: [-1, 300, 450]);
    expect(find.byType(FlatUnderlineTabs), findsOneWidget);
    expect(find.text('This sortie'), findsOneWidget);
    expect(fixture.exp(101).data, '+1,234,567');
    final percentage = find.byKey(const Key('sortie-exp-percentage-101'));
    expect(tester.widget<Text>(percentage).data, '99.9%');
    final shipRow = find.byKey(const Key('sortie-exp-ship-101'));
    final shipName = find.descendant(
      of: shipRow,
      matching: find.text(
        'A very long ship name that must wrap and then truncate',
      ),
    );
    expect(tester.widget<Text>(shipName).overflow, TextOverflow.ellipsis);
    expect(tester.widget<Text>(shipName).maxLines, 2);
    final rowBounds = tester.getRect(shipRow);
    for (final metric in ['level', 'next', 'value', 'percentage', 'mvp']) {
      final cell = find.byKey(Key('sortie-exp-$metric-101'));
      final cellBounds = tester.getRect(cell);
      expect(cellBounds.left, greaterThan(tester.getRect(shipName).right));
      expect(cellBounds.right, lessThanOrEqualTo(rowBounds.right));
      expect(cellBounds.width, greaterThan(0));
    }
    await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sortie-exp-tracking-switch')), findsOneWidget);
    expect(find.byKey(const Key('sortie-exp-clear-total')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('180px combined card shows all twelve ships and fits every '
      'level, six-digit Next., percentage and MVP', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mainIds = [101, 102, 103, 104, 105, 106];
    const escortIds = [201, 202, 203, 204, 205, 206];
    const ids = [...mainIds, ...escortIds];
    const name = 'A very long ship name shared by all twelve ships';
    final fixture = await _Fixture.mount(
      tester,
      locale: const Locale('en'),
      textScale: 1.4,
      width: 180,
      initialState: GameState(
        memberId: 99,
        fleets: const [
          Fleet(id: 1, name: '', shipIds: mainIds),
          Fleet(id: 2, name: '', shipIds: escortIds),
        ],
        combinedFleetType: CombinedFleetType.carrierTaskForce,
        masterShips: const {1: MasterShip(id: 1, name: name, shipTypeId: 2)},
        ships: {
          for (final id in ids)
            id: OwnedShip(
              id: id,
              masterId: 1,
              level: 179,
              experience: 12100000,
              nextExperience: 900000,
            ),
        },
      ),
    );
    await fixture.start();
    await fixture.settle(
      [-1, 1201, 1202, 1203, 1204, 1205, 1206],
      escort: [-1, 1207, 1208, 1209, 1210, 1211, 1212],
      mainMvp: 1,
      escortMvp: 6,
    );

    expect(find.text(name), findsNWidgets(12));
    for (final (index, id) in ids.indexed) {
      final row = find.byKey(Key('sortie-exp-ship-$id'));
      expect(find.byKey(Key('sortie-exp-position-$id')), findsNothing);
      expect(fixture.level(id), 'Lv.179');
      expect(fixture.next(id), 'Next. 898,${799 - index}');
      expect(fixture.exp(id).data, '+1,${201 + index}');
      expect(fixture.mvp(id), id == 101 || id == 206 ? '1' : '0');

      final shipName = find.descendant(of: row, matching: find.text(name));
      expect(
        tester.renderObject<RenderParagraph>(shipName).didExceedMaxLines,
        isTrue,
      );
      final bounds = tester.getRect(row);
      final nameBounds = tester.getRect(shipName);
      final levelBounds = tester.getRect(
        find.byKey(Key('sortie-exp-level-$id')),
      );
      final nextBounds = tester.getRect(find.byKey(Key('sortie-exp-next-$id')));
      final valueBounds = tester.getRect(
        find.byKey(Key('sortie-exp-value-$id')),
      );
      final percentageBounds = tester.getRect(
        find.byKey(Key('sortie-exp-percentage-$id')),
      );
      final mvpBounds = tester.getRect(find.byKey(Key('sortie-exp-mvp-$id')));
      expect(nameBounds.right, lessThan(nextBounds.left));
      expect(levelBounds.bottom, lessThanOrEqualTo(nextBounds.top + 0.01));
      expect(nextBounds.right, lessThan(valueBounds.left));
      expect(
        valueBounds.bottom,
        lessThanOrEqualTo(percentageBounds.top + 0.01),
      );
      expect(valueBounds.right, lessThan(mvpBounds.left));
      expect(percentageBounds.right, lessThan(mvpBounds.left));
      for (final metric in [
        levelBounds,
        nextBounds,
        valueBounds,
        percentageBounds,
        mvpBounds,
      ]) {
        expect(metric.width, greaterThan(0));
        expect(metric.top, greaterThanOrEqualTo(bounds.top));
        expect(metric.right, lessThanOrEqualTo(bounds.right));
        expect(metric.bottom, lessThanOrEqualTo(bounds.bottom));
      }
      expect(
        find.descendant(of: row, matching: find.text('EXP')),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.byType(Text)),
        findsNWidgets(6),
      );
    }
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object> _totalPreferences(
  int count, {
  int memberId = 99,
  int? fixedExperience,
  Map<String, Object?>? resourceLedger,
}) => {
  'account.$memberId.sortieExperience.v1': jsonEncode({
    'version': 1,
    'memberId': memberId,
    'tracking': true,
    'totalSorties': 3,
    'resourceLedger': ?resourceLedger,
    'totals': [
      for (var index = 0; index < count; index++)
        {
          'ownedShipId': 101 + index,
          'masterShipId': 1,
          'name': 'Ship ${101 + index}',
          'fleetId': 1,
          'position': 0,
          'experience': fixedExperience ?? 1000 - index,
          'retreated': false,
        },
    ],
  }),
};

final class _Fixture {
  _Fixture(this.tester, GameState initialState)
    : accountSession = AccountSession(initialMemberId: 99),
      gameState = GameStateController(initialState: initialState);

  final WidgetTester tester;
  final AccountSession accountSession;
  final GameStateController gameState;
  late final SortieExperienceController controller = SortieExperienceController(
    accountSession: accountSession,
    gameState: () => gameState.state,
  );
  int _sequence = 0;

  static Future<_Fixture> mount(
    WidgetTester tester, {
    bool combined = false,
    PanelStyle style = PanelStyle.card,
    Locale locale = const Locale('zh'),
    double textScale = 1,
    double width = 320,
    int hdColumns = 1,
    bool nativeActivity = false,
    NativeGameResourceChecklistPort? nativeChecklistPort,
    Map<String, Object> initialPreferences = const {},
    String? fontFamily,
    String firstShipName = '矢矧改二乙',
    GameState? initialState,
  }) async {
    SharedPreferences.setMockInitialValues(initialPreferences);
    final fixture = _Fixture(
      tester,
      initialState ?? _state(combined, firstShipName),
    );
    addTearDown(() {
      fixture.controller.dispose();
      fixture.gameState.dispose();
      fixture.accountSession.dispose();
    });
    await fixture.controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: fontFamily == null ? null : ThemeData(fontFamily: fontFamily),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: GameDialogPresentationScope(
          nativeActivity: nativeActivity,
          nativeChecklistPort: nativeChecklistPort,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: PanelStyleScope(
                    style: style,
                    child: HdModuleColumns(
                      columns: hdColumns,
                      child: SortieExperienceCard(
                        controller: fixture.controller,
                        gameState: fixture.gameState,
                        collapsed: false,
                        onToggleCollapse: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return fixture;
  }

  Text exp(int id) =>
      tester.widget<Text>(find.byKey(Key('sortie-exp-value-$id')));

  String? percentage(int id) =>
      tester.widget<Text>(find.byKey(Key('sortie-exp-percentage-$id'))).data;

  String? mvp(int id) =>
      tester.widget<Text>(find.byKey(Key('sortie-exp-mvp-$id'))).data;

  String? level(int id) =>
      tester.widget<Text>(find.byKey(Key('sortie-exp-level-$id'))).data;

  String? next(int id) =>
      tester.widget<Text>(find.byKey(Key('sortie-exp-next-$id'))).data;

  Future<void> recordTotal() async {
    await controller.setTrackingEnabled(true);
    await start();
    await settle([-1, 240, 720], mainMvp: 2);
    await returnToPort();
    await tester.tap(find.byKey(const Key('sortie-exp-tab-total')));
    await tester.pumpAndSettle();
    expect(controller.totalSorties, 1);
  }

  Future<void> start() => _send(
    '/kcsapi/api_req_map/start',
    {'api_maparea_id': 5, 'api_mapinfo_no': 3, 'api_no': 1},
    params: {'api_deck_id': '1'},
  );

  Future<void> moveToNextNode() => _send('/kcsapi/api_req_map/next', {
    'api_maparea_id': 5,
    'api_mapinfo_no': 3,
    'api_no': 2,
  });

  Future<void> settle(
    List<int> main, {
    List<int>? escort,
    int? mainMvp,
    int? escortMvp,
  }) async {
    final path = escort == null
        ? '/kcsapi/api_req_sortie'
        : '/kcsapi/api_req_combined_battle';
    await _send('$path/battle', {'api_deck_id': 1});
    await _send('$path/battleresult', {
      'api_get_ship_exp': main,
      'api_get_ship_exp_combined': ?escort,
      'api_mvp': ?mainMvp,
      'api_mvp_combined': ?escortMvp,
    });
  }

  Future<void> returnToPort() => _send('/kcsapi/api_port/port', {
    'api_basic': {'api_member_id': 99},
  });

  Future<void> destroyShips(String ids) => _send(
    '/kcsapi/api_req_kousyou/destroyship',
    {
      'api_material': [100, 100, 100, 100],
    },
    params: {'api_ship_id': ids},
  );

  Future<void> _send(
    String path,
    Map<String, Object?> data, {
    Map<String, Object?> params = const {},
  }) async {
    controller.accept(
      kcsapiEvent(path, data, requestParams: params, sequence: ++_sequence),
    );
    await controller.idle;
    await tester.pumpAndSettle();
  }
}

final class _ShipChecklistPort implements NativeGameResourceChecklistPort {
  final source = StreamController<Map<String, Object?>>.broadcast(sync: true);
  final shown = <Map<String, Object?>>[];
  final updated = <Map<String, Object?>>[];
  final dismissed = <int>[];
  final result = Completer<NativeGameWarningAction?>();

  @override
  Stream<Map<String, Object?>> get events => source.stream;

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload) {
    shown.add(payload);
    return result.future;
  }

  @override
  Future<void> update(Map<String, Object?> payload) async =>
      updated.add(payload);

  @override
  Future<void> dismiss({required String kind, required int id}) async {
    dismissed.add(id);
    if (!result.isCompleted) result.complete(null);
  }

  void emit(String shipId, int changeId, {required bool checked}) {
    source.add({
      'kind': shown.single['kind'],
      'id': shown.single['id'],
      'event': 'toggle',
      'itemId': shipId,
      'changeId': changeId,
      'checked': checked,
    });
  }
}

GameState _state(bool combined, String firstShipName) => GameState(
  memberId: 99,
  fleets: [
    const Fleet(id: 1, name: '', shipIds: [101, 102]),
    if (combined) const Fleet(id: 2, name: '', shipIds: [201, 202]),
  ],
  combinedFleetType: combined
      ? CombinedFleetType.carrierTaskForce
      : CombinedFleetType.none,
  ships: {
    101: const OwnedShip(
      id: 101,
      masterId: 1,
      level: 2,
      experience: 160,
      nextExperience: 140,
    ),
    102: const OwnedShip(
      id: 102,
      masterId: 2,
      level: 2,
      experience: 150,
      nextExperience: 150,
    ),
    if (combined)
      201: const OwnedShip(
        id: 201,
        masterId: 1,
        level: 2,
        experience: 140,
        nextExperience: 160,
      ),
    if (combined)
      202: const OwnedShip(
        id: 202,
        masterId: 4,
        level: 2,
        experience: 110,
        nextExperience: 190,
      ),
  },
  masterShips: {
    1: MasterShip(id: 1, name: firstShipName, shipTypeId: 2),
    2: const MasterShip(id: 2, name: '最上改二特', shipTypeId: 6),
    4: const MasterShip(id: 4, name: '长波改二', shipTypeId: 1),
  },
);
