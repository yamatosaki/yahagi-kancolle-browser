import 'dart:async';

import 'package:flutter/foundation.dart';

import '../account/account_session.dart';
import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../performance/frame_notification_coalescer.dart';
import 'senka_calculation.dart';
import 'senka_catalog.dart';
import 'senka_reducer.dart';
import 'senka_state.dart';
import 'senka_store.dart';

class SenkaController extends ChangeNotifier implements GameApiEventConsumer {
  SenkaController({
    required this.store,
    this._reducer = const SenkaReducer(),
    DateTime Function()? now,
    FrameNotificationCoalescer? captureNotifications,
    AccountSession? accountSession,
  }) : _now = now ?? DateTime.now,
       _accountSession =
           accountSession ??
           (store is AccountSenkaStore ? AccountSession.shared : null),
       _captureNotifications =
           captureNotifications ?? FrameNotificationCoalescer(),
       _state = SenkaState.forMonth(
         currentSenkaMonthKey((now ?? DateTime.now)()),
       ) {
    _accountSession?.addListener(_onAccountChanged);
  }

  final SenkaStore store;
  final SenkaReducer _reducer;
  final FrameNotificationCoalescer _captureNotifications;
  final DateTime Function() _now;
  final AccountSession? _accountSession;
  SenkaState _state;
  Future<void> _queue = Future<void>.value();
  int _revision = 0;
  final Map<int, ({int revision, SenkaState state})> _pendingAccountSaves = {};
  bool _disposed = false;
  Object? _persistenceError;

