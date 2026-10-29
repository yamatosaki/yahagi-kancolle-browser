import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  test('350 rejects Mitsushio in place of Ushio', () async {
    final state = await _runFleetRule(350, [93, 94, 15, 97]);
    expect(state.quests[350]!.progressCurrent, 0);
    expect(state.quests[350]!.isCompleted, isFalse);
  });

  for (final ushio in [16, 233, 407]) {
    test('350 accepts Ushio master $ushio and its genuine remodels', () async {
      final state = await _runFleetRule(350, [93, 94, 15, ushio]);
      expect(state.quests[350]!.progressCurrent, 3);
      expect(state.quests[350]!.isCompleted, isTrue);
    });
  }

  test('1005 rejects a renamed lookalike instead of Ushio Kai', () async {
    final state = await _runFleetRule(1005, [230, 232, 231, 489]);
    expect(state.quests[1005]!.progressCurrent, 0);
  });

  for (final ids in [
    [230, 232, 231, 233],
    [230, 232, 665, 407],
  ]) {
    test('1005 accepts its four ships at Kai or later: $ids', () async {
      final state = await _runFleetRule(1005, ids);
      expect(state.quests[1005]!.progressCurrent, 1);
    });
  }

  test('1005 does not accept the four unremodelled ships', () async {
    final state = await _runFleetRule(1005, [93, 94, 15, 16]);
    expect(state.quests[1005]!.progressCurrent, 0);
  });

  test('ID conditions cannot fall back to a matching ship name', () async {
    final state = await _runFleetRule(
      350,
      [93, 94, 15, 407],
      masters: {
        ..._masters,
        // The current ship is known, but the link from Ushio Kai is absent.
        233: const MasterShip(id: 233, name: '潮改', shipTypeId: 2),
      },
      goal: _idGoal(350, [93, 94, 15, 16]),
    );
    expect(state.quests[350]!.progressCurrent, 0);
  });

  test('flagship and second ship use their own ID lineage positions', () {
    const event = QuestProgressEvent(
      'practice_win_a',
      options: {
        'shipIds': [
          [407, 233, 16],
          [230, 93],
        ],
      },
    );
    expect(
      matchesQuestStep({
        'flagshipId': [16],
      }, event),
      isTrue,
    );
    expect(
      matchesQuestStep({
        'secondshipId': [93],
      }, event),
      isTrue,
    );
    expect(
      matchesQuestStep({
        'flagshipId': [93],
      }, event),
      isFalse,
    );
    expect(
      matchesQuestStep({
        'secondshipId': [16],
      }, event),
      isFalse,
    );
  });

  test('escort ID groups are OR while all-groups are AND', () {
    const event = QuestProgressEvent(
      'practice_win_a',
      options: {
        'shipIds': [
          [16],
          [93],
        ],
      },
    );
    final groups = [
      [
        [16],
        1,
      ],
      [
        [94],
        1,
      ],
    ];
    expect(matchesQuestStep({'escortshipId': groups}, event), isTrue);
    expect(matchesQuestStep({'escortshipIdAll': groups}, event), isFalse);
    expect(
      matchesQuestStep({
        'escortshipIdAll': [
          [
            [16],
            1,
          ],
          [
            [93],
            1,
          ],
        ],
      }, event),
      isTrue,
    );
  });

  test('ID groups count each ship once and can exclude the flagship', () {
    const event = QuestProgressEvent(
      'practice_win_a',
      options: {
        'shipIds': [
          [407, 233, 16],
          [93],
        ],
      },
    );
    expect(
      matchesQuestStep({
        'escortshipId': [
          [
            [407, 233, 16],
            1,
          ],
        ],
      }, event),
      isTrue,
    );
    for (final group in [
      [
        [407, 233, 16],
        2,
      ],
      [
        [16],
        1,
        true,
      ],
    ]) {
      expect(
        matchesQuestStep({
          'escortshipId': [group],
        }, event),
        isFalse,
      );
    }
  });

  test('missing ID metadata cannot be replaced by names', () {
    const event = QuestProgressEvent(
      'practice_win_a',
      ships: [MasterShip(id: 16, name: '潮', shipTypeId: 2)],
    );
    expect(
      matchesQuestStep({
        'flagshipId': [16],
      }, event),
      isFalse,
    );
    expect(
      matchesQuestStep({
        'flagship': ['潮'],
      }, event),
      isTrue,
    );
  });

  test(
    'renamed remodels count as ancestors, never as future remodels',
    () async {
      const masters = {
        35: MasterShip(id: 35, name: '響', shipTypeId: 2, afterShipId: 235),
        235: MasterShip(id: 235, name: '響改', shipTypeId: 2, afterShipId: 147),
        147: MasterShip(id: 147, name: 'Верный', shipTypeId: 2),
      };
      final renamed = await _runFleetRule(
        350,
        [147],
        masters: masters,
        goal: _idGoal(350, [35], count: 1),
      );
      expect(renamed.quests[350]!.progressCurrent, 3);
      final unremodelled = await _runFleetRule(
        350,
        [35],
        masters: masters,
        goal: _idGoal(350, [147], count: 1),
      );
      expect(unremodelled.quests[350]!.progressCurrent, 0);
    },
  );

  test(
    'a shared remodel destination does not connect sibling sources',
    () async {
      const masters = {
        1001: MasterShip(
          id: 1001,
          name: 'source A',
          shipTypeId: 2,
          afterShipId: 1003,
        ),
        1002: MasterShip(
          id: 1002,
          name: 'source B',
          shipTypeId: 2,
          afterShipId: 1003,
        ),
        1003: MasterShip(id: 1003, name: 'destination', shipTypeId: 2),
      };
      final sibling = await _runFleetRule(
        350,
        [1001],
        masters: masters,
        goal: _idGoal(350, [1002], count: 1),
      );
      expect(sibling.quests[350]!.progressCurrent, 0);
      for (final ancestor in [1001, 1002]) {
        final destination = await _runFleetRule(
          350,
          [1003],
          masters: masters,
          goal: _idGoal(350, [ancestor], count: 1),
        );
        expect(destination.quests[350]!.progressCurrent, 3);
      }
    },
  );

  test(
    'switchable remodel cycles terminate and retain both variants',
    () async {
      final state = await _runFleetRule(
        350,
        [1001],
        masters: const {
          1001: MasterShip(
            id: 1001,
            name: 'variant A',
            shipTypeId: 2,
            afterShipId: 1002,
          ),
          1002: MasterShip(
            id: 1002,
            name: 'variant B',
            shipTypeId: 2,
            afterShipId: 1001,
          ),
        },
        goal: _idGoal(350, [1002], count: 1),
      );
      expect(state.quests[350]!.progressCurrent, 3);
    },
  );
}

