import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_decoder.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_experience_record.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_controller.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('capture writes a sortie on return and a practice on result', () async {
    final fixture = await _ExperiencePipelineFixture.open();
    final experience = fixture.experience;
    final database = fixture.database;
    expect(experience.trackingEnabled, isFalse);

    await fixture.startSortie();
    await fixture.publish(dayBattleEvent.path, _fixtureData(dayBattleEvent));
    await fixture.result([360, 120], levelUps: _firstOrdinaryLevelUps);
    _expectProgress(experience, {9001: (6, 250), 9002: (8, 790)});
    await fixture.result([360, 120], levelUps: _firstOrdinaryLevelUps);
    _expectProgress(experience, {9001: (6, 250), 9002: (8, 790)});
    expect(await database.getExperienceRecords(), isEmpty);
    await fixture.port({9001: (6, 1850, 250), 9002: (8, 2810, 790)});
    await fixture.port();
    _expectProgress(experience, {9001: (6, 250), 9002: (8, 790)});
    final sortie = (await database.getExperienceRecords()).single;
    expect(sortie.isPractice, isFalse);
    expect(sortie.battles, 1);
    expect(_logbookExp(sortie), {9001: 360, 9002: 120});
    expect(_snapshotExp(experience.sortie!), _logbookExp(sortie));
    expect(experience.totalSorties, 0);

    await experience.setTrackingEnabled(true);
    await fixture.publish(
      '/kcsapi/api_req_practice/battle',
      _fixtureData(dayBattleEvent),
      request: {'api_deck_id': '1'},
    );
    final practiceResult = {
      'api_win_rank': 'S',
      'api_get_ship_exp': [-1, 420, 780, -1, -1, -1, -1],
      'api_get_exp_lvup': [
        [1850, 2100, 2800],
        [2810, 3600],
      ],
    };
    await fixture.publish(
      '/kcsapi/api_req_practice/battle_result',
      practiceResult,
    );
    _expectProgress(experience, {9001: (7, 530), 9002: (8, 10)});
    await fixture.publish(
      '/kcsapi/api_req_practice/battle_result',
      practiceResult,
    );
    _expectProgress(experience, {9001: (7, 530), 9002: (8, 10)});
    final practice = (await database.getExperienceRecords()).first;
    expect(experience.totalSorties, 1);
    expect(experience.sortie!.isPractice, isTrue);
    expect(_snapshotExp(experience.sortie!), {9001: 420, 9002: 780});
    expect(_snapshotExp(experience.sortie!), _logbookExp(practice));
    expect(_homeExp(experience.totals), _logbookExp(practice));

    await experience.clearTotal();
    final records = await database.getExperienceRecords();
    expect(records.map((record) => record.isPractice), [true, false]);
    expect(records.first.battles, 1);
    expect(records.first.toRow(), practice.toRow());
    expect(records.last.toRow(), sortie.toRow());
    expect(_snapshotExp(experience.sortie!), _logbookExp(practice));
    expect(await fixture.otherAccountDatabase.getExperienceRecords(), isEmpty);
    expect(experience.totalSorties, 0);
  });

  test('home and SQLite keep the whole two-node sortie while total includes '
      'only the enabled battle', () async {
    final fixture = await _ExperiencePipelineFixture.open();
    final experience = fixture.experience;
    final database = fixture.database;

    await fixture.startSortie();
    await fixture.publish(dayBattleEvent.path, _fixtureData(dayBattleEvent));
    await fixture.result([360, 120], levelUps: _firstOrdinaryLevelUps);
    await experience.setTrackingEnabled(true);
    await fixture.publish('/kcsapi/api_req_map/next', {
      ..._fixtureData(mapStartEvent),
      'api_no': 2,
    });
    // Replayed node 1 result must not settle node 2 before its own battle.
    await fixture.result([360, 120], levelUps: _firstOrdinaryLevelUps);
    _expectProgress(experience, {9001: (6, 250), 9002: (8, 790)});
    await fixture.publish(dayBattleEvent.path, _fixtureData(dayBattleEvent));
    const secondLevelUps = [
      [1850, 2100, 2800],
      [2810, 3600],
    ];
    await fixture.result([270, 540], levelUps: secondLevelUps);
    await fixture.result([270, 540], levelUps: secondLevelUps);
    _expectProgress(experience, {9001: (7, 680), 9002: (8, 250)});
    await experience.setTrackingEnabled(false);

    expect(experience.isActive, isTrue);
    expect(experience.sortie!.battles, 2);
    expect(_snapshotExp(experience.sortie!), {9001: 630, 9002: 660});
    expect(experience.totalSorties, 0);
    expect(await database.getExperienceRecords(), isEmpty);

    await fixture.port({9001: (7, 2120, 680), 9002: (8, 3350, 250)});
    await fixture.port();
    final run = (await database.getExperienceRecords()).single;
    final last = experience.sortie!;
    expect(experience.isActive, isFalse);
    expect(run.isPractice, isFalse);
    expect(run.incomplete, isFalse);
    expect((run.mapAreaId, run.mapInfoNo, run.deckId), (1, 1, 1));
    expect(run.battles, 2);
    expect(_logbookExp(run), {9001: 630, 9002: 660});
    expect(_snapshotExp(last), _logbookExp(run));
    expect(experience.totalSorties, 1);
    expect(_homeExp(experience.totals), {9001: 270, 9002: 540});

    await experience.clearTotal();
    expect(experience.totalSorties, 0);
    expect(experience.totals, isEmpty);
    expect(_snapshotExp(experience.sortie!), _logbookExp(run));
    expect((await database.getExperienceRecords()).single.toRow(), run.toRow());
  });

  test('combined nodes update both fleets before port and keep same-name '
      'ships separate in the logbook and total', () async {
    final fixture = await _ExperiencePipelineFixture.open(combined: true);
    final experience = fixture.experience;
    final database = fixture.database;
    await experience.setTrackingEnabled(true);
    await fixture.startSortie();
    _expectProgress(experience, {
      9001: (5, 10),
      9002: (7, 110),
      9003: (10, 10),
    });
    await fixture.combinedBattle();
    await fixture.combinedResult(
      main: [60, 40],
      mainLevelUps: [
        [1490, 1500, 2100],
        [2690, 2800],
      ],
      escort: [70],
      escortLevelUps: [
        [5490, 5500, 6600],
      ],
    );
    _expectProgress(experience, {
      9001: (6, 550),
      9002: (7, 70),
      9003: (11, 1040),
    });
    expect(_snapshotExp(experience.sortie!), {9001: 60, 9002: 40, 9003: 70});
    expect(experience.totalSorties, 0);
    expect(await database.getExperienceRecords(), isEmpty);

    await fixture.publish('/kcsapi/api_req_map/next', {
      ..._fixtureData(mapStartEvent),
      'api_no': 2,
    });
    await fixture.combinedBattle();
    await fixture.combinedResult(
      main: [80, 140],
      mainLevelUps: [
        [1550, 2100],
        [2730, 2800, 3600],
      ],
      escort: [180],
      escortLevelUps: [
        [5560, 6600],
      ],
    );
    const latest = {9001: (6, 470), 9002: (8, 730), 9003: (11, 860)};
    _expectProgress(experience, latest);
    const gained = {9001: 140, 9002: 180, 9003: 250};
    expect(experience.sortie!.battles, 2);
    expect(_snapshotExp(experience.sortie!), gained);
    expect(experience.totalSorties, 0);
    expect(await database.getExperienceRecords(), isEmpty);

    await fixture.port({
      9001: (6, 1630, 470),
      9002: (8, 2870, 730),
      9003: (11, 5740, 860),
    });
    _expectProgress(experience, latest);
    expect(experience.totalSorties, 1);
    expect(_homeExp(experience.totals), gained);
    final run = (await database.getExperienceRecords()).single;
    expect(run.battles, 2);
    expect(run.incomplete, isFalse);
    expect(run.ships.map((ship) => ship.fleetId), [1, 1, 2]);
    expect(run.ships.first.name, run.ships.last.name);
    expect(_logbookExp(run), gained);

    await fixture.port({9003: (11, 5840, 760)});
    _expectProgress(experience, {
      9001: (6, 470),
      9002: (8, 730),
      9003: (11, 760),
    });
    expect((await database.getExperienceRecords()).single.toRow(), run.toRow());
    expect(_homeExp(experience.totals), gained);
  });

  test('incomplete combined history preserves known zero and marks an '
      'unverified escort reward as unknown', () async {
    final fixture = await _ExperiencePipelineFixture.open(combined: true);
    final experience = fixture.experience;
    await experience.setTrackingEnabled(true);
    await fixture.startSortie();
    await fixture.combinedBattle();
    await fixture.combinedResult(
      main: [0, 300],
      mainLevelUps: [
        [1490, 1500],
        [2690, 2800, 3600],
      ],
      escort: const [],
      escortLevelUps: const [],
    );
    _expectProgress(experience, {
      9001: (5, 10),
      9002: (8, 610),
      9003: (10, 10),
    });
    await fixture.port({9002: (8, 2990, 610)});

    final run = (await fixture.database.getExperienceRecords()).single;
    final last = experience.sortie!;
    expect(last.incomplete, isTrue);
    expect(run.incomplete, isTrue);
    expect(run.battles, last.battles);
    expect(_logbookExp(run), {9001: 0, 9002: 300, 9003: null});
    expect(last.unverifiedShipIds, {9003});
    expect(_snapshotExp(last), _logbookExp(run));
    expect(_homeExp(experience.totals), {9001: 0, 9002: 300});
  });

  test(
    'another account records practice while a combined sortie write waits',
    () async {
      final firstWriteStarted = Completer<void>();
      final releaseFirstWrite = Completer<void>();
      final practiceWritten = Completer<void>();
      final fixture = await _ExperiencePipelineFixture.open(
        combined: true,
        aroundRecordWrite: (scope, record, insert) async {
          if (!record.isPractice && !firstWriteStarted.isCompleted) {
            firstWriteStarted.complete();
            await releaseFirstWrite.future;
          }
          await insert();
          if (record.isPractice && !practiceWritten.isCompleted) {
            practiceWritten.complete();
          }
        },
      );
      final experience = fixture.experience;
      const combinedGains = {9001: 60, 9002: 40, 9003: 70};
      const combinedProgress = {
        9001: (6, 550),
        9002: (7, 70),
        9003: (11, 1040),
      };
      const mainLevelUps = [
        [1490, 1500, 2100],
        [2690, 2800],
      ];
      const escortLevelUps = [
        [5490, 5500, 6600],
      ];
      await experience.setTrackingEnabled(true);
      await fixture.startSortie();
      await fixture.combinedBattle();
      await fixture.combinedResult(
        main: [60, 40],
        mainLevelUps: mainLevelUps,
        escort: [70],
        escortLevelUps: escortLevelUps,
      );
      _expectProgress(experience, combinedProgress);
      expect(experience.totalSorties, 0);
      final returning = fixture.port({
        9001: (6, 1550, 550),
        9002: (7, 2730, 70),
        9003: (11, 5560, 1040),
      });

      const practiceGains = {9001: 160, 9002: 90};
      const practiceProgress = {9001: (13, 1190), 9002: (15, 1440)};
      const practiceResultPath = '/kcsapi/api_req_practice/battle_result';
      const practiceResult = {
        'api_win_rank': 'S',
        'api_get_ship_exp': [-1, 160, 90, -1, -1, -1, -1],
        'api_get_exp_lvup': [
          [7750, 7800, 9100],
          [10470, 10500, 12000],
        ],
      };
      try {
        await firstWriteStarted.future.timeout(_eventTimeout);
        expect(_homeExp(experience.totals), combinedGains);

        await fixture.login(otherAccount: true, waitForLog: false);
        await _waitForExperience(experience, () => experience.isReady);
        expect(experience.trackingEnabled, isFalse);
        expect(experience.sortie, isNull);
        expect(experience.totals, isEmpty);
        _expectProgress(experience, {9001: (12, 50), 9002: (14, 30)});
        expect(experience.progressFor(9003), (
          level: null,
          nextExperience: null,
        ));
        await experience.setTrackingEnabled(true);
        await fixture.publish(
          '/kcsapi/api_req_practice/battle',
          _fixtureData(dayBattleEvent),
          request: {'api_deck_id': '1'},
          waitForLog: false,
        );
        await _waitForExperience(experience, () => experience.isActive);
        await fixture.combinedResult(
          main: [60, 40],
          mainLevelUps: mainLevelUps,
          escort: [70],
          escortLevelUps: escortLevelUps,
          staleDocument: 1,
          waitForLog: false,
        );
        _expectProgress(experience, {9001: (12, 50), 9002: (14, 30)});
        await fixture.publish(
          practiceResultPath,
          practiceResult,
          waitForLog: false,
        );
        await practiceWritten.future.timeout(
          _eventTimeout,
          onTimeout: () => fail('Practice write waited for another account'),
        );
        _expectProgress(experience, practiceProgress);
        expect(experience.totalSorties, 1);
        expect(_snapshotExp(experience.sortie!), practiceGains);
        expect(_homeExp(experience.totals), practiceGains);
        expect(await fixture.database.getExperienceRecords(), isEmpty);
        final practice =
            (await fixture.otherAccountDatabase.getExperienceRecords()).single;
        expect(practice.isPractice, isTrue);
        expect(_logbookExp(practice), practiceGains);

        await fixture.publish(
          practiceResultPath,
          practiceResult,
          waitForLog: false,
        );
        await fixture.login(waitForLog: false);
        await _waitForExperience(experience, () => experience.isReady);
        await fixture.publish(
          practiceResultPath,
          practiceResult,
          staleDocument: 2,
          waitForLog: false,
        );
        _expectProgress(experience, combinedProgress);
        expect(experience.isActive, isFalse);
        expect(experience.sortie!.isPractice, isFalse);
        expect(_snapshotExp(experience.sortie!), combinedGains);
        expect(_homeExp(experience.totals), combinedGains);
        expect(experience.totalSorties, 1);
      } finally {
        releaseFirstWrite.complete();
        await returning;
      }

      final combined = (await fixture.database.getExperienceRecords()).single;
      expect(combined.isPractice, isFalse);
      expect(_logbookExp(combined), combinedGains);
      await fixture.login(
        otherAccount: true,
        progress: {9001: (13, 7910, 1190), 9002: (15, 10560, 1440)},
      );
      _expectProgress(experience, practiceProgress);
      expect(experience.sortie!.isPractice, isTrue);
      expect(experience.totalSorties, 1);
      expect(_homeExp(experience.totals), practiceGains);
      final practice =
          (await fixture.otherAccountDatabase.getExperienceRecords()).single;
      expect(practice.isPractice, isTrue);
      expect(_logbookExp(practice), practiceGains);
    },
  );
}

