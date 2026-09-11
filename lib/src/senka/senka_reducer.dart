import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import '../game_state/game_api_decoder.dart';
import 'senka_calculation.dart';
import 'senka_catalog.dart';
import 'senka_state.dart';

class SenkaReducer {
  const SenkaReducer();

  static const _rankingPath = GameCapturePathCatalog.senkaRanking;
  static const _magicLeft = [36, 31, 33, 97, 64, 54, 52, 78, 40, 85];
  static const _magicRight = [
    8931,
    1201,
    1156,
    5061,
    4569,
    4732,
    3779,
    4568,
    5695,
    4619,
    4912,
    5669,
    6586,
  ];
  static const _experiencePaths = GameCapturePathCatalog.senkaExperience;

  SenkaState reduce(SenkaState state, CapturedApiEvent event) {
    final monthKey = currentSenkaMonthKey(event.capturedAt);
    final stateMonth = parseSenkaMonthKey(state.monthKey);
    final eventMonth = parseSenkaMonthKey(monthKey)!;
    if (stateMonth != null &&
        (eventMonth.year * 12 + eventMonth.month) <
            (stateMonth.year * 12 + stateMonth.month)) {
      return state;
    }
    var current = migrateSenkaExperienceTracking(
      migrateSenkaStateToMonth(state, monthKey),
    );
    final rewardMigrated = migrateSenkaRewardCycles(current, event.capturedAt);
    current = identical(rewardMigrated, current)
        ? ensureSenkaDailyTarget(current, event.capturedAt)
        : rebaseSenkaDailyTarget(current, rewardMigrated, event.capturedAt);
    if (_isSortieLifecyclePath(event.path) &&
        current.latestSortieEventAt != null &&
        event.capturedAt.isBefore(current.latestSortieEventAt!)) {
      return current;
    }
    if (!supportsPath(event.path)) return current;
    if (event.sourceOrigin.isNotEmpty) {
      current = current.copyWith(serverOrigin: event.sourceOrigin);
    }

    final data = GameApiDecoder.decodeEventData(event);
    if (data is! Map) {
      if (_sortieResultPaths.contains(event.path)) {
        final active = current.activeSortie;
        return current.copyWith(
          clearActiveSortie: active?.bossArrived == true,
          latestSortieEventAt: event.capturedAt,
          updatedAt: event.capturedAt,
        );
      }
      if (_clearsActiveSortie(event.path) || event.path == _sortieStartPath) {
        return current.copyWith(
          clearActiveSortie: true,
          latestSortieEventAt: event.capturedAt,
          updatedAt: event.capturedAt,
        );
      }
      if (event.path == '/kcsapi/api_req_map/next') {
        return current.copyWith(
          latestSortieEventAt: event.capturedAt,
          updatedAt: event.capturedAt,
        );
      }
      return current;
    }
    final map = data.cast<Object?, Object?>();

    current = _identity(current, event.path, map);
    if (_experiencePaths.contains(event.path)) {
      current = _experience(current, event.path, map, event.capturedAt);
    }
    if (event.path == '/kcsapi/api_get_member/mapinfo') {
      current = _mapInfo(current, map, event.capturedAt);
    } else if (event.path == '/kcsapi/api_req_quest/clearitemget') {
      current = _questClear(current, event, event.capturedAt);
    } else if (event.path == _rankingPath) {
      current = _ranking(current, map, event.capturedAt);
    }
    current = _sortie(current, event.path, map, event.capturedAt);
    return current.copyWith(updatedAt: event.capturedAt);
  }

  bool supportsPath(String path) => GameCapturePathCatalog.senka.contains(path);

  SenkaState _identity(
    SenkaState state,
    String path,
    Map<Object?, Object?> data,
  ) {
    Map<Object?, Object?>? basic;
    if (path == '/kcsapi/api_port/port') {
      basic = _map(data['api_basic']);
    } else if (path == '/kcsapi/api_get_member/basic') {
      basic = data;
    }
    if (basic == null) return state;
    return state.copyWith(
      memberId: _int(basic['api_member_id'], state.memberId),
      nickname: '${basic['api_nickname'] ?? state.nickname}',
    );
  }

  SenkaState _sortie(
    SenkaState state,
    String path,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    if (_clearsActiveSortie(path)) {
      return state.copyWith(
        clearActiveSortie: true,
        latestSortieEventAt: capturedAt,
      );
    }
    if (path == _sortieStartPath) {
      return _startSortie(state, data, capturedAt);
    }
    if (path == '/kcsapi/api_req_map/next') {
      return _nextNode(state, data, capturedAt);
    }
    if (_sortieResultPaths.contains(path)) {
      return _sortieResult(state, data, capturedAt);
    }
    return state;
  }

