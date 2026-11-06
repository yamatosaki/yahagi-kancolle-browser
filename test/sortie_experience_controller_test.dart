import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_experience_record.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'total ship visibility persists separately from cumulative experience',
    () async {
      final store = _MemoryStore();
      final records = <LogbookExperienceRecord>[];
      final fixture = _Fixture(
        store: store,
        recordExperience: (_, record) async => records.add(record),
      );
      addTearDown(fixture.dispose);
      final controller = fixture.controller;
      final account = fixture.session.current;
      await controller.initialize();
      expect(controller.isTotalShipVisibilityReady, isTrue);
      expect(controller.hiddenTotalShipIds, isEmpty);

      await controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 40, 20]);
      await fixture.port();
      final archive = store._saved[1];

      final hideLead = controller.setHiddenTotalShipIds({
        10,
      }, expectedAccount: account);
      expect(controller.hiddenTotalShipIds, {10});
      final hideSecond = controller.setHiddenTotalShipIds({
        10,
        11,
      }, expectedAccount: account);
      expect(controller.hiddenTotalShipIds, {10, 11});
      final showSecond = controller.setHiddenTotalShipIds({
        10,
      }, expectedAccount: account);
      final staleRow = controller.setHiddenTotalShipIds({
        10,
        999,
      }, expectedAccount: account);
      expect(controller.hiddenTotalShipIds, {10});
      await Future.wait([hideLead, hideSecond, showSecond, staleRow]);
      expect(store._saved[1], archive);
      expect(records, hasLength(1));

      await fixture.start();
      await fixture.result([-1, 50, 30]);
      await fixture.port();
      await fixture.start(deckId: 2);
      await fixture.result([-1, 60, 10]);
      await fixture.port();
      expect(controller.hiddenTotalShipIds, {10});
      expect(fixture.totalExperience, {10: 90, 11: 50, 12: 60, 13: 10});
      expect(controller.totalSorties, 3);
      expect(records, hasLength(3));

      final reopened = _Fixture(store: store);
      addTearDown(reopened.dispose);
      await reopened.controller.initialize();
      expect(reopened.controller.hiddenTotalShipIds, {10});
      expect(reopened.totalExperience, fixture.totalExperience);
      await reopened.controller.setHiddenTotalShipIds(
        {},
        expectedAccount: reopened.session.current,
      );
      expect(reopened.controller.hiddenTotalShipIds, isEmpty);
      final restored = _Fixture(store: store);
      addTearDown(restored.dispose);
      await restored.controller.initialize();
      expect(restored.controller.hiddenTotalShipIds, isEmpty);
      expect(restored.totalExperience, fixture.totalExperience);
    },
  );

  test(
    'total ship visibility is isolated by account and rejects stale callbacks',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final controller = fixture.controller;
      final firstScope = fixture.session.current;
      await controller.initialize();
      await controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 40, 20]);
      await fixture.port();

      final pendingFirst = controller.setHiddenTotalShipIds({
        10,
      }, expectedAccount: firstScope);
      fixture.session.selectMember(2);
      fixture.state = fixture.state.copyWith(memberId: 2);
      expect(controller.hiddenTotalShipIds, isEmpty);
      await controller.initialize();
      final secondScope = fixture.session.current;
      await controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 100, 200]);
      await fixture.port();
      final pendingSecond = controller.setHiddenTotalShipIds({
        11,
      }, expectedAccount: secondScope);
      expect(controller.hiddenTotalShipIds, {11});

      fixture.session.selectMember(1);
      fixture.state = fixture.state.copyWith(memberId: 1);
      expect(controller.isTotalShipVisibilityReady, isFalse);
      await controller.initialize();
      expect(controller.hiddenTotalShipIds, {10});
      await controller.setHiddenTotalShipIds({}, expectedAccount: firstScope);
      await controller.setHiddenTotalShipIds({
        11,
      }, expectedAccount: secondScope);
      expect(controller.hiddenTotalShipIds, {10});
      expect(fixture.totalExperience, {10: 40, 11: 20});

      await Future.wait([pendingFirst, pendingSecond]);
      fixture.session.selectMember(2);
      fixture.state = fixture.state.copyWith(memberId: 2);
      await controller.initialize();
      expect(controller.hiddenTotalShipIds, {11});
      expect(fixture.totalExperience, {10: 100, 11: 200});
    },
  );

  test('a blocked logbook write does not hold up another account', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondWritten = Completer<void>();
    final fixture = _Fixture(
      recordExperience: (scope, record) async {
        if (scope.memberId == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        } else {
          expect(scope.memberId, 2);
          expect(record.isPractice, isTrue);
          secondWritten.complete();
        }
      },
    );
    addTearDown(fixture.dispose);
    await fixture.start();
    await fixture.result([-1, 40, 20]);
    final first = fixture.port();
    final remaining = <Future<void>>[first];
    try {
      await firstStarted.future.timeout(const Duration(seconds: 3));
      fixture.session.selectMember(2);
      fixture.state = fixture.state.copyWith(memberId: 2);
      remaining.add(fixture.practiceStart());
      remaining.add(fixture.practiceResult([-1, 90, 30]));
      await secondWritten.future.timeout(const Duration(seconds: 3));
    } finally {
      releaseFirst.complete();
      await Future.wait(remaining);
    }
  });

  test(
    'an older archive resets only totals already over seven digits',
    () async {
      final store = _MemoryStore();
      final fixture = _Fixture(store: store);
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 70, 80]);
      await fixture.port();

      final archive = jsonDecode(store._saved[1]!) as Map<String, Object?>;
      (archive['totals'] as List).first['experience'] = 10000000;
      store._saved[1] = jsonEncode(archive);

      final reopened = _Fixture(store: store);
      addTearDown(reopened.dispose);
      await reopened.controller.initialize();
      expect(reopened.controller.totalSorties, 1);
      expect(reopened.totalExperience, {10: 0, 11: 80});
      expect(reopened.experience, [70, 80]);
    },
  );

  test('an explicit roster refresh replaces provisional progress', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.state = fixture.state.copyWith(
      ships: const {
        10: OwnedShip(id: 10, masterId: 101, level: 99, experience: 1000000),
        11: OwnedShip(id: 11, masterId: 101, level: 99, experience: 1000000),
      },
    );
    await fixture.practiceStart();
    await fixture.practiceResult([-1, 40, 20]);
    expect(fixture.controller.progressFor(10), (
      level: 100,
      nextExperience: 9960,
    ));
    await fixture.send('/kcsapi/api_get_member/ship_deck', {
      'api_ship_data': [
        {
          'api_id': 10,
          'api_lv': 99,
          'api_exp': [1000000, 0, 0],
        },
      ],
    });
    expect(fixture.controller.progressFor(10), (level: 99, nextExperience: 0));
    expect(fixture.controller.progressFor(11), (
      level: 100,
      nextExperience: 9980,
    ));
  });

  test(
    'a seven-ship result with six rewards keeps the verified slots',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.state = fixture.state.copyWith(
        fleets: const [
          Fleet(
            id: 3,
            name: '第三',
            shipIds: [10, 11, 12, 13, 14, 15, 16],
            slotCount: 7,
          ),
        ],
      );
      await fixture.start(deckId: 3);
      await fixture.result([
        -1,
        10,
        20,
        30,
        40,
        50,
        60,
      ], mainProgress: List.filled(7, [0, 100]));
      final snapshot = fixture.controller.sortie!;
      expect(snapshot.incomplete, isTrue);
      expect(snapshot.ships.map(snapshot.confirmedExperience), [
        10,
        20,
        30,
        40,
        50,
        60,
        null,
      ]);
      expect(fixture.controller.progressFor(15), (
        level: 1,
        nextExperience: 40,
      ));
      expect(fixture.controller.progressFor(16), (level: 1, nextExperience: 0));
    },
  );

  test('the seven-digit total resets only the copy that exceeds it', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.controller.setTrackingEnabled(true);
    await fixture.start();
    await fixture.result([-1, 9999999, 9999998]);
    await fixture.port();
    expect(fixture.totalExperience, {10: 9999999, 11: 9999998});

    await fixture.practiceStart();
    await fixture.practiceResult([-1, 1, 1]);
    expect(fixture.experience, [1, 1]);
    expect(fixture.totalExperience, {10: 0, 11: 9999999});
    expect(fixture.controller.totalSorties, 2);

    final reopened = _Fixture();
    addTearDown(reopened.dispose);
    await reopened.controller.initialize();
    expect(reopened.totalExperience, {10: 0, 11: 9999999});
    await reopened.start();
    await reopened.result([-1, 7, 2]);
    expect(reopened.totalExperience, {10: 0, 11: 9999999});
    await reopened.port();
    expect(reopened.totalExperience, {10: 7, 11: 0});
    expect(reopened.controller.totalSorties, 3);
  });

  test('continues past level 99 and caps progression at level 188', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.state = fixture.state.copyWith(
      ships: const {
        10: OwnedShip(
          id: 10,
          masterId: 101,
          level: 98,
          experience: 999900,
          nextExperience: 100,
        ),
        11: OwnedShip(
          id: 11,
          masterId: 101,
          level: 187,
          experience: 20199900,
          nextExperience: 100,
        ),
      },
    );
    await fixture.start();
    await fixture.result(
      [-1, 300, 400],
      mainProgress: [
        [999900, 1000000],
        [20199900, 20200000],
      ],
    );
    expect(fixture.controller.progressFor(10), (
      level: 100,
      nextExperience: 9800,
    ));
    expect(fixture.controller.progressFor(11), (level: 188, nextExperience: 0));
    await fixture.next(2);
    await fixture.result(
      [-1, 100, 500],
      mainProgress: [
        [1000000],
        [20200000],
      ],
    );
    expect(fixture.controller.progressFor(10), (
      level: 100,
      nextExperience: 9700,
    ));
    expect(fixture.controller.progressFor(11), (level: 188, nextExperience: 0));
  });

  test(
    'updates each copy immediately across combined nodes and practice',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.state = fixture.state.copyWith(
        combinedFleetType: CombinedFleetType.surfaceTaskForce,
        ships: const {
          10: OwnedShip(
            id: 10,
            masterId: 101,
            level: 10,
            experience: 5300,
            nextExperience: 200,
          ),
          11: OwnedShip(id: 11, masterId: 101, level: 99, experience: 1000000),
          12: OwnedShip(
            id: 12,
            masterId: 101,
            level: 12,
            experience: 6700,
            nextExperience: 1100,
          ),
          13: OwnedShip(id: 13, masterId: 101, level: 1, nextExperience: 100),
        },
      );
      final controller = fixture.controller;
      await controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result(
        [-1, 350, 40],
        escort: [-1, 75, 610],
        mainProgress: [
          [5300, 5500, 6600],
          [1000000],
        ],
        escortProgress: [
          [6700, 7800],
          [0, 100, 300, 600, 1000],
        ],
      );
      expect(controller.progressFor(10), (level: 11, nextExperience: 950));
      expect(controller.progressFor(11), (level: 100, nextExperience: 9960));
      expect(controller.progressFor(12), (level: 12, nextExperience: 1025));
      expect(controller.progressFor(13), (level: 4, nextExperience: 390));
      expect(controller.totalSorties, 0);

      await fixture.next(2);
      await fixture.result([-1, 950, 10], escort: [-1, 200, 90]);
      expect(controller.progressFor(10), (level: 12, nextExperience: 1200));
      expect(controller.progressFor(12), (level: 12, nextExperience: 825));
      expect(controller.progressFor(13), (level: 4, nextExperience: 300));
      expect(fixture.experience, [1300, 50, 275, 700]);
      await fixture.port();
      expect(fixture.totalExperience, {10: 1300, 11: 50, 12: 275, 13: 700});

      // The authoritative roster includes both awards already.
      fixture.state = fixture.state.copyWith(
        ships: {
          ...fixture.state.ships,
          10: const OwnedShip(
            id: 10,
            masterId: 101,
            level: 12,
            experience: 6600,
            nextExperience: 1200,
          ),
        },
      );
      expect(controller.progressFor(10), (level: 12, nextExperience: 1200));
      await fixture.practiceStart();
      await fixture.practiceResult([-1, 100, 10]);
      expect(controller.progressFor(10), (level: 12, nextExperience: 1100));
      expect(controller.progressFor(12), (level: 12, nextExperience: 825));
      expect(fixture.totalExperience, {10: 1400, 11: 60, 12: 275, 13: 700});
    },
  );

  test(
    'practice shows its own roster and settles before returning to port',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.practiceStart(deckId: 2);
      expect(fixture.controller.isActive, isTrue);
      final live = fixture.controller.sortie!;
      expect(live.isPractice, isTrue);
      expect(
        (live.mapAreaId, live.mapInfoNo, live.deckId, live.battles),
        (0, 0, 2, 0),
      );
      expect(live.ships.map((ship) => ship.ownedShipId), [12, 13]);
      expect(fixture.experience, [0, 0]);
      await fixture.send('/kcsapi/api_req_practice/midnight_battle', {
        'api_deck_id': 2,
      });
      expect(fixture.controller.totalSorties, 0);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.practiceResult([-1, 180, 0, -1, -1, -1, -1]);
      expect(fixture.controller.isActive, isFalse);
      expect(fixture.controller.sortie!.isPractice, isTrue);
      expect(fixture.controller.sortie!.battles, 1);
      expect(fixture.experience, [180, 0]);
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.totalExperience, {12: 180, 13: 0});

      await fixture.practiceResult([-1, 180, 0, -1, -1, -1, -1]);
      await fixture.port();
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.totalExperience, {12: 180, 13: 0});
      await fixture.practiceStart(deckId: 2);
      await fixture.controller.setTrackingEnabled(false);
      await fixture.practiceResult([-1, 75, 25]);
      expect(fixture.experience, [75, 25]);
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.totalExperience, {12: 180, 13: 0});
    },
  );

  test(
    'practice and ordinary sorties finalize only at their own boundaries',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.practiceStart();
      await fixture.practiceResult([-1, 50, 20]);
      await fixture.start();
      expect(fixture.controller.sortie!.isPractice, isFalse);
      await fixture.result([-1, 25, 10]);
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.totalExperience, {10: 50, 11: 20});
      await fixture.port();
      expect(fixture.controller.totalSorties, 2);
      expect(fixture.totalExperience, {10: 75, 11: 30});

      // A confirmed exercise can replace a map run whose port was not captured.
      await fixture.start();
      await fixture.result([-1, 600, 300]);
      await fixture.practiceStart();
      await fixture.practiceResult([-1, 40, 20]);
      await fixture.port();
      expect(fixture.controller.sortie!.isPractice, isTrue);
      expect(fixture.controller.totalSorties, 3);
      expect(fixture.totalExperience, {10: 115, 11: 50});

      await fixture.practiceStart();
      await fixture.start();
      await fixture.practiceResult([-1, 900, 900]);
      expect(fixture.controller.sortie!.isPractice, isFalse);
      expect(fixture.experience, [0, 0]);
      expect(fixture.controller.totalSorties, 3);
    },
  );

  test(
    'unverified exercise results cannot replace the last recorded experience',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.practiceResult([-1, 400, 300]);
      expect(fixture.controller.sortie, isNull);
      await fixture.practiceStart();
      await fixture.practiceResult([-1, 30, 20]);
      await fixture.practiceStart();
      await fixture.practiceResult([-1, 999]);
      expect(fixture.controller.isActive, isFalse);
      expect(fixture.experience, [30, 20]);
      await fixture.practiceStart();
      await fixture.port();
      await fixture.practiceResult([-1, 400, 300]);
      expect(fixture.controller.isActive, isFalse);
      expect(fixture.experience, [30, 20]);
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.totalExperience, {10: 30, 11: 20});
    },
  );

  test(
    'old map archive and newly saved practice both restore per account',
    () async {
      final store = _MemoryStore();
      await store.save(const AccountScope(memberId: 1, generation: 0), '''
      {"version":1,"memberId":1,"tracking":true,"last":{"mapAreaId":5,
       "mapInfoNo":3,"deckId":1,"battles":1,"ships":[],"incomplete":true},
       "totalSorties":0,"totals":[]}
    ''');
      final fixture = _Fixture(store: store);
      addTearDown(fixture.dispose);
      await fixture.controller.initialize();
      expect(fixture.controller.sortie!.isPractice, isFalse);
      expect(fixture.controller.sortie!.mapAreaId, 5);
      await fixture.practiceStart();
      await fixture.practiceResult([-1, 100, 40]);

      final reopened = _Fixture(store: store);
      addTearDown(reopened.dispose);
      await reopened.controller.initialize();
      expect(reopened.controller.isActive, isFalse);
      expect(reopened.controller.sortie!.isPractice, isTrue);
      expect(reopened.experience, [100, 40]);
      expect(reopened.controller.totalSorties, 1);

      reopened.session.selectMember(2);
      reopened.state = reopened.state.copyWith(memberId: 2);
      await reopened.controller.idle;
      expect(reopened.controller.sortie, isNull);
      expect(reopened.controller.totalSorties, 0);
      reopened.session.selectMember(1);
      reopened.state = reopened.state.copyWith(memberId: 1);
      await reopened.controller.idle;
      expect(reopened.controller.sortie!.isPractice, isTrue);
      expect(reopened.totalExperience, {10: 100, 11: 40});
    },
  );

  test(
    'a slow history write cannot block the next sortie or its switch',
    () async {
      final writing = Completer<void>();
      final finishWrite = Completer<void>();
      final fixture = _Fixture(
        recordExperience: (_, _) async {
          writing.complete();
          await finishWrite.future;
        },
      );
      addTearDown(fixture.dispose);
      await fixture.start();
      await fixture.result([-1, 40, 20]);

      final returning = fixture.port();
      Future<void>? nextSortie;
      try {
        await writing.future.timeout(const Duration(seconds: 2));
        nextSortie = fixture.start();
        await fixture.controller
            .setTrackingEnabled(true)
            .timeout(const Duration(seconds: 2));
        expect(fixture.controller.isActive, isTrue);
        expect(fixture.experience, [0, 0]);
        expect(fixture.controller.trackingEnabled, isTrue);
      } finally {
        finishWrite.complete();
        await returning;
        await nextSortie;
      }
    },
  );

  test(
    'an unwritten history record survives restart and retries once',
    () async {
      final store = _MemoryStore();
      final fixture = _Fixture(
        store: store,
        recordExperience: (_, _) async => throw StateError('Database offline'),
      );
      await fixture.controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 45, 0]);
      await fixture.port();
      expect(fixture.controller.totalSorties, 1);
      fixture.dispose();

      final records = <LogbookExperienceRecord>[];
      final reopened = _Fixture(
        store: store,
        recordExperience: (scope, record) async {
          expect(scope.memberId, 1);
          records.add(record);
        },
      );
      addTearDown(reopened.dispose);
      await reopened.controller.initialize();
      expect(reopened.controller.totalSorties, 1);
      expect(records.single.ships.map((ship) => ship.experience), [45, 0]);

      final again = _Fixture(
        store: store,
        recordExperience: (_, record) async => records.add(record),
      );
      addTearDown(again.dispose);
      await again.controller.initialize();
      expect(again.controller.totalSorties, 1);
      expect(records, hasLength(1));
    },
  );

  test('queued history retains its owner during an account switch', () async {
    final firstWrite = Completer<void>();
    final releaseWrite = Completer<void>();
    final written = <(int, bool)>[];
    final fixture = _Fixture(
      recordExperience: (scope, record) async {
        if (!firstWrite.isCompleted) {
          firstWrite.complete();
          await releaseWrite.future;
        }
        written.add((scope.memberId, record.isPractice));
      },
    );
    addTearDown(fixture.dispose);
    await fixture.start();
    await fixture.result([-1, 40, 20]);

    final returning = fixture.port();
    Future<void>? exerciseStart;
    Future<void>? exerciseEnd;
    try {
      await firstWrite.future.timeout(const Duration(seconds: 2));
      exerciseStart = fixture.practiceStart();
      exerciseEnd = fixture.practiceResult([-1, 90, 30]);
      await fixture.controller.setTrackingEnabled(true);
      expect(fixture.controller.sortie!.isPractice, isTrue);
      fixture.session.selectMember(2);
    } finally {
      releaseWrite.complete();
      await returning;
      await exerciseStart;
      await exerciseEnd;
    }
    expect(written, [(1, false), (1, true)]);
    expect(fixture.controller.sortie, isNull);
    expect(fixture.controller.totalSorties, 0);
  });

  test(
    'sortie history records the full run only after validated port',
    () async {
      final records = <LogbookExperienceRecord>[];
      final fixture = _Fixture(
        recordExperience: (scope, record) async {
          expect(scope.memberId, 1);
          records.add(record);
        },
      );
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 100, 50]);
      await fixture.controller.clearTotal();
      await fixture.controller.setTrackingEnabled(false);
      await fixture.next(2);
      await fixture.result([-1, 20, 30]);
      await fixture.send('/kcsapi/api_req_sortie/goback_port', null);
      await fixture.send('/kcsapi/api_port/port', {
        'api_basic': {'api_member_id': 2},
      });
      expect(records, isEmpty);
      await fixture.port();
      await fixture.port();

      final record = records.single;
      expect(record.isPractice, isFalse);
      expect((record.mapAreaId, record.mapInfoNo, record.deckId), (5, 3, 1));
      expect(record.battles, 2);
      expect(record.incomplete, isFalse);
      expect(record.ships.map((ship) => ship.ownedShipId), [10, 11]);
      expect(record.ships.map((ship) => ship.experience), [120, 80]);
      expect(fixture.controller.totalSorties, 0);
      await fixture.controller.clearTotal();
      expect(records, hasLength(1));
    },
  );

  test(
    'partial history distinguishes verified zero from missing rewards',
    () async {
      final records = <LogbookExperienceRecord>[];
      final fixture = _Fixture(
        recordExperience: (_, record) async {
          records.add(record);
        },
      );
      addTearDown(fixture.dispose);
      fixture.state = fixture.state.copyWith(
        combinedFleetType: CombinedFleetType.surfaceTaskForce,
      );
      await fixture.start();
      await fixture.result([-1, 0, 20], escort: [-1, 50]);
      await fixture.port();

      final record = records.single;
      expect(record.incomplete, isTrue);
      expect(record.ships.map((ship) => ship.fleetId), [1, 1, 2, 2]);
      expect(record.ships.map((ship) => ship.experience), [0, 20, null, null]);
      final reopened = _Fixture();
      addTearDown(reopened.dispose);
      await reopened.controller.initialize();
      final snapshot = reopened.controller.sortie!;
      expect(snapshot.ships.map(snapshot.confirmedExperience), [
        0,
        20,
        null,
        null,
      ]);
    },
  );

  test('history skips a sortie without verifiable rewards', () async {
    final records = <LogbookExperienceRecord>[];
    final fixture = _Fixture(
      recordExperience: (_, record) async {
        records.add(record);
      },
    );
    addTearDown(fixture.dispose);
    await fixture.start();
    await fixture.result([-1, 300]);
    await fixture.port();
    expect(records, isEmpty);
    expect(fixture.controller.sortie!.incomplete, isTrue);
  });

  test('day and night practice settle once using the day formation', () async {
    final records = <LogbookExperienceRecord>[];
    final fixture = _Fixture(
      recordExperience: (_, record) async {
        records.add(record);
      },
    );
    addTearDown(fixture.dispose);
    await fixture.controller.setTrackingEnabled(true);
    fixture.state = fixture.state.copyWith(
      combinedFleetType: CombinedFleetType.surfaceTaskForce,
    );
    await fixture.send('/kcsapi/api_req_practice/battle', {'api_deck_id': 2});
    fixture.state = fixture.state.copyWith(
      fleets: const [
        Fleet(id: 2, name: '第二', shipIds: [13, 12]),
      ],
    );
    await fixture.send('/kcsapi/api_req_practice/midnight_battle', {
      'api_deck_id': 2,
    });
    final rewards = {
      'api_get_ship_exp': [-1, 120, 0, -1, -1, -1, -1],
    };
    await fixture.send('/kcsapi/api_req_practice/battle_result', rewards);
    await fixture.send('/kcsapi/api_req_practice/battle_result', rewards);

    final record = records.single;
    expect(record.isPractice, isTrue);
    expect(record.battles, 1);
    expect(record.deckId, 2);
    expect(record.ships.map((ship) => ship.ownedShipId), [12, 13]);
    expect(record.ships.map((ship) => ship.experience), [120, 0]);
    expect(fixture.controller.sortie!.isPractice, isTrue);
    expect(fixture.controller.totalSorties, 1);
  });

  test('practice history rejects unanchored or stale settlements', () async {
    final records = <LogbookExperienceRecord>[];
    final fixture = _Fixture(
      recordExperience: (_, record) async {
        records.add(record);
      },
    );
    addTearDown(fixture.dispose);
    final rewards = {
      'api_get_ship_exp': [-1, 100, 50],
    };
    await fixture.send('/kcsapi/api_req_practice/battle_result', rewards);
    await fixture.send('/kcsapi/api_req_practice/battle', {'api_deck_id': 1});
    fixture.controller.interruptCaptureContinuity();
    await fixture.send('/kcsapi/api_req_practice/midnight_battle', {
      'api_deck_id': 1,
    });
    await fixture.send('/kcsapi/api_req_practice/battle_result', rewards);
    await fixture.send('/kcsapi/api_req_practice/battle', {'api_deck_id': 1});
    fixture.session.selectMember(2);
    fixture.state = fixture.state.copyWith(memberId: 2);
    await fixture.send('/kcsapi/api_req_practice/battle_result', rewards);
    expect(records, isEmpty);
  });

  test(
    'history write retries retain one event key and original owner',
    () async {
      final attempts = <(int, String)>[];
      final fixture = _Fixture(
        recordExperience: (scope, record) async {
          attempts.add((scope.memberId, record.eventKey));
          if (attempts.length == 1) throw StateError('Test write interrupted');
        },
      );
      addTearDown(fixture.dispose);
      await fixture.start();
      await fixture.result([-1, 75, 25]);
      await fixture.port();
      expect(attempts, hasLength(1));
      fixture.session.selectMember(2);
      fixture.state = fixture.state.copyWith(memberId: 2);
      await fixture.port();
      expect(attempts, hasLength(1));
      fixture.session.selectMember(1);
      fixture.state = fixture.state.copyWith(memberId: 1);
      await fixture.port();
      await fixture.port();
      expect(attempts, [attempts.first, attempts.first]);
    },
  );

  test(
    'live experience uses node rewards and books the tracked part on port',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.controller.initialize();
      await fixture.start();
      expect(fixture.controller.isActive, isTrue);
      expect(fixture.experience, [0, 0]);

      await fixture.result([-1, 100, 50, -1, -1, -1, -1]);
      await fixture.result([-1, 100, 50, -1, -1, -1, -1]);
      expect(fixture.experience, [100, 50]);
      expect(fixture.controller.sortie!.battles, 1);

      await fixture.controller.setTrackingEnabled(true);
      await fixture.next(2);
      await fixture.result([-1, 100, 50, -1, -1, -1, -1]);
      await fixture.controller.setTrackingEnabled(false);
      expect(fixture.experience, [200, 100]);
      expect(fixture.controller.totalSorties, 0);
      expect(fixture.controller.totals, isEmpty);

      await fixture.send('/kcsapi/api_req_sortie/goback_port', null);
      expect(fixture.controller.isActive, isTrue);
      await fixture.port();
      await fixture.port();
      expect(fixture.controller.isActive, isFalse);
      expect(fixture.experience, [200, 100]);
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.totalExperience, {10: 100, 11: 50});
      expect(fixture.controller.totals.map((ship) => ship.name), ['夕張', '夕張']);
      expect(fixture.controller.sortie!.incomplete, isFalse);
    },
  );

  test('combined rewards stay on their original slots after retreat', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.state = fixture.state.copyWith(
      combinedFleetType: CombinedFleetType.surfaceTaskForce,
    );
    await fixture.start();
    await fixture.result([-1, 111, 222], escort: [-1, 333, 444]);
    fixture.state = fixture.state.copyWith(
      combatState: const CombatState(
        isActive: true,
        sortieFleetId: 1,
        mapArea: 5,
        mapInfo: 3,
        currentNode: 1,
        pendingEscapeShipIds: [10, 12],
      ),
    );
    await fixture.send('/kcsapi/api_req_combined_battle/goback_port', null);
    expect(fixture.controller.isActive, isTrue);
    expect(
      fixture.controller.sortie!.ships
          .where((ship) => ship.retreated)
          .map((ship) => ship.ownedShipId),
      [10, 12],
    );
    await fixture.next(2);
    await fixture.result([-1, -1, 20], escort: [-1, 0, 40]);
    expect(fixture.experience, [111, 242, 333, 484]);
    expect(fixture.controller.sortie!.incomplete, isFalse);
  });

  test(
    'seven-ship fleet preserves slot seven and rejects ambiguous arrays',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.state = fixture.state.copyWith(
        fleets: const [
          Fleet(
            id: 3,
            name: '第三',
            shipIds: [10, 11, 12, 13, 14, 15, 16],
            slotCount: 7,
          ),
        ],
      );
      await fixture.start(deckId: 3);
      await fixture.result([-1, 10, 20, 30, 40, 50, 60, 70]);
      expect(fixture.experience, [10, 20, 30, 40, 50, 60, 70]);
      await fixture.next(2);
      await fixture.result([999, 20, 30, 40, 50, 60, 70]);
      expect(fixture.experience, [10, 20, 30, 40, 50, 60, 70]);
      expect(fixture.controller.sortie!.incomplete, isTrue);
    },
  );

  test(
    'clear discards pending total without resetting the active sortie',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 100, 200]);
      await fixture.controller.clearTotal();
      expect(fixture.experience, [100, 200]);
      await fixture.next(2);
      await fixture.result([-1, 30, 40]);
      await fixture.port();
      expect(fixture.controller.totalSorties, 1);
      expect(fixture.totalExperience, {10: 30, 11: 40});
    },
  );

  test(
    'interruption keeps known rewards and rejects unanchored settlement',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.start();
      await fixture.result([-1, 20, 10]);
      fixture.controller.interruptCaptureContinuity();
      await fixture.result([-1, 100, 50]);
      await fixture.next(2);
      await fixture.result([-1, 30, 15]);
      await fixture.port();
      expect(fixture.experience, [50, 25]);
      expect(fixture.controller.sortie!.battles, 2);
      expect(fixture.controller.sortie!.incomplete, isTrue);
    },
  );

  test(
    'account switch drops active pending data and restores completed archives',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 15, 20]);
      await fixture.port();
      await fixture.start();
      await fixture.result([-1, 100, 120]);

      fixture.session.selectMember(2);
      fixture.state = fixture.state.copyWith(memberId: 2);
      await fixture.port();
      expect(fixture.controller.sortie, isNull);
      expect(fixture.controller.totalSorties, 0);
      expect(fixture.controller.trackingEnabled, isFalse);

      fixture.session.selectMember(1);
      fixture.state = fixture.state.copyWith(memberId: 1);
      await fixture.controller.idle;
      expect(fixture.controller.isActive, isFalse);
      expect(fixture.experience, [15, 20]);
      expect(fixture.totalExperience, {10: 15, 11: 20});
      expect(fixture.controller.trackingEnabled, isTrue);
    },
  );

  test('failed port and unanchored results do not change totals', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.controller.setTrackingEnabled(true);
    await fixture.result([-1, 600, 400]);
    expect(fixture.controller.sortie, isNull);
    await fixture.start();
    await fixture.send('/kcsapi/api_req_practice/battle_result', {
      'api_get_ship_exp': [-1, 900, 900],
    });
    expect(fixture.experience, [0, 0]);
    await fixture.result([-1, 40, 20]);
    await fixture.send('/kcsapi/api_port/port', {
      'api_basic': {'api_member_id': 1},
    }, apiResult: 0);
    await fixture.send('/kcsapi/api_port/port', {});
    expect(fixture.controller.isActive, isTrue);
    expect(fixture.controller.totalSorties, 0);
    await fixture.port();
    expect(fixture.totalExperience, {10: 40, 11: 20});
  });

  test(
    'replayed result cannot settle a newly reached node before a battle',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.start();
      await fixture.result([-1, 30, 10]);
      await fixture.next(2);
      await fixture.result([-1, 30, 10], withBattle: false);
      expect(fixture.controller.sortie!.battles, 1);
      expect(fixture.experience, [30, 10]);
      await fixture.result([-1, 40, 20]);
      expect(fixture.experience, [70, 30]);
    },
  );

  test('lost result marks incomplete on navigation and on real port', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.start();
    await fixture.battle();
    await fixture.next(2);
    expect(fixture.controller.sortie!.incomplete, isTrue);
    await fixture.port();
    await fixture.start();
    await fixture.battle();
    await fixture.port();
    expect(fixture.controller.sortie!.incomplete, isTrue);
    expect(fixture.controller.sortie!.battles, 0);
    expect(fixture.controller.totalSorties, 0);
  });

  test(
    'duplicate start preserves its original sortie and night phase',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.start();
      await fixture.battle();
      await fixture.send('/kcsapi/api_req_battle_midnight/battle', {});
      await fixture.result([-1, 90, 30], withBattle: false);
      await fixture.start();
      expect(fixture.experience, [90, 30]);
      expect(fixture.controller.sortie!.battles, 1);
    },
  );

  test(
    'mixed tracking and clearing across 24 sorties books only at port',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      var expectedSorties = 0;
      var expectedLeadExp = 0;
      var expectedSecondExp = 0;
      for (var sortie = 1; sortie <= 24; sortie++) {
        await fixture.start();
        final trackFirst = sortie.isOdd;
        final trackSecond = sortie % 3 == 0;
        final clearInMap = sortie % 7 == 0;
        await fixture.controller.setTrackingEnabled(trackFirst);
        await fixture.result([-1, 3 * sortie, sortie]);
        await fixture.next(2);
        if (clearInMap) {
          await fixture.controller.clearTotal();
          expectedSorties = expectedLeadExp = expectedSecondExp = 0;
        }
        await fixture.controller.setTrackingEnabled(trackSecond);
        await fixture.result([-1, 2 * sortie, sortie]);
        expect(
          fixture.controller.totalSorties,
          expectedSorties,
          reason: 'in sortie $sortie',
        );
        expect(fixture.experience, [5 * sortie, 2 * sortie]);
        await fixture.port();
        if (trackFirst && !clearInMap || trackSecond) expectedSorties++;
        if (trackFirst && !clearInMap) {
          expectedLeadExp += 3 * sortie;
          expectedSecondExp += sortie;
        }
        if (trackSecond) {
          expectedLeadExp += 2 * sortie;
          expectedSecondExp += sortie;
        }
        expect(
          fixture.controller.totalSorties,
          expectedSorties,
          reason: 'after sortie $sortie',
        );
        expect(
          fixture.totalExperience,
          expectedSorties == 0
              ? {}
              : {10: expectedLeadExp, 11: expectedSecondExp},
        );
      }
    },
  );

  test(
    'failed return write retries the same archive without double booking',
    () async {
      final store = _MemoryStore();
      final fixture = _Fixture(store: store);
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 45, 15]);
      store.failNextWrite = true;
      await fixture.port();
      expect(fixture.controller.storageUnavailable, isTrue);
      expect(fixture.controller.totalSorties, 1);
      await fixture.port();
      expect(fixture.controller.storageUnavailable, isFalse);
      final reopened = _Fixture(store: store);
      addTearDown(reopened.dispose);
      await reopened.controller.initialize();
      expect(reopened.controller.totalSorties, 1);
      expect(reopened.totalExperience, {10: 45, 11: 15});
    },
  );
  test(
    'malformed navigation cannot carry prior rewards into a different run',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.controller.setTrackingEnabled(true);
      await fixture.start();
      await fixture.result([-1, 100, 50]);
      await fixture.send('/kcsapi/api_req_map/start', []);
      expect(fixture.controller.isActive, isFalse);
      await fixture.port();
      expect(fixture.controller.totalSorties, 0);

      await fixture.start();
      await fixture.battle();
      await fixture.send('/kcsapi/api_req_map/next', []);
      await fixture.result([-1, 600, 400], withBattle: false);
      expect(fixture.experience, [0, 0]);
      expect(fixture.controller.sortie!.incomplete, isTrue);
      await fixture.next(1);
      await fixture.result([-1, 20, 10]);
      await fixture.port();
      expect(fixture.totalExperience, {10: 20, 11: 10});
    },
  );
}

