import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_engine.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_rules.dart';

import 'quest_progress_engine_test.dart' as existing;

const _id = 99990;
final _now = DateTime.utc(2026, 10, 29, 3);

QuestProgressGoal _goal(Map<String, dynamic> steps, {int id = _id}) =>
    QuestProgressGoal(id, {'type': 0, ...steps});

Future<existing.Harness> _session(
  Map<int, QuestProgressGoal> goals, {
  existing.MemoryProgress? storage,
  GameState? state,
}) async {
  final engine = QuestProgressEngine(
    goals: goals,
    storage: storage ?? existing.MemoryProgress(),
  );
  return existing.Harness(
    engine,
    await engine.restore(
      state ??
          existing
              .sample(_now, id: _id)
              .copyWith(
                fleets: [
                  const Fleet(id: 1, name: 'one', shipIds: [1, 2]),
                ],
                ships: {
                  1: const OwnedShip(id: 1, masterId: 1, level: 99),
                  2: const OwnedShip(id: 2, masterId: 2, level: 99),
                },
                masterShips: {
                  1: const MasterShip(id: 1, name: 'one', shipTypeId: 2),
                  2: const MasterShip(id: 2, name: 'two', shipTypeId: 2),
                },
              ),
      _now,
    ),
    _now,
  );
}

Future<GameState> _replace(
  QuestProgressEngine engine,
  GameState state,
  Map<int, QuestProgressGoal> goals, [
  DateTime? now,
]) => engine.replaceGoals(state, goals, now ?? _now);

