import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/main.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_controller.dart';
import 'package:yahagi_kancolle_browser/src/audio/game_audio_store.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_toolbar_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_decoder.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_home_editor.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/dashboard_display_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/network_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/safety_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_controller.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_resource_ledger.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _module = 'sortie_experience';
const _preSortie = 'pre_sortie';
const _memberId = 733;
const _firstNode = [
  [5300, 5500, 6600],
  [6650, 7800],
];
const _secondNode = [
  [5660, 6600],
  [6770, 7800],
];
const _exerciseNode = [
  [5300, 5500],
  [6650, 7800],
];
const _afterSortie = [(11, 5750, 850), (12, 6980, 820)];
const _afterExercise = [(10, 5480, 20), (12, 6770, 1030)];

void main() {
  test(
    'the default home order puts sortie experience after sortie check',
    () async {
      SharedPreferences.setMockInitialValues({});
      final layout = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(layout.dispose);

      final order = layout.dashboardCardOrder;
      expect(order, contains(_preSortie));
      expect(order, contains(_module));
      expect(order.indexOf(_module), order.indexOf(_preSortie) + 1);
    },
  );

  testWidgets('home card updates on results and posts the total only in port', (
    tester,
  ) async {
    final harness = await _mount(tester, size: const Size(1180, 700));
    final card = find.byKey(const ValueKey(_module));
    final checkCard = find.byKey(const ValueKey(_preSortie));
    await _show(tester, card);
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(tester.getTopLeft(checkCard).dy),
    );

    final totalTab = find.byKey(const Key('sortie-exp-tab-total'));
    final sortieTab = find.byKey(const Key('sortie-exp-tab-sortie'));
    await _tap(tester, totalTab);
    expect(_inCard(card, '总累计 0 场'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('sortie-exp-tracking-switch')));
    await harness.experience.idle;
    expect(harness.experience.trackingEnabled, isTrue);

    await harness.publish(tester, mapStartEvent);
    await _tap(tester, sortieTab);
    expect(_inCard(card, '本次出击'), findsOneWidget);
    expect(_inCard(card, '0 场战斗'), findsOneWidget);
    expect(_inCard(card, '+0 EXP'), findsOneWidget);
    expect(harness.experience.sortie?.ships.map((ship) => ship.experience), [
      0,
      0,
    ]);

    await harness.publish(tester, dayBattleEvent);
    await harness.publishResult(tester, [360, 120], _firstNode);
    // A replay with a fresh capture sequence is still the same node result.
    await harness.publishResult(tester, [360, 120], _firstNode);
    expect(_inCard(card, '1 场战斗'), findsOneWidget);
    expect(harness.experience.sortie?.ships.map((ship) => ship.experience), [
      360,
      120,
    ]);
    _expectHomeMvp(tester, 9001, 1, percentage: '75%');
    _expectHomeMvp(tester, 9002, 0, percentage: '25%');
    _expectHomeProgress(9001, 11, '940');
    _expectHomeProgress(9002, 12, '1,030');

    await harness.publish(
      tester,
      mapStartEvent,
      path: '/kcsapi/api_req_map/next',
      data: {..._data(mapStartEvent), 'api_no': 2},
      request: const {},
    );
    await harness.publishResult(tester, [360, 120], _firstNode);
    expect(_inCard(card, '1 场战斗'), findsOneWidget);
    await harness.publish(tester, dayBattleEvent);
    await harness.publishResult(tester, [90, 210], _secondNode);
    expect(_inCard(card, '2 场战斗'), findsOneWidget);
    expect(harness.experience.sortie?.ships.map((ship) => ship.experience), [
      450,
      330,
    ]);
    // The server still names ship 9001 MVP at node 2 despite ship 9002's
    // higher EXP award. The replay must not increment either ship.
    _expectHomeMvp(tester, 9001, 2, percentage: '57.7%');
    _expectHomeMvp(tester, 9002, 0, percentage: '42.3%');
    _expectHomeProgress(9001, 11, '850');
    _expectHomeProgress(9002, 12, '820');
    await _tap(tester, totalTab);
    expect(_inCard(card, '总累计 0 场'), findsOneWidget);
    expect(harness.experience.totals, isEmpty);

    await harness.returnToPort(tester, _afterSortie);
    await harness.returnToPort(tester, _afterSortie);
    expect(_inCard(card, '总累计 1 场'), findsOneWidget);
    expect(harness.experience.totals.map((ship) => ship.experience), [
      450,
      330,
    ]);
    _expectHomeMvp(tester, 9001, 2, percentage: '57.7%');
    _expectHomeMvp(tester, 9002, 0, percentage: '42.3%');
    _expectHomeProgress(9001, 11, '850');
    _expectHomeProgress(9002, 12, '820');
    await _tap(tester, sortieTab);
    expect(_inCard(card, '上次出击'), findsOneWidget);
    expect(_inCard(card, '2 场战斗'), findsOneWidget);
    expect(_inCard(card, '+780 EXP'), findsOneWidget);
    _expectHomeMvp(tester, 9001, 2, percentage: '57.7%');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home spending follows sortie, refill, repair, and bucket APIs', (
    tester,
  ) async {
    // Use dedicated accounts so their SQLite queues cannot outlive this
    // widget test and be picked up by a separate fake clock.
    const memberId = 27101;
    const otherMember = 27102;
    final harness = await _mount(
      tester,
      size: const Size(1180, 820),
      memberId: memberId,
    );
    final experience = harness.experience;
    Finder keyed(String id) => find.byKey(Key('sortie-exp-$id'));
    double rowTop(int id) => tester.getTopLeft(keyed('ship-$id')).dy;

    Map<String, Object?> port([int sorties = 0]) {
      final after = sorties > 0;
      final (firstFuel, firstAmmo, secondFuel, secondAmmo) = switch (sorties) {
        0 => (25, 40, 15, 20),
        1 => (22, 37, 14, 15),
        2 => (19, 34, 13, 10),
        _ => (15, 30, 11, 6),
      };
      final base = _portData(memberId, [
        (
          after ? 11 : 10,
          5300 + 360 * sorties,
          after ? 1300 - 360 * sorties : 200,
        ),
        (12, 6650 + 120 * sorties, 1150 - 120 * sorties),
      ]);
      final ships = (base['api_ship'] as List).cast<Map>();
      return {
        ...base,
        'api_material': [
          for (var id = 1; id <= 8; id++) {'api_id': id, 'api_value': 1000},
        ],
        'api_ship': [
          {
            ...ships[0],
            'api_fuel': firstFuel,
            'api_bull': firstAmmo,
            'api_ndock_item': after ? [6, 11] : [0, 0],
            'api_ndock_time': after ? 3600000 : 0,
            'api_nowhp': after ? 22 : 30,
          },
          {
            ...ships[1],
            'api_fuel': secondFuel,
            'api_bull': secondAmmo,
            'api_ndock_item': after ? [3, 5] : [0, 0],
            'api_ndock_time': after ? 7200000 : 0,
            'api_nowhp': after ? 10 : 15,
          },
        ],
        'api_ndock': [
          for (var id = 1; id <= 2; id++)
            {'api_id': id, 'api_state': 0, 'api_ship_id': 0},
        ],
      };
    }

    Future<void> send(
      String path,
      Map<String, Object?> request, [
      Map<String, Object?> data = const {},
    ]) => harness.publish(
      tester,
      portEvent,
      path: '/kcsapi/$path',
      request: request,
      data: data,
    );

    await harness.publish(tester, portEvent, data: port());
    await _tap(tester, keyed('tab-total'));
    await _tap(tester, keyed('tracking-switch'));
    await _tap(tester, keyed('total-tab-consumption'));
    final summary = keyed('resource-summary');
    expect(summary, findsOneWidget);
    expect(experience.hasResourceSpendingData, isFalse);

    for (var sortie = 1; sortie <= 3; sortie++) {
      await harness.publish(tester, mapStartEvent);
      await harness.publish(tester, dayBattleEvent);
      await harness.publishResult(tester, [360, 120], _firstNode);
      expect(experience.totalSorties, sortie - 1);
      await harness.publish(tester, portEvent, data: port(sortie));
      expect(experience.totalSorties, sortie);
      expect(experience.totalResourceSpending.isEmpty, isTrue);
      expect(_inCard(summary, '未统计'), findsOneWidget);
      expect(_inCard(summary, '—'), findsNWidgets(5));
      for (final id in [9001, 9002]) {
        expect(_inCard(keyed('ship-$id'), '未统计'), findsOneWidget);
      }
    }
    expect(
      experience.resourceSpendingFor(9001)?.pending,
      const SortieResourceAmounts(fuel: 10, ammo: 10),
    );
    expect(
      experience.resourceSpendingFor(9002)?.pending,
      const SortieResourceAmounts(fuel: 4, ammo: 14),
    );
    expect(experience.totalResourceSpending.isEmpty, isTrue);
    expect(find.textContaining('本轮待补给'), findsNothing);
    await _tap(tester, keyed('resource-sort'));
    await _tap(tester, keyed('resource-sort-ammo'));
    await tester.pumpAndSettle();
    // A pending refill does not move a ship ahead of the EXP tie breaker.
    expect(rowTop(9001), lessThan(rowTop(9002)));

    const chargePath = '/kcsapi/api_req_hokyu/charge';
    const chargeRequest = {
      'api_kind': '3',
      'api_id_items': '9001,9002',
      'api_onslot': '1',
    };
    const chargeData = <String, Object?>{
      'api_ship': [
        {
          'api_id': 9001,
          'api_fuel': 25,
          'api_bull': 40,
          'api_onslot': [0, 2, 0],
        },
        {
          'api_id': 9002,
          'api_fuel': 15,
          'api_bull': 20,
          'api_onslot': [0, 0],
        },
      ],
      'api_material': [986, 976, 1000, 1000],
      'api_use_bou': 0,
    };
    await harness.publish(
      tester,
      portEvent,
      path: chargePath,
      request: chargeRequest,
      data: chargeData,
      apiResult: 0,
    );
    expect(experience.totalResourceSpending.isEmpty, isTrue);
    expect(_inCard(summary, '—'), findsNWidgets(5));
    expect(experience.resourceSpendingFor(9001)?.pending.fuel, 10);

    await send('api_req_hokyu/charge', chargeRequest, chargeData);
    expect(experience.resourceSpendingFor(9001)?.pending.isEmpty, isTrue);
    expect(experience.resourceSpendingFor(9002)?.pending.isEmpty, isTrue);
    expect(experience.resourceSpendingFor(9001)?.supply.fuel, 10);
    expect(experience.resourceSpendingFor(9002)?.supply.ammo, 14);
    expect(_inCard(summary, '未统计'), findsNothing);
    expect(_inCard(keyed('resource-group-fuel'), '14'), findsOneWidget);
    expect(_inCard(keyed('resource-group-ammo'), '24'), findsOneWidget);
    expect(_inCard(keyed('ship-9001'), '10'), findsNWidgets(2));
    expect(_inCard(keyed('ship-9002'), '14'), findsOneWidget);
    expect(rowTop(9002), lessThan(rowTop(9001)));
    await send('api_req_hokyu/charge', chargeRequest, chargeData);
    expect(
      experience.totalResourceSpending,
      const SortieResourceAmounts(fuel: 14, ammo: 24),
    );
    expect(_inCard(keyed('resource-group-fuel'), '14'), findsOneWidget);
    expect(_inCard(keyed('resource-group-ammo'), '24'), findsOneWidget);

    await send('api_req_nyukyo/start', {
      'api_ship_id': '9001',
      'api_ndock_id': '1',
      'api_highspeed': '1',
    });
    await send('api_req_nyukyo/start', {
      'api_ship_id': '9002',
      'api_ndock_id': '2',
      'api_highspeed': '0',
    });
    expect(experience.totalResourceSpending.buckets, 1);
    await send('api_req_nyukyo/speedchange', {'api_ndock_id': '2'});
    await send('api_req_nyukyo/speedchange', {'api_ndock_id': '2'});

    final SortieResourceAmounts total = experience.totalResourceSpending;
    expect(
      [total.fuel, total.ammo, total.steel, total.bauxite, total.buckets],
      [23, 24, 16, 0, 2],
    );
    expect(experience.resourceSpendingFor(9001)?.repair.steel, 11);
    expect(experience.resourceSpendingFor(9002)?.repair.steel, 5);
    expect(experience.resourceSpendingFor(9002)?.repair.buckets, 1);
    expect(experience.totals.map((ship) => ship.experience), [1080, 360]);
    expect(experience.resourceSpendingIncomplete, isFalse);
    expect(_inCard(summary, '桶'), findsOneWidget);
    for (final amount in ['23', '24', '16', '0', '2']) {
      expect(
        find.descendant(of: summary, matching: find.text(amount)),
        findsOneWidget,
      );
    }
    expect(find.textContaining('本轮待补给'), findsNothing);
    await _tap(tester, keyed('resource-open-9002'));
    expect(keyed('resource-dialog'), findsOneWidget);
    expect(find.text('出击补给支出'), findsOneWidget);
    expect(find.text('入渠与加速'), findsOneWidget);
    expect(find.text('燃料 4 · 弹药 14 · 铝土 0'), findsOneWidget);
    expect(find.text('燃料 3 · 钢材 5 · 桶 1'), findsOneWidget);
    await _tap(tester, keyed('resource-close'));

    await _tap(tester, keyed('filter-total'));
    await _tap(tester, keyed('filter-ship-9002'));
    await _tap(tester, keyed('filter-done'));
    await tester.pumpAndSettle();
    expect(experience.hiddenTotalShipIds, {9002});
    expect(keyed('ship-9002'), findsNothing);
    expect(experience.totalResourceSpending, total);
    expect(
      find.descendant(of: summary, matching: find.text('24')),
      findsOneWidget,
    );
    await _tap(tester, keyed('filter-total'));
    await _tap(tester, keyed('filter-ship-9002'));
    await _tap(tester, keyed('filter-done'));
    await tester.pumpAndSettle();
    expect(experience.hiddenTotalShipIds, isEmpty);
    expect(rowTop(9002), lessThan(rowTop(9001)));
    await _tap(tester, keyed('resource-sort'));
    await _tap(tester, keyed('resource-sort-fuel'));
    await tester.pumpAndSettle();
    expect(rowTop(9001), lessThan(rowTop(9002)));

    await harness.publish(tester, start2Event);
    await harness.publish(
      tester,
      portEvent,
      data: {
        ...port(),
        'api_basic': {'api_member_id': otherMember, 'api_level': 120},
      },
    );
    expect(harness.account.current.memberId, otherMember);
    expect(experience.hasResourceSpendingData, isFalse);
    expect(experience.totalResourceSpending.isEmpty, isTrue);

    await harness.publish(tester, start2Event);
    await harness.publish(tester, portEvent, data: port());
    expect(harness.account.current.memberId, memberId);
    expect(experience.totalResourceSpending, total);
    expect(experience.trackingEnabled, isTrue);
    await send('api_req_kousyou/destroyship', {'api_ship_id': '9002'});
    expect(experience.resourceSpendingFor(9002), isNull);
    expect(
      experience.totalResourceSpending,
      const SortieResourceAmounts(fuel: 16, ammo: 10, steel: 11, buckets: 1),
    );
    expect(experience.totalExperiencePercentage(9001), 100);
    await experience.clearTotal();
    expect(experience.hasResourceSpendingData, isFalse);
    expect(experience.totals, isEmpty);
    expect(experience.totalResourceSpending.isEmpty, isTrue);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    for (final id in [memberId, otherMember]) {
      await _awaitWithFrames(
        tester,
        LogbookDatabase.forAccount(id).close(),
        'close spending smoke SQLite',
      );
    }
  });

  testWidgets(
    'home pipeline prunes lost ships while preserving sortie history',
    (tester) async {
      const ids = [9001, 9002, 9003, 9004];
      const gains = [240, 120, 80, 40];
      final history = <List<int?>>[];
      final harness = await _mount(
        tester,
        size: const Size(1180, 820),
        recordExperience: (_, record) async {
          history.add(record.ships.map((ship) => ship.experience).toList());
        },
      );
      final card = find.byKey(const ValueKey(_module));
      final base = _portData(_memberId);
      final template = (base['api_ship'] as List).first as Map;
      final decks = (base['api_deck_port'] as List).cast<Map>();

      Map<String, Object?> portFor(
        Iterable<int> ownedIds, {
        bool earned = false,
      }) => {
        ...base,
        'api_ndock': const [],
        'api_ship': [
          for (final id in ownedIds)
            {
              ...template,
              'api_id': id,
              'api_lv': earned && id == 9001 ? 11 : 10,
              'api_exp': [
                5300 + (earned ? gains[ids.indexOf(id)] : 0),
                (earned && id == 9001 ? 6600 : 5500) -
                    5300 -
                    (earned ? gains[ids.indexOf(id)] : 0),
                0,
              ],
              'api_slot': const [-1, -1, -1],
              'api_slot_ex': -1,
              'api_onslot': const [0, 0, 0],
            },
        ],
        'api_deck_port': [
          {...decks.first, 'api_ship': ownedIds.toList()},
          for (final deck in decks.skip(1))
            {
              ...deck,
              'api_ship': const [-1, -1, -1, -1, -1, -1],
            },
        ],
      };

      await harness.publish(tester, portEvent, data: portFor(ids));
      final totalTab = find.byKey(const Key('sortie-exp-tab-total'));
      final filter = find.byKey(const Key('sortie-exp-filter-total'));
      final done = find.byKey(const Key('sortie-exp-filter-done'));
      await _tap(tester, totalTab);
      await _tap(tester, find.byKey(const Key('sortie-exp-tracking-switch')));
      await harness.publish(tester, mapStartEvent);
      await harness.publish(
        tester,
        dayBattleEvent,
        data: {
          ..._data(dayBattleEvent),
          'api_f_nowhps': const [28, 28, 28, 28],
          'api_f_maxhps': const [30, 30, 30, 30],
        },
      );
      await harness.publishResult(tester, gains);
      await harness.publish(
        tester,
        portEvent,
        data: portFor(ids, earned: true),
      );
      expect(harness.experience.totalExperience, 480);
      expect(harness.experience.totalExperiencePercentage(9001), 50);
      expect(_inCard(card, '合计 480 EXP'), findsOneWidget);
      expect(_inCard(card, '50%'), findsOneWidget);
      expect(history, [gains]);
      final snapshot = harness.experience.sortie;

      await _tap(tester, filter);
      await _tap(tester, find.byKey(const Key('sortie-exp-filter-ship-9002')));
      await _tap(tester, done);
      await tester.pumpAndSettle();
      expect(harness.experience.hiddenTotalShipIds, {9002});
      expect(find.byKey(const Key('sortie-exp-ship-9002')), findsNothing);
      expect(_inCard(card, '合计 480 EXP'), findsOneWidget);

      await harness.publish(
        tester,
        portEvent,
        path: '/kcsapi/api_req_kousyou/destroyship',
        request: const {'api_ship_id': '9004'},
        data: const {
          'api_material': [100, 100, 100, 100],
        },
      );
      expect(harness.state.state.ships, isNot(contains(9004)));
      expect(harness.experience.totalExperience, 440);
      expect(_inCard(card, '合计 440 EXP'), findsOneWidget);
      expect(_inCard(card, '54.5%'), findsOneWidget);
      expect(find.byKey(const Key('sortie-exp-ship-9004')), findsNothing);

      await _tap(tester, filter);
      final materialChoice = find.byKey(
        const Key('sortie-exp-filter-ship-9003'),
      );
      await _tap(tester, materialChoice);
      expect(tester.widget<CheckboxListTile>(materialChoice).value, isFalse);
      final target = (portFor([9001], earned: true)['api_ship'] as List).single;
      await harness.publish(
        tester,
        portEvent,
        path: '/kcsapi/api_req_kaisou/powerup',
        request: const {'api_id': '9001', 'api_id_items': '9003'},
        data: {'api_powerup_flag': 0, 'api_ship': target},
      );
      expect(harness.state.state.ships, contains(9001));
      expect(harness.state.state.ships, isNot(contains(9003)));
      expect(materialChoice, findsNothing);
      await _tap(tester, done);
      await tester.pumpAndSettle();
      expect(harness.experience.hiddenTotalShipIds, {9002});
      expect(harness.experience.totals.map((ship) => ship.ownedShipId), [
        9001,
        9002,
      ]);
      expect(harness.experience.totalExperience, 360);
      expect(
        harness.experience.totalExperiencePercentage(9001),
        closeTo(200 / 3, .0001),
      );
      expect(_inCard(card, '合计 360 EXP'), findsOneWidget);
      expect(_inCard(card, '66.7%'), findsOneWidget);
      expect(harness.experience.sortie, same(snapshot));
      expect(harness.experience.totalSorties, 1);
      expect(history, [gains]);

      await harness.publish(
        tester,
        portEvent,
        data: portFor([9001], earned: true),
      );
      expect(harness.experience.totals.single.ownedShipId, 9001);
      expect(harness.experience.totalExperience, 240);
      expect(harness.experience.totalExperiencePercentage(9001), 100);
      expect(harness.experience.hiddenTotalShipIds, isEmpty);
      expect(_inCard(card, '合计 240 EXP'), findsOneWidget);
      expect(_inCard(card, '100%'), findsOneWidget);

      await harness.publish(tester, portEvent, data: portFor(const []));
      expect(harness.experience.totals, isEmpty);
      expect(harness.experience.totalExperience, 0);
      expect(harness.experience.totalExperiencePercentage(9001), 0);
      expect(_inCard(card, '总累计 1 场'), findsOneWidget);
      expect(_inCard(card, '合计 0 EXP'), findsOneWidget);
      expect(find.byKey(const Key('sortie-exp-total-page')), findsNothing);

      final reopened = SortieExperienceController(
        accountSession: harness.account,
        gameState: () => harness.state.state,
      );
      try {
        await reopened.initialize();
        expect(reopened.totals, isEmpty);
        expect(reopened.hiddenTotalShipIds, isEmpty);
        expect(reopened.totalSorties, 1);
        expect(reopened.sortie?.ships.map((ship) => ship.experience), gains);
        expect(history, [gains]);
      } finally {
        reopened.dispose();
      }
      await _tap(tester, find.byKey(const Key('sortie-exp-tab-sortie')));
      for (final (index, id) in ids.indexed) {
        _homeExperienceRow(tester, id, gains[index]);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('clear confirmation protects game input and keeps capture live', (
    tester,
  ) async {
    const surfaceKey = Key('clear-confirmation-game-surface');
    var gameDowns = 0;
    var gameTaps = 0;
    final logbookGains = <List<int?>>[];
    final harness = await _mount(
      tester,
      size: const Size(1180, 700),
      gameSurface: Listener(
        key: surfaceKey,
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => gameDowns++,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => gameTaps++,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
      recordExperience: (_, record) async {
        logbookGains.add(record.ships.map((ship) => ship.experience).toList());
      },
    );
    final surface = find.byKey(surfaceKey);
    final liveSurface = tester.element(surface);
    final gamePoint = tester.getTopLeft(surface) + const Offset(24, 24);
    final clear = find.byKey(const Key('sortie-exp-clear-total'));
    final dialog = find.byKey(const Key('sortie-exp-clear-dialog'));
    final cancel = find.byKey(const Key('sortie-exp-clear-cancel'));
    final confirm = find.byKey(const Key('sortie-exp-clear-confirm'));

    Future<void> startAndSettle(List<int> gains, List<List<int>> levels) async {
      await harness.publish(tester, mapStartEvent);
      await harness.publish(tester, dayBattleEvent);
      await harness.publishResult(tester, gains, levels);
    }

    await tester.tapAt(gamePoint);
    expect(gameTaps, 1);
    expect(gameDowns, 1);
    await _tap(tester, find.byKey(const Key('sortie-exp-tab-total')));
    await _tap(tester, find.byKey(const Key('sortie-exp-tracking-switch')));
    await startAndSettle([360, 120], _firstNode);
    await harness.returnToPort(tester, [(11, 5660, 940), (12, 6770, 1030)]);
    await harness.experience.idle;

    await _tap(tester, clear);
    expect(ModalRoute.of(tester.element(dialog)), isA<GameSafetyDialogRoute>());
    expect(harness.experience.totalSorties, 1);
    final dialogSurface = find
        .descendant(of: dialog, matching: find.byType(Material))
        .first;
    expect(tester.getRect(dialogSurface).contains(gamePoint), isFalse);
    for (var tap = 0; tap < 5; tap++) {
      await tester.tapAt(gamePoint);
      await tester.pump(const Duration(milliseconds: 50));
    }
    final outsideHold = await tester.startGesture(gamePoint);
    final secondTouch = await tester.startGesture(
      gamePoint + const Offset(15, 15),
    );
    await tester.pump(const Duration(seconds: 2));
    await secondTouch.up();
    await outsideHold.up();
    await tester.pump();
    expect(gameTaps, 1);
    expect(gameDowns, 1);
    expect(dialog, findsOneWidget);
    expect(harness.experience.totalSorties, 1);

    await startAndSettle([90, 210], _secondNode);
    expect(harness.experience.sortie?.battles, 1);
    expect(harness.experience.totalSorties, 1);
    expect(tester.element(surface), same(liveSurface));
    await _tap(tester, cancel);
    await _waitForFrame(
      tester,
      () => surface.hitTestable().evaluate().isNotEmpty,
      'game input after cancellation',
    );
    expect(harness.experience.totalSorties, 1);
    await tester.tapAt(gamePoint);
    expect(gameTaps, 2);
    expect(gameDowns, 2);
    await harness.returnToPort(tester, _afterSortie);
    await harness.experience.idle;
    expect(harness.experience.totalSorties, 2);
    expect(logbookGains, [
      [360, 120],
      [90, 210],
    ]);

    await _tap(tester, clear);
    await tester.tap(confirm);
    await tester.pump();
    // Keep interrupting the quiet interval, but never beyond the shared cap.
    for (var tap = 0; tap < 6; tap++) {
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.experience.totalSorties, 2);
      await tester.tapAt(gamePoint);
      expect(gameDowns, 2);
      expect(gameTaps, 2);
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(surface.hitTestable(), findsOneWidget);
    await _waitForFrame(
      tester,
      () =>
          harness.experience.totalSorties == 0 &&
          surface.hitTestable().evaluate().isNotEmpty,
      'clear confirmation and game input restoration',
    );
    await harness.experience.idle;
    expect(harness.experience.trackingEnabled, isTrue);
    expect(harness.experience.totals, isEmpty);
    expect(logbookGains, [
      [360, 120],
      [90, 210],
    ]);
    expect(harness.experience.sortie?.ships.map((ship) => ship.experience), [
      90,
      210,
    ]);
    expect(harness.experience.sortie?.ships.map((ship) => ship.mvpCount), [
      1,
      0,
    ]);
    expect(tester.element(surface), same(liveSurface));
    await tester.tapAt(gamePoint);
    expect(gameTaps, 3);
    expect(gameDowns, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'total ship filter applies on Done while game capture stays live',
    (tester) async {
      const surfaceKey = Key('total-ship-filter-game-surface');
      var gameDowns = 0;
      var gameTaps = 0;
      final logbookGains = <List<int?>>[];
      final harness = await _mount(
        tester,
        size: const Size(1180, 700),
        gameSurface: Listener(
          key: surfaceKey,
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => gameDowns++,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => gameTaps++,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
        recordExperience: (_, record) async {
          logbookGains.add(
            record.ships.map((ship) => ship.experience).toList(),
          );
        },
      );
      final surface = find.byKey(surfaceKey);
      final liveSurface = tester.element(surface);
      final gamePoint = tester.getTopLeft(surface) + const Offset(24, 24);
      final totalTab = find.byKey(const Key('sortie-exp-tab-total'));
      final filter = find.byKey(const Key('sortie-exp-filter-total'));
      final dialog = find.byKey(const Key('sortie-exp-filter-dialog'));
      final done = find.byKey(const Key('sortie-exp-filter-done'));
      final firstChoice = find.byKey(const Key('sortie-exp-filter-ship-9001'));
      final secondChoice = find.byKey(const Key('sortie-exp-filter-ship-9002'));
      final firstShip = find.byKey(const Key('sortie-exp-ship-9001'));
      final secondShip = find.byKey(const Key('sortie-exp-ship-9002'));

      Future<void> startAndSettle(
        List<int> gains,
        List<List<int>> levels,
      ) async {
        await harness.publish(tester, mapStartEvent);
        await harness.publish(tester, dayBattleEvent);
        await harness.publishResult(tester, gains, levels);
      }

      await tester.tapAt(gamePoint);
      expect(gameDowns, 1);
      expect(gameTaps, 1);
      await _tap(tester, totalTab);
      await _tap(tester, find.byKey(const Key('sortie-exp-tracking-switch')));
      await startAndSettle([360, 120], _firstNode);
      await harness.returnToPort(tester, [(11, 5660, 940), (12, 6770, 1030)]);
      expect(firstShip, findsOneWidget);
      expect(secondShip, findsOneWidget);

      await _tap(tester, filter);
      expect(
        ModalRoute.of(tester.element(dialog)),
        isA<GameSafetyDialogRoute>(),
      );
      expect(firstChoice, findsOneWidget);
      expect(secondChoice, findsOneWidget);
      await _tap(tester, firstChoice);
      expect(dialog, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(firstChoice).value, isFalse);
      expect(firstShip, findsOneWidget);
      expect(secondShip, findsOneWidget);
      await _tap(tester, secondChoice);
      expect(tester.widget<CheckboxListTile>(secondChoice).value, isFalse);
      expect(secondShip, findsOneWidget);
      await _tap(tester, secondChoice);
      expect(secondShip, findsOneWidget);
      expect(harness.experience.totalSorties, 1);
      expect(harness.experience.totals.map((ship) => ship.experience), [
        360,
        120,
      ]);

      final dialogSurface = find
          .descendant(of: dialog, matching: find.byType(Material))
          .first;
      expect(tester.getRect(dialogSurface).contains(gamePoint), isFalse);
      for (var tap = 0; tap < 5; tap++) {
        await tester.tapAt(gamePoint);
        await tester.pump(const Duration(milliseconds: 50));
      }
      final outsideHold = await tester.startGesture(gamePoint);
      final secondTouch = await tester.startGesture(
        gamePoint + const Offset(15, 15),
      );
      await tester.pump(const Duration(seconds: 2));
      await secondTouch.up();
      await outsideHold.up();
      await tester.pump();
      expect(gameDowns, 1);
      expect(gameTaps, 1);
      expect(dialog, findsOneWidget);

      await startAndSettle([90, 210], _secondNode);
      await harness.returnToPort(tester, _afterSortie);
      await harness.experience.idle;
      expect(dialog, findsOneWidget);
      expect(firstShip, findsOneWidget);
      expect(secondShip, findsOneWidget);
      expect(harness.experience.totalSorties, 2);
      expect(harness.experience.totals.map((ship) => ship.experience), [
        450,
        330,
      ]);
      expect(logbookGains, [
        [360, 120],
        [90, 210],
      ]);
      expect(tester.element(surface), same(liveSurface));

      final heldAtClose = await tester.startGesture(gamePoint);
      try {
        await _tap(tester, done);
        expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
        expect(surface.hitTestable(), findsOneWidget);
        expect(dialog, findsNothing);
        expect(firstShip, findsNothing);
        expect(secondShip, findsOneWidget);
        await tester.tapAt(gamePoint);
      } finally {
        await heldAtClose.up();
      }
      expect(gameDowns, 2);
      expect(gameTaps, 2);

      await _tap(tester, find.byKey(const Key('sortie-exp-tab-sortie')));
      expect(firstShip, findsOneWidget);
      expect(secondShip, findsOneWidget);
      await _tap(tester, totalTab);
      expect(firstShip, findsNothing);
      await _tap(tester, filter);
      await _tap(tester, find.byKey(const Key('sortie-exp-filter-reset')));
      expect(dialog, findsOneWidget);
      expect(firstShip, findsNothing);
      expect(secondShip, findsOneWidget);
      expect(harness.experience.totalSorties, 2);
      await _tap(tester, done);
      await tester.pumpAndSettle();
      expect(firstShip, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('home records a completed exercise without waiting for port', (
    tester,
  ) async {
    final harness = await _mount(tester, size: const Size(1180, 700));
    final card = find.byKey(const ValueKey(_module));
    await _show(tester, card);
    await harness.experience.setTrackingEnabled(true);
    Future<void> startExercise() => harness.publish(
      tester,
      dayBattleEvent,
      path: '/kcsapi/api_req_practice/battle',
      data: {..._data(dayBattleEvent), 'api_deck_id': 1},
      request: const {},
    );
    await startExercise();
    expect(_inCard(card, '演习中'), findsOneWidget);
    expect(_inCard(card, '演习'), findsOneWidget);
    expect(_inCard(card, '第 1 舰队'), findsOneWidget);
    expect(_inCard(card, '0 场战斗'), findsOneWidget);
    expect(harness.experience.totalSorties, 0);

    Future<void> settleExercise({int mvp = 2}) => harness.publish(
      tester,
      battleResultEvent,
      path: '/kcsapi/api_req_practice/battle_result',
      data: {
        'api_win_rank': 'S',
        'api_mvp': mvp,
        'api_get_ship_exp': [-1, 180, 120, -1, -1, -1, -1],
        'api_get_exp_lvup': _exerciseNode,
      },
      request: const {},
    );

    await settleExercise();
    expect(_inCard(card, '上次出击'), findsOneWidget);
    expect(_inCard(card, '演习已结算'), findsOneWidget);
    expect(_inCard(card, '1 场战斗'), findsOneWidget);
    expect(_inCard(card, '+300 EXP'), findsOneWidget);
    expect(harness.experience.sortie?.ships.map((ship) => ship.experience), [
      180,
      120,
    ]);
    _expectHomeMvp(tester, 9001, 0, percentage: '60%');
    _expectHomeMvp(tester, 9002, 1, percentage: '40%');
    _expectHomeProgress(9001, 10, '20');
    _expectHomeProgress(9002, 12, '1,030');
    await _tap(tester, find.byKey(const Key('sortie-exp-tab-total')));
    expect(_inCard(card, '总累计 1 场'), findsOneWidget);
    await settleExercise();
    await harness.returnToPort(tester, _afterExercise);
    expect(_inCard(card, '总累计 1 场'), findsOneWidget);
    expect(harness.experience.totals.map((ship) => ship.experience), [
      180,
      120,
    ]);
    _expectHomeMvp(tester, 9001, 0);
    _expectHomeMvp(tester, 9002, 1);
    _expectHomeProgress(9001, 10, '20');
    _expectHomeProgress(9002, 12, '1,030');

    await harness.experience.setTrackingEnabled(false);
    await startExercise();
    await settleExercise(mvp: 1);
    expect(_inCard(card, '总累计 1 场'), findsOneWidget);
    _expectHomeMvp(tester, 9001, 0);
    _expectHomeMvp(tester, 9002, 1);
    await _tap(tester, find.byKey(const Key('sortie-exp-tab-sortie')));
    _expectHomeMvp(tester, 9001, 1, percentage: '60%');
    _expectHomeMvp(tester, 9002, 0, percentage: '40%');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (isPractice, writeWhileOpen) in [
    (false, false),
    (false, true),
    (true, false),
    (true, true),
  ]) {
    final kind = isPractice ? 'exercise' : 'two-battle sortie';
    final writeTiming = writeWhileOpen ? 'after opening' : 'on opening';
    testWidgets('home to logbook renders $kind EXP $writeTiming', (
      tester,
    ) async {
      final memberId =
          _memberId + 1 + (isPractice ? 2 : 0) + (writeWhileOpen ? 1 : 0);
      final database = LogbookDatabase.forAccount(memberId);
      await _awaitWithFrames(tester, database.database, 'open SQLite');
      final oldSession = LogbookDatabase.accountSession;
      final releaseWrite = Completer<void>();
      int? writeOwner;
      final changes = database.changesFor(LogbookChangeCategory.experience);
      final previousChange = changes.value;
      final harness = await _mount(
        tester,
        size: const Size(1180, 700),
        memberId: memberId,
        recordExperience: (scope, record) async {
          writeOwner = scope.memberId;
          await releaseWrite.future;
          await LogbookDatabase.forAccount(
            scope.memberId,
          ).insertExperienceRecord(record);
        },
      );
      LogbookDatabase.bindAccountSession(harness.account);
      try {
        final gains = isPractice ? [180, 120] : [450, 330];
        if (isPractice) {
          await harness.publish(
            tester,
            dayBattleEvent,
            path: '/kcsapi/api_req_practice/battle',
          );
          harness.enqueue(
            battleResultEvent,
            path: '/kcsapi/api_req_practice/battle_result',
            data: {
              'api_get_ship_exp': [-1, ...gains, -1, -1, -1, -1],
              'api_get_exp_lvup': _exerciseNode,
            },
          );
        } else {
          await harness.publish(tester, mapStartEvent);
          await harness.publish(tester, dayBattleEvent);
          await harness.publishResult(tester, [360, 120], _firstNode);
          await harness.publish(
            tester,
            mapStartEvent,
            path: '/kcsapi/api_req_map/next',
            data: {..._data(mapStartEvent), 'api_no': 2},
            request: const {},
          );
          await harness.publish(tester, dayBattleEvent);
          await harness.publishResult(tester, [90, 210], _secondNode);
          expect(writeOwner, isNull);
          harness.enqueue(portEvent, data: _portData(memberId, _afterSortie));
        }

        await _waitForFrame(
          tester,
          () => writeOwner != null,
          'experience writer',
        );
        expect(writeOwner, memberId);
        final card = find.byKey(const ValueKey(_module));
        await _show(tester, card);
        expect(_inCard(card, '上次出击'), findsOneWidget);
        final battles = isPractice ? 1 : 2;
        final battleLabel = '已结算 $battles 场战斗';
        expect(_inCard(card, '$battles 场战斗'), findsOneWidget);
        final homeRows = [
          for (final (index, id) in [9001, 9002].indexed)
            _homeExperienceRow(tester, id, gains[index]),
        ];

        Future<void> finishWrite() async {
          releaseWrite.complete();
          await _waitForFrame(
            tester,
            () => changes.value > previousChange,
            'SQLite experience change',
          );
        }

        if (!writeWhileOpen) await finishWrite();

        await _tap(
          tester,
          find.byKey(const Key('workspace-nav-battle-records')),
        );
        final page = find.byType(LogbookPage);
        expect(page, findsOneWidget);
        expect(LogbookDatabase.instance, same(database));
        await _tap(tester, find.byKey(const Key('logbook-tab-experience')));
        expect(tester.widget<LogbookPage>(page).selectedTabIndex, 6);
        final table = find.byKey(const Key('logbook-table-experience'));
        final pager = tester
            .widget<PageView>(
              find.descendant(of: page, matching: find.byType(PageView)).first,
            )
            .controller!;
        // The stable experience route is 6; its visible page is second.
        await _waitForFrame(
          tester,
          () => pager.page == 1 && table.evaluate().isNotEmpty,
          'experience tab to finish navigating',
        );
        if (writeWhileOpen) {
          final empty = _inCard(page, '暂无记录');
          await _waitForFrame(
            tester,
            () => empty.hitTestable().evaluate().isNotEmpty,
            'initial empty experience view',
          );
          expect(tester.widget<FrozenDataTable>(table).rowHeights, isEmpty);
          expect(changes.value, previousChange);
          // Complete the write without leaving the page or reloading it.
          await finishWrite();
        }
        await _waitForFrame(
          tester,
          () => _inCard(table, battleLabel).evaluate().isNotEmpty,
          'experience row after SQLite change',
        );
        await tester.pumpAndSettle();
        expect(changes.value, previousChange + 1);
        expect(tester.widget<FrozenDataTable>(table).rowHeights, hasLength(4));
        expect(
          _inCard(table, isPractice ? '本次演习经验' : '本次出击经验'),
          findsOneWidget,
        );
        final viewport = tester.getRect(table);
        for (final (id, name, gain, level, next) in homeRows) {
          final nameCell = _inCard(table, name);
          final gainCell = _inCard(table, gain);
          final levelCell = find.byKey(Key('logbook-experience-level-$id'));
          final nextCell = find.byKey(Key('logbook-experience-next-$id'));
          expect(nameCell, findsOneWidget);
          expect(gainCell, findsOneWidget);
          expect(tester.widget<Text>(levelCell).data, level);
          expect(tester.widget<Text>(nextCell).data, next);
          expect(viewport.contains(tester.getCenter(nameCell)), isTrue);
          expect(viewport.contains(tester.getCenter(gainCell)), isTrue);
          expect(
            tester.getCenter(levelCell).dy,
            closeTo(tester.getCenter(gainCell).dy, 3),
          );
        }
        final rows = await _awaitWithFrames(
          tester,
          database.getExperienceRecords(),
          'read committed SQLite experience',
        );
        final record = rows.single;
        expect(record.isPractice, isPractice);
        expect(record.battles, battles);
        expect(
          {for (final ship in record.ships) ship.ownedShipId: ship.experience},
          {9001: gains[0], 9002: gains[1]},
        );
        expect(_inCard(page, '总累计'), findsNothing);
        await harness.returnToPort(tester, [(11, 5800, 800), (12, 7000, 800)]);
        final next = find.byKey(const Key('logbook-experience-next-9001'));
        expect(tester.widget<Text>(next).data, 'Next. 800');
        expect(changes.value, previousChange + 1);
        expect(tester.takeException(), isNull);
      } finally {
        if (!releaseWrite.isCompleted) releaseWrite.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        LogbookDatabase.bindAccountSession(oldSession);
        await _awaitWithFrames(tester, harness.pipeline.idle, 'drain capture');
        await _awaitWithFrames(
          tester,
          harness.state.logbookIdle,
          'drain other logbook writes',
        );
        await _awaitWithFrames(tester, database.close(), 'close SQLite');
      }
    });
  }

  testWidgets('full combined fleet keeps both nodes and all twelve ship '
      'values aligned from home to logbook', (tester) async {
    const memberId = _memberId + 7;
    final database = LogbookDatabase.forAccount(memberId);
    await _awaitWithFrames(tester, database.database, 'open combined SQLite');
    final oldSession = LogbookDatabase.accountSession;
    final harness = await _mount(
      tester,
      size: const Size(1700, 1050),
      memberId: memberId,
      recordExperience: (scope, record) => LogbookDatabase.forAccount(
        scope.memberId,
      ).insertExperienceRecord(record),
    );
    LogbookDatabase.bindAccountSession(harness.account);

    const mainIds = [9001, 9002, 9003, 9004, 9005, 9006];
    const escortIds = [9101, 9102, 9103, 9104, 9105, 9106];
    const ids = [...mainIds, ...escortIds];
    final base = _portData(memberId);
    final shipTemplate = (base['api_ship'] as List).first as Map;
    final decks = (base['api_deck_port'] as List).cast<Map>();
    final initial = [for (var i = 0; i < ids.length; i++) 5440 + 4 * i];
    final first = [for (var i = 0; i < ids.length; i++) 180 + 10 * i];
    final second = [for (var i = 0; i < ids.length; i++) 60 + 5 * i];
    final afterFirst = [
      for (var i = 0; i < ids.length; i++) initial[i] + first[i],
    ];
    final afterSecond = [
      for (var i = 0; i < ids.length; i++) afterFirst[i] + second[i],
    ];
    final gains = [for (var i = 0; i < ids.length; i++) first[i] + second[i]];

    Future<void> port(List<int> progress, int level, int threshold) =>
        harness.publish(
          tester,
          portEvent,
          data: {
            ...base,
            'api_combined_flag': 2,
            'api_ndock': const [],
            'api_ship': [
              for (final (i, id) in ids.indexed)
                {
                  ...shipTemplate,
                  'api_id': id,
                  'api_lv': level,
                  'api_exp': [progress[i], threshold - progress[i], 0],
                  'api_slot': const [-1, -1, -1],
                  'api_onslot': const [0, 0, 0],
                },
            ],
            'api_deck_port': [
              {...decks[0], 'api_ship': mainIds},
              {
                ...decks[1],
                'api_ship': escortIds,
                'api_mission': const [0, 0, 0, 0],
              },
              ...decks.skip(2),
            ],
          },
        );

    Future<void> node(
      List<int> earned,
      List<List<int>> levelUps, {
      required int mainMvp,
      required int escortMvp,
    }) async {
      const hp = [28, 28, 28, 28, 28, 28];
      const maxHp = [30, 30, 30, 30, 30, 30];
      await harness.publish(
        tester,
        dayBattleEvent,
        path: '/kcsapi/api_req_combined_battle/battle',
        data: {
          ..._data(dayBattleEvent),
          'api_f_nowhps': hp,
          'api_f_maxhps': maxHp,
          'api_f_nowhps_combined': hp,
          'api_f_maxhps_combined': maxHp,
        },
      );
      await harness.publish(
        tester,
        battleResultEvent,
        path: '/kcsapi/api_req_combined_battle/battleresult',
        data: {
          ..._data(battleResultEvent),
          'api_mvp': mainMvp,
          'api_mvp_combined': escortMvp,
          'api_get_ship_exp': [-1, ...earned.take(6)],
          'api_get_ship_exp_combined': [-1, ...earned.skip(6)],
          'api_get_exp_lvup': levelUps.take(6).toList(),
          'api_get_exp_lvup_combined': levelUps.skip(6).toList(),
        },
      );
    }

    final card = find.byKey(const ValueKey(_module));
    final totalTab = find.byKey(const Key('sortie-exp-tab-total'));
    final sortieTab = find.byKey(const Key('sortie-exp-tab-sortie'));
    const battleLabel = '已结算 2 场战斗';

    void expectFleetLayout(Finder container, {required bool sideBySide}) {
      Rect row(int id) => tester.getRect(
        find.descendant(
          of: container,
          matching: find.byKey(Key('sortie-exp-ship-$id')),
        ),
      );

      final mainRows = mainIds.map(row).toList();
      final escortRows = escortIds.map(row).toList();
      final bounds = tester.getRect(container);
      for (final rect in [...mainRows, ...escortRows]) {
        expect(rect.left, greaterThanOrEqualTo(bounds.left));
        expect(rect.right, lessThanOrEqualTo(bounds.right));
      }
      for (var index = 1; index < mainRows.length; index++) {
        expect(mainRows[index].top, greaterThan(mainRows[index - 1].top));
        expect(escortRows[index].top, greaterThan(escortRows[index - 1].top));
      }
      if (sideBySide) {
        for (var index = 0; index < mainRows.length; index++) {
          expect(mainRows[index].right, lessThan(escortRows[index].left));
          expect(mainRows[index].top, closeTo(escortRows[index].top, 0.1));
        }
      } else {
        expect(mainRows.first.left, closeTo(escortRows.first.left, 0.1));
        expect(escortRows.first.top, greaterThan(mainRows.last.bottom));
      }
      expect(tester.takeException(), isNull);
    }

    try {
      await port(initial, 10, 5500);
      await _tap(tester, totalTab);
      await _tap(tester, find.byKey(const Key('sortie-exp-tracking-switch')));
      await harness.experience.idle;
      await harness.publish(tester, mapStartEvent);
      await _tap(tester, sortieTab);
      expect(_inCard(card, '主力舰队'), findsOneWidget);
      expect(_inCard(card, '护卫舰队'), findsOneWidget);
      expect(_inCard(card, '0 场战斗'), findsOneWidget);

      await node(
        first,
        [
          for (final value in initial) [value, 5500, 6600],
        ],
        mainMvp: 6,
        escortMvp: 1,
      );
      expect(_inCard(card, '1 场战斗'), findsOneWidget);
      for (final (i, id) in ids.indexed) {
        _expectHomeProgress(id, 11, '${6600 - afterFirst[i]}');
        _homeExperienceRow(tester, id, first[i]);
      }
      await harness.publish(
        tester,
        mapStartEvent,
        path: '/kcsapi/api_req_map/next',
        data: {..._data(mapStartEvent), 'api_no': 2},
        request: const {},
      );
      await node(
        second,
        [
          for (final value in afterFirst) [value, 6600],
        ],
        mainMvp: 6,
        escortMvp: 4,
      );
      expect(_inCard(card, '2 场战斗'), findsOneWidget);
      for (final (i, id) in ids.indexed) {
        _expectHomeProgress(id, 11, '${6600 - afterSecond[i]}');
        _homeExperienceRow(tester, id, gains[i]);
      }
      const expectedMvp = {9006: 2, 9101: 1, 9104: 1};
      for (final id in ids) {
        _expectHomeMvp(tester, id, expectedMvp[id] ?? 0);
      }
      _expectHomeMvp(tester, 9001, 0, percentage: '6.2%');
      _expectHomeMvp(tester, 9106, 0, percentage: '10.5%');
      expectFleetLayout(card, sideBySide: false);

      await harness.layout.moveHdModuleToSidebar('expedition');
      await harness.layout.moveHdModuleToSidebar('repair');
      expect(await harness.layout.moveHdModuleToBottom(_module), isTrue);
      for (final id in harness.layout.hdSettings.orderedModules) {
        if (id != _module) await harness.layout.toggleHdModuleHidden(id);
      }
      await harness.layout.setHdEnabled(true);
      final bottom = find.byKey(const Key('hd-module-content-$_module'));
      for (final span in [1, 2, 3]) {
        expect(await harness.layout.setHdModuleSpan(_module, span), isTrue);
        await _settle(tester);
        expectFleetLayout(bottom, sideBySide: span > 1);
      }
      expect(await harness.layout.setHdModuleSpan(_module, 2), isTrue);
      tester.view.physicalSize = const Size(700, 470);
      await _settle(tester);
      expectFleetLayout(bottom, sideBySide: false);

      for (final entry in harness.layout.hdSettings.portrait) {
        if (entry.id != _module) {
          await harness.layout.toggleHdPortraitHidden(entry.id);
        }
      }
      await harness.layout.setHdPortraitSpan(_module, 2);
      tester.view.physicalSize = const Size(820, 1000);
      await _settle(tester);
      final portrait = find.byKey(const Key('hd-portrait-cell-$_module'));
      expectFleetLayout(portrait, sideBySide: true);

      await harness.layout.setHdEnabled(false);
      tester.view.physicalSize = const Size(1700, 1050);
      await _settle(tester);
      await _tap(tester, totalTab);
      expect(_inCard(card, '总累计 0 场'), findsOneWidget);
      expect(
        await _awaitWithFrames(
          tester,
          database.getExperienceRecords(),
          'combined before port',
        ),
        isEmpty,
      );

      await port(afterSecond, 11, 6600);
      expect(_inCard(card, '总累计 1 场'), findsOneWidget);
      final totals = harness.experience.totals;
      for (var page = 0; page < 2; page++) {
        expect(_inCard(card, '${page + 1} / 2'), findsOneWidget);
        for (final ship in totals.skip(page * 10).take(10)) {
          final id = ship.ownedShipId;
          final i = ids.indexOf(id);
          _expectHomeProgress(id, 11, '${6600 - afterSecond[i]}');
          _homeExperienceRow(tester, id, gains[i]);
          _expectHomeMvp(tester, id, expectedMvp[id] ?? 0);
        }
        if (page == 0) {
          await _tap(tester, find.byKey(const Key('sortie-exp-total-next')));
        }
      }
      await _tap(tester, sortieTab);
      expect(_inCard(card, '上次出击'), findsOneWidget);
      final homeRows = [
        for (final (i, id) in ids.indexed)
          _homeExperienceRow(tester, id, gains[i]),
      ];

      await _tap(tester, find.byKey(const Key('workspace-nav-battle-records')));
      await _tap(tester, find.byKey(const Key('logbook-tab-experience')));
      final table = find.byKey(const Key('logbook-table-experience'));
      await _waitForFrame(
        tester,
        () => _inCard(table, battleLabel).evaluate().isNotEmpty,
        'combined logbook summary',
      );
      expect(_inCard(table, '主力舰队'), findsOneWidget);
      expect(_inCard(table, '护卫舰队'), findsOneWidget);
      expect(tester.widget<FrozenDataTable>(table).rowHeights, hasLength(16));
      final viewport = tester.getRect(table);
      for (final (id, _, gain, level, next) in homeRows) {
        for (final (field, value) in [
          ('value', gain),
          ('level', level),
          ('next', next),
        ]) {
          final cell = find.byKey(Key('logbook-experience-$field-$id'));
          expect(tester.widget<Text>(cell).data, value);
          expect(viewport.contains(tester.getCenter(cell)), isTrue);
        }
      }

      final records = await _awaitWithFrames(
        tester,
        database.getExperienceRecords(),
        'combined after port',
      );
      final record = records.single;
      expect(record.battles, 2);
      expect(record.incomplete, isFalse);
      expect(record.ships.map((ship) => ship.ownedShipId), ids);
      expect(record.ships.map((ship) => ship.fleetId), [
        for (final _ in mainIds) 1,
        for (final _ in escortIds) 2,
      ]);
      expect(record.ships.map((ship) => ship.experience), gains);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      LogbookDatabase.bindAccountSession(oldSession);
      await _awaitWithFrames(tester, harness.pipeline.idle, 'drain capture');
      await _awaitWithFrames(
        tester,
        harness.state.logbookIdle,
        'drain logbook',
      );
      await _awaitWithFrames(tester, database.close(), 'close combined SQLite');
    }
  });

  testWidgets('home and open logbook isolate gains and live progress through '
      'A to B to A login', (tester) async {
    const memberA = _memberId + 5;
    const memberB = _memberId + 6;
    const beforeB = [(5, 1490, 10), (7, 2690, 110)];
    const store = SharedPreferencesSortieExperienceStore();
    final databaseA = LogbookDatabase.forAccount(memberA);
    final databaseB = LogbookDatabase.forAccount(memberB);
    await _awaitWithFrames(tester, databaseA.database, 'open account A SQLite');
    await _awaitWithFrames(tester, databaseB.database, 'open account B SQLite');
    final oldSession = LogbookDatabase.accountSession;
    final harness = await _mount(
      tester,
      size: const Size(1180, 700),
      memberId: memberA,
      recordExperience: (scope, record) => LogbookDatabase.forAccount(
        scope.memberId,
      ).insertExperienceRecord(record),
    );
    LogbookDatabase.bindAccountSession(harness.account);

    final card = find.byKey(const ValueKey(_module));
    final totalTab = find.byKey(const Key('sortie-exp-tab-total'));
    final sortieTab = find.byKey(const Key('sortie-exp-tab-sortie'));
    final tracking = find.byKey(const Key('sortie-exp-tracking-switch'));
    final clear = find.byKey(const Key('sortie-exp-clear-total'));
    final page = find.byType(LogbookPage);
    final table = find.byKey(const Key('logbook-table-experience'));
    final game = find.byKey(const Key('workspace-nav-game'));

    Future<void> openLogbook() async {
      await _tap(tester, find.byKey(const Key('workspace-nav-battle-records')));
      if (tester.widget<LogbookPage>(page).selectedTabIndex != 6) {
        await _tap(tester, find.byKey(const Key('logbook-tab-experience')));
      }
      await _waitForFrame(
        tester,
        () => table.evaluate().isNotEmpty,
        'experience tab',
      );
    }

    Future<void> switchAccount(
      int memberId,
      List<(int, int, int)> ships,
    ) async {
      final openPage = tester.state(page);
      await harness.publish(tester, start2Event);
      expect(harness.account.current.isKnown, isFalse);
      expect(tester.state(page), same(openPage));
      expect(
        find.byKey(const Key('logbook-experience-value-9001')),
        findsNothing,
      );
      await harness.publish(
        tester,
        portEvent,
        data: _portData(memberId, ships),
      );
      expect(harness.account.current.memberId, memberId);
      expect(tester.state(page), same(openPage));
      expect(tester.widget<LogbookPage>(page).selectedTabIndex, 6);
    }

    Future<void> expectLogbook(
      String label,
      List<(int, int, String)> ships,
    ) async {
      await _waitForFrame(
        tester,
        () => _inCard(table, label).evaluate().isNotEmpty,
        label,
      );
      expect(tester.widget<FrozenDataTable>(table).rowHeights, hasLength(4));
      for (final (index, (gain, level, next)) in ships.indexed) {
        final id = 9001 + index;
        String? text(String field) => tester
            .widget<Text>(find.byKey(Key('logbook-experience-$field-$id')))
            .data;
        expect(text('value'), '+$gain');
        expect(text('level'), 'Lv.$level');
        expect(text('next'), 'Next. $next');
      }
      expect(_inCard(page, '总累计'), findsNothing);
    }

    try {
      final scopeA = harness.account.current;
      expect(scopeA.memberId, memberA);
      await _tap(tester, totalTab);
      await _tap(tester, tracking);
      await harness.experience.idle;
      await harness.publish(tester, mapStartEvent);
      await harness.publish(tester, dayBattleEvent);
      await harness.publishResult(tester, [360, 120], _firstNode);
      expect(_inCard(card, '总累计 0 场'), findsOneWidget);
      await harness.returnToPort(tester, [(11, 5660, 940), (12, 6770, 1030)]);
      expect(_inCard(card, '总累计 1 场'), findsOneWidget);
      _expectHomeProgress(9001, 11, '940');
      _expectHomeProgress(9002, 12, '1,030');
      _homeExperienceRow(tester, 9001, 360);
      _homeExperienceRow(tester, 9002, 120);
      final staleTracking = tester.widget<Switch>(tracking).onChanged!;
      final staleClear = tester.widget<FilledButton>(clear).onPressed!;
      final savedA = await store.load(scopeA);
      expect(savedA, isNotNull);

      await openLogbook();
      expect(LogbookDatabase.instance, same(databaseA));
      await expectLogbook('本次出击经验', [(360, 11, '940'), (120, 12, '1,030')]);
      // A's next battle changes live progress while the historical reward stays put.
      await harness.publish(tester, mapStartEvent);
      await harness.publish(tester, dayBattleEvent);
      await harness.publishResult(tester, [90, 210], _secondNode);
      expect(harness.experience.isActive, isTrue);
      await expectLogbook('本次出击经验', [(360, 11, '850'), (120, 12, '820')]);

      await switchAccount(memberB, beforeB);
      final scopeB = harness.account.current;
      expect(LogbookDatabase.instance, same(databaseB));
      await _waitForFrame(
        tester,
        () => _inCard(page, '暂无记录').hitTestable().evaluate().isNotEmpty,
        'account B empty experience log',
      );
      expect(tester.widget<FrozenDataTable>(table).rowHeights, isEmpty);
      expect(harness.experience.sortie, isNull);
      expect(harness.experience.isActive, isFalse);
      await _tap(tester, game);
      await _tap(tester, totalTab);
      expect(_inCard(card, '总累计 0 场'), findsOneWidget);
      expect(tester.widget<Switch>(tracking).value, isFalse);
      await _tap(tester, tracking);
      await harness.experience.idle;

      await openLogbook();
      await harness.publish(
        tester,
        dayBattleEvent,
        path: '/kcsapi/api_req_practice/battle',
      );
      await harness.publish(
        tester,
        battleResultEvent,
        path: '/kcsapi/api_req_practice/battle_result',
        data: {
          'api_mvp': 2,
          'api_get_ship_exp': [-1, 60, 40, -1, -1, -1, -1],
          'api_get_exp_lvup': [
            [1490, 1500, 2100],
            [2690, 2800],
          ],
        },
        request: const {},
      );
      await expectLogbook('本次演习经验', [(60, 6, '550'), (40, 7, '70')]);
      final savedB = await store.load(scopeB);
      expect(savedB, isNotNull);

      await _tap(tester, game);
      await _tap(tester, totalTab);
      expect(_inCard(card, '总累计 1 场'), findsOneWidget);
      staleTracking(false);
      staleClear();
      await harness.experience.idle;
      await _settle(tester);
      expect(find.byKey(const Key('sortie-exp-clear-dialog')), findsNothing);
      expect(tester.widget<Switch>(tracking).value, isTrue);
      expect(_inCard(card, '总累计 1 场'), findsOneWidget);
      _expectHomeProgress(9001, 6, '550');
      _expectHomeProgress(9002, 7, '70');
      _homeExperienceRow(tester, 9001, 60);
      _homeExperienceRow(tester, 9002, 40);
      _expectHomeMvp(tester, 9001, 0);
      _expectHomeMvp(tester, 9002, 1);
      expect(await store.load(scopeB), savedB);

      await openLogbook();
      await switchAccount(memberA, _afterSortie);
      expect(LogbookDatabase.instance, same(databaseA));
      await expectLogbook('本次出击经验', [(360, 11, '850'), (120, 12, '820')]);
      await _tap(tester, game);
      await _tap(tester, totalTab);
      expect(tester.widget<Switch>(tracking).value, isTrue);
      expect(_inCard(card, '总累计 1 场'), findsOneWidget);
      _homeExperienceRow(tester, 9001, 360);
      _homeExperienceRow(tester, 9002, 120);
      _expectHomeMvp(tester, 9001, 1);
      _expectHomeMvp(tester, 9002, 0);
      await _tap(tester, sortieTab);
      expect(_inCard(card, '上次出击'), findsOneWidget);
      _expectHomeMvp(tester, 9001, 1);
      _expectHomeMvp(tester, 9002, 0);
      _expectHomeProgress(9001, 11, '850');
      _expectHomeProgress(9002, 12, '820');
      expect(await store.load(scopeA), savedA);

      for (final (database, practice, gains) in [
        (databaseA, false, [360, 120]),
        (databaseB, true, [60, 40]),
      ]) {
        final records = await _awaitWithFrames(
          tester,
          database.getExperienceRecords(),
          'read account experience SQLite',
        );
        expect(records.single.isPractice, practice);
        expect(records.single.ships.map((ship) => ship.ownedShipId), [
          9001,
          9002,
        ]);
        expect(records.single.ships.map((ship) => ship.experience), gains);
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      LogbookDatabase.bindAccountSession(oldSession);
      await _awaitWithFrames(tester, harness.pipeline.idle, 'drain capture');
      await _awaitWithFrames(
        tester,
        harness.state.logbookIdle,
        'drain logbook',
      );
      await _awaitWithFrames(
        tester,
        databaseA.close(),
        'close account A SQLite',
      );
      await _awaitWithFrames(
        tester,
        databaseB.close(),
        'close account B SQLite',
      );
    }
  });

  testWidgets(
    'home editor exposes the experience card settings and visibility',
    (tester) async {
      final harness = await _mount(tester, size: const Size(1100, 620));
      final card = find.byKey(const ValueKey(_module));
      await _show(tester, card);
      await tester.longPress(_inCard(card, '出击经验'));
      await _settle(tester);
      final editor = find.byType(DashboardEditor);
      final list = find
          .descendant(of: editor, matching: find.byType(Scrollable))
          .first;
      final gear = find.byKey(const Key('$_module-display-settings-button'));
      await tester.scrollUntilVisible(gear, 180, scrollable: list);
      await _tap(tester, gear);
      expect(
        find.byKey(const Key('module-display-settings-$_module')),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('$_module-display-close')));

      final target = find.byKey(const Key('dashboard-target-$_module'));
      Future<void> toggleVisibility() async {
        await tester.scrollUntilVisible(target, 180, scrollable: list);
        final flatVisibility = find.byKey(
          const Key('dashboard-visibility-$_module'),
        );
        await _tap(
          tester,
          flatVisibility.evaluate().isNotEmpty
              ? flatVisibility
              : find
                    .descendant(of: target, matching: find.byType(Checkbox))
                    .first,
        );
      }

      await toggleVisibility();
      expect(harness.layout.dashboardCardHidden, contains(_module));
      await _tap(tester, find.byKey(const Key('dashboard-edit-done')));
      expect(card, findsNothing);

      final check = find.byKey(const ValueKey(_preSortie));
      await _show(tester, check);
      await tester.longPress(check);
      await _settle(tester);
      await toggleVisibility();
      expect(harness.layout.dashboardCardHidden, isNot(contains(_module)));
      final dragRegion = find.byKey(
        const Key('dashboard-drag-region-$_module'),
      );
      final checkTarget = find.byKey(const Key('dashboard-target-$_preSortie'));
      await _show(tester, dragRegion);
      final drop = tester.getRect(checkTarget);
      final gesture = await tester.startGesture(tester.getCenter(dragRegion));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(drop.center.dx, drop.top + 14));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await _settle(tester);
      var order = harness.layout.dashboardCardOrder;
      expect(order.indexOf(_module), lessThan(order.indexOf(_preSortie)));
      await _tap(tester, find.byKey(const Key('dashboard-edit-reset')));
      order = harness.layout.dashboardCardOrder;
      expect(order.indexOf(_module), order.indexOf(_preSortie) + 1);

      await _tap(tester, find.byKey(const Key('dashboard-edit-done')));
      expect(card, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('experience is selectable as a tab and in the HD workspace', (
    tester,
  ) async {
    final harness = await _mount(tester, size: const Size(960, 540));
    await harness.layout.setDashboardDisplayMode(DashboardDisplayMode.tabs);
    await _settle(tester);
    final experienceTab = find.byKey(const Key('dashboard-tab-$_module'));
    final checkTab = find.byKey(const Key('dashboard-tab-$_preSortie'));
    await _show(tester, experienceTab);
    expect(
      tester.getCenter(experienceTab).dx,
      greaterThan(tester.getCenter(checkTab).dx),
    );
    await _tap(tester, experienceTab);
    expect(find.byKey(const Key('sortie-exp-tab-total')), findsOneWidget);

    await harness.layout.setHdEnabled(true);
    for (final id in harness.layout.hdSettings.orderedModules) {
      if (id != _module && id != _preSortie) {
        await harness.layout.toggleHdModuleHidden(id);
      }
    }
    await _settle(tester);
    expect(experienceTab, findsNothing);
    final hdCard = find.byKey(const ValueKey(_module));
    await _show(tester, hdCard);
    expect(find.byKey(const Key('sortie-exp-tab-total')), findsOneWidget);

    expect(await harness.layout.moveHdModuleToBottom(_module), isTrue);
    await _settle(tester);
    final bottom = find.byKey(const Key('hd-module-content-$_module'));
    expect(
      find.descendant(
        of: bottom,
        matching: find.byKey(const Key('sortie-exp-tab-total')),
      ),
      findsOneWidget,
    );

    for (final entry in harness.layout.hdSettings.portrait) {
      if (entry.id != _module && entry.id != _preSortie) {
        await harness.layout.toggleHdPortraitHidden(entry.id);
      }
    }
    tester.view.physicalSize = const Size(420, 860);
    await _settle(tester);
    final portrait = find.byKey(const Key('hd-portrait-cell-$_module'));
    await _show(tester, portrait);
    expect(
      find.descendant(
        of: portrait,
        matching: find.byKey(const Key('sortie-exp-tab-total')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _inCard(Finder card, String label) =>
    find.descendant(of: card, matching: find.text(label));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _show(tester, finder);
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _waitForFrame(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  for (var frame = 0; frame < 160; frame++) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for $stage');
}

Future<T> _awaitWithFrames<T>(
  WidgetTester tester,
  Future<T> operation,
  String stage,
) async {
  var completed = false;
  final observed = operation.whenComplete(() => completed = true);
  unawaited(observed.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  await _waitForFrame(tester, () => completed, stage);
  return observed;
}

void _expectHomeProgress(int id, int level, String next) {
  expect(
    find.descendant(
      of: find.byKey(Key('sortie-exp-level-$id')),
      matching: find.text('Lv.$level'),
      matchRoot: true,
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: find.byKey(Key('sortie-exp-next-$id')),
      matching: find.text('Next. $next'),
      matchRoot: true,
    ),
    findsOneWidget,
  );
}

void _expectHomeMvp(
  WidgetTester tester,
  int id,
  int count, {
  String? percentage,
}) {
  final mvp = find.byKey(Key('sortie-exp-mvp-$id'));
  expect(tester.widget<Text>(mvp).data, '$count');
  if (percentage == null) return;

  final share = find.byKey(Key('sortie-exp-percentage-$id'));
  final amount = find.byKey(Key('sortie-exp-value-$id'));
  expect(tester.widget<Text>(share).data, percentage);
  expect(tester.getCenter(share).dy, greaterThan(tester.getCenter(amount).dy));
  expect(
    find.descendant(
      of: find.byKey(Key('sortie-exp-ship-$id')),
      matching: find.textContaining('EXP'),
    ),
    findsNothing,
  );
}

(int, String, String, String, String) _homeExperienceRow(
  WidgetTester tester,
  int id,
  int gain,
) {
  final ship = find.byKey(Key('sortie-exp-ship-$id'));
  final text = find.descendant(of: ship, matching: find.byType(Text));
  final amount = tester
      .widget<Text>(find.byKey(Key('sortie-exp-value-$id')))
      .data!;
  expect(amount, '+$gain');
  return (
    id,
    tester.widget<Text>(text.first).data!,
    amount,
    tester.widget<Text>(find.byKey(Key('sortie-exp-level-$id'))).data!,
    tester.widget<Text>(find.byKey(Key('sortie-exp-next-$id'))).data!,
  );
}

Map<String, Object?> _data(CapturedApiEvent event) => Map<String, Object?>.from(
  GameApiDecoder.decodeEnvelope(event.responseBody)['api_data'] as Map,
);

Map<String, Object?> _portData(
  int memberId, [
  List<(int, int, int)> progress = const [(10, 5300, 200), (12, 6650, 1150)],
]) {
  final data = _data(portEvent);
  final ships = (data['api_ship'] as List).cast<Map>();
  return {
    ...data,
    'api_basic': {'api_level': 120, 'api_member_id': memberId},
    'api_ship': [
      for (final (index, (level, experience, next)) in progress.indexed)
        {
          ...ships[index],
          'api_lv': level,
          'api_exp': [experience, next, 0],
        },
    ],
  };
}

Future<_HomeHarness> _mount(
  WidgetTester tester, {
  required Size size,
  int memberId = _memberId,
  Widget gameSurface = const ColoredBox(color: Colors.black),
  LogbookExperienceWriter? recordExperience,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final timersDisabled = GameStateController.disableTimerForTest;
  GameStateController.disableTimerForTest = true;
  addTearDown(() => GameStateController.disableTimerForTest = timersDisabled);

  final harness = await _HomeHarness.load(
    memberId: memberId,
    gameSurface: gameSurface,
    recordExperience: recordExperience,
  );
  await harness.publish(tester, start2Event);
  await harness.returnToPort(tester);
  await tester.pumpWidget(harness.app);
  await _settle(tester);
  return harness;
}

class _HomeHarness {
  _HomeHarness(
    this.app,
    this.layout,
    this.experience,
    this.pipeline,
    this.account,
    this.state,
    this.memberId,
  );

  final YahagiApp app;
  final LayoutSettingsController layout;
  final SortieExperienceController experience;
  final GameApiEventPipeline pipeline;
  final AccountSession account;
  final GameStateController state;
  final int memberId;
  int _sequence = 0;

  static Future<_HomeHarness> load({
    required int memberId,
    required Widget gameSurface,
    LogbookExperienceWriter? recordExperience,
  }) async {
    final account = AccountSession();
    final state = GameStateController(accountSession: account);
    final experience = SortieExperienceController(
      accountSession: account,
      gameState: () => state.state,
      gameStateChanges: state,
      recordExperience: recordExperience,
    );
    await experience.initialize();
    final battle = BattleController(
      accountSession: account,
      gameState: () => state.state,
      waitForGameState: () => state.idle,
      predictionExecutor: const ImmediateBattlePredictionExecutor(),
    );
    final pipeline = GameApiEventPipeline(
      consumers: [account, state, experience, battle],
      settleGameState: () async {
        await state.idle;
        await battle.idle;
        await state.idle;
      },
      // The harness supplies small, deterministic fixture envelopes.
      decodeEnvelope: (body) async => GameApiDecoder.decodeEnvelope(body),
    );
    final layout = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    await layout.setLocaleCode('zh');
    for (final id in layout.dashboardCardOrder) {
      if (id != _module && id != _preSortie) {
        await layout.toggleDashboardCardHidden(id);
      }
    }
    final display = await DisplayModeController.load(MemoryDisplayModeStore());
    final network = NetworkSettingsController(
      store: SharedPreferencesNetworkSettingsStore(),
    );
    final bypass = GadgetBypassController(
      store: SharedPreferencesGadgetBypassStore(),
      port: MethodChannelGadgetBypassPort(),
    );
    final safety = await SafetySettingsController.load(
      MemorySafetySettingsStore(),
    );
    final status = PrototypeStatusController();
    final browser = GameBrowserController();
    final captureMode = await CaptureModeController.load(
      SharedPreferencesCaptureModeStore(),
    );
    final capture = GameCaptureController(onAcceptedEvent: pipeline.add);
    final audio = await GameAudioController.load(
      SharedPreferencesGameAudioStore(),
    );
    final toolbar = GameToolbarController();
    final app = YahagiApp(
      layoutSettingsController: layout,
      displayModeController: display,
      networkSettingsController: network,
      gadgetBypassController: bypass,
      safetySettingsController: safety,
      controller: status,
      browserController: browser,
      captureModeController: captureMode,
      gameCaptureController: capture,
      gameStateController: state,
      battleController: battle,
      sortieExperienceController: experience,
      audioController: audio,
      toolbarController: toolbar,
      gameSurface: gameSurface,
    );
    addTearDown(() {
      for (final notifier in <ChangeNotifier>[
        toolbar,
        audio,
        capture,
        captureMode,
        browser,
        status,
        safety,
        bypass,
        network,
        display,
        layout,
        battle,
        experience,
        state,
        account,
      ]) {
        notifier.dispose();
      }
    });
    return _HomeHarness(
      app,
      layout,
      experience,
      pipeline,
      account,
      state,
      memberId,
    );
  }

  Future<void> publish(
    WidgetTester tester,
    CapturedApiEvent fixture, {
    String? path,
    Map<String, Object?>? data,
    Map<String, Object?>? request,
    int apiResult = 1,
  }) async {
    enqueue(
      fixture,
      path: path,
      data: data,
      request: request,
      apiResult: apiResult,
    );
    await pipeline.idle;
    await _settle(tester);
  }

  void enqueue(
    CapturedApiEvent fixture, {
    String? path,
    Map<String, Object?>? data,
    Map<String, Object?>? request,
    int apiResult = 1,
  }) {
    pipeline.add(
      kcsapiEvent(
        path ?? fixture.path,
        data ?? _data(fixture),
        apiResult: apiResult,
        sequence: ++_sequence,
        requestParams: request ?? fixture.requestParams,
      ),
    );
  }

  Future<void> publishResult(
    WidgetTester tester,
    List<int> gains, [
    List<List<int>>? levels,
  ]) => publish(
    tester,
    battleResultEvent,
    data: {
      ..._data(battleResultEvent),
      'api_get_ship_exp': [-1, ...gains, -1, -1, -1, -1],
      'api_get_exp_lvup': ?levels,
    },
  );

  Future<void> returnToPort(
    WidgetTester tester, [
    List<(int, int, int)>? progress,
  ]) => publish(
    tester,
    portEvent,
    data: progress == null
        ? _portData(memberId)
        : _portData(memberId, progress),
  );
}
