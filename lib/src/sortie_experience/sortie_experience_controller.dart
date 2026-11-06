import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_session.dart';
import '../bridge/capture_event_sequence_gate.dart';
import '../bridge/captured_api_event.dart';
import '../capture/game_capture_path_catalog.dart';
import '../game_state/game_api_decoder.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../game_state/game_state.dart';
import '../logbook/logbook_experience_record.dart';
import '../toolbox/exp_calc/ship_exp_table.dart';

final class SortieExperienceShip {
  const SortieExperienceShip({
    required this.ownedShipId,
    required this.masterShipId,
    required this.name,
    required this.fleetId,
    required this.position,
    this.experience = 0,
    this.retreated = false,
  });

  final int ownedShipId;
  final int masterShipId;
  final String name;
  final int fleetId;
  final int position;
  final int experience;
  final bool retreated;

  SortieExperienceShip _with({int? experience, bool? retreated}) =>
      SortieExperienceShip(
        ownedShipId: ownedShipId,
        masterShipId: masterShipId,
        name: name,
        fleetId: fleetId,
        position: position,
        experience: experience ?? this.experience,
        retreated: retreated ?? this.retreated,
      );

  Map<String, Object?> _toJson() => {
    'ownedShipId': ownedShipId,
    'masterShipId': masterShipId,
    'name': name,
    'fleetId': fleetId,
    'position': position,
    'experience': experience,
    'retreated': retreated,
  };

  factory SortieExperienceShip._fromJson(Object? value) {
    final json = _requireMap(value);
    if (json['name'] is! String || json['retreated'] is! bool) {
      throw const FormatException('Invalid sortie experience ship');
    }
    return SortieExperienceShip(
      ownedShipId: _storedInt(json['ownedShipId'], min: 1),
      masterShipId: _storedInt(json['masterShipId']),
      name: json['name'] as String,
      fleetId: _storedInt(json['fleetId'], min: 1),
      position: _storedInt(json['position']),
      experience: _storedInt(json['experience']),
      retreated: json['retreated'] as bool,
    );
  }
}

final class SortieExperienceSnapshot {
  const SortieExperienceSnapshot({
    required this.mapAreaId,
    required this.mapInfoNo,
    required this.deckId,
    required this.battles,
    required this.ships,
    this.incomplete = false,
    this.isPractice = false,
    this.unverifiedShipIds = const {},
  });

  final int mapAreaId;
  final int mapInfoNo;
  final int deckId;
  final int battles;
  final List<SortieExperienceShip> ships;
  final bool incomplete;
  final bool isPractice;
  final Set<int> unverifiedShipIds;

  int? confirmedExperience(SortieExperienceShip ship) =>
      unverifiedShipIds.contains(ship.ownedShipId) ? null : ship.experience;

  Map<String, Object?> _toJson() => {
    'mapAreaId': mapAreaId,
    'mapInfoNo': mapInfoNo,
    'deckId': deckId,
    'battles': battles,
    'ships': ships.map((ship) => ship._toJson()).toList(),
    'incomplete': incomplete,
    if (isPractice) 'isPractice': true,
    if (unverifiedShipIds.isNotEmpty)
      'unverifiedShipIds': unverifiedShipIds.toList(),
  };

  factory SortieExperienceSnapshot._fromJson(Object? value) {
    final json = _requireMap(value);
    final practice = json['isPractice'] ?? false;
    if (json['incomplete'] is! bool || practice is! bool) {
      throw const FormatException('Invalid sortie experience summary');
    }
    final mapAreaId = _storedInt(json['mapAreaId'], min: practice ? 0 : 1);
    final mapInfoNo = _storedInt(json['mapInfoNo'], min: practice ? 0 : 1);
    final deckId = _storedInt(json['deckId'], min: practice ? 1 : 0);
    final battles = _storedInt(json['battles']);
    if (practice && (mapAreaId != 0 || mapInfoNo != 0 || battles != 1)) {
      throw const FormatException('Invalid practice experience summary');
    }
    final ships = _storedShips(json['ships']);
    final unverified = json['unverifiedShipIds'] ?? const [];
    if (unverified is! List ||
        unverified.any((id) => id is! int || !ships.containsKey(id))) {
      throw const FormatException('Invalid unverified experience ships');
    }
    return SortieExperienceSnapshot(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      deckId: deckId,
      battles: battles,
      ships: List.unmodifiable(ships.values),
      incomplete: json['incomplete'] as bool,
      isPractice: practice,
      unverifiedShipIds: Set.unmodifiable(unverified.cast<int>()),
    );
  }
}

abstract interface class SortieExperienceStore {
  Future<String?> load(AccountScope account);
  Future<void> save(AccountScope account, String value);
}

final class SharedPreferencesSortieExperienceStore
    implements SortieExperienceStore {
  const SharedPreferencesSortieExperienceStore();

  static const _key = 'sortieExperience.v1';

  @override
  Future<String?> load(AccountScope account) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(account.key(_key));
  }

  @override
  Future<void> save(AccountScope account, String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(account.key(_key), value)) {
      await preferences.reload();
      throw StateError('Could not save sortie experience');
    }
  }
}

typedef LogbookExperienceWriter =
    Future<void> Function(AccountScope scope, LogbookExperienceRecord record);

