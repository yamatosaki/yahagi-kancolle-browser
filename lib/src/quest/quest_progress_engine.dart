import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../battle/battle_models.dart';
import '../bridge/captured_api_event.dart';
import '../game_state/game_state.dart';
import 'quest_progress_rules.dart';

abstract interface class QuestProgressStorage {
  Future<String?> read(int account);
  Future<void> write(int account, String value);
}

class PreferencesQuestProgressStorage implements QuestProgressStorage {
  @override
  Future<String?> read(int account) async =>
      (await SharedPreferences.getInstance()).getString(
        'quest_progress_v1_$account',
      );
  @override
  Future<void> write(int account, String value) async {
    await (await SharedPreferences.getInstance()).setString(
      'quest_progress_v1_$account',
      value,
    );
  }
}

class QuestStepProgress {
  const QuestStepProgress(this.description, this.count, this.required);
  final String description;
  final int count;
  final int required;
}

/// Pure matching plus an ordered, account-scoped event ledger. No game requests.
class QuestProgressEngine {
  QuestProgressEngine({required this.goals, required this.storage});
  final Map<int, QuestProgressGoal> goals;
  final QuestProgressStorage storage;
  int _account = 0;
  int _generation = 0;
  final Map<int, _Record> _records = {};
  final Map<int, int> _ruleTypes = {};
  Map<int, GameQuest> _active = {};
  final Set<String> _seen = {};
  String _nodeToken = '';
  String _countedBattle = '';
  int _fleetId = 1, _map = 0, _cell = 0;
  bool _boss = false;
  String? _lastSaved;
  String? persistenceError;