  SenkaState _startSortie(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final areaId = _positiveInt(data['api_maparea_id']);
    final mapNo = _positiveInt(data['api_mapinfo_no']);
    if (areaId == null || mapNo == null) {
      return state.copyWith(
        clearActiveSortie: true,
        latestSortieEventAt: capturedAt,
      );
    }
    final nodeNo = _positiveInt(data['api_no']);
    final bossCellNo = _positiveInt(data['api_bosscell_no']);
    final arrived = _isBossNode(
      data,
      nodeNo: nodeNo,
      bossCellNos: [bossCellNo],
    );
    final mapKey = senkaMapKey(areaId, mapNo);
    if (state.lastSortieStartAt == capturedAt.toUtc() &&
        state.lastSortieStartMapKey == mapKey) {
      return state.copyWith(latestSortieEventAt: capturedAt);
    }
    final active = SenkaActiveSortie(
      areaId: areaId,
      mapNo: mapNo,
      bossCellNo: bossCellNo,
      bossArrived: arrived,
      startedAt: capturedAt,
      lastEventAt: capturedAt,
    );
    final stats = _updatedSortieStats(
      state,
      active,
      sorties: 1,
      bossArrivals: arrived ? 1 : 0,
    );
    final dailyStats = _updatedDailySortieStats(
      state,
      active,
      sorties: 1,
      bossArrivals: arrived ? 1 : 0,
    );
    return state.copyWith(
      sortieStats: stats,
      sortieStatsByDay: dailyStats,
      activeSortie: active,
      latestSortieEventAt: capturedAt,
      lastSortieStartAt: capturedAt,
      lastSortieStartMapKey: mapKey,
    );
  }

  SenkaState _nextNode(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final active = state.activeSortie;
    if (active == null) {
      return state.copyWith(latestSortieEventAt: capturedAt);
    }
    final nodeNo = _positiveInt(data['api_no']);
    final responseBossCellNo = _positiveInt(data['api_bosscell_no']);
    final arrived = _isBossNode(
      data,
      nodeNo: nodeNo,
      bossCellNos: [active.bossCellNo, responseBossCellNo],
    );
    final nextActive = active.copyWith(
      bossCellNo: responseBossCellNo,
      lastEventAt: capturedAt,
    );
    if (!arrived || active.bossArrived) {
      return state.copyWith(
        activeSortie: nextActive,
        latestSortieEventAt: capturedAt,
      );
    }
    return state.copyWith(
      sortieStats: _updatedSortieStats(state, active, bossArrivals: 1),
      sortieStatsByDay: _updatedDailySortieStats(
        state,
        active,
        bossArrivals: 1,
      ),
      activeSortie: nextActive.copyWith(bossArrived: true),
      latestSortieEventAt: capturedAt,
    );
  }

  SenkaState _sortieResult(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final active = state.activeSortie;
    if (active == null) {
      return state.copyWith(latestSortieEventAt: capturedAt);
    }
    if (!active.bossArrived) {
      return state.copyWith(
        activeSortie: active.copyWith(lastEventAt: capturedAt),
        latestSortieEventAt: capturedAt,
      );
    }
    final rank = '${data['api_win_rank'] ?? ''}'.toUpperCase();
    final stats = switch (rank) {
      'S' || 'SS' => _updatedSortieStats(state, active, sWins: 1),
      'A' => _updatedSortieStats(state, active, aWins: 1),
      _ => state.sortieStats,
    };
    final dailyStats = switch (rank) {
      'S' || 'SS' => _updatedDailySortieStats(state, active, sWins: 1),
      'A' => _updatedDailySortieStats(state, active, aWins: 1),
      _ => state.sortieStatsByDay,
    };
    return state.copyWith(
      sortieStats: stats,
      sortieStatsByDay: dailyStats,
      clearActiveSortie: true,
      latestSortieEventAt: capturedAt,
    );
  }

  Map<String, SenkaSortieStats> _updatedSortieStats(
    SenkaState state,
    SenkaActiveSortie active, {
    int sorties = 0,
    int bossArrivals = 0,
    int sWins = 0,
    int aWins = 0,
  }) {
    final result = Map<String, SenkaSortieStats>.of(state.sortieStats);
    final current =
        result[active.mapKey] ??
        SenkaSortieStats(areaId: active.areaId, mapNo: active.mapNo);
    result[active.mapKey] = current.copyWith(
      sorties: current.sorties + sorties,
      bossArrivals: current.bossArrivals + bossArrivals,
      sWins: current.sWins + sWins,
      aWins: current.aWins + aWins,
    );
    return result;
  }