const _masters = {
  93: MasterShip(id: 93, name: '朧', shipTypeId: 2, afterShipId: 230),
  94: MasterShip(id: 94, name: '漣', shipTypeId: 2, afterShipId: 232),
  15: MasterShip(id: 15, name: '曙', shipTypeId: 2, afterShipId: 231),
  16: MasterShip(id: 16, name: '潮', shipTypeId: 2, afterShipId: 233),
  97: MasterShip(id: 97, name: '満潮', shipTypeId: 2, afterShipId: 250),
  250: MasterShip(id: 250, name: '満潮改', shipTypeId: 2, afterShipId: 489),
  230: MasterShip(id: 230, name: '朧改', shipTypeId: 2),
  232: MasterShip(id: 232, name: '漣改', shipTypeId: 2),
  231: MasterShip(id: 231, name: '曙改', shipTypeId: 2, afterShipId: 665),
  233: MasterShip(id: 233, name: '潮改', shipTypeId: 2, afterShipId: 407),
  665: MasterShip(id: 665, name: '曙改二', shipTypeId: 2),
  407: MasterShip(id: 407, name: '潮改二', shipTypeId: 2),
  489: MasterShip(id: 489, name: '満潮改二', shipTypeId: 2),
};

QuestProgressGoal _bundledGoal(int id) {
  final raw =
      jsonDecode(
            File('assets/data/quest-progress-goals.json').readAsStringSync(),
          )
          as Map;
  return QuestProgressGoal(id, Map<String, dynamic>.from(raw['$id'] as Map));
}

QuestProgressGoal _idGoal(int id, List<int> ids, {int count = 4}) =>
    QuestProgressGoal(id, {
      'type': 103,
      'practice_win_a': {
        'required': 3,
        'init': 0,
        'escortshipId': [
          [ids, count],
        ],
      },
    });

Future<GameState> _runFleetRule(
  int id,
  List<int> masterIds, {
  Map<int, MasterShip> masters = _masters,
  QuestProgressGoal? goal,
}) async {
  final now = DateTime.utc(2026, 10, 29, 7);
  final engine = QuestProgressEngine(
    goals: {id: goal ?? _bundledGoal(id)},
    storage: _MemoryProgress(),
  );
  var state = await engine.restore(
    GameState(
      memberId: 100,
      quests: {
        id: GameQuest(
          id: id,
          title: 'ID rule',
          detail: '',
          category: id == 350 ? 3 : 2,
          type: 5,
          state: 2,
          progressFlag: 0,
          updatedAt: now,
        ),
      },
      masterShips: masters,
      ships: {
        for (var i = 0; i < masterIds.length; i++)
          i + 1: OwnedShip(id: i + 1, masterId: masterIds[i], level: 90),
      },
      fleets: [
        Fleet(
          id: 1,
          name: 'test fleet',
          shipIds: List.generate(masterIds.length, (i) => i + 1),
        ),
      ],
    ),
    now,
  );
  var sequence = 0;
  Future<void> send(String path, Map<String, Object?> data) async {
    final event = kcsapiEvent(
      '/kcsapi/$path',
      data,
      requestParams: const {'api_deck_id': 1},
      capturedAt: now.add(Duration(seconds: sequence)),
      sequence: ++sequence,
    );
    state = await engine.process(state, state, event);
  }

  for (var i = 0; i < (id == 350 ? 3 : 1); i++) {
    if (id == 350) {
      await send('api_req_practice/battle', {'api_deck_id': 1});
      await send('api_req_practice/battle_result', {'api_win_rank': 'A'});
    } else {
      await send('api_req_map/start', {
        'api_maparea_id': 1,
        'api_mapinfo_no': 2,
        'api_no': 6,
        'api_event_id': 5,
      });
      await send('api_req_sortie/battleresult', {'api_win_rank': 'A'});
    }
  }
  return state;
}

class _MemoryProgress implements QuestProgressStorage {
  @override
  Future<String?> read(int account) async => null;

  @override
  Future<void> write(int account, String value) async {}
}