class _MemoryStore implements SortieExperienceStore {
  final _saved = <int, String>{};
  bool failNextWrite = false;

  @override
  Future<String?> load(AccountScope account) async => _saved[account.memberId];

  @override
  Future<void> save(AccountScope account, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Test write interrupted');
    }
    _saved[account.memberId] = value;
  }
}

class _Fixture {
  _Fixture({
    SortieExperienceStore? store,
    Future<void> Function(AccountScope, LogbookExperienceRecord)?
    recordExperience,
  }) {
    controller = SortieExperienceController(
      accountSession: session,
      gameState: () => state,
      store: store,
      recordExperience: recordExperience,
    );
  }

  final session = AccountSession(initialMemberId: 1);
  late final SortieExperienceController controller;
  var state = GameState(
    memberId: 1,
    fleets: const [
      Fleet(id: 1, name: '第一', shipIds: [10, 11]),
      Fleet(id: 2, name: '第二', shipIds: [12, 13]),
    ],
    ships: {
      for (var id = 10; id <= 16; id++)
        id: OwnedShip(id: id, masterId: 101, level: 1),
    },
    masterShips: const {101: MasterShip(id: 101, name: '夕張', shipTypeId: 2)},
  );
  var sequence = 0;

  List<int> get experience => [
    for (final ship in controller.sortie!.ships) ship.experience,
  ];
  Map<int, int> get totalExperience => {
    for (final ship in controller.totals) ship.ownedShipId: ship.experience,
  };