  Map<String, Map<String, SenkaSortieStats>> _updatedDailySortieStats(
    SenkaState state,
    SenkaActiveSortie active, {
    int sorties = 0,
    int bossArrivals = 0,
    int sWins = 0,
    int aWins = 0,
  }) {
    final day = dateKey(senkaBusinessDate(active.startedAt));
    final result = <String, Map<String, SenkaSortieStats>>{
      for (final entry in state.sortieStatsByDay.entries)
        entry.key: Map<String, SenkaSortieStats>.of(entry.value),
    };
    final currentDay = result[day] ?? <String, SenkaSortieStats>{};
    final current =
        currentDay[active.mapKey] ??
        SenkaSortieStats(areaId: active.areaId, mapNo: active.mapNo);
    final nextSWins = current.sWins + sWins;
    final nextAWins = current.aWins + aWins;
    final countedWins = nextSWins + nextAWins;
    final incrementedBossArrivals = current.bossArrivals + bossArrivals;
    final nextBossArrivals = incrementedBossArrivals < countedWins
        ? countedWins
        : incrementedBossArrivals;
    final incrementedSorties = current.sorties + sorties;
    final nextSorties = incrementedSorties < nextBossArrivals
        ? nextBossArrivals
        : incrementedSorties;
    currentDay[active.mapKey] = current.copyWith(
      sorties: nextSorties,
      bossArrivals: nextBossArrivals,
      sWins: nextSWins,
      aWins: nextAWins,
    );
    result[day] = currentDay;
    return result;
  }

  SenkaState _experience(
    SenkaState state,
    String path,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final experience = switch (path) {
      '/kcsapi/api_port/port' => _int(
        _map(data['api_basic'])?['api_experience'],
      ),
      '/kcsapi/api_get_member/record' => _firstInt(data['api_experience']),
      '/kcsapi/api_get_member/basic' => _int(data['api_experience']),
      _ => _int(data['api_member_exp']),
    };
    if (experience <= 0) return state;
    final previous = state.latestExperience;
    if (previous == null) {
      return state.copyWith(latestExperience: experience);
    }
    if (experience <= previous) return state;
    final gained = (experience - previous) * experienceToSenkaRate;
    return _addDay(
      state.copyWith(latestExperience: experience),
      capturedAt,
      experience: gained,
    );
  }

  SenkaState _mapInfo(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final values = data['api_map_info'];
    if (values is! List) return state;
    final cleared = <int>{};
    final known = <int>{};
    for (final value in values) {
      final map = _map(value);
      if (map == null) continue;
      final id = _int(map['api_id']);
      if (senkaEoById(id) == null) continue;
      known.add(id);
      if (_int(map['api_cleared']) > 0) cleared.add(id);
    }
    if (known.isEmpty) return state;
    final completed = Set<int>.of(state.completedEoIds)
      ..removeAll(known)
      ..addAll(cleared);
    final newlyCleared = cleared.difference(state.completedEoIds);
    final gained = newlyCleared.fold<double>(
      0,
      (sum, id) => sum + (senkaEoById(id)?.senka ?? 0),
    );
    var next = state.copyWith(
      completedEoIds: completed,
      eoTrackingInitialized: true,
    );
    if (gained == 0) return next;
    if (!state.eoTrackingInitialized) {
      next = next.copyWith(
        unattributedEoSenka: state.unattributedEoSenka + gained,
      );
      return _rebaseLocalBaseline(next, gained);
    }
    return _addDay(next, capturedAt, eo: gained);
  }

  SenkaState _questClear(
    SenkaState state,
    CapturedApiEvent event,
    DateTime capturedAt,
  ) {
    final id = _int(event.requestParams['api_quest_id']);
    final quest = senkaQuestById(id);
    if (quest == null) return state;
    final statuses = Map<int, SenkaRewardStatus>.of(state.questStatuses)
      ..[id] = SenkaRewardStatus.completed;
    if (state.recordedQuestIds.contains(id)) {
      return state.copyWith(questStatuses: statuses);
    }
    final recorded = Set<int>.of(state.recordedQuestIds)..add(id);
    return _addDay(
      state.copyWith(questStatuses: statuses, recordedQuestIds: recorded),
      capturedAt,
      quest: quest.senka.toDouble(),
    );
  }