  SenkaState get state => _state;
  double get monthBaseSenka => _state.monthExperienceSenka;
  bool get hasPersistenceError => _persistenceError != null;
  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) => _reducer.supportsPath(path);

  Future<void> initialize() async {
    if (_accountSession != null) {
      _onAccountChanged();
      await _queue;
      return;
    }
    final revisionAtStart = _revision;
    final SenkaState? loaded;
    try {
      loaded = await store.load();
    } catch (error) {
      if (!_disposed && _revision == revisionAtStart) {
        _persistenceError = error;
        debugPrint('Senka persistence load failed: $error');
        notifyListeners();
      }
      return;
    }
    if (_disposed || _revision != revisionAtStart) return;
    final instant = _now();
    if (loaded == null) {
      _state = ensureSenkaDailyTarget(_state, instant);
      _revision++;
      notifyListeners();
      return;
    }
    final month = currentSenkaMonthKey(instant);
    final monthMigrated = migrateSenkaExperienceTracking(
      migrateSenkaStateToMonth(loaded, month),
    );
    final rewardMigrated = migrateSenkaRewardCycles(monthMigrated, instant);
    final migrated = identical(rewardMigrated, monthMigrated)
        ? ensureSenkaDailyTarget(monthMigrated, instant)
        : rebaseSenkaDailyTarget(monthMigrated, rewardMigrated, instant);
    _state = migrated;
    final revision = ++_revision;
    _rememberAccountSave(migrated, revision);
    notifyListeners();
    if (!identical(migrated, loaded)) {
      _enqueue(() => _saveIfCurrent(migrated, revision));
      await _queue;
    }
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed) return;
    final scope = _accountSession?.current;
    if (scope != null && !scope.isKnown) return;
    _enqueue(() async {
      if (_disposed || (scope != null && !_accountSession!.isCurrent(scope))) {
        return;
      }
      final next = _reducer.reduce(_state, event);
      if (identical(next, _state)) return;
      _state = next;
      final revision = ++_revision;
      _rememberAccountSave(next, revision);
      _captureNotifications.schedule(notifyListeners);
      await _saveIfCurrent(next, revision);
    });
  }

  void _onAccountChanged() {
    if (_disposed) return;
    final scope = _accountSession!.current;
    _state = SenkaState.forMonth(
      currentSenkaMonthKey(_now()),
    ).copyWith(memberId: scope.memberId);
    final revision = ++_revision;
    _persistenceError = null;
    notifyListeners();
    if (!scope.isKnown) return;
    _enqueue(() => _restoreAccount(scope, revision));
  }

  Future<void> _restoreAccount(AccountScope scope, int revision) async {
    final session = _accountSession!;
    if (_disposed || !session.isCurrent(scope) || revision != _revision) {
      return;
    }
    try {
      final pending = _pendingAccountSaves[scope.memberId]?.state;
      final archive =
          pending ??
          (store is AccountSenkaStore
              ? await (store as AccountSenkaStore).loadForAccount(
                  scope.memberId,
                )
              : await store.load());
      if (_disposed || !session.isCurrent(scope) || revision != _revision) {
        return;
      }
      if (archive == null || archive.memberId != scope.memberId) return;
      final instant = _now();
      final current = migrateSenkaExperienceTracking(
        migrateSenkaStateToMonth(archive, currentSenkaMonthKey(instant)),
      );
      final rewards = migrateSenkaRewardCycles(current, instant);
      _state = identical(rewards, current)
          ? ensureSenkaDailyTarget(current, instant)
          : rebaseSenkaDailyTarget(current, rewards, instant);
      _revision++;
      notifyListeners();
    } catch (error) {
      if (_disposed || !session.isCurrent(scope)) return;
      _persistenceError = error;
      notifyListeners();
    }
  }

  void cycleEoReward(int id) {
    if (senkaEoById(id) == null || _disposed) return;
    final values = Map<int, SenkaRewardStatus>.of(_state.eoStatuses);
    values[id] = (values[id] ?? SenkaRewardStatus.deferred).next;
    final next = _state.copyWith(eoStatuses: values);
    _replace(rebaseSenkaDailyTarget(_state, next, _now()));
  }

  void cycleQuestReward(int id) {
    if (senkaQuestById(id) == null || _disposed) return;
    final values = Map<int, SenkaRewardStatus>.of(_state.questStatuses);
    values[id] = (values[id] ?? SenkaRewardStatus.deferred).next;
    final next = _state.copyWith(questStatuses: values);
    _replace(rebaseSenkaDailyTarget(_state, next, _now()));
  }

  void toggleEo(int id) => cycleEoReward(id);

  void toggleQuest(int id) => cycleQuestReward(id);

  void setCurrentSenka(double value) {
    if (!value.isFinite || _disposed) return;
    final normalized = value < 0 ? 0.0 : value;
    if (_state.calculatorCurrentSenka == normalized) return;
    final next = _state.copyWith(
      calculatorCurrentSenka: normalized,
      calculatorLocalSenkaAtSet: _state.monthRecorded,
    );
    _replace(rebaseSenkaDailyTarget(_state, next, _now()));
  }

  void setTargetSenka(double value) {
    if (!value.isFinite || _disposed) return;
    final normalized = value < 0 ? 0.0 : value;
    if (_state.targetSenka == normalized) return;
    _replace(_state.copyWith(targetSenka: normalized));
  }

  Future<bool> resetBaseSenka() => setBaseSenka(0);

  Future<bool> setBaseSenka(double value) async {
    if (!value.isFinite || value < 0 || _disposed) return false;
    final normalized = (value * 100).roundToDouble() / 100;
    final current = migrateSenkaStateToMonth(
      _state,
      currentSenkaMonthKey(_now()),
    );
    final days = <String, SenkaDayRecord>{
      for (final entry in current.days.entries)
        entry.key: SenkaDayRecord(eo: entry.value.eo, quest: entry.value.quest),
    };
    final updated = current.copyWith(
      days: days,
      unattributedExperienceSenka: normalized,
    );
    final rebased = _rebaseLatestPlayerRanking(updated);
    return _replaceForSettings(rebaseSenkaDailyTarget(_state, rebased, _now()));
  }

  void refreshForCurrentTime() {
    if (_disposed) return;
    final now = _now();
    final monthMigrated = migrateSenkaStateToMonth(
      _state,
      currentSenkaMonthKey(now),
    );
    final rewardMigrated = migrateSenkaRewardCycles(monthMigrated, now);
    final next = identical(rewardMigrated, monthMigrated)
        ? ensureSenkaDailyTarget(monthMigrated, now)
        : rebaseSenkaDailyTarget(monthMigrated, rewardMigrated, now);
    if (identical(next, _state)) {
      notifyListeners();
      return;
    }
    _replace(next);
  }

  void toggleSortieFavorite(String mapKey) {
    if (!_canToggleSortieMap(mapKey)) return;
    final values = Set<String>.of(_state.favoriteSortieMapKeys);
    values.contains(mapKey) ? values.remove(mapKey) : values.add(mapKey);
    _replace(_state.copyWith(favoriteSortieMapKeys: values));
  }

  void toggleSortieHidden(String mapKey) {
    if (!_canToggleSortieMap(mapKey)) return;
    final values = Set<String>.of(_state.hiddenSortieMapKeys);
    values.contains(mapKey) ? values.remove(mapKey) : values.add(mapKey);
    _replace(_state.copyWith(hiddenSortieMapKeys: values));
  }

  bool _canToggleSortieMap(String mapKey) =>
      !_disposed &&
      RegExp(r'^[1-9]\d*-[1-9]\d*$').hasMatch(mapKey) &&
      _state.sortieStats.containsKey(mapKey);

  void _replace(SenkaState next) {
    if (_accountSession != null && !_accountSession.current.isKnown) return;
    _state = next;
    final revision = ++_revision;
    _rememberAccountSave(next, revision);
    notifyListeners();
    _enqueue(() => _saveIfCurrent(next, revision));
  }

  Future<bool> _replaceForSettings(SenkaState next) {
    if (_disposed ||
        (_accountSession != null && !_accountSession.current.isKnown)) {
      return Future<bool>.value(false);
    }
    _state = next;
    final revision = ++_revision;
    _rememberAccountSave(next, revision);
    notifyListeners();
    final result = Completer<bool>();
    _enqueue(() async {
      if (_disposed) {
        if (!result.isCompleted) result.complete(false);
        return;
      }
      try {
        await _saveIfCurrent(next, revision);
        if (!result.isCompleted) result.complete(true);
      } catch (_) {
        if (!result.isCompleted) result.complete(false);
      }
    });
    return result.future;
  }

  void _enqueue(Future<void> Function() operation) {
    final scheduled = _queue.then<void>(
      (_) => operation(),
      onError: (Object _, StackTrace _) => operation(),
    );
    _queue = scheduled.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        debugPrint('Senka persistence failed: $error');
      },
    );
  }

  void _rememberAccountSave(SenkaState snapshot, int revision) {
    if (_accountSession == null || snapshot.memberId <= 0) return;
    _pendingAccountSaves[snapshot.memberId] = (
      revision: revision,
      state: snapshot,
    );
  }

  Future<void> _saveIfCurrent(SenkaState snapshot, int revision) async {
    // A switch changes the UI revision, but cannot revoke a save already
    // accepted for another owner. Only a newer save for that owner supersedes it.
    final latest = _accountSession == null
        ? _revision
        : _pendingAccountSaves[snapshot.memberId]?.revision;
    if (revision != latest) return;
    try {
      await store.save(snapshot);
      if (_pendingAccountSaves[snapshot.memberId]?.revision == revision) {
        _pendingAccountSaves.remove(snapshot.memberId);
      }
      if (revision == _revision && _persistenceError != null) {
        _persistenceError = null;
        if (!_disposed) notifyListeners();
      }
    } catch (error, stackTrace) {
      if (revision == _revision) {
        _persistenceError = error;
        if (!_disposed) notifyListeners();
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _accountSession?.removeListener(_onAccountChanged);
    _captureNotifications.dispose();
    super.dispose();
  }
}

SenkaState _rebaseLatestPlayerRanking(SenkaState state) {
  final playerHistory = state.rankingHistory['player'];
  if (playerHistory == null || playerHistory.isEmpty) {
    return state.copyWith(calculatorLocalSenkaAtSet: state.monthRecorded);
  }
  final latest = playerHistory.last;
  final rankingHistory = <String, List<SenkaRankingSnapshot>>{
    for (final entry in state.rankingHistory.entries)
      entry.key: List<SenkaRankingSnapshot>.of(entry.value),
  };
  rankingHistory['player'] = <SenkaRankingSnapshot>[
    ...playerHistory.take(playerHistory.length - 1),
    SenkaRankingSnapshot(
      rank: latest.rank,
      senka: latest.senka,
      capturedAt: latest.capturedAt,
      localSenkaAtCapture: state.monthRecorded,
    ),
  ];
  return state.copyWith(
    rankingHistory: rankingHistory,
    calculatorLocalSenkaAtSet: state.monthRecorded,
  );
}