const _eventTimeout = Duration(seconds: 5);

Future<void> _waitForExperience(
  SortieExperienceController experience,
  bool Function() condition,
) async {
  if (condition()) return;
  final reached = Completer<void>();
  void onChanged() {
    if (!reached.isCompleted && condition()) reached.complete();
  }

  experience.addListener(onChanged);
  try {
    await reached.future.timeout(_eventTimeout);
  } finally {
    experience.removeListener(onChanged);
  }
}

const _firstOrdinaryLevelUps = [
  [1490, 1500, 2100],
  [2690, 2800, 3600],
];

void _expectProgress(
  SortieExperienceController experience,
  Map<int, (int, int)> expected,
) {
  for (final MapEntry(key: id, value: (level, next)) in expected.entries) {
    expect(experience.progressFor(id), (
      level: level,
      nextExperience: next,
    ), reason: 'Progress for owned ship $id');
  }
}

final class _ExperiencePipelineFixture {
  _ExperiencePipelineFixture(
    this._pipeline,
    this._portData, {
    required this._otherPortData,
    required this.experience,
    required this.database,
    required this.otherAccountDatabase,
  });

  static const _memberId = 733;
  static const _otherMemberId = 734;

  final SortieExperienceController experience;
  final LogbookDatabase database;
  final LogbookDatabase otherAccountDatabase;
  final GameApiEventPipeline _pipeline;
  final Map<String, Object?> _portData;
  final Map<String, Object?> _otherPortData;
  int _document = 0;
  int _sequence = 0;
  bool _usingOtherAccount = false;