final class SortieExperienceController extends ChangeNotifier
    implements GameApiEventConsumer, GameApiContinuityGuard {
  SortieExperienceController({
    required this._accountSession,
    required this._gameState,
    this._gameStateChanges,
    SortieExperienceStore? store,
    this._recordExperience,
  }) : _store = store ?? const SharedPreferencesSortieExperienceStore() {
    _accountSession.addListener(_onAccountChanged);
    _gameStateChanges?.addListener(_onGameStateChanged);
    _onAccountChanged();
  }

  static const _startPath = '/kcsapi/api_req_map/start';
  static const _hiddenTotalShipIdsKey =
      'sortieExperience.hiddenTotalShipIds.v1';
  static const _nextPath = '/kcsapi/api_req_map/next';
  static const _portPath = '/kcsapi/api_port/port';
  static const _shipRosterPaths = {
    '/kcsapi/api_get_member/ship2',
    '/kcsapi/api_get_member/ship3',
    '/kcsapi/api_get_member/ship_deck',
  };
  static const _practiceDayPath = '/kcsapi/api_req_practice/battle';
  static const _practiceNightPath = '/kcsapi/api_req_practice/midnight_battle';
  static const _practiceResultPath = '/kcsapi/api_req_practice/battle_result';
  static const _practicePaths = {
    _practiceDayPath,
    _practiceNightPath,
    _practiceResultPath,
  };
  static const _resultPaths = {
    '/kcsapi/api_req_sortie/battleresult',
    '/kcsapi/api_req_combined_battle/battleresult',
  };

  final AccountSession _accountSession;
  final GameState Function() _gameState;
  final Listenable? _gameStateChanges;
  final SortieExperienceStore _store;
  final LogbookExperienceWriter? _recordExperience;
  final _sequenceGate = CaptureEventSequenceGate();
  final _unsaved = <int, String>{};
  final _pendingLogRecords = <int, Map<String, LogbookExperienceRecord>>{};
  final _queuedLogFlushes = <AccountScope>{};
  final _logQueues = <int, Future<void>>{};
  final _totalShipVisibilityQueues = <int, Future<void>>{};
  final _projectedProgress =
      <int, ({_ShipProgress baseline, _ShipProgress current})>{};
  Map<int, OwnedShip>? _observedShips;
  Future<void> _queue = Future<void>.value();
  Future<void>? _totalShipVisibilityLoad;
  AccountScope? _scope;
  DateTime? _latestCaptureAt;
  _Archive _archive = const _Archive();
  Set<int> _hiddenTotalShipIds = const {};
  _ActiveSortie? _active;
  _PracticeBattle? _practice;
  int _captureGeneration = 0;
  bool _disposed = false;
  bool _isReady = false;
  bool _loadedArchive = false;
  bool _storageUnavailable = false;
  bool _isTotalShipVisibilityReady = false;

  SortieExperienceSnapshot? get sortie =>
      _active?.snapshot ?? _practice?.snapshot() ?? _archive.last;
  bool get isActive => _active != null || _practice != null;
  AccountScope get accountScope => _accountSession.current;
  int get memberId => _scope?.memberId ?? 0;
  int get totalSorties => _archive.totalSorties;

  ({int? level, int? nextExperience}) progressFor(int ownedShipId) {
    final progress = _progressFor(_gameState(), ownedShipId);
    if (progress == null || progress.level <= 0) {
      return (level: null, nextExperience: null);
    }
    return (level: progress.level, nextExperience: progress.nextExperience);
  }

  _ShipProgress? _progressFor(GameState state, int ownedShipId) {
    final observed = _observedProgress(state, ownedShipId);
    final projected = _projectedProgress[ownedShipId];
    return projected != null && projected.baseline == observed
        ? projected.current
        : observed;
  }

  _ShipProgress? _observedProgress(GameState state, int ownedShipId) {
    if (memberId == 0 || state.memberId != memberId) return null;
    return _ShipProgress.fromShip(state.ships[ownedShipId]);
  }

  void _onGameStateChanged() {
    final state = _gameState();
    if (identical(_observedShips, state.ships)) return;
    _observedShips = state.ships;
    // A fresh roster can already include the rewards that we projected.
    _projectedProgress.removeWhere(
      (id, projection) => _observedProgress(state, id) != projection.baseline,
    );
    notifyListeners();
  }

  List<SortieExperienceShip> get totals {
    final ships = _archive.totals.values.toList();
    ships.sort((a, b) {
      final byExp = b.experience.compareTo(a.experience);
      return byExp == 0 ? a.ownedShipId.compareTo(b.ownedShipId) : byExp;
    });
    return List.unmodifiable(ships);
  }

  bool get trackingEnabled => _archive.tracking;
  bool get isReady => _isReady;
  bool get storageUnavailable => _storageUnavailable;
  Set<int> get hiddenTotalShipIds => _hiddenTotalShipIds;
  bool get isTotalShipVisibilityReady => _isTotalShipVisibilityReady;

  Future<void> initialize() async {
    await idle;
    await _totalShipVisibilityLoad;
  }

  Future<void> setHiddenTotalShipIds(
    Set<int> hiddenIds, {
    required AccountScope expectedAccount,
  }) {
    if (!_isCurrent(expectedAccount) || !_isTotalShipVisibilityReady) {
      return Future<void>.value();
    }
    final hidden = {
      for (final id in hiddenIds)
        if (_hiddenTotalShipIds.contains(id) || _archive.totals.containsKey(id))
          id,
    };
    if (setEquals(hidden, _hiddenTotalShipIds)) {
      return Future<void>.value();
    }
    _hiddenTotalShipIds = Set.unmodifiable(hidden);
    final storedIds = (hidden.toList()..sort()).map((id) => '$id').toList();
    final save = _enqueueTotalShipVisibility(expectedAccount, () async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setStringList(
        expectedAccount.key(_hiddenTotalShipIdsKey),
        storedIds,
      )) {
        throw StateError('Could not save total ship visibility');
      }
    });
    notifyListeners();
    return save;
  }

  Future<void> setTrackingEnabled(bool value, {AccountScope? expectedAccount}) {
    final scope = expectedAccount ?? accountScope;
    return _enqueue(() async {
      if (!_isCurrent(scope) || !_loadedArchive) return;
      if (_archive.tracking != value) {
        _archive = _archive._with(tracking: value);
        notifyListeners();
      }
      await _persist(scope);
    });
  }

  Future<void> clearTotal({AccountScope? expectedAccount}) {
    final scope = expectedAccount ?? accountScope;
    return _enqueue(() async {
      if (!_isCurrent(scope) || !_loadedArchive) return;
      _active?.pending.clear();
      _archive = _archive._with(totalSorties: 0, totals: const {});
      notifyListeners();
      await _persist(scope);
    });
  }

  @override
  Future<void> get idle async {
    while (true) {
      final pending = _queue;
      await pending;
      await Future.wait(_logQueues.values);
      if (identical(pending, _queue) && _logQueues.isEmpty) {
        return;
      }
    }
  }

  @override
  bool supportsPath(String path) =>
      GameCapturePathCatalog.battleMap.contains(path) ||
      _resultPaths.contains(path) ||
      _isSortiePhase(path) ||
      GameCapturePathCatalog.battleRetreat.contains(path) ||
      path == _portPath ||
      _shipRosterPaths.contains(path) ||
      _practicePaths.contains(path);

  static bool _isSortiePhase(String path) =>
      !path.startsWith('/kcsapi/api_req_practice/') &&
      GameCapturePathCatalog.battlePhases.contains(path);

  @override
  void accept(CapturedApiEvent event) {
    final scope = _accountSession.current;
    if (_disposed || !scope.isKnown || !supportsPath(event.path)) return;
    // The core pipeline settles earlier packets before dispatch. Keep that
    // exact pre-event roster even if archive I/O delays this consumer.
    final gameState = _gameState();
    final generation = _captureGeneration;
    unawaited(
      _enqueue(() async {
        if (!_isCurrent(scope) || generation != _captureGeneration) return;
        final Object? payload;
        try {
          payload = GameApiDecoder.decodeEventData(
            event,
            allowMissingData: true,
          );
        } on GameApiParseException {
          return;
        }
        if (_latestCaptureAt?.isAfter(event.capturedAt) == true ||
            !_sequenceGate.accept(event)) {
          return;
        }
        _latestCaptureAt = event.capturedAt;
        final data = _map(payload);

        switch (event.path) {
          case _startPath:
          case _nextPath:
            _practice = null;
            _move(event, data ?? const {}, gameState, scope);
          case _portPath:
            final basic = _map(data?['api_basic']);
            if (_wireInt(basic?['api_member_id']) == scope.memberId) {
              _reconcileProgress(data?['api_ship']);
              _discardPractice();
              await _returnToPort(scope, event);
            }
          case final path when _shipRosterPaths.contains(path):
            _reconcileProgress(
              payload is List
                  ? payload
                  : data?['api_ship_data'] ??
                        data?['api_ship'] ??
                        data?['api_ship_data_list'],
            );
          case _practiceDayPath:
            _beginPractice(event, data ?? const {}, gameState, scope);
          case _practiceNightPath:
            final deck = _practiceDeck(event, data ?? const {});
            if (deck != null && deck != _practice?.deckId) _discardPractice();
          case _practiceResultPath:
            await _settlePractice(event, data ?? const {}, scope, gameState);
          case '/kcsapi/api_req_sortie/goback_port':
          case '/kcsapi/api_req_combined_battle/goback_port':
            _retreat(gameState, scope);
          default:
            if (data == null) return;
            if (_resultPaths.contains(event.path)) {
              _settle(data, gameState);
            } else {
              _observeBattle(event, data, gameState, scope);
            }
        }
        _scheduleLogFlush(scope);
      }),
    );
  }

  @override
  bool allowsCaptureEvent(CapturedApiEvent event) => true;

  @override
  void interruptCaptureContinuity() {
    if (_disposed) return;
    _captureGeneration++;
    _discardPractice();
    if (_active case final active?) {
      active.loseNavigation();
      notifyListeners();
    }
  }

  Future<void> _enqueue(Future<void> Function() work) {
    final task = _queue.then((_) => work());
    _queue = task.catchError((Object error) {
      debugPrint('Sortie experience event failed (${error.runtimeType})');
    });
    return task;
  }

  bool _isCurrent(AccountScope scope) =>
      !_disposed && scope.isKnown && _accountSession.isCurrent(scope);

  // Display preferences never hold up capture and are ordered only within
  // their owning account, including reads after a rapid switch back.
  Future<void> _enqueueTotalShipVisibility(
    AccountScope scope,
    Future<void> Function() work,
  ) {
    final memberId = scope.memberId;
    final previous =
        _totalShipVisibilityQueues[memberId] ?? Future<void>.value();
    final task = previous.then((_) => work()).catchError((Object error) {
      debugPrint('Total ship visibility save failed (${error.runtimeType})');
    });
    _totalShipVisibilityQueues[memberId] = task;
    unawaited(
      task.then((_) {
        if (identical(_totalShipVisibilityQueues[memberId], task)) {
          _totalShipVisibilityQueues.remove(memberId);
        }
      }),
    );
    return task;
  }

  Future<void> _loadTotalShipVisibility(AccountScope scope) async {
    if (!_isCurrent(scope)) return;
    Set<int> hidden = const {};
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedIds =
          preferences.getStringList(scope.key(_hiddenTotalShipIdsKey)) ??
          const [];
      hidden = storedIds
          .map(int.tryParse)
          .whereType<int>()
          .where((id) => id > 0)
          .toSet();
    } catch (error) {
      debugPrint('Total ship visibility load failed (${error.runtimeType})');
    }
    if (!_isCurrent(scope)) return;
    _hiddenTotalShipIds = Set.unmodifiable(hidden);
    _isTotalShipVisibilityReady = true;
    notifyListeners();
  }

  void _onAccountChanged() {
    final scope = _accountSession.current;
    if (identical(scope, _scope)) return;
    _scope = scope;
    _sequenceGate.clear();
    _latestCaptureAt = null;
    _active = null;
    _practice = null;
    _projectedProgress.clear();
    _observedShips = null;
    _archive = const _Archive();
    _hiddenTotalShipIds = const {};
    _isTotalShipVisibilityReady = false;
    _totalShipVisibilityLoad = scope.isKnown
        ? _enqueueTotalShipVisibility(
            scope,
            () => _loadTotalShipVisibility(scope),
          )
        : null;
    _isReady = false;
    _loadedArchive = false;
    _storageUnavailable = false;
    if (scope.isKnown) {
      unawaited(
        _enqueue(() async {
          await _load(scope);
          _scheduleLogFlush(scope);
        }),
      );
    }
    notifyListeners();
  }

  Future<void> _load(AccountScope scope) async {
    if (!_isCurrent(scope)) return;
    try {
      final unsaved = _unsaved[scope.memberId];
      final raw = unsaved ?? await _store.load(scope);
      if (!_isCurrent(scope)) return;
      if (raw != null) {
        final decoded = _Archive.decode(raw, scope.memberId);
        _archive = decoded.archive;
        for (final record in decoded.pendingLogRecords) {
          _queueLogRecord(scope, record);
        }
      }
      _loadedArchive = true;
      if (unsaved != null) await _persist(scope);
    } catch (error) {
      if (!_isCurrent(scope)) return;
      _storageUnavailable = true;
      debugPrint('Sortie experience load failed (${error.runtimeType})');
    }
    if (!_isCurrent(scope)) return;
    _isReady = true;
    notifyListeners();
  }

  Future<void> _persist(AccountScope scope) async {
    if (!_loadedArchive) return;
    final raw = _archive.encode(
      scope.memberId,
      _pendingLogRecords[scope.memberId]?.values ?? const [],
    );
    _unsaved[scope.memberId] = raw;
    var failed = false;
    try {
      await _store.save(scope, raw);
      _unsaved.remove(scope.memberId);
    } catch (error) {
      failed = true;
      debugPrint('Sortie experience save failed (${error.runtimeType})');
    }
    if (_isCurrent(scope) && _storageUnavailable != failed) {
      _storageUnavailable = failed;
      notifyListeners();
    }
  }

  void _queueLogRecord(AccountScope scope, LogbookExperienceRecord record) {
    _pendingLogRecords.putIfAbsent(scope.memberId, () => {})[record.eventKey] =
        record;
  }

  void _scheduleLogFlush(AccountScope scope) {
    if (_recordExperience == null ||
        !_pendingLogRecords.containsKey(scope.memberId) ||
        !_queuedLogFlushes.add(scope)) {
      return;
    }
    // Writes for one account must stay ordered without holding up another
    // account's database when the user switches during a write.
    final owner = scope.memberId;
    final previous = _logQueues[owner] ?? Future<void>.value();
    late final Future<void> flush;
    flush = previous
        .then((_) {
          _queuedLogFlushes.remove(scope);
          return _flushLogRecords(scope);
        })
        .whenComplete(() {
          if (identical(_logQueues[owner], flush)) _logQueues.remove(owner);
        });
    _logQueues[owner] = flush;
  }

  Future<void> _flushLogRecords(AccountScope scope) async {
    final writer = _recordExperience;
    final pending = _pendingLogRecords[scope.memberId];
    if (_disposed || writer == null || pending == null) return;
    final written = <String>[];
    for (final record in pending.values.toList()) {
      try {
        // Completion already verified the owner. A later account switch does
        // not change the database that receives this finalized record.
        await writer(scope, record);
        written.add(record.eventKey);
      } catch (error) {
        debugPrint('Experience log write failed (${error.runtimeType})');
        break;
      }
    }
    if (written.isEmpty) return;
    await _enqueue(() async {
      for (final key in written) {
        pending.remove(key);
      }
      if (pending.isEmpty) _pendingLogRecords.remove(scope.memberId);
      final current = _accountSession.current;
      if (_isCurrent(current) && current.memberId == scope.memberId) {
        // Serialize the acknowledgement with later completions and switches.
        await _persist(current);
      }
      // An offscreen account may retry its saved record when selected again.
      // The database uses the event key to ignore the duplicate insert.
    });
  }

  void _move(
    CapturedApiEvent event,
    Map<Object?, Object?> data,
    GameState state,
    AccountScope scope,
  ) {
    final isStart = event.path == _startPath;
    final active = _active;
    final previous = isStart ? null : active;
    final area =
        _wireInt(data['api_maparea_id']) ??
        _wireInt(event.requestParams['api_maparea_id']) ??
        previous?.mapAreaId ??
        0;
    final map =
        _wireInt(data['api_mapinfo_no']) ??
        _wireInt(event.requestParams['api_mapinfo_no']) ??
        previous?.mapInfoNo ??
        0;
    final node = _wireInt(data['api_no']) ?? 0;
    if (area <= 0 || map <= 0 || node <= 0) {
      if (isStart) {
        _active = null;
      } else {
        previous?.loseNavigation();
      }
      notifyListeners();
      return;
    }

    final requestedDeck =
        _wireInt(event.requestParams['api_deck_id']) ??
        _wireInt(data['api_deck_id']) ??
        0;
    final combat = state.combatState;
    final matchingCombat =
        state.memberId == scope.memberId &&
        combat.isActive &&
        combat.mapArea == area &&
        combat.mapInfo == map;
    final sameMap = previous?.mapAreaId == area && previous?.mapInfoNo == map;
    final previousDeck = sameMap ? previous!.deckId : 0;
    final deck = requestedDeck > 0
        ? requestedDeck
        : previousDeck > 0
        ? previousDeck
        : (!isStart && matchingCombat ? combat.sortieFleetId : 0);

    if (isStart &&
        active?.startedAt == event.capturedAt &&
        active?.mapAreaId == area &&
        active?.mapInfoNo == map &&
        (deck == 0 || active?.deckId == deck)) {
      return;
    }

    if (previous != null && sameMap && previous.deckId == deck) {
      if (node != previous.node) {
        previous.markUnsettledBattle();
        previous.node = node;
        previous.battle = _NodeBattle.waitingForPhase;
      } else if (!previous.waitingForNavigation) {
        return;
      }
      previous.waitingForNavigation = false;
      if (matchingCombat && combat.sortieFleetId == deck) {
        previous.retreat(combat.escapedShipIds);
      }
    } else {
      final next = _snapshotRoster(
        state,
        scope,
        mapAreaId: area,
        mapInfoNo: map,
        deckId: deck,
        node: node,
        startedAt: isStart ? event.capturedAt : previous?.startedAt,
        eventKey: previous != null && sameMap
            ? previous.eventKey
            : _experienceEventKey('sortie', event),
        incomplete: !isStart,
      );
      if (!isStart && matchingCombat && combat.sortieFleetId == deck) {
        next.retreat(combat.escapedShipIds);
      }
      if (previous?.deckId == 0 && sameMap) next.battles = previous!.battles;
      _active = next;
    }
    notifyListeners();
  }

  _ActiveSortie _snapshotRoster(
    GameState state,
    AccountScope scope, {
    required int mapAreaId,
    required int mapInfoNo,
    required int deckId,
    required int node,
    required DateTime? startedAt,
    required String eventKey,
    required bool incomplete,
  }) {
    final trustedState = state.memberId == scope.memberId;
    final combined =
        trustedState &&
        deckId == 1 &&
        state.combinedFleetType != CombinedFleetType.none;
    final roster = _snapshotShips(state, scope, [deckId, if (combined) 2]);
    return _ActiveSortie(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      deckId: deckId,
      node: node,
      startedAt: startedAt,
      eventKey: eventKey,
      combined: combined,
      ships: roster.ships,
      incomplete: incomplete || roster.incomplete,
    );
  }

  ({List<SortieExperienceShip> ships, bool incomplete}) _snapshotShips(
    GameState state,
    AccountScope scope,
    List<int> fleetIds,
  ) {
    final trustedState = state.memberId == scope.memberId;
    final ships = <SortieExperienceShip>[];
    final seen = <int>{};
    var rosterIncomplete = !trustedState || fleetIds.first <= 0;
    for (final fleetId in fleetIds) {
      final fleet = trustedState
          ? state.fleets.where((fleet) => fleet.id == fleetId).firstOrNull
          : null;
      if (fleet == null || !fleet.shipIds.any((id) => id > 0)) {
        rosterIncomplete = true;
        continue;
      }
      for (final (position, id) in fleet.shipIds.indexed) {
        if (id <= 0) continue;
        if (!seen.add(id)) {
          rosterIncomplete = true;
          continue;
        }
        final masterId = state.ships[id]?.masterId ?? 0;
        ships.add(
          SortieExperienceShip(
            ownedShipId: id,
            masterShipId: masterId,
            name: state.masterShips[masterId]?.name ?? '',
            fleetId: fleetId,
            position: position,
          ),
        );
      }
    }
    return (ships: ships, incomplete: rosterIncomplete);
  }

  void _observeBattle(
    CapturedApiEvent event,
    Map<Object?, Object?> data,
    GameState state,
    AccountScope scope,
  ) {
    var active = _active;
    if (active == null ||
        active.waitingForNavigation ||
        active.battle == _NodeBattle.settled) {
      return;
    }
    final deck =
        _wireInt(event.requestParams['api_deck_id']) ??
        _wireInt(data['api_deck_id']) ??
        _wireInt(data['api_dock_id']) ??
        0;
    if (deck > 0 && active.deckId <= 0) {
      final recovered = _snapshotRoster(
        state,
        scope,
        mapAreaId: active.mapAreaId,
        mapInfoNo: active.mapInfoNo,
        deckId: deck,
        node: active.node,
        startedAt: active.startedAt,
        eventKey: active.eventKey,
        incomplete: true,
      )..battles = active.battles;
      _active = active = recovered;
      notifyListeners();
    } else if (deck > 0 &&
        active.deckId != deck &&
        event.path.startsWith('/kcsapi/api_req_sortie/')) {
      return;
    }
    active.battle = _NodeBattle.waitingForResult;
  }

  void _retreat(GameState state, AccountScope scope) {
    final active = _active;
    final combat = state.combatState;
    if (active == null ||
        state.memberId != scope.memberId ||
        !combat.isActive ||
        active.deckId != combat.sortieFleetId ||
        active.mapAreaId != combat.mapArea ||
        active.mapInfoNo != combat.mapInfo ||
        active.node != combat.currentNode ||
        combat.pendingEscapeShipIds.isEmpty) {
      return;
    }
    active.retreat(combat.pendingEscapeShipIds);
    notifyListeners();
  }

  static int? _practiceDeck(
    CapturedApiEvent event,
    Map<Object?, Object?> data,
  ) {
    final requested = _wireInt(event.requestParams['api_deck_id']);
    final reported = _wireInt(data['api_deck_id']);
    if (requested != null && reported != null && requested != reported) {
      return 0;
    }
    return reported ?? requested;
  }

  void _beginPractice(
    CapturedApiEvent event,
    Map<Object?, Object?> data,
    GameState state,
    AccountScope scope,
  ) {
    final deckId = _practiceDeck(event, data);
    if (deckId == null || deckId <= 0) {
      _discardPractice();
      return;
    }
    // Exercises use the one selected deck even while a combined fleet exists.
    // The result omits the deck ID, so freeze the lineup at the day phase.
    final roster = _snapshotShips(state, scope, [deckId]);
    if (roster.ships.isEmpty) {
      _discardPractice();
      return;
    }
    // A confirmed exercise supersedes a map sortie whose port was missed.
    // It must never book the unfinished map's pending total.
    _active = null;
    _practice = _PracticeBattle(
      eventKey: _experienceEventKey('practice', event),
      deckId: deckId,
      ships: roster.ships,
      incomplete: roster.incomplete,
    );
    notifyListeners();
  }

  void _discardPractice() {
    if (_practice == null) return;
    _practice = null;
    notifyListeners();
  }

  Future<void> _settlePractice(
    CapturedApiEvent event,
    Map<Object?, Object?> data,
    AccountScope scope,
    GameState gameState,
  ) async {
    final practice = _practice;
    if (practice == null) return;
    final deckId = _practiceDeck(event, data);
    if (deckId != null && deckId != practice.deckId) {
      _discardPractice();
      return;
    }
    final levelUps = data['api_get_exp_lvup'];
    final rewards = _decodeRewards(
      practice.ships,
      practice.deckId,
      data['api_get_ship_exp'],
      levelUps,
    );
    if (rewards == null || rewards.isEmpty) {
      _discardPractice();
      return;
    }
    _updateProgress(
      gameState,
      practice.ships,
      practice.deckId,
      rewards,
      levelUps,
    );
    _practice = null;
    await _completeSortie(
      scope,
      practice.snapshot(rewards),
      _archive.tracking ? rewards : const {},
      eventKey: practice.eventKey,
      completedAt: event.capturedAt,
    );
  }

  void _settle(Map<Object?, Object?> data, GameState gameState) {
    final active = _active;
    if (active == null ||
        active.waitingForNavigation ||
        active.battle != _NodeBattle.waitingForResult) {
      return;
    }
    active.battle = _NodeBattle.settled;
    active.battles++;
    final rewards = <int, int>{};
    final mainLevelUps = data['api_get_exp_lvup'];
    final main = _decodeRewards(
      active.ships,
      active.deckId,
      data['api_get_ship_exp'],
      mainLevelUps,
    );
    final escort = data['api_get_ship_exp_combined'];
    if (!active.combined &&
        escort is List &&
        escort.any((value) => (_wireInt(value) ?? 0) > 0)) {
      active.incomplete = true;
      notifyListeners();
      return;
    }
    if (main == null) {
      active.incomplete = true;
    } else {
      rewards.addAll(main);
      _updateProgress(
        gameState,
        active.ships,
        active.deckId,
        main,
        mainLevelUps,
      );
    }
    if (active.combined) {
      final escortLevelUps = data['api_get_exp_lvup_combined'];
      final extra = _decodeRewards(active.ships, 2, escort, escortLevelUps);
      if (extra == null) {
        active.incomplete = true;
      } else {
        rewards.addAll(extra);
        _updateProgress(gameState, active.ships, 2, extra, escortLevelUps);
      }
    }
    if (active.ships.any(
      (ship) => !ship.retreated && !rewards.containsKey(ship.ownedShipId),
    )) {
      active.incomplete = true;
    }
    active.recordedShipIds.addAll(rewards.keys);
    for (var index = 0; index < active.ships.length; index++) {
      final ship = active.ships[index];
      if (rewards[ship.ownedShipId] case final experience?) {
        active.ships[index] = ship._with(
          experience: ship.experience + experience,
        );
        if (_archive.tracking) {
          active.pending.update(
            ship.ownedShipId,
            (previous) => previous + experience,
            ifAbsent: () => experience,
          );
        }
      }
    }
    notifyListeners();
  }

  void _updateProgress(
    GameState state,
    List<SortieExperienceShip> ships,
    int fleetId,
    Map<int, int> rewards,
    Object? rawProgress,
  ) {
    final rows = rawProgress is List ? rawProgress : const [];
    for (final ship in ships) {
      if (ship.fleetId != fleetId) continue;
      final id = ship.ownedShipId;
      final gain = rewards[id];
      final baseline = _observedProgress(state, id);
      final before = _progressFor(state, id);
      if (gain == null || baseline == null || before == null) continue;
      // Unlike the rewards array, the level-up rows have no leading sentinel.
      final row = ship.position < rows.length ? rows[ship.position] : null;
      final current = before.afterAward(gain, row);
      if (current == baseline) {
        _projectedProgress.remove(id);
      } else {
        _projectedProgress[id] = (baseline: baseline, current: current);
      }
    }
  }

  void _reconcileProgress(Object? ships) {
    if (ships is! List || _projectedProgress.isEmpty) return;
    var changed = false;
    for (final row in ships) {
      final ship = _map(row);
      final id = _wireInt(ship?['api_id']);
      final baseline = _projectedProgress[id]?.baseline;
      if (baseline == null) continue;
      final level = _wireInt(ship?['api_lv']);
      final experience = ship?['api_exp'];
      // The state listener handles changed values. An explicitly refreshed
      // but unchanged roster must also retire a provisional calculation.
      if (id != null &&
          level == baseline.level &&
          experience is List &&
          experience.length >= 2 &&
          _wireInt(experience[0]) == baseline.experience &&
          _wireInt(experience[1]) == baseline.nextExperience) {
        _projectedProgress.remove(id);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  Future<void> _returnToPort(AccountScope scope, CapturedApiEvent event) async {
    final active = _active;
    if (active == null) {
      if (_unsaved.containsKey(scope.memberId)) await _persist(scope);
      return;
    }
    _active = null;
    active.markUnsettledBattle();
    await _completeSortie(
      scope,
      active.snapshot,
      active.pending,
      eventKey: active.eventKey,
      completedAt: event.capturedAt,
    );
  }

  Future<void> _completeSortie(
    AccountScope scope,
    SortieExperienceSnapshot snapshot,
    Map<int, int> trackedExperience, {
    required String eventKey,
    required DateTime completedAt,
  }) async {
    if (_recordExperience != null &&
        snapshot.battles > 0 &&
        snapshot.unverifiedShipIds.length < snapshot.ships.length) {
      _queueLogRecord(
        scope,
        LogbookExperienceRecord(
          eventKey: eventKey,
          completedAt: completedAt,
          isPractice: snapshot.isPractice,
          mapAreaId: snapshot.mapAreaId,
          mapInfoNo: snapshot.mapInfoNo,
          deckId: snapshot.deckId,
          battles: snapshot.battles,
          ships: [
            for (final ship in snapshot.ships)
              _logbookShip(ship, snapshot.confirmedExperience(ship)),
          ],
          incomplete: snapshot.incomplete,
        ),
      );
    }
    final totals = Map<int, SortieExperienceShip>.of(_archive.totals);
    for (final ship in snapshot.ships) {
      if (trackedExperience[ship.ownedShipId] case final experience?) {
        final previous = totals[ship.ownedShipId]?.experience ?? 0;
        totals[ship.ownedShipId] = ship._with(
          experience: _boundedTotal(previous + experience),
          retreated: false,
        );
      }
    }
    _archive = _archive._with(
      last: snapshot,
      totals: totals,
      totalSorties: _archive.totalSorties + (trackedExperience.isEmpty ? 0 : 1),
    );
    notifyListeners();
    await _persist(scope);
  }

  @override
  void dispose() {
    _disposed = true;
    _accountSession.removeListener(_onAccountChanged);
    _gameStateChanges?.removeListener(_onGameStateChanged);
    super.dispose();
  }
}

enum _NodeBattle { waitingForPhase, waitingForResult, settled }

final class _ActiveSortie {
  _ActiveSortie({
    required this.mapAreaId,
    required this.mapInfoNo,
    required this.deckId,
    required this.node,
    required this.startedAt,
    required this.eventKey,
    required this.combined,
    required this.ships,
    required this.incomplete,
  });

  final int mapAreaId;
  final int mapInfoNo;
  final int deckId;
  final DateTime? startedAt;
  final String eventKey;
  final bool combined;
  final List<SortieExperienceShip> ships;
  final pending = <int, int>{};
  final recordedShipIds = <int>{};
  int node;
  int battles = 0;
  _NodeBattle battle = _NodeBattle.waitingForPhase;
  bool waitingForNavigation = false;
  bool incomplete;

  void markUnsettledBattle() {
    if (battle == _NodeBattle.waitingForResult) incomplete = true;
  }

  void loseNavigation() {
    incomplete = true;
    waitingForNavigation = true;
    if (battle == _NodeBattle.waitingForResult) {
      battle = _NodeBattle.waitingForPhase;
    }
  }

  SortieExperienceSnapshot get snapshot => SortieExperienceSnapshot(
    mapAreaId: mapAreaId,
    mapInfoNo: mapInfoNo,
    deckId: deckId,
    battles: battles,
    ships: List.unmodifiable(ships),
    incomplete: incomplete,
    unverifiedShipIds: Set.unmodifiable({
      if (battles > 0)
        for (final ship in ships)
          if (!recordedShipIds.contains(ship.ownedShipId)) ship.ownedShipId,
    }),
  );

  void retreat(Iterable<int> ids) {
    for (var index = 0; index < ships.length; index++) {
      if (ids.contains(ships[index].ownedShipId)) {
        ships[index] = ships[index]._with(retreated: true);
      }
    }
  }
}

final class _PracticeBattle {
  const _PracticeBattle({
    required this.eventKey,
    required this.deckId,
    required this.ships,
    required this.incomplete,
  });

  final String eventKey;
  final int deckId;
  final List<SortieExperienceShip> ships;
  final bool incomplete;

  SortieExperienceSnapshot snapshot([Map<int, int>? rewards]) =>
      SortieExperienceSnapshot(
        mapAreaId: 0,
        mapInfoNo: 0,
        deckId: deckId,
        battles: rewards == null ? 0 : 1,
        ships: List.unmodifiable([
          for (final ship in ships)
            ship._with(experience: rewards?[ship.ownedShipId] ?? 0),
        ]),
        incomplete:
            incomplete || (rewards != null && rewards.length < ships.length),
        isPractice: true,
        unverifiedShipIds: Set.unmodifiable({
          if (rewards != null)
            for (final ship in ships)
              if (!rewards.containsKey(ship.ownedShipId)) ship.ownedShipId,
        }),
      );
}

String _experienceEventKey(String kind, CapturedApiEvent event) =>
    '$kind:${event.capturedAt.microsecondsSinceEpoch}:${event.sequence}';

LogbookExperienceShip _logbookShip(
  SortieExperienceShip ship,
  int? experience,
) => LogbookExperienceShip(
  ownedShipId: ship.ownedShipId,
  masterShipId: ship.masterShipId,
  name: ship.name,
  fleetId: ship.fleetId,
  experience: experience,
  retreated: ship.retreated,
);

Map<int, int>? _decodeRewards(
  List<SortieExperienceShip> ships,
  int fleetId,
  Object? raw,
  Object? levelUps,
) {
  if (raw is! List || raw.isEmpty || _wireInt(raw.first) != -1) return null;
  final fleet = {
    for (final ship in ships)
      if (ship.fleetId == fleetId) ship.position: ship,
  };
  // Some seven-ship results send six rewards but retain all seven level-up
  // rows. The available rewards are positional, and the seventh is unknown.
  final missingSeventh =
      fleet.length == 7 &&
      raw.length == 7 &&
      levelUps is List &&
      levelUps.length == 7;
  if (fleet.isEmpty ||
      fleet.keys.any(
        (position) =>
            position + 1 >= raw.length && !(missingSeventh && position == 6),
      )) {
    return null;
  }
  final result = <int, int>{};
  // Wire arrays use a leading -1 and retain the original fleet positions.
  // A positive reward in a known unused/evacuated slot invalidates the
  // entire deck instead of shifting rewards onto the wrong ship instance.
  for (var index = 1; index < raw.length; index++) {
    final value = _wireInt(raw[index]);
    final ship = fleet[index - 1];
    if (value == null || value < -1) return null;
    if (ship == null || ship.retreated) {
      if (value > 0) return null;
    } else {
      if (value < 0) return null;
      result[ship.ownedShipId] = value;
    }
  }
  return result;
}

int _boundedTotal(int experience) => experience > 9999999 ? 0 : experience;

extension type const _ShipProgress(
  ({int level, int experience, int nextExperience}) values
) {
  static _ShipProgress? fromShip(OwnedShip? ship) => ship == null
      ? null
      : _ShipProgress((
          level: ship.level,
          experience: ship.experience,
          nextExperience: ship.nextExperience,
        ));

  int get level => values.level;
  int get experience => values.experience;
  int get nextExperience => values.nextExperience;

  _ShipProgress afterAward(int gain, Object? row) {
    final fromWire = _fromResult(gain, row);
    if (fromWire != null) return fromWire;
    const cap = kShipMaxLevel;
    if (level <= 0 || level >= cap || gain == 0) return this;

    // Missing level-up rows can still use the synchronized Next. threshold.
    // A later result with a valid row re-anchors this projection.
    var threshold = nextExperience;
    if (threshold <= 0) {
      if (experience < shipCumulativeExp(level)) return this;
      threshold = shipCumulativeExp(level + 1) - experience;
      if (threshold < 0) return this;
    }
    var updatedLevel = level;
    var remainingGain = gain;
    while (remainingGain >= threshold) {
      remainingGain -= threshold;
      updatedLevel++;
      if (updatedLevel == cap) {
        return _ShipProgress((
          level: cap,
          experience: experience + gain - remainingGain,
          nextExperience: 0,
        ));
      }
      threshold =
          shipCumulativeExp(updatedLevel + 1) - shipCumulativeExp(updatedLevel);
    }
    return _ShipProgress((
      level: updatedLevel,
      experience: experience + gain,
      nextExperience: threshold - remainingGain,
    ));
  }

  _ShipProgress? _fromResult(int gain, Object? row) {
    if (row is! List || row.isEmpty) return null;
    final before = _wireInt(row.first);
    final last = _wireInt(row.last);
    if (before == null || last == null || before < 0 || last < before) {
      return null;
    }
    final after = before + gain;
    final maxExperience = shipCumulativeExp(kShipMaxLevel);
    if (after >= maxExperience) {
      return _ShipProgress((
        level: kShipMaxLevel,
        experience: maxExperience,
        nextExperience: 0,
      ));
    }
    final hasNextThreshold = row.length > 1 && last > after;
    if (!hasNextThreshold && (gain == 0 || before < experience)) return null;
    final updatedLevel = levelForExp(after);
    final threshold = hasNextThreshold
        ? last
        : shipCumulativeExp(updatedLevel + 1);
    return _ShipProgress((
      level: updatedLevel,
      experience: after,
      nextExperience: threshold - after,
    ));
  }
}

final class _Archive {
  const _Archive({
    this.tracking = false,
    this.last,
    this.totalSorties = 0,
    this.totals = const {},
  });

  final bool tracking;
  final SortieExperienceSnapshot? last;
  final int totalSorties;
  final Map<int, SortieExperienceShip> totals;

  static ({_Archive archive, List<LogbookExperienceRecord> pendingLogRecords})
  decode(String raw, int memberId) {
    final json = _requireMap(jsonDecode(raw));
    if (json['version'] != 1 ||
        json['memberId'] != memberId ||
        json['tracking'] is! bool) {
      throw const FormatException('Invalid sortie experience archive');
    }
    final count = _storedInt(json['totalSorties']);
    final totals = _storedShips(json['totals'])
      ..updateAll((_, ship) {
        final experience = _boundedTotal(ship.experience);
        return experience == ship.experience
            ? ship
            : ship._with(experience: experience);
      });
    if ((count == 0) != totals.isEmpty) {
      throw const FormatException('Invalid sortie experience total');
    }
    final last = json['last'];
    final records = json['pendingLogRecords'] ?? const [];
    if (records is! List) {
      throw const FormatException('Invalid pending experience records');
    }
    return (
      archive: _Archive(
        tracking: json['tracking'] as bool,
        last: last == null ? null : SortieExperienceSnapshot._fromJson(last),
        totalSorties: count,
        totals: totals,
      ),
      pendingLogRecords: [
        for (final record in records)
          LogbookExperienceRecord.fromRow(
            _requireMap(record).cast<String, Object?>(),
          ),
      ],
    );
  }

  String encode(
    int memberId,
    Iterable<LogbookExperienceRecord> pendingLogRecords,
  ) => jsonEncode({
    'version': 1,
    'memberId': memberId,
    'tracking': tracking,
    'last': last?._toJson(),
    'totalSorties': totalSorties,
    'totals': totals.values.map((ship) => ship._toJson()).toList(),
    if (pendingLogRecords.isNotEmpty)
      'pendingLogRecords': pendingLogRecords
          .map((record) => record.toRow())
          .toList(),
  });

  _Archive _with({
    bool? tracking,
    SortieExperienceSnapshot? last,
    int? totalSorties,
    Map<int, SortieExperienceShip>? totals,
  }) => _Archive(
    tracking: tracking ?? this.tracking,
    last: last ?? this.last,
    totalSorties: totalSorties ?? this.totalSorties,
    totals: totals ?? this.totals,
  );
}

Map<Object?, Object?>? _map(Object? value) => value is Map ? value : null;

Map<Object?, Object?> _requireMap(Object? value) =>
    _map(value) ??
    (throw const FormatException('Expected a sortie experience object'));

int? _wireInt(Object? value) => switch (value) {
  int number => number,
  String text => int.tryParse(text),
  _ => null,
};

int _storedInt(Object? value, {int min = 0}) {
  if (value is int && value >= min) return value;
  throw const FormatException('Invalid sortie experience number');
}

Map<int, SortieExperienceShip> _storedShips(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid sortie experience ships');
  }
  final ships = <int, SortieExperienceShip>{};
  for (final entry in value) {
    final ship = SortieExperienceShip._fromJson(entry);
    if (ships.containsKey(ship.ownedShipId)) {
      throw const FormatException('Duplicate sortie experience ship');
    }
    ships[ship.ownedShipId] = ship;
  }
  return ships;
}