void main() {
  test(
    'the complete bundled dataset can be adopted through the live API',
    () async {
      final h = await _session({});
      final bundled = existing.rules();
      h.state = await _replace(h.engine, h.state, bundled);
      expect(h.engine.goals.length, bundled.length);
    },
  );

  test(
    'expired old-rule quests cannot be revived by a less frequent schedule',
    () async {
      final h = await _session({
        _id: _goal({
          'type': 1,
          'create_item': {'required': 3, 'init': 0},
        }),
      });
      await h.event('api_req_kousyou/createitem', {});
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 3, 'init': 0},
        }),
      }, _now.add(const Duration(days: 1)));
      expect(h.state.quests.containsKey(_id), isFalse);
      expect(h.engine.stepsFor(_id), isEmpty);
    },
  );

  test(
    'shrinking a daily subgoal cannot retain yesterday\'s unfinished count',
    () async {
      final h = await _session({
        _id: _goal({
          'resetInterval': 1,
          'create_item': {'required': 3, 'init': 0},
        }),
      });
      await h.event('api_req_kousyou/createitem', {});
      await h.event('api_req_kousyou/createitem', {});
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'resetInterval': 1,
          'create_item': {'required': 2, 'init': 0},
        }),
      }, _now.add(const Duration(days: 1)));
      expect(h.state.quests[_id]!.progressCurrent, 0);
    },
  );

  test(
    'unknown event kinds and metadata cannot prove fresh completion',
    () async {
      for (final raw in [
        {
          'future_event': {'required': 1, 'init': 1},
        },
        {
          'future_condition': true,
          'create_item': {'required': 1, 'init': 1},
        },
      ]) {
        final h = await _session({});
        h.state = await _replace(h.engine, h.state, {_id: _goal(raw)});
        expect(h.state.quests[_id]!.isLocallyCompleted, isFalse);
      }
    },
  );

  test(
    'malformed known constraints fail before adopting any replacement',
    () async {
      final h = await _session({});
      for (final invalid in [
        {'flagshipId': null},
        {'flagshipId': '1'},
        {
          'escortshipId': [
            [1, 2],
          ],
        },
        {'fleetlimit': -1},
      ]) {
        await expectLater(
          _replace(h.engine, h.state, {
            _id: _goal({
              'sally': {'required': 1, 'init': 1, ...invalid},
            }),
          }),
          throwsFormatException,
        );
        expect(h.engine.goals, isEmpty);
      }
    },
  );

  test('sally uses the requested fleet and new map before matching', () async {
    final h = await _session({
      _id: _goal({
        'sally': {
          'required': 3,
          'init': 0,
          'maparea': [12],
          'flagshipId': [2],
        },
      }),
    });
    h.state = h.state.copyWith(
      fleets: [
        const Fleet(id: 1, name: 'one', shipIds: [1]),
        const Fleet(id: 2, name: 'two', shipIds: [2]),
      ],
    );
    await h.event(
      'api_req_map/start',
      {'api_maparea_id': 1, 'api_mapinfo_no': 2, 'api_no': 1},
      params: {'api_deck_id': 2},
    );
    expect(h.engine.stepsFor(_id).single.count, 1);
    await h.event(
      'api_req_map/start',
      {'api_maparea_id': 1, 'api_mapinfo_no': 2, 'api_no': 1},
      params: {'api_deck_id': 1},
    );
    expect(h.engine.stepsFor(_id).single.count, 1);
  });

  test('new definitions project an already active quest immediately', () async {
    final h = await _session({});
    h.state = await _replace(h.engine, h.state, {
      _id: _goal({
        'create_item': {'required': 3, 'init': 1},
      }),
    });
    expect(h.state.quests[_id]!.exactProgressLabel, '1/3');
    expect(h.engine.stepsFor(_id).single.count, 1);
    await h.event('api_req_kousyou/createitem', {});
    expect(h.state.quests[_id]!.exactProgressLabel, '2/3');
  });

  test(
    'a newly tracked step starts at init instead of an unproven aggregate',
    () async {
      final h = await _session(
        {},
        state: existing
            .sample(_now, id: _id)
            .copyWith(
              quests: {
                _id: GameQuest(
                  id: _id,
                  title: 'legacy',
                  detail: '',
                  category: 2,
                  type: 4,
                  state: 2,
                  progressFlag: 0,
                  progressCurrent: 2,
                  progressRequired: 2,
                  updatedAt: _now,
                ),
              },
            ),
      );
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 2, 'init': 0},
        }),
      });
      expect(h.state.quests[_id]!.exactProgressLabel, '0/2');
      expect(h.state.quests[_id]!.isLocallyCompleted, isFalse);
    },
  );

  test(
    'reload clamps retained steps, replaces keys, and waits for the server',
    () async {
      final h = await _session({
        _id: _goal({
          'create_item': {'required': 5, 'init': 0},
          'create_ship': {'required': 1, 'init': 0},
        }),
      });
      for (var i = 0; i < 3; i++) {
        await h.event('api_req_kousyou/createitem', {});
      }
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 2, 'init': 0},
          'remodel_item': {'required': 1, 'init': 1},
        }),
      });
      expect(h.engine.stepsFor(_id).map((s) => s.count), [2, 1]);
      expect(h.state.quests[_id]!.exactProgressLabel, '3/3');
      expect(h.state.quests[_id]!.isLocallyCompleted, isFalse);
      h.state = h.state.copyWith(
        quests: {_id: existing.quest(_id, _now, state: 3)},
      );
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 4, 'init': 0},
          'remodel_item': {'required': 2, 'init': 0},
        }),
      });
      expect(h.engine.stepsFor(_id).map((s) => s.count), [4, 2]);
      expect(h.state.quests[_id]!.isServerCompleted, isTrue);
    },
  );

  test(
    'stricter same-revision conditions discard unproven counts and persist the block',
    () async {
      final storage = existing.MemoryProgress();
      final h = await _session({
        _id: _goal({
          'sally': {'required': 2, 'init': 0},
        }),
      }, storage: storage);
      await h.battle(12);
      final strict = {
        _id: _goal({
          'sally': {
            'required': 2,
            'init': 0,
            'flagshipId': [1],
          },
        }),
      };
      h.state = await _replace(h.engine, h.state, strict);
      expect(h.state.quests[_id]!.progressCurrent, 0);
      await h.battle(12);
      await h.battle(12);
      expect(h.state.quests[_id]!.exactProgressLabel, '2/2');
      expect(h.state.quests[_id]!.isLocallyCompleted, isFalse);
      final restored = await _session(strict, storage: storage, state: h.state);
      expect(restored.state.quests[_id]!.exactProgressLabel, '2/2');
      expect(restored.state.quests[_id]!.isLocallyCompleted, isFalse);
    },
  );

  test(
    'semantic fingerprints migrate on restart without a revision increase',
    () async {
      final storage = existing.MemoryProgress();
      final h = await _session({
        _id: _goal({
          'create_item': {'required': 5, 'init': 0},
        }),
      }, storage: storage);
      for (var i = 0; i < 3; i++) {
        await h.event('api_req_kousyou/createitem', {});
      }
      final restored = await _session(
        {
          _id: _goal({
            'create_item': {'required': 2, 'init': 0},
          }),
        },
        storage: storage,
        state: h.state,
      );
      expect(restored.state.quests[_id]!.exactProgressLabel, '2/2');
      expect(restored.state.quests[_id]!.isLocallyCompleted, isFalse);
    },
  );

  test(
    'description-only reload preserves progress and revision never decreases',
    () async {
      final storage = existing.MemoryProgress();
      final h = await _session({
        _id: _goal({
          'revision': 4,
          'create_item': {'required': 2, 'init': 0},
        }),
      }, storage: storage);
      await h.event('api_req_kousyou/createitem', {});
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'revision': 1,
          'create_item': {
            'required': 2,
            'init': 0,
            'description': 'translated',
          },
        }),
      });
      await h.event('api_req_kousyou/createitem', {});
      expect(h.state.quests[_id]!.isLocallyCompleted, isTrue);
      final saved = jsonDecode(storage.values[100]!) as Map;
      expect(saved['records']['$_id']['ruleRevision'], 4);
    },
  );

  for (final change in ['type', 'resetInterval']) {
    test('$change changes cannot carry counts into a new schedule', () async {
      final h = await _session({
        _id: _goal({
          'create_item': {'required': 3, 'init': 0},
        }),
      });
      await h.event('api_req_kousyou/createitem', {});
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          change: 1,
          'create_item': {'required': 3, 'init': 0},
        }),
      });
      expect(h.state.quests[_id]!.progressCurrent, 0);
      expect(h.state.quests[_id]!.localCompletionVerified, isFalse);
    });
  }

  test(
    'missing definitions, claimed history, node and result deduplication survive reload',
    () async {
      final h = await _session({
        _id: _goal({
          'battle': {'required': 5, 'init': 0},
        }),
        99991: _goal({
          'create_item': {'required': 1, 'init': 0},
        }, id: 99991),
      });
      await h.battle(12);
      await h.event(
        'api_req_quest/clearitemget',
        {},
        params: {'api_quest_id': 99991},
      );
      h.state = await _replace(h.engine, h.state, {});
      expect(h.engine.goals.keys, containsAll([_id, 99991]));
      expect(h.engine.completedIds(_now), {99991});
      await h.event('api_req_sortie/battleresult', {'api_win_rank': 'S'});
      expect(h.engine.stepsFor(_id).single.count, 1);
    },
  );

  test(
    'unknown constraints and existing blocks cannot become completion proof',
    () async {
      final h = await _session({
        _id: _goal({
          'create_item': {'required': 3, 'init': 0},
        }),
      });
      await h.event('api_req_kousyou/createitem', {});
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 1, 'init': 0},
        }),
      });
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'unrecognizedCondition': true,
          'create_item': {'required': 1, 'init': 1},
        }),
      });
      expect(h.state.quests[_id]!.isLocallyCompleted, isFalse);
      h.state = await _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 1, 'init': 1},
        }),
      });
      expect(h.state.quests[_id]!.isLocallyCompleted, isFalse);
    },
  );

  test('invalid replacement leaves definitions and ledger intact', () async {
    final h = await _session({
      _id: _goal({
        'create_item': {'required': 3, 'init': 0},
      }),
    });
    await h.event('api_req_kousyou/createitem', {});
    await expectLater(
      _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 1, 'init': 0},
        }),
        99991: _goal({
          'create_item': {'required': -1, 'init': 0},
        }, id: 99991),
      }),
      throwsFormatException,
    );
    expect(h.engine.goals[_id]!.steps['create_item']!['required'], 3);
    expect(h.engine.goals.containsKey(99991), isFalse);
    expect(h.engine.stepsFor(_id).single.count, 1);
  });

  test('input maps and exposed goals cannot mutate live rules', () async {
    final raw = <String, dynamic>{
      'create_item': {'required': 3, 'init': 0},
    };
    final input = {_id: _goal(raw)};
    final h = await _session(input);
    (raw['create_item'] as Map)['required'] = 1;
    input.clear();
    expect(h.engine.goals[_id]!.steps['create_item']!['required'], 3);
    expect(() => h.engine.goals.clear(), throwsUnsupportedError);
    expect(
      () => (h.engine.goals[_id]!.raw['create_item'] as Map)['required'] = 1,
      throwsUnsupportedError,
    );
  });

  test(
    'save failure keeps live replacement and permits a later retry',
    () async {
      final storage = existing.MemoryProgress();
      final h = await _session({}, storage: storage);
      storage.fail = true;
      final goals = {
        _id: _goal({
          'create_item': {'required': 3, 'init': 1},
        }),
      };
      h.state = await _replace(h.engine, h.state, goals);
      expect(h.state.quests[_id]!.exactProgressLabel, '1/3');
      expect(h.engine.persistenceError, isNotNull);
      storage.fail = false;
      h.state = await _replace(h.engine, h.state, goals);
      expect(h.engine.persistenceError, isNull);
      expect(storage.values[100], isNotNull);
    },
  );

  test(
    'old-account in-flight replacement save cannot affect a new session',
    () async {
      final storage = _DelayedProgress();
      final h = await _session({}, storage: storage);
      final replacing = _replace(h.engine, h.state, {
        _id: _goal({
          'create_item': {'required': 3, 'init': 1},
        }),
      });
      await storage.started.future;
      h.engine.resetSession();
      final newState = await h.engine.restore(
        existing.sample(_now, id: _id).copyWith(memberId: 200),
        _now,
      );
      storage.finish.completeError(StateError('old account disk error'));
      await replacing;
      expect(h.engine.persistenceError, isNull);
      expect(newState.quests[_id]!.exactProgressLabel, '1/3');
      expect(storage.values.containsKey(200), isFalse);
    },
  );

  test(
    'rules still adopt when an in-flight old-account read is superseded',
    () async {
      final storage = _DelayedReadProgress();
      final engine = QuestProgressEngine(goals: {}, storage: storage);
      final replacement = engine.replaceGoals(existing.sample(_now, id: _id), {
        _id: _goal({
          'create_item': {'required': 3, 'init': 1},
        }),
      }, _now);
      await storage.started.future;
      engine.resetSession();
      await engine.restore(
        existing.sample(_now, id: _id).copyWith(memberId: 200),
        _now,
      );
      storage.finish.complete();
      await replacement;
      expect(engine.goals.containsKey(_id), isTrue);
      expect(engine.stepsFor(_id).single.count, 1);
      expect(storage.values.containsKey(100), isFalse);
      final saved = jsonDecode(storage.values[200]!) as Map;
      expect(saved['account'], 200);
    },
  );

  test(
    'adoption during the new account read never saves an empty ledger',
    () async {
      final storage = _DelayedReadProgress()..delayNewAccount = true;
      final engine = QuestProgressEngine(goals: {}, storage: storage);
      final replacement = engine.replaceGoals(existing.sample(_now, id: _id), {
        _id: _goal({
          'create_item': {'required': 3, 'init': 1},
        }),
      }, _now);
      await storage.started.future;
      engine.resetSession();
      final restoring = engine.restore(
        existing.sample(_now, id: _id).copyWith(memberId: 200),
        _now,
      );
      await storage.newAccountStarted.future;
      storage.finish.complete();
      await replacement;
      expect(engine.goals.containsKey(_id), isTrue);
      expect(storage.values, isEmpty);
      storage.newAccountFinish.complete();
      final current = await restoring;
      expect(current.memberId, 200);
      expect(current.quests[_id]!.exactProgressLabel, '1/3');
      expect(engine.stepsFor(_id).single.count, 1);
    },
  );
}

class _DelayedProgress extends existing.MemoryProgress {
  final started = Completer<void>();
  final finish = Completer<void>();

  @override
  Future<void> write(int account, String value) async {
    started.complete();
    await finish.future;
    await super.write(account, value);
  }
}

class _DelayedReadProgress extends existing.MemoryProgress {
  final started = Completer<void>();
  final finish = Completer<void>();
  bool delayNewAccount = false;
  final newAccountStarted = Completer<void>();
  final newAccountFinish = Completer<void>();

  @override
  Future<String?> read(int account) async {
    if (account == 100) {
      started.complete();
      await finish.future;
    } else if (delayNewAccount) {
      newAccountStarted.complete();
      await newAccountFinish.future;
    }
    return super.read(account);
  }
}
