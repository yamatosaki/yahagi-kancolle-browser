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
    expect(find.text('已结算 0 场战斗'), findsOneWidget);
    expect(find.text('5-3 · 第 1 舰队'), findsOneWidget);
    expect(find.byKey(const Key('sortie-exp-position-101')), findsNothing);
    expect(fixture.exp(101).data, '0');
    expect(fixture.level(101), 'Lv.2');
    expect(fixture.next(101), 'Next. 140');
    expect(fixture.exp(101).style?.color, const Color(0xfff7cf75));

    await fixture.settle([-1, 240, 720]);
    expect(fixture.level(101), 'Lv.3');
    expect(fixture.next(101), 'Next. 200');
    await fixture.moveToNextNode();
    await fixture.settle([-1, 240, 720]);
    expect(find.text('已结算 2 场战斗'), findsOneWidget);
    expect(fixture.exp(101).data, '+480');
    expect(fixture.exp(102).data, '+1,440');
    expect(fixture.level(101), 'Lv.4');
    expect(fixture.next(101), 'Next. 360');
    expect(fixture.exp(101).style?.color, const Color(0xfff7cf75));

    await fixture.returnToPort();
    expect(find.text('上次出击'), findsOneWidget);
    expect(find.byKey(const Key('sortie-exp-position-101')), findsNothing);
    expect(find.byKey(const Key('sortie-exp-position-102')), findsNothing);
    expect(fixture.exp(101).style?.color, const Color(0xff8adac7));
    expect(fixture.exp(101).data, '+480');
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
    expect(find.text('5-3 · 第 1 舰队'), findsNothing);
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
    expect(find.text('EXP'), findsNWidgets(4));
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
    for (final metric in ['level', 'next', 'value']) {
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
      'level, six-digit Next. and EXP without ship numbers', (tester) async {
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
    );

    expect(find.text(name), findsNWidgets(12));
    for (final (index, id) in ids.indexed) {
      final row = find.byKey(Key('sortie-exp-ship-$id'));
      expect(find.byKey(Key('sortie-exp-position-$id')), findsNothing);
      expect(fixture.level(id), 'Lv.179');
      expect(fixture.next(id), 'Next. 898,${799 - index}');
      expect(fixture.exp(id).data, '+1,${201 + index}');

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
      expect(nameBounds.right, lessThan(nextBounds.left));
      expect(levelBounds.bottom, lessThanOrEqualTo(nextBounds.top + 0.01));
      expect(nextBounds.right, lessThan(valueBounds.left));
      for (final metric in [levelBounds, nextBounds, valueBounds]) {
        expect(metric.width, greaterThan(0));
        expect(metric.top, greaterThanOrEqualTo(bounds.top));
        expect(metric.right, lessThanOrEqualTo(bounds.right));
        expect(metric.bottom, lessThanOrEqualTo(bounds.bottom));
      }
      expect(
        find.descendant(of: row, matching: find.text('EXP')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(Text)),
        findsNWidgets(5),
      );
    }
    expect(tester.takeException(), isNull);
  });
}

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

  String? level(int id) =>
      tester.widget<Text>(find.byKey(Key('sortie-exp-level-$id'))).data;

  String? next(int id) =>
      tester.widget<Text>(find.byKey(Key('sortie-exp-next-$id'))).data;

  Future<void> recordTotal() async {
    await controller.setTrackingEnabled(true);
    await start();
    await settle([-1, 240, 720]);
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

  Future<void> settle(List<int> main, {List<int>? escort}) async {
    final path = escort == null
        ? '/kcsapi/api_req_sortie'
        : '/kcsapi/api_req_combined_battle';
    await _send('$path/battle', {'api_deck_id': 1});
    await _send('$path/battleresult', {
      'api_get_ship_exp': main,
      'api_get_ship_exp_combined': ?escort,
    });
  }

  Future<void> returnToPort() => _send('/kcsapi/api_port/port', {
    'api_basic': {'api_member_id': 99},
  });

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