  SenkaState _ranking(
    SenkaState state,
    Map<Object?, Object?> data,
    DateTime capturedAt,
  ) {
    final latest = state.rankingUpdatedAt;
    if (latest != null && !capturedAt.isAfter(latest)) return state;
    final rawList = data['api_list'];
    if (rawList is! List) return state;
    final refreshed = state.copyWith(rankingUpdatedAt: capturedAt);
    if (state.memberId <= 0) return refreshed;
    final rows = rawList.map(_map).whereType<Map<Object?, Object?>>().toList();
    if (rows.isEmpty) return refreshed;
    final inferredMagic = _inferMagic(state, rows);
    final decryptState = inferredMagic == null
        ? refreshed
        : refreshed.copyWith(magic: inferredMagic);
    final history = <String, List<SenkaRankingSnapshot>>{
      for (final entry in state.rankingHistory.entries)
        entry.key: List<SenkaRankingSnapshot>.of(entry.value),
    };
    final playerRows = state.nickname.isEmpty
        ? const <Map<Object?, Object?>>[]
        : rows
              .where(
                (row) => '${row['api_mtjmdcwtvhdr'] ?? ''}' == state.nickname,
              )
              .toList();
    final playerRow = playerRows.length == 1 ? playerRows.single : null;
    final page = _int(data['api_disp_page']);
    double? playerSenka;
    for (final raw in rows) {
      final rank = _int(raw['api_mxltvkpyuklh']);
      final encrypted = _int(raw['api_wuhnhojjxmke']);
      if (rank <= 0 || encrypted <= 0) continue;
      final senka = _decrypt(decryptState, rank, encrypted);
      String? key;
      if (const {5, 20, 100, 501}.contains(rank) &&
          page == (rank / 10).ceil()) {
        key = '$rank';
      }
      if (identical(raw, playerRow)) {
        key = 'player';
        playerSenka = senka;
      }
      if (key == null) continue;
      final snapshots = history.putIfAbsent(key, () => []);
      snapshots.add(
        SenkaRankingSnapshot(
          rank: rank,
          senka: senka,
          capturedAt: capturedAt,
          localSenkaAtCapture: state.monthRecorded,
        ),
      );
      if (snapshots.length > 2) snapshots.removeAt(0);
    }
    return decryptState.copyWith(
      rankingHistory: history,
      calculatorCurrentSenka: playerSenka,
      calculatorLocalSenkaAtSet: playerSenka == null
          ? null
          : state.monthRecorded,
    );
  }

  double _decrypt(SenkaState state, int rank, int encrypted) {
    final magic = state.magic > 9
        ? state.magic
        : _magicLeft[state.memberId % 10];
    final value = encrypted / _magicRight[rank % 13] / magic - 73 - 18;
    return value > 0 ? value : 0;
  }