  static Future<_ExperiencePipelineFixture> open({
    bool combined = false,
    Future<void> Function(
      AccountScope scope,
      LogbookExperienceRecord record,
      Future<void> Function() insert,
    )?
    aroundRecordWrite,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final timerWasDisabled = GameStateController.disableTimerForTest;
    GameStateController.disableTimerForTest = true;
    addTearDown(() {
      GameStateController.disableTimerForTest = timerWasDisabled;
    });

    final account = AccountSession();
    final game = GameStateController(accountSession: account);
    final directory = await Directory.systemTemp.createTemp('yahagi-exp-log-');
    addTearDown(() => directory.delete(recursive: true));
    final database = await LogbookDatabase.openForTesting(
      path: '${directory.path}/owner.db',
    );
    final otherAccountDatabase = await LogbookDatabase.openForTesting(
      path: '${directory.path}/other.db',
    );
    final experience = SortieExperienceController(
      accountSession: account,
      gameState: () => game.state,
      gameStateChanges: game,
      recordExperience: (scope, record) {
        final owner = switch (scope.memberId) {
          _memberId => database,
          _otherMemberId => otherAccountDatabase,
          _ => throw StateError('Unexpected fixture account'),
        };
        Future<void> insert() => owner.insertExperienceRecord(record);
        return aroundRecordWrite?.call(scope, record, insert) ?? insert();
      },
    );
    addTearDown(() async {
      experience.dispose();
      game.dispose();
      account.dispose();
      await database.close();
      await otherAccountDatabase.close();
    });
    final otherPortData = _portPayload(
      combined: false,
      memberId: _otherMemberId,
    );
    _updateShipProgress(otherPortData, {
      9001: (12, 7750, 50),
      9002: (14, 10470, 30),
    });
    final fixture = _ExperiencePipelineFixture(
      GameApiEventPipeline(
        consumers: [account, game, experience],
        settleGameState: () => game.idle,
        decodeEnvelope: (body) async => GameApiDecoder.decodeEnvelope(body),
      ),
      _portPayload(combined: combined, memberId: _memberId),
      otherPortData: otherPortData,
      experience: experience,
      database: database,
      otherAccountDatabase: otherAccountDatabase,
    );
    await fixture.login();
    return fixture;
  }

  static Map<String, Object?> _portPayload({
    required bool combined,
    required int memberId,
  }) {
    final data = _fixtureData(portEvent);
    data['api_basic'] = {'api_member_id': memberId, 'api_level': 120};
    final ships = (data['api_ship'] as List).cast<Map<String, Object?>>();
    if (combined) {
      final fleets = (data['api_deck_port'] as List)
          .cast<Map<String, Object?>>();
      data['api_ship'] = [
        ...ships,
        {...ships.first, 'api_id': 9003},
      ];
      data['api_deck_port'] = [
        fleets.first,
        {
          ...fleets[1],
          'api_ship': [9003, -1, -1, -1, -1, -1],
          'api_mission': [0, 0, 0, 0],
        },
        ...fleets.skip(2),
      ];
      data['api_combined_flag'] = 2;
    }
    _updateShipProgress(data, {
      9001: (5, 1490, 10),
      9002: (7, 2690, 110),
      if (combined) 9003: (10, 5490, 10),
    });
    return data;
  }

  static void _updateShipProgress(
    Map<String, Object?> data,
    Map<int, (int, int, int)> progress,
  ) {
    final ships = (data['api_ship'] as List).cast<Map<String, Object?>>();
    data['api_ship'] = [
      for (final ship in ships)
        if (progress[ship['api_id']] case (
          final level,
          final total,
          final next,
        ))
          {
            ...ship,
            'api_lv': level,
            'api_exp': [total, next, 0],
          }
        else
          ship,
    ];
  }

  Future<void> port([Map<int, (int, int, int)> progress = const {}]) {
    final data = _usingOtherAccount ? _otherPortData : _portData;
    _updateShipProgress(data, progress);
    return publish(portEvent.path, data);
  }

  Future<void> login({
    bool otherAccount = false,
    bool waitForLog = true,
    Map<int, (int, int, int)> progress = const {},
  }) async {
    _document++;
    _usingOtherAccount = otherAccount;
    final portData = otherAccount ? _otherPortData : _portData;
    _updateShipProgress(portData, progress);
    await publish(
      start2Event.path,
      _fixtureData(start2Event),
      waitForLog: waitForLog,
    );
    await publish(portEvent.path, portData, waitForLog: waitForLog);
  }

  Future<void> startSortie() => publish(
    mapStartEvent.path,
    _fixtureData(mapStartEvent),
    request: mapStartEvent.requestParams,
  );

  Future<void> result(List<int> exp, {required List<List<int>> levelUps}) =>
      publish(battleResultEvent.path, {
        ..._fixtureData(battleResultEvent),
        'api_get_ship_exp': [-1, ...exp, -1, -1, -1, -1],
        'api_get_exp_lvup': levelUps,
      });

  Future<void> combinedBattle() =>
      publish('/kcsapi/api_req_combined_battle/battle', {
        ..._fixtureData(dayBattleEvent),
        'api_f_nowhps_combined': [30],
        'api_f_maxhps_combined': [30],
      });

  Future<void> combinedResult({
    required List<int> main,
    required List<List<int>> mainLevelUps,
    required List<int> escort,
    required List<List<int>> escortLevelUps,
    int? staleDocument,
    bool waitForLog = true,
  }) => publish(
    '/kcsapi/api_req_combined_battle/battleresult',
    {
      ..._fixtureData(battleResultEvent),
      'api_get_ship_exp': [-1, ...main, -1, -1, -1, -1],
      'api_get_exp_lvup': mainLevelUps,
      'api_get_ship_exp_combined': [
        -1,
        ...escort,
        if (escort.isNotEmpty) ...[-1, -1, -1, -1, -1],
      ],
      'api_get_exp_lvup_combined': escortLevelUps,
    },
    staleDocument: staleDocument,
    waitForLog: waitForLog,
  );

  Future<void> publish(
    String path,
    Map<String, Object?> data, {
    Map<String, Object?> request = const {},
    int? staleDocument,
    bool waitForLog = true,
  }) async {
    _sequence++;
    final payload = kcsapiEvent(path, data);
    final document = staleDocument ?? _document;
    final start = DateTime.utc(2026, 11, 6, 17);
    final event = CapturedApiEvent(
      path: path,
      responseBody: payload.responseBody,
      source: payload.source,
      sourceOrigin: payload.sourceOrigin,
      requestParams: request,
      sequence: _sequence,
      capturedAt: start.add(Duration(seconds: _sequence)),
      captureSessionId: 'logbook-exp-pipeline',
      captureDocumentId: 'page-$document',
      captureDocumentStartedAtEpochMs: (start.millisecondsSinceEpoch + document)
          .toDouble(),
    );
    _pipeline.add(event);
    await (waitForLog ? _pipeline.idle : _pipeline.dispatchIdle);
    if (staleDocument != null) {
      expect(_pipeline.wasEventAccepted(event), isFalse);
    }
  }
}

Map<int, int> _homeExp(List<SortieExperienceShip> ships) => {
  for (final ship in ships) ship.ownedShipId: ship.experience,
};

Map<int, int?> _snapshotExp(SortieExperienceSnapshot snapshot) => {
  for (final ship in snapshot.ships)
    ship.ownedShipId: snapshot.unverifiedShipIds.contains(ship.ownedShipId)
        ? null
        : ship.experience,
};

Map<int, int?> _logbookExp(LogbookExperienceRecord record) => {
  for (final ship in record.ships) ship.ownedShipId: ship.experience,
};

Map<String, Object?> _fixtureData(CapturedApiEvent event) =>
    Map<String, Object?>.from(
      GameApiDecoder.decodeEnvelope(event.responseBody)['api_data'] as Map,
    );