  Future<void> start({int deckId = 1}) => send(
    '/kcsapi/api_req_map/start',
    _map(1),
    request: {'api_deck_id': '$deckId'},
  );
  Future<void> next(int node) => send('/kcsapi/api_req_map/next', _map(node));
  Future<void> practiceStart({int deckId = 1}) =>
      send('/kcsapi/api_req_practice/battle', {'api_deck_id': deckId});
  Future<void> practiceResult(List<int> experience) => send(
    '/kcsapi/api_req_practice/battle_result',
    {'api_get_ship_exp': experience},
  );
  Map<String, int> _map(int node) => {
    'api_maparea_id': 5,
    'api_mapinfo_no': 3,
    'api_no': node,
  };
  Future<void> battle({bool combined = false}) => send(
    combined
        ? '/kcsapi/api_req_combined_battle/battle'
        : '/kcsapi/api_req_sortie/battle',
    {},
  );

  Future<void> result(
    List<int> main, {
    List<int>? escort,
    List<List<int>>? mainProgress,
    List<List<int>>? escortProgress,
    bool withBattle = true,
  }) async {
    if (withBattle) await battle(combined: escort != null);
    await send(
      escort == null
          ? '/kcsapi/api_req_sortie/battleresult'
          : '/kcsapi/api_req_combined_battle/battleresult',
      {
        'api_get_ship_exp': main,
        'api_get_ship_exp_combined': ?escort,
        'api_get_exp_lvup': ?mainProgress,
        'api_get_exp_lvup_combined': ?escortProgress,
      },
    );
  }

  Future<void> port() => send('/kcsapi/api_port/port', {
    'api_basic': {'api_member_id': session.current.memberId},
  });
  Future<void> send(
    String path,
    Object? data, {
    int apiResult = 1,
    Map<String, Object?> request = const {},
  }) async {
    controller.accept(
      kcsapiEvent(
        path,
        data,
        apiResult: apiResult,
        sequence: ++sequence,
        requestParams: request,
      ),
    );
    await controller.idle;
  }

  void dispose() {
    controller.dispose();
    session.dispose();
  }
}