  int? _inferMagic(SenkaState state, List<Map<Object?, Object?>> rows) {
    if (rows.length < 2) return null;
    final factors = <int>[];
    for (final row in rows) {
      final rank = _int(row['api_mxltvkpyuklh']);
      final encrypted = _int(row['api_wuhnhojjxmke']);
      if (rank <= 0 || encrypted <= 0) return null;
      final right = _magicRight[rank % 13];
      if (encrypted % right != 0) return null;
      factors.add(encrypted ~/ right);
    }
    var divisor = factors.first;
    for (final factor in factors.skip(1)) {
      divisor = _gcd(divisor, factor);
    }
    final candidates = <int>[
      for (var candidate = 10; candidate <= 99; candidate++)
        if (divisor % candidate == 0) candidate,
    ];
    final preferred = state.magic > 9
        ? state.magic
        : state.memberId > 0
        ? _magicLeft[state.memberId % 10]
        : 0;
    // An incompatible old factor also makes its decoded history unreliable.
    // Match poi's calibration fallback: use the largest two-digit divisor,
    // including composite factors, instead of falling back to the old table.
    if (!candidates.contains(preferred)) {
      return candidates.isEmpty ? null : candidates.last;
    }
    final historicalCandidate = _magicFromHistory(state, rows, candidates);
    if (historicalCandidate != null) return historicalCandidate;
    if (preferred >= 10 && preferred <= 99 && divisor % preferred == 0) {
      return preferred;
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  int? _magicFromHistory(
    SenkaState state,
    List<Map<Object?, Object?>> rows,
    List<int> candidates,
  ) {
    if (candidates.length < 2) return null;
    final scores = <(int, double, int)>[];
    for (final candidate in candidates) {
      var score = 0.0;
      var matches = 0;
      for (final row in rows) {
        final rank = _int(row['api_mxltvkpyuklh']);
        final encrypted = _int(row['api_wuhnhojjxmke']);
        final nickname = '${row['api_mtjmdcwtvhdr'] ?? ''}';
        final anchorHistory = state.rankingHistory['$rank'];
        final playerHistory = nickname == state.nickname
            ? state.rankingHistory['player']
            : null;
        final history = anchorHistory?.isNotEmpty == true
            ? anchorHistory
            : playerHistory;
        if (rank <= 0 || encrypted <= 0 || history?.isNotEmpty != true) {
          continue;
        }
        final decoded =
            encrypted / _magicRight[rank % 13] / candidate - 73 - 18;
        score += (decoded - history!.last.senka).abs();
        matches++;
      }
      if (matches > 0) scores.add((candidate, score, matches));
    }
    if (scores.length < 2) return null;
    scores.sort((left, right) {
      final leftAverage = left.$2 / left.$3;
      final rightAverage = right.$2 / right.$3;
      return leftAverage.compareTo(rightAverage);
    });
    final bestAverage = scores.first.$2 / scores.first.$3;
    final nextAverage = scores[1].$2 / scores[1].$3;
    return nextAverage - bestAverage > 0.000001 ? scores.first.$1 : null;
  }

  SenkaState _rebaseLocalBaseline(SenkaState state, double gained) {
    final playerHistory = state.rankingHistory['player'];
    if (playerHistory == null || playerHistory.isEmpty) {
      return state.copyWith(
        calculatorLocalSenkaAtSet: state.calculatorCurrentSenka > 0
            ? state.monthRecorded
            : state.calculatorLocalSenkaAtSet,
      );
    }
    final history = <String, List<SenkaRankingSnapshot>>{
      for (final entry in state.rankingHistory.entries)
        entry.key: List<SenkaRankingSnapshot>.of(entry.value),
    };
    final latest = playerHistory.last;
    history['player'] = <SenkaRankingSnapshot>[
      ...playerHistory.take(playerHistory.length - 1),
      SenkaRankingSnapshot(
        rank: latest.rank,
        senka: latest.senka,
        capturedAt: latest.capturedAt,
        localSenkaAtCapture: latest.localSenkaAtCapture + gained,
      ),
    ];
    return state.copyWith(
      rankingHistory: history,
      calculatorLocalSenkaAtSet:
          (state.calculatorLocalSenkaAtSet ?? latest.localSenkaAtCapture) +
          gained,
    );
  }

  SenkaState _addDay(
    SenkaState state,
    DateTime capturedAt, {
    double experience = 0,
    double eo = 0,
    double quest = 0,
  }) {
    final businessDate = senkaBusinessDate(capturedAt);
    final key = dateKey(businessDate);
    final days = Map<String, SenkaDayRecord>.of(state.days);
    days[key] = (days[key] ?? const SenkaDayRecord()).add(
      experience: experience,
      eo: eo,
      quest: quest,
    );
    return state.copyWith(days: days);
  }
}

const _sortieStartPath = '/kcsapi/api_req_map/start';
const _sortieResultPaths = <String>{
  '/kcsapi/api_req_sortie/battleresult',
  '/kcsapi/api_req_combined_battle/battleresult',
};

bool _clearsActiveSortie(String path) =>
    path == '/kcsapi/api_port/port' ||
    path == '/kcsapi/api_req_sortie/goback_port' ||
    path == '/kcsapi/api_req_combined_battle/goback_port';

bool _isSortieLifecyclePath(String path) =>
    path == _sortieStartPath ||
    path == '/kcsapi/api_req_map/next' ||
    _sortieResultPaths.contains(path) ||
    _clearsActiveSortie(path);

Map<Object?, Object?>? _map(Object? value) =>
    value is Map ? value.cast<Object?, Object?>() : null;

int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

int _firstInt(Object? value) =>
    value is List && value.isNotEmpty ? _int(value.first) : _int(value);

int? _positiveInt(Object? value) {
  if (value is! num || !value.isFinite) return null;
  final result = value.toInt();
  return result > 0 && value == result ? result : null;
}

bool _isBossNode(
  Map<Object?, Object?> data, {
  required int? nodeNo,
  required Iterable<int?> bossCellNos,
}) =>
    _int(data['api_event_id']) == 5 ||
    (nodeNo != null && bossCellNos.any((bossCellNo) => nodeNo == bossCellNo));

int _gcd(int left, int right) => right == 0 ? left : _gcd(right, left % right);
