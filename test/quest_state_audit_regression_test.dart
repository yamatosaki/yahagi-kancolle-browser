import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_tracker.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 10);

  test(
    'first supply after daily reset cannot revive yesterday, even on reconnect',
    () async {
      final before = DateTime.utc(2026, 9, 11, 19, 59, 59);
      final after = DateTime.utc(2026, 9, 11, 20, 0, 1);
      final storage = _MemoryProgress();
      final h = await _Harness.create(
        _state(_quest(504, before, type: 1, current: 14, required: 15)),
        before,
        storage: storage,
      );
      await h.event('api_req_hokyu/charge', {}, after);
      expect(h.state.quests, isEmpty);
      expect(h.engine.expire(h.state, after).quests, isEmpty);
      final restored = await _Harness.create(h.state, after, storage: storage);
      expect(restored.state.quests, isEmpty);
    },
  );

  test(
    'supply inside the same daily period still completes and survives reconnect',
    () async {
      final storage = _MemoryProgress();
      final h = await _Harness.create(
        _state(_quest(504, now, type: 1, current: 14, required: 15)),
        now,
        storage: storage,
      );
      await h.event(
        'api_req_hokyu/charge',
        {},
        now.add(const Duration(seconds: 1)),
      );
      expect(h.state.quests[504]!.exactProgressLabel, '15/15');
      expect(h.state.quests[504]!.isCompleted, isTrue);
      final restored = await _Harness.create(h.state, now, storage: storage);
      expect(restored.state.quests[504]!.isCompleted, isTrue);
    },
  );

  for (final boundary in [
    ('daily', 1, 1, DateTime.utc(2026, 9, 11, 20)),
    ('weekly', 2, 2, DateTime.utc(2026, 9, 13, 20)),
    ('monthly', 3, 3, DateTime.utc(2026, 9, 30, 20)),
    ('quarterly', 4, 5, DateTime.utc(2026, 8, 31, 20)),
    ('yearly', 109, 5, DateTime.utc(2026, 8, 31, 20)),
  ]) {
    test(
      '${boundary.$1} expiry clears both snapshots and preserves fresh rows',
      () async {
        final before = boundary.$4.subtract(const Duration(seconds: 1));
        final after = boundary.$4.add(const Duration(seconds: 1));
        final goals = {
          for (final id in [9001, 9002])
            id: QuestProgressGoal(id, {
              'type': boundary.$2,
              'supply': {'required': 1, 'init': 0},
            }),
        };
        final old = _quest(9001, before, type: boundary.$3);
        final fresh = _quest(9002, after, type: boundary.$3);
        final h = await _Harness.create(
          _state(old).copyWith(availableQuests: {9001: old}),
          before,
          goals: goals,
        );
        h.state = h.state.copyWith(
          quests: {...h.state.quests, 9002: fresh},
          availableQuests: {...h.state.availableQuests, 9002: fresh},
        );
        final expired = h.engine.expire(h.state, after);
        expect(expired.quests.keys, [9002]);
        expect(expired.availableQuests.keys, [9002]);
        expect(expired.hasCompleteQuestData, isFalse);
      },
    );
  }

  test(
    'quarterly available-only snapshot expires without an active record',
    () async {
      final before = DateTime.utc(2026, 8, 31, 19, 59, 59);
      final after = DateTime.utc(2026, 8, 31, 20, 0, 1);
      final q = _quest(337, before, type: 5);
      final h = await _Harness.create(
        GameState(memberId: 100, availableQuests: {337: q}),
        before,
      );
      expect(h.engine.expire(h.state, after).availableQuests, isEmpty);
    },
  );

  test(
    'annual label learned from the server expires available snapshot after reconnect',
    () async {
      final before = DateTime.utc(2026, 8, 31, 19, 59, 59);
      final after = DateTime.utc(2026, 8, 31, 20, 0, 1);
      final q = _quest(9001, before, type: 5);
      final h = await _Harness.create(
        _state(q).copyWith(availableQuests: {9001: q}),
        before,
        goals: {},
      );
      await h.event('api_get_member/questlist', {
        'api_list': [
          {
            'api_no': 9001,
            'api_title': 'annual task',
            'api_detail': '',
            'api_category': 3,
            'api_type': 5,
            'api_state': 2,
            'api_progress_flag': 0,
            'api_label_type': 109,
          },
        ],
      }, before);
      final restored = await _Harness.create(
        h.state,
        after,
        storage: h.storage,
        goals: {},
      );
      expect(restored.state.quests, isEmpty);
      expect(restored.state.availableQuests, isEmpty);
    },
  );

  for (final reconnect in [false, true]) {
    test(
      'new annual start retains its learned reset month ($reconnect)',
      () async {
        final before = DateTime.utc(2026, 8, 31, 19, 59, 59);
        final after = DateTime.utc(2026, 8, 31, 20, 0, 1);
        final nextYear = DateTime.utc(2027, 8, 31, 20, 0, 1);
        final q = _quest(9001, before, type: 5).withState(1);
        var h = await _Harness.create(
          GameState(memberId: 100, availableQuests: {9001: q}),
          before,
          goals: {},
        );
        await h.event('api_get_member/questlist', {
          'api_list': [
            {
              'api_no': 9001,
              'api_title': 'annual task',
              'api_detail': '',
              'api_category': 3,
              'api_type': 5,
              'api_state': 1,
              'api_progress_flag': 0,
              'api_label_type': 109,
            },
          ],
        }, before);
        await h.event(
          'api_req_quest/start',
          {},
          after,
          params: {'api_quest_id': 9001},
        );
        expect(h.state.quests[9001]!.isAccepted, isTrue);
        if (reconnect) {
          h = await _Harness.create(
            h.state,
            after,
            storage: h.storage,
            goals: {},
          );
        }
        expect(
          h.engine
              .expire(h.state, after.add(const Duration(days: 1)))
              .quests
              .keys,
          [9001],
        );
        final expired = h.engine.expire(h.state, nextYear);
        expect(expired.quests, isEmpty);
        expect(expired.availableQuests, isEmpty);
      },
    );
  }

  test(
    'new-period questlist can authoritatively reintroduce the same daily ID',
    () async {
      final before = DateTime.utc(2026, 9, 11, 19, 59, 59);
      final after = DateTime.utc(2026, 9, 11, 20, 0, 1);
      final h = await _Harness.create(
        _state(_quest(504, before, type: 1, current: 14, required: 15)),
        before,
      );
      await h.server(504, after, type: 1, state: 2);
      expect(h.state.quests[504]!.exactProgressLabel, '0/15');
      await h.event(
        'api_req_hokyu/charge',
        {},
        after.add(const Duration(seconds: 1)),
      );
      expect(h.state.quests[504]!.exactProgressLabel, '1/15');
    },
  );

  for (final crossesPeriod in [true, false]) {
    test(
      'successful start keeps accepted quest and uses the right period count ($crossesPeriod)',
      () async {
        final before = DateTime.utc(2026, 9, 11, 19, 59, 59);
        final at = before.add(Duration(seconds: crossesPeriod ? 2 : 0));
        final available = _quest(
          504,
          before,
          type: 1,
          current: 7,
          required: 15,
        ).withState(1);
        final h = await _Harness.create(
          GameState(memberId: 100, availableQuests: {504: available}),
          before,
        );
        await h.event(
          'api_req_quest/start',
          {},
          at,
          params: {'api_quest_id': 504},
        );
        expect(h.state.quests[504]!.isAccepted, isTrue);
        expect(h.state.quests[504]!.progressCurrent, crossesPeriod ? 0 : 7);
        expect(h.state.availableQuests[504]!.isAccepted, isTrue);
        expect(h.state.availableQuests[504]!.updatedAt, at);
      },
    );
  }

  for (final acceptedSnapshot in [true, false]) {
    test(
      'new-period start replaces an old server-completed snapshot ($acceptedSnapshot)',
      () async {
        final before = DateTime.utc(2026, 9, 11, 19, 59, 59);
        final after = DateTime.utc(2026, 9, 11, 20, 0, 1);
        final completed = GameQuest(
          id: 504,
          title: 'old completed daily',
          detail: '',
          category: 5,
          type: 1,
          state: 3,
          progressFlag: 2,
          progressCurrent: 15,
          progressRequired: 15,
          updatedAt: before,
        );
        final h = await _Harness.create(
          GameState(
            memberId: 100,
            quests: acceptedSnapshot ? {504: completed} : {},
            availableQuests: {504: completed},
          ),
          before,
        );
        await h.event(
          'api_req_quest/start',
          {},
          after,
          params: {'api_quest_id': 504},
        );
        final accepted = h.state.quests[504]!;
        expect(accepted.state, 2);
        expect(accepted.exactProgressLabel, '0/15');
        expect(accepted.progressFlag, 0);
        expect(accepted.isCompleted, isFalse);
        expect(h.state.availableQuests[504]!.state, 2);
        expect(h.state.availableQuests[504]!.isCompleted, isFalse);
        final restored = await _Harness.create(
          h.state,
          after,
          storage: h.storage,
        );
        expect(restored.state.quests[504]!.isCompleted, isFalse);
      },
    );
  }

  test(
    'current-period completed questlist remains authoritative across reset',
    () async {
      final before = DateTime.utc(2026, 9, 11, 19, 59, 59);
      final after = DateTime.utc(2026, 9, 11, 20, 0, 1);
      final h = await _Harness.create(
        _state(_quest(504, before, type: 1, current: 14, required: 15)),
        before,
      );
      await h.server(504, after, type: 1, state: 3, flag: 2);
      expect(h.state.quests[504]!.isServerCompleted, isTrue);
      expect(h.state.quests[504]!.exactProgressLabel, '15/15');
      expect(h.state.availableQuests[504]!.isServerCompleted, isTrue);
      final restored = await _Harness.create(
        h.state,
        after,
        storage: h.storage,
      );
      expect(restored.state.quests[504]!.isServerCompleted, isTrue);
    },
  );

  for (final crossesPeriod in [true, false]) {
    test(
      'engine checks the original period before specialized reducer completion ($crossesPeriod)',
      () async {
        final before = DateTime.utc(2026, 8, 31, 19, 59, 59);
        final at = before.add(Duration(seconds: crossesPeriod ? 2 : 0));
        // F96 itself is one-time. A synthetic quarterly rule exercises its
        // specialized reducer path without asserting a different game period.
        final h = await _Harness.create(
          _state(
            _quest(1101, before, type: 5, current: 7, required: 8),
          ).copyWith(
            furnitureCoins: 4000,
            hasFurnitureCoinData: true,
            slotItems: {
              100: const OwnedSlotItem(id: 100, masterId: 2),
              for (var i = 0; i < 4; i++)
                400 + i: OwnedSlotItem(id: 400 + i, masterId: 4),
              for (var i = 0; i < 4; i++)
                600 + i: OwnedSlotItem(id: 600 + i, masterId: 6),
            },
          ),
          before,
          goals: {
            1101: QuestProgressGoal(1101, {'type': 4}),
          },
        );
        await h.event(
          'api_req_kousyou/destroyitem2',
          {},
          at,
          params: {'api_slotitem_ids': '100'},
        );
        expect(h.state.slotItems.containsKey(100), isFalse);
        if (crossesPeriod) {
          expect(h.state.quests, isEmpty);
        } else {
          expect(h.state.quests[1101]!.exactProgressLabel, '8/8');
          expect(h.state.quests[1101]!.isCompleted, isTrue);
        }
      },
    );
  }

  for (final id in [330, 318]) {
    test(
      'incomplete rule $id keeps a full reference count pending until server confirms',
      () async {
        final h = await _Harness.create(
          _practiceState(
            id,
            now,
            id == 330 ? ['赤城'] : ['川内', '神通'],
            id == 330 ? [7] : [3, 3],
          ),
          now,
        );
        final tracker = QuestCompletionTracker(h.state, now: now);
        await h.practice(now, rank: 'B', times: id == 330 ? 4 : 3);
        expect(h.state.quests[id]!.progressCurrent, id == 330 ? 4 : 3);
        expect(h.state.quests[id]!.localCompletionVerified, isFalse);
        expect(h.state.quests[id]!.isCompleted, isFalse);
        expect(tracker.update(h.state, now: now), isFalse);
        await h.server(
          id,
          now.add(const Duration(minutes: 1)),
          type: id == 330 ? 5 : 3,
          state: 3,
        );
        expect(h.state.quests[id]!.isServerCompleted, isTrue);
        expect(h.state.quests[id]!.isCompleted, isTrue);
        final restored = await _Harness.create(
          h.state,
          now,
          storage: h.storage,
        );
        expect(restored.state.quests[id]!.isServerCompleted, isTrue);
      },
    );
  }

  test(
    'Cq1 with all visible fleet requirements remains pending while the rule is incomplete',
    () async {
      final h = await _Harness.create(
        _practiceState(330, now, ['赤城', '加賀', '吹雪', '白雪'], [7, 11, 2, 2]),
        now,
      );
      await h.practice(now, rank: 'B', times: 4);
      expect(h.state.quests[330]!.exactProgressLabel, '4/4');
      expect(h.state.quests[330]!.isCompleted, isFalse);
    },
  );

  test(
    'cached full count with an unknown required condition cannot be verified',
    () async {
      final h = await _Harness.create(
        _state(_quest(9001, now, current: 1, required: 1)),
        now,
        goals: {
          9001: QuestProgressGoal(9001, {
            'type': 0,
            'supply': {'required': 1, 'init': 0, 'unobservedCondition': true},
          }),
        },
      );
      expect(h.state.quests[9001]!.exactProgressLabel, '1/1');
      expect(h.state.quests[9001]!.isCompleted, isFalse);
    },
  );

  for (final fleet in [
    (373, ['Richelieu', 'Gloire'], [8, 3], [0, 0]),
    (372, ['秋月', '吹雪', '伊勢', '日向'], [2, 2, 10, 10], [54, 1, 2, 2]),
  ]) {
    test(
      'quest ${fleet.$1} requires the full escort group beyond its flagship',
      () async {
        final h = await _Harness.create(
          _practiceState(
            fleet.$1,
            now,
            fleet.$2,
            fleet.$3,
            classes: fleet.$4,
            masterIds: fleet.$1 == 373 ? [492, 965] : null,
          ),
          now,
        );
        await h.practice(now, rank: 'A', times: 4);
        expect(h.state.quests[fleet.$1]!.progressCurrent, 0);
        expect(h.state.quests[fleet.$1]!.isCompleted, isFalse);
      },
    );
  }

  for (final fleet in [
    (373, ['Richelieu', 'Gloire', 'Mogador'], [8, 3, 2], [0, 0, 0]),
    (372, ['秋月', '吹雪', '白雪', '伊勢', '日向'], [2, 2, 2, 10, 10], [54, 1, 1, 2, 2]),
  ]) {
    test(
      'quest ${fleet.$1} accepts sufficient escorts and preserves current-rule completion',
      () async {
        final h = await _Harness.create(
          _practiceState(
            fleet.$1,
            now,
            fleet.$2,
            fleet.$3,
            classes: fleet.$4,
            masterIds: fleet.$1 == 373 ? [492, 965, 962] : null,
          ),
          now,
        );
        await h.practice(now, rank: 'A', times: 4);
        expect(h.state.quests[fleet.$1]!.exactProgressLabel, '4/4');
        expect(h.state.quests[fleet.$1]!.isCompleted, isTrue);
        final restored = await _Harness.create(
          h.state,
          now,
          storage: h.storage,
        );
        expect(restored.state.quests[fleet.$1]!.isCompleted, isTrue);
      },
    );
  }

  for (final id in [330, 318, 372, 373]) {
    test(
      'legacy full count $id is corrected on restore and server confirmation remains authoritative',
      () async {
        final currentRules = _rules();
        final goal = currentRules[id]!;
        final required = id == 318 ? 3 : 4;
        final storage = _MemoryProgress();
        // A valid old-format cache, written before rule verification was tightened.
        storage.values[100] = jsonEncode({
          'account': 100,
          'records': {
            '504': {
              'period': questPeriodKey(1, 1, now),
              'type': 1,
              'counts': {'supply': 15},
              'claimed': false,
              'blocked': false,
            },
            '$id': {
              'period': questPeriodKey(goal.type, id == 318 ? 3 : 5, now),
              'type': id == 318 ? 3 : 5,
              'counts': {goal.steps.keys.single: required},
              'claimed': false,
              'blocked': false,
            },
          },
          'active': [
            {
              'id': 504,
              'title': 'unmodified daily',
              'detail': '',
              'category': 5,
              'type': 1,
              'state': 2,
              'flag': 2,
              'current': 15,
              'required': 15,
              'verified': true,
              'updated': now.toIso8601String(),
            },
            {
              'id': id,
              'title': 'cached task',
              'detail': '',
              'category': 3,
              'type': id == 318 ? 3 : 5,
              'state': 2,
              'flag': 2,
              'current': required,
              'required': required,
              'verified': true,
              'updated': now.toIso8601String(),
            },
          ],
        });
        final h = await _Harness.create(
          const GameState(memberId: 100),
          now,
          storage: storage,
        );
        expect(h.state.quests[id]!.progressCurrent, required);
        expect(h.state.quests[id]!.isCompleted, isFalse);
        expect(h.state.quests[504]!.isCompleted, isTrue);
        await h.event('api_req_hokyu/charge', {}, now, reduce: false);
        final reconnected = await _Harness.create(
          h.state,
          now,
          storage: storage,
        );
        expect(reconnected.state.quests[id]!.isCompleted, isFalse);
        await reconnected.server(
          id,
          now,
          type: id == 318 ? 3 : 5,
          state: 2,
          flag: 2,
        );
        expect(
          reconnected.state.quests[id]!.progressCurrent,
          lessThan(required),
        );
        expect(reconnected.state.quests[id]!.isCompleted, isFalse);
        await reconnected.server(id, now, type: id == 318 ? 3 : 5, state: 3);
        expect(reconnected.state.quests[id]!.isServerCompleted, isTrue);
        expect(reconnected.state.quests[id]!.isCompleted, isTrue);
      },
    );
  }

  test(
    'escort groups keep their existing whole-fleet default unless explicitly scoped',
    () {
      expect(
        matchesQuestStep(
          {
            'escortshiptype': [
              [
                [10],
                2,
              ],
            ],
          },
          const QuestProgressEvent(
            'practice_win_a',
            ships: [
              MasterShip(id: 1, name: '瑞穂', shipTypeId: 10),
              MasterShip(id: 2, name: '千歳', shipTypeId: 10),
            ],
          ),
        ),
        isTrue,
      );
    },
  );
}