  static Future<QuestProgressEngine> load() async {
    final raw =
        jsonDecode(
              await rootBundle.loadString(
                'assets/data/quest-progress-goals.json',
              ),
            )
            as Map;
    return QuestProgressEngine(
      goals: {
        for (final e in raw.entries)
          int.parse(e.key.toString()): QuestProgressGoal(
            int.parse(e.key.toString()),
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
      storage: PreferencesQuestProgressStorage(),
    );
  }

  Set<int> completedIds(DateTime now) => {
    for (final e in _records.entries)
      if (e.value.claimed && !_expired(e.key, e.value, now)) e.key,
  };
  List<QuestStepProgress> stepsFor(int id) {
    final record = _records[id], goal = goals[id];
    if (record == null || goal == null) return const [];
    return [
      for (final e in goal.steps.entries)
        QuestStepProgress(
          e.value['description']?.toString() ?? e.key,
          record.counts[e.key] ?? 0,
          _int(e.value['required']),
        ),
    ];
  }

  String periodFor(GameQuest quest, DateTime now) => questPeriodKey(
    _records[quest.id]?.ruleType ??
        _ruleTypes[quest.id] ??
        goals[quest.id]?.type ??
        0,
    quest.type,
    now,
  );

  bool _expired(int id, _Record r, DateTime now) =>
      r.period !=
      questPeriodKey(
        r.ruleType ?? _ruleTypes[id] ?? goals[id]?.type ?? 0,
        r.apiType,
        now,
      );

  Future<GameState> restore(
    GameState state,
    DateTime now, {
    bool allowLegacy = true,
  }) async {
    if (state.memberId <= 0) return state;
    resetSession();
    _account = state.memberId;
    final account = _account;
    final generation = _generation;
    _records.clear();
    _active = {};
    _seen.clear();
    _nodeToken = '';
    _countedBattle = '';
    _map = 0;
    _cell = 0;
    _boss = false;
    _lastSaved = null;
    var found = false;
    final expiredIds = <int>{};
    try {
      final raw = await storage.read(account);
      if (generation != _generation) {
        return state.copyWith(quests: {}, availableQuests: {});
      }
      if (raw != null) {
        final data = jsonDecode(raw) as Map;
        if (_int(data['account']) == _account) {
          found = true;
          for (final e in (data['ruleTypes'] as Map? ?? {}).entries) {
            final id = int.tryParse(e.key.toString()), type = _int(e.value);
            if (id != null && type >= 101 && type <= 112) {
              _ruleTypes[id] = type;
            }
          }
          for (final e in (data['records'] as Map? ?? {}).entries) {
            final id = int.tryParse(e.key.toString());
            if (id == null || e.value is! Map) continue;
            final r = _Record.fromJson(Map<String, dynamic>.from(e.value));
            // Read older caches whose annual reset month lived only on the
            // expiring counter. Rule metadata must outlive that period.
            final label = r.ruleType;
            if (label != null && label >= 101 && label <= 112) {
              _ruleTypes[id] = label;
            }
            if (_expired(id, r, now)) {
              expiredIds.add(id);
            } else {
              final revision = goals[id]?.revision ?? 0;
              if (r.ruleRevision < revision) {
                // Counts observed under a weaker rule are useful reference
                // progress, but require server confirmation after migration.
                if (!r.claimed && r.counts.values.any((count) => count > 0)) {
                  r.blocked = true;
                }
                r.ruleRevision = revision;
              }
              _records[id] = r;
            }
          }
          for (final q in data['active'] as List? ?? []) {
            final quest = _questFromJson(Map<String, dynamic>.from(q));
            if (!expiredIds.contains(quest.id) &&
                !quest.isExpired(now) &&
                !_expiredQuest(quest, now) &&
                !(_records[quest.id]?.claimed ?? false)) {
              _active[quest.id] = quest;
            }
          }
          _seen.addAll((data['seen'] as List? ?? []).whereType<String>());
          // A result retransmission after a reconnect must not count twice.
          _nodeToken = data['node']?.toString() ?? '';
          _countedBattle = data['counted']?.toString() ?? '';
          _fleetId = _int(data['fleet'], 1);
          _map = _int(data['map']);
          _cell = _int(data['cell']);
          _boss = data['boss'] == true;
        }
      }
    } catch (error) {
      if (generation != _generation) {
        return state.copyWith(quests: {}, availableQuests: {});
      }
      // A broken cache must not prevent game state initialization.
      persistenceError = error.toString();
      found = false;
      _records.clear();
      _ruleTypes.clear();
      _active.clear();
    }
    if (!found && allowLegacy) {
      _active = {
        for (final e in state.quests.entries)
          if (!e.value.isExpired(now)) e.key: e.value,
      };
    }
    final restored = state.copyWith(
      quests: Map.of(_active),
      availableQuests: {
        if (allowLegacy)
          for (final e in state.availableQuests.entries)
            if (!e.value.isExpired(now) && !_expiredQuest(e.value, now))
              e.key: e.value,
      },
      hasCompleteQuestData: false,
    );
    return expire(restored, now);
  }

  bool _expiredQuest(GameQuest q, DateTime now) =>
      q.updatedAt != null && periodFor(q, q.updatedAt!) != periodFor(q, now);

  Future<GameState> process(
    GameState previous,
    GameState next,
    CapturedApiEvent event, {
    LiveBattle? battle,
    bool battleTrusted = false,
    bool hasAccountScopedQuests = false,
  }) async {
    if (event.apiResult != 1) return next;
    if (next.memberId <= 0) {
      resetSession();
      return next;
    }
    final now = event.capturedAt.toUtc();
    final expiredPreviousIds = {
      if (previous.memberId == next.memberId)
        for (final q in {
          ...previous.availableQuests,
          ...previous.quests,
        }.values)
          if (q.isExpired(now) || _expiredQuest(q, now)) q.id,
    };
    final authoritativeSnapshot =
        event.path.endsWith('/questlist') ||
        event.path.endsWith('/api_req_quest/start');
    if (!authoritativeSnapshot && expiredPreviousIds.isNotEmpty) {
      // Reducers can update an exact count or its verification timestamp.
      // Retain the original period evidence before importing that new state.
      next = next.copyWith(
        quests: {
          for (final e in next.quests.entries)
            if (!expiredPreviousIds.contains(e.key)) e.key: e.value,
        },
        availableQuests: {
          for (final e in next.availableQuests.entries)
            if (!expiredPreviousIds.contains(e.key)) e.key: e.value,
        },
        hasCompleteQuestData: false,
      );
    } else if (authoritativeSnapshot && expiredPreviousIds.isNotEmpty) {
      final startedId = event.path.endsWith('/api_req_quest/start')
          ? _int(event.requestParams['api_quest_id'])
          : 0;
      GameQuest currentPeriodQuest(GameQuest q) {
        // A successful start or a freshly returned server row establishes a
        // new-period task, but cannot carry an exact count from the old period.
        if (!expiredPreviousIds.contains(q.id) ||
            (q.id != startedId && q.updatedAt?.toUtc() != now)) {
          return q;
        }
        final newlyAccepted = q.id == startedId;
        final serverCompleted = !newlyAccepted && q.isServerCompleted;
        return GameQuest(
          id: q.id,
          title: q.title,
          detail: q.detail,
          category: q.category,
          type: q.type,
          state: newlyAccepted ? 2 : q.state,
          progressFlag: newlyAccepted ? 0 : q.progressFlag,
          materials: q.materials,
          progressCurrent: serverCompleted ? q.progressRequired : null,
          progressRequired: q.progressRequired,
          localCompletionVerified: serverCompleted
              ? q.localCompletionVerified
              : false,
          updatedAt: now,
        );
      }

      final quests = {
        for (final e in next.quests.entries) e.key: currentPeriodQuest(e.value),
      };
      final availableQuests = {
        for (final e in next.availableQuests.entries)
          e.key: currentPeriodQuest(e.value),
      };
      if (expiredPreviousIds.contains(startedId)) {
        // A stale completed row can exist only in the available snapshot. The
        // successful start still establishes an accepted task in this period.
        final accepted = quests[startedId] ?? availableQuests[startedId];
        if (accepted != null) {
          quests[startedId] = accepted;
          availableQuests[startedId] = accepted;
        }
      }
      next = next.copyWith(quests: quests, availableQuests: availableQuests);
    }
    if (_account != next.memberId || previous.memberId <= 0) {
      final restoring = restore(
        next,
        now,
        allowLegacy:
            hasAccountScopedQuests || previous.memberId == next.memberId,
      );
      final generation = _generation;
      next = await restoring;
      if (generation != _generation) return next;
    }
    next = expire(next, now, project: false);
    final valid = {
      for (final e in next.quests.entries)
        if (!e.value.isExpired(now) && !_expiredQuest(e.value, now))
          e.key: e.value,
    };
    if (valid.length != next.quests.length) {
      next = next.copyWith(quests: valid, hasCompleteQuestData: false);
    }
    if (!RegExp(
      r'/(questlist|clearitemget|start|stop|next|battle|battleresult|battle_result|result|charge|createitem|createship|destroyship|remodel_slot|powerup|destroyitem2)$',
    ).hasMatch(event.path)) {
      return _project(next, now);
    }
    final token = sha256
        .convert(
          utf8.encode(
            '${event.path}|${event.capturedAt.microsecondsSinceEpoch}|${event.sequence}|${event.requestParams}|${event.responseBody}',
          ),
        )
        .toString();
    if (!_seen.add(token)) {
      return _project(next.copyWith(quests: previous.quests), now);
    }
    while (_seen.length > 128) {
      _seen.remove(_seen.first);
    }
    final decoded =
        event.decodedEnvelope ?? jsonDecode(event.responseBody) as Map;
    final data = Map<String, dynamic>.from(
      decoded['api_data'] is Map ? decoded['api_data'] as Map : {},
    );
    final path = event.path;
    if (path.endsWith('/questlist')) {
      for (final raw in data['api_list'] as List? ?? []) {
        if (raw is! Map) continue;
        final id = _int(raw['api_no']);
        final q = next.quests[id] ?? next.availableQuests[id];
        if (q == null) continue;
        final r = _record(q, now);
        r.claimed = false;
        final label = _int(raw['api_label_type']);
        if (label >= 101 && label <= 112 && goals[id] == null) {
          _ruleTypes[id] = label;
          r.ruleType = label;
          r.period = questPeriodKey(label, q.type, now);
        }
        final goal = goals[id];
        if (goal != null && id != 1101) {
          final steps = goal.steps;
          if (q.isServerCompleted) {
            for (final s in steps.entries) {
              r.counts[s.key] = _int(s.value['required']);
            }
            r.blocked = false;
          } else if (steps.length == 1) {
            final s = steps.entries.single,
                required = _int(steps.values.single['required']);
            final low = q.progressFlag == 2
                ? (required * .8).ceil()
                : q.progressFlag == 1
                ? (required * .5).ceil()
                : 0;
            final high = q.progressFlag == 2
                ? required - 1
                : q.progressFlag == 1
                ? (required * .8).ceil() - 1
                : (required * .5).ceil() - 1;
            r.counts[s.key] = (r.counts[s.key] ?? _int(s.value['init']))
                .clamp(low, high < low ? low : high)
                .clamp(0, required > 0 ? required - 1 : 0);
          } else if (_allDone(goal, r)) {
            // The authoritative task page contradicted a local completion.
            r.blocked = true;
          }
        }
      }
    }
    if (path.endsWith('/clearitemget')) {
      final id = _int(event.requestParams['api_quest_id']);
      final q = previous.quests[id] ?? previous.availableQuests[id];
      final r = q == null
          ? _records.putIfAbsent(
              id,
              () => _Record(questPeriodKey(goals[id]?.type ?? 0, 4, now), 4),
            )
          : _record(q, now);
      r.claimed = true;
      for (final step
          in goals[id]?.steps.entries ??
              const <MapEntry<String, Map<String, dynamic>>>[]) {
        r.counts[step.key] = _int(step.value['required']);
      }
    }
    final progressEvents = _events(
      previous,
      next,
      event,
      data,
      battle,
      battleTrusted,
      token,
    );
    for (final q in next.quests.values) {
      final goal = goals[q.id];
      if (!q.isAccepted ||
          q.isServerCompleted ||
          goal == null ||
          q.id == 1101 ||
          q.isExpired(now)) {
        continue;
      }
      final record = _record(q, now);
      if (record.claimed) continue;
      for (final s in goal.steps.entries) {
        for (final e in progressEvents) {
          if (s.key.split('@').first != e.kind ||
              !matchesQuestStep(s.value, e)) {
            continue;
          }
          final required = _int(s.value['required']);
          record.counts[s.key] =
              ((record.counts[s.key] ?? _int(s.value['init'])) + e.delta).clamp(
                0,
                required,
              );
        }
      }
    }
    final result = _project(next, now);
    _active = Map.of(result.quests);
    final generation = _generation;
    try {
      await _save();
      if (generation == _generation) persistenceError = null;
    } catch (error) {
      if (generation == _generation) persistenceError = error.toString();
    }
    return result;
  }

  _Record _record(GameQuest q, DateTime now) => _records.putIfAbsent(q.id, () {
    final r = _Record(
      questPeriodKey(_ruleTypes[q.id] ?? goals[q.id]?.type ?? 0, q.type, now),
      q.type,
    );
    r.ruleType = _ruleTypes[q.id];
    final goal = goals[q.id];
    if (goal != null) {
      r.ruleRevision = goal.revision;
      // Legacy quest-only caches have no ledger revision to establish which
      // fleet rules produced their exact count.
      r.blocked =
          goal.revision > 0 &&
          !q.isServerCompleted &&
          (q.progressCurrent ?? 0) > 0;
      r.countPeriod = questPeriodKey(
        _int(goal.raw['resetInterval']),
        q.type,
        now,
      );
      // Quest-only caches have no separate count-period marker. Do not turn
      // yesterday's partial daily streak into progress for today on restore.
      // As with ledger expiry, keep a fully reached streak for confirmation.
      final expiredCount =
          goal.raw['resetInterval'] != null &&
          q.updatedAt != null &&
          questPeriodKey(
                _int(goal.raw['resetInterval']),
                q.type,
                q.updatedAt!,
              ) !=
              r.countPeriod;
      for (final e in goal.steps.entries) {
        r.counts[e.key] = q.isServerCompleted
            ? _int(e.value['required'])
            : goal.steps.length == 1 &&
                  q.progressCurrent != null &&
                  (!expiredCount ||
                      q.progressCurrent! >= _int(e.value['required']))
            ? q.progressCurrent!.clamp(0, _int(e.value['required']))
            : _int(e.value['init']);
      }
    }
    return r;
  });

  GameState expire(GameState state, DateTime now, {bool project = true}) {
    final valid = {
      for (final e in state.quests.entries)
        if (!e.value.isExpired(now) && !_expiredQuest(e.value, now))
          e.key: e.value,
    };
    final available = {
      for (final e in state.availableQuests.entries)
        if (!e.value.isExpired(now) && !_expiredQuest(e.value, now))
          e.key: e.value,
    };
    final before = _records.length;
    _records.removeWhere((id, r) => _expired(id, r, now));
    var changed = before != _records.length;
    for (final e in _records.entries) {
      final goal = goals[e.key], record = e.value;
      if (goal == null || goal.raw['resetInterval'] == null) continue;
      final period = questPeriodKey(
        _int(goal.raw['resetInterval']),
        record.apiType,
        now,
      );
      if (record.countPeriod != period &&
          !record.claimed &&
          !_allDone(goal, record)) {
        record.counts.clear();
        record.blocked = false;
        changed = true;
      }
      record.countPeriod = period;
    }
    changed |= valid.length != state.quests.length;
    changed |= available.length != state.availableQuests.length;
    final expired = changed
        ? state.copyWith(
            quests: valid,
            availableQuests: available,
            hasCompleteQuestData: false,
          )
        : state;
    return project ? _project(expired, now) : expired;
  }

  bool _allDone(QuestProgressGoal goal, _Record r) =>
      goal.steps.isNotEmpty &&
      goal.steps.entries.every(
        (s) =>
            (r.counts[s.key] ?? _int(s.value['init'])) >=
            _int(s.value['required']),
      );
  GameState _project(GameState state, DateTime now) {
    final quests = Map<int, GameQuest>.of(state.quests);
    var changed = false;
    for (final q in state.quests.values) {
      final goal = goals[q.id];
      if (goal == null || q.id == 1101) continue;
      final record = _record(q, now);
      if (record.claimed) {
        quests.remove(q.id);
        changed = true;
        continue;
      }
      var count = 0, total = 0;
      for (final s in goal.steps.entries) {
        final required = _int(s.value['required']);
        total += required;
        count += (record.counts[s.key] ?? _int(s.value['init'])).clamp(
          0,
          required,
        );
      }
      final verified = goal.completeOnCount && !record.blocked;
      if (q.progressCurrent == count &&
          q.progressRequired == total &&
          q.localCompletionVerified == verified) {
        continue;
      }
      quests[q.id] = GameQuest(
        id: q.id,
        title: q.title,
        detail: q.detail,
        category: q.category,
        type: q.type,
        state: q.state,
        progressFlag: q.progressFlag,
        materials: q.materials,
        progressCurrent: count,
        progressRequired: total,
        localCompletionVerified: verified,
        updatedAt: q.updatedAt ?? now,
      );
      changed = true;
    }
    return changed ? state.copyWith(quests: quests) : state;
  }

  List<MasterShip> _ships(GameState state, int fleetId) {
    final fleet = state.fleets.where((f) => f.id == fleetId).firstOrNull;
    if (fleet == null) return [];
    final result = <MasterShip>[];
    for (final id in fleet.shipIds.where(
      (id) => id > 0 && !state.combatState.escapedShipIds.contains(id),
    )) {
      final ship = state.ships[id];
      final master = state.masterShips[ship?.masterId];
      // Unknown ship data must not satisfy a maximum fleet size / flagship rule.
      if (master == null) return [];
      result.add(master);
    }
    return result;
  }

  List<QuestProgressEvent> _events(
    GameState previous,
    GameState next,
    CapturedApiEvent event,
    Map<String, dynamic> data,
    LiveBattle? battle,
    bool trusted,
    String token,
  ) {
    final path = event.path;
    final result = <QuestProgressEvent>[];
    final options = <String, dynamic>{'maparea': _map, 'mapcell': _cell};
    var ships = _ships(previous, _fleetId);
    final shipIdEvents = <String>{
      for (final quest in next.quests.values)
        if (quest.isAccepted)
          for (final step
              in goals[quest.id]?.steps.entries ??
                  const <MapEntry<String, Map<String, dynamic>>>[])
            if (step.value.keys.any(
              const {
                'flagshipId',
                'secondshipId',
                'escortshipId',
                'escortshipIdAll',
              }.contains,
            ))
              step.key.split('@').first,
    };
    _QuestShipRemodelGraph? remodelGraph;
    void add(String kind, {int delta = 1, Map<String, dynamic>? extra}) {
      if (delta > 0) {
        final shipIds = shipIdEvents.contains(kind) && ships.isNotEmpty
            ? (remodelGraph ??= _QuestShipRemodelGraph(
                previous.masterShips,
              )).forShips(ships)
            : null;
        result.add(
          QuestProgressEvent(
            kind,
            delta: delta,
            options: {...options, ...?extra, 'shipIds': ?shipIds},
            ships: ships,
          ),
        );
      }
    }

    if (path.endsWith('/api_req_map/start') ||
        path.endsWith('/api_req_map/next')) {
      if (path.endsWith('/start')) {
        _fleetId = _int(event.requestParams['api_deck_id'], 1);
        add('sally');
      }
      _map = _int(data['api_maparea_id']) * 10 + _int(data['api_mapinfo_no']);
      _cell = _int(data['api_no']);
      _boss = _int(data['api_event_id']) == 5;
      _nodeToken = token;
      _countedBattle = '';
      ships = _ships(previous, _fleetId);
      options.addAll({'maparea': _map, 'mapcell': _cell});
      if (path.endsWith('/next')) add('reach_mapcell');
    } else if (path.endsWith('/api_req_practice/battle')) {
      _fleetId = _int(
        data['api_deck_id'],
        _int(event.requestParams['api_deck_id'], 1),
      );
      _nodeToken = token;
      _countedBattle = '';
    } else if (path.endsWith('/battleresult') ||
        path.endsWith('/api_req_practice/battle_result')) {
      if (_nodeToken.isEmpty || _countedBattle == _nodeToken) return [];
      _countedBattle = _nodeToken;
      final practice = path.contains('practice');
      final rank = data['api_win_rank']?.toString() ?? '';
      // Use the actual participating fleet and map snapshot, not a later edited fleet.
      if (battle != null &&
          battle.context.practice == practice &&
          (practice ||
              (battle.context.mapAreaId * 10 + battle.context.mapInfoNo ==
                      _map &&
                  battle.context.node == _cell))) {
        ships = _ships(previous, battle.context.deckId);
        if (!practice && trusted) {
          for (final enemy in battle.enemyShips) {
            if (enemy.hpUnknown || !enemy.isSunk) continue;
            final type = previous.masterShips[enemy.masterId]?.shipTypeId;
            if (type != null) add('sinking', extra: {'shipType': type});
          }
        }
      }
      if (practice) {
        add('practice');
        if (['S', 'A', 'B'].contains(rank)) add('practice_win');
        if (['S', 'A'].contains(rank)) add('practice_win_a');
        if (rank == 'S') add('practice_win_s');
      } else {
        add('battle');
        if (['S', 'A', 'B'].contains(rank)) add('battle_win');
        if (rank == 'S') add('battle_rank_s');
        if (_boss) {
          add('battle_boss');
          if (['S', 'A', 'B'].contains(rank)) add('battle_boss_win');
          if (['S', 'A'].contains(rank)) add('battle_boss_win_rank_a');
          if (rank == 'S') add('battle_boss_win_rank_s');
        }
      }
    } else if (path.endsWith('/api_req_mission/result')) {
      if (_int(data['api_clear_result']) > 0) {
        add('mission_success', extra: {'mission': data['api_quest_name']});
      }
    } else if (path.endsWith('/api_req_nyukyo/start')) {
      add('repair');
    } else if (path.endsWith('/api_req_hokyu/charge')) {
      add('supply');
    } else if (path.endsWith('/api_req_kousyou/createitem')) {
      add(
        'create_item',
        delta: data['api_get_items'] is List
            ? (data['api_get_items'] as List).length
            : 1,
      );
    } else if (path.endsWith('/api_req_kousyou/createship')) {
      add('create_ship');
    } else if (path.endsWith('/api_req_kousyou/destroyship')) {
      add(
        'destroy_ship',
        delta: _ids(event.requestParams['api_ship_id']).length,
      );
    } else if (path.endsWith('/api_req_kousyou/remodel_slot')) {
      add('remodel_item');
    } else if (path.endsWith('/api_req_kaisou/powerup')) {
      if (_int(data['api_powerup_flag']) == 1) {
        add(
          'remodel_ship',
          extra: {
            'times': 1,
            'materialShipTypes': [
              for (final id in _ids(event.requestParams['api_id_items']))
                previous.masterShips[previous.ships[id]?.masterId]?.shipTypeId,
            ],
          },
        );
      }
    } else if (path.endsWith('/api_req_kousyou/destroyitem2')) {
      final byType = <int, int>{}, byId = <int, int>{};
      for (final id in _ids(event.requestParams['api_slotitem_ids'])) {
        final item = previous.slotItems[id];
        if (item == null) continue;
        byId.update(item.masterId, (v) => v + 1, ifAbsent: () => 1);
        final types = previous.masterSlotItems[item.masterId]?.type;
        final type = types != null && types.length > 2 ? types[2] : null;
        if (type != null) byType.update(type, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final e in byType.entries) {
        add('destory_item', delta: e.value, extra: {'slotitemType2': e.key});
      }
      for (final e in byId.entries) {
        add('destory_item', delta: e.value, extra: {'slotitemId': e.key});
      }
      add('destory_item', extra: {'times': 1});
    }
    return result;
  }

  /// Invalidate in-flight restores without deleting this account's ledger.
  void resetSession() {
    _generation++;
    _account = 0;
    _records.clear();
    _ruleTypes.clear();
    _active.clear();
    _seen.clear();
    _nodeToken = '';
    _countedBattle = '';
    _fleetId = 1;
    _map = _cell = 0;
    _boss = false;
    _lastSaved = null;
    persistenceError = null;
  }

  Future<void> clear() async {
    _records.clear();
    _ruleTypes.clear();
    _active.clear();
    _seen.clear();
    _nodeToken = '';
    _countedBattle = '';
    _map = _cell = 0;
    _boss = false;
    _lastSaved = null;
    await _save();
  }

  Future<void> _save() async {
    if (_account <= 0) return;
    final account = _account;
    final generation = _generation;
    final raw = jsonEncode({
      'account': _account,
      'records': {
        for (final e in _records.entries) e.key.toString(): e.value.toJson(),
      },
      'ruleTypes': {
        for (final e in _ruleTypes.entries) e.key.toString(): e.value,
      },
      'active': _active.values.map(_questToJson).toList(),
      'seen': _seen.toList(),
      'node': _nodeToken,
      'counted': _countedBattle,
      'fleet': _fleetId,
      'map': _map,
      'cell': _cell,
      'boss': _boss,
    });
    if (raw == _lastSaved) return;
    await storage.write(account, raw);
    if (generation == _generation) _lastSaved = raw;
  }
}

// A goal names the first remodel that counts. Walk only incoming remodel links:
// later variants count as their ancestors, but never as unvisited descendants.
class _QuestShipRemodelGraph {
  _QuestShipRemodelGraph(Map<int, MasterShip> masters) {
    for (final ship in masters.values) {
      if (ship.id > 0 && ship.afterShipId > 0) {
        _incoming.putIfAbsent(ship.afterShipId, () => []).add(ship.id);
      }
    }
  }

  final _incoming = <int, List<int>>{};
  final _sources = <int, List<int>>{};

  List<List<int>> forShips(List<MasterShip> ships) => [
    for (final ship in ships)
      _sources.putIfAbsent(ship.id, () {
        final seen = <int>{};
        final queue = [ship.id];
        for (var i = 0; i < queue.length; i++) {
          final current = queue[i];
          if (current <= 0 || !seen.add(current)) continue;
          queue.addAll(_incoming[current] ?? const []);
        }
        return seen.toList(growable: false);
      }),
  ];
}

int _int(dynamic value, [int fallback = 0]) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;
List<int> _ids(dynamic value) => (value?.toString() ?? '')
    .split(',')
    .map((v) => _int(v))
    .where((v) => v > 0)
    .toList();

class _Record {
  _Record(this.period, this.apiType);
  String period;
  String? countPeriod;
  int? ruleType;
  int ruleRevision = 0;
  final int apiType;
  final Map<String, int> counts = {};
  bool claimed = false, blocked = false;
  Map<String, dynamic> toJson() => {
    'period': period,
    'countPeriod': countPeriod,
    'ruleType': ruleType,
    'ruleRevision': ruleRevision,
    'type': apiType,
    'counts': counts,
    'claimed': claimed,
    'blocked': blocked,
  };
  factory _Record.fromJson(Map<String, dynamic> json) {
    final r = _Record(json['period'] as String, _int(json['type']));
    r.countPeriod = json['countPeriod'] as String?;
    r.ruleType = json['ruleType'] as int?;
    r.ruleRevision = _int(json['ruleRevision']);
    r.claimed = json['claimed'] == true;
    r.blocked = json['blocked'] == true;
    for (final e in (json['counts'] as Map? ?? {}).entries) {
      r.counts[e.key.toString()] = _int(e.value);
    }
    return r;
  }
}

Map<String, dynamic> _questToJson(GameQuest q) => {
  'id': q.id,
  'title': q.title,
  'detail': q.detail,
  'category': q.category,
  'type': q.type,
  'state': q.state,
  'flag': q.progressFlag,
  'materials': q.materials,
  'current': q.progressCurrent,
  'required': q.progressRequired,
  'verified': q.localCompletionVerified,
  'updated': q.updatedAt?.toIso8601String(),
};
GameQuest _questFromJson(Map<String, dynamic> q) => GameQuest(
  id: _int(q['id']),
  title: q['title']?.toString() ?? '',
  detail: q['detail']?.toString() ?? '',
  category: _int(q['category']),
  type: _int(q['type']),
  state: _int(q['state']),
  progressFlag: _int(q['flag']),
  materials: (q['materials'] as List? ?? []).map((v) => _int(v)).toList(),
  progressCurrent: q['current'] as int?,
  progressRequired: q['required'] as int?,
  localCompletionVerified: q['verified'] as bool?,
  updatedAt: DateTime.tryParse(q['updated']?.toString() ?? ''),
);