Map<int, QuestProgressGoal> _rules() {
  final raw =
      jsonDecode(
            File('assets/data/quest-progress-goals.json').readAsStringSync(),
          )
          as Map;
  return {
    for (final e in raw.entries)
      int.parse(e.key): QuestProgressGoal(
        int.parse(e.key),
        Map<String, dynamic>.from(e.value),
      ),
  };
}

GameQuest _quest(
  int id,
  DateTime at, {
  int type = 4,
  int? current,
  int? required,
}) => GameQuest(
  id: id,
  title: 'task $id',
  detail: '',
  category: 3,
  type: type,
  state: 2,
  progressFlag: 0,
  updatedAt: at,
  progressCurrent: current,
  progressRequired: required,
);

GameState _state(GameQuest quest) =>
    GameState(memberId: 100, quests: {quest.id: quest});

GameState _practiceState(
  int id,
  DateTime now,
  List<String> names,
  List<int> types, {
  List<int>? classes,
  List<int>? masterIds,
}) => _state(_quest(id, now, type: id == 318 ? 3 : 5)).copyWith(
  fleets: [
    Fleet(
      id: 1,
      name: 'practice',
      shipIds: [for (var i = 1; i <= names.length; i++) i],
    ),
  ],
  ships: {
    for (var i = 1; i <= names.length; i++)
      i: OwnedShip(id: i, masterId: masterIds?[i - 1] ?? i, level: 99),
  },
  masterShips: {
    for (var i = 1; i <= names.length; i++)
      (masterIds?[i - 1] ?? i): MasterShip(
        id: masterIds?[i - 1] ?? i,
        name: names[i - 1],
        shipTypeId: types[i - 1],
        classTypeId: classes?[i - 1] ?? 0,
      ),
  },
);

class _MemoryProgress implements QuestProgressStorage {
  final values = <int, String>{};
  @override
  Future<String?> read(int account) async => values[account];
  @override
  Future<void> write(int account, String value) async {
    values[account] = value;
  }
}

class _Harness {
  _Harness(this.engine, this.storage, this.state);
  final QuestProgressEngine engine;
  final _MemoryProgress storage;
  GameState state;
  int sequence = 0;

  static Future<_Harness> create(
    GameState state,
    DateTime now, {
    _MemoryProgress? storage,
    Map<int, QuestProgressGoal>? goals,
  }) async {
    final store = storage ?? _MemoryProgress();
    final engine = QuestProgressEngine(
      goals: goals ?? _rules(),
      storage: store,
    );
    return _Harness(engine, store, await engine.restore(state, now));
  }

  Future<void> event(
    String path,
    Map<String, Object?> data,
    DateTime at, {
    Map<String, Object?> params = const {},
    bool reduce = true,
  }) async {
    final CapturedApiEvent event = kcsapiEvent(
      '/kcsapi/$path',
      data,
      requestParams: params,
      capturedAt: at,
      sequence: ++sequence,
    );
    state = await engine.process(
      state,
      reduce ? GameStateReducer().reduce(state, event) : state,
      event,
    );
  }

  Future<void> practice(
    DateTime at, {
    required String rank,
    required int times,
  }) async {
    for (var i = 0; i < times; i++) {
      await event(
        'api_req_practice/battle',
        {},
        at.add(Duration(seconds: i * 2 + 1)),
        params: {'api_deck_id': 1},
        reduce: false,
      );
      await event('api_req_practice/battle_result', {
        'api_win_rank': rank,
      }, at.add(Duration(seconds: i * 2 + 2)));
    }
  }

  Future<void> server(
    int id,
    DateTime at, {
    required int type,
    required int state,
    int flag = 0,
  }) => event('api_get_member/questlist', {
    'api_list': [
      {
        'api_no': id,
        'api_title': 'task $id',
        'api_detail': '',
        'api_category': 3,
        'api_type': type,
        'api_state': state,
        'api_progress_flag': flag,
      },
    ],
  }, at);
}
